-- SCRUM 37. Run after 02_tables_report.sql and 04_report_dependencies.sql.
USE FreshVendDB;
GO
CREATE OR ALTER FUNCTION report.fn_RevenueByLocation(@From DATE,@To DATE)
RETURNS TABLE
AS RETURN (
    SELECT l.LocationId,l.LocationName,CAST(NULL AS NVARCHAR(50)) LocationType,
           CAST(NULL AS NVARCHAR(100)) District,COUNT(DISTINCT o.MachineId) Machines,
           COUNT(DISTINCT o.OrderId) Orders,SUM(CONVERT(BIGINT,i.Quantity)) QtySold,
           SUM(i.LineTotal) Revenue
    FROM sales.[Order] o JOIN sales.OrderItem i ON i.OrderId=o.OrderId
    JOIN inventory.Machine m ON m.MachineId=o.MachineId
    JOIN inventory.Locations l ON l.LocationId=m.LocationId
    WHERE o.Status=N'paid' AND @From<=@To
      AND o.CreatedAt>=DATEADD(HOUR,-7,CONVERT(DATETIME2,@From))
      AND o.CreatedAt<DATEADD(HOUR,17,CONVERT(DATETIME2,@To))
    GROUP BY l.LocationId,l.LocationName
);
GO
-- Ratio in [0,1], not percentage. <0.02 means below 2%.
-- Denominator = physical attempts; JAM is counted even when a retry succeeds.
-- NULL means unknown machine or no attempts; it does not mean 0% failure.
CREATE OR ALTER FUNCTION report.fn_DispenseFailureRate(@MachineId INT)
RETURNS DECIMAL(12,6)
AS
BEGIN
    DECLARE @Rate DECIMAL(12,6);
    SELECT @Rate=CONVERT(DECIMAL(12,6),SUM(CONVERT(BIGINT,CASE WHEN a.Result=N'JAM' THEN 1 ELSE 0 END))*1.0/NULLIF(COUNT_BIG(*),0))
    FROM sales.DispenseAttempts a JOIN sales.OrderItem i ON i.OrderItemId=a.OrderItemId
    JOIN sales.[Order] o ON o.OrderId=i.OrderId WHERE o.MachineId=@MachineId;
    RETURN @Rate;
END;
GO
CREATE OR ALTER VIEW report.vw_ProductRanking
AS
WITH Sales AS (
    SELECT l.LocationId,l.LocationName,p.ProductId,p.ProductName,
           SUM(CONVERT(BIGINT,i.Quantity)) QtySold,SUM(i.LineTotal) Revenue
    FROM sales.[Order] o JOIN sales.OrderItem i ON i.OrderId=o.OrderId
    JOIN inventory.Product p ON p.ProductId=i.ProductId
    JOIN inventory.Machine m ON m.MachineId=o.MachineId
    JOIN inventory.Locations l ON l.LocationId=m.LocationId
    WHERE o.Status=N'paid' GROUP BY l.LocationId,l.LocationName,p.ProductId,p.ProductName
)
SELECT *,RANK() OVER(PARTITION BY LocationId ORDER BY Revenue DESC) RankInLocation,
       CONVERT(DECIMAL(8,2),100.0*Revenue/NULLIF(SUM(Revenue) OVER(PARTITION BY LocationId),0)) SharePercent
FROM Sales;
GO
-- Coverage is measured observed time, not a count of rows/hours.
-- Unknown/unobserved time is excluded. No data => NULL compliance.
CREATE OR ALTER VIEW report.vw_ColdChainCompliance
AS
SELECT m.MachineId,m.MachineCode AS Serial,m.MachineName,l.LocationName,
       COUNT(h.HourStart) HoursMonitored,SUM(h.MonitoredSeconds) MonitoredSeconds,
       SUM(h.InRangeSeconds) InRangeSeconds,
       CONVERT(DECIMAL(12,2),SUM(h.MonitoredSeconds-h.InRangeSeconds)/60.0) MinutesOutOfRange,
       MIN(h.MinTemp) MinTemp,MAX(h.MaxTemp) MaxTemp,
       CONVERT(DECIMAL(8,2),SUM(h.TemperatureSeconds)/NULLIF(SUM(h.MonitoredSeconds),0)) AvgTemp,
       CONVERT(DECIMAL(8,2),100.0*SUM(h.InRangeSeconds)/NULLIF(SUM(h.MonitoredSeconds),0)) CompliancePercent
FROM inventory.Machine m LEFT JOIN inventory.Locations l ON l.LocationId=m.LocationId
LEFT JOIN iot.TelemetryHourly h ON h.MachineId=m.MachineId
GROUP BY m.MachineId,m.MachineCode,m.MachineName,l.LocationName;
GO
CREATE OR ALTER VIEW report.vw_LatestTestRun
AS
SELECT t.* FROM report.TestResults t WHERE t.BatchId=(
    SELECT TOP(1) BatchId FROM report.TestResults ORDER BY RunAt DESC,TestId DESC
);
GO
