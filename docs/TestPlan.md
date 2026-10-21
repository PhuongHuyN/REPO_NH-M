# TestPlan — Kế hoạch Kiểm thử

> **Dự án:** FreshVend  
> **Phiên bản:** 0.1 (draft)  
> **Ngày:** 2026-10-21  

---

## 1. Phạm vi kiểm thử

| Module | Script kiểm thử |
|--------|-----------------|
| auth | tests/test_auth.sql |
| inventory | tests/test_inventory.sql |
| sales | tests/test_sales.sql |
| iot | tests/test_iot.sql |
| report | tests/test_reports.sql |

## 2. Chiến lược kiểm thử

- **Unit test:** Kiểm tra từng stored procedure / function độc lập.
- **Integration test:** Kiểm tra luồng mua hàng end-to-end (auth → inventory → sales → audit).
- **Regression test:** Chạy lại sau mỗi thay đổi lớn.

## 3. Tiêu chí chấp nhận

*(Điền điều kiện pass/fail cho từng test case…)*

## 4. Lịch kiểm thử

*(Điền thời gian dự kiến…)*
