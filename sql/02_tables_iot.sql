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
        CREATE NONCLUSTERED INDEX IX_Telemetry_Machine_Recorded
            ON iot.Telemetry(MachineId, RecordedAt DESC);
        PRINT N'[02-iot] Bảng iot.Telemetry đã được tạo.';
    END
ELSE
    PRINT N'[02-iot] Bảng iot.Telemetry đã tồn tại — bỏ qua.';


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
IF NOT EXISTS (SELECT 1
               FROM   sys.tables
               WHERE  object_id = OBJECT_ID(N'iot.Alerts'))
    BEGIN
        CREATE TABLE iot.Alerts (
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