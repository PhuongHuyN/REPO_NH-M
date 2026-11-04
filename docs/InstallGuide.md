# Cài đặt TV5

SQL Server 2022 (16.x), compatibility 160, Vietnamese_CI_AS. Chạy bằng SSMS hoặc sqlcmd -I -b; cần quyền tạo cấu trúc và ghi dữ liệu.

Thứ tự chuẩn được duy trì tại README.md: 00/01 → tất cả bảng 02 → 03_foreign_keys → 04_report_dependencies → 24_objects_report → 07_procs_report → 05_seed_small → 06_seed_large (sau cùng, khi cần).

Không dùng 09_seed cũ. Không chạy 00_database.sql trên một CSDL đang có phiên giao dịch cần giữ, vì script của TV1 bật READ_COMMITTED_SNAPSHOT với ROLLBACK IMMEDIATE. Bộ tests/run-tv5.ps1 tự tạo CSDL riêng và không gọi thao tác này trên CSDL ứng dụng.

Kiểm tra độc lập: powershell -NoProfile -File tests/run-tv5.ps1 -Server '.\SQLEXPRESS'. CSDL test và log giữ lại ở .local-test/tv5 để review. Đọc docs/TestReport.md để phân biệt kết quả đã chạy và phụ thuộc chưa tích hợp.

Các module auth/inventory/sales/iot hiện có bảng nhưng chưa có đầy đủ procedure nghiệp vụ trong repo. Seed là fixture SQL, không phải tài khoản đăng nhập thật. Việc chạy API toàn hệ thống cần các script nghiệp vụ, cấu hình quyền và tài khoản của chủ module.
