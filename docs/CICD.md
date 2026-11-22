# CI/CD FreshVend

## Phạm vi

GitHub Actions kiểm tra thay đổi khi có push lên `main`, Pull Request nhắm `main`, hoặc chạy thủ công bằng `workflow_dispatch`. Workflow nằm tại `.github/workflows/ci.yml`, chạy trên Ubuntu và chỉ cần quyền đọc repository. CI là hàng rào kiểm tra trước review/merge; workflow không tự deploy, merge hay kết nối SQL Server production.

## Các job trong CI

### App contract and tests

1. Cài Node.js theo `app/.nvmrc` và dependency cố định bằng `npm ci --prefix app/api`.
2. Chạy `npm run check --prefix app`, gọi `app/tools/check-sync.js` để đối chiếu route FE/API, vai trò trang/API, biến môi trường và danh sách page.
3. Chạy `npm test --prefix app/api`, thực thi bộ Node test của API.

Các test API hiện dùng `fakeDb.js` và driver SQL giả cho một số kiểm tra adapter; chúng không chứng minh stored procedure, quyền/RLS hay kết nối SQL Server thật.

### SQL structure and T-SQL parse

1. `tools/check-sql.js --require-parser` kiểm tra 26 file `.sql` trong `sql/` không rỗng, string/identifier/comment được đóng và ngoặc cân bằng.
2. GitHub Actions cài SQLFluff theo phiên bản ghim trong `tools/requirements-sql-check.txt`, rồi script gọi parser `tsql` cho từng file.

Đây là kiểm tra cấu trúc và parse cú pháp cơ bản. Nó không chạy các batch trên SQL Server, không phát hiện mọi lỗi phụ thuộc schema/quyền/phiên bản, không chứng minh file có thể cài theo thứ tự, và không thay thế `tests/run-acceptance.ps1` hoặc kiểm thử tích hợp SQL Server. SQL Server-specific runtime tests cần môi trường SQL Server/`sqlcmd` riêng.

## Chạy cục bộ

Từ gốc repository:

```powershell
npm ci --prefix app/api
npm run check --prefix app
npm test --prefix app/api
node tools/check-sql.js
```

Lệnh cuối chạy kiểm tra cấu trúc không cần cài SQL Server hay dependency mới. Để chạy cùng parser như CI, cài Python 3.12+ và `python -m pip install -r tools/requirements-sql-check.txt`, sau đó:

```powershell
node tools/check-sql.js --require-parser
```

Để kiểm tra DDL/procedure và test SQL trên SQL Server QA, dùng quy trình cài/test trong [TestPlan.md](TestPlan.md) hoặc `tests/run-acceptance.ps1`; không chạy acceptance suite ghi dữ liệu trên database vận hành.

## Giới hạn dữ liệu IoT

CI không có phần cứng ESP32/DHT22/servo. Tất cả telemetry và kịch bản cảm biến/nhả hàng hiện được mô phỏng bằng `app/simulator/esp32.js`; test xanh không phải bằng chứng đo đạc hoặc nghiệm thu phần cứng thật.
