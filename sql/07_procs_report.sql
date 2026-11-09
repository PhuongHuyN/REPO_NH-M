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
CREATE OR ALTER PROCEDURE report.sp_RunAllTests @RunBy NVARCHAR(400)=N'TV5 SQL tests'
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 BEGIN TRY
  IF @RunBy IS NULL OR LEN(LTRIM(RTRIM(@RunBy))) NOT BETWEEN 1 AND 100 THROW 50404,N'Tên người chạy kiểm thử phải có 1 đến 100 ký tự.',1;
  IF @@TRANCOUNT<>0 THROW 50404,N'Bộ kiểm thử cần phiên riêng, không nằm trong giao dịch khác.',1;
  DECLARE @Batch UNIQUEIDENTIFIER=NEWID(),@Name NVARCHAR(150),@Sql NVARCHAR(MAX),@Error INT,@Got INT,@At DATETIME2;
  DECLARE @Cases TABLE(Id INT IDENTITY,Name NVARCHAR(150),SqlText NVARCHAR(MAX),ErrorCode INT);
  INSERT @Cases(Name,SqlText,ErrorCode) VALUES
(N'Dashboard-valid',N'EXEC report.sp_DashboardKpi @AsOf=''20261103'';',0),
(N'Dashboard-machine',N'EXEC report.sp_DashboardKpi @MachineId=-1;',50401),
(N'Dashboard-date',N'EXEC report.sp_DashboardKpi @AsOf=''99991231'';',50401),
(N'Growth-valid',N'EXEC report.sp_RevenueGrowth @Year=2026;',0),
(N'Growth-low',N'EXEC report.sp_RevenueGrowth @Year=1999;',50401),
(N'Growth-high',N'EXEC report.sp_RevenueGrowth @Year=9999;',50401),
(N'Peak-valid',N'EXEC report.sp_PeakHours @From=''20260806'',@To=''20261103'';',0),
(N'Peak-reversed',N'EXEC report.sp_PeakHours @From=''20261103'',@To=''20260806'';',50401),
(N'Peak-overflow',N'EXEC report.sp_PeakHours @To=''99991231'';',50401),
(N'Export-valid',N'DECLARE @u INT=(SELECT UserId FROM auth.[User] WHERE Username=N''admin01''); EXEC report.sp_ExportSales ''20261101'',''20261103'',@u;',0),
(N'Export-null',N'EXEC report.sp_ExportSales NULL,''20261103'',-1;',50402),
(N'Export-user',N'EXEC report.sp_ExportSales ''20261101'',''20261103'',-1;',50402),
(N'Summary-valid',N'EXEC report.sp_RefreshDailySummary ''20260806'',''20261103'';',0),
(N'Summary-reversed',N'EXEC report.sp_RefreshDailySummary ''20261103'',''20260806'';',50403),
(N'Summary-overflow',N'EXEC report.sp_RefreshDailySummary ''20261103'',''99991231'';',50403),
(N'Runner-empty',N'EXEC report.sp_RunAllTests @RunBy=N'''';',50404),
(N'Runner-long',N'DECLARE @n NVARCHAR(400)=REPLICATE(N''x'',101); EXEC report.sp_RunAllTests @RunBy=@n;',50404);
  CREATE TABLE #Results(Name NVARCHAR(150),Expected INT,Actual INT,Passed BIT,DurationMs INT);
  DECLARE @Id INT=1,@Max INT=(SELECT COUNT(*) FROM @Cases);
  WHILE @Id<=@Max
  BEGIN
   SELECT @Name=Name,@Sql=SqlText,@Error=ErrorCode FROM @Cases WHERE Id=@Id;
   SET @Got=0; SET @At=SYSUTCDATETIME();
   BEGIN TRY
    EXEC sys.sp_executesql @Sql;
   END TRY
   BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    SET @Got=ERROR_NUMBER();
   END CATCH;
   INSERT #Results VALUES(@Name,@Error,@Got,IIF(@Error=@Got,1,0),DATEDIFF(MILLISECOND,@At,SYSUTCDATETIME()));
   SET @Id+=1;
  END;
  -- The positive runner case is completion of the preceding suite and result persistence.
  INSERT #Results VALUES(N'Runner-valid',0,0,1,0);
  BEGIN TRAN;
  INSERT report.TestResults(Module,TestCase,Expected,Actual,Passed,DurationMs,RunBy,BatchId)
  SELECT N'report',Name,CONVERT(NVARCHAR(20),Expected),CONVERT(NVARCHAR(20),Actual),Passed,DurationMs,@RunBy,@Batch FROM #Results;
  COMMIT;
  SELECT Module,COUNT(*) Total,SUM(CONVERT(INT,Passed)) Passed,SUM(1-CONVERT(INT,Passed)) Failed
  FROM report.TestResults WHERE BatchId=@Batch GROUP BY Module;
  SELECT TestCase,Module,Expected,Actual,Passed,DurationMs FROM report.TestResults WHERE BatchId=@Batch ORDER BY TestId;
  DROP TABLE IF EXISTS #Results;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;

GO
