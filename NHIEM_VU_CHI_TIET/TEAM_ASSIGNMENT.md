# TEAM_ASSIGNMENT – Phân công 5 thành viên

Phân công theo module (mỗi người 1 schema) để hạn chế 2 người sửa cùng file. Khối lượng cân bằng theo **độ khó + effort**, không theo số task: Toàn nhiều việc viết mới nhất (auth từ đầu) nên ít tài liệu hơn; Huy là Leader nên thêm review/tích hợp/phát hành; Anh giữ vai trò QA xuyên suốt.

**Quy ước giao tiếp giữa module:** (1) API chỉ gọi procedure/view, tên + tham số + mã lỗi + cột trả về theo `app/api/test/fakeDb.js`; (2) FK chéo schema chỉ trong `03_foreign_keys.sql` (Toàn); (3) cần thay đổi bảng của người khác → mở GitHub Issue gán người đó; (4) cảnh báo của mọi module ghi vào `iot.Alerts` (Dũng giữ cấu trúc bảng).

**Người tích hợp cuối cùng:** Huy (Leader) – FV-05, FV-20, FV-35.

| Thành viên | Vai trò | Module | Số task | Effort ước tính (giờ) |
|---|---|---|---|---|
| Nguyễn Phương Huy | Leader – TV2 Sản phẩm & Tồn kho (schema inventory) + Tích hợp hệ thống, review & merge PR | inventory + tích hợp | 11 | ~58 |
| Huỳnh Nhật Toàn | TV1 – Người dùng & Bảo mật (schema auth, audit), RBAC/RLS, Backup, cài đặt | auth, audit | 9 | ~56 |
| Đoàn Phương Thiên Ân | TV3 – Bán hàng & Thanh toán (schema sales), Kiosk, Docker, slide bảo vệ | sales + Docker | 9 | ~50 |
| Trương Tuấn Dũng | TV4 – IoT & Chuỗi lạnh (schema iot), mô phỏng ESP32, SQL Agent Job, kiến trúc | iot + simulator | 9 | ~54 |
| Nguyễn Phạm Xuân Anh | TV5 – Báo cáo & Phân tích (schema report), QA: kiểm thử tích hợp, hiệu năng, Test Report | report + QA | 8 | ~50 |

## Nguyễn Phương Huy (Huy) – jira@nguyenhuyth2k6.atlassian.net

- **Vai trò:** Leader – TV2 Sản phẩm & Tồn kho (schema inventory) + Tích hợp hệ thống, review & merge PR
- **Trách nhiệm chính:** Sản phẩm & Tồn kho (inventory); Tích hợp, Triển khai & Tài liệu
- **Module phụ trách:** inventory + tích hợp
- **Phối hợp với:** Toàn, Ân, Dũng, Anh
- **File nhiệm vụ:**
- Tuần 1: `TUAN_1/Huy_HopChot_BangVaProcInventory_ReviewMerge.md`
- Tuần 2: `TUAN_2/Huy_ObjectInventory_TichHopSQLServer.md`
- Tuần 3: `TUAN_3/Huy_DemoInventory_SRS_Release.md`

| Mã | Sprint | Task | Thời gian | Bàn giao | Tiêu chí nghiệm thu chính |
|---|---|---|---|---|---|
| FV-01 (SCRUM-195) | 1 | Họp chốt quyết định kỹ thuật và đưa bộ tài liệu NHIEM_VU_CHI_TIET lên repo | 06/11–06/11 | Biên bản họp trong MASTER_PLAN.md; Thư mục NHIEM_VU_CHI_TIET trên main; Sprint 1 trên Jira | 4 quyết định kỹ thuật có kết luận và được ghi trong MASTER_PLAN.md |
| FV-02 (SCRUM-196) | 1 | Sửa bảng inventory: hạn dùng theo giờ, SlotStock, phiếu châm hàng, kiểu TVP, Temporal Table | 07/11–08/11 | sql/02_tables_inventory.sql | Không đổi tên/xóa cột mà TV3, TV5 đang dùng (Slot, SlotStock, StockBatch, Product.UnitPrice) |
| FV-03 (SCRUM-197) | 1 | 5 procedure inventory: AddProduct, UpdateProduct, UpdatePrice, AssignColumn, AddBatch | 09/11–10/11 | sql/11_procs_inventory.sql (5 procedure) | 5 procedure dùng CREATE OR ALTER, chạy lại không lỗi |
| FV-04 (SCRUM-198) | 1 | sp_Restock (TVP + transaction) và sp_RemoveExpired | 11/11–12/11 | sql/11_procs_inventory.sql (đủ 7 procedure) | Rollback toàn bộ khi 1 dòng lỗi (đếm RestockEvent trước/sau bằng nhau) |
| FV-05 (SCRUM-199) | 1 | Leader: review & merge các nhánh tồn đọng, chạy thử toàn bộ script trên CSDL trống | 07/11–12/11 | Nhánh main sạch, chạy được; Danh sách GitHub Issues | 3 nhánh tồn đọng đã merge hoặc có Request changes ghi rõ lý do |
| FV-18 (SCRUM-212) | 2 | 21_objects_inventory: 4 view, fn_PriceHistory, fn_GetFifoStock, trigger cảnh báo sắp hết hàng | 13/11–15/11 | sql/21_objects_inventory.sql | Tên view/cột khớp fakeDb.js |
| FV-19 (SCRUM-213) | 2 | Index inventory và file test tests_inventory.sql | 16/11–16/11 | sql/30_index_inventory.sql; tests/tests_inventory.sql | 21/21 PASS, chạy lặp lại được |
| FV-20 (SCRUM-214) | 2 | Tích hợp: chạy app với SQL Server thật (DB_MODE=sqlserver), phân loại lỗi theo module | 17/11–19/11 | Danh sách GitHub Issues; Ảnh chụp 9 trang chạy SQL thật | App chạy DB_MODE=sqlserver, 9 trang + kiosk mở được |
| FV-33 (SCRUM-227) | 3 | Chuẩn bị demo phần khó TV2: Temporal Table, TVP rollback, FIFO (kèm video dự phòng) | 20/11–20/11 | tests/demo_inventory.sql; Video demo | 3 khối chạy được trên CSDL sạch |
| FV-34 (SCRUM-228) | 3 | Ghép URS/SRS tổng, User Story Tồn kho, User Manual Operator (phần tồn kho) | 21/11–23/11 | docs/SRS.md; docs/UserStories_Inventory.md; docs/UserManual_Operator.md | SRS đủ 5 module + phi chức năng + ràng buộc |
| FV-35 (SCRUM-229) | 3 | Release v1.0: code freeze, tag, file .bak, gói nộp, tổng duyệt demo & vấn đáp | 24/11–26/11 | Tag v1.0; FreshVendDB.bak; Gói nộp | Tag v1.0 trên GitHub |


## Huỳnh Nhật Toàn (Toàn) – htoan2851@gmail.com

- **Vai trò:** TV1 – Người dùng & Bảo mật (schema auth, audit), RBAC/RLS, Backup, cài đặt
- **Trách nhiệm chính:** Người dùng & Bảo mật (auth, audit); Tích hợp, Triển khai & Tài liệu
- **Module phụ trách:** auth, audit
- **Phối hợp với:** Huy, Ân, Dũng, Anh
- **File nhiệm vụ:**
- Tuần 1: `TUAN_1/Toan_BangAuthAudit_ForeignKey_ProcAuth.md`
- Tuần 2: `TUAN_2/Toan_ViewTrigger_PhanQuyenRLS_Backup.md`
- Tuần 3: `TUAN_3/Toan_TestBaoMat_ERD_InstallGuide.md`

| Mã | Sprint | Task | Thời gian | Bàn giao | Tiêu chí nghiệm thu chính |
|---|---|---|---|---|---|
| FV-06 (SCRUM-200) | 1 | Sửa bảng auth và tạo 02_tables_audit.sql (AuditLog, ChangeLog), bảng giao máy | 06/11–08/11 | sql/02_tables_auth.sql; sql/02_tables_audit.sql | auth.[User] có Salt, FailedLogins, LastLoginAt |
| FV-07 (SCRUM-201) | 1 | Sửa 03_foreign_keys.sql cho khớp bảng thật (đang lỗi khi chạy từ đầu) | 09/11–09/11 | sql/03_foreign_keys.sql | 03_foreign_keys chạy sạch trên CSDL trống |
| FV-08 (SCRUM-202) | 1 | 10_procs_auth.sql: sp_Login, sp_CreateUser, sp_ChangePassword, sp_AssignMachine, sp_DeactivateUser + fn_HashPassword | 10/11–12/11 | sql/10_procs_auth.sql | sp_Login trả đúng 2 bảng kết quả |
| FV-21 (SCRUM-215) | 2 | 20_objects_auth.sql: vw_UserPermissions, audit.vw_LoginActivity, trigger ghi ChangeLog | 13/11–14/11 | sql/20_objects_auth.sql | 2 view đúng cột API |
| FV-22 (SCRUM-216) | 2 | 40_security.sql: 4 login ứng dụng, database role, GRANT/DENY theo bảng ALLOW, Row-Level Security | 15/11–17/11 | sql/40_security.sql | Quyền 4 login khớp bảng ALLOW |
| FV-23 (SCRUM-217) | 2 | 50_backup.sql (Full/Diff/Log) và 99_run_all.bat (tạo CSDL từ máy trống bằng 1 lệnh) | 18/11–19/11 | 99_run_all.bat; sql/50_backup.sql | 99_run_all.bat dựng CSDL sạch trong 1 lệnh |
| FV-36 (SCRUM-230) | 3 | tests_auth.sql + demo phần khó TV1: RLS và khôi phục dữ liệu về thời điểm trước sự cố (STOPAT) | 20/11–21/11 | tests/tests_auth.sql; tests/demo_security.sql; Video | 18/18 PASS |
| FV-37 (SCRUM-231) | 3 | ERD toàn hệ thống + Data Dictionary (từ CSDL thật) | 22/11–23/11 | docs/ERD.png; docs/DataDictionary.md | ERD đủ 6 schema, khớp CSDL thật |
| FV-38 (SCRUM-232) | 3 | InstallGuide: cài đặt từ máy trống (SQL Server, Node.js, chạy CSDL, chạy app, simulator) | 24/11–25/11 | docs/InstallGuide.md | Người khác làm theo thành công |


## Đoàn Phương Thiên Ân (Ân) – thienann2611@gmail.com

- **Vai trò:** TV3 – Bán hàng & Thanh toán (schema sales), Kiosk, Docker, slide bảo vệ
- **Trách nhiệm chính:** Bán hàng & Thanh toán (sales); Tích hợp, Triển khai & Tài liệu
- **Module phụ trách:** sales + Docker
- **Phối hợp với:** Huy, Toàn, Dũng, Anh
- **File nhiệm vụ:**
- Tuần 1: `TUAN_1/An_MergeSales_DispenseQueue_Docker.md`
- Tuần 2: `TUAN_2/An_BanHangSQLThat_DemoDongThoi_DetailedDesign.md`
- Tuần 3: `TUAN_3/An_UserManualKhach_Slide_KiemThuDocker.md`

| Mã | Sprint | Task | Thời gian | Bàn giao | Tiêu chí nghiệm thu chính |
|---|---|---|---|---|---|
| FV-09 (SCRUM-203) | 1 | Đưa nhánh tv3-sales lên main: cập nhật theo main, bỏ phần tạo bảng của inventory, mở PR | 06/11–08/11 | PR tv3-sales đã merge | Không còn tạo bảng của schema khác trong file sales |
| FV-10 (SCRUM-204) | 1 | Thêm sales.vw_DispenseQueue và đối chiếu cột 3 view sales với API | 09/11–10/11 | sql/22_objects_sales.sql (thêm view) | View tồn tại, cột khớp fakeDb |
| FV-11 (SCRUM-205) | 1 | Dockerfile cho API và docker-compose.yml (SQL Server + API) | 11/11–12/11 | app/Dockerfile; docker-compose.yml | Build không lỗi |
| FV-24 (SCRUM-218) | 2 | Chạy kịch bản bán hàng trên SQL thật và sửa procedure sales cho khớp API | 13/11–15/11 | sql/12_procs_sales.sql (đã sửa); tests/tests_sales.sql | 4 test đúng trên SQL thật |
| FV-25 (SCRUM-219) | 2 | Chuẩn hóa demo 2 phiên mua cùng lúc (UPDLOCK, mức cô lập) để trình bày khi bảo vệ | 16/11–17/11 | tests/60_concurrency_demo.sql; Video | Demo lặp lại được |
| FV-26 (SCRUM-220) | 2 | Detailed Design: đặc tả API (Swagger), sequence diagram mua hàng, state diagram đơn hàng | 18/11–19/11 | docs/DetailedDesign.md | Đủ 3 phần API, sequence, state, wireframe |
| FV-39 (SCRUM-233) | 3 | User Manual Khách hàng (màn hình kiosk) có ảnh chạy SQL thật | 20/11–21/11 | docs/UserManual_Customer.md | Đủ 6 tình huống, có ảnh thật |
| FV-40 (SCRUM-234) | 3 | Slide bảo vệ (15–20 trang) + phân công người trình bày | 22/11–24/11 | docs/Slide_BaoVe.pptx | Đủ phần của 5 người |
| FV-41 (SCRUM-235) | 3 | Kiểm thử Docker trên máy sạch và sửa lỗi | 25/11–25/11 | Docker chạy được | Chạy được trên máy sạch |


## Trương Tuấn Dũng (Dũng) – dungtuanxz12345@gmail.com

- **Vai trò:** TV4 – IoT & Chuỗi lạnh (schema iot), mô phỏng ESP32, SQL Agent Job, kiến trúc
- **Trách nhiệm chính:** IoT & Chuỗi lạnh (iot)
- **Module phụ trách:** iot + simulator
- **Phối hợp với:** Huy, Toàn, Ân, Anh
- **File nhiệm vụ:**
- Tuần 1: `TUAN_1/Dung_MergeIoT_SuaTelemetry_HopNhatBangMay.md`
- Tuần 2: `TUAN_2/Dung_Partition_AgentJob_MoPhongESP32.md`
- Tuần 3: `TUAN_3/Dung_TestIoT_KienTruc_FirmwareThamChieu.md`

| Mã | Sprint | Task | Thời gian | Bàn giao | Tiêu chí nghiệm thu chính |
|---|---|---|---|---|---|
| FV-12 (SCRUM-206) | 1 | Đưa nhánh tv4-iot lên main, gộp file theo QĐ-3, sửa lệch gói telemetry (machineId/serial) | 06/11–08/11 | sql/13_procs_iot.sql; sql/23_objects_iot.sql | sp_IngestTelemetry nhận gói đúng định dạng API gửi |
| FV-13 (SCRUM-207) | 1 | Hợp nhất bảng máy và địa điểm theo QĐ-1 (iot.Machines, iot.Locations) + view tương thích inventory.Machine | 09/11–10/11 | sql/02_tables_iot.sql (view tương thích) | Chỉ còn 1 bảng máy |
| FV-14 (SCRUM-208) | 1 | fn_IsTempInRange và trigger trg_Machines_StatusChange (ghi lịch sử đổi trạng thái máy) | 11/11–12/11 | sql/23_objects_iot.sql | 3 test đúng |
| FV-27 (SCRUM-221) | 2 | Partition bảng iot.Telemetry theo tháng + sp_MaintainPartitions | 13/11–15/11 | sql/02_tables_iot.sql; sql/13_procs_iot.sql | Telemetry nằm trên partition scheme |
| FV-28 (SCRUM-222) | 2 | 45_jobs.sql: 3 SQL Agent Job (mỗi phút, mỗi giờ, mỗi tháng) + phương án cho SQL Express | 16/11–17/11 | sql/45_jobs.sql | 3 job tạo được (Developer) hoặc fallback chạy (Express) |
| FV-29 (SCRUM-223) | 2 | Mô phỏng ESP32 end-to-end với CSDL thật: 5 kịch bản (bình thường, quá nhiệt, mở cửa, kẹt hàng, mất mạng) | 18/11–19/11 | docs/KichBan_IoT_MoPhong.md; Ảnh/video trên Drive | 5/5 kịch bản đạt trên SQL thật |
| FV-42 (SCRUM-236) | 3 | tests_iot.sql + kiểm tra Offline Mode / thông báo 'Tạm ngưng' trên kiosk | 20/11–21/11 | tests/tests_iot.sql | 21/21 PASS |
| FV-43 (SCRUM-237) | 3 | Tài liệu kiến trúc: Component & Deployment Diagram, chương IoT & giới hạn phần cứng, User Manual Operator (máy & cảnh báo) | 22/11–24/11 | docs/Architecture.md; 2 diagram | Diagram khớp hệ thống thật |
| FV-44 (SCRUM-238) | 3 | (Tùy chọn) Firmware ESP32 tham chiếu – cùng giao thức với simulator, chỉ biên dịch, chưa nạp thiết bị | 25/11–26/11 | firmware/esp32_freshvend.ino | Biên dịch được |


## Nguyễn Phạm Xuân Anh (Anh) – modz06j.xuananhngxph@gmail.com

- **Vai trò:** TV5 – Báo cáo & Phân tích (schema report), QA: kiểm thử tích hợp, hiệu năng, Test Report
- **Trách nhiệm chính:** Báo cáo & Kiểm thử (report, QA); Tích hợp, Triển khai & Tài liệu
- **Module phụ trách:** report + QA
- **Phối hợp với:** Huy, Toàn, Ân, Dũng
- **File nhiệm vụ:**
- Tuần 1: `TUAN_1/Anh_MergeReport_ThuTuFile_TestPlan.md`
- Tuần 2: `TUAN_2/Anh_RunAllTests_HieuNang_TichHopE2E.md`
- Tuần 3: `TUAN_3/Anh_TestReport_UserManualAdmin_BaoCao.md`

| Mã | Sprint | Task | Thời gian | Bàn giao | Tiêu chí nghiệm thu chính |
|---|---|---|---|---|---|
| FV-15 (SCRUM-209) | 1 | Đưa nhánh TV5 lên main sạch: bỏ phần tạo bảng của module khác, trỏ báo cáo về bảng thật | 06/11–09/11 | PR nhánh TV5 đã merge | Không còn tạo bảng/index của schema khác |
| FV-16 (SCRUM-210) | 1 | Chuẩn hóa tên/số thứ tự file SQL theo QĐ-3 và cập nhật README, app/README | 10/11–10/11 | README.md; app/README.md | Tên file khớp bảng MASTER_PLAN |
| FV-17 (SCRUM-211) | 1 | Test Plan tổng: phạm vi, môi trường, ca kiểm thử từng module, tiêu chí đạt | 11/11–12/11 | docs/TestPlan.md | Có đủ 3 loại kiểm thử + tiêu chí đạt |
| FV-30 (SCRUM-224) | 2 | Cập nhật sp_RunAllTests phủ 5 module và seed nhỏ/lớn theo schema thật | 13/11–15/11 | sql/14_procs_report.sql; sql/80_seed_small.sql; sql/81_seed_large.sql | Không còn ca PASS giả |
| FV-31 (SCRUM-225) | 2 | 70_perf_tests.sql: so sánh Execution Plan trước/sau index, đo thời gian truy vấn báo cáo trên dữ liệu lớn | 16/11–17/11 | tests/70_perf_tests.sql; Bảng số liệu | Có bảng số liệu trước/sau |
| FV-32 (SCRUM-226) | 2 | Kiểm thử tích hợp end-to-end trên SQL thật: châm hàng → mua → thanh toán → nhả → cảnh báo → báo cáo | 18/11–19/11 | Mục Integration trong TestReport.md | 10/10 bước Pass trên SQL thật |
| FV-45 (SCRUM-239) | 3 | Test Report với kết quả thật: unit (SQL + npm test), integration, performance, chuỗi lạnh (mô phỏng) | 20/11–22/11 | docs/TestReport.md | Mọi số liệu có ngày chạy thật |
| FV-46 (SCRUM-240) | 3 | User Manual Admin + ghép Báo cáo tổng (BaoCao) từ tài liệu của cả nhóm | 23/11–25/11 | docs/UserManual_Admin.md; docs/BaoCao | Báo cáo đủ mục, thống nhất tên/ngày |
