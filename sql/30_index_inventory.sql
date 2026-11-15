-- =============================================================================
-- FILE        : 30_index_inventory.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV2 — Index cho module inventory
--               FV-19 (SCRUM-213)
-- VERSION     : 1.0.0
-- CREATED     : 2026-11-12
-- RUN ORDER   : Sau 02_tables_inventory.sql (v1.1). Chạy trước hay sau seed / procedure
--               đều được. Chạy lại nhiều lần không lỗi (IF NOT EXISTS theo tên index).
-- GHI CHÚ     : Index đã có sẵn ở file khác, KHÔNG tạo lại ở đây:
--                 • PK / UNIQUE của từng bảng (02_tables_inventory.sql)
--                 • IX_inventory_SlotStock_FIFO (SlotId, LoadedAt, StockId) — FIFO khi bán
--               Mỗi index dưới đây ghi rõ: truy vấn nào dùng nó.
--               Tên: IX_<schema>_<bảng>_<cột>, UX_… = UNIQUE.
--               Index có WHERE (filtered) yêu cầu QUOTED_IDENTIFIER ON khi tạo procedure
--               và khi ghi bảng: SSMS, app Node.js mặc định ON; chạy bằng sqlcmd phải
--               có tham số -I (các script run-*.ps1 của nhóm đã có).
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 1. Slot(ProductId) — lọc ngăn theo sản phẩm
--    Dùng ở: vw_ProductCatalog (ColumnCount), sp_UpdateProduct (chặn ngừng bán khi
--            sản phẩm còn ở ngăn), báo cáo theo sản phẩm.
--    Lọc ProductId IS NOT NULL: ngăn trống không cần nằm trong index.
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_Slot_ProductId'
               AND object_id = OBJECT_ID(N'inventory.Slot'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_inventory_Slot_ProductId
        ON inventory.Slot (ProductId)
        INCLUDE (MachineId, IsActive, CurrentStock, Capacity)
        WHERE ProductId IS NOT NULL;
    PRINT N'[30-inv] Đã tạo IX_inventory_Slot_ProductId.';
END
GO

-- =============================================================================
-- 2. SlotStock(BatchId) — tồn theo lô tra từ phía LÔ
--    Dùng ở: vw_ExpiringBatches, sp_RemoveExpired (tìm hàng của lô hết hạn),
--            truy vết "lô này đang nằm ở ngăn nào".
--    Lọc Quantity > 0: dòng đã bán hết / đã rút không cần tra.
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_SlotStock_BatchId'
               AND object_id = OBJECT_ID(N'inventory.SlotStock'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_inventory_SlotStock_BatchId
        ON inventory.SlotStock (BatchId)
        INCLUDE (SlotId, Quantity, LoadedAt)
        WHERE Quantity > 0;
    PRINT N'[30-inv] Đã tạo IX_inventory_SlotStock_BatchId.';
END
GO

-- =============================================================================
-- 3. StockBatch(ExpiryAt) — lọc lô theo hạn dùng
--    Dùng ở: vw_AvailableBatches (ExpiryAt > now), vw_ExpiringBatches (≤ now + 6h),
--            sp_RemoveExpired (ExpiryAt <= now), job rút hàng mỗi giờ (FV-28).
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_StockBatch_ExpiryAt'
               AND object_id = OBJECT_ID(N'inventory.StockBatch'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_inventory_StockBatch_ExpiryAt
        ON inventory.StockBatch (ExpiryAt)
        INCLUDE (ProductId, BatchCode, Quantity, PreparedAt);
    PRINT N'[30-inv] Đã tạo IX_inventory_StockBatch_ExpiryAt.';
END
GO

-- =============================================================================
-- 4. StockBatch(ProductId, ExpiryAt) — lô của 1 sản phẩm, hạn gần nhất trước
--    Dùng ở: GET /api/inventory/batches?productId= (chọn lô khi châm hàng),
--            sp_AddBatch / báo cáo nhập hàng theo sản phẩm.
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_StockBatch_Product_Expiry'
               AND object_id = OBJECT_ID(N'inventory.StockBatch'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_inventory_StockBatch_Product_Expiry
        ON inventory.StockBatch (ProductId, ExpiryAt)
        INCLUDE (BatchCode, Quantity, PreparedAt, SupplierId);
    PRINT N'[30-inv] Đã tạo IX_inventory_StockBatch_Product_Expiry.';
END
GO

-- =============================================================================
-- 5. StockMovement(BatchId, MovementType) — tổng số hộp đã nạp từ 1 lô
--    Dùng ở: sp_Restock (kiểm tra lô đủ số lượng — lỗi 50118),
--            vw_AvailableBatches (Allocated / Available).
--    Bảng này lớn dần theo thời gian (mỗi lần bán / châm / rút 1 dòng) → rất cần index.
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_StockMovement_Batch_Type'
               AND object_id = OBJECT_ID(N'inventory.StockMovement'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_inventory_StockMovement_Batch_Type
        ON inventory.StockMovement (BatchId, MovementType)
        INCLUDE (Quantity, Reason)
        WHERE BatchId IS NOT NULL;
    PRINT N'[30-inv] Đã tạo IX_inventory_StockMovement_Batch_Type.';
END
GO

-- =============================================================================
-- 6. StockMovement(SlotId, CreatedAt DESC) — lịch sử xuất/nhập của 1 ngăn, mới nhất trước
--    Dùng ở: màn hình lịch sử ngăn, đối soát tồn kho, báo cáo hao hụt.
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_StockMovement_Slot_CreatedAt'
               AND object_id = OBJECT_ID(N'inventory.StockMovement'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_inventory_StockMovement_Slot_CreatedAt
        ON inventory.StockMovement (SlotId, CreatedAt DESC)
        INCLUDE (MovementType, Quantity, BatchId);
    PRINT N'[30-inv] Đã tạo IX_inventory_StockMovement_Slot_CreatedAt.';
END
GO

-- =============================================================================
-- 7. RestockEvent(MachineId, RestockedAt DESC) — lịch sử châm hàng của 1 máy
--    Dùng ở: báo cáo châm hàng theo máy / theo ngày, kiểm tra ca làm của Operator.
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_RestockEvent_Machine_At'
               AND object_id = OBJECT_ID(N'inventory.RestockEvent'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_inventory_RestockEvent_Machine_At
        ON inventory.RestockEvent (MachineId, RestockedAt DESC)
        INCLUDE (UserId);
    PRINT N'[30-inv] Đã tạo IX_inventory_RestockEvent_Machine_At.';
END
GO

-- =============================================================================
-- 8. RestockItem(BatchId) — lô đã được châm vào phiếu nào
--    Dùng ở: truy vết lô (thu hồi hàng lỗi: lô X đã châm vào máy nào, lúc nào).
--    (UQ_inventory_RestockItem_Line bắt đầu bằng RestockId nên không dùng được.)
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_RestockItem_BatchId'
               AND object_id = OBJECT_ID(N'inventory.RestockItem'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_inventory_RestockItem_BatchId
        ON inventory.RestockItem (BatchId)
        INCLUDE (RestockId, SlotId, Qty);
    PRINT N'[30-inv] Đã tạo IX_inventory_RestockItem_BatchId.';
END
GO

-- =============================================================================
-- 9. UX Product(ProductName) WHERE IsDeleted = 0 — tên sản phẩm KHÔNG TRÙNG
--    Chặn trùng ở mức CSDL (kể cả khi chèn thẳng, không qua sp_AddProduct).
--    Collation Vietnamese_CI_AS → 'dưa hấu' và 'Dưa Hấu' tính là trùng.
--    Sản phẩm đã xóa mềm (IsDeleted = 1) được phép trùng tên với sản phẩm mới.
--    Dùng ở: sp_AddProduct / sp_UpdateProduct kiểm tra trùng tên (lỗi 50101).
--    Nếu dữ liệu đang có tên trùng → KHÔNG tạo, in cảnh báo để xử lý dữ liệu trước.
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_inventory_Product_Name'
               AND object_id = OBJECT_ID(N'inventory.Product'))
BEGIN
    IF EXISTS (SELECT ProductName FROM inventory.Product WHERE IsDeleted = 0
               GROUP BY ProductName HAVING COUNT(*) > 1)
        PRINT N'[30-inv] CẢNH BÁO: đang có tên sản phẩm trùng — chưa tạo UX_inventory_Product_Name.';
    ELSE
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX UX_inventory_Product_Name
            ON inventory.Product (ProductName)
            INCLUDE (IsActive)
            WHERE IsDeleted = 0;
        PRINT N'[30-inv] Đã tạo UX_inventory_Product_Name.';
    END
END
GO

-- =============================================================================
-- XÁC NHẬN: danh sách index của schema inventory
-- =============================================================================
SELECT OBJECT_NAME(i.object_id)  AS [Table],
       i.name                    AS [Index],
       i.type_desc               AS [Type],
       i.is_unique               AS [Unique],
       i.has_filter              AS [Filtered]
FROM   sys.indexes i
WHERE  OBJECT_SCHEMA_NAME(i.object_id) = N'inventory'
  AND  i.name IS NOT NULL
  AND  OBJECTPROPERTY(i.object_id, N'IsUserTable') = 1
ORDER  BY [Table], [Index];
GO

PRINT N'[30-inv] Hoàn tất index module inventory (FV-19).';
GO
