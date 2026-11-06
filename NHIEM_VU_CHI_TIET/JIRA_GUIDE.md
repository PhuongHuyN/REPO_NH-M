# JIRA_GUIDE – Đưa kế hoạch lên Jira

Board: https://nguyenhuyth2k6.atlassian.net/jira/software/projects/SCRUM/boards/1/backlog

## Trạng thái đã tạo trên Jira (05/11/2026)

- Đã tạo **3 sprint mới** (chưa Start): `FV Sprint 1 (06–12/11)`, `FV Sprint 2 (13–19/11)`, `FV Sprint 3 (20–26/11)` – có sẵn ngày và Sprint goal.
- Đã tạo **46 Task** `SCRUM-195` → `SCRUM-240`, tiêu đề bắt đầu bằng `[FV-xx]`, nhãn `ke-hoach-21-ngay` + `sprint-1/2/3`; mỗi task có Assignee, Priority, Start date, Due date, Epic cha, mô tả (bối cảnh, tiêu chí nghiệm thu, deliverable, nhánh Git) và link file nhiệm vụ.
- Dùng lại **6 Epic có sẵn** (SCRUM-5, 6, 7, 8, 9, 184) – không tạo Epic trùng.
- Đã tạo **80 liên kết phụ thuộc** loại *Blocks* (task phụ thuộc hiện *is blocked by*).
- **Kế hoạch cũ 4 tuần giữ nguyên** (48 Task, 140 Subtask, sprint *Tuần 1–4*, *SCRUM Sprint 0* đang chạy) theo yêu cầu không đụng dữ liệu cũ. Lọc kế hoạch mới: JQL `project = SCRUM AND labels = ke-hoach-21-ngay`.
- **Việc Leader cần tự làm:** (1) *Complete sprint* cho `SCRUM Sprint 0` (task chưa xong chọn chuyển về Backlog); (2) bấm **Start sprint** cho `FV Sprint 1` sáng 06/11; (3) tùy chọn dọn kế hoạch cũ: chọn task cũ trùng việc → *Move to Backlog* hoặc gắn nhãn `ke-hoach-cu`.

## Thành viên cần có trong project

| Thành viên | Email |
|---|---|
| Nguyễn Phương Huy | jira@nguyenhuyth2k6.atlassian.net |
| Huỳnh Nhật Toàn | htoan2851@gmail.com |
| Đoàn Phương Thiên Ân | thienann2611@gmail.com |
| Trương Tuấn Dũng | dungtuanxz12345@gmail.com |
| Nguyễn Phạm Xuân Anh | modz06j.xuananhngxph@gmail.com |

## 1. Kiểm tra project Jira hiện tại

- Site: `nguyenhuyth2k6.atlassian.net`, project **SCRUM** (Scrum software project), board 1 – Backlog.
- Mở **Project settings → Issue types** để xem đã có *Epic, Story, Task, Sub-task* chưa. Nếu project là *team-managed*, Epic hiển thị ở khung *Timeline*.
- Mở **Project settings → Access/People**: phải có đủ 5 thành viên. Chưa có → **Add people** bằng email ở bảng thành viên (mỗi người nhận email mời, bấm Accept).

## 2. Tạo Epic (6 epic)

Backlog → khung *Epic* (bật bằng nút **Epic** trên thanh lọc) → **+ Create epic**. Tạo 6 epic ở bảng *Epic* phía dưới, gán người phụ trách epic.

## 3. Tạo Sprint

Backlog → **Create sprint** 3 lần:

| Sprint | Ngày bắt đầu | Ngày kết thúc | Mục tiêu (dán vào Sprint goal) |
|---|---|---|---|
| Sprint 1 – Nền tảng CSDL | 06/11/2026 | 12/11/2026 | Mọi bảng và stored procedure lõi của 5 module có trên main; chạy toàn bộ script trên CSDL trống không lỗi; xóa hết nhánh tồn đọng. |
| Sprint 2 – Đủ object & nối app với SQL Server thật | 13/11/2026 | 19/11/2026 | Đủ view/function/trigger/phần khó của 5 module; phân quyền 4 login; app chạy DB_MODE=sqlserver qua trọn kịch bản châm hàng → mua → nhả hàng → cảnh báo → báo cáo. |
| Sprint 3 – Kiểm thử, tài liệu, demo | 20/11/2026 | 26/11/2026 | Test Report có số liệu thật, đủ tài liệu bắt buộc của đề, Docker chạy được, tag v1.0, tổng duyệt demo và vấn đáp. |

Chỉ **Start sprint** cho Sprint 1 vào 06/11; Sprint 2 bắt đầu 13/11 sau khi **Complete sprint** 1 (task chưa xong chuyển sang Sprint 2).

## 4. Tạo Task và Sub-task

- Backlog → **+ Create issue** → loại **Task** → điền theo bảng tổng hợp mục 10: *Summary*, *Description* (dán phần Mô tả + Tiêu chí nghiệm thu + link file nhiệm vụ trên GitHub), *Assignee*, *Priority*, *Parent* (Epic), *Sprint*, *Start date*, *Due date*.
- Sub-task: mở task → **Add subtask** cho từng bước lớn trong mục *4. Các bước thực hiện* của file nhiệm vụ (nếu muốn theo dõi chi tiết; không bắt buộc).

## 5. Assign

Trong task, ô **Assignee** → chọn tên thành viên. Người chưa chấp nhận lời mời sẽ không hiện.

## 6. Priority

Ô **Priority**: Highest (chặn người khác/đường găng) · High (bắt buộc của đề) · Medium (cần cho chất lượng) · Low (tùy chọn).

## 7. Due Date / Start date

Ô **Due date** và **Start date** theo bảng. Nếu không thấy *Start date*: **Project settings → Issue types → Task → Fields** → thêm field *Start date*.

## 8. Dependency

Task → **Link issue** → chọn *is blocked by* → nhập mã task phụ thuộc (cột *Phụ thuộc* trong bảng). Task bị chặn hiện biểu tượng ⛔ trên board.

## 9. Trạng thái và theo dõi tiến độ

- Luồng: **To Do → In Progress → In Review** (đã mở PR) **→ Done** (PR đã merge, đạt tiêu chí nghiệm thu). Nếu board chưa có cột *In Review*: **Board settings → Columns → Add column**.
- Mỗi tối 21h (họp 15 phút): mỗi người kéo thẻ của mình đúng cột, comment 1 dòng tiến độ.
- Theo dõi: **Reports → Burndown chart** (Sprint), **Timeline** (theo Epic), lọc *Only my issues*.
- Liên kết GitHub: cài app **GitHub for Jira** (Apps → Explore more apps) để commit/PR có mã `SCRUM-xx` tự hiện trong task.

## Epic

| Mã | Epic | Phụ trách | Mã Jira |
|---|---|---|---|
| E1 | Người dùng & Bảo mật (auth, audit) | Toàn | SCRUM-5 |
| E2 | Sản phẩm & Tồn kho (inventory) | Huy | SCRUM-6 |
| E3 | Bán hàng & Thanh toán (sales) | Ân | SCRUM-7 |
| E4 | IoT & Chuỗi lạnh (iot) | Dũng | SCRUM-8 |
| E5 | Báo cáo & Kiểm thử (report, QA) | Anh | SCRUM-9 |
| E6 | Tích hợp, Triển khai & Tài liệu | Huy | SCRUM-184 |

## 10. Bảng tổng hợp task (46 task)

Mỗi dòng = 1 Jira Task. *Description* trên Jira = cột Mô tả + mục *Tiêu chí nghiệm thu* + link file nhiệm vụ.

| Mã | Summary | Description | Assignee | Priority | Sprint | Start Date | Due Date | Acceptance Criteria | Dependencies | Epic | File nhiệm vụ |
|---|---|---|---|---|---|---|---|---|---|---|---|
| FV-01 (SCRUM-195) | Họp chốt quyết định kỹ thuật và đưa bộ tài liệu NHIEM_VU_CHI_TIET lên repo | Repo đang có 3 điểm lệch làm script SQL không chạy được từ đầu: hai bảng máy (`inventory.Machine` và `iot.Machines`), hai cách gọi ngăn hàng (`Slot` trong SQL, `Column` trong API), và số thứ tự file trùng nhau (`07_procs_iot`, `07_procs_report`, `05_views_repo… | Huy (jira@nguyenhuyth2k6.atlassian.net) | Highest | Sprint 1 | 06/11/2026 | 06/11/2026 | ☐ 4 quyết định kỹ thuật có kết luận và được ghi trong MASTER_PLAN.md<br>☐ PR thư mục NHIEM_VU_CHI_TIET đã merge, CI xanh<br>☐ Sprint 1 đã Start trên Jira, đủ task, đủ người | – | E6 | `NHIEM_VU_CHI_TIET/TUAN_1/Huy_HopChot_BangVaProcInventory_ReviewMerge.md` |
| FV-02 (SCRUM-196) | Sửa bảng inventory: hạn dùng theo giờ, SlotStock, phiếu châm hàng, kiểu TVP, Temporal Table | `sql/02_tables_inventory.sql` hiện có 7 bảng khung (tạo ngày 21/10) nhưng thiếu những gì API cần (`app/api/test/fakeDb.js` dòng 145–245): hạn dùng theo giờ, tồn theo lô trong từng ngăn, phiếu châm hàng, kiểu TVP cho `sp_Restock`, lịch sử giá. Bảng `inventory.S… | Huy (jira@nguyenhuyth2k6.atlassian.net) | Highest | Sprint 1 | 07/11/2026 | 08/11/2026 | ☐ Không đổi tên/xóa cột mà TV3, TV5 đang dùng (Slot, SlotStock, StockBatch, Product.UnitPrice)<br>☐ Đủ 3 bảng mới + 1 TVP + Temporal<br>☐ Chạy lại 2 lần không lỗi<br>☐ CI xanh, PR đã merge | FV-01 (SCRUM-195) | E2 | `NHIEM_VU_CHI_TIET/TUAN_1/Huy_HopChot_BangVaProcInventory_ReviewMerge.md` |
| FV-03 (SCRUM-197) | 5 procedure inventory: AddProduct, UpdateProduct, UpdatePrice, AssignColumn, AddBatch | API `app/api/src/routes/inventory.js` đã gọi các procedure này; `fakeDb.js` dòng 145–196 là đặc tả chạy được (tham số, mã lỗi 50100–50113, cột trả về). Test API `app/api/test/inventory.test.js` (đã merge PR #13) kiểm tra đúng các mã lỗi này. | Huy (jira@nguyenhuyth2k6.atlassian.net) | High | Sprint 1 | 09/11/2026 | 10/11/2026 | ☐ 5 procedure dùng CREATE OR ALTER, chạy lại không lỗi<br>☐ Mỗi procedure có 1 ca đúng + 2 ca sai chạy đúng mã lỗi<br>☐ Tên tham số và cột trả về khớp fakeDb.js<br>☐ PR merge, CI xanh | FV-02 (SCRUM-196) | E2 | `NHIEM_VU_CHI_TIET/TUAN_1/Huy_HopChot_BangVaProcInventory_ReviewMerge.md` |
| FV-04 (SCRUM-198) | sp_Restock (TVP + transaction) và sp_RemoveExpired | `sp_Restock` là phần khó của TV2: nhận danh sách nhiều dòng (TVP), kiểm tra 7 điều kiện rồi ghi 3 bảng trong **một giao dịch** – sai 1 dòng là rollback hết. `sp_RemoveExpired` được job mỗi giờ gọi (`app/api/src/jobs.js`). | Huy (jira@nguyenhuyth2k6.atlassian.net) | High | Sprint 1 | 11/11/2026 | 12/11/2026 | ☐ Rollback toàn bộ khi 1 dòng lỗi (đếm RestockEvent trước/sau bằng nhau)<br>☐ Đủ 9 mã lỗi 50110–50118<br>☐ Có UPDLOCK khi đọc tồn<br>☐ PR merge, CI xanh | FV-03 (SCRUM-197) | E2 | `NHIEM_VU_CHI_TIET/TUAN_1/Huy_HopChot_BangVaProcInventory_ReviewMerge.md` |
| FV-05 (SCRUM-199) | Leader: review & merge các nhánh tồn đọng, chạy thử toàn bộ script trên CSDL trống | Trên GitHub còn 3 nhánh chưa merge: `tv4-iot` (3 commit, view + function iot), `tv3-sales` (2 commit, objects + concurrency demo), `check-nv-chua-hoan-thien-xa` (TV5, 25 file, sửa cả `03_foreign_keys.sql` và README). Nhánh càng chờ lâu càng dễ xung đột. | Huy (jira@nguyenhuyth2k6.atlassian.net) | Highest | Sprint 1 | 07/11/2026 | 12/11/2026 | ☐ 3 nhánh tồn đọng đã merge hoặc có Request changes ghi rõ lý do<br>☐ 12/11: main chạy toàn bộ script không lỗi trên CSDL trống<br>☐ Lỗi còn lại có GitHub Issue và người phụ trách | FV-01 (SCRUM-195) | E6 | `NHIEM_VU_CHI_TIET/TUAN_1/Huy_HopChot_BangVaProcInventory_ReviewMerge.md` |
| FV-06 (SCRUM-200) | Sửa bảng auth và tạo 02_tables_audit.sql (AuditLog, ChangeLog), bảng giao máy | Module auth/audit chưa có commit nào ngoài bảng khung ngày 21/10. `03_foreign_keys.sql` đang thêm FK vào `audit.AuditLog` và `audit.ChangeLog` – hai bảng chưa tồn tại nên script chạy tới file 03 là lỗi. API (`app/api/src/routes/auth.js`) cần thêm: muối mật khẩ… | Toàn (htoan2851@gmail.com) | Highest | Sprint 1 | 06/11/2026 | 08/11/2026 | ☐ auth.[User] có Salt, FailedLogins, LastLoginAt<br>☐ audit.AuditLog, audit.ChangeLog, auth.UserMachine tồn tại<br>☐ Chạy lại không lỗi<br>☐ PR merge, CI xanh | FV-01 (SCRUM-195) | E1 | `NHIEM_VU_CHI_TIET/TUAN_1/Toan_BangAuthAudit_ForeignKey_ProcAuth.md` |
| FV-07 (SCRUM-201) | Sửa 03_foreign_keys.sql cho khớp bảng thật (đang lỗi khi chạy từ đầu) | `sql/03_foreign_keys.sql` (tạo 21/10) tham chiếu 5 bảng không tồn tại: `audit.AuditLog`, `audit.ChangeLog` (FV-06 đã tạo), `iot.Device`, `iot.Alert` (bảng thật là `iot.Alerts`), `report.MachineStockSnapshot`. Nhánh TV5 cũng đang sửa file này – phải phối hợp vớ… | Toàn (htoan2851@gmail.com) | Highest | Sprint 1 | 09/11/2026 | 09/11/2026 | ☐ 03_foreign_keys chạy sạch trên CSDL trống<br>☐ Không còn tham chiếu bảng không tồn tại<br>☐ PR merge | FV-06 (SCRUM-200), FV-02 (SCRUM-196) | E1 | `NHIEM_VU_CHI_TIET/TUAN_1/Toan_BangAuthAudit_ForeignKey_ProcAuth.md` |
| FV-08 (SCRUM-202) | 10_procs_auth.sql: sp_Login, sp_CreateUser, sp_ChangePassword, sp_AssignMachine, sp_DeactivateUser + fn_HashPassword | Không có `auth.sp_Login` thì **không ai đăng nhập được** khi chạy app với SQL Server thật – đây là việc chặn cả nhóm. API gọi `sp_Login` bằng tài khoản Kiosk (quyền thấp nhất) và cần **2 bảng kết quả**: thông tin user và danh sách máy được giao. | Toàn (htoan2851@gmail.com) | Highest | Sprint 1 | 10/11/2026 | 12/11/2026 | ☐ sp_Login trả đúng 2 bảng kết quả<br>☐ Mật khẩu chỉ lưu dạng băm + muối<br>☐ Đủ mã lỗi 50001–50031<br>☐ 3 tài khoản demo đăng nhập được<br>☐ PR merge | FV-06 (SCRUM-200) | E1 | `NHIEM_VU_CHI_TIET/TUAN_1/Toan_BangAuthAudit_ForeignKey_ProcAuth.md` |
| FV-09 (SCRUM-203) | Đưa nhánh tv3-sales lên main: cập nhật theo main, bỏ phần tạo bảng của inventory, mở PR | Nhánh `tv3-sales` có 2 commit chưa merge (05/11): `sql/22_objects_sales.sql` (fn_OrderTotal, trg_Orders_StatusGuard, vw_OrderDetail, vw_PendingOrders), `tests/60_concurrency_demo.sql`, `tests/tests_sales.sql`. File `12_procs_sales.sql` trên main đang tự tạo bả… | Ân (thienann2611@gmail.com) | High | Sprint 1 | 06/11/2026 | 08/11/2026 | ☐ Không còn tạo bảng của schema khác trong file sales<br>☐ PR merge vào main, CI xanh | FV-01 (SCRUM-195), FV-02 (SCRUM-196) | E3 | `NHIEM_VU_CHI_TIET/TUAN_1/An_MergeSales_DispenseQueue_Docker.md` |
| FV-10 (SCRUM-204) | Thêm sales.vw_DispenseQueue và đối chiếu cột 3 view sales với API | Bộ điều khiển máy (simulator ESP32 của TV4) hỏi hàng chờ nhả mỗi 1,5 giây qua `GET /api/dispense-queue` → đọc `sales.vw_DispenseQueue`. View này **chưa có** trong repo nên máy không bao giờ nhả hàng khi chạy SQL thật. | Ân (thienann2611@gmail.com) | High | Sprint 1 | 09/11/2026 | 10/11/2026 | ☐ View tồn tại, cột khớp fakeDb<br>☐ 3 test đúng<br>☐ PR merge | FV-09 (SCRUM-203) | E3 | `NHIEM_VU_CHI_TIET/TUAN_1/An_MergeSales_DispenseQueue_Docker.md` |
| FV-11 (SCRUM-205) | Dockerfile cho API và docker-compose.yml (SQL Server + API) | Đề bắt buộc gói triển khai Docker; repo hiện **chưa có** Dockerfile. API là Node.js (chỉ phụ thuộc `mssql`) và tự phục vụ giao diện `app/web`, nên chỉ cần 1 container app + 1 container SQL Server. | Ân (thienann2611@gmail.com) | Medium | Sprint 1 | 11/11/2026 | 12/11/2026 | ☐ Build không lỗi<br>☐ Không commit mật khẩu thật<br>☐ README có hướng dẫn Docker<br>☐ PR merge | – | E6 | `NHIEM_VU_CHI_TIET/TUAN_1/An_MergeSales_DispenseQueue_Docker.md` |
| FV-12 (SCRUM-206) | Đưa nhánh tv4-iot lên main, gộp file theo QĐ-3, sửa lệch gói telemetry (machineId/serial) | Nhánh `tv4-iot` có 3 commit chưa merge (01/11): `04_functions_iot.sql` (fn_RecentTelemetry), `05_views_iot.sql` (vw_MachineHealth, vw_OpenAlerts), ảnh Component/Deployment diagram. **Lỗi nghiêm trọng:** API gửi gói `{ machineId, readings }` (`app/api/src/route… | Dũng (dungtuanxz12345@gmail.com) | Highest | Sprint 1 | 06/11/2026 | 08/11/2026 | ☐ sp_IngestTelemetry nhận gói đúng định dạng API gửi<br>☐ File đặt tên theo QĐ-3<br>☐ PR merge, CI xanh | FV-01 (SCRUM-195) | E4 | `NHIEM_VU_CHI_TIET/TUAN_1/Dung_MergeIoT_SuaTelemetry_HopNhatBangMay.md` |
| FV-13 (SCRUM-207) | Hợp nhất bảng máy và địa điểm theo QĐ-1 (iot.Machines, iot.Locations) + view tương thích inventory.Machine | Hiện có 2 bảng máy: `inventory.Machine` (TV3, TV5 và seed dùng) và `iot.Machines` (TV4 dùng, có Serial, LocationId, Status, LastHeartbeat – khớp API). Hai bảng không đồng bộ → máy đăng ký ở trang *Máy* không xuất hiện ở *Châm hàng*. QĐ-1 (đề xuất): `iot.Machin… | Dũng (dungtuanxz12345@gmail.com) | Highest | Sprint 1 | 09/11/2026 | 10/11/2026 | ☐ Chỉ còn 1 bảng máy<br>☐ Code TV3/TV5 chạy không cần sửa (hoặc đã sửa)<br>☐ Chạy từ đầu không lỗi<br>☐ PR merge | FV-12 (SCRUM-206), FV-07 (SCRUM-201) | E4 | `NHIEM_VU_CHI_TIET/TUAN_1/Dung_MergeIoT_SuaTelemetry_HopNhatBangMay.md` |
| FV-14 (SCRUM-208) | fn_IsTempInRange và trigger trg_Machines_StatusChange (ghi lịch sử đổi trạng thái máy) | Kế hoạch giao TV4 2 function/trigger. Khi máy chuyển ACTIVE → DEGRADED/FAULT/OFFLINE cần ghi vết để Admin truy lại sự cố (đề: audit trail). | Dũng (dungtuanxz12345@gmail.com) | Medium | Sprint 1 | 11/11/2026 | 12/11/2026 | ☐ 3 test đúng<br>☐ PR merge | FV-13 (SCRUM-207) | E4 | `NHIEM_VU_CHI_TIET/TUAN_1/Dung_MergeIoT_SuaTelemetry_HopNhatBangMay.md` |
| FV-15 (SCRUM-209) | Đưa nhánh TV5 lên main sạch: bỏ phần tạo bảng của module khác, trỏ báo cáo về bảng thật | Nhánh `check-nv-chua-hoan-thien-xa` (1 commit, 04/11, 25 file) có kết quả kiểm thử thật rất tốt (21/21 PASS, đo hiệu năng). Nhưng file `sql/04_report_dependencies.sql` **tự tạo bảng của module khác**: `inventory.Locations`, `iot.TelemetryHourly`, `sales.Dispen… | Anh (modz06j.xuananhngxph@gmail.com) | Highest | Sprint 1 | 06/11/2026 | 09/11/2026 | ☐ Không còn tạo bảng/index của schema khác<br>☐ Commit hiện đúng tên Anh<br>☐ PR merge, CI xanh | FV-01 (SCRUM-195) | E5 | `NHIEM_VU_CHI_TIET/TUAN_1/Anh_MergeReport_ThuTuFile_TestPlan.md` |
| FV-16 (SCRUM-210) | Chuẩn hóa tên/số thứ tự file SQL theo QĐ-3 và cập nhật README, app/README | Hiện có các tên trùng số: `07_procs_iot` / `07_procs_report`, `05_views_report` / `05_seed_small` (nhánh TV5), seed có 2 bộ (05/06 và 09). README gốc liệt kê file không tồn tại; `app/README.md` vẫn bảo chạy `FreshVend_FULL.sql` (không có trong repo). | Anh (modz06j.xuananhngxph@gmail.com) | High | Sprint 1 | 10/11/2026 | 10/11/2026 | ☐ Tên file khớp bảng MASTER_PLAN<br>☐ README đúng thực tế<br>☐ PR merge | FV-15 (SCRUM-209), FV-12 (SCRUM-206) | E5 | `NHIEM_VU_CHI_TIET/TUAN_1/Anh_MergeReport_ThuTuFile_TestPlan.md` |
| FV-17 (SCRUM-211) | Test Plan tổng: phạm vi, môi trường, ca kiểm thử từng module, tiêu chí đạt | Đề bắt buộc Test Plan (Unit, Integration, Performance). `docs/TestPlan.md` hiện chỉ có phần report. Test Plan phải viết **trước** khi chạy test tuần 2–3. | Anh (modz06j.xuananhngxph@gmail.com) | Medium | Sprint 1 | 11/11/2026 | 12/11/2026 | ☐ Có đủ 3 loại kiểm thử + tiêu chí đạt | FV-01 (SCRUM-195) | E5 | `NHIEM_VU_CHI_TIET/TUAN_1/Anh_MergeReport_ThuTuFile_TestPlan.md` |
| FV-18 (SCRUM-212) | 21_objects_inventory: 4 view, fn_PriceHistory, fn_GetFifoStock, trigger cảnh báo sắp hết hàng | API đọc dữ liệu tồn kho chỉ qua view (`ctx.view(...)`); kiosk của TV3 đọc `inventory.vw_StockStatus`. `fn_GetFifoStock` được `sales.sp_CreateOrder` dùng để lấy lô cũ nhất. | Huy (jira@nguyenhuyth2k6.atlassian.net) | High | Sprint 2 | 13/11/2026 | 15/11/2026 | ☐ Tên view/cột khớp fakeDb.js<br>☐ Trigger xử lý đúng khi UPDATE nhiều dòng<br>☐ Kiosk hiển thị đúng khi chạy với SQL thật<br>☐ PR merge, CI xanh | FV-04 (SCRUM-198), FV-13 (SCRUM-207) | E2 | `NHIEM_VU_CHI_TIET/TUAN_2/Huy_ObjectInventory_TichHopSQLServer.md` |
| FV-19 (SCRUM-213) | Index inventory và file test tests_inventory.sql | Kế hoạch yêu cầu mỗi module có index cho bảng của mình và file test SQL (1 ca đúng + 2 ca sai/procedure). Anh dùng file này trong `sp_RunAllTests` và báo cáo hiệu năng. | Huy (jira@nguyenhuyth2k6.atlassian.net) | Medium | Sprint 2 | 16/11/2026 | 16/11/2026 | ☐ 21/21 PASS, chạy lặp lại được<br>☐ Index tạo được, chạy lại không lỗi | FV-18 (SCRUM-212) | E2 | `NHIEM_VU_CHI_TIET/TUAN_2/Huy_ObjectInventory_TichHopSQLServer.md` |
| FV-20 (SCRUM-214) | Tích hợp: chạy app với SQL Server thật (DB_MODE=sqlserver), phân loại lỗi theo module | Từ đầu dự án app chỉ chạy với CSDL giả lập (`fakeDb.js`). Đây là lần đầu nối `app/api/src/db.js` với SQL Server qua 4 login `fv_admin_app`, `fv_operator_app`, `fv_kiosk_app`, `fv_device_app` (do Toàn tạo ở FV-22). Leader là người chịu trách nhiệm tích hợp cuối… | Huy (jira@nguyenhuyth2k6.atlassian.net) | Highest | Sprint 2 | 17/11/2026 | 19/11/2026 | ☐ App chạy DB_MODE=sqlserver, 9 trang + kiosk mở được<br>☐ Mọi lỗi tìm thấy có GitHub Issue<br>☐ Lỗi mức Highest đã sửa trước 19/11 | FV-22 (SCRUM-216), FV-10 (SCRUM-204), FV-18 (SCRUM-212) | E6 | `NHIEM_VU_CHI_TIET/TUAN_2/Huy_ObjectInventory_TichHopSQLServer.md` |
| FV-21 (SCRUM-215) | 20_objects_auth.sql: vw_UserPermissions, audit.vw_LoginActivity, trigger ghi ChangeLog | Trang *Người dùng* đọc `auth.vw_UserPermissions`; Admin xem thống kê đăng nhập từ `audit.vw_LoginActivity`. Đề yêu cầu audit trail cho mọi thao tác thủ công – trigger của bạn là mẫu để cả nhóm dùng lại. | Toàn (htoan2851@gmail.com) | High | Sprint 2 | 13/11/2026 | 14/11/2026 | ☐ 2 view đúng cột API<br>☐ Trigger xử lý nhiều dòng, không ghi mật khẩu<br>☐ PR merge | FV-08 (SCRUM-202) | E1 | `NHIEM_VU_CHI_TIET/TUAN_2/Toan_ViewTrigger_PhanQuyenRLS_Backup.md` |
| FV-22 (SCRUM-216) | 40_security.sql: 4 login ứng dụng, database role, GRANT/DENY theo bảng ALLOW, Row-Level Security | Đề yêu cầu RBAC: Operator không được xem số liệu tài chính. API kết nối bằng 4 login tách biệt (`app/api/.env.example` dòng 23–30): `fv_admin_app`, `fv_operator_app`, `fv_kiosk_app`, `fv_device_app`. Quyền mỗi login phải **đúng y** bảng `ALLOW` trong `app/api/… | Toàn (htoan2851@gmail.com) | Highest | Sprint 2 | 15/11/2026 | 17/11/2026 | ☐ Quyền 4 login khớp bảng ALLOW<br>☐ RLS lọc đúng máy<br>☐ Chạy lại không lỗi<br>☐ PR merge | FV-21 (SCRUM-215), FV-18 (SCRUM-212), FV-10 (SCRUM-204), FV-12 (SCRUM-206) | E1 | `NHIEM_VU_CHI_TIET/TUAN_2/Toan_ViewTrigger_PhanQuyenRLS_Backup.md` |
| FV-23 (SCRUM-217) | 50_backup.sql (Full/Diff/Log) và 99_run_all.bat (tạo CSDL từ máy trống bằng 1 lệnh) | Đề yêu cầu 99,9% uptime và không mất dữ liệu → cần chiến lược sao lưu. Cả nhóm (và giảng viên) cần **một lệnh** để dựng CSDL từ đầu thay vì chạy tay 25 file. | Toàn (htoan2851@gmail.com) | High | Sprint 2 | 18/11/2026 | 19/11/2026 | ☐ 99_run_all.bat dựng CSDL sạch trong 1 lệnh<br>☐ 50_backup chạy được<br>☐ PR merge | FV-22 (SCRUM-216), FV-16 (SCRUM-210) | E1 | `NHIEM_VU_CHI_TIET/TUAN_2/Toan_ViewTrigger_PhanQuyenRLS_Backup.md` |
| FV-24 (SCRUM-218) | Chạy kịch bản bán hàng trên SQL thật và sửa procedure sales cho khớp API | 5 procedure sales đã có (12_procs_sales.sql) nhưng chưa từng chạy cùng procedure inventory thật (FIFO qua `fn_GetFifoStock` của TV2). Cần chứng minh luồng: tạo đơn → VietQR → xác nhận → nhả hàng → DISPENSED, và kẹt 3 lần → hoàn tiền. | Ân (thienann2611@gmail.com) | High | Sprint 2 | 13/11/2026 | 15/11/2026 | ☐ 4 test đúng trên SQL thật<br>☐ tests_sales.sql cập nhật, PASS hết<br>☐ PR merge | FV-10 (SCRUM-204), FV-04 (SCRUM-198), FV-18 (SCRUM-212) | E3 | `NHIEM_VU_CHI_TIET/TUAN_2/An_BanHangSQLThat_DemoDongThoi_DetailedDesign.md` |
| FV-25 (SCRUM-219) | Chuẩn hóa demo 2 phiên mua cùng lúc (UPDLOCK, mức cô lập) để trình bày khi bảo vệ | Phần khó TV3: chứng minh 2 kiosk mua ngăn cuối cùng cùng lúc không bán quá tồn. File `tests/60_concurrency_demo.sql` đã có (nhánh tv3-sales) với 3 procedure demo – cần chạy lại với schema sau FV-02/FV-24 và viết hướng dẫn 2 cửa sổ. | Ân (thienann2611@gmail.com) | Medium | Sprint 2 | 16/11/2026 | 17/11/2026 | ☐ Demo lặp lại được<br>☐ Có video | FV-24 (SCRUM-218) | E3 | `NHIEM_VU_CHI_TIET/TUAN_2/An_BanHangSQLThat_DemoDongThoi_DetailedDesign.md` |
| FV-26 (SCRUM-220) | Detailed Design: đặc tả API (Swagger), sequence diagram mua hàng, state diagram đơn hàng | Đề bắt buộc Detailed Design (API Specification, Database Schema, UI Wireframes). API đã có Swagger tại `/api-docs` (`app/api/src/openapi.js`); `docs/State.drawio` đã có từ 01/11. | Ân (thienann2611@gmail.com) | Medium | Sprint 2 | 18/11/2026 | 19/11/2026 | ☐ Đủ 3 phần API, sequence, state, wireframe | FV-24 (SCRUM-218) | E3 | `NHIEM_VU_CHI_TIET/TUAN_2/An_BanHangSQLThat_DemoDongThoi_DetailedDesign.md` |
| FV-27 (SCRUM-221) | Partition bảng iot.Telemetry theo tháng + sp_MaintainPartitions | Phần khó TV4. Đề: 1.000 máy × gửi 5 giây/lần → bảng Telemetry rất lớn. Partition theo tháng giúp xóa dữ liệu cũ nhanh (SWITCH/TRUNCATE partition) và truy vấn theo khoảng thời gian chỉ đọc partition cần. `app/api/src/jobs.js` đã nhắc `iot.sp_MaintainPartitions`… | Dũng (dungtuanxz12345@gmail.com) | High | Sprint 2 | 13/11/2026 | 15/11/2026 | ☐ Telemetry nằm trên partition scheme<br>☐ Procedure bảo trì chạy được<br>☐ PR merge | FV-13 (SCRUM-207) | E4 | `NHIEM_VU_CHI_TIET/TUAN_2/Dung_Partition_AgentJob_MoPhongESP32.md` |
| FV-28 (SCRUM-222) | 45_jobs.sql: 3 SQL Agent Job (mỗi phút, mỗi giờ, mỗi tháng) + phương án cho SQL Express | Hệ thống cần chạy định kỳ: đánh dấu máy OFFLINE, hủy đơn quá hạn (mỗi phút); gom số liệu giờ, rút hàng hết hạn, làm mới báo cáo (mỗi giờ); bảo trì partition (mỗi tháng). Danh sách procedure đúng như `app/api/src/jobs.js`. **SQL Server Express không có SQL Agen… | Dũng (dungtuanxz12345@gmail.com) | High | Sprint 2 | 16/11/2026 | 17/11/2026 | ☐ 3 job tạo được (Developer) hoặc fallback chạy (Express)<br>☐ Chạy lại file không tạo trùng job<br>☐ PR merge | FV-27 (SCRUM-221), FV-04 (SCRUM-198) | E4 | `NHIEM_VU_CHI_TIET/TUAN_2/Dung_Partition_AgentJob_MoPhongESP32.md` |
| FV-29 (SCRUM-223) | Mô phỏng ESP32 end-to-end với CSDL thật: 5 kịch bản (bình thường, quá nhiệt, mở cửa, kẹt hàng, mất mạng) | Đây là bằng chứng chính cho trụ cột IoT & chuỗi lạnh của đề. Nhóm không có phần cứng → dùng `app/simulator/esp32.js` gửi dữ liệu **mô phỏng** qua đúng giao thức mà ESP32 thật sẽ dùng (HTTP + JSON + header khóa thiết bị). Tất cả bằng chứng phải ghi rõ là mô phỏ… | Dũng (dungtuanxz12345@gmail.com) | Highest | Sprint 2 | 18/11/2026 | 19/11/2026 | ☐ 5/5 kịch bản đạt trên SQL thật<br>☐ Mỗi kịch bản có ảnh/video<br>☐ Mọi bằng chứng ghi 'dữ liệu mô phỏng' | FV-12 (SCRUM-206), FV-22 (SCRUM-216), FV-28 (SCRUM-222), FV-10 (SCRUM-204) | E4 | `NHIEM_VU_CHI_TIET/TUAN_2/Dung_Partition_AgentJob_MoPhongESP32.md` |
| FV-30 (SCRUM-224) | Cập nhật sp_RunAllTests phủ 5 module và seed nhỏ/lớn theo schema thật | `report.sp_RunAllTests` có 12 ca nhưng ca auth/inventory từng ghi PASS khi procedure chưa tồn tại, TC-11 (partition) luôn PASS. Trang *Kiểm thử hệ thống* của app hiển thị kết quả này – hội đồng có thể bấm chạy thử. | Anh (modz06j.xuananhngxph@gmail.com) | High | Sprint 2 | 13/11/2026 | 15/11/2026 | ☐ Không còn ca PASS giả<br>☐ Seed chạy qua procedure thật<br>☐ PR merge | FV-16 (SCRUM-210), FV-08 (SCRUM-202), FV-04 (SCRUM-198), FV-24 (SCRUM-218) | E5 | `NHIEM_VU_CHI_TIET/TUAN_2/Anh_RunAllTests_HieuNang_TichHopE2E.md` |
| FV-31 (SCRUM-225) | 70_perf_tests.sql: so sánh Execution Plan trước/sau index, đo thời gian truy vấn báo cáo trên dữ liệu lớn | Phần khó TV5 + yêu cầu phi chức năng: API ≤ 500 ms cho 95% request. Nhánh TV5 đã có `tests/sql/38_perf_report.sql` – chuyển thành `tests/70_perf_tests.sql` và đo lại trên schema mới (có partition của TV4, index của TV2). | Anh (modz06j.xuananhngxph@gmail.com) | Medium | Sprint 2 | 16/11/2026 | 17/11/2026 | ☐ Có bảng số liệu trước/sau<br>☐ Có ảnh Execution Plan | FV-30 (SCRUM-224), FV-19 (SCRUM-213), FV-27 (SCRUM-221) | E5 | `NHIEM_VU_CHI_TIET/TUAN_2/Anh_RunAllTests_HieuNang_TichHopE2E.md` |
| FV-32 (SCRUM-226) | Kiểm thử tích hợp end-to-end trên SQL thật: châm hàng → mua → thanh toán → nhả → cảnh báo → báo cáo | Kế hoạch yêu cầu cuối tuần 2–3 chạy một mạch kịch bản xuyên 5 module trên CSDL thật. Huy lo kết nối (FV-20), Anh là người **thực hiện và ghi bằng chứng** theo Test Plan. | Anh (modz06j.xuananhngxph@gmail.com) | Highest | Sprint 2 | 18/11/2026 | 19/11/2026 | ☐ 10/10 bước Pass trên SQL thật<br>☐ Mọi bước có ảnh | FV-20 (SCRUM-214), FV-29 (SCRUM-223) | E6 | `NHIEM_VU_CHI_TIET/TUAN_2/Anh_RunAllTests_HieuNang_TichHopE2E.md` |
| FV-33 (SCRUM-227) | Chuẩn bị demo phần khó TV2: Temporal Table, TVP rollback, FIFO (kèm video dự phòng) | Khi bảo vệ, hội đồng hỏi phần khó của từng người. Phần khó TV2 là Temporal Table + Table-Valued Parameter + FIFO. | Huy (jira@nguyenhuyth2k6.atlassian.net) | Medium | Sprint 3 | 20/11/2026 | 20/11/2026 | ☐ 3 khối chạy được trên CSDL sạch<br>☐ Có video ≤ 5 phút | FV-18 (SCRUM-212) | E2 | `NHIEM_VU_CHI_TIET/TUAN_3/Huy_DemoInventory_SRS_Release.md` |
| FV-34 (SCRUM-228) | Ghép URS/SRS tổng, User Story Tồn kho, User Manual Operator (phần tồn kho) | Đề bắt buộc URS/SRS và User Manual cho Operator. `docs/SRS.md` hiện là bản nháp 29 dòng (21/10). TV3 đã có `docs/UserStories_Sales.md` làm mẫu. | Huy (jira@nguyenhuyth2k6.atlassian.net) | High | Sprint 3 | 21/11/2026 | 23/11/2026 | ☐ SRS đủ 5 module + phi chức năng + ràng buộc<br>☐ User Manual có ảnh thật | FV-20 (SCRUM-214) | E6 | `NHIEM_VU_CHI_TIET/TUAN_3/Huy_DemoInventory_SRS_Release.md` |
| FV-35 (SCRUM-229) | Release v1.0: code freeze, tag, file .bak, gói nộp, tổng duyệt demo & vấn đáp | Đề yêu cầu nộp source code chạy được, gói Docker, tài liệu. Mỗi thành viên phải giải thích được toàn hệ thống trước hội đồng. | Huy (jira@nguyenhuyth2k6.atlassian.net) | Highest | Sprint 3 | 24/11/2026 | 26/11/2026 | ☐ Tag v1.0 trên GitHub<br>☐ Gói nộp đủ: source, .bak, docs, slide<br>☐ 2 buổi tổng duyệt đã làm, mỗi người trình bày được phần mình | FV-38 (SCRUM-232), FV-41 (SCRUM-235), FV-45 (SCRUM-239), FV-46 (SCRUM-240) | E6 | `NHIEM_VU_CHI_TIET/TUAN_3/Huy_DemoInventory_SRS_Release.md` |
| FV-36 (SCRUM-230) | tests_auth.sql + demo phần khó TV1: RLS và khôi phục dữ liệu về thời điểm trước sự cố (STOPAT) | Phần khó TV1 khi bảo vệ là RBAC + RLS + Backup/Restore. Cần kịch bản chạy được ngay trước hội đồng và video dự phòng. | Toàn (htoan2851@gmail.com) | High | Sprint 3 | 20/11/2026 | 21/11/2026 | ☐ 18/18 PASS<br>☐ Demo STOPAT chạy được trên máy sạch<br>☐ Có video | FV-22 (SCRUM-216), FV-23 (SCRUM-217) | E1 | `NHIEM_VU_CHI_TIET/TUAN_3/Toan_TestBaoMat_ERD_InstallGuide.md` |
| FV-37 (SCRUM-231) | ERD toàn hệ thống + Data Dictionary (từ CSDL thật) | Đề bắt buộc ERD trong tài liệu kiến trúc. Vẽ từ CSDL **đã chạy thật** để không lệch với code. | Toàn (htoan2851@gmail.com) | High | Sprint 3 | 22/11/2026 | 23/11/2026 | ☐ ERD đủ 6 schema, khớp CSDL thật<br>☐ Data Dictionary đủ bảng | FV-20 (SCRUM-214) | E6 | `NHIEM_VU_CHI_TIET/TUAN_3/Toan_TestBaoMat_ERD_InstallGuide.md` |
| FV-38 (SCRUM-232) | InstallGuide: cài đặt từ máy trống (SQL Server, Node.js, chạy CSDL, chạy app, simulator) | `docs/InstallGuide.md` hiện 35 dòng khung. Hội đồng có thể yêu cầu cài trên máy khác. Hướng dẫn phải được **một người chưa từng cài** làm theo thành công. | Toàn (htoan2851@gmail.com) | High | Sprint 3 | 24/11/2026 | 25/11/2026 | ☐ Người khác làm theo thành công<br>☐ Có bảng lỗi thường gặp | FV-23 (SCRUM-217) | E6 | `NHIEM_VU_CHI_TIET/TUAN_3/Toan_TestBaoMat_ERD_InstallGuide.md` |
| FV-39 (SCRUM-233) | User Manual Khách hàng (màn hình kiosk) có ảnh chạy SQL thật | Đề yêu cầu User Manual riêng cho Customer, Operator, Admin. | Ân (thienann2611@gmail.com) | Medium | Sprint 3 | 20/11/2026 | 21/11/2026 | ☐ Đủ 6 tình huống, có ảnh thật | FV-20 (SCRUM-214) | E3 | `NHIEM_VU_CHI_TIET/TUAN_3/An_UserManualKhach_Slide_KiemThuDocker.md` |
| FV-40 (SCRUM-234) | Slide bảo vệ (15–20 trang) + phân công người trình bày | Slide dẫn dắt buổi bảo vệ; mỗi thành viên trình bày phần mình ~3 phút. | Ân (thienann2611@gmail.com) | High | Sprint 3 | 22/11/2026 | 24/11/2026 | ☐ Đủ phần của 5 người<br>☐ Không tuyên bố đã thử phần cứng thật | FV-34 (SCRUM-228), FV-43 (SCRUM-237), FV-45 (SCRUM-239) | E6 | `NHIEM_VU_CHI_TIET/TUAN_3/An_UserManualKhach_Slide_KiemThuDocker.md` |
| FV-41 (SCRUM-235) | Kiểm thử Docker trên máy sạch và sửa lỗi | Gói Docker là sản phẩm phải nộp; cần chứng minh chạy được ngoài máy người viết. | Ân (thienann2611@gmail.com) | Medium | Sprint 3 | 25/11/2026 | 25/11/2026 | ☐ Chạy được trên máy sạch | FV-11 (SCRUM-205), FV-23 (SCRUM-217) | E6 | `NHIEM_VU_CHI_TIET/TUAN_3/An_UserManualKhach_Slide_KiemThuDocker.md` |
| FV-42 (SCRUM-236) | tests_iot.sql + kiểm tra Offline Mode / thông báo 'Tạm ngưng' trên kiosk | Đề yêu cầu *Offline Mode* (hiện “Out of Order” khi mất kết nối hoặc hỏng làm lạnh). Kiosk đọc `iot.vw_MachineHealth` để quyết định có bán hay không. | Dũng (dungtuanxz12345@gmail.com) | High | Sprint 3 | 20/11/2026 | 21/11/2026 | ☐ 21/21 PASS<br>☐ Offline Mode hoạt động | FV-29 (SCRUM-223) | E4 | `NHIEM_VU_CHI_TIET/TUAN_3/Dung_TestIoT_KienTruc_FirmwareThamChieu.md` |
| FV-43 (SCRUM-237) | Tài liệu kiến trúc: Component & Deployment Diagram, chương IoT & giới hạn phần cứng, User Manual Operator (máy & cảnh báo) | Nhánh tv4-iot đã có `docs/component_diagram.png`, `docs/deployment_diagram.png` (01/11) – cần cập nhật theo kiến trúc thật: Web (admin/kiosk) → API Node.js → SQL Server (4 login) ← simulator ESP32; Docker. | Dũng (dungtuanxz12345@gmail.com) | High | Sprint 3 | 22/11/2026 | 24/11/2026 | ☐ Diagram khớp hệ thống thật<br>☐ Chương IoT ghi rõ phần mô phỏng | FV-29 (SCRUM-223) | E4 | `NHIEM_VU_CHI_TIET/TUAN_3/Dung_TestIoT_KienTruc_FirmwareThamChieu.md` |
| FV-44 (SCRUM-238) | (Tùy chọn) Firmware ESP32 tham chiếu – cùng giao thức với simulator, chỉ biên dịch, chưa nạp thiết bị | Đề liệt kê sản phẩm *Automated Hardware Controller (ESP32)*. Nhóm không có thiết bị, nên chỉ làm **mã tham chiếu** để chứng minh hiểu giao thức. Làm khi FV-29, FV-42, FV-43 đã xong; nếu thiếu thời gian thì bỏ, ghi vào phần *Hạn chế* của báo cáo. | Dũng (dungtuanxz12345@gmail.com) | Low | Sprint 3 | 25/11/2026 | 26/11/2026 | ☐ Biên dịch được<br>☐ Ghi rõ chưa thử phần cứng | FV-29 (SCRUM-223) | E4 | `NHIEM_VU_CHI_TIET/TUAN_3/Dung_TestIoT_KienTruc_FirmwareThamChieu.md` |
| FV-45 (SCRUM-239) | Test Report với kết quả thật: unit (SQL + npm test), integration, performance, chuỗi lạnh (mô phỏng) | `docs/TestReport.md` trên main ghi 12/12 PASS dù procedure auth/inventory chưa tồn tại lúc đó. Bản nộp phải là số liệu chạy thật, có ngày giờ, môi trường, log. | Anh (modz06j.xuananhngxph@gmail.com) | Highest | Sprint 3 | 20/11/2026 | 22/11/2026 | ☐ Mọi số liệu có ngày chạy thật<br>☐ Không ghi PASS cho ca chưa chạy | FV-32 (SCRUM-226), FV-31 (SCRUM-225), FV-36 (SCRUM-230), FV-42 (SCRUM-236) | E5 | `NHIEM_VU_CHI_TIET/TUAN_3/Anh_TestReport_UserManualAdmin_BaoCao.md` |
| FV-46 (SCRUM-240) | User Manual Admin + ghép Báo cáo tổng (BaoCao) từ tài liệu của cả nhóm | `docs/UserManual.md` hiện có phần báo cáo của TV5. Báo cáo tổng phải gom URS/SRS, kiến trúc, ERD, thiết kế chi tiết, triển khai, kiểm thử, cài đặt, 3 user manual. | Anh (modz06j.xuananhngxph@gmail.com) | High | Sprint 3 | 23/11/2026 | 25/11/2026 | ☐ Báo cáo đủ mục, thống nhất tên/ngày | FV-34 (SCRUM-228), FV-37 (SCRUM-231), FV-43 (SCRUM-237), FV-45 (SCRUM-239) | E6 | `NHIEM_VU_CHI_TIET/TUAN_3/Anh_TestReport_UserManualAdmin_BaoCao.md` |

## 11. Ánh xạ mã kế hoạch → mã Jira

| Mã kế hoạch | Mã Jira |
|---|---|
| FV-01 | SCRUM-195 |
| FV-02 | SCRUM-196 |
| FV-03 | SCRUM-197 |
| FV-04 | SCRUM-198 |
| FV-05 | SCRUM-199 |
| FV-06 | SCRUM-200 |
| FV-07 | SCRUM-201 |
| FV-08 | SCRUM-202 |
| FV-09 | SCRUM-203 |
| FV-10 | SCRUM-204 |
| FV-11 | SCRUM-205 |
| FV-12 | SCRUM-206 |
| FV-13 | SCRUM-207 |
| FV-14 | SCRUM-208 |
| FV-15 | SCRUM-209 |
| FV-16 | SCRUM-210 |
| FV-17 | SCRUM-211 |
| FV-18 | SCRUM-212 |
| FV-19 | SCRUM-213 |
| FV-20 | SCRUM-214 |
| FV-21 | SCRUM-215 |
| FV-22 | SCRUM-216 |
| FV-23 | SCRUM-217 |
| FV-24 | SCRUM-218 |
| FV-25 | SCRUM-219 |
| FV-26 | SCRUM-220 |
| FV-27 | SCRUM-221 |
| FV-28 | SCRUM-222 |
| FV-29 | SCRUM-223 |
| FV-30 | SCRUM-224 |
| FV-31 | SCRUM-225 |
| FV-32 | SCRUM-226 |
| FV-33 | SCRUM-227 |
| FV-34 | SCRUM-228 |
| FV-35 | SCRUM-229 |
| FV-36 | SCRUM-230 |
| FV-37 | SCRUM-231 |
| FV-38 | SCRUM-232 |
| FV-39 | SCRUM-233 |
| FV-40 | SCRUM-234 |
| FV-41 | SCRUM-235 |
| FV-42 | SCRUM-236 |
| FV-43 | SCRUM-237 |
| FV-44 | SCRUM-238 |
| FV-45 | SCRUM-239 |
| FV-46 | SCRUM-240 |
