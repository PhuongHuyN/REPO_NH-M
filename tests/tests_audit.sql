-- =============================================================================
-- FILE        : tests/tests_audit.sql
-- PROJECT     : FreshVend
-- DESCRIPTION : FV-06 + FV-21 (SCRUM-200, SCRUM-215) — Kiểm thử bảng audit, 2 view auth
--               và trigger auth.trg_Users_Audit (chạy trong SSMS)
-- CÁCH CHẠY   : Sau 02_tables_audit.sql, 10_procs_auth.sql, 20_objects_auth.sql.
--               Các ca sửa dữ liệu nằm trong 1 transaction rồi ROLLBACK → không làm bẩn CSDL.
-- KẾT QUẢ     : Bảng cuối file (Passed = 1 là đạt); Messages "[tests_audit] x/10 PASS".
-- =============================================================================

USE FreshVendDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT OFF;

DECLARE @Result TABLE (TestNo INT, TestCase NVARCHAR(200), Expected NVARCHAR(100), Actual NVARCHAR(200), Passed BIT);
DECLARE @n INT, @a NVARCHAR(200), @b NVARCHAR(200), @op1 INT, @op2 INT, @before INT, @after INT,
        @old NVARCHAR(MAX), @new NVARCHAR(MAX), @err INT;

SELECT @op1 = UserId FROM auth.[User] WHERE Username = N'operator01';
SELECT @op2 = UserId FROM auth.[User] WHERE Username = N'operator02';

-- A1: 2 bảng audit
SET @n = (SELECT COUNT(*) FROM sys.tables WHERE object_id IN (OBJECT_ID(N'audit.ChangeLog'), OBJECT_ID(N'audit.AuditLog')));
INSERT @Result VALUES (1, N'Có bảng audit.ChangeLog và audit.AuditLog', N'2', CAST(@n AS NVARCHAR(10)), CASE WHEN @n = 2 THEN 1 ELSE 0 END);

-- A2: 2 view + 1 trigger
SET @n = (SELECT COUNT(*) FROM sys.objects WHERE object_id IN (OBJECT_ID(N'auth.vw_UserPermissions'),
          OBJECT_ID(N'audit.vw_LoginActivity'), OBJECT_ID(N'auth.trg_Users_Audit')));
INSERT @Result VALUES (2, N'Có 2 view + trigger auth.trg_Users_Audit', N'3', CAST(@n AS NVARCHAR(10)), CASE WHEN @n = 3 THEN 1 ELSE 0 END);

-- A3: mỗi tài khoản chưa xóa đúng 1 dòng
SET @n = (SELECT COUNT(*) FROM auth.vw_UserPermissions) - (SELECT COUNT(*) FROM auth.[User] WHERE IsDeleted = 0);
INSERT @Result VALUES (3, N'vw_UserPermissions: 1 dòng / tài khoản (chênh lệch)', N'0', CAST(@n AS NVARCHAR(10)), CASE WHEN @n = 0 THEN 1 ELSE 0 END);

-- A4: operator01 — MachineIds khớp bảng giao máy
SELECT @a = MachineIds FROM auth.vw_UserPermissions WHERE UserId = @op1;
SELECT @b = STRING_AGG(CAST(MachineId AS VARCHAR(10)), ',') WITHIN GROUP (ORDER BY MachineId)
FROM auth.UserMachine WHERE UserId = @op1;
INSERT @Result VALUES (4, N'vw_UserPermissions: MachineIds của operator01 khớp UserMachine', ISNULL(@b, N'NULL'), ISNULL(@a, N'NULL'),
       CASE WHEN @a = @b THEN 1 ELSE 0 END);

-- A5: admin có RoleName = Admin, không giao máy
SELECT @a = RoleName + N'/' + CAST(MachineCount AS NVARCHAR(10)) FROM auth.vw_UserPermissions WHERE Username = N'admin';
INSERT @Result VALUES (5, N'vw_UserPermissions: admin là Admin, 0 máy', N'Admin/0', ISNULL(@a, N'NULL'), CASE WHEN @a = N'Admin/0' THEN 1 ELSE 0 END);

-- A6: thống kê đăng nhập khớp tổng LoginHistory
SET @n = ISNULL((SELECT SUM(SuccessCount + FailedCount) FROM audit.vw_LoginActivity), 0) - (SELECT COUNT(*) FROM auth.LoginHistory);
INSERT @Result VALUES (6, N'vw_LoginActivity: tổng đúng + sai = số dòng LoginHistory (chênh lệch)', N'0', CAST(@n AS NVARCHAR(10)), CASE WHEN @n = 0 THEN 1 ELSE 0 END);

BEGIN TRANSACTION;
    -- A7: khóa 1 tài khoản qua procedure → 1 dòng ChangeLog, IsActive true → false
    SET @before = (SELECT COUNT(*) FROM audit.ChangeLog);
    SET @err = 0;
    BEGIN TRY EXEC auth.sp_DeactivateUser @UserId = @op2, @Activate = 0; END TRY
    BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
    SET @after = (SELECT COUNT(*) FROM audit.ChangeLog);
    SELECT TOP (1) @old = OldData, @new = NewData FROM audit.ChangeLog
    WHERE TableName = N'auth.User' AND RecordId = CAST(@op2 AS NVARCHAR(50)) ORDER BY ChangeId DESC;
    INSERT @Result VALUES (7, N'Trigger: khóa operator02 → 1 dòng ChangeLog, IsActive true→false', N'1 | true→false',
           CAST(@after - @before AS NVARCHAR(10)) + N' | ' + ISNULL(JSON_VALUE(@old, '$.IsActive'), N'?') + N'→' + ISNULL(JSON_VALUE(@new, '$.IsActive'), N'?'),
           CASE WHEN @err = 0 AND @after - @before = 1 AND JSON_VALUE(@old, '$.IsActive') = N'true'
                 AND JSON_VALUE(@new, '$.IsActive') = N'false' THEN 1 ELSE 0 END);

    -- A8: không lộ mật khẩu
    SET @n = (SELECT COUNT(*) FROM audit.ChangeLog
              WHERE TableName = N'auth.User'
                AND ((ISNULL(OldData, N'') + ISNULL(NewData, N'')) LIKE N'%PasswordHash%'
                  OR (ISNULL(OldData, N'') + ISNULL(NewData, N'')) LIKE N'%Salt%'));
    INSERT @Result VALUES (8, N'Trigger: ChangeLog không chứa PasswordHash / Salt', N'0', CAST(@n AS NVARCHAR(10)), CASE WHEN @n = 0 THEN 1 ELSE 0 END);

    -- A9: sửa nhiều dòng 1 lệnh → mỗi dòng 1 bản ghi
    SET @before = (SELECT COUNT(*) FROM audit.ChangeLog);
    UPDATE auth.[User] SET FullName = FullName + N' (test)' WHERE Username IN (N'kiosk01', N'kiosk02');
    SET @after = (SELECT COUNT(*) FROM audit.ChangeLog);
    INSERT @Result VALUES (9, N'Trigger: UPDATE 2 tài khoản 1 lệnh → 2 dòng ChangeLog', N'2', CAST(@after - @before AS NVARCHAR(10)),
           CASE WHEN @after - @before = 2 THEN 1 ELSE 0 END);

    -- A10: chỉ đổi LastLoginAt (mỗi lần đăng nhập) → không ghi
    SET @before = (SELECT COUNT(*) FROM audit.ChangeLog);
    UPDATE auth.[User] SET LastLoginAt = SYSUTCDATETIME() WHERE UserId = @op1;
    SET @after = (SELECT COUNT(*) FROM audit.ChangeLog);
    INSERT @Result VALUES (10, N'Trigger: chỉ đổi LastLoginAt thì KHÔNG ghi nhật ký', N'0', CAST(@after - @before AS NVARCHAR(10)),
           CASE WHEN @after = @before THEN 1 ELSE 0 END);
ROLLBACK TRANSACTION;

SELECT TestNo, TestCase, Expected, Actual, Passed FROM @Result ORDER BY TestNo;
DECLARE @pass INT = (SELECT COUNT(*) FROM @Result WHERE Passed = 1), @total INT = (SELECT COUNT(*) FROM @Result);
PRINT N'[tests_audit] ' + CAST(@pass AS NVARCHAR(10)) + N'/' + CAST(@total AS NVARCHAR(10)) + N' PASS';
GO
