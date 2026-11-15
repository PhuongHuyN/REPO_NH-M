USE FreshVendDB;
GO
SET NOCOUNT ON;
EXEC report.sp_RunAllTests @RunBy=N'SCRUM-209 acceptance';
IF EXISTS(SELECT 1 FROM report.vw_LatestTestRun WHERE Passed=0) THROW 50491,N'Procedure suite failed.',1;
IF (SELECT COUNT(*) FROM report.vw_LatestTestRun)<>18 THROW 50491,N'Expected six procedures x three cases.',1;
DECLARE @net DECIMAL(18,2)=(SELECT SUM(TotalAmount) FROM sales.[Order] WHERE Status IN(N'PAID',N'DISPENSED'));
IF @net<>(SELECT SUM(Revenue) FROM report.fn_RevenueByLocation('20261103','20261103')) THROW 50491,N'Location revenue mismatch.',1;
IF EXISTS(SELECT 1 FROM report.fn_RevenueByLocation('20261104','20261103')) THROW 50491,N'Reversed range must be empty.',1;
IF EXISTS(SELECT 1 FROM report.fn_RevenueByLocation('20270101','20270102')) THROW 50491,N'Empty range must be empty.',1;
IF NOT EXISTS(SELECT 1 FROM report.fn_RevenueByLocation('20261103','20261103') WHERE LocationType=N'CAMPUS' AND District=N'Thu Duc') THROW 50491,N'Real location metadata missing.',1;
DECLARE @m INT=(SELECT MachineId FROM iot.Machines WHERE Serial=N'TV5-M-001');
IF NOT EXISTS(SELECT 1 FROM report.vw_ColdChainCompliance WHERE MachineId=@m AND HoursMonitored=1 AND CompliancePercent=50) THROW 50491,N'Hourly owner contract mismatch.',1;
IF report.fn_DispenseFailureRate(-1) IS NOT NULL THROW 50491,N'Unknown machine must return NULL.',1;
DECLARE @jamMachine INT=(SELECT MachineId FROM iot.Machines WHERE Serial=N'TV5-M-002');
IF report.fn_DispenseFailureRate(@jamMachine)<>0.1 THROW 50491,N'Events ratio mismatch.',1;
IF EXISTS(SELECT 1 FROM report.vw_ProductRanking a JOIN report.vw_ProductRanking b ON a.LocationId=b.LocationId WHERE a.Revenue>b.Revenue AND a.RankInLocation>=b.RankInLocation) THROW 50491,N'Ranking ordering mismatch.',1;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 -- Multi-line discounted order: count/order revenue must not multiply by line count.
 DECLARE @o BIGINT=(SELECT OrderId FROM sales.[Order] WHERE OrderCode=N'TV5-O-00001');
 DECLARE @slot INT=(SELECT TOP(1) SlotId FROM sales.OrderItem WHERE OrderId=@o);
 DECLARE @product INT=(SELECT ProductId FROM inventory.Slot WHERE SlotId=@slot);
 INSERT sales.OrderItem(OrderId,SlotId,ProductId,Quantity,UnitPrice) VALUES(@o,@slot,@product,1,1000);
 UPDATE sales.[Order] SET Subtotal=2000,DiscountAmount=100,TotalAmount=1900 WHERE OrderId=@o;
 IF (SELECT SUM(Revenue) FROM report.fn_RevenueByLocation('20261103','20261103'))<>@net+900 THROW 50491,N'Multi-line net revenue doubled.',1;
 EXEC report.sp_RefreshDailySummary '20261103','20261103';
 DECLARE @gross DECIMAL(18,2)=(SELECT SUM(Revenue) FROM report.DailySalesSummary);
 EXEC report.sp_RefreshDailySummary '20261103','20261103';
 IF @gross<>(SELECT SUM(Revenue) FROM report.DailySalesSummary) THROW 50491,N'Refresh is not idempotent.',1;
 UPDATE sales.[Order] SET Status=N'REFUNDED' WHERE OrderId=@o;
 EXEC report.sp_RefreshDailySummary '20261103','20261103';
 IF @gross-2000<>(SELECT SUM(Revenue) FROM report.DailySalesSummary) THROW 50491,N'Refund left stale summary.',1;
 UPDATE iot.TelemetryHourly SET MinutesOutOfRange=61 WHERE MachineId=@m;
 IF EXISTS(SELECT 1 FROM report.vw_ColdChainCompliance WHERE MachineId=@m AND CompliancePercent IS NOT NULL) THROW 50491,N'Invalid upstream duration must not look valid.',1;
 ROLLBACK;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
SELECT N'PASS: owner tables, discounted multi-line revenue, events, hourly compliance, refresh' Result;
GO
