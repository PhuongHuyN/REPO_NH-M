-- =============================================================================
-- FILE        : 10_procs_auth.sql
-- PROJECT     : FreshVend — TV1 (auth)
-- DESCRIPTION : FV-08 (SCRUM-202) — fn_HashPassword + 5 procedure auth
--               sp_Login, sp_CreateUser, sp_ChangePassword,
--               sp_AssignMachine, sp_DeactivateUser
-- RUN ORDER   : Sau 01_schemas.sql, 02_tables_auth.sql (và 02_tables_inventory
--               nếu muốn seed giao máy). Chạy lại được (CREATE OR ALTER).
-- ĐẶC TẢ      : app/api/test/fakeDb.js (dòng 87–144); app/api/src/routes/auth.js
-- MÃ LỖI      : 50001–50031 (THROW). sp_Login không THROW khi sai mật khẩu.
-- NOTE        : FV-06 chưa merge — khối 0 vá Salt/FailedLogins/UserMachine/LoginHistory
--               để procedure chạy được trên schema khung 21/10.
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 0. Vá schema cần cho procedure (idempotent — FV-06 sẽ đưa vào 02_tables_auth)
-- =============================================================================

IF COL_LENGTH(N'auth.[User]', N'Salt') IS NULL
    ALTER TABLE auth.[User] ADD Salt UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT DF_auth_User_Salt DEFAULT NEWID();
GO

IF COL_LENGTH(N'auth.[User]', N'FailedLogins') IS NULL
    ALTER TABLE auth.[User] ADD FailedLogins TINYINT NOT NULL
        CONSTRAINT DF_auth_User_FailedLogins DEFAULT 0;
GO

IF COL_LENGTH(N'auth.[User]', N'LastLoginAt') IS NULL
    ALTER TABLE auth.[User] ADD LastLoginAt DATETIME2(0) NULL;
GO

-- API tạo Kiosk không gửi email. UNIQUE thường chỉ cho 1 giá trị NULL → operator/kiosk thứ 2 lỗi 2627.
IF EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = N'CK_auth_User_Email' AND parent_object_id = OBJECT_ID(N'auth.[User]')
)
    ALTER TABLE auth.[User] DROP CONSTRAINT CK_auth_User_Email;
GO

IF EXISTS (
    SELECT 1 FROM sys.key_constraints
    WHERE name = N'UQ_auth_User_Email' AND parent_object_id = OBJECT_ID(N'auth.[User]')
)
    ALTER TABLE auth.[User] DROP CONSTRAINT UQ_auth_User_Email;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'auth.[User]') AND name=N'Email' AND is_nullable=0)
    ALTER TABLE auth.[User] ALTER COLUMN Email NVARCHAR(150) NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = N'CK_auth_User_Email' AND parent_object_id = OBJECT_ID(N'auth.[User]')
)
    ALTER TABLE auth.[User] WITH CHECK
        ADD CONSTRAINT CK_auth_User_Email CHECK (Email IS NULL OR Email LIKE N'%@%.%');
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UQ_auth_User_Email' AND object_id = OBJECT_ID(N'auth.[User]')
)
    CREATE UNIQUE INDEX UQ_auth_User_Email
        ON auth.[User] (Email)
        WHERE Email IS NOT NULL;
GO

-- Đăng nhập sai tên: UserId phải NULL được
IF EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_auth_LoginHistory_User'
)
    ALTER TABLE auth.LoginHistory DROP CONSTRAINT FK_auth_LoginHistory_User;
GO

ALTER TABLE auth.LoginHistory ALTER COLUMN UserId INT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_auth_LoginHistory_User')
    ALTER TABLE auth.LoginHistory WITH CHECK
        ADD CONSTRAINT FK_auth_LoginHistory_User
            FOREIGN KEY (UserId) REFERENCES auth.[User](UserId);
GO

IF COL_LENGTH(N'auth.LoginHistory', N'Username') IS NULL
    ALTER TABLE auth.LoginHistory ADD Username NVARCHAR(50) NULL;
GO

IF OBJECT_ID(N'auth.UserMachine', N'U') IS NULL
BEGIN
    CREATE TABLE auth.UserMachine (
        UserId     INT          NOT NULL,
        MachineId  INT          NOT NULL,
        AssignedAt DATETIME2(0) NOT NULL
            CONSTRAINT DF_auth_UserMachine_At DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_auth_UserMachine PRIMARY KEY (UserId, MachineId),
        CONSTRAINT FK_auth_UserMachine_User
            FOREIGN KEY (UserId) REFERENCES auth.[User](UserId)
    );
END;
GO

-- 3 vai trò API
MERGE auth.Role AS tgt
USING (VALUES
    (N'Admin',    N'Quản trị viên'),
    (N'Operator', N'Nhân viên vận hành'),
    (N'Kiosk',    N'Màn hình bán hàng tại máy')
) AS src (RoleName, Description)
ON tgt.RoleName = src.RoleName
WHEN NOT MATCHED THEN
    INSERT (RoleName, Description) VALUES (src.RoleName, src.Description);
GO

-- =============================================================================
-- 1. auth.fn_HashPassword — SHA2-256(password|salt), không lưu mật khẩu gốc
-- =============================================================================
CREATE OR ALTER FUNCTION auth.fn_HashPassword (
    @Password NVARCHAR(128),
    @Salt     UNIQUEIDENTIFIER
)
RETURNS NVARCHAR(64)
WITH SCHEMABINDING
AS
BEGIN
    RETURN CONVERT(NVARCHAR(64),
        HASHBYTES(N'SHA2_256', @Password + N'|' + CONVERT(NVARCHAR(36), @Salt)),
        2);
END
GO

-- =============================================================================
-- 2. auth.sp_CreateUser
--    50001 tên < 3 · 50002 MK < 8 · 50003 trùng tên · 50004 vai trò · 50005 họ tên trống
-- =============================================================================
CREATE OR ALTER PROCEDURE auth.sp_CreateUser
    @Username NVARCHAR(50),
    @Password NVARCHAR(128),
    @FullName NVARCHAR(100),
    @RoleName NVARCHAR(50),
    @Email    NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Username = LOWER(LTRIM(RTRIM(ISNULL(@Username, N''))));
    SET @FullName = LTRIM(RTRIM(@FullName));
    SET @Email    = NULLIF(LTRIM(RTRIM(@Email)), N'');
    SET @RoleName = LTRIM(RTRIM(@RoleName));

    IF LEN(@Username) < 3
        THROW 50001, N'Tên đăng nhập phải có ít nhất 3 ký tự', 1;
    IF @Password IS NULL OR LEN(@Password) < 8
        THROW 50002, N'Mật khẩu phải có ít nhất 8 ký tự', 1;
    IF EXISTS (SELECT 1 FROM auth.[User] WHERE Username = @Username)
        THROW 50003, N'Tên đăng nhập đã tồn tại', 1;
    IF NOT EXISTS (SELECT 1 FROM auth.Role WHERE RoleName = @RoleName AND IsActive = 1)
        THROW 50004, N'Vai trò không hợp lệ (Admin, Operator, Kiosk)', 1;
    IF @FullName IS NULL OR @FullName = N''
        THROW 50005, N'Họ tên không được để trống', 1;

    DECLARE @Salt UNIQUEIDENTIFIER = NEWID();
    DECLARE @Hash NVARCHAR(64) = auth.fn_HashPassword(@Password, @Salt);
    DECLARE @UserId INT;
    DECLARE @RoleId INT = (SELECT RoleId FROM auth.Role WHERE RoleName = @RoleName);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT auth.[User] (Username, PasswordHash, Salt, FullName, Email, IsActive, FailedLogins)
        VALUES (@Username, @Hash, @Salt, @FullName, @Email, 1, 0);

        SET @UserId = CONVERT(INT, SCOPE_IDENTITY());

        INSERT auth.UserRole (UserId, RoleId)
        VALUES (@UserId, @RoleId);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @UserId AS UserId, @Username AS Username, @RoleName AS RoleName;
END
GO

-- =============================================================================
-- 3. auth.sp_Login — 2 bảng kết quả; sai MK không THROW (API trả 401)
-- =============================================================================
CREATE OR ALTER PROCEDURE auth.sp_Login
    @Username   NVARCHAR(50),
    @Password   NVARCHAR(128),
    @ClientInfo NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserId INT, @Salt UNIQUEIDENTIFIER, @Hash NVARCHAR(64),
            @Stored NVARCHAR(256), @IsActive BIT, @Failed TINYINT,
            @FullName NVARCHAR(100), @RoleName NVARCHAR(50),
            @Ok BIT = 0, @Msg NVARCHAR(200);

    SET @Username = LOWER(LTRIM(RTRIM(ISNULL(@Username, N''))));

    SELECT
        @UserId   = u.UserId,
        @Salt     = u.Salt,
        @Stored   = u.PasswordHash,
        @IsActive = u.IsActive,
        @Failed   = u.FailedLogins,
        @FullName = u.FullName,
        @RoleName = r.RoleName
    FROM auth.[User] u
    LEFT JOIN auth.UserRole ur ON ur.UserId = u.UserId
    LEFT JOIN auth.Role r ON r.RoleId = ur.RoleId
    WHERE u.Username = @Username
      AND ISNULL(u.IsDeleted, 0) = 0;

    IF @UserId IS NULL
        SET @Msg = N'Sai tên đăng nhập hoặc mật khẩu';
    ELSE IF @IsActive = 0
        SET @Msg = N'Tài khoản đã bị khóa. Liên hệ quản trị viên';
    ELSE
    BEGIN
        SET @Hash = auth.fn_HashPassword(@Password, @Salt);
        IF @Hash <> @Stored
        BEGIN
            SET @Failed = CAST(@Failed AS INT) + 1;
            IF @Failed >= 5
            BEGIN
                UPDATE auth.[User]
                SET FailedLogins = @Failed, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
                WHERE UserId = @UserId;
                SET @Msg = N'Sai mật khẩu 5 lần – tài khoản đã bị khóa';
            END
            ELSE
            BEGIN
                UPDATE auth.[User]
                SET FailedLogins = @Failed, UpdatedAt = SYSUTCDATETIME()
                WHERE UserId = @UserId;
                SET @Msg = N'Sai tên đăng nhập hoặc mật khẩu (còn '
                    + CONVERT(NVARCHAR(5), 5 - @Failed) + N' lần thử)';
            END
        END
        ELSE
        BEGIN
            UPDATE auth.[User]
            SET FailedLogins = 0, LastLoginAt = SYSUTCDATETIME(), UpdatedAt = SYSUTCDATETIME()
            WHERE UserId = @UserId;
            SET @Ok = 1;
            SET @Msg = N'Đăng nhập thành công';
        END
    END

    INSERT auth.LoginHistory (UserId, Username, IsSuccess, FailReason, UserAgent)
    VALUES (
        CASE WHEN @Ok = 1 OR @UserId IS NOT NULL THEN @UserId END,
        @Username,
        @Ok,
        CASE WHEN @Ok = 1 THEN NULL ELSE @Msg END,
        @ClientInfo
    );

    SELECT
        @Ok AS Success,
        @Msg AS Message,
        CASE WHEN @Ok = 1 THEN @UserId END AS UserId,
        CASE WHEN @Ok = 1 THEN @Username END AS Username,
        CASE WHEN @Ok = 1 THEN @FullName END AS FullName,
        CASE WHEN @Ok = 1 THEN @RoleName END AS RoleName;

    SELECT MachineId
    FROM auth.UserMachine
    WHERE UserId = @UserId AND @Ok = 1;
END
GO

-- =============================================================================
-- 4. auth.sp_ChangePassword
--    50010 không tồn tại/khóa · 50011 MK cũ sai · 50002 MK mới ngắn · 50012 trùng MK cũ
-- =============================================================================
CREATE OR ALTER PROCEDURE auth.sp_ChangePassword
    @UserId      INT,
    @OldPassword NVARCHAR(128),
    @NewPassword NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Salt UNIQUEIDENTIFIER, @Stored NVARCHAR(256), @IsActive BIT;

    SELECT @Salt = Salt, @Stored = PasswordHash, @IsActive = IsActive
    FROM auth.[User]
    WHERE UserId = @UserId AND ISNULL(IsDeleted, 0) = 0;

    IF @Salt IS NULL OR @IsActive = 0
        THROW 50010, N'Người dùng không tồn tại hoặc đã bị khóa', 1;
    IF auth.fn_HashPassword(@OldPassword, @Salt) <> @Stored
        THROW 50011, N'Mật khẩu cũ không đúng', 1;
    IF @NewPassword IS NULL OR LEN(@NewPassword) < 8
        THROW 50002, N'Mật khẩu phải có ít nhất 8 ký tự', 1;
    IF @NewPassword = @OldPassword
        THROW 50012, N'Mật khẩu mới phải khác mật khẩu cũ', 1;

    SET @Salt = NEWID();

    UPDATE auth.[User]
    SET Salt = @Salt,
        PasswordHash = auth.fn_HashPassword(@NewPassword, @Salt),
        UpdatedAt = SYSUTCDATETIME()
    WHERE UserId = @UserId;

    SELECT @UserId AS UserId, N'Đã đổi mật khẩu' AS Message;
END
GO

-- =============================================================================
-- 5. auth.sp_AssignMachine
--    50020 user · 50021 không phải Operator/Kiosk · 50022 máy không tồn tại
-- =============================================================================
CREATE OR ALTER PROCEDURE auth.sp_AssignMachine
    @UserId    INT,
    @MachineId INT,
    @Unassign  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RoleName NVARCHAR(50);

    SELECT @RoleName = r.RoleName
    FROM auth.[User] u
    LEFT JOIN auth.UserRole ur ON ur.UserId = u.UserId
    LEFT JOIN auth.Role r ON r.RoleId = ur.RoleId
    WHERE u.UserId = @UserId AND ISNULL(u.IsDeleted, 0) = 0;

    IF @RoleName IS NULL AND NOT EXISTS (SELECT 1 FROM auth.[User] WHERE UserId = @UserId)
        THROW 50020, N'Người dùng không tồn tại', 1;
    IF @RoleName IS NULL
        THROW 50020, N'Người dùng không tồn tại', 1;
    IF @RoleName NOT IN (N'Operator', N'Kiosk')
        THROW 50021, N'Chỉ giao máy cho tài khoản Operator hoặc Kiosk', 1;

    IF OBJECT_ID(N'inventory.Machine', N'U') IS NULL
        OR NOT EXISTS (SELECT 1 FROM inventory.Machine WHERE MachineId = @MachineId)
        THROW 50022, N'Máy không tồn tại', 1;

    IF @Unassign = 1
        DELETE FROM auth.UserMachine
        WHERE UserId = @UserId AND MachineId = @MachineId;
    ELSE IF NOT EXISTS (
        SELECT 1 FROM auth.UserMachine WHERE UserId = @UserId AND MachineId = @MachineId
    )
        INSERT auth.UserMachine (UserId, MachineId)
        VALUES (@UserId, @MachineId);

    SELECT
        um.UserId,
        um.MachineId,
        um.AssignedAt,
        m.MachineCode AS Serial
    FROM auth.UserMachine um
    LEFT JOIN inventory.Machine m ON m.MachineId = um.MachineId
    WHERE um.UserId = @UserId;
END
GO

-- =============================================================================
-- 6. auth.sp_DeactivateUser — không xóa; 50031 không tự khóa (SESSION_CONTEXT)
-- =============================================================================
CREATE OR ALTER PROCEDURE auth.sp_DeactivateUser
    @UserId   INT,
    @Activate BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM auth.[User] WHERE UserId = @UserId AND ISNULL(IsDeleted, 0) = 0)
        THROW 50030, N'Người dùng không tồn tại', 1;

    DECLARE @Self INT = TRY_CAST(SESSION_CONTEXT(N'UserId') AS INT);
    IF @Activate = 0 AND @Self IS NOT NULL AND @UserId = @Self
        THROW 50031, N'Không thể tự khóa tài khoản của chính mình', 1;

    UPDATE auth.[User]
    SET IsActive = @Activate,
        FailedLogins = CASE WHEN @Activate = 1 THEN 0 ELSE FailedLogins END,
        UpdatedAt = SYSUTCDATETIME()
    WHERE UserId = @UserId;

    SELECT UserId, Username, IsActive
    FROM auth.[User]
    WHERE UserId = @UserId;
END
GO

-- =============================================================================
-- 7. Seed tài khoản demo (idempotent) + giao máy nếu đã có inventory.Machine
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM auth.[User] WHERE Username = N'admin')
    EXEC auth.sp_CreateUser
        @Username = N'admin', @Password = N'Admin@2026',
        @FullName = N'Nguyễn Phương Huy', @RoleName = N'Admin',
        @Email = N'admin@freshvend.vn';

IF NOT EXISTS (SELECT 1 FROM auth.[User] WHERE Username = N'operator01')
    EXEC auth.sp_CreateUser
        @Username = N'operator01', @Password = N'Operator@2026',
        @FullName = N'Nguyễn Văn An', @RoleName = N'Operator';

IF NOT EXISTS (SELECT 1 FROM auth.[User] WHERE Username = N'operator02')
    EXEC auth.sp_CreateUser
        @Username = N'operator02', @Password = N'Operator@2026',
        @FullName = N'Trần Thị Bình', @RoleName = N'Operator';

IF NOT EXISTS (SELECT 1 FROM auth.[User] WHERE Username = N'kiosk01')
    EXEC auth.sp_CreateUser
        @Username = N'kiosk01', @Password = N'Kiosk@2026',
        @FullName = N'Kiosk FV-HCM-001', @RoleName = N'Kiosk';
IF NOT EXISTS (SELECT 1 FROM auth.[User] WHERE Username = N'kiosk02')
    EXEC auth.sp_CreateUser
        @Username = N'kiosk02', @Password = N'Kiosk@2026',
        @FullName = N'Kiosk FV-HCM-002', @RoleName = N'Kiosk';
IF NOT EXISTS (SELECT 1 FROM auth.[User] WHERE Username = N'kiosk03')
    EXEC auth.sp_CreateUser
        @Username = N'kiosk03', @Password = N'Kiosk@2026',
        @FullName = N'Kiosk FV-HCM-003', @RoleName = N'Kiosk';
IF NOT EXISTS (SELECT 1 FROM auth.[User] WHERE Username = N'kiosk04')
    EXEC auth.sp_CreateUser
        @Username = N'kiosk04', @Password = N'Kiosk@2026',
        @FullName = N'Kiosk FV-HCM-004', @RoleName = N'Kiosk';
IF NOT EXISTS (SELECT 1 FROM auth.[User] WHERE Username = N'kiosk05')
    EXEC auth.sp_CreateUser
        @Username = N'kiosk05', @Password = N'Kiosk@2026',
        @FullName = N'Kiosk FV-HCM-005', @RoleName = N'Kiosk';
GO

-- Giao máy chỉ khi đã có inventory.Machine (dynamic SQL: batch vẫn chạy nếu chưa có bảng máy)
IF OBJECT_ID(N'inventory.Machine', N'U') IS NOT NULL
    EXEC sys.sp_executesql N'
        DECLARE @Uid INT, @Mid INT;

        SELECT @Uid = UserId FROM auth.[User] WHERE Username = N''operator01'';
        IF @Uid IS NOT NULL
        BEGIN
            DECLARE c CURSOR LOCAL FAST_FORWARD FOR
                SELECT TOP (3) MachineId FROM inventory.Machine WHERE IsActive = 1 ORDER BY MachineId;
            OPEN c;
            FETCH NEXT FROM c INTO @Mid;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM auth.UserMachine WHERE UserId = @Uid AND MachineId = @Mid)
                    EXEC auth.sp_AssignMachine @UserId = @Uid, @MachineId = @Mid, @Unassign = 0;
                FETCH NEXT FROM c INTO @Mid;
            END
            CLOSE c; DEALLOCATE c;
        END

        SELECT @Uid = UserId FROM auth.[User] WHERE Username = N''operator02'';
        IF @Uid IS NOT NULL
        BEGIN
            DECLARE c2 CURSOR LOCAL FAST_FORWARD FOR
                SELECT MachineId FROM (
                    SELECT MachineId, ROW_NUMBER() OVER (ORDER BY MachineId) AS rn
                    FROM inventory.Machine WHERE IsActive = 1
                ) x WHERE rn IN (4, 5);
            OPEN c2;
            FETCH NEXT FROM c2 INTO @Mid;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM auth.UserMachine WHERE UserId = @Uid AND MachineId = @Mid)
                    EXEC auth.sp_AssignMachine @UserId = @Uid, @MachineId = @Mid, @Unassign = 0;
                FETCH NEXT FROM c2 INTO @Mid;
            END
            CLOSE c2; DEALLOCATE c2;
        END

        DECLARE @k INT = 1;
        WHILE @k <= 5
        BEGIN
            SELECT @Uid = UserId FROM auth.[User]
            WHERE Username = N''kiosk0'' + CONVERT(NVARCHAR(1), @k);
            SELECT @Mid = MachineId FROM (
                SELECT MachineId, ROW_NUMBER() OVER (ORDER BY MachineId) AS rn
                FROM inventory.Machine WHERE IsActive = 1
            ) x WHERE rn = @k;
            IF @Uid IS NOT NULL AND @Mid IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM auth.UserMachine WHERE UserId = @Uid AND MachineId = @Mid)
                EXEC auth.sp_AssignMachine @UserId = @Uid, @MachineId = @Mid, @Unassign = 0;
            SET @k += 1;
        END
    ';
GO

PRINT N'[10-auth] fn_HashPassword + 5 procedure + seed demo xong.';
GO
