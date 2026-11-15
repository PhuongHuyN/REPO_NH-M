-- =============================================================================
-- FILE        : 02_tables_audit.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : FV-06 (SCRUM-200) — Bảng nhật ký (schema audit)
--                 audit.ChangeLog : lịch sử THAY ĐỔI dữ liệu (giá trị cũ / mới dạng JSON),
--                                   do trigger ghi (vd. auth.trg_Users_Audit ở 20_objects_auth)
--                 audit.AuditLog  : nhật ký THAO TÁC của người dùng (ai làm gì, lúc nào)
--               (Bảng giao máy auth.UserMachine và các cột auth bổ sung đã được tạo ở
--                khối 0 của 10_procs_auth.sql — FV-08.)
-- VERSION     : 1.0.0
-- CREATED     : 2026-11-12
-- RUN ORDER   : Sau 01_schemas.sql và 02_tables_auth.sql. Chạy lại nhiều lần không lỗi.
--               FK UserId → auth.[User] nằm ở 03_foreign_keys.sql (mục F) — đúng quy ước
--               "FK liên schema chỉ đặt ở file 03".
-- QUY ƯỚC     : Giờ UTC (SYSUTCDATETIME). OldData / NewData / Detail bắt buộc là JSON hợp lệ.
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 1. audit.ChangeLog — mỗi dòng = 1 bản ghi bị thêm / sửa / xóa
-- =============================================================================
IF OBJECT_ID(N'audit.ChangeLog', N'U') IS NULL
BEGIN
    CREATE TABLE audit.ChangeLog (
        ChangeId    BIGINT          NOT NULL IDENTITY(1,1),
        TableName   NVARCHAR(128)   NOT NULL,          -- vd. 'auth.User'
        RecordId    NVARCHAR(50)    NOT NULL,          -- khóa của bản ghi (dạng chuỗi)
        Action      NVARCHAR(10)    NOT NULL,          -- INSERT | UPDATE | DELETE
        OldData     NVARCHAR(MAX)       NULL,          -- JSON giá trị cũ (NULL khi INSERT)
        NewData     NVARCHAR(MAX)       NULL,          -- JSON giá trị mới (NULL khi DELETE)
        UserId      INT                 NULL,          -- người thao tác (SESSION_CONTEXT) — FK ở 03
        ChangedAt   DATETIME2(0)    NOT NULL CONSTRAINT DF_audit_ChangeLog_ChangedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_audit_ChangeLog         PRIMARY KEY (ChangeId),
        CONSTRAINT CK_audit_ChangeLog_Action  CHECK (Action IN (N'INSERT', N'UPDATE', N'DELETE')),
        CONSTRAINT CK_audit_ChangeLog_OldJson CHECK (OldData IS NULL OR ISJSON(OldData) = 1),
        CONSTRAINT CK_audit_ChangeLog_NewJson CHECK (NewData IS NULL OR ISJSON(NewData) = 1)
    );
    -- Tra lịch sử 1 bản ghi, mới nhất trước
    CREATE INDEX IX_audit_ChangeLog_Record ON audit.ChangeLog (TableName, RecordId, ChangedAt DESC);
    PRINT N'[02-audit] Bảng audit.ChangeLog đã được tạo.';
END
ELSE
    PRINT N'[02-audit] Bảng audit.ChangeLog đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 2. audit.AuditLog — nhật ký thao tác (đăng nhập, xuất báo cáo, xóa lỗi máy…)
-- =============================================================================
IF OBJECT_ID(N'audit.AuditLog', N'U') IS NULL
BEGIN
    CREATE TABLE audit.AuditLog (
        AuditId     BIGINT          NOT NULL IDENTITY(1,1),
        UserId      INT                 NULL,          -- FK ở 03_foreign_keys.sql
        Action      NVARCHAR(50)    NOT NULL,          -- vd. 'EXPORT_SALES', 'CLEAR_FAULT'
        ObjectName  NVARCHAR(128)       NULL,          -- procedure / bảng liên quan
        Detail      NVARCHAR(MAX)       NULL,          -- JSON tham số / kết quả
        IpAddress   NVARCHAR(45)        NULL,
        CreatedAt   DATETIME2(0)    NOT NULL CONSTRAINT DF_audit_AuditLog_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_audit_AuditLog         PRIMARY KEY (AuditId),
        CONSTRAINT CK_audit_AuditLog_Detail  CHECK (Detail IS NULL OR ISJSON(Detail) = 1)
    );
    CREATE INDEX IX_audit_AuditLog_User_At ON audit.AuditLog (UserId, CreatedAt DESC) INCLUDE (Action, ObjectName);
    PRINT N'[02-audit] Bảng audit.AuditLog đã được tạo.';
END
ELSE
    PRINT N'[02-audit] Bảng audit.AuditLog đã tồn tại — bỏ qua.';
GO

SELECT TABLE_SCHEMA AS [Schema], TABLE_NAME AS [Table]
FROM   INFORMATION_SCHEMA.TABLES
WHERE  TABLE_SCHEMA = N'audit'
ORDER  BY TABLE_NAME;
GO
