-- =============================================================================
-- FILE        : 03_foreign_keys.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : Gom toàn bộ Foreign Key tham chiếu CHÉO SCHEMA.
--               FK nội bộ trong cùng một schema đã được tạo ngay
--               trong file 02_tables_*.sql tương ứng.
-- VERSION     : 1.0.0
-- CREATED     : 2026-10-21
-- RUN ORDER   : Bước 3 — SAU KHI tất cả file 02_tables_*.sql đã chạy xong
-- =============================================================================
-- ⚠️  Thứ tự tạo FK không quan trọng vì tất cả bảng đã tồn tại.
--     Script dùng pattern IF NOT EXISTS để idempotent (chạy lại an toàn).
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- HELPER: macro kiểm tra FK tồn tại
-- =============================================================================
-- Thay vì viết IF NOT EXISTS lặp đi lặp lại, dùng một block GO riêng cho mỗi FK.

-- =============================================================================
-- A. inventory → auth
-- =============================================================================

-- inventory.StockBatch.CreatedBy → auth.User
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_inventory_StockBatch_auth_User'
)
BEGIN
    ALTER TABLE inventory.StockBatch
        ADD CONSTRAINT FK_inventory_StockBatch_auth_User
            FOREIGN KEY (CreatedBy) REFERENCES auth.[User](UserId);
    PRINT N'[03] FK: inventory.StockBatch.CreatedBy → auth.User';
END
GO

-- inventory.StockMovement.CreatedBy → auth.User
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_inventory_StockMovement_auth_User'
)
BEGIN
    ALTER TABLE inventory.StockMovement
        ADD CONSTRAINT FK_inventory_StockMovement_auth_User
            FOREIGN KEY (CreatedBy) REFERENCES auth.[User](UserId);
    PRINT N'[03] FK: inventory.StockMovement.CreatedBy → auth.User';
END
GO

-- =============================================================================
-- B. sales → inventory
-- =============================================================================

-- sales.Order.MachineId → inventory.Machine
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_sales_Order_inventory_Machine'
)
BEGIN
    ALTER TABLE sales.[Order]
        ADD CONSTRAINT FK_sales_Order_inventory_Machine
            FOREIGN KEY (MachineId) REFERENCES inventory.Machine(MachineId);
    PRINT N'[03] FK: sales.Order.MachineId → inventory.Machine';
END
GO

-- sales.OrderItem.SlotId → inventory.Slot
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_sales_OrderItem_inventory_Slot'
)
BEGIN
    ALTER TABLE sales.OrderItem
        ADD CONSTRAINT FK_sales_OrderItem_inventory_Slot
            FOREIGN KEY (SlotId) REFERENCES inventory.Slot(SlotId);
    PRINT N'[03] FK: sales.OrderItem.SlotId → inventory.Slot';
END
GO

-- sales.OrderItem.ProductId → inventory.Product
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_sales_OrderItem_inventory_Product'
)
BEGIN
    ALTER TABLE sales.OrderItem
        ADD CONSTRAINT FK_sales_OrderItem_inventory_Product
            FOREIGN KEY (ProductId) REFERENCES inventory.Product(ProductId);
    PRINT N'[03] FK: sales.OrderItem.ProductId → inventory.Product';
END
GO

-- =============================================================================
-- C. sales → auth
-- =============================================================================

-- sales.Order.CustomerId → auth.User
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_sales_Order_auth_User'
)
BEGIN
    ALTER TABLE sales.[Order]
        ADD CONSTRAINT FK_sales_Order_auth_User
            FOREIGN KEY (CustomerId) REFERENCES auth.[User](UserId);
    PRINT N'[03] FK: sales.Order.CustomerId → auth.User';
END
GO

-- sales.Refund.ProcessedBy → auth.User
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_sales_Refund_auth_User'
)
BEGIN
    ALTER TABLE sales.Refund
        ADD CONSTRAINT FK_sales_Refund_auth_User
            FOREIGN KEY (ProcessedBy) REFERENCES auth.[User](UserId);
    PRINT N'[03] FK: sales.Refund.ProcessedBy → auth.User';
END
GO

-- =============================================================================
-- D. iot → inventory
-- =============================================================================

-- iot.Device.MachineId → inventory.Machine
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_iot_Device_inventory_Machine'
)
BEGIN
    ALTER TABLE iot.Device
        ADD CONSTRAINT FK_iot_Device_inventory_Machine
            FOREIGN KEY (MachineId) REFERENCES inventory.Machine(MachineId);
    PRINT N'[03] FK: iot.Device.MachineId → inventory.Machine';
END
GO

-- =============================================================================
-- E. iot → auth
-- =============================================================================

-- iot.Alert.ResolvedBy → auth.User
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_iot_Alert_auth_User'
)
BEGIN
    ALTER TABLE iot.Alert
        ADD CONSTRAINT FK_iot_Alert_auth_User
            FOREIGN KEY (ResolvedBy) REFERENCES auth.[User](UserId);
    PRINT N'[03] FK: iot.Alert.ResolvedBy → auth.User';
END
GO

-- =============================================================================
-- F. audit → auth
-- =============================================================================

-- audit.AuditLog.UserId → auth.User
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_audit_AuditLog_auth_User'
)
BEGIN
    ALTER TABLE audit.AuditLog
        ADD CONSTRAINT FK_audit_AuditLog_auth_User
            FOREIGN KEY (UserId) REFERENCES auth.[User](UserId);
    PRINT N'[03] FK: audit.AuditLog.UserId → auth.User';
END
GO

-- audit.ChangeLog.UserId → auth.User
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_audit_ChangeLog_auth_User'
)
BEGIN
    ALTER TABLE audit.ChangeLog
        ADD CONSTRAINT FK_audit_ChangeLog_auth_User
            FOREIGN KEY (UserId) REFERENCES auth.[User](UserId);
    PRINT N'[03] FK: audit.ChangeLog.UserId → auth.User';
END
GO

-- =============================================================================
-- G. report → inventory
-- =============================================================================

-- report.DailySalesSummary.MachineId → inventory.Machine
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_report_DailySalesSummary_inventory_Machine'
)
BEGIN
    ALTER TABLE report.DailySalesSummary
        ADD CONSTRAINT FK_report_DailySalesSummary_inventory_Machine
            FOREIGN KEY (MachineId) REFERENCES inventory.Machine(MachineId);
    PRINT N'[03] FK: report.DailySalesSummary.MachineId → inventory.Machine';
END
GO

-- report.MachineStockSnapshot.MachineId → inventory.Machine
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_report_MachineStockSnapshot_inventory_Machine'
)
BEGIN
    ALTER TABLE report.MachineStockSnapshot
        ADD CONSTRAINT FK_report_MachineStockSnapshot_inventory_Machine
            FOREIGN KEY (MachineId) REFERENCES inventory.Machine(MachineId);
    PRINT N'[03] FK: report.MachineStockSnapshot.MachineId → inventory.Machine';
END
GO

-- report.MachineStockSnapshot.ProductId → inventory.Product
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_report_MachineStockSnapshot_inventory_Product'
)
BEGIN
    ALTER TABLE report.MachineStockSnapshot
        ADD CONSTRAINT FK_report_MachineStockSnapshot_inventory_Product
            FOREIGN KEY (ProductId) REFERENCES inventory.Product(ProductId);
    PRINT N'[03] FK: report.MachineStockSnapshot.ProductId → inventory.Product';
END
GO

-- report.MachineStockSnapshot.SlotId → inventory.Slot
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_report_MachineStockSnapshot_inventory_Slot'
)
BEGIN
    ALTER TABLE report.MachineStockSnapshot
        ADD CONSTRAINT FK_report_MachineStockSnapshot_inventory_Slot
            FOREIGN KEY (SlotId) REFERENCES inventory.Slot(SlotId);
    PRINT N'[03] FK: report.MachineStockSnapshot.SlotId → inventory.Slot';
END
GO

-- =============================================================================
-- XÁC NHẬN — Liệt kê tất cả FK liên schema vừa tạo
-- =============================================================================

SELECT
    fk.name                         AS ConstraintName,
    OBJECT_SCHEMA_NAME(fk.parent_object_id) + '.' +
        OBJECT_NAME(fk.parent_object_id)    AS [FromTable],
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS [FromColumn],
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '.' +
        OBJECT_NAME(fk.referenced_object_id)AS [ToTable],
    COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS [ToColumn]
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc
    ON fk.object_id = fkc.constraint_object_id
WHERE
    -- Chỉ hiện FK liên schema (schema của bảng cha ≠ schema của bảng con)
    OBJECT_SCHEMA_NAME(fk.parent_object_id) <>
    OBJECT_SCHEMA_NAME(fk.referenced_object_id)
ORDER BY [FromTable], ConstraintName;
GO

PRINT N'';
PRINT N'============================================================';
PRINT N'  03_foreign_keys.sql hoàn tất. Tiếp theo: 04_indexes.sql  ';
PRINT N'============================================================';
GO
