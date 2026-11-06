-- =============================================================================
-- FILE        : tests/tests_inventory.sql
-- PROJECT     : FreshVend
-- DESCRIPTION : TV2 — Kiểm thử module inventory (chạy trong SSMS)
--               PHẦN 1 — Cấu trúc bảng (FV-02, SCRUM-196)        T1–T11
--               PHẦN 2 — Dữ liệu mẫu 08_seed_inventory.sql        T12–T18
--               PHẦN 3 — 5 procedure FV-03 (11_procs_inventory)   T19–T33
--               (sp_Restock, sp_RemoveExpired, view… nối tiếp ở các task sau)
-- CÁCH CHẠY   : Chạy SAU 02_tables_inventory.sql, 08_seed_inventory.sql và
--               11_procs_inventory.sql. Phần 3 tự dọn dữ liệu test (tên '__TEST__…').
--               Phần 1 sửa dữ liệu trong 1 transaction rồi ROLLBACK; Phần 2 chỉ đọc
--               → không làm bẩn CSDL. Toàn file là 1 batch (không thêm GO ở giữa).
--               T16 (lô sắp hết hạn) tính theo giờ thật: chạy trong vòng 4 giờ sau
--               khi nạp seed; để lâu hơn lô đó hết hạn thật nên T16 sẽ báo 0.
-- KẾT QUẢ     : Bảng kết quả cuối file: mỗi dòng 1 test, cột Passed = 1 là đạt.
-- =============================================================================

USE FreshVendDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT OFF;   -- lỗi CHECK chỉ hủy câu lệnh, không hủy cả transaction test

-- Biến bảng (không bị ROLLBACK) — toàn bộ file là 1 batch, KHÔNG thêm GO ở giữa.
DECLARE @Result TABLE (
    TestNo   INT            NOT NULL,
    TestCase NVARCHAR(200)  NOT NULL,
    Expected NVARCHAR(100)  NOT NULL,
    Actual   NVARCHAR(100)  NULL,
    Passed   BIT            NOT NULL
);

-- =============================================================================
-- PHẦN 1 — CẤU TRÚC BẢNG (FV-02)
-- =============================================================================

-- T1–T6: đối tượng đã tồn tại
INSERT @Result
SELECT 1, N'Có cột Product.ShelfLifeHours', N'1',
       CAST(CASE WHEN COL_LENGTH(N'inventory.Product', N'ShelfLifeHours') IS NULL THEN 0 ELSE 1 END AS NVARCHAR(10)),
       CASE WHEN COL_LENGTH(N'inventory.Product', N'ShelfLifeHours') IS NULL THEN 0 ELSE 1 END
UNION ALL
SELECT 2, N'Có cột StockBatch.PreparedAt và ExpiryAt', N'1',
       CAST(CASE WHEN COL_LENGTH(N'inventory.StockBatch', N'PreparedAt') IS NOT NULL
                  AND COL_LENGTH(N'inventory.StockBatch', N'ExpiryAt') IS NOT NULL THEN 1 ELSE 0 END AS NVARCHAR(10)),
       CASE WHEN COL_LENGTH(N'inventory.StockBatch', N'PreparedAt') IS NOT NULL
             AND COL_LENGTH(N'inventory.StockBatch', N'ExpiryAt') IS NOT NULL THEN 1 ELSE 0 END
UNION ALL
SELECT 3, N'Có bảng SlotStock, RestockEvent, RestockItem', N'3',
       CAST((SELECT COUNT(*) FROM sys.tables
             WHERE object_id IN (OBJECT_ID(N'inventory.SlotStock'), OBJECT_ID(N'inventory.RestockEvent'),
                                 OBJECT_ID(N'inventory.RestockItem'))) AS NVARCHAR(10)),
       CASE WHEN (SELECT COUNT(*) FROM sys.tables
                  WHERE object_id IN (OBJECT_ID(N'inventory.SlotStock'), OBJECT_ID(N'inventory.RestockEvent'),
                                      OBJECT_ID(N'inventory.RestockItem'))) = 3 THEN 1 ELSE 0 END
UNION ALL
SELECT 4, N'Kiểu TVP RestockItemType có đúng 3 cột ColumnId, BatchId, Qty', N'3',
       CAST((SELECT COUNT(*) FROM sys.columns c
             JOIN sys.table_types tt ON tt.type_table_object_id = c.object_id
             WHERE tt.user_type_id = TYPE_ID(N'inventory.RestockItemType')
               AND c.name IN (N'ColumnId', N'BatchId', N'Qty')) AS NVARCHAR(10)),
       CASE WHEN (SELECT COUNT(*) FROM sys.columns c
                  JOIN sys.table_types tt ON tt.type_table_object_id = c.object_id
                  WHERE tt.user_type_id = TYPE_ID(N'inventory.RestockItemType')
                    AND c.name IN (N'ColumnId', N'BatchId', N'Qty')) = 3 THEN 1 ELSE 0 END
UNION ALL
SELECT 5, N'Product là Temporal Table (temporal_type = 2)', N'2',
       CAST((SELECT temporal_type FROM sys.tables WHERE object_id = OBJECT_ID(N'inventory.Product')) AS NVARCHAR(10)),
       CASE WHEN (SELECT temporal_type FROM sys.tables WHERE object_id = OBJECT_ID(N'inventory.Product')) = 2 THEN 1 ELSE 0 END
UNION ALL
SELECT 6, N'Cột cũ TV3/TV5 đang dùng vẫn còn (UnitPrice, CurrentStock, ExpiryDate)', N'3',
       CAST(  CASE WHEN COL_LENGTH(N'inventory.Product',    N'UnitPrice')    IS NULL THEN 0 ELSE 1 END
            + CASE WHEN COL_LENGTH(N'inventory.Slot',       N'CurrentStock') IS NULL THEN 0 ELSE 1 END
            + CASE WHEN COL_LENGTH(N'inventory.StockBatch', N'ExpiryDate')   IS NULL THEN 0 ELSE 1 END AS NVARCHAR(10)),
       CASE WHEN COL_LENGTH(N'inventory.Product', N'UnitPrice') IS NOT NULL
             AND COL_LENGTH(N'inventory.Slot', N'CurrentStock') IS NOT NULL
             AND COL_LENGTH(N'inventory.StockBatch', N'ExpiryDate') IS NOT NULL THEN 1 ELSE 0 END;

-- T7–T11: hành vi — chạy trên dữ liệu tạm trong transaction
BEGIN TRANSACTION;

DECLARE @cat INT, @prod INT, @mach INT, @slot INT, @batch INT, @restock INT,
        @before INT, @after INT, @err INT;

INSERT inventory.Category (CategoryName) VALUES (N'__TEST_CAT__');
SET @cat = SCOPE_IDENTITY();

INSERT inventory.Product (SKU, ProductName, CategoryId, UnitPrice, Unit, ShelfLifeHours)
VALUES (N'__TEST_SKU__', N'Sản phẩm test', @cat, 30000, N'hộp', 24);
SET @prod = SCOPE_IDENTITY();

-- T7: đổi giá → Temporal ghi thêm 1 dòng vào ProductHistory
SELECT @before = COUNT(*) FROM inventory.ProductHistory WHERE ProductId = @prod;
UPDATE inventory.Product SET UnitPrice = UnitPrice + 1000 WHERE ProductId = @prod;
SELECT @after  = COUNT(*) FROM inventory.ProductHistory WHERE ProductId = @prod;
INSERT @Result VALUES (7, N'Đổi giá → ProductHistory tăng 1 dòng', N'+1',
       N'+' + CAST(@after - @before AS NVARCHAR(10)), CASE WHEN @after = @before + 1 THEN 1 ELSE 0 END);

-- T8: ShelfLifeHours = 0 → lỗi 547 (vi phạm CHECK)
SET @err = 0;
BEGIN TRY
    UPDATE inventory.Product SET ShelfLifeHours = 0 WHERE ProductId = @prod;
END TRY
BEGIN CATCH
    SET @err = ERROR_NUMBER();
END CATCH;
INSERT @Result VALUES (8, N'ShelfLifeHours = 0 bị chặn', N'547', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 547 THEN 1 ELSE 0 END);

-- T9: lô có hạn dùng trước giờ làm → lỗi 547
SET @err = 0;
BEGIN TRY
    INSERT inventory.StockBatch (ProductId, BatchCode, Quantity, UnitCost, ImportDate, PreparedAt, ExpiryAt)
    VALUES (@prod, N'__TEST_BAD__', 10, 15000, CAST(SYSUTCDATETIME() AS DATE),
            SYSUTCDATETIME(), DATEADD(HOUR, -1, SYSUTCDATETIME()));
END TRY
BEGIN CATCH
    SET @err = ERROR_NUMBER();
END CATCH;
INSERT @Result VALUES (9, N'Lô có ExpiryAt <= PreparedAt bị chặn', N'547', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 547 THEN 1 ELSE 0 END);

-- Dữ liệu hợp lệ cho các test còn lại
INSERT inventory.StockBatch (ProductId, BatchCode, Quantity, UnitCost, ImportDate, PreparedAt, ExpiryAt)
VALUES (@prod, N'__TEST_LOT__', 10, 15000, CAST(SYSUTCDATETIME() AS DATE),
        SYSUTCDATETIME(), DATEADD(HOUR, 24, SYSUTCDATETIME()));
SET @batch = SCOPE_IDENTITY();

SELECT TOP (1) @mach = MachineId FROM inventory.Machine ORDER BY MachineId;
IF @mach IS NULL
BEGIN
    -- CSDL trống: tạo tạm 1 máy (chỉ khi inventory.Machine còn là bảng)
    IF OBJECT_ID(N'inventory.Machine', N'U') IS NOT NULL
    BEGIN
        INSERT inventory.Machine (MachineCode, MachineName) VALUES (N'__TEST_M__', N'Máy test');
        SET @mach = SCOPE_IDENTITY();
    END
END;

IF @mach IS NOT NULL
BEGIN
    INSERT inventory.Slot (MachineId, SlotCode, ProductId, Capacity, CurrentStock)
    VALUES (@mach, N'Z9', @prod, 8, 0);
    SET @slot = SCOPE_IDENTITY();

    DECLARE @uid INT = (SELECT TOP (1) UserId FROM auth.[User] ORDER BY UserId);
    INSERT inventory.RestockEvent (MachineId, UserId, Note) VALUES (@mach, ISNULL(@uid, 1), N'test');
    SET @restock = SCOPE_IDENTITY();

    -- T10: dòng phiếu châm Qty = 0 → lỗi 547
    SET @err = 0;
    BEGIN TRY
        INSERT inventory.RestockItem (RestockId, SlotId, BatchId, Qty) VALUES (@restock, @slot, @batch, 0);
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();
    END CATCH;
    INSERT @Result VALUES (10, N'Dòng phiếu châm Qty = 0 bị chặn', N'547', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 547 THEN 1 ELSE 0 END);
END
ELSE
    INSERT @Result VALUES (10, N'Dòng phiếu châm Qty = 0 bị chặn (bỏ qua: chưa có bảng máy)', N'547', N'SKIP', 0);

-- T11: TVP không nhận 2 dòng trùng cặp ngăn + lô → lỗi 2627
DECLARE @items inventory.RestockItemType;
SET @err = 0;
BEGIN TRY
    INSERT @items (ColumnId, BatchId, Qty) VALUES (1, 1, 2), (1, 1, 3);
END TRY
BEGIN CATCH
    SET @err = ERROR_NUMBER();
END CATCH;
INSERT @Result VALUES (11, N'TVP chặn trùng cặp ColumnId + BatchId', N'2627', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 2627 THEN 1 ELSE 0 END);

ROLLBACK TRANSACTION;   -- trả CSDL về như trước khi test

-- =============================================================================
-- PHẦN 2 — DỮ LIỆU MẪU (08_seed_inventory.sql) — chỉ đọc, không sửa dữ liệu
-- =============================================================================
DECLARE @n INT, @utc DATETIME2(0) = SYSUTCDATETIME();

SELECT @n = COUNT(*) FROM inventory.Product WHERE SKU LIKE N'FV-SP-%';
INSERT @Result VALUES (12, N'Có đủ 36 sản phẩm FV-SP-001…036', N'36', CAST(@n AS NVARCHAR(10)), CASE WHEN @n = 36 THEN 1 ELSE 0 END);

SELECT @n = COUNT(*) FROM inventory.Slot sl JOIN inventory.Machine m ON m.MachineId = sl.MachineId
WHERE m.MachineCode IN (N'VM-BK-01', N'VM-BK-02', N'VM-VT-01', N'VM-VT-02', N'VM-CM-01')
  AND sl.SlotCode LIKE N'[A-C][1-4]';
INSERT @Result VALUES (13, N'5 máy × 12 ngăn A1–C4', N'60', CAST(@n AS NVARCHAR(10)), CASE WHEN @n = 60 THEN 1 ELSE 0 END);

-- Mọi ngăn đã có tồn theo lô: tổng SlotStock phải bằng Slot.CurrentStock
SELECT @n = COUNT(*) FROM inventory.Slot sl
JOIN (SELECT SlotId, SUM(Quantity) AS Qty FROM inventory.SlotStock GROUP BY SlotId) x ON x.SlotId = sl.SlotId
WHERE x.Qty <> sl.CurrentStock;
INSERT @Result VALUES (14, N'Tồn theo lô khớp Slot.CurrentStock (số ngăn lệch)', N'0', CAST(@n AS NVARCHAR(10)), CASE WHEN @n = 0 THEN 1 ELSE 0 END);

SELECT @n = COUNT(*) FROM inventory.Slot WHERE CurrentStock > Capacity;
INSERT @Result VALUES (15, N'Không ngăn nào vượt sức chứa', N'0', CAST(@n AS NVARCHAR(10)), CASE WHEN @n = 0 THEN 1 ELSE 0 END);

SELECT @n = COUNT(*) FROM inventory.SlotStock ss JOIN inventory.StockBatch b ON b.BatchId = ss.BatchId
WHERE ss.Quantity > 0 AND b.ExpiryAt > @utc AND b.ExpiryAt <= DATEADD(HOUR, 6, @utc);
INSERT @Result VALUES (16, N'Có hàng sắp hết hạn trong 6 giờ (demo cảnh báo)', N'>0', CAST(@n AS NVARCHAR(10)), CASE WHEN @n > 0 THEN 1 ELSE 0 END);

SELECT @n = COUNT(*) FROM inventory.SlotStock ss JOIN inventory.StockBatch b ON b.BatchId = ss.BatchId
WHERE ss.Quantity > 0 AND b.ExpiryAt <= @utc;
INSERT @Result VALUES (17, N'Có lô đã hết hạn còn trong ngăn (demo rút hàng)', N'>0', CAST(@n AS NVARCHAR(10)), CASE WHEN @n > 0 THEN 1 ELSE 0 END);

-- FIFO: trong 1 ngăn, lô nạp trước phải hết hạn trước (không có cặp ngược)
SELECT @n = COUNT(*) FROM inventory.SlotStock a
JOIN inventory.SlotStock c ON c.SlotId = a.SlotId AND c.LoadedAt > a.LoadedAt
JOIN inventory.StockBatch ba ON ba.BatchId = a.BatchId
JOIN inventory.StockBatch bc ON bc.BatchId = c.BatchId
WHERE ba.ExpiryAt > bc.ExpiryAt;
INSERT @Result VALUES (18, N'FIFO: lô nạp trước hết hạn trước (số cặp sai)', N'0', CAST(@n AS NVARCHAR(10)), CASE WHEN @n = 0 THEN 1 ELSE 0 END);

-- =============================================================================
-- PHẦN 3 — 5 PROCEDURE FV-03 (11_procs_inventory.sql): mỗi proc 1 ca đúng + 2 ca sai
--   Gọi EXEC trực tiếp (không bọc transaction ngoài — procedure tự quản lý giao dịch).
--   Dữ liệu test có tên bắt đầu '__TEST__' và được dọn ở cuối phần này.
-- =============================================================================
DECLARE @tp INT, @tName NVARCHAR(100) = N'__TEST__ Bưởi da xanh', @busyProd INT,
        @emptySlot INT, @emptySlotOldProd INT, @stockSlot INT, @tBatch INT,
        @v1 NVARCHAR(100), @ok BIT;

-- Dọn dữ liệu test còn sót nếu lần chạy trước bị dừng giữa chừng
DELETE b FROM inventory.StockBatch b JOIN inventory.Product p ON p.ProductId = b.ProductId
WHERE p.ProductName LIKE N'[_][_]TEST[_][_]%'
  AND NOT EXISTS (SELECT 1 FROM inventory.SlotStock ss WHERE ss.BatchId = b.BatchId);
UPDATE inventory.Slot SET ProductId = NULL
WHERE ProductId IN (SELECT ProductId FROM inventory.Product WHERE ProductName LIKE N'[_][_]TEST[_][_]%')
  AND CurrentStock = 0;
DELETE p FROM inventory.Product p
WHERE p.ProductName LIKE N'[_][_]TEST[_][_]%'
  AND NOT EXISTS (SELECT 1 FROM inventory.Slot s WHERE s.ProductId = p.ProductId)
  AND NOT EXISTS (SELECT 1 FROM inventory.StockBatch b WHERE b.ProductId = p.ProductId);

-- ---------- sp_AddProduct ----------
SET @err = 0;
BEGIN TRY
    EXEC inventory.sp_AddProduct @ProductName = @tName, @Price = 42000, @ShelfLifeHours = 36,
                                 @Category = N'Trái cây cắt sẵn', @Description = N'Hộp 300 g';
END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
SELECT @tp = ProductId FROM inventory.Product WHERE ProductName = @tName;
SET @ok = CASE WHEN @err = 0 AND @tp IS NOT NULL
                AND EXISTS (SELECT 1 FROM inventory.Product WHERE ProductId = @tp AND UnitPrice = 42000
                            AND ShelfLifeHours = 36 AND SKU LIKE N'FV-SP-%') THEN 1 ELSE 0 END;
INSERT @Result VALUES (19, N'sp_AddProduct đúng: tạo sản phẩm, SKU FV-SP-…, giá 42000', N'OK',
       CASE WHEN @ok = 1 THEN N'OK' ELSE N'lỗi ' + CAST(@err AS NVARCHAR(10)) END, @ok);

SET @err = 0;
BEGIN TRY EXEC inventory.sp_AddProduct @ProductName = N'__test__ BƯỞI DA XANH', @Price = 42000, @ShelfLifeHours = 36; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
INSERT @Result VALUES (20, N'sp_AddProduct trùng tên (khác hoa/thường)', N'50101', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 50101 THEN 1 ELSE 0 END);

SET @err = 0;
BEGIN TRY EXEC inventory.sp_AddProduct @ProductName = N'__TEST__ Táo', @Price = 0, @ShelfLifeHours = 24; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
INSERT @Result VALUES (21, N'sp_AddProduct giá = 0', N'50102', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 50102 THEN 1 ELSE 0 END);

-- ---------- sp_UpdateProduct ----------
SET @err = 0;
BEGIN TRY
    EXEC inventory.sp_UpdateProduct @ProductId = @tp, @ProductName = N'__TEST__ Bưởi da xanh (hộp lớn)',
         @Category = N'Trái cây cắt sẵn', @Description = N'Hộp 400 g', @ImageUrl = NULL,
         @ShelfLifeHours = 48, @IsActive = 1;
END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
SET @ok = CASE WHEN @err = 0 AND EXISTS (SELECT 1 FROM inventory.Product WHERE ProductId = @tp
                AND ProductName = N'__TEST__ Bưởi da xanh (hộp lớn)' AND ShelfLifeHours = 48) THEN 1 ELSE 0 END;
INSERT @Result VALUES (22, N'sp_UpdateProduct đúng: đổi tên + hạn dùng', N'OK',
       CASE WHEN @ok = 1 THEN N'OK' ELSE N'lỗi ' + CAST(@err AS NVARCHAR(10)) END, @ok);

SET @err = 0;
BEGIN TRY EXEC inventory.sp_UpdateProduct @ProductId = -1, @ProductName = N'Bất kỳ', @ShelfLifeHours = 24; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
INSERT @Result VALUES (23, N'sp_UpdateProduct sản phẩm không tồn tại', N'50103', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 50103 THEN 1 ELSE 0 END);

-- Ngừng bán 1 sản phẩm đang được gán ở ngăn máy → 50109 (lỗi xảy ra trước khi sửa dữ liệu)
SELECT TOP (1) @busyProd = p.ProductId, @v1 = p.ProductName
FROM inventory.Product p WHERE EXISTS (SELECT 1 FROM inventory.Slot s WHERE s.ProductId = p.ProductId)
ORDER BY p.ProductId;
SET @err = 0;
BEGIN TRY EXEC inventory.sp_UpdateProduct @ProductId = @busyProd, @ProductName = @v1, @ShelfLifeHours = 24, @IsActive = 0; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
INSERT @Result VALUES (24, N'sp_UpdateProduct ngừng bán khi còn gán ở ngăn', N'50109', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 50109 THEN 1 ELSE 0 END);

-- ---------- sp_UpdatePrice ----------
SET @before = (SELECT COUNT(*) FROM inventory.ProductHistory WHERE ProductId = @tp);
SET @err = 0;
BEGIN TRY EXEC inventory.sp_UpdatePrice @ProductId = @tp, @NewPrice = 45000; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
SET @after = (SELECT COUNT(*) FROM inventory.ProductHistory WHERE ProductId = @tp);
SET @ok = CASE WHEN @err = 0 AND @after = @before + 1
                AND EXISTS (SELECT 1 FROM inventory.Product WHERE ProductId = @tp AND UnitPrice = 45000) THEN 1 ELSE 0 END;
INSERT @Result VALUES (25, N'sp_UpdatePrice đúng: 42000 → 45000, lịch sử +1', N'OK',
       CASE WHEN @ok = 1 THEN N'OK' ELSE N'lỗi ' + CAST(@err AS NVARCHAR(10)) END, @ok);

SET @err = 0;
BEGIN TRY EXEC inventory.sp_UpdatePrice @ProductId = @tp, @NewPrice = 45000; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
INSERT @Result VALUES (26, N'sp_UpdatePrice giá mới trùng giá hiện tại', N'50104', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 50104 THEN 1 ELSE 0 END);

SET @err = 0;
BEGIN TRY EXEC inventory.sp_UpdatePrice @ProductId = -1, @NewPrice = 30000; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
INSERT @Result VALUES (27, N'sp_UpdatePrice sản phẩm không tồn tại', N'50103', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 50103 THEN 1 ELSE 0 END);

-- ---------- sp_AssignColumn ----------
-- Ngăn rỗng (không còn hàng) để gán thử, ghi nhớ sản phẩm cũ để trả lại
SELECT TOP (1) @emptySlot = s.SlotId, @emptySlotOldProd = s.ProductId
FROM inventory.Slot s
WHERE s.CurrentStock = 0
  AND NOT EXISTS (SELECT 1 FROM inventory.SlotStock ss WHERE ss.SlotId = s.SlotId AND ss.Quantity > 0)
ORDER BY s.SlotId;
SET @err = 0;
BEGIN TRY EXEC inventory.sp_AssignColumn @ColumnId = @emptySlot, @ProductId = @tp; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
SET @ok = CASE WHEN @err = 0 AND EXISTS (SELECT 1 FROM inventory.Slot WHERE SlotId = @emptySlot AND ProductId = @tp) THEN 1 ELSE 0 END;
INSERT @Result VALUES (28, N'sp_AssignColumn đúng: gán sản phẩm vào ngăn rỗng', N'OK',
       CASE WHEN @ok = 1 THEN N'OK' WHEN @emptySlot IS NULL THEN N'không có ngăn rỗng' ELSE N'lỗi ' + CAST(@err AS NVARCHAR(10)) END, @ok);

SET @err = 0;
BEGIN TRY EXEC inventory.sp_AssignColumn @ColumnId = -1, @ProductId = @tp; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
INSERT @Result VALUES (29, N'sp_AssignColumn ngăn không tồn tại', N'50105', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 50105 THEN 1 ELSE 0 END);

SELECT TOP (1) @stockSlot = SlotId FROM inventory.SlotStock WHERE Quantity > 0 ORDER BY SlotId;
SET @err = 0;
BEGIN TRY EXEC inventory.sp_AssignColumn @ColumnId = @stockSlot, @ProductId = @tp; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
INSERT @Result VALUES (30, N'sp_AssignColumn ngăn còn hàng', N'50106', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 50106 THEN 1 ELSE 0 END);

-- ---------- sp_AddBatch ----------
SET @err = 0;
BEGIN TRY EXEC inventory.sp_AddBatch @ProductId = @tp, @Quantity = 20, @Supplier = N'Bếp trung tâm FreshVend Quận 7'; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
SELECT TOP (1) @tBatch = BatchId FROM inventory.StockBatch WHERE ProductId = @tp ORDER BY BatchId DESC;
SET @ok = CASE WHEN @err = 0 AND EXISTS (SELECT 1 FROM inventory.StockBatch WHERE BatchId = @tBatch
                AND Quantity = 20 AND BatchCode = N'LO' + RIGHT(N'000000' + CAST(@tBatch AS NVARCHAR(10)), 6)
                AND ExpiryAt = DATEADD(HOUR, 48, PreparedAt)) THEN 1 ELSE 0 END;
INSERT @Result VALUES (31, N'sp_AddBatch đúng: mã LOxxxxxx, hạn = giờ làm + 48 giờ', N'OK',
       CASE WHEN @ok = 1 THEN N'OK' ELSE N'lỗi ' + CAST(@err AS NVARCHAR(10)) END, @ok);

SET @err = 0;
BEGIN TRY EXEC inventory.sp_AddBatch @ProductId = -1, @Quantity = 10; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
INSERT @Result VALUES (32, N'sp_AddBatch sản phẩm không tồn tại', N'50107', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 50107 THEN 1 ELSE 0 END);

SET @err = 0;
BEGIN TRY EXEC inventory.sp_AddBatch @ProductId = @tp, @Quantity = 0; END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
INSERT @Result VALUES (33, N'sp_AddBatch số lượng = 0', N'50113', CAST(@err AS NVARCHAR(10)), CASE WHEN @err = 50113 THEN 1 ELSE 0 END);

-- ---------- Dọn dữ liệu test của phần 3 ----------
DELETE FROM inventory.StockBatch WHERE ProductId = @tp;
IF @emptySlot IS NOT NULL
    UPDATE inventory.Slot SET ProductId = @emptySlotOldProd WHERE SlotId = @emptySlot AND ProductId = @tp;
DELETE FROM inventory.Product WHERE ProductId = @tp;

-- =============================================================================
-- KẾT QUẢ
-- =============================================================================
SELECT TestNo, TestCase, Expected, Actual, Passed FROM @Result ORDER BY TestNo;

DECLARE @pass INT = (SELECT COUNT(*) FROM @Result WHERE Passed = 1),
        @total INT = (SELECT COUNT(*) FROM @Result);
PRINT N'[tests_inventory] ' + CAST(@pass AS NVARCHAR(10)) + N'/' + CAST(@total AS NVARCHAR(10)) + N' PASS';
GO
