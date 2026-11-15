-- =============================================================================
-- FILE        : tests/tests_security.sql
-- PROJECT     : FreshVend
-- DESCRIPTION : FV-22 (SCRUM-216) — Kiểm thử 40_security.sql (chạy trong SSMS)
--               Đóng vai từng login bằng EXECUTE AS USER, đặt SESSION_CONTEXT
--               giống app/api/src/db.js, rồi kiểm tra quyền + Row-Level Security.
-- CÁCH CHẠY   : Sau 00 → 30 và 10_procs_auth.sql (có operator01 được giao 3 máy),
--               cuối cùng 40_security.sql. Chạy bằng tài khoản sysadmin (Windows).
--               Chỉ đọc dữ liệu / gọi lệnh bị từ chối → không làm bẩn CSDL.
-- KẾT QUẢ     : Bảng cuối file, Passed = 1 là đạt; dòng Messages "[tests_security] x/11 PASS".
-- =============================================================================

USE FreshVendDB;
GO

SET NOCOUNT ON;

DECLARE @Result TABLE (TestNo INT, TestCase NVARCHAR(200), Expected NVARCHAR(100), Actual NVARCHAR(100), Passed BIT);
DECLARE @n INT, @err INT, @op1 INT, @assigned INT, @allMachines INT, @otherMachine INT,
        @seen INT, @seen2 INT;
DECLARE @items inventory.RestockItemType;
DECLARE @reportObj NVARCHAR(300), @rsql NVARCHAR(400);
SELECT TOP (1) @reportObj = QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name)
FROM sys.objects WHERE schema_id = SCHEMA_ID(N'report') AND type IN ('U', 'V')
ORDER BY CASE type WHEN 'V' THEN 0 ELSE 1 END, name;

SELECT @op1 = UserId FROM auth.[User] WHERE Username = N'operator01';
SELECT @assigned = COUNT(*) FROM auth.UserMachine WHERE UserId = @op1;
SELECT @allMachines = COUNT(*) FROM inventory.Machine;
SELECT TOP (1) @otherMachine = MachineId FROM inventory.Machine
WHERE MachineId NOT IN (SELECT MachineId FROM auth.UserMachine WHERE UserId = @op1)
ORDER BY MachineId;

-- S1: đủ 4 login
SET @n = (SELECT COUNT(*) FROM sys.server_principals
          WHERE name IN (N'fv_admin_app', N'fv_operator_app', N'fv_kiosk_app', N'fv_device_app'));
INSERT @Result VALUES (1, N'Có đủ 4 login fv_*_app', N'4', CAST(@n AS NVARCHAR(10)), CASE WHEN @n = 4 THEN 1 ELSE 0 END);

-- S2: mỗi user đúng role
SET @n = ISNULL(IS_ROLEMEMBER(N'r_operator', N'fv_operator_app'), 0) + ISNULL(IS_ROLEMEMBER(N'r_kiosk', N'fv_kiosk_app'), 0)
       + ISNULL(IS_ROLEMEMBER(N'r_device', N'fv_device_app'), 0) + ISNULL(IS_ROLEMEMBER(N'db_owner', N'fv_admin_app'), 0);
INSERT @Result VALUES (2, N'4 user thuộc đúng role (admin = db_owner)', N'4', CAST(@n AS NVARCHAR(10)), CASE WHEN @n = 4 THEN 1 ELSE 0 END);

-- S3: policy RLS đang bật, gắn ≥ 2 bảng
SET @n = (SELECT COUNT(*) FROM sys.security_predicates sp
          JOIN sys.security_policies p ON p.object_id = sp.object_id
          WHERE p.name = N'MachinePolicy' AND p.is_enabled = 1);
INSERT @Result VALUES (3, N'RLS auth.MachinePolicy bật, số bảng được lọc', N'>=2', CAST(@n AS NVARCHAR(10)), CASE WHEN @n >= 2 THEN 1 ELSE 0 END);

-- S4–S7: đóng vai Operator operator01
EXEC sys.sp_set_session_context @key = N'UserId', @value = @op1;
EXECUTE AS USER = N'fv_operator_app';
    SET @seen  = (SELECT COUNT(*) FROM inventory.Machine);
    SET @seen2 = (SELECT COUNT(DISTINCT MachineId) FROM inventory.vw_StockStatus);

    -- Lấy 1 bảng/view bất kỳ của schema report (không phụ thuộc file 24 của TV5)
    SET @err = 0;
    IF @reportObj IS NULL SET @err = -1;
    ELSE
    BEGIN TRY
        SET @rsql = N'SELECT TOP (1) 1 FROM ' + @reportObj + N';';
        EXEC sys.sp_executesql @rsql;
    END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;

    INSERT @items VALUES (1, 1, 1);
    DECLARE @err7 INT = 0;
    BEGIN TRY EXEC inventory.sp_Restock @MachineId = @otherMachine, @UserId = @op1, @Items = @items; END TRY
    BEGIN CATCH SET @err7 = ERROR_NUMBER(); END CATCH;
REVERT;

INSERT @Result VALUES (4, N'RLS: operator01 chỉ thấy máy được giao (inventory.Machine)',
       CAST(@assigned AS NVARCHAR(10)), CAST(@seen AS NVARCHAR(10)),
       CASE WHEN @assigned > 0 AND @seen = @assigned AND @allMachines > @assigned THEN 1 ELSE 0 END);
INSERT @Result VALUES (5, N'RLS: vw_StockStatus của operator01 chỉ có máy được giao',
       CAST(@assigned AS NVARCHAR(10)), CAST(@seen2 AS NVARCHAR(10)), CASE WHEN @seen2 = @assigned THEN 1 ELSE 0 END);
INSERT @Result VALUES (6, N'DENY: Operator xem report (số liệu tài chính)', N'229',
       CASE WHEN @err = -1 THEN N'BỎ QUA: schema report chưa có bảng/view nào' ELSE CAST(@err AS NVARCHAR(10)) + N' (' + @reportObj + N')' END,
       CASE WHEN @err = 229 THEN 1 ELSE 0 END);
INSERT @Result VALUES (7, N'RLS: Operator châm hàng máy KHÔNG được giao', N'50110', CAST(@err7 AS NVARCHAR(10)), CASE WHEN @err7 = 50110 THEN 1 ELSE 0 END);

-- S8–S9: đóng vai Kiosk
EXEC sys.sp_set_session_context @key = N'UserId', @value = NULL;
EXECUTE AS USER = N'fv_kiosk_app';
    SET @err = 0;
    BEGIN TRY EXEC inventory.sp_AddProduct @ProductName = N'__TEST__ kiosk', @Price = 1000, @ShelfLifeHours = 24; END TRY
    BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
    DECLARE @err9 INT = 0;
    BEGIN TRY SET @seen = (SELECT COUNT(DISTINCT MachineId) FROM inventory.vw_StockStatus); END TRY
    BEGIN CATCH SET @err9 = ERROR_NUMBER(); END CATCH;
REVERT;
INSERT @Result VALUES (8, N'Kiosk gọi inventory.sp_AddProduct bị từ chối', N'229', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 229 THEN 1 ELSE 0 END);
INSERT @Result VALUES (9, N'Kiosk đọc vw_StockStatus được, thấy mọi máy', CAST(@allMachines AS NVARCHAR(10)),
       CASE WHEN @err9 <> 0 THEN N'lỗi ' + CAST(@err9 AS NVARCHAR(10)) ELSE CAST(@seen AS NVARCHAR(10)) END,
       CASE WHEN @err9 = 0 AND @seen = (SELECT COUNT(DISTINCT s.MachineId) FROM inventory.Slot s WHERE s.IsActive = 1) THEN 1 ELSE 0 END);

-- S10: đóng vai Device
EXECUTE AS USER = N'fv_device_app';
    SET @err = 0;
    BEGIN TRY SET @n = (SELECT COUNT(*) FROM inventory.vw_ProductCatalog); END TRY
    BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
REVERT;
INSERT @Result VALUES (10, N'Device đọc danh mục sản phẩm bị từ chối', N'229', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 229 THEN 1 ELSE 0 END);

-- S11: Operator KHÔNG có SESSION_CONTEXT (gọi thẳng, không qua API) → không thấy máy nào
EXEC sys.sp_set_session_context @key = N'UserId', @value = NULL;
EXECUTE AS USER = N'fv_operator_app';
    SET @seen = (SELECT COUNT(*) FROM inventory.Machine);
REVERT;
INSERT @Result VALUES (11, N'RLS: Operator thiếu UserId không thấy máy nào', N'0', CAST(@seen AS NVARCHAR(10)), CASE WHEN @seen = 0 THEN 1 ELSE 0 END);

SELECT TestNo, TestCase, Expected, Actual, Passed FROM @Result ORDER BY TestNo;
DECLARE @pass INT = (SELECT COUNT(*) FROM @Result WHERE Passed = 1), @total INT = (SELECT COUNT(*) FROM @Result);
PRINT N'[tests_security] ' + CAST(@pass AS NVARCHAR(10)) + N'/' + CAST(@total AS NVARCHAR(10)) + N' PASS';
GO
