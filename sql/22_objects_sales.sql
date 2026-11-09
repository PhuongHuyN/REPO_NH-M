-- =============================================================================
-- FILE        : 22_objects_sales.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV3 — Function, trigger và view schema [sales]
--               fn_OrderTotal, trg_Orders_StatusGuard,
--               vw_OrderDetail, vw_PendingOrders
-- VERSION     : 1.0.0
-- CREATED     : 2026-11-04
-- RUN ORDER   : Sau 02_tables_sales.sql, 03_foreign_keys.sql, 12_procs_sales.sql
-- NOTE        : Luồng trạng thái đơn khớp docs/UserStories_Sales.md và 12_procs_sales.sql
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 1. sales.fn_OrderTotal — Tổng tiền theo dòng OrderItem (trước giảm giá)
-- =============================================================================

CREATE OR ALTER FUNCTION sales.fn_OrderTotal (@OrderId BIGINT)
RETURNS DECIMAL(14,2)
AS
BEGIN
    DECLARE @Total DECIMAL(14,2);

    SELECT @Total = COALESCE(SUM(oi.LineTotal), 0)
    FROM sales.OrderItem oi
    WHERE oi.OrderId = @OrderId;

    RETURN @Total;
END;
GO

-- =============================================================================
-- 2. sales.trg_Orders_StatusGuard — Chặn chuyển trạng thái sai (state machine)
-- =============================================================================

CREATE OR ALTER TRIGGER sales.trg_Orders_StatusGuard
ON sales.[Order]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(Status)
        RETURN;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON d.OrderId = i.OrderId
        WHERE UPPER(i.Status) <> UPPER(d.Status)
          AND NOT (
                (UPPER(d.Status) = N'PENDING' AND UPPER(i.Status) IN (N'PAID', N'EXPIRED', N'CANCELLED'))
             OR (UPPER(d.Status) = N'PAID' AND UPPER(i.Status) IN (N'DISPENSED', N'DISPENSE_FAILED', N'REFUNDED'))
             OR (UPPER(d.Status) = N'DISPENSE_FAILED' AND UPPER(i.Status) = N'REFUNDED')
          )
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50220, N'Chuyển trạng thái đơn hàng không hợp lệ (ví dụ REFUNDED → PAID).', 1;
    END;
END;
GO

-- =============================================================================
-- 3. sales.vw_OrderDetail — Đơn · sản phẩm · thanh toán · kết quả nhả (theo dòng)
-- =============================================================================

CREATE OR ALTER VIEW sales.vw_OrderDetail
AS
SELECT
    o.OrderId,
    o.OrderCode,
    o.MachineId,
    m.MachineCode,
    o.Status              AS OrderStatus,
    o.Subtotal,
    o.DiscountAmount,
    o.TotalAmount,
    o.CreatedAt           AS OrderCreatedAt,
    o.PaidAt              AS OrderPaidAt,
    o.CompletedAt         AS OrderCompletedAt,
    oi.OrderItemId,
    oi.SlotId,
    oi.ProductId,
    p.SKU,
    p.ProductName,
    oi.Quantity,
    oi.UnitPrice,
    oi.LineTotal,
    pay.PaymentId,
    pay.PaymentMethod,
    pay.Status            AS PaymentStatus,
    pay.Amount            AS PaymentAmount,
    pay.TransactionRef,
    pay.GatewayTxnId,
    pay.PaidAt            AS PaymentPaidAt,
    disp.DispenseAttempts,
    disp.LastDispenseResult,
    disp.LastDispenseErrorCode,
    disp.LastDispenseAt
FROM sales.[Order] o
INNER JOIN sales.OrderItem oi
    ON oi.OrderId = o.OrderId
INNER JOIN inventory.Product p
    ON p.ProductId = oi.ProductId
LEFT JOIN inventory.Machine m
    ON m.MachineId = o.MachineId
OUTER APPLY (
    SELECT TOP (1)
        pmt.PaymentId,
        pmt.PaymentMethod,
        pmt.Status,
        pmt.Amount,
        pmt.TransactionRef,
        pmt.GatewayTxnId,
        pmt.PaidAt
    FROM sales.Payment pmt
    WHERE pmt.OrderId = o.OrderId
    ORDER BY pmt.PaymentId DESC
) pay
OUTER APPLY (
    SELECT
        COUNT(*) AS DispenseAttempts,
        MAX(CASE WHEN de.AttemptNo = mx.MaxAttempt THEN de.Result END) AS LastDispenseResult,
        MAX(CASE WHEN de.AttemptNo = mx.MaxAttempt THEN de.ErrorCode END) AS LastDispenseErrorCode,
        MAX(CASE WHEN de.AttemptNo = mx.MaxAttempt THEN de.EventAt END) AS LastDispenseAt
    FROM sales.DispenseEvents de
    CROSS APPLY (
        SELECT MAX(de2.AttemptNo) AS MaxAttempt
        FROM sales.DispenseEvents de2
        WHERE de2.OrderItemId = oi.OrderItemId
    ) mx
    WHERE de.OrderItemId = oi.OrderItemId
) disp;
GO

-- =============================================================================
-- 4. sales.vw_PendingOrders — Đơn chờ thanh toán (kèm tuổi đơn tính bằng giây)
-- =============================================================================

CREATE OR ALTER VIEW sales.vw_PendingOrders
AS
SELECT
    o.OrderId,
    o.OrderCode,
    o.MachineId,
    m.MachineCode,
    o.TotalAmount,
    o.CreatedAt,
    o.ExpiresAt,
    DATEDIFF(SECOND, o.CreatedAt, SYSUTCDATETIME()) AS AgeSeconds
FROM sales.[Order] o
LEFT JOIN inventory.Machine m
    ON m.MachineId = o.MachineId
WHERE UPPER(o.Status) = N'PENDING';
GO

-- =============================================================================
-- XÁC NHẬN
-- =============================================================================

SELECT name AS [Object], type_desc AS [Type]
FROM sys.objects
WHERE schema_id = SCHEMA_ID(N'sales')
  AND name IN (N'fn_OrderTotal', N'trg_Orders_StatusGuard', N'vw_OrderDetail', N'vw_PendingOrders')
ORDER BY name;
GO
