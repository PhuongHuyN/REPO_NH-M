-- SCRUM-210: SQL Server 2022; run AFTER all owner schemas and QD-1 migration.
-- Shared TV5 keys: small -> large produces large profile, never 5050 orders.
-- Fixed historical UTC window [2026-08-06,2026-11-04); VN peak business hours.
USE FreshVendDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 IF OBJECT_ID(N'inventory.Machine',N'V') IS NULL
  THROW 50400,N'Chua co view may theo QD-1. Can hoan thanh SCRUM-207 / GitHub #20 truoc khi seed.',1;
 IF (SELECT compatibility_level FROM sys.databases WHERE name=DB_NAME())<160
  THROW 50400,N'Seed can SQL Server 2022 compatibility 160.',1;
 BEGIN TRAN;
 INSERT auth.[User](Username,PasswordHash,FullName,Email,IsActive)
 SELECT N'admin01',N'FIXTURE-NO-LOGIN',N'TV5 QA',N'tv5@fixture.local',0
 WHERE NOT EXISTS(SELECT 1 FROM auth.[User] WHERE Username=N'admin01');
 INSERT inventory.Category(CategoryName) SELECT N'TV5 Fruit' WHERE NOT EXISTS(SELECT 1 FROM inventory.Category WHERE CategoryName=N'TV5 Fruit');
 INSERT inventory.Product(SKU,ProductName,CategoryId,UnitPrice,ShelfLifeHours,StorageTempMin,StorageTempMax)
 SELECT N'TV5-P-'+FORMAT(value,'000'),N'TV5 Fruit '+CONVERT(NVARCHAR(4),value),c.CategoryId,10000+value*1000,72,2,8
 FROM GENERATE_SERIES(1,15) g CROSS JOIN inventory.Category c
 WHERE c.CategoryName=N'TV5 Fruit' AND NOT EXISTS(SELECT 1 FROM inventory.Product p WHERE p.SKU=N'TV5-P-'+FORMAT(g.value,'000'));
 INSERT iot.Locations(LocationName,LocationType,District)
 SELECT N'TV5 Site '+CONVERT(NVARCHAR(2),value),N'CAMPUS',N'Thu Duc' FROM GENERATE_SERIES(1,3) g
 WHERE NOT EXISTS(SELECT 1 FROM iot.Locations l WHERE l.LocationName=N'TV5 Site '+CONVERT(NVARCHAR(2),g.value));
 INSERT iot.Machines(Serial,MachineName,LocationId,Status,LastHeartbeat)
 SELECT N'TV5-M-'+FORMAT(value,'000'),N'TV5 Machine '+CONVERT(NVARCHAR(3),value),l.LocationId,
 CASE WHEN value%5=0 THEN N'OFFLINE' ELSE N'ACTIVE' END,'20261103'
 FROM GENERATE_SERIES(1,20) g JOIN iot.Locations l ON l.LocationName=N'TV5 Site '+CONVERT(NVARCHAR(2),1+(value-1)%3)
 WHERE NOT EXISTS(SELECT 1 FROM iot.Machines m WHERE m.Serial=N'TV5-M-'+FORMAT(g.value,'000'));
 INSERT iot.MachineThresholds(MachineId,MinTemp,MaxTemp)
 SELECT MachineId,2,8 FROM iot.Machines m WHERE Serial LIKE N'TV5-M-%'
 AND NOT EXISTS(SELECT 1 FROM iot.MachineThresholds t WHERE t.MachineId=m.MachineId);
 INSERT inventory.Slot(MachineId,SlotCode,ProductId,Capacity,CurrentStock)
 SELECT m.MachineId,N'P'+RIGHT(p.SKU,3),p.ProductId,100,0 FROM iot.Machines m CROSS JOIN inventory.Product p
 WHERE m.Serial BETWEEN N'TV5-M-001' AND N'TV5-M-020' AND p.SKU BETWEEN N'TV5-P-001' AND N'TV5-P-015'
 AND NOT EXISTS(SELECT 1 FROM inventory.Slot s WHERE s.MachineId=m.MachineId AND s.SlotCode=N'P'+RIGHT(p.SKU,3));
 -- Reporting history only; operational FIFO/restock inventory comes from 08_seed_inventory.
 SELECT g.value n,m.MachineId,p.ProductId,p.UnitPrice,s.SlotId,N'TV5-O-'+FORMAT(value,'00000') OrderCode,
 CONVERT(SMALLINT,CASE WHEN value<=50 THEN 1 ELSE 1+ABS(CONVERT(BIGINT,CHECKSUM(NEWID())))%3 END) Qty
 INTO #Orders FROM GENERATE_SERIES(1,5000) g
 JOIN iot.Machines m ON m.Serial=N'TV5-M-'+FORMAT(1+(value-1)%CASE WHEN value<=50 THEN 5 ELSE 20 END,'000')
 JOIN inventory.Product p ON p.SKU=N'TV5-P-'+FORMAT(1+(value-1)%CASE WHEN value<=50 THEN 10 ELSE 15 END,'000')
 JOIN inventory.Slot s ON s.MachineId=m.MachineId AND s.SlotCode=N'P'+RIGHT(p.SKU,3) AND s.ProductId=p.ProductId;
 INSERT sales.[Order](OrderCode,MachineId,Subtotal,TotalAmount,Status,CreatedAt,ExpiresAt)
 SELECT s.OrderCode,s.MachineId,s.UnitPrice*s.Qty,s.UnitPrice*s.Qty,
 CASE WHEN n>50 AND n%20=0 THEN N'CANCELLED' WHEN n>50 AND n%20=1 THEN N'REFUNDED' WHEN n%2=0 THEN N'DISPENSED' ELSE N'PAID' END,
 dt.AtUtc,DATEADD(MINUTE,5,dt.AtUtc)
 FROM #Orders s CROSS APPLY(VALUES(DATEADD(MINUTE,ABS(CONVERT(BIGINT,CHECKSUM(NEWID())))%60,
 DATEADD(HOUR,CASE n%6 WHEN 0 THEN 7 WHEN 1 THEN 8 WHEN 2 THEN 11 WHEN 3 THEN 12 WHEN 4 THEN 17 ELSE 18 END-7,
 DATEADD(DAY,(n-1)%90,CONVERT(DATETIME2,'20260806')))))) dt(AtUtc)
 WHERE NOT EXISTS(SELECT 1 FROM sales.[Order] o WHERE o.OrderCode=s.OrderCode);
 INSERT sales.OrderItem(OrderId,SlotId,ProductId,Quantity,UnitPrice)
 SELECT o.OrderId,s.SlotId,s.ProductId,CONVERT(SMALLINT,o.Subtotal/s.UnitPrice),s.UnitPrice
 FROM #Orders s JOIN sales.[Order] o ON o.OrderCode=s.OrderCode
 WHERE NOT EXISTS(SELECT 1 FROM sales.OrderItem i WHERE i.OrderId=o.OrderId);
 INSERT sales.Payment(OrderId,PaymentMethod,Amount,Status,PaidAt,TransactionRef,GatewayTxnId)
 SELECT o.OrderId,N'VIETQR',o.TotalAmount,IIF(o.Status=N'REFUNDED',N'refunded',N'success'),o.CreatedAt,N'TV5-PAY-'+o.OrderCode,N'TV5-PAY-'+o.OrderCode
 FROM #Orders s JOIN sales.[Order] o ON o.OrderCode=s.OrderCode
 WHERE o.Status<>N'CANCELLED' AND NOT EXISTS(SELECT 1 FROM sales.Payment p WHERE p.OrderId=o.OrderId);
 INSERT sales.Refund(PaymentId,OrderId,RefundAmount,Amount,Reason,Status,ProcessedAt,RefundedAt)
 SELECT p.PaymentId,o.OrderId,p.Amount,p.Amount,N'TV5 historical refund',N'completed',o.CreatedAt,o.CreatedAt
 FROM #Orders s JOIN sales.[Order] o ON o.OrderCode=s.OrderCode JOIN sales.Payment p ON p.OrderId=o.OrderId
 WHERE o.Status=N'REFUNDED' AND NOT EXISTS(SELECT 1 FROM sales.Refund r WHERE r.PaymentId=p.PaymentId);
 INSERT sales.DispenseEvents(OrderItemId,AttemptNo,Result,EventAt)
 SELECT i.OrderItemId,1,CASE WHEN s.n%97=0 THEN N'JAM' ELSE N'SUCCESS' END,o.CreatedAt
 FROM #Orders s JOIN sales.[Order] o ON o.OrderCode=s.OrderCode JOIN sales.OrderItem i ON i.OrderId=o.OrderId
 WHERE o.Status<>N'CANCELLED' AND NOT EXISTS(SELECT 1 FROM sales.DispenseEvents d WHERE d.OrderItemId=i.OrderItemId AND d.AttemptNo=1);
 INSERT iot.Telemetry(MachineId,RecordedAt,Temperature,Humidity,DoorOpen)
 SELECT m.MachineId,ts.AtUtc,CASE WHEN g.value%20=0 THEN 10 ELSE 4 END,65,0
 FROM GENERATE_SERIES(1,200000) g
 JOIN iot.Machines m ON m.Serial=N'TV5-M-'+FORMAT(1+(value-1)%CASE WHEN value<=500 THEN 5 ELSE 20 END,'000')
 CROSS APPLY(VALUES(DATEADD(SECOND,CONVERT(INT,CONVERT(BIGINT,value-1)*7776000/200000),CONVERT(DATETIME2,'20260806')))) ts(AtUtc)
 WHERE NOT EXISTS(SELECT 1 FROM iot.Telemetry t WHERE t.MachineId=m.MachineId AND t.RecordedAt=ts.AtUtc);
 EXEC report.sp_RefreshDailySummary '20260806','20261103';
 -- Do not invent elapsed minutes from sparse telemetry samples. Hourly backfill:
 -- wait for the owner contract in #21; cold-chain seed coverage remains unknown.
 DROP TABLE IF EXISTS #Orders;
 COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
GO
