# FreshVend — Test Report (SCRUM-239 / FV-45)

Phiên bản 1.0, ngày tổng hợp **15/11/2026**, người thực hiện Nguyễn Phạm Xuân Anh. Bản này thay kết luận hiện hành; [báo cáo trước](archive/TestReport_PreSCRUM239.md) chỉ là lịch sử trên schema khác, không dùng để cộng số đạt.

## 1. Môi trường và nguồn bằng chứng

- Windows, SQL Server **2022 Express 16.0.1000.6**, compatibility **160**, collation **Vietnamese_CI_AS**. CSDL mới `FreshVend_QA239_20261115_005521`, tạo bằng 99_run_all.bat trước khi nạp fixture. [Môi trường SQL và số dòng](evidence/SCRUM-239/environment.json), [Node/npm/ngày giờ](evidence/SCRUM-239/npm-environment.json).
- Nhánh xuất phát từ main `7f1d6cd`, cộng bản sửa FK SCRUM-201, SCRUM-217 và SCRUM-230; không phải nghiệm thu nguyên trạng main. [Hash nguồn và bằng chứng](evidence/SCRUM-239/manifest.json) khóa phiên bản đã chạy.
- Log SQL ghi ISO-8601 +07:00; JSON Node ghi UTC (`Z`), ví dụ 14/11/2026 17:59Z = 15/11/2026 00:59 giờ Việt Nam. Không lấy ngày deadline làm ngày thực thi.
- Fixture QA có bridge ID máy canonical/legacy dành riêng kiểm thử để chạy seed inventory hiện hữu. Đây **không** phải bản sửa QĐ-1 hoặc bằng chứng seed 80/81 đã chạy thành công. 08_seed_inventory và 10_procs_auth chạy lại sau fixture, log ở thư mục bằng chứng.
- Trước đo hiệu năng: **54 đơn, 0 raw telemetry**; fixture report có một dòng hourly. Sau đó simulator mới sinh raw telemetry. Không gọi tập này là LARGE 5.000 đơn/200.000 telemetry; không dùng dữ liệu sau mô phỏng để thay số đo trước đó.

## 2. Unit SQL và npm

| File | Tổng | PASS | FAIL | Bắt đầu chạy (+07:00) | Bằng chứng |
|---|---:|---:|---:|---|---|
| tests_auth.sql | 18 | 18 | 0 | 2026-11-15T00:55:43.9932945+07:00 | [JSON](evidence/SCRUM-239/tests_auth.sql.json) |
| tests_inventory.sql | 54 | 53 | 1 | 2026-11-15T00:55:46.2797351+07:00 | [JSON](evidence/SCRUM-239/tests_inventory.sql.json) |
| tests_sales.sql | 5 | 5 | 0 | 2026-11-15T00:55:49.5945962+07:00 | [JSON](evidence/SCRUM-239/tests_sales.sql.json) |
| tests_iot.sql | 6 | 6 | 0 | 2026-11-15T00:55:54.3314276+07:00 | [JSON](evidence/SCRUM-239/tests_iot.sql.json) |
| tests_report.sql | 6 | 6 | 0 | 2026-11-15T00:55:54.4599709+07:00 | [JSON](evidence/SCRUM-239/tests_report.sql.json) |
| tests_audit.sql | 10 | 10 | 0 | 2026-11-15T00:55:51.1757271+07:00 | [JSON](evidence/SCRUM-239/tests_audit.sql.json) |
| tests_security.sql | 11 | 11 | 0 | 2026-11-15T00:55:51.7151760+07:00 | [JSON](evidence/SCRUM-239/tests_security.sql.json) |

Năm file chính auth/inventory/sales/iot/report: **88/89 PASS, 1 FAIL**. Audit và security là kiểm tra bổ sung, không cộng để làm đẹp tỷ lệ. Phạm vi tests_iot gồm sáu ca ingest (batch, UTC và năm lỗi/atomicity), chưa phải ba ca cho mọi procedure IoT. Sáu ca report lấy từ batch runner thật gần nhất, không phải sáu lần chạy độc lập bổ sung vào tổng runner.

Inventory **T48 FAIL**: fn_PriceHistory cần hai mốc giá 42000→45000 nhưng trả một mốc khi sửa nhanh. Cần owner kiểm tra tính chính xác theo độ phân giải temporal/phiên bản có thời gian bằng nhau; chưa sửa hàm hay nới assertion để đổi thành PASS. Chi tiết Expected/Actual trong JSON.

`npm test --prefix app/api`: **31/31 PASS, 0 skipped**, ngày giờ/Node/npm trong manifest; [log nguyên bản](evidence/SCRUM-239/npm-test.log). Các test API dùng fakeDb, test db.js dùng driver mssql giả. Chúng kiểm tra hợp đồng/API, không chứng minh stored procedure, RLS hay thiết bị chạy SQL thật.

## 3. report.sp_RunAllTests

Chạy thật lúc 15/11/2026 trên cùng QA DB, có [33 dòng kết quả](evidence/SCRUM-239/runner.json). Không nhân đôi các dòng report ở phần unit.

| Module | PASS | FAIL | BLOCKED |
|---|---:|---:|---:|
| auth | 4 | 0 | 0 |
| inventory | 7 | 0 | 1 |
| sales | 6 | 0 | 0 |
| iot | 8 | 0 | 1 |
| report | 6 | 0 | 0 |
| Tổng | **31** | **0** | **2** |

Hai ca BLOCKED: INV-restock-empty chờ hợp nhất máy #20; IOT-partition-real thiếu iot.sp_MaintainPartitions. Passed=0 cho BLOCKED. Bộ điều phối không được coi toàn bộ đạt chỉ vì procedure chạy hết.

## 4. Integration với SQL Server thật

API cổng 32139, DB_MODE=sqlserver, trỏ đúng CSDL QA nêu trên; bốn login theo vai trò. [Smoke 26 ca](evidence/SCRUM-239/api-smoke.md), [output thực](evidence/SCRUM-239/api-smoke.log): **21/26 PASS, 5 FAIL**. Kiểm tra đăng nhập ba vai trò, quyền report của Operator và quyền quản lý sản phẩm của Kiosk có thực thi.

Năm HTTP 500 do thiếu ba đối tượng IoT: iot.vw_MachineHealth (menu Kiosk, danh sách máy Admin và Operator), iot.vw_OpenAlerts, iot.fn_RecentTelemetry. Không coi HTTP 200 với dữ liệu trống là đã kiểm tra nghiệp vụ đầy đủ; smoke chủ yếu kiểm tra đăng nhập, quyền và khả năng gọi route.

Luồng ghi end-to-end mười bước FV-32: **0 PASS / 10 BLOCKED**, [manifest preflight](evidence/SCRUM-239/integration-e2e.json). Thiếu hai view IoT và seed SMALL chưa hoàn tất. Preflight không chạy luồng nên không ghi kết quả mua/nhả hàng hay QR là PASS. Thử tạo đơn trong kịch bản JAM còn gặp HTTP 500: “Cannot find data type OrderItemType”; cần kiểm tra mapping TVP có schema trong db.js/driver, không nhầm với lỗi nghiệp vụ thiếu tiền/hết hàng.

## 5. Hiệu năng

Chạy lúc **00:56:30 ngày 15/11/2026 (+07:00)**. Một lượt đầu + năm lượt warm, một client, không tạo tải cạnh tranh. Có STATISTICS XML/TIME/IO và 60 plan, [samples](evidence/SCRUM-239/perf-control/samples.json), [TIME/IO](evidence/SCRUM-239/perf-control/statistics-time-io.txt), đủ 60 plan và snapshot index trong cùng thư mục. Manifest ghi tên và SHA-256 của cả 60 plan gốc; toàn bộ plan được bàn giao trong thư mục bằng chứng.

**Đây là đo đối chứng trên tập nhỏ**, chưa là nghiệm thu SLA <500 ms hoặc so sánh trước/sau index. Ledger LARGE chưa có; lệnh strict chạy thật lúc 00:59:30 dừng **BLOCKED** trước khi đo, [lý do](evidence/SCRUM-239/perf-strict.json). AFTER chưa chạy vì chưa có index mới của owner. Các số dưới là elapsed phía SQL, không phải HTTP P95, cũng không tương đương cold buffer sau restart.

| Truy vấn | Lượt đầu (ms) | Năm lượt warm (ms) | Max warm (ms) |
|---|---:|---|---:|
| PeakHours | 99.818 | 119.695 / 14.952 / 8.913 / 21.691 / 10.998 | 119.695 |
| RevenueByLocation | 104.581 | 11.497 / 45.739 / 13.510 / 9.113 / 12.739 | 45.739 |
| ProductRanking | 158.107 | 16.030 / 26.287 / 22.088 / 17.990 / 15.907 | 26.287 |
| ColdChainCompliance | 57.517 | 5.237 / 9.843 / 32.722 / 11.196 / 10.957 | 32.722 |
| ExportSales30Days | 110.116 | 77.574 / 62.059 / 50.982 / 58.110 / 52.477 | 77.574 |

## 6. Chuỗi lạnh — dữ liệu mô phỏng

Chạy **app/simulator/esp32.js thật** với API và SQL thật, dữ liệu cảm biến mô phỏng; **không thử phần cứng ESP32/DHT22**. Các ca chạy từ 00:59:00 đến 00:59:16 ngày 15/11/2026 (+07:00). [Kết quả từng ca](evidence/SCRUM-239/cold-chain/results.json) và log simulator cùng thư mục.

| Ca | Kết quả | Quan sát thực |
|---|---|---|
| KB1 bình thường | PASS | Có raw telemetry mới, năm mẫu cuối trong 2–8°C, máy ACTIVE |
| KB2 quá nhiệt | FAIL | Ba mẫu cuối >8°C, máy vẫn ACTIVE, không có alert nhiệt độ |
| KB3 mở cửa | FAIL | Không có DOOR_OPEN alert sau fixture cửa mở từ ba phút trước và packet live |
| KB4 kẹt ba lần | BLOCKED | Tạo đơn trả HTTP 500 vì kiểu TVP OrderItemType; chưa chạy được ba lần nhả cho đơn này |
| KB5 mất mạng/kết nối lại | FAIL | Job thủ công chuyển OFFLINE; nhận telemetry trở lại vẫn OFFLINE |

Tổng **1 PASS / 3 FAIL / 1 BLOCKED**. KB3 và KB5 dùng timestamp fixture tăng tốc; KB5 gọi job heartbeat thủ công. Không tuyên bố đã đợi đủ 2/5 phút, đã kiểm chứng scheduler tự chạy, hoặc đã kiểm tra trọn vẹn hàng đợi offline bền vững. Không có giao dịch ngân hàng thật. Do job heartbeat dùng thời gian local trong khi ingest ghi UTC, kết quả này cũng cần owner kiểm tra lệch múi giờ.

## 7. Bảo mật và khôi phục (FV-36)

Được chạy độc lập trên CSDL sạch, không dùng các ca npm giả: **18/18 PASS**, RLS ba máy, DENY report và cấm Kiosk thêm sản phẩm. Full/Diff/Log checksum và restore STOPAT thực: COUNT trước/sau=1, đúng tên/giá, marker 2 còn, marker sự cố 3 bị loại. [Runbook, video và log SCRUM-230](Security_Demo.md). Ngày giờ chính xác trong recording.json và clean-run-result.json; không suy rộng demo này thành SLA uptime hoặc RPO bằng 0.

## 8. Lỗi đã sửa và việc còn lại

| Nội dung | Trạng thái |
|---|---|
| FK cũ chặn cài từ đầu (SCRUM-201) | Sửa trong nhánh phụ thuộc; PR #46 cần merge |
| Auth chạy lại nhầm index thành constraint | Sửa trong SCRUM-217; cài lại PASS |
| Parser/batch ingest IoT | Bản sửa trước đã có, sáu regression ingest hiện PASS |
| Temporal history T48 | FAIL; cần xử lý trước khi công bố unit toàn hệ thống đạt |
| QĐ-1 hai nguồn máy, RegisterMachine chưa tạo ngăn | Còn; seed SMALL/LARGE và một ca runner BLOCKED |
| Ba đối tượng API IoT, partition maintenance, scheduler | Còn; smoke/integration chưa đạt đầy đủ |
| TVP OrderItemType qua API | Còn; JAM và luồng mua thật bị chặn |
| Trigger nhiệt/cửa và phục hồi sau offline | Còn; ca mô phỏng FAIL |
| Đồng bộ UTC giữa SQL/API/simulator | Cần owner rà soát; không sửa dữ liệu để che sai giờ |
| PDF ứng dụng, tải CSV mở bằng Excel, HTTP P95 với LARGE | NOT RUN trong phiên này; không ghi PASS |
| Huy review, PR merge và chạy chéo máy khác | Chưa có bằng chứng hoàn tất |

## 9. Chạy lại và điều kiện chốt

```powershell
powershell -NoProfile -File tests/run-acceptance.ps1 -Server .\SQLEXPRESS
npm ci --prefix app/api
npm test --prefix app/api
# Khởi động API với DB_MODE=sqlserver, DB_NAME=CSDL_QA_vừa_tạo, PORT=32139.
# Đặt DB_SERVER/DB_PORT và bốn login theo .env.example trong môi trường local.
$env:SMOKE_URL='http://127.0.0.1:32139'
node app/api/tools/smoke-sqlserver.js
powershell -NoProfile -File tests/run-integration-preflight.ps1 -Database <CSDL_QA> -BaseUrl http://127.0.0.1:32139
powershell -NoProfile -File tests/run-perf.ps1 -Database <CSDL_QA>
# measure-cold-chain đọc DB_NAME/DB_SERVER/DB_PORT và API_URL từ môi trường.
node tests/measure-cold-chain.mjs
```

run-acceptance tạo DB mới mặc định, chạy fixture có guard QA, ghi kết quả từng result set và thoát khác 0 khi có FAIL/BLOCKED. Không chạy suite ghi dữ liệu trên CSDL vận hành. Chạy simulator sau unit/performance vì có ghi dữ liệu và đổi trạng thái máy.

**Kết luận hiện tại:** có báo cáo từ số liệu chạy thật, nhưng chưa nghiệm thu toàn bộ hệ thống. Chỉ chốt các chỉ tiêu tương ứng sau khi sửa lỗi, chạy lại đúng bộ dữ liệu, đính kèm log mới và được Huy review. Không mang số PASS cũ sang lần chạy mới.
