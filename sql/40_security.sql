-- =============================================================================
-- FILE        : 40_security.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : FV-22 (SCRUM-216) — Bảo mật CSDL
--                 1. 4 LOGIN + USER cho API (mỗi vai trò 1 login, đúng app/api/.env.example)
--                 2. 4 ROLE r_admin, r_operator, r_kiosk, r_device
--                 3. GRANT / DENY đúng bảng ALLOW (app/api/test/fakeDb.js dòng 16–28)
--                 4. Row-Level Security: Operator chỉ thấy máy được giao (auth.UserMachine)
-- VERSION     : 1.0.0
-- CREATED     : 2026-11-12
-- RUN ORDER   : CHẠY SAU CÙNG — sau toàn bộ 0x, 1x, 2x, 30 (GRANT trên object chỉ chạy
--               được khi object đã có). Object chưa có → in "BỎ QUA", không lỗi; khi
--               module đó xong (vd. view iot của SCRUM-259) chỉ cần chạy lại file này.
-- YÊU CẦU     : SQL Server bật "SQL Server and Windows Authentication mode" (Mixed Mode)
--               thì API mới đăng nhập bằng 4 login này được.
-- QUY ƯỚC     : • Chạy lại nhiều lần không lỗi.
--               • Mật khẩu PHẢI trùng app/api/.env (mặc định giống .env.example).
--                 Đổi mật khẩu thật khi triển khai: sửa cả 2 nơi.
--               • RLS gắn vào inventory.Machine, inventory.Slot và iot.Machines (nếu có).
--                 Hàm lọc dùng SCHEMABINDING nên khi đổi cấu trúc các bảng này (QĐ-1)
--                 phải gỡ trước:  DROP SECURITY POLICY auth.MachinePolicy;
--                                 DROP FUNCTION auth.fn_MachineSerialFilter;
--                 rồi chạy lại file này sau khi đổi xong.
--               • Giới hạn đã biết: Operator chỉ "thấy" ngăn của máy được giao, nên
--                 vw_ProductCatalog.ColumnCount của Operator chỉ đếm ngăn máy mình; ngừng
--                 bán sản phẩm (sp_UpdateProduct IsActive = 0) nên để Admin làm.
-- =============================================================================

-- =============================================================================
-- 1. LOGIN (cấp server)
-- =============================================================================
USE master;
GO

DECLARE @logins TABLE (LoginName SYSNAME, Pwd NVARCHAR(128));
INSERT @logins VALUES
    (N'fv_admin_app',    N'FreshVend@Admin2026'),
    (N'fv_operator_app', N'FreshVend@Operator2026'),
    (N'fv_kiosk_app',    N'FreshVend@Kiosk2026'),
    (N'fv_device_app',   N'FreshVend@Device2026');

DECLARE @name SYSNAME, @pwd NVARCHAR(128), @sql NVARCHAR(MAX);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT LoginName, Pwd FROM @logins;
OPEN c;
FETCH NEXT FROM c INTO @name, @pwd;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF SUSER_ID(@name) IS NULL
    BEGIN
        SET @sql = N'CREATE LOGIN ' + QUOTENAME(@name) + N' WITH PASSWORD = N' + QUOTENAME(@pwd, '''')
                 + N', DEFAULT_DATABASE = FreshVendDB, CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;';
        EXEC sys.sp_executesql @sql;
        PRINT N'[40-sec] Đã tạo login ' + @name;
    END
    ELSE
        PRINT N'[40-sec] Login ' + @name + N' đã có — giữ nguyên.';
    FETCH NEXT FROM c INTO @name, @pwd;
END
CLOSE c; DEALLOCATE c;

IF CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') AS INT) = 1
    PRINT N'[40-sec] CẢNH BÁO: SQL Server đang chỉ cho đăng nhập Windows. Bật Mixed Mode '
        + N'(SSMS → Properties → Security) rồi restart dịch vụ thì API mới dùng được 4 login này.';
GO

-- =============================================================================
-- 2. USER + ROLE (cấp CSDL)
-- =============================================================================
USE FreshVendDB;
GO

DECLARE @map TABLE (UserName SYSNAME, RoleName SYSNAME);
INSERT @map VALUES
    (N'fv_admin_app',    N'r_admin'),
    (N'fv_operator_app', N'r_operator'),
    (N'fv_kiosk_app',    N'r_kiosk'),
    (N'fv_device_app',   N'r_device');

DECLARE @u SYSNAME, @r SYSNAME, @sql NVARCHAR(MAX);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT UserName, RoleName FROM @map;
OPEN c;
FETCH NEXT FROM c INTO @u, @r;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF USER_ID(@u) IS NULL
    BEGIN
        SET @sql = N'CREATE USER ' + QUOTENAME(@u) + N' FOR LOGIN ' + QUOTENAME(@u) + N';';
        EXEC sys.sp_executesql @sql;
    END
    IF DATABASE_PRINCIPAL_ID(@r) IS NULL
    BEGIN
        SET @sql = N'CREATE ROLE ' + QUOTENAME(@r) + N';';
        EXEC sys.sp_executesql @sql;
    END
    IF IS_ROLEMEMBER(@r, @u) = 0
    BEGIN
        SET @sql = N'ALTER ROLE ' + QUOTENAME(@r) + N' ADD MEMBER ' + QUOTENAME(@u) + N';';
        EXEC sys.sp_executesql @sql;
    END
    FETCH NEXT FROM c INTO @u, @r;
END
CLOSE c; DEALLOCATE c;

-- Admin: toàn quyền trên CSDL (giống fakeDb: Admin không bị kiểm tra ALLOW)
IF IS_ROLEMEMBER(N'db_owner', N'fv_admin_app') = 0
    ALTER ROLE db_owner ADD MEMBER fv_admin_app;

PRINT N'[40-sec] 4 user + 4 role: xong.';
GO

-- =============================================================================
-- 3. GRANT / DENY theo bảng ALLOW
--    Operator : inventory.* ; iot.vw_MachineHealth, vw_OpenAlerts, fn_RecentTelemetry,
--               sp_AcknowledgeAlert, sp_ClearFault ; auth.sp_Login, sp_ChangePassword
--               KHÔNG được xem schema report (số liệu tài chính) → DENY
--    Kiosk    : auth.sp_Login, sp_ChangePassword ; sales.sp_CreateOrder, sp_ConfirmPayment,
--               sp_RecordDispense, sp_ExpirePendingOrders ; inventory.vw_StockStatus ;
--               sales.vw_OrderDetail, vw_DispenseQueue ; iot.vw_MachineHealth
--    Device   : iot.sp_IngestTelemetry ; sales.sp_RecordDispense ; sales.vw_DispenseQueue ;
--               iot.vw_MachineHealth
--    Kiểu bảng (TVP) cần quyền EXECUTE riêng thì mới truyền tham số được.
-- =============================================================================
DECLARE @g TABLE (Seq INT IDENTITY, Perm NVARCHAR(30), Obj NVARCHAR(200), RoleName SYSNAME, Kind CHAR(1));
-- Kind: S = schema, O = object, T = type
INSERT @g (Perm, Obj, RoleName, Kind) VALUES
    -- Operator
    (N'SELECT',  N'inventory',                      N'r_operator', 'S'),
    (N'EXECUTE', N'inventory',                      N'r_operator', 'S'),
    (N'EXECUTE', N'inventory.RestockItemType',      N'r_operator', 'T'),
    (N'SELECT',  N'iot.vw_MachineHealth',           N'r_operator', 'O'),
    (N'SELECT',  N'iot.vw_OpenAlerts',              N'r_operator', 'O'),
    (N'SELECT',  N'iot.fn_RecentTelemetry',         N'r_operator', 'O'),
    (N'EXECUTE', N'iot.sp_AcknowledgeAlert',        N'r_operator', 'O'),
    (N'EXECUTE', N'iot.sp_ClearFault',              N'r_operator', 'O'),
    (N'EXECUTE', N'auth.sp_Login',                  N'r_operator', 'O'),
    (N'EXECUTE', N'auth.sp_ChangePassword',         N'r_operator', 'O'),
    -- Kiosk
    (N'EXECUTE', N'auth.sp_Login',                  N'r_kiosk',    'O'),
    (N'EXECUTE', N'auth.sp_ChangePassword',         N'r_kiosk',    'O'),
    (N'EXECUTE', N'sales.sp_CreateOrder',           N'r_kiosk',    'O'),
    (N'EXECUTE', N'sales.sp_ConfirmPayment',        N'r_kiosk',    'O'),
    (N'EXECUTE', N'sales.sp_RecordDispense',        N'r_kiosk',    'O'),
    (N'EXECUTE', N'sales.sp_ExpirePendingOrders',   N'r_kiosk',    'O'),
    (N'EXECUTE', N'sales.OrderItemType',            N'r_kiosk',    'T'),
    (N'SELECT',  N'inventory.vw_StockStatus',       N'r_kiosk',    'O'),
    (N'SELECT',  N'sales.vw_OrderDetail',           N'r_kiosk',    'O'),
    (N'SELECT',  N'sales.vw_DispenseQueue',         N'r_kiosk',    'O'),
    (N'SELECT',  N'iot.vw_MachineHealth',           N'r_kiosk',    'O'),
    -- Device
    (N'EXECUTE', N'iot.sp_IngestTelemetry',         N'r_device',   'O'),
    (N'EXECUTE', N'sales.sp_RecordDispense',        N'r_device',   'O'),
    (N'SELECT',  N'sales.vw_DispenseQueue',         N'r_device',   'O'),
    (N'SELECT',  N'iot.vw_MachineHealth',           N'r_device',   'O');

DECLARE @perm NVARCHAR(30), @obj NVARCHAR(200), @role SYSNAME, @kind CHAR(1),
        @target NVARCHAR(300), @exists BIT, @sql NVARCHAR(MAX), @ok INT = 0, @skip INT = 0;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Perm, Obj, RoleName, Kind FROM @g ORDER BY Seq;
OPEN c;
FETCH NEXT FROM c INTO @perm, @obj, @role, @kind;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @exists = CASE @kind
        WHEN 'S' THEN CASE WHEN SCHEMA_ID(@obj) IS NOT NULL THEN 1 ELSE 0 END
        WHEN 'T' THEN CASE WHEN TYPE_ID(@obj)   IS NOT NULL THEN 1 ELSE 0 END
        ELSE          CASE WHEN OBJECT_ID(@obj) IS NOT NULL THEN 1 ELSE 0 END END;
    SET @target = CASE @kind
        WHEN 'S' THEN N'SCHEMA::' + QUOTENAME(@obj)
        WHEN 'T' THEN N'TYPE::'   + QUOTENAME(PARSENAME(@obj, 2)) + N'.' + QUOTENAME(PARSENAME(@obj, 1))
        ELSE          QUOTENAME(PARSENAME(@obj, 2)) + N'.' + QUOTENAME(PARSENAME(@obj, 1)) END;

    IF @exists = 1
    BEGIN
        SET @sql = N'GRANT ' + @perm + N' ON ' + @target + N' TO ' + QUOTENAME(@role) + N';';
        EXEC sys.sp_executesql @sql;
        SET @ok += 1;
    END
    ELSE
    BEGIN
        PRINT N'[40-sec] BỎ QUA (chưa có): ' + @perm + N' ' + @obj + N' → ' + @role;
        SET @skip += 1;
    END
    FETCH NEXT FROM c INTO @perm, @obj, @role, @kind;
END
CLOSE c; DEALLOCATE c;

-- Operator KHÔNG được xem số liệu tài chính (đề bài)
IF SCHEMA_ID(N'report') IS NOT NULL
    DENY SELECT, EXECUTE ON SCHEMA::report TO r_operator;

PRINT N'[40-sec] GRANT: ' + CAST(@ok AS NVARCHAR(10)) + N' quyền đã cấp, '
    + CAST(@skip AS NVARCHAR(10)) + N' bỏ qua vì object chưa có. DENY report → r_operator.';
GO

-- =============================================================================
-- 4. ROW-LEVEL SECURITY — Operator chỉ thấy máy được giao
--    UserId lấy từ SESSION_CONTEXT(N'UserId') mà app/api/src/db.js đặt trước MỖI lệnh.
--    Người không thuộc r_operator (admin, kiosk, device, dbo) thấy tất cả.
--    Lọc ở bảng gốc → mọi view / procedure đọc các bảng này đều bị lọc theo:
--      inventory.Machine  (theo MachineId)       → sp_Restock báo 50110 với máy khác
--      inventory.Slot     (theo MachineId)       → sp_AssignColumn báo 50105 với ngăn máy khác
--      iot.Machines       (theo Serial = MachineCode của máy được giao)
-- =============================================================================

-- Gỡ policy cũ trước khi sửa hàm lọc (hàm đang bị policy SCHEMABINDING)
IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = N'MachinePolicy' AND schema_id = SCHEMA_ID(N'auth'))
    DROP SECURITY POLICY auth.MachinePolicy;
GO

CREATE OR ALTER FUNCTION auth.fn_MachineFilter (@MachineId INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Allowed
    WHERE IS_MEMBER(N'r_operator') = 0
       OR EXISTS (SELECT 1
                  FROM   auth.UserMachine a
                  WHERE  a.MachineId = @MachineId
                    AND  a.UserId    = CAST(SESSION_CONTEXT(N'UserId') AS INT));
GO

CREATE OR ALTER FUNCTION auth.fn_MachineSerialFilter (@Serial NVARCHAR(50))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Allowed
    WHERE IS_MEMBER(N'r_operator') = 0
       OR EXISTS (SELECT 1
                  FROM   auth.UserMachine a
                  JOIN   inventory.Machine m ON m.MachineId = a.MachineId
                  WHERE  m.MachineCode = @Serial
                    AND  a.UserId      = CAST(SESSION_CONTEXT(N'UserId') AS INT));
GO

DECLARE @sql NVARCHAR(MAX) = N'CREATE SECURITY POLICY auth.MachinePolicy';
DECLARE @parts NVARCHAR(MAX) = N'';

IF OBJECT_ID(N'inventory.Machine', N'U') IS NOT NULL
    SET @parts += N', ADD FILTER PREDICATE auth.fn_MachineFilter(MachineId) ON inventory.Machine';
IF OBJECT_ID(N'inventory.Slot', N'U') IS NOT NULL
    SET @parts += N', ADD FILTER PREDICATE auth.fn_MachineFilter(MachineId) ON inventory.Slot';
IF OBJECT_ID(N'iot.Machines', N'U') IS NOT NULL
    SET @parts += N', ADD FILTER PREDICATE auth.fn_MachineSerialFilter(Serial) ON iot.Machines';

IF @parts <> N''
BEGIN
    SET @sql += N' ' + STUFF(@parts, 1, 2, N'') + N' WITH (STATE = ON);';
    EXEC sys.sp_executesql @sql;
    PRINT N'[40-sec] Đã bật Row-Level Security auth.MachinePolicy.';
END
ELSE
    PRINT N'[40-sec] BỎ QUA RLS: chưa có bảng máy.';
GO

-- =============================================================================
-- XÁC NHẬN: quyền của 4 role
-- =============================================================================
SELECT pr.name                                   AS [Role],
       pe.state_desc                             AS [State],
       pe.permission_name                        AS [Permission],
       CASE pe.class_desc
            WHEN N'SCHEMA'            THEN N'SCHEMA::' + SCHEMA_NAME(pe.major_id)
            WHEN N'TYPE'              THEN N'TYPE::' + (SELECT SCHEMA_NAME(t.schema_id) + N'.' + t.name
                                                         FROM sys.types t WHERE t.user_type_id = pe.major_id)
            ELSE OBJECT_SCHEMA_NAME(pe.major_id) + N'.' + OBJECT_NAME(pe.major_id) END AS [On]
FROM   sys.database_permissions pe
JOIN   sys.database_principals  pr ON pr.principal_id = pe.grantee_principal_id
WHERE  pr.name IN (N'r_operator', N'r_kiosk', N'r_device')
ORDER  BY [Role], [On], [Permission];
GO

PRINT N'[40-sec] Hoàn tất FV-22: 4 login, 4 role, GRANT/DENY theo ALLOW, RLS.';
GO
