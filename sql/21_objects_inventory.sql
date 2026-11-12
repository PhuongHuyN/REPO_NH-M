-- =============================================================================
-- FILE        : 21_objects_inventory.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV2 — View, function, trigger của module inventory
--               FV-18 (SCRUM-212):
--                 4 view : vw_ProductCatalog, vw_StockStatus, vw_AvailableBatches,
--                          vw_ExpiringBatches
--                 2 TVF  : fn_PriceHistory (Temporal Table), fn_GetFifoStock (FIFO)
--                 1 trigger: trg_Slot_LowStock (cảnh báo sắp hết hàng)
-- VERSION     : 1.0.0
-- CREATED     : 2026-11-12
-- RUN ORDER   : Sau 02_tables_inventory.sql (v1.1), 02_tables_iot.sql,
--               11_procs_inventory.sql (không bắt buộc 08 seed).
-- ĐẶC TẢ      : app/api/test/fakeDb.js (VIEW / TVF) — tên cột trả về phải GIỐNG HỆT
--               vì app/web/js đọc trực tiếp theo tên cột.
-- QUY ƯỚC     : • API gọi "cột" (ColumnId, ColumnNo) — SQL giữ "ngăn" (SlotId, SlotCode),
--                 ColumnNo = thứ tự ngăn trong máy theo SlotCode (A1 = 1 … C4 = 12) (QĐ-2).
--               • Giờ UTC (SYSUTCDATETIME). "Còn hạn" = ExpiryAt > bây giờ.
--               • "Đã nạp từ lô" = tổng StockMovement 'IN' có Reason bắt đầu 'Nạp ngăn'
--                 (giống sp_Restock).
--               • Trạng thái máy: ưu tiên iot.Machines.Status (khớp Serial = MachineCode),
--                 không có thì đổi Status của inventory.Machine sang cùng bộ giá trị
--                 ACTIVE / DEGRADED / OFFLINE / FAULT (QĐ-1 chưa chốt).
--               • CREATE OR ALTER → chạy lại nhiều lần không lỗi.
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 0. Hàm phụ: số thứ tự ngăn trong máy (A1 = 1, A2 = 2, …, C4 = 12, A10 sau A9)
--    Dùng chung cho các view bên dưới để không lặp công thức.
-- =============================================================================
CREATE OR ALTER FUNCTION inventory.fn_ColumnNo (@SlotId INT)
RETURNS TABLE
AS
RETURN
    SELECT COUNT(*) AS ColumnNo
    FROM   inventory.Slot s
    JOIN   inventory.Slot s2 ON s2.MachineId = s.MachineId
    WHERE  s.SlotId = @SlotId
      AND (LEN(s2.SlotCode) < LEN(s.SlotCode)
           OR (LEN(s2.SlotCode) = LEN(s.SlotCode) AND s2.SlotCode <= s.SlotCode));
GO

-- =============================================================================
-- 1. inventory.vw_ProductCatalog — Danh mục sản phẩm (GET /api/inventory/products)
--    Cột: ProductId, SKU, ProductName, Category, Description, Price, ImageUrl,
--         ShelfLifeHours, IsActive, ValidFrom, PriceSince, ColumnCount
--    (cùng cột với kết quả sp_UpdateProduct + ColumnCount = số ngăn đang bán)
-- =============================================================================
CREATE OR ALTER VIEW inventory.vw_ProductCatalog
AS
SELECT p.ProductId,
       p.SKU,
       p.ProductName,
       c.CategoryName                         AS Category,
       p.Description,
       p.UnitPrice                            AS Price,
       p.ImageUrl,
       p.ShelfLifeHours,
       p.IsActive,
       p.ValidFrom,                           -- cột HIDDEN của Temporal → phải gọi tên
       p.ValidFrom                            AS PriceSince,
       (SELECT COUNT(*) FROM inventory.Slot s
        WHERE  s.ProductId = p.ProductId AND s.IsActive = 1) AS ColumnCount
FROM   inventory.Product  p
JOIN   inventory.Category c ON c.CategoryId = p.CategoryId
WHERE  p.IsDeleted = 0;
GO

-- =============================================================================
-- 2. inventory.vw_StockStatus — Tồn kho theo ngăn (GET /api/inventory/stock, kiosk)
--    Remaining   = hộp CÒN HẠN trong ngăn (bán được)
--    ExpiredQty  = hộp ĐÃ HẾT HẠN còn nằm trong ngăn (chờ sp_RemoveExpired)
--    StockLabel  = TRỐNG | HẾT HÀNG | SẮP HẾT (≤ 20 % sức chứa) | CÒN HÀNG
-- =============================================================================
CREATE OR ALTER VIEW inventory.vw_StockStatus
AS
SELECT m.MachineId,
       m.MachineCode                                            AS Serial,
       m.MachineName,
       COALESCE(im.Status,
                CASE m.Status WHEN N'online'      THEN N'ACTIVE'
                              WHEN N'maintenance' THEN N'DEGRADED'
                              WHEN N'error'       THEN N'FAULT'
                              ELSE N'OFFLINE' END)              AS MachineStatus,
       s.SlotId                                                 AS ColumnId,
       n.ColumnNo,
       s.Capacity,
       p.ProductId,
       p.ProductName,
       c.CategoryName                                           AS Category,
       p.Description,
       p.UnitPrice                                              AS Price,
       p.ImageUrl,
       q.Remaining,
       q.ExpiredQty,
       CAST(q.Remaining * 100.0 / NULLIF(s.Capacity, 0) AS DECIMAL(5,1)) AS FillPercent,
       q.NearestExpiry,
       CASE WHEN p.ProductId IS NULL           THEN N'TRỐNG'
            WHEN q.Remaining = 0               THEN N'HẾT HÀNG'
            WHEN q.Remaining * 5 <= s.Capacity THEN N'SẮP HẾT'
            ELSE N'CÒN HÀNG' END                                AS StockLabel
FROM   inventory.Slot     s
JOIN   inventory.Machine  m  ON m.MachineId  = s.MachineId
LEFT JOIN iot.Machines    im ON im.Serial    = m.MachineCode
LEFT JOIN inventory.Product  p ON p.ProductId  = s.ProductId
LEFT JOIN inventory.Category c ON c.CategoryId = p.CategoryId
CROSS APPLY inventory.fn_ColumnNo(s.SlotId) n
CROSS APPLY (
    SELECT ISNULL(SUM(CASE WHEN b.ExpiryAt >  SYSUTCDATETIME() THEN ss.Quantity END), 0) AS Remaining,
           ISNULL(SUM(CASE WHEN b.ExpiryAt <= SYSUTCDATETIME() THEN ss.Quantity END), 0) AS ExpiredQty,
           MIN(CASE WHEN b.ExpiryAt > SYSUTCDATETIME() THEN b.ExpiryAt END)             AS NearestExpiry
    FROM   inventory.SlotStock  ss
    JOIN   inventory.StockBatch b ON b.BatchId = ss.BatchId
    WHERE  ss.SlotId = s.SlotId AND ss.Quantity > 0
) q
WHERE  s.IsActive = 1;
GO

-- =============================================================================
-- 3. inventory.vw_AvailableBatches — Lô còn có thể châm (GET /api/inventory/batches)
--    Chỉ lô CÒN HẠN và còn hộp chưa nạp vào ngăn (Available > 0).
--    Allocated = đã nạp vào ngăn (seed + sp_Restock), Available = Quantity − Allocated
-- =============================================================================
CREATE OR ALTER VIEW inventory.vw_AvailableBatches
AS
SELECT b.BatchId,
       b.BatchCode,
       b.ProductId,
       p.ProductName,
       b.PreparedAt,
       b.ExpiryAt,
       COALESCE(sp.SupplierName,
                CASE WHEN b.Note LIKE N'Nhà cung cấp: %' THEN SUBSTRING(b.Note, 16, 100) END) AS Supplier,
       b.Quantity,
       u.Allocated,
       b.Quantity - u.Allocated AS Available
FROM   inventory.StockBatch b
JOIN   inventory.Product    p  ON p.ProductId   = b.ProductId
LEFT JOIN inventory.Supplier sp ON sp.SupplierId = b.SupplierId
CROSS APPLY (
    SELECT ISNULL(SUM(m.Quantity), 0) AS Allocated
    FROM   inventory.StockMovement m
    WHERE  m.BatchId = b.BatchId
      AND  m.MovementType = N'IN'
      AND  m.Reason LIKE N'Nạp ngăn%'
) u
WHERE  b.ExpiryAt > SYSUTCDATETIME()
  AND  b.Quantity - u.Allocated > 0;
GO

-- =============================================================================
-- 4. inventory.vw_ExpiringBatches — Hàng trong ngăn sắp hết hạn (≤ 6 giờ) hoặc
--    đã hết hạn (GET /api/inventory/expiring)
--    ExpiryLabel = ĐÃ HẾT HẠN | SẮP HẾT HẠN ; HoursLeft âm = đã quá hạn bao lâu
-- =============================================================================
CREATE OR ALTER VIEW inventory.vw_ExpiringBatches
AS
SELECT s.MachineId,
       m.MachineCode                                                   AS Serial,
       s.SlotId                                                        AS ColumnId,
       n.ColumnNo,
       p.ProductName,
       b.BatchId,
       b.BatchCode,
       b.ExpiryAt,
       ss.StockId,
       ss.Quantity                                                     AS Qty,
       CAST(DATEDIFF(SECOND, SYSUTCDATETIME(), b.ExpiryAt) / 3600.0 AS DECIMAL(7,1)) AS HoursLeft,
       CASE WHEN b.ExpiryAt <= SYSUTCDATETIME() THEN N'ĐÃ HẾT HẠN'
            ELSE N'SẮP HẾT HẠN' END                                    AS ExpiryLabel
FROM   inventory.SlotStock  ss
JOIN   inventory.StockBatch b ON b.BatchId   = ss.BatchId
JOIN   inventory.Product    p ON p.ProductId = b.ProductId
JOIN   inventory.Slot       s ON s.SlotId    = ss.SlotId
JOIN   inventory.Machine    m ON m.MachineId = s.MachineId
CROSS APPLY inventory.fn_ColumnNo(s.SlotId) n
WHERE  ss.Quantity > 0
  AND  b.ExpiryAt <= DATEADD(HOUR, 6, SYSUTCDATETIME());
GO

-- =============================================================================
-- 5. inventory.fn_PriceHistory(@ProductId) — Lịch sử giá từ Temporal Table
--    (GET /api/inventory/products/:id/price-history)
--    Đọc inventory.Product FOR SYSTEM_TIME ALL (bảng lịch sử ProductHistory), chỉ
--    giữ các mốc ĐỔI GIÁ (đổi tên / mô tả không tạo dòng mới).
--    Cột: ProductId, ProductName, Price, ValidFrom, ValidTo, IsCurrent
-- =============================================================================
CREATE OR ALTER FUNCTION inventory.fn_PriceHistory (@ProductId INT)
RETURNS TABLE
AS
RETURN
    WITH v AS (
        SELECT ProductId, ProductName, UnitPrice, ValidFrom, ValidTo,
               LAG(UnitPrice) OVER (ORDER BY ValidFrom, ValidTo) AS PrevPrice
        FROM   inventory.Product FOR SYSTEM_TIME ALL
        WHERE  ProductId = @ProductId
        -- ValidFrom chỉ chính xác tới giây: nhiều lần sửa trong 1 giây có cùng ValidFrom,
        -- nên sắp thêm theo ValidTo (dòng lịch sử kết thúc trước dòng hiện tại).
    ), chg AS (
        SELECT ProductId, ProductName, UnitPrice, ValidFrom, ValidTo
        FROM   v
        WHERE  PrevPrice IS NULL OR PrevPrice <> UnitPrice
    )
    SELECT ProductId,
           ProductName,
           UnitPrice AS Price,
           ValidFrom,
           LEAD(ValidFrom, 1, (SELECT MAX(ValidTo) FROM v)) OVER (ORDER BY ValidFrom, ValidTo) AS ValidTo,
           CAST(CASE WHEN LEAD(ValidFrom) OVER (ORDER BY ValidFrom, ValidTo) IS NULL
                      AND (SELECT MAX(ValidTo) FROM v) >= CONVERT(DATETIME2(0), '9999-12-31 00:00:00')
                     THEN 1 ELSE 0 END AS BIT) AS IsCurrent
    FROM   chg;
GO

-- =============================================================================
-- 6. inventory.fn_GetFifoStock(@ColumnId) — Thứ tự bán FIFO trong 1 ngăn
--    Lô nạp trước bán trước (LoadedAt, StockId); chỉ lô còn hàng và CÒN HẠN.
--    CumulativeQty: cộng dồn — dùng để biết 1 đơn n hộp sẽ lấy từ những lô nào.
--    Ví dụ: SELECT * FROM inventory.fn_GetFifoStock(5) ORDER BY FifoOrder;
-- =============================================================================
CREATE OR ALTER FUNCTION inventory.fn_GetFifoStock (@ColumnId INT)
RETURNS TABLE
AS
RETURN
    SELECT ss.StockId,
           ss.SlotId                                                        AS ColumnId,
           ss.BatchId,
           b.BatchCode,
           ss.Quantity                                                      AS Qty,
           ss.LoadedAt,
           b.ExpiryAt,
           ROW_NUMBER() OVER (ORDER BY ss.LoadedAt, ss.StockId)             AS FifoOrder,
           SUM(CAST(ss.Quantity AS INT)) OVER (ORDER BY ss.LoadedAt, ss.StockId
                                               ROWS UNBOUNDED PRECEDING)    AS CumulativeQty
    FROM   inventory.SlotStock  ss
    JOIN   inventory.StockBatch b ON b.BatchId = ss.BatchId
    WHERE  ss.SlotId = @ColumnId
      AND  ss.Quantity > 0
      AND  b.ExpiryAt > SYSUTCDATETIME();
GO

-- =============================================================================
-- 7. trg_Slot_LowStock — Cảnh báo SẮP HẾT HÀNG khi tồn của ngăn giảm
--    Bắn khi UPDATE inventory.Slot đổi CurrentStock (bán, rút hết hạn, châm…).
--    Ngăn có sản phẩm và số hộp CÒN HẠN ≤ 20 % sức chứa → ghi iot.Alerts:
--      AlertType LOW_STOCK, RefKey 'COL:<SlotId>', Severity HIGH khi = 0, MEDIUM khi > 0
--    Không ghi trùng nếu cột đó đang có cảnh báo LOW_STOCK chưa xử lý.
--    sp_Restock đóng cảnh báo (ResolvedAt) khi châm đủ hàng.
--    Chưa có iot.Alerts / máy chưa có bên iot.Machines → bỏ qua, không lỗi
--    (không làm hỏng giao dịch bán hàng).
-- =============================================================================
CREATE OR ALTER TRIGGER inventory.trg_Slot_LowStock
ON inventory.Slot
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(CurrentStock) RETURN;
    IF OBJECT_ID(N'iot.Alerts', N'U') IS NULL OR OBJECT_ID(N'iot.Machines', N'U') IS NULL RETURN;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    INSERT iot.Alerts (MachineId, AlertType, Severity, Message, RefKey, CreatedAt)
    SELECT im.MachineId,
           N'LOW_STOCK',
           CASE WHEN r.Remaining = 0 THEN N'HIGH' ELSE N'MEDIUM' END,
           N'Cột ' + CAST(n.ColumnNo AS NVARCHAR(10)) + N' (' + p.ProductName + N') còn '
             + CAST(r.Remaining AS NVARCHAR(10)) + N'/' + CAST(i.Capacity AS NVARCHAR(10)) + N' hộp',
           N'COL:' + CAST(i.SlotId AS NVARCHAR(10)),
           @Now
    FROM   inserted i
    JOIN   deleted d             ON d.SlotId     = i.SlotId
    JOIN   inventory.Product p   ON p.ProductId  = i.ProductId
    JOIN   inventory.Machine m   ON m.MachineId  = i.MachineId
    JOIN   iot.Machines im       ON im.Serial    = m.MachineCode
    CROSS APPLY inventory.fn_ColumnNo(i.SlotId) n
    CROSS APPLY (SELECT ISNULL(SUM(ss.Quantity), 0) AS Remaining
                 FROM   inventory.SlotStock  ss
                 JOIN   inventory.StockBatch b ON b.BatchId = ss.BatchId
                 WHERE  ss.SlotId = i.SlotId AND b.ExpiryAt > @Now) r
    WHERE  i.CurrentStock < d.CurrentStock          -- chỉ khi tồn GIẢM
      AND  r.Remaining * 5 <= i.Capacity
      AND  NOT EXISTS (SELECT 1 FROM iot.Alerts a
                       WHERE a.AlertType = N'LOW_STOCK'
                         AND a.RefKey    = N'COL:' + CAST(i.SlotId AS NVARCHAR(10))
                         AND a.ResolvedAt IS NULL);
END
GO

PRINT N'[21-inv] Đã tạo/cập nhật: 4 view, fn_PriceHistory, fn_GetFifoStock, fn_ColumnNo, trigger trg_Slot_LowStock.';
GO
