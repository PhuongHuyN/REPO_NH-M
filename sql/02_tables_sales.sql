-- =============================================================================
-- FILE        : 02_tables_sales.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV3 — Tạo các bảng thuộc schema [sales]
--               Promotion, Order, OrderItem, Payment, Refund, DispenseEvents
-- VERSION     : 1.0.0
-- CREATED     : 2026-10-21
-- RUN ORDER   : Bước 2 — sau 02_tables_inventory.sql
-- NOTE        : FK liên schema đặt trong 03_foreign_keys.sql
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 1. sales.Promotion  — Chương trình khuyến mãi / mã giảm giá
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sales.Promotion'))
BEGIN
    CREATE TABLE sales.Promotion (
        PromotionId     INT             NOT NULL IDENTITY(1,1),
        PromoCode       NVARCHAR(30)    NOT NULL,
        Description     NVARCHAR(300)       NULL,
        DiscountType    NVARCHAR(10)    NOT NULL,       -- 'PERCENT' | 'FIXED'
        DiscountValue   DECIMAL(12,2)   NOT NULL,
        MinOrderAmount  DECIMAL(12,2)       NULL,
        MaxUses         INT                 NULL,       -- NULL = không giới hạn
        UsedCount       INT             NOT NULL CONSTRAINT DF_sales_Promotion_UsedCount   DEFAULT (0),
        StartDate       DATETIME2(0)    NOT NULL,
        EndDate         DATETIME2(0)    NOT NULL,
        IsActive        BIT             NOT NULL CONSTRAINT DF_sales_Promotion_IsActive    DEFAULT (1),
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_sales_Promotion_CreatedAt   DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_sales_Promotion               PRIMARY KEY (PromotionId),
        CONSTRAINT UQ_sales_Promotion_Code          UNIQUE (PromoCode),
        CONSTRAINT CK_sales_Promotion_Type          CHECK (DiscountType IN (N'PERCENT', N'FIXED')),
        CONSTRAINT CK_sales_Promotion_Percent       CHECK (DiscountType <> N'PERCENT' OR (DiscountValue > 0 AND DiscountValue <= 100)),
        CONSTRAINT CK_sales_Promotion_Fixed         CHECK (DiscountType <> N'FIXED'   OR DiscountValue > 0),
        CONSTRAINT CK_sales_Promotion_DateRange     CHECK (EndDate > StartDate)
    );

    PRINT N'[02-sales] Bảng sales.Promotion đã được tạo.';
END
ELSE
    PRINT N'[02-sales] Bảng sales.Promotion đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 2. sales.Order  — Đơn hàng (mỗi phiên giao dịch tại máy)
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sales.Order'))
BEGIN
    CREATE TABLE sales.[Order] (
        OrderId         BIGINT          NOT NULL IDENTITY(1,1),
        OrderCode       NVARCHAR(30)    NOT NULL,       -- mã đơn hiển thị cho KH
        MachineId       INT             NOT NULL,       -- FK → inventory.Machine (03_fk)
        CustomerId      INT                 NULL,       -- FK → auth.User (03_fk), NULL = khách vãng lai
        PromotionId     INT                 NULL,       -- FK → sales.Promotion
        Subtotal        DECIMAL(14,2)   NOT NULL,
        DiscountAmount  DECIMAL(14,2)   NOT NULL CONSTRAINT DF_sales_Order_Discount DEFAULT (0),
        TotalAmount     DECIMAL(14,2)   NOT NULL,
        Status          NVARCHAR(20)    NOT NULL CONSTRAINT DF_sales_Order_Status   DEFAULT (N'PENDING'),
                                                        -- 'pending','paid','cancelled','refunded'
        Note            NVARCHAR(500)       NULL,
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_sales_Order_CreatedAt DEFAULT SYSUTCDATETIME(),
        ExpiresAt        DATETIME2(0)    NOT NULL CONSTRAINT DF_sales_Order_ExpiresAt DEFAULT DATEADD(MINUTE, 5, SYSUTCDATETIME()),
        PaidAt          DATETIME2(0)        NULL,
        CompletedAt     DATETIME2(0)        NULL,
        UpdatedAt       DATETIME2(0)        NULL,

        CONSTRAINT PK_sales_Order               PRIMARY KEY (OrderId),
        CONSTRAINT UQ_sales_Order_Code          UNIQUE (OrderCode),
        CONSTRAINT FK_sales_Order_Promotion     FOREIGN KEY (PromotionId) REFERENCES sales.Promotion(PromotionId),
        CONSTRAINT CK_sales_Order_Status        CHECK (UPPER(Status) IN (N'PENDING', N'PAID', N'COMPLETED', N'DISPENSED', N'DISPENSE_FAILED', N'EXPIRED', N'CANCELLED', N'REFUNDED')),
        CONSTRAINT CK_sales_Order_Total         CHECK (TotalAmount >= 0 AND DiscountAmount >= 0 AND Subtotal >= 0)
    );

    PRINT N'[02-sales] Bảng sales.Order đã được tạo.';
END
ELSE
    PRINT N'[02-sales] Bảng sales.Order đã tồn tại — bỏ qua.';
GO

-- Upgrade existing installations without replacing the sales schema.
IF COL_LENGTH(N'sales.Order', N'ExpiresAt') IS NULL
    ALTER TABLE sales.[Order] ADD ExpiresAt DATETIME2(0) NULL;
IF COL_LENGTH(N'sales.Order', N'PaidAt') IS NULL
    ALTER TABLE sales.[Order] ADD PaidAt DATETIME2(0) NULL;
IF COL_LENGTH(N'sales.Order', N'CompletedAt') IS NULL
    ALTER TABLE sales.[Order] ADD CompletedAt DATETIME2(0) NULL;
GO

UPDATE sales.[Order]
SET ExpiresAt = DATEADD(MINUTE, 5, CreatedAt)
WHERE ExpiresAt IS NULL;
GO

IF EXISTS (SELECT 1 FROM sys.default_constraints
           WHERE name = N'DF_sales_Order_Status'
             AND parent_object_id = OBJECT_ID(N'sales.[Order]'))
    ALTER TABLE sales.[Order] DROP CONSTRAINT DF_sales_Order_Status;
ALTER TABLE sales.[Order] ADD CONSTRAINT DF_sales_Order_Status DEFAULT (N'PENDING') FOR Status;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = N'CK_sales_Order_Status'
             AND parent_object_id = OBJECT_ID(N'sales.[Order]'))
    ALTER TABLE sales.[Order] DROP CONSTRAINT CK_sales_Order_Status;
GO

ALTER TABLE sales.[Order] ALTER COLUMN ExpiresAt DATETIME2(0) NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints
               WHERE name = N'DF_sales_Order_ExpiresAt'
                 AND parent_object_id = OBJECT_ID(N'sales.[Order]'))
    ALTER TABLE sales.[Order] ADD CONSTRAINT DF_sales_Order_ExpiresAt
        DEFAULT DATEADD(MINUTE, 5, SYSUTCDATETIME()) FOR ExpiresAt;
ALTER TABLE sales.[Order] WITH CHECK
    ADD CONSTRAINT CK_sales_Order_Status
    CHECK (UPPER(Status) IN (N'PENDING', N'PAID', N'COMPLETED', N'DISPENSED', N'DISPENSE_FAILED', N'EXPIRED', N'CANCELLED', N'REFUNDED'));
GO

-- =============================================================================
-- 3. sales.OrderItem  — Chi tiết sản phẩm trong đơn hàng
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sales.OrderItem'))
BEGIN
    CREATE TABLE sales.OrderItem (
        OrderItemId     BIGINT          NOT NULL IDENTITY(1,1),
        OrderId         BIGINT          NOT NULL,
        SlotId          INT             NOT NULL,       -- FK → inventory.Slot (03_fk)
        ColumnId        AS (SlotId) PERSISTED,           -- API naming alias for the same slot
        StockId         BIGINT              NULL,       -- FIFO lot row, added by 12_procs_sales.sql
        BatchId         INT                 NULL,       -- source batch for reporting/traceability
        ProductId       INT             NOT NULL,       -- FK → inventory.Product (03_fk)
        Quantity        SMALLINT        NOT NULL,
        Qty             AS (Quantity) PERSISTED,         -- API naming alias
        UnitPrice       DECIMAL(12,2)   NOT NULL,       -- giá tại thời điểm mua
        LineTotal       AS (CAST(Quantity AS DECIMAL(12,2)) * UnitPrice) PERSISTED,

        CONSTRAINT PK_sales_OrderItem           PRIMARY KEY (OrderItemId),
        CONSTRAINT FK_sales_OrderItem_Order     FOREIGN KEY (OrderId) REFERENCES sales.[Order](OrderId),
        CONSTRAINT CK_sales_OrderItem_Qty       CHECK (Quantity BETWEEN 1 AND 5),
        CONSTRAINT CK_sales_OrderItem_Price     CHECK (UnitPrice >= 0)
    );

    PRINT N'[02-sales] Bảng sales.OrderItem đã được tạo.';
END
ELSE
    PRINT N'[02-sales] Bảng sales.OrderItem đã tồn tại — bỏ qua.';
GO

IF COL_LENGTH(N'sales.OrderItem', N'StockId') IS NULL
    ALTER TABLE sales.OrderItem ADD StockId BIGINT NULL;
IF COL_LENGTH(N'sales.OrderItem', N'BatchId') IS NULL
    ALTER TABLE sales.OrderItem ADD BatchId INT NULL;
IF COL_LENGTH(N'sales.OrderItem', N'ColumnId') IS NULL
    ALTER TABLE sales.OrderItem ADD ColumnId AS (SlotId) PERSISTED;
IF COL_LENGTH(N'sales.OrderItem', N'Qty') IS NULL
    ALTER TABLE sales.OrderItem ADD Qty AS (Quantity) PERSISTED;
IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = N'CK_sales_OrderItem_Qty'
             AND parent_object_id = OBJECT_ID(N'sales.OrderItem'))
    ALTER TABLE sales.OrderItem DROP CONSTRAINT CK_sales_OrderItem_Qty;
ALTER TABLE sales.OrderItem WITH CHECK
    ADD CONSTRAINT CK_sales_OrderItem_Qty CHECK (Quantity BETWEEN 1 AND 5);
GO

-- =============================================================================
-- 4. sales.Payment  — Giao dịch thanh toán
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sales.Payment'))
BEGIN
    CREATE TABLE sales.Payment (
        PaymentId       BIGINT          NOT NULL IDENTITY(1,1),
        OrderId         BIGINT          NOT NULL,
        PaymentMethod   NVARCHAR(20)    NOT NULL,   -- API uses VIETQR, MOMO, VNPAY
        Method          AS (PaymentMethod) PERSISTED,
        Amount          DECIMAL(14,2)   NOT NULL,
        Currency        CHAR(3)         NOT NULL CONSTRAINT DF_sales_Payment_Currency DEFAULT ('VND'),
        TransactionRef  NVARCHAR(100)       NULL,   -- mã GD từ cổng thanh toán
        GatewayTxnId    NVARCHAR(100)       NULL,   -- API webhook idempotency key
        Status          NVARCHAR(15)    NOT NULL CONSTRAINT DF_sales_Payment_Status   DEFAULT (N'pending'),
                                                    -- 'pending','success','failed','refunded'
        PaidAt          DATETIME2(0)        NULL,
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_sales_Payment_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_sales_Payment             PRIMARY KEY (PaymentId),
        CONSTRAINT FK_sales_Payment_Order       FOREIGN KEY (OrderId) REFERENCES sales.[Order](OrderId),
        CONSTRAINT CK_sales_Payment_Method      CHECK (PaymentMethod IN (N'CASH', N'QRCODE', N'CARD', N'EWALLET', N'VIETQR', N'MOMO', N'VNPAY')),
        CONSTRAINT CK_sales_Payment_Status      CHECK (Status IN (N'pending', N'success', N'failed', N'refunded')),
        CONSTRAINT CK_sales_Payment_Amount      CHECK (Amount > 0)
    );

    PRINT N'[02-sales] Bảng sales.Payment đã được tạo.';
END
ELSE
    PRINT N'[02-sales] Bảng sales.Payment đã tồn tại — bỏ qua.';
GO

IF COL_LENGTH(N'sales.Payment', N'GatewayTxnId') IS NULL
    ALTER TABLE sales.Payment ADD GatewayTxnId NVARCHAR(100) NULL;
IF COL_LENGTH(N'sales.Payment', N'Method') IS NULL
    ALTER TABLE sales.Payment ADD Method AS (PaymentMethod) PERSISTED;
GO

UPDATE sales.Payment SET GatewayTxnId = TransactionRef
WHERE GatewayTxnId IS NULL AND TransactionRef IS NOT NULL;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = N'CK_sales_Payment_Method'
             AND parent_object_id = OBJECT_ID(N'sales.Payment'))
    ALTER TABLE sales.Payment DROP CONSTRAINT CK_sales_Payment_Method;
GO

ALTER TABLE sales.Payment WITH CHECK
    ADD CONSTRAINT CK_sales_Payment_Method
    CHECK (PaymentMethod IN (N'CASH', N'QRCODE', N'CARD', N'EWALLET', N'VIETQR', N'MOMO', N'VNPAY'));
IF NOT EXISTS (SELECT 1 FROM sys.indexes
WHERE name = N'UQ_sales_Payment_GatewayTxnId'
AND object_id = OBJECT_ID(N'sales.Payment'))
    CREATE UNIQUE INDEX UQ_sales_Payment_GatewayTxnId
        ON sales.Payment(GatewayTxnId) WHERE GatewayTxnId IS NOT NULL;
GO

-- =============================================================================
-- 5. sales.Refund  — Hoàn tiền
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sales.Refund'))
BEGIN
    CREATE TABLE sales.Refund (
        RefundId        BIGINT          NOT NULL IDENTITY(1,1),
        PaymentId       BIGINT          NOT NULL,
        OrderId         BIGINT          NOT NULL,
        Amount          DECIMAL(14,2)   NOT NULL,
        RefundAmount    DECIMAL(14,2)   NOT NULL,
        Reason          NVARCHAR(300)       NULL,
        Status          NVARCHAR(15)    NOT NULL CONSTRAINT DF_sales_Refund_Status    DEFAULT (N'pending'),
        ProcessedBy     INT                 NULL,   -- FK → auth.User (03_fk)
        ProcessedAt     DATETIME2(0)        NULL,
        RefundedAt      DATETIME2(0)    NOT NULL,
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_sales_Refund_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_sales_Refund              PRIMARY KEY (RefundId),
        CONSTRAINT FK_sales_Refund_Payment      FOREIGN KEY (PaymentId) REFERENCES sales.Payment(PaymentId),
        CONSTRAINT FK_sales_Refund_Order        FOREIGN KEY (OrderId) REFERENCES sales.[Order](OrderId),
        CONSTRAINT CK_sales_Refund_Amount       CHECK (RefundAmount > 0),
        CONSTRAINT CK_sales_Refund_Amount_New   CHECK (Amount > 0),
        CONSTRAINT CK_sales_Refund_Status       CHECK (Status IN (N'pending', N'approved', N'rejected', N'completed'))
    );

    PRINT N'[02-sales] Bảng sales.Refund đã được tạo.';
END
ELSE
    PRINT N'[02-sales] Bảng sales.Refund đã tồn tại — bỏ qua.';
GO

IF COL_LENGTH(N'sales.Refund', N'OrderId') IS NULL
    ALTER TABLE sales.Refund ADD OrderId BIGINT NULL;
IF COL_LENGTH(N'sales.Refund', N'Amount') IS NULL
    ALTER TABLE sales.Refund ADD Amount DECIMAL(14,2) NULL;
IF COL_LENGTH(N'sales.Refund', N'RefundedAt') IS NULL
    ALTER TABLE sales.Refund ADD RefundedAt DATETIME2(0) NULL;
GO

UPDATE r
SET r.OrderId = p.OrderId,
    r.Amount = COALESCE(r.Amount, r.RefundAmount),
    r.RefundedAt = COALESCE(r.RefundedAt, r.ProcessedAt, r.CreatedAt)
FROM sales.Refund r
JOIN sales.Payment p ON p.PaymentId = r.PaymentId
WHERE r.OrderId IS NULL OR r.Amount IS NULL OR r.RefundedAt IS NULL;
GO

ALTER TABLE sales.Refund ALTER COLUMN OrderId BIGINT NOT NULL;
ALTER TABLE sales.Refund ALTER COLUMN Amount DECIMAL(14,2) NOT NULL;
ALTER TABLE sales.Refund ALTER COLUMN RefundedAt DATETIME2(0) NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
WHERE name = N'CK_sales_Refund_Amount_New'
AND parent_object_id = OBJECT_ID(N'sales.Refund'))
    ALTER TABLE sales.Refund WITH CHECK
        ADD CONSTRAINT CK_sales_Refund_Amount_New CHECK (Amount > 0);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sales_Refund_Order')
    ALTER TABLE sales.Refund WITH CHECK
        ADD CONSTRAINT FK_sales_Refund_Order FOREIGN KEY (OrderId) REFERENCES sales.[Order](OrderId);
GO

IF OBJECT_ID(N'sales.DispenseEvents', N'U') IS NULL
BEGIN
    CREATE TABLE sales.DispenseEvents (
        EventId       BIGINT       NOT NULL IDENTITY(1,1),
        OrderItemId   BIGINT       NOT NULL,
        AttemptNo     TINYINT      NOT NULL,
        Result        NVARCHAR(10) NOT NULL,
        ErrorCode     NVARCHAR(30) NULL,
        EventAt       DATETIME2(0) NOT NULL CONSTRAINT DF_sales_DispenseEvents_EventAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_sales_DispenseEvents PRIMARY KEY (EventId),
        CONSTRAINT FK_sales_DispenseEvents_OrderItem FOREIGN KEY (OrderItemId) REFERENCES sales.OrderItem(OrderItemId),
        CONSTRAINT UQ_sales_DispenseEvents_Attempt UNIQUE (OrderItemId, AttemptNo),
        CONSTRAINT CK_sales_DispenseEvents_Attempt CHECK (AttemptNo BETWEEN 1 AND 3),
        CONSTRAINT CK_sales_DispenseEvents_Result CHECK (Result IN (N'SUCCESS', N'JAM'))
    );
END;
GO

-- SQL Server table types cannot be altered; create the API TVP once.
IF TYPE_ID(N'sales.OrderItemType') IS NULL
    EXEC(N'CREATE TYPE sales.OrderItemType AS TABLE (
        ColumnId INT NOT NULL PRIMARY KEY,
        Qty TINYINT NOT NULL CHECK (Qty BETWEEN 1 AND 5)
    );');
GO

-- =============================================================================
-- XÁC NHẬN
-- =============================================================================

SELECT TABLE_SCHEMA AS [Schema], TABLE_NAME AS [Table]
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'sales'
ORDER BY TABLE_NAME;
GO
