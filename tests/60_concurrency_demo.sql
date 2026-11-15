-- =============================================================================
-- FILE        : 60_concurrency_demo.sql
-- PROJECT     : FreshVend — TV3 (sales)
-- DESCRIPTION : Demo bắt buộc — 2 phiên SSMS mua cùng lúc, UPDLOCK vs không UPDLOCK
--               + Giải thích 4 mức cô lập & deadlock graph
-- RUN ORDER   : Sau 02_tables_*.sql, 03_foreign_keys.sql, 12_procs_sales.sql
-- NOTE        : Chạy phần SETUP một lần; mở 2 cửa sổ SSMS cho phần DEMO THỦ CÔNG
-- =============================================================================

USE FreshVendDB;
GO

/* =============================================================================
   A. GIẢI THÍCH — 4 MỨC CÔ LẬP (SQL Server, mặc định READ COMMITTED)

   1) READ UNCOMMITTED
      - Cho phép đọc dữ liệu transaction chưa COMMIT (dirty read).
      - Không khuyến nghị; chỉ dùng NOLOCK khi chấp nhận sai số.

   2) READ COMMITTED (mặc định FreshVend / sp_CreateOrder)
      - Chỉ đọc bản ghi đã commit; vẫn có thể lost update nếu không khóa khi đọc-ghi.
      - UPDLOCK + ROWLOCK trên Slot / SlotStock: phiên sau phải CHỜ phiên trước commit
        rồi mới thấy tồn mới → tránh 2 đơn cùng giữ 1 hộp.

   3) REPEATABLE READ
      - Khóa đọc đến hết transaction → không đọc lại thấy giá trị khác; vẫn có thể
        phantom row nếu không khóa phạm vi.

   4) SERIALIZABLE
      - Khóa phạm vi (range); mạnh nhất, dễ deadlock / chậm nhất.

   Deadlock graph (Extended Events hoặc system_health):
      - Mở Deadlock tab / XML: <process-list> — spid, waitresource (KEY/PAGE), inputbuf (câu lệnh).
      - <victim-list> — session bị SQL Server chọn ROLLBACK.
      - <resource-list> — thứ tự khóa ngược chiều giữa 2 phiên → sửa bằng khóa cùng thứ tự
        (sp_CreateOrder duyệt cột ORDER BY ColumnId) hoặc rút ngắn transaction.
   ============================================================================= */

-- =============================================================================
-- B. CHUẨN BỊ DỮ LIỆU DEMO — một ngăn chỉ còn đúng 1 hộp
-- =============================================================================

CREATE OR ALTER PROCEDURE sales.sp_ConcurrencyDemo_Prepare
    @MachineId INT = NULL OUTPUT,
    @SlotId INT = NULL OUTPUT,
    @ProductId INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        @MachineId = m.MachineId,
        @SlotId = s.SlotId,
        @ProductId = s.ProductId
    FROM inventory.Machine m
    JOIN inventory.Slot s ON s.MachineId = m.MachineId AND s.IsActive = 1 AND s.ProductId IS NOT NULL
    WHERE m.IsActive = 1 AND m.Status = N'online'
    ORDER BY m.MachineId, s.SlotId;

    IF @SlotId IS NULL
        THROW 50299, N'Không tìm thấy ngăn có sản phẩm — chạy seed + 12_procs_sales.sql trước.', 1;

    UPDATE inventory.Slot
    SET CurrentStock = 1, UpdatedAt = SYSUTCDATETIME()
    WHERE SlotId = @SlotId;

    -- Không DELETE SlotStock (có thể đang FK từ OrderItem) — gộp tồn về 1 hộp
    UPDATE inventory.SlotStock SET Quantity = 0 WHERE SlotId = @SlotId;

    DECLARE @BatchId INT;
    SELECT TOP (1) @BatchId = b.BatchId
    FROM inventory.StockBatch b
    WHERE b.ProductId = @ProductId
    ORDER BY b.BatchId;

    IF @BatchId IS NULL
    BEGIN
        INSERT inventory.StockBatch (ProductId, BatchCode, Quantity, UnitCost, ImportDate, Note)
        VALUES (@ProductId, N'DEMO-CONC-' + CONVERT(NVARCHAR(12), @SlotId), 1, 0, CONVERT(DATE, SYSUTCDATETIME()),
                N'Lô demo concurrency TV3');
        SET @BatchId = CONVERT(INT, SCOPE_IDENTITY());
    END;

    IF EXISTS (SELECT 1 FROM inventory.SlotStock WHERE SlotId = @SlotId)
        UPDATE inventory.SlotStock SET Quantity = 1, BatchId = @BatchId
        WHERE StockId = (SELECT MIN(StockId) FROM inventory.SlotStock WHERE SlotId = @SlotId);
    ELSE
        INSERT inventory.SlotStock (SlotId, BatchId, Quantity, LoadedAt)
        VALUES (@SlotId, @BatchId, 1, SYSUTCDATETIME());

    SELECT @MachineId AS MachineId, @SlotId AS SlotId, @ProductId AS ProductId,
           N'Ngăn này chỉ còn 1 hộp — dùng cho demo 2 cửa sổ SSMS' AS Note;
END;
GO

-- Giống sp_CreateOrder nhưng WAITFOR trước COMMIT (cửa sổ 1)
CREATE OR ALTER PROCEDURE sales.sp_CreateOrder_DemoDelay
    @MachineId INT,
    @SlotId INT,
    @Qty TINYINT = 1,
    @Delay CHAR(12) = '00:00:10',
    @OrderId BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Qty < 1 OR @Qty > 5 THROW 50200, N'Số lượng không hợp lệ.', 1;

    DECLARE @ProductId INT, @UnitPrice DECIMAL(12,2), @StockId BIGINT, @BatchId INT,
            @LotQty SMALLINT, @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRAN;

        SELECT @ProductId = s.ProductId
        FROM inventory.Slot s WITH (UPDLOCK, ROWLOCK)
        WHERE s.SlotId = @SlotId AND s.MachineId = @MachineId AND s.IsActive = 1;
        IF @ProductId IS NULL
            THROW 50204, N'Ngăn không tồn tại trên máy này.', 1;

        SELECT @LotQty = ss.Quantity, @StockId = ss.StockId, @BatchId = ss.BatchId
        FROM inventory.SlotStock ss WITH (UPDLOCK, ROWLOCK)
        JOIN inventory.StockBatch b ON b.BatchId = ss.BatchId
        WHERE ss.SlotId = @SlotId AND ss.Quantity > 0 AND b.ProductId = @ProductId
        ORDER BY ss.LoadedAt, ss.StockId;

        IF @StockId IS NULL OR @LotQty < @Qty
            THROW 50201, N'Sản phẩm đã hết hàng hoặc không đủ số lượng.', 1;

        SELECT @UnitPrice = UnitPrice FROM inventory.Product WHERE ProductId = @ProductId;

        INSERT sales.[Order] (OrderCode, MachineId, Subtotal, DiscountAmount, TotalAmount, Status, CreatedAt)
        VALUES (N'FVDEMO' + LEFT(REPLACE(CONVERT(NVARCHAR(36), NEWID()), N'-', N''), 24),
                @MachineId, 0, 0, 0, N'PENDING', @Now);
        SET @OrderId = CONVERT(BIGINT, SCOPE_IDENTITY());

        UPDATE inventory.SlotStock SET Quantity = Quantity - @Qty WHERE StockId = @StockId;
        UPDATE inventory.Slot SET CurrentStock = CurrentStock - @Qty, UpdatedAt = @Now WHERE SlotId = @SlotId;
        INSERT sales.OrderItem (OrderId, SlotId, ProductId, Quantity, UnitPrice, StockId, BatchId)
        VALUES (@OrderId, @SlotId, @ProductId, @Qty, @UnitPrice, @StockId, @BatchId);

        UPDATE sales.[Order]
        SET Subtotal = sales.fn_OrderTotal(@OrderId),
            TotalAmount = sales.fn_OrderTotal(@OrderId),
            UpdatedAt = @Now
        WHERE OrderId = @OrderId;

        WAITFOR DELAY @Delay;

        COMMIT;

        SELECT @OrderId AS OrderId, N'PAID path: PENDING (demo delay done)' AS Note, @Delay AS DelayUsed;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- Bản KHÔNG UPDLOCK — minh hoạ bán vượt khi 2 phiên chạy song song (chỉ dùng lab)
CREATE OR ALTER PROCEDURE sales.sp_CreateOrder_NoUpdLock
    @MachineId INT,
    @SlotId INT,
    @Qty TINYINT = 1,
    @OrderId BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ProductId INT, @UnitPrice DECIMAL(12,2), @StockId BIGINT, @BatchId INT,
            @LotQty SMALLINT, @OnHand INT, @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRAN;

        SELECT @ProductId = s.ProductId, @OnHand = s.CurrentStock
        FROM inventory.Slot s
        WHERE s.SlotId = @SlotId AND s.MachineId = @MachineId AND s.IsActive = 1;
        IF @ProductId IS NULL OR @OnHand < @Qty
            THROW 50201, N'Sản phẩm đã hết hàng hoặc không đủ số lượng.', 1;

        SELECT TOP (1) @StockId = ss.StockId, @BatchId = ss.BatchId, @LotQty = ss.Quantity
        FROM inventory.SlotStock ss
        JOIN inventory.StockBatch b ON b.BatchId = ss.BatchId
        WHERE ss.SlotId = @SlotId AND ss.Quantity > 0 AND b.ProductId = @ProductId
        ORDER BY ss.LoadedAt, ss.StockId;

        SELECT @UnitPrice = UnitPrice FROM inventory.Product WHERE ProductId = @ProductId;

        INSERT sales.[Order] (OrderCode, MachineId, Subtotal, DiscountAmount, TotalAmount, Status, CreatedAt)
        VALUES (N'FVNOLCK' + LEFT(REPLACE(CONVERT(NVARCHAR(36), NEWID()), N'-', N''), 23),
                @MachineId, 0, 0, 0, N'PENDING', @Now);
        SET @OrderId = CONVERT(BIGINT, SCOPE_IDENTITY());

        WAITFOR DELAY '00:00:05';

        UPDATE inventory.SlotStock SET Quantity = Quantity - @Qty WHERE StockId = @StockId;
        UPDATE inventory.Slot SET CurrentStock = CurrentStock - @Qty WHERE SlotId = @SlotId;
        INSERT sales.OrderItem (OrderId, SlotId, ProductId, Quantity, UnitPrice, StockId, BatchId)
        VALUES (@OrderId, @SlotId, @ProductId, @Qty, @UnitPrice, @StockId, @BatchId);

        UPDATE sales.[Order]
        SET Subtotal = @Qty * @UnitPrice, TotalAmount = @Qty * @UnitPrice, UpdatedAt = @Now
        WHERE OrderId = @OrderId;

        COMMIT;
        SELECT @OrderId AS OrderId, N'No UPDLOCK demo' AS Note;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- C. SETUP — chạy 1 lần, ghi lại MachineId / SlotId in ra
-- =============================================================================

DECLARE @Mid INT, @Sid INT, @Pid INT;
EXEC sales.sp_ConcurrencyDemo_Prepare @MachineId = @Mid OUTPUT, @SlotId = @Sid OUTPUT, @ProductId = @Pid OUTPUT;
GO

/* =============================================================================
   D. HƯỚNG DẪN 2 CỬA SỔ SSMS (FV-25) — quay video ≤ 5 phút (Win + Alt + R)

   1. F5 cả file này (SETUP). Ghi MachineId / SlotId ở lưới kết quả.
   2. Mở thêm 1 tab SSMS (cùng FreshVendDB).

   --- Có UPDLOCK (đạt): 1 đơn thành công, tab kia 50201 hết hàng ---
   Tab A: F5 trước (giữ 10 giây). Tab B: F5 ngay trong lúc A còn chạy.

   Thay @MachineId, @SlotId bằng giá trị từ SETUP phía trên.

   --- Cửa sổ 1: Execute trước (giữ transaction 10 giây nhờ WAITFOR trong proc) ---
   DECLARE @MachineId INT = 1;   -- TODO: từ SETUP
   DECLARE @SlotId INT = 1;      -- TODO: từ SETUP
   DECLARE @OrderId BIGINT;
   EXEC sales.sp_CreateOrder_DemoDelay
        @MachineId = @MachineId,
        @SlotId = @SlotId,
        @Qty = 1,
        @Delay = '00:00:10',
        @OrderId = @OrderId OUTPUT;
   SELECT @OrderId AS OrderId_Window1;

   --- Cửa sổ 2: Execute ngay sau cửa sổ 1 (sẽ BLOCK vài giây rồi lỗi 50201) ---
   DECLARE @MachineId INT = 1;
   DECLARE @SlotId INT = 1;
   DECLARE @Items sales.OrderItemType;
   DECLARE @OrderId BIGINT;
   INSERT @Items (ColumnId, Qty) VALUES (@SlotId, 1);
   BEGIN TRY
       EXEC sales.sp_CreateOrder @MachineId = @MachineId, @Items = @Items, @OrderId = @OrderId OUTPUT;
       SELECT @OrderId AS OrderId_Window2, N'Thành công — không mong đợi khi chỉ còn 1 hộp' AS Note;
   END TRY
   BEGIN CATCH
       SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
       -- Kỳ vọng: 50201 — Sản phẩm đã hết hàng hoặc không đủ số lượng
   END CATCH;

   --- Lab: bỏ UPDLOCK — chạy Prepare lại, mở 2 cửa sổ gọi sp_CreateOrder_NoUpdLock cùng lúc ---
   EXEC sales.sp_ConcurrencyDemo_Prepare;
   -- Cả hai cửa sổ:
   -- EXEC sales.sp_CreateOrder_NoUpdLock @MachineId=..., @SlotId=..., @OrderId=@o OUT;
   -- Sau đó: SELECT CurrentStock FROM inventory.Slot WHERE SlotId=...  → có thể âm hoặc 2 đơn PENDING
   ============================================================================= */

PRINT N'[60_concurrency_demo] Đã tạo proc demo. Xem khối comment D để chạy 2 cửa sổ SSMS.';
GO
