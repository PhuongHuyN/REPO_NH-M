# Dũng – Tuần 2: Sprint 2 – Đủ object & nối app với SQL Server thật

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Trương Tuấn Dũng
- **Email:** dungtuanxz12345@gmail.com
- **Tuần:** 2 (Sprint 2 – Đủ object & nối app với SQL Server thật)
- **Thời gian:** 13/11/2026 → 19/11/2026
- **Vai trò:** TV4 – IoT & Chuỗi lạnh (schema iot), mô phỏng ESP32, SQL Agent Job, kiến trúc
- **Mức độ ưu tiên:** Highest
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-221, SCRUM-222, SCRUM-223

**Mục tiêu Sprint:** Đủ view/function/trigger/phần khó của 5 module; phân quyền 4 login; app chạy DB_MODE=sqlserver qua trọn kịch bản châm hàng → mua → nhả hàng → cảnh báo → báo cáo.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-27 (SCRUM-221) | Partition bảng iot.Telemetry theo tháng + sp_MaintainPartitions | 13/11/2026 | 15/11/2026 | High | FV-13 |
| FV-28 (SCRUM-222) | 45_jobs.sql: 3 SQL Agent Job (mỗi phút, mỗi giờ, mỗi tháng) + phương án cho SQL Express | 16/11/2026 | 17/11/2026 | High | FV-27, FV-04 |
| FV-29 (SCRUM-223) | Mô phỏng ESP32 end-to-end với CSDL thật: 5 kịch bản (bình thường, quá nhiệt, mở cửa, kẹt hàng, mất mạng) | 18/11/2026 | 19/11/2026 | Highest | FV-12, FV-22, FV-28, FV-10 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-27 (SCRUM-221) – Partition bảng iot.Telemetry theo tháng + sp_MaintainPartitions

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 13/11/2026 → 15/11/2026 |
| Mức ưu tiên | High |
| Epic | E4 – IoT & Chuỗi lạnh (iot) |
| Phụ thuộc | FV-13 (SCRUM-207) (Dũng) |
| Người hỗ trợ | Anh |

### 1. MỤC TIÊU
Partition bảng iot.Telemetry theo tháng + sp_MaintainPartitions. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Phần khó TV4. Đề: 1.000 máy × gửi 5 giây/lần → bảng Telemetry rất lớn. Partition theo tháng giúp xóa dữ liệu cũ nhanh (SWITCH/TRUNCATE partition) và truy vấn theo khoảng thời gian chỉ đọc partition cần. `app/api/src/jobs.js` đã nhắc `iot.sp_MaintainPartitions` nhưng procedure chưa có. Hiện `iot.Telemetry` có PK `ReadingId` – muốn partition theo `RecordedAt` thì khóa chính phải chứa `RecordedAt`.

### 3. PHẠM VI CÔNG VIỆC
- `PF_iot_Telemetry_Month` (RANGE RIGHT theo ngày đầu tháng, 12 tháng gần nhất + 3 tháng tới), `PS_iot_Telemetry_Month` (ALL TO [PRIMARY]).
- Tạo lại `iot.Telemetry` trên partition scheme với PK `(ReadingId, RecordedAt)`; `RecordedAt NOT NULL`.
- `iot.sp_MaintainPartitions`: SPLIT thêm tháng mới, MERGE tháng cũ hơn 12 tháng.
- Test TC-11 của Anh (`$PARTITION.PF_iot_Telemetry_Month`) phải PASS thật.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Partition function/scheme**
```sql
IF NOT EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = N'PF_iot_Telemetry_Month')
  CREATE PARTITION FUNCTION PF_iot_Telemetry_Month (DATETIME2(0)) AS RANGE RIGHT FOR VALUES
  ('2026-01-01','2026-02-01','2026-03-01','2026-04-01','2026-05-01','2026-06-01','2026-07-01','2026-08-01',
   '2026-09-01','2026-10-01','2026-11-01','2026-12-01','2027-01-01','2027-02-01');
IF NOT EXISTS (SELECT 1 FROM sys.partition_schemes WHERE name = N'PS_iot_Telemetry_Month')
  CREATE PARTITION SCHEME PS_iot_Telemetry_Month AS PARTITION PF_iot_Telemetry_Month ALL TO ([PRIMARY]);
```
- SQL Server 2016 SP1 trở lên hỗ trợ partition ở **mọi** bản (cả Express).

**Bước 2. Tạo lại bảng**
Trong `02_tables_iot.sql`: `CREATE TABLE iot.Telemetry (... CONSTRAINT PK_iot_Telemetry PRIMARY KEY (ReadingId, RecordedAt)) ON PS_iot_Telemetry_Month(RecordedAt);`. Nếu bảng cũ đã có dữ liệu trên máy: đổi tên bảng cũ, tạo mới, `INSERT ... SELECT`, xóa bảng cũ.

**Bước 3. Kiểm tra**
```sql
SELECT $PARTITION.PF_iot_Telemetry_Month(RecordedAt) AS P, COUNT(*) FROM iot.Telemetry GROUP BY $PARTITION.PF_iot_Telemetry_Month(RecordedAt);
SELECT partition_number, rows FROM sys.partitions WHERE object_id = OBJECT_ID(N'iot.Telemetry') AND index_id = 1;
```

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/02_tables_iot.sql`
- `sql/13_procs_iot.sql` (sp_MaintainPartitions)
- `app/api/src/jobs.js` (dòng nhắc sp_MaintainPartitions)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu ra cho:** Anh (FV-31 đo truy vấn theo tháng trước/sau partition, TC-11).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Dữ liệu vào đúng tháng | Chèn 3 dòng 3 tháng khác nhau | 3 partition khác nhau |
| 2 | Maintain | EXEC iot.sp_MaintainPartitions | Có thêm biên tháng mới |
| 3 | TC-11 | EXEC report.sp_RunAllTests | TC-11 PASS thật |

**Kết quả cần lưu lại:** Ảnh sys.partitions.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Telemetry nằm trên partition scheme
- [ ] Procedure bảo trì chạy được
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
git checkout -b feature/SCRUM-221-telemetry-partition
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/02_tables_iot.sql
git commit -m "feat(sql-iot): partition Telemetry theo tháng"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-221-telemetry-partition
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-221-telemetry-partition`.
7. **Mô tả PR:** tiêu đề `[SCRUM-221] Partition bảng iot.Telemetry theo tháng + sp_MaintainPartitions`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-221`; dán ảnh bằng chứng: Ảnh sys.partitions.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-221-telemetry-partition
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-221 |
| Branch | `feature/SCRUM-221-telemetry-partition` |
| Commit | `feat(sql-iot): partition Telemetry theo tháng` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/02_tables_iot.sql
- sql/13_procs_iot.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 15/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-221
- **Bằng chứng hoàn thành:** Ảnh sys.partitions
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-28 (SCRUM-222) – 45_jobs.sql: 3 SQL Agent Job (mỗi phút, mỗi giờ, mỗi tháng) + phương án cho SQL Express

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 16/11/2026 → 17/11/2026 |
| Mức ưu tiên | High |
| Epic | E4 – IoT & Chuỗi lạnh (iot) |
| Phụ thuộc | FV-27 (SCRUM-221) (Dũng), FV-04 (SCRUM-198) (Huy) |
| Người hỗ trợ | Huy |

### 1. MỤC TIÊU
45_jobs.sql: 3 SQL Agent Job (mỗi phút, mỗi giờ, mỗi tháng) + phương án cho SQL Express. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Hệ thống cần chạy định kỳ: đánh dấu máy OFFLINE, hủy đơn quá hạn (mỗi phút); gom số liệu giờ, rút hàng hết hạn, làm mới báo cáo (mỗi giờ); bảo trì partition (mỗi tháng). Danh sách procedure đúng như `app/api/src/jobs.js`. **SQL Server Express không có SQL Agent** → app có chế độ dự phòng `JOBS_FALLBACK=true`.

### 3. PHẠM VI CÔNG VIỆC
- `sql/45_jobs.sql` dùng `msdb.dbo.sp_add_job`, `sp_add_jobstep`, `sp_add_schedule`, `sp_attach_schedule`, `sp_add_jobserver`.
- Job FV_Minute: `iot.sp_CheckHeartbeat @Minutes=5`, `sales.sp_ExpirePendingOrders`.
- Job FV_Hourly: `iot.sp_AggregateHourly`, `inventory.sp_RemoveExpired`, `report.sp_RefreshDailySummary`.
- Job FV_Monthly: `iot.sp_MaintainPartitions`.
- Đầu file: nếu không có Agent (`SERVERPROPERTY('EngineEdition') = 4` là Express) thì PRINT hướng dẫn bật `JOBS_FALLBACK=true` và dừng.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Kiểm tra bản SQL Server**
`SELECT SERVERPROPERTY('Edition'), SERVERPROPERTY('EngineEdition');` – 4 là Express.

**Bước 2. Mẫu tạo job**
```sql
USE msdb;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'FV_Minute')
BEGIN
  EXEC dbo.sp_add_job @job_name = N'FV_Minute';
  EXEC dbo.sp_add_jobstep @job_name = N'FV_Minute', @step_name = N'heartbeat+expire', @subsystem = N'TSQL',
       @database_name = N'FreshVendDB', @command = N'EXEC iot.sp_CheckHeartbeat @Minutes = 5; EXEC sales.sp_ExpirePendingOrders;';
  EXEC dbo.sp_add_schedule @schedule_name = N'FV_every_minute', @freq_type = 4, @freq_interval = 1, @freq_subday_type = 4, @freq_subday_interval = 1;
  EXEC dbo.sp_attach_schedule @job_name = N'FV_Minute', @schedule_name = N'FV_every_minute';
  EXEC dbo.sp_add_jobserver @job_name = N'FV_Minute';
END
```

**Bước 3. Kiểm tra chạy**
SSMS → *SQL Server Agent* (phải Start) → *Jobs* → chuột phải FV_Minute → *View History*. Với Express: đặt `JOBS_FALLBACK=true` trong `.env` → terminal in `[job minute] ...` mỗi phút.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/45_jobs.sql` (mới)
- `app/api/src/jobs.js` (đối chiếu)
- `app/api/.env.example` (JOBS_FALLBACK)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** procedure của Huy (sp_RemoveExpired), Ân (sp_ExpirePendingOrders), Anh (sp_RefreshDailySummary).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Developer | Chạy 45_jobs, đợi 2 phút | History có 2 lần Succeeded |
| 2 | Express | Chạy 45_jobs | In hướng dẫn fallback, không lỗi |
| 3 | Offline | Dừng simulator máy 4 > 5 phút | Máy 4 OFFLINE |

**Kết quả cần lưu lại:** Ảnh Job History hoặc log fallback.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 3 job tạo được (Developer) hoặc fallback chạy (Express)
- [ ] Chạy lại file không tạo trùng job
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
git checkout -b feature/SCRUM-222-agent-jobs
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/45_jobs.sql
git commit -m "feat(sql-iot): 45_jobs SQL Agent (minute/hour/month)"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-222-agent-jobs
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-222-agent-jobs`.
7. **Mô tả PR:** tiêu đề `[SCRUM-222] 45_jobs.sql: 3 SQL Agent Job (mỗi phút, mỗi giờ, mỗi tháng) + phương án cho SQL Express`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-222`; dán ảnh bằng chứng: Ảnh Job History hoặc log fallback.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-222-agent-jobs
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-222 |
| Branch | `feature/SCRUM-222-agent-jobs` |
| Commit | `feat(sql-iot): 45_jobs SQL Agent (minute/hour/month)` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/45_jobs.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 17/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-222
- **Bằng chứng hoàn thành:** Ảnh Job History hoặc log fallback
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-29 (SCRUM-223) – Mô phỏng ESP32 end-to-end với CSDL thật: 5 kịch bản (bình thường, quá nhiệt, mở cửa, kẹt hàng, mất mạng)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 18/11/2026 → 19/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E4 – IoT & Chuỗi lạnh (iot) |
| Phụ thuộc | FV-12 (SCRUM-206) (Dũng), FV-22 (SCRUM-216) (Toàn), FV-28 (SCRUM-222) (Dũng), FV-10 (SCRUM-204) (Ân) |
| Người hỗ trợ | Ân, Huy |

### 1. MỤC TIÊU
Mô phỏng ESP32 end-to-end với CSDL thật: 5 kịch bản (bình thường, quá nhiệt, mở cửa, kẹt hàng, mất mạng). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Đây là bằng chứng chính cho trụ cột IoT & chuỗi lạnh của đề. Nhóm không có phần cứng → dùng `app/simulator/esp32.js` gửi dữ liệu **mô phỏng** qua đúng giao thức mà ESP32 thật sẽ dùng (HTTP + JSON + header khóa thiết bị). Tất cả bằng chứng phải ghi rõ là mô phỏng.

### 3. PHẠM VI CÔNG VIỆC
- Chạy 5 kịch bản trên app `DB_MODE=sqlserver`.
- Mỗi kịch bản: lệnh, thời gian chờ, kết quả trên web, kết quả trong SQL, ảnh/video.
- Ghi kết quả vào `docs/KichBan_IoT_MoPhong.md`; Anh trích vào Test Report (FV-45).

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Chuẩn bị**
Terminal 1: `cd app` → `npm start` (DB_MODE=sqlserver). Terminal 2: `cd app` → các lệnh simulator bên dưới. Trình duyệt: http://localhost:3000 (admin) và /kiosk.

**Bước 2. KB1 – Bình thường**
`node simulator/esp32.js` → 1 phút sau: trang *Máy & chuỗi lạnh* hiện 5 máy, nhiệt độ 3–6°C, trạng thái ACTIVE.

**Bước 3. KB2 – Quá nhiệt**
`node simulator/esp32.js --overheat 3 --interval 2` → sau ~3 lần đo > 8°C: cảnh báo `TEMP_HIGH`, máy 3 `DEGRADED`, kiosk máy 3 hiện thông báo *Tạm ngưng*.

**Bước 4. KB3 – Mở cửa**
`node simulator/esp32.js --door 2` → sau 2 phút: cảnh báo `DOOR_OPEN`.

**Bước 5. KB4 – Kẹt hàng**
`node simulator/esp32.js --jam 1` + mua 1 đơn ở kiosk máy 1 → 3 lần JAM → đơn `REFUNDED`, máy 1 `FAULT`. Operator bấm *Xóa lỗi* ở trang Máy → máy về ACTIVE.

**Bước 6. KB5 – Mất mạng**
`node simulator/esp32.js --offline 4` → sau 5 phút (job mỗi phút) máy 4 `OFFLINE`. Tắt cờ → máy gửi bù dữ liệu đệm (có trường `t`) → về ACTIVE.

### Hướng dẫn thực hành IoT (12 mục bắt buộc)

1. **Mục đích:** Chứng minh luồng IoT: cảm biến → API → SQL → cảnh báo → giao diện, và luồng nhả hàng ngược lại, chạy đúng với CSDL thật.
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
7. **Lệnh / code sử dụng:** Như mục 4 (KB1–KB5).
8. **Cách kiểm tra thiết bị (mô phỏng) đã hoạt động:**
- Terminal simulator in `máy 3 | 🌡 9.8°C -> trạng thái DEGRADED`.
- `SELECT TOP 20 * FROM iot.Alerts ORDER BY AlertId DESC;`
- `SELECT MachineId, Status, LastHeartbeat FROM iot.Machines;`
9. **Dữ liệu đầu ra mong đợi:** Bảng `iot.Telemetry` tăng ~12 dòng/phút/máy; `iot.Alerts` có TEMP_HIGH, DOOR_OPEN, DISPENSE_JAM, OFFLINE; đơn kẹt chuyển REFUNDED.
10. **Lỗi thường gặp và cách xử lý:**
- `Thiếu DEVICE_API_KEY`: chưa có `app/api/.env` → copy từ `.env.example`.
- `fetch failed`/`ECONNREFUSED`: API chưa chạy hoặc sai cổng.
- 401: khóa thiết bị khác giữa simulator và API.
- 403/229: login `fv_device_app` thiếu GRANT → báo Toàn.
- Máy không nhả hàng: `sales.vw_DispenseQueue` trống → kiểm tra đơn đã PAID chưa.
11. **Kết nối với hệ thống hiện tại:** `POST /api/iot/telemetry`, `GET /api/dispense-queue`, `POST /api/orders/items/:id/dispense` → login `fv_device_app`.
12. **Tiêu chí nghiệm thu:**
- [ ] 5/5 kịch bản đạt trên SQL thật
- [ ] Mỗi kịch bản có ảnh/video
- [ ] Mọi bằng chứng ghi 'dữ liệu mô phỏng'

> **Dữ liệu mô phỏng:** Mọi số liệu nhiệt độ/độ ẩm/cửa trong dự án là **dữ liệu mô phỏng**. Tài liệu, slide, Test Report phải ghi rõ *“dữ liệu mô phỏng bằng esp32.js”*; không được ghi *“đã kiểm thử trên phần cứng thật”*.
>
> **Thao tác thủ công:** người thực hiện **Trương Tuấn Dũng**, trên laptop cá nhân (Windows) có SQL Server + Node.js; chuẩn bị theo mục 2–4; bằng chứng: ảnh terminal simulator + ảnh trang web + kết quả truy vấn SQL, lưu vào Google Drive nhóm thư mục `FreshVend/BangChung/FV-29`; người khác tái hiện bằng cách chạy đúng các lệnh ở mục 4 trên CSDL tạo bằng `99_run_all.bat`.

### 5. FILE VÀ MODULE LIÊN QUAN
- `docs/KichBan_IoT_MoPhong.md` (mới – 5 kịch bản, lệnh, kết quả, ảnh)
- `app/simulator/esp32.js` (chỉ đọc)
- `app/api/.env` (không commit)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** Toàn (login fv_device_app), Ân (vw_DispenseQueue), job của bạn (FV-28). **Đầu ra cho:** Anh (FV-45), Huy (FV-35 tổng duyệt).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | KB1 | simulator mặc định | 5 máy ACTIVE |
| 2 | KB2 | --overheat 3 | TEMP_HIGH, DEGRADED, kiosk Tạm ngưng |
| 3 | KB3 | --door 2 | DOOR_OPEN |
| 4 | KB4 | --jam 1 + mua | REFUNDED, FAULT |
| 5 | KB5 | --offline 4 | OFFLINE sau 5 phút, gửi bù khi có mạng |

**Kết quả cần lưu lại:** Thư mục ảnh/video trên Drive + bảng kết quả gửi Anh.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 5/5 kịch bản đạt trên SQL thật
- [ ] Mỗi kịch bản có ảnh/video
- [ ] Mọi bằng chứng ghi 'dữ liệu mô phỏng'

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b test/SCRUM-223-iot-simulator-e2e
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add docs/KichBan_IoT_MoPhong.md
git commit -m "test(iot): kịch bản mô phỏng ESP32 với SQL Server thật"
```
5. **Push**
```powershell
git pull origin main
git push -u origin test/SCRUM-223-iot-simulator-e2e
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: test/SCRUM-223-iot-simulator-e2e`.
7. **Mô tả PR:** tiêu đề `[SCRUM-223] Mô phỏng ESP32 end-to-end với CSDL thật: 5 kịch bản (bình thường, quá nhiệt, mở cửa, kẹt hàng, mất mạng)`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-223`; dán ảnh bằng chứng: Thư mục ảnh/video trên Drive + bảng kết quả gửi Anh.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d test/SCRUM-223-iot-simulator-e2e
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-223 |
| Branch | `test/SCRUM-223-iot-simulator-e2e` |
| Commit | `test(iot): kịch bản mô phỏng ESP32 với SQL Server thật` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- docs/KichBan_IoT_MoPhong.md
- Ảnh/video trên Drive

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 19/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-223
- **Bằng chứng hoàn thành:** Thư mục ảnh/video trên Drive + bảng kết quả gửi Anh
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
