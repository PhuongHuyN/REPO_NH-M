# TestPlan — Kế hoạch Kiểm thử

> **Dự án:** FreshVend
> **Phiên bản:** 1.0
> **Ngày cập nhật:** 2026-10-31
> **Người phụ trách:** TV5 — Trương Tuấn Dũng

---

## 1. Phạm vi kiểm thử

| Module | Đối tượng kiểm thử | Script / Procedure |
|--------|-------------------|--------------------|
| auth | sp_CreateUser, sp_Login, RBAC, RLS | `EXEC report.sp_RunAllTests` (TC-01–04) |
| inventory | sp_Restock, sp_UpdatePrice (Temporal) | `EXEC report.sp_RunAllTests` (TC-05–06) |
| sales | sp_CreateOrder, sp_ConfirmPayment, sp_RecordDispense | `EXEC report.sp_RunAllTests` (TC-07–09) |
| iot | Ngưỡng alert, Partition | `EXEC report.sp_RunAllTests` (TC-10–11) |
| report | sp_RefreshDailySummary, Views, Functions, Procs | `EXEC report.sp_RunAllTests` (TC-12) |

---

## 2. Chiến lược kiểm thử

### 2.1 Unit Test
Kiểm tra từng stored procedure / view / function độc lập, đảm bảo:
- Đầu ra đúng cột và kiểu dữ liệu khớp với `fakeDb.js` spec.
- Các lỗi nghiệp vụ ném đúng error number.

### 2.2 Integration Test
Chạy `EXEC report.sp_RunAllTests` — 12 ca kiểm thử liên module, kết quả ghi vào `report.TestResults`. Dùng `SELECT * FROM report.vw_LatestTestRun` để xem.

### 2.3 Regression Test
Chạy lại `sp_RunAllTests` sau mỗi lần merge PR vào `main`. CI/CD sẽ so sánh số PASS với lần trước.

### 2.4 Kiểm thử hiệu năng
Tiêu chí: **mỗi procedure/view phải trả kết quả ≤ 500 ms** trên dataset `09_seed_large.sql`.

---

## 3. Test Cases chi tiết

### Module auth (TC-01–04)

| ID | TestCase | Expected | Tiêu chí PASS |
|----|----------|----------|---------------|
| TC-01 | sp_CreateUser: trùng tên đăng nhập | ERROR 50003 | ERROR_NUMBER() = 50003 |
| TC-02 | sp_Login: sai 5 lần thì khóa tài khoản | LOCKED | ERROR message chứa "LOCK" hoặc "khoá" |
| TC-03 | RBAC: Operator không xem được báo cáo tài chính | 0 permission | COUNT(report_financial permission for operator) = 0 |
| TC-04 | RLS: operator01 chỉ thấy máy được giao | ≥1 machine | COUNT(UserMachineAssignment) ≥ 1 |

### Module inventory (TC-05–06)

| ID | TestCase | Expected | Tiêu chí PASS |
|----|----------|----------|---------------|
| TC-05 | sp_Restock: vượt sức chứa thì rollback | ERROR 50117 | ERROR_NUMBER() = 50117 |
| TC-06 | sp_UpdatePrice: Temporal lưu lịch sử giá | HISTORY+1 | PriceHistory tăng thêm 1 dòng |

### Module sales (TC-07–09)

| ID | TestCase | Expected | Tiêu chí PASS |
|----|----------|----------|---------------|
| TC-07 | sp_CreateOrder: không bán vượt tồn kho | ERROR 50201 | ERROR_NUMBER() = 50201 |
| TC-08 | sp_ConfirmPayment: callback trùng không ghi 2 lần | IDEMPOTENT | COUNT(Payment by GatewayTxnId) = 1 |
| TC-09 | sp_RecordDispense: kẹt 3 lần tự hoàn tiền | REFUNDED | Order.Status = 'REFUNDED' |

### Module iot (TC-10–11)

| ID | TestCase | Expected | Tiêu chí PASS |
|----|----------|----------|---------------|
| TC-10 | Ngưỡng: vượt 3 lần liên tiếp thì cảnh báo | ALERT+DEGRADED | Alert mới xuất hiện sau 3 lần RecordTelemetry |
| TC-11 | Partition: bản ghi tháng này vào partition tháng này | CORRECT PARTITION | $PARTITION trả về đúng số |

### Module report (TC-12)

| ID | TestCase | Expected | Tiêu chí PASS |
|----|----------|----------|---------------|
| TC-12 | sp_RefreshDailySummary: khớp tổng tính tay | MATCH | SUM(DailySalesSummary.Revenue) = SUM(Order.TotalAmount) |

---

## 4. Kiểm thử hiệu năng (≤ 500 ms)

Chạy trên `09_seed_large.sql` — SET STATISTICS TIME ON:

| Đối tượng | Dataset | Mục tiêu |
|-----------|---------|---------|
| `sp_DashboardKpi` | large | ≤ 500 ms |
| `sp_RevenueGrowth` | large | ≤ 500 ms |
| `sp_PeakHours` | large | ≤ 500 ms |
| `sp_ExportSales` (30 ngày) | large | ≤ 500 ms |
| `vw_ProductRanking` | large | ≤ 500 ms |
| `vw_ColdChainCompliance` | large | ≤ 500 ms |
| `fn_RevenueByLocation` (1 tháng) | large | ≤ 500 ms |

---

## 5. Tiêu chí chấp nhận tổng thể

- **Unit tests:** 12/12 TC PASS.
- **Hiệu năng:** Tất cả objects ≤ 500 ms trên large dataset.
- **Views:** `SELECT TOP 100 * FROM report.vw_ProductRanking` trả đúng cột `RankInLocation`, `SharePercent`.
- **sp_RunAllTests:** `Passed = 1` cho tất cả 12 dòng trong `report.vw_LatestTestRun`.
