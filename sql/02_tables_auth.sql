-- =============================================================================
-- FILE        : 02_tables_auth.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV1 — Tạo các bảng thuộc schema [auth]
--               User, Role, UserRole, Permission, RolePermission,
--               RefreshToken, LoginHistory
-- VERSION     : 1.0.0
-- CREATED     : 2026-10-21
-- RUN ORDER   : Bước 2 — sau 01_schemas.sql
-- NOTE        : Không tạo FK liên schema ở đây. Xem 03_foreign_keys.sql.
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 1. auth.User
-- =============================================================================
-- Lưu thông tin tài khoản người dùng (nhân viên, quản trị viên).

IF NOT EXISTS (
    SELECT 1 FROM sys.tables
    WHERE object_id = OBJECT_ID(N'auth.User')
)
BEGIN
    CREATE TABLE auth.[User] (
        UserId          INT             NOT NULL IDENTITY(1,1),
        Username        NVARCHAR(50)    NOT NULL,
        PasswordHash    NVARCHAR(256)   NOT NULL,   -- bcrypt / SHA-256 hash
        FullName        NVARCHAR(100)   NOT NULL,
        Email           NVARCHAR(150)   NOT NULL,
        PhoneNumber     NVARCHAR(15)        NULL,
        AvatarUrl       NVARCHAR(500)       NULL,
        IsActive        BIT             NOT NULL CONSTRAINT DF_auth_User_IsActive    DEFAULT (1),
        IsDeleted       BIT             NOT NULL CONSTRAINT DF_auth_User_IsDeleted   DEFAULT (0),
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_auth_User_CreatedAt   DEFAULT SYSUTCDATETIME(),
        UpdatedAt       DATETIME2(0)        NULL,

        CONSTRAINT PK_auth_User         PRIMARY KEY (UserId),
        CONSTRAINT UQ_auth_User_Username UNIQUE (Username),
        CONSTRAINT UQ_auth_User_Email    UNIQUE (Email),
        CONSTRAINT CK_auth_User_Email    CHECK (Email LIKE N'%@%.%')
    );

    PRINT N'[02-auth] Bảng auth.User đã được tạo.';
END
ELSE
    PRINT N'[02-auth] Bảng auth.User đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 2. auth.Role
-- =============================================================================
-- Danh mục vai trò: Admin, Operator, Viewer, Technician…

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'auth.Role'))
BEGIN
    CREATE TABLE auth.Role (
        RoleId      INT             NOT NULL IDENTITY(1,1),
        RoleName    NVARCHAR(50)    NOT NULL,
        Description NVARCHAR(250)       NULL,
        IsActive    BIT             NOT NULL CONSTRAINT DF_auth_Role_IsActive  DEFAULT (1),
        CreatedAt   DATETIME2(0)    NOT NULL CONSTRAINT DF_auth_Role_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_auth_Role             PRIMARY KEY (RoleId),
        CONSTRAINT UQ_auth_Role_RoleName    UNIQUE (RoleName)
    );

    PRINT N'[02-auth] Bảng auth.Role đã được tạo.';
END
ELSE
    PRINT N'[02-auth] Bảng auth.Role đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 3. auth.UserRole  (bảng giao n-n giữa User và Role)
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'auth.UserRole'))
BEGIN
    CREATE TABLE auth.UserRole (
        UserRoleId  INT          NOT NULL IDENTITY(1,1),
        UserId      INT          NOT NULL,   -- FK → auth.User
        RoleId      INT          NOT NULL,   -- FK → auth.Role
        AssignedAt  DATETIME2(0) NOT NULL CONSTRAINT DF_auth_UserRole_AssignedAt DEFAULT SYSUTCDATETIME(),
        AssignedBy  INT              NULL,   -- FK → auth.User (người gán quyền)

        CONSTRAINT PK_auth_UserRole             PRIMARY KEY (UserRoleId),
        CONSTRAINT UQ_auth_UserRole_UserRole    UNIQUE (UserId, RoleId),
        CONSTRAINT FK_auth_UserRole_User        FOREIGN KEY (UserId)      REFERENCES auth.[User](UserId),
        CONSTRAINT FK_auth_UserRole_Role        FOREIGN KEY (RoleId)      REFERENCES auth.Role(RoleId),
        CONSTRAINT FK_auth_UserRole_AssignedBy  FOREIGN KEY (AssignedBy)  REFERENCES auth.[User](UserId)
    );

    PRINT N'[02-auth] Bảng auth.UserRole đã được tạo.';
END
ELSE
    PRINT N'[02-auth] Bảng auth.UserRole đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 4. auth.Permission
-- =============================================================================
-- Danh mục quyền chi tiết: inventory.read, sales.create, iot.write…

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'auth.Permission'))
BEGIN
    CREATE TABLE auth.Permission (
        PermissionId    INT             NOT NULL IDENTITY(1,1),
        PermissionName  NVARCHAR(100)   NOT NULL,   -- vd: 'inventory.product.read'
        Module          NVARCHAR(50)    NOT NULL,   -- vd: 'inventory'
        Description     NVARCHAR(250)       NULL,

        CONSTRAINT PK_auth_Permission               PRIMARY KEY (PermissionId),
        CONSTRAINT UQ_auth_Permission_Name          UNIQUE (PermissionName)
    );

    PRINT N'[02-auth] Bảng auth.Permission đã được tạo.';
END
ELSE
    PRINT N'[02-auth] Bảng auth.Permission đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 5. auth.RolePermission  (n-n: Role ←→ Permission)
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'auth.RolePermission'))
BEGIN
    CREATE TABLE auth.RolePermission (
        RolePermissionId    INT          NOT NULL IDENTITY(1,1),
        RoleId              INT          NOT NULL,
        PermissionId        INT          NOT NULL,
        GrantedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_auth_RolePermission_GrantedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_auth_RolePermission               PRIMARY KEY (RolePermissionId),
        CONSTRAINT UQ_auth_RolePermission_RolePerm      UNIQUE (RoleId, PermissionId),
        CONSTRAINT FK_auth_RolePermission_Role          FOREIGN KEY (RoleId)        REFERENCES auth.Role(RoleId),
        CONSTRAINT FK_auth_RolePermission_Permission    FOREIGN KEY (PermissionId)  REFERENCES auth.Permission(PermissionId)
    );

    PRINT N'[02-auth] Bảng auth.RolePermission đã được tạo.';
END
ELSE
    PRINT N'[02-auth] Bảng auth.RolePermission đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 6. auth.RefreshToken
-- =============================================================================
-- Lưu refresh token dùng cho xác thực JWT / session kéo dài.

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'auth.RefreshToken'))
BEGIN
    CREATE TABLE auth.RefreshToken (
        TokenId     INT             NOT NULL IDENTITY(1,1),
        UserId      INT             NOT NULL,
        Token       NVARCHAR(500)   NOT NULL,
        ExpiresAt   DATETIME2(0)    NOT NULL,
        IsRevoked   BIT             NOT NULL CONSTRAINT DF_auth_RefreshToken_IsRevoked DEFAULT (0),
        CreatedAt   DATETIME2(0)    NOT NULL CONSTRAINT DF_auth_RefreshToken_CreatedAt DEFAULT SYSUTCDATETIME(),
        RevokedAt   DATETIME2(0)        NULL,
        IpAddress   NVARCHAR(45)        NULL,   -- hỗ trợ IPv6
        UserAgent   NVARCHAR(500)       NULL,

        CONSTRAINT PK_auth_RefreshToken     PRIMARY KEY (TokenId),
        CONSTRAINT UQ_auth_RefreshToken     UNIQUE (Token),
        CONSTRAINT FK_auth_RefreshToken_User FOREIGN KEY (UserId) REFERENCES auth.[User](UserId)
    );

    PRINT N'[02-auth] Bảng auth.RefreshToken đã được tạo.';
END
ELSE
    PRINT N'[02-auth] Bảng auth.RefreshToken đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 7. auth.LoginHistory
-- =============================================================================
-- Lịch sử đăng nhập để phục vụ giám sát bảo mật.

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'auth.LoginHistory'))
BEGIN
    CREATE TABLE auth.LoginHistory (
        LoginId     BIGINT          NOT NULL IDENTITY(1,1),
        UserId      INT             NOT NULL,
        LoginAt     DATETIME2(0)    NOT NULL CONSTRAINT DF_auth_LoginHistory_LoginAt DEFAULT SYSUTCDATETIME(),
        IpAddress   NVARCHAR(45)        NULL,
        UserAgent   NVARCHAR(500)       NULL,
        IsSuccess   BIT             NOT NULL,
        FailReason  NVARCHAR(200)       NULL,

        CONSTRAINT PK_auth_LoginHistory         PRIMARY KEY (LoginId),
        CONSTRAINT FK_auth_LoginHistory_User    FOREIGN KEY (UserId) REFERENCES auth.[User](UserId)
    );

    PRINT N'[02-auth] Bảng auth.LoginHistory đã được tạo.';
END
ELSE
    PRINT N'[02-auth] Bảng auth.LoginHistory đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- XÁC NHẬN
-- =============================================================================

SELECT
    TABLE_SCHEMA    AS [Schema],
    TABLE_NAME      AS [Table],
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'auth'
ORDER BY TABLE_NAME;
GO

PRINT N'';
PRINT N'============================================================';
PRINT N'  TV1 (auth) hoàn tất. Tiếp theo: 02_tables_inventory.sql  ';
PRINT N'============================================================';
GO
