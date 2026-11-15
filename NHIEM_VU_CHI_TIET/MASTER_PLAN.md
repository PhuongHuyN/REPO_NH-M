# MASTER_PLAN – Kế hoạch 21 ngày FreshVend

- **Thời gian:** 06/11/2026 → 26/11/2026 (21 ngày, 3 Sprint × 7 ngày)
- **Leader / người chịu trách nhiệm tích hợp cuối cùng:** Nguyễn Phương Huy
- **Nguồn phân tích:** `PROJECT_ANALYSIS.md`
- **Họp nhanh:** 21h mỗi tối (15 phút, online) – mỗi người: hôm qua làm gì, hôm nay làm gì, đang vướng gì. Cuối mỗi Sprint: demo nội bộ 30 phút.

## Quyết định kỹ thuật cần chốt ở FV-01 (họp 06/11)

| Mã | Vấn đề | Đề xuất | Lý do | Trạng thái |
|---|---|---|---|---|
| QĐ-1 | Hai bảng máy `inventory.Machine` và `iot.Machines` | Dùng **`iot.Machines` + `iot.Locations`** làm bảng duy nhất; `inventory.Machine` đổi thành **view** cùng tên cột cũ (FV-13) | `iot.Machines` đã có Serial, LocationId, Status, LastHeartbeat đúng như API; view giúp code TV3/TV5 không phải sửa | Chờ chốt |
| QĐ-2 | Ngăn hàng: SQL dùng `Slot/SlotId/SlotCode`, API dùng `Column/ColumnId/ColumnNo` | **Giữ tên bảng/cột `Slot` trong SQL**, đổi tên bằng bí danh trong view/procedure (`SlotId AS ColumnId`); `ColumnNo` = số thứ tự ngăn | Không phá code TV3 đã viết; API không phải sửa | Chờ chốt |
| QĐ-3 | Số thứ tự file trùng | Theo bảng *Thứ tự chạy file SQL* bên dưới (10–14 procedure, 20–24 object, 30 index, 40 security, 45 jobs, 50 backup, 80–81 seed) | Mỗi module 1 số riêng, không đụng file nhau | Chờ chốt |
| QĐ-4 | Mã lỗi | TV1 50001–50099, TV2 50100–50199, TV3 50200–50299, TV4 50300–50399, TV5 50400–50499; câu thông báo tiếng Việt copy từ `fakeDb.js` | Đã dùng sẵn trong `app/api/src/lib/errors.js` | Đã có |
| QĐ-5 | Quy tắc chung | FK chéo schema chỉ đặt ở `03_foreign_keys.sql`; mọi script dùng `CREATE OR ALTER`/`IF NOT EXISTS` để chạy lại được; không tạo bảng của schema khác | Tránh xung đột và lỗi thứ tự | Đã có |

## Thứ tự chạy file SQL (chuẩn sau QĐ-3)

| # | File | Người phụ trách | Hiện trạng |
|---|---|---|---|
| 1 | `00_database.sql` | TV1 Toàn | Có |
| 2 | `01_schemas.sql` | TV1 Toàn | Có |
| 3 | `02_tables_audit.sql` | TV1 Toàn | Chưa – FV-06 |
| 4 | `02_tables_auth.sql` | TV1 Toàn | Có, cần sửa – FV-06 |
| 5 | `02_tables_inventory.sql` | TV2 Huy | Có, cần sửa – FV-02 |
| 6 | `02_tables_iot.sql` | TV4 Dũng | Có – FV-13 thêm view tương thích |
| 7 | `02_tables_report.sql` | TV5 Anh | Có |
| 8 | `02_tables_sales.sql` | TV3 Ân | Có |
| 9 | `03_foreign_keys.sql` | TV1 Toàn | Có, đang lỗi – FV-07 |
| 9a | `08_seed_inventory.sql` (danh mục 36 sản phẩm, 5 máy × 12 ngăn, lô, tồn theo lô) | TV2 Huy | Mới – FV-02; chạy trước `12_procs_sales.sql` và seed 80/81 |
| 10 | `10_procs_auth.sql` | TV1 Toàn | Chưa – FV-08 |
| 11 | `11_procs_inventory.sql` | TV2 Huy | Chưa – FV-03, FV-04 |
| 12 | `12_procs_sales.sql` | TV3 Ân | Có |
| 13 | `13_procs_iot.sql` | TV4 Dũng | Đổi tên từ 07_procs_iot.sql – FV-12 |
| 14 | `14_procs_report.sql` | TV5 Anh | Đổi tên từ 07_procs_report.sql – FV-16 |
| 15 | `20_objects_auth.sql` | TV1 Toàn | Chưa – FV-21 |
| 16 | `21_objects_inventory.sql` | TV2 Huy | Chưa – FV-18 |
| 17 | `22_objects_sales.sql` | TV3 Ân | Trên nhánh tv3-sales – FV-09, FV-10 |
| 18 | `23_objects_iot.sql` | TV4 Dũng | Gộp 04_functions_iot + 05_views_iot – FV-12, FV-14 |
| 19 | `24_objects_report.sql` | TV5 Anh | Trên nhánh TV5 – FV-15 |
| 20 | `30_index_inventory.sql (và 30_index_<module>.sql)` | Mỗi TV | Chưa |
| 21 | `40_security.sql` | TV1 Toàn | Chưa – FV-22 |
| 22 | `45_jobs.sql` | TV4 Dũng | Chưa – FV-28 |
| 23 | `50_backup.sql` | TV1 Toàn | Chưa – FV-23 |
| 24 | `80_seed_small.sql / 81_seed_large.sql` | TV5 Anh | Đổi tên từ 09_seed_* – FV-16 |
| 25 | `tests/tests_<module>.sql, tests/60_concurrency_demo.sql, tests/70_perf_tests.sql` | Mỗi TV | Một phần |
| 26 | `99_run_all.bat` | TV1 Toàn | Chưa – FV-23 |

## Tuần 1 – Sprint 1 – Nền tảng CSDL (06/11/2026 → 12/11/2026)

**1. Mục tiêu Sprint:** Mọi bảng và stored procedure lõi của 5 module có trên main; chạy toàn bộ script trên CSDL trống không lỗi; xóa hết nhánh tồn đọng.

**2. Chức năng cần hoàn thành:** Đăng nhập (SQL thật), quản lý sản phẩm/lô/châm hàng, bán hàng lõi, nhận telemetry, báo cáo lõi; Docker khung

**3. Công việc từng thành viên**

| Thành viên | Task |
|---|---|
| Huy | FV-01 (SCRUM-195) Họp chốt quyết định kỹ thuật và đưa bộ tài liệu NHIEM_VU_CHI_TIET lên repo (06/11–06/11)<br>FV-02 (SCRUM-196) Sửa bảng inventory: hạn dùng theo giờ, SlotStock, phiếu châm hàng, kiểu TVP, Temporal Table (07/11–08/11)<br>FV-03 (SCRUM-197) 5 procedure inventory: AddProduct, UpdateProduct, UpdatePrice, AssignColumn, AddBatch (09/11–10/11)<br>FV-04 (SCRUM-198) sp_Restock (TVP + transaction) và sp_RemoveExpired (11/11–12/11)<br>FV-05 (SCRUM-199) Leader: review & merge các nhánh tồn đọng, chạy thử toàn bộ script trên CSDL trống (07/11–12/11) |
| Toàn | FV-06 (SCRUM-200) Sửa bảng auth và tạo 02_tables_audit.sql (AuditLog, ChangeLog), bảng giao máy (06/11–08/11)<br>FV-07 (SCRUM-201) Sửa 03_foreign_keys.sql cho khớp bảng thật (đang lỗi khi chạy từ đầu) (09/11–09/11)<br>FV-08 (SCRUM-202) 10_procs_auth.sql: sp_Login, sp_CreateUser, sp_ChangePassword, sp_AssignMachine, sp_DeactivateUser + fn_HashPassword (10/11–12/11) |
| Ân | FV-09 (SCRUM-203) Đưa nhánh tv3-sales lên main: cập nhật theo main, bỏ phần tạo bảng của inventory, mở PR (06/11–08/11)<br>FV-10 (SCRUM-204) Thêm sales.vw_DispenseQueue và đối chiếu cột 3 view sales với API (09/11–10/11)<br>FV-11 (SCRUM-205) Dockerfile cho API và docker-compose.yml (SQL Server + API) (11/11–12/11) |
| Dũng | FV-12 (SCRUM-206) Đưa nhánh tv4-iot lên main, gộp file theo QĐ-3, sửa lệch gói telemetry (machineId/serial) (06/11–08/11)<br>FV-13 (SCRUM-207) Hợp nhất bảng máy và địa điểm theo QĐ-1 (iot.Machines, iot.Locations) + view tương thích inventory.Machine (09/11–10/11)<br>FV-14 (SCRUM-208) fn_IsTempInRange và trigger trg_Machines_StatusChange (ghi lịch sử đổi trạng thái máy) (11/11–12/11) |
| Anh | FV-15 (SCRUM-209) Đưa nhánh TV5 lên main sạch: bỏ phần tạo bảng của module khác, trỏ báo cáo về bảng thật (06/11–09/11)<br>FV-16 (SCRUM-210) Chuẩn hóa tên/số thứ tự file SQL theo QĐ-3 và cập nhật README, app/README (10/11–10/11)<br>FV-17 (SCRUM-211) Test Plan tổng: phạm vi, môi trường, ca kiểm thử từng module, tiêu chí đạt (11/11–12/11) |

**4. Mốc kiểm tra tiến độ**
- **06/11/2026:** FV-01 (SCRUM-195) (Huy)
- **08/11/2026:** FV-02 (SCRUM-196) (Huy); FV-06 (SCRUM-200) (Toàn); FV-09 (SCRUM-203) (Ân); FV-12 (SCRUM-206) (Dũng)
- **09/11/2026:** FV-07 (SCRUM-201) (Toàn); FV-15 (SCRUM-209) (Anh)
- **10/11/2026:** FV-03 (SCRUM-197) (Huy); FV-10 (SCRUM-204) (Ân); FV-13 (SCRUM-207) (Dũng); FV-16 (SCRUM-210) (Anh)
- **12/11/2026:** FV-04 (SCRUM-198) (Huy); FV-05 (SCRUM-199) (Huy); FV-08 (SCRUM-202) (Toàn); FV-11 (SCRUM-205) (Ân); FV-14 (SCRUM-208) (Dũng); FV-17 (SCRUM-211) (Anh)

**5. Kết quả đầu ra**
- Biên bản họp trong MASTER_PLAN.md
- Thư mục NHIEM_VU_CHI_TIET trên main
- Sprint 1 trên Jira
- sql/02_tables_inventory.sql
- sql/11_procs_inventory.sql (5 procedure)
- sql/11_procs_inventory.sql (đủ 7 procedure)
- Nhánh main sạch, chạy được
- Danh sách GitHub Issues
- sql/02_tables_auth.sql
- sql/02_tables_audit.sql
- sql/03_foreign_keys.sql
- sql/10_procs_auth.sql
- PR tv3-sales đã merge
- sql/22_objects_sales.sql (thêm view)
- app/Dockerfile
- docker-compose.yml
- sql/13_procs_iot.sql
- sql/23_objects_iot.sql
- sql/02_tables_iot.sql (view tương thích)
- sql/23_objects_iot.sql
- PR nhánh TV5 đã merge
- README.md
- app/README.md
- docs/TestPlan.md

**6. Tiêu chí nghiệm thu Sprint**
- Chạy toàn bộ script trên CSDL trống không lỗi (Huy kiểm tra 12/11)
- 3 nhánh tồn đọng đã merge
- `auth.sp_Login` đăng nhập được 3 tài khoản demo
- 7 procedure inventory + 7 procedure iot (đã sửa gói) + 5 procedure sales trên main

**7. Rủi ro và phương án xử lý**

| Rủi ro | Phương án |
|---|---|
| Toàn (TV1) chậm – chưa có commit nào | Huy hỗ trợ cặp FV-08 ngày 10–11/11; nếu 11/11 chưa có sp_Login thì Huy viết sp_Login, Toàn làm 4 procedure còn lại |
| Conflict khi merge 3 nhánh cũ | Merge đúng thứ tự tv4-iot → tv3-sales → TV5; mỗi nhánh tự merge main trước |
| Nhóm không chốt được QĐ-1 | Leader quyết trong họp 06/11 |
## Tuần 2 – Sprint 2 – Đủ object & nối app với SQL Server thật (13/11/2026 → 19/11/2026)

**1. Mục tiêu Sprint:** Đủ view/function/trigger/phần khó của 5 module; phân quyền 4 login; app chạy DB_MODE=sqlserver qua trọn kịch bản châm hàng → mua → nhả hàng → cảnh báo → báo cáo.

**2. Chức năng cần hoàn thành:** Phân quyền RBAC/RLS, cảnh báo tồn thấp/hết hạn, hàng chờ nhả, partition + job, đo hiệu năng, tích hợp app ↔ SQL

**3. Công việc từng thành viên**

| Thành viên | Task |
|---|---|
| Huy | FV-18 (SCRUM-212) 21_objects_inventory: 4 view, fn_PriceHistory, fn_GetFifoStock, trigger cảnh báo sắp hết hàng (13/11–15/11)<br>FV-19 (SCRUM-213) Index inventory và file test tests_inventory.sql (16/11–16/11)<br>FV-20 (SCRUM-214) Tích hợp: chạy app với SQL Server thật (DB_MODE=sqlserver), phân loại lỗi theo module (17/11–19/11) |
| Toàn | FV-21 (SCRUM-215) 20_objects_auth.sql: vw_UserPermissions, audit.vw_LoginActivity, trigger ghi ChangeLog (13/11–14/11)<br>FV-22 (SCRUM-216) 40_security.sql: 4 login ứng dụng, database role, GRANT/DENY theo bảng ALLOW, Row-Level Security (15/11–17/11)<br>FV-23 (SCRUM-217) 50_backup.sql (Full/Diff/Log) và 99_run_all.bat (tạo CSDL từ máy trống bằng 1 lệnh) (18/11–19/11) |
| Ân | FV-24 (SCRUM-218) Chạy kịch bản bán hàng trên SQL thật và sửa procedure sales cho khớp API (13/11–15/11)<br>FV-25 (SCRUM-219) Chuẩn hóa demo 2 phiên mua cùng lúc (UPDLOCK, mức cô lập) để trình bày khi bảo vệ (16/11–17/11)<br>FV-26 (SCRUM-220) Detailed Design: đặc tả API (Swagger), sequence diagram mua hàng, state diagram đơn hàng (18/11–19/11) |
| Dũng | FV-27 (SCRUM-221) Partition bảng iot.Telemetry theo tháng + sp_MaintainPartitions (13/11–15/11)<br>FV-28 (SCRUM-222) 45_jobs.sql: 3 SQL Agent Job (mỗi phút, mỗi giờ, mỗi tháng) + phương án cho SQL Express (16/11–17/11)<br>FV-29 (SCRUM-223) Mô phỏng ESP32 end-to-end với CSDL thật: 5 kịch bản (bình thường, quá nhiệt, mở cửa, kẹt hàng, mất mạng) (18/11–19/11) |
| Anh | FV-30 (SCRUM-224) Cập nhật sp_RunAllTests phủ 5 module và seed nhỏ/lớn theo schema thật (13/11–15/11)<br>FV-31 (SCRUM-225) 70_perf_tests.sql: so sánh Execution Plan trước/sau index, đo thời gian truy vấn báo cáo trên dữ liệu lớn (16/11–17/11)<br>FV-32 (SCRUM-226) Kiểm thử tích hợp end-to-end trên SQL thật: châm hàng → mua → thanh toán → nhả → cảnh báo → báo cáo (18/11–19/11) |

**4. Mốc kiểm tra tiến độ**
- **14/11/2026:** FV-21 (SCRUM-215) (Toàn)
- **15/11/2026:** FV-18 (SCRUM-212) (Huy); FV-24 (SCRUM-218) (Ân); FV-27 (SCRUM-221) (Dũng); FV-30 (SCRUM-224) (Anh)
- **16/11/2026:** FV-19 (SCRUM-213) (Huy)
- **17/11/2026:** FV-22 (SCRUM-216) (Toàn); FV-25 (SCRUM-219) (Ân); FV-28 (SCRUM-222) (Dũng); FV-31 (SCRUM-225) (Anh)
- **19/11/2026:** FV-20 (SCRUM-214) (Huy); FV-23 (SCRUM-217) (Toàn); FV-26 (SCRUM-220) (Ân); FV-29 (SCRUM-223) (Dũng); FV-32 (SCRUM-226) (Anh)

**5. Kết quả đầu ra**
- sql/21_objects_inventory.sql
- sql/30_index_inventory.sql
- tests/tests_inventory.sql
- Danh sách GitHub Issues
- Ảnh chụp 9 trang chạy SQL thật
- sql/20_objects_auth.sql
- sql/40_security.sql
- 99_run_all.bat
- sql/50_backup.sql
- sql/12_procs_sales.sql (đã sửa)
- tests/tests_sales.sql
- tests/60_concurrency_demo.sql
- Video
- docs/DetailedDesign.md
- sql/02_tables_iot.sql
- sql/13_procs_iot.sql
- sql/45_jobs.sql
- docs/KichBan_IoT_MoPhong.md
- Ảnh/video trên Drive
- sql/14_procs_report.sql
- sql/80_seed_small.sql
- sql/81_seed_large.sql
- tests/70_perf_tests.sql
- Bảng số liệu
- Mục Integration trong TestReport.md

**6. Tiêu chí nghiệm thu Sprint**
- Đủ 45 đối tượng CSDL mà API cần
- App chạy `DB_MODE=sqlserver`, 9 trang + kiosk không lỗi 500
- 5 kịch bản IoT mô phỏng đạt
- Kịch bản tích hợp 10 bước đạt

**7. Rủi ro và phương án xử lý**

| Rủi ro | Phương án |
|---|---|
| 40_security chặn nhầm quyền làm app lỗi 403 | Đối chiếu bảng ALLOW trong fakeDb.js; Huy test từng vai trò ngay 17/11 |
| Máy dùng SQL Express (không có Agent) | JOBS_FALLBACK=true (FV-28) |
| Lỗi tích hợp nhiều hơn dự kiến | Ngày 18–19/11 dành riêng sửa lỗi; Issue Highest ưu tiên trước |
## Tuần 3 – Sprint 3 – Kiểm thử, tài liệu, demo (20/11/2026 → 26/11/2026)

**1. Mục tiêu Sprint:** Test Report có số liệu thật, đủ tài liệu bắt buộc của đề, Docker chạy được, tag v1.0, tổng duyệt demo và vấn đáp.

**2. Chức năng cần hoàn thành:** Kiểm thử tổng thể, tài liệu, demo phần khó, đóng gói

**3. Công việc từng thành viên**

| Thành viên | Task |
|---|---|
| Huy | FV-33 (SCRUM-227) Chuẩn bị demo phần khó TV2: Temporal Table, TVP rollback, FIFO (kèm video dự phòng) (20/11–20/11)<br>FV-34 (SCRUM-228) Ghép URS/SRS tổng, User Story Tồn kho, User Manual Operator (phần tồn kho) (21/11–23/11)<br>FV-35 (SCRUM-229) Release v1.0: code freeze, tag, file .bak, gói nộp, tổng duyệt demo & vấn đáp (24/11–26/11) |
| Toàn | FV-36 (SCRUM-230) tests_auth.sql + demo phần khó TV1: RLS và khôi phục dữ liệu về thời điểm trước sự cố (STOPAT) (20/11–21/11)<br>FV-37 (SCRUM-231) ERD toàn hệ thống + Data Dictionary (từ CSDL thật) (22/11–23/11)<br>FV-38 (SCRUM-232) InstallGuide: cài đặt từ máy trống (SQL Server, Node.js, chạy CSDL, chạy app, simulator) (24/11–25/11) |
| Ân | FV-39 (SCRUM-233) User Manual Khách hàng (màn hình kiosk) có ảnh chạy SQL thật (20/11–21/11)<br>FV-40 (SCRUM-234) Slide bảo vệ (15–20 trang) + phân công người trình bày (22/11–24/11)<br>FV-41 (SCRUM-235) Kiểm thử Docker trên máy sạch và sửa lỗi (25/11–25/11) |
| Dũng | FV-42 (SCRUM-236) tests_iot.sql + kiểm tra Offline Mode / thông báo 'Tạm ngưng' trên kiosk (20/11–21/11)<br>FV-43 (SCRUM-237) Tài liệu kiến trúc: Component & Deployment Diagram, chương IoT & giới hạn phần cứng, User Manual Operator (máy & cảnh báo) (22/11–24/11)<br>FV-44 (SCRUM-238) (Tùy chọn) Firmware ESP32 tham chiếu – cùng giao thức với simulator, chỉ biên dịch, chưa nạp thiết bị (25/11–26/11) |
| Anh | FV-45 (SCRUM-239) Test Report với kết quả thật: unit (SQL + npm test), integration, performance, chuỗi lạnh (mô phỏng) (20/11–22/11)<br>FV-46 (SCRUM-240) User Manual Admin + ghép Báo cáo tổng (BaoCao) từ tài liệu của cả nhóm (23/11–25/11) |

**4. Mốc kiểm tra tiến độ**
- **20/11/2026:** FV-33 (SCRUM-227) (Huy)
- **21/11/2026:** FV-36 (SCRUM-230) (Toàn); FV-39 (SCRUM-233) (Ân); FV-42 (SCRUM-236) (Dũng)
- **22/11/2026:** FV-45 (SCRUM-239) (Anh)
- **23/11/2026:** FV-34 (SCRUM-228) (Huy); FV-37 (SCRUM-231) (Toàn)
- **24/11/2026:** FV-40 (SCRUM-234) (Ân); FV-43 (SCRUM-237) (Dũng)
- **25/11/2026:** FV-38 (SCRUM-232) (Toàn); FV-41 (SCRUM-235) (Ân); FV-46 (SCRUM-240) (Anh)
- **26/11/2026:** FV-35 (SCRUM-229) (Huy); FV-44 (SCRUM-238) (Dũng)

**5. Kết quả đầu ra**
- tests/demo_inventory.sql
- Video demo
- docs/SRS.md
- docs/UserStories_Inventory.md
- docs/UserManual_Operator.md
- Tag v1.0
- FreshVendDB.bak
- Gói nộp
- tests/tests_auth.sql
- tests/demo_security.sql
- Video
- docs/ERD.png
- docs/DataDictionary.md
- docs/InstallGuide.md
- docs/UserManual_Customer.md
- docs/Slide_BaoVe.pptx
- Docker chạy được
- tests/tests_iot.sql
- docs/Architecture.md
- 2 diagram
- firmware/esp32_freshvend.ino
- docs/TestReport.md
- docs/UserManual_Admin.md
- docs/BaoCao

**6. Tiêu chí nghiệm thu Sprint**
- Test Report số liệu thật
- Đủ tài liệu bắt buộc: SRS, Architecture (Component, Deployment, ERD), Detailed Design, Test Plan/Report, Install Guide, 3 User Manual
- Docker chạy trên máy sạch
- Tag v1.0, 2 buổi tổng duyệt

**7. Rủi ro và phương án xử lý**

| Rủi ro | Phương án |
|---|---|
| Tài liệu dồn cuối | Mỗi tài liệu có hạn riêng 21–24/11; code freeze 24/11 |
| Máy demo hỏng khi bảo vệ | Video dự phòng cho mỗi phần khó + Docker + file .bak |
| Thành viên chưa nắm toàn hệ thống | 2 buổi tổng duyệt hỏi chéo 25–26/11 |

## Bảng tổng quan 21 ngày

> **Phụ thuộc** = task kia phải xong trước khi task này được **hoàn tất**. Phần việc không phụ thuộc được bắt đầu song song từ ngày *Bắt đầu*.

| Mã | Bắt đầu | Kết thúc | Task | Phụ trách | Hỗ trợ | Ưu tiên | Phụ thuộc | Deliverable |
|---|---|---|---|---|---|---|---|---|
| FV-01 (SCRUM-195) | 06/11/2026 | 06/11/2026 | Họp chốt quyết định kỹ thuật và đưa bộ tài liệu NHIEM_VU_CHI_TIET lên repo | Huy | Toàn, Ân, Dũng, Anh | Highest | – | Biên bản họp trong MASTER_PLAN.md; Thư mục NHIEM_VU_CHI_TIET trên main; Sprint 1 trên Jira |
| FV-02 (SCRUM-196) | 07/11/2026 | 08/11/2026 | Sửa bảng inventory: hạn dùng theo giờ, SlotStock, phiếu châm hàng, kiểu TVP, Temporal Table | Huy | Ân, Dũng | Highest | FV-01 | sql/02_tables_inventory.sql |
| FV-03 (SCRUM-197) | 09/11/2026 | 10/11/2026 | 5 procedure inventory: AddProduct, UpdateProduct, UpdatePrice, AssignColumn, AddBatch | Huy | – | High | FV-02 | sql/11_procs_inventory.sql (5 procedure) |
| FV-04 (SCRUM-198) | 11/11/2026 | 12/11/2026 | sp_Restock (TVP + transaction) và sp_RemoveExpired | Huy | – | High | FV-03 | sql/11_procs_inventory.sql (đủ 7 procedure) |
| FV-05 (SCRUM-199) | 07/11/2026 | 12/11/2026 | Leader: review & merge các nhánh tồn đọng, chạy thử toàn bộ script trên CSDL trống | Huy | Anh | Highest | FV-01 | Nhánh main sạch, chạy được; Danh sách GitHub Issues |
| FV-06 (SCRUM-200) | 06/11/2026 | 08/11/2026 | Sửa bảng auth và tạo 02_tables_audit.sql (AuditLog, ChangeLog), bảng giao máy | Toàn | Huy | Highest | FV-01 | sql/02_tables_auth.sql; sql/02_tables_audit.sql |
| FV-07 (SCRUM-201) | 09/11/2026 | 09/11/2026 | Sửa 03_foreign_keys.sql cho khớp bảng thật (đang lỗi khi chạy từ đầu) | Toàn | Dũng, Anh | Highest | FV-06, FV-02 | sql/03_foreign_keys.sql |
| FV-08 (SCRUM-202) | 10/11/2026 | 12/11/2026 | 10_procs_auth.sql: sp_Login, sp_CreateUser, sp_ChangePassword, sp_AssignMachine, sp_DeactivateUser + fn_HashPassword | Toàn | Huy | Highest | FV-06 | sql/10_procs_auth.sql |
| FV-09 (SCRUM-203) | 06/11/2026 | 08/11/2026 | Đưa nhánh tv3-sales lên main: cập nhật theo main, bỏ phần tạo bảng của inventory, mở PR | Ân | Huy | High | FV-01, FV-02 | PR tv3-sales đã merge |
| FV-10 (SCRUM-204) | 09/11/2026 | 10/11/2026 | Thêm sales.vw_DispenseQueue và đối chiếu cột 3 view sales với API | Ân | Dũng | High | FV-09 | sql/22_objects_sales.sql (thêm view) |
| FV-11 (SCRUM-205) | 11/11/2026 | 12/11/2026 | Dockerfile cho API và docker-compose.yml (SQL Server + API) | Ân | Toàn | Medium | – | app/Dockerfile; docker-compose.yml |
| FV-12 (SCRUM-206) | 06/11/2026 | 08/11/2026 | Đưa nhánh tv4-iot lên main, gộp file theo QĐ-3, sửa lệch gói telemetry (machineId/serial) | Dũng | Huy | Highest | FV-01 | sql/13_procs_iot.sql; sql/23_objects_iot.sql |
| FV-13 (SCRUM-207) | 09/11/2026 | 10/11/2026 | Hợp nhất bảng máy và địa điểm theo QĐ-1 (iot.Machines, iot.Locations) + view tương thích inventory.Machine | Dũng | Huy, Toàn, Ân, Anh | Highest | FV-12, FV-07 | sql/02_tables_iot.sql (view tương thích) |
| FV-14 (SCRUM-208) | 11/11/2026 | 12/11/2026 | fn_IsTempInRange và trigger trg_Machines_StatusChange (ghi lịch sử đổi trạng thái máy) | Dũng | Toàn | Medium | FV-13 | sql/23_objects_iot.sql |
| FV-15 (SCRUM-209) | 06/11/2026 | 09/11/2026 | Đưa nhánh TV5 lên main sạch: bỏ phần tạo bảng của module khác, trỏ báo cáo về bảng thật | Anh | Huy, Dũng | Highest | FV-01 | PR nhánh TV5 đã merge |
| FV-16 (SCRUM-210) | 10/11/2026 | 10/11/2026 | Chuẩn hóa tên/số thứ tự file SQL theo QĐ-3 và cập nhật README, app/README | Anh | Toàn | High | FV-15, FV-12 | README.md; app/README.md |
| FV-17 (SCRUM-211) | 11/11/2026 | 12/11/2026 | Test Plan tổng: phạm vi, môi trường, ca kiểm thử từng module, tiêu chí đạt | Anh | Huy, Toàn, Ân, Dũng | Medium | FV-01 | docs/TestPlan.md |
| FV-18 (SCRUM-212) | 13/11/2026 | 15/11/2026 | 21_objects_inventory: 4 view, fn_PriceHistory, fn_GetFifoStock, trigger cảnh báo sắp hết hàng | Huy | Ân | High | FV-04, FV-13 | sql/21_objects_inventory.sql |
| FV-19 (SCRUM-213) | 16/11/2026 | 16/11/2026 | Index inventory và file test tests_inventory.sql | Huy | Anh | Medium | FV-18 | sql/30_index_inventory.sql; tests/tests_inventory.sql |
| FV-20 (SCRUM-214) | 17/11/2026 | 19/11/2026 | Tích hợp: chạy app với SQL Server thật (DB_MODE=sqlserver), phân loại lỗi theo module | Huy | Toàn, Anh | Highest | FV-22, FV-10, FV-18 | Danh sách GitHub Issues; Ảnh chụp 9 trang chạy SQL thật |
| FV-21 (SCRUM-215) | 13/11/2026 | 14/11/2026 | 20_objects_auth.sql: vw_UserPermissions, audit.vw_LoginActivity, trigger ghi ChangeLog | Toàn | – | High | FV-08 | sql/20_objects_auth.sql |
| FV-22 (SCRUM-216) | 15/11/2026 | 17/11/2026 | 40_security.sql: 4 login ứng dụng, database role, GRANT/DENY theo bảng ALLOW, Row-Level Security | Toàn | Huy | Highest | FV-21, FV-18, FV-10, FV-12 | sql/40_security.sql |
| FV-23 (SCRUM-217) | 18/11/2026 | 19/11/2026 | 50_backup.sql (Full/Diff/Log) và 99_run_all.bat (tạo CSDL từ máy trống bằng 1 lệnh) | Toàn | Anh | High | FV-22, FV-16 | 99_run_all.bat; sql/50_backup.sql |
| FV-24 (SCRUM-218) | 13/11/2026 | 15/11/2026 | Chạy kịch bản bán hàng trên SQL thật và sửa procedure sales cho khớp API | Ân | Huy | High | FV-10, FV-04, FV-18 | sql/12_procs_sales.sql (đã sửa); tests/tests_sales.sql |
| FV-25 (SCRUM-219) | 16/11/2026 | 17/11/2026 | Chuẩn hóa demo 2 phiên mua cùng lúc (UPDLOCK, mức cô lập) để trình bày khi bảo vệ | Ân | – | Medium | FV-24 | tests/60_concurrency_demo.sql; Video |
| FV-26 (SCRUM-220) | 18/11/2026 | 19/11/2026 | Detailed Design: đặc tả API (Swagger), sequence diagram mua hàng, state diagram đơn hàng | Ân | Huy | Medium | FV-24 | docs/DetailedDesign.md |
| FV-27 (SCRUM-221) | 13/11/2026 | 15/11/2026 | Partition bảng iot.Telemetry theo tháng + sp_MaintainPartitions | Dũng | Anh | High | FV-13 | sql/02_tables_iot.sql; sql/13_procs_iot.sql |
| FV-28 (SCRUM-222) | 16/11/2026 | 17/11/2026 | 45_jobs.sql: 3 SQL Agent Job (mỗi phút, mỗi giờ, mỗi tháng) + phương án cho SQL Express | Dũng | Huy | High | FV-27, FV-04 | sql/45_jobs.sql |
| FV-29 (SCRUM-223) | 18/11/2026 | 19/11/2026 | Mô phỏng ESP32 end-to-end với CSDL thật: 5 kịch bản (bình thường, quá nhiệt, mở cửa, kẹt hàng, mất mạng) | Dũng | Ân, Huy | Highest | FV-12, FV-22, FV-28, FV-10 | docs/KichBan_IoT_MoPhong.md; Ảnh/video trên Drive |
| FV-30 (SCRUM-224) | 13/11/2026 | 15/11/2026 | Cập nhật sp_RunAllTests phủ 5 module và seed nhỏ/lớn theo schema thật | Anh | Huy | High | FV-16, FV-08, FV-04, FV-24 | sql/14_procs_report.sql; sql/80_seed_small.sql; sql/81_seed_large.sql |
| FV-31 (SCRUM-225) | 16/11/2026 | 17/11/2026 | 70_perf_tests.sql: so sánh Execution Plan trước/sau index, đo thời gian truy vấn báo cáo trên dữ liệu lớn | Anh | Dũng | Medium | FV-30, FV-19, FV-27 | tests/70_perf_tests.sql; Bảng số liệu |
| FV-32 (SCRUM-226) | 18/11/2026 | 19/11/2026 | Kiểm thử tích hợp end-to-end trên SQL thật: châm hàng → mua → thanh toán → nhả → cảnh báo → báo cáo | Anh | Huy, Ân, Dũng | Highest | FV-20, FV-29 | Mục Integration trong TestReport.md |
| FV-33 (SCRUM-227) | 20/11/2026 | 20/11/2026 | Chuẩn bị demo phần khó TV2: Temporal Table, TVP rollback, FIFO (kèm video dự phòng) | Huy | – | Medium | FV-18 | tests/demo_inventory.sql; Video demo |
| FV-34 (SCRUM-228) | 21/11/2026 | 23/11/2026 | Ghép URS/SRS tổng, User Story Tồn kho, User Manual Operator (phần tồn kho) | Huy | Toàn, Ân, Dũng, Anh | High | FV-20 | docs/SRS.md; docs/UserStories_Inventory.md; docs/UserManual_Operator.md |
| FV-35 (SCRUM-229) | 24/11/2026 | 26/11/2026 | Release v1.0: code freeze, tag, file .bak, gói nộp, tổng duyệt demo & vấn đáp | Huy | Toàn, Ân, Dũng, Anh | Highest | FV-38, FV-41, FV-45, FV-46 | Tag v1.0; FreshVendDB.bak; Gói nộp |
| FV-36 (SCRUM-230) | 20/11/2026 | 21/11/2026 | tests_auth.sql + demo phần khó TV1: RLS và khôi phục dữ liệu về thời điểm trước sự cố (STOPAT) | Toàn | – | High | FV-22, FV-23 | tests/tests_auth.sql; tests/demo_security.sql; Video |
| FV-37 (SCRUM-231) | 22/11/2026 | 23/11/2026 | ERD toàn hệ thống + Data Dictionary (từ CSDL thật) | Toàn | Huy, Ân, Dũng, Anh | High | FV-20 | docs/ERD.png; docs/DataDictionary.md |
| FV-38 (SCRUM-232) | 24/11/2026 | 25/11/2026 | InstallGuide: cài đặt từ máy trống (SQL Server, Node.js, chạy CSDL, chạy app, simulator) | Toàn | Ân | High | FV-23 | docs/InstallGuide.md |
| FV-39 (SCRUM-233) | 20/11/2026 | 21/11/2026 | User Manual Khách hàng (màn hình kiosk) có ảnh chạy SQL thật | Ân | – | Medium | FV-20 | docs/UserManual_Customer.md |
| FV-40 (SCRUM-234) | 22/11/2026 | 24/11/2026 | Slide bảo vệ (15–20 trang) + phân công người trình bày | Ân | Huy, Toàn, Dũng, Anh | High | FV-34, FV-43, FV-45 | docs/Slide_BaoVe.pptx |
| FV-41 (SCRUM-235) | 25/11/2026 | 25/11/2026 | Kiểm thử Docker trên máy sạch và sửa lỗi | Ân | Toàn | Medium | FV-11, FV-23 | Docker chạy được |
| FV-42 (SCRUM-236) | 20/11/2026 | 21/11/2026 | tests_iot.sql + kiểm tra Offline Mode / thông báo 'Tạm ngưng' trên kiosk | Dũng | Ân | High | FV-29 | tests/tests_iot.sql |
| FV-43 (SCRUM-237) | 22/11/2026 | 24/11/2026 | Tài liệu kiến trúc: Component & Deployment Diagram, chương IoT & giới hạn phần cứng, User Manual Operator (máy & cảnh báo) | Dũng | Huy | High | FV-29 | docs/Architecture.md; 2 diagram |
| FV-44 (SCRUM-238) | 25/11/2026 | 26/11/2026 | (Tùy chọn) Firmware ESP32 tham chiếu – cùng giao thức với simulator, chỉ biên dịch, chưa nạp thiết bị | Dũng | – | Low | FV-29 | firmware/esp32_freshvend.ino |
| FV-45 (SCRUM-239) | 20/11/2026 | 22/11/2026 | Test Report với kết quả thật: unit (SQL + npm test), integration, performance, chuỗi lạnh (mô phỏng) | Anh | Huy, Toàn, Ân, Dũng | Highest | FV-32, FV-31, FV-36, FV-42 | docs/TestReport.md |
| FV-46 (SCRUM-240) | 23/11/2026 | 25/11/2026 | User Manual Admin + ghép Báo cáo tổng (BaoCao) từ tài liệu của cả nhóm | Anh | Huy | High | FV-34, FV-37, FV-43, FV-45 | docs/UserManual_Admin.md; docs/BaoCao |

## Thời gian dự phòng

- Mỗi Sprint giữ ngày cuối (12/11, 19/11) cho sửa lỗi và merge.
- 25–26/11 chỉ tổng duyệt, sửa lỗi nhỏ; không thêm chức năng sau code freeze 24/11 18h.
- FV-44 (firmware tham chiếu) là tùy chọn – bỏ nếu thiếu thời gian.

## Theo dõi tiến độ

| Ngày | Kết quả chạy toàn bộ script trên main | Ghi chú |
|---|---|---|
| 12/11/2026 | | |
| 19/11/2026 | | |
| 24/11/2026 | | |

## Biên bản họp

**06/11/2026 – Họp khởi động (FV-01)**
- Người tham dự:
- QĐ-1:
- QĐ-2:
- QĐ-3:
- QĐ-4:
- Việc tiếp theo:
