-- =============================================================================
-- FILE        : 11_procs_inventory.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV2 — Stored procedure module inventory
--               FV-03 (SCRUM-197): sp_AddProduct, sp_UpdateProduct, sp_UpdatePrice,
--                                  sp_AssignColumn, sp_AddBatch
--               FV-04 (SCRUM-198): sp_Restock (TVP + transaction), sp_RemoveExpired
-- VERSION     : 1.1.0
-- CREATED     : 2026-11-07
-- RUN ORDER   : Sau 02_tables_inventory.sql (v1.1), 03_foreign_keys.sql, 08_seed_inventory.sql
-- ĐẶC TẢ      : app/api/test/fakeDb.js (dòng 145–196) — tên tham số, mã lỗi, cột trả về
--               app/api/src/routes/inventory.js — cách API gọi từng procedure
-- QUY ƯỚC     : • Mã lỗi TV2: 50100–50199 (THROW), thông báo tiếng Việt giống fakeDb.js
--                 → app/api/src/lib/errors.js đổi sang HTTP 404 / 409 / 400.
--               • API gọi "cột" (ColumnId, ColumnNo); SQL giữ tên "ngăn" (SlotId, SlotCode)
--                 và đặt bí danh khi trả kết quả (QĐ-2). ColumnNo = số thứ tự ngăn trong
--                 máy, sắp theo SlotCode (A1 = 1, A2 = 2, … C4 = 12).
--               • API gọi "giá" là Price; cột trong bảng là UnitPrice.
--               • Giờ lưu UTC (SYSUTCDATETIME) — thống nhất với TV3.
--               • CREATE OR ALTER → chạy lại file nhiều lần không lỗi.
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 1. inventory.sp_AddProduct — Thêm sản phẩm mới
--    Lỗi: 50100 tên trống · 50101 trùng tên · 50102 giá ≤ 0 · 50108 hạn dùng ngoài 1–120 giờ
--    Trả về: ProductId, ProductName, Price (+ SKU tự sinh)
-- =============================================================================
CREATE OR ALTER PROCEDURE inventory.sp_AddProduct
    @ProductName    NVARCHAR(100),
    @Price          DECIMAL(12,2),
    @ShelfLifeHours INT,
    @Category       NVARCHAR(50)  = NULL,   -- tên danh mục; NULL → 'Trái cây cắt sẵn'
    @Description    NVARCHAR(300) = NULL,
    @ImageUrl       NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- 1. Kiểm tra đầu vào
        SET @ProductName = LTRIM(RTRIM(@ProductName));
        SET @Category    = NULLIF(LTRIM(RTRIM(@Category)), N'');

        IF @ProductName IS NULL OR @ProductName = N''
            THROW 50100, N'Tên sản phẩm không được để trống', 1;
        -- Collation Vietnamese_CI_AS → so sánh không phân biệt hoa/thường
        IF EXISTS (SELECT 1 FROM inventory.Product WHERE ProductName = @ProductName AND IsDeleted = 0)
            THROW 50101, N'Tên sản phẩm đã tồn tại', 1;
        IF @Price IS NULL OR @Price <= 0
            THROW 50102, N'Giá bán phải lớn hơn 0', 1;
        IF @ShelfLifeHours IS NULL OR @ShelfLifeHours NOT BETWEEN 1 AND 120
            THROW 50108, N'Hạn sử dụng phải từ 1 đến 120 giờ', 1;

        DECLARE @CategoryId INT, @Seq INT, @SKU NVARCHAR(30), @NewId INT;

        BEGIN TRANSACTION;

        -- 2. Danh mục: tìm theo tên, chưa có thì tạo mới
        SET @Category = ISNULL(@Category, N'Trái cây cắt sẵn');
        SELECT @CategoryId = CategoryId
        FROM   inventory.Category WITH (UPDLOCK, HOLDLOCK)
        WHERE  CategoryName = @Category;

        IF @CategoryId IS NULL
        BEGIN
            INSERT inventory.Category (CategoryName) VALUES (@Category);
            SET @CategoryId = SCOPE_IDENTITY();
        END;

        -- 3. SKU tự sinh FV-SP-NNN (khóa bảng đọc để 2 người thêm cùng lúc không trùng SKU)
        SELECT @Seq = ISNULL(MAX(TRY_CAST(SUBSTRING(SKU, 7, 10) AS INT)), 0) + 1
        FROM   inventory.Product WITH (UPDLOCK, HOLDLOCK)
        WHERE  SKU LIKE N'FV-SP-%';

        SET @SKU = N'FV-SP-' + CASE WHEN @Seq < 1000
                                    THEN RIGHT(N'000' + CAST(@Seq AS NVARCHAR(10)), 3)
                                    ELSE CAST(@Seq AS NVARCHAR(10)) END;

        -- 4. Ghi sản phẩm (bảo quản 2–8 °C theo chuỗi lạnh của máy)
        INSERT inventory.Product (SKU, ProductName, CategoryId, UnitPrice, Unit, Description, ImageUrl,
                                  ShelfLifeHours, ShelfLifeDays, StorageTempMin, StorageTempMax, IsActive)
        VALUES (@SKU, @ProductName, @CategoryId, @Price, N'hộp', @Description, @ImageUrl,
                @ShelfLifeHours, CAST(CEILING(@ShelfLifeHours / 24.0) AS SMALLINT), 2.0, 8.0, 1);

        SET @NewId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT ProductId, SKU, ProductName, UnitPrice AS Price
        FROM   inventory.Product
        WHERE  ProductId = @NewId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================================================
-- 2. inventory.sp_UpdateProduct — Sửa thông tin sản phẩm / ngừng bán
--    Lỗi: 50103 không tồn tại · 50100 tên trống · 50101 trùng tên · 50108 hạn dùng
--         50109 ngừng bán khi sản phẩm còn gán ở ngăn máy
--    Trả về: dòng sản phẩm đầy đủ (cùng cột với vw_ProductCatalog)
--    Ghi chú: Category NULL → giữ danh mục cũ; Description / ImageUrl ghi đúng giá trị
--             gửi lên (giống fakeDb.js — giao diện luôn gửi lại ImageUrl hiện tại).
-- =============================================================================
CREATE OR ALTER PROCEDURE inventory.sp_UpdateProduct
    @ProductId      INT,
    @ProductName    NVARCHAR(100),
    @Category       NVARCHAR(50)  = NULL,
    @Description    NVARCHAR(300) = NULL,
    @ImageUrl       NVARCHAR(300) = NULL,
    @ShelfLifeHours INT,
    @IsActive       BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @ProductName = LTRIM(RTRIM(@ProductName));
        SET @Category    = NULLIF(LTRIM(RTRIM(@Category)), N'');
        SET @IsActive    = ISNULL(@IsActive, 1);

        IF NOT EXISTS (SELECT 1 FROM inventory.Product WHERE ProductId = @ProductId AND IsDeleted = 0)
            THROW 50103, N'Sản phẩm không tồn tại', 1;
        IF @ProductName IS NULL OR @ProductName = N''
            THROW 50100, N'Tên sản phẩm không được để trống', 1;
        IF EXISTS (SELECT 1 FROM inventory.Product
                   WHERE ProductName = @ProductName AND ProductId <> @ProductId AND IsDeleted = 0)
            THROW 50101, N'Tên sản phẩm đã tồn tại', 1;
        IF @ShelfLifeHours IS NULL OR @ShelfLifeHours NOT BETWEEN 1 AND 120
            THROW 50108, N'Hạn sử dụng phải từ 1 đến 120 giờ', 1;
        IF @IsActive = 0 AND EXISTS (SELECT 1 FROM inventory.Slot WHERE ProductId = @ProductId)
            THROW 50109, N'Sản phẩm đang được bán ở máy – gỡ khỏi các ô trước khi ngừng bán', 1;

        DECLARE @CategoryId INT;

        BEGIN TRANSACTION;

        IF @Category IS NOT NULL
        BEGIN
            SELECT @CategoryId = CategoryId
            FROM   inventory.Category WITH (UPDLOCK, HOLDLOCK)
            WHERE  CategoryName = @Category;

            IF @CategoryId IS NULL
            BEGIN
                INSERT inventory.Category (CategoryName) VALUES (@Category);
                SET @CategoryId = SCOPE_IDENTITY();
            END;
        END;

        UPDATE inventory.Product
        SET    ProductName    = @ProductName,
               CategoryId     = ISNULL(@CategoryId, CategoryId),
               Description    = @Description,
               ImageUrl       = @ImageUrl,
               ShelfLifeHours = @ShelfLifeHours,
               ShelfLifeDays  = CAST(CEILING(@ShelfLifeHours / 24.0) AS SMALLINT),
               IsActive       = @IsActive,
               UpdatedAt      = SYSUTCDATETIME()
        WHERE  ProductId = @ProductId;

        COMMIT TRANSACTION;

        SELECT p.ProductId, p.SKU, p.ProductName, c.CategoryName AS Category, p.Description,
               p.UnitPrice AS Price, p.ImageUrl, p.ShelfLifeHours, p.IsActive,
               p.ValidFrom AS PriceSince
        FROM   inventory.Product  p
        JOIN   inventory.Category c ON c.CategoryId = p.CategoryId
        WHERE  p.ProductId = @ProductId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================================================
-- 3. inventory.sp_UpdatePrice — Đổi giá bán (Temporal Table tự lưu giá cũ vào ProductHistory)
--    Lỗi: 50103 không tồn tại · 50102 giá ≤ 0 · 50104 giá mới trùng giá hiện tại
--    Trả về: ProductId, OldPrice, NewPrice
--    @UpdatedBy: tùy chọn, chỉ để tương thích lời gọi trong sp_RunAllTests (TV5);
--                người đổi giá đã có trong SESSION_CONTEXT('UserId') do API gửi kèm.
-- =============================================================================
CREATE OR ALTER PROCEDURE inventory.sp_UpdatePrice
    @ProductId  INT,
    @NewPrice   DECIMAL(12,2),
    @UpdatedBy  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @NewPrice IS NULL OR @NewPrice <= 0
            THROW 50102, N'Giá bán phải lớn hơn 0', 1;

        DECLARE @OldPrice DECIMAL(12,2);

        BEGIN TRANSACTION;

        -- Khóa dòng khi đọc giá cũ để 2 người đổi giá cùng lúc không ghi đè nhau
        SELECT @OldPrice = UnitPrice
        FROM   inventory.Product WITH (UPDLOCK, ROWLOCK)
        WHERE  ProductId = @ProductId AND IsDeleted = 0;

        IF @OldPrice IS NULL
            THROW 50103, N'Sản phẩm không tồn tại', 1;
        IF @OldPrice = @NewPrice
            THROW 50104, N'Giá mới trùng giá hiện tại', 1;

        UPDATE inventory.Product
        SET    UnitPrice = @NewPrice,
               UpdatedAt = SYSUTCDATETIME()
        WHERE  ProductId = @ProductId;

        COMMIT TRANSACTION;

        SELECT @ProductId AS ProductId, @OldPrice AS OldPrice, @NewPrice AS NewPrice;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================================================
-- 4. inventory.sp_AssignColumn — Đổi sản phẩm cho 1 ngăn (chỉ khi ngăn đã rỗng)
--    @ColumnId = SlotId; @ProductId = NULL → bỏ gán sản phẩm khỏi ngăn
--    Lỗi: 50105 ngăn không tồn tại (hoặc không được giao máy)
--         50107 sản phẩm không tồn tại / đã ngừng bán · 50106 ngăn còn hàng
--    Trả về: ColumnId, MachineId, ColumnNo, SlotCode, ProductId
--    TODO FV-22 (TV1): Row-Level Security giới hạn Operator chỉ thấy máy được giao —
--         khi đó ngăn của máy khác sẽ "không tồn tại" với Operator → vẫn lỗi 50105.
-- =============================================================================
CREATE OR ALTER PROCEDURE inventory.sp_AssignColumn
    @ColumnId   INT,
    @ProductId  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @ProductId IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM inventory.Product
                           WHERE ProductId = @ProductId AND IsActive = 1 AND IsDeleted = 0)
            THROW 50107, N'Sản phẩm không tồn tại hoặc đã ngừng bán', 1;

        BEGIN TRANSACTION;

        -- Khóa ngăn trong lúc kiểm tra tồn và đổi sản phẩm (tránh vừa châm hàng vừa đổi)
        IF NOT EXISTS (SELECT 1 FROM inventory.Slot WITH (UPDLOCK, ROWLOCK) WHERE SlotId = @ColumnId)
            THROW 50105, N'Cột không tồn tại hoặc bạn không được giao máy này', 1;

        IF EXISTS (SELECT 1 FROM inventory.SlotStock WHERE SlotId = @ColumnId AND Quantity > 0)
           OR EXISTS (SELECT 1 FROM inventory.Slot WHERE SlotId = @ColumnId AND CurrentStock > 0)
            THROW 50106, N'Cột đang còn hàng – cần rút hết hàng trước khi đổi sản phẩm', 1;

        UPDATE inventory.Slot
        SET    ProductId = @ProductId,
               UpdatedAt = SYSUTCDATETIME()
        WHERE  SlotId = @ColumnId;

        COMMIT TRANSACTION;

        SELECT s.SlotId AS ColumnId, s.MachineId, n.ColumnNo, s.SlotCode, s.ProductId
        FROM   inventory.Slot s
        CROSS APPLY (SELECT COUNT(*) AS ColumnNo          -- số thứ tự ngăn trong máy
                     FROM   inventory.Slot s2
                     WHERE  s2.MachineId = s.MachineId
                       AND (LEN(s2.SlotCode) < LEN(s.SlotCode)
                            OR (LEN(s2.SlotCode) = LEN(s.SlotCode) AND s2.SlotCode <= s.SlotCode))) n
        WHERE  s.SlotId = @ColumnId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================================================
-- 5. inventory.sp_AddBatch — Nhập lô hàng mới từ bếp trung tâm
--    ExpiryAt = PreparedAt + ShelfLifeHours của sản phẩm; BatchCode = 'LO' + BatchId 6 số
--    Lỗi: 50107 sản phẩm không tồn tại / đã ngừng bán · 50113 số lượng ≤ 0
--    Trả về: BatchId, BatchCode, ProductId, PreparedAt, ExpiryAt, Quantity
--    @Supplier: tên nhà cung cấp; khớp tên trong inventory.Supplier thì gán SupplierId,
--               không khớp thì ghi tên vào Note (không tự tạo NCC vì TaxCode là UNIQUE).
-- =============================================================================
CREATE OR ALTER PROCEDURE inventory.sp_AddBatch
    @ProductId  INT,
    @Quantity   INT,
    @Supplier   NVARCHAR(100) = NULL,
    @PreparedAt DATETIME2(0)  = NULL     -- NULL → thời điểm hiện tại (UTC)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @ShelfLifeHours INT, @DefaultSupplierId INT, @SupplierId INT,
                @ExpiryAt DATETIME2(0), @BatchId INT, @UserId INT;

        SELECT @ShelfLifeHours    = ShelfLifeHours,
               @DefaultSupplierId = SupplierId
        FROM   inventory.Product
        WHERE  ProductId = @ProductId AND IsActive = 1 AND IsDeleted = 0;

        IF @ShelfLifeHours IS NULL
            THROW 50107, N'Sản phẩm không tồn tại hoặc đã ngừng bán', 1;
        IF @Quantity IS NULL OR @Quantity <= 0
            THROW 50113, N'Số lượng phải lớn hơn 0', 1;

        SET @Supplier   = NULLIF(LTRIM(RTRIM(@Supplier)), N'');
        SET @PreparedAt = ISNULL(@PreparedAt, SYSUTCDATETIME());
        SET @ExpiryAt   = DATEADD(HOUR, @ShelfLifeHours, @PreparedAt);

        SELECT @SupplierId = SupplierId FROM inventory.Supplier WHERE SupplierName = @Supplier;
        IF @Supplier IS NULL SET @SupplierId = @DefaultSupplierId;

        -- Người nhập lô (do API gửi kèm qua SESSION_CONTEXT); chỉ ghi khi tài khoản tồn tại
        SET @UserId = TRY_CAST(SESSION_CONTEXT(N'UserId') AS INT);
        IF NOT EXISTS (SELECT 1 FROM auth.[User] WHERE UserId = @UserId) SET @UserId = NULL;

        BEGIN TRANSACTION;

        -- BatchCode NOT NULL + UNIQUE: ghi mã tạm, có BatchId rồi đổi sang LO000123
        INSERT inventory.StockBatch (ProductId, SupplierId, BatchCode, Quantity, UnitCost,
                                     ImportDate, ExpiryDate, PreparedAt, ExpiryAt, Note, CreatedBy)
        VALUES (@ProductId, @SupplierId,
                N'TMP' + LEFT(REPLACE(CONVERT(NVARCHAR(36), NEWID()), N'-', N''), 26),
                @Quantity, 0,
                CAST(@PreparedAt AS DATE), CAST(@ExpiryAt AS DATE), @PreparedAt, @ExpiryAt,
                CASE WHEN @Supplier IS NOT NULL AND @SupplierId IS NULL
                     THEN N'Nhà cung cấp: ' + @Supplier END,
                @UserId);

        SET @BatchId = SCOPE_IDENTITY();

        UPDATE inventory.StockBatch
        SET    BatchCode = N'LO' + RIGHT(N'000000' + CAST(@BatchId AS NVARCHAR(10)), 6)
        WHERE  BatchId = @BatchId;

        COMMIT TRANSACTION;

        SELECT BatchId, BatchCode, ProductId, PreparedAt, ExpiryAt, Quantity
        FROM   inventory.StockBatch
        WHERE  BatchId = @BatchId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================================================
-- 6. inventory.sp_Restock — Châm hàng nhiều dòng trong 1 giao dịch (TVP)
--    FV-04 (SCRUM-198). API: POST /api/inventory/restock
--    @Items (inventory.RestockItemType): ColumnId (= SlotId), BatchId, Qty 1–20
--    Lỗi (giống fakeDb.js):
--      50110 máy không tồn tại / không được giao   · 50111 danh sách rỗng
--      50112 có cột không thuộc máy này            · 50115 có lô không tồn tại
--      50114 lô không đúng sản phẩm của cột (hoặc cột chưa gán sản phẩm)
--      50116 lô đã hết hạn / còn dưới 1 giờ sử dụng · 50117 vượt sức chứa của cột
--      50118 lô không đủ số lượng để châm           · 50119 không xác định người châm
--    TẤT CẢ hoặc KHÔNG: 1 dòng sai → không dòng nào được ghi (ROLLBACK).
--    Ghi: RestockEvent (đầu phiếu), RestockItem (dòng phiếu), SlotStock (tồn theo
--         lô, LoadedAt = bây giờ → bán sau lô cũ theo FIFO), StockMovement 'IN',
--         Slot.CurrentStock, đóng cảnh báo LOW_STOCK của cột đã đủ hàng.
--    "Đã châm từ lô" = tổng StockMovement 'IN' có Reason bắt đầu bằng 'Nạp ngăn'
--         (seed 08 và procedure này đều ghi đúng tiền tố đó; hoàn hàng của TV3
--         ghi 'Hoàn hàng…' nên không bị tính trùng).
--    Trả về: RestockId, Lines, TotalQty
--    TODO FV-06/FV-22 (TV1): kiểm tra Operator chỉ châm máy được giao (bảng giao
--         máy + RLS) — khi đó máy không được giao cũng báo 50110.
-- =============================================================================
CREATE OR ALTER PROCEDURE inventory.sp_Restock
    @MachineId  INT,
    @UserId     INT = NULL,                          -- NULL → lấy từ SESSION_CONTEXT
    @Items      inventory.RestockItemType READONLY,
    @Note       NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @Now DATETIME2(0) = SYSUTCDATETIME(), @RestockId INT, @MachineCode NVARCHAR(20);

        SET @UserId = ISNULL(@UserId, TRY_CAST(SESSION_CONTEXT(N'UserId') AS INT));
        SET @Note   = NULLIF(LTRIM(RTRIM(@Note)), N'');

        -- 1. Kiểm tra đầu vào không cần khóa
        SELECT @MachineCode = MachineCode FROM inventory.Machine WHERE MachineId = @MachineId;
        IF @MachineCode IS NULL
            THROW 50110, N'Máy không tồn tại hoặc bạn không được giao máy này', 1;
        IF NOT EXISTS (SELECT 1 FROM @Items)
            THROW 50111, N'Danh sách châm hàng rỗng', 1;
        IF @UserId IS NULL
            THROW 50119, N'Không xác định được người châm hàng', 1;

        BEGIN TRANSACTION;

        -- 2. Khóa các ngăn và lô liên quan đến hết giao dịch (UPDLOCK + HOLDLOCK):
        --    2 người châm cùng ngăn / cùng lô phải chờ nhau → không vượt sức chứa,
        --    không châm quá số lượng lô.
        DECLARE @L TABLE (
            SlotId          INT          NOT NULL,
            BatchId         INT          NOT NULL,
            Qty             SMALLINT     NOT NULL,
            SlotMachineId   INT              NULL,
            SlotProductId   INT              NULL,
            BatchProductId  INT              NULL,
            BatchCode       NVARCHAR(30)     NULL,
            ExpiryAt        DATETIME2(0)     NULL,
            PRIMARY KEY (SlotId, BatchId)
        );

        INSERT @L (SlotId, BatchId, Qty, SlotMachineId, SlotProductId, BatchProductId, BatchCode, ExpiryAt)
        SELECT i.ColumnId, i.BatchId, i.Qty, s.MachineId, s.ProductId, b.ProductId, b.BatchCode, b.ExpiryAt
        FROM   @Items i
        LEFT JOIN inventory.Slot       s WITH (UPDLOCK, HOLDLOCK) ON s.SlotId  = i.ColumnId
        LEFT JOIN inventory.StockBatch b WITH (UPDLOCK, HOLDLOCK) ON b.BatchId = i.BatchId;

        -- 3. Kiểm tra từng dòng
        IF EXISTS (SELECT 1 FROM @L WHERE SlotMachineId IS NULL OR SlotMachineId <> @MachineId)
            THROW 50112, N'Có cột không thuộc máy này', 1;
        IF EXISTS (SELECT 1 FROM @L WHERE BatchProductId IS NULL)
            THROW 50115, N'Có lô hàng không tồn tại', 1;
        IF EXISTS (SELECT 1 FROM @L WHERE SlotProductId IS NULL OR BatchProductId <> SlotProductId)
            THROW 50114, N'Lô hàng không đúng sản phẩm của cột', 1;
        IF EXISTS (SELECT 1 FROM @L WHERE ExpiryAt IS NULL OR ExpiryAt <= DATEADD(HOUR, 1, @Now))
            THROW 50116, N'Không châm lô đã hết hạn hoặc còn dưới 1 giờ sử dụng', 1;

        -- Sức chứa: tồn hiện tại của ngăn + tổng số châm thêm (1 ngăn có thể nhận nhiều lô)
        IF EXISTS (SELECT 1
                   FROM  (SELECT SlotId, SUM(Qty) AS AddQty FROM @L GROUP BY SlotId) x
                   JOIN   inventory.Slot s ON s.SlotId = x.SlotId
                   WHERE  s.CurrentStock + x.AddQty > s.Capacity)
            THROW 50117, N'Vượt sức chứa của cột', 1;

        -- Số lượng lô: đã nạp vào ngăn (mọi máy) + lần này không vượt Quantity của lô
        IF EXISTS (SELECT 1
                   FROM  (SELECT BatchId, SUM(Qty) AS AddQty FROM @L GROUP BY BatchId) x
                   JOIN   inventory.StockBatch b ON b.BatchId = x.BatchId
                   OUTER APPLY (SELECT ISNULL(SUM(m.Quantity), 0) AS Loaded
                                FROM   inventory.StockMovement m
                                WHERE  m.BatchId = x.BatchId
                                  AND  m.MovementType = N'IN'
                                  AND  m.Reason LIKE N'Nạp ngăn%') u
                   WHERE  u.Loaded + x.AddQty > b.Quantity)
            THROW 50118, N'Lô hàng không đủ số lượng để châm', 1;

        -- 4. Ghi phiếu châm hàng
        INSERT inventory.RestockEvent (MachineId, UserId, RestockedAt, Note)
        VALUES (@MachineId, @UserId, @Now, @Note);
        SET @RestockId = SCOPE_IDENTITY();

        INSERT inventory.RestockItem (RestockId, SlotId, BatchId, Qty)
        SELECT @RestockId, SlotId, BatchId, Qty FROM @L;

        -- 5. Tồn theo lô + lịch sử nhập ngăn + tồn tổng của ngăn
        INSERT inventory.SlotStock (SlotId, BatchId, Quantity, LoadedAt)
        SELECT SlotId, BatchId, Qty, @Now FROM @L;

        INSERT inventory.StockMovement (SlotId, BatchId, MovementType, Quantity, Reason, CreatedBy, CreatedAt)
        SELECT SlotId, BatchId, N'IN', Qty,
               N'Nạp ngăn từ lô ' + BatchCode + N' (phiếu châm #' + CAST(@RestockId AS NVARCHAR(10)) + N')',
               CASE WHEN EXISTS (SELECT 1 FROM auth.[User] WHERE UserId = @UserId) THEN @UserId END,
               @Now
        FROM   @L;

        UPDATE s
        SET    CurrentStock = s.CurrentStock + x.AddQty,
               UpdatedAt    = @Now
        FROM   inventory.Slot s
        JOIN  (SELECT SlotId, SUM(Qty) AS AddQty FROM @L GROUP BY SlotId) x ON x.SlotId = s.SlotId;

        -- 6. Đóng cảnh báo "sắp hết hàng" của cột đã có trên 20 % sức chứa (hàng còn hạn)
        IF OBJECT_ID(N'iot.Alerts', N'U') IS NOT NULL
            UPDATE a
            SET    ResolvedAt = @Now
            FROM   iot.Alerts a
            JOIN  (SELECT s.SlotId
                   FROM   inventory.Slot s
                   JOIN  (SELECT DISTINCT SlotId FROM @L) l ON l.SlotId = s.SlotId
                   CROSS APPLY (SELECT ISNULL(SUM(ss.Quantity), 0) AS Remaining
                                FROM   inventory.SlotStock ss
                                JOIN   inventory.StockBatch b ON b.BatchId = ss.BatchId
                                WHERE  ss.SlotId = s.SlotId AND b.ExpiryAt > @Now) r
                   WHERE  r.Remaining * 5 > s.Capacity) ok
              ON   a.RefKey = N'COL:' + CAST(ok.SlotId AS NVARCHAR(10))
            WHERE  a.AlertType = N'LOW_STOCK' AND a.ResolvedAt IS NULL;

        COMMIT TRANSACTION;

        SELECT @RestockId AS RestockId, COUNT(*) AS Lines, SUM(CAST(Qty AS INT)) AS TotalQty
        FROM   @L;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================================================
-- 7. inventory.sp_RemoveExpired — Rút hàng hết hạn khỏi ngăn
--    FV-04 (SCRUM-198). API: POST /api/inventory/remove-expired; job mỗi giờ (FV-28)
--    @MachineId NULL → mọi máy.
--    Mỗi dòng SlotStock còn hàng của lô có ExpiryAt <= bây giờ:
--      Quantity = 0, Slot.CurrentStock giảm tương ứng, StockMovement 'OUT'
--      (lý do 'Rút hàng hết hạn'), 1 cảnh báo EXPIRY (HIGH) cho mỗi cột bị rút.
--    Không lỗi khi không có gì để rút (trả 0, 0).
--    Trả về: RemovedLines (số dòng tồn theo lô bị rút), RemovedQty (số hộp)
--    Cảnh báo ghi iot.Alerts (TV4); máy bên iot tìm theo Serial = MachineCode
--    (QĐ-1 chưa chốt bảng máy nên không dùng thẳng MachineId).
-- =============================================================================
CREATE OR ALTER PROCEDURE inventory.sp_RemoveExpired
    @MachineId  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @Now DATETIME2(0) = SYSUTCDATETIME(),
                @UserId INT = TRY_CAST(SESSION_CONTEXT(N'UserId') AS INT);
        IF NOT EXISTS (SELECT 1 FROM auth.[User] WHERE UserId = @UserId) SET @UserId = NULL;

        DECLARE @R TABLE (
            StockId  BIGINT   NOT NULL PRIMARY KEY,
            SlotId   INT      NOT NULL,
            BatchId  INT      NOT NULL,
            Qty      SMALLINT NOT NULL
        );

        BEGIN TRANSACTION;

        -- 1. Rút: đưa tồn theo lô về 0, ghi lại dòng đã rút
        UPDATE ss
        SET    Quantity = 0
        OUTPUT deleted.StockId, deleted.SlotId, deleted.BatchId, deleted.Quantity INTO @R
        FROM   inventory.SlotStock ss
        JOIN   inventory.StockBatch b ON b.BatchId = ss.BatchId
        JOIN   inventory.Slot s       ON s.SlotId  = ss.SlotId
        WHERE  ss.Quantity > 0
          AND  b.ExpiryAt <= @Now
          AND (@MachineId IS NULL OR s.MachineId = @MachineId);

        IF EXISTS (SELECT 1 FROM @R)
        BEGIN
            -- 2. Tồn tổng của ngăn (không để âm nếu dữ liệu cũ lệch)
            UPDATE s
            SET    CurrentStock = CASE WHEN s.CurrentStock >= x.Qty THEN s.CurrentStock - x.Qty ELSE 0 END,
                   UpdatedAt    = @Now
            FROM   inventory.Slot s
            JOIN  (SELECT SlotId, SUM(Qty) AS Qty FROM @R GROUP BY SlotId) x ON x.SlotId = s.SlotId;

            -- 3. Lịch sử xuất ngăn
            INSERT inventory.StockMovement (SlotId, BatchId, MovementType, Quantity, Reason, CreatedBy, CreatedAt)
            SELECT r.SlotId, r.BatchId, N'OUT', r.Qty,
                   N'Rút hàng hết hạn – lô ' + b.BatchCode, @UserId, @Now
            FROM   @R r
            JOIN   inventory.StockBatch b ON b.BatchId = r.BatchId;

            -- 4. Cảnh báo cho nhân viên vận hành: mỗi cột bị rút 1 cảnh báo
            IF OBJECT_ID(N'iot.Alerts', N'U') IS NOT NULL AND OBJECT_ID(N'iot.Machines', N'U') IS NOT NULL
                INSERT iot.Alerts (MachineId, AlertType, Severity, Message, RefKey, CreatedAt)
                SELECT im.MachineId, N'EXPIRY', N'HIGH',
                       N'Đã rút ' + CAST(x.Qty AS NVARCHAR(10)) + N' hộp hết hạn ở cột '
                         + CAST(n.ColumnNo AS NVARCHAR(10)) + N' – cần châm lại',
                       N'EXP:' + CAST(x.SlotId AS NVARCHAR(10)), @Now
                FROM  (SELECT SlotId, SUM(Qty) AS Qty FROM @R GROUP BY SlotId) x
                JOIN   inventory.Slot s    ON s.SlotId     = x.SlotId
                JOIN   inventory.Machine m ON m.MachineId  = s.MachineId
                JOIN   iot.Machines im     ON im.Serial    = m.MachineCode
                CROSS APPLY (SELECT COUNT(*) AS ColumnNo          -- số thứ tự ngăn trong máy
                             FROM   inventory.Slot s2
                             WHERE  s2.MachineId = s.MachineId
                               AND (LEN(s2.SlotCode) < LEN(s.SlotCode)
                                    OR (LEN(s2.SlotCode) = LEN(s.SlotCode) AND s2.SlotCode <= s.SlotCode))) n;
        END;

        COMMIT TRANSACTION;

        SELECT COUNT(*) AS RemovedLines, ISNULL(SUM(CAST(Qty AS INT)), 0) AS RemovedQty
        FROM   @R;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT N'[11-inv] Đã tạo/cập nhật 7 procedure: sp_AddProduct, sp_UpdateProduct, sp_UpdatePrice, sp_AssignColumn, sp_AddBatch, sp_Restock, sp_RemoveExpired.';
GO
