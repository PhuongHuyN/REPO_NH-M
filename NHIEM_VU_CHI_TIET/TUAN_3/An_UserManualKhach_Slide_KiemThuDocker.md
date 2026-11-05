# Ân – Tuần 3: Sprint 3 – Kiểm thử, tài liệu, demo

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Đoàn Phương Thiên Ân
- **Email:** thienann2611@gmail.com
- **Tuần:** 3 (Sprint 3 – Kiểm thử, tài liệu, demo)
- **Thời gian:** 20/11/2026 → 26/11/2026
- **Vai trò:** TV3 – Bán hàng & Thanh toán (schema sales), Kiosk, Docker, slide bảo vệ
- **Mức độ ưu tiên:** High
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-233, SCRUM-234, SCRUM-235

**Mục tiêu Sprint:** Test Report có số liệu thật, đủ tài liệu bắt buộc của đề, Docker chạy được, tag v1.0, tổng duyệt demo và vấn đáp.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-39 (SCRUM-233) | User Manual Khách hàng (màn hình kiosk) có ảnh chạy SQL thật | 20/11/2026 | 21/11/2026 | Medium | FV-20 |
| FV-40 (SCRUM-234) | Slide bảo vệ (15–20 trang) + phân công người trình bày | 22/11/2026 | 24/11/2026 | High | FV-34, FV-43, FV-45 |
| FV-41 (SCRUM-235) | Kiểm thử Docker trên máy sạch và sửa lỗi | 25/11/2026 | 25/11/2026 | Medium | FV-11, FV-23 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-39 (SCRUM-233) – User Manual Khách hàng (màn hình kiosk) có ảnh chạy SQL thật

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 20/11/2026 → 21/11/2026 |
| Mức ưu tiên | Medium |
| Epic | E3 – Bán hàng & Thanh toán (sales) |
| Phụ thuộc | FV-20 (SCRUM-214) (Huy) |
| Người hỗ trợ | Không |

### 1. MỤC TIÊU
User Manual Khách hàng (màn hình kiosk) có ảnh chạy SQL thật. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Đề yêu cầu User Manual riêng cho Customer, Operator, Admin.

### 3. PHẠM VI CÔNG VIỆC
- `docs/UserManual_Customer.md`: chọn món, giỏ hàng, thanh toán QR, nhận hàng, khi kẹt hàng/hoàn tiền, khi máy *Tạm ngưng*.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Chụp ảnh**
Chạy app DB_MODE=sqlserver + simulator, mở /kiosk, F11, chụp từng màn hình.

**Bước 2. Viết**
Mỗi mục: mục đích – bước – ảnh – lưu ý.

### 5. FILE VÀ MODULE LIÊN QUAN
- `docs/UserManual_Customer.md` (mới)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Dùng ảnh cho slide (FV-40).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Đọc thử | Nhờ 1 người ngoài nhóm đọc và mua thử | Mua được không cần hỏi |

**Kết quả cần lưu lại:** Link PR.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Đủ 6 tình huống, có ảnh thật

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-233-usermanual-customer
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add docs/UserManual_Customer.md
git commit -m "docs: user manual khách hàng"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-233-usermanual-customer
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-233-usermanual-customer`.
7. **Mô tả PR:** tiêu đề `[SCRUM-233] User Manual Khách hàng (màn hình kiosk) có ảnh chạy SQL thật`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-233`; dán ảnh bằng chứng: Link PR.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-233-usermanual-customer
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-233 |
| Branch | `docs/SCRUM-233-usermanual-customer` |
| Commit | `docs: user manual khách hàng` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- docs/UserManual_Customer.md

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 21/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-233
- **Bằng chứng hoàn thành:** Link PR
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-40 (SCRUM-234) – Slide bảo vệ (15–20 trang) + phân công người trình bày

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 22/11/2026 → 24/11/2026 |
| Mức ưu tiên | High |
| Epic | E6 – Tích hợp, Triển khai & Tài liệu |
| Phụ thuộc | FV-34 (SCRUM-228) (Huy), FV-43 (SCRUM-237) (Dũng), FV-45 (SCRUM-239) (Anh) |
| Người hỗ trợ | Huy, Toàn, Dũng, Anh |

### 1. MỤC TIÊU
Slide bảo vệ (15–20 trang) + phân công người trình bày. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Slide dẫn dắt buổi bảo vệ; mỗi thành viên trình bày phần mình ~3 phút.

### 3. PHẠM VI CÔNG VIỆC
- Bố cục: bài toán – giải pháp 6 trụ cột – kiến trúc – ERD – 5 module (mỗi người 2 slide) – kiểm thử – demo – hạn chế & hướng phát triển.
- Ghi rõ: phần cứng ESP32 **mô phỏng**, thanh toán VietQR xác nhận giả lập/thủ công.
- Lưu `docs/Slide_BaoVe.pptx`.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Thu nội dung**
22/11 nhắn mỗi người gửi 2 slide module mình (ảnh + 3 ý chính).

**Bước 2. Ghép**
23–24/11 ghép, thống nhất font/màu xanh–cam của app.

**Bước 3. Duyệt**
Tổng duyệt 25/11 (FV-35).

### 5. FILE VÀ MODULE LIÊN QUAN
- `docs/Slide_BaoVe.pptx` (mới)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Cả nhóm gửi nội dung trước 23/11 12h.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Bấm giờ | Trình bày thử | ≤ 20 phút |

**Kết quả cần lưu lại:** Link PR.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Đủ phần của 5 người
- [ ] Không tuyên bố đã thử phần cứng thật

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-234-slide
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add docs/Slide_BaoVe.pptx
git commit -m "docs: slide bảo vệ"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-234-slide
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-234-slide`.
7. **Mô tả PR:** tiêu đề `[SCRUM-234] Slide bảo vệ (15–20 trang) + phân công người trình bày`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-234`; dán ảnh bằng chứng: Link PR.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-234-slide
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-234 |
| Branch | `docs/SCRUM-234-slide` |
| Commit | `docs: slide bảo vệ` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- docs/Slide_BaoVe.pptx

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 24/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-234
- **Bằng chứng hoàn thành:** Link PR
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-41 (SCRUM-235) – Kiểm thử Docker trên máy sạch và sửa lỗi

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 25/11/2026 → 25/11/2026 |
| Mức ưu tiên | Medium |
| Epic | E6 – Tích hợp, Triển khai & Tài liệu |
| Phụ thuộc | FV-11 (SCRUM-205) (Ân), FV-23 (SCRUM-217) (Toàn) |
| Người hỗ trợ | Toàn |

### 1. MỤC TIÊU
Kiểm thử Docker trên máy sạch và sửa lỗi. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Gói Docker là sản phẩm phải nộp; cần chứng minh chạy được ngoài máy người viết.

### 3. PHẠM VI CÔNG VIỆC
- Clone repo vào thư mục mới trên máy khác (hoặc xóa image/volume cũ).
- Chạy theo hướng dẫn Docker trong InstallGuide.
- Sửa lỗi, cập nhật tài liệu.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Làm sạch**
`docker compose down -v` → `docker system prune -a` (xác nhận trước khi xóa).

**Bước 2. Chạy lại**
Làm đúng theo InstallGuide mục Docker, ghi thời gian.

### 5. FILE VÀ MODULE LIÊN QUAN
- `app/Dockerfile`
- `docker-compose.yml`
- `docs/InstallGuide.md`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Toàn sửa InstallGuide nếu cần.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Máy sạch | Theo InstallGuide | API + DB chạy, mua được 1 đơn |

**Kết quả cần lưu lại:** Ảnh docker compose ps.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Chạy được trên máy sạch

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b fix/SCRUM-235-docker
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add app/Dockerfile docker-compose.yml docs/InstallGuide.md
git commit -m "fix(docker): sửa lỗi khi chạy trên máy sạch"
```
5. **Push**
```powershell
git pull origin main
git push -u origin fix/SCRUM-235-docker
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: fix/SCRUM-235-docker`.
7. **Mô tả PR:** tiêu đề `[SCRUM-235] Kiểm thử Docker trên máy sạch và sửa lỗi`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-235`; dán ảnh bằng chứng: Ảnh docker compose ps.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d fix/SCRUM-235-docker
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-235 |
| Branch | `fix/SCRUM-235-docker` |
| Commit | `fix(docker): sửa lỗi khi chạy trên máy sạch` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- Docker chạy được

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 25/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-235
- **Bằng chứng hoàn thành:** Ảnh docker compose ps
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
