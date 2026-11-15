-- =============================================================================
-- FILE        : 30_index_sales.sql
-- PROJECT     : FreshVend — TV3 (sales)
-- DESCRIPTION : Index schema sales (idempotent). Chuyển từ tests/tests_sales.sql (FV-09).
-- RUN ORDER   : Sau 02_tables_sales.sql, 12_procs_sales.sql (cột OrderItem.StockId,
--               bảng sales.DispenseEvents nếu tạo ở file procedure).
-- =============================================================================

USE FreshVendDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_sales_Order_Pending_ExpiresAt'
               AND object_id = OBJECT_ID(N'sales.[Order]'))
    CREATE NONCLUSTERED INDEX IX_sales_Order_Pending_ExpiresAt
        ON sales.[Order] (ExpiresAt, CreatedAt)
        INCLUDE (OrderId, OrderCode, MachineId, TotalAmount)
        WHERE Status = N'PENDING';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_sales_Order_Machine_CreatedAt'
               AND object_id = OBJECT_ID(N'sales.[Order]'))
    CREATE NONCLUSTERED INDEX IX_sales_Order_Machine_CreatedAt
        ON sales.[Order] (MachineId, CreatedAt DESC)
        INCLUDE (OrderId, Status, TotalAmount);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_sales_OrderItem_OrderId'
               AND object_id = OBJECT_ID(N'sales.OrderItem'))
    CREATE NONCLUSTERED INDEX IX_sales_OrderItem_OrderId
        ON sales.OrderItem (OrderId)
        INCLUDE (OrderItemId, SlotId, ProductId, Quantity, LineTotal, StockId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_sales_Payment_OrderId_Status'
               AND object_id = OBJECT_ID(N'sales.Payment'))
    CREATE NONCLUSTERED INDEX IX_sales_Payment_OrderId_Status
        ON sales.Payment (OrderId, Status)
        INCLUDE (PaymentId, Amount, GatewayTxnId, PaidAt);
GO

IF OBJECT_ID(N'sales.DispenseEvents', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_sales_DispenseEvents_OrderItem'
                   AND object_id = OBJECT_ID(N'sales.DispenseEvents'))
    CREATE NONCLUSTERED INDEX IX_sales_DispenseEvents_OrderItem
        ON sales.DispenseEvents (OrderItemId, AttemptNo)
        INCLUDE (Result, ErrorCode, EventAt);
GO

PRINT N'[30_index_sales] Index sales: xong.';
GO
