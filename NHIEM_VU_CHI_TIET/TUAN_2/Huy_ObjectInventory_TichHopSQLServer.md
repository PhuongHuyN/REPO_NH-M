# Huy – Tuần 2: Sprint 2 – Đủ object & nối app với SQL Server thật

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Nguyễn Phương Huy
- **Email:** jira@nguyenhuyth2k6.atlassian.net
- **Tuần:** 2 (Sprint 2 – Đủ object & nối app với SQL Server thật)
- **Thời gian:** 13/11/2026 → 19/11/2026
- **Vai trò:** Leader – TV2 Sản phẩm & Tồn kho (schema inventory) + Tích hợp hệ thống, review & merge PR
- **Mức độ ưu tiên:** Highest
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-212, SCRUM-213, SCRUM-214

**Mục tiêu Sprint:** Đủ view/function/trigger/phần khó của 5 module; phân quyền 4 login; app chạy DB_MODE=sqlserver qua trọn kịch bản châm hàng → mua → nhả hàng → cảnh báo → báo cáo.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-18 (SCRUM-212) | 21_objects_inventory: 4 view, fn_PriceHistory, fn_GetFifoStock, trigger cảnh báo sắp hết hàng | 13/11/2026 | 15/11/2026 | High | FV-04, FV-13 |
| FV-19 (SCRUM-213) | Index inventory và file test tests_inventory.sql | 16/11/2026 | 16/11/2026 | Medium | FV-18 |
| FV-20 (SCRUM-214) | Tích hợp: chạy app với SQL Server thật (DB_MODE=sqlserver), phân loại lỗi theo module | 17/11/2026 | 19/11/2026 | Highest | FV-22, FV-10, FV-18 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-18 (SCRUM-212) – 21_objects_inventory: 4 view, fn_PriceHistory, fn_GetFifoStock, trigger cảnh báo sắp hết hàng

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 13/11/2026 → 15/11/2026 |
| Mức ưu tiên | High |
| Epic | E2 – Sản phẩm & Tồn kho (inventory) |
| Phụ thuộc | FV-04 (SCRUM-198) (Huy), FV-13 (SCRUM-207) (Dũng) |
| Người hỗ trợ | Ân |

### 1. MỤC TIÊU
21_objects_inventory: 4 view, fn_PriceHistory, fn_GetFifoStock, trigger cảnh báo sắp hết hàng. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
API đọc dữ liệu tồn kho chỉ qua view (`ctx.view(...)`); kiosk của TV3 đọc `inventory.vw_StockStatus`. `fn_GetFifoStock` được `sales.sp_CreateOrder` dùng để lấy lô cũ nhất.

### 3. PHẠM VI CÔNG VIỆC
- Tạo `sql/21_objects_inventory.sql`.
- View: `vw_ProductCatalog`, `vw_StockStatus`, `vw_AvailableBatches`, `vw_ExpiringBatches` – tên cột y hệt fakeDb.js dòng 534–565.
- Function: `fn_PriceHistory(@ProductId)` (FOR SYSTEM_TIME ALL), `fn_GetFifoStock(@ColumnId)`.
- Trigger `trg_SlotStock_LowStock` AFTER UPDATE trên `inventory.SlotStock`: tồn ≤ 20% sức chứa → chèn `iot.Alerts` loại `LOW_STOCK`, không trùng.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. vw_StockStatus**
- **Đặc tả:** fakeDb.js dòng 537–550. Cột: `MachineId, Serial, MachineName, MachineStatus, ColumnId, ColumnNo, Capacity, ProductId, ProductName, Category, Description, Price, ImageUrl, Remaining, ExpiredQty, FillPercent, NearestExpiry, StockLabel`.
- **Cách làm:** `SlotId AS ColumnId`, `CAST(SlotCode ...) AS ColumnNo` (theo QĐ-2), JOIN bảng máy theo QĐ-1. `StockLabel` = `CASE WHEN ProductId IS NULL THEN N'TRỐNG' WHEN Remaining = 0 THEN N'HẾT HÀNG' WHEN Remaining*5 <= Capacity THEN N'SẮP HẾT' ELSE N'CÒN HÀNG' END`.

**Bước 2. 3 view còn lại**
- `vw_ProductCatalog`: thêm `PriceSince` (= ValidFrom), `ColumnCount`.
- `vw_AvailableBatches`: lô còn hạn, `Available = Quantity - SUM(RestockItem.Qty)` > 0.
- `vw_ExpiringBatches`: lô có tồn và hết hạn trong 6 giờ; `HoursLeft = DATEDIFF(MINUTE, SYSDATETIME(), ExpiryAt)/60.0`; `ExpiryLabel` = `N'ĐÃ HẾT HẠN'`/`N'SẮP HẾT HẠN'`.

**Bước 3. 2 function**
```sql
CREATE OR ALTER FUNCTION inventory.fn_PriceHistory (@ProductId INT)
RETURNS TABLE AS RETURN
  SELECT ProductId, ProductName, UnitPrice AS Price, ValidFrom, ValidTo
  FROM inventory.Product FOR SYSTEM_TIME ALL WHERE ProductId = @ProductId;
GO
CREATE OR ALTER FUNCTION inventory.fn_GetFifoStock (@ColumnId INT)
RETURNS TABLE AS RETURN
  SELECT TOP (1) ss.StockId, ss.BatchId, ss.Quantity
  FROM inventory.SlotStock ss JOIN inventory.StockBatch b ON b.BatchId = ss.BatchId
  WHERE ss.SlotId = @ColumnId AND ss.Quantity > 0 AND b.ExpiryAt > SYSDATETIME()
  ORDER BY ss.LoadedAt, ss.StockId;
```

**Bước 4. Trigger LowStock**
- **Cách làm:** xử lý **nhiều dòng** qua bảng `inserted` (không dùng biến vô hướng). Chỉ chèn khi chưa có Alert `LOW_STOCK` đang mở cho cùng ngăn (`RefKey = 'COL:' + SlotId`).
- **Phối hợp:** hỏi Dũng tên cột `iot.Alerts` (AlertType, Severity, Message, RefKey, ResolvedAt).

**Bước 5. Đối chiếu với kiosk**
- Chạy app `DB_MODE=sqlserver` (sau FV-22) hoặc so cột bằng `SELECT TOP 1 * FROM inventory.vw_StockStatus` với fakeDb. Nhờ Ân mở kiosk kiểm tra hiển thị.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/21_objects_inventory.sql` (tạo mới)
- `app/api/test/fakeDb.js dòng 534–565, 645`
- `app/web/js/kiosk.js, app/web/js/pages/restock.js` (chỉ đọc – cột dùng trên giao diện)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** QĐ-1 bảng máy (FV-13 của Dũng), cột iot.Alerts. **Đầu ra cho:** Ân (sp_CreateOrder dùng fn_GetFifoStock; kiosk đọc vw_StockStatus), Toàn (GRANT SELECT các view cho r_operator, r_kiosk ở FV-22).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Cột view | SELECT TOP 1 * FROM inventory.vw_StockStatus | Đủ 18 cột đúng tên |
| 2 | FIFO | Châm lô A rồi lô B vào cùng ngăn; SELECT * FROM inventory.fn_GetFifoStock(@ngăn) | Trả lô A |
| 3 | LowStock | UPDATE SlotStock giảm còn 2/10 | Có 1 Alert LOW_STOCK; chạy lại không thêm dòng |
| 4 | Lịch sử giá | Đổi giá 2 lần; SELECT * FROM inventory.fn_PriceHistory(1) | ≥ 3 dòng |

**Kết quả cần lưu lại:** Ảnh SSMS 4 test + ảnh kiosk.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Tên view/cột khớp fakeDb.js
- [ ] Trigger xử lý đúng khi UPDATE nhiều dòng
- [ ] Kiosk hiển thị đúng khi chạy với SQL thật
- [ ] PR merge, CI xanh

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b feature/SCRUM-212-inventory-objects
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/21_objects_inventory.sql
git commit -m "feat(sql-inventory): 4 view, 2 function, trg LowStock"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-212-inventory-objects
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-212-inventory-objects`.
7. **Mô tả PR:** tiêu đề `[SCRUM-212] 21_objects_inventory: 4 view, fn_PriceHistory, fn_GetFifoStock, trigger cảnh báo sắp hết hàng`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-212`; dán ảnh bằng chứng: Ảnh SSMS 4 test + ảnh kiosk.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-212-inventory-objects
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-212 |
| Branch | `feature/SCRUM-212-inventory-objects` |
| Commit | `feat(sql-inventory): 4 view, 2 function, trg LowStock` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) – tự merge sau khi CI xanh và 1 bạn xem |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/21_objects_inventory.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 15/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-212
- **Bằng chứng hoàn thành:** Ảnh SSMS 4 test + ảnh kiosk
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-19 (SCRUM-213) – Index inventory và file test tests_inventory.sql

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 16/11/2026 → 16/11/2026 |
| Mức ưu tiên | Medium |
| Epic | E2 – Sản phẩm & Tồn kho (inventory) |
| Phụ thuộc | FV-18 (SCRUM-212) (Huy) |
| Người hỗ trợ | Anh |

### 1. MỤC TIÊU
Index inventory và file test tests_inventory.sql. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Kế hoạch yêu cầu mỗi module có index cho bảng của mình và file test SQL (1 ca đúng + 2 ca sai/procedure). Anh dùng file này trong `sp_RunAllTests` và báo cáo hiệu năng.

### 3. PHẠM VI CÔNG VIỆC
- `sql/30_index_inventory.sql`: index FIFO trên SlotStock (đã có từ TV3 – chỉ kiểm tra), index `StockBatch(ProductId, ExpiryAt)`, `RestockItem(BatchId)`.
- `tests/tests_inventory.sql`: 21 ca (7 procedure × 3), in PASS/FAIL.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Viết index**
```sql
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_StockBatch_Product_Expiry')
  CREATE INDEX IX_inventory_StockBatch_Product_Expiry ON inventory.StockBatch (ProductId, ExpiryAt) INCLUDE (Quantity);
```

**Bước 2. Mẫu 1 ca test**
```sql
BEGIN TRY
  BEGIN TRAN;
    EXEC inventory.sp_UpdatePrice @ProductId = 1, @NewPrice = 999999;
  ROLLBACK;
  PRINT N'PASS  sp_UpdatePrice đúng';
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK;
  PRINT N'FAIL  sp_UpdatePrice đúng: ' + ERROR_MESSAGE();
END CATCH
```
Ca sai: kiểm tra `ERROR_NUMBER() = 50104` thì PASS. **Mọi ca đều ROLLBACK** để không bẩn dữ liệu.

**Bước 3. Chạy**
- Mở `tests/tests_inventory.sql` trong SSMS → F5. Đếm số dòng PASS.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/30_index_inventory.sql` (tạo mới)
- `tests/tests_inventory.sql` (tạo mới)
- `tests/tests_sales.sql trên nhánh tv3-sales` (tham khảo mẫu)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu ra cho:** Anh (FV-30, FV-31) – gọi file test và đo hiệu năng.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Chạy file test | F5 tests_inventory.sql | 21/21 PASS |
| 2 | Chạy 2 lần | F5 lần 2 | Kết quả giống lần 1 (không bẩn dữ liệu) |

**Kết quả cần lưu lại:** Ảnh tab Messages 21 dòng PASS.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 21/21 PASS, chạy lặp lại được
- [ ] Index tạo được, chạy lại không lỗi

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b test/SCRUM-213-inventory-index-tests
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/30_index_inventory.sql tests/tests_inventory.sql
git commit -m "test(sql-inventory): index FIFO/hạn dùng + tests_inventory.sql"
```
5. **Push**
```powershell
git pull origin main
git push -u origin test/SCRUM-213-inventory-index-tests
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: test/SCRUM-213-inventory-index-tests`.
7. **Mô tả PR:** tiêu đề `[SCRUM-213] Index inventory và file test tests_inventory.sql`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-213`; dán ảnh bằng chứng: Ảnh tab Messages 21 dòng PASS.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d test/SCRUM-213-inventory-index-tests
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-213 |
| Branch | `test/SCRUM-213-inventory-index-tests` |
| Commit | `test(sql-inventory): index FIFO/hạn dùng + tests_inventory.sql` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) – tự merge sau khi CI xanh và 1 bạn xem |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/30_index_inventory.sql
- tests/tests_inventory.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 16/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-213
- **Bằng chứng hoàn thành:** Ảnh tab Messages 21 dòng PASS
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-20 (SCRUM-214) – Tích hợp: chạy app với SQL Server thật (DB_MODE=sqlserver), phân loại lỗi theo module

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 17/11/2026 → 19/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E6 – Tích hợp, Triển khai & Tài liệu |
| Phụ thuộc | FV-22 (SCRUM-216) (Toàn), FV-10 (SCRUM-204) (Ân), FV-18 (SCRUM-212) (Huy) |
| Người hỗ trợ | Toàn, Anh |

### 1. MỤC TIÊU
Tích hợp: chạy app với SQL Server thật (DB_MODE=sqlserver), phân loại lỗi theo module. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Từ đầu dự án app chỉ chạy với CSDL giả lập (`fakeDb.js`). Đây là lần đầu nối `app/api/src/db.js` với SQL Server qua 4 login `fv_admin_app`, `fv_operator_app`, `fv_kiosk_app`, `fv_device_app` (do Toàn tạo ở FV-22). Leader là người chịu trách nhiệm tích hợp cuối cùng.

### 3. PHẠM VI CÔNG VIỆC
- Cấu hình SQL Server nhận kết nối TCP và đăng nhập SQL.
- Điền `app/api/.env` (không commit).
- Chạy `npm start`, bấm toàn bộ 9 trang quản trị + kiosk.
- Mỗi lỗi → 1 GitHub Issue gán đúng module.
- Sửa lỗi phần chung (`db.js`, `config.js`) nếu có.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Bật TCP/IP và SQL Authentication**
- **SQL Server Configuration Manager** → *SQL Server Network Configuration* → *Protocols for MSSQLSERVER* (hoặc SQLEXPRESS) → **TCP/IP = Enabled**.
- **SSMS** → chuột phải server → *Properties* → *Security* → **SQL Server and Windows Authentication mode**.
- Khởi động lại dịch vụ SQL Server.

**Bước 2. Tạo CSDL sạch**
- Chạy `99_run_all.bat` (FV-23). Nếu chưa có thì chạy tay theo thứ tự trong MASTER_PLAN.md.

**Bước 3. Điền .env**
```powershell
cd C:\Users\Lenovo\Desktop\REPO_NH-M\app\api
copy .env.example .env
```
Sửa trong `.env`: `DB_MODE=sqlserver`, `DB_SERVER=localhost`, `DB_PORT=1433` (SQL Express: `DB_INSTANCE=SQLEXPRESS`, để trống `DB_PORT`), mật khẩu 4 login đúng như `40_security.sql`; máy dùng SQL Express thêm `JOBS_FALLBACK=true`.

**Bước 4. Chạy và kiểm tra**
```powershell
cd ..
npm start
```
Terminal phải in *đã kết nối FreshVendDB*. Mở http://localhost:3000/api/health → `ok`. Bấm lần lượt: Tổng quan, Sản phẩm, Châm hàng, Đơn hàng, Máy, Cảnh báo, Người dùng, Báo cáo, Kiểm thử; mở http://localhost:3000/kiosk mua 1 đơn.

**Bước 5. Ghi lỗi**
- GitHub → *Issues* → *New issue*. Tiêu đề `[sales] vw_OrderDetail thiếu cột PaidAt`. Nội dung: trang, thao tác, thông báo lỗi (F12 → Network → response). Gán người phụ trách module, nhãn `bug`.

### 5. FILE VÀ MODULE LIÊN QUAN
- `app/api/.env` (không commit)
- `app/api/src/db.js, app/api/src/config.js` (chỉ sửa khi lỗi chung)
- `app/README.md mục 1–2`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** Toàn (40_security, 99_run_all), mọi module đủ object. **Đầu ra:** danh sách Issue cho từng người sửa trong 18–19/11; Anh dùng kết quả cho FV-32.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Kết nối | GET /api/health | status ok, DB_MODE=sqlserver |
| 2 | 9 trang quản trị | Đăng nhập admin, mở từng trang | Không trang nào lỗi 500 |
| 3 | Phân quyền | Đăng nhập operator01, mở Báo cáo | Bị chặn 403 |

**Kết quả cần lưu lại:** Ảnh terminal 'đã kết nối FreshVendDB' + ảnh các trang.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] App chạy DB_MODE=sqlserver, 9 trang + kiosk mở được
- [ ] Mọi lỗi tìm thấy có GitHub Issue
- [ ] Lỗi mức Highest đã sửa trước 19/11

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b fix/SCRUM-214-tich-hop-sqlserver (chỉ khi phải sửa code chung)
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add app/api/src/db.js app/api/src/config.js
git commit -m "fix(api): điều chỉnh tích hợp SQL Server"
```
5. **Push**
```powershell
git pull origin main
git push -u origin fix/SCRUM-214-tich-hop-sqlserver (chỉ khi phải sửa code chung)
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: fix/SCRUM-214-tich-hop-sqlserver (chỉ khi phải sửa code chung)`.
7. **Mô tả PR:** tiêu đề `[SCRUM-214] Tích hợp: chạy app với SQL Server thật (DB_MODE=sqlserver), phân loại lỗi theo module`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-214`; dán ảnh bằng chứng: Ảnh terminal 'đã kết nối FreshVendDB' + ảnh các trang.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d fix/SCRUM-214-tich-hop-sqlserver (chỉ khi phải sửa code chung)
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-214 |
| Branch | `fix/SCRUM-214-tich-hop-sqlserver (chỉ khi phải sửa code chung)` |
| Commit | `fix(api): điều chỉnh tích hợp SQL Server` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) – tự merge sau khi CI xanh và 1 bạn xem |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- Danh sách GitHub Issues
- Ảnh chụp 9 trang chạy SQL thật

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 19/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-214
- **Bằng chứng hoàn thành:** Ảnh terminal 'đã kết nối FreshVendDB' + ảnh các trang
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
