-- =============================================================================
-- FILE        : 01_schemas.sql
-- PROJECT     : FreshVend — Smart IoT Fruit Vending Machine
-- DESCRIPTION : TV1 - Tạo 6 schema nghiệp vụ phân chia module hệ thống
-- SCHEMAS     : auth, audit, inventory, sales, iot, report
-- RUN ORDER   : 01 (Sau 00_database.sql)
-- =============================================================================

USE FreshVendDB;
GO

-- 1. auth: Người dùng, vai trò, phân quyền, đăng nhập
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'auth')
BEGIN
    EXEC('CREATE SCHEMA auth AUTHORIZATION dbo;');
    PRINT N'[01] Đã tạo schema [auth].';
END
GO

-- 2. audit: Nhật ký truy vết thay đổi dữ liệu và lịch sử phiên làm việc
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'audit')
BEGIN
    EXEC('CREATE SCHEMA audit AUTHORIZATION dbo;');
    PRINT N'[01] Đã tạo schema [audit].';
END
GO

-- 3. inventory: Quản lý sản phẩm, lô hàng, hộc/cột chứa hàng và tồn kho FIFO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'inventory')
BEGIN
    EXEC('CREATE SCHEMA inventory AUTHORIZATION dbo;');
    PRINT N'[01] Đã tạo schema [inventory].';
END
GO

-- 4. sales: Đơn hàng kiosk, chi tiết đơn hàng, thanh toán và hoàn tiền
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'sales')
BEGIN
    EXEC('CREATE SCHEMA sales AUTHORIZATION dbo;');
    PRINT N'[01] Đã tạo schema [sales].';
END
GO

-- 5. iot: Địa điểm, đội máy bán hàng, dữ liệu cảm biến telemetry và cảnh báo
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'iot')
BEGIN
    EXEC('CREATE SCHEMA iot AUTHORIZATION dbo;');
    PRINT N'[01] Đã tạo schema [iot].';
END
GO

-- 6. report: Báo cáo kinh doanh tổng hợp, nhật ký xuất dữ liệu và kết quả kiểm thử
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'report')
BEGIN
    EXEC('CREATE SCHEMA report AUTHORIZATION dbo;');
    PRINT N'[01] Đã tạo schema [report].';
END
GO
