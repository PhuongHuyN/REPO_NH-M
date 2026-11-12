USE FreshVendDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @m INT=(SELECT TOP(1) MachineId FROM iot.Machines),@before BIGINT=(SELECT COUNT_BIG(*) FROM iot.Telemetry),@payload NVARCHAR(MAX);
BEGIN TRY
 BEGIN TRAN;
 SET @payload=N'{"machineId":'+CONVERT(NVARCHAR(12),@m)+N',"readings":[{"temp":2,"hum":60,"door":0,"t":"2026-11-10T00:00:00Z"},{"temp":8,"hum":61,"door":1},{"temp":5,"hum":62,"door":0}]}';
 CREATE TABLE #Reply(MachineId INT,Status NVARCHAR(20),LastTemp DECIMAL(5,2));
 INSERT #Reply EXEC iot.sp_IngestTelemetry @Payload=@payload;
 IF (SELECT COUNT_BIG(*) FROM iot.Telemetry)<>@before+3 THROW 50491,N'Batch rows missing.',1;
 IF NOT EXISTS(SELECT 1 FROM #Reply WHERE MachineId=@m AND LastTemp=5) THROW 50491,N'LastTemp must follow input ordinal, not MAX(temp).',1;
 IF NOT EXISTS(SELECT 1 FROM iot.Telemetry WHERE MachineId=@m AND Temperature=2 AND RecordedAt='20261110') THROW 50491,N'UTC buffered timestamp was lost.',1;
 IF NOT EXISTS(SELECT 1 FROM iot.Machines WHERE MachineId=@m AND ABS(DATEDIFF(SECOND,LastHeartbeat,SYSUTCDATETIME()))<=5) THROW 50491,N'Heartbeat is not UTC.',1;
 ROLLBACK;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
DECLARE @Cases TABLE(Id INT IDENTITY,Body NVARCHAR(MAX),Expected INT);
INSERT @Cases VALUES(N'not json',50310),(N'{"machineId":-1,"readings":[]}',50311),
 (N'{"machineId":'+CONVERT(NVARCHAR(12),@m)+N',"readings":[]}',50312),
 (N'{"machineId":'+CONVERT(NVARCHAR(12),@m)+N',"readings":[{"temp":4},{"temp":"bad"}]}',50312),
 (N'{"machineId":'+CONVERT(NVARCHAR(12),@m)+N',"readings":[4]}',50312);
DECLARE @i INT=1,@error INT,@got INT;
WHILE @i<=5
BEGIN
 SELECT @payload=Body,@error=Expected FROM @Cases WHERE Id=@i;
 SET @got=0;
 BEGIN TRY
  BEGIN TRAN;
  EXEC iot.sp_IngestTelemetry @Payload=@payload;
  IF XACT_STATE()<>0 ROLLBACK;
 END TRY
 BEGIN CATCH
  SET @got=ERROR_NUMBER();
  IF XACT_STATE()<>0 ROLLBACK;
 END CATCH;
 IF @got<>@error THROW 50491,N'Incorrect validation error.',1;
 IF (SELECT COUNT_BIG(*) FROM iot.Telemetry)<>@before THROW 50491,N'Invalid batch wrote partial data.',1;
 SET @i+=1;
END;
SELECT N'PASS: ordered batch, UTC timestamp/heartbeat, correct errors, atomic invalid batch' Result;
GO
