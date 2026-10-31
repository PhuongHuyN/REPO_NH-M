-- =============================================================================
-- FILE        : 06_functions_report.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV5 — Table-valued function thuộc schema [report]
--               1. report.fn_RevenueByLocation(@From DATE, @To DATE)
--                  → Doanh thu tổng hợp theo từng địa điểm trong khoảng thời gian
-- VERSION     : 1.0.0
-- CREATED     : 2026-10-31
-- AUTHOR      : TV5
-- RUN ORDER   : Bước 4 — sau 05_views_report.sql
-- DEPENDS ON  : sales.Order, sales.OrderItem, inventory.Machine,
--               inventory.Location, inventory.Stock
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 1. report.fn_RevenueByLocation
-- =============================================================================
-- Inline Table-Valued Function (iTVF) — hiệu năng cao, không có BEGIN/END.
-- Tham số:
--   @From DATE  — ngày bắt đầu (tính cả ngày này)
--   @To   DATE  — ngày kết thúc (tính cả ngày này)
-- Trả về một bảng có các cột:
--   LocationId, LocationName, LocationType, District,
--   Machines (số máy phân biệt có đơn), Orders, QtySold, Revenue
--
-- Ví dụ sử dụng:
--   SELECT * FROM report.fn_RevenueByLocation('2026-10-01', '2026-10-31')
--   ORDER BY Revenue DESC;

IF OBJECT_ID(N'report.fn_RevenueByLocation', N'IF') IS NOT NULL
BEGIN
    DROP FUNCTION report.fn_RevenueByLocation;
    PRINT N'[06-functions-report] Đã xoá function cũ report.fn_RevenueByLocation.';
END
GO

CREATE FUNCTION report.fn_RevenueByLocation
(
    @From   DATE,
    @To     DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        l.LocationId,
        l.LocationName,
        l.LocationType,
        l.District,
        -- Số máy phân biệt có phát sinh đơn hàng trong khoảng thời gian
        COUNT(DISTINCT o.MachineId)             AS Machines,
        COUNT(DISTINCT o.OrderId)               AS Orders,
        -- Tổng số lượng sản phẩm bán ra
        SUM(oi.Qty)                             AS QtySold,
        -- Tổng doanh thu
        SUM(CAST(oi.Qty AS DECIMAL(18,2))
            * oi.UnitPrice)                     AS Revenue
    FROM sales.[Order]      o
    JOIN sales.OrderItem    oi  ON oi.OrderId   = o.OrderId
    JOIN inventory.Machine  m   ON m.MachineId  = o.MachineId
    JOIN inventory.Location l   ON l.LocationId = m.LocationId
    WHERE
        o.Status IN (N'PAID', N'DISPENSED')
        -- Lọc theo ngày tạo đơn (cột DATETIME2, cast về DATE để so sánh)
        AND CAST(o.CreatedAt AT TIME ZONE N'UTC'
                              AT TIME ZONE N'SE Asia Standard Time'
                 AS DATE) >= @From
        AND CAST(o.CreatedAt AT TIME ZONE N'UTC'
                              AT TIME ZONE N'SE Asia Standard Time'
                 AS DATE) <= @To
    GROUP BY
        l.LocationId,
        l.LocationName,
        l.LocationType,
        l.District
);
GO

PRINT N'[06-functions-report] Function report.fn_RevenueByLocation đã tạo thành công.';
GO

-- =============================================================================
-- SMOKE TEST (chạy thử — comment ra khi không cần)
-- =============================================================================
-- DECLARE @from DATE = CAST(GETDATE() AS DATE),
--         @to   DATE = CAST(GETDATE() AS DATE);
-- SELECT * FROM report.fn_RevenueByLocation(@from, @to) ORDER BY Revenue DESC;

-- =============================================================================
-- XÁC NHẬN KẾT QUẢ
-- =============================================================================

SELECT
    r.ROUTINE_SCHEMA    AS [Schema],
    r.ROUTINE_NAME      AS [Function],
    r.ROUTINE_TYPE      AS [Type],
    r.DATA_TYPE         AS [Return Type]
FROM INFORMATION_SCHEMA.ROUTINES r
WHERE r.ROUTINE_SCHEMA = N'report'
  AND r.ROUTINE_TYPE   = N'FUNCTION'
ORDER BY r.ROUTINE_NAME;
GO

PRINT N'';
PRINT N'================================================================';
PRINT N'  06_functions_report.sql hoàn tất. Tiếp theo: 07_procs_report.sql';
PRINT N'================================================================';
GO
