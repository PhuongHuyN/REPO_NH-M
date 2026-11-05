# Anh – Tuần 1: Sprint 1 – Nền tảng CSDL

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Nguyễn Phạm Xuân Anh
- **Email:** modz06j.xuananhngxph@gmail.com
- **Tuần:** 1 (Sprint 1 – Nền tảng CSDL)
- **Thời gian:** 06/11/2026 → 12/11/2026
- **Vai trò:** TV5 – Báo cáo & Phân tích (schema report), QA: kiểm thử tích hợp, hiệu năng, Test Report
- **Mức độ ưu tiên:** Highest
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-209, SCRUM-210, SCRUM-211

**Mục tiêu Sprint:** Mọi bảng và stored procedure lõi của 5 module có trên main; chạy toàn bộ script trên CSDL trống không lỗi; xóa hết nhánh tồn đọng.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-15 (SCRUM-209) | Đưa nhánh TV5 lên main sạch: bỏ phần tạo bảng của module khác, trỏ báo cáo về bảng thật | 06/11/2026 | 09/11/2026 | Highest | FV-01 |
| FV-16 (SCRUM-210) | Chuẩn hóa tên/số thứ tự file SQL theo QĐ-3 và cập nhật README, app/README | 10/11/2026 | 10/11/2026 | High | FV-15, FV-12 |
| FV-17 (SCRUM-211) | Test Plan tổng: phạm vi, môi trường, ca kiểm thử từng module, tiêu chí đạt | 11/11/2026 | 12/11/2026 | Medium | FV-01 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-15 (SCRUM-209) – Đưa nhánh TV5 lên main sạch: bỏ phần tạo bảng của module khác, trỏ báo cáo về bảng thật

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 06/11/2026 → 09/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E5 – Báo cáo & Kiểm thử (report, QA) |
| Phụ thuộc | FV-01 (SCRUM-195) (Huy) |
| Người hỗ trợ | Huy, Dũng |

### 1. MỤC TIÊU
Đưa nhánh TV5 lên main sạch: bỏ phần tạo bảng của module khác, trỏ báo cáo về bảng thật. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Nhánh `check-nv-chua-hoan-thien-xa` (1 commit, 04/11, 25 file) có kết quả kiểm thử thật rất tốt (21/21 PASS, đo hiệu năng). Nhưng file `sql/04_report_dependencies.sql` **tự tạo bảng của module khác**: `inventory.Locations`, `iot.TelemetryHourly`, `sales.DispenseAttempts` và index trên bảng sales/iot → trùng hoặc lệch với bảng của TV2/TV3/TV4. Nhánh cũng sửa file chung `03_foreign_keys.sql`, `README.md` và tạo cả `05_seed_*`, `06_seed_*` lẫn `09_seed_*`. Commit dùng email `email-cua-ban@example.com` nên GitHub không ghi nhận đúng người.

### 3. PHẠM VI CÔNG VIỆC
- Cấu hình lại `git config user.email` đúng email GitHub.
- Merge `origin/main` vào nhánh.
- Bỏ `04_report_dependencies.sql`: bảng nào báo cáo cần mà module chưa có → mở GitHub Issue cho chủ module (Dũng: TelemetryHourly đã có trong `02_tables_iot.sql`; Ân: dùng `sales.DispenseEvents` thay `DispenseAttempts`; Dũng: `iot.Locations` thay `inventory.Locations`).
- Giữ 1 bộ seed (xem FV-16).
- Không sửa `03_foreign_keys.sql` trong nhánh này (để Toàn sửa ở FV-07) – revert phần đó.
- Mở PR.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Sửa email commit**
```powershell
git config --global user.email "modz06j.xuananhngxph@gmail.com"
git config --global user.name "Nguyen Pham Xuan Anh"
```

**Bước 2. Cập nhật nhánh**
```powershell
git checkout check-nv-chua-hoan-thien-xa
git pull origin check-nv-chua-hoan-thien-xa
git fetch origin
git merge origin/main
```

**Bước 3. Trả lại file chung**
```powershell
git checkout origin/main -- sql/03_foreign_keys.sql
```
(Phần FK cần cho báo cáo → gửi Toàn trong Issue.)

**Bước 4. Đổi tham chiếu**
Trong `14_procs_report.sql`, `24_objects_report.sql`: `inventory.Location(s)` → `iot.Locations`; `sales.DispenseAttempts` → `sales.DispenseEvents`; `inventory.Stock`/`inventory.Batch` → `inventory.SlotStock`/`inventory.StockBatch`. Dùng VS Code *Ctrl+Shift+H* (tìm & thay trong thư mục `sql/`).

**Bước 5. Xóa file phụ thuộc**
`git rm sql/04_report_dependencies.sql`

**Bước 6. Chạy lại bộ kiểm thử**
`powershell -NoProfile -File tests/run-tv5.ps1` trên CSDL tạo từ main + nhánh. Ghi kết quả mới.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/04_report_dependencies.sql` (xóa)
- `sql/14_procs_report.sql, sql/24_objects_report.sql`
- `sql/03_foreign_keys.sql` (trả về bản main)
- `tests/run-tv5.ps1`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Phối hợp:** Dũng (iot.Locations, TelemetryHourly – FV-13), Ân (DispenseEvents), Toàn (FK báo cáo – FV-07). Huy review (FV-05).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Không tạo bảng ngoài report | Select-String 'CREATE TABLE (inventory|iot|sales)' trong file của TV5 | Không có kết quả |
| 2 | run-tv5.ps1 | Chạy | PASS như trước |

**Kết quả cần lưu lại:** Link PR + log run-tv5.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Không còn tạo bảng/index của schema khác
- [ ] Commit hiện đúng tên Anh
- [ ] PR merge, CI xanh

### 9. GITHUB WORKFLOW
Task dùng **nhánh có sẵn `check-nv-chua-hoan-thien-xa`** (không tạo nhánh mới).
1. **Kiểm tra nhánh hiện tại**
```powershell
git status
git branch
```
2. **Chuyển sang nhánh và đồng bộ với main**
```powershell
git checkout check-nv-chua-hoan-thien-xa
git pull origin check-nv-chua-hoan-thien-xa
git fetch origin
git merge origin/main
```
Nếu báo `CONFLICT` → xem `Cach_su_dung_GITHUB.md` mục 7.
3. **Commit**
```powershell
git add sql/04_report_dependencies.sql sql/14_procs_report.sql sql/24_objects_report.sql sql/03_foreign_keys.sql tests/run-tv5.ps1
git commit -m "refactor(sql-report): bỏ tạo bảng ngoài schema report, dùng bảng thật của các module"
```
4. **Push**
```powershell
git push origin check-nv-chua-hoan-thien-xa
```
5. **Tạo Pull Request** `base: main` ← `compare: check-nv-chua-hoan-thien-xa`, tiêu đề `[SCRUM-209] Đưa nhánh TV5 lên main sạch: bỏ phần tạo bảng của module khác, trỏ báo cáo về bảng thật`, nội dung theo mẫu ở `Cach_su_dung_GITHUB.md` mục 5, mục *Related Jira Task* ghi `SCRUM-209`.
6. **Kiểm tra conflict:** GitHub hiện *This branch has no conflicts with the base branch*. Nếu có conflict → làm lại bước 2.
7. **Nhờ Leader review:** Reviewers → PhuongHuyN; nhắn nhóm chat kèm link PR.
8. **Merge** khi được Approve (Leader bấm *Squash and merge*). Sau đó:
```powershell
git checkout main
git pull origin main
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-209 |
| Branch | `check-nv-chua-hoan-thien-xa (nhánh hiện có – giữ tên)` |
| Commit | `refactor(sql-report): bỏ tạo bảng ngoài schema report, dùng bảng thật của các module` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- PR nhánh TV5 đã merge

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 09/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-209
- **Bằng chứng hoàn thành:** Link PR + log run-tv5
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-16 (SCRUM-210) – Chuẩn hóa tên/số thứ tự file SQL theo QĐ-3 và cập nhật README, app/README

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 10/11/2026 → 10/11/2026 |
| Mức ưu tiên | High |
| Epic | E5 – Báo cáo & Kiểm thử (report, QA) |
| Phụ thuộc | FV-15 (SCRUM-209) (Anh), FV-12 (SCRUM-206) (Dũng) |
| Người hỗ trợ | Toàn |

### 1. MỤC TIÊU
Chuẩn hóa tên/số thứ tự file SQL theo QĐ-3 và cập nhật README, app/README. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Hiện có các tên trùng số: `07_procs_iot` / `07_procs_report`, `05_views_report` / `05_seed_small` (nhánh TV5), seed có 2 bộ (05/06 và 09). README gốc liệt kê file không tồn tại; `app/README.md` vẫn bảo chạy `FreshVend_FULL.sql` (không có trong repo).

### 3. PHẠM VI CÔNG VIỆC
- `git mv sql/07_procs_report.sql sql/14_procs_report.sql`.
- Gộp `05_views_report.sql` + `06_functions_report.sql` vào `24_objects_report.sql`.
- Giữ 1 bộ seed: `80_seed_small.sql`, `81_seed_large.sql`.
- README gốc: bảng thứ tự chạy đúng MASTER_PLAN.md, bảng thành viên điền module + người.
- `app/README.md` mục 2: thay `FreshVend_FULL.sql` bằng `99_run_all.bat`.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Đổi tên**
Dùng `git mv` để giữ lịch sử từng file.

**Bước 2. README**
Sửa bảng *Nhóm thực hiện* (cột *Phụ trách*: TV1 Toàn – auth/audit; TV2 Huy – inventory; TV3 Ân – sales; TV4 Dũng – iot; TV5 Anh – report).

**Bước 3. Chạy thử**
CSDL trống → chạy theo bảng mới → không lỗi.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/*` (đổi tên)
- `README.md`
- `app/README.md`
- `NHIEM_VU_CHI_TIET/MASTER_PLAN.md` (đối chiếu)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu ra cho:** Toàn (FV-23 99_run_all.bat dùng danh sách này).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Không trùng số | ls sql | Không 2 file cùng tiền tố trừ nhóm 02_tables_* |
| 2 | Chạy theo README | Làm đúng README | Không lỗi |

**Kết quả cần lưu lại:** Link PR.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Tên file khớp bảng MASTER_PLAN
- [ ] README đúng thực tế
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
git checkout -b chore/SCRUM-210-thu-tu-file
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add README.md app/README.md
git commit -m "chore(sql): chuẩn hóa thứ tự file + README cài đặt"
```
5. **Push**
```powershell
git pull origin main
git push -u origin chore/SCRUM-210-thu-tu-file
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: chore/SCRUM-210-thu-tu-file`.
7. **Mô tả PR:** tiêu đề `[SCRUM-210] Chuẩn hóa tên/số thứ tự file SQL theo QĐ-3 và cập nhật README, app/README`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-210`; dán ảnh bằng chứng: Link PR.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d chore/SCRUM-210-thu-tu-file
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-210 |
| Branch | `chore/SCRUM-210-thu-tu-file` |
| Commit | `chore(sql): chuẩn hóa thứ tự file + README cài đặt` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- README.md
- app/README.md

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 10/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-210
- **Bằng chứng hoàn thành:** Link PR
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-17 (SCRUM-211) – Test Plan tổng: phạm vi, môi trường, ca kiểm thử từng module, tiêu chí đạt

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 11/11/2026 → 12/11/2026 |
| Mức ưu tiên | Medium |
| Epic | E5 – Báo cáo & Kiểm thử (report, QA) |
| Phụ thuộc | FV-01 (SCRUM-195) (Huy) |
| Người hỗ trợ | Huy, Toàn, Ân, Dũng |

### 1. MỤC TIÊU
Test Plan tổng: phạm vi, môi trường, ca kiểm thử từng module, tiêu chí đạt. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Đề bắt buộc Test Plan (Unit, Integration, Performance). `docs/TestPlan.md` hiện chỉ có phần report. Test Plan phải viết **trước** khi chạy test tuần 2–3.

### 3. PHẠM VI CÔNG VIỆC
- Phạm vi: unit (tests_<module>.sql + npm test), integration (kịch bản end-to-end), performance (≤ 500 ms cho 95% API; truy vấn báo cáo trên seed lớn).
- Môi trường: Windows, SQL Server 2022 Express/Developer, Node 20+.
- Bảng ca kiểm thử theo module (thu từ 4 bạn).
- Tiêu chí vào/ra, quản lý lỗi (GitHub Issues), phân công.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Thu ca kiểm thử**
11/11 nhắn 4 bạn gửi danh sách procedure + 3 ca (đúng/sai) – hạn 12/11 12h.

**Bước 2. Viết**
Cập nhật `docs/TestPlan.md`, giữ phần report đã có.

### 5. FILE VÀ MODULE LIÊN QUAN
- `docs/TestPlan.md`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Cả nhóm gửi ca kiểm thử.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Đủ module | Đọc lại | 5 module, mỗi procedure ≥ 3 ca |

**Kết quả cần lưu lại:** Link PR.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Có đủ 3 loại kiểm thử + tiêu chí đạt

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-211-test-plan
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add docs/TestPlan.md
git commit -m "docs: Test Plan tổng 5 module"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-211-test-plan
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-211-test-plan`.
7. **Mô tả PR:** tiêu đề `[SCRUM-211] Test Plan tổng: phạm vi, môi trường, ca kiểm thử từng module, tiêu chí đạt`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-211`; dán ảnh bằng chứng: Link PR.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-211-test-plan
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-211 |
| Branch | `docs/SCRUM-211-test-plan` |
| Commit | `docs: Test Plan tổng 5 module` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- docs/TestPlan.md

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 12/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-211
- **Bằng chứng hoàn thành:** Link PR
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
