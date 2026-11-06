# Anh – Tuần 3: Sprint 3 – Kiểm thử, tài liệu, demo

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Nguyễn Phạm Xuân Anh
- **Email:** modz06j.xuananhngxph@gmail.com
- **Tuần:** 3 (Sprint 3 – Kiểm thử, tài liệu, demo)
- **Thời gian:** 20/11/2026 → 26/11/2026
- **Vai trò:** TV5 – Báo cáo & Phân tích (schema report), QA: kiểm thử tích hợp, hiệu năng, Test Report
- **Mức độ ưu tiên:** Highest
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-239, SCRUM-240

**Mục tiêu Sprint:** Test Report có số liệu thật, đủ tài liệu bắt buộc của đề, Docker chạy được, tag v1.0, tổng duyệt demo và vấn đáp.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-45 (SCRUM-239) | Test Report với kết quả thật: unit (SQL + npm test), integration, performance, chuỗi lạnh (mô phỏng) | 20/11/2026 | 22/11/2026 | Highest | FV-32, FV-31, FV-36, FV-42 |
| FV-46 (SCRUM-240) | User Manual Admin + ghép Báo cáo tổng (BaoCao) từ tài liệu của cả nhóm | 23/11/2026 | 25/11/2026 | High | FV-34, FV-37, FV-43, FV-45 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-45 (SCRUM-239) – Test Report với kết quả thật: unit (SQL + npm test), integration, performance, chuỗi lạnh (mô phỏng)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 20/11/2026 → 22/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E5 – Báo cáo & Kiểm thử (report, QA) |
| Phụ thuộc | FV-32 (SCRUM-226) (Anh), FV-31 (SCRUM-225) (Anh), FV-36 (SCRUM-230) (Toàn), FV-42 (SCRUM-236) (Dũng) |
| Người hỗ trợ | Huy, Toàn, Ân, Dũng |

### 1. MỤC TIÊU
Test Report với kết quả thật: unit (SQL + npm test), integration, performance, chuỗi lạnh (mô phỏng). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
`docs/TestReport.md` trên main ghi 12/12 PASS dù procedure auth/inventory chưa tồn tại lúc đó. Bản nộp phải là số liệu chạy thật, có ngày giờ, môi trường, log.

### 3. PHẠM VI CÔNG VIỆC
- Unit: kết quả 5 file `tests/tests_<module>.sql` + `npm test`.
- Integration: FV-32.
- Performance: FV-31.
- Chuỗi lạnh: 5 kịch bản FV-29 (ghi rõ dữ liệu mô phỏng).
- Danh sách lỗi đã sửa/còn lại.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Chạy lại toàn bộ**
20/11 trên CSDL sạch: 5 file test + `npm test` + `EXEC report.sp_RunAllTests`.

**Bước 2. Viết**
Bảng tổng (module × Pass/Fail/Blocked), chi tiết, ảnh.

### 5. FILE VÀ MODULE LIÊN QUAN
- `docs/TestReport.md`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
4 bạn gửi log test module trước 21/11.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Tự kiểm | So số ca trong report với file test | Khớp |

**Kết quả cần lưu lại:** Link PR.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Mọi số liệu có ngày chạy thật
- [ ] Không ghi PASS cho ca chưa chạy

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-239-test-report
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add docs/TestReport.md
git commit -m "docs: Test Report kết quả thật"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-239-test-report
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-239-test-report`.
7. **Mô tả PR:** tiêu đề `[SCRUM-239] Test Report với kết quả thật: unit (SQL + npm test), integration, performance, chuỗi lạnh (mô phỏng)`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-239`; dán ảnh bằng chứng: Link PR.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-239-test-report
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-239 |
| Branch | `docs/SCRUM-239-test-report` |
| Commit | `docs: Test Report kết quả thật` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- docs/TestReport.md

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 22/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-239
- **Bằng chứng hoàn thành:** Link PR
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-46 (SCRUM-240) – User Manual Admin + ghép Báo cáo tổng (BaoCao) từ tài liệu của cả nhóm

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 23/11/2026 → 25/11/2026 |
| Mức ưu tiên | High |
| Epic | E6 – Tích hợp, Triển khai & Tài liệu |
| Phụ thuộc | FV-34 (SCRUM-228) (Huy), FV-37 (SCRUM-231) (Toàn), FV-43 (SCRUM-237) (Dũng), FV-45 (SCRUM-239) (Anh) |
| Người hỗ trợ | Huy |

### 1. MỤC TIÊU
User Manual Admin + ghép Báo cáo tổng (BaoCao) từ tài liệu của cả nhóm. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
`docs/UserManual.md` hiện có phần báo cáo của TV5. Báo cáo tổng phải gom URS/SRS, kiến trúc, ERD, thiết kế chi tiết, triển khai, kiểm thử, cài đặt, 3 user manual.

### 3. PHẠM VI CÔNG VIỆC
- `docs/UserManual_Admin.md` (đổi tên từ UserManual.md, bổ sung: quản lý người dùng, cấu hình ngưỡng, xuất CSV).
- `docs/BaoCao.docx` hoặc `.md`: mục lục theo đề mục e) Theory & Practical.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Ghép**
Mỗi chương lấy từ file của người phụ trách; chỉ sửa định dạng, không sửa nội dung kỹ thuật.

**Bước 2. Đọc chéo**
25/11 nhờ Huy đọc toàn bộ.

### 5. FILE VÀ MODULE LIÊN QUAN
- `docs/UserManual_Admin.md`
- `docs/BaoCao.(docx|md)`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Cần tài liệu của Huy (FV-34), Toàn (FV-37), Dũng (FV-43), Ân (FV-26, FV-39).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Đủ mục đề | So với đề mục e) | Đủ 6 nhóm tài liệu |

**Kết quả cần lưu lại:** Link PR.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Báo cáo đủ mục, thống nhất tên/ngày

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-240-usermanual-admin-baocao
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add docs/UserManual_Admin.md
git commit -m "docs: user manual admin + báo cáo tổng"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-240-usermanual-admin-baocao
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-240-usermanual-admin-baocao`.
7. **Mô tả PR:** tiêu đề `[SCRUM-240] User Manual Admin + ghép Báo cáo tổng (BaoCao) từ tài liệu của cả nhóm`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-240`; dán ảnh bằng chứng: Link PR.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-240-usermanual-admin-baocao
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-240 |
| Branch | `docs/SCRUM-240-usermanual-admin-baocao` |
| Commit | `docs: user manual admin + báo cáo tổng` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- docs/UserManual_Admin.md
- docs/BaoCao

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 25/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-240
- **Bằng chứng hoàn thành:** Link PR
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
