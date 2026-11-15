-- =============================================================================
-- FILE        : 02_tables_iot.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV4 — Tạo các bảng thuộc schema [iot]
--               Locations, Machines, MachineThresholds, Telemetry, 
--               TelemetryHourly, Alerts
-- VERSION     : 1.1.0
-- CREATED     : 2026-10-30
-- RUN ORDER   : Bước 2 — sau 02_tables_sales.sql
-- NOTE        : FK tham chiếu sang auth.User và cấu trúc chuẩn cho IoT & Chuỗi lạnh
-- =============================================================================
USE FreshVendDB;


GO
-- =============================================================================
-- 1. iot.Locations  — Danh mục địa điểm đặt máy
-- =============================================================================
IF NOT EXISTS (SELECT 1
               FROM   sys.tables AS t
                      INNER JOIN
                      sys.schemas AS s
                      ON t.schema_id = s.schema_id
               WHERE  s.name = 'iot'
                      AND t.name = 'Locations')
    BEGIN
        CREATE TABLE iot.Locations (
            LocationId   INT            IDENTITY (1, 1) PRIMARY KEY,
            LocationName NVARCHAR (100) NOT NULL,
            LocationType NVARCHAR (50)  CHECK (LocationType IN ('OFFICE', 'CAMPUS', 'RESIDENTIAL')),
            Address      NVARCHAR (255),
            District     NVARCHAR (100)
        );
        PRINT N'[02-iot] Bảng iot.Locations đã được tạo.';
    END
ELSE
    PRINT N'[02-iot] Bảng iot.Locations đã tồn tại — bỏ qua.';


GO
-- =============================================================================
-- 2. iot.Machines  — Danh mục loại cảm biến
-- =============================================================================
IF NOT EXISTS (SELECT 1
               FROM   sys.tables AS t
                      INNER JOIN
                      sys.schemas AS s
                      ON t.schema_id = s.schema_id
               WHERE  s.name = 'iot'
                      AND t.name = 'Machines')
    BEGIN
        CREATE TABLE iot.Machines (
            MachineId       INT            IDENTITY (1, 1) PRIMARY KEY,
            Serial          NVARCHAR (50)  UNIQUE NOT NULL,
            MachineName     NVARCHAR (100) NOT NULL,
            LocationId      INT            FOREIGN KEY REFERENCES iot.Locations (LocationId),
            Status          NVARCHAR (20)  DEFAULT 'ACTIVE' CHECK (Status IN ('ACTIVE', 'DEGRADED', 'OFFLINE', 'FAULT')),
            FirmwareVersion NVARCHAR (20) ,
            LastHeartbeat   DATETIME2 (0) ,
            InstalledAt     DATETIME2 (0)  DEFAULT SYSDATETIME()
        );
        PRINT N'[02-iot] Bảng iot.Machines đã được tạo.';
    END
ELSE
    PRINT N'[02-iot] Bảng iot.Machines đã tồn tại — bỏ qua.';


GO
-- =============================================================================
-- QĐ-1. Hợp nhất inventory.Machine vào iot.Machines
-- Gỡ các FK đã biết trỏ tới bảng cũ; 03_foreign_keys.sql sẽ tạo lại chúng
-- trỏ trực tiếp tới iot.Machines.
-- =============================================================================
IF OBJECT_ID(N'inventory.Machine', N'U') IS NOT NULL
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_inventory_Slot_Machine')
            EXEC sys.sp_executesql N'ALTER TABLE inventory.Slot DROP CONSTRAINT FK_inventory_Slot_Machine;';
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sales_Order_inventory_Machine')
            EXEC sys.sp_executesql N'ALTER TABLE sales.[Order] DROP CONSTRAINT FK_sales_Order_inventory_Machine;';
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_iot_Device_inventory_Machine')
            EXEC sys.sp_executesql N'ALTER TABLE iot.Device DROP CONSTRAINT FK_iot_Device_inventory_Machine;';
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_DailySalesSummary_MachineId')
            EXEC sys.sp_executesql N'ALTER TABLE report.DailySalesSummary DROP CONSTRAINT FK_DailySalesSummary_MachineId;';
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_report_MachineStockSnapshot_inventory_Machine')
            EXEC sys.sp_executesql N'ALTER TABLE report.MachineStockSnapshot DROP CONSTRAINT FK_report_MachineStockSnapshot_inventory_Machine;';

        IF EXISTS (
            SELECT 1 FROM sys.foreign_keys
            WHERE referenced_object_id = OBJECT_ID(N'inventory.Machine', N'U')
        )
        BEGIN
            ;THROW 50380, N'Không thể thay inventory.Machine vì vẫn còn FK chưa được nhận diện trỏ tới bảng này.', 1;
        END;

        DROP TABLE inventory.Machine;
        COMMIT TRANSACTION;
        PRINT N'[02-iot] Bảng vật lý inventory.Machine rỗng đã được gỡ bỏ.';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER VIEW inventory.Machine
AS
SELECT m.MachineId,
       m.Serial AS MachineCode,
       m.MachineName,
       CONVERT(NVARCHAR(200), l.LocationName) AS Location,
       CONVERT(DECIMAL(10,7), NULL) AS Latitude,
       CONVERT(DECIMAL(10,7), NULL) AS Longitude,
       CONVERT(NVARCHAR(20), CASE m.Status
           WHEN N'ACTIVE' THEN N'online'
           WHEN N'DEGRADED' THEN N'maintenance'
           WHEN N'OFFLINE' THEN N'offline'
           WHEN N'FAULT' THEN N'error'
       END) AS Status,
       CONVERT(BIT, 1) AS IsActive,
       m.LocationId,
       CONVERT(DATE, m.InstalledAt) AS InstallDate,
       CONVERT(DATE, NULL) AS LastServiceDate,
       m.InstalledAt AS CreatedAt,
       m.LastHeartbeat AS UpdatedAt,
       m.FirmwareVersion,
       m.LastHeartbeat,
       m.InstalledAt
FROM iot.Machines AS m
LEFT JOIN iot.Locations AS l ON l.LocationId = m.LocationId;
GO
PRINT N'[02-iot] View inventory.Machine đã được tạo từ iot.Machines.';
GO

-- 2b. iot.Device — Quản lý thiết bị phần cứng IoT
IF OBJECT_ID(N'iot.Device', N'U') IS NULL
BEGIN
    CREATE TABLE iot.Device (
        DeviceId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_iot_Device PRIMARY KEY,
        MachineId  INT NOT NULL,
        DeviceCode NVARCHAR(50) NOT NULL,
        DeviceType NVARCHAR(50) NOT NULL,
        Status     NVARCHAR(20) NOT NULL CONSTRAINT DF_iot_Device_Status DEFAULT (N'ACTIVE'),
        CreatedAt  DATETIME2(0) NOT NULL CONSTRAINT DF_iot_Device_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_iot_Device_Machines FOREIGN KEY (MachineId) REFERENCES iot.Machines(MachineId)
    );
END;
GO

-- =============================================================================
-- 3. iot.MachineThresholds  — Cấu hình ngưỡng cảnh báo theo từng máy
-- =============================================================================
IF NOT EXISTS (SELECT 1
               FROM   sys.tables AS t
                      INNER JOIN
                      sys.schemas AS s
                      ON t.schema_id = s.schema_id
               WHERE  s.name = 'iot'
                      AND t.name = 'MachineThresholds')
    BEGIN
        CREATE TABLE iot.MachineThresholds (
            MachineId           INT            PRIMARY KEY FOREIGN KEY REFERENCES iot.Machines (MachineId),
            MinTemp             DECIMAL (5, 2) DEFAULT 2.00,
            MaxTemp             DECIMAL (5, 2) DEFAULT 8.00,
            DoorOpenMaxMinutes  INT            DEFAULT 2,
            ConsecutiveBreaches INT            DEFAULT 3,
            DegradedMessage     NVARCHAR (255) DEFAULT N'Nhiệt độ tủ lạnh vượt ngưỡng an toàn, vui lòng kiểm tra.'
        );
        PRINT N'[02-iot] Bảng iot.MachineThresholds đã được tạo.';
    END
ELSE
    PRINT N'[02-iot] Bảng iot.MachineThresholds đã tồn tại — bỏ qua.';


GO
-- =============================================================================
-- 4. iot.Telemetry  — Dữ liệu cảm biến thời gian thực từ thiết bị[cite: 6]
-- =============================================================================
IF NOT EXISTS (SELECT 1
               FROM   sys.tables
               WHERE  object_id = OBJECT_ID(N'iot.Telemetry'))
    BEGIN
        CREATE TABLE iot.Telemetry (
            ReadingId   BIGINT         IDENTITY (1, 1) PRIMARY KEY,
            MachineId   INT            FOREIGN KEY REFERENCES iot.Machines (MachineId),
            RecordedAt  DATETIME2 (0)  DEFAULT SYSDATETIME(),
            Temperature DECIMAL (5, 2),
            Humidity    DECIMAL (5, 2),
            DoorOpen    BIT           
        );
        PRINT N'[02-iot] Bảng iot.Telemetry đã được tạo.';
    END
ELSE
    PRINT N'[02-iot] Bảng iot.Telemetry đã tồn tại — bỏ qua.';


GO
DROP INDEX IF EXISTS IX_Telemetry_Machine_Recorded ON iot.Telemetry;
GO
CREATE NONCLUSTERED INDEX IX_Telemetry_Machine_Recorded
    ON iot.Telemetry(MachineId, RecordedAt DESC);
GO

-- =============================================================================
-- 5. iot.TelemetryHourly  — Tổng hợp dữ liệu cảm biến theo giờ (phục vụ báo cáo)[cite: 6]
-- =============================================================================
IF NOT EXISTS (SELECT 1
               FROM   sys.tables AS t
                      INNER JOIN
                      sys.schemas AS s
                      ON t.schema_id = s.schema_id
               WHERE  s.name = 'iot'
                      AND t.name = 'TelemetryHourly')
    BEGIN
        CREATE TABLE iot.TelemetryHourly (
            MachineId         INT            FOREIGN KEY REFERENCES iot.Machines (MachineId),
            HourStart         DATETIME2 (0) ,
            MinTemp           DECIMAL (5, 2),
            MaxTemp           DECIMAL (5, 2),
            AvgTemp           DECIMAL (5, 2),
            ReadingCount      INT           ,
            MinutesOutOfRange INT           ,
            PRIMARY KEY (MachineId, HourStart)
        );
        PRINT N'[02-iot] Bảng iot.TelemetryHourly đã được tạo.';
    END
ELSE
    PRINT N'[02-iot] Bảng iot.TelemetryHourly đã tồn tại — bỏ qua.';


GO
-- =============================================================================
-- 6. iot.Alert  — Lịch sử cảnh báo được sinh ra
-- =============================================================================
IF OBJECT_ID(N'iot.Alerts', N'U') IS NOT NULL
BEGIN
    IF OBJECT_ID(N'iot.Alert') IS NOT NULL
    BEGIN
        ;THROW 50382, N'Cả iot.Alerts và iot.Alert cùng tồn tại; cần hợp nhất dữ liệu trước khi cài đặt.', 1;
    END;
    EXEC sys.sp_rename N'iot.Alerts', N'Alert';
END;

IF NOT EXISTS (SELECT 1
               FROM   sys.tables
               WHERE  object_id = OBJECT_ID(N'iot.Alert', N'U'))
    BEGIN
        CREATE TABLE iot.Alert (
            AlertId    INT            IDENTITY (1, 1) PRIMARY KEY,
            MachineId  INT            FOREIGN KEY REFERENCES iot.Machines (MachineId),
            AlertType  NVARCHAR (50)  NOT NULL,
            Severity   NVARCHAR (20)  CHECK (Severity IN ('INFO', 'HIGH', 'MEDIUM', 'CRITICAL')),
            Message    NVARCHAR (255),
            RefKey     NVARCHAR (100),
            CreatedAt  DATETIME2 (0)  DEFAULT SYSDATETIME(),
            AckBy      INT           ,
            AckAt      DATETIME2 (0) ,
            ResolvedAt DATETIME2 (0) 
        );
        PRINT N'[02-iot] Bảng iot.Alert đã được tạo.';
    END
ELSE
    PRINT N'[02-iot] Bảng iot.Alert đã tồn tại — bỏ qua.';


GO
CREATE OR ALTER VIEW iot.Alerts
AS
SELECT AlertId, MachineId, AlertType, Severity, Message, RefKey,
       CreatedAt, AckBy, AckAt, ResolvedAt
FROM iot.Alert;
GO

-- =============================================================================
-- XÁC NHẬN
-- =============================================================================
SELECT   TABLE_SCHEMA AS [Schema],
         TABLE_NAME AS [Table]
FROM     INFORMATION_SCHEMA.TABLES
WHERE    TABLE_SCHEMA = 'iot'
ORDER BY TABLE_NAME;


GO
PRINT N'';

PRINT N'================================================================';

PRINT N'  TV4 (iot) hoàn tất. Tiếp theo: 02_tables_audit.sql           ';

PRINT N'================================================================';
