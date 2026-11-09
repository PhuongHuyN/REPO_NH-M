USE FreshVendDB;
GO
SET NOCOUNT ON;
DECLARE @Tasks TABLE(Id INT IDENTITY,Name NVARCHAR(150),SqlText NVARCHAR(MAX));
INSERT @Tasks(Name,SqlText) VALUES
(N'sp_DashboardKpi',N'EXEC report.sp_DashboardKpi @AsOf=''20261103'';'),
(N'sp_RevenueGrowth',N'EXEC report.sp_RevenueGrowth @Year=2026;'),
(N'sp_PeakHours',N'EXEC report.sp_PeakHours ''20260806'',''20261103'';'),
(N'sp_ExportSales',N'DECLARE @u INT=(SELECT UserId FROM auth.[User] WHERE Username=N''admin01''); EXEC report.sp_ExportSales ''20261005'',''20261103'',@u;'),
(N'sp_RefreshDailySummary',N'EXEC report.sp_RefreshDailySummary ''20260806'',''20261103'';'),
(N'sp_RunAllTests',N'EXEC report.sp_RunAllTests @RunBy=N''performance'';'),
(N'fn_RevenueByLocation',N'SELECT * FROM report.fn_RevenueByLocation(''20260806'',''20261103'');'),
(N'fn_DispenseFailureRate',N'DECLARE @m INT=(SELECT MachineId FROM iot.Machines WHERE Serial=N''TV5-M-002''); SELECT report.fn_DispenseFailureRate(@m) Rate;'),
(N'vw_ProductRanking',N'SELECT * FROM report.vw_ProductRanking;'),
(N'vw_ColdChainCompliance',N'SELECT * FROM report.vw_ColdChainCompliance;');
DECLARE @Id INT=1,@Count INT=(SELECT COUNT(*) FROM @Tasks),@Name NVARCHAR(150),@Sql NVARCHAR(MAX),@Try INT,@Start DATETIME2,@Elapsed INT;
CREATE TABLE #Times(Name NVARCHAR(150),Iteration INT,ElapsedMs INT);
WHILE @Id<=@Count
BEGIN
 SELECT @Name=Name,@Sql=SqlText FROM @Tasks WHERE Id=@Id;
 SET @Try=0;
 WHILE @Try<=5
 BEGIN
  SET @Start=SYSUTCDATETIME();
  EXEC sys.sp_executesql @Sql;
  SET @Elapsed=DATEDIFF(MICROSECOND,@Start,SYSUTCDATETIME())/1000;
  INSERT #Times VALUES(@Name,@Try,@Elapsed);
  SET @Try+=1;
 END;
 SET @Id+=1;
END;
SELECT Name,MAX(CASE WHEN Iteration=0 THEN ElapsedMs END) ColdMs,
 MAX(CASE WHEN Iteration=1 THEN ElapsedMs END) Run1,
 MAX(CASE WHEN Iteration=2 THEN ElapsedMs END) Run2,
 MAX(CASE WHEN Iteration=3 THEN ElapsedMs END) Run3,
 MAX(CASE WHEN Iteration=4 THEN ElapsedMs END) Run4,
 MAX(CASE WHEN Iteration=5 THEN ElapsedMs END) Run5,
 MAX(CASE WHEN Iteration>0 THEN ElapsedMs END) WarmMaxMs
FROM #Times GROUP BY Name ORDER BY Name;
-- The test orchestrator runs the entire suite, not one business request.
-- Its elapsed time is reported above, with no per-request budget applied.
IF EXISTS(SELECT 1 FROM #Times WHERE Name<>N'sp_RunAllTests' AND Iteration>0 AND ElapsedMs>=500)
 THROW 50492,N'Business request exceeds strict 500ms limit',1;
DROP TABLE IF EXISTS #Times;
GO
