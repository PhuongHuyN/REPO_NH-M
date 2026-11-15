-- =============================================================================
-- FILE        : 08_seed_inventory.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV2 — Dữ liệu danh mục & tồn kho thực tế cho schema [inventory]
--               ▸ 4 nhà cung cấp, 4 danh mục
--               ▸ 36 sản phẩm FV-SP-001 … FV-SP-036 (027 Vải thiều: ngừng bán – hết mùa)
--               ▸ 5 máy (cùng mã với seed của TV5 – không tạo trùng) × 12 ngăn A1–C4,
--                 sức chứa 8 hộp/ngăn
--               ▸ Lô hàng theo sản phẩm (giờ làm, giờ hết hạn), tồn theo lô trong ngăn
--                 (SlotStock, FIFO), lịch sử nhập ngăn (StockMovement),
--                 phiếu châm hàng ca sáng (RestockEvent/RestockItem)
--               ▸ Có sẵn tình huống demo: ngăn sắp hết hàng (≤ 2 hộp), ngăn hết hàng,
--                 lô sắp hết hạn (< 6 giờ), 1 lô đã hết hạn còn trong ngăn
-- VERSION     : 1.0.0
-- CREATED     : 2026-11-07 — FV-02 (SCRUM-196)
-- RUN ORDER   : Sau 02_tables_inventory.sql (v1.1) và 03_foreign_keys.sql,
--               TRƯỚC 12_procs_sales.sql và 80/81_seed_* của TV5.
-- IDEMPOTENT  : MERGE theo khóa tự nhiên (TaxCode, CategoryName, SKU, MachineCode,
--               MachineId+SlotCode, BatchCode). Chạy lại không nhân đôi dữ liệu.
-- THỜI GIAN   : Lưu giờ UTC (SYSUTCDATETIME) — thống nhất với TV3. Giờ làm/hết hạn
--               tính tương đối theo lúc chạy script nên dữ liệu luôn "tươi".
-- =============================================================================

USE FreshVendDB;
GO

SET NOCOUNT ON;
PRINT N'[08-inv] ── Bắt đầu nạp dữ liệu inventory ──────────────────────────────';
GO

-- =============================================================================
-- 1. Nhà cung cấp
-- =============================================================================
MERGE inventory.Supplier AS tgt
USING (VALUES
    (N'Bếp trung tâm FreshVend Quận 7',            N'Trần Thị Mai',   N'028-3775-1201', N'bepq7@freshvend.vn',
     N'Lô B4, KCN Tân Thuận, P. Tân Thuận Đông, Quận 7, TP.HCM',          N'0318123401'),
    (N'Hợp tác xã Trái cây Cái Bè',                N'Lê Văn Hùng',    N'0273-3824-502', N'htx.caibe@gmail.com',
     N'Ấp Hậu Thành, xã Hậu Thành, huyện Cái Bè, Tiền Giang',              N'1201234502'),
    (N'Nông trại Đà Lạt Xanh',                     N'Phạm Ngọc Lan',  N'0263-3821-503', N'dalatxanh.farm@gmail.com',
     N'Thôn Đa Thọ, xã Xuân Thọ, TP. Đà Lạt, Lâm Đồng',                   N'5801234503'),
    (N'Công ty TNHH Nhập khẩu Trái cây Sao Việt',  N'Nguyễn Quốc Bảo',N'028-3911-6504', N'order@saovietfruit.vn',
     N'Số 18 Đường số 7, KCN Vĩnh Lộc, Bình Tân, TP.HCM',                  N'0312345604')
) AS src (SupplierName, ContactPerson, PhoneNumber, Email, Address, TaxCode)
ON tgt.TaxCode = src.TaxCode
WHEN NOT MATCHED THEN
    INSERT (SupplierName, ContactPerson, PhoneNumber, Email, Address, TaxCode)
    VALUES (src.SupplierName, src.ContactPerson, src.PhoneNumber, src.Email, src.Address, src.TaxCode);
PRINT N'[08-inv] 1. Supplier: xong (4 nhà cung cấp).';
GO

-- =============================================================================
-- 2. Danh mục
-- =============================================================================
MERGE inventory.Category AS tgt
USING (VALUES
    (N'Trái cây cắt sẵn',    N'Trái cây gọt vỏ, cắt miếng, đóng hộp trong ngày tại bếp trung tâm', 1),
    (N'Trái cây nguyên quả', N'Trái cây rửa sạch, để nguyên quả hoặc bóc vỏ, ăn ngay',             2),
    (N'Hộp trái cây trộn',   N'Hộp mix nhiều loại trái cây theo công thức của FreshVend',           3),
    (N'Sữa chua trái cây',   N'Sữa chua không đường kết hợp trái cây tươi',                         4)
) AS src (CategoryName, Description, DisplayOrder)
ON tgt.CategoryName = src.CategoryName
WHEN NOT MATCHED THEN
    INSERT (CategoryName, Description, DisplayOrder)
    VALUES (src.CategoryName, src.Description, src.DisplayOrder);
PRINT N'[08-inv] 2. Category: xong (4 danh mục).';
GO

-- =============================================================================
-- 3. Sản phẩm (36) — giá bán lẻ VNĐ/hộp, khối lượng tịnh (gram), hạn dùng (giờ)
--    Bảo quản 2–8 °C (chuỗi lạnh của máy). Ảnh: /img/products/fv-sp-XXX.jpg
-- =============================================================================
MERGE inventory.Product AS tgt
USING (
    SELECT src.SKU, src.ProductName, c.CategoryId, s.SupplierId, src.UnitPrice,
           src.WeightGram, src.ShelfLifeHours,
           CAST(CEILING(src.ShelfLifeHours / 24.0) AS SMALLINT) AS ShelfLifeDays,
           src.IsActive, src.Description,
           N'/img/products/' + LOWER(src.SKU) + N'.jpg' AS ImageUrl
    FROM (VALUES
     -- SKU          Tên sản phẩm                     Danh mục                 Mã số thuế NCC  Giá     Gram Giờ Bán  Mô tả
     (N'FV-SP-001', N'Dưa hấu ruột đỏ',              N'Trái cây cắt sẵn',     N'0318123401', 25000, 350, 24, 1, N'Dưa hấu Long An ruột đỏ, cắt khối vuông, ngọt mát'),
     (N'FV-SP-002', N'Dưa hấu ruột vàng',            N'Trái cây cắt sẵn',     N'0318123401', 29000, 350, 24, 1, N'Dưa hấu ruột vàng ít hạt, cắt khối, vị ngọt thanh'),
     (N'FV-SP-003', N'Xoài cát Hòa Lộc',             N'Trái cây cắt sẵn',     N'0318123401', 45000, 300, 24, 1, N'Xoài cát Hòa Lộc chín cây, cắt miếng, thơm ngọt đậm'),
     (N'FV-SP-004', N'Xoài keo xanh kèm muối ớt',    N'Trái cây cắt sẵn',     N'0318123401', 25000, 300, 48, 1, N'Xoài keo xanh giòn chua, cắt que, kèm gói muối ớt'),
     (N'FV-SP-005', N'Thơm mật Bến Lức',             N'Trái cây cắt sẵn',     N'0318123401', 25000, 350, 24, 1, N'Thơm mật Bến Lức gọt mắt, cắt miếng, ngọt mọng nước'),
     (N'FV-SP-006', N'Ổi xá lị',                     N'Trái cây cắt sẵn',     N'0318123401', 22000, 300, 48, 1, N'Ổi xá lị giòn, cắt múi cau, kèm gói muối ớt'),
     (N'FV-SP-007', N'Cam sành bóc múi',             N'Trái cây cắt sẵn',     N'0318123401', 35000, 300, 24, 1, N'Cam sành Vĩnh Long bóc sẵn múi, giàu vitamin C'),
     (N'FV-SP-008', N'Bưởi da xanh bóc múi',         N'Trái cây cắt sẵn',     N'0318123401', 45000, 300, 48, 1, N'Bưởi da xanh Bến Tre tách tép, ngọt, không đắng'),
     (N'FV-SP-009', N'Thanh long ruột đỏ',           N'Trái cây cắt sẵn',     N'0318123401', 30000, 350, 24, 1, N'Thanh long ruột đỏ Bình Thuận, cắt khối'),
     (N'FV-SP-010', N'Thanh long ruột trắng',        N'Trái cây cắt sẵn',     N'0318123401', 25000, 350, 24, 1, N'Thanh long ruột trắng, cắt khối, vị thanh mát'),
     (N'FV-SP-011', N'Dưa lưới Ruby',                N'Trái cây cắt sẵn',     N'0318123401', 39000, 300, 24, 1, N'Dưa lưới ruột cam Ruby, cắt khối, thơm ngọt'),
     (N'FV-SP-012', N'Dưa lưới Taki',                N'Trái cây cắt sẵn',     N'0318123401', 42000, 300, 24, 1, N'Dưa lưới Taki ruột xanh, giòn ngọt, cắt khối'),
     (N'FV-SP-013', N'Đu đủ ruột đỏ',                N'Trái cây cắt sẵn',     N'0318123401', 25000, 350, 24, 1, N'Đu đủ ruột đỏ chín cây, cắt khối mềm'),
     (N'FV-SP-014', N'Mít Thái múi',                 N'Trái cây cắt sẵn',     N'0318123401', 39000, 250, 48, 1, N'Múi mít Thái vàng giòn, đã bỏ hạt'),
     (N'FV-SP-015', N'Sầu riêng Ri6 múi',            N'Trái cây cắt sẵn',     N'0318123401', 89000, 250, 48, 1, N'Múi sầu riêng Ri6 cơm vàng, béo, hộp kín mùi'),
     (N'FV-SP-016', N'Táo xanh cắt lát',             N'Trái cây cắt sẵn',     N'0318123401', 35000, 250, 12, 1, N'Táo xanh cắt lát, ngâm chanh chống thâm'),
     (N'FV-SP-017', N'Lê Hàn Quốc cắt lát',          N'Trái cây cắt sẵn',     N'0318123401', 45000, 250, 12, 1, N'Lê Hàn Quốc cắt lát, giòn, mọng nước'),
     (N'FV-SP-018', N'Kiwi xanh cắt lát',            N'Trái cây cắt sẵn',     N'0318123401', 49000, 250, 24, 1, N'Kiwi xanh New Zealand gọt vỏ, cắt lát tròn'),
     (N'FV-SP-019', N'Cóc non kèm muối ớt',          N'Trái cây cắt sẵn',     N'0318123401', 22000, 300, 48, 1, N'Cóc non giòn, cắt miếng, kèm muối ớt'),
     (N'FV-SP-020', N'Mận hồng đào',                 N'Trái cây nguyên quả',  N'1201234502', 35000, 400, 72, 1, N'Mận hồng đào miền Tây, rửa sạch, nguyên quả'),
     (N'FV-SP-021', N'Nho xanh không hạt',           N'Trái cây nguyên quả',  N'0312345604', 59000, 300, 96, 1, N'Nho xanh không hạt nhập khẩu, tách quả, rửa sạch'),
     (N'FV-SP-022', N'Nho đỏ không hạt',             N'Trái cây nguyên quả',  N'0312345604', 65000, 300, 96, 1, N'Nho đỏ không hạt nhập khẩu, tách quả, rửa sạch'),
     (N'FV-SP-023', N'Dâu tây Đà Lạt',               N'Trái cây nguyên quả',  N'5801234503', 69000, 250, 48, 1, N'Dâu tây Đà Lạt chọn quả to, còn cuống'),
     (N'FV-SP-024', N'Chôm chôm Thái',               N'Trái cây nguyên quả',  N'1201234502', 35000, 500, 72, 1, N'Chôm chôm Thái tróc, cùi dày giòn'),
     (N'FV-SP-025', N'Măng cụt',                     N'Trái cây nguyên quả',  N'1201234502', 55000, 500, 72, 1, N'Măng cụt Lái Thiêu, khía sẵn vỏ dễ bóc'),
     (N'FV-SP-026', N'Nhãn xuồng',                   N'Trái cây nguyên quả',  N'1201234502', 39000, 500, 72, 1, N'Nhãn xuồng cơm vàng, cùi dày, ngọt'),
     (N'FV-SP-027', N'Vải thiều',                    N'Trái cây nguyên quả',  N'1201234502', 45000, 500, 72, 0, N'Vải thiều Lục Ngạn — tạm ngừng bán (hết mùa)'),
     (N'FV-SP-028', N'Việt quất',                    N'Trái cây nguyên quả',  N'0312345604', 79000, 125, 120, 1, N'Việt quất tươi nhập khẩu, hộp 125 g'),
     (N'FV-SP-029', N'Chuối Laba',                   N'Trái cây nguyên quả',  N'5801234503', 20000, 400, 72, 1, N'Chuối Laba Đà Lạt chín vàng, 3–4 trái'),
     (N'FV-SP-030', N'Quýt đường',                   N'Trái cây nguyên quả',  N'1201234502', 35000, 500, 96, 1, N'Quýt đường Lai Vung, vỏ mỏng, ngọt'),
     (N'FV-SP-031', N'Mix nhiệt đới',                N'Hộp trái cây trộn',    N'0318123401', 45000, 400, 24, 1, N'Xoài, thơm, đu đủ, thanh long ruột đỏ cắt khối'),
     (N'FV-SP-032', N'Mix dưa',                      N'Hộp trái cây trộn',    N'0318123401', 39000, 400, 24, 1, N'Dưa hấu đỏ, dưa hấu vàng, dưa lưới cắt khối'),
     (N'FV-SP-033', N'Mix vitamin C',                N'Hộp trái cây trộn',    N'0318123401', 49000, 400, 24, 1, N'Cam, bưởi, kiwi, ổi — giàu vitamin C'),
     (N'FV-SP-034', N'Mix eat-clean',                N'Hộp trái cây trộn',    N'0318123401', 55000, 400, 24, 1, N'Táo xanh, kiwi, nho, việt quất — ít ngọt'),
     (N'FV-SP-035', N'Sữa chua trái cây nhiệt đới',  N'Sữa chua trái cây',    N'0318123401', 35000, 250, 72, 1, N'Sữa chua không đường, xoài, thơm, chanh dây'),
     (N'FV-SP-036', N'Sữa chua dâu – việt quất',     N'Sữa chua trái cây',    N'0318123401', 39000, 250, 72, 1, N'Sữa chua không đường, dâu tây Đà Lạt, việt quất')
    ) AS src (SKU, ProductName, CategoryName, SupplierTax, UnitPrice, WeightGram, ShelfLifeHours, IsActive, Description)
    JOIN inventory.Category c ON c.CategoryName = src.CategoryName
    JOIN inventory.Supplier s ON s.TaxCode     = src.SupplierTax
) AS src
ON tgt.SKU = src.SKU
WHEN NOT MATCHED THEN
    INSERT (SKU, ProductName, CategoryId, SupplierId, UnitPrice, Unit, WeightGram, Description, ImageUrl,
            ShelfLifeDays, ShelfLifeHours, StorageTempMin, StorageTempMax, IsActive)
    VALUES (src.SKU, src.ProductName, src.CategoryId, src.SupplierId, src.UnitPrice, N'hộp', src.WeightGram,
            src.Description, src.ImageUrl, src.ShelfLifeDays, src.ShelfLifeHours, 2.0, 8.0, src.IsActive);
PRINT N'[08-inv] 3. Product: xong (36 sản phẩm, 35 đang bán).';
GO

-- =============================================================================
-- 4. Máy bán hàng — dùng ĐÚNG 5 mã máy trong seed của TV5 để không nhân đôi.
--    Chỉ nạp khi inventory.Machine còn là BẢNG. Nếu nhóm đã chuyển sang
--    iot.Machines (QĐ-1) và inventory.Machine là VIEW thì máy do TV4 nạp.
-- =============================================================================
IF OBJECT_ID(N'inventory.Machine', N'U') IS NOT NULL
BEGIN
    -- Chạy qua sp_executesql: khi inventory.Machine đã là VIEW, câu MERGE không bị
    -- biên dịch (tránh lỗi ngay cả khi nhánh IF này không chạy).
    EXEC sys.sp_executesql N'
    MERGE inventory.Machine AS tgt
    USING (VALUES
        (N''VM-BK-01'', N''Máy Bách Khoa 01'', N''Trường ĐH Bách Khoa TP.HCM — Cổng A'',          10.7730, 106.6592, N''online''),
        (N''VM-BK-02'', N''Máy Bách Khoa 02'', N''Trường ĐH Bách Khoa TP.HCM — Căng tin B2'',     10.7728, 106.6595, N''online''),
        (N''VM-VT-01'', N''Máy Vincom TD 01'', N''Vincom Thủ Đức — Tầng trệt, cạnh thang máy'',   10.8544, 106.7723, N''online''),
        (N''VM-VT-02'', N''Máy Vincom TD 02'', N''Vincom Thủ Đức — Tầng 2, khu ẩm thực'',         10.8542, 106.7720, N''maintenance''),
        (N''VM-CM-01'', N''Máy Coopmart 01'',  N''Siêu Thị Coopmart Nguyễn Đình Chiểu — Lối ra'', 10.7834, 106.6941, N''online'')
    ) AS src (MachineCode, MachineName, Location, Lat, Lon, Status)
    ON tgt.MachineCode = src.MachineCode
    WHEN NOT MATCHED THEN
        INSERT (MachineCode, MachineName, Location, Latitude, Longitude, Status, InstallDate)
        VALUES (src.MachineCode, src.MachineName, src.Location, src.Lat, src.Lon, src.Status, ''2026-09-01'');';
    PRINT N'[08-inv] 4. Machine: xong (5 máy).';
END
ELSE
    PRINT N'[08-inv] 4. Machine: bỏ qua — inventory.Machine không phải bảng (QĐ-1).';
GO

-- =============================================================================
-- 5. Ngăn hàng — mỗi máy 12 ngăn A1–A4, B1–B4, C1–C4, sức chứa 8 hộp.
--    Ngăn k của máy thứ m nhận sản phẩm đang bán thứ ((m-1)*7 + k - 1) % N + 1
--    (theo thứ tự SKU) → mỗi máy 12 món khác nhau, 5 máy phủ hết danh mục.
-- =============================================================================
;WITH m AS (
    SELECT MachineId, ROW_NUMBER() OVER (ORDER BY MachineCode) AS mrn
    FROM inventory.Machine
    WHERE MachineCode IN (N'VM-BK-01', N'VM-BK-02', N'VM-VT-01', N'VM-VT-02', N'VM-CM-01')
), k AS (
    SELECT k FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) AS v (k)
), p AS (
    SELECT ProductId, ROW_NUMBER() OVER (ORDER BY SKU) AS prn, COUNT(*) OVER () AS n
    FROM inventory.Product
    WHERE SKU LIKE N'FV-SP-%' AND IsActive = 1
)
MERGE inventory.Slot AS tgt
USING (
    SELECT m.MachineId,
           CAST(CHAR(64 + (k.k - 1) / 4 + 1) + CAST((k.k - 1) % 4 + 1 AS NCHAR(1)) AS NVARCHAR(10)) AS SlotCode,
           p.ProductId
    FROM m CROSS JOIN k
    JOIN p ON p.prn = ((m.mrn - 1) * 7 + k.k - 1) % p.n + 1
) AS src
ON tgt.MachineId = src.MachineId AND tgt.SlotCode = src.SlotCode
WHEN NOT MATCHED THEN
    INSERT (MachineId, SlotCode, ProductId, Capacity, CurrentStock, IsActive, UpdatedAt)
    VALUES (src.MachineId, src.SlotCode, src.ProductId, 8, 0, 1, SYSUTCDATETIME());
PRINT N'[08-inv] 5. Slot: xong (5 máy × 12 ngăn, sức chứa 8).';
GO

-- =============================================================================
-- 6. Lô hàng + tồn theo lô trong ngăn + lịch sử nhập ngăn
--    Chỉ nạp cho ngăn MỚI (CurrentStock = 0 và chưa có SlotStock) để chạy lại
--    không nhân đôi, và không đụng ngăn do seed khác tạo.
--    Mỗi sản phẩm có:
--      Lô A — làm 3 giờ trước, nạp ngăn 2 giờ trước, dư 10 hộp ở bếp để châm thêm
--      Lô B — làm 20 giờ trước (chỉ món hạn 24–48 giờ) → món 24 giờ sắp hết hạn (< 6 giờ)
--      Lô X — 1 hộp Dưa hấu ruột đỏ đã HẾT HẠN còn trong 1 ngăn (demo sp_RemoveExpired)
-- =============================================================================
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @now DATETIME2(0) = SYSUTCDATETIME();

    IF OBJECT_ID(N'tempdb..#plan') IS NOT NULL DROP TABLE #plan;

    -- Kế hoạch nạp cho từng ngăn mới
    ;WITH s AS (
        SELECT sl.SlotId, sl.ProductId, sl.Capacity,
               DENSE_RANK() OVER (ORDER BY mc.MachineCode) AS mrn,
               (ASCII(LEFT(sl.SlotCode, 1)) - 65) * 4 + ISNULL(TRY_CAST(RIGHT(sl.SlotCode, 1) AS INT), 0) AS k
        FROM inventory.Slot sl
        JOIN inventory.Machine mc ON mc.MachineId = sl.MachineId
        WHERE mc.MachineCode IN (N'VM-BK-01', N'VM-BK-02', N'VM-VT-01', N'VM-VT-02', N'VM-CM-01')
          AND sl.SlotCode LIKE N'[A-C][1-4]'
          AND sl.ProductId IS NOT NULL
          AND sl.CurrentStock = 0
          AND NOT EXISTS (SELECT 1 FROM inventory.SlotStock ss WHERE ss.SlotId = sl.SlotId)
    ), t AS (
        -- Tổng số hộp mỗi ngăn: có ngăn đầy, ngăn vừa, ngăn sắp hết (1–2), ngăn hết (0)
        SELECT s.SlotId, s.ProductId, s.Capacity, p.SKU, p.ShelfLifeHours,
               CASE WHEN (s.mrn * 12 + s.k) % 11 = 0 THEN 0
                    ELSE CHOOSE((s.mrn * 12 + s.k) % 6 + 1, 2, 8, 6, 5, 7, 1) END AS Total
        FROM s JOIN inventory.Product p ON p.ProductId = s.ProductId
    )
    SELECT t.SlotId, t.ProductId, t.SKU, t.ShelfLifeHours,
           CASE WHEN t.Total > t.Capacity THEN t.Capacity ELSE t.Total END AS Total,
           CAST(0 AS SMALLINT) AS QtyA, CAST(0 AS SMALLINT) AS QtyB, CAST(0 AS SMALLINT) AS QtyX
    INTO #plan
    FROM t;

    -- Lô B (cũ hơn, nạp trước) cho món hạn 24–48 giờ, ngăn có từ 5 hộp
    UPDATE #plan SET QtyB = 2 WHERE Total >= 5 AND ShelfLifeHours BETWEEN 24 AND 48;
    UPDATE #plan SET QtyA = Total - QtyB;

    -- Lô X: 1 hộp Dưa hấu ruột đỏ đã hết hạn ở ngăn đầu tiên có món này (còn chỗ)
    UPDATE p SET QtyX = 1
    FROM #plan p
    WHERE p.SlotId = (SELECT MIN(SlotId) FROM #plan WHERE SKU = N'FV-SP-001' AND Total BETWEEN 1 AND 7);

    -- 6a. Lô hàng (MERGE theo BatchCode)
    MERGE inventory.StockBatch AS tgt
    USING (
        SELECT p.ProductId, pr.SupplierId,
               N'LOT-SEED-' + p.SKU + N'-' + l.Suffix AS BatchCode,
               SUM(CASE l.Suffix WHEN N'A' THEN p.QtyA WHEN N'B' THEN p.QtyB ELSE p.QtyX END)
                 + CASE l.Suffix WHEN N'A' THEN 10 ELSE 0 END                         AS Quantity,
               CAST(ROUND(pr.UnitPrice * 0.55, -3) AS DECIMAL(12,2))                  AS UnitCost,
               DATEADD(HOUR, -l.AgeHours, @now)                                       AS PreparedAt,
               DATEADD(HOUR, p.ShelfLifeHours - l.AgeHours, @now)                     AS ExpiryAt,
               l.Note
        FROM #plan p
        JOIN inventory.Product pr ON pr.ProductId = p.ProductId
        CROSS JOIN (VALUES (N'A', 3,  N'Lô làm trong ngày tại bếp trung tâm (dữ liệu mẫu)'),
                           (N'B', 20, N'Lô làm hôm qua (dữ liệu mẫu)'),
                           (N'X', 30, N'Lô quá hạn còn trong ngăn — demo rút hàng hết hạn (dữ liệu mẫu)')
                   ) AS l (Suffix, AgeHours, Note)
        GROUP BY p.ProductId, pr.SupplierId, pr.UnitPrice, p.SKU, p.ShelfLifeHours, l.Suffix, l.AgeHours, l.Note
        HAVING SUM(CASE l.Suffix WHEN N'A' THEN p.QtyA WHEN N'B' THEN p.QtyB ELSE p.QtyX END)
                 + CASE l.Suffix WHEN N'A' THEN 10 ELSE 0 END > 0
    ) AS src
    ON tgt.BatchCode = src.BatchCode
    WHEN NOT MATCHED THEN
        INSERT (ProductId, SupplierId, BatchCode, Quantity, UnitCost, ImportDate, ExpiryDate,
                PreparedAt, ExpiryAt, Note)
        VALUES (src.ProductId, src.SupplierId, src.BatchCode, src.Quantity, src.UnitCost,
                CAST(src.PreparedAt AS DATE), CAST(src.ExpiryAt AS DATE),
                src.PreparedAt, src.ExpiryAt, src.Note);

    -- 6b. Tồn theo lô trong ngăn (LoadedAt cũ hơn = bán trước theo FIFO)
    INSERT inventory.SlotStock (SlotId, BatchId, Quantity, LoadedAt)
    SELECT p.SlotId, b.BatchId, v.Qty, DATEADD(HOUR, -v.LoadedAgo, @now)
    FROM #plan p
    CROSS APPLY (VALUES (N'X', p.QtyX, 29), (N'B', p.QtyB, 19), (N'A', p.QtyA, 2)) AS v (Suffix, Qty, LoadedAgo)
    JOIN inventory.StockBatch b ON b.BatchCode = N'LOT-SEED-' + p.SKU + N'-' + v.Suffix
    WHERE v.Qty > 0;

    -- 6c. Lịch sử nhập ngăn
    INSERT inventory.StockMovement (SlotId, BatchId, MovementType, Quantity, Reason, CreatedAt)
    SELECT ss.SlotId, ss.BatchId, N'IN', ss.Quantity,
           N'Nạp ngăn từ lô ' + b.BatchCode + N' (dữ liệu mẫu)', ss.LoadedAt
    FROM inventory.SlotStock ss
    JOIN #plan p ON p.SlotId = ss.SlotId
    JOIN inventory.StockBatch b ON b.BatchId = ss.BatchId;

    -- 6d. Đồng bộ tồn tổng của ngăn = tổng tồn theo lô
    UPDATE sl
    SET    CurrentStock = x.Qty, UpdatedAt = @now
    FROM   inventory.Slot sl
    JOIN  (SELECT ss.SlotId, SUM(ss.Quantity) AS Qty
           FROM inventory.SlotStock ss JOIN #plan p ON p.SlotId = ss.SlotId
           GROUP BY ss.SlotId) x ON x.SlotId = sl.SlotId;

    COMMIT TRANSACTION;
    DECLARE @loaded INT = (SELECT COUNT(*) FROM #plan);
    PRINT N'[08-inv] 6. StockBatch / SlotStock / StockMovement: xong ('
          + CAST(@loaded AS NVARCHAR(10)) + N' ngăn được nạp).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'[08-inv] LỖI ở bước 6 — đã hoàn tác toàn bộ bước 6.';
    THROW;
END CATCH;
GO

-- =============================================================================
-- 7. Phiếu châm hàng ca sáng — 1 phiếu/máy, gồm các dòng nạp từ lô A.
--    Cần có ít nhất 1 tài khoản trong auth.[User] (người châm hàng).
--    Nếu chưa có tài khoản (seed tài khoản chạy sau) → bỏ qua; chạy lại file này
--    sau khi có tài khoản thì phiếu sẽ được tạo.
-- =============================================================================
SET XACT_ABORT ON;
DECLARE @op INT = (SELECT TOP (1) UserId FROM auth.[User] ORDER BY UserId);

IF @op IS NULL
    PRINT N'[08-inv] 7. RestockEvent: bỏ qua — chưa có tài khoản trong auth.[User].';
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ev TABLE (RestockId INT, MachineId INT);

        INSERT inventory.RestockEvent (MachineId, UserId, RestockedAt, Note)
        OUTPUT inserted.RestockId, inserted.MachineId INTO @ev
        SELECT mc.MachineId, @op, MIN(ss.LoadedAt), N'Châm hàng ca sáng (dữ liệu mẫu)'
        FROM inventory.Machine mc
        JOIN inventory.Slot sl        ON sl.MachineId = mc.MachineId
        JOIN inventory.SlotStock ss   ON ss.SlotId    = sl.SlotId
        JOIN inventory.StockBatch b   ON b.BatchId    = ss.BatchId AND b.BatchCode LIKE N'LOT-SEED-%-A'
        WHERE mc.MachineCode IN (N'VM-BK-01', N'VM-BK-02', N'VM-VT-01', N'VM-VT-02', N'VM-CM-01')
          AND NOT EXISTS (SELECT 1 FROM inventory.RestockEvent re
                          WHERE re.MachineId = mc.MachineId AND re.Note = N'Châm hàng ca sáng (dữ liệu mẫu)')
        GROUP BY mc.MachineId;

        INSERT inventory.RestockItem (RestockId, SlotId, BatchId, Qty)
        SELECT e.RestockId, ss.SlotId, ss.BatchId, ss.Quantity
        FROM @ev e
        JOIN inventory.Slot sl      ON sl.MachineId = e.MachineId
        JOIN inventory.SlotStock ss ON ss.SlotId    = sl.SlotId
        JOIN inventory.StockBatch b ON b.BatchId    = ss.BatchId AND b.BatchCode LIKE N'LOT-SEED-%-A'
        WHERE ss.Quantity BETWEEN 1 AND 20;

        COMMIT TRANSACTION;
        DECLARE @evCount INT = (SELECT COUNT(*) FROM @ev);
        PRINT N'[08-inv] 7. RestockEvent/RestockItem: xong ('
              + CAST(@evCount AS NVARCHAR(10)) + N' phiếu mới).';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT N'[08-inv] LỖI ở bước 7 — đã hoàn tác bước 7.';
        THROW;
    END CATCH;
END
GO

-- =============================================================================
-- 8. Tổng kết
-- =============================================================================
SELECT N'Supplier'      AS [Bảng], COUNT(*) AS [Số dòng] FROM inventory.Supplier
UNION ALL SELECT N'Category',      COUNT(*) FROM inventory.Category
UNION ALL SELECT N'Product',       COUNT(*) FROM inventory.Product
UNION ALL SELECT N'Machine',       COUNT(*) FROM inventory.Machine
UNION ALL SELECT N'Slot',          COUNT(*) FROM inventory.Slot
UNION ALL SELECT N'StockBatch',    COUNT(*) FROM inventory.StockBatch
UNION ALL SELECT N'SlotStock',     COUNT(*) FROM inventory.SlotStock
UNION ALL SELECT N'StockMovement', COUNT(*) FROM inventory.StockMovement
UNION ALL SELECT N'RestockEvent',  COUNT(*) FROM inventory.RestockEvent
UNION ALL SELECT N'RestockItem',   COUNT(*) FROM inventory.RestockItem;
GO

PRINT N'[08-inv] ── Hoàn tất dữ liệu inventory ────────────────────────────────';
GO
