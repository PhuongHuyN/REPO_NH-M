-- =============================================================================
-- FILE        : tests/demo_tv2.sql
-- PROJECT     : FreshVend
-- DESCRIPTION : FV-33 (SCRUM-227) — DEMO 3 phần khó của TV2 (Tồn kho) khi bảo vệ
--                 DEMO 1 — Temporal Table: SQL Server tự lưu lịch sử giá, xem "giá lúc trước"
--                 DEMO 2 — TVP + transaction: phiếu châm 3 dòng, 1 dòng sai → KHÔNG dòng nào được ghi
--                 DEMO 3 — FIFO: bán hàng lấy lô nạp trước, tự chuyển sang lô sau khi lô trước hết
-- DỮ LIỆU     : Chạy THẬT trên FreshVendDB (procedure / view / bảng thật), đầu vào là dữ liệu
--               mẫu của 08_seed_inventory.sql. Mỗi demo tự tìm sản phẩm / ngăn / lô phù hợp.
-- AN TOÀN     : • DEMO 1 đổi giá rồi TRẢ LẠI giá cũ (bảng lịch sử giữ lại các mốc — đúng bản
--                 chất Temporal: lịch sử không xóa được, đó chính là điểm cần chứng minh).
--               • DEMO 2, 3 chạy phần ghi trong BEGIN TRAN … ROLLBACK → tồn kho trở lại như cũ.
--               → Chạy lại bao nhiêu lần cũng được.
-- CÁCH CHẠY   : Bôi đen TỪNG KHỐI (từ dòng "DEMO x" tới GO) rồi F5. Xem tab Results (từng bảng
--               có cột "Bước") và tab Messages (lời giải thích). Giờ hiển thị = giờ VN.
-- CHUẨN BỊ    : Đã dựng CSDL đủ 00 → 40 (README.md). Nên chạy 08_seed_inventory.sql trong ngày
--               để các lô còn hạn.
-- =============================================================================

USE FreshVendDB;
GO
SET NOCOUNT ON;
GO

-- =============================================================================
-- DEMO 1 — TEMPORAL TABLE (lịch sử giá tự động)
--   Ý cần nói: bảng inventory.Product bật SYSTEM_VERSIONING → mỗi lần UPDATE, SQL Server
--   tự chép dòng cũ sang inventory.ProductHistory kèm khoảng thời gian hiệu lực.
--   Không cần trigger, không cần code lưu lịch sử. Truy vấn "giá tại thời điểm X" bằng AS OF.
-- =============================================================================
DECLARE @pid INT, @name NVARCHAR(150), @p0 DECIMAL(12,2), @p1 DECIMAL(12,2), @p2 DECIMAL(12,2),
        @t0 DATETIME2(0), @t1 DATETIME2(0);

SELECT @pid = ProductId, @name = ProductName, @p0 = UnitPrice
FROM inventory.Product WHERE SKU = N'FV-SP-003';                 -- Xoài cát Hòa Lộc
IF @pid IS NULL
    SELECT TOP (1) @pid = ProductId, @name = ProductName, @p0 = UnitPrice
    FROM inventory.Product WHERE IsDeleted = 0 ORDER BY ProductId;

-- EXEC không nhận biểu thức (@p0 + 2000) làm tham số → tính sẵn vào biến
SELECT @p1 = @p0 + 2000, @p2 = @p0 + 5000;

PRINT N'DEMO 1 — Sản phẩm: ' + @name + N', giá hiện tại ' + FORMAT(@p0, 'N0') + N' đ';

SELECT N'1. Trước khi đổi' AS [Bước], ProductId, ProductName, UnitPrice AS Price,
       DATEADD(HOUR, 7, ValidFrom) AS [Áp dụng từ (giờ VN)]
FROM inventory.Product WHERE ProductId = @pid;

SET @t0 = SYSUTCDATETIME();                                       -- mốc 1: giá gốc
WAITFOR DELAY '00:00:02';
EXEC inventory.sp_UpdatePrice @ProductId = @pid, @NewPrice = @p1;   -- lần đổi 1
WAITFOR DELAY '00:00:02';
SET @t1 = SYSUTCDATETIME();                                       -- mốc 2: giá sau lần 1
WAITFOR DELAY '00:00:02';
EXEC inventory.sp_UpdatePrice @ProductId = @pid, @NewPrice = @p2;   -- lần đổi 2

PRINT N'Đã đổi giá 2 lần: +2.000 đ rồi +5.000 đ. Tiếp theo: xem lịch sử SQL Server tự lưu.';

-- Toàn bộ lịch sử (bảng hiện tại + bảng lịch sử)
SELECT N'2. FOR SYSTEM_TIME ALL — mọi phiên bản' AS [Bước], ProductName, UnitPrice AS Price,
       DATEADD(HOUR, 7, ValidFrom) AS [Từ (giờ VN)],
       CASE WHEN ValidTo >= '9999-12-31' THEN N'(đang áp dụng)'
            ELSE CONVERT(NVARCHAR(30), DATEADD(HOUR, 7, ValidTo), 120) END AS [Đến (giờ VN)]
FROM inventory.Product FOR SYSTEM_TIME ALL
WHERE ProductId = @pid AND ValidTo >= DATEADD(SECOND, -1, @t0)   -- phiên bản gốc + các phiên bản tạo trong demo
ORDER BY ValidFrom, ValidTo;

-- "Giá lúc trước" — không cần bảng phụ nào
SELECT N'3. AS OF mốc 1 (trước khi đổi)' AS [Bước], UnitPrice AS Price, DATEADD(HOUR, 7, @t0) AS [Thời điểm (giờ VN)]
FROM inventory.Product FOR SYSTEM_TIME AS OF @t0 WHERE ProductId = @pid
UNION ALL
SELECT N'4. AS OF mốc 2 (sau lần đổi 1)', UnitPrice, DATEADD(HOUR, 7, @t1)
FROM inventory.Product FOR SYSTEM_TIME AS OF @t1 WHERE ProductId = @pid
UNION ALL
SELECT N'5. Hiện tại', UnitPrice, DATEADD(HOUR, 7, SYSUTCDATETIME())
FROM inventory.Product WHERE ProductId = @pid;

-- Hàm app dùng cho màn hình "Lịch sử giá"
SELECT N'6. inventory.fn_PriceHistory (API dùng)' AS [Bước], Price,
       DATEADD(HOUR, 7, ValidFrom) AS [Từ (giờ VN)], IsCurrent
FROM inventory.fn_PriceHistory(@pid)
ORDER BY ValidFrom DESC;

-- Trả lại giá gốc (lịch sử vẫn ghi nhận cả lần trả lại này)
EXEC inventory.sp_UpdatePrice @ProductId = @pid, @NewPrice = @p0;
PRINT N'Đã trả lại giá gốc ' + FORMAT(@p0, 'N0') + N' đ. Lịch sử KHÔNG xóa được bằng UPDATE/DELETE thường — đó là ý nghĩa của Temporal Table.';
GO

-- =============================================================================
-- DEMO 2 — TVP + TRANSACTION (tất cả hoặc không gì cả)
--   Ý cần nói: sp_Restock nhận CẢ phiếu châm hàng qua 1 tham số bảng (Table-Valued
--   Parameter) inventory.RestockItemType → 1 lần gọi, 1 giao dịch. Chỉ cần 1 dòng sai
--   (vượt sức chứa) là THROW 50117 và ROLLBACK toàn bộ: 2 dòng đúng cũng không được ghi.
-- =============================================================================
DECLARE @m INT, @uid INT, @before INT, @after INT, @err INT, @msg NVARCHAR(400);
DECLARE @bad inventory.RestockItemType, @good inventory.RestockItemType;

-- Máy đang hoạt động + người châm hàng
SELECT TOP (1) @m = MachineId FROM inventory.Machine WHERE Status = N'online' AND IsActive = 1 ORDER BY MachineId;
SELECT TOP (1) @uid = u.UserId FROM auth.[User] u
JOIN auth.UserRole ur ON ur.UserId = u.UserId JOIN auth.Role r ON r.RoleId = ur.RoleId
WHERE r.RoleName = N'Operator' ORDER BY u.UserId;
SET @uid = ISNULL(@uid, (SELECT TOP (1) UserId FROM auth.[User] ORDER BY UserId));

-- 3 ngăn còn chỗ của máy @m, mỗi ngăn có 1 lô cùng sản phẩm còn hàng và còn hạn > 1 giờ
IF OBJECT_ID(N'tempdb..#c') IS NOT NULL DROP TABLE #c;
SELECT TOP (3) s.SlotId, s.Capacity, s.CurrentStock, s.Capacity - s.CurrentStock AS Free,
       p.ProductName, b.BatchId, b.BatchCode, b.Available,
       ROW_NUMBER() OVER (ORDER BY s.SlotId) AS Line
INTO #c
FROM inventory.Slot s
JOIN inventory.Product p ON p.ProductId = s.ProductId
CROSS APPLY (SELECT TOP (1) BatchId, BatchCode, Available
             FROM inventory.vw_AvailableBatches
             WHERE ProductId = s.ProductId AND Available >= 2
               AND ExpiryAt > DATEADD(HOUR, 1, SYSUTCDATETIME())
             ORDER BY ExpiryAt DESC) b
WHERE s.MachineId = @m AND s.IsActive = 1 AND s.CurrentStock < s.Capacity
ORDER BY s.SlotId;

IF (SELECT COUNT(*) FROM #c) < 3
BEGIN
    PRINT N'DEMO 2: không đủ 3 ngăn còn chỗ có lô phù hợp — chạy lại 08_seed_inventory.sql rồi thử lại.';
    RETURN;
END;

-- Phiếu SAI: dòng 1, 2 đúng (1 hộp); dòng 3 châm (chỗ trống + 1) hộp → vượt sức chứa
INSERT @bad (ColumnId, BatchId, Qty)
SELECT SlotId, BatchId, CASE WHEN Line = 3 THEN Free + 1 ELSE 1 END FROM #c;
INSERT @good (ColumnId, BatchId, Qty)
SELECT SlotId, BatchId, 1 FROM #c WHERE Line < 3;

PRINT N'DEMO 2 — Máy ' + CAST(@m AS NVARCHAR(10)) + N': phiếu châm 3 dòng, dòng 3 cố tình vượt sức chứa.';

SELECT N'1. Phiếu châm gửi vào (TVP)' AS [Bước], c.Line AS [Dòng], c.SlotId AS ColumnId, c.ProductName,
       c.BatchCode, i.Qty AS [Châm thêm], c.CurrentStock AS [Đang có], c.Capacity AS [Sức chứa],
       CASE WHEN c.CurrentStock + i.Qty > c.Capacity THEN N'VƯỢT SỨC CHỨA' ELSE N'hợp lệ' END AS [Kiểm tra]
FROM #c c JOIN @bad i ON i.ColumnId = c.SlotId ORDER BY c.Line;

SET @before = (SELECT SUM(CurrentStock) FROM inventory.Slot WHERE SlotId IN (SELECT SlotId FROM #c));
SET @err = 0;
BEGIN TRY
    EXEC inventory.sp_Restock @MachineId = @m, @UserId = @uid, @Items = @bad, @Note = N'DEMO 2 – phiếu sai';
END TRY
BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @msg = ERROR_MESSAGE();
END CATCH;
SET @after = (SELECT SUM(CurrentStock) FROM inventory.Slot WHERE SlotId IN (SELECT SlotId FROM #c));

SELECT N'2. Kết quả phiếu SAI' AS [Bước], @err AS [Mã lỗi], @msg AS [Thông báo],
       @before AS [Tổng tồn 3 ngăn TRƯỚC], @after AS [Tổng tồn 3 ngăn SAU],
       CASE WHEN @before = @after THEN N'KHÔNG dòng nào được ghi (kể cả 2 dòng đúng)' ELSE N'!!! có dòng bị ghi' END AS [Kết luận];

-- Phiếu ĐÚNG (2 dòng) — chạy trong transaction rồi ROLLBACK để không đổi dữ liệu thật
BEGIN TRANSACTION;
    EXEC inventory.sp_Restock @MachineId = @m, @UserId = @uid, @Items = @good, @Note = N'DEMO 2 – phiếu đúng';
    SELECT N'3. Phiếu ĐÚNG 2 dòng → ghi đủ' AS [Bước], s.SlotId AS ColumnId, p.ProductName,
           c.CurrentStock AS [Trước], s.CurrentStock AS [Sau]
    FROM inventory.Slot s JOIN #c c ON c.SlotId = s.SlotId JOIN inventory.Product p ON p.ProductId = s.ProductId
    WHERE c.Line < 3 ORDER BY c.Line;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

SELECT N'4. Sau ROLLBACK của demo (dữ liệu trả về như cũ)' AS [Bước],
       SUM(CurrentStock) AS [Tổng tồn 3 ngăn], @before AS [Ban đầu]
FROM inventory.Slot WHERE SlotId IN (SELECT SlotId FROM #c);
PRINT N'DEMO 2 xong: phiếu sai bị từ chối nguyên khối (lỗi ' + CAST(@err AS NVARCHAR(10)) + N'), phiếu đúng ghi đủ 2 dòng.';
GO

-- =============================================================================
-- DEMO 3 — FIFO (nhập trước bán trước, theo LÔ trong từng ngăn)
--   Ý cần nói: 1 ngăn có thể chứa nhiều lô (inventory.SlotStock). inventory.fn_GetFifoStock
--   xếp lô nạp trước lên đầu; sales.sp_CreateOrder lấy hàng theo đúng thứ tự đó và khóa dòng
--   (UPDLOCK) để 2 khách mua cùng lúc không lấy trùng. Mua nhiều hơn số hộp của lô đầu →
--   tự lấy tiếp sang lô sau, mỗi lô 1 dòng OrderItem (truy vết được hộp nào thuộc lô nào).
-- =============================================================================
DECLARE @slot INT, @mach INT, @first INT, @total INT, @buy TINYINT, @oid BIGINT;
DECLARE @cart sales.OrderItemType;

-- Ngăn của máy đang hoạt động có ≥ 2 lô còn hạn, mua (số hộp lô đầu + 1) ≤ 5 hộp
SELECT TOP (1) @slot = s.SlotId, @mach = s.MachineId, @first = f1.Qty, @total = t.Total
FROM inventory.Slot s
JOIN inventory.Machine m ON m.MachineId = s.MachineId AND m.Status = N'online' AND m.IsActive = 1
CROSS APPLY (SELECT Qty FROM inventory.fn_GetFifoStock(s.SlotId) WHERE FifoOrder = 1) f1
CROSS APPLY (SELECT COUNT(*) AS Lots, SUM(Qty) AS Total FROM inventory.fn_GetFifoStock(s.SlotId)) t
WHERE s.IsActive = 1 AND t.Lots >= 2 AND f1.Qty + 1 <= 5 AND t.Total >= f1.Qty + 1
ORDER BY s.SlotId;

IF @slot IS NULL
BEGIN
    PRINT N'DEMO 3: chưa có ngăn nào có 2 lô còn hạn — chạy lại 08_seed_inventory.sql rồi thử lại.';
    RETURN;
END;

SET @buy = @first + 1;
INSERT @cart (ColumnId, Qty) VALUES (@slot, @buy);
PRINT N'DEMO 3 — Ngăn ' + CAST(@slot AS NVARCHAR(10)) + N' (máy ' + CAST(@mach AS NVARCHAR(10)) + N'): lô đầu còn '
    + CAST(@first AS NVARCHAR(10)) + N' hộp, khách mua ' + CAST(@buy AS NVARCHAR(10)) + N' hộp.';

SELECT N'1. Thứ tự FIFO trước khi bán' AS [Bước], FifoOrder AS [Thứ tự], BatchCode, Qty AS [Còn],
       DATEADD(HOUR, 7, LoadedAt) AS [Nạp ngăn lúc (giờ VN)], DATEADD(HOUR, 7, ExpiryAt) AS [Hết hạn (giờ VN)]
FROM inventory.fn_GetFifoStock(@slot) ORDER BY FifoOrder;

BEGIN TRANSACTION;
    EXEC sales.sp_CreateOrder @MachineId = @mach, @Items = @cart, @OrderId = @oid OUTPUT;

    SELECT N'2. Đơn hàng lấy từ lô nào' AS [Bước], oi.OrderId, b.BatchCode, oi.Quantity AS [Số hộp],
           DATEADD(HOUR, 7, ss.LoadedAt) AS [Lô nạp lúc (giờ VN)]
    FROM sales.OrderItem oi
    JOIN inventory.StockBatch b ON b.BatchId = oi.BatchId
    JOIN inventory.SlotStock ss ON ss.StockId = oi.StockId
    WHERE oi.OrderId = @oid
    ORDER BY ss.LoadedAt, ss.StockId;

    SELECT N'3. Thứ tự FIFO sau khi bán' AS [Bước], FifoOrder AS [Thứ tự], BatchCode, Qty AS [Còn]
    FROM inventory.fn_GetFifoStock(@slot) ORDER BY FifoOrder;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

SELECT N'4. Sau ROLLBACK của demo (tồn theo lô trả về như cũ)' AS [Bước], FifoOrder AS [Thứ tự], BatchCode, Qty AS [Còn]
FROM inventory.fn_GetFifoStock(@slot) ORDER BY FifoOrder;
PRINT N'DEMO 3 xong: lô nạp trước bị lấy hết trước, phần còn thiếu lấy sang lô sau.';
GO
