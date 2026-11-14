-- SCRUM-239: report subset of the current real rollback suite, not historical 18-case assertions.
USE FreshVendDB;
GO
SET NOCOUNT ON;
IF DB_NAME() NOT LIKE N'FreshVend[_]QA%' THROW 50491,N'Use QA database.',1;
IF NOT EXISTS(SELECT 1 FROM report.vw_LatestTestRun) THROW 50491,N'Run report.sp_RunAllTests first.',1;
SELECT TestCase,Expected,Actual,Passed,Status,ErrorDetail,RunAt FROM report.vw_LatestTestRun WHERE Module=N'report';
IF (SELECT COUNT(*) FROM report.vw_LatestTestRun WHERE Module=N'report')<>6
 OR EXISTS(SELECT 1 FROM report.vw_LatestTestRun WHERE Module=N'report' AND Status<>N'PASS')
 THROW 50491,N'Report subset requires six real passing cases.',1;
GO
