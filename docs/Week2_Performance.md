# SCRUM-225 — bằng chứng và giới hạn

Công cụ đã triển khai: tests/70_perf_tests.sql, tests/run-perf.ps1, tests/measure-report-api.ps1.

## Control run thật, không phải nghiệm thu LARGE

Đã thu 5 query × (1 cold +5 warm), 60 actual execution plans và STATISTICS TIME/IO trên SQL Server 2022, CSDL FreshVendTV5_Week2_20261110_170803. Dataset control có 50 đơn/1 hourly, không có 200.000 telemetry. Không dùng số đo này khẳng định SLA hoặc before/after index trên seed lớn.

| Query | Cold ms | Max warm ms | CPU cold ms | Logical reads cold | AFTER |
|---|---:|---:|---:|---:|---|
| ColdChainCompliance | 15.536 | 21.757 | 0 | 24 | BLOCKED |
| ExportSales30Days | 75.735 | 52.314 | 3 | 410 | BLOCKED |
| PeakHours | 106.896 | 85.169 | 2 | 72 | BLOCKED |
| ProductRanking | 29.511 | 10.574 | 2 | 359 | BLOCKED |
| RevenueByLocation | 25.134 | 115.552 | 2 | 345 | BLOCKED |

Actual XML .sqlplan và log TIME/IO ở docs/evidence/week2/perf-control. None nghĩa SQL Server không expose trường đó; không bịa số 0. Chưa có ảnh SSMS Execution Plan, chưa có AFTER và chưa chứng minh logical reads giảm.

## Chạy nghiệm thu khi đủ phụ thuộc

1. Chạy seed LARGE qua procedure thật; xác minh 5.000 đơn/200.000 telemetry và seed lần hai giữ nguyên tiền.
2. powershell -NoProfile -File tests/run-perf.ps1 -Database QA_DB -OwnerIndexScript script_index_duoc_owner_duyet.sql
3. Công cụ lưu metadata index trước/sau và SHA256 script; chỉ gán AFTER khi index thực sự thay đổi. Không tự tạo/xóa index module khác. Mở actual .sqlplan bằng SSMS, lưu ảnh Ctrl+M.
4. Đăng nhập Admin thật, truyền token qua biến môi trường process FRESHVEND_QA_ADMIN_TOKEN; chạy tests/measure-report-api.ps1 -Requests 100. Đo KPI/peak/growth; giữ cả mẫu lỗi/timeout; p95 nearest-rank từng route ≤500 ms và error count=0.

Hiện nghiệm thu BLOCKED: auth/Restock/view máy/partition/index owner chưa được bàn giao, seed LARGE chưa chạy được. Không đo API demo rồi ghi PASS. Run-perf -ControlOnly chủ động trả mã khác 0 vì không phải nghiệm thu.
