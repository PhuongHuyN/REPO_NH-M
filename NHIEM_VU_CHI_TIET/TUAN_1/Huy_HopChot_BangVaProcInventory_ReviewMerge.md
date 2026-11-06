# Huy – Tuần 1: Sprint 1 – Nền tảng CSDL

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Nguyễn Phương Huy
- **Email:** jira@nguyenhuyth2k6.atlassian.net
- **Tuần:** 1 (Sprint 1 – Nền tảng CSDL)
- **Thời gian:** 06/11/2026 → 12/11/2026
- **Vai trò:** Leader – TV2 Sản phẩm & Tồn kho (schema inventory) + Tích hợp hệ thống, review & merge PR
- **Mức độ ưu tiên:** Highest
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-195, SCRUM-196, SCRUM-197, SCRUM-198, SCRUM-199

**Mục tiêu Sprint:** Mọi bảng và stored procedure lõi của 5 module có trên main; chạy toàn bộ script trên CSDL trống không lỗi; xóa hết nhánh tồn đọng.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-01 (SCRUM-195) | Họp chốt quyết định kỹ thuật và đưa bộ tài liệu NHIEM_VU_CHI_TIET lên repo | 06/11/2026 | 06/11/2026 | Highest | – |
| FV-02 (SCRUM-196) | Sửa bảng inventory: hạn dùng theo giờ, SlotStock, phiếu châm hàng, kiểu TVP, Temporal Table | 07/11/2026 | 08/11/2026 | Highest | FV-01 |
| FV-03 (SCRUM-197) | 5 procedure inventory: AddProduct, UpdateProduct, UpdatePrice, AssignColumn, AddBatch | 09/11/2026 | 10/11/2026 | High | FV-02 |
| FV-04 (SCRUM-198) | sp_Restock (TVP + transaction) và sp_RemoveExpired | 11/11/2026 | 12/11/2026 | High | FV-03 |
| FV-05 (SCRUM-199) | Leader: review & merge các nhánh tồn đọng, chạy thử toàn bộ script trên CSDL trống | 07/11/2026 | 12/11/2026 | Highest | FV-01 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-01 (SCRUM-195) – Họp chốt quyết định kỹ thuật và đưa bộ tài liệu NHIEM_VU_CHI_TIET lên repo

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 06/11/2026 → 06/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E6 – Tích hợp, Triển khai & Tài liệu |
| Phụ thuộc | Không |
| Người hỗ trợ | Toàn, Ân, Dũng, Anh |

### 1. MỤC TIÊU
Họp chốt quyết định kỹ thuật và đưa bộ tài liệu NHIEM_VU_CHI_TIET lên repo. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Repo đang có 3 điểm lệch làm script SQL không chạy được từ đầu: hai bảng máy (`inventory.Machine` và `iot.Machines`), hai cách gọi ngăn hàng (`Slot` trong SQL, `Column` trong API), và số thứ tự file trùng nhau (`07_procs_iot`, `07_procs_report`, `05_views_report`, `05_seed_small`...). Nếu không chốt ngay ngày đầu, cả 5 người sẽ viết theo 5 kiểu khác nhau.

### 3. PHẠM VI CÔNG VIỆC
- Tổ chức họp online 30 phút với 5 thành viên.
- Chốt 4 quyết định ở mục *Quyết định kỹ thuật* trong MASTER_PLAN.md.
- Ghi biên bản ngắn vào mục *Biên bản họp* cuối MASTER_PLAN.md.
- Đưa thư mục NHIEM_VU_CHI_TIET lên repo qua Pull Request.
- Tạo Sprint 1 trên Jira và gán task theo JIRA_GUIDE.md.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Chuẩn bị nội dung họp**
- **Làm ở đâu:** VS Code, mở `NHIEM_VU_CHI_TIET/MASTER_PLAN.md` mục *Quyết định kỹ thuật*.
- **Cách làm:** đọc trước 4 đề xuất (QĐ-1 bảng máy, QĐ-2 tên Slot/Column, QĐ-3 đánh số file, QĐ-4 dải mã lỗi). Gửi link file vào nhóm chat trước giờ họp.
- **Kết quả:** mọi người đọc trước khi vào họp.

**Bước 2. Họp và chốt**
- **Làm ở đâu:** Google Meet/Zalo call, 20h ngày 06/11.
- **Cách làm:** đi lần lượt QĐ-1 → QĐ-4. Mỗi quyết định chỉ có 2 lựa chọn: đồng ý đề xuất hoặc đề xuất khác (phải nêu lý do). Không chốt được thì Leader quyết.
- **Kết quả:** 4 quyết định có trạng thái *Đã chốt*.

**Bước 3. Ghi biên bản**
- **Mở file:** `NHIEM_VU_CHI_TIET/MASTER_PLAN.md`, mục cuối *Biên bản họp*.
- **Chỉnh sửa:** điền ngày, người tham dự, kết luận từng QĐ, ai làm gì tiếp.
- **Kết quả:** biên bản nằm trong repo, ai cũng xem được.

**Bước 4. Đưa thư mục lên GitHub**
- **Làm ở đâu:** Terminal VS Code tại `C:\Users\Lenovo\Desktop\REPO_NH-M`.
- **Cách làm:** theo mục 9 GitHub Workflow bên dưới, chỉ add thư mục `NHIEM_VU_CHI_TIET/`.
- **Kết quả:** PR được merge, thư mục có trên `main`.

**Bước 5. Mở Sprint 1 trên Jira**
- **Làm ở đâu:** Jira board SCRUM.
- **Cách làm:** theo `JIRA_GUIDE.md` mục 3 (tạo Sprint), kéo các task FV-01 → FV-17 vào Sprint 1, bấm **Start sprint** (06/11 → 12/11).
- **Kết quả:** board Sprint 1 có đủ 17 task, mỗi task có người phụ trách.

### 5. FILE VÀ MODULE LIÊN QUAN
- `NHIEM_VU_CHI_TIET/` (toàn bộ – tạo mới)
- `NHIEM_VU_CHI_TIET/MASTER_PLAN.md` (điền biên bản)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** cả 5 người đọc MASTER_PLAN.md trước họp. **Đầu ra:** 4 quyết định đã chốt – là đầu vào bắt buộc của FV-02, FV-06, FV-09, FV-12, FV-13, FV-15, FV-16.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Thư mục lên main | Mở repo trên GitHub, nhánh main | Thấy thư mục NHIEM_VU_CHI_TIET có đủ 21 file |
| 2 | Biên bản | Mở MASTER_PLAN.md mục Biên bản họp | Có ngày 06/11, 5 người tham dự, 4 QĐ có kết luận |
| 3 | Jira | Mở board SCRUM | Sprint 1 đang chạy, 17 task có Assignee |

**Kết quả cần lưu lại:** Link PR đã merge + ảnh chụp board Sprint 1.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 4 quyết định kỹ thuật có kết luận và được ghi trong MASTER_PLAN.md
- [ ] PR thư mục NHIEM_VU_CHI_TIET đã merge, CI xanh
- [ ] Sprint 1 đã Start trên Jira, đủ task, đủ người

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-195-nhiem-vu-chi-tiet
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add NHIEM_VU_CHI_TIET/ NHIEM_VU_CHI_TIET/MASTER_PLAN.md
git commit -m "docs: thêm bộ tài liệu NHIEM_VU_CHI_TIET và quyết định kỹ thuật"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-195-nhiem-vu-chi-tiet
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-195-nhiem-vu-chi-tiet`.
7. **Mô tả PR:** tiêu đề `[SCRUM-195] Họp chốt quyết định kỹ thuật và đưa bộ tài liệu NHIEM_VU_CHI_TIET lên repo`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-195`; dán ảnh bằng chứng: Link PR đã merge + ảnh chụp board Sprint 1.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-195-nhiem-vu-chi-tiet
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-195 |
| Branch | `docs/SCRUM-195-nhiem-vu-chi-tiet` |
| Commit | `docs: thêm bộ tài liệu NHIEM_VU_CHI_TIET và quyết định kỹ thuật` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) – tự merge sau khi CI xanh và 1 bạn xem |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- Biên bản họp trong MASTER_PLAN.md
- Thư mục NHIEM_VU_CHI_TIET trên main
- Sprint 1 trên Jira

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 06/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-195
- **Bằng chứng hoàn thành:** Link PR đã merge + ảnh chụp board Sprint 1
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-02 (SCRUM-196) – Sửa bảng inventory: hạn dùng theo giờ, SlotStock, phiếu châm hàng, kiểu TVP, Temporal Table

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 07/11/2026 → 08/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E2 – Sản phẩm & Tồn kho (inventory) |
| Phụ thuộc | FV-01 (SCRUM-195) (Huy) |
| Người hỗ trợ | Ân, Dũng |

### 1. MỤC TIÊU
Sửa bảng inventory: hạn dùng theo giờ, SlotStock, phiếu châm hàng, kiểu TVP, Temporal Table. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
`sql/02_tables_inventory.sql` hiện có 7 bảng khung (tạo ngày 21/10) nhưng thiếu những gì API cần (`app/api/test/fakeDb.js` dòng 145–245): hạn dùng theo giờ, tồn theo lô trong từng ngăn, phiếu châm hàng, kiểu TVP cho `sp_Restock`, lịch sử giá. Bảng `inventory.SlotStock` hiện do TV3 tạo tạm trong `12_procs_sales.sql` – đúng ra thuộc TV2.

### 3. PHẠM VI CÔNG VIỆC
- Thêm cột (không xóa, không đổi tên cột cũ): `Product.ShelfLifeHours`, `StockBatch.PreparedAt`, `StockBatch.ExpiryAt`.
- Khai báo `inventory.SlotStock` giống hệt định nghĩa của TV3 (có `IF OBJECT_ID ... IS NULL`).
- Tạo `inventory.RestockEvent`, `inventory.RestockItem`, kiểu `inventory.RestockItemType (ColumnId INT, BatchId INT, Qty SMALLINT)`.
- Bật SYSTEM_VERSIONING cho `inventory.Product` (bảng lịch sử `inventory.ProductHistory`).
- Áp dụng QĐ-1: nếu chốt dùng `iot.Machines` thì bỏ FK nội schema từ `inventory.Slot` sang `inventory.Machine` (FK mới do TV1 thêm ở 03).
- 10–20 dòng dữ liệu mẫu cho các bảng mới.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Tạo nhánh**
- **Làm ở đâu:** Terminal VS Code.
- **Cách làm:** xem mục 9, bước 1–3.
- **Kết quả:** đang ở nhánh `feature/FV-02-inventory-tables`.

**Bước 2. Thêm cột an toàn khi chạy lại**
- **Mở file:** `sql/02_tables_inventory.sql`, thêm vào **cuối file**.
- **Cách làm:**
```sql
IF COL_LENGTH(N'inventory.Product', N'ShelfLifeHours') IS NULL
    ALTER TABLE inventory.Product ADD ShelfLifeHours INT NOT NULL
        CONSTRAINT DF_inventory_Product_ShelfLifeHours DEFAULT 24
        CONSTRAINT CK_inventory_Product_ShelfLifeHours CHECK (ShelfLifeHours BETWEEN 1 AND 120);
GO
IF COL_LENGTH(N'inventory.StockBatch', N'PreparedAt') IS NULL
    ALTER TABLE inventory.StockBatch ADD PreparedAt DATETIME2(0) NULL, ExpiryAt DATETIME2(0) NULL;
GO
```
- **Kết quả:** chạy file 2 lần không báo lỗi.

**Bước 3. Khai báo SlotStock trùng khớp TV3**
- **Mở file:** cùng file. Chép nguyên khối `IF OBJECT_ID(N'inventory.SlotStock', N'U') IS NULL ... END;` từ `sql/12_procs_sales.sql` (dòng 42–60) sang.
- **Lưu ý:** giữ **y hệt** tên cột, kiểu dữ liệu, tên constraint. Chạy file nào trước cũng không lỗi.
- **Kết quả:** báo Ân (FV-09) xóa khối này khỏi `12_procs_sales.sql` sau khi PR này merge.

**Bước 4. Phiếu châm hàng và TVP**
- **Cách làm:**
```sql
IF OBJECT_ID(N'inventory.RestockEvent', N'U') IS NULL
CREATE TABLE inventory.RestockEvent (
  RestockId   INT IDENTITY CONSTRAINT PK_inventory_RestockEvent PRIMARY KEY,
  MachineId   INT NOT NULL,          -- FK sang bảng máy: thêm ở 03_foreign_keys (TV1)
  UserId      INT NOT NULL,          -- FK sang auth.[User]: thêm ở 03_foreign_keys (TV1)
  RestockedAt DATETIME2(0) NOT NULL CONSTRAINT DF_inventory_RestockEvent_At DEFAULT SYSDATETIME(),
  Note        NVARCHAR(200) NULL);
GO
IF OBJECT_ID(N'inventory.RestockItem', N'U') IS NULL
CREATE TABLE inventory.RestockItem (
  RestockItemId INT IDENTITY CONSTRAINT PK_inventory_RestockItem PRIMARY KEY,
  RestockId INT NOT NULL CONSTRAINT FK_inventory_RestockItem_Event REFERENCES inventory.RestockEvent(RestockId),
  SlotId    INT NOT NULL CONSTRAINT FK_inventory_RestockItem_Slot  REFERENCES inventory.Slot(SlotId),
  BatchId   INT NOT NULL CONSTRAINT FK_inventory_RestockItem_Batch REFERENCES inventory.StockBatch(BatchId),
  Qty       SMALLINT NOT NULL CONSTRAINT CK_inventory_RestockItem_Qty CHECK (Qty BETWEEN 1 AND 20));
GO
IF TYPE_ID(N'inventory.RestockItemType') IS NULL
  CREATE TYPE inventory.RestockItemType AS TABLE (ColumnId INT NOT NULL, BatchId INT NOT NULL, Qty SMALLINT NOT NULL);
GO
```
- **Lưu ý:** tên cột trong TVP phải là `ColumnId, BatchId, Qty` – đúng như `app/api/src/routes/inventory.js` dòng gọi `db.tvp('inventory.RestockItemType', ...)`.

**Bước 5. Bật Temporal Table cho Product**
- **Cách làm:**
```sql
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'inventory.Product') AND temporal_type = 2)
BEGIN
  ALTER TABLE inventory.Product ADD
    ValidFrom DATETIME2(0) GENERATED ALWAYS AS ROW START HIDDEN NOT NULL CONSTRAINT DF_inventory_Product_ValidFrom DEFAULT SYSUTCDATETIME(),
    ValidTo   DATETIME2(0) GENERATED ALWAYS AS ROW END   HIDDEN NOT NULL CONSTRAINT DF_inventory_Product_ValidTo   DEFAULT CONVERT(DATETIME2(0), '9999-12-31 23:59:59'),
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
  ALTER TABLE inventory.Product SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = inventory.ProductHistory));
END
GO
```
- **Kiểm tra:** `SELECT * FROM inventory.Product FOR SYSTEM_TIME ALL;` chạy được.

**Bước 6. Áp dụng QĐ-1 (bảng máy)**
- **Nếu chốt dùng `iot.Machines`:** trong file này, xóa FK nội schema `inventory.Slot.MachineId → inventory.Machine` (giữ cột `MachineId`). Bảng `inventory.Machine` **không xóa** trong tuần 1 – Dũng thay bằng view tương thích ở FV-13 sau khi Toàn đổi FK (FV-07).
- **Kết quả:** không có FK chéo schema nào trong file 02 của bạn.

**Bước 7. Dữ liệu mẫu và chạy thử**
- **Làm ở đâu:** SSMS. Tạo CSDL trống bằng `00_database.sql`, `01_schemas.sql`, rồi chạy lần lượt các file 02 theo bảng thứ tự trong MASTER_PLAN.md, sau đó `12_procs_sales.sql` của TV3.
- **Kết quả:** không lỗi; chạy lại `02_tables_inventory.sql` lần 2 vẫn không lỗi.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/02_tables_inventory.sql` (sửa)
- `sql/12_procs_sales.sql` (chỉ đọc, đối chiếu SlotStock)
- `app/api/test/fakeDb.js dòng 145–245, 534–565` (chỉ đọc)
- `app/api/src/routes/inventory.js` (chỉ đọc – tên cột TVP)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** QĐ-1, QĐ-2 (FV-01). **Đầu ra cho:** Ân (FV-09 xóa SlotStock khỏi file sales), Toàn (FV-07 thêm FK `RestockEvent.MachineId`, `RestockEvent.UserId`, `Slot.MachineId`), Dũng (FV-13 view tương thích).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Chạy lại file | Chạy 02_tables_inventory.sql 2 lần | Không lỗi lần 2 |
| 2 | Tương thích TV3 | Chạy 02_tables_inventory rồi 12_procs_sales | 12_procs_sales không lỗi, không tạo trùng SlotStock |
| 3 | Temporal | UPDATE inventory.Product SET UnitPrice = UnitPrice + 1000 WHERE ProductId = 1; rồi SELECT ... FOR SYSTEM_TIME ALL | Có 2 dòng cho ProductId 1 |
| 4 | CHECK hạn dùng | UPDATE inventory.Product SET ShelfLifeHours = 0 WHERE ProductId = 1 | Lỗi 547 (vi phạm CHECK) |

**Kết quả cần lưu lại:** Ảnh SSMS chạy file 2 lần không lỗi + kết quả FOR SYSTEM_TIME ALL.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Không đổi tên/xóa cột mà TV3, TV5 đang dùng (Slot, SlotStock, StockBatch, Product.UnitPrice)
- [ ] Đủ 3 bảng mới + 1 TVP + Temporal
- [ ] Chạy lại 2 lần không lỗi
- [ ] CI xanh, PR đã merge

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b feature/SCRUM-196-inventory-tables
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/02_tables_inventory.sql
git commit -m "feat(sql-inventory): thêm hạn dùng, SlotStock, RestockEvent/Item, TVP, Temporal"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-196-inventory-tables
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-196-inventory-tables`.
7. **Mô tả PR:** tiêu đề `[SCRUM-196] Sửa bảng inventory: hạn dùng theo giờ, SlotStock, phiếu châm hàng, kiểu TVP, Temporal Table`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-196`; dán ảnh bằng chứng: Ảnh SSMS chạy file 2 lần không lỗi + kết quả FOR SYSTEM_TIME ALL.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-196-inventory-tables
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-196 |
| Branch | `feature/SCRUM-196-inventory-tables` |
| Commit | `feat(sql-inventory): thêm hạn dùng, SlotStock, RestockEvent/Item, TVP, Temporal` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) – tự merge sau khi CI xanh và 1 bạn xem |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/02_tables_inventory.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 08/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-196
- **Bằng chứng hoàn thành:** Ảnh SSMS chạy file 2 lần không lỗi + kết quả FOR SYSTEM_TIME ALL
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-03 (SCRUM-197) – 5 procedure inventory: AddProduct, UpdateProduct, UpdatePrice, AssignColumn, AddBatch

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 09/11/2026 → 10/11/2026 |
| Mức ưu tiên | High |
| Epic | E2 – Sản phẩm & Tồn kho (inventory) |
| Phụ thuộc | FV-02 (SCRUM-196) (Huy) |
| Người hỗ trợ | Không |

### 1. MỤC TIÊU
5 procedure inventory: AddProduct, UpdateProduct, UpdatePrice, AssignColumn, AddBatch. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
API `app/api/src/routes/inventory.js` đã gọi các procedure này; `fakeDb.js` dòng 145–196 là đặc tả chạy được (tham số, mã lỗi 50100–50113, cột trả về). Test API `app/api/test/inventory.test.js` (đã merge PR #13) kiểm tra đúng các mã lỗi này.

### 3. PHẠM VI CÔNG VIỆC
- Tạo file mới `sql/11_procs_inventory.sql`.
- Viết 5 procedure đúng tên, tham số, mã lỗi, cột trả về như fakeDb.js.
- Mỗi procedure: `SET NOCOUNT ON; SET XACT_ABORT ON;` + `BEGIN TRY/BEGIN TRAN ... COMMIT` + `THROW 501xx`.
- Trả cột theo tên API dùng (`ColumnId`, `ColumnNo`, `Price`) bằng bí danh, không đổi tên cột bảng.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Mẫu chung cho mọi procedure**
- **Mở file:** tạo `sql/11_procs_inventory.sql`.
```sql
USE FreshVendDB;
GO
CREATE OR ALTER PROCEDURE inventory.sp_AddProduct
  @ProductName NVARCHAR(100), @Price DECIMAL(12,0), @ShelfLifeHours INT,
  @Category NVARCHAR(50) = NULL, @Description NVARCHAR(300) = NULL, @ImageUrl NVARCHAR(300) = NULL
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  SET @ProductName = LTRIM(RTRIM(@ProductName));
  IF @ProductName IS NULL OR @ProductName = N'' THROW 50100, N'Tên sản phẩm không được để trống', 1;
  IF EXISTS (SELECT 1 FROM inventory.Product WHERE ProductName = @ProductName) THROW 50101, N'Tên sản phẩm đã tồn tại', 1;
  IF @Price <= 0 THROW 50102, N'Giá bán phải lớn hơn 0', 1;
  IF @ShelfLifeHours NOT BETWEEN 1 AND 120 THROW 50108, N'Hạn sử dụng phải từ 1 đến 120 giờ', 1;
  BEGIN TRAN;
    -- INSERT inventory.Product (...) – map @Price vào cột UnitPrice, @Category vào CategoryId (tìm hoặc tạo)
  COMMIT;
  SELECT ProductId, ProductName, UnitPrice AS Price FROM inventory.Product WHERE ProductId = SCOPE_IDENTITY();
END
GO
```
- **Lưu ý:** collation `Vietnamese_CI_AS` nên so sánh tên đã không phân biệt hoa thường – giống fakeDb.

**Bước 2. sp_UpdateProduct**
- **Đặc tả:** fakeDb.js dòng 156–166. Lỗi 50103 (không tồn tại), 50100, 50101, 50108, **50109** (ngừng bán khi sản phẩm còn gán ở ngăn nào đó: `EXISTS (SELECT 1 FROM inventory.Slot WHERE ProductId = @ProductId)`).
- **Trả về:** toàn bộ dòng sản phẩm (giống `vw_ProductCatalog`).

**Bước 3. sp_UpdatePrice**
- **Đặc tả:** dòng 168–176. Lỗi 50103, 50102, **50104** (giá mới trùng giá hiện tại). Chỉ `UPDATE inventory.Product SET UnitPrice = @NewPrice` – Temporal tự lưu giá cũ.
- **Trả về:** `ProductId, OldPrice, NewPrice`.

**Bước 4. sp_AssignColumn**
- **Tham số:** `@ColumnId INT, @ProductId INT = NULL` (`@ColumnId` chính là `SlotId`).
- **Lỗi:** 50105 (ngăn không tồn tại hoặc Operator không được giao máy – đọc `SESSION_CONTEXT(N'UserId')` và bảng giao máy của TV1; trong tuần 1 nếu TV1 chưa có bảng thì chỉ kiểm tra tồn tại và để `-- TODO RLS FV-22`), 50107, **50106** (ngăn còn hàng: `EXISTS (SELECT 1 FROM inventory.SlotStock WHERE SlotId = @ColumnId AND Quantity > 0)`).
- **Trả về:** `SlotId AS ColumnId, MachineId, SlotCode AS ColumnNo, ProductId`.

**Bước 5. sp_AddBatch**
- **Đặc tả:** dòng 186–196. `ExpiryAt = DATEADD(HOUR, ShelfLifeHours, PreparedAt)`; `BatchCode = 'LO' + RIGHT('000000' + CAST(BatchId AS VARCHAR), 6)`. Lỗi 50107, **50113**.
- **Lưu ý:** cột `ImportDate`, `UnitCost` cũ là NOT NULL – điền `CAST(@PreparedAt AS DATE)` và `0`.

**Bước 6. Chạy thử trong SSMS**
- **Cách làm:** mỗi procedure gọi 1 lần đúng + 2 lần sai, ví dụ:
```sql
EXEC inventory.sp_AddProduct @ProductName = N'Bưởi da xanh', @Price = 42000, @ShelfLifeHours = 36;  -- đúng
EXEC inventory.sp_AddProduct @ProductName = N'bưởi da xanh', @Price = 42000, @ShelfLifeHours = 36;  -- 50101
EXEC inventory.sp_AddProduct @ProductName = N'Táo', @Price = 0, @ShelfLifeHours = 24;               -- 50102
```
- **Kết quả:** mã lỗi đúng như comment.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/11_procs_inventory.sql` (tạo mới)
- `app/api/test/fakeDb.js dòng 145–196` (đặc tả)
- `app/api/src/lib/errors.js` (mã lỗi → HTTP 404/409/400)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu ra cho:** Ân (FV-24 dùng sản phẩm/lô để test bán), Anh (FV-30 thêm ca test inventory vào `sp_RunAllTests`). Phần kiểm tra quyền theo máy chờ Toàn (FV-08 bảng giao máy).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | AddProduct đúng | @ProductName='Bưởi da xanh', @Price=42000, @ShelfLifeHours=36 | Trả ProductId mới, Price=42000 |
| 2 | AddProduct trùng | @ProductName='dưa hấu cắt miếng' | THROW 50101 |
| 3 | UpdatePrice trùng giá | @NewPrice = giá hiện tại | THROW 50104 |
| 4 | AssignColumn ngăn còn hàng | @ColumnId có SlotStock.Quantity>0 | THROW 50106 |
| 5 | AddBatch số lượng 0 | @Quantity=0 | THROW 50113 |

**Kết quả cần lưu lại:** Ảnh SSMS 15 lần gọi (5 × 3) với kết quả.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 5 procedure dùng CREATE OR ALTER, chạy lại không lỗi
- [ ] Mỗi procedure có 1 ca đúng + 2 ca sai chạy đúng mã lỗi
- [ ] Tên tham số và cột trả về khớp fakeDb.js
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
git checkout -b feature/SCRUM-197-inventory-procs
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/11_procs_inventory.sql
git commit -m "feat(sql-inventory): sp_AddProduct, sp_UpdateProduct, sp_UpdatePrice, sp_AssignColumn, sp_AddBatch"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-197-inventory-procs
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-197-inventory-procs`.
7. **Mô tả PR:** tiêu đề `[SCRUM-197] 5 procedure inventory: AddProduct, UpdateProduct, UpdatePrice, AssignColumn, AddBatch`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-197`; dán ảnh bằng chứng: Ảnh SSMS 15 lần gọi (5 × 3) với kết quả.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-197-inventory-procs
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-197 |
| Branch | `feature/SCRUM-197-inventory-procs` |
| Commit | `feat(sql-inventory): sp_AddProduct, sp_UpdateProduct, sp_UpdatePrice, sp_AssignColumn, sp_AddBatch` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) – tự merge sau khi CI xanh và 1 bạn xem |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/11_procs_inventory.sql (5 procedure)

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 10/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-197
- **Bằng chứng hoàn thành:** Ảnh SSMS 15 lần gọi (5 × 3) với kết quả
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-04 (SCRUM-198) – sp_Restock (TVP + transaction) và sp_RemoveExpired

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 11/11/2026 → 12/11/2026 |
| Mức ưu tiên | High |
| Epic | E2 – Sản phẩm & Tồn kho (inventory) |
| Phụ thuộc | FV-03 (SCRUM-197) (Huy) |
| Người hỗ trợ | Không |

### 1. MỤC TIÊU
sp_Restock (TVP + transaction) và sp_RemoveExpired. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
`sp_Restock` là phần khó của TV2: nhận danh sách nhiều dòng (TVP), kiểm tra 7 điều kiện rồi ghi 3 bảng trong **một giao dịch** – sai 1 dòng là rollback hết. `sp_RemoveExpired` được job mỗi giờ gọi (`app/api/src/jobs.js`).

### 3. PHẠM VI CÔNG VIỆC
- Thêm 2 procedure vào `sql/11_procs_inventory.sql`.
- Mã lỗi 50110–50118 đúng fakeDb.js dòng 197–245.
- Ghi `RestockEvent`, `RestockItem`, `SlotStock` trong 1 transaction.
- `sp_RemoveExpired` đưa Quantity của lô hết hạn về 0 và tạo cảnh báo `EXPIRY` trong `iot.Alerts`.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Khung sp_Restock**
```sql
CREATE OR ALTER PROCEDURE inventory.sp_Restock
  @MachineId INT, @UserId INT, @Items inventory.RestockItemType READONLY, @Note NVARCHAR(200) = NULL
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  IF NOT EXISTS (SELECT 1 FROM @Items) THROW 50111, N'Danh sách châm hàng rỗng', 1;
  IF EXISTS (SELECT 1 FROM @Items i LEFT JOIN inventory.Slot s ON s.SlotId = i.ColumnId
             WHERE s.SlotId IS NULL OR s.MachineId <> @MachineId) THROW 50112, N'Có cột không thuộc máy này', 1;
  -- 50110 máy không tồn tại/không được giao, 50115 lô không tồn tại, 50114 lô sai sản phẩm,
  -- 50116 lô hết hạn hoặc còn < 1 giờ, 50117 vượt sức chứa, 50118 lô không đủ số lượng
  BEGIN TRAN;
    INSERT inventory.RestockEvent (MachineId, UserId, Note) VALUES (@MachineId, @UserId, @Note);
    DECLARE @RestockId INT = SCOPE_IDENTITY();
    INSERT inventory.RestockItem (RestockId, SlotId, BatchId, Qty) SELECT @RestockId, ColumnId, BatchId, Qty FROM @Items;
    INSERT inventory.SlotStock (SlotId, BatchId, Quantity) SELECT ColumnId, BatchId, Qty FROM @Items;
  COMMIT;
  SELECT @RestockId AS RestockId, COUNT(*) AS Lines, SUM(Qty) AS TotalQty FROM @Items;
END
```

**Bước 2. Kiểm tra sức chứa**
- **Cách làm:** cộng tồn hiện tại theo ngăn + số châm theo ngăn rồi so với `Slot.Capacity`:
```sql
IF EXISTS (
  SELECT 1 FROM (SELECT ColumnId, SUM(Qty) q FROM @Items GROUP BY ColumnId) x
  JOIN inventory.Slot s ON s.SlotId = x.ColumnId
  OUTER APPLY (SELECT ISNULL(SUM(Quantity),0) cur FROM inventory.SlotStock WITH (UPDLOCK) WHERE SlotId = x.ColumnId) c
  WHERE c.cur + x.q > s.Capacity) THROW 50117, N'Vượt sức chứa của cột', 1;
```
- **Lưu ý:** đặt khối kiểm tra **sau** `BEGIN TRAN` để `UPDLOCK` giữ khóa tới khi COMMIT (chống 2 người châm cùng lúc).

**Bước 3. Cập nhật Slot.CurrentStock**
- TV3/TV5 đang đọc `inventory.Slot.CurrentStock`. Sau khi chèn SlotStock, cập nhật lại: `UPDATE s SET CurrentStock = (SELECT SUM(Quantity) FROM inventory.SlotStock WHERE SlotId = s.SlotId) FROM inventory.Slot s WHERE s.SlotId IN (SELECT ColumnId FROM @Items);`

**Bước 4. sp_RemoveExpired**
- **Tham số:** `@MachineId INT = NULL` (NULL = tất cả máy).
- **Cách làm:** với mỗi dòng `SlotStock` có `Quantity > 0` và lô `ExpiryAt <= SYSDATETIME()`: chèn `iot.Alerts` loại `EXPIRY` mức `HIGH`, rồi đặt `Quantity = 0`.
- **Trả về:** `RemovedLines, RemovedQty`.
- **Phụ thuộc:** cột của `iot.Alerts` – xem `sql/02_tables_iot.sql` (TV4).

**Bước 5. Demo rollback**
```sql
DECLARE @t inventory.RestockItemType;
INSERT @t VALUES (1, 1, 2), (2, 2, 1), (3, 3, 99);   -- dòng 3 vượt sức chứa
EXEC inventory.sp_Restock @MachineId = 1, @UserId = 1, @Items = @t;   -- THROW 50117
SELECT COUNT(*) FROM inventory.RestockEvent;          -- không tăng
```

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/11_procs_inventory.sql` (thêm 2 procedure)
- `app/api/test/fakeDb.js dòng 197–245`
- `app/api/src/jobs.js` (job gọi sp_RemoveExpired mỗi giờ)
- `sql/02_tables_iot.sql` (đọc cột iot.Alerts)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** bảng `iot.Alerts` của Dũng (đã có trên main). **Đầu ra cho:** Dũng (FV-28 job gọi `sp_RemoveExpired`), Ân (bán hàng cần tồn trong SlotStock).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Châm đúng | TVP 1 dòng, cột rỗng, lô còn hạn | Trả RestockId, Lines=1 |
| 2 | Vượt sức chứa | TVP có dòng Qty vượt Capacity | THROW 50117, không ghi dòng nào |
| 3 | Lô sai sản phẩm | BatchId của sản phẩm khác | THROW 50114 |
| 4 | Rút hết hạn | Lô ExpiryAt < now trong máy 1 | RemovedLines ≥ 1, có Alert EXPIRY |

**Kết quả cần lưu lại:** Ảnh SSMS demo rollback (COUNT trước = sau).

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Rollback toàn bộ khi 1 dòng lỗi (đếm RestockEvent trước/sau bằng nhau)
- [ ] Đủ 9 mã lỗi 50110–50118
- [ ] Có UPDLOCK khi đọc tồn
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
git checkout -b feature/SCRUM-198-restock-tvp
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/11_procs_inventory.sql
git commit -m "feat(sql-inventory): sp_Restock nhận TVP trong 1 giao dịch, sp_RemoveExpired"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-198-restock-tvp
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-198-restock-tvp`.
7. **Mô tả PR:** tiêu đề `[SCRUM-198] sp_Restock (TVP + transaction) và sp_RemoveExpired`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-198`; dán ảnh bằng chứng: Ảnh SSMS demo rollback (COUNT trước = sau).
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-198-restock-tvp
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-198 |
| Branch | `feature/SCRUM-198-restock-tvp` |
| Commit | `feat(sql-inventory): sp_Restock nhận TVP trong 1 giao dịch, sp_RemoveExpired` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) – tự merge sau khi CI xanh và 1 bạn xem |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/11_procs_inventory.sql (đủ 7 procedure)

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 12/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-198
- **Bằng chứng hoàn thành:** Ảnh SSMS demo rollback (COUNT trước = sau)
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-05 (SCRUM-199) – Leader: review & merge các nhánh tồn đọng, chạy thử toàn bộ script trên CSDL trống

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 07/11/2026 → 12/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E6 – Tích hợp, Triển khai & Tài liệu |
| Phụ thuộc | FV-01 (SCRUM-195) (Huy) |
| Người hỗ trợ | Anh |

### 1. MỤC TIÊU
Leader: review & merge các nhánh tồn đọng, chạy thử toàn bộ script trên CSDL trống. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Trên GitHub còn 3 nhánh chưa merge: `tv4-iot` (3 commit, view + function iot), `tv3-sales` (2 commit, objects + concurrency demo), `check-nv-chua-hoan-thien-xa` (TV5, 25 file, sửa cả `03_foreign_keys.sql` và README). Nhánh càng chờ lâu càng dễ xung đột.

### 3. PHẠM VI CÔNG VIỆC
- Merge theo thứ tự: tv4-iot (FV-12) → tv3-sales (FV-09) → nhánh TV5 (FV-15).
- Trước mỗi lần merge: tạo CSDL trống và chạy toàn bộ script theo thứ tự trong MASTER_PLAN.md.
- Ghi lỗi tìm được thành GitHub Issue, gán đúng người.
- Cuối tuần (12/11): chạy lại toàn bộ trên main, ghi kết quả vào mục Theo dõi tiến độ của MASTER_PLAN.md.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Mở PR để review**
- **Làm ở đâu:** GitHub → tab *Pull requests* → mở PR của thành viên.
- **Cách làm:** đọc tab *Files changed*. Kiểm tra: (1) chỉ sửa file của module đó; (2) không có `.env`; (3) CI xanh.

**Bước 2. Chạy thử trên máy**
```powershell
git fetch origin
git checkout -b review/tv4-iot origin/tv4-iot
```
Trong SSMS: `DROP DATABASE IF EXISTS FreshVendDB;` rồi chạy lần lượt các file theo bảng thứ tự. Ghi lại file nào lỗi, dòng nào.

**Bước 3. Ra quyết định**
- Lỗi nghiêm trọng → bấm **Review changes → Request changes**, ghi rõ file + dòng + thông báo lỗi.
- Không lỗi → **Approve** → **Squash and merge** → **Delete branch**.

**Bước 4. Dọn máy**
```powershell
git checkout main
git pull origin main
git branch -D review/tv4-iot
```

### 5. FILE VÀ MODULE LIÊN QUAN
- `Các PR của TV3, TV4, TV5`
- `Toàn bộ thư mục sql/`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Phối hợp:** Dũng (FV-12), Ân (FV-09), Anh (FV-15) báo khi nhánh sẵn sàng. Anh hỗ trợ chạy toàn bộ script.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Chạy toàn bộ trên main | CSDL trống, chạy 00 → 81 theo thứ tự | Không lỗi; ghi lại số object tạo được |
| 2 | CI | Mỗi PR | Job app-check-and-test xanh |

**Kết quả cần lưu lại:** Ảnh SSMS chạy toàn bộ script trên main ngày 12/11.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 3 nhánh tồn đọng đã merge hoặc có Request changes ghi rõ lý do
- [ ] 12/11: main chạy toàn bộ script không lỗi trên CSDL trống
- [ ] Lỗi còn lại có GitHub Issue và người phụ trách

### 9. GITHUB WORKFLOW
Task này không tạo nhánh riêng – không tạo nhánh – review PR của người khác. Quy trình review/merge PR của người khác:
```powershell
git status
git checkout main
git pull origin main
git fetch origin
git checkout -b review/<nhánh> origin/<nhánh>   # chạy thử trên máy
# ... chạy script trong SSMS ...
git checkout main
git branch -D review/<nhánh>
```
Trên GitHub: mở PR → *Files changed* → **Review changes** → *Approve* hoặc *Request changes* → **Squash and merge** → **Delete branch**.

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-199 |
| Branch | `(không tạo nhánh – review PR của người khác)` |
| Commit | `(không commit)` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) – tự merge sau khi CI xanh và 1 bạn xem |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- Nhánh main sạch, chạy được
- Danh sách GitHub Issues

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 12/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-199
- **Bằng chứng hoàn thành:** Ảnh SSMS chạy toàn bộ script trên main ngày 12/11
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
