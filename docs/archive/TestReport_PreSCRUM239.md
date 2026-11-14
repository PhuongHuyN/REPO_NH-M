> **LỊCH SỬ 04/11/2026 — schema cũ.** Không dùng số đo/21 ca dưới đây làm bằng chứng schema 09/11. Xem [Week1_Anh_Validation.md](Week1_Anh_Validation.md).

# TestReport — kết quả thực thi TV5

Ngày kiểm tra: 04/11/2026. Môi trường: Windows, SQL Server Express 2022 16.0.1000.6, compatibility 160, Vietnamese_CI_AS; CPU Intel Core i5-8250U 1.60 GHz, 8 logical processors. Chạy một client sqlcmd cục bộ, không có tải cạnh tranh chủ động. CSDL kiểm thử được giữ lại, không sửa CSDL ứng dụng.

## Kết quả nghiệm thu SQL

Lệnh: `powershell -NoProfile -File tests/run-tv5.ps1`.
CSDL: `FreshVendTV5_Test_20261104_194444`. Log gốc: `.local-test/tv5-small-to-large/` (không commit).

| Nhóm kiểm tra | Kết quả |
|---|---|
| Tạo cấu trúc từ schema repo và chạy lại toàn bộ object | PASS |
| Small: 3 địa điểm, 5 máy, 10 sản phẩm, 50 đơn, 500 telemetry | PASS |
| Small chạy hai lần | PASS, không trùng và không tăng revenue |
| Small→large: tổng 20 máy, 15 sản phẩm, 5.000 đơn, 200.000 telemetry | PASS |
| Large chạy hai lần | PASS, số lượng và tổng tiền giữ nguyên |
| Chi tiết, slot, product, payment, thời gian 90 ngày và giờ cao điểm | PASS |
| 7 procedure × 1 ca đúng + 2 ca sai | 21/21 PASS |
| Revenue TVF đủ/rỗng/đảo khoảng | PASS |
| Failure rate, máy lạ/không lần nhả, đúng 2% và dưới 2% | PASS |
| Ranking giảm dần, tổng tỷ trọng và đồng hạng | PASS |
| Cold chain 2°C, 8°C, 8.001°C, thời lượng không đều | PASS: 120/240 giây = 50% |
| JSON lỗi, thiếu duration, không dữ liệu | PASS: không tạo coverage giả |
| paid→refunded→refresh | PASS: xóa summary cũ |
| SQL client đối chiếu KPI, tăng trưởng, DATEFIRST 1/7, xuất dòng và log JSON/PDF PENDING | PASS |

Các lỗi chạy thật phát hiện trong quá trình sửa đã được xử lý: RowCount là từ khóa cần bracket, dependency bảng/cột cũ, seed thiếu chi tiết, telemetry/summary nhân đôi khi chạy lại, tổng KPI bị nhân do cross join, thiếu index Payment.OrderId, phân tích lại JSON làm báo cáo chậm. Không sử dụng kết quả PASS seed hoặc số đo cũ để nghiệm thu.

## Hiệu năng thực tế (ms)

Một lượt khởi động/đo đầu và năm lượt warm. Dataset large 5.000 đơn, 200.000 raw telemetry và toàn bộ hourly tương ứng. Tiêu chí nghiêm ngặt: mỗi lượt warm của yêu cầu nghiệp vụ <500 ms. `sp_RefreshTelemetryHourly` đo cập nhật một ngày UTC như job định kỳ; backfill 90 ngày nằm trong thời gian seed. `sp_RefreshDailySummary` đo 90 ngày. `sp_ExportSales` đo 30 ngày và trả dòng thật.

| Đối tượng | Cold | Lượt 1 | Lượt 2 | Lượt 3 | Lượt 4 | Lượt 5 | Max warm |
|---|---:|---:|---:|---:|---:|---:|---:|
| fn_DispenseFailureRate | 32 | 13 | 13 | 12 | 14 | 12 | 14 |
| fn_RevenueByLocation | 84 | 82 | 75 | 67 | 63 | 63 | 82 |
| sp_DashboardKpi | 220 | 94 | 83 | 238 | 148 | 79 | 238 |
| sp_ExportSales | 89 | 79 | 74 | 85 | 101 | 82 | 101 |
| sp_PeakHours | 273 | 297 | 376 | 210 | 232 | 243 | 376 |
| sp_RefreshDailySummary | 91 | 72 | 76 | 87 | 100 | 126 | 126 |
| sp_RefreshTelemetryHourly | 50 | 45 | 63 | 40 | 25 | 37 | 63 |
| sp_RevenueGrowth | 8 | 6 | 8 | 6 | 8 | 10 | 10 |
| sp_RunAllTests | 641 | 647 | 591 | 795 | 621 | 356 | 795 |
| vw_ColdChainCompliance | 94 | 83 | 74 | 117 | 190 | 189 | 190 |
| vw_ProductRanking | 66 | 31 | 36 | 33 | 30 | 34 | 36 |

`sp_RunAllTests` là bộ điều phối chạy toàn suite, chỉ báo thời gian tham khảo; không áp ngân sách một truy vấn cho tổng suite. Các số trên là elapsed phía SQL, không bao gồm tải CSV/PDF qua HTTP. Không khẳng định SLA cho tải cạnh tranh hoặc máy khác.

## Kiểm thử ứng dụng và tài liệu

`npm test --prefix app`: 16/16 PASS; kiểm tra đồng bộ 56 route, 59 lời gọi và 30 biến môi trường PASS. Đây là test API với fake DB, được tách biệt với bằng chứng SQL thực ở trên.

`python tools/build_testplan_docx.py`: tạo TestPlan.docx và xác thực cấu trúc ZIP/XML, chứa đầy đủ nội dung TestPlan.md. Chưa kiểm tra trình bày bằng Microsoft Word trên giao diện.

## Phạm vi còn phụ thuộc nhóm

- Các procedure nghiệp vụ auth/inventory/sales/iot chưa có định nghĩa trong repo: ma trận khung đã có, kiểm thử SQL nghiệp vụ các module này BLOCKED đến khi chủ module cung cấp.
- Đăng nhập, phân quyền DB thực, luồng mua hàng thực xuyên TV1–TV4, tạo/mở file PDF và xác nhận export SUCCESS/FAILED: chưa nghiệm thu end-to-end trên DB thật; thuộc các ca INT-04–06 của TestPlan.
- Cần owner IoT đưa `report.sp_RefreshTelemetryHourly` vào lịch sau ingest; seed tự refresh. View hiển thị toàn lịch sử hourly đã tổng hợp.
- PR trên tv5-report cần ít nhất một bạn review; chưa có review của người khác trong phiên làm việc này.

Không dùng các phụ thuộc này để đánh dấu PASS toàn hệ thống. SCRUM 34 là User Story và khung Test Plan, không phải triển khai tính năng PDF ứng dụng.

## Seed lớn độc lập

Lệnh: `powershell -NoProfile -File tests/run-tv5.ps1 -LargeOnly`.
CSDL sạch: `FreshVendTV5_Test_20261104_194713`. Không chạy seed nhỏ trước. Tạo/rerun object, large/rerun seed, kiểm tra dữ liệu, 21 ca procedure, oracle client và hiệu năng đều PASS. Log gốc `.local-test/tv5/`.

| Đối tượng | Cold | Lượt 1 | Lượt 2 | Lượt 3 | Lượt 4 | Lượt 5 | Max warm |
|---|---:|---:|---:|---:|---:|---:|---:|
| fn_DispenseFailureRate | 34 | 16 | 13 | 12 | 14 | 13 | 16 |
| fn_RevenueByLocation | 83 | 74 | 64 | 66 | 60 | 88 | 88 |
| sp_DashboardKpi | 356 | 163 | 196 | 162 | 165 | 162 | 196 |
| sp_ExportSales | 96 | 78 | 58 | 61 | 58 | 59 | 78 |
| sp_PeakHours | 265 | 215 | 202 | 129 | 129 | 134 | 215 |
| sp_RefreshDailySummary | 199 | 57 | 57 | 60 | 76 | 50 | 76 |
| sp_RefreshTelemetryHourly | 107 | 47 | 51 | 77 | 50 | 49 | 77 |
| sp_RevenueGrowth | 29 | 11 | 9 | 7 | 7 | 8 | 11 |
| sp_RunAllTests | 492 | 625 | 417 | 359 | 369 | 444 | 625 |
| vw_ColdChainCompliance | 108 | 102 | 88 | 109 | 167 | 93 | 167 |
| vw_ProductRanking | 52 | 33 | 36 | 34 | 34 | 34 | 36 |

## Integration — SCRUM-226 (10/11/2026)

Đã chạy preflight trên CSDL SQL Server riêng `FreshVendTV5_Week2_20261110_170803`. **Chưa thực thi thành công E2E: 0/10 PASS, 10 BLOCKED.** Không lấy 31 test API/mock hoặc ảnh demo làm bằng chứng SQL E2E.

| Bước | Kịch bản | Kết quả hiện tại | Bằng chứng |
|---|---|---|---|
| 1 | Operator login sees exactly three assigned machines | BLOCKED | Chưa có ảnh SQL thật |
| 2 | Add batch and restock | BLOCKED | Chưa có ảnh SQL thật |
| 3 | Kiosk buys two items and receives VietQR | BLOCKED | Chưa có ảnh SQL thật |
| 4 | Payment callback sets PAID | BLOCKED | Chưa có ảnh SQL thật |
| 5 | Simulator dispenses and order DISPENSED | BLOCKED | Chưa có ảnh SQL thật |
| 6 | Stock decremented from FIFO lot | BLOCKED | Chưa có ảnh SQL thật |
| 7 | Machine 3 overheat creates alert and pause | BLOCKED | Chưa có ảnh SQL thật |
| 8 | Machine 1 jams and is REFUNDED | BLOCKED | Chưa có ảnh SQL thật |
| 9 | Admin report contains new order | BLOCKED | Chưa có ảnh SQL thật |
| 10 | Operator report request returns 403 | BLOCKED | Chưa có ảnh SQL thật |

### Các điều kiện chưa đạt

- auth.sp_Login
- auth.sp_AssignMachine
- inventory.sp_Restock
- inventory.sp_RemoveExpired
- iot.vw_MachineHealth
- iot.vw_OpenAlerts
- sales.vw_DispenseQueue
- inventory.vw_StockStatus
- Procedure-driven SMALL seed has not completed
- RLS/security owner setup is not ready
- API with SQL Server is not reachable

Artifact thật: [226-preflight.json](evidence/week2/226-preflight.json). Lệnh tái lập: `powershell -NoProfile -File tests/run-integration-preflight.ps1 -Database <QA_DB> -BaseUrl <API_SQLSERVER>`.

### Quy trình chạy lại khi owner bàn giao

1. Huy xác nhận main đã đủ schema, auth/security/RLS, FIFO/restock, queue/IoT và 99_run_all.bat của Toàn. Chạy SMALL seed qua procedure thật hai lần, so row count/tổng tiền, kiểm operator01 được giao đúng 3 máy.
2. API DB_MODE=sqlserver trỏ đúng QA_DB; kiểm /api/health mode/database; simulator dùng cùng API và cấu hình device key. Không chuyển tiền thật: chỉ dùng callback giả lập theo giao thức test đã được chủ sales duyệt; không bật demo DB để vượt bước payment.
3. Chạy lần lượt 10 bước bảng trên bằng Web/kiosk/simulator. Trước mua ghi BatchId/ExpiryAt/Qty; sau nhả đối chiếu vw_OrderDetail và SlotStock để chứng minh FIFO. Ghi OrderId/PaymentId/DispenseEvents/RefundId trong log đã lọc.
4. Quá nhiệt dùng máy 3, kẹt dùng máy 1 trên fixture riêng; chờ đủ lần đọc/nhả theo contract, kiểm trạng thái/cảnh báo và kiosk Tạm ngưng. Raw→hourly phải sửa #21/#26 trước khi đánh giá chuỗi lạnh.
5. Mỗi bước lưu ảnh thật có thời gian và SHA vào thư mục evidence riêng; ghi Expected/Actual/Status. Bước 10 phải lưu response 403 thực với operator01, không chỉ nhìn menu bị ẩn. Thiếu ảnh hoặc chưa chạy giữ NOT RUN/BLOCKED, không tự điền PASS.
6. Lỗi tạo Issue chủ module, retest sau fix; chỉ chốt 10/10 khi mọi bước có ảnh và SQL đối chiếu. PR cần Huy review/merge; Jira chưa được cập nhật từ phiên này.

Owner blockers #19/#20/#21 và lỗi mới [#26](https://github.com/PhuongHuyN/REPO_NH-M/issues/26). Kết quả 04/11 phía trên là lịch sử schema cũ.
