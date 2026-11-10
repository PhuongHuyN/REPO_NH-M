# Tuần 2 — bằng chứng của Anh

## SCRUM-224: kết quả SQL thật

SQL Server Express 2022 (16.0.1000.6), compatibility 160, CSDL riêng `FreshVendTV5_Week2_20261110_170803`. Lệnh `powershell -NoProfile -File tests/run-week2.ps1`; nguồn và log tại `.local-test\week2\FreshVendTV5_Week2_20261110_170803`. Không đổi dữ liệu ứng dụng. 33 ca thật, mỗi ca đủ điều kiện dùng BEGIN TRAN/ROLLBACK; kiểm tra tổng số dòng Product/Order/Machine/Telemetry và tổng giá sản phẩm trước/sau đều giữ nguyên; transaction không rò. Identity/sequence có thể tăng dù rollback, vì vậy chỉ dùng DB test.

**24 PASS / 2 FAIL / 7 BLOCKED**. Đây không phải “toàn bộ đã đạt”.

| Module | Trạng thái | Số ca |
|---|---|---:|
| auth | BLOCKED | 4 |
| inventory | BLOCKED | 2 |
| inventory | PASS | 6 |
| iot | BLOCKED | 1 |
| iot | FAIL | 2 |
| iot | PASS | 6 |
| report | PASS | 6 |
| sales | PASS | 6 |

| Bước setup / kiểm chứng | Kết quả |
|---|---|
| sql/01_schemas.sql | PASS |
| sql/02_tables_auth.sql | PASS |
| sql/02_tables_inventory.sql | PASS |
| sql/02_tables_iot.sql | PASS |
| sql/02_tables_report.sql | PASS |
| sql/02_tables_sales.sql | PASS |
| sql/03_foreign_keys.sql | BLOCKED |
| sql/11_procs_inventory.sql | PASS |
| sql/12_procs_sales.sql | PASS |
| sql/13_procs_iot.sql | PASS |
| sql/14_procs_report.sql | PASS |
| sql/24_objects_report.sql | PASS |
| tests/sql/fixtures_report.sql | PASS |
| sql/80_seed_small.sql | BLOCKED |
| sql/81_seed_large.sql | BLOCKED |
| tests/sql/224_verify_runner.sql | PASS |

Các ca thiếu procedure/type/fixture ghi BLOCKED, Passed=0. Partition không có procedure/partition scheme thật không được PASS. Ca dương kiểm tra giá trị/row count; lỗi nghiệp vụ phải khớp ERROR_NUMBER chính xác. Summary/UI tách Blocked khỏi Failed; không có ca nào được gán PASS chỉ vì không có dependency.

### Hai lỗi IoT tái hiện được

[Issue #26](https://github.com/PhuongHuyN/REPO_NH-M/issues/26), owner Dũng:
- `IOT-ingest-invalid-json`: expected 50310; actual lỗi JSON SQL Server 13609.
- `IOT-ingest-two-readings`: expected +2 telemetry, actual chỉ +1 do SELECT TOP 1.

Các lỗi cũ [#19 FK](https://github.com/PhuongHuyN/REPO_NH-M/issues/19), [#20 máy chuẩn](https://github.com/PhuongHuyN/REPO_NH-M/issues/20), [#21 phút telemetry](https://github.com/PhuongHuyN/REPO_NH-M/issues/21) vẫn là dependency. Không sửa procedure/bảng owner để ép test xanh.

## Seed qua procedure thật

80/81 gọi CreateUser, AssignMachine, RegisterMachine, AddProduct, AssignColumn, AddBatch, Restock, CreateOrder, ConfirmPayment, RecordDispense; QA ledger trong schema report cho chạy lại. Cần toàn bộ procedure và view máy chuẩn; thiếu thì THROW 50410 trước ghi. Tài khoản demo dùng auth API thật, không chèn hash placeholder. GENERATE_SERIES dựng stage; cursor chỉ điều phối API procedure từng máy/sản phẩm/đơn (API không có bulk tương đương). Telemetry typed insert set-based.

Các đơn được tạo/thanh toán/nhả thật trước khi điều chỉnh **timestamp fixture lịch sử tổng hợp** trong 90 ngày; không dùng chúng làm bằng chứng thanh toán đã xảy ra trong quá khứ. Không coi seed là giao dịch tiền thật. Restock/FIFO và lot expiry vẫn dùng procedure owner.

Hiện cả hai seed **BLOCKED trước khi ghi**, do auth/Restock chưa có và QĐ-1 chưa hợp nhất. Chưa có bằng chứng seed thành công/chạy hai lần; không đánh dấu tiêu chí này đạt. Không backfill hourly bằng số mẫu để giả phút; chờ #21.

## Giao diện và kiểm thử ứng dụng

`npm test --prefix app`: **31/31 PASS**, FE/BE sync PASS. Các test này là API/mock + chính sách trạng thái, không thay SQL acceptance.

Ảnh [trang Kiểm thử ở chế độ demo](evidence/week2/224-tests-demo-blocked.png) được chụp bằng Edge headless từ ứng dụng thật; 12 ca demo đều BLOCKED, không có badge PASS. Metadata ở evidence/week2/224-ui.json. Đây là bằng chứng UI, **không phải ảnh SQL-server E2E**; auth/security thật chưa đủ để chạy trang qua DB_MODE=sqlserver.

## Điều kiện chốt nghiệm thu

SCRUM-224 chưa đủ 100%: owner bàn giao auth/Restock/RemoveExpired/machine view, sửa #26; chạy seed và suite với `-RequireAll`; 0 FAIL/0 BLOCKED và review/merge PR. Các kiểm thử hiện có chứng minh runner trung thực và rollback hoạt động, không chứng minh toàn hệ thống đã sẵn sàng.

SCRUM-225/226 được ghi riêng trong tài liệu và artifact tương ứng; không lấy số đo 04/11 hoặc demo làm kết quả hiện tại. Huy review/merge, không tự approve. Chưa cập nhật Jira hoặc gửi tin nhắn thay các thành viên.
