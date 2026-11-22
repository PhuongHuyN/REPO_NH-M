# Module IoT & Bảo mật — FreshVend

> Tài liệu đối chiếu mã nguồn trong repository. FreshVend **không có phần cứng ESP32, DHT22, công tắc cửa hoặc servo thật**. Toàn bộ dữ liệu nhiệt độ, độ ẩm, trạng thái cửa và cơ cấu nhả hàng trong luồng IoT/kiểm thử hiện được tạo bởi `app/simulator/esp32.js`. Không dùng kết quả mô phỏng để kết luận về hiệu chuẩn cảm biến, an toàn chuỗi lạnh hoặc độ tin cậy cơ khí.

## 1. Module IoT & Chuỗi lạnh (`iot`)

### 1.1 Kiến trúc luồng

```text
app/simulator/esp32.js
  ├─ POST /api/iot/telemetry (X-Device-Key, JSON)
  │       → API Node.js → iot.sp_IngestTelemetry → iot.Telemetry / iot.Machines
  ├─ GET /api/dispense-queue?machineId=N (X-Device-Key)
  │       → API Node.js → sales.vw_DispenseQueue
  └─ POST /api/orders/items/:itemId/dispense (SUCCESS | JAM)
          → API Node.js → sales.sp_RecordDispense
```

API route khai báo tại `app/api/src/routes/iot.js` và `app/api/src/routes/sales.js`. API nhận JSON, xác thực request, rồi gọi procedure/view SQL qua `app/api/src/db.js`. Trong chế độ `DB_MODE=sqlserver`, dữ liệu được lưu trong SQL Server. `DB_MODE=demo` sử dụng `app/api/test/fakeDb.js` với dữ liệu trong bộ nhớ; cần phân biệt rõ kết quả demo với kết quả SQL Server.

### 1.2 Telemetry và hàng chờ nhả

Simulator mặc định tạo số đo cho các máy 1–5 và gửi mỗi **5 giây** (có thể thay đổi bằng `--interval`). Payload gửi tới `POST /api/iot/telemetry`:

```json
{
  "machineId": 3,
  "readings": [{ "temp": 4.5, "hum": 80, "door": 0 }]
}
```

`temp` là bắt buộc; `hum`, `door` và thời gian `t` được API/SQL kiểm tra nếu có. Simulator không gửi `t` trong hoạt động thường, để server đặt thời gian nhận. Request gửi header `X-Device-Key`. Route giới hạn mảng tối đa 500 readings. Trong SQL, `iot.sp_IngestTelemetry` parse payload bằng `OPENJSON`, ghi `iot.Telemetry`, cập nhật `iot.Machines.LastHeartbeat` và trả máy tương ứng.

Simulator hỏi hàng chờ mỗi **1,5 giây** qua `GET /api/dispense-queue?machineId=N`. Hàng chờ đến từ `sales.vw_DispenseQueue`. Mỗi mặt hàng được mô phỏng nhả thì simulator gọi `POST /api/orders/items/:itemId/dispense` với `SUCCESS` hoặc `JAM`; tình huống `--jam` gửi mã `E_MOTOR_STALL`. SQL ghi nhận qua `sales.sp_RecordDispense`; quy tắc retry/hoàn tiền thuộc module Sales.

### 1.3 Ngưỡng và trạng thái máy

Giá trị mặc định lưu trong cấu hình máy `iot.MachineThresholds` là:

| Cấu hình | Mặc định |
|---|---:|
| `MinTemp` | 2°C |
| `MaxTemp` | 8°C |
| `ConsecutiveBreaches` | 3 lần đo liên tiếp |
| `DoorOpenMaxMinutes` | 2 phút |
| Heartbeat timeout để đánh dấu OFFLINE | 5 phút |

Trạng thái máy trong schema gồm `ACTIVE`, `DEGRADED`, `OFFLINE`, `FAULT`. `iot.vw_MachineHealth` cung cấp trạng thái/heartbeat/số đo mới nhất; `iot.vw_OpenAlerts` liệt kê alert chưa có `ResolvedAt`. `iot.sp_CheckHeartbeat` có thể chuyển máy từ `ACTIVE`/`DEGRADED` sang `OFFLINE` và tạo alert OFFLINE sau timeout; lịch chạy phụ thuộc cấu hình SQL Agent hoặc `JOBS_FALLBACK` của API.

**Giới hạn cần phân biệt theo chế độ:** `fakeDb.js` có logic kiểm tra nhiệt độ vượt ngưỡng liên tiếp, mở cảnh báo nhiệt độ, đặt `DEGRADED`, kiểm tra cửa và tạo `DOOR_OPEN`. Bản SQL hiện tại của `iot.sp_IngestTelemetry` chỉ ghi readings và heartbeat; trong các file SQL đã đối chiếu chưa thấy phần tính chuỗi vi phạm nhiệt độ/cửa tương ứng để tạo alert và chuyển `DEGRADED`. Các ngưỡng và `DegradedMessage` được lưu/cập nhật ở SQL không tự chứng minh rằng rule đang được thực thi. Kiểm thử giả lập trên `DB_MODE=demo` vì vậy không phải bằng chứng rằng luồng SQL Server có cùng hành vi.

Kiosk/UI có thể nhận trạng thái máy và thông điệp suy giảm từ API; `app/web/js/kiosk.js` hiển thị thông báo tạm ngưng cho trạng thái `DEGRADED`/`OFFLINE`. `DegradedMessage` có giá trị cấu hình mặc định khi đăng ký máy và route Admin để cập nhật ngưỡng/thông điệp. Cần kiểm tra đường đi của message và trạng thái trong SQL thật trước khi coi cảnh báo/kiosk là vận hành đầy đủ.

### 1.4 Offline Mode và giới hạn mô phỏng

Khi lời gọi API thất bại, `esp32.js` gắn timestamp, giữ readings trong buffer RAM tối đa 500 mẫu mỗi máy và thử gửi bù ở vòng tiếp theo. Buffer không bền vững và mất khi tiến trình dừng; cơ chế không bảo đảm exactly-once, nên dữ liệu gửi lại có khả năng lặp. Cờ `--offline N` có nghĩa là máy mô phỏng im lặng: bỏ qua telemetry và poll nhả, không tạo readings để lưu buffer; SQL heartbeat/job sẽ phát hiện timeout theo cấu hình. Đây không phải mô phỏng lưu trữ cục bộ khi thiết bị mất mạng.

Các cờ `--overheat`, `--door`, `--jam`, `--offline` tạo kịch bản phục vụ demo. Nhiệt độ/độ ẩm là số giả lập, không phải số đo vật lý. `esp32.js` chưa điều khiển motor thật và không kiểm chứng kết quả nhả ngoài API callback.

## 2. Bảo mật: X-Device-Key, JWT, RBAC và RLS

### 2.1 Xác thực thiết bị — `X-Device-Key`

`app/api/src/app.js` kiểm tra header `X-Device-Key` cho route `auth: 'device'`; route telemetry `/api/iot/telemetry` dùng kiểu này. Các route `auth: 'user-or-device'` chấp nhận device key hoặc JWT người dùng, gồm GET hàng chờ và POST báo kết quả dispense. Header được so sánh trực tiếp với `DEVICE_API_KEY` trong `app/api/src/config.js`. Simulator đọc cùng khóa từ environment hoặc `app/api/.env`.

Đây là một khóa dùng chung, không phải credential riêng theo máy. API không ràng buộc key với `machineId`; endpoint queue nhận `machineId` từ query khi caller là Device và procedure ingest nhận định danh máy từ payload. Vì thế khóa hiện tại xác thực nhóm thiết bị nhưng không chứng minh từng thiết bị chỉ được thao tác trên đúng máy của nó. Giá trị mặc định trong config là giá trị phát triển; cần secret riêng, TLS và cơ chế cấp/thu hồi/luân chuyển khóa trước khi triển khai mạng thật.

### 2.2 Người dùng và phiên JWT

1. `POST /api/auth/login` là route public để nhận thông tin đăng nhập; API gọi `auth.sp_Login` qua SQL pool `Kiosk`.
2. Procedure kiểm tra tài khoản, trạng thái và password hash, cập nhật `auth.LoginHistory`/số lần đăng nhập sai và trả thông tin người dùng cùng máy được giao. SQL dùng `auth.fn_HashPassword` với SHA2-256 và salt riêng (không lưu mật khẩu thuần). Sau năm lần sai theo logic hiện tại, tài khoản bị vô hiệu hóa cho tới khi được Admin kích hoạt lại.
3. API ký JWT HS256 bằng `app/api/src/lib/jwt.js`; request người dùng gửi `Authorization: Bearer <token>`. Verify kiểm tra chữ ký, thuật toán HS256 và thời gian hết hạn.
4. Thời hạn mặc định là 8 giờ cho Admin/Operator và 720 giờ (30 ngày) cho Kiosk; cấu hình tương ứng là `JWT_EXPIRES_HOURS` và `KIOSK_SESSION_HOURS`. API quản lý tài khoản, đổi mật khẩu, kích hoạt/vô hiệu hóa và giao máy qua các route/procedure auth.

API còn giới hạn đăng nhập sai trong bộ nhớ theo IP: tối đa 10 lần/phút/tiến trình; đây không phải bộ đếm phân tán. JWT là stateless trong code hiện tại, không thấy route refresh/revoke token hoạt động; vô hiệu hóa tài khoản không nhất thiết thu hồi JWT đã ký trước khi hết hạn. `JWT_SECRET` có giá trị mặc định trong config, phải thay bằng secret mạnh riêng khi triển khai. Login không bật TLS tự thân; dùng HTTPS/reverse proxy ở môi trường thật.

### 2.3 RBAC — quyền theo vai trò

RBAC được áp dụng ở hai lớp khác nhau:

| Lớp | Role/tài khoản | Cách áp dụng trong repo |
|---|---|---|
| API / người dùng | `Admin`, `Operator`, `Kiosk` | JWT chứa role; route metadata `roles` chặn role không phù hợp. Auth routes cho Admin tạo tài khoản, gán máy, kích hoạt/vô hiệu hóa; Operator/Admin được đọc phần vận hành theo khai báo route. |
| API / thiết bị | `Device` | Không phải role người dùng đăng nhập; `app.js` tạo role nội bộ sau khi kiểm tra device key. Chỉ các route `device` hoặc `user-or-device` chấp nhận nó. |
| SQL Server | Login `fv_admin_app`, `fv_operator_app`, `fv_kiosk_app`, `fv_device_app`; database role tương ứng `r_admin`, `r_operator`, `r_kiosk`, `r_device` | `sql/40_security.sql` tạo/mapping bốn login/user/role và cấp GRANT theo allow-list; Operator bị DENY schema `report`. Admin được thêm vào `db_owner`, quyền rộng hơn ba role còn lại. |

API tạo pool kết nối riêng theo vai trò trong `app/api/src/db.js`; user login dùng pool `Kiosk` có quyền gọi `auth.sp_Login`, còn mỗi request sau xác thực dùng pool role tương ứng. Khi chạy SQL Server, các thao tác được bind tham số, ghi qua stored procedure và đọc qua view/TVF. Tài khoản người dùng trong `auth.UserRole` không phải các SQL login dịch vụ. SQL `auth.Role` hiện có Admin/Operator/Kiosk; Device được mô tả như role service trong `40_security.sql`, không phải loại tài khoản người dùng đăng nhập tạo qua `auth.sp_CreateUser`.

### 2.4 RLS — Row-Level Security

`sql/40_security.sql` định nghĩa `auth.MachinePolicy` với filter predicate trên các bảng tồn tại trong lần chạy script: `inventory.Machine`, `inventory.Slot` và `iot.Machines`. Hàm lọc lấy `SESSION_CONTEXT(N'UserId')` và đối chiếu `auth.UserMachine`. Với `r_operator`, chỉ hàng máy/ngăn được giao được nhìn thấy; các role không thuộc `r_operator` được predicate cho phép qua. Đây là **filter predicate** (lọc hàng đọc/nhìn thấy), không phải block predicate cho mọi thao tác ghi.

Trước mỗi lệnh SQL, `db.js` đặt `sp_set_session_context @key=N'UserId'` trong cùng batch với lệnh nghiệp vụ, để SQL policy biết user hiện tại cả khi pool được tái sử dụng. Riêng các kết nối `Kiosk` và `Device` dùng `UserId=null`; theo hàm RLS hiện tại, chúng không bị lọc theo máy giao. Bởi vậy không được diễn giải RLS là ranh giới thiết bị hoặc RLS toàn hệ thống. API phải kiểm tra thêm phạm vi từng request; việc ràng buộc device key với machine ID hiện chưa có.

RLS tác động lên các bảng được gắn predicate và các truy vấn phụ thuộc chúng; không tự lọc mọi bảng IoT/alert/telemetry hay mọi quyền API. Role `r_device` và `r_kiosk` không thuộc `r_operator`, do đó policy cụ thể này không giới hạn họ theo `auth.UserMachine`. Cần kiểm tra trạng thái policy thực tế sau cài mới vì `40_security.sql` có thể bỏ qua object chưa tồn tại; chạy script lại sau khi các bảng đã được tạo.

### 2.5 Audit và bằng chứng kiểm thử

- `auth.sp_Login` ghi lần đăng nhập thành công/thất bại vào `auth.LoginHistory`; `audit.vw_LoginActivity` tổng hợp hoạt động đăng nhập.
- `auth.trg_Users_Audit` ghi thay đổi người dùng vào `audit.ChangeLog`, không đưa password hash/salt vào JSON audit. `SESSION_CONTEXT` cung cấp UserId khi thao tác qua API.
- `audit.AuditLog` được tạo trong schema, nhưng trong các procedure/route đã rà soát chưa thấy luồng ghi tổng quát vào bảng này; không nên khẳng định mọi thao tác đã được audit ở đó.
- Kết quả SQL auth/RLS được ghi trong [Security Demo SCRUM-230](Security_Demo.md), bao gồm test role/RLS và log cài sạch. Bằng chứng đó xác nhận các ca được chạy trên môi trường ghi trong report, không thay thế xác minh cấu hình production.

## 3. Đối chiếu mã nguồn

- IoT API: `app/api/src/routes/iot.js`, `app/api/src/routes/sales.js`, `app/api/src/app.js`.
- Simulator: `app/simulator/esp32.js`; mock/quy tắc demo: `app/api/test/fakeDb.js`.
- SQL IoT: `sql/02_tables_iot.sql`, `sql/13_procs_iot.sql`, `sql/23_objects_iot.sql`, `sql/45_jobs.sql`.
- Auth/audit/RBAC/RLS: `sql/02_tables_auth.sql`, `sql/02_tables_audit.sql`, `sql/10_procs_auth.sql`, `sql/20_objects_auth.sql`, `sql/40_security.sql`.
- JWT, role guards và kết nối: `app/api/src/lib/jwt.js`, `app/api/src/routes/auth.js`, `app/api/src/config.js`, `app/api/src/db.js`.
- Tài liệu liên quan: [Kiến trúc](Architecture.md), [Thiết kế chi tiết/API](DetailedDesign.md), [hướng dẫn vận hành](UserManual_Operator.md), [bằng chứng security](Security_Demo.md).
