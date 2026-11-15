# SCRUM-201 — sửa khóa ngoại hệ thống

Base main a79b461. SQL Server 2022, CSDL riêng `FreshVend_FK201_Test_20261112_235546`. Chạy `powershell -NoProfile -File tests/run-fk201.ps1`.

## Đã kiểm chứng

- 00_database → 01_schemas → tất cả 02 (có audit) → 03_foreign_keys: PASS.
- Chạy lại 03 hai lần: PASS, số FK không tăng; không FK disabled/untrusted.
- Tám ca FK mồ côi: ExportLogs.UserId, RestockEvent.UserId/MachineId, DailySalesSummary.ProductId/MachineId, UserMachine.MachineId, Alerts.AckBy và ChangeLog.UserId đều bị chặn bằng 547.
- Dữ liệu hợp lệ theo máy iot được chấp nhận dù chưa có dòng legacy inventory.Machine.
- FK bị NOCHECK được WITH CHECK CHECK lại và trusted.
- Máy legacy cùng ID nhưng khác Serial/MachineCode bị từ chối 50090; không remap dữ liệu tự động.
- Dữ liệu mồ côi có sẵn làm validation thất bại 547; dọn dữ liệu rồi chạy lại thành công.
- Thiếu audit.ChangeLog làm preflight thất bại 50090, không bỏ qua dependency; khôi phục bảng và chạy lại thành công.

Bằng chứng: evidence/SCRUM-201/results.json, foreign-keys.txt (kết quả sys.foreign_keys từ SQL thật). Chưa chụp ảnh SSMS; không giả ảnh Object Explorer.

## Thay đổi

03_foreign_keys dùng danh mục 19 quan hệ, một transaction, preflight toàn bộ bảng/cột, kiểm tra định nghĩa tương đương để không tạo FK trùng dưới tên khác. Loại bỏ hẳn Device/Alert/MachineStockSnapshot cũ. Máy dùng iot.Machines, cảnh báo dùng iot.Alerts.AckBy. Bổ sung các quan hệ kho/bán hàng/report/audit/giao máy còn thiếu; bảo đảm mọi constraint được CHECK/trusted.

02_tables_auth tạo auth.UserMachine trước bước 03, cùng cấu trúc khối tương thích trong 10_procs_auth. Nhờ vậy FK giao máy không bị bỏ sót vì bảng chỉ được tạo ở bước procedure. Không tạo bảng giả hoặc đổi dữ liệu cũ để vượt test.

## Giới hạn phạm vi

Bản sửa chứng minh cài đặt **00–03** và ràng buộc dữ liệu. Không có nghĩa toàn bộ seed/app/E2E đã đạt. QĐ-1 chuyển bảng legacy thành view và migration dữ liệu cũ vẫn phải được thực hiện phối hợp; dữ liệu chưa ánh xạ sẽ bị dừng rõ ràng. Không tự approve/merge; Huy review PR. Thông báo của script thuộc TV1 dùng 50090/50091, không chiếm mã TV5.
