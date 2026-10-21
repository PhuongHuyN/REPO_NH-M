-- =============================================================================
-- FILE        : 06_seed_large.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : Dữ liệu MỚI LỚN — dành cho kiểm thử hiệu năng (performance test)
--               ▸ 20 máy (thêm vào, không xoá máy cũ)
--               ▸ 15 sản phẩm (thêm 5 so với seed_small)
--               ▸ 5.000 đơn hàng trong 90 ngày
--                 tập trung giờ cao điểm: 07–09h, 11–13h, 17–19h
--               ▸ ~200.000 dòng iot.Telemetry (giả lập ESP32 ping 30s)
--               ▸ Tổng hợp report.DailySalesSummary từ 5.000 đơn
-- VERSION     : 1.0.0
-- CREATED     : 2026-10-21
-- RUN ORDER   : Bước 5 — sau 05_seed_small.sql (cần dữ liệu auth, Category, Supplier)
-- YÊUCẦU DB  : SQL Server 2022+ (dùng GENERATE_SERIES)
-- IDEMPOTENT  : Guard bằng NOT EXISTS / MERGE — chạy lại không lỗi
-- =============================================================================

USE FreshVendDB;
GO

SET NOCOUNT ON;
PRINT N'[06-large] ── Bắt đầu nạp seed data lớn ─────────────────────────────';
GO

-- =============================================================================
-- PHẦN A — inventory: 20 Máy (VM-LG-01 … VM-LG-20)
-- =============================================================================
-- Dùng GENERATE_SERIES(1,20) + chuỗi nhân tạo để tránh WHILE loop.

INSERT INTO inventory.Machine (MachineCode, MachineName, Location, Latitude, Longitude, Status, InstallDate)
SELECT
    N'VM-LG-' + RIGHT('00' + CAST(gs.value AS NVARCHAR(2)), 2)          AS MachineCode,
    N'Máy Large #'  + CAST(gs.value AS NVARCHAR(2))                     AS MachineName,
    N'Địa điểm ' + CAST(((gs.value - 1) / 4 + 1) AS NVARCHAR(2))
        + N' — Vị trí ' + CAST(((gs.value - 1) % 4 + 1) AS NVARCHAR(1)) AS Location,
    -- Tọa độ giả quanh TP.HCM: lat 10.70–10.85, lon 106.62–106.72
    CAST(10.70 + (gs.value % 15) * 0.01  AS DECIMAL(10,7))              AS Latitude,
    CAST(106.62 + (gs.value % 10) * 0.01 AS DECIMAL(10,7))              AS Longitude,
    CASE (gs.value % 10)
        WHEN 0 THEN N'maintenance'
        WHEN 9 THEN N'offline'
        ELSE         N'online'
    END                                                                   AS Status,
    DATEADD(DAY, -(gs.value * 3), '2026-09-01')                         AS InstallDate
FROM GENERATE_SERIES(1, 20) AS gs
WHERE NOT EXISTS (
    SELECT 1 FROM inventory.Machine
    WHERE MachineCode = N'VM-LG-' + RIGHT('00' + CAST(gs.value AS NVARCHAR(2)), 2)
);

PRINT N'[06-large] A. Machine: xong (' + CAST(@@ROWCOUNT AS NVARCHAR) + N' máy mới).';
GO

-- =============================================================================
-- PHẦN B — inventory: 15 Sản phẩm (FV-011 … FV-025)
-- =============================================================================

MERGE inventory.Product AS tgt
USING (
    SELECT
        src.SKU, src.ProductName,
        c.CategoryId,
        s.SupplierId,
        src.UnitPrice, src.Unit,
        src.ShelfLifeDays, src.TempMin, src.TempMax
    FROM (VALUES
        (N'FV-011', N'Dâu Tây Đà Lạt',          N'Trái Cây Ôn Đới',    65000.00, N'hộp', 5,  2.0,  6.0),
        (N'FV-012', N'Kiwi Xanh New Zealand',    N'Trái Cây Ôn Đới',    55000.00, N'quả', 14, 2.0,  8.0),
        (N'FV-013', N'Mận Hậu Sơn La',           N'Trái Cây Nhiệt Đới', 28000.00, N'kg',  7,  8.0, 14.0),
        (N'FV-014', N'Sầu Riêng Ri6 Cần Thơ',   N'Trái Cây Nhiệt Đới', 120000.00,N'múi', 3,  15.0,20.0),
        (N'FV-015', N'Măng Cụt Bình Dương',      N'Trái Cây Nhiệt Đới', 45000.00, N'kg',  5,  10.0,16.0),
        (N'FV-016', N'Chôm Chôm Đồng Nai',       N'Trái Cây Nhiệt Đới', 22000.00, N'kg',  4,  10.0,15.0),
        (N'FV-017', N'Vú Sữa Lò Rèn Vĩnh Kim',  N'Trái Cây Nhiệt Đới', 38000.00, N'kg',  5,  8.0, 14.0),
        (N'FV-018', N'Nhãn Lồng Hưng Yên',       N'Trái Cây Nhiệt Đới', 32000.00, N'kg',  6,  8.0, 14.0),
        (N'FV-019', N'Cherimoyas (Mãng Cầu Na)', N'Trái Cây Nhiệt Đới', 42000.00, N'quả', 4,  10.0,16.0),
        (N'FV-020', N'Khóm Queen Tiền Giang',    N'Trái Cây Nhiệt Đới', 18000.00, N'quả', 5,  8.0, 14.0),
        (N'FV-021', N'Táo Envy Premium',         N'Trái Cây Ôn Đới',    52000.00, N'quả', 21, 2.0,  8.0),
        (N'FV-022', N'Nho Đen Shine Muscat',     N'Trái Cây Ôn Đới',    95000.00, N'chùm',7,  2.0,  6.0),
        (N'FV-023', N'Lê Nashi Úc',              N'Trái Cây Ôn Đới',    48000.00, N'quả', 14, 2.0,  8.0),
        (N'FV-024', N'Đào Vàng Mộc Châu',        N'Trái Cây Ôn Đới',    35000.00, N'quả', 7,  4.0,  9.0),
        (N'FV-025', N'Cherry Mỹ',                N'Trái Cây Ôn Đới',    145000.00,N'hộp', 7,  2.0,  6.0)
    ) AS src (SKU, ProductName, CatName, UnitPrice, Unit, ShelfLifeDays, TempMin, TempMax)
    JOIN inventory.Category c ON c.CategoryName = src.CatName
    CROSS JOIN (SELECT TOP 1 SupplierId FROM inventory.Supplier) s
) AS src (SKU, ProductName, CategoryId, SupplierId, UnitPrice, Unit, ShelfLifeDays, StorageTempMin, StorageTempMax)
ON tgt.SKU = src.SKU
WHEN NOT MATCHED THEN
    INSERT (SKU, ProductName, CategoryId, SupplierId, UnitPrice, Unit, ShelfLifeDays, StorageTempMin, StorageTempMax)
    VALUES (src.SKU, src.ProductName, src.CategoryId, src.SupplierId, src.UnitPrice, src.Unit, src.ShelfLifeDays, src.StorageTempMin, src.StorageTempMax);

PRINT N'[06-large] B. Product: xong (FV-011 → FV-025, 15 sản phẩm mới).';
GO

-- =============================================================================
-- PHẦN C — inventory: Slot cho 20 máy mới (mỗi máy 5 ngăn A1–A5)
-- =============================================================================

INSERT INTO inventory.Slot (MachineId, SlotCode, ProductId, Capacity, CurrentStock)
SELECT
    m.MachineId,
    N'A' + CAST(gs.value AS NVARCHAR(1))    AS SlotCode,
    p.ProductId,
    CAST(30 AS SMALLINT)                    AS Capacity,
    -- Tồn kho ngẫu nhiên từ 10–28
    CAST(10 + (ABS(CHECKSUM(NEWID())) % 19) AS SMALLINT) AS CurrentStock
FROM inventory.Machine m
CROSS JOIN GENERATE_SERIES(1, 5) AS gs
-- Gán sản phẩm theo hash ngẫu nhiên trong 15 sản phẩm mới (FV-011..025)
JOIN (
    SELECT ProductId, ROW_NUMBER() OVER (ORDER BY ProductId) - 1 AS rn
    FROM inventory.Product
    WHERE SKU BETWEEN N'FV-011' AND N'FV-025'
      AND IsActive = 1
) p ON p.rn = (ABS(CHECKSUM(m.MachineId, gs.value)) % 15)
WHERE m.MachineCode LIKE N'VM-LG-%'
  AND NOT EXISTS (
      SELECT 1 FROM inventory.Slot s2
      WHERE s2.MachineId = m.MachineId
        AND s2.SlotCode  = N'A' + CAST(gs.value AS NVARCHAR(1))
  );

PRINT N'[06-large] C. Slot: xong (5 ngăn/máy × 20 máy = 100 slot mới).';
GO

-- =============================================================================
-- PHẦN D — IoT: Đăng ký Device cho 20 máy mới
-- =============================================================================

INSERT INTO iot.Device (DeviceCode, MachineId, DeviceType, FirmwareVersion, Status)
SELECT
    N'ESP32-LG-' + RIGHT('00' + CAST(gs.value AS NVARCHAR(2)), 2) AS DeviceCode,
    m.MachineId,
    N'ESP32'    AS DeviceType,
    N'2.1.0'    AS FirmwareVersion,
    CASE WHEN m.Status = N'online' THEN N'online' ELSE N'offline' END AS Status
FROM GENERATE_SERIES(1, 20) AS gs
JOIN inventory.Machine m
    ON m.MachineCode = N'VM-LG-' + RIGHT('00' + CAST(gs.value AS NVARCHAR(2)), 2)
WHERE NOT EXISTS (
    SELECT 1 FROM iot.Device d
    WHERE d.DeviceCode = N'ESP32-LG-' + RIGHT('00' + CAST(gs.value AS NVARCHAR(2)), 2)
);

-- Đảm bảo SensorType TEMPERATURE và HUMIDITY tồn tại
IF NOT EXISTS (SELECT 1 FROM iot.SensorType WHERE TypeName = N'TEMPERATURE')
    INSERT INTO iot.SensorType (TypeName, Unit, Description)
    VALUES (N'TEMPERATURE', N'°C', N'Nhiệt độ khoang máy');

IF NOT EXISTS (SELECT 1 FROM iot.SensorType WHERE TypeName = N'HUMIDITY')
    INSERT INTO iot.SensorType (TypeName, Unit, Description)
    VALUES (N'HUMIDITY', N'%RH', N'Độ ẩm tương đối');

PRINT N'[06-large] D. Device: xong.';
GO

-- =============================================================================
-- PHẦN E — iot.Telemetry: ~200.000 dòng
-- =============================================================================
-- Mô hình: 20 thiết bị × ping mỗi 30 giây × 90 ngày × 86400 giây/ngày / 30
--          = 20 × 2880 × 90 ≈ 5.184.000  (quá lớn)
-- Thực tế ta sinh: 20 thiết bị × 10.000 gói = 200.000 dòng
-- Mỗi gói cách nhau 1 phút (thay vì 30 giây) → trải đều 90 ngày × 1440 phút
-- ─────────────────────────────────────────────────────────────────────────────
-- Kỹ thuật: CROSS JOIN GENERATE_SERIES(1,20) × GENERATE_SERIES(1,10000)
--           → 200.000 hàng, KHÔNG dùng vòng lặp WHILE.
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO iot.Telemetry (DeviceId, Payload, ReceivedAt, IsProcessed)
SELECT
    d.DeviceId,
    -- Payload JSON nhỏ gọn
    N'{"dev":"' + d.DeviceCode + N'","t":'
        + CAST(CAST(18.0 + (ABS(CHECKSUM(d.DeviceId, ping.value)) % 12) AS DECIMAL(4,1)) AS NVARCHAR(6))
        + N',"h":'
        + CAST(CAST(60.0 + (ABS(CHECKSUM(d.DeviceId, ping.value + 1000)) % 31) AS DECIMAL(4,1)) AS NVARCHAR(6))
        + N',"seq":' + CAST(ping.value AS NVARCHAR(6))
        + N'}' AS Payload,
    -- Thời điểm: bắt đầu từ 90 ngày trước, mỗi gói cách nhau 1 phút
    DATEADD(MINUTE,
        ((dev_idx.rn - 1) * 10000 + ping.value - 1),   -- offset theo device + seq
        DATEADD(DAY, -90, CAST(GETDATE() AS DATETIME2))
    ) AS ReceivedAt,
    CAST(1 AS BIT) AS IsProcessed   -- giả định đã được xử lý
FROM GENERATE_SERIES(1, 10000) AS ping          -- 10.000 gói mỗi thiết bị
CROSS JOIN (
    SELECT d2.DeviceId, d2.DeviceCode,
           ROW_NUMBER() OVER (ORDER BY d2.DeviceId) AS rn
    FROM iot.Device d2
    WHERE d2.DeviceCode LIKE N'ESP32-LG-%'
) AS dev_idx
-- Alias cho join tường minh
JOIN iot.Device d ON d.DeviceId = dev_idx.DeviceId
WHERE NOT EXISTS (
    -- Guard: không insert lại nếu đã có > 10.000 dòng telemetry từ device này
    SELECT 1 FROM (
        SELECT TOP 1 1 AS x
        FROM iot.Telemetry tel
        WHERE tel.DeviceId = dev_idx.DeviceId
        HAVING COUNT(*) > 10000
    ) chk
);

PRINT N'[06-large] E. Telemetry: xong (~200.000 dòng).';
GO

-- =============================================================================
-- PHẦN F — sales: 5.000 Đơn hàng trong 90 ngày
-- =============================================================================
-- Phân bổ thời gian theo giờ cao điểm:
--   ▸ 07–09h  (peak sáng)   → offset_hour ∈ {7, 8}
--   ▸ 11–13h  (peak trưa)   → offset_hour ∈ {11, 12}
--   ▸ 17–19h  (peak chiều)  → offset_hour ∈ {17, 18}
-- Kỹ thuật: GENERATE_SERIES(1, 5000) + ánh xạ (value % 6) → 6 khung giờ
-- ─────────────────────────────────────────────────────────────────────────────

-- Bảng tham chiếu giờ cao điểm (6 slot, tương ứng value % 6 → 0..5)
DECLARE @peakHours TABLE (slot INT, hour INT);
INSERT INTO @peakHours VALUES (0,7),(1,8),(2,11),(3,12),(4,17),(5,18);

-- Insert 5.000 đơn hàng
INSERT INTO sales.[Order] (OrderCode, MachineId, CustomerId, Subtotal, TotalAmount, Status, CreatedAt)
SELECT
    N'ORD-LG-' + RIGHT('00000' + CAST(gs.value AS NVARCHAR(5)), 5)  AS OrderCode,

    -- Máy: phân phối đều 5.000 đơn cho 20 máy VM-LG
    m.MachineId,

    NULL                                                              AS CustomerId, -- khách vãng lai

    p.UnitPrice * qty.q                                               AS Subtotal,
    p.UnitPrice * qty.q                                               AS TotalAmount,

    -- 90% paid, 5% cancelled, 5% refunded
    CASE (ABS(CHECKSUM(NEWID())) % 20)
        WHEN 0 THEN N'cancelled'
        WHEN 1 THEN N'refunded'
        ELSE         N'paid'
    END                                                               AS Status,

    -- Timestamp: 90 ngày trước + ngày ngẫu nhiên + giờ cao điểm
    DATEADD(MINUTE,
        ABS(CHECKSUM(NEWID())) % 60,        -- phút ngẫu nhiên trong giờ
        DATEADD(HOUR,
            ph.hour,
            DATEADD(DAY,
                -( ABS(CHECKSUM(NEWID())) % 90 ),   -- ngày ngẫu nhiên trong 90 ngày
                CAST(CAST(GETDATE() AS DATE) AS DATETIME2)
            )
        )
    )                                                                 AS CreatedAt
FROM GENERATE_SERIES(1, 5000) AS gs

-- Máy: gs.value % 20 → index 0..19 → MachineId từ VM-LG-01..20
JOIN (
    SELECT MachineId,
           ROW_NUMBER() OVER (ORDER BY MachineId) - 1 AS rn
    FROM inventory.Machine
    WHERE MachineCode LIKE N'VM-LG-%'
      AND IsActive = 1
) m ON m.rn = (gs.value - 1) % 20

-- Sản phẩm: gs.value % 15 → index 0..14 → FV-011..025
JOIN (
    SELECT ProductId, UnitPrice,
           ROW_NUMBER() OVER (ORDER BY ProductId) - 1 AS rn
    FROM inventory.Product
    WHERE SKU BETWEEN N'FV-011' AND N'FV-025'
      AND IsActive = 1
) p ON p.rn = (gs.value - 1) % 15

-- Số lượng: 1–3 sản phẩm (tránh ảnh hưởng CK_sales_Order_Total)
CROSS JOIN (VALUES (1 + (ABS(CHECKSUM(NEWID())) % 3))) AS qty(q)

-- Giờ cao điểm: gs.value % 6 → 1 trong 6 khung giờ
JOIN @peakHours ph ON ph.slot = (gs.value - 1) % 6

-- Guard idempotent
WHERE NOT EXISTS (
    SELECT 1 FROM sales.[Order]
    WHERE OrderCode = N'ORD-LG-' + RIGHT('00000' + CAST(gs.value AS NVARCHAR(5)), 5)
);

PRINT N'[06-large] F. Order: xong (5.000 đơn hàng trải 90 ngày, tập trung giờ cao điểm).';
GO

-- =============================================================================
-- PHẦN G — sales: OrderItem cho 5.000 đơn (1 item/đơn)
-- =============================================================================

INSERT INTO sales.OrderItem (OrderId, SlotId, ProductId, Quantity, UnitPrice)
SELECT
    o.OrderId,
    sl.SlotId,
    -- Xác định sản phẩm từ TotalAmount: cần join ngược lại Product
    prd.ProductId,
    CAST(1 AS SMALLINT)     AS Quantity,
    prd.UnitPrice
FROM sales.[Order] o
-- Sản phẩm: match theo UnitPrice (1 item → TotalAmount = UnitPrice)
JOIN inventory.Product prd
    ON prd.UnitPrice = o.TotalAmount
    AND prd.SKU BETWEEN N'FV-011' AND N'FV-025'
    AND prd.IsActive = 1
-- Slot: lấy slot đầu tiên của máy có chứa sản phẩm đó
JOIN (
    SELECT sl2.SlotId, sl2.MachineId, sl2.ProductId,
           ROW_NUMBER() OVER (PARTITION BY sl2.MachineId, sl2.ProductId ORDER BY sl2.SlotId) AS rn
    FROM inventory.Slot sl2
    WHERE sl2.IsActive = 1
) sl ON sl.MachineId  = o.MachineId
     AND sl.ProductId = prd.ProductId
     AND sl.rn        = 1
WHERE o.OrderCode LIKE N'ORD-LG-%'
  AND NOT EXISTS (
      SELECT 1 FROM sales.OrderItem oi WHERE oi.OrderId = o.OrderId
  );

PRINT N'[06-large] G. OrderItem: xong.';
GO

-- =============================================================================
-- PHẦN H — sales: Payment cho đơn hàng 'paid' và 'refunded'
-- =============================================================================

INSERT INTO sales.Payment (OrderId, PaymentMethod, Amount, Status, PaidAt, TransactionRef)
SELECT
    o.OrderId,
    CASE (ABS(CHECKSUM(o.OrderCode)) % 4)
        WHEN 0 THEN N'QRCODE'
        WHEN 1 THEN N'EWALLET'
        WHEN 2 THEN N'CARD'
        ELSE         N'CASH'
    END                 AS PaymentMethod,
    o.TotalAmount       AS Amount,
    CASE o.Status
        WHEN N'refunded' THEN N'refunded'
        ELSE                  N'success'
    END                 AS Status,
    o.CreatedAt         AS PaidAt,
    N'TXN-LG-' + RIGHT('000000' + CAST(o.OrderId AS NVARCHAR(6)), 6) AS TransactionRef
FROM sales.[Order] o
WHERE o.OrderCode LIKE N'ORD-LG-%'
  AND o.Status IN (N'paid', N'refunded')
  AND NOT EXISTS (
      SELECT 1 FROM sales.Payment py WHERE py.OrderId = o.OrderId
  );

PRINT N'[06-large] H. Payment: xong (~4.500 bản ghi thanh toán).';
GO

-- =============================================================================
-- PHẦN I — report.DailySalesSummary: Tổng hợp từ 5.000 đơn mới
-- =============================================================================
-- Dùng MERGE để cộng dồn vào các dòng đã tồn tại (từ seed_small).

MERGE report.DailySalesSummary AS tgt
USING (
    SELECT
        CAST(o.CreatedAt AS DATE)       AS SummaryDate,
        o.MachineId,
        oi.ProductId,
        COUNT(DISTINCT o.OrderId)       AS OrderCount,
        SUM(oi.Quantity)                AS QtySold,
        SUM(oi.LineTotal)               AS Revenue,
        SUM(o.DiscountAmount)           AS TotalDiscount,
        AVG(oi.UnitPrice)               AS AvgUnitPrice
    FROM sales.[Order] o
    JOIN sales.OrderItem oi ON oi.OrderId = o.OrderId
    WHERE o.OrderCode LIKE N'ORD-LG-%'
      AND o.Status    = N'paid'
    GROUP BY CAST(o.CreatedAt AS DATE), o.MachineId, oi.ProductId
) AS src
ON  tgt.SummaryDate = src.SummaryDate
AND tgt.MachineId   = src.MachineId
AND tgt.ProductId   = src.ProductId
WHEN MATCHED THEN
    UPDATE SET
        tgt.QtySold       = tgt.QtySold       + src.QtySold,
        tgt.Revenue       = tgt.Revenue       + src.Revenue,
        tgt.OrderCount    = tgt.OrderCount    + src.OrderCount,
        tgt.TotalDiscount = tgt.TotalDiscount + src.TotalDiscount,
        tgt.AvgUnitPrice  = (tgt.AvgUnitPrice + src.AvgUnitPrice) / 2,
        tgt.RefreshedAt   = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (SummaryDate, MachineId, ProductId, QtySold, Revenue, OrderCount, TotalDiscount, AvgUnitPrice)
    VALUES (src.SummaryDate, src.MachineId, src.ProductId,
            src.QtySold, src.Revenue, src.OrderCount, src.TotalDiscount, src.AvgUnitPrice);

PRINT N'[06-large] I. DailySalesSummary: xong (upsert cho 5.000 đơn).';
GO

-- =============================================================================
-- XÁC NHẬN KẾT QUẢ
-- =============================================================================

SELECT 'inventory.Machine'          AS [Table], COUNT(*) AS [Rows] FROM inventory.Machine
UNION ALL SELECT 'inventory.Product',            COUNT(*) FROM inventory.Product
UNION ALL SELECT 'inventory.Slot',               COUNT(*) FROM inventory.Slot
UNION ALL SELECT 'iot.Device',                   COUNT(*) FROM iot.Device      WHERE DeviceCode LIKE N'ESP32-LG-%'
UNION ALL SELECT 'iot.Telemetry',                COUNT(*) FROM iot.Telemetry
UNION ALL SELECT 'sales.Order (LG-total)',        COUNT(*) FROM sales.[Order]   WHERE OrderCode  LIKE N'ORD-LG-%'
UNION ALL SELECT 'sales.Order (LG-paid)',         COUNT(*) FROM sales.[Order]   WHERE OrderCode  LIKE N'ORD-LG-%' AND Status = N'paid'
UNION ALL SELECT 'sales.OrderItem',               COUNT(*) FROM sales.OrderItem
UNION ALL SELECT 'sales.Payment',                 COUNT(*) FROM sales.Payment
UNION ALL SELECT 'report.DailySalesSummary',      COUNT(*) FROM report.DailySalesSummary
ORDER BY [Table];
GO

-- Phân phối đơn hàng theo giờ (xác nhận tập trung đúng giờ cao điểm)
SELECT
    DATEPART(HOUR, CreatedAt)   AS [Hour],
    COUNT(*)                    AS [OrderCount],
    REPLICATE(N'█', COUNT(*) / 20) AS [Histogram]
FROM sales.[Order]
WHERE OrderCode LIKE N'ORD-LG-%'
GROUP BY DATEPART(HOUR, CreatedAt)
ORDER BY [Hour];
GO

PRINT N'';
PRINT N'======================================================================';
PRINT N'  06_seed_large.sql hoàn tất.';
PRINT N'  ▸ 20 máy, 15 sản phẩm, 5.000 đơn hàng, ~200.000 telemetry         ';
PRINT N'  ▸ Dữ liệu sẵn sàng cho kiểm thử hiệu năng (performance test).      ';
PRINT N'======================================================================';
GO
