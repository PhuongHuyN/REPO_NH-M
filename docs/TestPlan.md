# Test Plan tổng — FreshVend / SCRUM-211

Phiên bản 3.0 · Soạn 09/11/2026, trước kiểm thử Sprint 2–3 · Người phụ trách: Nguyễn Phạm Xuân Anh (TV5/QA). Nguồn: MASTER_PLAN QĐ-1..5, TEAM_ASSIGNMENT, schema/procedure hiện có, app/api/test/fakeDb.js, tests/tests_inventory.sql và tests/tests_sales.sql.

## 1. Phạm vi và nguyên tắc

Năm module: auth (kèm audit), inventory, sales, iot, report. Ba loại kiểm thử bắt buộc: unit, integration, performance; bổ sung regression, security, concurrency, idempotency và phục hồi lỗi. Mục tiêu: đúng nghiệp vụ, không thất thoát tồn/tiền, đúng vai trò, báo cáo khớp dữ liệu nguồn và đạt ngưỡng hiệu năng có số đo thật.

Ma trận cuối tài liệu có 30 procedure × 3 ca = 90 ca: mỗi procedure một ca hợp lệ và hai ca âm. 23 procedure đã có định nghĩa; auth 5 và inventory Restock/RemoveExpired 2 là kế hoạch chờ owner. Ma trận là **kế hoạch**, không phải kết quả đã chạy. Phiên SQL riêng report ngày 09/11 đạt 18 ca và oracle; các ca còn lại phải giữ NOT RUN/BLOCKED đến khi có bằng chứng.

Nguồn kết quả hiện tại: docs/Week1_Anh_Validation.md. TestReport 04/11 là lịch sử schema cũ, không dùng chứng minh schema mới. Không đặt Actual=Expected hoặc seed sẵn Passed=1.

## 2. User Story Admin

| ID | User Story | Tiêu chí chấp nhận |
|---|---|---|
| US-ADM-01 | Là Admin, tôi muốn xem doanh thu theo sản phẩm để biết đóng góp của từng sản phẩm. | Chỉ cộng đơn PAID/DISPENSED, loại PENDING/CANCELLED/REFUNDED. Hiển thị QtySold, Revenue và hạng trong địa điểm. Cùng doanh thu cùng hạng, hạng sau bỏ số. Có trạng thái không dữ liệu. |
| US-ADM-02 | Là Admin, tôi muốn lọc doanh thu theo địa điểm và khoảng ngày để so sánh điểm đặt máy. | Ngày bao gồm hai đầu theo UTC+7. Tổng bằng tổng chi tiết đơn tương ứng. From>To bị từ chối tại lớp gọi; TVF trả rỗng. Địa điểm không có doanh thu không có dòng trong TVF. |
| US-ADM-03 | Là Admin, tôi muốn xem giờ cao điểm để bố trí bổ sung hàng. | 24 giờ và ma trận T2–CN độc lập DATEFIRST. Seed lớn tập trung 7–9h, 11–13h, 17–19h (không gồm biên phải). |
| US-ADM-04 | Là Admin, tôi muốn xuất CSV để phân tích trên bảng tính. | UTF-8, tiêu đề cột, escape dấu phẩy/nháy/xuống dòng, chống công thức bảng tính tại lớp xuất. Nội dung khớp bộ lọc; từ chối người không quyền; log UserId, Params JSON, FileFormat=CSV. |
| US-ADM-05 | Là Admin, tôi muốn xuất PDF để chia sẻ báo cáo. | PDF mở được, có tiêu đề/ngày/địa điểm/tổng tiền, phân trang không mất dòng. Log FileFormat=PDF. SQL chuẩn bị dữ liệu và ghi PENDING; ứng dụng xác nhận SUCCESS/FAILED sau tạo file. |
| US-ADM-06 | Là Admin, tôi muốn giám sát toàn đội máy để phát hiện máy offline, kẹt và vi phạm chuỗi lạnh. | Bao gồm máy không có đơn/telemetry; hiển thị trạng thái và cảnh báo. Tỷ lệ JAM/tổng lần nhả <0.02 mới đạt; đúng 0.02 không đạt. Nhiệt độ 2 và 8°C hợp lệ. Không dữ liệu hiển thị chưa xác định. |

## 3. Môi trường và cấu hình

| Hạng mục | Môi trường chuẩn / cách ghi bằng chứng |
|---|---|
| Máy | Windows 10/11; ghi CPU, RAM, tải nền, thời điểm và mã máy test, không gửi thông tin định danh nhạy cảm |
| CSDL | SQL Server 2022 Express/Developer 16.x, compatibility 160, Vietnamese_CI_AS; ghi ProductVersion/Edition và isolation |
| Runtime | Node.js 20+; ghi node -v, npm -v, commit SHA và package-lock; test 09/11 đã chạy Node 26, không khẳng định là Node 20 |
| SQL client | SSMS hoặc sqlcmd -I -b; QUOTED_IDENTIFIER/ANSI ON, NUMERIC_ROUNDABORT OFF |
| API/Web | DB_MODE=sqlserver cho nghiệm thu; demo/fakeDb chỉ unit API, không thay SQL thật; localhost:3000 và cấu hình .env không commit |
| CSDL test | Tạo CSDL tên FreshVendTV5_Week1_timestamp riêng; quyền DDL cho người setup, role thật khi test RBAC/RLS |
| Agent | Express dùng JOBS_FALLBACK; Developer có thể Agent, ghi rõ phương án đang chạy |

Cài theo bảng README/QĐ-3, giữ script module riêng. 99_run_all.bat chờ Toàn/FV-23; không giả lập file đã có. Không sửa/xóa dữ liệu production. Backup trước nghiệm thu phục hồi; không dùng script có ROLLBACK IMMEDIATE trên CSDL có giao dịch cần giữ.

## 4. Dữ liệu, oracle và tiền điều kiện

- 08_seed_inventory của Huy: danh mục vận hành 36 sản phẩm, 5 máy ×12 ngăn, lô/SlotStock; dùng kiểm FIFO/restock/hạn theo giờ. Không xóa hoặc thay thế bằng fixture báo cáo.
- 80_seed_small: fixture TV5 3 địa điểm, 5 máy, 10 sản phẩm, 50 đơn; 81_seed_large: tổng fixture 20 máy, 15 sản phẩm, 5.000 đơn/90 ngày và 200.000 telemetry. Số lượng theo mã TV5-, dữ liệu chủ module giữ riêng. Small→large vẫn 5.000 đơn; chạy độc lập/lặp phải giữ số lượng, tiền và FK.
- Thời gian lưu UTC; ngày/giờ bán UTC+7; khoảng ngày báo cáo bao gồm hai đầu bằng UTC [From-7h,To+17h). Dataset lịch sử cố định [06/08/2026,04/11/2026), giờ cao điểm [7,9),[11,13),[17,19). Tài khoản fixture bị vô hiệu hóa, không là mật khẩu demo thật.
- Máy chuẩn iot.Machines/iot.Locations; inventory.Machine phải là view tương thích QĐ-1. SlotId/SlotCode giữ tên SQL, API ColumnId/ColumnNo là alias. Dispense dùng sales.DispenseEvents, AttemptNo 1..3. Không tạo bảng/schema thay owner để test xanh.
- KPI, growth và fn_RevenueByLocation dùng net Order.TotalAmount của PAID/DISPENSED; TVF tổng hợp mỗi đơn một lần kể cả nhiều chi tiết. Ranking/summary dùng gross SUM(Quantity*UnitPrice); summary NetRevenue trừ giảm giá phân bổ. Audit export bao gồm REFUNDED/DISPENSE_FAILED theo fakeDb. Kiểm riêng nhiều dòng, giảm giá, hoàn một phần/toàn bộ.
- FailureRate là JAM/tổng lần nhả vật lý, 0..1, không có lần nhả NULL. <0.02 mới đạt; đúng 0.02 không đạt. Retry cũng tính vào mẫu số.
- View cold-chain đọc iot.TelemetryHourly theo contract hiện tại: một hourly đại diện 60 phút, MinutesOutOfRange phải là phút thật 0..60, 2 và 8°C hợp lệ. Không hourly →NULL; phút -1/61/NULL →không công bố compliance hợp lệ. Giả định coverage phải được owner xác nhận; không suy diễn khoảng mất telemetry là hợp lệ. Raw→hourly/backfill đang chờ #21; không dùng số mẫu làm phút.
- Mỗi ca dựng dữ liệu theo trạng thái được ghi trong Input, chụp baseline/row count, gọi procedure, SELECT oracle độc lập, rồi cleanup/rollback. Mật khẩu/hash/token không đưa vào log/ảnh PR.

## 5. Điều kiện vào và điều kiện ra

| Cổng | Tiêu chí |
|---|---|
| Entry unit SQL | Owner schema/procedure tồn tại, compile thành công, fixture riêng, xác nhận Input/Expected và mã lỗi; ca âm không ghi một phần |
| Entry integration | PR module đã merge/review, #19/#20 xử lý, auth/sql login/quyền đủ, DB_MODE=sqlserver, không thiếu view/function API cần |
| Entry performance | Large seed đã xác minh số dòng và khoảng ngày; query/endpoint đã đúng nghiệp vụ; ghi hardware, tải, index, plan và cache |
| Exit unit | 100% ca procedure đã duyệt chạy; 0 FAIL không giải thích; không tính SKIP/BLOCKED là PASS; mỗi procedure ≥3 ca |
| Exit integration | INT-01..10 đạt; tiền/tồn/FK/audit/state đúng; không lỗi Highest/High đang mở |
| Exit performance | API p95 ≤500 ms theo từng endpoint và workload; query report warm <500 ms trên seed lớn, có raw samples và execution plan |
| Exit release | Npm CI xanh, SQL thật đạt, mọi issue ảnh hưởng nghiệm thu xử lý hoặc được Leader chấp thuận ghi rõ; Leader review/approve; không tự merge |

Hiện tại entry integration chưa đạt: #19 FK cũ, #20 hai bảng máy, #21 phút telemetry. Thiếu auth và hai procedure inventory được ghi BLOCKED, không tự bổ sung thay chủ module trong nhiệm vụ Test Plan.

## 6. Unit và regression

Unit SQL ở tests/tests_<module>.sql; hiện có inventory/sales, auth/iot chờ owner theo Sprint 3; report có tests/sql/37_verify_report.sql và runner SQL. Npm test --prefix app kiểm tra API/mock, binding/session context và đồng bộ FE/BE. Regression chạy sau mỗi PR merge; lưu số PASS/FAIL/BLOCKED, không chỉ so tổng PASS với lần trước.

Ma trận đầy đủ cuối tài liệu và docs/TestCases_Week1.md; dữ liệu máy đọc docs/TestCases_Week1.json. Tên tham số/mã lỗi chốt theo SQL owner + fakeDb. Mã lỗi TV1 500xx, TV2 501xx, TV3 502xx, TV4 503xx, TV5 504xx. Login sai có Success=0 là kết quả hợp đồng, không mặc định phải THROW. Ca âm không nhất thiết là exception: lặp expire, đơn sai trạng thái hoặc không có hàng hết hạn có thể trả 0 thay đổi.

Procedure không có tham số như AggregateHourly dùng ca âm ngữ cảnh (DENY/READ_ONLY) trên DB test, thay vì bịa tham số. Quyền security chưa có thì giữ BLOCKED. Dọn READ_ONLY về READ_WRITE trong finally kể cả test lỗi. Không chỉ bắt mọi exception rồi đánh PASS.

## 7. Integration end-to-end trên SQL thật

| ID | Tiền điều kiện và các bước | Expected / oracle | Chủ trì |
|---|---|---|---|
| INT-01 | Admin/Operator/Kiosk đăng nhập, chọn role và scope; gọi API bằng JWT | Đúng role; operator chỉ máy được giao; kiosk không đọc báo cáo; token lỗi 401, sai quyền 403 | Toàn + Anh |
| INT-02 | Thêm sản phẩm, giá, lô còn hạn; gán cột rỗng; châm 2 dòng TVP | Hạn = PreparedAt+ShelfLifeHours, giá temporal có history, tồn/phiếu/movement đúng | Huy + Anh |
| INT-03 | Châm dòng đầu hợp lệ, dòng sau vượt sức chứa hoặc sai lô | 50117/50114; rollback cả tồn và phiếu, không thành công một phần | Huy |
| INT-04 | Kiosk tạo đơn từ tồn còn hạn, chọn Qty; hai phiên tranh hộp cuối | Một đơn thành công, đơn kia hết hàng; FIFO theo ExpiryAt, tồn không âm | Ân + Huy |
| INT-05 | Ngân hàng callback đúng tiền/chữ ký, gọi lại cùng GatewayTxnId | PAID, một payment, idempotent; callback sai tiền không PAID; không thu lại | Ân |
| INT-06 | Simulator lấy queue → SUCCESS; chạy lại cùng event | Một nhả vật lý, cả đơn hoàn thành đúng; không trừ hàng hai lần | Ân + Dũng |
| INT-07 | Đơn PAID nhả JAM ba lần hoặc chưa nhả và yêu cầu hoàn | DispenseEvents đầy đủ, một refund phần chưa nhả, tồn trả đúng, FAULT/cảnh báo đúng | Ân + Dũng |
| INT-08 | Payload machineId temp/cửa; 3 lần vượt, cửa mở, heartbeat mất mạng rồi hồi phục | Telemetry đúng máy/UTC; threshold/alert/status đúng; không cảnh báo trùng; kiểm offline trên kiosk | Dũng |
| INT-09 | Aggregate raw→hourly → compliance; 30 phút quá nhiệt với mẫu 5 giây | 30 phút ngoài, không 360; biên 2/8 hợp lệ; gap/coverage đúng hợp đồng owner | Dũng + Anh |
| INT-10 | Refresh summary → KPI/growth/location/ranking/peak → CSV/PDF → log | Gross/net rõ; không nhân đơn nhiều dòng; refund loại khỏi revenue; đúng file/bộ lọc, SUCCESS chỉ khi ứng dụng xác nhận | Anh |

INT-01..10 chạy DB_MODE=sqlserver, lưu cả request/status, SELECT trước/sau và log/ảnh có timestamp + SHA. Kết quả mock không đánh PASS cho bảng này. Các ca queue/cold-chain/security chưa đủ object là BLOCKED. Hai session concurrency dùng tests/60_concurrency_demo.sql sau khi seed/FIFO owner sẵn sàng.

## 8. Performance và execution plan

### 8.1 API p95 ≤500 ms

Chạy localhost trên DB thật, dataset large đã được xác minh. Ghi danh sách endpoint/role/query, phiên bản Node/SQL, SHA, hardware và tải. Warm-up 100 request mỗi endpoint; sau đó ≥1.000 request/endpoint, ít nhất ba lượt với cùng cấu hình. Bắt đầu 1 client và lặp với 5 client đồng thời; ghi cả kịch bản và tổng mẫu. Endpoint thuộc phạm vi: login, inventory catalog/stock/restock, tạo đơn/payment/dispense, IoT ingest/health, report KPI/growth/peak/location/ranking/cold-chain/export CSV.

Đo elapsed end-to-end HTTP, bao gồm app và SQL. Sắp mẫu tăng dần, p95 = mẫu thứ ceil(0.95*N) (nearest rank). Báo p50/p95/p99/max, throughput, timeout và error rate; từng endpoint p95 ≤500 ms, không dùng trung bình hoặc gộp endpoint nhanh để che endpoint chậm. Không bỏ mẫu chậm/lỗi khỏi file dữ liệu; lỗi/timeout ngoài lỗi nghiệp vụ chủ động phải bằng 0 trong workload hợp lệ. Báo kết quả từng lượt, không chỉ chọn lượt đẹp. PDF chưa có/endpoint thiếu ghi BLOCKED, không tự loại khỏi ma trận nghiệm thu.

### 8.2 Truy vấn report và index

Seed lớn 5.000 đơn/200.000 telemetry; kiểm raw/hourly sau backfill đúng hợp đồng. Các đối tượng: DashboardKpi, RevenueGrowth, PeakHours, ExportSales 30 ngày, RefreshDailySummary 90 ngày, RevenueByLocation, DispenseFailureRate, ProductRanking, ColdChainCompliance. Mục tiêu query warm <500 ms (nghiêm ngặt hơn ngân sách API ≤500 ms). Một lượt đầu báo riêng, 5 lượt warm ghi từng elapsed/CPU/logical reads và max. RunAllTests là điều phối tổng suite: báo runtime riêng, không xem là một truy vấn nghiệp vụ.

FV-31 / tests/70_perf_tests.sql (chưa có) phải lưu actual execution plan và STATISTICS TIME/IO trước/sau index với cùng seed, tham số, isolation và tải; hash query/SHA rõ. Index do owner bảng review, TV5 không tự tạo index trên sales/iot/inventory. Không DBCC DROPCLEANBUFFERS trên shared/production. Không ghi PASS khi chưa chạy hay dùng số đo 04/11 cho schema mới.

## 9. Quản lý lỗi và trách nhiệm

| Người | Trách nhiệm |
|---|---|
| Anh (QA/report) | Duy trì Test Plan, ma trận, bằng chứng unit/integration/performance và phân loại lỗi; không sửa trạng thái Jira trong tài liệu nhiệm vụ |
| Huy (Leader/inventory) | Xác nhận oracle kho/FIFO/TVP, review PR, quyết định mức chặn và merge |
| Toàn (auth/audit/FK/security) | Ca đăng nhập/quyền/RLS/backup; sửa FK và account DB |
| Ân (sales) | Ca đơn/thanh toán/idempotency/refund/concurrency; kiểm queue |
| Dũng (iot) | Machine mapping, telemetry/hours/minutes/gap, thresholds, offline và jobs |

Lỗi được tạo GitHub Issue gán chủ module sau khi xác nhận tài khoản GitHub; nếu chưa biết username thì ghi rõ tên owner, không gán nhầm. Mẫu: title [SCRUM-id][module] điều kiện gây lỗi; SHA/môi trường, tiền điều kiện, Input/Steps, Expected/Actual, mức Highest/High/Medium/Low, log/ảnh, ảnh hưởng và tiêu chí retest. Highest: mất/nhân tiền, tồn âm, lộ quyền, không cài DB; High: luồng lõi/report sai; Medium: lỗi có cách tránh; Low: trình bày. Mỗi fix phải retest ca lỗi và regression liên quan, liên kết Issue↔PR↔test ID. Jira cập nhật bởi người có kết nối/quyền, không giả tạo trạng thái đã cập nhật.

Owner cung cấp/xác nhận ca test theo task: gửi yêu cầu thu thập ngày 11/11, hạn 12/11 12h; kế hoạch đã dùng ca SQL/mock trong repo để chuẩn bị. Chưa gửi tin nhắn riêng hoặc giả xác nhận của owner. Huy duyệt ma trận trước chạy Sprint 2. Các Issue hiện hữu: #19 FK, #20 machine mapping, #21 duration.

## 10. Thực thi và lưu bằng chứng

```powershell
python tests/check_week1.py
powershell -NoProfile -File tests/run-tv5.ps1
powershell -NoProfile -File tests/run-tv5.ps1 -RequireIntegration
npm test --prefix app
python tools/build_test_matrix.py
python tools/build_testplan_docx.py
```

Report runner trả riêng PASS report và BLOCKED owner integration; -RequireIntegration là cổng nghiêm ngặt, có BLOCKED thì exit khác 0 sau lưu checks.json. Không chạy lại test chỉ để săn kết quả nhanh hơn nếu chưa đổi code/môi trường có lý do. tests/check_week1.py kiểm 30 procedure/90 ca, ≥3 ca/procedure, đủ module và bao phủ mọi definition hiện có. File Word sinh từ cùng nguồn TestPlan.md, ZIP/XML được xác thực; cần mở Word/LibreOffice review bố cục trước nộp.

Mỗi bản ghi kết quả: RunId/BatchId, test ID, module/procedure, Input/Expected/Actual, PASS/FAIL/BLOCKED/NOT RUN, error number, DurationMs, UTC timestamp, người chạy, SHA, log path hoặc link PR. SQL report dùng report.TestResults; chưa thực thi không insert Passed=1. Log cục bộ .local-test không commit secrets; bản tổng hợp/số liệu đã lọc trong docs và PR. Chụp màn hình SQL thật khi có SSMS; không tạo ảnh giả.

## 11. Lịch và nghiệm thu tài liệu

09/11 hoàn thiện SCRUM-209 và chuẩn bị chuẩn hóa file; 10/11 chốt QĐ-3/README; 11–12/11 thu/xác nhận case và duyệt SCRUM-211; Sprint 2 (13–19/11) unit/integration/performance; Sprint 3 (20–26/11) regression, security/restore và TestReport cuối.

SCRUM-211 đạt phần tài liệu khi có phạm vi/môi trường, 5 module × mỗi procedure ≥3 ca, ba loại test, entry/exit, lỗi, phân công và bằng chứng nguồn. Nghiệm thu dự án không đạt chỉ nhờ tài liệu đầy đủ: phải xử lý blocker, chạy thực tế, CI xanh và Huy review/merge. PR mỗi task riêng, không push main, không tự approve.

## 12. Ma trận unit chi tiết (tự sinh từ catalog)

Kế hoạch test, **không phải kết quả thực thi**. 30 procedure / 90 ca; 23 procedure có định nghĩa và 7 procedure chờ owner. Dữ liệu ký hiệu U/A/M/L/C/P/B/O/I/AL phải được resolve bằng khóa fixture, không hardcode ID của CSDL khác.

Tiền điều kiện: CSDL test riêng; Admin A, Operator U, Kiosk K; máy M, địa điểm L, ngăn C, sản phẩm P, lô B, đơn O, chi tiết I, alert AL theo từng trạng thái trong Input. Mỗi ca ghi baseline (tồn, tổng tiền, row count), gọi procedure đúng một lần hoặc số lần nêu rõ, đối chiếu Expected bằng SELECT độc lập và ERROR_NUMBER. Dọn fixture bằng rollback khi transaction còn hợp lệ; lỗi XACT_ABORT rollback toàn bộ thì dựng lại fixture cho ca sau.

Nguồn oracle: SQL chủ module + app/api/test/fakeDb.js + tests/tests_inventory.sql + tests/tests_sales.sql. Các case auth/Restock/RemoveExpired là kế hoạch từ hợp đồng mock, chưa có đủ implementation. Chưa nhận xác nhận trực tiếp từ bốn owner: cần Toàn/Huy/Ân/Dũng review Expected trước Sprint 2. Không giả nhận xét hoặc kết quả của thành viên khác.

### auth

| ID | Procedure / sẵn sàng | Input / bước gọi | Expected / oracle |
|---|---|---|---|
| UT-AUTH-01-OK | auth.sp_CreateUser (planned) | Username=qa_new, Password=QaPass123!, RoleName=Operator, FullName=QA | Tạo đúng 1 user, role đúng; mật khẩu không lưu plain text |
| UT-AUTH-01-ERR1 | auth.sp_CreateUser (planned) | Username=ab | 50001; không tạo user |
| UT-AUTH-01-ERR2 | auth.sp_CreateUser (planned) | Username=admin đã có | 50003; không tạo user trùng |
| UT-AUTH-02-OK | auth.sp_Login (planned) | Admin hoạt động + mật khẩu đúng; ClientInfo=QA | Success=1, đúng UserId/RoleName; reset failed count, ghi LoginActivity |
| UT-AUTH-02-ERR1 | auth.sp_Login (planned) | Mật khẩu sai 1 lần | Success=0, failed count +1, không trả quyền |
| UT-AUTH-02-ERR2 | auth.sp_Login (planned) | Sai liên tiếp 5 lần trên fixture riêng | Success=0, tài khoản khóa, lần sau không đăng nhập; không coi là exception 500xx |
| UT-AUTH-03-OK | auth.sp_ChangePassword (planned) | UserId=U hoạt động, OldPassword đúng, NewPassword=Different123! | Đổi salt/hash; mật khẩu cũ không đăng nhập được |
| UT-AUTH-03-ERR1 | auth.sp_ChangePassword (planned) | OldPassword sai | 50011; hash giữ nguyên |
| UT-AUTH-03-ERR2 | auth.sp_ChangePassword (planned) | NewPassword ngắn 7 ký tự | 50002; hash giữ nguyên |
| UT-AUTH-04-OK | auth.sp_AssignMachine (planned) | UserId=Operator U, MachineId=M có thật, Unassign=0 | Một assignment; gọi lại không trùng |
| UT-AUTH-04-ERR1 | auth.sp_AssignMachine (planned) | UserId=-1 | 50020; không assignment |
| UT-AUTH-04-ERR2 | auth.sp_AssignMachine (planned) | UserId=Admin | 50021; không giao máy cho Admin |
| UT-AUTH-05-OK | auth.sp_DeactivateUser (planned) | UserId=Operator U hoạt động, Activate=0; SESSION_CONTEXT UserId=Admin A | IsActive=0; phiên đăng nhập mới bị từ chối |
| UT-AUTH-05-ERR1 | auth.sp_DeactivateUser (planned) | UserId=-1 | 50030; không thay user khác |
| UT-AUTH-05-ERR2 | auth.sp_DeactivateUser (planned) | UserId=A, Activate=0, SESSION_CONTEXT UserId=A | 50031; không tự vô hiệu hóa |

### inventory

| ID | Procedure / sẵn sàng | Input / bước gọi | Expected / oracle |
|---|---|---|---|
| UT-INVENTORY-06-OK | inventory.sp_AddProduct (present) | ProductName=QA_NEW, Price=15000, ShelfLifeHours=24, Category=Trái cây cắt sẵn | Đúng ProductId, ProductName, Price; SKU duy nhất |
| UT-INVENTORY-06-ERR1 | inventory.sp_AddProduct (present) | Price=0 | 50102; không thêm sản phẩm |
| UT-INVENTORY-06-ERR2 | inventory.sp_AddProduct (present) | ProductName đã tồn tại | 50101; không thêm trùng |
| UT-INVENTORY-07-OK | inventory.sp_UpdateProduct (present) | ProductId=P, tên mới duy nhất, ShelfLifeHours=24, IsActive=1 | Đúng cột thay đổi, không sửa giá bằng đường vòng |
| UT-INVENTORY-07-ERR1 | inventory.sp_UpdateProduct (present) | ProductId=-1 | 50103; không update |
| UT-INVENTORY-07-ERR2 | inventory.sp_UpdateProduct (present) | ProductName trùng sản phẩm khác | 50101; không update |
| UT-INVENTORY-08-OK | inventory.sp_UpdatePrice (present) | ProductId=P, NewPrice khác giá cũ và >0, UpdatedBy=A | OldPrice/NewPrice đúng, temporal history thêm phiên bản |
| UT-INVENTORY-08-ERR1 | inventory.sp_UpdatePrice (present) | ProductId=-1 | 50103; không history mới |
| UT-INVENTORY-08-ERR2 | inventory.sp_UpdatePrice (present) | NewPrice bằng giá hiện tại | 50104; không update/history |
| UT-INVENTORY-09-OK | inventory.sp_AssignColumn (present) | ColumnId=C rỗng trên máy được giao, ProductId=P, UpdatedBy=U | ColumnId/ColumnNo đúng alias Slot; gán đúng sản phẩm |
| UT-INVENTORY-09-ERR1 | inventory.sp_AssignColumn (present) | ColumnId=-1 | 50105; không update |
| UT-INVENTORY-09-ERR2 | inventory.sp_AssignColumn (present) | Cột còn ít nhất một hộp | 50106; không đổi sản phẩm |
| UT-INVENTORY-10-OK | inventory.sp_AddBatch (present) | ProductId=P hoạt động, Quantity=20, PreparedAt UTC=T, Supplier=QA | ExpiryAt=T+ShelfLifeHours; BatchCode duy nhất |
| UT-INVENTORY-10-ERR1 | inventory.sp_AddBatch (present) | ProductId=-1 | 50107; không lô mới |
| UT-INVENTORY-10-ERR2 | inventory.sp_AddBatch (present) | Quantity=0 | 50113; không lô mới |
| UT-INVENTORY-11-OK | inventory.sp_Restock (planned) | MachineId=M được giao, UserId=U, Items TVP có C/B/Qty=2 hợp lệ, Note=QA | Tồn theo lô +2, phiếu/chi tiết/movement đủ, giao dịch atomic |
| UT-INVENTORY-11-ERR1 | inventory.sp_Restock (planned) | Items TVP rỗng | 50111; không đổi tồn/phiếu |
| UT-INVENTORY-11-ERR2 | inventory.sp_Restock (planned) | Qty làm vượt Capacity (kèm dòng trước hợp lệ) | 50117; rollback tất cả dòng, không nạp một phần |
| UT-INVENTORY-12-OK | inventory.sp_RemoveExpired (planned) | MachineId=M; có một lô hết hạn và một lô còn hạn | Chỉ rút lô hết hạn; trả RemovedLines/RemovedQty đúng |
| UT-INVENTORY-12-ERR1 | inventory.sp_RemoveExpired (planned) | MachineId=-1 | Không thay tồn, 0 dòng; nếu owner chốt mã lỗi mới thì cập nhật oracle trước chạy |
| UT-INVENTORY-12-ERR2 | inventory.sp_RemoveExpired (planned) | MachineId=M, không có lô hết hạn | 0 dòng/hộp, không xóa lô còn hạn (ca âm nghiệp vụ) |

### sales

| ID | Procedure / sẵn sàng | Input / bước gọi | Expected / oracle |
|---|---|---|---|
| UT-SALES-13-OK | sales.sp_CreateOrder (present) | MachineId=M ACTIVE, Items TVP ColumnId=C/Qty=1 còn tồn chưa hết hạn, CustomerId=NULL | PENDING, TotalAmount đúng, FIFO trừ tồn đúng lô, ExpiresAt +5 phút |
| UT-SALES-13-ERR1 | sales.sp_CreateOrder (present) | Items TVP rỗng | 50200; không đơn/tồn thay đổi |
| UT-SALES-13-ERR2 | sales.sp_CreateOrder (present) | Qty vượt tồn hợp lệ | 50201; toàn bộ rollback |
| UT-SALES-14-OK | sales.sp_ConfirmPayment (present) | OrderId=O PENDING chưa hết hạn, Method=VIETQR, GatewayTxnId=QA-UNIQUE, Amount đúng | PAID; một payment; callback y hệt lần hai IsDuplicate=1 |
| UT-SALES-14-ERR1 | sales.sp_ConfirmPayment (present) | Amount khác TotalAmount | 50208; chưa PAID, không payment mới |
| UT-SALES-14-ERR2 | sales.sp_ConfirmPayment (present) | O quá hạn 5 phút | 50207; không thu tiền thành công |
| UT-SALES-15-OK | sales.sp_RecordDispense (present) | OrderItemId=I thuộc PAID, Result=SUCCESS, ErrorCode=NULL | Ghi một DispenseEvents; toàn đơn nhả đủ → DISPENSED |
| UT-SALES-15-ERR1 | sales.sp_RecordDispense (present) | Result=UNKNOWN | 50211; không event |
| UT-SALES-15-ERR2 | sales.sp_RecordDispense (present) | OrderItemId=-1 | 50212; không event/hoàn tiền |
| UT-SALES-16-OK | sales.sp_Refund (present) | OrderId=O PAID chưa nhả, Reason=QA, RefundedBy=A | Đúng phần chưa nhả được hoàn; một Refund; tồn trả đúng |
| UT-SALES-16-ERR1 | sales.sp_Refund (present) | OrderId=-1 | 50216; không refund |
| UT-SALES-16-ERR2 | sales.sp_Refund (present) | OrderId của đơn PENDING | 50217; không refund |
| UT-SALES-17-OK | sales.sp_ExpirePendingOrders (present) | OrderId=O PENDING quá hạn; hoặc NULL cho batch | EXPIRED, trả tồn đúng; trả số đơn hết hạn |
| UT-SALES-17-ERR1 | sales.sp_ExpirePendingOrders (present) | OrderId của đơn PAID | Không đổi trạng thái hoặc tồn (ca âm trạng thái) |
| UT-SALES-17-ERR2 | sales.sp_ExpirePendingOrders (present) | OrderId đã EXPIRED | Không trả tồn hai lần; 0 thay đổi |

### iot

| ID | Procedure / sẵn sàng | Input / bước gọi | Expected / oracle |
|---|---|---|---|
| UT-IOT-18-OK | iot.sp_RegisterMachine (present) | Serial=QA-NEW, MachineName=QA, LocationId=L có thật, FirmwareVersion=1.0 | Máy ACTIVE + thresholds 2..8; không tạo bản sao inventory |
| UT-IOT-18-ERR1 | iot.sp_RegisterMachine (present) | Serial đã tồn tại | 50301; không máy/threshold mới |
| UT-IOT-18-ERR2 | iot.sp_RegisterMachine (present) | LocationId=-1 | 50302; không máy mới |
| UT-IOT-19-OK | iot.sp_IngestTelemetry (present) | Payload JSON array [{machineId:M,temp:4,hum:65,door:0}] | Một telemetry đúng M và dữ liệu, heartbeat UTC cập nhật |
| UT-IOT-19-ERR1 | iot.sp_IngestTelemetry (present) | Payload=not-json | 50310; không telemetry |
| UT-IOT-19-ERR2 | iot.sp_IngestTelemetry (present) | Payload machineId không tồn tại | 50311; không telemetry |
| UT-IOT-20-OK | iot.sp_AcknowledgeAlert (present) | AlertId=AL mở, UserId=A | AckBy/AckAt đúng, không tự resolve cảnh báo |
| UT-IOT-20-ERR1 | iot.sp_AcknowledgeAlert (present) | AlertId=-1 | 50320; không update |
| UT-IOT-20-ERR2 | iot.sp_AcknowledgeAlert (present) | AL đã acknowledge | 50321; không ghi đè AckBy |
| UT-IOT-21-OK | iot.sp_ClearFault (present) | MachineId=M FAULT, UserId=A, Note=QA | ACTIVE, đóng cảnh báo của máy, trả OldStatus/NewStatus |
| UT-IOT-21-ERR1 | iot.sp_ClearFault (present) | MachineId=-1 | 50330; không update |
| UT-IOT-21-ERR2 | iot.sp_ClearFault (present) | M đang ACTIVE | 50331; không tạo chuyển trạng thái giả |
| UT-IOT-22-OK | iot.sp_UpdateThreshold (present) | MachineId=M, MinTemp=2, MaxTemp=8, DoorOpenMaxMinutes=2, ConsecutiveBreaches=3, DegradedMessage=QA | Đúng một threshold và cột trả về |
| UT-IOT-22-ERR1 | iot.sp_UpdateThreshold (present) | MachineId=-1 | 50340; không update |
| UT-IOT-22-ERR2 | iot.sp_UpdateThreshold (present) | MinTemp=8, MaxTemp=2 | 50341; không update |
| UT-IOT-23-OK | iot.sp_CheckHeartbeat (present) | Minutes=5; M heartbeat 6 phút trước, M2 heartbeat 1 phút trước | Chỉ M OFFLINE, một cảnh báo mở, gọi lại không trùng |
| UT-IOT-23-ERR1 | iot.sp_CheckHeartbeat (present) | Thực thi bằng Kiosk sau 40_security | 229/permission denied, không thay máy; BLOCKED khi chưa có security |
| UT-IOT-23-ERR2 | iot.sp_CheckHeartbeat (present) | CSDL test READ_ONLY với máy cần update | 3906; không thay đổi trạng thái; dọn READ_WRITE trong finally |
| UT-IOT-24-OK | iot.sp_AggregateHourly (present) | Telemetry của giờ đang tổng hợp, nhiệt độ 2 và 8 và vượt ngưỡng | Hourly đúng min/max/avg/count, phút thật 0..60, upsert lặp không tăng |
| UT-IOT-24-ERR1 | iot.sp_AggregateHourly (present) | Thực thi bằng Operator sau 40_security | 229, không sửa hourly; BLOCKED khi chưa có security |
| UT-IOT-24-ERR2 | iot.sp_AggregateHourly (present) | CSDL test READ_ONLY với dữ liệu cần MERGE | 3906; không ghi một phần; khôi phục READ_WRITE trong finally |

### report

| ID | Procedure / sẵn sàng | Input / bước gọi | Expected / oracle |
|---|---|---|---|
| UT-REPORT-25-OK | report.sp_DashboardKpi (present) | AsOf=2026-11-03, MachineId=NULL | 3 result sets; net doanh thu PAID/DISPENSED, 14 ngày, top 5, máy ACTIVE |
| UT-REPORT-25-ERR1 | report.sp_DashboardKpi (present) | MachineId=-1 | 50401; không trả KPI giả |
| UT-REPORT-25-ERR2 | report.sp_DashboardKpi (present) | AsOf=9999-12-31 | 50401; không tràn ngày |
| UT-REPORT-26-OK | report.sp_RevenueGrowth (present) | Year=2026 | 12 tháng, QtySold/PrevRevenue đúng; LAG, running sum đúng |
| UT-REPORT-26-ERR1 | report.sp_RevenueGrowth (present) | Year=1999 | 50401 |
| UT-REPORT-26-ERR2 | report.sp_RevenueGrowth (present) | Year=9999 | 50401 |
| UT-REPORT-27-OK | report.sp_PeakHours (present) | From=2026-08-06, To=2026-11-03 | 24 hàng T2..CN; tổng đơn đúng; DATEFIRST 1/7 không đổi |
| UT-REPORT-27-ERR1 | report.sp_PeakHours (present) | From > To | 50401 |
| UT-REPORT-27-ERR2 | report.sp_PeakHours (present) | To=9999-12-31 | 50401 |
| UT-REPORT-28-OK | report.sp_ExportSales (present) | From/To hợp lệ, UserId có thật, LocationId=NULL, FileFormat=CSV | Audit rows PAID/DISPENSED/REFUNDED/DISPENSE_FAILED; Params JSON; log PENDING |
| UT-REPORT-28-ERR1 | report.sp_ExportSales (present) | From=NULL | 50402; không log |
| UT-REPORT-28-ERR2 | report.sp_ExportSales (present) | UserId=-1 | 50402; không log |
| UT-REPORT-29-OK | report.sp_RefreshDailySummary (present) | Date=2026-08-06, ToDate=2026-11-03 | Gross chi tiết, discount phân bổ, net đúng; lặp không nhân, refund loại summary cũ |
| UT-REPORT-29-ERR1 | report.sp_RefreshDailySummary (present) | Date > ToDate | 50403; không ghi |
| UT-REPORT-29-ERR2 | report.sp_RefreshDailySummary (present) | ToDate=9999-12-31 | 50403; không ghi |
| UT-REPORT-30-OK | report.sp_RunAllTests (present) | RunBy=QA, phiên test độc lập | 18 ca, đúng BatchId, kết thúc và ghi log thật; lỗi không biến PASS |
| UT-REPORT-30-ERR1 | report.sp_RunAllTests (present) | RunBy rỗng | 50404; không tạo kết quả |
| UT-REPORT-30-ERR2 | report.sp_RunAllTests (present) | RunBy dài 101 ký tự | 50404; không tạo kết quả |

### Ca bổ sung bắt buộc

- Multi-line có discount: fn_RevenueByLocation không nhân Order.TotalAmount theo số chi tiết. Ranking/summary dùng gross, NetRevenue trừ discount; không so net và gross tùy tiện.
- FailureRate: 0/50=0, 1/50=0.02 không đạt <2%, 1/100=0.01 đạt; retry JAM→SUCCESS đếm cả hai; không lần nhả NULL. Dựng nhiều OrderItem thay vì AttemptNo=100 (owner giới hạn 1..3).
- Cold-chain: ngưỡng 2/8 bao gồm biên, 8.01 ngoài; hourly có 30 phút ngoài trong 60 phút →50%; không hourly →NULL; dữ liệu phút -1/61/NULL không được trình bày thành tuân thủ hợp lệ. Raw→hourly chờ #21.
- RANK tie: hai sản phẩm cùng doanh thu cùng địa điểm phải cùng rank; reset fixture/location riêng tránh doanh thu nền làm mất tie.
- Export invalid date/user/location/format không ghi log; CSV quoting, formula injection, PDF rendering và xác nhận SUCCESS/FAILED thuộc lớp ứng dụng, chưa nghiệm thu bằng SELECT.
- Seed small/large độc lập và chạy lại; hiện phải báo BLOCKED #20 trước full seed, không tạo view/bảng thay owner trong test production.
- Upstream faults của procedure không có tham số là ca âm ngữ cảnh, không bịa tham số sai. Chỉ chạy READ_ONLY/DENY trên CSDL test riêng và luôn phục hồi trạng thái trong finally.
