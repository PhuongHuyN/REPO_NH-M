# Huy – Tuần 3: Sprint 3 – Kiểm thử, tài liệu, demo

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Nguyễn Phương Huy
- **Email:** jira@nguyenhuyth2k6.atlassian.net
- **Tuần:** 3 (Sprint 3 – Kiểm thử, tài liệu, demo)
- **Thời gian:** 20/11/2026 → 26/11/2026
- **Vai trò:** Leader – TV2 Sản phẩm & Tồn kho (schema inventory) + Tích hợp hệ thống, review & merge PR
- **Mức độ ưu tiên:** Highest
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-227, SCRUM-228, SCRUM-229

**Mục tiêu Sprint:** Test Report có số liệu thật, đủ tài liệu bắt buộc của đề, Docker chạy được, tag v1.0, tổng duyệt demo và vấn đáp.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-33 (SCRUM-227) | Chuẩn bị demo phần khó TV2: Temporal Table, TVP rollback, FIFO (kèm video dự phòng) | 20/11/2026 | 20/11/2026 | Medium | FV-18 |
| FV-34 (SCRUM-228) | Ghép URS/SRS tổng, User Story Tồn kho, User Manual Operator (phần tồn kho) | 21/11/2026 | 23/11/2026 | High | FV-20 |
| FV-35 (SCRUM-229) | Release v1.0: code freeze, tag, file .bak, gói nộp, tổng duyệt demo & vấn đáp | 24/11/2026 | 26/11/2026 | Highest | FV-38, FV-41, FV-45, FV-46 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-33 (SCRUM-227) – Chuẩn bị demo phần khó TV2: Temporal Table, TVP rollback, FIFO (kèm video dự phòng)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 20/11/2026 → 20/11/2026 |
| Mức ưu tiên | Medium |
| Epic | E2 – Sản phẩm & Tồn kho (inventory) |
| Phụ thuộc | FV-18 (SCRUM-212) (Huy) |
| Người hỗ trợ | Không |

### 1. MỤC TIÊU
Chuẩn bị demo phần khó TV2: Temporal Table, TVP rollback, FIFO (kèm video dự phòng). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Khi bảo vệ, hội đồng hỏi phần khó của từng người. Phần khó TV2 là Temporal Table + Table-Valued Parameter + FIFO.

### 3. PHẠM VI CÔNG VIỆC
- File `tests/demo_inventory.sql` gồm 3 khối demo chạy lần lượt.
- Quay video màn hình 3–5 phút.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Khối 1 Temporal**
Đổi giá sản phẩm 1 hai lần → `SELECT * FROM inventory.fn_PriceHistory(1)` → giải thích SQL Server tự lưu ValidFrom/ValidTo.

**Bước 2. Khối 2 TVP rollback**
Dùng đoạn demo ở FV-04: TVP 3 dòng, 1 dòng vượt sức chứa → lỗi 50117 → đếm RestockEvent trước/sau bằng nhau.

**Bước 3. Khối 3 FIFO**
Châm lô A rồi lô B vào cùng ngăn → mua 1 hộp ở kiosk → `sales.vw_OrderDetail` cho thấy lấy từ lô A.

**Bước 4. Quay video**
Windows: **Win + Alt + R** (Xbox Game Bar) quay màn hình SSMS. Lưu vào Google Drive nhóm.

### 5. FILE VÀ MODULE LIÊN QUAN
- `tests/demo_inventory.sql` (tạo mới)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Ân hỗ trợ khối 3 (mua hàng ở kiosk).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Chạy demo | F5 từng khối | Kết quả như mô tả |

**Kết quả cần lưu lại:** Link video.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 3 khối chạy được trên CSDL sạch
- [ ] Có video ≤ 5 phút

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-227-demo-inventory
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add tests/demo_inventory.sql
git commit -m "docs(inventory): kịch bản demo Temporal, TVP, FIFO"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-227-demo-inventory
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-227-demo-inventory`.
7. **Mô tả PR:** tiêu đề `[SCRUM-227] Chuẩn bị demo phần khó TV2: Temporal Table, TVP rollback, FIFO (kèm video dự phòng)`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-227`; dán ảnh bằng chứng: Link video.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-227-demo-inventory
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-227 |
| Branch | `docs/SCRUM-227-demo-inventory` |
| Commit | `docs(inventory): kịch bản demo Temporal, TVP, FIFO` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) – tự merge sau khi CI xanh và 1 bạn xem |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- tests/demo_inventory.sql
- Video demo

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 20/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-227
- **Bằng chứng hoàn thành:** Link video
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-34 (SCRUM-228) – Ghép URS/SRS tổng, User Story Tồn kho, User Manual Operator (phần tồn kho)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 21/11/2026 → 23/11/2026 |
| Mức ưu tiên | High |
| Epic | E6 – Tích hợp, Triển khai & Tài liệu |
| Phụ thuộc | FV-20 (SCRUM-214) (Huy) |
| Người hỗ trợ | Toàn, Ân, Dũng, Anh |

### 1. MỤC TIÊU
Ghép URS/SRS tổng, User Story Tồn kho, User Manual Operator (phần tồn kho). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Đề bắt buộc URS/SRS và User Manual cho Operator. `docs/SRS.md` hiện là bản nháp 29 dòng (21/10). TV3 đã có `docs/UserStories_Sales.md` làm mẫu.

### 3. PHẠM VI CÔNG VIỆC
- `docs/UserStories_Inventory.md` (5 user story có tiêu chí chấp nhận).
- `docs/SRS.md`: giới thiệu, phạm vi, yêu cầu chức năng theo 5 module, yêu cầu phi chức năng, ràng buộc (ghi rõ dùng SQL Server thay PostgreSQL, phần cứng mô phỏng).
- `docs/UserManual_Operator.md` phần Sản phẩm & Châm hàng có ảnh chụp chạy SQL thật.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Thu user story**
Ngày 21/11 nhắn 4 bạn gửi user story module mình (Ân đã có file). Hạn 22/11 12h.

**Bước 2. Viết SRS**
Mở `docs/SRS.md`, giữ các mục hiện có, điền nội dung. Mục *Ràng buộc*: SQL Server 2022/Express, Node.js ≥ 20, ESP32 mô phỏng bằng `app/simulator/esp32.js`, thanh toán VietQR xác nhận thủ công/SePay.

**Bước 3. User Manual Operator**
Chụp ảnh trang Sản phẩm, Châm hàng khi chạy `DB_MODE=sqlserver`. Mỗi thao tác: mục đích – các bước – ảnh – lỗi thường gặp. Dũng viết tiếp phần Máy & Cảnh báo (FV-43).

### 5. FILE VÀ MODULE LIÊN QUAN
- `docs/SRS.md`
- `docs/UserStories_Inventory.md` (mới)
- `docs/UserManual_Operator.md` (mới)
- `docs/UserStories_Sales.md` (mẫu)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** user story của 4 bạn. **Đầu ra cho:** Anh (FV-46 ghép báo cáo), Ân (FV-40 slide).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Đọc chéo | Nhờ Toàn đọc SRS | Không mâu thuẫn với code (tên chức năng, quyền) |

**Kết quả cần lưu lại:** Link PR.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] SRS đủ 5 module + phi chức năng + ràng buộc
- [ ] User Manual có ảnh thật

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-228-srs-usermanual-operator
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add docs/SRS.md docs/UserStories_Inventory.md docs/UserManual_Operator.md
git commit -m "docs: SRS tổng, user story tồn kho, user manual operator"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-228-srs-usermanual-operator
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-228-srs-usermanual-operator`.
7. **Mô tả PR:** tiêu đề `[SCRUM-228] Ghép URS/SRS tổng, User Story Tồn kho, User Manual Operator (phần tồn kho)`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-228`; dán ảnh bằng chứng: Link PR.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-228-srs-usermanual-operator
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-228 |
| Branch | `docs/SCRUM-228-srs-usermanual-operator` |
| Commit | `docs: SRS tổng, user story tồn kho, user manual operator` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) – tự merge sau khi CI xanh và 1 bạn xem |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- docs/SRS.md
- docs/UserStories_Inventory.md
- docs/UserManual_Operator.md

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 23/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-228
- **Bằng chứng hoàn thành:** Link PR
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-35 (SCRUM-229) – Release v1.0: code freeze, tag, file .bak, gói nộp, tổng duyệt demo & vấn đáp

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 24/11/2026 → 26/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E6 – Tích hợp, Triển khai & Tài liệu |
| Phụ thuộc | FV-38 (SCRUM-232) (Toàn), FV-41 (SCRUM-235) (Ân), FV-45 (SCRUM-239) (Anh), FV-46 (SCRUM-240) (Anh) |
| Người hỗ trợ | Toàn, Ân, Dũng, Anh |

### 1. MỤC TIÊU
Release v1.0: code freeze, tag, file .bak, gói nộp, tổng duyệt demo & vấn đáp. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Đề yêu cầu nộp source code chạy được, gói Docker, tài liệu. Mỗi thành viên phải giải thích được toàn hệ thống trước hội đồng.

### 3. PHẠM VI CÔNG VIỆC
- 24/11 18h: code freeze – chỉ merge PR sửa lỗi.
- 25/11: chạy lại toàn bộ trên máy trống bằng InstallGuide; tạo `FreshVendDB.bak`.
- 25/11 20h: tổng duyệt demo lần 1 (mỗi người 3 phút + hỏi chéo).
- 26/11: tổng duyệt lần 2, tag `v1.0`, nộp bài.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Code freeze**
Nhắn nhóm 24/11. Trên GitHub: *Settings → Branches* kiểm tra rule bảo vệ main còn bật.

**Bước 2. Backup**
SSMS → chuột phải FreshVendDB → *Tasks → Back Up...* → Full → lưu `FreshVendDB.bak` (không commit vào Git; nộp kèm qua Drive).

**Bước 3. Tag**
```powershell
git checkout main
git pull origin main
git tag -a v1.0 -m "FreshVend v1.0 – nộp bảo vệ"
git push origin v1.0
```

**Bước 4. Tổng duyệt**
Kịch bản: Operator châm hàng → khách mua ở kiosk → thanh toán giả lập → máy nhả → simulator `--overheat 3` sinh cảnh báo → Admin xem báo cáo. Mỗi người trả lời 2 câu: *vì sao API không viết SQL mà gọi procedure?* và *chế độ demo khác chế độ thật ở đâu?*

### 5. FILE VÀ MODULE LIÊN QUAN
- `Toàn repo`
- `docs/InstallGuide.md`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Cả nhóm có mặt 2 buổi tổng duyệt; Ân mang slide (FV-40); Anh mang Test Report (FV-45).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Cài từ máy trống | Làm theo InstallGuide | App chạy SQL thật trong ≤ 30 phút |
| 2 | Docker | docker compose up | API lên cổng 3000 |

**Kết quả cần lưu lại:** Link release v1.0 + biên bản tổng duyệt.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Tag v1.0 trên GitHub
- [ ] Gói nộp đủ: source, .bak, docs, slide
- [ ] 2 buổi tổng duyệt đã làm, mỗi người trình bày được phần mình

### 9. GITHUB WORKFLOW
Task này không tạo nhánh riêng – merge vào main, tag v1.0. Quy trình review/merge PR của người khác:
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
| Jira Issue | SCRUM-229 |
| Branch | `(merge vào main, tag v1.0)` |
| Commit | `chore: release v1.0` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) – tự merge sau khi CI xanh và 1 bạn xem |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- Tag v1.0
- FreshVendDB.bak
- Gói nộp

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 26/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-229
- **Bằng chứng hoàn thành:** Link release v1.0 + biên bản tổng duyệt
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
