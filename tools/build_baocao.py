"""Assemble owner documents without changing their technical contents.
Sources remain authoritative; absent owner handoffs are listed, never fabricated.
"""
from pathlib import Path
import datetime,re,json,hashlib
ROOT=Path(__file__).resolve().parent.parent
DOCS=ROOT/'docs'

def read(name):return (ROOT/name).read_text(encoding='utf-8-sig')
def embed(name):
    # All markdown sources embedded below live in docs/, so relative links remain valid.
    content=read(name)
    return '\n> Nguồn ghép: ['+name.split('/')[-1]+']('+name.split('/')[-1]+'). Giữ nội dung kỹ thuật và ngày nguồn; các nhận định lịch sử không thay kết quả kiểm thử hiện hành.\n\n'+content+'\n'

intro="""# FreshVend — Báo cáo tổng hợp

**SCRUM-240 / FV-46 · Bản ghép 1.0 · Ngày tổng hợp: 15/11/2026 (UTC+7)**  
Biên tập: Nguyễn Phạm Xuân Anh. Người đọc chéo: Nguyễn Phương Huy — **chưa có xác nhận review**.

| Thành viên | Phần phụ trách |
|---|---|
| Nguyễn Phương Huy | Leader, inventory, URS/SRS, review |
| Huỳnh Nhật Toàn | auth/audit, phân quyền, backup, ERD |
| Đoàn Phương Thiên Ân | sales, kiosk, Docker, thiết kế chi tiết |
| Trương Tuấn Dũng | IoT, kiến trúc, simulator, vận hành máy |
| Nguyễn Phạm Xuân Anh | report, QA, Test Report, manual Admin, ghép báo cáo |

Báo cáo mô tả sản phẩm theo mã hiện có và các lần chạy thật. Không phải biên bản nghiệm thu toàn hệ thống. Đề mục yêu cầu được nhóm ghi trong NHIEM_VU_CHI_TIET; bản đề gốc mục e) không có trong repo để đối chiếu độc lập. Bảng sau bao phủ sáu nhóm tài liệu theo hướng dẫn FV-46.

| Nhóm tài liệu | Chương | Nguồn / tình trạng |
|---|---|---|
| URS/SRS | 1 | SRS hiện là draft; chờ FV-34 của Huy |
| Kiến trúc và ERD | 2–3 | Hai ảnh diagram, topology FK và dictionary từ SQL thật; chờ tài liệu FV-37/FV-42 được owner duyệt |
| Thiết kế chi tiết | 4 | Ghép DetailedDesign của nhóm |
| Triển khai và kiểm thử | 5–6 | Script module, Test Plan và Test Report có log thật |
| Cài đặt | 7 | Bộ cài đã chạy, runbook backup; chưa có xác nhận cài chéo máy khác |
| Ba user manual | 8 | Admin đầy đủ; Customer/Operator có quy trình đối chiếu UI hiện có, chờ bản chính thức và ảnh SQL thật từ owner |

Ngày trên bìa là ngày ghép; ngày trong tài liệu nguồn và log được giữ để truy vết, không đổi thành ngày hôm nay. SQL Server 2022 là nền tảng thực tế, Node.js theo package/lockfile; thiết bị là **mô phỏng bằng app/simulator/esp32.js**, không phải phần cứng đã lắp. Thanh toán trong kiểm thử không phải giao dịch ngân hàng thật.

## Mục lục

1. [Yêu cầu và phạm vi](#yeu-cau)
2. [Kiến trúc](#kien-truc)
3. [Thiết kế dữ liệu, ERD và từ điển](#du-lieu)
4. [Thiết kế chi tiết](#thiet-ke)
5. [Triển khai](#trien-khai)
6. [Kiểm thử](#kiem-thu)
7. [Cài đặt và sao lưu](#cai-dat)
8. [Ba hướng dẫn người dùng](#huong-dan)
9. [Nguồn bàn giao, giới hạn và review](#ban-giao)

<a id="yeu-cau"></a>

## 1. Yêu cầu và phạm vi

Hệ thống hỗ trợ quản lý đội máy bán trái cây, châm hàng theo lô/hạn dùng, mua tại kiosk, ghi nhận thanh toán và nhả hàng, telemetry/cảnh báo và báo cáo cho Admin. Khách thao tác kiosk đã được kích hoạt; Operator chỉ thao tác máy được giao; Admin xem doanh thu toàn đội và quản lý tài khoản. Các yêu cầu mục tiêu như phản hồi dưới 500 ms, uptime 99,9%, kẹt dưới 2% phải được đo, không suy ra từ số lượng file SQL.

Ma trận truy vết biên tập từ các module có thật:

| Yêu cầu | Thành phần | Kiểm chứng hiện hành |
|---|---|---|
| Đăng nhập và quản lý quyền | auth/audit, 10/20/40 | 18/18 auth, audit 10/10, security 11/11 |
| Tồn kho, temporal, TVP/FIFO | inventory, 11/21/30 | 53/54 unit; temporal T48 chưa đạt |
| Mua, thanh toán, nhả | sales, 12/22 | SQL sales 5/5; tạo đơn qua API đang lỗi TVP |
| Cảm biến/cảnh báo | iot, 13/23 | ingest 6/6; cảnh báo và reconnect chưa đạt mô phỏng |
| Phân tích và CSV | report, 14/24 | sáu ca report PASS trong runner; chưa nghiệm thu PDF |
| Sao lưu và STOPAT | 50_backup, demo_security | Full/Diff/Log và restore thực PASS; chưa chứng minh HA/RPO=0 |

Các số trên là tóm tắt Test Report của bản nhánh, không áp cho main trước khi merge. Sau đây là SRS nguồn và User Story bán hàng, giữ nguyên để Huy tiếp tục hoàn thiện.
"""
architecture="""
<a id="kien-truc"></a>

## 2. Kiến trúc

Trình duyệt Admin/Operator và kiosk gọi REST API Node.js. API kiểm tra JWT/vai trò, bind tham số rồi EXEC stored procedure hoặc SELECT view/TVF qua bốn login SQL. RLS lọc máy theo SESSION_CONTEXT. Simulator gửi telemetry và kết quả nhả bằng khóa thiết bị. SSE cập nhật đội máy/cảnh báo trên UI. DB_MODE=demo dùng fakeDb; DB_MODE=sqlserver dùng SQL Server thật. Mô tả đối chiếu app/api/src/db.js, app/api/src/routes, app/web/js/admin.js và app/simulator/esp32.js, không thay tài liệu kiến trúc chính thức của Dũng.

```mermaid
flowchart LR
    Console[Admin / Operator browser] -->|JWT / REST| API[Node.js API]
    Kiosk[Kiosk browser] -->|REST| API
    Simulator[esp32.js simulated DHT22 and servo] -->|X-Device-Key / JSON| API
    API -->|EXEC SP / SELECT view or TVF / four logins| DB[(SQL Server 2022)]
    API -->|SSE| Console
    DB --> Backup[Full / Differential / Log backups]
```

Sơ đồ thành phần và triển khai do nhóm đã có trong repo; chưa có biên bản review cập nhật của owner:

![Sơ đồ thành phần nguồn](component_diagram.png)

![Sơ đồ triển khai nguồn](deployment_diagram.png)

Điểm cần chốt: hợp nhất nguồn máy, UTC thống nhất, ba đối tượng API IoT, lịch job/partition và hợp đồng duration của TelemetryHourly. Docker có Dockerfile/compose nhưng chưa chạy trong đợt kiểm tra này. Không coi sơ đồ biểu diễn là bằng chứng triển khai đầy đủ.

<a id="du-lieu"></a>

## 3. Thiết kế dữ liệu, topology ERD và Data Dictionary

Sáu schema: auth, audit, inventory, sales, iot, report. Snapshot từ CSDL QA thật đã dựng bằng bộ cài, metadata đọc bằng tools/export-report-schema.ps1; [JSON ngày giờ/đối tượng](evidence/SCRUM-240/schema.json). Snapshot có cả temporal history và hai bảng máy hiện tại, không vẽ schema đích thay schema đang chạy.

Các mối liên hệ chính: User–Role–UserRole, User–UserMachine–Machines, Location–Machines, Machine–Slot–SlotStock–StockBatch–Product, Order–OrderItem–Payment–DispenseEvents, Machine–Telemetry/TelemetryHourly/Alerts và User–ExportLogs. Khóa ngoại chéo schema tập trung ở 03_foreign_keys.sql; các khóa trong schema ở script bảng tương ứng.

Sơ đồ dưới chỉ thể hiện chiều FK từ bảng con sang bảng cha, nhãn là cột FK; không suy diễn cardinality/unique composite từ sơ đồ. Đây là phụ lục tự trích từ DB, **không thay ERD.png/DataDictionary được Toàn review trong FV-37**. [Từ điển đầy đủ cột/kiểu/NULL/PK/identity/default và FK](BaoCao_DataDictionary.md).

```mermaid
"""
implementation="""
<a id="trien-khai"></a>

## 5. Triển khai

| Nhóm | Script chính | Trách nhiệm |
|---|---|---|
| Nền | 00_database, 01_schemas, 02_tables_*, 03_foreign_keys | CSDL, schema, bảng, FK có kiểm tra dữ liệu |
| Auth/audit | 10_procs_auth, 20_objects_auth, 40_security | Tài khoản, login history, audit JSON, RBAC và RLS |
| Inventory | 11_procs_inventory, 21_objects_inventory, 30_index_inventory | Sản phẩm, giá temporal, lô, TVP restock, FIFO |
| Sales | 12_procs_sales, 22_objects_sales | Đơn, payment idempotency, dispense, refund, trạng thái |
| IoT | 13_procs_iot, 23_objects_iot | Đăng ký máy, ingest JSON, heartbeat, hourly; còn phần chưa đủ |
| Report | 14_procs_report, 24_objects_report | KPI, LAG, PIVOT, RANK, inline TVF, summary, export logs, test runner |
| Cài/backup | 99_run_all.bat, tools/install-database.ps1, 50_backup | Thứ tự script, fail-fast, Full/Diff/Log và checksum |

Mỗi file SQL giữ riêng, không tạo FULL.sql. DDL dùng CREATE OR ALTER / kiểm tra tồn tại; procedure ghi theo NOCOUNT/XACT_ABORT/TRY–kiểm tra–TRAN–ghi–COMMIT/CATCH–ROLLBACK–THROW. Quy ước mã TV1 500xx, TV2 501xx, TV3 502xx, TV4 503xx và TV5 504xx; giữ tên legacy thật để tương thích, không tự đổi số nhiều trong bản ghép tài liệu.

Quy tắc repository: mỗi task nhánh riêng, không push main, Huy review trước merge. Test CI ứng dụng dùng fakeDb, không thay SQL acceptance. Bộ seed 80/81 còn chờ QĐ-1/RegisterMachine; không báo đã có dữ liệu LARGE hoặc uptime khi chưa đo.

<a id="kiem-thu"></a>

## 6. Kiểm thử

Tài liệu dưới ghép nguyên nội dung Test Plan và Test Report. Khi mâu thuẫn với các con số ở tài liệu lịch sử, Test Report chạy ngày 15/11/2026 và log đi kèm là nguồn hiện hành cho bản nhánh này. Không cộng trùng ca report/runner, không cộng npm giả thành kiểm thử SQL.
"""
install=r"""
<a id="cai-dat"></a>

## 7. Cài đặt, backup và khôi phục

Yêu cầu: Windows có SQL Server 2022, Microsoft sqlcmd, Windows login đủ quyền tạo CSDL/login/backup; Node.js theo package (CI dùng 20). Máy dịch vụ SQL cần quyền ghi thư mục backup/data. Một lệnh cài:

```bat
99_run_all.bat .\SQLEXPRESS FreshVendDB
```

Lệnh dựng object/security/backup, không tự xóa DB và mặc định không seed. Cài SQL thành công không có nghĩa API đủ các đối tượng IoT hay seed chạy thành công. Bộ cài hiện đã kiểm tra từ **CSDL trống trên SQL Server có sẵn**, chưa kiểm tra từ Windows/VM trắng hoặc người khác tự cài trong 30 phút.

Để chạy app, từ gốc repo: npm ci --prefix app/api; copy app/api/.env.example thành app/api/.env; đặt DB_MODE=sqlserver, DB_NAME và DB_SERVER/DB_PORT đúng máy, bốn login khớp SQL và mật khẩu local; npm start --prefix app/api. Cần Mixed Mode/TCP cho driver SQL login. Không commit .env. Kiểm tra /api/health trả đúng mode và CSDL; xem /api-docs để đối chiếu route. Demo/SQL là hai môi trường riêng, không nhập nhằng số liệu.

Docker: [hướng dẫn của Ân](../app/README.md#3b-docker-sql-server--api), [compose](../docker-compose.yml), [Dockerfile](../app/Dockerfile). Không chạy Docker trong đợt kiểm tra này và không nhận trạng thái đã cài thành công trên container. Sau đây là runbook backup đã kiểm chứng; InstallGuide cũ còn trạng thái lịch sử và cần Toàn cập nhật tại FV-38.
"""
operator="""
### 8.2. Operator — quy trình đối chiếu giao diện hiện có

Nguồn: app/web/js/pages/restock.js, products.js, machines.js và alerts.js. Đây là phần biên tập theo UI để báo cáo có quy trình Operator, **chưa phải bản manual chính thức có ảnh SQL thật của Huy/Dũng**. Hiện thiếu view IoT khiến trang lấy danh sách máy lỗi; xử lý phụ thuộc trước khi tập huấn vận hành.

1. Đăng nhập bằng Operator, kiểm tra máy được giao. Không thấy máy thì nhờ Admin kiểm tra phân công; không dùng tài khoản người khác.
2. Vào Châm hàng & tồn kho, chọn máy. Xem sản phẩm/ngăn, tồn, sức chứa, lô sắp hết hạn và lô đã hết hạn.
3. Chọn Nhập lô mới khi có lô thực, nhập đúng sản phẩm/số lượng/nhà cung cấp theo phiếu. Đối chiếu ngày hết hạn được hệ thống tính; không nạp lô sai sản phẩm hoặc hết hạn.
4. Với từng ngăn cần châm, chọn lô đúng và số lượng trong sức chứa còn trống. Chỉ đổi sản phẩm khi ngăn không còn hàng; ghi chú ca châm, bấm Xác nhận châm hàng một lần. Một dòng lỗi phải rollback cả lần châm; tải lại để đối chiếu tồn trước khi thao tác tiếp.
5. Dùng Rút hàng hết hạn cho máy đang kiểm tra; đối chiếu số hộp thực rút với kết quả. Phần sắp hết hạn không đồng nghĩa đã hết hạn.
6. Vào Máy & chuỗi lạnh/Cảnh báo, nhận xử lý, kiểm tra thiết bị, hoàn tất sau khi xác minh. Không xóa lỗi để che quá nhiệt. Với lỗi 401/403 kiểm tra phiên/phân công; 500 lưu thời gian và thông báo cho người phụ trách.
7. Đăng xuất khi hết ca. Operator không xem doanh thu hay quản lý tài khoản Admin. Xem Test Report để biết các ca UI/IoT chưa nghiệm thu.

### 8.3. Customer — quy trình kiosk

Nguồn quy trình bán hàng: app/README.md mục 4, docs/UserStories_Sales.md và app/web/kiosk.html. Biên tập thống nhất thuật ngữ; **chưa có bản UserManual_Customer được Ân bàn giao/duyệt**. API tạo đơn SQL hiện bị lỗi TVP nên quy trình này mô tả giao diện mong đợi, chưa xác nhận hoàn thành E2E trên bản thử.

1. Khách dùng kiosk đã được kỹ thuật viên kích hoạt bằng tài khoản Kiosk gắn máy; khách không cần tài khoản Admin hay nhập khóa thiết bị.
2. Xem món còn bán, giá và số lượng; chọn món, tăng/giảm/xóa trong giỏ và kiểm tra tổng tiền.
3. Chọn thanh toán, đối chiếu số tiền/nội dung chuyển khoản của đơn và tài khoản nhận trên VietQR. Không chuyển tiền vào tài khoản mẫu khi chạy demo. Không coi hình QR xuất hiện là đã thanh toán.
4. Khi có xác nhận tiền, đợi màn hình mời nhận hàng và lấy đúng món. Nếu chưa xác nhận, không tạo/chuyển khoản lặp lại; báo hỗ trợ cùng mã đơn/thời gian để đối chiếu.
5. Khi đơn hết hạn, làm theo thông báo; không tiếp tục dùng QR cũ. Kẹt hàng hoặc giao thiếu cần cung cấp mã đơn cho hỗ trợ. Trạng thái REFUNDED trong SQL là ghi nhận nghiệp vụ; chưa chứng minh ngân hàng đã hoàn tiền thực.
6. Nếu máy báo đang suy giảm làm lạnh/bảo trì hoặc mất kết nối, ngừng thao tác và liên hệ số hỗ trợ được đơn vị vận hành cấu hình. Không có hotline thật được xác minh trong bản thử.
"""
handoff="""
<a id="ban-giao"></a>

## 9. Nguồn bàn giao, giới hạn và đọc chéo

Nguồn được giữ nguyên nội dung kỹ thuật khi ghép: SRS.md, UserStories_Sales.md, DetailedDesign.md, TestPlan.md, TestReport.md, Backup_RunAll.md, UserManual_Admin.md; diagram gốc và metadata có SHA-256 trong [assembly.json](evidence/SCRUM-240/assembly.json). Bản ghép không chỉnh nội dung hay đóng task thay thành viên khác.

| Phần cần bổ sung | Người phụ trách / phụ thuộc | Điều kiện chốt |
|---|---|---|
| URS/SRS cuối cùng, story tồn kho | Huy, FV-34 | Thay bản draft bằng nội dung đã review |
| Kiến trúc chính thức | Dũng, FV-42 | Đối chiếu diagram với object và triển khai thật |
| ERD.png/DataDictionary chính thức | Toàn, FV-37 | Review metadata/schema và mô hình; snapshot phụ lục chỉ là đầu vào |
| Customer manual | Ân, FV-39 | Bản chính thức và luồng SQL thực sau sửa TVP |
| Operator manual có ảnh | Huy/Dũng, FV-34/FV-43 | Ảnh thao tác SQL thật; xử lý view IoT trước |
| Test Report cập nhật sau sửa lỗi | Anh cùng chủ module, FV-45 | Chạy lại các ca FAIL/BLOCKED và dataset LARGE |
| Đọc chéo, review và merge | Huy | Một bạn review, CI đạt; không tự approve |

Báo cáo đã có các nhóm đề mục, phụ lục dữ liệu thật và manual Admin; **chưa thể xác nhận FV-46 hoàn tất 100%** do nguồn URS/SRS/manual/kiến trúc chính thức và review chưa đủ. Các mục trên là bàn giao cần thực hiện, không phải checkbox PASS. Khi owner cập nhật file, ghép lại bằng python tools/build_baocao.py và kiểm tra link/phiên bản trước nộp.
"""
text=intro+embed('docs/SRS.md')+embed('docs/UserStories_Sales.md')+architecture
text+=read('docs/evidence/SCRUM-240/schema.mmd')+'```\n'
text+='\n<a id="thiet-ke"></a>\n\n## 4. Thiết kế chi tiết\n'+embed('docs/DetailedDesign.md')+implementation
text+=embed('docs/TestPlan.md')+embed('docs/TestReport.md')+install+embed('docs/Backup_RunAll.md')
text+='\n<a id="huong-dan"></a>\n\n## 8. Ba hướng dẫn người dùng\n\n### 8.1. Admin\n'+embed('docs/UserManual_Admin.md')+operator+handoff
# Optional owner handoffs, appended verbatim when available, rather than silently omitted.
for file in ['docs/UserManual_Customer.md','docs/UserManual_Operator.md','docs/Architecture.md','docs/DataDictionary.md']:
    if (ROOT/file).exists():text+='\n## Phụ lục bàn giao: '+Path(file).name+'\n'+embed(file)
(DOCS/'BaoCao.md').write_text(text,encoding='utf-8-sig')
print('Assembled docs/BaoCao.md; unresolved owner handoffs remain explicit.')
