-- =============================================================================
-- FILE        : tests_sales.sql
-- PROJECT     : FreshVend — TV3 (sales)
-- DESCRIPTION : Unit test SQL (hết hàng, sai tiền, callback 2 lần, kẹt 3 lần)
-- RUN ORDER   : Sau 12_procs_sales.sql, 30_index_sales.sql (và 22_objects_sales.sql nếu có)
-- NOTE        : In bảng kết quả cuối script; Passed = 1 là đạt
-- =============================================================================

USE FreshVendDB;
GO

SET NOCOUNT ON;

-- =============================================================================
-- 1. Bảng kết quả unit test
-- =============================================================================

DECLARE @Results TABLE (
    TestCode    NVARCHAR(20)  NOT NULL,
    TestName    NVARCHAR(120) NOT NULL,
    Passed      BIT           NOT NULL,
    Detail      NVARCHAR(500) NULL
);

DECLARE @MachineId INT, @SlotId INT, @ProductId INT, @OrderId BIGINT, @OrderItemId BIGINT,
        @Items sales.OrderItemType, @GatewayTxnId NVARCHAR(100),
        @Total DECIMAL(14,2), @WrongAmount DECIMAL(14,2), @Dup BIT, @Status NVARCHAR(20), @BatchId INT,
        @UtMachineId INT, @UtProductId INT, @UtCatId INT;

SET @GatewayTxnId = CONCAT(N'TV3UT', REPLACE(CONVERT(NVARCHAR(36), NEWID()), N'-', N''));

IF OBJECT_ID(N'inventory.SlotStock', N'U') IS NULL
   OR OBJECT_ID(N'sales.sp_CreateOrder', N'P') IS NULL
BEGIN
    INSERT @Results (TestCode, TestName, Passed, Detail)
    VALUES (N'SKIP', N'Toan bo', 0, N'Chay 02_tables_inventory.sql + 12_procs_sales.sql truoc (SlotStock + sp_CreateOrder).');
    GOTO PrintSummary;
END;

IF NOT EXISTS (SELECT 1 FROM inventory.Category)
    INSERT inventory.Category (CategoryName, Description) VALUES (N'UT-Cat', N'Unit test TV3');

IF NOT EXISTS (SELECT 1 FROM inventory.Product)
BEGIN
    SET @UtCatId = (SELECT TOP (1) CategoryId FROM inventory.Category ORDER BY CategoryId);
    INSERT inventory.Product (SKU, ProductName, CategoryId, UnitPrice, Unit)
    VALUES (N'UT-SKU-01', N'San pham unit test', @UtCatId, 25000, N'hop');
END;

-- Ngữ cảnh chung: máy online + ngăn có hàng (tạo tối thiểu nếu chưa seed)
IF NOT EXISTS (SELECT 1 FROM inventory.Machine WHERE IsActive = 1)
BEGIN
    INSERT inventory.Machine (MachineCode, MachineName, Location, Status, InstallDate)
    VALUES (N'VMUT01', N'May unit test TV3', N'Lab', N'online', CONVERT(DATE, SYSUTCDATETIME()));
END;

IF NOT EXISTS (SELECT 1 FROM inventory.Slot)
BEGIN
    SET @UtMachineId = (SELECT TOP (1) MachineId FROM inventory.Machine ORDER BY MachineId);
    SET @UtProductId = (SELECT TOP (1) ProductId FROM inventory.Product ORDER BY ProductId);
    IF @UtMachineId IS NOT NULL AND @UtProductId IS NOT NULL
        INSERT inventory.Slot (MachineId, SlotCode, ProductId, Capacity, CurrentStock, IsActive)
        VALUES (@UtMachineId, N'A1', @UtProductId, 10, 5, 1);
END;

SELECT TOP (1) @MachineId = m.MachineId, @SlotId = s.SlotId, @ProductId = s.ProductId
FROM inventory.Machine AS m
INNER JOIN inventory.Slot AS s ON s.MachineId = m.MachineId AND s.IsActive = 1 AND s.ProductId IS NOT NULL
WHERE m.IsActive = 1 AND m.Status = N'online'
ORDER BY m.MachineId, s.SlotId;

IF @SlotId IS NULL
BEGIN
    INSERT @Results (TestCode, TestName, Passed, Detail)
    VALUES (N'SKIP', N'Toan bo', 0, N'Chua co may/ngan - chay 05_seed_small.sql + 12_procs_sales.sql');
    GOTO PrintSummary;
END;

-- Đảm bảo có tồn FIFO (không DELETE SlotStock — OrderItem.StockId đang FK tới đó).
UPDATE inventory.Slot SET CurrentStock = 5, UpdatedAt = SYSUTCDATETIME() WHERE SlotId = @SlotId;
IF EXISTS (SELECT 1 FROM inventory.SlotStock WHERE SlotId = @SlotId)
    UPDATE inventory.SlotStock SET Quantity = 5 WHERE SlotId = @SlotId;
ELSE
BEGIN
    SET @BatchId = (SELECT TOP (1) BatchId FROM inventory.StockBatch WHERE ProductId = @ProductId ORDER BY BatchId);
    IF @BatchId IS NULL
    BEGIN
        INSERT inventory.StockBatch (ProductId, BatchCode, Quantity, UnitCost, ImportDate, Note)
        VALUES (@ProductId, N'UT-BATCH', 10, 0, CONVERT(DATE, SYSUTCDATETIME()), N'Unit test TV3');
        SET @BatchId = CONVERT(INT, SCOPE_IDENTITY());
    END;
    INSERT inventory.SlotStock (SlotId, BatchId, Quantity) VALUES (@SlotId, @BatchId, 5);
END;

-- UT01 Het hang (50201): tồn 0, đặt 1
BEGIN TRY
    UPDATE inventory.SlotStock SET Quantity = 0 WHERE SlotId = @SlotId;
    UPDATE inventory.Slot SET CurrentStock = 0, UpdatedAt = SYSUTCDATETIME() WHERE SlotId = @SlotId;

    DELETE FROM @Items;
    INSERT @Items (ColumnId, Qty) VALUES (@SlotId, 1);
    SET @OrderId = NULL;
    EXEC sales.sp_CreateOrder @MachineId = @MachineId, @Items = @Items, @OrderId = @OrderId OUTPUT;
    INSERT @Results VALUES (N'UT01', N'Het hang - sp_CreateOrder vuot ton', 0, N'Khong duoc tao don thanh cong');
END TRY
BEGIN CATCH
    INSERT @Results VALUES (N'UT01', N'Het hang - sp_CreateOrder vuot ton',
        CASE WHEN ERROR_NUMBER() = 50201 THEN 1 ELSE 0 END,
        CONCAT(N'Err ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

UPDATE inventory.Slot SET CurrentStock = 5, UpdatedAt = SYSUTCDATETIME() WHERE SlotId = @SlotId;
IF EXISTS (SELECT 1 FROM inventory.SlotStock WHERE SlotId = @SlotId)
    UPDATE inventory.SlotStock SET Quantity = 5 WHERE SlotId = @SlotId;
ELSE IF @BatchId IS NOT NULL
    INSERT inventory.SlotStock (SlotId, BatchId, Quantity) VALUES (@SlotId, @BatchId, 5);

-- UT02 Thanh toan sai so tien (50208)
BEGIN TRY
    DELETE FROM @Items;
    INSERT @Items (ColumnId, Qty) VALUES (@SlotId, 1);
    EXEC sales.sp_CreateOrder @MachineId = @MachineId, @Items = @Items, @OrderId = @OrderId OUTPUT;
    SELECT @Total = TotalAmount FROM sales.[Order] WHERE OrderId = @OrderId;
    SET @WrongAmount = @Total - 1;
    EXEC sales.sp_ConfirmPayment @OrderId = @OrderId, @Method = N'VIETQR',
         @GatewayTxnId = @GatewayTxnId, @Amount = @WrongAmount;
    INSERT @Results VALUES (N'UT02', N'Thanh toan sai so tien', 0, N'Khong duoc xac nhan');
END TRY
BEGIN CATCH
    INSERT @Results VALUES (N'UT02', N'Thanh toan sai so tien',
        CASE WHEN ERROR_NUMBER() = 50208 THEN 1 ELSE 0 END,
        CONCAT(N'Err ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

-- UT03 Callback gateway 2 lan
BEGIN TRY
    DELETE FROM @Items;
    SET @GatewayTxnId = CONCAT(N'TV3UTDUP', REPLACE(CONVERT(NVARCHAR(36), NEWID()), N'-', N''));
    INSERT @Items (ColumnId, Qty) VALUES (@SlotId, 1);
    EXEC sales.sp_CreateOrder @MachineId = @MachineId, @Items = @Items, @OrderId = @OrderId OUTPUT;
    SELECT @Total = TotalAmount FROM sales.[Order] WHERE OrderId = @OrderId;

    DECLARE @Pay TABLE (OrderId BIGINT, Status NVARCHAR(20), Amount DECIMAL(14,2), PaidAt DATETIME2(0), IsDuplicate BIT);

    DELETE FROM @Pay;
    INSERT @Pay
    EXEC sales.sp_ConfirmPayment @OrderId = @OrderId, @Method = N'MOMO',
         @GatewayTxnId = @GatewayTxnId, @Amount = @Total;

    DELETE FROM @Pay;
    INSERT @Pay
    EXEC sales.sp_ConfirmPayment @OrderId = @OrderId, @Method = N'MOMO',
         @GatewayTxnId = @GatewayTxnId, @Amount = @Total;

    SELECT @Dup = IsDuplicate FROM @Pay;
    INSERT @Results VALUES (N'UT03', N'Callback gateway gui 2 lan - lan 2 IsDuplicate',
        CASE WHEN @Dup = 1 THEN 1 ELSE 0 END,
        CONCAT(N'IsDuplicate=', COALESCE(CONVERT(NVARCHAR(5), @Dup), N'NULL')));
END TRY
BEGIN CATCH
    INSERT @Results VALUES (N'UT03', N'Callback gateway gui 2 lan', 0,
        CONCAT(N'Err ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

-- UT04 Ket 3 lan hoan tien (sp_RecordDispense ghi iot.Alerts, không cần iot.Device)
BEGIN TRY
    DELETE FROM @Items;
    INSERT @Items (ColumnId, Qty) VALUES (@SlotId, 1);
    EXEC sales.sp_CreateOrder @MachineId = @MachineId, @Items = @Items, @OrderId = @OrderId OUTPUT;
    SELECT @Total = TotalAmount FROM sales.[Order] WHERE OrderId = @OrderId;
    SET @GatewayTxnId = CONCAT(N'TV3UTJAM', REPLACE(CONVERT(NVARCHAR(36), NEWID()), N'-', N''));
    EXEC sales.sp_ConfirmPayment @OrderId = @OrderId, @Method = N'VNPAY',
         @GatewayTxnId = @GatewayTxnId, @Amount = @Total;

    SELECT TOP (1) @OrderItemId = OrderItemId FROM sales.OrderItem WHERE OrderId = @OrderId;

    EXEC sales.sp_RecordDispense @OrderItemId = @OrderItemId, @Result = N'JAM', @ErrorCode = N'E_UT1';
    EXEC sales.sp_RecordDispense @OrderItemId = @OrderItemId, @Result = N'JAM', @ErrorCode = N'E_UT2';
    EXEC sales.sp_RecordDispense @OrderItemId = @OrderItemId, @Result = N'JAM', @ErrorCode = N'E_UT3';

    SELECT @Status = Status FROM sales.[Order] WHERE OrderId = @OrderId;
    INSERT @Results VALUES (N'UT04', N'Ket hang 3 lan - tu hoan tien (REFUNDED)',
        CASE WHEN @Status = N'REFUNDED' THEN 1 ELSE 0 END,
        CONCAT(N'Status=', COALESCE(@Status, N'NULL')));
END TRY
BEGIN CATCH
    INSERT @Results VALUES (N'UT04', N'Ket 3 lan hoan tien', 0,
        CONCAT(N'Err ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH;

PrintSummary:
SELECT TestCode, TestName, Passed, Detail FROM @Results ORDER BY TestCode;

DECLARE @Pass INT = (SELECT COUNT(*) FROM @Results WHERE Passed = 1 AND TestCode LIKE N'UT%');
DECLARE @Fail INT = (SELECT COUNT(*) FROM @Results WHERE Passed = 0 AND TestCode LIKE N'UT%');

PRINT N'[tests_sales] Unit test TV3 — Pass: ' + CAST(@Pass AS NVARCHAR(10))
    + N' | Fail: ' + CAST(@Fail AS NVARCHAR(10));

IF @Fail > 0 AND NOT EXISTS (SELECT 1 FROM @Results WHERE TestCode = N'SKIP')
    RAISERROR(N'[tests_sales] Co test that bai — xem bang ket qua.', 16, 1);
GO
