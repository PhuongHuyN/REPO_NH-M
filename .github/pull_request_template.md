## Thay đổi gì?
<!-- module nào: auth (TV1) / inventory (TV2) / sales (TV3) / iot (TV4) / report (TV5) / web -->

## Checklist đồng bộ FE ⇄ BE (bắt buộc)
- [ ] Đã chạy `npm test` trong thư mục `app/` → ✔ "FE và BE khớp nhau" và toàn bộ test xanh
- [ ] Thêm / đổi route API → đã sửa CÙNG LÚC file `web/js/...` gọi route đó
- [ ] Thêm biến môi trường → đã thêm vào `api/.env.example` (không commit `api/.env`)
- [ ] Đổi tên cột / view / procedure SQL → đã sửa route trong `api/src/routes` và chạy lại test
- [ ] Trang mới trong `web/js/pages` → đã import trong `web/js/admin.js`, khai báo `roles`
- [ ] Không thêm thư viện ngoài nếu không thật cần (nếu thêm: ghi lý do, commit `package-lock.json`)
- [ ] Đã có 1 bạn review
