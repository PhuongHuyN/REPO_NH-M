USE FreshVendDB;
GO
-- Controlled test data only. No table/view/index is created outside report.
-- Bridge IDs below exists ONLY in this isolated fixture while FV-13 is pending.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 INSERT auth.[User](Username,PasswordHash,FullName,Email,IsActive)
 SELECT N'admin01',N'NO-LOGIN-FIXTURE',N'TV5 QA',N'tv5@fixture.local',0
 WHERE NOT EXISTS(SELECT 1 FROM auth.[User] WHERE Username=N'admin01');
 INSERT inventory.Category(CategoryName) SELECT N'TV5 QA' WHERE NOT EXISTS(SELECT 1 FROM inventory.Category WHERE CategoryName=N'TV5 QA');
 INSERT inventory.Product(SKU,ProductName,CategoryId,UnitPrice)
 SELECT N'TV5-P-'+FORMAT(value,'000'),N'QA fruit '+CONVERT(NVARCHAR(5),value),(SELECT CategoryId FROM inventory.Category WHERE CategoryName=N'TV5 QA'),1000*value
 FROM GENERATE_SERIES(1,10) g WHERE NOT EXISTS(SELECT 1 FROM inventory.Product WHERE SKU=N'TV5-P-'+FORMAT(g.value,'000'));
 INSERT iot.Locations(LocationName,LocationType,District)
 SELECT N'TV5 QA '+CONVERT(NVARCHAR(5),value),N'CAMPUS',N'Thu Duc'
 FROM GENERATE_SERIES(1,3) g WHERE NOT EXISTS(SELECT 1 FROM iot.Locations WHERE LocationName=N'TV5 QA '+CONVERT(NVARCHAR(5),g.value));
 INSERT iot.Machines(Serial,MachineName,LocationId,Status)
 SELECT N'TV5-M-'+FORMAT(value,'000'),N'QA machine '+CONVERT(NVARCHAR(5),value),
 (SELECT LocationId FROM iot.Locations WHERE LocationName=N'TV5 QA '+CONVERT(NVARCHAR(5),1+(value-1)%3)),IIF(value=5,N'OFFLINE',N'ACTIVE')
 FROM GENERATE_SERIES(1,5) g WHERE NOT EXISTS(SELECT 1 FROM iot.Machines WHERE Serial=N'TV5-M-'+FORMAT(g.value,'000'));
 IF OBJECT_ID(N'inventory.Machine',N'U') IS NOT NULL
 BEGIN
  IF EXISTS(SELECT 1 FROM iot.Machines i JOIN inventory.Machine m ON m.MachineId=i.MachineId WHERE i.Serial LIKE N'TV5-M-%' AND m.MachineCode<>i.Serial)
   THROW 50490,N'Fixture requires a clean isolated database; machine IDs conflict.',1;
  SET IDENTITY_INSERT inventory.Machine ON;
  INSERT inventory.Machine(MachineId,MachineCode,MachineName,Status)
  SELECT MachineId,Serial,MachineName,N'online' FROM iot.Machines i WHERE i.Serial LIKE N'TV5-M-%'
  AND NOT EXISTS(SELECT 1 FROM inventory.Machine m WHERE m.MachineId=i.MachineId);
  SET IDENTITY_INSERT inventory.Machine OFF;
 END;
 INSERT inventory.Slot(MachineId,SlotCode,ProductId,Capacity,CurrentStock)
 SELECT m.MachineId,N'P'+RIGHT(p.SKU,3),p.ProductId,100,80 FROM iot.Machines m CROSS JOIN inventory.Product p
 WHERE m.Serial LIKE N'TV5-M-%' AND p.SKU LIKE N'TV5-P-%'
 AND NOT EXISTS(SELECT 1 FROM inventory.Slot s WHERE s.MachineId=m.MachineId AND s.ProductId=p.ProductId);
 INSERT sales.[Order](OrderCode,MachineId,Subtotal,TotalAmount,Status,CreatedAt)
 SELECT N'TV5-O-'+FORMAT(value,'00000'),m.MachineId,p.UnitPrice,p.UnitPrice,
 CASE value%5 WHEN 0 THEN N'REFUNDED' WHEN 1 THEN N'DISPENSED' ELSE N'PAID' END,
 DATEADD(HOUR,7+(value%6),CONVERT(DATETIME2,'20261103'))
 FROM GENERATE_SERIES(1,50) g JOIN iot.Machines m ON m.Serial=N'TV5-M-'+FORMAT(1+(value-1)%5,'000')
 JOIN inventory.Product p ON p.SKU=N'TV5-P-'+FORMAT(1+(value-1)%10,'000')
 WHERE NOT EXISTS(SELECT 1 FROM sales.[Order] o WHERE o.OrderCode=N'TV5-O-'+FORMAT(g.value,'00000'));
 INSERT sales.OrderItem(OrderId,SlotId,ProductId,Quantity,UnitPrice)
 SELECT o.OrderId,s.SlotId,s.ProductId,1,p.UnitPrice FROM sales.[Order] o
 JOIN inventory.Product p ON p.SKU=N'TV5-P-'+FORMAT(1+(TRY_CONVERT(INT,RIGHT(o.OrderCode,5))-1)%10,'000')
 JOIN inventory.Slot s ON s.MachineId=o.MachineId AND s.ProductId=p.ProductId
 WHERE o.OrderCode LIKE N'TV5-O-%' AND NOT EXISTS(SELECT 1 FROM sales.OrderItem i WHERE i.OrderId=o.OrderId);
 INSERT sales.DispenseEvents(OrderItemId,AttemptNo,Result)
 SELECT i.OrderItemId,1,CASE WHEN RIGHT(o.OrderCode,5)=N'00002' THEN N'JAM' ELSE N'SUCCESS' END
 FROM sales.[Order] o JOIN sales.OrderItem i ON i.OrderId=o.OrderId WHERE o.OrderCode LIKE N'TV5-O-%'
 AND NOT EXISTS(SELECT 1 FROM sales.DispenseEvents d WHERE d.OrderItemId=i.OrderItemId);
 INSERT iot.TelemetryHourly(MachineId,HourStart,MinTemp,MaxTemp,AvgTemp,ReadingCount,MinutesOutOfRange)
 SELECT MachineId,'20261103',2,8,5,60,30 FROM iot.Machines m WHERE m.Serial=N'TV5-M-001'
 AND NOT EXISTS(SELECT 1 FROM iot.TelemetryHourly h WHERE h.MachineId=m.MachineId AND h.HourStart='20261103');
 COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
GO
