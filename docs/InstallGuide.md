# Cài đặt FreshVend — trạng thái Tuần 1

SQL Server 2022 (16.x), compatibility 160, Vietnamese_CI_AS. Node.js 20+. Chạy SSMS với QUOTED_IDENTIFIER ON hoặc sqlcmd -I -b.

Thứ tự chuẩn theo QĐ-3 và trạng thái từng file nằm trong README.md. Không tự bỏ qua các mục chưa có hoặc lỗi rồi coi hệ thống cài thành công. Không có FreshVend_FULL.sql. 99_run_all.bat do Toàn bàn giao ở FV-23; hiện chưa có, dùng danh sách manual trong README sau khi các phụ thuộc sẵn sàng.

Report được tạo bằng 02_tables_report.sql, 14_procs_report.sql và 24_objects_report.sql. Chỉ một bộ seed 80_seed_small.sql/81_seed_large.sql; các entry point 05/06/09 cũ đã bỏ. Seed cần view inventory.Machine theo QĐ-1 và dừng 50400 nếu FV-13 chưa hoàn thành.

Full install hiện BLOCKED: #19 file FK cũ, #20 hợp nhất máy và #21 hợp đồng MinutesOutOfRange. Chủ module sửa các phần đó; TV5 không tạo bảng khác để bù.

Kiểm tra riêng report bằng powershell -NoProfile -File tests/run-tv5.ps1 -Server '.\SQLEXPRESS'. Muốn dùng như cổng kiểm thử tích hợp bắt buộc thì thêm -RequireIntegration: mọi trạng thái BLOCKED làm lệnh thất bại sau khi lưu đủ kết quả. CSDL riêng và log giữ ở .local-test/tv5-week1; không chạy runner trên production.

00_database.sql của TV1 bật READ_COMMITTED_SNAPSHOT với ROLLBACK IMMEDIATE; không chạy trên CSDL có giao dịch cần giữ. Runner tự tạo DB riêng, không chạm CSDL ứng dụng. Tài khoản fixture bị vô hiệu hóa và không là tài khoản đăng nhập thật; chủ module auth cấp tài khoản demo và cấu hình quyền DB khi tích hợp.
