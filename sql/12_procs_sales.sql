-- =============================================================================
-- FILE        : 12_procs_sales.sql
-- PROJECT     : FreshVend
-- DESCRIPTION : TV3 sales procedures, aligned with app/api/src/routes/sales.js
-- RUN ORDER   : After 02_tables_*.sql (gồm SlotStock của TV2), 03_foreign_keys.sql
--               và inventory seed data.
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 0. Supporting schema
-- =============================================================================

-- Keep the order state constraint compatible with the sales lifecycle.
IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = N'CK_sales_Order_Status'
             AND parent_object_id = OBJECT_ID(N'sales.[Order]'))
    ALTER TABLE sales.[Order] DROP CONSTRAINT CK_sales_Order_Status;
GO

ALTER TABLE sales.[Order] WITH CHECK
    ADD CONSTRAINT CK_sales_Order_Status
    CHECK (UPPER(Status) IN
      (N'PENDING', N'PAID', N'DISPENSED', N'DISPENSE_FAILED', N'EXPIRED', N'CANCELLED', N'REFUNDED'));
GO

-- The API uses VIETQR/MOMO/VNPAY. Retain existing methods for other clients.
IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = N'CK_sales_Payment_Method'
             AND parent_object_id = OBJECT_ID(N'sales.Payment'))
    ALTER TABLE sales.Payment DROP CONSTRAINT CK_sales_Payment_Method;
GO

ALTER TABLE sales.Payment WITH CHECK
    ADD CONSTRAINT CK_sales_Payment_Method
    CHECK (PaymentMethod IN (N'CASH', N'QRCODE', N'CARD', N'EWALLET', N'VIETQR', N'MOMO', N'VNPAY'));
GO

-- inventory.SlotStock do TV2 tạo trong 02_tables_inventory.sql

IF COL_LENGTH(N'sales.OrderItem', N'StockId') IS NULL
    ALTER TABLE sales.OrderItem ADD StockId BIGINT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sales_OrderItem_SlotStock')
    ALTER TABLE sales.OrderItem WITH CHECK
        ADD CONSTRAINT FK_sales_OrderItem_SlotStock
            FOREIGN KEY (StockId) REFERENCES inventory.SlotStock(StockId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sales_OrderItem_StockBatch')
    ALTER TABLE sales.OrderItem WITH CHECK
        ADD CONSTRAINT FK_sales_OrderItem_StockBatch
            FOREIGN KEY (BatchId) REFERENCES inventory.StockBatch(BatchId);
GO

-- Preserve the seeded aggregate stock as one opening lot when no lot-level rows
-- exist yet. Future restocking must also insert inventory.SlotStock rows.
INSERT inventory.StockBatch (ProductId, BatchCode, Quantity, UnitCost, ImportDate, ExpiryDate, Note)
SELECT s.ProductId,
       N'OPEN-SLOT-' + CONVERT(NVARCHAR(12), s.SlotId),
       s.CurrentStock, 0, CONVERT(DATE, SYSUTCDATETIME()), NULL,
       N'Opening lot created from inventory.Slot.CurrentStock by 12_procs_sales.sql'
FROM inventory.Slot s
WHERE s.ProductId IS NOT NULL AND s.CurrentStock > 0
  AND NOT EXISTS (SELECT 1 FROM inventory.StockBatch b
                  WHERE b.BatchCode = N'OPEN-SLOT-' + CONVERT(NVARCHAR(12), s.SlotId))
  AND NOT EXISTS (SELECT 1 FROM inventory.SlotStock ss WHERE ss.SlotId = s.SlotId);
GO

INSERT inventory.SlotStock (SlotId, BatchId, Quantity, LoadedAt)
SELECT s.SlotId, b.BatchId, s.CurrentStock, SYSUTCDATETIME()
FROM inventory.Slot s
JOIN inventory.StockBatch b
  ON b.BatchCode = N'OPEN-SLOT-' + CONVERT(NVARCHAR(12), s.SlotId)
WHERE s.ProductId IS NOT NULL AND s.CurrentStock > 0
  AND NOT EXISTS (SELECT 1 FROM inventory.SlotStock ss WHERE ss.SlotId = s.SlotId);
GO

-- If an earlier draft created order-level events, discard the empty draft table
-- so it can be recreated with the API's per-order-item event key.
IF OBJECT_ID(N'sales.DispenseEvents', N'U') IS NOT NULL
   AND COL_LENGTH(N'sales.DispenseEvents', N'OrderItemId') IS NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sales.DispenseEvents)
        THROW 50991, N'sales.DispenseEvents cũ đang có dữ liệu; cần migrate events sang OrderItemId trước.', 1;
    DROP TABLE sales.DispenseEvents;
END;
GO

IF OBJECT_ID(N'sales.DispenseEvents', N'U') IS NULL
BEGIN
    CREATE TABLE sales.DispenseEvents (
        EventId     BIGINT       NOT NULL IDENTITY(1,1),
        OrderItemId BIGINT       NOT NULL,
        AttemptNo   TINYINT      NOT NULL,
        Result      NVARCHAR(10) NOT NULL,
        ErrorCode   NVARCHAR(30) NULL,
        EventAt     DATETIME2(0) NOT NULL CONSTRAINT DF_sales_DispenseEvents_EventAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_sales_DispenseEvents PRIMARY KEY (EventId),
        CONSTRAINT FK_sales_DispenseEvents_OrderItem FOREIGN KEY (OrderItemId) REFERENCES sales.OrderItem(OrderItemId),
        CONSTRAINT UQ_sales_DispenseEvents_Attempt UNIQUE (OrderItemId, AttemptNo),
        CONSTRAINT CK_sales_DispenseEvents_Attempt CHECK (AttemptNo BETWEEN 1 AND 3),
        CONSTRAINT CK_sales_DispenseEvents_Result CHECK (Result IN (N'SUCCESS', N'JAM'))
    );
END;
GO

-- A previous draft used (SlotId, Quantity); table types cannot be altered.
-- Replace that type and its dependent procedures when it has the old shape.
IF TYPE_ID(N'sales.OrderItemType') IS NOT NULL
   AND (NOT EXISTS (
       SELECT 1 FROM sys.columns c JOIN sys.table_types tt ON tt.type_table_object_id = c.object_id
       WHERE tt.user_type_id = TYPE_ID(N'sales.OrderItemType') AND c.name = N'ColumnId'
   ) OR NOT EXISTS (
       SELECT 1 FROM sys.columns c JOIN sys.table_types tt ON tt.type_table_object_id = c.object_id
       WHERE tt.user_type_id = TYPE_ID(N'sales.OrderItemType') AND c.name = N'Qty'
   ))
BEGIN
    DROP PROCEDURE IF EXISTS sales.sp_CreateOrder;
    DROP TYPE sales.OrderItemType;
END;
GO

IF TYPE_ID(N'sales.OrderItemType') IS NULL
    EXEC(N'CREATE TYPE sales.OrderItemType AS TABLE (
        ColumnId INT NOT NULL PRIMARY KEY,
        Qty TINYINT NOT NULL CHECK (Qty BETWEEN 1 AND 5)
    );');
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'UQ_sales_Payment_GatewayTxnId'
                 AND object_id = OBJECT_ID(N'sales.Payment'))
    CREATE UNIQUE INDEX UQ_sales_Payment_GatewayTxnId
        ON sales.Payment(GatewayTxnId) WHERE GatewayTxnId IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'UQ_sales_Refund_Payment'
                 AND object_id = OBJECT_ID(N'sales.Refund'))
    CREATE UNIQUE INDEX UQ_sales_Refund_Payment ON sales.Refund(PaymentId);
GO

-- =============================================================================
-- 0.1. Shared total function
-- =============================================================================
CREATE OR ALTER FUNCTION sales.fn_OrderTotal (@OrderId BIGINT)
RETURNS DECIMAL(14,2)
AS
BEGIN
    DECLARE @Total DECIMAL(14,2);
    SELECT @Total = COALESCE(SUM(LineTotal), 0)
    FROM sales.OrderItem
    WHERE OrderId = @OrderId;
    RETURN @Total;
END;
GO

-- =============================================================================
-- 1. Create order and reserve FIFO lots
-- =============================================================================
CREATE OR ALTER PROCEDURE sales.sp_CreateOrder
    @MachineId INT,
    @Items sales.OrderItemType READONLY,
    @OrderId BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM @Items)
        THROW 50200, N'Giỏ hàng phải có ít nhất một sản phẩm.', 1;
    IF NOT EXISTS (SELECT 1 FROM inventory.Machine WHERE MachineId = @MachineId AND IsActive = 1)
        THROW 50202, N'Máy bán hàng không tồn tại hoặc đã ngừng hoạt động.', 1;
    IF NOT EXISTS (SELECT 1 FROM inventory.Machine WHERE MachineId = @MachineId AND IsActive = 1 AND Status = N'online')
        THROW 50203, N'Máy đang tạm ngưng phục vụ.', 1;

    DECLARE @ColumnId INT, @Qty TINYINT, @SlotId INT, @ProductId INT,
            @StockId BIGINT, @BatchId INT, @LotQty SMALLINT, @Take SMALLINT,
            @UnitPrice DECIMAL(12,2), @Remaining INT, @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRAN;

        -- Lock columns in stable order, then check all requested quantities.
        DECLARE item_check CURSOR LOCAL FAST_FORWARD FOR
            SELECT ColumnId, Qty FROM @Items ORDER BY ColumnId;
        OPEN item_check;
        FETCH NEXT FROM item_check INTO @ColumnId, @Qty;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @SlotId = NULL, @ProductId = NULL;
            SELECT @SlotId = SlotId, @ProductId = ProductId
            FROM inventory.Slot WITH (UPDLOCK, ROWLOCK)
            WHERE SlotId = @ColumnId AND MachineId = @MachineId AND IsActive = 1;
            IF @SlotId IS NULL OR @ProductId IS NULL
                THROW 50204, N'Ngăn chứa không tồn tại trên máy này hoặc chưa có sản phẩm.', 1;

            SELECT @Remaining = COALESCE(SUM(ss.Quantity), 0)
            FROM inventory.SlotStock ss WITH (UPDLOCK, ROWLOCK)
            JOIN inventory.StockBatch b ON b.BatchId = ss.BatchId
            WHERE ss.SlotId = @SlotId
              AND b.ProductId = @ProductId
              AND (b.ExpiryDate IS NULL OR b.ExpiryDate >= CONVERT(DATE, @Now));
            IF @Remaining < @Qty
                THROW 50201, N'Sản phẩm đã hết hàng hoặc không đủ số lượng.', 1;
            FETCH NEXT FROM item_check INTO @ColumnId, @Qty;
        END;
        CLOSE item_check;
        DEALLOCATE item_check;

        INSERT sales.[Order] (OrderCode, MachineId, Subtotal, DiscountAmount, TotalAmount, Status, CreatedAt)
        VALUES (N'FV' + LEFT(REPLACE(CONVERT(NVARCHAR(36), NEWID()), N'-', N''), 28),
                @MachineId, 0, 0, 0, N'PENDING', @Now);
        SET @OrderId = CONVERT(BIGINT, SCOPE_IDENTITY());

        DECLARE item_reserve CURSOR LOCAL FAST_FORWARD FOR
            SELECT ColumnId, Qty FROM @Items ORDER BY ColumnId;
        OPEN item_reserve;
        FETCH NEXT FROM item_reserve INTO @ColumnId, @Qty;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @SlotId = SlotId, @ProductId = ProductId
            FROM inventory.Slot
            WHERE SlotId = @ColumnId AND MachineId = @MachineId;
            SELECT @UnitPrice = UnitPrice FROM inventory.Product WHERE ProductId = @ProductId;
            SET @Remaining = @Qty;

            WHILE @Remaining > 0
            BEGIN
                SELECT @StockId = NULL, @BatchId = NULL, @LotQty = NULL;
                SELECT TOP (1) @StockId = ss.StockId, @BatchId = ss.BatchId, @LotQty = ss.Quantity
                FROM inventory.SlotStock ss WITH (UPDLOCK, ROWLOCK)
                JOIN inventory.StockBatch b ON b.BatchId = ss.BatchId
                WHERE ss.SlotId = @SlotId AND ss.Quantity > 0
                  AND b.ProductId = @ProductId
                  AND (b.ExpiryDate IS NULL OR b.ExpiryDate >= CONVERT(DATE, @Now))
                ORDER BY ss.LoadedAt, ss.StockId;

                IF @StockId IS NULL
                    THROW 50201, N'Sản phẩm đã hết hàng hoặc không đủ số lượng.', 1;

                SET @Take = CASE WHEN @LotQty < @Remaining THEN @LotQty ELSE @Remaining END;
                UPDATE inventory.SlotStock SET Quantity = Quantity - @Take WHERE StockId = @StockId;
                UPDATE inventory.Slot SET CurrentStock = CurrentStock - @Take, UpdatedAt = @Now WHERE SlotId = @SlotId;

                INSERT sales.OrderItem (OrderId, SlotId, ProductId, Quantity, UnitPrice, StockId, BatchId)
                VALUES (@OrderId, @SlotId, @ProductId, @Take, @UnitPrice, @StockId, @BatchId);
                INSERT inventory.StockMovement (SlotId, BatchId, MovementType, Quantity, Reason, CreatedAt)
                VALUES (@SlotId, @BatchId, N'OUT', @Take,
                        N'Giữ hàng cho đơn ' + CONVERT(NVARCHAR(20), @OrderId), @Now);
                SET @Remaining -= @Take;
            END;
            FETCH NEXT FROM item_reserve INTO @ColumnId, @Qty;
        END;
        CLOSE item_reserve;
        DEALLOCATE item_reserve;

        DECLARE @Total DECIMAL(14,2) = sales.fn_OrderTotal(@OrderId);
        UPDATE sales.[Order] SET Subtotal = @Total, TotalAmount = @Total, UpdatedAt = @Now
        WHERE OrderId = @OrderId;

        COMMIT;
        SELECT OrderId, MachineId, Status, TotalAmount, CreatedAt, ExpiresAt
        FROM sales.[Order] WHERE OrderId = @OrderId;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'item_check') >= 0 CLOSE item_check;
        IF CURSOR_STATUS('local', 'item_check') > -3 DEALLOCATE item_check;
        IF CURSOR_STATUS('local', 'item_reserve') >= 0 CLOSE item_reserve;
        IF CURSOR_STATUS('local', 'item_reserve') > -3 DEALLOCATE item_reserve;
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- 2. Confirm payment. GatewayTxnId is the idempotency key.
-- =============================================================================
CREATE OR ALTER PROCEDURE sales.sp_ConfirmPayment
    @OrderId BIGINT,
    @Method NVARCHAR(20),
    @GatewayTxnId NVARCHAR(100),
    @Amount DECIMAL(14,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@GatewayTxnId)), N'') IS NULL
        THROW 50210, N'GatewayTxnId không được để trống.', 1;
    IF @Method IS NULL OR @Method NOT IN (N'VIETQR', N'MOMO', N'VNPAY')
        THROW 50209, N'Phương thức thanh toán không được hỗ trợ.', 1;

    BEGIN TRY
        BEGIN TRAN;
        IF EXISTS (SELECT 1 FROM sales.Payment WITH (UPDLOCK, HOLDLOCK)
                   WHERE GatewayTxnId = @GatewayTxnId)
        BEGIN
            COMMIT;
            SELECT p.OrderId, o.Status, p.Amount, p.PaidAt, CAST(1 AS BIT) AS IsDuplicate
            FROM sales.Payment p JOIN sales.[Order] o ON o.OrderId = p.OrderId
            WHERE p.GatewayTxnId = @GatewayTxnId;
            RETURN;
        END;

        DECLARE @Status NVARCHAR(20), @Total DECIMAL(14,2), @ExpiresAt DATETIME2(0),
                @Now DATETIME2(0) = SYSUTCDATETIME();
        SELECT @Status = Status, @Total = TotalAmount, @ExpiresAt = ExpiresAt
        FROM sales.[Order] WITH (UPDLOCK, ROWLOCK) WHERE OrderId = @OrderId;
        IF @Status IS NULL THROW 50205, N'Đơn hàng không tồn tại.', 1;
        IF UPPER(@Status) <> N'PENDING' THROW 50206, N'Đơn hàng không ở trạng thái chờ thanh toán.', 1;
        IF @ExpiresAt <= @Now
            THROW 50207, N'Đơn hàng đã quá hạn thanh toán (5 phút).', 1;
        IF @Amount IS NULL OR @Amount <> @Total
            THROW 50208, N'Số tiền thanh toán không khớp với đơn hàng.', 1;

        INSERT sales.Payment (OrderId, PaymentMethod, Amount, TransactionRef, GatewayTxnId, Status, PaidAt, CreatedAt)
        VALUES (@OrderId, @Method, @Amount, @GatewayTxnId, @GatewayTxnId, N'success', @Now, @Now);
        UPDATE sales.[Order] SET Status = N'PAID', PaidAt = @Now, UpdatedAt = @Now WHERE OrderId = @OrderId;
        COMMIT;
        SELECT @OrderId AS OrderId, N'PAID' AS Status, @Amount AS Amount,
               @Now AS PaidAt, CAST(0 AS BIT) AS IsDuplicate;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601, 2627)
           AND EXISTS (SELECT 1 FROM sales.Payment WHERE GatewayTxnId = @GatewayTxnId)
        BEGIN
            SELECT p.OrderId, o.Status, p.Amount, p.PaidAt, CAST(1 AS BIT) AS IsDuplicate
            FROM sales.Payment p JOIN sales.[Order] o ON o.OrderId = p.OrderId
            WHERE p.GatewayTxnId = @GatewayTxnId;
            RETURN;
        END;
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- 3. Record one dispense attempt per order item
-- =============================================================================
CREATE OR ALTER PROCEDURE sales.sp_RecordDispense
    @OrderItemId BIGINT,
    @Result NVARCHAR(10),
    @ErrorCode NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Result NOT IN (N'SUCCESS', N'JAM')
        THROW 50211, N'Result chỉ nhận SUCCESS hoặc JAM.', 1;

    DECLARE @OrderId BIGINT, @MachineId INT, @Status NVARCHAR(20), @AttemptNo TINYINT,
            @Now DATETIME2(0) = SYSUTCDATETIME();
    BEGIN TRY
        BEGIN TRAN;
        SELECT @OrderId = oi.OrderId, @MachineId = o.MachineId, @Status = o.Status
        FROM sales.OrderItem oi WITH (UPDLOCK, ROWLOCK)
        JOIN sales.[Order] o WITH (UPDLOCK, ROWLOCK) ON o.OrderId = oi.OrderId
        WHERE oi.OrderItemId = @OrderItemId;
        IF @OrderId IS NULL THROW 50212, N'Không tìm thấy dòng đơn hàng.', 1;
        IF UPPER(@Status) <> N'PAID'
            THROW 50213, N'Đơn hàng chưa thanh toán hoặc đã xử lý xong.', 1;
        IF EXISTS (SELECT 1 FROM sales.DispenseEvents
                   WHERE OrderItemId = @OrderItemId AND Result = N'SUCCESS')
            THROW 50214, N'Sản phẩm này đã được nhả thành công.', 1;

        SELECT @AttemptNo = CONVERT(TINYINT, COALESCE(MAX(AttemptNo), 0) + 1)
        FROM sales.DispenseEvents WITH (UPDLOCK, HOLDLOCK)
        WHERE OrderItemId = @OrderItemId;
        IF @AttemptNo > 3 THROW 50215, N'Đã vượt quá 3 lần thử nhả hàng.', 1;

        INSERT sales.DispenseEvents (OrderItemId, AttemptNo, Result, ErrorCode, EventAt)
        VALUES (@OrderItemId, @AttemptNo, @Result, @ErrorCode, @Now);

        IF @Result = N'SUCCESS'
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM sales.OrderItem oi
                WHERE oi.OrderId = @OrderId
                  AND NOT EXISTS (SELECT 1 FROM sales.DispenseEvents de
                                  WHERE de.OrderItemId = oi.OrderItemId AND de.Result = N'SUCCESS'))
                UPDATE sales.[Order] SET Status = N'DISPENSED', CompletedAt = @Now, UpdatedAt = @Now WHERE OrderId = @OrderId;
        END
        ELSE IF @AttemptNo = 3
        BEGIN
            UPDATE sales.[Order] SET Status = N'DISPENSE_FAILED', UpdatedAt = @Now WHERE OrderId = @OrderId;
            EXEC sales.sp_Refund @OrderId = @OrderId, @Reason = N'Tự động hoàn tiền do kẹt hàng 3 lần';

            -- Cảnh báo ghi iot.Alerts (TV4). Không dùng iot.Device / iot.Alert (bảng cũ, không có trên CSDL).
            IF OBJECT_ID(N'iot.Alerts', N'U') IS NOT NULL
               AND OBJECT_ID(N'iot.Machines', N'U') IS NOT NULL
               AND EXISTS (SELECT 1 FROM iot.Machines WHERE MachineId = @MachineId)
                INSERT iot.Alerts (MachineId, AlertType, Severity, Message, RefKey, CreatedAt)
                VALUES (
                    @MachineId,
                    N'DISPENSE_JAM',
                    N'HIGH',
                    N'Kẹt hàng 3 lần ở đơn ' + CONVERT(NVARCHAR(20), @OrderId) + N' – đã tự động hoàn tiền',
                    N'ORD:' + CONVERT(NVARCHAR(20), @OrderId),
                    @Now
                );
        END;

        COMMIT;
        SELECT @OrderId AS OrderId, @OrderItemId AS OrderItemId,
               @AttemptNo AS AttemptNo, @Result AS Result,
               (SELECT Status FROM sales.[Order] WHERE OrderId = @OrderId) AS OrderStatus;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- 4. Refund only items that have not successfully left the machine
-- =============================================================================
CREATE OR ALTER PROCEDURE sales.sp_Refund
    @OrderId BIGINT,
    @Reason NVARCHAR(300) = NULL,
    @RefundedBy INT = NULL,
    @RefundId BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Status NVARCHAR(20), @PaymentId BIGINT, @RefundAmount DECIMAL(14,2),
            @Now DATETIME2(0) = SYSUTCDATETIME();
    BEGIN TRY
        BEGIN TRAN;
        SELECT @Status = Status FROM sales.[Order] WITH (UPDLOCK, ROWLOCK) WHERE OrderId = @OrderId;
        IF @Status IS NULL THROW 50216, N'Đơn hàng không tồn tại.', 1;
        IF UPPER(@Status) NOT IN (N'PAID', N'DISPENSE_FAILED')
            THROW 50217, N'Chỉ hoàn tiền đơn đã thanh toán và còn hàng chưa nhả.', 1;
        IF EXISTS (SELECT 1 FROM sales.Refund r JOIN sales.Payment p ON p.PaymentId = r.PaymentId
                   WHERE p.OrderId = @OrderId)
            THROW 50218, N'Đơn hàng đã được hoàn tiền.', 1;

        SELECT TOP (1) @PaymentId = PaymentId
        FROM sales.Payment WHERE OrderId = @OrderId AND Status = N'success'
        ORDER BY PaymentId DESC;
        IF @PaymentId IS NULL THROW 50219, N'Không tìm thấy thanh toán thành công.', 1;

        SELECT @RefundAmount = COALESCE(SUM(oi.LineTotal), 0)
        FROM sales.OrderItem oi
        WHERE oi.OrderId = @OrderId
          AND NOT EXISTS (SELECT 1 FROM sales.DispenseEvents de
                          WHERE de.OrderItemId = oi.OrderItemId AND de.Result = N'SUCCESS');
        IF @RefundAmount <= 0 THROW 50218, N'Không có sản phẩm nào cần hoàn tiền.', 1;

        -- Return only stock for items that have not left the machine.
        ;WITH ReturnLines AS (
            SELECT oi.StockId, oi.SlotId, SUM(oi.Quantity) AS Qty
            FROM sales.OrderItem oi
            WHERE oi.OrderId = @OrderId AND oi.StockId IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM sales.DispenseEvents de
                              WHERE de.OrderItemId = oi.OrderItemId AND de.Result = N'SUCCESS')
            GROUP BY oi.StockId, oi.SlotId
        )
        UPDATE ss SET Quantity = ss.Quantity + r.Qty
        FROM inventory.SlotStock ss JOIN ReturnLines r ON r.StockId = ss.StockId;

        ;WITH ReturnSlots AS (
            SELECT oi.SlotId, SUM(oi.Quantity) AS Qty
            FROM sales.OrderItem oi
            WHERE oi.OrderId = @OrderId
              AND NOT EXISTS (SELECT 1 FROM sales.DispenseEvents de
                              WHERE de.OrderItemId = oi.OrderItemId AND de.Result = N'SUCCESS')
            GROUP BY oi.SlotId
        )
        UPDATE s SET CurrentStock = CurrentStock + r.Qty, UpdatedAt = @Now
        FROM inventory.Slot s JOIN ReturnSlots r ON r.SlotId = s.SlotId;

        INSERT sales.Refund (PaymentId, OrderId, Amount, RefundAmount, Reason, Status,
                             ProcessedBy, ProcessedAt, RefundedAt, CreatedAt)
        VALUES (@PaymentId, @OrderId, @RefundAmount, @RefundAmount, @Reason, N'completed',
                @RefundedBy, @Now, @Now, @Now);
        SET @RefundId = CONVERT(BIGINT, SCOPE_IDENTITY());
        UPDATE sales.Payment SET Status = N'refunded' WHERE PaymentId = @PaymentId;
        UPDATE sales.[Order] SET Status = N'REFUNDED', CompletedAt = @Now, UpdatedAt = @Now WHERE OrderId = @OrderId;

        INSERT inventory.StockMovement (SlotId, BatchId, MovementType, Quantity, Reason, CreatedBy, CreatedAt)
        SELECT oi.SlotId, ss.BatchId, N'IN', SUM(oi.Quantity),
               N'Hoàn hàng đơn ' + CONVERT(NVARCHAR(20), @OrderId), @RefundedBy, @Now
        FROM sales.OrderItem oi JOIN inventory.SlotStock ss ON ss.StockId = oi.StockId
        WHERE oi.OrderId = @OrderId
          AND NOT EXISTS (SELECT 1 FROM sales.DispenseEvents de
                          WHERE de.OrderItemId = oi.OrderItemId AND de.Result = N'SUCCESS')
        GROUP BY oi.SlotId, ss.BatchId;

        COMMIT;
        SELECT @RefundId AS RefundId, @OrderId AS OrderId,
               @RefundAmount AS Amount, N'REFUNDED' AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- 5. Cancel/expire pending orders and release reserved stock.
-- SQL Agent can call with no parameters every minute; the API can pass OrderId
-- to cancel one pending order.
-- =============================================================================
CREATE OR ALTER PROCEDURE sales.sp_ExpirePendingOrders
    @OrderId BIGINT = NULL,
    @TimeoutMinutes INT = 5
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @TimeoutMinutes IS NULL OR @TimeoutMinutes <= 0
        THROW 50216, N'Thời gian chờ phải lớn hơn 0 phút.', 1;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @Expired TABLE (OrderId BIGINT PRIMARY KEY, FinalStatus NVARCHAR(20));
    BEGIN TRY
        BEGIN TRAN;
        INSERT @Expired (OrderId, FinalStatus)
        SELECT o.OrderId,
               CASE WHEN @OrderId IS NOT NULL THEN N'CANCELLED' ELSE N'EXPIRED' END
        FROM sales.[Order] o WITH (UPDLOCK, HOLDLOCK)
        WHERE UPPER(o.Status) = N'PENDING'
          AND ((@OrderId IS NOT NULL AND o.OrderId = @OrderId)
               OR (@OrderId IS NULL AND o.ExpiresAt <= @Now));

        IF @OrderId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM @Expired)
            THROW 50217, N'Đơn không tồn tại hoặc không còn ở trạng thái chờ.', 1;

        ;WITH ReturnLots AS (
            SELECT oi.StockId, SUM(oi.Quantity) AS Qty
            FROM sales.OrderItem oi JOIN @Expired e ON e.OrderId = oi.OrderId
            WHERE oi.StockId IS NOT NULL
            GROUP BY oi.StockId
        )
        UPDATE ss SET Quantity = ss.Quantity + r.Qty
        FROM inventory.SlotStock ss JOIN ReturnLots r ON r.StockId = ss.StockId;

        ;WITH ReturnSlots AS (
            SELECT oi.SlotId, SUM(oi.Quantity) AS Qty
            FROM sales.OrderItem oi JOIN @Expired e ON e.OrderId = oi.OrderId
            GROUP BY oi.SlotId
        )
        UPDATE s SET CurrentStock = CurrentStock + r.Qty, UpdatedAt = @Now
        FROM inventory.Slot s JOIN ReturnSlots r ON r.SlotId = s.SlotId;

        INSERT inventory.StockMovement (SlotId, BatchId, MovementType, Quantity, Reason, CreatedAt)
        SELECT oi.SlotId, ss.BatchId, N'IN', SUM(oi.Quantity),
               N'Trả hàng đơn hết hạn/hủy ' + CONVERT(NVARCHAR(20), oi.OrderId), @Now
        FROM sales.OrderItem oi
        JOIN @Expired e ON e.OrderId = oi.OrderId
        JOIN inventory.SlotStock ss ON ss.StockId = oi.StockId
        GROUP BY oi.SlotId, ss.BatchId, oi.OrderId;

        UPDATE o SET Status = e.FinalStatus, CompletedAt = @Now, UpdatedAt = @Now
        FROM sales.[Order] o JOIN @Expired e ON e.OrderId = o.OrderId;
        COMMIT;

        SELECT COUNT(*) AS ExpiredOrders FROM @Expired;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
