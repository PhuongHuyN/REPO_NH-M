-- TV5 large profile; SQL Server 2022, compatibility 160.
-- Shared natural keys: running small then large yields 20 machines, 15 products,
-- 5000 orders and 200000 packets owned by TV5, without deleting anybody's data.
-- Fixed UTC window [2026-08-06,2026-11-04). Business hours are UTC+7.
USE FreshVendDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    IF (SELECT compatibility_level FROM sys.databases WHERE name=DB_NAME()) < 160
        THROW 50400, N'Seed requires SQL Server 2022 compatibility 160.', 1;
    BEGIN TRAN;
    MERGE auth.Role AS t USING (VALUES(N'Admin',N'Administrator'),(N'Operator',N'Operator'),(N'Viewer',N'Read only')) s(RoleName,Description)
    ON t.RoleName=s.RoleName WHEN NOT MATCHED THEN INSERT(RoleName,Description) VALUES(s.RoleName,s.Description);
    -- Disabled fixtures, not usable login credentials. Auth owner supplies real hashes.
    MERGE auth.[User] AS t USING (VALUES(N'admin01',N'Admin'),(N'operator01',N'Operator'),(N'viewer01',N'Viewer')) s(Username,FullName)
    ON t.Username=s.Username WHEN NOT MATCHED THEN INSERT(Username,FullName,PasswordHash,Email,IsActive)
    VALUES(s.Username,s.FullName,N'TEST-FIXTURE-NO-LOGIN',s.Username+N'@freshvend.local',0);
    INSERT auth.UserRole(UserId,RoleId)
    SELECT u.UserId,r.RoleId FROM (VALUES(N'admin01',N'Admin'),(N'operator01',N'Operator'),(N'viewer01',N'Viewer')) s(Username,RoleName)
    JOIN auth.[User] u ON u.Username=s.Username JOIN auth.Role r ON r.RoleName=s.RoleName
    WHERE NOT EXISTS(SELECT 1 FROM auth.UserRole x WHERE x.UserId=u.UserId AND x.RoleId=r.RoleId);
    MERGE auth.Permission t USING(VALUES(N'report.read',N'report'),(N'report.export',N'report'),(N'inventory.read',N'inventory')) s(PermissionName,Module)
    ON t.PermissionName=s.PermissionName WHEN NOT MATCHED THEN INSERT(PermissionName,Module) VALUES(s.PermissionName,s.Module);
    INSERT auth.RolePermission(RoleId,PermissionId)
    SELECT r.RoleId,p.PermissionId FROM auth.Role r CROSS JOIN auth.Permission p
    WHERE ((r.RoleName=N'Admin' AND p.PermissionName IN(N'report.read',N'report.export',N'inventory.read'))
      OR (r.RoleName IN(N'Operator',N'Viewer') AND p.PermissionName=N'inventory.read'))
      AND NOT EXISTS(SELECT 1 FROM auth.RolePermission x WHERE x.RoleId=r.RoleId AND x.PermissionId=p.PermissionId);
    MERGE inventory.Supplier AS t USING(VALUES(N'TV5-SUPPLIER',N'TV5 fruit supplier')) s(TaxCode,SupplierName)
    ON t.TaxCode=s.TaxCode WHEN NOT MATCHED THEN INSERT(TaxCode,SupplierName) VALUES(s.TaxCode,s.SupplierName);
    MERGE inventory.Category AS t USING(VALUES(N'TV5 Fruit')) s(CategoryName)
    ON t.CategoryName=s.CategoryName WHEN NOT MATCHED THEN INSERT(CategoryName) VALUES(s.CategoryName);
    INSERT inventory.Product(SKU,ProductName,CategoryId,SupplierId,UnitPrice,Unit,StorageTempMin,StorageTempMax)
    SELECT N'TV5-P-'+FORMAT(g.value,'000'),N'TV5 Fruit '+CONVERT(NVARCHAR(3),g.value),c.CategoryId,s.SupplierId,
           10000+g.value*1000,N'pack',2,8
    FROM GENERATE_SERIES(1,15) g
    CROSS JOIN inventory.Category c CROSS JOIN inventory.Supplier s
    WHERE c.CategoryName=N'TV5 Fruit' AND s.TaxCode=N'TV5-SUPPLIER'
      AND NOT EXISTS(SELECT 1 FROM inventory.Product p WHERE p.SKU=N'TV5-P-'+FORMAT(g.value,'000'));
    MERGE inventory.Locations AS t USING(VALUES(N'TV5-L1',N'Bach Khoa'),(N'TV5-L2',N'Vincom Thu Duc'),(N'TV5-L3',N'Coopmart')) s(LocationCode,LocationName)
    ON t.LocationCode=s.LocationCode WHEN NOT MATCHED THEN INSERT(LocationCode,LocationName) VALUES(s.LocationCode,s.LocationName);
    INSERT inventory.Machine(MachineCode,MachineName,Location,LocationId,Status)
    SELECT N'TV5-M-'+FORMAT(g.value,'000'),N'TV5 Machine '+CONVERT(NVARCHAR(3),g.value),l.LocationName,l.LocationId,
           CASE WHEN g.value%5=0 THEN N'offline' ELSE N'online' END
    FROM GENERATE_SERIES(1,20) g JOIN inventory.Locations l ON l.LocationCode=N'TV5-L'+CONVERT(NVARCHAR(1),1+(g.value-1)%3)
    WHERE NOT EXISTS(SELECT 1 FROM inventory.Machine m WHERE m.MachineCode=N'TV5-M-'+FORMAT(g.value,'000'));
    -- Every fixture machine can sell every fixture product. Never infer identity from price.
    INSERT inventory.Slot(MachineId,SlotCode,ProductId,Capacity,CurrentStock)
    SELECT m.MachineId,N'P'+RIGHT(p.SKU,3),p.ProductId,100,80
    FROM inventory.Machine m CROSS JOIN inventory.Product p
    WHERE m.MachineCode BETWEEN N'TV5-M-001' AND N'TV5-M-020'
      AND p.SKU BETWEEN N'TV5-P-001' AND N'TV5-P-015'
      AND NOT EXISTS(SELECT 1 FROM inventory.Slot x WHERE x.MachineId=m.MachineId AND x.SlotCode=N'P'+RIGHT(p.SKU,3));
    INSERT inventory.StockBatch(ProductId,SupplierId,BatchCode,Quantity,UnitCost,ImportDate,ExpiryDate,Note)
    SELECT p.ProductId,p.SupplierId,N'TV5-B-'+RIGHT(p.SKU,3),10000,p.UnitPrice*0.6,'20260801','20261130',N'TV5 historical fixture'
    FROM inventory.Product p WHERE p.SKU BETWEEN N'TV5-P-001' AND N'TV5-P-015'
      AND NOT EXISTS(SELECT 1 FROM inventory.StockBatch b WHERE b.BatchCode=N'TV5-B-'+RIGHT(p.SKU,3));
    INSERT inventory.StockMovement(SlotId,BatchId,MovementType,Quantity,Reason)
    SELECT sl.SlotId,b.BatchId,N'IN',80,N'TV5 initial stock'
    FROM inventory.Slot sl JOIN inventory.Machine m ON m.MachineId=sl.MachineId
    JOIN inventory.Product p ON p.ProductId=sl.ProductId JOIN inventory.StockBatch b ON b.BatchCode=N'TV5-B-'+RIGHT(p.SKU,3)
    WHERE m.MachineCode BETWEEN N'TV5-M-001' AND N'TV5-M-020'
      AND NOT EXISTS(SELECT 1 FROM inventory.StockMovement x WHERE x.SlotId=sl.SlotId AND x.Reason=N'TV5 initial stock');
    SELECT g.value AS n,m.MachineId,p.ProductId,sl.SlotId,p.UnitPrice,
           CONVERT(SMALLINT,CASE WHEN g.value<=50 THEN 1 ELSE 1+ABS(CONVERT(BIGINT,CHECKSUM(NEWID())))%3 END) AS Qty,
           N'TV5-O-'+FORMAT(g.value,'00000') AS OrderCode
    INTO #SeedOrders
    FROM GENERATE_SERIES(1,5000) g
    JOIN inventory.Machine m ON m.MachineCode=N'TV5-M-'+FORMAT(1+(g.value-1)%CASE WHEN g.value<=50 THEN 5 ELSE 20 END,'000')
    JOIN inventory.Product p ON p.SKU=N'TV5-P-'+FORMAT(1+(g.value-1)%CASE WHEN g.value<=50 THEN 10 ELSE 15 END,'000')
    JOIN inventory.Slot sl ON sl.MachineId=m.MachineId AND sl.ProductId=p.ProductId AND sl.SlotCode=N'P'+RIGHT(p.SKU,3);
    INSERT sales.[Order](OrderCode,MachineId,Subtotal,TotalAmount,Status,CreatedAt)
    SELECT s.OrderCode,s.MachineId,s.UnitPrice*s.Qty,s.UnitPrice*s.Qty,
           CASE WHEN s.n>50 AND s.n%20=0 THEN N'cancelled' WHEN s.n>50 AND s.n%20=1 THEN N'refunded' ELSE N'paid' END,
           DATEADD(MINUTE,ABS(CONVERT(BIGINT,CHECKSUM(NEWID())))%60,
             DATEADD(HOUR,CASE s.n%6 WHEN 0 THEN 7 WHEN 1 THEN 8 WHEN 2 THEN 11 WHEN 3 THEN 12 WHEN 4 THEN 17 ELSE 18 END-7,
               DATEADD(DAY,(s.n-1)%90,CONVERT(DATETIME2,'20260806'))))
    FROM #SeedOrders s WHERE NOT EXISTS(SELECT 1 FROM sales.[Order] o WHERE o.OrderCode=s.OrderCode);
    INSERT sales.OrderItem(OrderId,SlotId,ProductId,Quantity,UnitPrice)
    SELECT o.OrderId,s.SlotId,s.ProductId,CONVERT(SMALLINT,o.Subtotal/s.UnitPrice),s.UnitPrice
    FROM #SeedOrders s JOIN sales.[Order] o ON o.OrderCode=s.OrderCode
    WHERE NOT EXISTS(SELECT 1 FROM sales.OrderItem i WHERE i.OrderId=o.OrderId);
    INSERT sales.Payment(OrderId,PaymentMethod,Amount,Status,PaidAt,TransactionRef)
    SELECT o.OrderId,N'QRCODE',o.TotalAmount,CASE WHEN o.Status=N'refunded' THEN N'refunded' ELSE N'success' END,o.CreatedAt,N'TV5-PAY-'+o.OrderCode
    FROM #SeedOrders s JOIN sales.[Order] o ON o.OrderCode=s.OrderCode
    WHERE o.Status IN(N'paid',N'refunded') AND NOT EXISTS(SELECT 1 FROM sales.Payment p WHERE p.OrderId=o.OrderId);
    INSERT sales.Refund(PaymentId,RefundAmount,Reason,Status,ProcessedAt)
    SELECT p.PaymentId,p.Amount,N'TV5 fixture refund',N'completed',p.PaidAt FROM sales.Payment p
    JOIN sales.[Order] o ON o.OrderId=p.OrderId JOIN #SeedOrders s ON s.OrderCode=o.OrderCode
    WHERE o.Status=N'refunded' AND NOT EXISTS(SELECT 1 FROM sales.Refund r WHERE r.PaymentId=p.PaymentId);
    INSERT sales.DispenseAttempts(OrderItemId,AttemptNo,Result,AttemptedAt)
    SELECT i.OrderItemId,1,CASE WHEN s.n%97=0 THEN N'JAM' ELSE N'SUCCESS' END,o.CreatedAt
    FROM #SeedOrders s JOIN sales.[Order] o ON o.OrderCode=s.OrderCode JOIN sales.OrderItem i ON i.OrderId=o.OrderId
    WHERE o.Status IN(N'paid',N'refunded') AND NOT EXISTS(SELECT 1 FROM sales.DispenseAttempts a WHERE a.OrderItemId=i.OrderItemId AND a.AttemptNo=1);
    INSERT iot.Device(DeviceCode,MachineId,DeviceType,Status)
    SELECT N'TV5-D-'+RIGHT(m.MachineCode,3),m.MachineId,N'ESP32',N'online' FROM inventory.Machine m
    WHERE m.MachineCode BETWEEN N'TV5-M-001' AND N'TV5-M-020'
      AND NOT EXISTS(SELECT 1 FROM iot.Device d WHERE d.DeviceCode=N'TV5-D-'+RIGHT(m.MachineCode,3));
    MERGE iot.SensorType t USING(VALUES(N'TEMPERATURE',N'°C'),(N'HUMIDITY',N'%RH')) s(TypeName,Unit)
    ON t.TypeName=s.TypeName WHEN NOT MATCHED THEN INSERT(TypeName,Unit) VALUES(s.TypeName,s.Unit);
    INSERT iot.AlertRule(RuleName,SensorTypeId,Operator,Threshold,Severity,Message)
    SELECT N'TV5 cold-chain high',SensorTypeId,N'>',8,N'WARNING',N'TV5 temperature above 8 C' FROM iot.SensorType st
    WHERE TypeName=N'TEMPERATURE' AND NOT EXISTS(SELECT 1 FROM iot.AlertRule WHERE RuleName=N'TV5 cold-chain high');
    INSERT iot.SensorReading(DeviceId,SensorTypeId,Value,RecordedAt)
    SELECT d.DeviceId,st.SensorTypeId,4,'20261103' FROM iot.Device d CROSS JOIN iot.SensorType st
    WHERE d.DeviceCode BETWEEN N'TV5-D-001' AND N'TV5-D-020' AND st.TypeName=N'TEMPERATURE'
      AND NOT EXISTS(SELECT 1 FROM iot.SensorReading r WHERE r.DeviceId=d.DeviceId AND r.SensorTypeId=st.SensorTypeId AND r.RecordedAt='20261103');
    INSERT iot.Alert(DeviceId,AlertRuleId,SensorTypeId,SensorValue,Severity,Message,CreatedAt)
    SELECT d.DeviceId,r.AlertRuleId,r.SensorTypeId,10,N'WARNING',N'TV5 fixture warning','20261103'
    FROM iot.Device d CROSS JOIN iot.AlertRule r
    WHERE d.DeviceCode=N'TV5-D-001' AND r.RuleName=N'TV5 cold-chain high'
      AND NOT EXISTS(SELECT 1 FROM iot.Alert a WHERE a.DeviceId=d.DeviceId AND a.Message=N'TV5 fixture warning');
    -- A stable sequence and timestamps provide an exact natural key for reruns.
    -- First 500 packets use 5 devices in both profiles; the rest use all 20.
    INSERT iot.Telemetry(DeviceId,Payload,ReceivedAt,IsProcessed)
    SELECT d.DeviceId,N'{"seed":"TV5","seq":'+CONVERT(NVARCHAR(10),g.value)+N',"t":'+
           CASE WHEN g.value%20=0 THEN N'10' ELSE N'4' END+N',"durationSeconds":30}',ts.AtUtc,1
    FROM GENERATE_SERIES(1,200000) g
    JOIN iot.Device d ON d.DeviceCode=N'TV5-D-'+FORMAT(1+(g.value-1)%CASE WHEN g.value<=500 THEN 5 ELSE 20 END,'000')
    CROSS APPLY(VALUES(DATEADD(SECOND,CONVERT(INT,CONVERT(BIGINT,g.value-1)*7776000/200000),CONVERT(DATETIME2,'20260806')))) ts(AtUtc)
    WHERE NOT EXISTS(SELECT 1 FROM iot.Telemetry t WHERE t.DeviceId=d.DeviceId AND t.ReceivedAt=ts.AtUtc);
    EXEC report.sp_RefreshTelemetryHourly '20260806','20261103';
    -- Replace aggregate values; never add the same source twice.
    MERGE report.DailySalesSummary AS t USING(
        SELECT CONVERT(DATE,DATEADD(HOUR,7,o.CreatedAt)) SummaryDate,o.MachineId,i.ProductId,
               SUM(CONVERT(INT,i.Quantity)) QtySold,SUM(i.LineTotal) Revenue,COUNT(DISTINCT o.OrderId) OrderCount
        FROM sales.[Order] o JOIN sales.OrderItem i ON i.OrderId=o.OrderId
        JOIN (SELECT DISTINCT MachineId FROM #SeedOrders) m ON m.MachineId=o.MachineId
        WHERE o.Status=N'paid' GROUP BY CONVERT(DATE,DATEADD(HOUR,7,o.CreatedAt)),o.MachineId,i.ProductId
    ) s ON t.SummaryDate=s.SummaryDate AND t.MachineId=s.MachineId AND t.ProductId=s.ProductId
    WHEN MATCHED THEN UPDATE SET QtySold=s.QtySold,Revenue=s.Revenue,OrderCount=s.OrderCount,
        AvgUnitPrice=s.Revenue/NULLIF(s.QtySold,0),TotalDiscount=0,RefreshedAt=SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT(SummaryDate,MachineId,ProductId,QtySold,Revenue,OrderCount,AvgUnitPrice)
        VALUES(s.SummaryDate,s.MachineId,s.ProductId,s.QtySold,s.Revenue,s.OrderCount,s.Revenue/NULLIF(s.QtySold,0));
    DROP TABLE IF EXISTS #SeedOrders;
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
GO
