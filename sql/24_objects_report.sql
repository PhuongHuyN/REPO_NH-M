-- SCRUM-209: read the owner-provided tables; no cross-module DDL.
USE FreshVendDB;
GO
CREATE OR ALTER FUNCTION report.fn_RevenueByLocation(@From DATE,@To DATE)
RETURNS TABLE
AS RETURN (
    SELECT l.LocationId,l.LocationName,l.LocationType,l.District,COUNT(DISTINCT o.MachineId) Machines,
           COUNT_BIG(*) Orders,SUM(q.QtySold) QtySold,SUM(o.TotalAmount) Revenue
    FROM sales.[Order] o
    JOIN (SELECT OrderId,SUM(CONVERT(BIGINT,Quantity)) QtySold FROM sales.OrderItem GROUP BY OrderId) q ON q.OrderId=o.OrderId
    JOIN iot.Machines m ON m.MachineId=o.MachineId
    JOIN iot.Locations l ON l.LocationId=m.LocationId
    WHERE o.Status IN(N'PAID',N'DISPENSED') AND @From<=@To
      AND o.CreatedAt>=DATEADD(HOUR,-7,CONVERT(DATETIME2,@From))
      AND o.CreatedAt<DATEADD(HOUR,17,CONVERT(DATETIME2,@To))
    GROUP BY l.LocationId,l.LocationName,l.LocationType,l.District
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
    FROM sales.DispenseEvents a JOIN sales.OrderItem i ON i.OrderItemId=a.OrderItemId
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
    JOIN iot.Machines m ON m.MachineId=o.MachineId
    JOIN iot.Locations l ON l.LocationId=m.LocationId
    WHERE o.Status IN(N'PAID',N'DISPENSED') GROUP BY l.LocationId,l.LocationName,p.ProductId,p.ProductName
)
SELECT *,RANK() OVER(PARTITION BY LocationId ORDER BY Revenue DESC) RankInLocation,
       CONVERT(DECIMAL(8,2),100.0*Revenue/NULLIF(SUM(Revenue) OVER(PARTITION BY LocationId),0)) SharePercent
FROM Sales;
GO
-- Owner contract: each hourly row represents 60 minutes. Missing hours are unknown.
-- MinutesOutOfRange must be an elapsed duration 0..60 (not a sample count).
-- Invalid duration => NULL compliance; report never silently clamps upstream errors.
CREATE OR ALTER VIEW report.vw_ColdChainCompliance
AS
SELECT m.MachineId,m.Serial,m.MachineName,l.LocationName,
       COUNT(h.HourStart) HoursMonitored,CONVERT(BIGINT,COUNT(h.HourStart))*3600 MonitoredSeconds,
       SUM(CONVERT(BIGINT,60-h.MinutesOutOfRange))*60 InRangeSeconds,
       SUM(h.MinutesOutOfRange) MinutesOutOfRange,
       MIN(h.MinTemp) MinTemp,MAX(h.MaxTemp) MaxTemp,
       CONVERT(DECIMAL(8,2),AVG(h.AvgTemp)) AvgTemp,
       CASE WHEN COUNT(h.HourStart)=0 OR COUNT(h.MinutesOutOfRange)<>COUNT(h.HourStart)
              OR MIN(h.MinutesOutOfRange)<0 OR MAX(h.MinutesOutOfRange)>60 THEN NULL
            ELSE CONVERT(DECIMAL(8,2),100.0-100.0*SUM(CONVERT(BIGINT,h.MinutesOutOfRange))/(COUNT_BIG(h.HourStart)*60)) END CompliancePercent
FROM iot.Machines m LEFT JOIN iot.Locations l ON l.LocationId=m.LocationId
LEFT JOIN iot.TelemetryHourly h ON h.MachineId=m.MachineId
GROUP BY m.MachineId,m.Serial,m.MachineName,l.LocationName;
GO
CREATE OR ALTER VIEW report.vw_LatestTestRun
AS
SELECT t.* FROM report.TestResults t WHERE t.BatchId=(
    SELECT TOP(1) BatchId FROM report.TestResults ORDER BY RunAt DESC,TestId DESC
);
GO
