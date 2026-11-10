"""SCRUM-224: generate two procedure-driven seed profiles; no schema repair."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
TEMPLATE=r'''-- Procedure-driven QA seed. Requires the owner-provided schemas/security.
-- GENERATE_SERIES stages data; cursors only dispatch scalar procedure APIs.
-- Bulk typed telemetry is inserted set-wise, never by a per-row loop.
USE FreshVendDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Profile NVARCHAR(10)=N'__PROFILE__',@Machines INT=__MACHINES__,@Products INT=__PRODUCTS__,@Orders INT=__ORDERS__,@Packets INT=__PACKETS__,@HistoryEnd DATE='20261104';
DECLARE @Required TABLE(Name NVARCHAR(200));
INSERT @Required VALUES(N'auth.sp_CreateUser'),(N'auth.sp_AssignMachine'),(N'iot.sp_RegisterMachine'),
 (N'inventory.sp_AddProduct'),(N'inventory.sp_AssignColumn'),(N'inventory.sp_AddBatch'),(N'inventory.sp_Restock'),
 (N'sales.sp_CreateOrder'),(N'sales.sp_ConfirmPayment'),(N'sales.sp_RecordDispense'),(N'report.sp_RefreshDailySummary');
DECLARE @Missing NVARCHAR(1800);
SELECT @Missing=STRING_AGG(CONVERT(NVARCHAR(MAX),Name),N', ') FROM @Required WHERE OBJECT_ID(Name,N'P') IS NULL;
IF @Missing IS NOT NULL
BEGIN
 SET @Missing=N'BLOCKED: chưa có procedure thật: '+@Missing;
 THROW 50410,@Missing,1;
END;
IF OBJECT_ID(N'inventory.Machine',N'V') IS NULL THROW 50410,N'BLOCKED #20: cần view máy chuẩn QĐ-1 trước khi seed.',1;
IF NOT EXISTS(SELECT 1 FROM sys.databases WHERE name=DB_NAME() AND compatibility_level>=160) THROW 50410,N'Cần compatibility 160.',1;
IF EXISTS(SELECT 1 FROM report.SeedRuns WHERE Profile=@Profile AND HistoryEnd<>@HistoryEnd) THROW 50411,N'Profile đã dùng cửa sổ khác; không sửa lịch sử fixture cũ.',1;
IF EXISTS(SELECT 1 FROM report.SeedRuns WHERE Profile=@Profile)
BEGIN
 IF EXISTS(SELECT 1 FROM report.SeedItems s WHERE s.Kind=N'Order' AND s.ItemKey<=FORMAT(@Orders,'00000') AND NOT EXISTS(SELECT 1 FROM sales.[Order] o WHERE o.OrderId=s.ObjectId)) THROW 50411,N'Ledger seed mất dữ liệu; cần CSDL test sạch.',1;
 SELECT @Profile Profile,N'UNCHANGED' Result;
 RETURN;
END;
BEGIN TRY
 BEGIN TRAN;
 DECLARE @name NVARCHAR(100),@key NVARCHAR(100),@id BIGINT,@n INT,@m INT,@p INT,@slot INT,@batch INT,@actor INT,@order BIGINT,@amount DECIMAL(14,2),@txn NVARCHAR(100),@item BIGINT;
 DECLARE users_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT Username,Password,FullName,RoleName FROM
 (VALUES(N'admin',N'Admin@2026',N'QA Admin',N'Admin'),(N'operator01',N'Operator@2026',N'QA Operator',N'Operator'),(N'kiosk01',N'Kiosk@2026',N'QA Kiosk',N'Kiosk')) u(Username,Password,FullName,RoleName);
 DECLARE @password NVARCHAR(100),@full NVARCHAR(100),@role NVARCHAR(30);
 OPEN users_cursor; FETCH NEXT FROM users_cursor INTO @name,@password,@full,@role;
 WHILE @@FETCH_STATUS=0
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM auth.[User] WHERE Username=@name)
   EXEC auth.sp_CreateUser @Username=@name,@Password=@password,@FullName=@full,@RoleName=@role;
  FETCH NEXT FROM users_cursor INTO @name,@password,@full,@role;
 END;
 CLOSE users_cursor; DEALLOCATE users_cursor;
 SELECT @actor=UserId FROM auth.[User] WHERE Username=N'admin';
 EXEC sys.sp_set_session_context @key=N'UserId',@value=@actor;
 -- Locations have no public creation procedure; insert reference rows only, no DDL.
 INSERT iot.Locations(LocationName,LocationType,District)
 SELECT N'TV5v2 Site '+CONVERT(NVARCHAR(2),value),N'CAMPUS',N'Thu Duc' FROM GENERATE_SERIES(1,3) g
 WHERE NOT EXISTS(SELECT 1 FROM iot.Locations l WHERE l.LocationName=N'TV5v2 Site '+CONVERT(NVARCHAR(2),g.value));
 DECLARE product_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT value FROM GENERATE_SERIES(1,@Products);
 OPEN product_cursor; FETCH NEXT FROM product_cursor INTO @n;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @key=FORMAT(@n,'000'); SET @name=N'TV5v2 Fruit '+@key;
  SELECT @id=ObjectId FROM report.SeedItems WHERE Kind=N'Product' AND ItemKey=@key;
  IF NOT EXISTS(SELECT 1 FROM report.SeedItems WHERE Kind=N'Product' AND ItemKey=@key)
  BEGIN
   SET @id=NULL;
   DECLARE @price DECIMAL(12,2)=10000+@n*1000;
   EXEC inventory.sp_AddProduct @ProductName=@name,@Price=@price,@ShelfLifeHours=72;
   SELECT @id=ProductId FROM inventory.Product WHERE ProductName=@name;
   IF @id IS NULL THROW 50411,N'AddProduct không trả ra sản phẩm thực.',1;
   INSERT report.SeedItems(Kind,ItemKey,ObjectId) VALUES(N'Product',@key,@id);
  END;
  FETCH NEXT FROM product_cursor INTO @n;
 END;
 CLOSE product_cursor; DEALLOCATE product_cursor;
 DECLARE machine_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT value FROM GENERATE_SERIES(1,@Machines);
 OPEN machine_cursor; FETCH NEXT FROM machine_cursor INTO @n;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @key=FORMAT(@n,'000'); SET @name=N'TV5v2-M-'+@key;
  IF NOT EXISTS(SELECT 1 FROM report.SeedItems WHERE Kind=N'Machine' AND ItemKey=@key)
  BEGIN
   DECLARE @loc INT=(SELECT LocationId FROM iot.Locations WHERE LocationName=N'TV5v2 Site '+CONVERT(NVARCHAR(2),1+(@n-1)%3));
   SET @id=NULL;
   EXEC iot.sp_RegisterMachine @Serial=@name,@MachineName=@name,@LocationId=@loc,@ColumnCount=15,@Capacity=100;
   SELECT @id=MachineId FROM iot.Machines WHERE Serial=@name;
   IF (SELECT COUNT(*) FROM inventory.Slot WHERE MachineId=@id)<15 THROW 50411,N'RegisterMachine chưa tạo đủ ngăn thật (FV-13).',1;
   INSERT report.SeedItems(Kind,ItemKey,ObjectId) VALUES(N'Machine',@key,@id);
  END;
  FETCH NEXT FROM machine_cursor INTO @n;
 END;
 CLOSE machine_cursor; DEALLOCATE machine_cursor;
 -- Assign exactly three fixture machines to operator, one to kiosk, using auth API.
 DECLARE @operator INT=(SELECT UserId FROM auth.[User] WHERE Username=N'operator01'),@kiosk INT=(SELECT UserId FROM auth.[User] WHERE Username=N'kiosk01');
 DECLARE assignment_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT CONVERT(INT,ObjectId) FROM report.SeedItems WHERE Kind=N'Machine' AND ItemKey<=N'003';
 OPEN assignment_cursor; FETCH NEXT FROM assignment_cursor INTO @m;
 WHILE @@FETCH_STATUS=0
 BEGIN
  EXEC auth.sp_AssignMachine @UserId=@operator,@MachineId=@m,@Unassign=0;
  FETCH NEXT FROM assignment_cursor INTO @m;
 END;
 CLOSE assignment_cursor; DEALLOCATE assignment_cursor;
 SELECT @m=CONVERT(INT,ObjectId) FROM report.SeedItems WHERE Kind=N'Machine' AND ItemKey=N'001';
 EXEC auth.sp_AssignMachine @UserId=@kiosk,@MachineId=@m,@Unassign=0;
 -- One current lot per fixture product; historical order dates are adjusted only AFTER real payment/dispense.
 DECLARE batch_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT ItemKey,CONVERT(INT,ObjectId) FROM report.SeedItems WHERE Kind=N'Product' AND ItemKey<=FORMAT(@Products,'000');
 OPEN batch_cursor; FETCH NEXT FROM batch_cursor INTO @key,@p;
 WHILE @@FETCH_STATUS=0
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM report.SeedItems WHERE Kind=N'Batch' AND ItemKey=@key)
  BEGIN
   SET @id=NULL;
   DECLARE @before INT=(SELECT COALESCE(MAX(BatchId),0) FROM inventory.StockBatch WHERE ProductId=@p);
   EXEC inventory.sp_AddBatch @ProductId=@p,@Quantity=100000,@Supplier=N'TV5 QA';
   SELECT @id=MAX(BatchId) FROM inventory.StockBatch WHERE ProductId=@p AND BatchId>@before;
   IF @id IS NULL THROW 50411,N'AddBatch không tạo lô thực.',1;
   INSERT report.SeedItems(Kind,ItemKey,ObjectId) VALUES(N'Batch',@key,@id);
  END;
  FETCH NEXT FROM batch_cursor INTO @key,@p;
 END;
 CLOSE batch_cursor; DEALLOCATE batch_cursor;
 DECLARE slots_cursor CURSOR LOCAL FAST_FORWARD FOR
 SELECT CONVERT(INT,m.ObjectId),CONVERT(INT,p.ObjectId),s.SlotId
 FROM report.SeedItems m CROSS JOIN report.SeedItems p
 CROSS APPLY(SELECT SlotId,ROW_NUMBER() OVER(ORDER BY SlotId) rn FROM inventory.Slot WHERE MachineId=m.ObjectId) s
 WHERE m.Kind=N'Machine' AND m.ItemKey<=FORMAT(@Machines,'000') AND p.Kind=N'Product' AND p.ItemKey<=FORMAT(@Products,'000') AND s.rn=CONVERT(INT,p.ItemKey);
 OPEN slots_cursor; FETCH NEXT FROM slots_cursor INTO @m,@p,@slot;
 WHILE @@FETCH_STATUS=0
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM inventory.Slot WHERE SlotId=@slot AND ProductId=@p)
   EXEC inventory.sp_AssignColumn @ColumnId=@slot,@ProductId=@p;
  FETCH NEXT FROM slots_cursor INTO @m,@p,@slot;
 END;
 CLOSE slots_cursor; DEALLOCATE slots_cursor;
 DECLARE order_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT value FROM GENERATE_SERIES(1,@Orders);
 OPEN order_cursor; FETCH NEXT FROM order_cursor INTO @n;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @key=FORMAT(@n,'00000');
  IF NOT EXISTS(SELECT 1 FROM report.SeedItems WHERE Kind=N'Order' AND ItemKey=@key)
  BEGIN
   SELECT @m=CONVERT(INT,ObjectId) FROM report.SeedItems WHERE Kind=N'Machine' AND ItemKey=FORMAT(1+(@n-1)%CASE WHEN @n<=50 THEN 5 ELSE 20 END,'000');
   DECLARE @pk NVARCHAR(3)=FORMAT(1+(@n-1)%CASE WHEN @n<=50 THEN 10 ELSE 15 END,'000');
   SELECT @p=CONVERT(INT,ObjectId) FROM report.SeedItems WHERE Kind=N'Product' AND ItemKey=@pk;
   SELECT @batch=CONVERT(INT,ObjectId) FROM report.SeedItems WHERE Kind=N'Batch' AND ItemKey=@pk;
   SET @slot=NULL;
   SELECT @slot=SlotId FROM inventory.Slot WHERE MachineId=@m AND ProductId=@p;
   IF COALESCE((SELECT SUM(Quantity) FROM inventory.SlotStock WHERE SlotId=@slot),0)<1
   BEGIN
    DECLARE @restock inventory.RestockItemType;
    DELETE @restock; INSERT @restock VALUES(@slot,@batch,20);
    EXEC inventory.sp_Restock @MachineId=@m,@UserId=@actor,@Items=@restock,@Note=N'TV5 real-procedure QA seed';
   END;
   DECLARE @items sales.OrderItemType;
   DELETE @items; INSERT @items VALUES(@slot,1);
   SET @order=NULL;
   EXEC sales.sp_CreateOrder @MachineId=@m,@Items=@items,@OrderId=@order OUTPUT;
   IF @order IS NULL OR NOT EXISTS(SELECT 1 FROM sales.[Order] WHERE OrderId=@order AND MachineId=@m AND Status=N'PENDING') THROW 50411,N'CreateOrder không tạo đơn PENDING thực.',1;
   SELECT @amount=TotalAmount FROM sales.[Order] WHERE OrderId=@order;
   SET @txn=N'TV5v2-PAY-'+@key;
   EXEC sales.sp_ConfirmPayment @OrderId=@order,@Method=N'VIETQR',@GatewayTxnId=@txn,@Amount=@amount;
   SELECT @item=OrderItemId FROM sales.OrderItem WHERE OrderId=@order;
   IF @n%97=0 EXEC sales.sp_RecordDispense @OrderItemId=@item,@Result=N'JAM',@ErrorCode=N'QA_RETRY';
   EXEC sales.sp_RecordDispense @OrderItemId=@item,@Result=N'SUCCESS';
   IF NOT EXISTS(SELECT 1 FROM sales.[Order] WHERE OrderId=@order AND Status=N'DISPENSED') THROW 50411,N'Luồng procedure không kết thúc DISPENSED.',1;
   DECLARE @at DATETIME2=DATEADD(MINUTE,ABS(CONVERT(BIGINT,CHECKSUM(NEWID())))%60,
    DATEADD(HOUR,CASE @n%6 WHEN 0 THEN 7 WHEN 1 THEN 8 WHEN 2 THEN 11 WHEN 3 THEN 12 WHEN 4 THEN 17 ELSE 18 END-7,
    DATEADD(DAY,-90+(@n-1)%90,CONVERT(DATETIME2,@HistoryEnd))));
   -- Synthetic reporting history, not evidence a real payment happened on this date.
   UPDATE sales.[Order] SET CreatedAt=@at,ExpiresAt=DATEADD(MINUTE,5,@at),PaidAt=@at,CompletedAt=@at,Note=N'TV5 synthetic history after real procedure flow' WHERE OrderId=@order;
   UPDATE sales.Payment SET PaidAt=@at WHERE OrderId=@order;
   UPDATE sales.DispenseEvents SET EventAt=@at WHERE OrderItemId=@item;
   INSERT report.SeedItems(Kind,ItemKey,ObjectId) VALUES(N'Order',@key,@order);
  END;
  FETCH NEXT FROM order_cursor INTO @n;
 END;
 CLOSE order_cursor; DEALLOCATE order_cursor;
 -- Typed telemetry uses a set-based insertion; test ingestion procedure separately.
 INSERT iot.Telemetry(MachineId,RecordedAt,Temperature,Humidity,DoorOpen)
 SELECT CONVERT(INT,m.ObjectId),ts.AtUtc,IIF(g.value%20=0,10,4),65,0
 FROM GENERATE_SERIES(1,@Packets) g JOIN report.SeedItems m ON m.Kind=N'Machine' AND m.ItemKey=FORMAT(1+(value-1)%CASE WHEN value<=500 THEN 5 ELSE 20 END,'000')
 CROSS APPLY(VALUES(DATEADD(SECOND,CONVERT(INT,CONVERT(BIGINT,value-1)*7776000/200000),DATEADD(DAY,-90,CONVERT(DATETIME2,@HistoryEnd))))) ts(AtUtc)
 WHERE NOT EXISTS(SELECT 1 FROM iot.Telemetry t WHERE t.MachineId=m.ObjectId AND t.RecordedAt=ts.AtUtc);
 EXEC report.sp_RefreshDailySummary @Date='20260806',@ToDate='20261103';
 INSERT report.SeedRuns(Profile,HistoryEnd,OrdersCreated,TelemetryCreated) VALUES(@Profile,@HistoryEnd,@Orders,@Packets);
 COMMIT;
 SELECT @Profile Profile,N'CREATED' Result,@Orders Orders,@Packets Telemetry;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
GO
'''
def seed(large=False):
    values=('LARGE',20,15,5000,200000) if large else ('SMALL',5,10,50,500)
    text=TEMPLATE
    for key,value in zip(('PROFILE','MACHINES','PRODUCTS','ORDERS','PACKETS'),values): text=text.replace('__'+key+'__',str(value))
    return text
if __name__=='__main__':
    for large,name in [(False,'80_seed_small.sql'),(True,'81_seed_large.sql')]:
        (ROOT/'sql'/name).write_text(seed(large),encoding='utf-8-sig')
