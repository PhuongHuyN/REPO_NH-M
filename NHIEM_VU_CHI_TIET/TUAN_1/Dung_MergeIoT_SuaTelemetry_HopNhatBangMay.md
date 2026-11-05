# Dũng – Tuần 1: Sprint 1 – Nền tảng CSDL

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Trương Tuấn Dũng
- **Email:** dungtuanxz12345@gmail.com
- **Tuần:** 1 (Sprint 1 – Nền tảng CSDL)
- **Thời gian:** 06/11/2026 → 12/11/2026
- **Vai trò:** TV4 – IoT & Chuỗi lạnh (schema iot), mô phỏng ESP32, SQL Agent Job, kiến trúc
- **Mức độ ưu tiên:** Highest
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-206, SCRUM-207, SCRUM-208

**Mục tiêu Sprint:** Mọi bảng và stored procedure lõi của 5 module có trên main; chạy toàn bộ script trên CSDL trống không lỗi; xóa hết nhánh tồn đọng.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-12 (SCRUM-206) | Đưa nhánh tv4-iot lên main, gộp file theo QĐ-3, sửa lệch gói telemetry (machineId/serial) | 06/11/2026 | 08/11/2026 | Highest | FV-01 |
| FV-13 (SCRUM-207) | Hợp nhất bảng máy và địa điểm theo QĐ-1 (iot.Machines, iot.Locations) + view tương thích inventory.Machine | 09/11/2026 | 10/11/2026 | Highest | FV-12, FV-07 |
| FV-14 (SCRUM-208) | fn_IsTempInRange và trigger trg_Machines_StatusChange (ghi lịch sử đổi trạng thái máy) | 11/11/2026 | 12/11/2026 | Medium | FV-13 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-12 (SCRUM-206) – Đưa nhánh tv4-iot lên main, gộp file theo QĐ-3, sửa lệch gói telemetry (machineId/serial)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 06/11/2026 → 08/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E4 – IoT & Chuỗi lạnh (iot) |
| Phụ thuộc | FV-01 (SCRUM-195) (Huy) |
| Người hỗ trợ | Huy |

### 1. MỤC TIÊU
Đưa nhánh tv4-iot lên main, gộp file theo QĐ-3, sửa lệch gói telemetry (machineId/serial). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Nhánh `tv4-iot` có 3 commit chưa merge (01/11): `04_functions_iot.sql` (fn_RecentTelemetry), `05_views_iot.sql` (vw_MachineHealth, vw_OpenAlerts), ảnh Component/Deployment diagram. **Lỗi nghiêm trọng:** API gửi gói `{ machineId, readings }` (`app/api/src/routes/iot.js` dòng 14–23, simulator dòng 82) nhưng `iot.sp_IngestTelemetry` (dòng 79–85 của `07_procs_iot.sql`) lại đọc `$.serial` → khi chạy SQL thật mọi gói đều lỗi 50311 *Không tìm thấy máy*.

### 3. PHẠM VI CÔNG VIỆC
- Merge `origin/main` vào `tv4-iot`.
- Đổi tên `07_procs_iot.sql` → `13_procs_iot.sql`; gộp `04_functions_iot.sql` + `05_views_iot.sql` → `23_objects_iot.sql` (QĐ-3).
- Sửa `sp_IngestTelemetry`: đọc `$.machineId`, nếu không có thì đọc `$.serial`.
- Mở PR, nhờ Leader review.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Cập nhật nhánh**
```powershell
git checkout tv4-iot
git pull origin tv4-iot
git fetch origin
git merge origin/main
```

**Bước 2. Đổi tên file bằng git mv (giữ lịch sử)**
```powershell
git mv sql/07_procs_iot.sql sql/13_procs_iot.sql
```
Tạo `sql/23_objects_iot.sql`: dán nội dung `04_functions_iot.sql` rồi `05_views_iot.sql`; sau đó `git rm sql/04_functions_iot.sql sql/05_views_iot.sql`.

**Bước 3. Sửa sp_IngestTelemetry**
- **Mở file:** `sql/13_procs_iot.sql`, chỗ `DECLARE @Serial ...`:
```sql
DECLARE @MachineId INT = TRY_CAST(JSON_VALUE(@Payload, '$.machineId') AS INT);
IF @MachineId IS NULL
  SELECT @MachineId = MachineId FROM iot.Machines WHERE Serial = JSON_VALUE(@Payload, '$.serial');
IF @MachineId IS NULL OR NOT EXISTS (SELECT 1 FROM iot.Machines WHERE MachineId = @MachineId)
  THROW 50311, N'Không tìm thấy máy tương ứng với thiết bị gửi dữ liệu.', 1;
```
- **Lưu ý:** procedure đang `BEGIN TRANSACTION` trước kiểm tra JSON → thêm `SET XACT_ABORT ON` để THROW tự rollback.

**Bước 4. Kiểm tra trả về**
API đọc `r1.recordset[0]` và simulator in `r.Status` → procedure phải `SELECT ... AS Status` (trạng thái máy sau khi xử lý). So với fakeDb.js dòng 336–420.

**Bước 5. Chạy thử**
```sql
EXEC iot.sp_IngestTelemetry @Payload = N'{"machineId":1,"readings":[{"temp":4.5,"hum":80,"door":0}]}';
SELECT TOP 5 * FROM iot.Telemetry ORDER BY ReadingId DESC;
```

### Hướng dẫn thực hành IoT (12 mục bắt buộc)

1. **Mục đích:** Bảo đảm gói dữ liệu cảm biến mà bộ điều khiển máy (mô phỏng) gửi lên được CSDL nhận đúng.
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
7. **Lệnh / code sử dụng:** Như mục 4 bước 5; sau đó (khi đã có FV-22) chạy `npm start` + `npm run simulator` và xem bảng iot.Telemetry tăng mỗi 5 giây.
8. **Cách kiểm tra thiết bị (mô phỏng) đã hoạt động:**
`SELECT COUNT(*) FROM iot.Telemetry WHERE RecordedAt > DATEADD(MINUTE,-1,SYSDATETIME());` ≈ 12 × số máy mỗi phút.
9. **Dữ liệu đầu ra mong đợi:** Mỗi gói → 1 dòng `iot.Telemetry` (MachineId, RecordedAt, Temperature, Humidity, DoorOpen) + `iot.Machines.LastHeartbeat` cập nhật.
10. **Lỗi thường gặp và cách xử lý:**
- 50311: gói thiếu machineId/serial hoặc máy chưa đăng ký → kiểm tra `SELECT * FROM iot.Machines`.
- 50310: JSON hỏng → in payload ra console.
- 401 ở API: sai `DEVICE_API_KEY`.
11. **Kết nối với hệ thống hiện tại:** API `POST /api/iot/telemetry` → `iot.sp_IngestTelemetry` (login `fv_device_app`).
12. **Tiêu chí nghiệm thu:**
- [ ] sp_IngestTelemetry nhận gói đúng định dạng API gửi
- [ ] File đặt tên theo QĐ-3
- [ ] PR merge, CI xanh

> **Dữ liệu mô phỏng:** Mọi số liệu nhiệt độ/độ ẩm/cửa trong dự án là **dữ liệu mô phỏng**. Tài liệu, slide, Test Report phải ghi rõ *“dữ liệu mô phỏng bằng esp32.js”*; không được ghi *“đã kiểm thử trên phần cứng thật”*.
>
> **Thao tác thủ công:** người thực hiện **Trương Tuấn Dũng**, trên laptop cá nhân (Windows) có SQL Server + Node.js; chuẩn bị theo mục 2–4; bằng chứng: ảnh terminal simulator + ảnh trang web + kết quả truy vấn SQL, lưu vào Google Drive nhóm thư mục `FreshVend/BangChung/FV-12`; người khác tái hiện bằng cách chạy đúng các lệnh ở mục 4 trên CSDL tạo bằng `99_run_all.bat`.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/07_procs_iot.sql → sql/13_procs_iot.sql`
- `sql/04_functions_iot.sql + sql/05_views_iot.sql → sql/23_objects_iot.sql`
- `app/api/src/routes/iot.js dòng 14–23`
- `app/simulator/esp32.js dòng 75–95`
- `app/api/test/fakeDb.js dòng 336–420`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu ra cho:** Huy (FV-05 review), Toàn (FV-22 GRANT view iot), Anh (FV-16 thứ tự file).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Gói theo machineId | Payload {machineId:1, readings:[...]} | Chèn 1 dòng Telemetry, trả Status |
| 2 | Gói theo serial | {serial:'FV-HCM-001', ...} | Vẫn chèn được |
| 3 | JSON hỏng | N'abc' | THROW 50310 |
| 4 | Máy không tồn tại | machineId 999 | THROW 50311 |

**Kết quả cần lưu lại:** Ảnh 4 test SSMS.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] sp_IngestTelemetry nhận gói đúng định dạng API gửi
- [ ] File đặt tên theo QĐ-3
- [ ] PR merge, CI xanh

### 9. GITHUB WORKFLOW
Task dùng **nhánh có sẵn `tv4-iot`** (không tạo nhánh mới).
1. **Kiểm tra nhánh hiện tại**
```powershell
git status
git branch
```
2. **Chuyển sang nhánh và đồng bộ với main**
```powershell
git checkout tv4-iot
git pull origin tv4-iot
git fetch origin
git merge origin/main
```
Nếu báo `CONFLICT` → xem `Cach_su_dung_GITHUB.md` mục 7.
3. **Commit**
```powershell
git add sql/13_procs_iot.sql sql/23_objects_iot.sql
git commit -m "fix(sql-iot): sp_IngestTelemetry nhận machineId; gộp 23_objects_iot"
```
4. **Push**
```powershell
git push origin tv4-iot
```
5. **Tạo Pull Request** `base: main` ← `compare: tv4-iot`, tiêu đề `[SCRUM-206] Đưa nhánh tv4-iot lên main, gộp file theo QĐ-3, sửa lệch gói telemetry (machineId/serial)`, nội dung theo mẫu ở `Cach_su_dung_GITHUB.md` mục 5, mục *Related Jira Task* ghi `SCRUM-206`.
6. **Kiểm tra conflict:** GitHub hiện *This branch has no conflicts with the base branch*. Nếu có conflict → làm lại bước 2.
7. **Nhờ Leader review:** Reviewers → PhuongHuyN; nhắn nhóm chat kèm link PR.
8. **Merge** khi được Approve (Leader bấm *Squash and merge*). Sau đó:
```powershell
git checkout main
git pull origin main
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-206 |
| Branch | `tv4-iot (nhánh hiện có – giữ tên)` |
| Commit | `fix(sql-iot): sp_IngestTelemetry nhận machineId; gộp 23_objects_iot` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/13_procs_iot.sql
- sql/23_objects_iot.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 08/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-206
- **Bằng chứng hoàn thành:** Ảnh 4 test SSMS
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-13 (SCRUM-207) – Hợp nhất bảng máy và địa điểm theo QĐ-1 (iot.Machines, iot.Locations) + view tương thích inventory.Machine

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 09/11/2026 → 10/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E4 – IoT & Chuỗi lạnh (iot) |
| Phụ thuộc | FV-12 (SCRUM-206) (Dũng), FV-07 (SCRUM-201) (Toàn) |
| Người hỗ trợ | Huy, Toàn, Ân, Anh |

### 1. MỤC TIÊU
Hợp nhất bảng máy và địa điểm theo QĐ-1 (iot.Machines, iot.Locations) + view tương thích inventory.Machine. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Hiện có 2 bảng máy: `inventory.Machine` (TV3, TV5 và seed dùng) và `iot.Machines` (TV4 dùng, có Serial, LocationId, Status, LastHeartbeat – khớp API). Hai bảng không đồng bộ → máy đăng ký ở trang *Máy* không xuất hiện ở *Châm hàng*. QĐ-1 (đề xuất): `iot.Machines` là bảng duy nhất, `inventory.Machine` trở thành **view** cùng tên cột cũ để code TV3/TV5 không phải sửa.

### 3. PHẠM VI CÔNG VIỆC
- Sau khi Toàn đổi FK sang `iot.Machines` (FV-07) và Huy bỏ FK nội schema (FV-02): xóa **bảng** `inventory.Machine`.
- Tạo **view** `inventory.Machine` (MachineId, MachineCode, MachineName, Location, Status, IsActive...) đọc từ `iot.Machines` + `iot.Locations`.
- Thống nhất `iot.Locations` thay cho `inventory.Location(s)` mà nhánh TV5 tạo – báo Anh (FV-15).
- Cập nhật seed nếu đang INSERT vào `inventory.Machine` → chuyển sang `iot.sp_RegisterMachine`.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Liệt kê nơi dùng**
```powershell
Select-String -Path sql\*.sql, tests\*.sql -Pattern 'inventory\.Machine\b' | Select-Object Path, LineNumber
```
Gửi danh sách vào nhóm chat: ai sở hữu file nào.

**Bước 2. View tương thích**
- **Mở file:** `sql/02_tables_iot.sql`, cuối file:
```sql
IF OBJECT_ID(N'inventory.Machine', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE referenced_object_id = OBJECT_ID(N'inventory.Machine'))
  DROP TABLE inventory.Machine;
GO
CREATE OR ALTER VIEW inventory.Machine AS
SELECT m.MachineId, m.Serial AS MachineCode, m.MachineName, l.LocationName AS Location,
       m.Status, CAST(CASE WHEN m.Status <> 'OFFLINE' THEN 1 ELSE 0 END AS BIT) AS IsActive, m.LocationId
FROM iot.Machines m LEFT JOIN iot.Locations l ON l.LocationId = m.LocationId;
GO
```
- **Lưu ý:** INSERT vào view sẽ lỗi → seed phải chèn qua `iot.Machines`.

**Bước 3. Kiểm tra toàn bộ**
CSDL trống → chạy toàn bộ theo thứ tự → `SELECT * FROM inventory.Machine` ra đủ máy; `EXEC report.sp_DashboardKpi` không lỗi.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/02_tables_iot.sql`
- `sql/02_tables_inventory.sql` (Huy)
- `sql/03_foreign_keys.sql` (Toàn)
- `sql/12_procs_sales.sql` (Ân, chỉ đọc)
- `sql/14_procs_report.sql, seed` (Anh)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Phải làm cùng lúc với:** Toàn (FV-07 FK), Huy (FV-02). Thứ tự merge: FV-02 → FV-07 → FV-13. **Báo cho:** Anh đổi `inventory.Location(s)` → `iot.Locations` trong FV-15.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | View | SELECT * FROM inventory.Machine | Đủ máy, MachineCode = Serial |
| 2 | Đăng ký máy mới | EXEC iot.sp_RegisterMachine ... | Máy mới thấy ngay trong inventory.Machine |
| 3 | Báo cáo | EXEC report.sp_DashboardKpi | Không lỗi |

**Kết quả cần lưu lại:** Ảnh 3 test.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Chỉ còn 1 bảng máy
- [ ] Code TV3/TV5 chạy không cần sửa (hoặc đã sửa)
- [ ] Chạy từ đầu không lỗi
- [ ] PR merge

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b refactor/SCRUM-207-machine-table
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/02_tables_iot.sql
git commit -m "refactor(sql-iot): iot.Machines là bảng máy duy nhất + view tương thích inventory.Machine"
```
5. **Push**
```powershell
git pull origin main
git push -u origin refactor/SCRUM-207-machine-table
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: refactor/SCRUM-207-machine-table`.
7. **Mô tả PR:** tiêu đề `[SCRUM-207] Hợp nhất bảng máy và địa điểm theo QĐ-1 (iot.Machines, iot.Locations) + view tương thích inventory.Machine`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-207`; dán ảnh bằng chứng: Ảnh 3 test.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d refactor/SCRUM-207-machine-table
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-207 |
| Branch | `refactor/SCRUM-207-machine-table` |
| Commit | `refactor(sql-iot): iot.Machines là bảng máy duy nhất + view tương thích inventory.Machine` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/02_tables_iot.sql (view tương thích)

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 10/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-207
- **Bằng chứng hoàn thành:** Ảnh 3 test
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-14 (SCRUM-208) – fn_IsTempInRange và trigger trg_Machines_StatusChange (ghi lịch sử đổi trạng thái máy)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 11/11/2026 → 12/11/2026 |
| Mức ưu tiên | Medium |
| Epic | E4 – IoT & Chuỗi lạnh (iot) |
| Phụ thuộc | FV-13 (SCRUM-207) (Dũng) |
| Người hỗ trợ | Toàn |

### 1. MỤC TIÊU
fn_IsTempInRange và trigger trg_Machines_StatusChange (ghi lịch sử đổi trạng thái máy). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Kế hoạch giao TV4 2 function/trigger. Khi máy chuyển ACTIVE → DEGRADED/FAULT/OFFLINE cần ghi vết để Admin truy lại sự cố (đề: audit trail).

### 3. PHẠM VI CÔNG VIỆC
- `iot.fn_IsTempInRange(@MachineId, @Temp)` trả BIT theo `iot.MachineThresholds`.
- `iot.trg_Machines_StatusChange` AFTER UPDATE: khi Status đổi → chèn `audit.ChangeLog` (mẫu FOR JSON của Toàn) và, nếu sang FAULT/OFFLINE, chèn `iot.Alerts`.
- Đặt trong `sql/23_objects_iot.sql`.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Function**
```sql
CREATE OR ALTER FUNCTION iot.fn_IsTempInRange (@MachineId INT, @Temp DECIMAL(5,2))
RETURNS BIT AS
BEGIN
  RETURN (SELECT CASE WHEN @Temp BETWEEN MinTemp AND MaxTemp THEN 1 ELSE 0 END
          FROM iot.MachineThresholds WHERE MachineId = @MachineId);
END
```

**Bước 2. Trigger nhiều dòng**
Dùng `inserted i JOIN deleted d ON d.MachineId = i.MachineId WHERE i.Status <> d.Status` – không dùng biến vô hướng.

**Bước 3. Thử**
`UPDATE iot.Machines SET Status = 'FAULT' WHERE MachineId IN (1,2);` → 2 dòng ChangeLog, 2 Alert.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/23_objects_iot.sql`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
Dùng bảng `audit.ChangeLog` của Toàn (FV-06).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Trong ngưỡng | fn_IsTempInRange(1, 4.5) | 1 |
| 2 | Ngoài ngưỡng | fn_IsTempInRange(1, 9) | 0 |
| 3 | Trigger 2 dòng | UPDATE 2 máy | 2 dòng ChangeLog |

**Kết quả cần lưu lại:** Ảnh 3 test.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 3 test đúng
- [ ] PR merge

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b feature/SCRUM-208-iot-function-trigger
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/23_objects_iot.sql
git commit -m "feat(sql-iot): fn_IsTempInRange, trg_Machines_StatusChange"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-208-iot-function-trigger
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-208-iot-function-trigger`.
7. **Mô tả PR:** tiêu đề `[SCRUM-208] fn_IsTempInRange và trigger trg_Machines_StatusChange (ghi lịch sử đổi trạng thái máy)`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-208`; dán ảnh bằng chứng: Ảnh 3 test.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-208-iot-function-trigger
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-208 |
| Branch | `feature/SCRUM-208-iot-function-trigger` |
| Commit | `feat(sql-iot): fn_IsTempInRange, trg_Machines_StatusChange` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/23_objects_iot.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 12/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-208
- **Bằng chứng hoàn thành:** Ảnh 3 test
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
