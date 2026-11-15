# FreshVend — SQL Server 2022

Hệ thống máy bán trái cây tự động. Nhiệm vụ và quyết định kỹ thuật: NHIEM_VU_CHI_TIET/MASTER_PLAN.md.

## Nhóm thực hiện

| Thành viên | MSSV | Phụ trách |
|---|---|---|
| Nguyễn Phạm Xuân Anh | 089306017838 | TV5 — report, QA, Test Plan/Report |
| Đoàn Phương Thiên Ân | 079306092350 | TV3 — sales, kiosk, Docker |
| Nguyễn Phương Huy | 054206004278 | Leader, TV2 — inventory, review/tích hợp |
| Huỳnh Nhật Toàn | 051206007163 | TV1 — auth/audit, FK, security, backup |
| Trương Tuấn Dũng | 079206042161 | TV4 — iot, máy/địa điểm, telemetry, jobs |

## Thứ tự SQL theo QĐ-3

Yêu cầu SQL Server 2022, compatibility 160, Vietnamese_CI_AS; SSMS QUOTED_IDENTIFIER ON hoặc sqlcmd -I -b. Không chạy theo thứ tự chữ cái toàn thư mục. Mọi file là script riêng, không tạo FULL.

| Thứ tự | File | Chủ module | Hiện trạng 09/11/2026 |
|---|---|---|---|
| 1 | sql/00_database.sql | Toàn | Có; chỉ khởi tạo CSDL chủ động, có thao tác ROLLBACK IMMEDIATE |
| 2 | sql/01_schemas.sql | Toàn | Có |
| 3 | sql/02_tables_audit.sql | Huy | Có: audit.ChangeLog, audit.AuditLog (FV-06) |
| 4 | sql/02_tables_auth.sql | Toàn | Có, còn FV-06 |
| 5 | sql/02_tables_inventory.sql | Huy | Có |
| 6 | sql/02_tables_iot.sql | Dũng | Có; chưa view inventory.Machine, FV-13 |
| 7 | sql/02_tables_report.sql | Anh | Có, chỉ cấu trúc report |
| 8 | sql/02_tables_sales.sql | Ân | Có |
| 9 | sql/03_foreign_keys.sql | Toàn | Có nhưng đang BLOCKED, Issue #19 |
| 9a | sql/08_seed_inventory.sql | Huy | Có, danh mục/tồn kho vận hành; trước 12 và 80/81 |
| 10 | sql/10_procs_auth.sql | Ân | Có: sp_Login + 4 procedure auth, fn_HashPassword, seed admin/operator/kiosk (FV-08) |
| 11 | sql/11_procs_inventory.sql | Huy | Có 7 procedure (gồm sp_Restock, sp_RemoveExpired – FV-04) |
| 12 | sql/12_procs_sales.sql | Ân | Có |
| 13 | sql/13_procs_iot.sql | Dũng | Có |
| 14 | sql/14_procs_report.sql | Anh | Có 6 procedure; tạo trước object, chạy sau 24 |
| 15 | sql/20_objects_auth.sql | Huy | Có: vw_UserPermissions, audit.vw_LoginActivity, trigger trg_Users_Audit (FV-21); chạy sau 10; test: tests/tests_audit.sql |
| 16 | sql/21_objects_inventory.sql | Huy | Có: 4 view, fn_PriceHistory, fn_GetFifoStock, trigger sắp hết hàng (FV-18); chạy sau 02_tables_iot |
| 17 | sql/22_objects_sales.sql | Ân | Có |
| 18 | sql/23_objects_iot.sql | Dũng | Có |
| 19 | sql/24_objects_report.sql | Anh | Có, gồm function/view, không còn file 05/06 trùng |
| 20 | sql/30_index_<module>.sql | Từng chủ module | Chưa có; TV5 không tự tạo index trên schema khác |
| 20a | sql/30_index_inventory.sql | Huy | Có: 9 index inventory (FV-19); chạy sau 02_tables_inventory |
| 21 | sql/40_security.sql | Huy | Có: 4 login app, 4 role, GRANT/DENY theo ALLOW, RLS máy được giao (FV-22); chạy SAU CÙNG, cần Mixed Mode; test: tests/tests_security.sql |
| 22 | sql/45_jobs.sql | Dũng | Chưa có, FV-28 |
| 23 | sql/50_backup.sql | Toàn | Chưa có, FV-23 |
| 24 | sql/80_seed_small.sql, sql/81_seed_large.sql | Anh | Một bộ seed; chỉ chạy sau hợp nhất máy (#20) |
| 25 | tests/tests_<module>.sql, tests/60_concurrency_demo.sql, tests/70_perf_tests.sql | Từng chủ module | inventory/sales/concurrency có; các phần khác chờ Sprint 2–3 |
| 26 | 99_run_all.bat | Toàn | Chưa có, FV-23; không hướng dẫn chạy file chưa tồn tại |

Các mục chưa có là kế hoạch của MASTER_PLAN, không phải sản phẩm đã bàn giao. File 03 hiện lỗi iot.Device/iot.Alert cũ; full install chưa đạt. Không bỏ qua lỗi này rồi coi hệ thống đã cài thành công. Issue: [#19 FK](https://github.com/PhuongHuyN/REPO_NH-M/issues/19), [#20 hợp nhất máy](https://github.com/PhuongHuyN/REPO_NH-M/issues/20), [#21 phút ngoài ngưỡng](https://github.com/PhuongHuyN/REPO_NH-M/issues/21).

## Seed và hợp đồng dữ liệu

80_seed_small: fixture TV5 3 địa điểm, 5 máy, 10 sản phẩm, 50 đơn, 500 telemetry. 81_seed_large: tổng fixture TV5 20 máy, 15 sản phẩm, 5.000 đơn trong 90 ngày và 200.000 telemetry. Cùng mã TV5- nên small→large không thành 5.050 đơn. Số lượng là fixture sở hữu TV5, không xóa danh mục 36 sản phẩm của Huy hoặc dữ liệu khác.

Cửa sổ lịch sử cố định [06/08/2026,04/11/2026), ngày/giờ bán theo UTC+7, giờ cao điểm 7–9h / 11–13h / 17–19h. Seed dùng GENERATE_SERIES và hash ngẫu nhiên, không vòng lặp. Chạy lại không cộng doanh thu lần nữa. Tài khoản fixture không đăng nhập thật. Dữ liệu bán hàng lịch sử phục vụ report; dữ liệu FIFO/châm hàng vận hành đến từ 08_seed_inventory, không coi seed report là kiểm thử nghiệp vụ kho.

Seed dừng 50400 nếu chưa có inventory.Machine view theo QĐ-1. Không tự tạo bảng máy thay thế. iot.TelemetryHourly do Dũng cung cấp; TV5 không tự ước lượng phút từ số mẫu thưa để làm compliance đẹp. Historical hourly backfill cần hợp đồng #21, sẽ được nghiệm thu ở FV-30.

Report đọc iot.Machines, iot.Locations, sales.DispenseEvents, iot.TelemetryHourly. KPI/TVF dùng doanh thu thuần Order.TotalAmount của PAID/DISPENSED; ranking/summary tổng hợp dòng gộp và summary có NetRevenue trừ giảm giá. Audit export gồm PAID/DISPENSED/REFUNDED/DISPENSE_FAILED theo fakeDb. Params là JSON, trạng thái PENDING đến khi ứng dụng xác nhận file đã tạo. Phần trăm kẹt dùng hàm tỷ lệ 0..1; chưa có lần nhả trả NULL. Không bịa coverage chuỗi lạnh khi owner gửi phút ngoài 0..60.

## Kiểm thử hiện tại

```powershell
powershell -NoProfile -File tests/run-tv5.ps1
npm test --prefix app
python tests/check_week1.py
```

Runner tạo FreshVendTV5_Week1_timestamp, giữ CSDL và log trong .local-test/tv5-week1. Report acceptance và integration là hai trạng thái riêng: report có 18 ca, còn file FK chung lỗi thì ghi BLOCKED. Fixture bridge MachineId chỉ nằm trong CSDL test; không dùng làm giải pháp migration. Bằng chứng mới: docs/Week1_Anh_Validation.md; TestReport cũ có số đo 04/11 là lịch sử schema cũ.

Test Plan tổng: docs/TestPlan.md, docs/TestPlan.docx. Sinh Word: python tools/build_testplan_docx.py. Sinh lại seed: python tools/complete_tv5.py. Phạm vi triển khai ứng dụng xem app/README.md; test mock không thay cho SQL thật.

## Quy trình Git

Mỗi task nhánh riêng theo NHIEM_VU_CHI_TIET/Cach_su_dung_GITHUB.md; nhánh TV5 cũ giữ cho SCRUM-209, SCRUM-210 dùng chore/SCRUM-210-thu-tu-file, SCRUM-211 dùng docs/SCRUM-211-test-plan. Không push main. PR cần Huy review, CI xanh và xử lý phụ thuộc trước merge; không tự approve. TV5 THROW 50400–50499; procedure ghi dùng NOCOUNT, XACT_ABORT, TRY/kiểm tra/transaction/COMMIT/CATCH rollback/THROW. FK chéo schema chỉ do Toàn quản lý trong 03_foreign_keys.sql.
