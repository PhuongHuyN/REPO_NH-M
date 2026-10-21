-- =============================================================================
-- FILE        : 02_tables_sales.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV3 — Tạo các bảng thuộc schema [sales]
--               Promotion, Order, OrderItem, Payment, Refund
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
        Status          NVARCHAR(20)    NOT NULL CONSTRAINT DF_sales_Order_Status   DEFAULT (N'pending'),
                                                        -- 'pending','paid','cancelled','refunded'
        Note            NVARCHAR(500)       NULL,
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_sales_Order_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt       DATETIME2(0)        NULL,

        CONSTRAINT PK_sales_Order               PRIMARY KEY (OrderId),
        CONSTRAINT UQ_sales_Order_Code          UNIQUE (OrderCode),
        CONSTRAINT FK_sales_Order_Promotion     FOREIGN KEY (PromotionId) REFERENCES sales.Promotion(PromotionId),
        CONSTRAINT CK_sales_Order_Status        CHECK (Status IN (N'pending', N'paid', N'cancelled', N'refunded')),
        CONSTRAINT CK_sales_Order_Total         CHECK (TotalAmount >= 0 AND DiscountAmount >= 0 AND Subtotal >= 0)
    );

    PRINT N'[02-sales] Bảng sales.Order đã được tạo.';
END
ELSE
    PRINT N'[02-sales] Bảng sales.Order đã tồn tại — bỏ qua.';
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
        ProductId       INT             NOT NULL,       -- FK → inventory.Product (03_fk)
        Quantity        SMALLINT        NOT NULL,
        UnitPrice       DECIMAL(12,2)   NOT NULL,       -- giá tại thời điểm mua
        LineTotal       AS (CAST(Quantity AS DECIMAL(12,2)) * UnitPrice) PERSISTED,

        CONSTRAINT PK_sales_OrderItem           PRIMARY KEY (OrderItemId),
        CONSTRAINT FK_sales_OrderItem_Order     FOREIGN KEY (OrderId) REFERENCES sales.[Order](OrderId),
        CONSTRAINT CK_sales_OrderItem_Qty       CHECK (Quantity > 0),
        CONSTRAINT CK_sales_OrderItem_Price     CHECK (UnitPrice >= 0)
    );

    PRINT N'[02-sales] Bảng sales.OrderItem đã được tạo.';
END
ELSE
    PRINT N'[02-sales] Bảng sales.OrderItem đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 4. sales.Payment  — Giao dịch thanh toán
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sales.Payment'))
BEGIN
    CREATE TABLE sales.Payment (
        PaymentId       BIGINT          NOT NULL IDENTITY(1,1),
        OrderId         BIGINT          NOT NULL,
        PaymentMethod   NVARCHAR(20)    NOT NULL,   -- 'CASH','QRCODE','CARD','EWALLET'
        Amount          DECIMAL(14,2)   NOT NULL,
        Currency        CHAR(3)         NOT NULL CONSTRAINT DF_sales_Payment_Currency DEFAULT ('VND'),
        TransactionRef  NVARCHAR(100)       NULL,   -- mã GD từ cổng thanh toán
        Status          NVARCHAR(15)    NOT NULL CONSTRAINT DF_sales_Payment_Status   DEFAULT (N'pending'),
                                                    -- 'pending','success','failed','refunded'
        PaidAt          DATETIME2(0)        NULL,
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_sales_Payment_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_sales_Payment             PRIMARY KEY (PaymentId),
        CONSTRAINT FK_sales_Payment_Order       FOREIGN KEY (OrderId) REFERENCES sales.[Order](OrderId),
        CONSTRAINT CK_sales_Payment_Method      CHECK (PaymentMethod IN (N'CASH', N'QRCODE', N'CARD', N'EWALLET')),
        CONSTRAINT CK_sales_Payment_Status      CHECK (Status IN (N'pending', N'success', N'failed', N'refunded')),
        CONSTRAINT CK_sales_Payment_Amount      CHECK (Amount > 0)
    );

    PRINT N'[02-sales] Bảng sales.Payment đã được tạo.';
END
ELSE
    PRINT N'[02-sales] Bảng sales.Payment đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 5. sales.Refund  — Hoàn tiền
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sales.Refund'))
BEGIN
    CREATE TABLE sales.Refund (
        RefundId        BIGINT          NOT NULL IDENTITY(1,1),
        PaymentId       BIGINT          NOT NULL,
        RefundAmount    DECIMAL(14,2)   NOT NULL,
        Reason          NVARCHAR(300)       NULL,
        Status          NVARCHAR(15)    NOT NULL CONSTRAINT DF_sales_Refund_Status    DEFAULT (N'pending'),
        ProcessedBy     INT                 NULL,   -- FK → auth.User (03_fk)
        ProcessedAt     DATETIME2(0)        NULL,
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_sales_Refund_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_sales_Refund              PRIMARY KEY (RefundId),
        CONSTRAINT FK_sales_Refund_Payment      FOREIGN KEY (PaymentId) REFERENCES sales.Payment(PaymentId),
        CONSTRAINT CK_sales_Refund_Amount       CHECK (RefundAmount > 0),
        CONSTRAINT CK_sales_Refund_Status       CHECK (Status IN (N'pending', N'approved', N'rejected', N'completed'))
    );

    PRINT N'[02-sales] Bảng sales.Refund đã được tạo.';
END
ELSE
    PRINT N'[02-sales] Bảng sales.Refund đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- XÁC NHẬN
-- =============================================================================

SELECT TABLE_SCHEMA AS [Schema], TABLE_NAME AS [Table]
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'sales'
ORDER BY TABLE_NAME;
GO

PRINT N'';
PRINT N'============================================================';
PRINT N'  TV3 (sales) hoàn tất. Tiếp theo: 02_tables_iot.sql       ';
PRINT N'============================================================';
GO
