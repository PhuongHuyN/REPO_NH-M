-- sqlcmd -S .\SQLEXPRESS -E -C -I -b -d FreshVend_S217_Clean_20261115 -i tests/demo_security.sql
-- Prerequisite: clean QA install via 99_run_all.bat. Never restores over the input DB.
-- Both source and restored DBs get fresh UUID names; kept for inspection, no WITH REPLACE.
SET NOCOUNT ON;
IF DB_NAME() NOT LIKE N'FreshVend[_]S%' AND DB_NAME() NOT LIKE N'FreshVend[_]QA%'
 THROW 50097,N'Demo requires a FreshVend_S* or FreshVend_QA* database.',1;
IF USER_NAME()<>N'dbo' THROW 50097,N'Demo requires dbo.',1;
IF EXISTS(SELECT 1 FROM inventory.Product) THROW 50097,N'Use a clean QA installation without business seed.',1;
-- Part 1: real RLS with controlled fixtures, rolled back before the backup demo.
BEGIN TRY
 BEGIN TRAN;
 DECLARE @op INT=(SELECT UserId FROM auth.[User] WHERE Username=N'operator01'),@m INT,@count INT;
 IF @op IS NULL THROW 50097,N'Missing operator01 from auth install.',1;
 SELECT @m=1+CASE WHEN COALESCE((SELECT MAX(MachineId) FROM iot.Machines),0)>COALESCE((SELECT MAX(MachineId) FROM inventory.Machine),0)
  THEN COALESCE((SELECT MAX(MachineId) FROM iot.Machines),0) ELSE COALESCE((SELECT MAX(MachineId) FROM inventory.Machine),0) END;
 SET IDENTITY_INSERT iot.Machines ON;
 INSERT iot.Machines(MachineId,Serial,MachineName) SELECT @m+value,N'DEMO230-'+CONVERT(NVARCHAR(12),@m+value),N'Demo RLS' FROM GENERATE_SERIES(0,3);
 SET IDENTITY_INSERT iot.Machines OFF;
 SET IDENTITY_INSERT inventory.Machine ON;
 INSERT inventory.Machine(MachineId,MachineCode,MachineName) SELECT @m+value,N'DEMO230-'+CONVERT(NVARCHAR(12),@m+value),N'Demo RLS' FROM GENERATE_SERIES(0,3);
 SET IDENTITY_INSERT inventory.Machine OFF;
 DELETE auth.UserMachine WHERE UserId=@op;
 INSERT auth.UserMachine(UserId,MachineId) SELECT @op,@m+value FROM GENERATE_SERIES(0,2);
 EXEC sys.sp_set_session_context N'UserId',@op;
 EXECUTE AS USER=N'fv_operator_app';
 SELECT N'RLS: operator01 sees exactly assigned machines' Step,MachineId,MachineCode FROM inventory.Machine;
 SELECT @count=COUNT(*) FROM inventory.Machine;
 REVERT;
 IF @count<>3 THROW 50098,N'RLS expected exactly three machines.',1;
 ROLLBACK;
 EXEC sys.sp_set_session_context N'UserId',NULL;
 PRINT 'RLS PASS: 3 of 4 fixture machines visible';
END TRY
BEGIN CATCH
 WHILE USER_NAME()<>N'dbo' REVERT;
 IF @@TRANCOUNT>0 ROLLBACK;
 EXEC sys.sp_set_session_context N'UserId',NULL;
 THROW;
END CATCH;
GO
-- Part 2: clone actual schema, commit product, full + diff + log, delete, STOPAT restore.
DECLARE @input SYSNAME=DB_NAME(),@id NVARCHAR(32)=REPLACE(CONVERT(NVARCHAR(36),NEWID()),'-',''),
 @backupDir NVARCHAR(4000)=CONVERT(NVARCHAR(4000),SERVERPROPERTY('InstanceDefaultBackupPath')),
 @dataDir NVARCHAR(4000)=CONVERT(NVARCHAR(4000),SERVERPROPERTY('InstanceDefaultDataPath'));
IF @backupDir IS NULL OR @dataDir IS NULL THROW 50080,N'Configure SQL Server default backup/data directories.',1;
IF RIGHT(@backupDir,1) NOT IN(N'\',N'/') SET @backupDir+=N'\';
IF RIGHT(@dataDir,1) NOT IN(N'\',N'/') SET @dataDir+=N'\';
DECLARE @source SYSNAME=N'FreshVend_StopAt_'+@id,@restored SYSNAME=N'FreshVend_Restored_'+@id,
 @clone NVARCHAR(4000)=@backupDir+N'FV230_'+@id+N'_clone.bak',
 @full NVARCHAR(4000)=@backupDir+N'FV230_'+@id+N'_full.bak',
 @diff NVARCHAR(4000)=@backupDir+N'FV230_'+@id+N'_diff.bak',
 @log NVARCHAR(4000)=@backupDir+N'FV230_'+@id+N'_log.trn',
 @moveSource NVARCHAR(MAX),@moveRestored NVARCHAR(MAX),@sql NVARCHAR(MAX),@target DATETIME,@before INT,@after INT,@marker INT;
-- MOVE every actual file (including databases with more than two files).
SELECT @moveSource=STRING_AGG(CONVERT(NVARCHAR(MAX),N'MOVE N'+QUOTENAME(name,'''')+N' TO N'+QUOTENAME(@dataDir+@source+N'_'+CONVERT(NVARCHAR(12),file_id)+CASE WHEN type=1 THEN N'.ldf' ELSE N'.mdf' END,'''')),N', '),
 @moveRestored=STRING_AGG(CONVERT(NVARCHAR(MAX),N'MOVE N'+QUOTENAME(name,'''')+N' TO N'+QUOTENAME(@dataDir+@restored+N'_'+CONVERT(NVARCHAR(12),file_id)+CASE WHEN type=1 THEN N'.ldf' ELSE N'.mdf' END,'''')),N', ')
FROM sys.database_files;
BACKUP DATABASE @input TO DISK=@clone WITH COPY_ONLY,CHECKSUM;
SET @sql=N'USE master; RESTORE DATABASE '+QUOTENAME(@source)+N' FROM DISK=@file WITH '+@moveSource+N', RECOVERY, CHECKSUM;';
EXEC sys.sp_executesql @sql,N'@file NVARCHAR(4000)',@clone;
SET @sql=N'USE '+QUOTENAME(@source)+N'; ALTER DATABASE '+QUOTENAME(@source)+N' SET RECOVERY FULL;
 EXEC inventory.sp_AddProduct @ProductName=N''STOPAT fruit'',@Price=25000,@ShelfLifeHours=24;
 CREATE TABLE dbo.RestoreMarkers(Marker INT NOT NULL PRIMARY KEY);
 INSERT dbo.RestoreMarkers VALUES(1);';
EXEC sys.sp_executesql @sql;
BACKUP DATABASE @source TO DISK=@full WITH CHECKSUM;
SET @sql=N'USE '+QUOTENAME(@source)+N'; INSERT dbo.RestoreMarkers VALUES(2); SELECT @n=COUNT(*) FROM inventory.Product;';
EXEC sys.sp_executesql @sql,N'@n INT OUTPUT',@before OUTPUT;
IF @before<>1 THROW 50098,N'Expected one committed demo product.',1;
BACKUP DATABASE @source TO DISK=@diff WITH DIFFERENTIAL,CHECKSUM;
WAITFOR DELAY '00:00:01';
SET @target=GETDATE(); -- SQL Server local clock, same clock as RESTORE STOPAT.
WAITFOR DELAY '00:00:01';
SET @sql=N'USE '+QUOTENAME(@source)+N'; DELETE inventory.Product; INSERT dbo.RestoreMarkers VALUES(3);
 IF EXISTS(SELECT 1 FROM inventory.Product) THROW 50098,N''Incident deletion failed'',1;';
EXEC sys.sp_executesql @sql;
SELECT N'Incident committed; product count is zero' Step,@source SourceDatabase,@target StopAtServerLocal;
BACKUP LOG @source TO DISK=@log WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK=@full WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK=@diff WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK=@log WITH CHECKSUM;
SET @sql=N'USE master; RESTORE DATABASE '+QUOTENAME(@restored)+N' FROM DISK=@f WITH '+@moveRestored+N', NORECOVERY, CHECKSUM;
 RESTORE DATABASE '+QUOTENAME(@restored)+N' FROM DISK=@d WITH NORECOVERY,CHECKSUM;
 RESTORE LOG '+QUOTENAME(@restored)+N' FROM DISK=@l WITH STOPAT=@t,RECOVERY,CHECKSUM;';
EXEC sys.sp_executesql @sql,N'@f NVARCHAR(4000),@d NVARCHAR(4000),@l NVARCHAR(4000),@t DATETIME',@full,@diff,@log,@target;
SET @sql=N'USE '+QUOTENAME(@restored)+N'; SELECT @n=COUNT(*) FROM inventory.Product; SELECT @k=MAX(Marker) FROM dbo.RestoreMarkers;
 SELECT ProductId,ProductName,UnitPrice FROM inventory.Product;
 IF NOT EXISTS(SELECT 1 FROM inventory.Product WHERE ProductName=N''STOPAT fruit'' AND UnitPrice=25000) THROW 50098,N''Restored data mismatch'',1;';
EXEC sys.sp_executesql @sql,N'@n INT OUTPUT,@k INT OUTPUT',@after OUTPUT,@marker OUTPUT;
IF @before<>@after OR @marker<>2 THROW 50098,N'STOPAT failed: pre-incident data/marker mismatch.',1;
SELECT N'PASS' Status,@input InputDatabase,@source IncidentDatabase,@restored RestoredDatabase,@target StopAtServerLocal,
 @before BeforeCount,@after RestoredCount,@marker LatestRestoredMarker,SYSDATETIMEOFFSET() CompletedAt,
 @full FullBackup,@diff DifferentialBackup,@log LogBackup;
PRINT 'STOPAT PASS: product restored; marker 2 retained; incident marker 3 excluded';
GO
