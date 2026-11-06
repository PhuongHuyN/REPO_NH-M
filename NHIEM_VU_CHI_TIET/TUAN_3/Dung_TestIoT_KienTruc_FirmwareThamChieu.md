# Dũng – Tuần 3: Sprint 3 – Kiểm thử, tài liệu, demo

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Trương Tuấn Dũng
- **Email:** dungtuanxz12345@gmail.com
- **Tuần:** 3 (Sprint 3 – Kiểm thử, tài liệu, demo)
- **Thời gian:** 20/11/2026 → 26/11/2026
- **Vai trò:** TV4 – IoT & Chuỗi lạnh (schema iot), mô phỏng ESP32, SQL Agent Job, kiến trúc
- **Mức độ ưu tiên:** High
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-236, SCRUM-237, SCRUM-238

**Mục tiêu Sprint:** Test Report có số liệu thật, đủ tài liệu bắt buộc của đề, Docker chạy được, tag v1.0, tổng duyệt demo và vấn đáp.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-42 (SCRUM-236) | tests_iot.sql + kiểm tra Offline Mode / thông báo 'Tạm ngưng' trên kiosk | 20/11/2026 | 21/11/2026 | High | FV-29 |
| FV-43 (SCRUM-237) | Tài liệu kiến trúc: Component & Deployment Diagram, chương IoT & giới hạn phần cứng, User Manual Operator (máy & cảnh báo) | 22/11/2026 | 24/11/2026 | High | FV-29 |
| FV-44 (SCRUM-238) | (Tùy chọn) Firmware ESP32 tham chiếu – cùng giao thức với simulator, chỉ biên dịch, chưa nạp thiết bị | 25/11/2026 | 26/11/2026 | Low | FV-29 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-42 (SCRUM-236) – tests_iot.sql + kiểm tra Offline Mode / thông báo 'Tạm ngưng' trên kiosk

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 20/11/2026 → 21/11/2026 |
| Mức ưu tiên | High |
| Epic | E4 – IoT & Chuỗi lạnh (iot) |
| Phụ thuộc | FV-29 (SCRUM-223) (Dũng) |
| Người hỗ trợ | Ân |

### 1. MỤC TIÊU
tests_iot.sql + kiểm tra Offline Mode / thông báo 'Tạm ngưng' trên kiosk. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Đề yêu cầu *Offline Mode* (hiện “Out of Order” khi mất kết nối hoặc hỏng làm lạnh). Kiosk đọc `iot.vw_MachineHealth` để quyết định có bán hay không.

### 3. PHẠM VI CÔNG VIỆC
- `tests/tests_iot.sql`: 7 procedure × 3 ca = 21 ca, ROLLBACK sau mỗi ca.
- Kiểm tra kiosk: máy DEGRADED/FAULT/OFFLINE → không cho mua, hiện `DegradedMessage`.
- Kiểm tra simulator lưu đệm khi API tắt và gửi bù khi bật lại.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Viết test**
Theo mẫu `tests/tests_inventory.sql` (FV-19).

**Bước 2. Offline API**
Đang chạy simulator, tắt API (Ctrl+C) 1 phút rồi bật lại → simulator in *lưu đệm N bản ghi* rồi gửi bù; SQL có dữ liệu trong khoảng tắt (cột RecordedAt lấy từ trường `t`).

### Hướng dẫn thực hành IoT (12 mục bắt buộc)

1. **Mục đích:** Kiểm tra hệ thống xử lý đúng khi thiết bị mất mạng hoặc hỏng làm lạnh.
2. **Thiết bị cần chuẩn bị:** **Không có thiết bị thật** (nhóm không mua ESP32/DHT22/servo). Dùng 1 laptop Windows chạy SQL Server + Node.js. Bộ điều khiển máy được **mô phỏng** bằng `app/simulator/esp32.js`.
3. **Phần mềm và công cụ:** SQL Server 2022 (Developer hoặc Express) + SSMS; Node.js ≥ 20; VS Code; trình duyệt Chrome/Edge; (tùy chọn) Postman hoặc `curl` có sẵn trong Windows 10/11.
4. **Thông số cấu hình cần biết:**
- `app/api/.env`: `DEVICE_API_KEY` (khóa thiết bị – simulator gửi trong header `X-Device-Key`), `PORT=3000`, `DB_MODE`, `DB_DEVICE_USER=fv_device_app`, `DB_DEVICE_PASSWORD`.
- Ngưỡng mặc định mỗi máy: MinTemp 2°C, MaxTemp 8°C, ConsecutiveBreaches 3, DoorOpenMaxMinutes 2 (bảng `iot.MachineThresholds`).
- Chu kỳ gửi cảm biến: 5 giây (`--interval`), hỏi hàng chờ nhả: 1,5 giây.
5. **Sơ đồ kết nối:**
```
[esp32.js (giả lập DHT22 + servo)] --HTTP POST /api/iot/telemetry (JSON, X-Device-Key)--> [API Node.js :3000]
        ^                                                                                  |
        |--HTTP GET /api/dispense-queue  <--------------------------------------------------|
        |--HTTP POST /api/orders/items/:id/dispense ---------------------------------------->|
                                                                                           v
                                              [SQL Server: iot.sp_IngestTelemetry, sales.vw_DispenseQueue, sales.sp_RecordDispense]
```
6. **Thao tác từng bước:** xem mục *4. Các bước thực hiện* ở trên.
7. **Lệnh / code sử dụng:** Như mục 4.
8. **Cách kiểm tra thiết bị (mô phỏng) đã hoạt động:**
Terminal simulator in số bản ghi đệm; `SELECT COUNT(*) FROM iot.Telemetry WHERE RecordedAt BETWEEN <lúc tắt> AND <lúc bật>` > 0.
9. **Dữ liệu đầu ra mong đợi:** Không mất bản ghi; kiosk hiện DegradedMessage.
10. **Lỗi thường gặp và cách xử lý:**
Dữ liệu bù bị lệch giờ: kiểm tra simulator gửi `t` theo giờ VN (dòng `ts()`), SQL dùng SYSDATETIME giờ máy.
11. **Kết nối với hệ thống hiện tại:** Như FV-29.
12. **Tiêu chí nghiệm thu:**
- [ ] 21/21 PASS
- [ ] Offline Mode hoạt động

> **Dữ liệu mô phỏng:** Mọi số liệu nhiệt độ/độ ẩm/cửa trong dự án là **dữ liệu mô phỏng**. Tài liệu, slide, Test Report phải ghi rõ *“dữ liệu mô phỏng bằng esp32.js”*; không được ghi *“đã kiểm thử trên phần cứng thật”*.
>
> **Thao tác thủ công:** người thực hiện **Trương Tuấn Dũng**, trên laptop cá nhân (Windows) có SQL Server + Node.js; chuẩn bị theo mục 2–4; bằng chứng: ảnh terminal simulator + ảnh trang web + kết quả truy vấn SQL, lưu vào Google Drive nhóm thư mục `FreshVend/BangChung/FV-42`; người khác tái hiện bằng cách chạy đúng các lệnh ở mục 4 trên CSDL tạo bằng `99_run_all.bat`.

### 5. FILE VÀ MODULE LIÊN QUAN
- `tests/tests_iot.sql` (mới)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Ân kiểm tra hiển thị kiosk.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | tests_iot | F5 | 21/21 PASS |
| 2 | Kiosk | Máy 3 DEGRADED | Hiện thông báo, không bấm mua được |
| 3 | Gửi bù | Tắt API 1 phút | Không mất dữ liệu |

**Kết quả cần lưu lại:** Ảnh PASS + ảnh kiosk.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 21/21 PASS
- [ ] Offline Mode hoạt động

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b test/SCRUM-236-iot-tests
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add tests/tests_iot.sql
git commit -m "test(sql-iot): tests_iot.sql + kiểm tra offline mode"
```
5. **Push**
```powershell
git pull origin main
git push -u origin test/SCRUM-236-iot-tests
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: test/SCRUM-236-iot-tests`.
7. **Mô tả PR:** tiêu đề `[SCRUM-236] tests_iot.sql + kiểm tra Offline Mode / thông báo 'Tạm ngưng' trên kiosk`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-236`; dán ảnh bằng chứng: Ảnh PASS + ảnh kiosk.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d test/SCRUM-236-iot-tests
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-236 |
| Branch | `test/SCRUM-236-iot-tests` |
| Commit | `test(sql-iot): tests_iot.sql + kiểm tra offline mode` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- tests/tests_iot.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 21/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-236
- **Bằng chứng hoàn thành:** Ảnh PASS + ảnh kiosk
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-43 (SCRUM-237) – Tài liệu kiến trúc: Component & Deployment Diagram, chương IoT & giới hạn phần cứng, User Manual Operator (máy & cảnh báo)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 22/11/2026 → 24/11/2026 |
| Mức ưu tiên | High |
| Epic | E4 – IoT & Chuỗi lạnh (iot) |
| Phụ thuộc | FV-29 (SCRUM-223) (Dũng) |
| Người hỗ trợ | Huy |

### 1. MỤC TIÊU
Tài liệu kiến trúc: Component & Deployment Diagram, chương IoT & giới hạn phần cứng, User Manual Operator (máy & cảnh báo). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Nhánh tv4-iot đã có `docs/component_diagram.png`, `docs/deployment_diagram.png` (01/11) – cần cập nhật theo kiến trúc thật: Web (admin/kiosk) → API Node.js → SQL Server (4 login) ← simulator ESP32; Docker.

### 3. PHẠM VI CÔNG VIỆC
- `docs/Architecture.md`: mô tả tầng, giao thức, bảo mật (X-Device-Key, JWT, RBAC/RLS).
- Cập nhật 2 diagram (draw.io) có Docker và 4 login.
- Chương *IoT & giới hạn phần cứng*: giao thức gói JSON, chu kỳ, ngưỡng, Offline Mode; nêu rõ chưa có phần cứng, cách thay simulator bằng ESP32 thật (cùng endpoint).
- `docs/UserManual_Operator.md` phần Máy & chuỗi lạnh, Cảnh báo (Huy viết phần tồn kho).

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Vẽ lại**
draw.io: lưu `.drawio` + xuất PNG.

**Bước 2. Viết chương IoT**
Dùng kết quả FV-29 làm minh họa.

### 5. FILE VÀ MODULE LIÊN QUAN
- `docs/Architecture.md` (mới)
- `docs/component_diagram.png, docs/deployment_diagram.png`
- `docs/UserManual_Operator.md` (phần máy)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Huy hợp nhất UserManual_Operator; Ân lấy hình cho slide.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Đối chiếu | So diagram với code | Đúng thành phần, đúng giao thức |

**Kết quả cần lưu lại:** Link PR.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Diagram khớp hệ thống thật
- [ ] Chương IoT ghi rõ phần mô phỏng

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b docs/SCRUM-237-architecture-iot
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add docs/Architecture.md docs/component_diagram.png docs/deployment_diagram.png docs/UserManual_Operator.md
git commit -m "docs: kiến trúc, chương IoT, user manual operator phần máy"
```
5. **Push**
```powershell
git pull origin main
git push -u origin docs/SCRUM-237-architecture-iot
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: docs/SCRUM-237-architecture-iot`.
7. **Mô tả PR:** tiêu đề `[SCRUM-237] Tài liệu kiến trúc: Component & Deployment Diagram, chương IoT & giới hạn phần cứng, User Manual Operator (máy & cảnh báo)`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-237`; dán ảnh bằng chứng: Link PR.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d docs/SCRUM-237-architecture-iot
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-237 |
| Branch | `docs/SCRUM-237-architecture-iot` |
| Commit | `docs: kiến trúc, chương IoT, user manual operator phần máy` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- docs/Architecture.md
- 2 diagram

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 24/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-237
- **Bằng chứng hoàn thành:** Link PR
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-44 (SCRUM-238) – (Tùy chọn) Firmware ESP32 tham chiếu – cùng giao thức với simulator, chỉ biên dịch, chưa nạp thiết bị

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 25/11/2026 → 26/11/2026 |
| Mức ưu tiên | Low |
| Epic | E4 – IoT & Chuỗi lạnh (iot) |
| Phụ thuộc | FV-29 (SCRUM-223) (Dũng) |
| Người hỗ trợ | Không |

### 1. MỤC TIÊU
(Tùy chọn) Firmware ESP32 tham chiếu – cùng giao thức với simulator, chỉ biên dịch, chưa nạp thiết bị. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Đề liệt kê sản phẩm *Automated Hardware Controller (ESP32)*. Nhóm không có thiết bị, nên chỉ làm **mã tham chiếu** để chứng minh hiểu giao thức. Làm khi FV-29, FV-42, FV-43 đã xong; nếu thiếu thời gian thì bỏ, ghi vào phần *Hạn chế* của báo cáo.

### 3. PHẠM VI CÔNG VIỆC
- `firmware/esp32_freshvend/esp32_freshvend.ino`: đọc DHT22, POST JSON `{machineId, readings}` kèm header `X-Device-Key`, GET hàng chờ nhả, quay servo.
- Biên dịch thành công trong Arduino IDE (board *ESP32 Dev Module*).
- README ghi rõ: **chưa nạp/kiểm thử trên phần cứng thật**.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Cài Arduino IDE 2**
Boards Manager → *esp32 by Espressif*; Library Manager → *DHT sensor library* (Adafruit), *ESP32Servo*, *ArduinoJson*.

**Bước 2. Viết mã**
Dùng `WiFi.h`, `HTTPClient.h`; chu kỳ 5 giây; payload giống `simulator/esp32.js` dòng 75–90.

**Bước 3. Biên dịch**
Bấm ✓ *Verify*. Chụp ảnh *Done compiling*.

### Hướng dẫn thực hành IoT (12 mục bắt buộc)

1. **Mục đích:** Mã nguồn bộ điều khiển thật theo đúng giao thức hệ thống, sẵn sàng nạp khi có thiết bị.
2. **Thiết bị cần chuẩn bị:** **Không có thiết bị thật** (nhóm không mua ESP32/DHT22/servo). Dùng 1 laptop Windows chạy SQL Server + Node.js. Bộ điều khiển máy được **mô phỏng** bằng `app/simulator/esp32.js`.
3. **Phần mềm và công cụ:** SQL Server 2022 (Developer hoặc Express) + SSMS; Node.js ≥ 20; VS Code; trình duyệt Chrome/Edge; (tùy chọn) Postman hoặc `curl` có sẵn trong Windows 10/11.
4. **Thông số cấu hình cần biết:**
- `app/api/.env`: `DEVICE_API_KEY` (khóa thiết bị – simulator gửi trong header `X-Device-Key`), `PORT=3000`, `DB_MODE`, `DB_DEVICE_USER=fv_device_app`, `DB_DEVICE_PASSWORD`.
- Ngưỡng mặc định mỗi máy: MinTemp 2°C, MaxTemp 8°C, ConsecutiveBreaches 3, DoorOpenMaxMinutes 2 (bảng `iot.MachineThresholds`).
- Chu kỳ gửi cảm biến: 5 giây (`--interval`), hỏi hàng chờ nhả: 1,5 giây.
5. **Sơ đồ kết nối:**
Sơ đồ đề xuất (chưa lắp): DHT22 DATA → GPIO4 (điện trở kéo lên 10kΩ lên 3V3), VCC 3V3, GND; Servo SG90 tín hiệu → GPIO18, nguồn 5V riêng, chung GND; công tắc cửa → GPIO27 (INPUT_PULLUP).
6. **Thao tác từng bước:** xem mục *4. Các bước thực hiện* ở trên.
7. **Lệnh / code sử dụng:** Như mục 4.
8. **Cách kiểm tra thiết bị (mô phỏng) đã hoạt động:**
Chỉ kiểm tra biên dịch. **Không** tuyên bố đã chạy trên ESP32.
9. **Dữ liệu đầu ra mong đợi:** File .ino biên dịch thành công.
10. **Lỗi thường gặp và cách xử lý:**
- Thiếu thư viện: cài qua Library Manager.
- Sai board: chọn *ESP32 Dev Module*.
11. **Kết nối với hệ thống hiện tại:** Cùng endpoint với simulator: `POST /api/iot/telemetry`, `GET /api/dispense-queue`, `POST /api/orders/items/:id/dispense`.
12. **Tiêu chí nghiệm thu:**
- [ ] Biên dịch được
- [ ] Ghi rõ chưa thử phần cứng

> **Dữ liệu mô phỏng:** Mọi số liệu nhiệt độ/độ ẩm/cửa trong dự án là **dữ liệu mô phỏng**. Tài liệu, slide, Test Report phải ghi rõ *“dữ liệu mô phỏng bằng esp32.js”*; không được ghi *“đã kiểm thử trên phần cứng thật”*.
>
> **Thao tác thủ công:** người thực hiện **Trương Tuấn Dũng**, trên laptop cá nhân (Windows) có SQL Server + Node.js; chuẩn bị theo mục 2–4; bằng chứng: ảnh terminal simulator + ảnh trang web + kết quả truy vấn SQL, lưu vào Google Drive nhóm thư mục `FreshVend/BangChung/FV-44`; người khác tái hiện bằng cách chạy đúng các lệnh ở mục 4 trên CSDL tạo bằng `99_run_all.bat`.

### 5. FILE VÀ MODULE LIÊN QUAN
- `firmware/esp32_freshvend/esp32_freshvend.ino` (mới)
- `firmware/README.md` (mới)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Không phụ thuộc người khác.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Biên dịch | Arduino IDE Verify | Done compiling |

**Kết quả cần lưu lại:** Ảnh Done compiling.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Biên dịch được
- [ ] Ghi rõ chưa thử phần cứng

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b feature/SCRUM-238-esp32-firmware-ref
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add firmware/esp32_freshvend/esp32_freshvend.ino firmware/README.md
git commit -m "feat(firmware): mã tham chiếu ESP32 (chưa thử trên phần cứng)"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-238-esp32-firmware-ref
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-238-esp32-firmware-ref`.
7. **Mô tả PR:** tiêu đề `[SCRUM-238] (Tùy chọn) Firmware ESP32 tham chiếu – cùng giao thức với simulator, chỉ biên dịch, chưa nạp thiết bị`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-238`; dán ảnh bằng chứng: Ảnh Done compiling.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-238-esp32-firmware-ref
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-238 |
| Branch | `feature/SCRUM-238-esp32-firmware-ref` |
| Commit | `feat(firmware): mã tham chiếu ESP32 (chưa thử trên phần cứng)` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- firmware/esp32_freshvend.ino

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 26/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-238
- **Bằng chứng hoàn thành:** Ảnh Done compiling
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
