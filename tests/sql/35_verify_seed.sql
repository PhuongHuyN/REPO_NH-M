USE FreshVendDB;
GO
SET NOCOUNT ON;
DECLARE @Large BIT=IIF(EXISTS(SELECT 1 FROM sales.[Order] WHERE OrderCode=N'TV5-O-05000'),1,0);
DECLARE @Orders INT=IIF(@Large=1,5000,50),@Machines INT=IIF(@Large=1,20,5),@Products INT=IIF(@Large=1,15,10),@Packets INT=IIF(@Large=1,200000,500);
IF (SELECT COUNT(*) FROM iot.Locations WHERE LocationName LIKE N'TV5 Site %')<>3 THROW 50490,N'Location count mismatch',1;
IF (SELECT COUNT(*) FROM iot.Machines WHERE Serial LIKE N'TV5-M-%')<>@Machines THROW 50490,N'Machine count mismatch',1;
IF (SELECT COUNT(*) FROM inventory.Product WHERE SKU LIKE N'TV5-P-%')<>@Products THROW 50490,N'Product count mismatch',1;
IF (SELECT COUNT(*) FROM sales.[Order] WHERE OrderCode LIKE N'TV5-O-%')<>@Orders THROW 50490,N'Order count mismatch',1;
IF (SELECT COUNT(*) FROM iot.Telemetry t JOIN iot.Machines m ON m.MachineId=t.MachineId WHERE m.Serial LIKE N'TV5-M-%')<>@Packets THROW 50490,N'Telemetry count mismatch',1;
IF EXISTS(SELECT o.OrderId FROM sales.[Order] o LEFT JOIN sales.OrderItem i ON i.OrderId=o.OrderId
 WHERE o.OrderCode LIKE N'TV5-O-%' GROUP BY o.OrderId,o.Subtotal HAVING COUNT(i.OrderItemId)<>1 OR COALESCE(SUM(i.LineTotal),0)<>o.Subtotal)
 THROW 50490,N'Order detail count or subtotal mismatch',1;
IF EXISTS(SELECT 1 FROM sales.OrderItem i JOIN sales.[Order] o ON o.OrderId=i.OrderId JOIN inventory.Slot s ON s.SlotId=i.SlotId
 WHERE o.OrderCode LIKE N'TV5-O-%' AND (s.MachineId<>o.MachineId OR s.ProductId<>i.ProductId)) THROW 50490,N'Slot mismatch',1;
IF EXISTS(SELECT o.OrderId FROM sales.[Order] o LEFT JOIN sales.Payment p ON p.OrderId=o.OrderId
 WHERE o.OrderCode LIKE N'TV5-O-%' AND o.Status IN(N'PAID',N'DISPENSED',N'REFUNDED')
 GROUP BY o.OrderId,o.TotalAmount HAVING COUNT(p.PaymentId)<>1 OR SUM(p.Amount)<>o.TotalAmount) THROW 50490,N'Payment mismatch',1;
IF EXISTS(SELECT 1 FROM iot.Telemetry t JOIN iot.Machines m ON m.MachineId=t.MachineId WHERE m.Serial LIKE N'TV5-M-%'
 AND (RecordedAt<'20260806' OR RecordedAt>='20261104')) THROW 50490,N'Telemetry outside 90 days',1;
IF EXISTS(SELECT 1 FROM sales.[Order] WHERE OrderCode LIKE N'TV5-O-%'
 AND (CreatedAt<'20260806' OR CreatedAt>='20261104' OR DATEPART(HOUR,DATEADD(HOUR,7,CreatedAt)) NOT IN(7,8,11,12,17,18))) THROW 50490,N'Order outside peak/window',1;
IF (SELECT SUM(Revenue) FROM report.DailySalesSummary)<>(SELECT SUM(i.LineTotal) FROM sales.[Order] o JOIN sales.OrderItem i ON i.OrderId=o.OrderId WHERE o.Status IN(N'PAID',N'DISPENSED'))
 THROW 50490,N'Summary revenue mismatch (including rerun inflation)',1;
IF @Large=1 AND (SELECT COUNT(DISTINCT CONVERT(DATE,DATEADD(HOUR,7,CreatedAt))) FROM sales.[Order] WHERE OrderCode LIKE N'TV5-O-%')<>90
 THROW 50490,N'Large orders must cover 90 days',1;
SELECT @Large LargeProfile,@Machines Machines,@Products Products,@Orders Orders,@Packets Telemetry,N'PASS' Result;
