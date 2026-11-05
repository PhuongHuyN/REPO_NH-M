# Anh – Tuần 2: Sprint 2 – Đủ object & nối app với SQL Server thật

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Nguyễn Phạm Xuân Anh
- **Email:** modz06j.xuananhngxph@gmail.com
- **Tuần:** 2 (Sprint 2 – Đủ object & nối app với SQL Server thật)
- **Thời gian:** 13/11/2026 → 19/11/2026
- **Vai trò:** TV5 – Báo cáo & Phân tích (schema report), QA: kiểm thử tích hợp, hiệu năng, Test Report
- **Mức độ ưu tiên:** Highest
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-224, SCRUM-225, SCRUM-226

**Mục tiêu Sprint:** Đủ view/function/trigger/phần khó của 5 module; phân quyền 4 login; app chạy DB_MODE=sqlserver qua trọn kịch bản châm hàng → mua → nhả hàng → cảnh báo → báo cáo.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-30 (SCRUM-224) | Cập nhật sp_RunAllTests phủ 5 module và seed nhỏ/lớn theo schema thật | 13/11/2026 | 15/11/2026 | High | FV-16, FV-08, FV-04, FV-24 |
| FV-31 (SCRUM-225) | 70_perf_tests.sql: so sánh Execution Plan trước/sau index, đo thời gian truy vấn báo cáo trên dữ liệu lớn | 16/11/2026 | 17/11/2026 | Medium | FV-30, FV-19, FV-27 |
| FV-32 (SCRUM-226) | Kiểm thử tích hợp end-to-end trên SQL thật: châm hàng → mua → thanh toán → nhả → cảnh báo → báo cáo | 18/11/2026 | 19/11/2026 | Highest | FV-20, FV-29 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-30 (SCRUM-224) – Cập nhật sp_RunAllTests phủ 5 module và seed nhỏ/lớn theo schema thật

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 13/11/2026 → 15/11/2026 |
| Mức ưu tiên | High |
| Epic | E5 – Báo cáo & Kiểm thử (report, QA) |
| Phụ thuộc | FV-16 (SCRUM-210) (Anh), FV-08 (SCRUM-202) (Toàn), FV-04 (SCRUM-198) (Huy), FV-24 (SCRUM-218) (Ân) |
| Người hỗ trợ | Huy |

### 1. MỤC TIÊU
Cập nhật sp_RunAllTests phủ 5 module và seed nhỏ/lớn theo schema thật. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
`report.sp_RunAllTests` có 12 ca nhưng ca auth/inventory từng ghi PASS khi procedure chưa tồn tại, TC-11 (partition) luôn PASS. Trang *Kiểm thử hệ thống* của app hiển thị kết quả này – hội đồng có thể bấm chạy thử.

### 3. PHẠM VI CÔNG VIỆC
- Mỗi ca gọi procedure thật trong `BEGIN TRAN ... ROLLBACK`, so mã lỗi thật.
- Xóa nhánh “chấp nhận nếu không có partition” ở TC-11.
- Seed `80_seed_small` (3 địa điểm, 5 máy, 10 sản phẩm, 50 đơn, tài khoản demo) và `81_seed_large` (20 máy, 5.000 đơn, 200.000 telemetry) chèn qua bảng thật/procedure thật.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Sửa ca**
Mở `sql/14_procs_report.sql`, tìm từng `INSERT #Results`. Ca nào gọi procedure chưa có → đợi chủ module merge rồi mới bật; tạm thời ghi `BLOCKED` (không ghi PASS).

**Bước 2. Seed**
Seed máy qua `iot.sp_RegisterMachine`, sản phẩm qua `inventory.sp_AddProduct`, lô qua `sp_AddBatch`, châm qua `sp_Restock`, đơn qua `sales.sp_CreateOrder` → seed cũng là test tích hợp.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/14_procs_report.sql`
- `sql/80_seed_small.sql`
- `sql/81_seed_large.sql`
- `app/web/js/pages/tests.js` (hiển thị)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** procedure của 4 bạn. **Đầu ra cho:** FV-31, FV-45.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | RunAllTests | EXEC report.sp_RunAllTests | Mọi ca PASS thật, không có ca giả PASS |
| 2 | Seed 2 lần | Chạy seed lại | Không trùng, tổng tiền không đổi |

**Kết quả cần lưu lại:** Ảnh trang Kiểm thử hệ thống.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Không còn ca PASS giả
- [ ] Seed chạy qua procedure thật
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
git checkout -b feature/SCRUM-224-run-all-tests-seed
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/14_procs_report.sql sql/80_seed_small.sql sql/81_seed_large.sql
git commit -m "feat(sql-report): sp_RunAllTests phủ 5 module, seed theo schema thật"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-224-run-all-tests-seed
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-224-run-all-tests-seed`.
7. **Mô tả PR:** tiêu đề `[SCRUM-224] Cập nhật sp_RunAllTests phủ 5 module và seed nhỏ/lớn theo schema thật`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-224`; dán ảnh bằng chứng: Ảnh trang Kiểm thử hệ thống.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-224-run-all-tests-seed
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-224 |
| Branch | `feature/SCRUM-224-run-all-tests-seed` |
| Commit | `feat(sql-report): sp_RunAllTests phủ 5 module, seed theo schema thật` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/14_procs_report.sql
- sql/80_seed_small.sql
- sql/81_seed_large.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 15/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-224
- **Bằng chứng hoàn thành:** Ảnh trang Kiểm thử hệ thống
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-31 (SCRUM-225) – 70_perf_tests.sql: so sánh Execution Plan trước/sau index, đo thời gian truy vấn báo cáo trên dữ liệu lớn

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 16/11/2026 → 17/11/2026 |
| Mức ưu tiên | Medium |
| Epic | E5 – Báo cáo & Kiểm thử (report, QA) |
| Phụ thuộc | FV-30 (SCRUM-224) (Anh), FV-19 (SCRUM-213) (Huy), FV-27 (SCRUM-221) (Dũng) |
| Người hỗ trợ | Dũng |

### 1. MỤC TIÊU
70_perf_tests.sql: so sánh Execution Plan trước/sau index, đo thời gian truy vấn báo cáo trên dữ liệu lớn. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Phần khó TV5 + yêu cầu phi chức năng: API ≤ 500 ms cho 95% request. Nhánh TV5 đã có `tests/sql/38_perf_report.sql` – chuyển thành `tests/70_perf_tests.sql` và đo lại trên schema mới (có partition của TV4, index của TV2).

### 3. PHẠM VI CÔNG VIỆC
- `SET STATISTICS TIME, IO ON` cho 5 truy vấn báo cáo chính.
- Chạy trước/sau tạo index; lưu ảnh Execution Plan (Ctrl+M).
- Đo API bằng PowerShell `Measure-Command` 100 lần cho 3 route báo cáo.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Đo SQL**
```sql
SET STATISTICS TIME, IO ON;
EXEC report.sp_PeakHours @From = '2026-08-01', @To = '2026-11-01';
SET STATISTICS TIME, IO OFF;
```
Ghi *CPU time*, *elapsed time*, *logical reads*.

**Bước 2. Đo API**
```powershell
$t = 1..100 | ForEach-Object { (Measure-Command { Invoke-RestMethod http://localhost:3000/api/reports/kpi -Headers @{Authorization="Bearer $token"} }).TotalMilliseconds }
($t | Sort-Object)[94]   # P95
```

### 5. FILE VÀ MODULE LIÊN QUAN
- `tests/70_perf_tests.sql` (mới, từ 38_perf_report.sql)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Dũng: so truy vấn telemetry có/không partition.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | P95 API | 100 lần /api/reports/kpi | ≤ 500 ms |
| 2 | Index | Trước/sau | logical reads giảm |

**Kết quả cần lưu lại:** Ảnh plan + bảng số.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Có bảng số liệu trước/sau
- [ ] Có ảnh Execution Plan

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b test/SCRUM-225-perf-tests
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add tests/70_perf_tests.sql
git commit -m "test(sql-report): 70_perf_tests – execution plan trước/sau index"
```
5. **Push**
```powershell
git pull origin main
git push -u origin test/SCRUM-225-perf-tests
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: test/SCRUM-225-perf-tests`.
7. **Mô tả PR:** tiêu đề `[SCRUM-225] 70_perf_tests.sql: so sánh Execution Plan trước/sau index, đo thời gian truy vấn báo cáo trên dữ liệu lớn`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-225`; dán ảnh bằng chứng: Ảnh plan + bảng số.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d test/SCRUM-225-perf-tests
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-225 |
| Branch | `test/SCRUM-225-perf-tests` |
| Commit | `test(sql-report): 70_perf_tests – execution plan trước/sau index` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- tests/70_perf_tests.sql
- Bảng số liệu

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 17/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-225
- **Bằng chứng hoàn thành:** Ảnh plan + bảng số
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-32 (SCRUM-226) – Kiểm thử tích hợp end-to-end trên SQL thật: châm hàng → mua → thanh toán → nhả → cảnh báo → báo cáo

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 18/11/2026 → 19/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E6 – Tích hợp, Triển khai & Tài liệu |
| Phụ thuộc | FV-20 (SCRUM-214) (Huy), FV-29 (SCRUM-223) (Dũng) |
| Người hỗ trợ | Huy, Ân, Dũng |

### 1. MỤC TIÊU
Kiểm thử tích hợp end-to-end trên SQL thật: châm hàng → mua → thanh toán → nhả → cảnh báo → báo cáo. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Kế hoạch yêu cầu cuối tuần 2–3 chạy một mạch kịch bản xuyên 5 module trên CSDL thật. Huy lo kết nối (FV-20), Anh là người **thực hiện và ghi bằng chứng** theo Test Plan.

### 3. PHẠM VI CÔNG VIỆC
- 10 bước kịch bản (bảng mục 7), mỗi bước ghi Pass/Fail + ảnh.
- Lỗi → GitHub Issue gán chủ module.
- Chạy lại sau khi sửa.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Chuẩn bị**
CSDL sạch bằng `99_run_all.bat` + `80_seed_small`; `npm start` (sqlserver); simulator chạy nền.

**Bước 2. Thực hiện**
Làm lần lượt 10 bước ở mục 7, mỗi bước chụp 1 ảnh, ghi thời gian.

### 5. FILE VÀ MODULE LIÊN QUAN
- `docs/TestReport.md` (sửa – mục Integration)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Huy, Ân, Dũng có mặt online để sửa nhanh.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | 1 Đăng nhập operator01 | Web | Thấy 3 máy |
| 2 | 2 Nhập lô + châm hàng | Trang Châm hàng | Tồn tăng |
| 3 | 3 Kiosk mua 2 món | /kiosk | Mã VietQR |
| 4 | 4 Xác nhận tiền | Giả lập đã chuyển khoản | Đơn PAID |
| 5 | 5 Máy nhả | Simulator | DISPENSED |
| 6 | 6 Tồn giảm FIFO | vw_OrderDetail | Lấy lô cũ |
| 7 | 7 Quá nhiệt máy 3 | --overheat 3 | Cảnh báo + Tạm ngưng |
| 8 | 8 Kẹt máy 1 | --jam 1 | REFUNDED |
| 9 | 9 Admin xem báo cáo | Trang Báo cáo | Có đơn mới |
| 10 | 10 Operator vào báo cáo | operator01 | 403 |

**Kết quả cần lưu lại:** Thư mục ảnh.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 10/10 bước Pass trên SQL thật
- [ ] Mọi bước có ảnh

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-226-integration-test
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add docs/TestReport.md
git commit -m "docs(test): kết quả kiểm thử tích hợp end-to-end"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-226-integration-test
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-226-integration-test`.
7. **Mô tả PR:** tiêu đề `[SCRUM-226] Kiểm thử tích hợp end-to-end trên SQL thật: châm hàng → mua → thanh toán → nhả → cảnh báo → báo cáo`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-226`; dán ảnh bằng chứng: Thư mục ảnh.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-226-integration-test
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-226 |
| Branch | `docs/SCRUM-226-integration-test` |
| Commit | `docs(test): kết quả kiểm thử tích hợp end-to-end` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- Mục Integration trong TestReport.md

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 19/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-226
- **Bằng chứng hoàn thành:** Thư mục ảnh
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
