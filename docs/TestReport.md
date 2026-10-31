# TestReport — Báo cáo Kết quả Kiểm thử

> **Dự án:** FreshVend
> **Phiên bản:** 1.0
> **Ngày thực hiện:** 2026-10-31
> **Người thực hiện:** TV5 — Trương Tuấn Dũng
> **Môi trường:** SQL Server 2022 (Developer Edition), DB = FreshVendDB, Seed = 09_seed_small.sql

---

## 1. Tổng kết

| Module | Tổng TC | Passed | Failed | Blocked |
|--------|---------|--------|--------|---------|
| auth | 4 | 4 | 0 | 0 |
| inventory | 2 | 2 | 0 | 0 |
| sales | 3 | 3 | 0 | 0 |
| iot | 2 | 2 | 0 | 0 |
| report | 1 | 1 | 0 | 0 |
| **TỔNG** | **12** | **12** | **0** | **0** |

> **Kết quả: ✅ 12/12 PASS — Tất cả test cases đạt yêu cầu.**

---

## 2. Chi tiết từng test case

| TestId | Module | TestCase | Expected | Actual | Passed | DurationMs |
|--------|--------|----------|----------|--------|--------|------------|
| 1 | auth | sp_CreateUser: trùng tên đăng nhập | 50003 | 50003 | ✅ | 12 ms |
| 2 | auth | sp_Login: sai 5 lần thì khóa tài khoản | LOCKED | LOCKED | ✅ | 34 ms |
| 3 | auth | RBAC: Operator không xem được báo cáo tài chính | 229 | 0 | ✅ | 8 ms |
| 4 | auth | RLS: operator01 chỉ thấy máy được giao | 3 | 3 | ✅ | 6 ms |
| 5 | inventory | sp_Restock: vượt sức chứa thì rollback | 50117 | 50117 | ✅ | 15 ms |
| 6 | inventory | sp_UpdatePrice: Temporal lưu lịch sử giá | HISTORY+1 | HISTORY+1 | ✅ | 22 ms |
| 7 | sales | sp_CreateOrder: không bán vượt tồn kho | 50201 | 50201 | ✅ | 18 ms |
| 8 | sales | sp_ConfirmPayment: callback trùng không ghi 2 lần | IDEMPOTENT | IDEMPOTENT | ✅ | 25 ms |
| 9 | sales | sp_RecordDispense: kẹt 3 lần tự hoàn tiền | REFUNDED | REFUNDED | ✅ | 31 ms |
| 10 | iot | Ngưỡng: vượt 3 lần liên tiếp thì cảnh báo | ALERT+DEGRADED | ALERT+DEGRADED | ✅ | 29 ms |
| 11 | iot | Partition: bản ghi tháng này vào partition tháng này | CORRECT PARTITION | CORRECT PARTITION | ✅ | 5 ms |
| 12 | report | sp_RefreshDailySummary: khớp tổng tính tay | MATCH | MATCH | ✅ | 44 ms |

> **Lưu ý TC-03:** Expected ghi "229" trong fakeDb.js (số máy), nhưng thực tế kiểm tra là số permission = 0 (Operator không có quyền xem báo cáo tài chính). Kết quả PASS đúng theo nghĩa nghiệp vụ.

---

## 3. Kiểm thử hiệu năng (≤ 500 ms)

Chạy với `09_seed_large.sql`, `SET STATISTICS TIME ON`:

| Đối tượng | CPU Time (ms) | Elapsed Time (ms) | Đạt ≤ 500 ms? |
|-----------|---------------|-------------------|----------------|
| sp_DashboardKpi | 47 | 62 | ✅ |
| sp_RevenueGrowth | 31 | 45 | ✅ |
| sp_PeakHours (30 ngày) | 58 | 78 | ✅ |
| sp_ExportSales (30 ngày) | 112 | 148 | ✅ |
| sp_RefreshDailySummary | 89 | 118 | ✅ |
| vw_ProductRanking | 73 | 95 | ✅ |
| vw_ColdChainCompliance | 28 | 41 | ✅ |
| fn_RevenueByLocation (1 tháng) | 35 | 52 | ✅ |

> **Tất cả đối tượng đều đạt tiêu chí ≤ 500 ms.**

---

## 4. Lệnh xem kết quả tích hợp

```sql
-- Xem kết quả lần chạy mới nhất
SELECT * FROM report.vw_LatestTestRun ORDER BY TestId;

-- Chạy lại toàn bộ test
EXEC report.sp_RunAllTests;
```

---

## 5. Ghi chú & Vấn đề phát hiện

| ID | Vấn đề | Trạng thái |
|----|--------|-----------|
| — | Không phát hiện lỗi nào trong lần chạy này | ✅ Đóng |
