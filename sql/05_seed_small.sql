-- =============================================================================
-- FILE        : 05_seed_small.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : Dữ liệu mẫu NHỎ — dành cho kiểm thử nhanh (tuần 1 sprint)
--               ▸ 2 vai trò, 3 người dùng
--               ▸ 1 nhà cung cấp, 2 danh mục
--               ▸ 10 sản phẩm
--               ▸ 3 địa điểm, 5 máy (mỗi máy 4 ngăn)
--               ▸ 50 đơn hàng đã hoàn thành (status = 'paid') + 50 OrderItem
--               ▸ 50 Payment tương ứng
--               ▸ Seed report.DailySalesSummary, report.ExportLogs, report.TestResults
-- VERSION     : 1.0.0
-- CREATED     : 2026-10-21
-- RUN ORDER   : Bước 5 — sau khi chạy xong 00→04
-- IDEMPOTENT  : Dùng MERGE hoặc IF NOT EXISTS — chạy lại không bị lỗi trùng khóa
-- =============================================================================

USE FreshVendDB;
GO

SET NOCOUNT ON;
PRINT N'[05-small] ── Bắt đầu nạp seed data nhỏ ──────────────────────────────';
GO

-- =============================================================================
-- PHẦN A — auth: Roles & Users
-- =============================================================================

-- ── A1. Roles ────────────────────────────────────────────────────────────────
MERGE auth.Role AS tgt
USING (VALUES
    (N'Admin',      N'Quản trị hệ thống toàn quyền'),
    (N'Operator',   N'Vận hành máy bán hàng hằng ngày'),
    (N'Viewer',     N'Chỉ xem báo cáo')
) AS src (RoleName, Description)
ON tgt.RoleName = src.RoleName
WHEN NOT MATCHED THEN
    INSERT (RoleName, Description)
    VALUES (src.RoleName, src.Description);

PRINT N'[05-small] A1. Roles: xong (' + CAST(@@ROWCOUNT AS NVARCHAR) + N' dòng mới).';
GO

-- ── A2. Users ────────────────────────────────────────────────────────────────
-- PasswordHash là placeholder (bcrypt của "Password@123")
MERGE auth.[User] AS tgt
USING (VALUES
    (N'admin01',    N'$2b$10$KIXmMvP1u8Zrp3gQ.placeholderAdminHash',   N'Nguyễn Quản Trị', N'admin01@freshvend.local'),
    (N'operator01', N'$2b$10$KIXmMvP1u8Zrp3gQ.placeholderOpsHash1',   N'Trần Vận Hành',   N'op01@freshvend.local'),
    (N'viewer01',   N'$2b$10$KIXmMvP1u8Zrp3gQ.placeholderViewHash1',  N'Lê Xem Báo Cáo',  N'view01@freshvend.local')
) AS src (Username, PasswordHash, FullName, Email)
ON tgt.Username = src.Username
WHEN NOT MATCHED THEN
    INSERT (Username, PasswordHash, FullName, Email)
    VALUES (src.Username, src.PasswordHash, src.FullName, src.Email);

PRINT N'[05-small] A2. Users: xong.';
GO

-- ── A3. UserRole ─────────────────────────────────────────────────────────────
MERGE auth.UserRole AS tgt
USING (
    SELECT u.UserId, r.RoleId
    FROM (VALUES
        (N'admin01',    N'Admin'),
        (N'operator01', N'Operator'),
        (N'viewer01',   N'Viewer')
    ) AS m(Username, RoleName)
    JOIN auth.[User] u ON u.Username = m.Username
    JOIN auth.Role   r ON r.RoleName = m.RoleName
) AS src (UserId, RoleId)
ON tgt.UserId = src.UserId AND tgt.RoleId = src.RoleId
WHEN NOT MATCHED THEN
    INSERT (UserId, RoleId) VALUES (src.UserId, src.RoleId);

PRINT N'[05-small] A3. UserRole: xong.';
GO

-- =============================================================================
-- PHẦN B — inventory: Supplier, Category, Product
-- =============================================================================

-- ── B1. Supplier ─────────────────────────────────────────────────────────────
MERGE inventory.Supplier AS tgt
USING (VALUES
    (N'Vườn Trái Cây Đà Lạt', N'Nguyễn Văn An', N'0251-3812345', N'supplier@dalat.vn', N'Thành phố Đà Lạt, Lâm Đồng', N'5901234567')
) AS src (SupplierName, ContactPerson, PhoneNumber, Email, Address, TaxCode)
ON tgt.TaxCode = src.TaxCode
WHEN NOT MATCHED THEN
    INSERT (SupplierName, ContactPerson, PhoneNumber, Email, Address, TaxCode)
    VALUES (src.SupplierName, src.ContactPerson, src.PhoneNumber, src.Email, src.Address, src.TaxCode);

PRINT N'[05-small] B1. Supplier: xong.';
GO

-- ── B2. Category ─────────────────────────────────────────────────────────────
MERGE inventory.Category AS tgt
USING (VALUES
    (N'Trái Cây Nhiệt Đới', N'Xoài, dứa, ổi, chuối…'),
    (N'Trái Cây Ôn Đới',    N'Táo, lê, nho, mận…')
) AS src (CategoryName, Description)
ON tgt.CategoryName = src.CategoryName
WHEN NOT MATCHED THEN
    INSERT (CategoryName, Description)
    VALUES (src.CategoryName, src.Description);

PRINT N'[05-small] B2. Category: xong.';
GO

-- ── B3. Product (10 sản phẩm) ────────────────────────────────────────────────
MERGE inventory.Product AS tgt
USING (
    SELECT
        src.SKU, src.ProductName,
        c.CategoryId,
        s.SupplierId,
        src.UnitPrice, src.Unit, src.ShelfLifeDays,
        src.StorageTempMin, src.StorageTempMax
    FROM (VALUES
        (N'FV-001', N'Chuối Tiêu Đà Lạt',     N'Trái Cây Nhiệt Đới', 15000.00, N'nải',  7,  13.0, 18.0),
        (N'FV-002', N'Xoài Cát Chu',           N'Trái Cây Nhiệt Đới', 35000.00, N'kg',   5,  10.0, 16.0),
        (N'FV-003', N'Ổi Lê Đài Loan',         N'Trái Cây Nhiệt Đới', 25000.00, N'quả',  6,  10.0, 15.0),
        (N'FV-004', N'Dứa Queen',              N'Trái Cây Nhiệt Đới', 20000.00, N'quả',  4,   8.0, 14.0),
        (N'FV-005', N'Thanh Long Ruột Đỏ',     N'Trái Cây Nhiệt Đới', 30000.00, N'quả',  5,  10.0, 15.0),
        (N'FV-006', N'Táo Fuji Nhật',          N'Trái Cây Ôn Đới',    45000.00, N'quả', 14,   2.0,  8.0),
        (N'FV-007', N'Lê Xanh Hàn Quốc',      N'Trái Cây Ôn Đới',    40000.00, N'quả', 10,   2.0,  8.0),
        (N'FV-008', N'Nho Đỏ Seedless',        N'Trái Cây Ôn Đới',    85000.00, N'chùm', 7,   2.0,  6.0),
        (N'FV-009', N'Cam Sành Vĩnh Long',     N'Trái Cây Nhiệt Đới', 18000.00, N'quả',  7,   8.0, 14.0),
        (N'FV-010', N'Bưởi Da Xanh Bến Tre',   N'Trái Cây Nhiệt Đới', 55000.00, N'quả', 10,   8.0, 14.0)
    ) AS src (SKU, ProductName, CatName, UnitPrice, Unit, ShelfLifeDays, TempMin, TempMax)
    JOIN inventory.Category c ON c.CategoryName = src.CatName
    CROSS JOIN (SELECT TOP 1 SupplierId FROM inventory.Supplier) s
) AS src (SKU, ProductName, CategoryId, SupplierId, UnitPrice, Unit, ShelfLifeDays, StorageTempMin, StorageTempMax)
ON tgt.SKU = src.SKU
WHEN NOT MATCHED THEN
    INSERT (SKU, ProductName, CategoryId, SupplierId, UnitPrice, Unit, ShelfLifeDays, StorageTempMin, StorageTempMax)
    VALUES (src.SKU, src.ProductName, src.CategoryId, src.SupplierId, src.UnitPrice, src.Unit, src.ShelfLifeDays, src.StorageTempMin, src.StorageTempMax);

PRINT N'[05-small] B3. Product: xong (10 sản phẩm).';
GO

-- =============================================================================
-- PHẦN C — inventory: Machine (5 máy tại 3 địa điểm)
-- =============================================================================

-- 3 địa điểm đặt máy được mã hóa vào tên máy và Location:
--   ▸ Địa điểm 1: "ĐH Bách Khoa HCM" → VM-BK-01, VM-BK-02
--   ▸ Địa điểm 2: "Vincom Thủ Đức"   → VM-VT-01, VM-VT-02
--   ▸ Địa điểm 3: "Siêu Thị Coopmart" → VM-CM-01

MERGE inventory.Machine AS tgt
USING (VALUES
    (N'VM-BK-01', N'Máy Bách Khoa 01', N'Trường ĐH Bách Khoa TP.HCM — Cổng A',           10.7730, 106.6592, N'online'),
    (N'VM-BK-02', N'Máy Bách Khoa 02', N'Trường ĐH Bách Khoa TP.HCM — Căng tin B2',      10.7728, 106.6595, N'online'),
    (N'VM-VT-01', N'Máy Vincom TD 01', N'Vincom Thủ Đức — Tầng trệt, cạnh thang máy',    10.8544, 106.7723, N'online'),
    (N'VM-VT-02', N'Máy Vincom TD 02', N'Vincom Thủ Đức — Tầng 2, khu ẩm thực',          10.8542, 106.7720, N'maintenance'),
    (N'VM-CM-01', N'Máy Coopmart 01',  N'Siêu Thị Coopmart Nguyễn Đình Chiểu — Lối ra',  10.7834, 106.6941, N'online')
) AS src (MachineCode, MachineName, Location, Lat, Lon, Status)
ON tgt.MachineCode = src.MachineCode
WHEN NOT MATCHED THEN
    INSERT (MachineCode, MachineName, Location, Latitude, Longitude, Status, InstallDate)
    VALUES (src.MachineCode, src.MachineName, src.Location, src.Lat, src.Lon, src.Status, '2026-09-01');

PRINT N'[05-small] C. Machine: xong (5 máy, 3 địa điểm).';
GO

-- =============================================================================
-- PHẦN D — inventory: Slot (mỗi máy 4 ngăn A1–A4 → tổng 20 slot)
-- =============================================================================

MERGE inventory.Slot AS tgt
USING (
    SELECT
        m.MachineId,
        N'A' + CAST(gs.value AS NVARCHAR(1)) AS SlotCode,
        p.ProductId,
        CAST(20 AS SMALLINT)                  AS Capacity,
        CAST(15 AS SMALLINT)                  AS CurrentStock
    FROM inventory.Machine m
    CROSS JOIN GENERATE_SERIES(1, 4) AS gs          -- SQL Server 2022
    JOIN (
        -- Gán sản phẩm luân phiên theo vị trí ngăn (slot 1→4 → product 1→4)
        SELECT ProductId, ROW_NUMBER() OVER (ORDER BY ProductId) AS rn
        FROM inventory.Product
        WHERE IsActive = 1
    ) p ON p.rn = gs.value
    WHERE m.MachineCode IN (N'VM-BK-01', N'VM-BK-02', N'VM-VT-01', N'VM-VT-02', N'VM-CM-01')
) AS src (MachineId, SlotCode, ProductId, Capacity, CurrentStock)
ON tgt.MachineId = src.MachineId AND tgt.SlotCode = src.SlotCode
WHEN NOT MATCHED THEN
    INSERT (MachineId, SlotCode, ProductId, Capacity, CurrentStock)
    VALUES (src.MachineId, src.SlotCode, src.ProductId, src.Capacity, src.CurrentStock);

PRINT N'[05-small] D. Slot: xong (20 ngăn — 4 ngăn/máy).';
GO

-- =============================================================================
-- PHẦN E — sales: 50 Order + OrderItem + Payment
-- =============================================================================
-- Dùng GENERATE_SERIES để sinh 50 đơn hàng trong 7 ngày gần nhất.
-- Mỗi đơn có 1 OrderItem (1 sản phẩm ngẫu nhiên) và 1 Payment.

-- ── E1. Order ────────────────────────────────────────────────────────────────

INSERT INTO sales.[Order] (OrderCode, MachineId, CustomerId, Subtotal, TotalAmount, Status, CreatedAt)
SELECT
    N'ORD-SM-' + RIGHT('0000' + CAST(gs.value AS NVARCHAR(4)), 4)   AS OrderCode,
    -- Phân phối đơn hàng đều cho 5 máy (value % 5 → 0..4, cộng offset MachineId)
    m.MachineId,
    NULL                                                              AS CustomerId, -- khách vãng lai
    p.UnitPrice * 1                                                   AS Subtotal,
    p.UnitPrice * 1                                                   AS TotalAmount,
    N'paid'                                                           AS Status,
    -- Tạo ra trong 7 ngày gần nhất, trải đều theo thời gian
    DATEADD(HOUR,
        -( (gs.value - 1) * 3 ),                -- cách nhau ~3 giờ
        DATEADD(DAY, -7, CAST(GETDATE() AS DATETIME2))
    )                                                                  AS CreatedAt
FROM GENERATE_SERIES(1, 50) AS gs
-- Chọn máy: luân phiên theo gs.value % 5
JOIN (
    SELECT MachineId, ROW_NUMBER() OVER (ORDER BY MachineId) - 1 AS rn
    FROM inventory.Machine
    WHERE MachineCode IN (N'VM-BK-01',N'VM-BK-02',N'VM-VT-01',N'VM-VT-02',N'VM-CM-01')
) m ON m.rn = (gs.value - 1) % 5
-- Chọn sản phẩm: luân phiên theo gs.value % 10
JOIN (
    SELECT ProductId, UnitPrice, ROW_NUMBER() OVER (ORDER BY ProductId) - 1 AS rn
    FROM inventory.Product
    WHERE IsActive = 1
) p ON p.rn = (gs.value - 1) % 10
WHERE NOT EXISTS (
    SELECT 1 FROM sales.[Order]
    WHERE OrderCode = N'ORD-SM-' + RIGHT('0000' + CAST(gs.value AS NVARCHAR(4)), 4)
);

PRINT N'[05-small] E1. Order: xong (50 đơn hàng).';
GO

-- ── E2. OrderItem (1 item/đơn, dùng slot tương ứng với sản phẩm) ─────────────

INSERT INTO sales.OrderItem (OrderId, SlotId, ProductId, Quantity, UnitPrice)
SELECT
    o.OrderId,
    sl.SlotId,
    o_prod.ProductId,
    1                   AS Quantity,
    o_prod.UnitPrice
FROM sales.[Order] o
-- Xác định ProductId từ TotalAmount (= UnitPrice * 1)
JOIN inventory.Product o_prod
    ON o_prod.UnitPrice = o.TotalAmount
    AND o_prod.IsActive = 1
-- Lấy slot đầu tiên của máy có chứa sản phẩm đó
JOIN inventory.Slot sl
    ON sl.MachineId  = o.MachineId
    AND sl.ProductId = o_prod.ProductId
WHERE o.OrderCode LIKE N'ORD-SM-%'
  AND NOT EXISTS (
      SELECT 1 FROM sales.OrderItem oi WHERE oi.OrderId = o.OrderId
  );

PRINT N'[05-small] E2. OrderItem: xong.';
GO

-- ── E3. Payment ───────────────────────────────────────────────────────────────

INSERT INTO sales.Payment (OrderId, PaymentMethod, Amount, Status, PaidAt)
SELECT
    o.OrderId,
    CASE (o.OrderId % 3)
        WHEN 0 THEN N'QRCODE'
        WHEN 1 THEN N'CASH'
        ELSE         N'EWALLET'
    END             AS PaymentMethod,
    o.TotalAmount   AS Amount,
    N'success'      AS Status,
    o.CreatedAt     AS PaidAt
FROM sales.[Order] o
WHERE o.OrderCode LIKE N'ORD-SM-%'
  AND NOT EXISTS (
      SELECT 1 FROM sales.Payment py WHERE py.OrderId = o.OrderId
  );

PRINT N'[05-small] E3. Payment: xong (50 bản ghi).';
GO

-- =============================================================================
-- PHẦN F — report: DailySalesSummary (tóm tắt từ 50 đơn hàng)
-- =============================================================================

MERGE report.DailySalesSummary AS tgt
USING (
    SELECT
        CAST(o.CreatedAt AS DATE)   AS SummaryDate,
        o.MachineId,
        oi.ProductId,
        COUNT(DISTINCT o.OrderId)   AS OrderCount,
        SUM(oi.Quantity)            AS QtySold,
        SUM(oi.LineTotal)           AS Revenue,
        0.00                        AS TotalDiscount,
        AVG(oi.UnitPrice)           AS AvgUnitPrice
    FROM sales.[Order] o
    JOIN sales.OrderItem oi ON oi.OrderId = o.OrderId
    WHERE o.OrderCode LIKE N'ORD-SM-%'
      AND o.Status = N'paid'
    GROUP BY CAST(o.CreatedAt AS DATE), o.MachineId, oi.ProductId
) AS src
ON  tgt.SummaryDate = src.SummaryDate
AND tgt.MachineId   = src.MachineId
AND tgt.ProductId   = src.ProductId
WHEN MATCHED THEN
    UPDATE SET
        tgt.QtySold       = src.QtySold,
        tgt.Revenue       = src.Revenue,
        tgt.OrderCount    = src.OrderCount,
        tgt.TotalDiscount = src.TotalDiscount,
        tgt.AvgUnitPrice  = src.AvgUnitPrice,
        tgt.RefreshedAt   = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (SummaryDate, MachineId, ProductId, QtySold, Revenue, OrderCount, TotalDiscount, AvgUnitPrice)
    VALUES (src.SummaryDate, src.MachineId, src.ProductId, src.QtySold, src.Revenue, src.OrderCount, src.TotalDiscount, src.AvgUnitPrice);

PRINT N'[05-small] F. DailySalesSummary: xong.';
GO

-- =============================================================================
-- PHẦN G — report: ExportLogs (3 bản ghi mẫu)
-- =============================================================================

INSERT INTO report.ExportLogs (UserId, ReportName, Params, FileFormat, FileSizeBytes, RowCount, DurationMs, Status)
SELECT
    u.UserId,
    src.ReportName,
    src.Params,
    src.FileFormat,
    src.FileSizeBytes,
    src.RowCount,
    src.DurationMs,
    N'SUCCESS'
FROM (VALUES
    (N'admin01',    N'DailySales',       N'{"from":"2026-10-15","to":"2026-10-21"}', N'EXCEL', 48200,  7,  320),
    (N'operator01', N'MachineStock',     N'{"machineId":1}',                         N'PDF',   25600,  5,  210),
    (N'viewer01',   N'ProductSalesRank', N'{"month":"2026-10"}',                     N'CSV',   12400, 10,  150)
) AS src (Username, ReportName, Params, FileFormat, FileSizeBytes, RowCount, DurationMs)
JOIN auth.[User] u ON u.Username = src.Username
WHERE NOT EXISTS (
    SELECT 1 FROM report.ExportLogs el
    WHERE el.UserId = u.UserId AND el.ReportName = src.ReportName
);

PRINT N'[05-small] G. ExportLogs: xong (3 bản ghi).';
GO

-- =============================================================================
-- PHẦN H — report: TestResults (seed các test case cơ bản đã PASS)
-- =============================================================================

INSERT INTO report.TestResults (Module, TestCase, Expected, Actual, Passed, DurationMs, RunBy)
SELECT src.Module, src.TestCase, src.Expected, src.Actual, 1, src.DurationMs, N'05_seed_small.sql'
FROM (VALUES
    (N'auth',      N'TC-AUTH-01: Tạo user hợp lệ',           N'INSERT thành công',         N'1 row affected',   12),
    (N'auth',      N'TC-AUTH-02: Email trùng bị từ chối',     N'Lỗi unique constraint',     N'Msg 2627',         8),
    (N'auth',      N'TC-AUTH-03: Email sai định dạng',        N'Lỗi CHECK constraint',      N'Msg 547',          7),
    (N'inventory', N'TC-INV-01: Tạo nhà cung cấp',           N'INSERT thành công',         N'1 row affected',   10),
    (N'inventory', N'TC-INV-02: Giá sản phẩm âm bị từ chối', N'Lỗi CHECK UnitPrice >= 0',  N'Msg 547',          9),
    (N'sales',     N'TC-SALES-01: Đơn hàng trạng thái hợp lệ',N'INSERT thành công',        N'1 row affected',   11),
    (N'sales',     N'TC-SALES-02: Status không hợp lệ',      N'Lỗi CHECK constraint',      N'Msg 547',          8),
    (N'report',    N'TC-RPT-01: Seed DailySalesSummary',      N'Rows > 0',                  N'Rows inserted',    15),
    (N'report',    N'TC-RPT-02: Trùng (date,machine,product)',N'Lỗi PRIMARY KEY violation', N'Msg 2627',         6)
) AS src (Module, TestCase, Expected, Actual, DurationMs)
WHERE NOT EXISTS (
    SELECT 1 FROM report.TestResults tr
    WHERE tr.Module = src.Module AND tr.TestCase = src.TestCase
      AND tr.RunBy = N'05_seed_small.sql'
);

PRINT N'[05-small] H. TestResults: xong (9 test cases — tất cả PASS).';
GO

-- =============================================================================
-- XÁC NHẬN KẾT QUẢ
-- =============================================================================

SELECT 'auth.User'                  AS [Table], COUNT(*) AS [Rows] FROM auth.[User]
UNION ALL SELECT 'auth.Role',                              COUNT(*) FROM auth.Role
UNION ALL SELECT 'inventory.Supplier',                    COUNT(*) FROM inventory.Supplier
UNION ALL SELECT 'inventory.Category',                    COUNT(*) FROM inventory.Category
UNION ALL SELECT 'inventory.Product',                     COUNT(*) FROM inventory.Product
UNION ALL SELECT 'inventory.Machine',                     COUNT(*) FROM inventory.Machine
UNION ALL SELECT 'inventory.Slot',                        COUNT(*) FROM inventory.Slot
UNION ALL SELECT 'sales.Order (paid)',
    COUNT(*) FROM sales.[Order] WHERE Status = N'paid'
UNION ALL SELECT 'sales.OrderItem',                       COUNT(*) FROM sales.OrderItem
UNION ALL SELECT 'sales.Payment',                         COUNT(*) FROM sales.Payment
UNION ALL SELECT 'report.DailySalesSummary',              COUNT(*) FROM report.DailySalesSummary
UNION ALL SELECT 'report.ExportLogs',                     COUNT(*) FROM report.ExportLogs
UNION ALL SELECT 'report.TestResults',                    COUNT(*) FROM report.TestResults
ORDER BY [Table];
GO

PRINT N'';
PRINT N'================================================================';
PRINT N'  05_seed_small.sql hoàn tất. Dữ liệu sẵn sàng kiểm thử nhanh.';
PRINT N'================================================================';
GO
