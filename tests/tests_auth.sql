-- =============================================================================
-- FILE        : tests_auth.sql
-- PROJECT     : FreshVend — TV1 (auth)
-- DESCRIPTION : FV-08 — 4 ca: login đúng, sai 5 lần khóa, tạo trùng, tự khóa
-- RUN ORDER   : Sau sql/10_procs_auth.sql
-- NOTE        : Không dùng INSERT…EXEC vì sp_Login trả 2 result set (lỗi 213).
-- =============================================================================

USE FreshVendDB;
GO

SET NOCOUNT ON;

DECLARE @Results TABLE (
    TestCode NVARCHAR(20)  NOT NULL,
    TestName NVARCHAR(120) NOT NULL,
    Passed   BIT           NOT NULL,
    Detail   NVARCHAR(500) NULL
);

IF OBJECT_ID(N'auth.sp_Login', N'P') IS NULL
BEGIN
    INSERT @Results VALUES (N'SKIP', N'Toan bo', 0, N'Chay sql/10_procs_auth.sql truoc.');
    GOTO PrintSummary;
END;

DECLARE @Ok BIT, @Role NVARCHAR(50), @Msg NVARCHAR(200);
DECLARE @LockUser INT, @LockMsg NVARCHAR(200), @Active BIT, @i INT;

-- Ca 1: admin / Admin@2026 → Success=1, RoleName=Admin
EXEC auth.sp_Login @Username = N'admin', @Password = N'Admin@2026';

SELECT TOP (1)
    @Ok  = h.IsSuccess,
    @Msg = CASE WHEN h.IsSuccess = 1 THEN N'Đăng nhập thành công' ELSE h.FailReason END
FROM auth.LoginHistory h
WHERE h.Username = N'admin' OR h.UserId = (SELECT UserId FROM auth.[User] WHERE Username = N'admin')
ORDER BY h.LoginId DESC;

SELECT @Role = r.RoleName
FROM auth.[User] u
JOIN auth.UserRole ur ON ur.UserId = u.UserId
JOIN auth.Role r ON r.RoleId = ur.RoleId
WHERE u.Username = N'admin';

INSERT @Results VALUES (
    N'UT01', N'Dang nhap dung admin',
    CASE WHEN @Ok = 1 AND @Role = N'Admin' THEN 1 ELSE 0 END,
    CONCAT(N'Success=', COALESCE(CONVERT(NVARCHAR(5), @Ok), N'NULL'),
           N' Role=', COALESCE(@Role, N'NULL'), N' Msg=', COALESCE(@Msg, N''))
);

-- Ca 2: sai 5 lần → khóa (user riêng, không đụng admin)
IF EXISTS (SELECT 1 FROM auth.[User] WHERE Username = N'fv08lock')
BEGIN
    DELETE FROM auth.LoginHistory WHERE UserId IN (SELECT UserId FROM auth.[User] WHERE Username = N'fv08lock')
        OR Username = N'fv08lock';
    DELETE FROM auth.UserMachine WHERE UserId IN (SELECT UserId FROM auth.[User] WHERE Username = N'fv08lock');
    DELETE FROM auth.UserRole WHERE UserId IN (SELECT UserId FROM auth.[User] WHERE Username = N'fv08lock');
    DELETE FROM auth.[User] WHERE Username = N'fv08lock';
END

EXEC auth.sp_CreateUser
    @Username = N'fv08lock', @Password = N'LockMe@2026',
    @FullName = N'User khoa test', @RoleName = N'Operator';
SELECT @LockUser = UserId FROM auth.[User] WHERE Username = N'fv08lock';

SET @i = 0;
WHILE @i < 5
BEGIN
    EXEC auth.sp_Login @Username = N'fv08lock', @Password = N'sai-mat-khau';
    SET @i += 1;
END

SELECT @Active = IsActive FROM auth.[User] WHERE UserId = @LockUser;
SELECT TOP (1) @LockMsg = FailReason
FROM auth.LoginHistory
WHERE UserId = @LockUser OR Username = N'fv08lock'
ORDER BY LoginId DESC;

INSERT @Results VALUES (
    N'UT02', N'Sai 5 lan thi khoa',
    CASE WHEN @Active = 0 AND @LockMsg LIKE N'%khóa%' THEN 1 ELSE 0 END,
    CONCAT(N'IsActive=', COALESCE(CONVERT(NVARCHAR(5), @Active), N'NULL'),
           N' Msg=', COALESCE(@LockMsg, N''))
);

-- Ca 3: sp_CreateUser admin → 50003
BEGIN TRY
    EXEC auth.sp_CreateUser
        @Username = N'admin', @Password = N'Admin@2026',
        @FullName = N'Trung', @RoleName = N'Admin',
        @Email = N'dup@freshvend.vn';
    INSERT @Results VALUES (N'UT03', N'Tao trung ten', 0, N'Khong THROW');
END TRY
BEGIN CATCH
    INSERT @Results VALUES (
        N'UT03', N'Tao trung ten',
        CASE WHEN ERROR_NUMBER() = 50003 THEN 1 ELSE 0 END,
        CONCAT(N'Err ', ERROR_NUMBER(), N': ', ERROR_MESSAGE())
    );
END CATCH;

-- Ca 4: tự khóa → 50031
BEGIN TRY
    EXEC sys.sp_set_session_context @key = N'UserId', @value = @LockUser;
    EXEC auth.sp_DeactivateUser @UserId = @LockUser, @Activate = 0;
    INSERT @Results VALUES (N'UT04', N'Tu khoa chinh minh', 0, N'Khong THROW');
END TRY
BEGIN CATCH
    INSERT @Results VALUES (
        N'UT04', N'Tu khoa chinh minh',
        CASE WHEN ERROR_NUMBER() = 50031 THEN 1 ELSE 0 END,
        CONCAT(N'Err ', ERROR_NUMBER(), N': ', ERROR_MESSAGE())
    );
END CATCH;

DELETE FROM auth.LoginHistory WHERE UserId = @LockUser OR Username = N'fv08lock';
DELETE FROM auth.UserRole WHERE UserId = @LockUser;
DELETE FROM auth.UserMachine WHERE UserId = @LockUser;
DELETE FROM auth.[User] WHERE UserId = @LockUser;
EXEC sys.sp_set_session_context @key = N'UserId', @value = NULL;

PrintSummary:
SELECT TestCode, TestName, Passed, Detail FROM @Results ORDER BY TestCode;

DECLARE @Pass INT = (SELECT COUNT(*) FROM @Results WHERE Passed = 1 AND TestCode LIKE N'UT%');
DECLARE @Fail INT = (SELECT COUNT(*) FROM @Results WHERE Passed = 0 AND TestCode LIKE N'UT%');
PRINT N'[tests_auth] FV-08 — Pass: ' + CAST(@Pass AS NVARCHAR(10))
    + N' | Fail: ' + CAST(@Fail AS NVARCHAR(10));
GO
