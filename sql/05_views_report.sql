-- =============================================================================
-- FILE        : 05_views_report.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV5 — Views thuộc schema [report]
--               1. report.vw_ProductRanking   — RANK() doanh thu theo địa điểm
--               2. report.vw_ColdChainCompliance — % tuân thủ nhiệt độ cold-chain
--               3. report.vw_LatestTestRun    — Kết quả lần chạy test mới nhất
-- VERSION     : 1.0.0
-- CREATED     : 2026-10-31
-- AUTHOR      : TV5
-- RUN ORDER   : Bước 4 — sau 04_indexes.sql (bảng đã tồn tại đủ)
-- DEPENDS ON  : report.TestResults (02_tables_report.sql)
--               iot.HourlyAggregate, inventory.Machine, inventory.Location
--               sales.Order, sales.OrderItem, inventory.Stock, inventory.Batch
--               inventory.Product
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 1. report.vw_ProductRanking
-- =============================================================================
-- Xếp hạng doanh thu sản phẩm theo từng địa điểm (RANK() OVER PARTITION BY).
-- Cột RankInLocation: 1 = bán chạy nhất tại địa điểm đó.
-- Cột SharePercent  : % doanh thu sản phẩm trên tổng doanh thu địa điểm.
-- Chỉ tính đơn trạng thái PAID hoặc DISPENSED.

IF OBJECT_ID(N'report.vw_ProductRanking', N'V') IS NOT NULL
BEGIN
    DROP VIEW report.vw_ProductRanking;
    PRINT N'[05-views-report] Đã xoá view cũ report.vw_ProductRanking.';
END
GO

CREATE VIEW report.vw_ProductRanking
WITH SCHEMABINDING
AS
WITH SalesByLocProduct AS (
    -- Tổng hợp doanh thu theo (LocationId, ProductId)
    SELECT
        l.LocationId,
        l.LocationName,
        p.ProductId,
        p.ProductName,
        SUM(oi.Qty)                              AS QtySold,
        SUM(CAST(oi.Qty AS DECIMAL(18,2))
            * oi.UnitPrice)                      AS Revenue
    FROM sales.[Order]          o
    JOIN sales.OrderItem        oi  ON oi.OrderId    = o.OrderId
    JOIN inventory.Stock        st  ON st.StockId    = oi.StockId
    JOIN inventory.Batch        b   ON b.BatchId     = st.BatchId
    JOIN inventory.Product      p   ON p.ProductId   = b.ProductId
    JOIN inventory.Machine      m   ON m.MachineId   = o.MachineId
    JOIN inventory.Location     l   ON l.LocationId  = m.LocationId
    WHERE o.Status IN (N'PAID', N'DISPENSED')
    GROUP BY
        l.LocationId, l.LocationName,
        p.ProductId,  p.ProductName
),
LocTotal AS (
    -- Tổng doanh thu toàn bộ địa điểm (để tính SharePercent)
    SELECT LocationId, SUM(Revenue) AS TotalRevenue
    FROM   SalesByLocProduct
    GROUP BY LocationId
)
SELECT
    s.LocationId,
    s.LocationName,
    s.ProductId,
    s.ProductName,
    s.QtySold,
    s.Revenue,
    -- RANK: bằng nhau thì cùng rank, bỏ qua số thứ tự tiếp theo
    RANK() OVER (
        PARTITION BY s.LocationId
        ORDER BY s.Revenue DESC
    )                                            AS RankInLocation,
    -- Phần trăm đóng góp doanh thu
    CAST(
        ROUND(s.Revenue * 100.0 / NULLIF(t.TotalRevenue, 0), 2)
    AS DECIMAL(8,2))                             AS SharePercent
FROM SalesByLocProduct  s
JOIN LocTotal           t ON t.LocationId = s.LocationId;
GO

PRINT N'[05-views-report] View report.vw_ProductRanking đã tạo thành công.';
GO

-- =============================================================================
-- 2. report.vw_ColdChainCompliance
-- =============================================================================
-- Tỷ lệ tuân thủ nhiệt độ cold-chain theo từng máy.
-- CompliancePercent = 100 - (MinutesOutOfRange / (HoursMonitored * 60)) * 100
-- Nguồn dữ liệu: iot.HourlyAggregate (được nạp bởi sp_AggregateHourly).

IF OBJECT_ID(N'report.vw_ColdChainCompliance', N'V') IS NOT NULL
BEGIN
    DROP VIEW report.vw_ColdChainCompliance;
    PRINT N'[05-views-report] Đã xoá view cũ report.vw_ColdChainCompliance.';
END
GO

CREATE VIEW report.vw_ColdChainCompliance
AS
SELECT
    m.MachineId,
    m.Serial,
    m.MachineName,
    l.LocationName,
    COUNT(h.HourId)                             AS HoursMonitored,
    SUM(h.MinutesOutOfRange)                    AS MinutesOutOfRange,
    MIN(h.MinTemp)                              AS MinTemp,
    MAX(h.MaxTemp)                              AS MaxTemp,
    CAST(
        ROUND(
            AVG(CAST(h.AvgTemp AS FLOAT))
        , 2)
    AS DECIMAL(8,2))                            AS AvgTemp,
    -- CompliancePercent: NULL nếu chưa có dữ liệu
    CASE
        WHEN COUNT(h.HourId) = 0 THEN NULL
        ELSE CAST(
            ROUND(
                100.0 - SUM(h.MinutesOutOfRange) * 100.0
                      / (COUNT(h.HourId) * 60)
            , 2)
        AS DECIMAL(8,2))
    END                                         AS CompliancePercent
FROM inventory.Machine          m
JOIN inventory.Location         l   ON l.LocationId  = m.LocationId
LEFT JOIN iot.HourlyAggregate   h   ON h.MachineId   = m.MachineId
GROUP BY
    m.MachineId,
    m.Serial,
    m.MachineName,
    l.LocationName;
GO

PRINT N'[05-views-report] View report.vw_ColdChainCompliance đã tạo thành công.';
GO

-- =============================================================================
-- 3. report.vw_LatestTestRun
-- =============================================================================
-- Hiển thị toàn bộ kết quả của lần chạy test mới nhất (RunId mới nhất).
-- Dùng để xem nhanh tình trạng regression mà không cần filter thủ công.

IF OBJECT_ID(N'report.vw_LatestTestRun', N'V') IS NOT NULL
BEGIN
    DROP VIEW report.vw_LatestTestRun;
    PRINT N'[05-views-report] Đã xoá view cũ report.vw_LatestTestRun.';
END
GO

CREATE VIEW report.vw_LatestTestRun
AS
WITH LatestBatch AS (
    -- Tìm BatchId của lần chạy mới nhất
    SELECT TOP 1 BatchId
    FROM   report.TestResults
    ORDER BY RunAt DESC
)
SELECT
    tr.TestId,
    tr.Module,
    tr.TestCase,
    tr.Expected,
    tr.Actual,
    tr.ErrorDetail,
    tr.Passed,
    tr.DurationMs,
    tr.RunBy,
    tr.RunAt,
    tr.BatchId
FROM report.TestResults tr
WHERE tr.BatchId = (SELECT BatchId FROM LatestBatch);
GO

PRINT N'[05-views-report] View report.vw_LatestTestRun đã tạo thành công.';
GO

-- =============================================================================
-- XÁC NHẬN KẾT QUẢ
-- =============================================================================

SELECT
    v.TABLE_SCHEMA  AS [Schema],
    v.TABLE_NAME    AS [View],
    v.VIEW_DEFINITION AS [Definition (snippet)]
FROM INFORMATION_SCHEMA.VIEWS v
WHERE v.TABLE_SCHEMA = N'report'
ORDER BY v.TABLE_NAME;
GO

PRINT N'';
PRINT N'================================================================';
PRINT N'  05_views_report.sql hoàn tất. Tiếp theo: 06_functions_report.sql';
PRINT N'================================================================';
GO
