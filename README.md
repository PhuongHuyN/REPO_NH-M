# FreshVend — SQL Server 2022

Hệ thống máy bán trái cây tự động: auth, inventory, sales, iot, audit và report.

| Thành viên | MSSV |
|---|---|
| Nguyễn Phạm Xuân Anh | 089306017838 |
| Đoàn Phương Thiên Ân | 079306092350 |
| Nguyễn Phương Huy | 054206004278 |
| Huỳnh Nhật Toàn | 051206007163 |
| Trương Tuấn Dũng (TV5) | 079206042161 |

## TV5 — SCRUM 34, 35, 37

| Sản phẩm | File |
|---|---|
| User Story Admin và khung kiểm thử | docs/TestPlan.docx (nguồn docs/TestPlan.md) |
| Ba bảng report | sql/02_tables_report.sql |
| Seed nhỏ | sql/05_seed_small.sql |
| Seed lớn | sql/06_seed_large.sql |
| Hai function và hai view | sql/24_objects_report.sql |
| Hợp đồng dữ liệu phụ thuộc | sql/04_report_dependencies.sql |
| Procedure báo cáo và runner | sql/07_procs_report.sql |
| Kiểm thử SQL và hiệu năng | tests/run-tv5.ps1, tests/sql/ |
| Kết quả chạy thực tế | docs/TestReport.md |

## Thứ tự chạy

SQL Server 2022, compatibility level 160, Vietnamese_CI_AS. SSMS dùng QUOTED_IDENTIFIER ON; sqlcmd dùng -I -b để bật thiết lập này và dừng khi lỗi.

1. sql/00_database.sql, sql/01_schemas.sql.
2. sql/02_tables_auth.sql, sql/02_tables_inventory.sql, sql/02_tables_sales.sql, sql/02_tables_iot.sql, sql/02_tables_report.sql.
3. sql/03_foreign_keys.sql, sql/04_report_dependencies.sql.
4. sql/24_objects_report.sql, sql/07_procs_report.sql.
5. sql/05_seed_small.sql; sau khi chốt cấu trúc và cần đo hiệu năng, chạy sql/06_seed_large.sql sau cùng.

Không chạy theo thứ tự tên file toàn thư mục: số 05/06 là tên sản phẩm được giao, các phụ thuộc 24 và 07 phải tạo trước khi gọi logic. File 05_views_report/06_functions_report là thông báo chuyển vị trí; 09_seed_small/large dừng bằng lỗi hướng dẫn để ngăn chạy nhầm seed cũ.

Small có 3 địa điểm, 5 máy, 10 sản phẩm, 50 đơn. Large độc lập có 20 máy, 15 sản phẩm, 5.000 đơn, 200.000 telemetry trong cửa sổ cố định 06/08/2026–03/11/2026. Hai profile chung mã TV5-; small→large vẫn đạt tổng large, không cộng thêm 50 đơn. Chạy lại không tăng dữ liệu hoặc doanh thu. Người dùng mẫu bị vô hiệu hóa, không dùng đăng nhập thật; owner auth cấp tài khoản demo khi tích hợp ứng dụng.

## Kiểm thử

```powershell
powershell -NoProfile -File tests/run-tv5.ps1
```

Tạo CSDL FreshVendTV5_Test_timestamp riêng, giữ lại để review; log tại .local-test/tv5 (không commit). Kết nối mặc định .\SQLEXPRESS, có thể truyền -Server. Bộ test chạy seed hai lần, đối chiếu dữ liệu và biên function/view, kiểm tra unit procedure, đo hiệu năng warm-up + 5 lượt với ngưỡng nghiêm ngặt <500 ms. Không chạy runner ghi dữ liệu trên production.

```sql
EXEC report.sp_RunAllTests;
SELECT * FROM report.vw_LatestTestRun ORDER BY TestId;
SELECT * FROM report.fn_RevenueByLocation('20260806','20261103');
SELECT report.fn_DispenseFailureRate(1); -- tỷ lệ 0..1, NULL khi không có lần nhả
```

Tạo lại tài liệu Word: python tools/build_testplan_docx.py. Sinh lại hai seed từ cùng nguồn: python tools/complete_tv5.py. Không tạo file FULL.

## Hợp đồng với các module khác

Giữ nguyên tên bảng số ít đã có của TV1–TV4. Script 04 bổ sung inventory.Locations, Machine.LocationId, sales.DispenseAttempts và iot.TelemetryHourly để report có nguồn chuẩn. TelemetryHourly là bảng tiền tổng hợp theo giờ, cập nhật bằng report.sp_RefreshTelemetryHourly theo ngày UTC sau ingest; seed tự refresh. Nhiệt độ và thời lượng được phân tích một lần bằng computed columns persisted; 2–8°C bao gồm hai biên, không tự coi mất dữ liệu là tuân thủ. Gói tin cần t và durationSeconds; thời lượng 1..300 giây, các khoảng cùng thiết bị không chồng nhau. Đọc coverage cùng compliance khi đánh giá.

Revenue là tổng giá dòng đơn paid, chưa trừ chiết khấu; NetRevenue ở summary có trừ chiết khấu phân bổ. FailureRate tính JAM/tổng lần nhả vật lý, kể cả retry. SQL export chuẩn bị dữ liệu, log PENDING; việc tạo file CSV/PDF và cập nhật SUCCESS/FAILED thuộc ứng dụng.

03_foreign_keys bỏ qua audit.AuditLog/ChangeLog và MachineStockSnapshot khi các bảng này chưa được module chủ cung cấp. Không giả tạo các bảng ngoài phạm vi TV5. Các ca login/quyền, nghiệp vụ TV1–TV4 và PDF ứng dụng được ghi riêng trong TestPlan; kết quả mock không thay kiểm thử SQL thật.

## Quy ước nhóm

Nhánh tv5-report, không push main; PR cần ít nhất một bạn review. TV5 THROW 50400–50499. SQL object dùng CREATE OR ALTER; bảng dùng IF OBJECT_ID IS NULL để giữ dữ liệu. Procedure ghi: NOCOUNT, XACT_ABORT, TRY, kiểm tra, transaction, COMMIT, CATCH rollback và THROW. Bảng mới PascalCase số nhiều (ngoại lệ tên giao việc), sp_<ĐộngTừ><ĐốiTượng>, fn_, trg_<Bảng><MụcĐích>, vw_, IX_<Bảng>_<Cột>, <Tên>Type. Mỗi sản phẩm SQL một file riêng.
