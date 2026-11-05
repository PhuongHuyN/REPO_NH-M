# Ân – Tuần 2: Sprint 2 – Đủ object & nối app với SQL Server thật

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Đoàn Phương Thiên Ân
- **Email:** thienann2611@gmail.com
- **Tuần:** 2 (Sprint 2 – Đủ object & nối app với SQL Server thật)
- **Thời gian:** 13/11/2026 → 19/11/2026
- **Vai trò:** TV3 – Bán hàng & Thanh toán (schema sales), Kiosk, Docker, slide bảo vệ
- **Mức độ ưu tiên:** High
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-218, SCRUM-219, SCRUM-220

**Mục tiêu Sprint:** Đủ view/function/trigger/phần khó của 5 module; phân quyền 4 login; app chạy DB_MODE=sqlserver qua trọn kịch bản châm hàng → mua → nhả hàng → cảnh báo → báo cáo.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-24 (SCRUM-218) | Chạy kịch bản bán hàng trên SQL thật và sửa procedure sales cho khớp API | 13/11/2026 | 15/11/2026 | High | FV-10, FV-04, FV-18 |
| FV-25 (SCRUM-219) | Chuẩn hóa demo 2 phiên mua cùng lúc (UPDLOCK, mức cô lập) để trình bày khi bảo vệ | 16/11/2026 | 17/11/2026 | Medium | FV-24 |
| FV-26 (SCRUM-220) | Detailed Design: đặc tả API (Swagger), sequence diagram mua hàng, state diagram đơn hàng | 18/11/2026 | 19/11/2026 | Medium | FV-24 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-24 (SCRUM-218) – Chạy kịch bản bán hàng trên SQL thật và sửa procedure sales cho khớp API

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 13/11/2026 → 15/11/2026 |
| Mức ưu tiên | High |
| Epic | E3 – Bán hàng & Thanh toán (sales) |
| Phụ thuộc | FV-10 (SCRUM-204) (Ân), FV-04 (SCRUM-198) (Huy), FV-18 (SCRUM-212) (Huy) |
| Người hỗ trợ | Huy |

### 1. MỤC TIÊU
Chạy kịch bản bán hàng trên SQL thật và sửa procedure sales cho khớp API. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
5 procedure sales đã có (12_procs_sales.sql) nhưng chưa từng chạy cùng procedure inventory thật (FIFO qua `fn_GetFifoStock` của TV2). Cần chứng minh luồng: tạo đơn → VietQR → xác nhận → nhả hàng → DISPENSED, và kẹt 3 lần → hoàn tiền.

### 3. PHẠM VI CÔNG VIỆC
- Trong SSMS chạy đủ luồng mua hàng bằng EXEC (chưa cần app).
- Dùng `inventory.fn_GetFifoStock` trong `sp_CreateOrder` thay cho truy vấn tự viết (nếu nhóm đồng ý).
- So tham số với `app/api/src/routes/sales.js`, cột trả về với fakeDb.js dòng 246–335.
- Cập nhật `tests/tests_sales.sql`.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Kịch bản SSMS**
```sql
DECLARE @items sales.OrderItemType; INSERT @items (ColumnId, Qty) VALUES (1, 1);
EXEC sales.sp_CreateOrder @MachineId = 1, @Items = @items;                 -- ghi lại OrderId, TotalAmount
EXEC sales.sp_ConfirmPayment @OrderId = <id>, @Method = 'VIETQR', @GatewayTxnId = 'TEST-1', @Amount = <tổng>;
EXEC sales.sp_ConfirmPayment @OrderId = <id>, @Method = 'VIETQR', @GatewayTxnId = 'TEST-1', @Amount = <tổng>;  -- IsDuplicate = 1
EXEC sales.sp_RecordDispense @OrderItemId = <item>, @Result = 'SUCCESS';
SELECT * FROM sales.vw_OrderDetail WHERE OrderId = <id>;                    -- DISPENSED, đúng lô FIFO
```

**Bước 2. Kịch bản kẹt**
Gọi `sp_RecordDispense ... @Result = 'JAM', @ErrorCode = 'E_MOTOR_STALL'` 3 lần → đơn `REFUNDED`, có dòng `sales.Refund`, hàng trả về SlotStock.

**Bước 3. Sửa lệch**
Mỗi chỗ lệch tên tham số/cột: sửa procedure (không sửa API). Ghi danh sách sửa vào mô tả PR.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/12_procs_sales.sql`
- `tests/tests_sales.sql`
- `app/api/src/routes/sales.js`
- `app/api/test/fakeDb.js dòng 246–335`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** Huy (FV-04 tồn kho, FV-18 fn_GetFifoStock). **Đầu ra cho:** Huy (FV-20), Anh (FV-32).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Mua thành công | Kịch bản trên | DISPENSED, tồn giảm 1 |
| 2 | Callback trùng | ConfirmPayment 2 lần | IsDuplicate=1, 1 dòng Payment |
| 3 | Kẹt 3 lần | 3 × JAM | REFUNDED, tồn trả lại |
| 4 | Hết hàng | Qty > tồn | THROW 50201 |

**Kết quả cần lưu lại:** Ảnh SSMS kịch bản mua + kẹt.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 4 test đúng trên SQL thật
- [ ] tests_sales.sql cập nhật, PASS hết
- [ ] PR merge

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b fix/SCRUM-218-sales-sqlserver
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/12_procs_sales.sql tests/tests_sales.sql
git commit -m "fix(sql-sales): khớp tham số/cột trả về với API khi chạy SQL thật"
```
5. **Push**
```powershell
git pull origin main
git push -u origin fix/SCRUM-218-sales-sqlserver
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: fix/SCRUM-218-sales-sqlserver`.
7. **Mô tả PR:** tiêu đề `[SCRUM-218] Chạy kịch bản bán hàng trên SQL thật và sửa procedure sales cho khớp API`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-218`; dán ảnh bằng chứng: Ảnh SSMS kịch bản mua + kẹt.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d fix/SCRUM-218-sales-sqlserver
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-218 |
| Branch | `fix/SCRUM-218-sales-sqlserver` |
| Commit | `fix(sql-sales): khớp tham số/cột trả về với API khi chạy SQL thật` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/12_procs_sales.sql (đã sửa)
- tests/tests_sales.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 15/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-218
- **Bằng chứng hoàn thành:** Ảnh SSMS kịch bản mua + kẹt
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-25 (SCRUM-219) – Chuẩn hóa demo 2 phiên mua cùng lúc (UPDLOCK, mức cô lập) để trình bày khi bảo vệ

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 16/11/2026 → 17/11/2026 |
| Mức ưu tiên | Medium |
| Epic | E3 – Bán hàng & Thanh toán (sales) |
| Phụ thuộc | FV-24 (SCRUM-218) (Ân) |
| Người hỗ trợ | Không |

### 1. MỤC TIÊU
Chuẩn hóa demo 2 phiên mua cùng lúc (UPDLOCK, mức cô lập) để trình bày khi bảo vệ. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Phần khó TV3: chứng minh 2 kiosk mua ngăn cuối cùng cùng lúc không bán quá tồn. File `tests/60_concurrency_demo.sql` đã có (nhánh tv3-sales) với 3 procedure demo – cần chạy lại với schema sau FV-02/FV-24 và viết hướng dẫn 2 cửa sổ.

### 3. PHẠM VI CÔNG VIỆC
- Chạy lại file trên CSDL mới.
- Ghi hướng dẫn: mở 2 tab SSMS, thứ tự bấm F5, kết quả mong đợi khi có/không có UPDLOCK.
- Quay video ≤ 5 phút.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Chuẩn bị**
Đặt tồn ngăn 1 = 1 hộp bằng `sales.sp_ConcurrencyDemo_Prepare`.

**Bước 2. Không khóa**
Tab A: `EXEC sales.sp_CreateOrder_NoUpdLock ...` (có WAITFOR 10 giây). Trong 10 giây đó tab B chạy cùng lệnh → **cả 2 đều thành công → bán âm**.

**Bước 3. Có UPDLOCK**
Lặp lại với `sales.sp_CreateOrder_DemoDelay` → tab B **chờ** tab A xong rồi nhận lỗi 50201 *hết hàng*.

**Bước 4. Quay video**
Win + Alt + R.

### 5. FILE VÀ MODULE LIÊN QUAN
- `tests/60_concurrency_demo.sql`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Huy dùng trong buổi tổng duyệt (FV-35).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Không khóa | 2 tab | Tồn âm hoặc 2 đơn thành công |
| 2 | Có khóa | 2 tab | 1 thành công, 1 lỗi 50201 |

**Kết quả cần lưu lại:** Link video.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Demo lặp lại được
- [ ] Có video

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b test/SCRUM-219-concurrency-demo
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add tests/60_concurrency_demo.sql
git commit -m "test(sql-sales): chuẩn hóa 60_concurrency_demo"
```
5. **Push**
```powershell
git pull origin main
git push -u origin test/SCRUM-219-concurrency-demo
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: test/SCRUM-219-concurrency-demo`.
7. **Mô tả PR:** tiêu đề `[SCRUM-219] Chuẩn hóa demo 2 phiên mua cùng lúc (UPDLOCK, mức cô lập) để trình bày khi bảo vệ`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-219`; dán ảnh bằng chứng: Link video.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d test/SCRUM-219-concurrency-demo
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-219 |
| Branch | `test/SCRUM-219-concurrency-demo` |
| Commit | `test(sql-sales): chuẩn hóa 60_concurrency_demo` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- tests/60_concurrency_demo.sql
- Video

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 17/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-219
- **Bằng chứng hoàn thành:** Link video
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-26 (SCRUM-220) – Detailed Design: đặc tả API (Swagger), sequence diagram mua hàng, state diagram đơn hàng

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 18/11/2026 → 19/11/2026 |
| Mức ưu tiên | Medium |
| Epic | E3 – Bán hàng & Thanh toán (sales) |
| Phụ thuộc | FV-24 (SCRUM-218) (Ân) |
| Người hỗ trợ | Huy |

### 1. MỤC TIÊU
Detailed Design: đặc tả API (Swagger), sequence diagram mua hàng, state diagram đơn hàng. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Đề bắt buộc Detailed Design (API Specification, Database Schema, UI Wireframes). API đã có Swagger tại `/api-docs` (`app/api/src/openapi.js`); `docs/State.drawio` đã có từ 01/11.

### 3. PHẠM VI CÔNG VIỆC
- `docs/DetailedDesign.md`: danh sách 56 route (lấy từ `/api-docs`), nhóm theo module, vai trò được gọi, procedure/view tương ứng.
- Sequence diagram luồng mua hàng (Kiosk → API → SQL → Simulator).
- Cập nhật State diagram theo trạng thái thật.
- UI wireframe: chụp màn hình kiosk + admin làm wireframe.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Xuất Swagger**
Chạy `npm run demo`, mở http://localhost:3000/api-docs/openapi.json, lưu thành `docs/openapi.json`.

**Bước 2. Sequence diagram**
draw.io: các đối tượng Khách, Kiosk (web), API, SQL Server, ESP32 simulator, Ngân hàng/SePay. Xuất `docs/Sequence_MuaHang.png`.

### 5. FILE VÀ MODULE LIÊN QUAN
- `docs/DetailedDesign.md` (mới)
- `docs/openapi.json` (mới)
- `docs/Sequence_MuaHang.png` (mới)
- `docs/State.drawio`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Huy, Toàn kiểm tra phần route module mình.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Đối chiếu | So số route trong tài liệu với check-sync (56 route) | Khớp |

**Kết quả cần lưu lại:** Link PR.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Đủ 3 phần API, sequence, state, wireframe

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-220-detailed-design
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add docs/DetailedDesign.md docs/openapi.json docs/Sequence_MuaHang.png docs/State.drawio
git commit -m "docs: detailed design – API spec, sequence, state diagram"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-220-detailed-design
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-220-detailed-design`.
7. **Mô tả PR:** tiêu đề `[SCRUM-220] Detailed Design: đặc tả API (Swagger), sequence diagram mua hàng, state diagram đơn hàng`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-220`; dán ảnh bằng chứng: Link PR.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-220-detailed-design
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-220 |
| Branch | `docs/SCRUM-220-detailed-design` |
| Commit | `docs: detailed design – API spec, sequence, state diagram` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- docs/DetailedDesign.md

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 19/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-220
- **Bằng chứng hoàn thành:** Link PR
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
