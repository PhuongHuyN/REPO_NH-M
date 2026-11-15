# Anh — bằng chứng Tuần 1 (SCRUM-209/210/211)

Ngày 09/11/2026; SQL Server Express 2022 16.0.1000.6, compatibility 160, Vietnamese_CI_AS. CSDL riêng `FreshVendTV5_Week1_20261109_082431`. Lệnh `powershell -NoProfile -File tests/run-tv5.ps1`. Log gốc tại `.local-test\tv5-week1\FreshVendTV5_Week1_20261109_082431` (không commit). Không chạy trên dữ liệu ứng dụng.

| Bước thực thi | Kết quả |
|---|---|
| 01_schemas.sql | PASS |
| 02_tables_auth.sql | PASS |
| 02_tables_inventory.sql | PASS |
| 02_tables_iot.sql | PASS |
| 02_tables_report.sql | PASS |
| 02_tables_sales.sql | PASS |
| 03_foreign_keys.sql | BLOCKED |
| 14_procs_report.sql | PASS |
| 24_objects_report.sql | PASS |
| preflight-80_seed_small.sql | BLOCKED |
| preflight-81_seed_large.sql | BLOCKED |
| fixtures-report.sql | PASS |
| fixtures-report-rerun.sql | PASS |
| rerun-02_tables_report.sql | PASS |
| rerun-14_procs_report.sql | PASS |
| rerun-24_objects_report.sql | PASS |
| verify-report.sql | PASS |
| client-oracles | PASS |

Report: **18/18** ca procedure (6 procedure × 1 đúng + 2 sai), kiểm tra metadata iot.Locations, JAM từ sales.DispenseEvents, compliance từ iot.TelemetryHourly, chi tiết nhiều dòng có giảm giá, refresh lặp và paid→refunded. SQL client đối chiếu 3 result sets dashboard, 12 tháng và QtySold/PrevRevenue, DATEFIRST 1/7, export đủ refunded theo fakeDb và Params JSON hợp lệ. Fixture chạy hai lần không nhân đôi.

## Phụ thuộc và giới hạn

- [#19](https://github.com/PhuongHuyN/REPO_NH-M/issues/19): file FK của TV1 vẫn tham chiếu iot.Device/iot.Alert đã bỏ. Script main trên CSDL trống **BLOCKED**, không phải PASS. 03_foreign_keys.sql giữ nguyên origin/main.
- [#20](https://github.com/PhuongHuyN/REPO_NH-M/issues/20): FV-13 chưa cung cấp inventory.Machine view trên iot.Machines. Fixture chỉ bridge dữ liệu trong CSDL test để kiểm tra report; không phải migration hay bằng chứng hợp nhất máy.
- [#21](https://github.com/PhuongHuyN/REPO_NH-M/issues/21): MinutesOutOfRange hiện đếm mẫu; cold-chain end-to-end và backfill chưa được nghiệm thu. Report dùng contract hourly, trả NULL nếu số phút không hợp lệ.
- Không tạo bảng/index/function/procedure của schema khác trong file report. Cross-schema FK đề nghị TV1 quản lý. Không thay đổi schema của TV2/TV3/TV4 để làm test xanh.
- Số đo 04/11 trong TestReport.md là lịch sử schema cũ; không tái sử dụng làm bằng chứng hiệu năng schema 09/11. Seed lớn, hiệu năng API p95 và E2E toàn hệ thống nằm trong kế hoạch Tuần 2; chưa ghi PASS ở đây.
- Review/merge do Huy thực hiện sau khi CI và các phụ thuộc đạt. Không tự approve hoặc merge PR của mình. Trạng thái Jira không được tự sửa trong file nhiệm vụ.
