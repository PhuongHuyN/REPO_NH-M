-- SCRUM-225. Actual plans + TIME/IO for five report queries.
-- SSMS: set session context TV5PerfPhase='BEFORE' or 'AFTER'.
-- Use run-perf.ps1 to retain every plan/message/sample and owner index provenance.
USE FreshVendDB;
GO
SET NOCOUNT ON;
DECLARE @Phase NVARCHAR(10)=CONVERT(NVARCHAR(10),SESSION_CONTEXT(N'TV5PerfPhase')),
 @Control BIT=COALESCE(TRY_CONVERT(BIT,SESSION_CONTEXT(N'TV5PerfControl')),0);
IF @Phase IS NULL OR @Phase NOT IN(N'BEFORE',N'AFTER') THROW 50420,N'Cần Phase BEFORE/AFTER rõ ràng.',1;
DECLARE @OrderCount BIGINT=(SELECT COUNT_BIG(*) FROM report.SeedItems WHERE Kind=N'Order'),
 @TelemetryCount BIGINT=(SELECT COUNT_BIG(*) FROM iot.Telemetry t JOIN report.SeedItems m ON m.Kind=N'Machine' AND m.ObjectId=t.MachineId);
IF @Control=0 AND (NOT EXISTS(SELECT 1 FROM report.SeedRuns WHERE Profile=N'LARGE') OR @OrderCount<>5000 OR @TelemetryCount<>200000)
 THROW 50420,N'BLOCKED: seed LARGE chưa chạy thật hoặc chưa đủ 5000/200000.',1;
IF @Phase=N'AFTER' AND COALESCE(TRY_CONVERT(BIT,SESSION_CONTEXT(N'TV5OwnerIndexApplied')),0)<>1
 THROW 50420,N'Không đo AFTER khi chưa có thay đổi index được owner cung cấp.',1;
DECLARE @From DATE='20260806',@To DATE='20261103',@UserId INT=COALESCE(
 (SELECT UserId FROM auth.[User] WHERE Username=N'admin'),(SELECT UserId FROM auth.[User] WHERE Username=N'admin01'));
IF @UserId IS NULL THROW 50420,N'Cần tài khoản fixture để đo export thật.',1;
DECLARE @Queries TABLE(Id INT PRIMARY KEY,Name NVARCHAR(100),Body NVARCHAR(MAX));
INSERT @Queries VALUES
(1,N'PeakHours',N'EXEC report.sp_PeakHours @From=@F,@To=@T;'),
(2,N'RevenueByLocation',N'SELECT * FROM report.fn_RevenueByLocation(@F,@T);'),
(3,N'ProductRanking',N'SELECT * FROM report.vw_ProductRanking;'),
(4,N'ColdChainCompliance',N'SELECT * FROM report.vw_ColdChainCompliance;'),
(5,N'ExportSales30Days',N'DECLARE @E DATE=DATEADD(DAY,-29,@T); EXEC report.sp_ExportSales @From=@E,@To=@T,@UserId=@U;');
DECLARE @Id INT=1,@Iteration INT,@Name NVARCHAR(100),@Sql NVARCHAR(MAX),@At DATETIME2,@ElapsedMs DECIMAL(18,3);
WHILE @Id<=5
BEGIN
 SELECT @Name=Name,@Sql=Body FROM @Queries WHERE Id=@Id;
 SET @Iteration=0;
 WHILE @Iteration<=5
 BEGIN
  BEGIN TRY
   BEGIN TRAN;
   PRINT N'PERF '+@Name+N' iteration '+CONVERT(NVARCHAR(3),@Iteration);
   SET STATISTICS TIME ON;
   SET STATISTICS IO ON;
   SET STATISTICS XML ON;
   SET @At=SYSUTCDATETIME();
   EXEC sys.sp_executesql @Sql,N'@F DATE,@T DATE,@U INT',@F=@From,@T=@To,@U=@UserId;
   SET @ElapsedMs=DATEDIFF_BIG(MICROSECOND,@At,SYSUTCDATETIME())/1000.0;
   SET STATISTICS XML OFF;
   SET STATISTICS IO OFF;
   SET STATISTICS TIME OFF;
   IF XACT_STATE()<>1 THROW 50420,N'Query làm mất transaction của benchmark.',1;
   ROLLBACK;
   SELECT N'TIMING' RecordType,@Phase Phase,@Name QueryName,@Iteration Iteration,@ElapsedMs ElapsedMs,
    @Control ControlOnly,@OrderCount FixtureOrders,@TelemetryCount FixtureTelemetry,DB_NAME() [Database];
  END TRY
  BEGIN CATCH
   SET STATISTICS XML OFF;
   SET STATISTICS IO OFF;
   SET STATISTICS TIME OFF;
   IF XACT_STATE()<>0 ROLLBACK;
   THROW;
  END CATCH;
  SET @Iteration+=1;
 END;
 SET @Id+=1;
END;
GO
