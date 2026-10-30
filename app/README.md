# FreshVend – Ứng dụng

Phần mềm vận hành chuỗi máy bán trái cây tươi tự động FreshVend, gồm:

- **API** (Node.js) – chỉ gọi stored procedure / view của SQL Server, phân quyền theo vai trò.
- **Bảng điều khiển** (`/`) – cho quản trị viên và nhân viên vận hành.
- **Màn hình bán hàng** (`/kiosk`) – chạy trên màn hình cảm ứng gắn ở máy, thanh toán chuyển khoản VietQR.
- **Bộ điều khiển máy** (`simulator/esp32.js`) – gửi nhiệt độ/cửa, nhả hàng khi đơn đã thanh toán. Dùng thay ESP32 khi chưa lắp phần cứng.

Cơ sở dữ liệu nằm ở gói riêng **FreshVend_Database** (T-SQL, chạy bằng SSMS). Hai phần nối với nhau qua file `api/.env`.

```
FreshVend_App/
├─ package.json      lệnh chạy nhanh từ thư mục gốc (npm install / npm start / npm test)
├─ api/
│  ├─ src/routes/    auth.js (TV1) · inventory.js (TV2) · sales.js (TV3) · iot.js (TV4) · report.js (TV5)
│  ├─ src/lib/       vietqr.js (mã VietQR chuẩn NAPAS), qrcode/ (vẽ QR), jwt, router, validate
│  └─ test/          kiểm thử tự động (CSDL mô phỏng trong bộ nhớ, không cần SQL Server)
├─ web/              admin.html · kiosk.html · js/pages/ (mỗi trang ghi thành viên phụ trách)
├─ simulator/        esp32.js – chương trình bộ điều khiển máy
├─ tools/            check-sync.js (kiểm tra FE ⇄ BE) · setup.js (chuẩn bị máy mới)
├─ CONTRIBUTING.md   quy tắc làm việc nhóm, đồng bộ FE ⇄ BE
└─ .vscode/          cấu hình Run and Debug
```

> Thư mục này là **`app/`** trong repo `REPO_NH-M` (cùng cấp `sql/`, `docs/`). Mọi lệnh `npm` bên dưới chạy **trong `app/`**: mở terminal rồi `cd app`.

## 0. Chạy ngay khi CHƯA có cơ sở dữ liệu (chế độ demo)
Đang làm giao diện (FE), chưa cần SQL Server:
```powershell
npm install
npm run demo
```
Mở http://localhost:3000/ (quản trị) và http://localhost:3000/kiosk. Lệnh này chạy API với **dữ liệu giả lập trong bộ nhớ** + bộ điều khiển máy mô phỏng, nên đi trọn luồng: chọn hàng → mã VietQR → bấm **Giả lập: đã chuyển khoản** → máy nhả hàng.

| Tài khoản demo | Mật khẩu |
|---|---|
| `admin` | `Admin@2026` |
| `operator01` | `Operator@2026` |
| `kiosk01` (kích hoạt màn hình kiosk) | `Kiosk@2026` |

Màn hình đăng nhập có sẵn nút điền nhanh. Dữ liệu demo mất khi tắt máy chủ (Ctrl + C) – đây là chủ ý.
**Khi CSDL xong:** làm mục 1–2 bên dưới, đặt `DB_MODE=sqlserver` trong `api/.env`, rồi `npm start`. Không phải sửa dòng code giao diện nào.

## 1. Cài đặt (một lần)
1. Cài **Node.js LTS** (https://nodejs.org), khởi động lại VS Code. Kiểm tra: `node -v`.
2. Đã tạo CSDL bằng gói **FreshVend_Database** (chạy `FreshVend_FULL.sql` trong SSMS).
3. Mở thư mục `FreshVend_App` trong VS Code → **Terminal → New Terminal**:
   ```powershell
   npm install
   npm run setup
   ```
   `npm install` ở thư mục gốc tự cài luôn thư viện cho `api/`. `npm run setup` tạo `api/.env` từ `api/.env.example` (nếu chưa có) và kiểm tra FE ⇄ BE có khớp không.

> **Làm việc nhóm:** đọc `CONTRIBUTING.md` (quy tắc đồng bộ FE ⇄ BE). Trước khi commit luôn chạy `npm test`.

## 2. Cấu hình `api/.env`
| Nhóm | Biến | Ghi chú |
|---|---|---|
| Chế độ | `DB_MODE` | `demo` (mặc định – dữ liệu giả lập) · `sqlserver` (kết nối CSDL thật) |
| SQL Server | `DB_SERVER`, `DB_PORT` / `DB_INSTANCE` | Bản Express: `DB_INSTANCE=SQLEXPRESS`, để trống `DB_PORT` |
| | `DB_*_USER`, `DB_*_PASSWORD` | Phải trùng 4 login tạo trong `26_security.sql` |
| Bảo mật | `JWT_SECRET`, `DEVICE_API_KEY`, `PAYMENT_WEBHOOK_SECRET` | Đổi thành chuỗi ngẫu nhiên dài |
| Nhận tiền | `PAYMENT_BANK_BIN`, `PAYMENT_BANK_NAME`, `PAYMENT_ACCOUNT_NO`, `PAYMENT_ACCOUNT_NAME` | Tài khoản ngân hàng nhận tiền. Thiếu thì kiosk báo "chưa sẵn sàng nhận thanh toán" |
| | `SEPAY_API_KEY` | Khóa webhook để tự xác nhận khi tiền về (tùy chọn) |
| Kiosk | `SUPPORT_PHONE`, `KIOSK_SESSION_HOURS` | Hotline hiện trên màn hình; thời hạn phiên kiosk (mặc định 720 giờ) |
| Job | `JOBS_FALLBACK=true` | Bật khi SQL Server không có SQL Server Agent (Express/LocalDB) |

SQL Server cần bật **SQL Server and Windows Authentication mode** và **TCP/IP** (SQL Server Configuration Manager), sau đó khởi động lại dịch vụ.

## 3. Chạy
```powershell
npm start
```
Màn hình terminal in ra địa chỉ và dòng `Cơ sở dữ liệu : đã kết nối FreshVendDB`.

| Địa chỉ | Dùng cho |
|---|---|
| http://localhost:3000/ | Bảng điều khiển (quản trị viên, nhân viên vận hành) |
| http://localhost:3000/kiosk | Màn hình bán hàng tại máy |
| http://localhost:3000/api-docs | Tài liệu API (Swagger) |
| http://localhost:3000/api/health | Kiểm tra kết nối CSDL |

Terminal thứ hai – chạy bộ điều khiển máy (5 máy, gửi cảm biến 5 giây/lần, kiểm tra hàng chờ nhả 1,5 giây/lần):
```powershell
npm run simulator
```
Tùy chọn: `node simulator/esp32.js --overheat 3` (máy 3 nóng dần), `--door 2` (mở cửa), `--jam 1` (kẹt motor), `--offline 4` (mất mạng).

## 4. Quy trình bán hàng
1. Lần đầu mở `/kiosk`, kỹ thuật viên nhập **mã thiết bị** và **mã kích hoạt** (tài khoản vai trò Kiosk, tạo ở trang *Người dùng*, gắn máy bằng nút *Giao máy*).
2. Khách chọn sản phẩm → **Thanh toán** → màn hình hiện mã **VietQR** kèm số tài khoản, số tiền, nội dung `FV<mã đơn>`. Đơn được giữ 5 phút.
3. Tiền về tài khoản:
   - **Tự động**: SePay gọi `POST /api/payments/sepay-webhook` (khai báo URL này trong my.sepay.vn, xác thực *API Key* = `SEPAY_API_KEY`). Máy chủ phải truy cập được từ Internet (tên miền hoặc đường hầm như Cloudflare Tunnel).
   - **Thủ công**: quản trị viên mở *Đơn hàng* → đơn *Chờ thanh toán* → **Xác nhận đã nhận tiền** sau khi đối chiếu app ngân hàng.
4. Bộ điều khiển máy thấy đơn đã thanh toán → nhả hàng → báo kết quả. Kẹt 3 lần thì hệ thống tự hoàn tiền và chuyển máy sang trạng thái lỗi.
5. Màn hình kiosk tự chuyển sang "Mời quý khách nhận hàng" hoặc hướng dẫn liên hệ hỗ trợ.

Bảng thông tin thiết bị trên kiosk: chạm logo 5 lần liên tiếp.

Ảnh sản phẩm: trang *Sản phẩm & giá* → **Sửa** → **Chọn ảnh** (JPG/PNG/WebP). Ảnh lưu ở `web/uploads/products/` trên máy chủ.
Sản phẩm chưa có ảnh riêng sẽ tự hiện ảnh trái cây thật trong `web/img/products/` (chọn theo tên sản phẩm – hàm `productImage` trong `web/js/ui.js`).

Giao diện: màu & font khai báo một chỗ trong `web/css/app.css` (`:root`) – xanh rừng `#173f30`, cam `#ec6b39`, tiêu đề Fraunces, chữ Be Vietnam Pro.

## 5. Kiểm thử
```powershell
npm test
```
Bước 1 chạy `tools/check-sync.js`: mọi lời gọi API trong `web/js` và `simulator/` phải khớp route thật trong `api/src/routes` (đúng METHOD + đường dẫn), trang nào cũng đã khai báo trong `admin.js`, biến môi trường nào cũng có trong `api/.env.example`. Bước 2 chạy kiểm thử API.
Chạy kiểm thử API (đăng nhập, phân quyền, mua hàng, VietQR, webhook ngân hàng, nhả hàng, kẹt hàng → hoàn tiền, ảnh sản phẩm, chống SQL injection) trên CSDL mô phỏng trong bộ nhớ – không cần SQL Server, dùng cho GitHub Actions.

## 6. Đưa lên Git
```powershell
git init
git add .
git commit -m "FreshVend app"
git branch -M main
git remote add origin https://github.com/<tai-khoan>/freshvend-app.git
git push -u origin main
```
| Đưa lên Git | Không đưa lên (đã chặn trong `.gitignore`) |
|---|---|
| `package.json`, `api/src`, `api/test`, `api/package.json`, `api/.env.example`, `web/`, `simulator/`, `.vscode/`, `.github/`, `README.md` | `node_modules/`, `api/.env` (mật khẩu, khóa bí mật), `web/uploads/` (ảnh tải lên), `*.log`, `*.bak` |

GitHub Actions tự chạy `npm test` sau mỗi lần push – dấu ✓ xanh là code không lỗi.

Quy tắc nhóm: mỗi người một nhánh (`tv1-auth`, `tv2-inventory`, `tv3-sales`, `tv4-iot`, `tv5-report`), tạo Pull Request, có người review và CI xanh mới merge vào `main`.
