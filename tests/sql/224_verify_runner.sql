USE FreshVendDB;
GO
SET NOCOUNT ON;
DECLARE @Products BIGINT=(SELECT COUNT_BIG(*) FROM inventory.Product),@Orders BIGINT=(SELECT COUNT_BIG(*) FROM sales.[Order]),
 @Machines BIGINT=(SELECT COUNT_BIG(*) FROM iot.Machines),@Telemetry BIGINT=(SELECT COUNT_BIG(*) FROM iot.Telemetry),@Prices DECIMAL(38,2)=(SELECT SUM(UnitPrice) FROM inventory.Product);
EXEC report.sp_RunAllTests @RunBy=N'SCRUM-224 real SQL';
IF @Products<>(SELECT COUNT_BIG(*) FROM inventory.Product) OR @Orders<>(SELECT COUNT_BIG(*) FROM sales.[Order])
 OR @Machines<>(SELECT COUNT_BIG(*) FROM iot.Machines) OR @Telemetry<>(SELECT COUNT_BIG(*) FROM iot.Telemetry)
 OR @Prices<>(SELECT SUM(UnitPrice) FROM inventory.Product) THROW 50491,N'Runner changed business rows despite rollback.',1;
IF @@TRANCOUNT<>0 THROW 50491,N'Runner leaked a transaction.',1;
IF (SELECT COUNT(DISTINCT Module) FROM report.vw_LatestTestRun)<>5 THROW 50491,N'Missing module coverage.',1;
IF (SELECT COUNT(*) FROM report.vw_LatestTestRun)<>33 THROW 50491,N'Missing real test cases.',1;
IF EXISTS(SELECT 1 FROM report.vw_LatestTestRun WHERE (Status=N'PASS' AND Passed<>1) OR (Status<>N'PASS' AND Passed<>0)) THROW 50491,N'Contradictory test status.',1;
IF OBJECT_ID(N'auth.sp_CreateUser',N'P') IS NULL AND EXISTS(SELECT 1 FROM report.vw_LatestTestRun WHERE Module=N'auth' AND Status=N'PASS') THROW 50491,N'Fake auth PASS.',1;
IF OBJECT_ID(N'iot.sp_MaintainPartitions',N'P') IS NULL AND NOT EXISTS(SELECT 1 FROM report.vw_LatestTestRun WHERE TestCase=N'IOT-partition-real' AND Status=N'BLOCKED') THROW 50491,N'Missing partition was accepted.',1;
SELECT N'PASS: runner coverage, rollback, real statuses, no fake partition/auth PASS' Integrity;
GO
