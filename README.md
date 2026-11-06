#  FreshVend — Hệ thống máy bán trái cây tự động

> **Môn học:** Hệ quản trị Cơ sở dữ liệu (T-SQL / SQL Server)  
> **Ngày khởi tạo:** 2026-10-21  

---

##  Nhóm thực hiện

| Thành viên | MSSV | Phụ trách | Mức độ hoàn thành |
|------------|-------|-----------|------------------|
| Nguyễn Phạm Xuân Anh | 089306017838 | *(Module)* | *(Module)* |
| Đoàn Phương Thiên Ân | 079306092350 | *(Module)* | *(Module)* |
| Nguyễn Phương Huy | 054206004278 | *(Module)* | *(Module)* |
| Huỳnh Nhật Toàn | 051206007163 | *(Module)* | *(Module)* |
| Trương Tuấn Dũng | 079206042161 | *(Module)* | *(Module)* |

---
##  Tổng quan đề tài

**FreshVend** là hệ thống cơ sở dữ liệu cho máy bán trái cây tươi tự động (vending machine). Hệ thống quản lý toàn bộ vòng đời sản phẩm — từ nhập kho, bán hàng, thanh toán, cho đến giám sát thiết bị IoT (ESP32) và báo cáo kinh doanh.

### Các chức năng chính

| Module | Mô tả |
|--------|-------|
| **auth** | Quản lý người dùng, vai trò, phân quyền |
| **inventory** | Quản lý kho, sản phẩm, nhà cung cấp, lô hàng |
| **sales** | Đơn hàng, giao dịch, thanh toán, khuyến mãi |
| **iot** | Thiết bị ESP32, cảm biến, cảnh báo, telemetry |
| **audit** | Nhật ký thay đổi dữ liệu, lịch sử thao tác |
| **report** | View tổng hợp, dữ liệu báo cáo định kỳ |

---

##  Cấu trúc thư mục

```
REPO_NH-M/
├── README.md                       ← File này
├── sql/
│   ├── 00_database.sql             ← Tạo DB FreshVendDB + 6 schema (TV1)
│   ├── 01_schemas.sql              ← Cấu hình schema (quyền, collation…) (TV1)
│   ├── 02_tables_auth.sql          ← Bảng module auth (TV1)
│   ├── 02_tables_inventory.sql     ← Bảng module inventory (TV2)
│   ├── 02_tables_sales.sql         ← Bảng module sales (TV3)
│   ├── 02_tables_iot.sql           ← Bảng module iot (TV4)
│   ├── 02_tables_report.sql        ← Bảng module audit + report (TV5)
│   ├── 03_foreign_keys.sql         ← Gom toàn bộ FK liên schema (TV1)
│   ├── 05_views_report.sql         ← Views module report (TV5)
│   ├── 06_functions_report.sql     ← Functions module report (TV5)
│   ├── 07_procs_report.sql         ← Stored procedures module report (TV5)
│   ├── 09_seed_small.sql           ← Dữ liệu mẫu nhỏ (~50 dòng/bảng)
│   └── 09_seed_large.sql           ← Dữ liệu mẫu lớn (kiểm thử hiệu năng)
├── docs/
│   ├── SRS.md                      ← Đặc tả yêu cầu phần mềm
│   ├── TestPlan.md                 ← Kế hoạch kiểm thử (TV5)
│   ├── TestReport.md               ← Báo cáo kết quả kiểm thử (TV5)
│   ├── UserManual.md               ← Hướng dẫn sử dụng — Admin báo cáo (TV5)
│   └── InstallGuide.md             ← Hướng dẫn cài đặt chi tiết
└── app/                            ← Ứng dụng Node.js (API + Web + Simulator)
    ├── api/                        ← REST API (Express)
    ├── web/                        ← Giao diện quản trị & kiosk
    ├── simulator/                  ← Mô phỏng thiết bị ESP32
    └── README.md                   ← Hướng dẫn chạy ứng dụng
```

---

##  Hướng dẫn cài đặt nhanh

### Yêu cầu

- **SQL Server** 2019 trở lên (hoặc SQL Server 2022)
- **SQL Server Management Studio (SSMS)** 18+ hoặc Azure Data Studio
- Quyền `sysadmin` hoặc `dbcreator` trên SQL Server instance

### Thứ tự chạy script (bắt buộc theo thứ tự)

> **Quy tắc merge:** TV1 & TV2 (bảng nền) → TV4 → TV3 → TV5

```
Bước 1 — Khởi tạo nền tảng (TV1)
  sql/00_database.sql            → Tạo database FreshVendDB và 6 schema
  sql/01_schemas.sql             → Cấu hình thêm cho các schema

Bước 2 — Tạo bảng (chạy theo thứ tự merge: TV1 → TV2 → TV4 → TV3 → TV5)
  sql/02_tables_auth.sql         → TV1: auth schema
  sql/02_tables_inventory.sql    → TV2: inventory schema
  sql/02_tables_iot.sql          → TV4: iot schema
  sql/02_tables_sales.sql        → TV3: sales schema
  sql/02_tables_report.sql       → TV5: audit + report schema

Bước 3 — Ràng buộc & tối ưu (TV1)
  sql/03_foreign_keys.sql        → Thêm toàn bộ FK (sau khi tất cả bảng đã tồn tại)

Bước 4 — Logic nghiệp vụ (TV5)
  sql/05_views_report.sql        → 3 views: vw_ProductRanking, vw_ColdChainCompliance, vw_LatestTestRun
  sql/06_functions_report.sql    → fn_RevenueByLocation(@From, @To)
  sql/07_procs_report.sql        → 6 procs: sp_DashboardKpi, sp_RevenueGrowth, sp_PeakHours,
                                             sp_ExportSales, sp_RefreshDailySummary, sp_RunAllTests

Bước 5 — Dữ liệu mẫu (chọn một)
  sql/09_seed_small.sql          → Dữ liệu mẫu nhỏ (phát triển & demo)
  sql/09_seed_large.sql          → Dữ liệu mẫu lớn (kiểm thử hiệu năng ≤ 500 ms)

Bước 6 — Kiểm thử tích hợp (TV5)
  EXEC report.sp_RunAllTests;    → Chạy 12 test cases, ghi kết quả vào report.TestResults
  SELECT * FROM report.vw_LatestTestRun ORDER BY TestId;
```

>  **Lưu ý:** File `03_foreign_keys.sql` **phải chạy sau tất cả** các file `02_tables_*.sql` vì các FK tham chiếu chéo giữa nhiều schema.

---

##  Quy tắc đặt tên (Naming Convention)

### Bảng & Schema

| Đối tượng | Quy tắc | Ví dụ |
|-----------|---------|-------|
| Schema | `snake_case` viết thường | `auth`, `inventory`, `iot` |
| Bảng | `[schema].[PascalCase]` | `auth.User`, `inventory.Product` |
| Cột khóa chính | `Id` (INT IDENTITY) hoặc `<Tên>Id` | `UserId`, `ProductId` |
| Cột khóa ngoại | `<TênBảngTham chiếu>Id` | `UserId`, `MachineId` |
| Cột ngày tạo | `CreatedAt` (DATETIME2) | `CreatedAt` |
| Cột ngày cập nhật | `UpdatedAt` (DATETIME2) | `UpdatedAt` |
| Cột trạng thái | `IsActive` / `IsDeleted` (BIT) | `IsActive` |

### Constraint

| Loại | Tiền tố | Ví dụ |
|------|---------|-------|
| Primary Key | `PK_` | `PK_auth_User` |
| Foreign Key | `FK_` | `FK_sales_Order_auth_User` |
| Unique | `UQ_` | `UQ_auth_User_Email` |
| Check | `CK_` | `CK_inventory_Product_Price` |
| Index | `IX_` | `IX_sales_Order_CreatedAt` |
| Default | `DF_` | `DF_auth_User_IsActive` |

### Stored Procedure & Function

| Đối tượng | Quy tắc | Ví dụ |
|-----------|---------|-------|
| Stored Procedure | `usp_<Schema>_<Verb><Noun>` | `usp_sales_CreateOrder` |
| Scalar Function | `ufn_<Schema>_<Verb><Noun>` | `ufn_inventory_GetStock` |
| Table Function | `uft_<Schema>_<Verb><Noun>` | `uft_report_DailySales` |
| Trigger | `tr_<Schema>_<Table>_<Event>` | `tr_audit_User_AfterUpdate` |
| View | `v_<Schema>_<Noun>` | `v_report_MonthlySales` |

### File SQL

- Tiền tố số `NN_` xác định thứ tự chạy (00, 01, 02…)
- Tên mô tả rõ nội dung: `02_tables_auth.sql`
- Tất cả viết thường, dùng dấu gạch dưới

---

##  Sơ đồ quan hệ (tóm tắt)

```
auth.User ──────────────┐
auth.Role               │ (1:N)
auth.UserRole           │
                        ▼
inventory.Machine ←── sales.Order ──→ sales.OrderItem
        │                                    │
        ▼                                    ▼
iot.Device ──→ iot.Telemetry        inventory.Product
        │
        ▼
audit.AuditLog (ghi nhận mọi thay đổi)
```

---


