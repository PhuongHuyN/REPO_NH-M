"""Generate the transaction-isolated, dependency-aware SQL test catalog."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CASES=[]
def case(module,name,dependencies,body,error=0,fixture=''):
    CASES.append((module,name,dependencies,fixture,body,error))

case('auth','AUTH-create-valid','auth.sp_CreateUser',"""DECLARE @name NVARCHAR(50)=N'qa_'+LEFT(CONVERT(NVARCHAR(36),NEWID()),12);
EXEC auth.sp_CreateUser @Username=@name,@Password=N'QaPassword123!',@FullName=N'QA',@RoleName=N'Operator',@Email=N'qa@fixture.local';
IF NOT EXISTS(SELECT 1 FROM auth.[User] WHERE Username=@name) THROW 50490,N'User was not created.',1;""")
case('auth','AUTH-create-invalid-name','auth.sp_CreateUser',"EXEC auth.sp_CreateUser @Username=N'ab',@Password=N'QaPassword123!',@FullName=N'QA',@RoleName=N'Operator';",50001)
case('auth','AUTH-create-invalid-password','auth.sp_CreateUser',"EXEC auth.sp_CreateUser @Username=N'qa_password',@Password=N'123',@FullName=N'QA',@RoleName=N'Operator';",50002)
case('auth','AUTH-login-real','auth.sp_Login',"""DECLARE @before BIGINT=(SELECT COALESCE(MAX(LoginId),0) FROM auth.LoginHistory);
EXEC auth.sp_Login @Username=N'admin',@Password=N'Admin@2026',@ClientInfo=N'QA rollback test';
IF NOT EXISTS(SELECT 1 FROM auth.LoginHistory h JOIN auth.[User] u ON u.UserId=h.UserId WHERE u.Username=N'admin' AND h.LoginId>@before AND h.IsSuccess=1) THROW 50490,N'Login did not record a successful authentication.',1;""",fixture="IF NOT EXISTS(SELECT 1 FROM auth.[User] WHERE Username=N'admin' AND IsActive=1) SET @Why=N'Cần seed tài khoản demo qua auth procedure.';")

case('inventory','INV-add-valid','inventory.sp_AddProduct',"""DECLARE @name NVARCHAR(100)=N'QA '+CONVERT(NVARCHAR(36),NEWID());
EXEC inventory.sp_AddProduct @ProductName=@name,@Price=15000,@ShelfLifeHours=24;
IF NOT EXISTS(SELECT 1 FROM inventory.Product WHERE ProductName=@name AND UnitPrice=15000 AND ShelfLifeHours=24) THROW 50490,N'Product values differ.',1;""")
case('inventory','INV-add-zero-price','inventory.sp_AddProduct',"EXEC inventory.sp_AddProduct @ProductName=N'QA invalid',@Price=0,@ShelfLifeHours=24;",50102)
case('inventory','INV-add-empty-name','inventory.sp_AddProduct',"EXEC inventory.sp_AddProduct @ProductName=N'',@Price=15000,@ShelfLifeHours=24;",50100)
case('inventory','INV-update-price-valid','inventory.sp_AddProduct,inventory.sp_UpdatePrice',"""DECLARE @n NVARCHAR(100)=N'QA '+CONVERT(NVARCHAR(36),NEWID());
EXEC inventory.sp_AddProduct @ProductName=@n,@Price=15000,@ShelfLifeHours=24;
DECLARE @p INT=(SELECT ProductId FROM inventory.Product WHERE ProductName=@n);
EXEC inventory.sp_UpdatePrice @ProductId=@p,@NewPrice=16000;
IF NOT EXISTS(SELECT 1 FROM inventory.Product WHERE ProductId=@p AND UnitPrice=16000) THROW 50490,N'Price unchanged.',1;""")
case('inventory','INV-price-invalid-id','inventory.sp_UpdatePrice',"EXEC inventory.sp_UpdatePrice @ProductId=-1,@NewPrice=16000;",50103)
case('inventory','INV-batch-zero','inventory.sp_AddBatch',"DECLARE @p INT=(SELECT TOP(1) ProductId FROM inventory.Product WHERE IsActive=1 AND IsDeleted=0); EXEC inventory.sp_AddBatch @ProductId=@p,@Quantity=0;",50113,"IF NOT EXISTS(SELECT 1 FROM inventory.Product WHERE IsActive=1 AND IsDeleted=0) SET @Why=N'Cần sản phẩm fixture hợp lệ.';")
case('inventory','INV-restock-empty','inventory.sp_Restock,TYPE:inventory.RestockItemType',"DECLARE @items inventory.RestockItemType; DECLARE @m INT=(SELECT TOP(1) MachineId FROM iot.Machines); DECLARE @u INT=(SELECT TOP(1) UserId FROM auth.[User]); EXEC inventory.sp_Restock @MachineId=@m,@UserId=@u,@Items=@items;",50111,"IF OBJECT_ID(N'inventory.Machine',N'V') IS NULL SET @Why=N'Chưa hợp nhất máy theo #20.';")
case('inventory','INV-remove-expired-idempotent','inventory.sp_RemoveExpired',"EXEC inventory.sp_RemoveExpired @MachineId=-1; IF EXISTS(SELECT 1 FROM inventory.SlotStock WHERE Quantity<0) THROW 50490,N'Negative stock.',1;")

case('sales','SALES-empty-cart','sales.sp_CreateOrder,TYPE:sales.OrderItemType',"DECLARE @items sales.OrderItemType,@id BIGINT; EXEC sales.sp_CreateOrder @MachineId=-1,@Items=@items,@OrderId=@id OUTPUT;",50200)
case('sales','SALES-empty-gateway','sales.sp_ConfirmPayment',"EXEC sales.sp_ConfirmPayment @OrderId=-1,@Method=N'VIETQR',@GatewayTxnId=N'',@Amount=1;",50210)
case('sales','SALES-invalid-dispense-result','sales.sp_RecordDispense',"EXEC sales.sp_RecordDispense @OrderItemId=-1,@Result=N'INVALID';",50211)
case('sales','SALES-missing-item','sales.sp_RecordDispense',"EXEC sales.sp_RecordDispense @OrderItemId=-1,@Result=N'SUCCESS';",50212)
case('sales','SALES-missing-refund','sales.sp_Refund',"EXEC sales.sp_Refund @OrderId=-1;",50216)
case('sales','SALES-invalid-expiry','sales.sp_ExpirePendingOrders',"EXEC sales.sp_ExpirePendingOrders @TimeoutMinutes=0;",50216)

machine_fixture="IF NOT EXISTS(SELECT 1 FROM iot.Machines) SET @Why=N'Cần máy fixture để gọi procedure thật.';"
case('iot','IOT-register-real','iot.sp_RegisterMachine',"""DECLARE @s NVARCHAR(50)=N'QA-'+CONVERT(NVARCHAR(36),NEWID()),@l INT=(SELECT TOP(1) LocationId FROM iot.Locations);
EXEC iot.sp_RegisterMachine @Serial=@s,@MachineName=N'QA rollback',@LocationId=@l;
IF NOT EXISTS(SELECT 1 FROM iot.Machines m JOIN iot.MachineThresholds t ON t.MachineId=m.MachineId WHERE m.Serial=@s AND t.MinTemp=2 AND t.MaxTemp=8) THROW 50490,N'Machine/threshold missing.',1;""",fixture="IF NOT EXISTS(SELECT 1 FROM iot.Locations) SET @Why=N'Cần địa điểm fixture.';")
case('iot','IOT-register-invalid-location','iot.sp_RegisterMachine',"EXEC iot.sp_RegisterMachine @Serial=N'QA-invalid-location',@MachineName=N'QA',@LocationId=-1;",50302)
case('iot','IOT-ingest-invalid-json','iot.sp_IngestTelemetry',"EXEC iot.sp_IngestTelemetry @Payload=N'not json';",50310)
case('iot','IOT-ingest-missing-machine','iot.sp_IngestTelemetry',"EXEC iot.sp_IngestTelemetry @Payload=N'{\"machineId\":-1,\"readings\":[]}';",50311)
case('iot','IOT-ingest-two-readings','iot.sp_IngestTelemetry',"""DECLARE @m INT=(SELECT TOP(1) MachineId FROM iot.Machines),@before BIGINT;
SELECT @before=COUNT_BIG(*) FROM iot.Telemetry WHERE MachineId=@m;
DECLARE @payload NVARCHAR(MAX)=N'{"machineId":'+CONVERT(NVARCHAR(12),@m)+N',"readings":[{"temp":4,"hum":60,"door":0},{"temp":5,"hum":61,"door":0}]}';
EXEC iot.sp_IngestTelemetry @Payload=@payload;
IF (SELECT COUNT_BIG(*) FROM iot.Telemetry WHERE MachineId=@m)<>@before+2 THROW 50490,N'Batch ingestion lost telemetry readings.',1;""",fixture=machine_fixture)
case('iot','IOT-clear-missing','iot.sp_ClearFault',"EXEC iot.sp_ClearFault @MachineId=-1,@UserId=1;",50330)
case('iot','IOT-threshold-invalid-machine','iot.sp_UpdateThreshold',"EXEC iot.sp_UpdateThreshold @MachineId=-1,@MinTemp=2,@MaxTemp=8,@DoorOpenMaxMinutes=2,@ConsecutiveBreaches=3,@DegradedMessage=N'QA';",50340)
case('iot','IOT-ack-missing','iot.sp_AcknowledgeAlert',"EXEC iot.sp_AcknowledgeAlert @AlertId=-1,@UserId=1;",50320)
case('iot','IOT-partition-real','iot.sp_MaintainPartitions',"""EXEC iot.sp_MaintainPartitions;
IF NOT EXISTS(SELECT 1 FROM sys.indexes i JOIN sys.partition_schemes ps ON ps.data_space_id=i.data_space_id WHERE i.object_id=OBJECT_ID(N'iot.Telemetry') AND i.index_id IN(0,1)) THROW 50490,N'Telemetry is not partitioned.',1;""")

case('report','REPORT-growth-12-months','report.sp_RevenueGrowth',"""CREATE TABLE #Growth([Year] INT,MonthNo INT,Revenue DECIMAL(38,2),QtySold BIGINT,Orders INT,PrevRevenue DECIMAL(38,2),GrowthPercent DECIMAL(12,2),RunningTotal DECIMAL(38,2));
INSERT #Growth EXEC report.sp_RevenueGrowth @Year=2026;
IF (SELECT COUNT(*) FROM #Growth)<>12 THROW 50490,N'Expected twelve months.',1;
IF COALESCE((SELECT SUM(Revenue) FROM #Growth),0)<>COALESCE((SELECT SUM(TotalAmount) FROM sales.[Order] WHERE Status IN(N'PAID',N'DISPENSED') AND CreatedAt>='2025-12-31T17:00:00' AND CreatedAt<'2026-12-31T17:00:00'),0) THROW 50490,N'Month revenue mismatch.',1;""")
case('report','REPORT-invalid-year','report.sp_RevenueGrowth',"EXEC report.sp_RevenueGrowth @Year=1999;",50401)
case('report','REPORT-reversed-peak','report.sp_PeakHours',"EXEC report.sp_PeakHours '20261103','20260806';",50401)
case('report','REPORT-invalid-export','report.sp_ExportSales',"EXEC report.sp_ExportSales NULL,'20261103',-1;",50402)
case('report','REPORT-reversed-summary','report.sp_RefreshDailySummary',"EXEC report.sp_RefreshDailySummary '20261103','20260806';",50403)
case('report','REPORT-empty-runby','report.sp_RunAllTests',"EXEC report.sp_RunAllTests @RunBy=N'';",50404)

def literal(s): return "N'"+s.replace("'","''")+"'"
def build():
    values=',\n'.join('('+','.join([literal(m),literal(n),literal(d),literal(f),literal(b),str(e)])+')' for m,n,d,f,b,e in CASES)
    proc="""CREATE OR ALTER PROCEDURE report.sp_RunAllTests @RunBy NVARCHAR(400)=N'TV5 real SQL rollback tests'
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
"""+values+""";
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
"""
    path=ROOT/'sql/14_procs_report.sql'
    prefix=path.read_text(encoding='utf-8-sig').split('CREATE OR ALTER PROCEDURE report.sp_RunAllTests')[0]
    path.write_text(prefix+proc,encoding='utf-8-sig')
    print(f'Generated {len(CASES)} real SQL cases covering five modules')
if __name__=='__main__': build()
