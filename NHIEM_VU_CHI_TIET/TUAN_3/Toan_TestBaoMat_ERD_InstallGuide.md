# Toàn – Tuần 3: Sprint 3 – Kiểm thử, tài liệu, demo

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Huỳnh Nhật Toàn
- **Email:** htoan2851@gmail.com
- **Tuần:** 3 (Sprint 3 – Kiểm thử, tài liệu, demo)
- **Thời gian:** 20/11/2026 → 26/11/2026
- **Vai trò:** TV1 – Người dùng & Bảo mật (schema auth, audit), RBAC/RLS, Backup, cài đặt
- **Mức độ ưu tiên:** High
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-230, SCRUM-231, SCRUM-232

**Mục tiêu Sprint:** Test Report có số liệu thật, đủ tài liệu bắt buộc của đề, Docker chạy được, tag v1.0, tổng duyệt demo và vấn đáp.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-36 (SCRUM-230) | tests_auth.sql + demo phần khó TV1: RLS và khôi phục dữ liệu về thời điểm trước sự cố (STOPAT) | 20/11/2026 | 21/11/2026 | High | FV-22, FV-23 |
| FV-37 (SCRUM-231) | ERD toàn hệ thống + Data Dictionary (từ CSDL thật) | 22/11/2026 | 23/11/2026 | High | FV-20 |
| FV-38 (SCRUM-232) | InstallGuide: cài đặt từ máy trống (SQL Server, Node.js, chạy CSDL, chạy app, simulator) | 24/11/2026 | 25/11/2026 | High | FV-23 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-36 (SCRUM-230) – tests_auth.sql + demo phần khó TV1: RLS và khôi phục dữ liệu về thời điểm trước sự cố (STOPAT)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 20/11/2026 → 21/11/2026 |
| Mức ưu tiên | High |
| Epic | E1 – Người dùng & Bảo mật (auth, audit) |
| Phụ thuộc | FV-22 (SCRUM-216) (Toàn), FV-23 (SCRUM-217) (Toàn) |
| Người hỗ trợ | Không |

### 1. MỤC TIÊU
tests_auth.sql + demo phần khó TV1: RLS và khôi phục dữ liệu về thời điểm trước sự cố (STOPAT). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Phần khó TV1 khi bảo vệ là RBAC + RLS + Backup/Restore. Cần kịch bản chạy được ngay trước hội đồng và video dự phòng.

### 3. PHẠM VI CÔNG VIỆC
- `tests/tests_auth.sql`: 15 ca (5 procedure × 3) + 3 ca quyền (RLS, DENY report, Kiosk bị chặn).
- `tests/demo_security.sql`: (1) operator01 chỉ thấy 3 máy; (2) xóa nhầm bảng → RESTORE WITH STOPAT → dữ liệu trở lại.
- Quay video ≤ 5 phút.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Demo STOPAT**
1) Backup FULL. 2) Ghi giờ `SELECT SYSDATETIME()`. 3) `DELETE FROM inventory.Product;` (cố ý). 4) BACKUP LOG. 5) `RESTORE DATABASE ... WITH NORECOVERY` từ FULL, `RESTORE LOG ... WITH STOPAT = '<giờ bước 2>', RECOVERY`. 6) `SELECT COUNT(*) FROM inventory.Product` – dữ liệu trở lại.

**Bước 2. Quay video**
Win + Alt + R; lưu Drive nhóm.

### 5. FILE VÀ MODULE LIÊN QUAN
- `tests/tests_auth.sql` (mới)
- `tests/demo_security.sql` (mới)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Anh gọi tests_auth.sql trong FV-45 Test Report.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | tests_auth | F5 | 18/18 PASS |
| 2 | STOPAT | Theo kịch bản | COUNT trước sự cố = sau khôi phục |

**Kết quả cần lưu lại:** Ảnh 18 dòng PASS + link video.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 18/18 PASS
- [ ] Demo STOPAT chạy được trên máy sạch
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
git checkout -b test/SCRUM-230-auth-tests-demo
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add tests/tests_auth.sql tests/demo_security.sql
git commit -m "test(sql-auth): tests_auth.sql + kịch bản demo RLS, STOPAT"
```
5. **Push**
```powershell
git pull origin main
git push -u origin test/SCRUM-230-auth-tests-demo
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: test/SCRUM-230-auth-tests-demo`.
7. **Mô tả PR:** tiêu đề `[SCRUM-230] tests_auth.sql + demo phần khó TV1: RLS và khôi phục dữ liệu về thời điểm trước sự cố (STOPAT)`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-230`; dán ảnh bằng chứng: Ảnh 18 dòng PASS + link video.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d test/SCRUM-230-auth-tests-demo
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-230 |
| Branch | `test/SCRUM-230-auth-tests-demo` |
| Commit | `test(sql-auth): tests_auth.sql + kịch bản demo RLS, STOPAT` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- tests/tests_auth.sql
- tests/demo_security.sql
- Video

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 21/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-230
- **Bằng chứng hoàn thành:** Ảnh 18 dòng PASS + link video
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-37 (SCRUM-231) – ERD toàn hệ thống + Data Dictionary (từ CSDL thật)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 22/11/2026 → 23/11/2026 |
| Mức ưu tiên | High |
| Epic | E6 – Tích hợp, Triển khai & Tài liệu |
| Phụ thuộc | FV-20 (SCRUM-214) (Huy) |
| Người hỗ trợ | Huy, Ân, Dũng, Anh |

### 1. MỤC TIÊU
ERD toàn hệ thống + Data Dictionary (từ CSDL thật). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Đề bắt buộc ERD trong tài liệu kiến trúc. Vẽ từ CSDL **đã chạy thật** để không lệch với code.

### 3. PHẠM VI CÔNG VIỆC
- `docs/ERD.drawio` + ảnh `docs/ERD.png`: 6 schema, tô màu theo schema.
- `docs/DataDictionary.md`: mỗi bảng – cột, kiểu, NULL, khóa, mô tả.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Lấy danh sách cột tự động**
```sql
SELECT s.name AS [Schema], t.name AS [Table], c.name AS [Column], ty.name AS [Type], c.max_length, c.is_nullable
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id JOIN sys.types ty ON ty.user_type_id = c.user_type_id
ORDER BY 1, 2, c.column_id;
```
Copy kết quả (Ctrl+Shift+C) sang Markdown.

**Bước 2. Vẽ ERD**
SSMS → *Database Diagrams* → *New Database Diagram* → chọn bảng để xem quan hệ; vẽ lại gọn trong draw.io (app.diagrams.net), xuất PNG.

### 5. FILE VÀ MODULE LIÊN QUAN
- `docs/ERD.drawio, docs/ERD.png` (mới)
- `docs/DataDictionary.md` (mới)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Mỗi bạn kiểm tra phần schema mình trong ERD trước 23/11 12h.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Đối chiếu | So ERD với sys.foreign_keys | Đủ mọi quan hệ |

**Kết quả cần lưu lại:** Link PR.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] ERD đủ 6 schema, khớp CSDL thật
- [ ] Data Dictionary đủ bảng

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-231-erd-data-dictionary
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add docs/ERD.drawio docs/ERD.png docs/DataDictionary.md
git commit -m "docs: ERD và Data Dictionary"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-231-erd-data-dictionary
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-231-erd-data-dictionary`.
7. **Mô tả PR:** tiêu đề `[SCRUM-231] ERD toàn hệ thống + Data Dictionary (từ CSDL thật)`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-231`; dán ảnh bằng chứng: Link PR.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-231-erd-data-dictionary
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-231 |
| Branch | `docs/SCRUM-231-erd-data-dictionary` |
| Commit | `docs: ERD và Data Dictionary` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- docs/ERD.png
- docs/DataDictionary.md

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 23/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-231
- **Bằng chứng hoàn thành:** Link PR
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-38 (SCRUM-232) – InstallGuide: cài đặt từ máy trống (SQL Server, Node.js, chạy CSDL, chạy app, simulator)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 24/11/2026 → 25/11/2026 |
| Mức ưu tiên | High |
| Epic | E6 – Tích hợp, Triển khai & Tài liệu |
| Phụ thuộc | FV-23 (SCRUM-217) (Toàn) |
| Người hỗ trợ | Ân |

### 1. MỤC TIÊU
InstallGuide: cài đặt từ máy trống (SQL Server, Node.js, chạy CSDL, chạy app, simulator). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
`docs/InstallGuide.md` hiện 35 dòng khung. Hội đồng có thể yêu cầu cài trên máy khác. Hướng dẫn phải được **một người chưa từng cài** làm theo thành công.

### 3. PHẠM VI CÔNG VIỆC
- Yêu cầu phần mềm + phiên bản.
- Cài SQL Server 2022 Developer/Express, bật TCP/IP + SQL Auth.
- Chạy `99_run_all.bat`.
- Cài Node.js, `npm install`, cấu hình `.env`, `npm start`, `npm run simulator`.
- Cách chạy bằng Docker (lấy từ FV-11 của Ân).
- Bảng lỗi thường gặp.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Viết**
Mở `docs/InstallGuide.md`, viết theo thứ tự trên, mỗi bước có lệnh + ảnh.

**Bước 2. Thử thật**
25/11: nhờ Dũng làm theo trên máy của Dũng (hoặc máy ảo). Ghi lại chỗ vướng → sửa tài liệu.

### 5. FILE VÀ MODULE LIÊN QUAN
- `docs/InstallGuide.md`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Ân cung cấp phần Docker; Huy dùng cho FV-35.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Người khác làm theo | Dũng cài theo tài liệu | App chạy SQL thật ≤ 30 phút |

**Kết quả cần lưu lại:** Ảnh máy của Dũng chạy app.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Người khác làm theo thành công
- [ ] Có bảng lỗi thường gặp

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-232-install-guide
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add docs/InstallGuide.md
git commit -m "docs: InstallGuide cài từ máy trống"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-232-install-guide
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-232-install-guide`.
7. **Mô tả PR:** tiêu đề `[SCRUM-232] InstallGuide: cài đặt từ máy trống (SQL Server, Node.js, chạy CSDL, chạy app, simulator)`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-232`; dán ảnh bằng chứng: Ảnh máy của Dũng chạy app.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-232-install-guide
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-232 |
| Branch | `docs/SCRUM-232-install-guide` |
| Commit | `docs: InstallGuide cài từ máy trống` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- docs/InstallGuide.md

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 25/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-232
- **Bằng chứng hoàn thành:** Ảnh máy của Dũng chạy app
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
