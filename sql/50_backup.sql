-- FV-23: run after installation, as sysadmin/backup operator with ALTER DATABASE permission.
-- Backups are SERVER-side files. No client C: assumption, no overwrite of earlier runs.
-- Express has no SQL Agent: schedule Full weekly, Diff daily, Log every 15 minutes
-- with Windows Task Scheduler. A 15-minute log interval implies up to 15-minute RPO;
-- backups alone do not prove zero data loss or 99.9% availability.
USE FreshVendDB;
GO
SET NOCOUNT ON;
DECLARE @db SYSNAME=DB_NAME(), @dir NVARCHAR(4000)=CONVERT(NVARCHAR(4000),SERVERPROPERTY('InstanceDefaultBackupPath')),
 @sql NVARCHAR(MAX), @stamp NVARCHAR(40)=REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR(30),SYSDATETIME(),126),':',''),'-',''),'.','')
 +N'_'+LEFT(REPLACE(CONVERT(NVARCHAR(36),NEWID()),'-',''),8);
IF @dir IS NULL THROW 50080,N'Server backup directory unavailable; configure InstanceDefaultBackupPath.',1;
IF RIGHT(@dir,1) NOT IN (N'\',N'/') SET @dir+=N'\';
DECLARE @full NVARCHAR(4000)=@dir+@db+N'_'+@stamp+N'_full.bak',
 @diff NVARCHAR(4000)=@dir+@db+N'_'+@stamp+N'_diff.bak',
 @log NVARCHAR(4000)=@dir+@db+N'_'+@stamp+N'_log.trn';
-- No WITH ROLLBACK IMMEDIATE: do not terminate other users' transactions.
IF (SELECT recovery_model_desc FROM sys.databases WHERE name=@db)<>N'FULL'
BEGIN
 SET @sql=N'ALTER DATABASE '+QUOTENAME(@db)+N' SET RECOVERY FULL;';
 EXEC sys.sp_executesql @sql;
END;
-- Express does not support backup compression; CHECKSUM applies on every edition.
BACKUP DATABASE @db TO DISK=@full WITH CHECKSUM, STATS=10;
BACKUP DATABASE @db TO DISK=@diff WITH DIFFERENTIAL, CHECKSUM, STATS=10;
BACKUP LOG @db TO DISK=@log WITH CHECKSUM, STATS=10;
RESTORE VERIFYONLY FROM DISK=@full WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK=@diff WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK=@log WITH CHECKSUM;
SELECT @db DatabaseName,SYSDATETIMEOFFSET() CompletedAt,@full FullBackup,@diff DifferentialBackup,@log LogBackup;
GO
-- Point-in-time recovery uses an isolated destination, logical names from FILELISTONLY,
-- FULL WITH MOVE ..., NORECOVERY; optional DIFF (before target) WITH NORECOVERY;
-- LOG(s) in LSN order, final LOG WITH STOPAT=<server-local time>, RECOVERY.
-- Never overwrite the live database. Executable, asserted example: tests/demo_security.sql.
