-- =============================================================================
-- FILE        : 13_procs_iot.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV4 — Stored Procedures cho module IoT & Chuỗi lạnh
--               sp_RegisterMachine, sp_IngestTelemetry, sp_AcknowledgeAlert,
--               sp_ClearFault, sp_UpdateThreshold, sp_CheckHeartbeat, sp_AggregateHourly
-- =============================================================================
USE FreshVendDB;


GO
-- 1. Đăng ký máy mới (sp_RegisterMachine)
CREATE OR ALTER PROCEDURE iot.sp_RegisterMachine
@Serial NVARCHAR (50), @MachineName NVARCHAR (100), @LocationId INT, @FirmwareVersion NVARCHAR (20)='1.0.0', @ColumnCount INT=6, @Capacity INT=10
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  BEGIN TRY
    BEGIN TRANSACTION;
    -- Kiểm tra dữ liệu đầu vào
    IF LTRIM(RTRIM(@Serial)) = ''
      THROW 50300, N'Mã Serial của máy không được để trống.', 1;
    IF EXISTS (SELECT 1
               FROM   iot.Machines
               WHERE  Serial = @Serial)
      THROW 50301, N'Mã Serial máy đã tồn tại trong hệ thống.', 1;
    IF NOT EXISTS (SELECT 1
                   FROM   iot.Locations
                   WHERE  LocationId = @LocationId)
      THROW 50302, N'Địa điểm đặt máy (LocationId) không tồn tại.', 1;
    -- Thêm máy mới vào bảng iot.Machines
    INSERT  INTO iot.Machines (
      Serial,
      MachineName,
      LocationId,
      Status,
      FirmwareVersion,
      InstalledAt
    )
    VALUES                    (@Serial, @MachineName, @LocationId, 'ACTIVE', @FirmwareVersion, SYSDATETIME());
    DECLARE @NewMachineId AS INT = SCOPE_IDENTITY();
    -- Khởi tạo cấu hình ngưỡng mặc định cho máy vừa tạo (2-8 độ C)
    INSERT  INTO iot.MachineThresholds (
      MachineId,
      MinTemp,
      MaxTemp,
      DoorOpenMaxMinutes,
      ConsecutiveBreaches,
      DegradedMessage
    )
    VALUES                             (@NewMachineId, 2.00, 8.00, 2, 3, N'Nhiệt độ tủ lạnh vượt ngưỡng an toàn, vui lòng kiểm tra.');
    COMMIT TRANSACTION;
    -- Trả về thông tin máy vừa tạo
    SELECT MachineId,
           Serial,
           MachineName,
           Status
    FROM   iot.Machines
    WHERE  MachineId = @NewMachineId;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0
      ROLLBACK;
    THROW;
  END CATCH
END


GO
-- 2. Nhận dữ liệu Telemetry từ ESP32 và kiểm tra ngưỡng chuỗi lạnh (sp_IngestTelemetry)
-- =============================================================================
-- FILE        : 13_procs_iot.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV4 — Stored Procedures cho module IoT & Chuỗi lạnh
-- =============================================================================
USE FreshVendDB;


GO
CREATE OR ALTER PROCEDURE iot.sp_IngestTelemetry @Payload NVARCHAR(MAX)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Every parser receives a valid JSON expression, even during eager evaluation.
 DECLARE @Safe NVARCHAR(MAX)=CASE WHEN ISJSON(@Payload)=1 THEN @Payload ELSE N'{}' END;
 BEGIN TRY
  IF @Payload IS NULL OR ISJSON(@Payload)<>1
   THROW 50310,N'Dữ liệu payload truyền lên không phải định dạng JSON hợp lệ.',1;
  DECLARE @MachineId INT=TRY_CONVERT(INT,JSON_VALUE(@Safe,'$.machineId'));
  IF @MachineId IS NULL SELECT @MachineId=MachineId FROM iot.Machines WHERE Serial=JSON_VALUE(@Safe,'$.serial');
  IF @MachineId IS NULL OR NOT EXISTS(SELECT 1 FROM iot.Machines WHERE MachineId=@MachineId)
   THROW 50311,N'Không tìm thấy máy tương ứng với thiết bị gửi dữ liệu.',1;
  DECLARE @Array NVARCHAR(MAX)=JSON_QUERY(@Safe,'$.readings'),@Now DATETIME2(0)=SYSUTCDATETIME();
  IF @Array IS NULL OR ISJSON(@Array,ARRAY)<>1
   THROW 50312,N'readings phải là mảng có ít nhất một bản đọc hợp lệ.',1;
  DECLARE @Readings TABLE(Ordinal INT PRIMARY KEY,Temperature DECIMAL(5,2),Humidity DECIMAL(5,2),DoorOpen BIT,RecordedAt DATETIME2(0),Valid BIT);
  INSERT @Readings
  SELECT TRY_CONVERT(INT,j.[key]),TRY_CONVERT(DECIMAL(5,2),v.Temp),TRY_CONVERT(DECIMAL(5,2),v.Hum),
   CASE WHEN v.Door IN(N'1',N'true') THEN 1 ELSE 0 END,
   CASE WHEN v.AtUtc IS NULL THEN @Now ELSE CONVERT(DATETIME2(0),SWITCHOFFSET(TRY_CONVERT(DATETIMEOFFSET(0),v.AtUtc,127),'+00:00')) END,
   CASE WHEN j.type=5 AND TRY_CONVERT(DECIMAL(5,2),v.Temp) IS NOT NULL
    AND (v.Hum IS NULL OR TRY_CONVERT(DECIMAL(5,2),v.Hum) BETWEEN 0 AND 100)
    AND (v.Door IS NULL OR v.Door IN(N'0',N'1',N'true',N'false'))
    AND (v.AtUtc IS NULL OR TRY_CONVERT(DATETIMEOFFSET(0),v.AtUtc,127) IS NOT NULL) THEN 1 ELSE 0 END
  FROM OPENJSON(@Array) j
  CROSS APPLY(VALUES(CASE WHEN j.type=5 THEN j.value ELSE N'{}' END)) safe(Value)
  CROSS APPLY(VALUES(JSON_VALUE(safe.Value,'$.temp'),JSON_VALUE(safe.Value,'$.hum'),JSON_VALUE(safe.Value,'$.door'),JSON_VALUE(safe.Value,'$.t'))) v(Temp,Hum,Door,AtUtc);
  IF NOT EXISTS(SELECT 1 FROM @Readings) OR EXISTS(SELECT 1 FROM @Readings WHERE Valid=0)
   THROW 50312,N'Mảng readings rỗng hoặc có dữ liệu cảm biến không hợp lệ.',1;
  BEGIN TRAN;
  INSERT iot.Telemetry(MachineId,Temperature,Humidity,DoorOpen,RecordedAt)
  SELECT @MachineId,Temperature,Humidity,DoorOpen,RecordedAt FROM @Readings;
  UPDATE iot.Machines SET LastHeartbeat=@Now WHERE MachineId=@MachineId;
  COMMIT;
  SELECT m.MachineId,m.Status,(SELECT TOP(1) Temperature FROM @Readings ORDER BY Ordinal DESC) LastTemp
  FROM iot.Machines m WHERE m.MachineId=@MachineId;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO
-- 3. Acknowledge an existing alert.
CREATE OR ALTER PROCEDURE iot.sp_AcknowledgeAlert
@AlertId INT, @UserId INT, @Resolve BIT=0
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    IF NOT EXISTS (SELECT 1
                   FROM   iot.Alerts
                   WHERE  AlertId = @AlertId)
      THROW 50320, N'Mã cảnh báo (AlertId) không tồn tại trong hệ thống.', 1;
    IF EXISTS (SELECT 1
               FROM   iot.Alerts
               WHERE  AlertId = @AlertId
                      AND ResolvedAt IS NOT NULL)
      THROW 50321, N'Cảnh báo này đã được xử lý trước đó rồi.', 1;
    UPDATE iot.Alerts
    SET    AckBy      = @UserId,
           AckAt      = SYSDATETIME(),
           ResolvedAt = CASE WHEN @Resolve = 1 THEN SYSDATETIME() ELSE ResolvedAt END
    WHERE  AlertId = @AlertId;
    SELECT AlertId,
           AlertType,
           AckBy,
           AckAt,
           ResolvedAt
    FROM   iot.Alerts
    WHERE  AlertId = @AlertId;
  END TRY
  BEGIN CATCH
    THROW;
  END CATCH
END


GO
-- 4. Xóa trạng thái lỗi/sự cố của máy (sp_ClearFault)
CREATE OR ALTER PROCEDURE iot.sp_ClearFault
@MachineId INT, @UserId INT, @Note NVARCHAR (255)=NULL
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @CurrentStatus AS NVARCHAR (20);
    SELECT @CurrentStatus = Status
    FROM   iot.Machines
    WHERE  MachineId = @MachineId;
    IF @CurrentStatus IS NULL
      THROW 50330, N'Mã máy (MachineId) không tồn tại.', 1;
    IF @CurrentStatus = 'ACTIVE'
      THROW 50331, N'Máy đang ở trạng thái hoạt động bình thường (ACTIVE), không cần xóa lỗi.', 1;
    -- Đưa máy về lại trạng thái ACTIVE và đóng toàn bộ cảnh báo đang mở
    UPDATE iot.Machines
    SET    Status = 'ACTIVE'
    WHERE  MachineId = @MachineId;
    UPDATE iot.Alerts
    SET    ResolvedAt = SYSDATETIME(),
           AckBy      = @UserId,
           AckAt      = SYSDATETIME()
    WHERE  MachineId = @MachineId
           AND ResolvedAt IS NULL;
    COMMIT TRANSACTION;
    SELECT @MachineId AS MachineId,
           @CurrentStatus AS OldStatus,
           N'ACTIVE' AS NewStatus;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0
      ROLLBACK;
    THROW;
  END CATCH
END


GO
-- 5. Cập nhật ngưỡng cảnh báo của máy (sp_UpdateThreshold)
CREATE OR ALTER PROCEDURE iot.sp_UpdateThreshold
@MachineId INT, @MinTemp DECIMAL (5, 2), @MaxTemp DECIMAL (5, 2), @DoorOpenMaxMinutes INT, @ConsecutiveBreaches INT, @DegradedMessage NVARCHAR (255)
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    IF NOT EXISTS (SELECT 1
                   FROM   iot.Machines
                   WHERE  MachineId = @MachineId)
      THROW 50340, N'Mã máy (MachineId) không tồn tại.', 1;
    IF @MinTemp >= @MaxTemp
      THROW 50341, N'Ngưỡng nhiệt độ tối thiểu (MinTemp) không thể lớn hơn hoặc bằng nhiệt độ tối đa (MaxTemp).', 1;
    UPDATE iot.MachineThresholds
    SET    MinTemp             = @MinTemp,
           MaxTemp             = @MaxTemp,
           DoorOpenMaxMinutes  = @DoorOpenMaxMinutes,
           ConsecutiveBreaches = @ConsecutiveBreaches,
           DegradedMessage     = @DegradedMessage
    WHERE  MachineId = @MachineId;
    SELECT *
    FROM   iot.MachineThresholds
    WHERE  MachineId = @MachineId;
  END TRY
  BEGIN CATCH
    THROW;
  END CATCH
END


GO
-- 6. Kiểm tra trạng thái kết nối máy — quá 5 phút không có tín hiệu thì chuyển OFFLINE (sp_CheckHeartbeat)
CREATE OR ALTER PROCEDURE iot.sp_CheckHeartbeat
@Minutes INT=5
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    -- Chuyển trạng thái máy sang OFFLINE nếu quá thời gian quy định không nhận được tín hiệu heartbeat
    UPDATE iot.Machines
    SET    Status = 'OFFLINE'
    WHERE  Status IN ('ACTIVE', 'DEGRADED')
           AND (LastHeartbeat IS NULL
                OR DATEDIFF(MINUTE, LastHeartbeat, SYSDATETIME()) >= @Minutes);
    -- Tự động sinh cảnh báo OFFLINE cho các máy vừa mất kết nối (nếu chưa có cảnh báo mở)
    INSERT INTO iot.Alerts (
      MachineId,
      AlertType,
      Severity,
      Message,
      CreatedAt
    )
    SELECT m.MachineId,
           'OFFLINE',
           'CRITICAL',
           N'Mất kết nối tín hiệu (Heartbeat timeout quá thời gian cho phép).',
           SYSDATETIME()
    FROM   iot.Machines AS m
    WHERE  m.Status = 'OFFLINE'
           AND NOT EXISTS (SELECT 1
                           FROM   iot.Alerts AS a
                           WHERE  a.MachineId = m.MachineId
                                  AND a.AlertType = 'OFFLINE'
                                  AND a.ResolvedAt IS NULL);
    SELECT @@ROWCOUNT AS MachinesOfflined;
  END TRY
  BEGIN CATCH
    THROW;
  END CATCH
END


GO
-- 7. Tổng hợp dữ liệu cảm biến theo giờ phục vụ báo cáo chuỗi lạnh (sp_AggregateHourly)
CREATE OR ALTER PROCEDURE iot.sp_AggregateHourly
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    DECLARE @HourStart AS DATETIME2 (0) = DATEADD(HOUR, DATEDIFF(HOUR, 0, DATEADD(MINUTE, -1, SYSDATETIME())), 0);
    MERGE INTO iot.TelemetryHourly
     AS target
    USING (SELECT   MachineId,
                    @HourStart AS HourStart,
                    MIN(Temperature) AS MinTemp,
                    MAX(Temperature) AS MaxTemp,
                    AVG(Temperature) AS AvgTemp,
                    COUNT(*) AS ReadingCount,
                    SUM(CASE WHEN Temperature < 2.00
                                  OR Temperature > 8.00 THEN 1 ELSE 0 END) AS MinutesOutOfRange
           FROM     iot.Telemetry
           WHERE    RecordedAt >= @HourStart
                    AND RecordedAt < DATEADD(HOUR, 1, @HourStart)
           GROUP BY MachineId) AS source ON (target.MachineId = source.MachineId
                                             AND target.HourStart = source.HourStart)
    WHEN MATCHED THEN UPDATE 
    SET MinTemp           = source.MinTemp,
        MaxTemp           = source.MaxTemp,
        AvgTemp           = source.AvgTemp,
        ReadingCount      = source.ReadingCount,
        MinutesOutOfRange = source.MinutesOutOfRange
    WHEN NOT MATCHED THEN INSERT (
      MachineId,
      HourStart,
      MinTemp,
      MaxTemp,
      AvgTemp,
      ReadingCount,
      MinutesOutOfRange
    ) VALUES (source.MachineId, source.HourStart, source.MinTemp, source.MaxTemp, source.AvgTemp, source.ReadingCount, source.MinutesOutOfRange);
    PRINT N'Tổng hợp dữ liệu TelemetryHourly thành công cho khung giờ: ' + CONVERT (NVARCHAR (30), @HourStart, 120);
  END TRY
  BEGIN CATCH
    THROW;
  END CATCH
END


GO
PRINT N'[13-iot] Các Stored Procedures của module IoT đã được tạo thành công.';