-- =============================================================================
-- FILE        : 02_tables_inventory.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV2 — Tạo các bảng thuộc schema [inventory]
--               Supplier, Category, Product, Machine, Slot,
--               StockBatch, StockMovement
-- VERSION     : 1.0.0
-- CREATED     : 2026-10-21
-- RUN ORDER   : Bước 2 — sau 02_tables_auth.sql
-- NOTE        : FK liên schema (inventory → auth) đặt trong 03_foreign_keys.sql
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 1. inventory.Supplier  — Nhà cung cấp trái cây
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'inventory.Supplier'))
BEGIN
    CREATE TABLE inventory.Supplier (
        SupplierId      INT             NOT NULL IDENTITY(1,1),
        SupplierName    NVARCHAR(150)   NOT NULL,
        ContactPerson   NVARCHAR(100)       NULL,
        PhoneNumber     NVARCHAR(15)        NULL,
        Email           NVARCHAR(150)       NULL,
        Address         NVARCHAR(300)       NULL,
        TaxCode         NVARCHAR(20)        NULL,
        IsActive        BIT             NOT NULL CONSTRAINT DF_inventory_Supplier_IsActive  DEFAULT (1),
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_inventory_Supplier_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt       DATETIME2(0)        NULL,

        CONSTRAINT PK_inventory_Supplier    PRIMARY KEY (SupplierId),
        CONSTRAINT UQ_inventory_Supplier_Tax UNIQUE (TaxCode)
    );

    PRINT N'[02-inv] Bảng inventory.Supplier đã được tạo.';
END
ELSE
    PRINT N'[02-inv] Bảng inventory.Supplier đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 2. inventory.Category  — Danh mục loại trái cây
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'inventory.Category'))
BEGIN
    CREATE TABLE inventory.Category (
        CategoryId      INT             NOT NULL IDENTITY(1,1),
        CategoryName    NVARCHAR(100)   NOT NULL,
        Description     NVARCHAR(300)       NULL,
        ParentId        INT                 NULL,   -- danh mục cha (tự tham chiếu)
        DisplayOrder    SMALLINT        NOT NULL CONSTRAINT DF_inventory_Category_DisplayOrder DEFAULT (0),
        IsActive        BIT             NOT NULL CONSTRAINT DF_inventory_Category_IsActive     DEFAULT (1),

        CONSTRAINT PK_inventory_Category        PRIMARY KEY (CategoryId),
        CONSTRAINT UQ_inventory_Category_Name   UNIQUE (CategoryName),
        CONSTRAINT FK_inventory_Category_Parent FOREIGN KEY (ParentId) REFERENCES inventory.Category(CategoryId)
    );

    PRINT N'[02-inv] Bảng inventory.Category đã được tạo.';
END
ELSE
    PRINT N'[02-inv] Bảng inventory.Category đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 3. inventory.Product  — Sản phẩm trái cây
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'inventory.Product'))
BEGIN
    CREATE TABLE inventory.Product (
        ProductId       INT             NOT NULL IDENTITY(1,1),
        SKU             NVARCHAR(30)    NOT NULL,   -- mã hàng nội bộ
        ProductName     NVARCHAR(150)   NOT NULL,
        CategoryId      INT             NOT NULL,
        SupplierId      INT                 NULL,
        UnitPrice       DECIMAL(12,2)   NOT NULL,
        Unit            NVARCHAR(20)    NOT NULL CONSTRAINT DF_inventory_Product_Unit DEFAULT (N'kg'),
        WeightGram      INT                 NULL,   -- khối lượng đơn vị (gram)
        Description     NVARCHAR(500)       NULL,
        ImageUrl        NVARCHAR(500)       NULL,
        ShelfLifeDays   SMALLINT            NULL,   -- hạn sử dụng (ngày)
        StorageTempMin  DECIMAL(4,1)        NULL,   -- °C
        StorageTempMax  DECIMAL(4,1)        NULL,   -- °C
        IsActive        BIT             NOT NULL CONSTRAINT DF_inventory_Product_IsActive  DEFAULT (1),
        IsDeleted       BIT             NOT NULL CONSTRAINT DF_inventory_Product_IsDeleted DEFAULT (0),
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_inventory_Product_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt       DATETIME2(0)        NULL,

        CONSTRAINT PK_inventory_Product         PRIMARY KEY (ProductId),
        CONSTRAINT UQ_inventory_Product_SKU     UNIQUE (SKU),
        CONSTRAINT FK_inventory_Product_Cat     FOREIGN KEY (CategoryId)  REFERENCES inventory.Category(CategoryId),
        CONSTRAINT FK_inventory_Product_Sup     FOREIGN KEY (SupplierId)  REFERENCES inventory.Supplier(SupplierId),
        CONSTRAINT CK_inventory_Product_Price   CHECK (UnitPrice >= 0),
        CONSTRAINT CK_inventory_Product_Temp    CHECK (StorageTempMin IS NULL OR StorageTempMax IS NULL OR StorageTempMin <= StorageTempMax)
    );

    PRINT N'[02-inv] Bảng inventory.Product đã được tạo.';
END
ELSE
    PRINT N'[02-inv] Bảng inventory.Product đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 4. inventory.Machine  — Máy bán hàng tự động
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'inventory.Machine'))
BEGIN
    CREATE TABLE inventory.Machine (
        MachineId       INT             NOT NULL IDENTITY(1,1),
        MachineCode     NVARCHAR(20)    NOT NULL,
        MachineName     NVARCHAR(100)   NOT NULL,
        Location        NVARCHAR(200)       NULL,
        Latitude        DECIMAL(10,7)       NULL,
        Longitude       DECIMAL(10,7)       NULL,
        Status          NVARCHAR(20)    NOT NULL CONSTRAINT DF_inventory_Machine_Status  DEFAULT (N'offline'),
                                                            -- 'online','offline','maintenance','error'
        InstallDate     DATE                NULL,
        LastServiceDate DATE                NULL,
        IsActive        BIT             NOT NULL CONSTRAINT DF_inventory_Machine_IsActive  DEFAULT (1),
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_inventory_Machine_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt       DATETIME2(0)        NULL,

        CONSTRAINT PK_inventory_Machine         PRIMARY KEY (MachineId),
        CONSTRAINT UQ_inventory_Machine_Code    UNIQUE (MachineCode),
        CONSTRAINT CK_inventory_Machine_Status  CHECK (Status IN (N'online', N'offline', N'maintenance', N'error'))
    );

    PRINT N'[02-inv] Bảng inventory.Machine đã được tạo.';
END
ELSE
    PRINT N'[02-inv] Bảng inventory.Machine đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 5. inventory.Slot  — Ngăn chứa hàng trong máy
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'inventory.Slot'))
BEGIN
    CREATE TABLE inventory.Slot (
        SlotId          INT             NOT NULL IDENTITY(1,1),
        MachineId       INT             NOT NULL,
        SlotCode        NVARCHAR(10)    NOT NULL,   -- vd: 'A1', 'B3'
        ProductId       INT                 NULL,   -- sản phẩm hiện đang chứa
        Capacity        SMALLINT        NOT NULL,   -- số đơn vị tối đa
        CurrentStock    SMALLINT        NOT NULL CONSTRAINT DF_inventory_Slot_CurrentStock DEFAULT (0),
        IsActive        BIT             NOT NULL CONSTRAINT DF_inventory_Slot_IsActive     DEFAULT (1),
        UpdatedAt       DATETIME2(0)        NULL,

        CONSTRAINT PK_inventory_Slot            PRIMARY KEY (SlotId),
        CONSTRAINT UQ_inventory_Slot_Code       UNIQUE (MachineId, SlotCode),
        CONSTRAINT FK_inventory_Slot_Machine    FOREIGN KEY (MachineId)  REFERENCES inventory.Machine(MachineId),
        CONSTRAINT FK_inventory_Slot_Product    FOREIGN KEY (ProductId)  REFERENCES inventory.Product(ProductId),
        CONSTRAINT CK_inventory_Slot_Stock      CHECK (CurrentStock >= 0 AND CurrentStock <= Capacity)
    );

    PRINT N'[02-inv] Bảng inventory.Slot đã được tạo.';
END
ELSE
    PRINT N'[02-inv] Bảng inventory.Slot đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 6. inventory.StockBatch  — Lô hàng nhập kho
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'inventory.StockBatch'))
BEGIN
    CREATE TABLE inventory.StockBatch (
        BatchId         INT             NOT NULL IDENTITY(1,1),
        ProductId       INT             NOT NULL,
        SupplierId      INT                 NULL,
        BatchCode       NVARCHAR(30)    NOT NULL,
        Quantity        INT             NOT NULL,
        UnitCost        DECIMAL(12,2)   NOT NULL,
        ImportDate      DATE            NOT NULL,
        ExpiryDate      DATE                NULL,
        Note            NVARCHAR(500)       NULL,
        CreatedBy       INT                 NULL,   -- FK → auth.User (03_fk)
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_inventory_StockBatch_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_inventory_StockBatch          PRIMARY KEY (BatchId),
        CONSTRAINT UQ_inventory_StockBatch_Code     UNIQUE (BatchCode),
        CONSTRAINT FK_inventory_StockBatch_Product  FOREIGN KEY (ProductId)  REFERENCES inventory.Product(ProductId),
        CONSTRAINT FK_inventory_StockBatch_Supplier FOREIGN KEY (SupplierId) REFERENCES inventory.Supplier(SupplierId),
        CONSTRAINT CK_inventory_StockBatch_Qty      CHECK (Quantity > 0),
        CONSTRAINT CK_inventory_StockBatch_Cost     CHECK (UnitCost >= 0)
    );

    PRINT N'[02-inv] Bảng inventory.StockBatch đã được tạo.';
END
ELSE
    PRINT N'[02-inv] Bảng inventory.StockBatch đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 7. inventory.StockMovement  — Lịch sử xuất/nhập kho theo ngăn máy
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'inventory.StockMovement'))
BEGIN
    CREATE TABLE inventory.StockMovement (
        MovementId      BIGINT          NOT NULL IDENTITY(1,1),
        SlotId          INT             NOT NULL,
        BatchId         INT                 NULL,
        MovementType    NVARCHAR(10)    NOT NULL,   -- 'IN' | 'OUT' | 'ADJUST'
        Quantity        INT             NOT NULL,
        Reason          NVARCHAR(200)       NULL,
        CreatedBy       INT                 NULL,   -- FK → auth.User (03_fk)
        CreatedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_inventory_StockMovement_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_inventory_StockMovement           PRIMARY KEY (MovementId),
        CONSTRAINT FK_inventory_StockMovement_Slot      FOREIGN KEY (SlotId)   REFERENCES inventory.Slot(SlotId),
        CONSTRAINT FK_inventory_StockMovement_Batch     FOREIGN KEY (BatchId)  REFERENCES inventory.StockBatch(BatchId),
        CONSTRAINT CK_inventory_StockMovement_Type      CHECK (MovementType IN (N'IN', N'OUT', N'ADJUST'))
    );

    PRINT N'[02-inv] Bảng inventory.StockMovement đã được tạo.';
END
ELSE
    PRINT N'[02-inv] Bảng inventory.StockMovement đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- XÁC NHẬN
-- =============================================================================

SELECT TABLE_SCHEMA AS [Schema], TABLE_NAME AS [Table]
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'inventory'
ORDER BY TABLE_NAME;
GO

PRINT N'';
PRINT N'==============================================================';
PRINT N'  TV2 (inventory) hoàn tất. Tiếp theo: 02_tables_sales.sql  ';
PRINT N'==============================================================';
GO
