-- =============================================================================
-- FILE        : 02_tables_iot.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : TV4 — Tạo các bảng thuộc schema [iot]
--               Device, SensorType, SensorReading, Telemetry,
--               Alert, AlertRule
-- VERSION     : 1.0.0
-- CREATED     : 2026-10-21
-- RUN ORDER   : Bước 2 — sau 02_tables_sales.sql
-- NOTE        : FK tham chiếu sang inventory.Machine đặt trong 03_foreign_keys.sql
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- 1. iot.Device  — Thiết bị ESP32 gắn trên máy bán hàng
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'iot.Device'))
BEGIN
    CREATE TABLE iot.Device (
        DeviceId        INT             NOT NULL IDENTITY(1,1),
        DeviceCode      NVARCHAR(30)    NOT NULL,       -- MAC address hoặc ID nội bộ
        MachineId       INT             NOT NULL,       -- FK → inventory.Machine (03_fk)
        DeviceType      NVARCHAR(30)    NOT NULL,       -- 'ESP32','Sensor','Display'…
        FirmwareVersion NVARCHAR(20)        NULL,
        LastHeartbeat   DATETIME2(0)        NULL,       -- lần ping cuối cùng
        Status          NVARCHAR(15)    NOT NULL CONSTRAINT DF_iot_Device_Status    DEFAULT (N'offline'),
                                                        -- 'online','offline','error'
        IsActive        BIT             NOT NULL CONSTRAINT DF_iot_Device_IsActive  DEFAULT (1),
        RegisteredAt    DATETIME2(0)    NOT NULL CONSTRAINT DF_iot_Device_Registered DEFAULT SYSUTCDATETIME(),
        UpdatedAt       DATETIME2(0)        NULL,

        CONSTRAINT PK_iot_Device            PRIMARY KEY (DeviceId),
        CONSTRAINT UQ_iot_Device_Code       UNIQUE (DeviceCode),
        CONSTRAINT CK_iot_Device_Status     CHECK (Status IN (N'online', N'offline', N'error'))
    );

    PRINT N'[02-iot] Bảng iot.Device đã được tạo.';
END
ELSE
    PRINT N'[02-iot] Bảng iot.Device đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 2. iot.SensorType  — Danh mục loại cảm biến
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'iot.SensorType'))
BEGIN
    CREATE TABLE iot.SensorType (
        SensorTypeId    INT             NOT NULL IDENTITY(1,1),
        TypeName        NVARCHAR(50)    NOT NULL,   -- 'TEMPERATURE','HUMIDITY','WEIGHT','DOOR'…
        Unit            NVARCHAR(20)        NULL,   -- '°C', '%RH', 'g'
        Description     NVARCHAR(200)       NULL,

        CONSTRAINT PK_iot_SensorType            PRIMARY KEY (SensorTypeId),
        CONSTRAINT UQ_iot_SensorType_Name       UNIQUE (TypeName)
    );

    PRINT N'[02-iot] Bảng iot.SensorType đã được tạo.';
END
ELSE
    PRINT N'[02-iot] Bảng iot.SensorType đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 3. iot.SensorReading  — Giá trị đọc từng cảm biến theo thời gian thực
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'iot.SensorReading'))
BEGIN
    CREATE TABLE iot.SensorReading (
        ReadingId       BIGINT          NOT NULL IDENTITY(1,1),
        DeviceId        INT             NOT NULL,
        SensorTypeId    INT             NOT NULL,
        Value           DECIMAL(10,3)   NOT NULL,
        RecordedAt      DATETIME2(3)    NOT NULL CONSTRAINT DF_iot_SensorReading_RecordedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_iot_SensorReading             PRIMARY KEY (ReadingId),
        CONSTRAINT FK_iot_SensorReading_Device      FOREIGN KEY (DeviceId)      REFERENCES iot.Device(DeviceId),
        CONSTRAINT FK_iot_SensorReading_SensorType  FOREIGN KEY (SensorTypeId)  REFERENCES iot.SensorType(SensorTypeId)
    );

    -- Index hỗ trợ truy vấn theo thiết bị + thời gian
    CREATE NONCLUSTERED INDEX IX_iot_SensorReading_Device_Time
        ON iot.SensorReading (DeviceId, RecordedAt DESC);

    PRINT N'[02-iot] Bảng iot.SensorReading đã được tạo.';
END
ELSE
    PRINT N'[02-iot] Bảng iot.SensorReading đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 4. iot.Telemetry  — Gói telemetry tổng hợp từ máy (gửi định kỳ)
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'iot.Telemetry'))
BEGIN
    CREATE TABLE iot.Telemetry (
        TelemetryId     BIGINT          NOT NULL IDENTITY(1,1),
        DeviceId        INT             NOT NULL,
        Payload         NVARCHAR(MAX)   NOT NULL,   -- JSON từ ESP32
        ReceivedAt      DATETIME2(3)    NOT NULL CONSTRAINT DF_iot_Telemetry_ReceivedAt DEFAULT SYSUTCDATETIME(),
        IsProcessed     BIT             NOT NULL CONSTRAINT DF_iot_Telemetry_IsProcessed DEFAULT (0),
        ProcessedAt     DATETIME2(0)        NULL,

        CONSTRAINT PK_iot_Telemetry             PRIMARY KEY (TelemetryId),
        CONSTRAINT FK_iot_Telemetry_Device      FOREIGN KEY (DeviceId) REFERENCES iot.Device(DeviceId)
    );

    PRINT N'[02-iot] Bảng iot.Telemetry đã được tạo.';
END
ELSE
    PRINT N'[02-iot] Bảng iot.Telemetry đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 5. iot.AlertRule  — Quy tắc sinh cảnh báo tự động
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'iot.AlertRule'))
BEGIN
    CREATE TABLE iot.AlertRule (
        AlertRuleId     INT             NOT NULL IDENTITY(1,1),
        RuleName        NVARCHAR(100)   NOT NULL,
        SensorTypeId    INT             NOT NULL,
        Operator        NVARCHAR(5)     NOT NULL,   -- '>', '<', '>=', '<=', '='
        Threshold       DECIMAL(10,3)   NOT NULL,
        Severity        NVARCHAR(10)    NOT NULL,   -- 'INFO','WARNING','CRITICAL'
        Message         NVARCHAR(300)       NULL,
        IsActive        BIT             NOT NULL CONSTRAINT DF_iot_AlertRule_IsActive DEFAULT (1),

        CONSTRAINT PK_iot_AlertRule             PRIMARY KEY (AlertRuleId),
        CONSTRAINT FK_iot_AlertRule_SensorType  FOREIGN KEY (SensorTypeId) REFERENCES iot.SensorType(SensorTypeId),
        CONSTRAINT CK_iot_AlertRule_Operator    CHECK (Operator IN (N'>', N'<', N'>=', N'<=', N'=')),
        CONSTRAINT CK_iot_AlertRule_Severity    CHECK (Severity IN (N'INFO', N'WARNING', N'CRITICAL'))
    );

    PRINT N'[02-iot] Bảng iot.AlertRule đã được tạo.';
END
ELSE
    PRINT N'[02-iot] Bảng iot.AlertRule đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- 6. iot.Alert  — Lịch sử cảnh báo được sinh ra
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'iot.Alert'))
BEGIN
    CREATE TABLE iot.Alert (
        AlertId         BIGINT          NOT NULL IDENTITY(1,1),
        DeviceId        INT             NOT NULL,
        AlertRuleId     INT                 NULL,
        SensorTypeId    INT                 NULL,
        SensorValue     DECIMAL(10,3)       NULL,
        Severity        NVARCHAR(10)    NOT NULL,
        Message         NVARCHAR(300)       NULL,
        IsResolved      BIT             NOT NULL CONSTRAINT DF_iot_Alert_IsResolved DEFAULT (0),
        ResolvedAt      DATETIME2(0)        NULL,
        ResolvedBy      INT                 NULL,   -- FK → auth.User (03_fk)
        CreatedAt       DATETIME2(3)    NOT NULL CONSTRAINT DF_iot_Alert_CreatedAt  DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_iot_Alert             PRIMARY KEY (AlertId),
        CONSTRAINT FK_iot_Alert_Device      FOREIGN KEY (DeviceId)      REFERENCES iot.Device(DeviceId),
        CONSTRAINT FK_iot_Alert_AlertRule   FOREIGN KEY (AlertRuleId)   REFERENCES iot.AlertRule(AlertRuleId),
        CONSTRAINT FK_iot_Alert_SensorType  FOREIGN KEY (SensorTypeId)  REFERENCES iot.SensorType(SensorTypeId),
        CONSTRAINT CK_iot_Alert_Severity    CHECK (Severity IN (N'INFO', N'WARNING', N'CRITICAL'))
    );

    PRINT N'[02-iot] Bảng iot.Alert đã được tạo.';
END
ELSE
    PRINT N'[02-iot] Bảng iot.Alert đã tồn tại — bỏ qua.';
GO

-- =============================================================================
-- XÁC NHẬN
-- =============================================================================

SELECT TABLE_SCHEMA AS [Schema], TABLE_NAME AS [Table]
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'iot'
ORDER BY TABLE_NAME;
GO

PRINT N'';
PRINT N'================================================================';
PRINT N'  TV4 (iot) hoàn tất. Tiếp theo: 02_tables_audit.sql           ';
PRINT N'================================================================';
GO
