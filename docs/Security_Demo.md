# SCRUM-230 — kiểm thử auth, RLS và STOPAT

Ngày chạy thực và môi trường được ghi trong [manifest video](evidence/SCRUM-230/recording.json) và [lần cài sạch](evidence/SCRUM-230/clean-run-result.json). SQL Server Express 2022 16.0.1000.6 trên Windows, Windows authentication bằng dbo. Đã dựng CSDL trống trên SQL Server hiện có; chưa thử trên máy vật lý/VM khác.

## Chạy lại từ CSDL mới

```powershell
powershell -NoProfile -File tests/run-security.ps1 -Server .\SQLEXPRESS
```

Lệnh tạo CSDL FreshVend_S230_<thời gian>, gọi 99_run_all.bat, chạy tests_auth và demo_security, dừng khi lỗi. Cần quyền sysadmin và đủ dung lượng backup/data ở máy SQL Server. Không xóa hay ghi đè CSDL có sẵn. Giữ lại CSDL demo và backup để kiểm tra; người vận hành dọn sau khi đã duyệt bằng chứng.

Chạy riêng demo: `sqlcmd -S .\SQLEXPRESS -E -C -I -b -d <CSDL_QA_sạch> -i tests/demo_security.sql`. Script từ chối tên CSDL ngoài FreshVend_S*/FreshVend_QA*, từ chối CSDL có sản phẩm. tests_auth.sql chạy bằng sqlcmd/SSMS sau khi thay USE FreshVendDB thành tên CSDL QA; mỗi ca tạo fixture riêng và rollback, không dùng mật khẩu/ID ngẫu nhiên của người dùng thật.

## Kết quả

- 15 ca: năm procedure × một ca đúng và hai ca sai. Login sai trả IsSuccess=0 nên kiểm tra LoginHistory và FailedLogins, không đòi THROW giả.
- Ba ca quyền: RLS trả chính xác ba máy được giao, Operator đọc report bị 229, Kiosk thêm sản phẩm bị 229. RLS truy vấn inventory.Machine là đối tượng Operator được cấp SELECT theo ALLOW; không mở thêm quyền đọc trực tiếp iot.Machines để làm test xanh.
- Tổng **18/18 PASS**, có từng ExpectedError/ActualError/RunAt trong [log](evidence/SCRUM-230/tests_auth.log). Fixture lỗi không được tính là lỗi nghiệp vụ đúng mong đợi; ca sai mã hoặc thiếu ca làm sqlcmd exit khác 0.
- Demo: RLS với bốn máy mô phỏng, Operator thấy ba; rollback fixture. Clone schema thật thành CSDL tên UUID; thêm sản phẩm qua procedure, backup FULL, thêm marker 2, backup DIFF. Chụp thời gian SQL Server, đợi ranh giới một giây, DELETE sản phẩm và ghi marker 3, backup LOG. Restore FULL + DIFF + LOG WITH STOPAT vào CSDL UUID khác, có MOVE cho từng file, không WITH REPLACE.
- Restore **PASS**: COUNT trước/sau bằng 1, tên/giá sản phẩm đúng, marker tối đa bằng 2. Điều này kiểm tra khôi phục thật và loại dữ liệu sau thời điểm mục tiêu, không chỉ VERIFYONLY. Xem [log demo](evidence/SCRUM-230/demo_security.log).

## Video

[Video WebM](evidence/SCRUM-230/security-demo.webm), dưới 5 phút, không âm thanh, có chú thích; ghi trực tiếp output của lần chạy sqlcmd thật bằng công cụ console tự động. Không phải video SSMS hay quay màn hình desktop. [Ảnh 18 ca](evidence/SCRUM-230/tests_auth.png), [ảnh STOPAT](evidence/SCRUM-230/demo_security.png), SHA-256 log/video trong manifest.

Tái tạo video cần Python + Pillow và ffmpeg có MJPEG decoder, VP9 encoder:

```powershell
python tools/record-security-demo.py --ffmpeg <đường_dẫn_ffmpeg> --database <CSDL_QA_sạch>
```

SQL dùng đồng hồ local server GETDATE cho STOPAT (DATETIME), thời điểm UTC+07:00 và thời điểm hoàn tất có trong log. Không dùng đồng hồ máy client hoặc suy diễn RPO/uptime từ demo nhỏ. Phụ thuộc SCRUM-217 và PR #46; Huy còn cần review/merge và xác nhận video phù hợp hình thức bảo vệ.
