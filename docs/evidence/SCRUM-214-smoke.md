# SCRUM-214 – Kết quả chạy app với SQL Server thật

- Thời điểm: 16:23:32 12/11/2026
- API: http://localhost:3000 — /api/health: 200 {"status":"ok","db":{"ok":true,"mode":"sqlserver","db":"FreshVendDB","now":"2026-11-12T09:23:32.253Z","version":"Microsoft SQL Server 2025 (RTM) - 17.0.1000.7 (X64) \n\tOct 21 2025 12:05:57 \n\tCopyri
- Lệnh: `node tools/smoke-sqlserver.js` (chỉ đọc, không ghi dữ liệu)

## Tổng hợp theo module

| Module | Đạt | Lỗi |
|---|---|---|
| auth | 4/6 | 2 |
| inventory | 6/6 | 0 |
| sales | 3/4 | 1 |
| iot | 0/4 | 4 |
| report | 4/4 | 0 |
| security | 2/2 | 0 |

## Chi tiết

| # | Module | Vai trò | API | Mong đợi | Thực tế | Kết quả | Ghi chú |
|---|---|---|---|---|---|---|---|
| 1 | auth | Admin | POST /api/auth/login (admin) | 200 | 200 | ĐẠT | Đăng nhập (auth.sp_Login qua login fv_kiosk_app) — OK |
| 2 | auth | Operator | POST /api/auth/login (operator01) | 200 | 200 | ĐẠT | Đăng nhập (auth.sp_Login qua login fv_kiosk_app) — OK |
| 3 | auth | Kiosk | POST /api/auth/login (kiosk01) | 200 | 200 | ĐẠT | Đăng nhập (auth.sp_Login qua login fv_kiosk_app) — OK |
| 4 | auth | Admin | GET /api/auth/me | 200 | 200 | ĐẠT | Thông tin tài khoản đang đăng nhập — OK |
| 5 | auth | Admin | GET /api/auth/users | 200 | 500 | **LỖI** | Danh sách người dùng (auth.vw_UserPermissions) — INTERNAL Lỗi máy chủ: Invalid object name 'auth.vw_UserPermissions'. |
| 6 | auth | Admin | GET /api/auth/login-activity | 200 | 500 | **LỖI** | Thống kê đăng nhập (audit.vw_LoginActivity) — INTERNAL Lỗi máy chủ: Invalid object name 'audit.vw_LoginActivity'. |
| 7 | inventory | Admin | GET /api/inventory/products | 200 | 200 | ĐẠT | Danh mục sản phẩm (vw_ProductCatalog) — 36 dòng |
| 8 | inventory | Admin | GET /api/inventory/products/1/price-history | 200 | 200 | ĐẠT | Lịch sử giá (fn_PriceHistory) — 1 dòng |
| 9 | inventory | Admin | GET /api/inventory/stock | 200 | 200 | ĐẠT | Tồn kho theo cột (vw_StockStatus) — 60 dòng |
| 10 | inventory | Admin | GET /api/inventory/batches | 200 | 200 | ĐẠT | Lô còn châm được (vw_AvailableBatches) — 35 dòng |
| 11 | inventory | Admin | GET /api/inventory/expiring | 200 | 200 | ĐẠT | Hàng sắp/đã hết hạn (vw_ExpiringBatches) — 18 dòng |
| 12 | inventory | Operator | GET /api/inventory/stock | 200 | 200 | ĐẠT | Operator xem tồn kho (RLS: chỉ máy được giao) — 36 dòng |
| 13 | sales | Admin | GET /api/orders | 200 | 200 | ĐẠT | Danh sách đơn (vw_OrderDetail) — 0 dòng |
| 14 | sales | Admin | GET /api/orders/pending | 200 | 200 | ĐẠT | Đơn chờ thanh toán (vw_PendingOrders) — 0 dòng |
| 15 | sales | Kiosk | GET /api/kiosk/menu | 200 | 500 | **LỖI** | Thực đơn kiosk (vw_StockStatus + vw_MachineHealth) — INTERNAL Lỗi máy chủ: Invalid object name 'iot.vw_MachineHealth'. |
| 16 | sales | Kiosk | GET /api/dispense-queue | 200 | 200 | ĐẠT | Hàng chờ nhả (vw_DispenseQueue) — 0 dòng |
| 17 | iot | Admin | GET /api/iot/machines | 200 | 500 | **LỖI** | Sức khỏe máy (vw_MachineHealth) — INTERNAL Lỗi máy chủ: Invalid object name 'iot.vw_MachineHealth'. |
| 18 | iot | Admin | GET /api/iot/alerts | 200 | 500 | **LỖI** | Cảnh báo đang mở (vw_OpenAlerts) — INTERNAL Lỗi máy chủ: Invalid object name 'iot.vw_OpenAlerts'. |
| 19 | iot | Admin | GET /api/iot/machines/1/telemetry | 200 | 500 | **LỖI** | Cảm biến 6 giờ (fn_RecentTelemetry) — INTERNAL Lỗi máy chủ: Invalid object name 'iot.fn_RecentTelemetry'. |
| 20 | iot | Operator | GET /api/iot/machines | 200 | 500 | **LỖI** | Operator xem máy (RLS) — INTERNAL Lỗi máy chủ: Invalid object name 'iot.vw_MachineHealth'. |
| 21 | report | Admin | GET /api/reports/kpi | 200 | 200 | ĐẠT | KPI dashboard (sp_DashboardKpi) — OK |
| 22 | report | Admin | GET /api/reports/ranking | 200 | 200 | ĐẠT | Xếp hạng sản phẩm (vw_ProductRanking) — 0 dòng |
| 23 | report | Admin | GET /api/reports/cold-chain | 200 | 200 | ĐẠT | Chuỗi lạnh (vw_ColdChainCompliance) — 0 dòng |
| 24 | report | Admin | GET /api/reports/test-results | 200 | 200 | ĐẠT | Kết quả test gần nhất (vw_LatestTestRun) — 33 dòng |
| 25 | security | Operator | GET /api/reports/kpi | 403 | 403 | ĐẠT | Operator KHÔNG được xem báo cáo tài chính — OK |
| 26 | security | Kiosk | GET /api/inventory/products | 403 | 403 | ĐẠT | Kiosk KHÔNG được vào quản lý sản phẩm — OK |

**Tổng: 19/26 đạt.**
