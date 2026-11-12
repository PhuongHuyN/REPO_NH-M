-- =============================================================================
-- FILE        : 20_objects_auth.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : FV-21 (SCRUM-215) — View + trigger module auth / audit
--                 auth.vw_UserPermissions  : trang "Người dùng" (GET /api/auth/users)
--                 audit.vw_LoginActivity   : thống kê đăng nhập theo ngày (GET /api/auth/login-activity)
--                 auth.trg_Users_Audit     : ghi audit.ChangeLog (JSON cũ / mới) khi thêm / sửa user
-- VERSION     : 1.0.0
-- CREATED     : 2026-11-12
-- RUN ORDER   : Sau 02_tables_audit.sql, 10_procs_auth.sql (có auth.UserMachine,
--               LoginHistory.Username, LastLoginAt…) và 02_tables_inventory.sql.
-- ĐẶC TẢ      : app/api/test/fakeDb.js — 'auth.vw_UserPermissions', 'audit.vw_LoginActivity'
--               (tên cột phải giống hệt; app/web/js/pages/users.js đọc MachineIds, AssignedMachines).
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 1. auth.vw_UserPermissions — mỗi tài khoản 1 dòng (không gồm tài khoản đã xóa mềm)
--    MachineIds       : '1,2,3' — giao diện tick sẵn máy đã giao
--    AssignedMachines : 'VM-BK-01, VM-BK-02' — mã máy để hiển thị
--    Dùng OUTER APPLY (không GROUP BY) để 1 user nhiều máy / nhiều role không nhân dòng.
-- =============================================================================
CREATE OR ALTER VIEW auth.vw_UserPermissions
AS
SELECT u.UserId,
       u.Username,
       u.FullName,
       u.Email,
       rl.RoleName,
       u.IsActive,
       u.FailedLogins,
       u.LastLoginAt,
       u.CreatedAt,
       ISNULL(ma.MachineCount, 0) AS MachineCount,
       ma.MachineIds,
       ma.AssignedMachines
FROM   auth.[User] u
OUTER APPLY (SELECT TOP (1) r.RoleName
             FROM   auth.UserRole ur
             JOIN   auth.Role r ON r.RoleId = ur.RoleId
             WHERE  ur.UserId = u.UserId
             ORDER  BY r.RoleId) rl
OUTER APPLY (SELECT COUNT(*) AS MachineCount,
                    STRING_AGG(CAST(um.MachineId AS VARCHAR(10)), ',')
                        WITHIN GROUP (ORDER BY um.MachineId)              AS MachineIds,
                    STRING_AGG(m.MachineCode, N', ')
                        WITHIN GROUP (ORDER BY um.MachineId)              AS AssignedMachines
             FROM   auth.UserMachine um
             LEFT JOIN inventory.Machine m ON m.MachineId = um.MachineId
             WHERE  um.UserId = u.UserId) ma
WHERE  u.IsDeleted = 0;
GO

-- =============================================================================
-- 2. audit.vw_LoginActivity — số lần đăng nhập đúng / sai theo NGÀY (giờ VN)
--    LoginAt lưu UTC → cộng 7 giờ trước khi lấy ngày (giống fakeDb vnDate).
-- =============================================================================
CREATE OR ALTER VIEW audit.vw_LoginActivity
AS
SELECT CAST(DATEADD(HOUR, 7, h.LoginAt) AS DATE)                      AS LoginDate,
       SUM(CASE WHEN h.IsSuccess = 1 THEN 1 ELSE 0 END)               AS SuccessCount,
       SUM(CASE WHEN h.IsSuccess = 0 THEN 1 ELSE 0 END)               AS FailedCount,
       COUNT(DISTINCT COALESCE(h.Username, CAST(h.UserId AS NVARCHAR(20)))) AS DistinctUsers
FROM   auth.LoginHistory h
GROUP  BY CAST(DATEADD(HOUR, 7, h.LoginAt) AS DATE);
GO

-- =============================================================================
-- 3. auth.trg_Users_Audit — audit trail cho bảng auth.[User]
--    • AFTER INSERT, UPDATE; xử lý NHIỀU dòng một lúc (set-based, không cursor).
--    • OldData / NewData = JSON các cột nghiệp vụ; KHÔNG BAO GIỜ ghi PasswordHash, Salt.
--      Đổi mật khẩu chỉ ghi "PasswordChanged": true.
--    • Bỏ qua lần sửa chỉ đổi LastLoginAt / UpdatedAt (mỗi lần đăng nhập) → nhật ký không rác.
--    • Người thao tác: SESSION_CONTEXT(N'UserId') do API đặt (NULL khi chạy tay trong SSMS).
--    Trigger DML phải cùng schema với bảng → tên auth.trg_Users_Audit.
--    Mẫu này dùng lại được cho bảng khác (đổi tên bảng + danh sách cột).
-- =============================================================================
CREATE OR ALTER TRIGGER auth.trg_Users_Audit
ON auth.[User]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF OBJECT_ID(N'audit.ChangeLog', N'U') IS NULL RETURN;

    DECLARE @By INT = TRY_CAST(SESSION_CONTEXT(N'UserId') AS INT);

    INSERT audit.ChangeLog (TableName, RecordId, Action, OldData, NewData, UserId)
    SELECT N'auth.User',
           CAST(i.UserId AS NVARCHAR(50)),
           CASE WHEN d.UserId IS NULL THEN N'INSERT' ELSE N'UPDATE' END,
           CASE WHEN d.UserId IS NULL THEN NULL ELSE
               (SELECT d.Username, d.FullName, d.Email, d.IsActive, d.IsDeleted, d.FailedLogins
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) END,
           (SELECT i.Username, i.FullName, i.Email, i.IsActive, i.IsDeleted, i.FailedLogins,
                   CASE WHEN d.UserId IS NOT NULL AND d.PasswordHash <> i.PasswordHash
                        THEN CAST(1 AS BIT) END AS PasswordChanged
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
           @By
    FROM   inserted i
    LEFT JOIN deleted d ON d.UserId = i.UserId
    WHERE  d.UserId IS NULL                                    -- INSERT: luôn ghi
       OR  EXISTS (SELECT i.Username, i.FullName, i.Email, i.IsActive, i.IsDeleted, i.FailedLogins, i.PasswordHash
                   EXCEPT
                   SELECT d.Username, d.FullName, d.Email, d.IsActive, d.IsDeleted, d.FailedLogins, d.PasswordHash);
END
GO

PRINT N'[20-auth] Đã tạo/cập nhật: auth.vw_UserPermissions, audit.vw_LoginActivity, trigger auth.trg_Users_Audit.';
GO
