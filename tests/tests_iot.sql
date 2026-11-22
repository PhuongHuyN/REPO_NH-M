USE FreshVendDB;
GO
IF DB_NAME() NOT LIKE N'FreshVend[_]QA%' THROW 50491,N'Use a QA database with machine fixtures.',1;
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

SELECT TestCase,CONVERT(BIT,1) Passed,SYSDATETIMEOFFSET() RunAt FROM (VALUES(N'ordered batch and UTC timestamps'),(N'invalid JSON 50310'),(N'unknown machine 50311'),(N'empty readings 50312'),(N'atomic invalid reading 50312'),(N'non-object reading 50312')) c(TestCase);
GO

USE FreshVendDB;
GO
SET NOCOUNT ON;

-- Contract checks for the three IoT read objects consumed by API/web.
IF OBJECT_ID(N'iot.vw_MachineHealth', N'V') IS NULL
   OR OBJECT_ID(N'iot.vw_OpenAlerts', N'V') IS NULL
   OR OBJECT_ID(N'iot.fn_RecentTelemetry', N'IF') IS NULL
  THROW 50492,N'Missing IoT API view/function.',1;

DECLARE @ExpectedColumns TABLE(ObjectName SYSNAME,ColumnName SYSNAME,PRIMARY KEY(ObjectName,ColumnName));
INSERT @ExpectedColumns VALUES
(N'vw_MachineHealth',N'MachineId'),(N'vw_MachineHealth',N'Serial'),(N'vw_MachineHealth',N'MachineName'),
(N'vw_MachineHealth',N'Status'),(N'vw_MachineHealth',N'FirmwareVersion'),(N'vw_MachineHealth',N'LocationId'),
(N'vw_MachineHealth',N'LocationName'),(N'vw_MachineHealth',N'LocationType'),(N'vw_MachineHealth',N'District'),
(N'vw_MachineHealth',N'LastHeartbeat'),(N'vw_MachineHealth',N'SecondsSinceHeartbeat'),(N'vw_MachineHealth',N'LastTemp'),
(N'vw_MachineHealth',N'LastHumidity'),(N'vw_MachineHealth',N'DoorOpen'),(N'vw_MachineHealth',N'LastReadingAt'),
(N'vw_MachineHealth',N'MinTemp'),(N'vw_MachineHealth',N'MaxTemp'),(N'vw_MachineHealth',N'DoorOpenMaxMinutes'),
(N'vw_MachineHealth',N'ConsecutiveBreaches'),(N'vw_MachineHealth',N'DegradedMessage'),(N'vw_MachineHealth',N'OpenAlerts'),
(N'vw_MachineHealth',N'IsServing'),
(N'vw_OpenAlerts',N'AlertId'),(N'vw_OpenAlerts',N'MachineId'),(N'vw_OpenAlerts',N'AlertType'),
(N'vw_OpenAlerts',N'Severity'),(N'vw_OpenAlerts',N'Message'),(N'vw_OpenAlerts',N'RefKey'),
(N'vw_OpenAlerts',N'CreatedAt'),(N'vw_OpenAlerts',N'AckBy'),(N'vw_OpenAlerts',N'AckAt'),
(N'vw_OpenAlerts',N'ResolvedAt'),(N'vw_OpenAlerts',N'Serial'),(N'vw_OpenAlerts',N'MachineName'),
(N'vw_OpenAlerts',N'LocationName'),(N'vw_OpenAlerts',N'AckByName'),(N'vw_OpenAlerts',N'AgeMinutes'),
(N'fn_RecentTelemetry',N'MachineId'),(N'fn_RecentTelemetry',N'RecordedAt'),
(N'fn_RecentTelemetry',N'Temperature'),(N'fn_RecentTelemetry',N'Humidity'),(N'fn_RecentTelemetry',N'DoorOpen');

DECLARE @ActualColumns TABLE(ObjectName SYSNAME,ColumnName SYSNAME,PRIMARY KEY(ObjectName,ColumnName));
INSERT @ActualColumns
SELECT CASE o.name WHEN N'vw_MachineHealth' THEN N'vw_MachineHealth'
                   WHEN N'vw_OpenAlerts' THEN N'vw_OpenAlerts'
                   ELSE N'fn_RecentTelemetry' END,c.name
FROM sys.objects AS o
JOIN sys.schemas AS s ON s.schema_id=o.schema_id
JOIN sys.columns AS c ON c.object_id=o.object_id
WHERE s.name=N'iot' AND o.name IN(N'vw_MachineHealth',N'vw_OpenAlerts',N'fn_RecentTelemetry');

DECLARE @columnContract BIT=CASE WHEN NOT EXISTS(SELECT ObjectName,ColumnName FROM @ExpectedColumns EXCEPT SELECT ObjectName,ColumnName FROM @ActualColumns)
                                    AND NOT EXISTS(SELECT ObjectName,ColumnName FROM @ActualColumns EXCEPT SELECT ObjectName,ColumnName FROM @ExpectedColumns)
                                 THEN 1 ELSE 0 END;
DECLARE @parameterContract BIT=CASE WHEN (SELECT COUNT(*) FROM sys.parameters WHERE object_id=OBJECT_ID(N'iot.fn_RecentTelemetry') AND parameter_id>0)=2
                                      AND NOT EXISTS(SELECT Name,SqlType FROM (VALUES(N'MachineId',N'int'),(N'Hours',N'int')) e(Name,SqlType)
                                        EXCEPT SELECT REPLACE(p.name,N'@',N''),TYPE_NAME(p.user_type_id)
                                        FROM sys.parameters p WHERE p.object_id=OBJECT_ID(N'iot.fn_RecentTelemetry') AND p.parameter_id>0)
                                      AND NOT EXISTS(SELECT REPLACE(p.name,N'@',N''),TYPE_NAME(p.user_type_id)
                                        FROM sys.parameters p WHERE p.object_id=OBJECT_ID(N'iot.fn_RecentTelemetry') AND p.parameter_id>0
                                        EXCEPT SELECT Name,SqlType FROM (VALUES(N'MachineId',N'int'),(N'Hours',N'int')) e(Name,SqlType))
                                   THEN 1 ELSE 0 END;
DECLARE @types BIT=CASE WHEN EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'iot.vw_MachineHealth') AND name=N'MachineId' AND TYPE_NAME(user_type_id)=N'int')
                         AND EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'iot.vw_MachineHealth') AND name=N'LastTemp' AND TYPE_NAME(user_type_id)=N'decimal' AND precision=5 AND scale=2)
                         AND EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'iot.vw_MachineHealth') AND name=N'DoorOpen' AND TYPE_NAME(user_type_id)=N'bit')
                         AND EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'iot.vw_OpenAlerts') AND name=N'AlertId' AND TYPE_NAME(user_type_id)=N'int')
                         AND EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'iot.vw_OpenAlerts') AND name=N'CreatedAt' AND TYPE_NAME(user_type_id)=N'datetime2')
                         AND EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'iot.fn_RecentTelemetry') AND name=N'Temperature' AND TYPE_NAME(user_type_id)=N'decimal')
                      THEN 1 ELSE 0 END;
DECLARE @m INT=(SELECT TOP(1) MachineId FROM iot.Machines ORDER BY MachineId);
DECLARE @healthValues BIT=CASE WHEN @m IS NOT NULL AND EXISTS
  (SELECT 1 FROM iot.vw_MachineHealth h WHERE h.MachineId=@m
    AND h.OpenAlerts=(SELECT COUNT(*) FROM iot.Alerts a WHERE a.MachineId=@m AND a.ResolvedAt IS NULL)
    AND h.IsServing=CASE WHEN h.Status=N'ACTIVE' THEN 1 ELSE 0 END)
  THEN 1 ELSE 0 END;
DECLARE @alertValues BIT=CASE WHEN NOT EXISTS
  (SELECT 1 FROM iot.vw_OpenAlerts a WHERE a.ResolvedAt IS NOT NULL OR a.Serial IS NULL OR a.MachineName IS NULL)
  THEN 1 ELSE 0 END;
DECLARE @windowValues BIT=CASE WHEN @m IS NOT NULL
  AND NOT EXISTS(SELECT 1 FROM iot.fn_RecentTelemetry(@m,6) WHERE MachineId<>@m OR RecordedAt<DATEADD(HOUR,-6,SYSUTCDATETIME()))
  AND NOT EXISTS(SELECT 1 FROM iot.fn_RecentTelemetry(@m,0))
  THEN 1 ELSE 0 END;

SELECT TestCase,Passed,SYSDATETIMEOFFSET() RunAt
FROM (VALUES
 (N'IoT read object column contract',@columnContract),
 (N'RecentTelemetry parameter contract',@parameterContract),
 (N'IoT read object SQL types',@types),
 (N'MachineHealth health/count/serving values',@healthValues),
 (N'OpenAlerts unresolved rows and machine enrichment',@alertValues),
 (N'RecentTelemetry machine and hour window',@windowValues)
) checks(TestCase,Passed);

IF @columnContract=0 OR @parameterContract=0 OR @types=0 OR @healthValues=0 OR @alertValues=0 OR @windowValues=0
  THROW 50492,N'IoT read object contract/behavior check failed.',1;
GO
