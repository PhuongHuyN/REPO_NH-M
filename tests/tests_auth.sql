-- SCRUM-230: 5 procedures x (1 valid + 2 invalid) + 3 security cases.
-- Run after 99_run_all.bat, as dbo, on a QA database only. Each case rolls back fixtures.
-- Negative Login returns IsSuccess=0 instead of THROW; assert the audit and state.
USE FreshVendDB;
GO
SET NOCOUNT ON;
IF DB_NAME() NOT LIKE N'FreshVend[_]S%' AND DB_NAME() NOT LIKE N'FreshVend[_]QA%'
 THROW 50097,N'Run tests on a dedicated FreshVend_S* or FreshVend_QA* database.',1;
IF USER_NAME()<>N'dbo' THROW 50097,N'Run as dbo for EXECUTE AS assertions.',1;
IF EXISTS(SELECT 1 FROM auth.[User] WHERE Username LIKE N'qa230[_]%') THROW 50097,N'Fixture name already exists; use a fresh QA database.',1;
DECLARE @Cases TABLE(Id INT PRIMARY KEY,Name NVARCHAR(150),SqlText NVARCHAR(MAX),ExpectedError INT);
INSERT @Cases VALUES
(1,N'CreateUser valid',N'EXEC auth.sp_CreateUser N''qa230_new'',N''Valid@2026'',N''QA new'',N''Operator''; IF NOT EXISTS(SELECT 1 FROM auth.[User] WHERE Username=N''qa230_new'') THROW 50098,N''No created user'',1;',0),
(2,N'CreateUser short username',N'EXEC auth.sp_CreateUser N''x'',N''Valid@2026'',N''QA'',N''Operator'';',50001),
(3,N'CreateUser duplicate',N'EXEC auth.sp_CreateUser N''qa230_op'',N''Valid@2026'',N''QA'',N''Operator'';',50003),
(4,N'Login valid',N'EXEC auth.sp_Login N''qa230_op'',N''Valid@2026''; IF NOT EXISTS(SELECT 1 FROM auth.LoginHistory WHERE UserId=@op AND IsSuccess=1) THROW 50098,N''No successful login'',1;',0),
(5,N'Login wrong password',N'EXEC auth.sp_Login N''qa230_op'',N''Wrong@2026''; IF NOT EXISTS(SELECT 1 FROM auth.[User] WHERE UserId=@op AND FailedLogins=1) OR NOT EXISTS(SELECT 1 FROM auth.LoginHistory WHERE UserId=@op AND IsSuccess=0) THROW 50098,N''Wrong login not recorded'',1;',0),
(6,N'Login unknown username',N'EXEC auth.sp_Login N''qa230_unknown'',N''Valid@2026''; IF NOT EXISTS(SELECT 1 FROM auth.LoginHistory WHERE Username=N''qa230_unknown'' AND IsSuccess=0 AND UserId IS NULL) THROW 50098,N''Unknown login not rejected'',1;',0),
(7,N'ChangePassword valid',N'EXEC auth.sp_ChangePassword @op,N''Valid@2026'',N''Changed@2026''; IF NOT EXISTS(SELECT 1 FROM auth.[User] WHERE UserId=@op AND PasswordHash=auth.fn_HashPassword(N''Changed@2026'',Salt)) THROW 50098,N''Hash not updated'',1;',0),
(8,N'ChangePassword wrong old password',N'EXEC auth.sp_ChangePassword @op,N''Wrong@2026'',N''Changed@2026'';',50011),
(9,N'ChangePassword short new password',N'EXEC auth.sp_ChangePassword @op,N''Valid@2026'',N''bad'';',50002),
(10,N'AssignMachine valid',N'EXEC auth.sp_AssignMachine @op,@m4; IF NOT EXISTS(SELECT 1 FROM auth.UserMachine WHERE UserId=@op AND MachineId=@m4) THROW 50098,N''Mapping not created'',1;',0),
(11,N'AssignMachine unknown user',N'EXEC auth.sp_AssignMachine -1,@m4;',50020),
(12,N'AssignMachine unknown machine',N'EXEC auth.sp_AssignMachine @op,-1;',50022),
(13,N'DeactivateUser valid',N'EXEC auth.sp_DeactivateUser @op,0; IF NOT EXISTS(SELECT 1 FROM auth.[User] WHERE UserId=@op AND IsActive=0) THROW 50098,N''User still active'',1;',0),
(14,N'DeactivateUser unknown user',N'EXEC auth.sp_DeactivateUser -1,0;',50030),
(15,N'DeactivateUser self forbidden',N'EXEC sys.sp_set_session_context N''UserId'',@op; EXEC auth.sp_DeactivateUser @op,0;',50031),
(16,N'RLS exact three assigned machines',N'EXEC sys.sp_set_session_context N''UserId'',@op; EXECUTE AS USER=N''fv_operator_app''; SELECT @seen=COUNT(*) FROM inventory.Machine; SELECT @outside=COUNT(*) FROM inventory.Machine WHERE MachineId NOT IN (SELECT @m1 UNION ALL SELECT @m1+1 UNION ALL SELECT @m1+2); REVERT; IF @seen<>3 OR @outside<>0 THROW 50098,N''RLS does not return exactly assigned set'',1;',0),
(17,N'Operator DENY report',N'EXECUTE AS USER=N''fv_operator_app''; SELECT TOP(1) * FROM report.DailySalesSummary;',229),
(18,N'Kiosk cannot add product',N'EXECUTE AS USER=N''fv_kiosk_app''; EXEC inventory.sp_AddProduct @ProductName=N''forbidden'',@Price=10,@ShelfLifeHours=24;',229);
DECLARE @Fixture NVARCHAR(MAX)=N'
DECLARE @op INT,@m1 INT,@m4 INT,@seen INT,@outside INT;
EXEC auth.sp_CreateUser N''qa230_op'',N''Valid@2026'',N''QA Operator'',N''Operator'';
SELECT @op=UserId FROM auth.[User] WHERE Username=N''qa230_op'';
SELECT @m1=1+CASE WHEN COALESCE((SELECT MAX(MachineId) FROM iot.Machines),0)>COALESCE((SELECT MAX(MachineId) FROM inventory.Machine),0) THEN COALESCE((SELECT MAX(MachineId) FROM iot.Machines),0) ELSE COALESCE((SELECT MAX(MachineId) FROM inventory.Machine),0) END;
SET @m4=@m1+3;
SET IDENTITY_INSERT iot.Machines ON;
INSERT iot.Machines(MachineId,Serial,MachineName) SELECT @m1+value,N''QA230-''+CONVERT(NVARCHAR(12),@m1+value),N''QA'' FROM GENERATE_SERIES(0,3);
SET IDENTITY_INSERT iot.Machines OFF;
SET IDENTITY_INSERT inventory.Machine ON;
INSERT inventory.Machine(MachineId,MachineCode,MachineName) SELECT @m1+value,N''QA230-''+CONVERT(NVARCHAR(12),@m1+value),N''QA'' FROM GENERATE_SERIES(0,3);
SET IDENTITY_INSERT inventory.Machine OFF;
EXEC auth.sp_AssignMachine @op,@m1;
DECLARE @m2 INT=@m1+1,@m3 INT=@m1+2;
EXEC auth.sp_AssignMachine @op,@m2;
EXEC auth.sp_AssignMachine @op,@m3;
';

DECLARE @Results TABLE(TestNo INT,TestCase NVARCHAR(150),ExpectedError INT,ActualError INT,Passed BIT,Detail NVARCHAR(2000),RunAt DATETIMEOFFSET);
DECLARE @i INT=1,@name NVARCHAR(150),@body NVARCHAR(MAX),@expected INT,@actual INT,@detail NVARCHAR(2000),@ready BIT;
WHILE @i<=18
BEGIN
 SELECT @name=Name,@body=SqlText,@expected=ExpectedError FROM @Cases WHERE Id=@i;
 SELECT @actual=0,@detail=N'Assertions completed',@ready=0;
 BEGIN TRY
  EXEC sys.sp_set_session_context N'UserId',NULL;
  BEGIN TRAN;
  -- Fixture errors must never count as an expected negative result.
  DECLARE @prefix NVARCHAR(MAX)=@Fixture+N' EXEC sys.sp_set_session_context N''QA230Ready'',1; '+@body;
  EXEC sys.sp_executesql @prefix;
 END TRY
 BEGIN CATCH
  SELECT @actual=ERROR_NUMBER(),@detail=ERROR_MESSAGE();
 END CATCH;
 SET @ready=COALESCE(TRY_CONVERT(BIT,SESSION_CONTEXT(N'QA230Ready')),0);
 WHILE USER_NAME()<>N'dbo' REVERT;
 IF @@TRANCOUNT>0 ROLLBACK;
 -- IDENTITY_INSERT settings survive a rollback after a failed fixture.
 SET IDENTITY_INSERT inventory.Machine OFF;
 SET IDENTITY_INSERT iot.Machines OFF;
 EXEC sys.sp_set_session_context N'UserId',NULL;
 EXEC sys.sp_set_session_context N'QA230Ready',NULL;
 INSERT @Results VALUES(@i,@name,@expected,@actual,CASE WHEN @ready=1 AND @actual=@expected THEN 1 ELSE 0 END,@detail,SYSDATETIMEOFFSET());
 SET @i+=1;
END;
SELECT *,CASE WHEN Passed=1 THEN 'PASS' ELSE 'FAIL' END Status FROM @Results ORDER BY TestNo;
SELECT COUNT(*) Total,SUM(CONVERT(INT,Passed)) Passed,COUNT(*)-SUM(CONVERT(INT,Passed)) Failed FROM @Results;
IF (SELECT COUNT(*) FROM @Results WHERE Passed=1)<>18 THROW 50098,N'Auth acceptance requires 18/18 PASS; inspect result rows.',1;
PRINT '[tests_auth] 18/18 PASS';
GO
