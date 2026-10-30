# QUY TẮC ĐỒNG BỘ FE ⇄ BE — để ai clone về cũng chạy được ngay

> Tóm tắt: **clone → `npm install` → `npm run setup` → `npm test` xanh → `npm start`.**
> Trước khi commit luôn chạy `npm test`. CI trên GitHub chạy lại y hệt — đỏ là không merge.

## 1. Người mới clone repo

```powershell
git clone https://github.com/PhuongHuyN/REPO_NH-M
cd REPO_NH-M/app
npm install          # cài cho cả api/ (postinstall)
npm run demo         # CHƯA có SQL Server? chạy luôn bằng dữ liệu giả lập (bỏ qua các bước dưới)
npm run setup        # tạo api/.env từ .env.example + kiểm tra đồng bộ
# mở api/.env, điền DB_* (theo 26_security.sql) và PAYMENT_*
npm test             # phải thấy: ✔ FE và BE khớp nhau  + toàn bộ test pass
npm start            # http://localhost:3000  ·  /kiosk
```

Không có SQL Server vẫn chạy được `npm test` (CSDL mô phỏng `api/test/fakeDb.js`).

### Giai đoạn hiện tại: làm FE trước, DB kết nối sau
- Chạy `npm run demo` (DB_MODE=demo): API + web chạy trên **CSDL giả lập `api/test/fakeDb.js`** – cùng tên stored procedure / view / cột với SQL thật.
- Web **không bao giờ** biết đang demo hay thật: luôn gọi API như nhau. Khi SQL Server xong chỉ đổi `DB_MODE=sqlserver` trong `api/.env`.
- Thêm/đổi procedure, view, cột ⇒ sửa **cả** `api/test/fakeDb.js` (để demo + test chạy) **và** script SQL bên gói Database, cùng tên, cùng tham số, cùng mã lỗi THROW.
- Route `/api/demo/*` chỉ hoạt động khi `DB_MODE=demo` (máy chủ thật trả 404) – không dùng cho tính năng thật.

## 2. Các quy tắc

| # | Quy tắc | Công cụ tự kiểm tra |
|---|---|---|
| R1 | **Một nguồn sự thật cho API = `api/src/routes/*.js`**. Web (`web/js`) và bộ điều khiển máy (`simulator/`) chỉ gọi đường dẫn có trong đó, đúng METHOD | `tools/check-sync.js` báo `✘ … API không có route này` |
| R2 | Đổi / xóa / đổi tên route ⇒ sửa **cùng commit** mọi chỗ gọi trong `web/js` và `simulator/` | như trên |
| R3 | Trang (`web/js/pages/*.js`) khai báo `roles`. Nút nào gọi API chỉ dành cho Admin thì phải ẩn với Operator (`isAdmin ? … : ''`) và ghi chú `// @roles Admin` cuối dòng gọi API | cảnh báo `⚠ trang cho Operator nhưng … chỉ cho Admin` |
| R4 | Trang mới: tạo `web/js/pages/<ten>.js` và thêm `'<ten>'` vào `PAGE_FILES` trong `web/js/admin.js`. Trang chưa có file thì tự ẩn khỏi menu, không làm hỏng giao diện | `✘ … chưa có trong PAGE_FILES` |
| R5 | Biến môi trường mới ⇒ thêm vào `api/src/config.js` **và** `api/.env.example` (kèm chú thích). **Không commit `api/.env`** | `✘ api/.env.example thiếu biến …` · `npm run setup` báo `.env` của bạn thiếu gì |
| R6 | API **không viết SQL nghiệp vụ**: ghi = `db.exec('<schema>.sp_…')`, đọc = `db.view(...)`. Đổi tên cột/view/procedure trong SQL ⇒ sửa route + `api/test/fakeDb.js` cùng PR | `npm test` (api.test.js, db.test.js) |
| R7 | Tên trường JSON trả về giữ nguyên cách route đang dùng; web đọc đúng tên đó. Không tự đổi tên trường trong một bên | test API + chạy thử trang |
| R8 | Lỗi nghiệp vụ: SQL `THROW 50xxx, N'Thông báo tiếng Việt'` → API trả `{ error, message }` → web hiện nguyên `message`. Dải mã: TV1 500xx · TV2 501xx · TV3 502xx · TV4 503xx · TV5 504xx | review |
| R9 | Node theo `.nvmrc` (20 LTS, tối thiểu 18). Hạn chế thêm thư viện (hiện chỉ có `mssql`). Thêm thư viện ⇒ commit `package-lock.json`, từ đó dùng `npm ci` | CI dùng `npm ci` khi có lock |
| R10 | Xuống dòng LF, UTF-8 (`.gitattributes`, `.editorconfig`, `.vscode/settings.json`) — Windows/macOS sửa chung không bị "đổi cả file" | Git tự chuẩn hóa |
| R11 | Màu, font chỉ khai báo ở `:root` trong `web/css/app.css`; không viết mã màu rải rác | review |
| R12 | Không đưa lên Git: `node_modules/`, `api/.env`, `web/uploads/`, `*.bak`, `*.log` | `.gitignore` |

## 3. Làm việc với Git

- Mỗi người một nhánh: `tv1-auth`, `tv2-inventory`, `tv3-sales`, `tv4-iot`, `tv5-report`.
- Không push thẳng `main`. Tạo Pull Request → điền checklist (tự hiện) → 1 bạn review → CI xanh → merge.
- Trước khi tạo PR: `git pull origin main` rồi `npm test` lại để chắc không lệch với code mới của bạn khác.
- Commit nhỏ, tiêu đề rõ: `feat(sales): hủy đơn khi hết 5 phút`, `fix(web): ẩn nút đăng ký máy với Operator`.

## 4. Lỗi hay gặp khi clone về

| Hiện tượng | Cách sửa |
|---|---|
| `npm` không nhận lệnh | Cài Node.js 20 LTS, mở lại VS Code |
| `Cannot find path ...` khi `cd` | Đang đứng sẵn trong thư mục — gõ `dir` xem cấu trúc rồi `cd` đúng tên |
| Terminal báo `Cơ sở dữ liệu: chưa kết nối` | Sai `DB_*` trong `api/.env`, chưa bật TCP/IP hoặc SQL Authentication (xem README mục 2) |
| Kiosk báo "chưa sẵn sàng nhận thanh toán" | Chưa điền `PAYMENT_BANK_BIN`, `PAYMENT_ACCOUNT_NO`… trong `api/.env` |
| `npm test` báo `✘ … API không có route này` | Web gọi route chưa có / sai METHOD — sửa theo dòng và số dòng được in ra |
| Trang trắng, F12 báo lỗi 404 file `.js` | Tên file / đường dẫn import sai chữ hoa – thường (Linux phân biệt, Windows không) |

## 5. Lộ trình commit lần đầu vào `REPO_NH-M` (đã chạy thử: mọi lần push đều xanh, merge không xung đột)

Repo đã có `sql/`, `docs/`, `README.md` của nhóm → **không xóa, không sửa** những thứ đó; ứng dụng nằm gọn trong thư mục mới `app/`.

**Pull Request 1 – người giữ repo (hoặc TV1) trên nhánh `app-khung`** (4 commit, push 1 lần):

| # | Chép các mục (từ gói `REPO_NH-M_app.zip`) | Commit |
|---|---|---|
| 1 | `.github/` `.vscode/` (gốc repo) + trong `app/`: `.editorconfig .gitattributes .gitignore .nvmrc package.json README.md CONTRIBUTING.md api/package.json api/.env.example` | `chore(app): cấu hình ứng dụng, quy tắc nhóm, CI` |
| 2 | `app/api/src/` `app/api/test/` | `feat(api): REST API + CSDL giả lập (chế độ demo)` |
| 3 | `app/simulator/` `app/tools/` | `feat(tools): bộ điều khiển máy mô phỏng, kiểm tra đồng bộ, npm run demo` |
| 4 | `app/web/admin.html app/web/css/ app/web/img/` + `app/web/js/api.js ui.js icons.js charts.js admin.js` | `feat(web): khung giao diện quản trị` |

**Pull Request 2…6 – mỗi người một nhánh** (từ `main` sau khi PR 1 đã merge):

| Người | Nhánh | Chép | Commit |
|---|---|---|---|
| TV3 | `tv3-sales` | `app/web/kiosk.html app/web/js/kiosk.js`, rồi `app/web/js/pages/orders.js` | `feat(web): màn hình kiosk bán hàng` · `feat(web): trang Đơn hàng` |
| TV2 | `tv2-inventory` | `app/web/js/pages/products.js restock.js` | `feat(web): trang Sản phẩm & giá, Châm hàng` |
| TV4 | `tv4-iot` | `app/web/js/pages/machines.js alerts.js` | `feat(web): trang Máy & chuỗi lạnh, Cảnh báo` |
| TV1 | `tv1-auth` | `app/web/js/pages/users.js` | `feat(web): trang Người dùng` |
| TV5 | `tv5-report` | `app/web/js/pages/dashboard.js reports.js tests.js` | `feat(web): Tổng quan, Báo cáo, Kiểm thử hệ thống` |

```powershell
git checkout main
git pull
git checkout -b tv2-inventory
# chép file của mình vào đúng thư mục app/...
cd app
npm install
npm test
cd ..
git add app
git status            # chỉ thấy file của mình; KHÔNG có node_modules/, app/api/.env, app/web/uploads/
git commit -m "feat(web): trang Sản phẩm & giá, Châm hàng"
git push -u origin tv2-inventory
# GitHub -> "Compare & pull request" -> 1 bạn review -> CI xanh -> Merge
```
