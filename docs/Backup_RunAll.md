# SCRUM-217 — Cài đặt và sao lưu

Chạy tại gốc repo trên Windows có SQL Server 2022 và Microsoft sqlcmd, bằng Windows login có quyền tạo CSDL, login và backup:

```bat
99_run_all.bat .\SQLEXPRESS FreshVendDB
```

Mặc định server localhost, database FreshVendDB. Bộ cài chạy riêng từng file SQL với `-I -b -V 11`, dựng schema, procedure, object, index, RBAC/RLS và Full/Diff/Log. Không tự xóa CSDL; chạy lại cập nhật object. Lỗi trả exit 1, tên file và log; chỉ in HOAN TAT khi toàn bộ thành công. Log UTF-16 và manifest tại `.local-test/install/`.

Tham số thứ ba `Small` hoặc `Large` yêu cầu seed. Mặc định `None`: không thêm dữ liệu nghiệp vụ. Hiện seed bị chặn 50410 do QĐ-1: inventory.Machine chưa thành view và RegisterMachine chưa tạo ngăn. Không coi seed đã nghiệm thu. Không chạy 08_seed_inventory vì còn tạo máy legacy độc lập với IoT; 45_jobs chưa có trong repo nên không đưa vào manifest.

## Backup và phục hồi

Chạy riêng `sqlcmd -S .\SQLEXPRESS -E -C -I -b -i sql/50_backup.sql`. Script đặt recovery FULL, tạo full (không COPY_ONLY), differential và log, CHECKSUM và VERIFYONLY cho từng file. Tên file chứa thời gian và UUID, không ghi đè bản cũ. Đường dẫn lấy từ InstanceDefaultBackupPath trên máy SQL Server; tài khoản dịch vụ cần quyền ghi và đủ dung lượng. Express không hỗ trợ backup compression nên không dùng COMPRESSION.

Đề xuất full Chủ nhật, diff hằng ngày, log mỗi 15 phút. Express dùng Task Scheduler; tách từng loại lệnh BACKUP từ script cho lịch tương ứng, không chạy cả ba loại mỗi 15 phút. Theo dõi tác vụ lỗi, dung lượng và bản sao ngoài máy; kiểm tra chuỗi khôi phục trước khi áp retention. VERIFYONLY chưa chứng minh restore; tests/demo_security.sql của SCRUM-230 kiểm tra restore thực.

RPO theo lịch log là tối đa 15 phút nếu mất máy và không lấy được tail-log. Backup không tự chứng minh không mất dữ liệu hoặc uptime 99,9%; cần HA, giám sát và diễn tập đo RTO riêng. Script không tự cấu hình hoặc xóa lịch backup hiện hữu.

## Kết quả chạy thật

SQL Express 2022 16.0.1000.6, Windows, Vietnamese_CI_AS, compatibility 160. Ngày giờ thật nằm trong manifest và backup log ở evidence/SCRUM-217. FreshVend_S217_Clean_20261115: cài mới PASS; cả ba backup checksum và VERIFYONLY PASS. Chạy lại sau sửa unique index/constraint trong 10_procs_auth PASS. Bản sao script cố ý THROW 50499 tại 14_procs_report trên FreshVend_S217_Fault_20261115: exit 1, dừng đúng file, không chạy object/security/backup tiếp theo.

Phụ thuộc sửa khóa ngoại SCRUM-201 (PR #46, có trong nhánh). Cần Huy review và merge; tiêu chí PR merge chưa hoàn tất.
