# UserManual — Hướng dẫn Sử dụng FreshVend

> **Dự án:** FreshVend
> **Phiên bản:** 1.0
> **Ngày:** 2026-10-31

---

## 1. Đăng nhập hệ thống

### 1.1 Đăng nhập giao diện Web (Admin Dashboard)

1. Mở trình duyệt, truy cập `http://localhost:3000/`.
2. Nhập **Tên đăng nhập** và **Mật khẩu**.
3. Nhấn **Đăng nhập**.

| Tài khoản | Mật khẩu | Vai trò |
|-----------|---------|---------|
| `admin` | `Admin@2026` | Quản trị viên (toàn quyền) |
| `operator01` | `Operator@2026` | Nhân viên vận hành |
| `kiosk01` | `Kiosk@2026` | Màn hình bán hàng |

> **Lưu ý bảo mật:** Sau 5 lần nhập sai mật khẩu, tài khoản sẽ bị khóa. Quản trị viên cần mở khoá thủ công.

### 1.2 Đăng nhập SSMS (SQL Server Management Studio)

1. Mở SSMS → Connect → Server name: `localhost\SQLEXPRESS` (hoặc theo cấu hình).
2. Authentication: **SQL Server Authentication**.
3. Dùng login được tạo trong `00_database.sql`.

---

## 2. Quản lý sản phẩm

1. Vào menu **Sản phẩm & Giá**.
2. Nhấn **Thêm sản phẩm** → điền tên, giá, danh mục, mô tả.
3. Để tải ảnh: nhấn **Sửa** → **Chọn ảnh** (JPG/PNG/WebP, tối đa 5MB).
4. Lịch sử thay đổi giá được lưu tự động — xem tại **Lịch sử giá** của từng sản phẩm.

---

## 3. Xem báo cáo doanh thu (Admin — Phần của TV5)

### 3.1 Dashboard KPI

Vào menu **Báo cáo** → **Dashboard**. Trang hiển thị:

| Chỉ số | Mô tả |
|--------|-------|
| Doanh thu hôm nay | Tổng tiền đơn PAID + DISPENSED trong ngày |
| So hôm qua | Doanh thu ngày hôm qua |
| Số đơn hôm nay | Tổng đơn hoàn thành trong ngày |
| Máy hoạt động | Số máy trạng thái ACTIVE |
| Cảnh báo mở | Số cảnh báo IoT chưa xử lý |
| Tỷ lệ kẹt | % lần nhả hàng bị kẹt |
| Cold-chain | % thời gian nhiệt độ trong ngưỡng cho phép |

Biểu đồ doanh thu 14 ngày và Top-5 sản phẩm bán chạy 30 ngày cũng hiển thị trên trang này.

**Nguồn dữ liệu (SQL Server):**
```sql
EXEC report.sp_DashboardKpi;
```

---

### 3.2 Doanh thu theo tháng (Tăng trưởng)

Vào **Báo cáo** → **Tăng trưởng doanh thu**.

Hiển thị bảng 12 tháng:

| Cột | Mô tả |
|-----|-------|
| MonthNo | Tháng (1–12) |
| Revenue | Doanh thu tháng đó |
| GrowthPercent | % tăng so tháng trước (dùng LAG) |
| RunningTotal | Luỹ kế từ đầu năm (dùng SUM OVER) |

**Tham số:** Chọn năm ở ô **Năm** (mặc định năm hiện tại).

**SQL trực tiếp:**
```sql
EXEC report.sp_RevenueGrowth @Year = 2026;
```

---

### 3.3 Giờ cao điểm bán hàng (Peak Hours)

Vào **Báo cáo** → **Giờ cao điểm**.

Hiển thị bảng nhiệt (heatmap) 24 giờ × 7 ngày:

| Cột | Mô tả |
|-----|-------|
| HourOfDay | Giờ trong ngày (0–23) |
| T2 … CN | Số đơn theo từng ngày trong tuần |
| Total | Tổng đơn trong giờ đó |

**Lọc theo ngày:** Điền `Từ ngày` và `Đến ngày`.

**SQL trực tiếp:**
```sql
EXEC report.sp_PeakHours @From = '2026-10-01', @To = '2026-10-31';
```

---

### 3.4 Xuất báo cáo doanh thu (Excel)

Vào **Báo cáo** → **Xuất dữ liệu**.

1. Chọn khoảng ngày (**Từ ngày**, **Đến ngày**).
2. Chọn địa điểm (tuỳ chọn — để trống = tất cả).
3. Nhấn **Xuất Excel**.

File Excel tải về gồm các cột:
`OrderId | CreatedAt | LocationName | Serial | ProductName | Qty | UnitPrice | LineTotal | Status | PaymentMethod`

Mỗi lần xuất được ghi vào **Lịch sử xuất báo cáo** (`report.ExportLogs`).

**SQL trực tiếp:**
```sql
EXEC report.sp_ExportSales
    @From       = '2026-10-01',
    @To         = '2026-10-31',
    @UserId     = 1,
    @LocationId = NULL;   -- NULL = tất cả địa điểm
```

---

### 3.5 Xếp hạng sản phẩm theo địa điểm

Vào **Báo cáo** → **Xếp hạng sản phẩm**.

Hiển thị bảng xếp hạng sản phẩm bán chạy tại từng địa điểm:

| Cột | Mô tả |
|-----|-------|
| LocationName | Tên địa điểm |
| ProductName | Tên sản phẩm |
| RankInLocation | Hạng trong địa điểm (RANK(), 1 = bán chạy nhất) |
| QtySold | Số lượng bán |
| Revenue | Doanh thu |
| SharePercent | % đóng góp doanh thu địa điểm |

**SQL trực tiếp:**
```sql
SELECT * FROM report.vw_ProductRanking ORDER BY LocationId, RankInLocation;
```

---

### 3.6 Tuân thủ cold-chain

Vào **Báo cáo** → **Nhiệt độ & Cold-chain**.

| Cột | Mô tả |
|-----|-------|
| MachineName | Tên máy |
| HoursMonitored | Số giờ có dữ liệu telemetry |
| MinutesOutOfRange | Số phút nhiệt độ ngoài ngưỡng |
| CompliancePercent | % thời gian trong ngưỡng cho phép |

**SQL trực tiếp:**
```sql
SELECT * FROM report.vw_ColdChainCompliance ORDER BY CompliancePercent;
```

---

### 3.7 Doanh thu theo địa điểm (TVF)

Dùng khi cần truy vấn doanh thu tổng hợp theo địa điểm trong khoảng thời gian tùy ý:

```sql
SELECT *
FROM report.fn_RevenueByLocation('2026-10-01', '2026-10-31')
ORDER BY Revenue DESC;
```

---

### 3.8 Làm mới tóm tắt doanh thu hàng ngày

Chạy thủ công (hoặc qua SQL Server Agent job):

```sql
-- Làm mới cho hôm nay
EXEC report.sp_RefreshDailySummary;

-- Làm mới cho khoảng ngày cụ thể
EXEC report.sp_RefreshDailySummary @Date = '2026-10-01', @ToDate = '2026-10-31';
```

---

## 4. Giám sát IoT

1. Vào menu **Thiết bị** → **Trạng thái máy** để xem nhiệt độ, độ ẩm, tình trạng cửa.
2. Cảnh báo mở xem tại **Cảnh báo** — nhấn **Xử lý** để đánh dấu đã giải quyết.
3. Nếu máy chuyển trạng thái `DEGRADED`: kiểm tra tab **Lịch sử nhiệt độ** và view `vw_ColdChainCompliance`.

---

## 5. Kiểm thử hệ thống (Admin)

Chạy 12 ca kiểm thử tích hợp:

```sql
EXEC report.sp_RunAllTests;

-- Xem kết quả lần chạy mới nhất
SELECT * FROM report.vw_LatestTestRun ORDER BY TestId;
```

Kết quả mong đợi: tất cả 12 dòng có `Passed = 1`.
