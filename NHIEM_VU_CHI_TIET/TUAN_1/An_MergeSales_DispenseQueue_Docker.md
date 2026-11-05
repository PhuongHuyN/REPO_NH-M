# Ân – Tuần 1: Sprint 1 – Nền tảng CSDL

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Đoàn Phương Thiên Ân
- **Email:** thienann2611@gmail.com
- **Tuần:** 1 (Sprint 1 – Nền tảng CSDL)
- **Thời gian:** 06/11/2026 → 12/11/2026
- **Vai trò:** TV3 – Bán hàng & Thanh toán (schema sales), Kiosk, Docker, slide bảo vệ
- **Mức độ ưu tiên:** High
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-203, SCRUM-204, SCRUM-205

**Mục tiêu Sprint:** Mọi bảng và stored procedure lõi của 5 module có trên main; chạy toàn bộ script trên CSDL trống không lỗi; xóa hết nhánh tồn đọng.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-09 (SCRUM-203) | Đưa nhánh tv3-sales lên main: cập nhật theo main, bỏ phần tạo bảng của inventory, mở PR | 06/11/2026 | 08/11/2026 | High | FV-01, FV-02 |
| FV-10 (SCRUM-204) | Thêm sales.vw_DispenseQueue và đối chiếu cột 3 view sales với API | 09/11/2026 | 10/11/2026 | High | FV-09 |
| FV-11 (SCRUM-205) | Dockerfile cho API và docker-compose.yml (SQL Server + API) | 11/11/2026 | 12/11/2026 | Medium | – |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-09 (SCRUM-203) – Đưa nhánh tv3-sales lên main: cập nhật theo main, bỏ phần tạo bảng của inventory, mở PR

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 06/11/2026 → 08/11/2026 |
| Mức ưu tiên | High |
| Epic | E3 – Bán hàng & Thanh toán (sales) |
| Phụ thuộc | FV-01 (SCRUM-195) (Huy), FV-02 (SCRUM-196) (Huy) |
| Người hỗ trợ | Huy |

### 1. MỤC TIÊU
Đưa nhánh tv3-sales lên main: cập nhật theo main, bỏ phần tạo bảng của inventory, mở PR. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Nhánh `tv3-sales` có 2 commit chưa merge (05/11): `sql/22_objects_sales.sql` (fn_OrderTotal, trg_Orders_StatusGuard, vw_OrderDetail, vw_PendingOrders), `tests/60_concurrency_demo.sql`, `tests/tests_sales.sql`. File `12_procs_sales.sql` trên main đang tự tạo bảng `inventory.SlotStock` và dữ liệu *OPEN-SLOT* – bảng này thuộc TV2 và Huy đã khai báo lại y hệt trong FV-02.

### 3. PHẠM VI CÔNG VIỆC
- Merge `origin/main` mới nhất vào `tv3-sales`.
- Sau khi PR FV-02 merge: xóa khối `CREATE TABLE inventory.SlotStock` khỏi `12_procs_sales.sql` (giữ phần ALTER bảng sales).
- Chạy toàn bộ script trên CSDL trống.
- Mở PR `tv3-sales → main`, nhờ Leader review.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Cập nhật nhánh**
```powershell
git checkout tv3-sales
git pull origin tv3-sales
git fetch origin
git merge origin/main
```
Nếu báo CONFLICT: mở file trong VS Code, chọn *Accept Both* rồi sửa tay, **không** chọn hết một phía.

**Bước 2. Bỏ khối SlotStock**
- **Mở file:** `sql/12_procs_sales.sql` dòng ~42–60 (khối `IF OBJECT_ID(N'inventory.SlotStock', N'U') IS NULL ...`).
- **Cách làm:** xóa khối này, thay bằng 1 dòng chú thích: `-- inventory.SlotStock do TV2 tạo trong 02_tables_inventory.sql`.
- **Giữ lại:** phần ALTER `sales.OrderItem ADD StockId`, FK sang SlotStock, phần chuyển *OPEN-SLOT* (nếu nhóm vẫn cần).

**Bước 3. Đổi tên file đúng QĐ-3**
- `tests/tests_sales.sql` đang chứa lệnh `CREATE INDEX` → chuyển các index sang `sql/30_index_sales.sql`, file test chỉ còn ca kiểm thử.

**Bước 4. Chạy thử**
SSMS: CSDL trống → 00 → 01 → toàn bộ 02 → 03 → 12_procs_sales → 22_objects_sales → tests_sales.sql.

**Bước 5. Mở PR**
Theo mục 9 bước 6–10.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/12_procs_sales.sql`
- `sql/22_objects_sales.sql`
- `tests/tests_sales.sql`
- `sql/30_index_sales.sql` (mới)
- `tests/60_concurrency_demo.sql`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** Huy merge FV-02 (khoảng 08/11). **Đầu ra:** nhánh sales lên main để Toàn (FV-22) GRANT quyền view sales.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Chạy từ đầu | CSDL trống, toàn bộ script | Không lỗi |
| 2 | tests_sales | F5 | Tất cả PASS |

**Kết quả cần lưu lại:** Link PR.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Không còn tạo bảng của schema khác trong file sales
- [ ] PR merge vào main, CI xanh

### 9. GITHUB WORKFLOW
Task dùng **nhánh có sẵn `tv3-sales`** (không tạo nhánh mới).
1. **Kiểm tra nhánh hiện tại**
```powershell
git status
git branch
```
2. **Chuyển sang nhánh và đồng bộ với main**
```powershell
git checkout tv3-sales
git pull origin tv3-sales
git fetch origin
git merge origin/main
```
Nếu báo `CONFLICT` → xem `Cach_su_dung_GITHUB.md` mục 7.
3. **Commit**
```powershell
git add sql/12_procs_sales.sql sql/22_objects_sales.sql tests/tests_sales.sql sql/30_index_sales.sql tests/60_concurrency_demo.sql
git commit -m "refactor(sql-sales): bỏ tạo inventory.SlotStock (đã chuyển về TV2), cập nhật theo main"
```
4. **Push**
```powershell
git push origin tv3-sales
```
5. **Tạo Pull Request** `base: main` ← `compare: tv3-sales`, tiêu đề `[SCRUM-203] Đưa nhánh tv3-sales lên main: cập nhật theo main, bỏ phần tạo bảng của inventory, mở PR`, nội dung theo mẫu ở `Cach_su_dung_GITHUB.md` mục 5, mục *Related Jira Task* ghi `SCRUM-203`.
6. **Kiểm tra conflict:** GitHub hiện *This branch has no conflicts with the base branch*. Nếu có conflict → làm lại bước 2.
7. **Nhờ Leader review:** Reviewers → PhuongHuyN; nhắn nhóm chat kèm link PR.
8. **Merge** khi được Approve (Leader bấm *Squash and merge*). Sau đó:
```powershell
git checkout main
git pull origin main
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-203 |
| Branch | `tv3-sales (nhánh hiện có – giữ tên)` |
| Commit | `refactor(sql-sales): bỏ tạo inventory.SlotStock (đã chuyển về TV2), cập nhật theo main` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- PR tv3-sales đã merge

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 08/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-203
- **Bằng chứng hoàn thành:** Link PR
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-10 (SCRUM-204) – Thêm sales.vw_DispenseQueue và đối chiếu cột 3 view sales với API

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 09/11/2026 → 10/11/2026 |
| Mức ưu tiên | High |
| Epic | E3 – Bán hàng & Thanh toán (sales) |
| Phụ thuộc | FV-09 (SCRUM-203) (Ân) |
| Người hỗ trợ | Dũng |

### 1. MỤC TIÊU
Thêm sales.vw_DispenseQueue và đối chiếu cột 3 view sales với API. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Bộ điều khiển máy (simulator ESP32 của TV4) hỏi hàng chờ nhả mỗi 1,5 giây qua `GET /api/dispense-queue` → đọc `sales.vw_DispenseQueue`. View này **chưa có** trong repo nên máy không bao giờ nhả hàng khi chạy SQL thật.

### 3. PHẠM VI CÔNG VIỆC
- Thêm `sales.vw_DispenseQueue` vào `sql/22_objects_sales.sql`.
- Cột: `OrderId, MachineId, OrderItemId, ColumnNo, Qty, PaidAt, AttemptsSoFar` (fakeDb.js dòng 583–590).
- Điều kiện: đơn `PAID`, món chưa nhả thành công, số lần thử < 3.
- So cột `vw_OrderDetail`, `vw_PendingOrders` với fakeDb dòng 566–582; thiếu thì bổ sung.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Viết view**
```sql
CREATE OR ALTER VIEW sales.vw_DispenseQueue AS
SELECT o.OrderId, o.MachineId, oi.OrderItemId, s.SlotCode AS ColumnNo, oi.Quantity AS Qty, o.PaidAt,
       (SELECT COUNT(*) FROM sales.DispenseEvents d WHERE d.OrderItemId = oi.OrderItemId) AS AttemptsSoFar
FROM sales.[Order] o
JOIN sales.OrderItem oi ON oi.OrderId = o.OrderId
JOIN inventory.Slot s ON s.SlotId = oi.SlotId
WHERE o.Status = 'PAID'
  AND NOT EXISTS (SELECT 1 FROM sales.DispenseEvents d WHERE d.OrderItemId = oi.OrderItemId AND d.Result = 'SUCCESS')
  AND (SELECT COUNT(*) FROM sales.DispenseEvents d WHERE d.OrderItemId = oi.OrderItemId) < 3;
```
- **Lưu ý:** kiểm tra lại tên cột thật trong `02_tables_sales.sql` (`Quantity`/`Qty`, `Result`).

**Bước 2. Đối chiếu cột**
```sql
SELECT name FROM sys.columns WHERE object_id = OBJECT_ID(N'sales.vw_OrderDetail') ORDER BY column_id;
```
So với danh sách key trong fakeDb.js. Ghi bảng đối chiếu vào mô tả PR.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/22_objects_sales.sql`
- `app/api/test/fakeDb.js dòng 566–590`
- `app/api/src/routes/sales.js` (route /api/dispense-queue)
- `app/simulator/esp32.js` (vòng hỏi hàng chờ)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu ra cho:** Dũng (FV-29 simulator nhả hàng với SQL thật), Toàn (FV-22 GRANT SELECT cho r_kiosk, r_device).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Đơn đã trả tiền | Tạo đơn + ConfirmPayment | Đơn xuất hiện trong view |
| 2 | Đã nhả | RecordDispense SUCCESS | Đơn biến mất khỏi view |
| 3 | Kẹt 3 lần | 3 lần JAM | Không còn trong view, đơn REFUNDED |

**Kết quả cần lưu lại:** Ảnh 3 test.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] View tồn tại, cột khớp fakeDb
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
git checkout -b feature/SCRUM-204-sales-dispense-queue
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/22_objects_sales.sql
git commit -m "feat(sql-sales): vw_DispenseQueue; khớp cột view với fakeDb"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-204-sales-dispense-queue
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-204-sales-dispense-queue`.
7. **Mô tả PR:** tiêu đề `[SCRUM-204] Thêm sales.vw_DispenseQueue và đối chiếu cột 3 view sales với API`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-204`; dán ảnh bằng chứng: Ảnh 3 test.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-204-sales-dispense-queue
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-204 |
| Branch | `feature/SCRUM-204-sales-dispense-queue` |
| Commit | `feat(sql-sales): vw_DispenseQueue; khớp cột view với fakeDb` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/22_objects_sales.sql (thêm view)

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 10/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-204
- **Bằng chứng hoàn thành:** Ảnh 3 test
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-11 (SCRUM-205) – Dockerfile cho API và docker-compose.yml (SQL Server + API)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 11/11/2026 → 12/11/2026 |
| Mức ưu tiên | Medium |
| Epic | E6 – Tích hợp, Triển khai & Tài liệu |
| Phụ thuộc | Không |
| Người hỗ trợ | Toàn |

### 1. MỤC TIÊU
Dockerfile cho API và docker-compose.yml (SQL Server + API). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Đề bắt buộc gói triển khai Docker; repo hiện **chưa có** Dockerfile. API là Node.js (chỉ phụ thuộc `mssql`) và tự phục vụ giao diện `app/web`, nên chỉ cần 1 container app + 1 container SQL Server.

### 3. PHẠM VI CÔNG VIỆC
- `app/Dockerfile` (Node 20 alpine, cài `api/`, chạy `node api/src/server.js`).
- `app/.dockerignore` (node_modules, .env, uploads).
- `docker-compose.yml` ở gốc repo: dịch vụ `db` (mcr.microsoft.com/mssql/server:2022-latest) + `api`.
- Mục hướng dẫn chạy trong `app/README.md`.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Cài Docker Desktop**
Tải Docker Desktop for Windows, bật WSL 2. Kiểm tra: `docker version`.

**Bước 2. Dockerfile**
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY api/package*.json api/
RUN cd api && npm ci --omit=dev
COPY api ./api
COPY web ./web
COPY simulator ./simulator
ENV PORT=3000
EXPOSE 3000
CMD ["node", "api/src/server.js"]
```

**Bước 3. docker-compose.yml**
```yaml
services:
  db:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      ACCEPT_EULA: "Y"
      MSSQL_SA_PASSWORD: "${SA_PASSWORD}"
    ports: ["1433:1433"]
    volumes: ["mssql-data:/var/opt/mssql"]
  api:
    build: ./app
    env_file: ./app/api/.env
    environment:
      DB_SERVER: db
    ports: ["3000:3000"]
    depends_on: [db]
volumes:
  mssql-data:
```
Mật khẩu SA đặt trong file `.env` cạnh compose (thêm `.env` vào `.gitignore`).

**Bước 4. Tạo CSDL trong container**
```powershell
docker compose up -d db
docker cp sql freshvend-db-1:/sql
docker exec -it freshvend-db-1 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "<SA_PASSWORD>" -C -i /sql/00_database.sql
```
Lặp lại theo thứ tự file (hoặc viết `scripts/docker-init.sh` gọi lần lượt). Sau đó `docker compose up -d api`.

### 5. FILE VÀ MODULE LIÊN QUAN
- `app/Dockerfile` (mới)
- `app/.dockerignore` (mới)
- `docker-compose.yml` (mới)
- `app/README.md` (thêm mục Docker)
- `.gitignore`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu ra cho:** Toàn (FV-38 InstallGuide phần Docker), Huy (FV-35 gói nộp).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Build | docker compose build | Thành công |
| 2 | Chạy demo trong Docker | DB_MODE=demo, docker compose up api | http://localhost:3000 mở được |
| 3 | Chạy với db | DB_MODE=sqlserver | /api/health ok |

**Kết quả cần lưu lại:** Ảnh docker compose ps + trình duyệt.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Build không lỗi
- [ ] Không commit mật khẩu thật
- [ ] README có hướng dẫn Docker
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
git checkout -b feature/SCRUM-205-docker
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add app/Dockerfile app/.dockerignore docker-compose.yml app/README.md
git commit -m "feat(docker): Dockerfile API + docker-compose (mssql + api)"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-205-docker
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-205-docker`.
7. **Mô tả PR:** tiêu đề `[SCRUM-205] Dockerfile cho API và docker-compose.yml (SQL Server + API)`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-205`; dán ảnh bằng chứng: Ảnh docker compose ps + trình duyệt.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-205-docker
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-205 |
| Branch | `feature/SCRUM-205-docker` |
| Commit | `feat(docker): Dockerfile API + docker-compose (mssql + api)` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- app/Dockerfile
- docker-compose.yml

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 12/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-205
- **Bằng chứng hoàn thành:** Ảnh docker compose ps + trình duyệt
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
