# Gỡ lỗi IoT — Issue #26

Nhánh fix/SCRUM-224-iot-ingest, được phép xử lý phụ thuộc sau xác nhận của người dùng. Không sửa các module khác trong PR này.

- Mọi JSON parser nhận biểu thức JSON an toàn; JSON sai trả 50310, máy lạ 50311, readings sai/rỗng trả 50312.
- Bỏ TOP 1 làm mất batch: parse và validate toàn bộ trước transaction, insert tất cả trong một giao dịch.
- LastTemp lấy phần tử cuối theo ordinal, không lấy nhiệt độ lớn nhất. Buffered timestamp được chuẩn hóa UTC; heartbeat dùng SYSUTCDATETIME.
- Không thay đổi trạng thái/cảnh báo ngoài phạm vi sửa ingestion này; các yêu cầu khác tiếp tục theo task của owner.

## Kiểm chứng thật

SQL Server 2022, CSDL riêng FreshVendTV5_Week2_20261110_223138. Chạy tests/run-week2.ps1: **26 PASS / 0 FAIL / 7 BLOCKED**, so với 24/2/7 trước sửa. Rollback giữ số dòng nghiệp vụ và tổng giá như baseline.

Chạy thêm tests/sql/26_verify_ingest.sql: PASS. Batch 3 dòng có nhiệt độ 2,8,5 lưu đủ 3 và LastTemp=5; timestamp đệm UTC đúng; heartbeat trong 5 giây so SYSUTCDATETIME. Năm ca âm kiểm đúng mã lỗi và không ghi một phần, kể cả một phần tử hợp lệ đứng trước phần tử sai.

Artifact: evidence/week2/26-ingest-retest.json. Log gốc .local-test/week2/FreshVendTV5_Week2_20261110_223138. Ảnh demo và số liệu control cũ không được dùng thay kiểm thử SQL này.

## Còn chờ

Bảy ca BLOCKED: auth 4, inventory 2, partition 1. Full install/seed lớn/benchmark trước-sau index/E2E chưa đạt; các Issue #19/#20/#21 và các procedure owner còn thiếu chưa được sửa trong PR này. Review/merge do Huy thực hiện. Không đánh dấu toàn bộ Tuần 2 là 100%.
