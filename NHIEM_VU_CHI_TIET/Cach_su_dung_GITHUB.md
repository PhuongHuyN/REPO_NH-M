# Cách sử dụng GitHub – Branch, Commit & Pull Request

Quy trình bắt buộc cho cả 5 thành viên. **Không sửa và không push trực tiếp lên `main`.** Mọi thay đổi đi qua Pull Request (PR); Leader (Huy) review và merge.

## 1. Hiện trạng repository (kiểm tra ngày 05/11/2026)

| Mục | Giá trị |
|---|---|
| Repository | https://github.com/PhuongHuyN/REPO_NH-M |
| Nhánh mặc định | `main` |
| Nhánh đang có | `main`, `app-khung` (đã merge, có thể xóa), `tv3-sales` (2 commit chờ merge), `tv4-iot` (3 commit chờ merge), `check-nv-chua-hoan-thien-xa` (1 commit chờ merge) |
| Quy ước nhánh đang dùng | `tvN-module` (vd. `tv2-inventory`, `tv3-sales`) |
| Quy ước commit đang dùng | `feat(phạm-vi): ...`, `test(...)`, `docs(...)` – xem `app/CONTRIBUTING.md` |
| Cách merge | Pull Request → CI (`.github/workflows/ci.yml`: check-sync + npm test) phải xanh → merge |
| Mẫu PR | `.github/pull_request_template.md` (đã có) |

**Quyết định:** từ 06/11 mỗi task tạo **nhánh riêng** theo mẫu `loại/MÃ-JIRA-mô-tả` (vd. `feature/SCRUM-12-inventory-tables`). Ba nhánh cũ `tv3-sales`, `tv4-iot`, `check-nv-chua-hoan-thien-xa` **giữ nguyên tên** cho đến khi merge xong (FV-09, FV-12, FV-15), sau đó xóa.

## 2. Quy ước đặt tên nhánh

| Tiền tố | Dùng khi | Ví dụ |
|---|---|---|
| `feature/` | thêm chức năng/đối tượng CSDL mới | `feature/SCRUM-12-inventory-tables` |
| `fix/` | sửa lỗi | `fix/SCRUM-18-foreign-keys` |
| `refactor/` | tái cấu trúc, đổi tên file | `refactor/SCRUM-24-machine-table` |
| `test/` | viết/cải thiện kiểm thử | `test/SCRUM-30-inventory-tests` |
| `docs/` | tài liệu | `docs/SCRUM-40-test-plan` |
| `chore/` | cấu hình, bảo trì | `chore/SCRUM-27-thu-tu-file` |

Mã task trong tài liệu là `FV-xx`; khi đã tạo Jira, thay bằng mã Jira tương ứng (bảng ánh xạ trong `JIRA_GUIDE.md`). Không dùng chung nhánh với người khác, không đặt trùng tên.

## 3. Tạo nhánh và đồng bộ code (làm mỗi khi bắt đầu task mới)

Mở VS Code → *Terminal → New Terminal* (PowerShell), đứng ở thư mục repo (ví dụ `C:\Users\<tên>\Desktop\REPO_NH-M`).

| Bước | Lệnh | Ý nghĩa | Kết quả đúng |
|---|---|---|---|
| 1 | `git status` | Xem có file nào đang sửa dở | `nothing to commit, working tree clean` (nếu có file dở: commit hoặc `git stash`) |
| 2 | `git branch` | Xem đang ở nhánh nào | Dòng có `*` là nhánh hiện tại |
| 3 | `git checkout main` | Về nhánh chính | `Switched to branch 'main'` |
| 4 | `git pull origin main` | Lấy code mới nhất của nhóm | `Already up to date` hoặc danh sách file mới |
| 5 | `git checkout -b feature/SCRUM-12-inventory-tables` | Tạo nhánh cho task | `Switched to a new branch ...` |
| 6 | `git branch` | Kiểm tra lại | `*` ở nhánh mới |

Lần đầu trên máy: khai báo người commit (dùng **email đăng ký GitHub** để GitHub ghi nhận đúng người):
```powershell
git config --global user.name "Ho Ten"
git config --global user.email "email-github@gmail.com"
```

## 4. Commit và Push

```powershell
git status                                   # xem file đã đổi
git add sql/11_procs_inventory.sql           # add ĐÚNG file của task (hạn chế "git add .")
git commit -m "feat(sql-inventory): sp_AddProduct, sp_UpdatePrice"
git pull origin main                         # lấy phần mới của nhóm trước khi push
git push -u origin feature/SCRUM-12-inventory-tables
```

| Loại commit | Dùng khi |
|---|---|
| `feat:` | thêm chức năng |
| `fix:` | sửa lỗi |
| `docs:` | tài liệu |
| `refactor:` | tái cấu trúc |
| `test:` | kiểm thử |
| `chore:` | cấu hình, bảo trì |

Thêm phạm vi trong ngoặc: `feat(sql-auth)`, `fix(api)`, `docs(inventory)`.

**Không commit:** `app/api/.env` (mật khẩu), file `.bak`, `node_modules/`, `web/uploads/`, ảnh/video lớn (đưa lên Drive), file không thuộc task.

## 5. Tạo Pull Request

1. Sau `git push`, terminal in link `https://github.com/PhuongHuyN/REPO_NH-M/pull/new/<tên-nhánh>` → mở link (hoặc tab **Pull requests → New pull request**, chọn `base: main` ← `compare: <nhánh>`).
2. Tiêu đề: `[SCRUM-12] Bảng inventory: hạn dùng, SlotStock, TVP, Temporal`.
3. Nội dung theo mẫu:

```markdown
## Summary
Mô tả ngắn những gì đã làm.

## Related Jira Task
SCRUM-12

## Changes
- ...

## Testing
- [ ] Unit Test (tests/*.sql hoặc npm test)
- [ ] Integration Test
- [ ] Manual Test (SSMS / trình duyệt)

## Screenshots / Evidence
(ảnh SSMS, ảnh trang web)

## Checklist
- [ ] Đã chạy toàn bộ script trên CSDL trống, không lỗi
- [ ] Không chứa mật khẩu, .env
- [ ] Không sửa file của module khác (hoặc đã báo người phụ trách)
- [ ] Đã cập nhật tài liệu liên quan
- [ ] npm test xanh
```
4. Bên phải: **Reviewers → PhuongHuyN (Huy)**.
5. Bấm **Create pull request**. Dán link PR vào task Jira (ô *Development* hoặc comment).

## 6. Leader review và merge

Leader kiểm tra: (1) đúng yêu cầu task Jira và tiêu chí nghiệm thu; (2) không ảnh hưởng module khác; (3) CI xanh; (4) chạy thử script trên CSDL trống; (5) không có conflict.

- Có lỗi → **Review changes → Request changes**, ghi file + dòng + lỗi.
- Đạt → **Approve** → **Squash and merge** → **Delete branch**.

Không merge khi: lỗi nghiêm trọng, chưa đạt tiêu chí nghiệm thu, test thất bại, còn conflict, chưa được duyệt.

## 7. Xử lý conflict

```powershell
git checkout feature/SCRUM-12-inventory-tables
git fetch origin
git merge origin/main
```
VS Code đánh dấu đoạn xung đột (`<<<<<<<`, `=======`, `>>>>>>>`). Với mỗi đoạn: đọc hiểu cả hai phía, giữ đúng phần cần, xóa dấu đánh dấu. **Không chọn hết một phía khi chưa hiểu.** File của người khác → hỏi người đó.
```powershell
git add <file đã sửa>
git commit -m "fix: resolve merge conflicts with main"
git push
```

## 8. Sau khi PR được merge

```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-12-inventory-tables
```
Task mới → tạo nhánh mới từ `main` vừa cập nhật. Không làm tiếp trên nhánh đã merge.

## 9. Workflow theo tuần

- **Tuần 1 – Nền tảng (06–12/11):** merge 3 nhánh tồn đọng theo thứ tự `tv4-iot → tv3-sales → check-nv-chua-hoan-thien-xa`; bảng + procedure lõi; mỗi PR nhỏ; cuối tuần `main` chạy toàn bộ script không lỗi.
- **Tuần 2 – Phát triển & tích hợp (13–19/11):** nhánh theo mã Jira; view/function/trigger/phần khó; nối app với SQL thật; không merge PR chưa chạy trên CSDL trống.
- **Tuần 3 – Kiểm thử & hoàn thiện (20–26/11):** nhánh `fix/`, `test/`, `docs/`; code freeze 24/11 18h; tag `v1.0` ngày 26/11.

## 10. Bảng theo dõi GitHub (có trong mỗi file nhiệm vụ)

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-xx |
| Branch | feature/SCRUM-xx-ten-task |
| Commit | feat: ... |
| Pull Request | Link PR |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | dd/mm/2026 |

## 11. Hai thành viên cùng sửa một file

| File chung | Người sửa | Cách tránh xung đột |
|---|---|---|
| `sql/03_foreign_keys.sql` | Toàn (chủ file); Anh, Huy, Dũng cần thêm FK | Gửi FK cần thêm cho Toàn qua GitHub Issue; chỉ Toàn sửa |
| `README.md`, `app/README.md` | Anh (FV-16); Ân thêm mục Docker (FV-11) | Anh merge trước; Ân pull rồi mới sửa mục Docker |
| `docs/UserManual_Operator.md` | Huy (tồn kho), Dũng (máy, cảnh báo) | Huy tạo file với 2 mục trống; Dũng chỉ sửa mục của mình |
| `sql/12_procs_sales.sql` | Ân; Huy cần xóa khối SlotStock | Ân xóa (FV-09) sau khi Huy merge FV-02 |
| `app/api/src/db.js`, `config.js`, `lib/` | Chỉ Huy (FV-20) | Người khác báo lỗi qua Issue |
