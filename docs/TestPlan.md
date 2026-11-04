# Test Plan — FreshVend / TV5

Phiên bản 2.0 · SCRUM 34, 35, 37 · SQL Server 2022 (16.x), compatibility 160 · Nhánh tv5-report.

## 1. Mục tiêu và phạm vi

Xác nhận báo cáo Admin, dữ liệu mẫu toàn hệ thống và bốn đối tượng SCRUM 37. Khung kiểm thử chung bao phủ auth, inventory, sales, iot, report; bộ tự động kiểm tra procedure report hiện có. User Story là đặc tả sản phẩm, không đồng nghĩa mọi chức năng ứng dụng đã triển khai.

## 2. User Story Admin

| ID | User Story | Tiêu chí chấp nhận |
|---|---|---|
| US-ADM-01 | Là Admin, tôi muốn xem doanh thu theo sản phẩm để biết đóng góp của từng sản phẩm. | Chỉ cộng đơn paid, loại pending/cancelled/refunded. Hiển thị QtySold, Revenue và hạng trong địa điểm. Cùng doanh thu cùng hạng, hạng sau bỏ số. Có trạng thái không dữ liệu. |
| US-ADM-02 | Là Admin, tôi muốn lọc doanh thu theo địa điểm và khoảng ngày để so sánh điểm đặt máy. | Ngày bao gồm hai đầu theo UTC+7. Tổng bằng tổng chi tiết đơn tương ứng. From>To bị từ chối tại lớp gọi; TVF trả rỗng. Địa điểm không có doanh thu không có dòng trong TVF. |
| US-ADM-03 | Là Admin, tôi muốn xem giờ cao điểm để bố trí bổ sung hàng. | 24 giờ và ma trận T2–CN độc lập DATEFIRST. Seed lớn tập trung 7–9h, 11–13h, 17–19h (không gồm biên phải). |
| US-ADM-04 | Là Admin, tôi muốn xuất CSV để phân tích trên bảng tính. | UTF-8, tiêu đề cột, escape dấu phẩy/nháy/xuống dòng, chống công thức bảng tính tại lớp xuất. Nội dung khớp bộ lọc; từ chối người không quyền; log UserId, Params JSON, FileFormat=CSV. |
| US-ADM-05 | Là Admin, tôi muốn xuất PDF để chia sẻ báo cáo. | PDF mở được, có tiêu đề/ngày/địa điểm/tổng tiền, phân trang không mất dòng. Log FileFormat=PDF. SQL chuẩn bị dữ liệu và ghi PENDING; ứng dụng xác nhận SUCCESS/FAILED sau tạo file. |
| US-ADM-06 | Là Admin, tôi muốn giám sát toàn đội máy để phát hiện máy offline, kẹt và vi phạm chuỗi lạnh. | Bao gồm máy không có đơn/telemetry; hiển thị trạng thái và cảnh báo. Tỷ lệ JAM/tổng lần nhả <0.02 mới đạt; đúng 0.02 không đạt. Nhiệt độ 2 và 8°C hợp lệ. Không dữ liệu hiển thị chưa xác định. |

## 3. Oracle và quy ước

- Lưu UTC, kinh doanh UTC+7; From/To là ngày bao gồm hai đầu, khoảng UTC [From-7h, To+17h).
- Revenue là doanh thu gộp chi tiết đơn paid: SUM(Quantity*UnitPrice). NetRevenue trừ chiết khấu phân bổ. Không đối chiếu gộp với thuần.
- fn_DispenseFailureRate trả tỷ lệ 0..1; máy lạ hoặc không có lần nhả trả NULL. Đếm mỗi lần nhả vật lý kể cả retry.
- ColdChainCompliance = 100*InRangeSeconds/MonitoredSeconds, đọc bảng tiền tổng hợp iot.TelemetryHourly; gọi report.sp_RefreshTelemetryHourly theo ngày UTC sau khi ingest hoặc sửa/xóa raw telemetry. Seed tự refresh. View hiển thị toàn bộ lịch sử đã tổng hợp, không mặc định 30 ngày. Không suy diễn khoảng mất dữ liệu là hợp lệ. Gói phải có nhiệt độ và durationSeconds (1..300); khoảng quan sát trên cùng thiết bị không chồng nhau.
- Giữ tên bảng cũ TV1–TV4 để tương thích. Bảng bổ sung dùng số nhiều; DailySalesSummary và TelemetryHourly giữ tên theo yêu cầu.

## 4. Môi trường và dữ liệu

SQL Server 2022, compatibility 160, Vietnamese_CI_AS; sqlcmd -I để bật QUOTED_IDENTIFIER. Chạy trên CSDL test riêng với quyền tạo cấu trúc và ghi fixture; không chạy suite ghi dữ liệu trên production.

Small: 3 địa điểm, 5 máy, 10 sản phẩm, 50 đơn (mỗi đơn 1 chi tiết và 1 payment), 500 telemetry. Large: tổng fixture TV5 20 máy, 15 sản phẩm, 5.000 đơn trong 90 ngày, 200.000 telemetry. Chung mã TV5- nên small→large đạt tổng large. Giữ dữ liệu người khác; kiểm tra số lượng theo fixture. Cửa sổ cố định 06/08/2026–03/11/2026 để tái lập. User seed bị vô hiệu hóa, không chứa mật khẩu thật.

Thứ tự: 00_database → 01_schemas → 02_tables_auth/inventory/sales/iot/report → 03_foreign_keys → 04_report_dependencies → 24_objects_report → 07_procs_report → 05_seed_small. 06_seed_large chạy sau cùng. Các entry point 09_seed đã nghỉ sử dụng.

## 5. Unit: mỗi procedure một ca đúng và hai ca sai

| Procedure hiện có | Ca đúng | Ca sai 1 | Ca sai 2 |
|---|---|---|---|
| report.sp_DashboardKpi | AsOf=2026-11-03; 3 tập kết quả, KPI không nhân theo lần nhả | MachineId=-1 → 50401 | AsOf=9999-12-31 → 50401 |
| report.sp_RevenueGrowth | Year=2026; 12 tháng, tổng tiền đúng | Year=1999 → 50401 | Year=9999 → 50401 |
| report.sp_PeakHours | 90 ngày; 24 hàng, tổng bằng đơn paid | From>To → 50401 | To=9999-12-31 → 50401 |
| report.sp_ExportSales | Ngày/user hợp lệ; đúng dòng và log PENDING | From=NULL → 50402 | UserId=-1 → 50402 |
| report.sp_RefreshDailySummary | Tổng paid khớp, chạy lại không đổi | Date>ToDate → 50403 | ToDate=9999-12-31 → 50403 |
| report.sp_RefreshTelemetryHourly | Một ngày UTC hợp lệ; dữ liệu hourly khớp raw | From=NULL → 50405 | From>To → 50405 |
| report.sp_RunAllTests | Kết thúc suite, ghi đủ kết quả cùng BatchId | RunBy rỗng → 50404 | RunBy dài 101 ký tự → 50404 |

sp_RunAllTests chạy 20 ca con và ghi ca hoàn tất runner; tests/sql/37_verify_report.sql kiểm tra ngữ nghĩa sâu. Lỗi ngoài dự kiến phải FAIL; không đánh PASS trong CATCH. Expected error phải đúng số.

Khung cho procedure thành viên khác chưa có định nghĩa trong repo: mỗi procedure khi merge cần ba ca cụ thể, gồm ID, tiền điều kiện, Input, Steps, Expected, Actual, Passed, DurationMs, người chạy và bằng chứng. Chưa có procedure thì ghi BLOCKED, không đánh PASS.

| Nhóm procedure dự kiến | Ca đúng | Ca sai 1 | Ca sai 2 |
|---|---|---|---|
| auth: CreateUser, Login, ChangePassword, AssignMachine, DeactivateUser | Dữ liệu và quyền hợp lệ | Trùng hoặc không tồn tại định danh | Dữ liệu hoặc quyền sai |
| inventory: Add/UpdateProduct, UpdatePrice, AssignColumn, AddBatch, Restock, RemoveExpired | Ghi đúng tồn/giá/lịch sử | FK không tồn tại | Giá âm, vượt sức chứa hoặc hạn sai theo procedure |
| sales: CreateOrder, ConfirmPayment, RecordDispense, Refund, ExpirePendingOrders | Mua→trả tiền→nhả/hoàn/hết hạn | Đơn/chi tiết không tồn tại | Vượt tồn hoặc chuyển trạng thái sai |
| iot: RegisterMachine, IngestTelemetry, AcknowledgeAlert, ClearFault, UpdateThreshold, CheckHeartbeat, AggregateHourly | Ghi/aggregate/cảnh báo đúng | Máy/cảnh báo không tồn tại | JSON/ngưỡng/khoảng ngày sai |

Khi TV1–TV4 merge: lấy danh sách sys.procedures, đối chiếu đủ 3 ca/procedure, chốt Expected theo hợp đồng chủ module. Không tự gán 504xx cho lỗi module khác.

## 6. Kiểm thử function, view và seed

| ID | Kịch bản | Expected |
|---|---|---|
| OBJ-01 | Revenue đủ 90 ngày, ngày rỗng, khoảng đảo | Khớp chi tiết; rỗng; rỗng |
| OBJ-02 | FailureRate có JAM, không lần nhả, máy lạ | Đúng phân số; NULL; NULL |
| OBJ-03 | Ranking doanh thu khác nhau và bằng nhau | Giảm dần; đồng doanh thu đồng hạng |
| OBJ-04 | 2°C/30s, 8°C/90s, 8.001°C/120s | Coverage 240s, hợp lệ 120s, compliance 50% |
| OBJ-05 | JSON lỗi, thiếu duration, không telemetry | Không cộng coverage; máy không dữ liệu trả NULL |
| OBJ-06 | paid→refunded rồi refresh | Xóa doanh thu summary cũ |
| DATA-01 | Small→small | 3/5/10/50; tiền và liên kết khớp; không nhân summary |
| DATA-02 | Small→large→large | 20/15/5000/200000; đủ 90 ngày; đúng giờ; không trùng |
| DATA-03 | Large trên CSDL sạch | Cùng tổng fixture, không phụ thuộc small |

## 7. Integration end-to-end

| ID | Các bước | Expected |
|---|---|---|
| INT-01 | Seed → đơn paid → chi tiết/payment/lần nhả → refresh → TVF/ranking → export rows/log | FK đúng; tiền/số lượng/bộ lọc nhất quán; Params là JSON hợp lệ |
| INT-02 | paid → refunded → refresh → báo cáo | Loại doanh thu hoàn; không còn summary cũ |
| INT-03 | Telemetry → hourly → compliance → dashboard | 2/8°C hợp lệ; tính theo thời gian; không nhân số liệu bán hàng |
| INT-04 | Admin đăng nhập → lọc → xuất CSV/PDF → mở file → xem log | Đúng quyền và định dạng; SUCCESS chỉ khi tạo file; lỗi ghi FAILED |
| INT-05 | Operator/Viewer gọi chức năng Admin | Bị từ chối tại API và quyền DB theo cấu hình auth |
| INT-06 | Tạo đơn → callback thanh toán lặp → kẹt/retry → hoàn → báo cáo | Không thu/hoàn lặp; tồn đúng; failure rate đếm từng lần nhả |

INT-01–03 có kiểm tra SQL tự động. INT-04–06 cần chạy sau khi module ứng dụng/TV1–TV4 sẵn sàng; thiếu thì BLOCKED, không giả lập PASS.

## 8. Hiệu năng: nghiêm ngặt <500 ms

Large dataset, CSDL test riêng. Ghi phiên bản SQL, CPU/RAM, ngày chạy và số dòng. Đo elapsed time phía SQL cho từng procedure nghiệp vụ, hai function và hai view; sp_RefreshTelemetryHourly đo cập nhật một ngày (job định kỳ), sp_RefreshDailySummary đo 90 ngày. sp_RunAllTests là bộ điều phối toàn suite nên chỉ ghi thời gian tham khảo, không áp ngưỡng một yêu cầu nghiệp vụ cho tổng thời gian toàn suite; không đồng nhất thời gian tải file qua mạng. Warm-up một lần rồi đo năm lần, ghi từng lần và max. PASS khi mọi lần <500 ms; không dùng CPU time thay elapsed time. Ghi riêng cold run, cache và tải đồng thời.

Nếu vượt: lưu FAIL, xem plan/IO, sửa index hoặc tiền tổng hợp, đo lại cùng điều kiện. Không dùng dữ liệu seed PASS làm bằng chứng. Hai phiên refresh/export cạnh tranh và end-to-end API là bước nghiệm thu môi trường triển khai.

## 9. Chạy và tiêu chí kết thúc

Chạy powershell -NoProfile -File tests/run-tv5.ps1. Script tạo FreshVendTV5_Test_timestamp và giữ lại để review; log ở .local-test/tv5. Test sai phải dừng khác 0. TestResults chỉ ghi khi thực thi thật.

SCRUM 34: đủ User Story, khung unit/integration/performance và TestPlan.docx. SCRUM 35: small/large và chạy lại đạt dữ liệu. SCRUM 37: đủ hai function/hai view, schema và oracle đúng. Toàn hệ thống còn phụ thuộc ca ứng dụng và procedure thành viên khác.

PR từ tv5-report, mỗi sản phẩm SQL riêng, không FULL; cần ít nhất một bạn review. TestReport chỉ ghi kết quả thực tế, phân biệt BLOCKED/NOT RUN.
