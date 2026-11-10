USE FreshVendDB;
GO
CREATE OR ALTER PROCEDURE report.sp_DashboardKpi @AsOf DATE=NULL,@MachineId INT=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF @AsOf='99991231' THROW 50401,N'Ngày báo cáo nằm ngoài phạm vi hỗ trợ.',1;
 IF @MachineId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM iot.Machines WHERE MachineId=@MachineId)
   THROW 50401,N'Máy bán hàng không tồn tại.',1;
 SET @AsOf=COALESCE(@AsOf,CONVERT(DATE,DATEADD(HOUR,7,SYSUTCDATETIME())));
 SELECT COALESCE(SUM(CASE WHEN CONVERT(DATE,DATEADD(HOUR,7,CreatedAt))=@AsOf THEN TotalAmount END),0) RevenueToday,
 COUNT(CASE WHEN CONVERT(DATE,DATEADD(HOUR,7,CreatedAt))=@AsOf THEN 1 END) OrdersToday,
 COALESCE(SUM(CASE WHEN CONVERT(DATE,DATEADD(HOUR,7,CreatedAt))=DATEADD(DAY,-1,@AsOf) THEN TotalAmount END),0) RevenueYesterday,
 (SELECT COUNT(*) FROM iot.Machines WHERE @MachineId IS NULL OR MachineId=@MachineId) MachinesTotal,
 (SELECT COUNT(*) FROM iot.Machines WHERE Status=N'ACTIVE' AND (@MachineId IS NULL OR MachineId=@MachineId)) MachinesActive,
 (SELECT COUNT(*) FROM iot.Alerts a WHERE a.ResolvedAt IS NULL AND (@MachineId IS NULL OR a.MachineId=@MachineId)) OpenAlerts,
 (SELECT COUNT(*) FROM iot.Alerts a WHERE a.ResolvedAt IS NULL AND a.Severity=N'HIGH' AND (@MachineId IS NULL OR a.MachineId=@MachineId)) HighAlerts,
 (SELECT CONVERT(DECIMAL(8,2),SUM(CONVERT(BIGINT,CASE WHEN a.Result=N'JAM' THEN 1 ELSE 0 END))*100.0/NULLIF(COUNT_BIG(*),0))
  FROM sales.DispenseEvents a JOIN sales.OrderItem i ON i.OrderItemId=a.OrderItemId JOIN sales.[Order] o ON o.OrderId=i.OrderId
  WHERE @MachineId IS NULL OR o.MachineId=@MachineId) JamRatePercent,
 (SELECT CONVERT(DECIMAL(8,2),100.0*SUM(InRangeSeconds)/NULLIF(SUM(MonitoredSeconds),0)) FROM report.vw_ColdChainCompliance
  WHERE @MachineId IS NULL OR MachineId=@MachineId) ColdChainPercent
 FROM sales.[Order] WHERE Status IN(N'PAID',N'DISPENSED') AND (@MachineId IS NULL OR MachineId=@MachineId);
 SELECT DATEADD(DAY,-g.value,@AsOf) SalesDate,COALESCE(SUM(o.TotalAmount),0) Revenue,COUNT(o.OrderId) Orders
 FROM GENERATE_SERIES(0,13) g LEFT JOIN sales.[Order] o
 ON o.CreatedAt>=DATEADD(HOUR,-7,CONVERT(DATETIME2,DATEADD(DAY,-g.value,@AsOf)))
 AND o.CreatedAt<DATEADD(HOUR,17,CONVERT(DATETIME2,DATEADD(DAY,-g.value,@AsOf)))
 AND o.Status IN(N'PAID',N'DISPENSED') AND (@MachineId IS NULL OR o.MachineId=@MachineId)
 GROUP BY g.value ORDER BY SalesDate;
 SELECT TOP(5) p.ProductId,p.ProductName,SUM(CONVERT(BIGINT,i.Quantity)) QtySold,SUM(i.LineTotal) Revenue
 FROM sales.[Order] o JOIN sales.OrderItem i ON i.OrderId=o.OrderId JOIN inventory.Product p ON p.ProductId=i.ProductId
 WHERE o.Status IN(N'PAID',N'DISPENSED') AND o.CreatedAt>=DATEADD(HOUR,-7,CONVERT(DATETIME2,DATEADD(DAY,-29,@AsOf)))
 AND o.CreatedAt<DATEADD(HOUR,17,CONVERT(DATETIME2,@AsOf)) AND (@MachineId IS NULL OR o.MachineId=@MachineId)
 GROUP BY p.ProductId,p.ProductName ORDER BY Revenue DESC,p.ProductId;
END;

GO
CREATE OR ALTER PROCEDURE report.sp_RevenueGrowth @Year INT=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET @Year=COALESCE(@Year,YEAR(DATEADD(HOUR,7,SYSUTCDATETIME())));
 IF @Year NOT BETWEEN 2000 AND 9998 THROW 50401,N'Năm báo cáo phải từ 2000 đến 9998.',1;
 WITH Monthly AS (
 SELECT g.value Month,COALESCE(SUM(o.TotalAmount),0) Revenue,COALESCE(SUM(q.QtySold),0) QtySold,COUNT(o.OrderId) Orders
 FROM GENERATE_SERIES(1,12) g LEFT JOIN sales.[Order] o
 ON o.CreatedAt>=DATEADD(HOUR,-7,CONVERT(DATETIME2,DATEFROMPARTS(@Year,g.value,1)))
 AND o.CreatedAt<DATEADD(HOUR,-7,CONVERT(DATETIME2,DATEADD(MONTH,1,DATEFROMPARTS(@Year,g.value,1))))
 AND o.Status IN(N'PAID',N'DISPENSED')
 LEFT JOIN (SELECT OrderId,SUM(CONVERT(BIGINT,Quantity)) QtySold FROM sales.OrderItem GROUP BY OrderId) q ON q.OrderId=o.OrderId GROUP BY g.value
 ), Previous AS (SELECT *,LAG(Revenue) OVER(ORDER BY Month) PreviousRevenue FROM Monthly)
 SELECT @Year Year,Month AS MonthNo,Revenue,QtySold,Orders,PreviousRevenue AS PrevRevenue,
 CONVERT(DECIMAL(12,2),100.0*(Revenue-PreviousRevenue)/NULLIF(PreviousRevenue,0)) GrowthPercent,
 SUM(Revenue) OVER(ORDER BY Month ROWS UNBOUNDED PRECEDING) RunningTotal FROM Previous ORDER BY Month;
END;

GO
CREATE OR ALTER PROCEDURE report.sp_PeakHours @From DATE=NULL,@To DATE=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET @To=COALESCE(@To,CONVERT(DATE,DATEADD(HOUR,7,SYSUTCDATETIME())));
 SET @From=COALESCE(@From,DATEADD(DAY,-29,@To));
 IF @From>@To THROW 50401,N'Ngày bắt đầu phải trước hoặc bằng ngày kết thúc.',1;
 IF @To='99991231' THROW 50401,N'Ngày kết thúc nằm ngoài phạm vi hỗ trợ.',1;
 WITH Source AS (
 SELECT DATEPART(HOUR,DATEADD(HOUR,7,o.CreatedAt)) HourOfDay,
 CASE ((DATEDIFF(DAY,CONVERT(DATE,'19000101'),CONVERT(DATE,DATEADD(HOUR,7,o.CreatedAt)))%7+7)%7)
 WHEN 0 THEN N'T2' WHEN 1 THEN N'T3' WHEN 2 THEN N'T4' WHEN 3 THEN N'T5' WHEN 4 THEN N'T6' WHEN 5 THEN N'T7' ELSE N'CN' END DayLabel,
 1 Cnt FROM sales.[Order] o WHERE o.Status IN(N'PAID',N'DISPENSED')
 AND o.CreatedAt>=DATEADD(HOUR,-7,CONVERT(DATETIME2,@From)) AND o.CreatedAt<DATEADD(HOUR,17,CONVERT(DATETIME2,@To))
 ), Pivoted AS (SELECT * FROM Source PIVOT(SUM(Cnt) FOR DayLabel IN([T2],[T3],[T4],[T5],[T6],[T7],[CN])) p)
 SELECT g.value HourOfDay,COALESCE(T2,0) T2,COALESCE(T3,0) T3,COALESCE(T4,0) T4,COALESCE(T5,0) T5,
 COALESCE(T6,0) T6,COALESCE(T7,0) T7,COALESCE(CN,0) CN,
 COALESCE(T2,0)+COALESCE(T3,0)+COALESCE(T4,0)+COALESCE(T5,0)+COALESCE(T6,0)+COALESCE(T7,0)+COALESCE(CN,0) Total
 FROM GENERATE_SERIES(0,23) g LEFT JOIN Pivoted p ON p.HourOfDay=g.value ORDER BY g.value;
END;

GO
CREATE OR ALTER PROCEDURE report.sp_ExportSales
 @From DATE,@To DATE,@UserId INT,@LocationId INT=NULL,@FileFormat NVARCHAR(10)=N'CSV'
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 BEGIN TRY
  IF @From IS NULL OR @To IS NULL OR @From>@To OR @To='99991231' THROW 50402,N'Khoảng thời gian xuất báo cáo không hợp lệ',1;
  IF @FileFormat IS NULL OR @FileFormat NOT IN(N'CSV',N'PDF') THROW 50402,N'Định dạng xuất phải là CSV hoặc PDF.',1;
  IF NOT EXISTS(SELECT 1 FROM auth.[User] WHERE UserId=@UserId) THROW 50402,N'Người dùng không tồn tại.',1;
  IF @LocationId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM iot.Locations WHERE LocationId=@LocationId) THROW 50402,N'Địa điểm không tồn tại.',1;
  DECLARE @Started DATETIME2=SYSUTCDATETIME(),@Params NVARCHAR(MAX);
  SET @Params=(SELECT @From [from],@To [to],@LocationId locationId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  BEGIN TRAN;
  SELECT o.OrderId,o.CreatedAt,l.LocationName,m.Serial,p.ProductName,
         i.Quantity Qty,i.UnitPrice,i.LineTotal,o.Status,
         (SELECT TOP(1) PaymentMethod FROM sales.Payment WHERE OrderId=o.OrderId ORDER BY PaymentId DESC) PaymentMethod
  INTO #Export FROM sales.[Order] o JOIN sales.OrderItem i ON i.OrderId=o.OrderId
  JOIN inventory.Product p ON p.ProductId=i.ProductId JOIN iot.Machines m ON m.MachineId=o.MachineId
  LEFT JOIN iot.Locations l ON l.LocationId=m.LocationId
  WHERE o.Status IN(N'PAID',N'DISPENSED',N'REFUNDED',N'DISPENSE_FAILED') AND o.CreatedAt>=DATEADD(HOUR,-7,CONVERT(DATETIME2,@From))
  AND o.CreatedAt<DATEADD(HOUR,17,CONVERT(DATETIME2,@To)) AND (@LocationId IS NULL OR m.LocationId=@LocationId);
  -- PENDING: SQL prepares rows; the application must render and confirm delivery.
  INSERT report.ExportLogs(UserId,ReportName,Params,FileFormat,[RowCount],DurationMs,Status)
  SELECT @UserId,N'SalesExport',@Params,@FileFormat,COUNT(*),DATEDIFF(MILLISECOND,@Started,SYSUTCDATETIME()),N'PENDING' FROM #Export;
  COMMIT;
  SELECT * FROM #Export ORDER BY CreatedAt,OrderId,ProductName;
  DROP TABLE IF EXISTS #Export;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;

GO
CREATE OR ALTER PROCEDURE report.sp_RefreshDailySummary @Date DATE=NULL,@ToDate DATE=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 BEGIN TRY
  SET @Date=COALESCE(@Date,CONVERT(DATE,DATEADD(HOUR,7,SYSUTCDATETIME())));
  SET @ToDate=COALESCE(@ToDate,@Date);
  IF @Date>@ToDate OR @ToDate='99991231' THROW 50403,N'Khoảng ngày tổng hợp không hợp lệ.',1;
  BEGIN TRAN;
  -- Delete/rebuild also removes stale rows when orders are cancelled/refunded.
  DELETE FROM report.DailySalesSummary WITH (TABLOCKX) WHERE SummaryDate BETWEEN @Date AND @ToDate;
  INSERT report.DailySalesSummary(SummaryDate,MachineId,ProductId,QtySold,Revenue,OrderCount,AvgUnitPrice,TotalDiscount)
  SELECT CONVERT(DATE,DATEADD(HOUR,7,o.CreatedAt)),o.MachineId,i.ProductId,SUM(CONVERT(INT,i.Quantity)),
   SUM(i.LineTotal),COUNT(DISTINCT o.OrderId),SUM(i.LineTotal)/NULLIF(SUM(CONVERT(INT,i.Quantity)),0),
   SUM(CASE WHEN o.Subtotal=0 THEN 0 ELSE o.DiscountAmount*i.LineTotal/o.Subtotal END)
  FROM sales.[Order] o JOIN sales.OrderItem i ON i.OrderId=o.OrderId
  WHERE o.Status IN(N'PAID',N'DISPENSED') AND o.CreatedAt>=DATEADD(HOUR,-7,CONVERT(DATETIME2,@Date))
  AND o.CreatedAt<DATEADD(HOUR,17,CONVERT(DATETIME2,@ToDate))
  GROUP BY CONVERT(DATE,DATEADD(HOUR,7,o.CreatedAt)),o.MachineId,i.ProductId;
  DECLARE @Rows INT=@@ROWCOUNT;
  COMMIT;
  SELECT @Date FromDate,@ToDate ToDate,@Rows RowsAffected;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;

GO
CREATE OR ALTER PROCEDURE report.sp_RunAllTests @RunBy NVARCHAR(400)=N'TV5 real SQL rollback tests'
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @RunBy IS NULL OR LEN(LTRIM(RTRIM(@RunBy))) NOT BETWEEN 1 AND 100 THROW 50404,N'Tên người chạy cần 1..100 ký tự.',1;
 IF @@TRANCOUNT<>0 THROW 50404,N'Cần phiên kiểm thử độc lập.',1;
 DECLARE @Batch UNIQUEIDENTIFIER=NEWID(),@Id INT=1,@Max INT,@Module NVARCHAR(50),@Name NVARCHAR(150),
 @Deps NVARCHAR(1000),@Fixture NVARCHAR(MAX),@Sql NVARCHAR(MAX),@Expected INT,@Actual INT,@Why NVARCHAR(500),@Message NVARCHAR(500),@Start DATETIME2,@Status NVARCHAR(10);
 DECLARE @Cases TABLE(Id INT IDENTITY,Module NVARCHAR(50),Name NVARCHAR(150),Deps NVARCHAR(1000),Fixture NVARCHAR(MAX),Body NVARCHAR(MAX),Expected INT);
 INSERT @Cases(Module,Name,Deps,Fixture,Body,Expected) VALUES
(N'auth',N'AUTH-create-valid',N'auth.sp_CreateUser',N'',N'DECLARE @name NVARCHAR(50)=N''qa_''+LEFT(CONVERT(NVARCHAR(36),NEWID()),12);
EXEC auth.sp_CreateUser @Username=@name,@Password=N''QaPassword123!'',@FullName=N''QA'',@RoleName=N''Operator'',@Email=N''qa@fixture.local'';
IF NOT EXISTS(SELECT 1 FROM auth.[User] WHERE Username=@name) THROW 50490,N''User was not created.'',1;',0),
(N'auth',N'AUTH-create-invalid-name',N'auth.sp_CreateUser',N'',N'EXEC auth.sp_CreateUser @Username=N''ab'',@Password=N''QaPassword123!'',@FullName=N''QA'',@RoleName=N''Operator'';',50001),
(N'auth',N'AUTH-create-invalid-password',N'auth.sp_CreateUser',N'',N'EXEC auth.sp_CreateUser @Username=N''qa_password'',@Password=N''123'',@FullName=N''QA'',@RoleName=N''Operator'';',50002),
(N'auth',N'AUTH-login-real',N'auth.sp_Login',N'IF NOT EXISTS(SELECT 1 FROM auth.[User] WHERE Username=N''admin'' AND IsActive=1) SET @Why=N''Cần seed tài khoản demo qua auth procedure.'';',N'DECLARE @before BIGINT=(SELECT COALESCE(MAX(LoginId),0) FROM auth.LoginHistory);
EXEC auth.sp_Login @Username=N''admin'',@Password=N''Admin@2026'',@ClientInfo=N''QA rollback test'';
IF NOT EXISTS(SELECT 1 FROM auth.LoginHistory h JOIN auth.[User] u ON u.UserId=h.UserId WHERE u.Username=N''admin'' AND h.LoginId>@before AND h.IsSuccess=1) THROW 50490,N''Login did not record a successful authentication.'',1;',0),
(N'inventory',N'INV-add-valid',N'inventory.sp_AddProduct',N'',N'DECLARE @name NVARCHAR(100)=N''QA ''+CONVERT(NVARCHAR(36),NEWID());
EXEC inventory.sp_AddProduct @ProductName=@name,@Price=15000,@ShelfLifeHours=24;
IF NOT EXISTS(SELECT 1 FROM inventory.Product WHERE ProductName=@name AND UnitPrice=15000 AND ShelfLifeHours=24) THROW 50490,N''Product values differ.'',1;',0),
(N'inventory',N'INV-add-zero-price',N'inventory.sp_AddProduct',N'',N'EXEC inventory.sp_AddProduct @ProductName=N''QA invalid'',@Price=0,@ShelfLifeHours=24;',50102),
(N'inventory',N'INV-add-empty-name',N'inventory.sp_AddProduct',N'',N'EXEC inventory.sp_AddProduct @ProductName=N'''',@Price=15000,@ShelfLifeHours=24;',50100),
(N'inventory',N'INV-update-price-valid',N'inventory.sp_AddProduct,inventory.sp_UpdatePrice',N'',N'DECLARE @n NVARCHAR(100)=N''QA ''+CONVERT(NVARCHAR(36),NEWID());
EXEC inventory.sp_AddProduct @ProductName=@n,@Price=15000,@ShelfLifeHours=24;
DECLARE @p INT=(SELECT ProductId FROM inventory.Product WHERE ProductName=@n);
EXEC inventory.sp_UpdatePrice @ProductId=@p,@NewPrice=16000;
IF NOT EXISTS(SELECT 1 FROM inventory.Product WHERE ProductId=@p AND UnitPrice=16000) THROW 50490,N''Price unchanged.'',1;',0),
(N'inventory',N'INV-price-invalid-id',N'inventory.sp_UpdatePrice',N'',N'EXEC inventory.sp_UpdatePrice @ProductId=-1,@NewPrice=16000;',50103),
(N'inventory',N'INV-batch-zero',N'inventory.sp_AddBatch',N'IF NOT EXISTS(SELECT 1 FROM inventory.Product WHERE IsActive=1 AND IsDeleted=0) SET @Why=N''Cần sản phẩm fixture hợp lệ.'';',N'DECLARE @p INT=(SELECT TOP(1) ProductId FROM inventory.Product WHERE IsActive=1 AND IsDeleted=0); EXEC inventory.sp_AddBatch @ProductId=@p,@Quantity=0;',50113),
(N'inventory',N'INV-restock-empty',N'inventory.sp_Restock,TYPE:inventory.RestockItemType',N'IF OBJECT_ID(N''inventory.Machine'',N''V'') IS NULL SET @Why=N''Chưa hợp nhất máy theo #20.'';',N'DECLARE @items inventory.RestockItemType; DECLARE @m INT=(SELECT TOP(1) MachineId FROM iot.Machines); DECLARE @u INT=(SELECT TOP(1) UserId FROM auth.[User]); EXEC inventory.sp_Restock @MachineId=@m,@UserId=@u,@Items=@items;',50111),
(N'inventory',N'INV-remove-expired-idempotent',N'inventory.sp_RemoveExpired',N'',N'EXEC inventory.sp_RemoveExpired @MachineId=-1; IF EXISTS(SELECT 1 FROM inventory.SlotStock WHERE Quantity<0) THROW 50490,N''Negative stock.'',1;',0),
(N'sales',N'SALES-empty-cart',N'sales.sp_CreateOrder,TYPE:sales.OrderItemType',N'',N'DECLARE @items sales.OrderItemType,@id BIGINT; EXEC sales.sp_CreateOrder @MachineId=-1,@Items=@items,@OrderId=@id OUTPUT;',50200),
(N'sales',N'SALES-empty-gateway',N'sales.sp_ConfirmPayment',N'',N'EXEC sales.sp_ConfirmPayment @OrderId=-1,@Method=N''VIETQR'',@GatewayTxnId=N'''',@Amount=1;',50210),
(N'sales',N'SALES-invalid-dispense-result',N'sales.sp_RecordDispense',N'',N'EXEC sales.sp_RecordDispense @OrderItemId=-1,@Result=N''INVALID'';',50211),
(N'sales',N'SALES-missing-item',N'sales.sp_RecordDispense',N'',N'EXEC sales.sp_RecordDispense @OrderItemId=-1,@Result=N''SUCCESS'';',50212),
(N'sales',N'SALES-missing-refund',N'sales.sp_Refund',N'',N'EXEC sales.sp_Refund @OrderId=-1;',50216),
(N'sales',N'SALES-invalid-expiry',N'sales.sp_ExpirePendingOrders',N'',N'EXEC sales.sp_ExpirePendingOrders @TimeoutMinutes=0;',50216),
(N'iot',N'IOT-register-real',N'iot.sp_RegisterMachine',N'IF NOT EXISTS(SELECT 1 FROM iot.Locations) SET @Why=N''Cần địa điểm fixture.'';',N'DECLARE @s NVARCHAR(50)=N''QA-''+CONVERT(NVARCHAR(36),NEWID()),@l INT=(SELECT TOP(1) LocationId FROM iot.Locations);
EXEC iot.sp_RegisterMachine @Serial=@s,@MachineName=N''QA rollback'',@LocationId=@l;
IF NOT EXISTS(SELECT 1 FROM iot.Machines m JOIN iot.MachineThresholds t ON t.MachineId=m.MachineId WHERE m.Serial=@s AND t.MinTemp=2 AND t.MaxTemp=8) THROW 50490,N''Machine/threshold missing.'',1;',0),
(N'iot',N'IOT-register-invalid-location',N'iot.sp_RegisterMachine',N'',N'EXEC iot.sp_RegisterMachine @Serial=N''QA-invalid-location'',@MachineName=N''QA'',@LocationId=-1;',50302),
(N'iot',N'IOT-ingest-invalid-json',N'iot.sp_IngestTelemetry',N'',N'EXEC iot.sp_IngestTelemetry @Payload=N''not json'';',50310),
(N'iot',N'IOT-ingest-missing-machine',N'iot.sp_IngestTelemetry',N'',N'EXEC iot.sp_IngestTelemetry @Payload=N''{"machineId":-1,"readings":[]}'';',50311),
(N'iot',N'IOT-ingest-two-readings',N'iot.sp_IngestTelemetry',N'IF NOT EXISTS(SELECT 1 FROM iot.Machines) SET @Why=N''Cần máy fixture để gọi procedure thật.'';',N'DECLARE @m INT=(SELECT TOP(1) MachineId FROM iot.Machines),@before BIGINT;
SELECT @before=COUNT_BIG(*) FROM iot.Telemetry WHERE MachineId=@m;
DECLARE @payload NVARCHAR(MAX)=N''{"machineId":''+CONVERT(NVARCHAR(12),@m)+N'',"readings":[{"temp":4,"hum":60,"door":0},{"temp":5,"hum":61,"door":0}]}'';
EXEC iot.sp_IngestTelemetry @Payload=@payload;
IF (SELECT COUNT_BIG(*) FROM iot.Telemetry WHERE MachineId=@m)<>@before+2 THROW 50490,N''Batch ingestion lost telemetry readings.'',1;',0),
(N'iot',N'IOT-clear-missing',N'iot.sp_ClearFault',N'',N'EXEC iot.sp_ClearFault @MachineId=-1,@UserId=1;',50330),
(N'iot',N'IOT-threshold-invalid-machine',N'iot.sp_UpdateThreshold',N'',N'EXEC iot.sp_UpdateThreshold @MachineId=-1,@MinTemp=2,@MaxTemp=8,@DoorOpenMaxMinutes=2,@ConsecutiveBreaches=3,@DegradedMessage=N''QA'';',50340),
(N'iot',N'IOT-ack-missing',N'iot.sp_AcknowledgeAlert',N'',N'EXEC iot.sp_AcknowledgeAlert @AlertId=-1,@UserId=1;',50320),
(N'iot',N'IOT-partition-real',N'iot.sp_MaintainPartitions',N'',N'EXEC iot.sp_MaintainPartitions;
IF NOT EXISTS(SELECT 1 FROM sys.indexes i JOIN sys.partition_schemes ps ON ps.data_space_id=i.data_space_id WHERE i.object_id=OBJECT_ID(N''iot.Telemetry'') AND i.index_id IN(0,1)) THROW 50490,N''Telemetry is not partitioned.'',1;',0),
(N'report',N'REPORT-growth-12-months',N'report.sp_RevenueGrowth',N'',N'CREATE TABLE #Growth([Year] INT,MonthNo INT,Revenue DECIMAL(38,2),QtySold BIGINT,Orders INT,PrevRevenue DECIMAL(38,2),GrowthPercent DECIMAL(12,2),RunningTotal DECIMAL(38,2));
INSERT #Growth EXEC report.sp_RevenueGrowth @Year=2026;
IF (SELECT COUNT(*) FROM #Growth)<>12 THROW 50490,N''Expected twelve months.'',1;
IF COALESCE((SELECT SUM(Revenue) FROM #Growth),0)<>COALESCE((SELECT SUM(TotalAmount) FROM sales.[Order] WHERE Status IN(N''PAID'',N''DISPENSED'') AND CreatedAt>=''2025-12-31T17:00:00'' AND CreatedAt<''2026-12-31T17:00:00''),0) THROW 50490,N''Month revenue mismatch.'',1;',0),
(N'report',N'REPORT-invalid-year',N'report.sp_RevenueGrowth',N'',N'EXEC report.sp_RevenueGrowth @Year=1999;',50401),
(N'report',N'REPORT-reversed-peak',N'report.sp_PeakHours',N'',N'EXEC report.sp_PeakHours ''20261103'',''20260806'';',50401),
(N'report',N'REPORT-invalid-export',N'report.sp_ExportSales',N'',N'EXEC report.sp_ExportSales NULL,''20261103'',-1;',50402),
(N'report',N'REPORT-reversed-summary',N'report.sp_RefreshDailySummary',N'',N'EXEC report.sp_RefreshDailySummary ''20261103'',''20260806'';',50403),
(N'report',N'REPORT-empty-runby',N'report.sp_RunAllTests',N'',N'EXEC report.sp_RunAllTests @RunBy=N'''';',50404);
 CREATE TABLE #Results(Module NVARCHAR(50),TestCase NVARCHAR(150),Expected NVARCHAR(500),Actual NVARCHAR(500),Status NVARCHAR(10),DurationMs INT,ErrorDetail NVARCHAR(MAX));
 SELECT @Max=COUNT(*) FROM @Cases;
 WHILE @Id<=@Max
 BEGIN
  SELECT @Module=Module,@Name=Name,@Deps=Deps,@Fixture=Fixture,@Sql=Body,@Expected=Expected FROM @Cases WHERE Id=@Id;
  SET @Start=SYSUTCDATETIME(); SET @Why=NULL; SET @Message=NULL; SET @Actual=0; SET @Status=N'BLOCKED';
  SELECT @Why=STRING_AGG(CONVERT(NVARCHAR(MAX),value),N', ') FROM STRING_SPLIT(@Deps,N',')
   WHERE (value LIKE N'TYPE:%' AND TYPE_ID(SUBSTRING(value,6,500)) IS NULL)
      OR (value NOT LIKE N'TYPE:%' AND OBJECT_ID(value,N'P') IS NULL);
  IF @Why IS NOT NULL SET @Why=N'Thiếu dependency: '+@Why;
  IF @Why IS NULL AND @Fixture<>N''
   BEGIN TRY
    EXEC sys.sp_executesql @Fixture,N'@Why NVARCHAR(500) OUTPUT',@Why OUTPUT;
   END TRY
   BEGIN CATCH
    SET @Why=N'Fixture/schema chưa sẵn sàng: '+ERROR_MESSAGE();
   END CATCH;
  IF @Why IS NULL
  BEGIN
   BEGIN TRY
    BEGIN TRAN;
    EXEC sys.sp_executesql @Sql;
    IF XACT_STATE()<>1 OR @@TRANCOUNT<>1 THROW 50490,N'Procedure làm mất hoặc rò transaction kiểm thử.',1;
    ROLLBACK;
   END TRY
   BEGIN CATCH
    SET @Actual=ERROR_NUMBER(); SET @Message=ERROR_MESSAGE();
    IF XACT_STATE()<>0 ROLLBACK;
   END CATCH;
   SET @Status=IIF(@Actual=@Expected,N'PASS',N'FAIL');
  END;
  INSERT #Results VALUES(@Module,@Name,CONVERT(NVARCHAR(20),@Expected),COALESCE(@Why,CONVERT(NVARCHAR(20),@Actual)),@Status,DATEDIFF(MILLISECOND,@Start,SYSUTCDATETIME()),@Message);
  SET @Id+=1;
 END;
 BEGIN TRY
  BEGIN TRAN;
  INSERT report.TestResults(Module,TestCase,Expected,Actual,Status,Passed,DurationMs,ErrorDetail,RunBy,BatchId)
  SELECT Module,TestCase,Expected,Actual,Status,IIF(Status=N'PASS',1,0),DurationMs,ErrorDetail,@RunBy,@Batch FROM #Results;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
 SELECT Module,COUNT(*) Total,SUM(IIF(Status=N'PASS',1,0)) Passed,SUM(IIF(Status=N'FAIL',1,0)) Failed,SUM(IIF(Status=N'BLOCKED',1,0)) Blocked
 FROM #Results GROUP BY Module ORDER BY Module;
 SELECT t.TestCase,t.Module,t.Expected,t.Actual,t.Passed,t.Status,t.DurationMs,t.ErrorDetail,t.RunAt,t.BatchId
 FROM report.TestResults t WHERE t.BatchId=@Batch ORDER BY t.TestId;
 DROP TABLE IF EXISTS #Results;
END;
GO
