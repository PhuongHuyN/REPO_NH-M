USE FreshVendDB;
GO
SET NOCOUNT ON;
-- Unit error/valid branches for all six report procedures, results persisted.
EXEC report.sp_RunAllTests @RunBy=N'TV5 acceptance';
IF EXISTS(SELECT 1 FROM report.vw_LatestTestRun WHERE Passed=0) THROW 50491,N'Procedure suite failed',1;
IF (SELECT COUNT(*) FROM report.vw_LatestTestRun)<>21 THROW 50491,N'Missing procedure test cases',1;
-- Revenue functions: full range, empty range and reversed range.
IF (SELECT SUM(Revenue) FROM report.fn_RevenueByLocation('20260806','20261103'))<>
   (SELECT SUM(i.LineTotal) FROM sales.[Order] o JOIN sales.OrderItem i ON i.OrderId=o.OrderId WHERE o.Status=N'paid')
 THROW 50491,N'Location revenue mismatch',1;
IF EXISTS(SELECT 1 FROM report.fn_RevenueByLocation('20270101','20270102')) THROW 50491,N'Empty range returned revenue',1;
IF EXISTS(SELECT 1 FROM report.fn_RevenueByLocation('20261103','20260806')) THROW 50491,N'Reversed range returned revenue',1;
IF report.fn_DispenseFailureRate(-1) IS NOT NULL THROW 50491,N'Unknown machine must return NULL',1;
DECLARE @m INT=(SELECT MachineId FROM inventory.Machine WHERE MachineCode=N'TV5-M-002');
DECLARE @expected DECIMAL(12,6);
SELECT @expected=SUM(CASE WHEN a.Result=N'JAM' THEN 1.0 ELSE 0 END)/COUNT_BIG(*)
FROM sales.DispenseAttempts a JOIN sales.OrderItem i ON i.OrderItemId=a.OrderItemId JOIN sales.[Order] o ON o.OrderId=i.OrderId WHERE o.MachineId=@m;
IF report.fn_DispenseFailureRate(@m)<>@expected THROW 50491,N'Failure ratio mismatch',1;
-- Seed mixes physical jams; a whole-fleet rate is the acceptance criterion.
IF (SELECT SUM(CASE WHEN Result=N'JAM' THEN 1.0 ELSE 0 END)/COUNT_BIG(*) FROM sales.DispenseAttempts)>=0.02
 THROW 50491,N'Fleet jam rate must be below 2 percent',1;
-- Ranking ordering and total shares.
IF EXISTS(SELECT LocationId FROM report.vw_ProductRanking GROUP BY LocationId HAVING ABS(SUM(SharePercent)-100)>0.15)
 THROW 50491,N'Ranking share mismatch',1;
IF EXISTS(SELECT 1 FROM report.vw_ProductRanking a JOIN report.vw_ProductRanking b ON a.LocationId=b.LocationId
 WHERE a.Revenue>b.Revenue AND a.RankInLocation>=b.RankInLocation) THROW 50491,N'Ranking order mismatch',1;
-- Controlled boundary/tie/time-weighted/no-data cases are rolled back.
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 DECLARE @u INT=(SELECT UserId FROM auth.[User] WHERE Username=N'admin01');
 INSERT inventory.Machine(MachineCode,MachineName,LocationId) VALUES(N'TV5-TEST-EMPTY',N'No samples',NULL);
 DECLARE @empty INT=SCOPE_IDENTITY();
 IF report.fn_DispenseFailureRate(@empty) IS NOT NULL THROW 50491,N'No-attempt machine must return NULL',1;
 IF EXISTS(SELECT 1 FROM report.vw_ColdChainCompliance WHERE MachineId=@empty AND CompliancePercent IS NOT NULL) THROW 50491,N'No telemetry must return NULL',1;
 INSERT iot.Device(DeviceCode,MachineId,DeviceType) VALUES(N'TV5-TEST-DEVICE',@empty,N'ESP32');
 DECLARE @d INT=SCOPE_IDENTITY();
 INSERT iot.Telemetry(DeviceId,Payload,ReceivedAt) VALUES
 (@d,N'{"t":2,"durationSeconds":30}','2026-11-01T00:00:00'),
 (@d,N'{"t":8,"durationSeconds":90}','2026-11-01T00:02:00'),
 (@d,N'{"t":8.001,"durationSeconds":120}','2026-11-01T00:04:00'),
 (@d,N'{"t":4}','2026-11-01T00:07:00'),
 (@d,N'invalid json','2026-11-01T00:08:00');
 EXEC report.sp_RefreshTelemetryHourly '20261101','20261101';
 IF NOT EXISTS(SELECT 1 FROM report.vw_ColdChainCompliance WHERE MachineId=@empty AND MonitoredSeconds=240 AND InRangeSeconds=120 AND CompliancePercent=50)
 THROW 50491,N'Cold-chain boundary/time weighting failed',1;
 -- Tied revenues must share rank 1 (RANK, not ROW_NUMBER).
 INSERT inventory.Locations(LocationCode,LocationName) VALUES(N'TV5-TEST-L',N'Tie fixture');
 DECLARE @loc INT=SCOPE_IDENTITY();
 UPDATE inventory.Machine SET LocationId=@loc WHERE MachineId=@empty;
 DECLARE @p1 INT=(SELECT ProductId FROM inventory.Product WHERE SKU=N'TV5-P-001'),@p2 INT=(SELECT ProductId FROM inventory.Product WHERE SKU=N'TV5-P-002');
 INSERT inventory.Slot(MachineId,SlotCode,ProductId,Capacity) VALUES(@empty,N'T1',@p1,10),(@empty,N'T2',@p2,10);
 INSERT sales.[Order](OrderCode,MachineId,Subtotal,TotalAmount,Status,CreatedAt) VALUES(N'TV5-TEST-TIE',@empty,200000000,200000000,N'paid','20261101');
 DECLARE @o BIGINT=SCOPE_IDENTITY();
 INSERT sales.OrderItem(OrderId,SlotId,ProductId,Quantity,UnitPrice)
 SELECT @o,SlotId,ProductId,1,100000000 FROM inventory.Slot WHERE MachineId=@empty;
 DECLARE @item BIGINT=(SELECT MIN(OrderItemId) FROM sales.OrderItem WHERE OrderId=@o);
 INSERT sales.DispenseAttempts(OrderItemId,AttemptNo,Result)
 SELECT @item,value,CASE WHEN value<=2 THEN N'JAM' ELSE N'SUCCESS' END FROM GENERATE_SERIES(1,100);
 IF report.fn_DispenseFailureRate(@empty)<>0.02 THROW 50491,N'Exact 2 percent boundary failed',1;
 UPDATE sales.DispenseAttempts SET Result=N'SUCCESS' WHERE OrderItemId=@item AND AttemptNo=2;
 IF report.fn_DispenseFailureRate(@empty)<>0.01 THROW 50491,N'Below 2 percent failed',1;
 IF (SELECT COUNT(*) FROM report.vw_ProductRanking WHERE LocationId=@loc AND RankInLocation=1)<>2 THROW 50491,N'Tied rank failed',1;
 -- Refresh handles paid -> refunded transitions rather than leaving stale rows.
 EXEC report.sp_RefreshDailySummary '20261101','20261101';
 UPDATE sales.[Order] SET Status=N'refunded' WHERE OrderId=@o;
 EXEC report.sp_RefreshDailySummary '20261101','20261101';
 IF EXISTS(SELECT 1 FROM report.DailySalesSummary WHERE MachineId=@empty) THROW 50491,N'Stale refund summary',1;
 ROLLBACK;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
SELECT N'PASS: function/view boundaries, ties, transitions and procedure cases' Result;
GO
