-- =============================================================================
-- FILE        : 00_database.sql
-- PROJECT     : FreshVend — Smart IoT Fruit Vending Machine
-- DESCRIPTION : TV1 - Tạo CSDL FreshVendDB và thiết lập collation tiếng Việt
-- RUN ORDER   : 00 (Chạy đầu tiên với quyền sysadmin/dbcreator)
-- =============================================================================

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'FreshVendDB')
BEGIN
    CREATE DATABASE FreshVendDB
        COLLATE Vietnamese_CI_AS;
    PRINT N'[00] Database FreshVendDB đã được tạo thành công.';
END
ELSE
BEGIN
    PRINT N'[00] Database FreshVendDB đã tồn tại — bỏ qua tạo mới.';
END
GO

USE FreshVendDB;
GO

-- Bật READ_COMMITTED_SNAPSHOT để hỗ trợ hiệu năng đọc/ghi đồng thời
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'FreshVendDB' AND is_read_committed_snapshot_on = 0)
BEGIN
    ALTER DATABASE FreshVendDB SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
    PRINT N'[00] Đã kích hoạt READ_COMMITTED_SNAPSHOT ON.';
END
GO
