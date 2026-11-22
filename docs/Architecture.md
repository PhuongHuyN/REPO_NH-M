# Kiến trúc FreshVend

> Tài liệu này mô tả trạng thái repository hiện tại. **FreshVend chưa có phần cứng thật**: telemetry, nhiệt độ, độ ẩm, trạng thái cửa và thao tác nhả hàng đều do `app/simulator/esp32.js` mô phỏng. Kết quả kiểm thử IoT hiện không phải số đo từ cảm biến vật lý.

## Thành phần và ranh giới

```text
Trình duyệt ── HTTPS/HTTP REST + Bearer JWT ──> Web admin / API Node.js
    │                                           ├── trang kiosk
    │                                           └── SQL Server (FreshVendDB)
    │
Simulator ESP32 (hoặc ESP32 thật) ── REST + X-Device-Key ──> API Node.js
API Node.js ── kết nối SQL theo role ──> SQL Server
```

- **Web admin/operator và kiosk:** HTML/CSS/JavaScript tĩnh trong `app/web`. Trang quản trị đọc API; kiosk hiển thị thông tin sản phẩm, tình trạng phục vụ và thông báo tạm ngưng.
- **API Node.js:** `app/api/src/server.js` phục vụ web và REST API. Các route gọi stored procedure, view và hàm SQL qua `app/api/src/db.js`. API kiểm tra vai trò, chuyển lỗi SQL thành HTTP và cấp luồng SSE tình trạng máy cho dashboard.
- **SQL Server:** CSDL `FreshVendDB` lưu người dùng/phân quyền, máy/địa điểm, cấu hình ngưỡng, telemetry/cảnh báo, bán hàng và hàng chờ nhả. Logic nghiệp vụ chính nằm trong procedure/view/function; SQL Server là nơi lưu dữ liệu bền vững ở chế độ `DB_MODE=sqlserver`.
- **Bốn SQL login của ứng dụng:** `fv_admin_app`, `fv_operator_app`, `fv_kiosk_app`, `fv_device_app`, được ánh xạ lần lượt vào `r_admin`, `r_operator`, `r_kiosk`, `r_device` trong `sql/40_security.sql`. API chọn thông tin kết nối tương ứng theo vai trò; đây là tài khoản dịch vụ, khác với JWT của từng người dùng.
- **Simulator:** `app/simulator/esp32.js` tạo số đo giả, gọi đúng endpoint thiết bị, giả lập servo/kẹt hàng và timeout mất kết nối. Nó không nằm trong `docker-compose.yml` mặc định.
- **Docker:** `docker-compose.yml` chạy hai service `db` (SQL Server 2022) và `api` (build từ `app/Dockerfile`), gắn volume dữ liệu SQL. Simulator chạy riêng trên máy host/thiết bị khác và trỏ `API_URL` tới API. `depends_on` không đồng nghĩa SQL đã sẵn sàng nhận kết nối; cần cấu hình môi trường và khởi tạo schema theo hướng dẫn cài đặt.

## Giao thức và bảo mật

Chương đối chiếu chi tiết về luồng IoT, RBAC/RLS và trạng thái triển khai nằm tại [Module IoT & Bảo mật](Module_IoT_and_Security.md).

- Browser và thiết bị giao tiếp với API bằng HTTP JSON trong cấu hình phát triển; khi triển khai cần đặt reverse proxy/TLS trước API để bảo vệ JWT và device key khi truyền.
- Phiên người dùng dùng `Authorization: Bearer <JWT>` (JWT HS256, mặc định hết hạn sau 8 giờ). API giới hạn route theo `Admin`, `Operator`, `Kiosk`; không nhúng mật khẩu SQL hay device key vào mã giao diện.
- Thiết bị gửi `X-Device-Key`; API so sánh với `DEVICE_API_KEY`. Endpoint nhận telemetry yêu cầu khóa này. Endpoint hàng chờ và báo kết quả nhả chấp nhận thiết bị hoặc phiên phù hợp. Dùng khóa dài, riêng tư, luân chuyển khi lộ; cấu hình thật phải đặt trong secret/env, không dùng giá trị mẫu.
- API áp dụng kiểm tra vai trò ở lớp HTTP. SQL áp dụng bốn login/role, GRANT/DENY theo `sql/40_security.sql`; RLS giới hạn Operator theo máy được giao (`auth.UserMachine`). Đây là hai lớp bảo vệ, không thay thế lẫn nhau.
- `X-Device-Key` là một khóa dùng chung theo cấu hình hiện tại, không phải danh tính mật mã riêng cho từng máy. API không ràng buộc khóa với `machineId`; việc đó và chống giả mạo/gửi lặp cần được xem xét trước triển khai thiết bị thật.

## Luồng dữ liệu

### Telemetry, trạng thái và cảnh báo

1. Simulator đọc cảm biến giả và POST `/api/iot/telemetry` với `machineId` cùng mảng `readings` JSON (`t` tùy chọn, `temp`, `hum`, `door`); header là `X-Device-Key`.
2. API kiểm tra payload/kích thước rồi gọi `iot.sp_IngestTelemetry`. Procedure ghi vào `iot.Telemetry`, cập nhật `iot.Machines.LastHeartbeat` và trả trạng thái máy. Thời gian được server gán nếu gói không có `t`.
3. `iot.vw_MachineHealth` cung cấp trạng thái/heartbeat/số đo hiện tại; `iot.vw_OpenAlerts` lọc các cảnh báo chưa giải quyết. Dashboard đọc chúng qua API/SSE; API cung cấp SSE health khoảng mỗi 2 giây. **Trong `fakeDb.js`,** logic mẫu kiểm tra nhiệt độ liên tiếp/cửa và chuyển DEGRADED. Tuy nhiên, phiên bản `sql/13_procs_iot.sql` hiện tại của `sp_IngestTelemetry` chỉ ghi telemetry/cập nhật heartbeat; bộ file SQL IoT đã đối chiếu chưa cho thấy logic tương đương tạo cảnh báo nhiệt độ/cửa và chuyển DEGRADED. Đây là điểm cần đối chiếu/hoàn thiện trước khi coi luồng chuỗi lạnh SQL là tương đương demo.
4. Job `iot.sp_CheckHeartbeat` chuyển máy sang `OFFLINE` khi quá timeout mặc định 5 phút và mở cảnh báo. SQL Agent jobs hoặc lịch dự phòng trong API (`JOBS_FALLBACK=true`, ví dụ SQL Express) chạy các tác vụ định kỳ.
5. Người vận hành xem telemetry gần đây, điều tra máy/cửa/nhiệt độ, xác nhận hoặc giải quyết cảnh báo qua `iot.sp_AcknowledgeAlert`; sau khắc phục có thể dùng thao tác xóa lỗi theo quyền được cấp.

### Kiosk và hàng chờ nhả đồ

1. Khách tạo đơn/thanh toán trên kiosk; SQL lưu trạng thái đơn và `sales.vw_DispenseQueue` chỉ đưa các mặt hàng đủ điều kiện nhả vào hàng chờ.
2. Simulator hỏi `GET /api/dispense-queue?machineId=...` mỗi 1,5 giây; thiết bị thật sẽ hỏi endpoint tương tự. API đọc view hàng chờ bằng kết nối kiosk/device.
3. Bộ điều khiển tác động cơ cấu nhả và POST `/api/orders/items/:itemId/dispense` với `SUCCESS` hoặc `JAM`. SQL ghi lần thử; kẹt nhiều lần có thể kích hoạt hoàn tiền tự động theo logic sales.
4. Kiosk lấy trạng thái phục vụ máy; khi máy không phục vụ, giao diện hiện thông báo tạm ngưng/ngoài dịch vụ thay vì tiếp tục bán.

## IoT & giới hạn phần cứng

- **Phần cứng:** Chưa có ESP32, cảm biến DHT22, công tắc cửa, servo hay máy bán hàng thật được kết nối trong repository này. `esp32.js` chỉ sinh số liệu ngẫu nhiên/mô phỏng: nhiệt độ quanh 4–5°C (hoặc tăng lên khi dùng `--overheat`), độ ẩm 75–85%, cửa theo cờ `--door`; `--jam` mô phỏng kẹt motor. Vì vậy không thể kết luận hiệu chuẩn cảm biến, sai số đo, thời gian đáp ứng, an toàn thực phẩm hay độ tin cậy cơ khí từ demo.
- **Gói JSON:** `POST /api/iot/telemetry`, ví dụ:

  ```json
  { "machineId": 3, "readings": [{ "t": "2026-11-20T10:00:00", "temp": 4.5, "hum": 80, "door": 0 }] }
  ```

  `machineId` hoặc `serial` xác định máy; mỗi reading có `temp` bắt buộc, `hum` (0–100), `door` (0/1 hoặc boolean), `t` thời gian tùy chọn. Dùng ISO-8601 có múi giờ khi thiết bị tự đóng dấu thời gian. Header `X-Device-Key` bắt buộc.
- **Chu kỳ hiện tại:** telemetry mặc định mỗi **5 giây**; có thể đổi bằng `--interval`. Thăm dò hàng chờ nhả mỗi **1,5 giây**. API chấp nhận mảng tối đa 500 readings.
- **Ngưỡng khởi tạo:** `MinTemp=2°C`, `MaxTemp=8°C`, `ConsecutiveBreaches=3`, `DoorOpenMaxMinutes=2`; message suy giảm mặc định nằm trong `iot.sp_RegisterMachine`/bảng `iot.MachineThresholds`. Có thể cấu hình theo máy qua API thresholds/Admin. Timeout heartbeat OFFLINE mặc định 5 phút.
- **Offline Mode:** Với lỗi gọi API, simulator gắn timestamp cho số đo, giữ trong buffer RAM (tối đa 500 bản ghi/máy) và gửi bù trong lần thử kế tiếp. Buffer mất khi tiến trình dừng; không có lưu trữ bền vững, xác nhận từng reading hay đảm bảo không trùng khi gửi lại. Cờ `--offline N` mô phỏng máy im lặng: bỏ qua cả telemetry lẫn hỏi hàng chờ, không tạo mẫu đọc để buffer. Khi heartbeat quá hạn SQL đánh dấu OFFLINE.
- **DegradedMessage:** cấu hình thông điệp máy suy giảm được lưu theo máy; kiosk/UI có thể hiện thông báo máy tạm ngưng khi API trả trạng thái phù hợp. Trong mock, trạng thái DEGRADED do logic giả lập đặt; SQL hiện có cột/cấu hình nhưng cần xác minh cơ chế thực sự đặt trạng thái, tạo cảnh báo và trả thông điệp sau telemetry (xem ghi chú luồng trên) trước khi vận hành.
- **Thay simulator bằng ESP32 thật:** giữ cùng giao thức API, cấu hình `API_URL` trỏ tới host API và cấp `DEVICE_API_KEY` an toàn. Firmware đọc cảm biến nhiệt/ẩm và công tắc cửa, đóng JSON đúng schema, POST telemetry theo chu kỳ; GET hàng chờ mỗi 1,5 giây; điều khiển motor rồi POST `SUCCESS`/`JAM`. Nên có hàng đợi flash/SD có giới hạn và retry có backoff, timestamp UTC, TLS qua proxy/gateway, khóa riêng từng máy hoặc cơ chế ký/xoay khóa, chống replay, watchdog và xử lý lỗi cảm biến. Đăng ký Serial/MachineId và kiểm chứng endpoint/role trước khi đấu cơ cấu thật. Endpoint không cần thay đổi; cần triển khai và nghiệm thu firmware, bảo mật, hiệu chuẩn, điện/cơ khí riêng.

## Sơ đồ

- [Component Diagram](component_diagram.drawio)
- [Deployment Diagram](deployment_diagram.drawio)
- Ảnh PNG hiện có tại `component_diagram.png` và `deployment_diagram.png`. Hai file draw.io đi kèm là nguồn có thể chỉnh sửa. Mở từng file trong diagrams.net (app hoặc web), chọn **File → Export as → PNG**, xuất với tên tương ứng vào `docs/`. Nếu ảnh PNG có sẵn không đồng bộ với sơ đồ, xuất lại từ file `.drawio`.

## Đối chiếu trước phát hành

Đối chiếu route/payload với `app/api/src/routes/iot.js`, `app/api/src/routes/sales.js`; cách mô phỏng với `app/simulator/esp32.js`; schema, view và ngưỡng với `sql/02_tables_iot.sql`, `sql/13_procs_iot.sql`, `sql/23_objects_iot.sql`; quyền với `sql/40_security.sql`; và cấu hình chạy với `docker-compose.yml`, `app/api/src/config.js`. Đặc biệt xác nhận các trigger/job tạo DEGRADED/alerts, timeout và mapping bốn tài khoản sau khi dựng CSDL mới, vì tài liệu không thay thế xác minh runtime.
