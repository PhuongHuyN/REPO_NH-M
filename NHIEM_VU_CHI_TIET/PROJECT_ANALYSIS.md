# PROJECT_ANALYSIS – Phân tích hiện trạng FreshVend

> Ngày phân tích: **05/11/2026**. Nguồn: repo `PhuongHuyN/REPO_NH-M` – nhánh `main` tại commit `5f75b9e` (merge PR #13) và 3 nhánh chưa merge `tv3-sales`, `tv4-iot`, `check-nv-chua-hoan-thien-xa`. Mọi nhận định dưới đây có kèm bằng chứng (đường dẫn file, dòng, lệnh đã chạy). Phần nào chưa có bằng chứng thì ghi **chưa xác minh**.

## 1. Tổng quan kiến trúc

```
 Trình duyệt                        Máy chủ ứng dụng (Node.js)                     SQL Server (FreshVendDB)
┌──────────────────────┐   HTTPS   ┌───────────────────────────────┐   mssql   ┌────────────────────────────────┐
│ web/admin.html       │──JWT────▶│ api/src/app.js (router tự viết)│──4 login──▶│ 6 schema: auth, audit,          │
│  (9 trang quản trị)  │◀──SSE────│ routes/auth|inventory|sales|   │  EXEC SP   │  inventory, sales, iot, report  │
│ web/kiosk.html       │          │        iot|report.js           │  SELECT VIEW│ Stored procedure / view / TVF  │
└──────────────────────┘          │ jobs.js (lịch dự phòng)        │            │ SQL Agent Job (45_jobs – chưa có)│
                                  └───────────────▲───────────────┘            └────────────────────────────────┘
 Bộ điều khiển máy (MÔ PHỎNG)                     │ X-Device-Key
┌────────────────────────────┐   HTTP JSON        │
│ simulator/esp32.js         │────────────────────┘  POST /api/iot/telemetry, GET /api/dispense-queue,
│ (giả lập DHT22 + servo)    │                       POST /api/orders/items/:id/dispense
└────────────────────────────┘
```

- **Nguyên tắc chính:** API **không viết câu SQL** – ghi dữ liệu chỉ qua `ctx.exec('<schema>.sp_...')`, đọc chỉ qua `ctx.view(...)`/`ctx.tvf(...)` (bằng chứng: `app/api/src/db.js`, `app/CONTRIBUTING.md`).
- **Hai chế độ:** `DB_MODE=demo` dùng CSDL giả lập trong bộ nhớ `app/api/test/fakeDb.js` (mô phỏng đúng tham số, mã lỗi, cột trả về của từng procedure/view); `DB_MODE=sqlserver` kết nối SQL Server thật (`app/api/.env.example` dòng 9–30).
- **Phân quyền 2 lớp:** JWT + vai trò ở API (`roles: [...]` trong mỗi route) và 4 login SQL tách biệt `fv_admin_app`, `fv_operator_app`, `fv_kiosk_app`, `fv_device_app` (bảng quyền mẫu: `fakeDb.js` dòng 16–28).

## 2. Công nghệ đang dùng

| Thành phần | Công nghệ | Bằng chứng |
|---|---|---|
| CSDL | SQL Server 2022 (T-SQL), 6 schema | `sql/00_database.sql`, `sql/01_schemas.sql` |
| Backend | Node.js ≥ 18 (CI dùng 20), thư viện duy nhất `mssql` ^11, router/JWT/QR tự viết | `app/api/package.json`, `app/.nvmrc` |
| Frontend | HTML/CSS/JS thuần, ES module, SSE `/api/stream` | `app/web/`, `app/web/js/admin.js` dòng 4, 38–39 |
| Thanh toán | VietQR (tự sinh mã), webhook SePay, nút giả lập chuyển khoản | `app/api/src/lib/vietqr.js`, `routes/sales.js` |
| IoT | **Mô phỏng** ESP32 bằng Node.js (không có phần cứng) | `app/simulator/esp32.js` |
| Tài liệu API | Swagger/OpenAPI tại `/api-docs` | `app/api/src/openapi.js` |
| Kiểm thử | `node --test` (30 test), `tools/check-sync.js` (FE ⇄ BE), GitHub Actions CI | `.github/workflows/ci.yml` |
| Docker | **Chưa có** | không tìm thấy Dockerfile/compose |

> Lưu ý ràng buộc: đề ghi PostgreSQL nhưng môn học dùng T-SQL → nhóm dùng SQL Server. Cần ghi trong SRS mục *Ràng buộc*.

## 3. Chức năng đã hoàn thành (có bằng chứng)

| # | Chức năng | Bằng chứng |
|---|---|---|
| 1 | API đủ 56 route cho 5 module, Swagger | `check-sync`: *56 route API · 59 lời gọi từ web/ + simulator/* |
| 2 | Giao diện quản trị 9 trang + kiosk bán hàng | `app/web/js/pages/*.js` (9 file), `app/web/kiosk.html` |
| 3 | Chạy trọn luồng ở chế độ demo (chọn hàng → VietQR → giả lập chuyển khoản → nhả hàng) | `npm run demo`, đã chạy thử 05/11 |
| 4 | Kiểm thử API: **30/30 pass**, FE ⇄ BE khớp | `npm test` chạy trên máy nhóm ngày 05/11 (PR #13) |
| 5 | Mô phỏng ESP32: gửi nhiệt độ/độ ẩm/cửa, kịch bản quá nhiệt, mở cửa, kẹt, mất mạng, lưu đệm gửi bù | `app/simulator/esp32.js` dòng 1–13, 75–95 |
| 6 | CSDL – report: 3 bảng, 6 procedure, 3 view, 1 function | `sql/02_tables_report.sql`, `07_procs_report.sql`, `05_views_report.sql`, `06_functions_report.sql` |
| 7 | CSDL – sales: 5 bảng + TVP, 5 procedure có UPDLOCK | `sql/02_tables_sales.sql`, `sql/12_procs_sales.sql` |
| 8 | CSDL – iot: 6 bảng, 7 procedure (OPENJSON, heartbeat, gom theo giờ) | `sql/02_tables_iot.sql`, `sql/07_procs_iot.sql` |
| 9 | Tài liệu: State diagram đơn hàng, User Story bán hàng | `docs/State.drawio`, `docs/UserStories_Sales.md` |

## 4. Đang làm dở (trên nhánh chưa merge)

| Nhánh | Người | Nội dung | Vấn đề |
|---|---|---|---|
| `tv3-sales` | Ân | `22_objects_sales.sql` (fn_OrderTotal, trg_Orders_StatusGuard, vw_OrderDetail, vw_PendingOrders), `tests/60_concurrency_demo.sql`, `tests/tests_sales.sql` | Chưa có `vw_DispenseQueue`; file test chứa cả lệnh tạo index |
| `tv4-iot` | Dũng | `04_functions_iot.sql` (fn_RecentTelemetry), `05_views_iot.sql` (vw_MachineHealth, vw_OpenAlerts), 2 ảnh diagram | Số file trùng với file của report |
| `check-nv-chua-hoan-thien-xa` | Anh | 25 file: seed, procs/view report sửa lại, `04_report_dependencies.sql`, kiểm thử TV5 21/21 PASS | `04_report_dependencies.sql` **tự tạo bảng của module khác** (`inventory.Locations`, `iot.TelemetryHourly`, `sales.DispenseAttempts`); sửa file chung `03_foreign_keys.sql`, `README.md`; email commit `email-cua-ban@example.com` |

## 5. Chưa thực hiện

API gọi **45 đối tượng CSDL** (procedure/view/function). Trên `main` có 20; tính cả 3 nhánh là 25; **20 đối tượng chưa ai viết**:

| Module | Thiếu | Ảnh hưởng |
|---|---|---|
| auth/audit (TV1) | 5 procedure (`sp_Login`, `sp_CreateUser`, `sp_ChangePassword`, `sp_AssignMachine`, `sp_DeactivateUser`), 2 view, bảng `audit.*`, phân quyền 4 login, RLS, backup | **Không đăng nhập được** khi chạy SQL thật |
| inventory (TV2) | 7 procedure, 4 view, 1 function, Temporal, TVP | Không có sản phẩm/tồn kho → kiosk trống |
| sales (TV3) | `vw_DispenseQueue` | Máy không bao giờ nhả hàng khi chạy SQL thật |
| Toàn hệ thống | Trigger (chỉ có 1 trên nhánh sales), SQL Agent Job, partition Telemetry, Docker, `99_run_all`, ERD, Detailed Design, Architecture, User Manual Customer/Operator, Install Guide đầy đủ | Thiếu sản phẩm bắt buộc của đề |

## 6. Lỗi và rủi ro (có bằng chứng)

| # | Mức | Lỗi/rủi ro | Bằng chứng | Xử lý (task) |
|---|---|---|---|---|
| L1 | Nghiêm trọng | `03_foreign_keys.sql` tham chiếu 5 bảng không tồn tại (`audit.AuditLog`, `audit.ChangeLog`, `iot.Device`, `iot.Alert`, `report.MachineStockSnapshot`) → chạy từ đầu báo lỗi | `sql/03_foreign_keys.sql` dòng 136, 153, 170, 183, 213–241 | FV-06, FV-07 |
| L2 | Nghiêm trọng | Gói telemetry API gửi `{machineId, readings}` nhưng `iot.sp_IngestTelemetry` đọc `$.serial` → mọi gói lỗi 50311 khi chạy SQL thật | `routes/iot.js` dòng 16–21; `07_procs_iot.sql` dòng 79–85 | FV-12 |
| L3 | Nghiêm trọng | Hai bảng máy `inventory.Machine` và `iot.Machines` không đồng bộ; báo cáo dùng `inventory.Location`, `inventory.Stock`, `inventory.Batch` không tồn tại | `02_tables_inventory.sql` dòng 114; `02_tables_iot.sql` dòng 52; `05_views_report.sql` dòng 51–55 | FV-01, FV-13, FV-15 |
| L4 | Cao | Tên ngăn lệch: SQL `SlotId/SlotCode`, API `ColumnId/ColumnNo` | `02_tables_inventory.sql` dòng 146–154; `routes/inventory.js` | FV-01 (QĐ-2), FV-18 |
| L5 | Cao | Bảng `inventory.SlotStock` do module sales tạo | `12_procs_sales.sql` dòng 42–60 | FV-02, FV-09 |
| L6 | Cao | `docs/TestReport.md` trên main ghi 12/12 PASS cho cả ca auth/inventory khi procedure chưa tồn tại; TC-11 luôn PASS | `docs/TestReport.md`; `07_procs_report.sql` dòng 821–836 | FV-30, FV-45 |
| L7 | Trung bình | Số thứ tự file trùng (`07_procs_iot`/`07_procs_report`, `05_views_report`/`05_seed_small`), README liệt kê file không có, `app/README.md` bảo chạy `FreshVend_FULL.sql` không tồn tại | `ls sql/`, `README.md`, `app/README.md` dòng 47 | FV-16, FV-23 |
| L8 | Trung bình | `auth.LoginHistory.UserId` NOT NULL → không ghi được lần đăng nhập sai tên; `auth.[User]` thiếu Salt, FailedLogins | `02_tables_auth.sql` dòng 26–37, 184–191 | FV-06 |
| L9 | Trung bình | Chưa có Docker (đề bắt buộc) | không có file | FV-11, FV-41 |
| R1 | Rủi ro | TV1 (Toàn) chưa có commit nào – khối lượng tồn lớn nhất, nằm trên đường găng (đăng nhập) | `git log --author` | Leader hỗ trợ; chia nhỏ FV-06/07/08 |
| R2 | Rủi ro | SQL Server Express không có SQL Agent | `jobs.js` dòng 1–2 | FV-28 dùng `JOBS_FALLBACK=true` |
| R3 | Rủi ro | Không có phần cứng IoT | yêu cầu nhóm | Mô phỏng + ghi rõ trong tài liệu (FV-29, FV-43); firmware tham chiếu tùy chọn (FV-44) |

## 7. Module cần cải thiện

- **auth/audit:** viết mới gần như toàn bộ (FV-06 → FV-08, FV-21 → FV-23, FV-36).
- **inventory:** viết mới procedure/view, bổ sung bảng (FV-02 → FV-04, FV-18, FV-19).
- **iot:** sửa lệch gói dữ liệu, hợp nhất bảng máy, partition, job (FV-12 → FV-14, FV-27, FV-28).
- **report:** bỏ tạo bảng ngoài schema, test thật (FV-15, FV-30).

## 8. Phần cần tích hợp

1. Bảng máy chung (QĐ-1) giữa inventory – sales – iot – report – auth (RLS, giao máy).
2. `sales.sp_CreateOrder` ↔ `inventory.fn_GetFifoStock` (FIFO).
3. Trigger tồn thấp (inventory) ↔ `iot.Alerts`.
4. API ↔ SQL Server qua 4 login + `SESSION_CONTEXT('UserId')` cho RLS.
5. Simulator ↔ `iot.sp_IngestTelemetry`, `sales.vw_DispenseQueue`, `sales.sp_RecordDispense`.
6. Job định kỳ ↔ procedure của 4 module.

## 9. Phần cần kiểm thử

- Unit SQL: `tests/tests_<module>.sql` – 1 ca đúng + 2 ca sai cho mỗi procedure (5 module).
- Unit API: `npm test` (đã có 30 test, giữ xanh trong CI).
- Integration: kịch bản 10 bước (FV-32) trên SQL thật.
- Performance: P95 API ≤ 500 ms, truy vấn báo cáo trên 200.000 telemetry/5.000 đơn (FV-31).
- Chuỗi lạnh/IoT (mô phỏng): 5 kịch bản (FV-29).
- Đồng thời: 2 phiên mua cùng lúc (FV-25). Bảo mật: RLS, DENY, khôi phục STOPAT (FV-36).

## 10. Phần phải làm thủ công

| Việc | Ai | Ở đâu | Bằng chứng |
|---|---|---|---|
| Bật TCP/IP, SQL Authentication, khởi động lại dịch vụ | Mỗi người trên máy mình (lần đầu); Huy cho máy demo | SQL Server Configuration Manager, SSMS | Ảnh cửa sổ cấu hình |
| Điền `app/api/.env` (không commit) | Mỗi người | VS Code | – |
| Bấm thử giao diện, chụp ảnh cho User Manual | Ân, Huy, Dũng, Anh | Trình duyệt | Ảnh trong `docs/` |
| Chạy kịch bản simulator, quay video | Dũng | 2 terminal + trình duyệt | Video trên Drive |
| Xác nhận thanh toán thủ công (giả lập) | Người demo | Trang Đơn hàng / nút giả lập | Ảnh |
| Tạo `.bak`, tag release | Huy | SSMS, Git | Link release |
| Tạo Sprint/Epic/Task Jira | Huy | Jira | Ảnh board |

## 11. Đánh giá mức độ hoàn thiện (05/11/2026)

| Hạng mục | Ước lượng | Căn cứ |
|---|---|---|
| Frontend + API (chế độ demo) | ~90% | 56 route, 9 trang + kiosk, 30/30 test |
| CSDL (đối tượng API cần) | ~45% (25/45 có trên repo, 20/45 trên main) | đếm `CREATE PROCEDURE/VIEW/FUNCTION` |
| Chạy với SQL Server thật | ~0% | thiếu `sp_Login`, lỗi `03_foreign_keys` |
| IoT (mô phỏng) | ~60% | simulator xong, CSDL lệch gói, chưa partition/job |
| Docker/CI | CI có, Docker 0% | `.github/workflows/ci.yml` |
| Tài liệu bắt buộc | ~15% | SRS nháp, TestPlan/TestReport phần report, State diagram |

## 12. Phạm vi đề xuất cho 21 ngày (06/11 – 26/11/2026)

**Phải có (Must):** 45 đối tượng CSDL đủ, chạy từ máy trống không lỗi; app chạy `DB_MODE=sqlserver` trọn kịch bản; RBAC/RLS; mỗi người 1 phần khó demo được; Test Report số liệu thật; SRS, ERD, Architecture, Detailed Design, Install Guide, 3 User Manual; Docker chạy được.

**Nên có (Should):** SQL Agent Job (hoặc fallback), partition Telemetry, đo hiệu năng trước/sau index, video dự phòng.

**Có thì tốt (Could):** firmware ESP32 tham chiếu (chỉ biên dịch). **Không làm:** ứng dụng di động riêng cho Operator (giao diện web đã responsive – ghi vào *Hạn chế*), thanh toán thẻ tín dụng, mã hóa TDE (chỉ trình bày lý thuyết).
