-- =============================================================================
-- FILE        : 02_tables_inventory.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV2 — Tạo các bảng thuộc schema [inventory]
--               Supplier, Category, Product, Machine, Slot,
--               StockBatch, StockMovement
--               (v1.1) SlotStock, RestockEvent, RestockItem,
--               kiểu TVP RestockItemType, Temporal Table cho Product
-- VERSION     : 1.1.0
-- CREATED     : 2026-10-21
-- UPDATED     : 2026-11-07 — FV-02 (SCRUM-196): hạn dùng theo giờ, tồn theo lô
--               trong ngăn, phiếu châm hàng, TVP, lịch sử giá (Temporal)
-- RUN ORDER   : Bước 2 — sau 02_tables_auth.sql
-- NOTE        : FK liên schema (inventory → auth / iot) đặt trong 03_foreign_keys.sql
--               Chạy lại nhiều lần không lỗi (mọi khối đều có IF ... IS NULL).
--               Giờ lưu trong CSDL là UTC (SYSUTCDATETIME) — thống nhất với TV3.
--               KHÔNG xóa / đổi tên cột cũ: TV3, TV5 đang dùng Slot, StockBatch,
--               Product.UnitPrice, Slot.CurrentStock.
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
-- 8. (v1.1) Product.ShelfLifeHours — hạn dùng tính theo GIỜ (trái cây cắt sẵn)
--    Giữ nguyên ShelfLifeDays cũ để không ảnh hưởng code của nhóm.
-- =============================================================================

IF COL_LENGTH(N'inventory.Product', N'ShelfLifeHours') IS NULL
BEGIN
    ALTER TABLE inventory.Product ADD ShelfLifeHours INT NOT NULL
        CONSTRAINT DF_inventory_Product_ShelfLifeHours DEFAULT (24)
        CONSTRAINT CK_inventory_Product_ShelfLifeHours CHECK (ShelfLifeHours BETWEEN 1 AND 120);
    PRINT N'[02-inv] Đã thêm cột inventory.Product.ShelfLifeHours (1–120 giờ, mặc định 24).';
END
ELSE
    PRINT N'[02-inv] Cột Product.ShelfLifeHours đã có — bỏ qua.';
GO

-- Sản phẩm cũ đã khai báo ShelfLifeDays → đổi sang giờ (tối đa 120).
-- Chỉ cập nhật dòng còn khác giá trị, để chạy lại không sinh thêm lịch sử.
UPDATE inventory.Product
SET    ShelfLifeHours = CASE WHEN ShelfLifeDays * 24 > 120 THEN 120 ELSE ShelfLifeDays * 24 END
WHERE  ShelfLifeDays IS NOT NULL AND ShelfLifeDays > 0
  AND  ShelfLifeHours <> CASE WHEN ShelfLifeDays * 24 > 120 THEN 120 ELSE ShelfLifeDays * 24 END;
GO

-- =============================================================================
-- 9. (v1.1) StockBatch.PreparedAt / ExpiryAt — giờ làm và giờ hết hạn của lô
--    Giữ ImportDate / ExpiryDate (DATE) vì TV3 đang lọc theo ExpiryDate.
-- =============================================================================

IF COL_LENGTH(N'inventory.StockBatch', N'PreparedAt') IS NULL
BEGIN
    ALTER TABLE inventory.StockBatch ADD PreparedAt DATETIME2(0) NULL
        CONSTRAINT DF_inventory_StockBatch_PreparedAt DEFAULT SYSUTCDATETIME();
    PRINT N'[02-inv] Đã thêm cột inventory.StockBatch.PreparedAt.';
END
GO

IF COL_LENGTH(N'inventory.StockBatch', N'ExpiryAt') IS NULL
BEGIN
    ALTER TABLE inventory.StockBatch ADD ExpiryAt DATETIME2(0) NULL;
    PRINT N'[02-inv] Đã thêm cột inventory.StockBatch.ExpiryAt.';
END
GO

-- Lô cũ chỉ có ngày → suy ra giờ: làm lúc 00:00 ngày nhập, hết hạn 23:59:59 ngày hết hạn.
UPDATE inventory.StockBatch
SET    PreparedAt = CAST(ImportDate AS DATETIME2(0))
WHERE  PreparedAt IS NULL;

UPDATE inventory.StockBatch
SET    ExpiryAt = DATEADD(SECOND, -1, CAST(DATEADD(DAY, 1, ExpiryDate) AS DATETIME2(0)))
WHERE  ExpiryAt IS NULL AND ExpiryDate IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_inventory_StockBatch_Expiry')
BEGIN
    ALTER TABLE inventory.StockBatch WITH CHECK ADD CONSTRAINT CK_inventory_StockBatch_Expiry
        CHECK (ExpiryAt IS NULL OR PreparedAt IS NULL OR ExpiryAt > PreparedAt);
    PRINT N'[02-inv] Đã thêm CHECK: hạn dùng phải sau giờ làm.';
END
GO

-- =============================================================================
-- 10. (v1.1) inventory.SlotStock — tồn kho theo LÔ trong từng NGĂN (phục vụ FIFO)
--     Định nghĩa GIỐNG HỆT khối trong 12_procs_sales.sql (TV3) — file nào chạy
--     trước cũng được, không tạo trùng. Tổng Quantity của 1 ngăn = Slot.CurrentStock.
-- =============================================================================

IF OBJECT_ID(N'inventory.SlotStock', N'U') IS NULL
BEGIN
    CREATE TABLE inventory.SlotStock (
        StockId     BIGINT       NOT NULL IDENTITY(1,1),
        SlotId      INT          NOT NULL,
        BatchId     INT          NOT NULL,
        Quantity    SMALLINT     NOT NULL,
        LoadedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_inventory_SlotStock_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_inventory_SlotStock PRIMARY KEY (StockId),
        CONSTRAINT FK_inventory_SlotStock_Slot FOREIGN KEY (SlotId) REFERENCES inventory.Slot(SlotId),
        CONSTRAINT FK_inventory_SlotStock_Batch FOREIGN KEY (BatchId) REFERENCES inventory.StockBatch(BatchId),
        CONSTRAINT CK_inventory_SlotStock_Quantity CHECK (Quantity >= 0)
    );
    CREATE INDEX IX_inventory_SlotStock_FIFO
        ON inventory.SlotStock (SlotId, LoadedAt, StockId) INCLUDE (BatchId, Quantity);
    PRINT N'[02-inv] Bảng inventory.SlotStock đã được tạo.';
END
ELSE
    PRINT N'[02-inv] Bảng inventory.SlotStock đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 11. (v1.1) Phiếu châm hàng: RestockEvent (đầu phiếu) + RestockItem (dòng phiếu)
--     MachineId, UserId: FK sang bảng máy / auth.[User] do TV1 thêm ở 03_foreign_keys
--     (QĐ-1 chưa chốt bảng máy cuối cùng nên file này không khóa cứng FK máy).
-- =============================================================================

IF OBJECT_ID(N'inventory.RestockEvent', N'U') IS NULL
BEGIN
    CREATE TABLE inventory.RestockEvent (
        RestockId       INT             NOT NULL IDENTITY(1,1),
        MachineId       INT             NOT NULL,   -- FK → bảng máy (03_fk, theo QĐ-1)
        UserId          INT             NOT NULL,   -- FK → auth.[User] (03_fk)
        RestockedAt     DATETIME2(0)    NOT NULL CONSTRAINT DF_inventory_RestockEvent_At DEFAULT SYSUTCDATETIME(),
        Note            NVARCHAR(200)       NULL,

        CONSTRAINT PK_inventory_RestockEvent PRIMARY KEY (RestockId)
    );
    PRINT N'[02-inv] Bảng inventory.RestockEvent đã được tạo.';
END
ELSE
    PRINT N'[02-inv] Bảng inventory.RestockEvent đã tồn tại — bỏ qua.';
GO

IF OBJECT_ID(N'inventory.RestockItem', N'U') IS NULL
BEGIN
    CREATE TABLE inventory.RestockItem (
        RestockItemId   INT             NOT NULL IDENTITY(1,1),
        RestockId       INT             NOT NULL,
        SlotId          INT             NOT NULL,   -- API gọi là ColumnId
        BatchId         INT             NOT NULL,
        Qty             SMALLINT        NOT NULL,

        CONSTRAINT PK_inventory_RestockItem       PRIMARY KEY (RestockItemId),
        CONSTRAINT FK_inventory_RestockItem_Event FOREIGN KEY (RestockId) REFERENCES inventory.RestockEvent(RestockId),
        CONSTRAINT FK_inventory_RestockItem_Slot  FOREIGN KEY (SlotId)    REFERENCES inventory.Slot(SlotId),
        CONSTRAINT FK_inventory_RestockItem_Batch FOREIGN KEY (BatchId)   REFERENCES inventory.StockBatch(BatchId),
        CONSTRAINT UQ_inventory_RestockItem_Line  UNIQUE (RestockId, SlotId, BatchId),
        CONSTRAINT CK_inventory_RestockItem_Qty   CHECK (Qty BETWEEN 1 AND 20)
    );
    PRINT N'[02-inv] Bảng inventory.RestockItem đã được tạo.';
END
ELSE
    PRINT N'[02-inv] Bảng inventory.RestockItem đã tồn tại — bỏ qua.';
GO

-- Kiểu bảng (TVP) cho sp_Restock — tên cột ĐÚNG như app/api/src/routes/inventory.js:
-- db.tvp('inventory.RestockItemType', [['ColumnId','int'],['BatchId','int'],['Qty','smallint']], ...)
IF TYPE_ID(N'inventory.RestockItemType') IS NULL
BEGIN
    CREATE TYPE inventory.RestockItemType AS TABLE (
        ColumnId    INT         NOT NULL,
        BatchId     INT         NOT NULL,
        Qty         SMALLINT    NOT NULL CHECK (Qty BETWEEN 1 AND 20),
        PRIMARY KEY (ColumnId, BatchId)          -- mỗi cặp ngăn + lô chỉ 1 dòng
    );
    PRINT N'[02-inv] Kiểu TVP inventory.RestockItemType đã được tạo.';
END
ELSE
    PRINT N'[02-inv] Kiểu TVP inventory.RestockItemType đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 12. (v1.1) Temporal Table cho inventory.Product — SQL Server tự lưu lịch sử giá
--     Bảng lịch sử: inventory.ProductHistory. Cột ValidFrom/ValidTo để HIDDEN nên
--     SELECT * và INSERT không liệt kê cột của các file khác KHÔNG bị ảnh hưởng.
--     Xem lịch sử:  SELECT ProductId, UnitPrice, ValidFrom, ValidTo
--                   FROM inventory.Product FOR SYSTEM_TIME ALL WHERE ProductId = 1;
--     Lưu ý: bảng temporal không TRUNCATE / DROP trực tiếp được — phải tắt
--     SYSTEM_VERSIONING trước.
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.periods WHERE object_id = OBJECT_ID(N'inventory.Product'))
BEGIN
    ALTER TABLE inventory.Product ADD
        ValidFrom DATETIME2(0) GENERATED ALWAYS AS ROW START HIDDEN NOT NULL
            CONSTRAINT DF_inventory_Product_ValidFrom DEFAULT SYSUTCDATETIME(),
        ValidTo   DATETIME2(0) GENERATED ALWAYS AS ROW END   HIDDEN NOT NULL
            CONSTRAINT DF_inventory_Product_ValidTo   DEFAULT CONVERT(DATETIME2(0), '9999-12-31 23:59:59'),
        PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
    PRINT N'[02-inv] Đã thêm cột thời gian hệ thống ValidFrom/ValidTo cho Product.';
END
GO

IF EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'inventory.Product') AND temporal_type <> 2)
BEGIN
    ALTER TABLE inventory.Product
        SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = inventory.ProductHistory, DATA_CONSISTENCY_CHECK = ON));
    PRINT N'[02-inv] Đã bật Temporal Table: lịch sử ghi vào inventory.ProductHistory.';
END
ELSE
    PRINT N'[02-inv] inventory.Product đã là Temporal Table — bỏ qua.';
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
