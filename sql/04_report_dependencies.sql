-- TV5 additive contracts for the existing TV1-TV4 schema. SQL Server 2022.
-- Existing singular table names belong to other modules and are preserved.
USE FreshVendDB;
GO
IF OBJECT_ID(N'inventory.Locations', N'U') IS NULL
CREATE TABLE inventory.Locations (
    LocationId INT IDENTITY PRIMARY KEY,
    LocationCode NVARCHAR(30) NOT NULL UNIQUE,
    LocationName NVARCHAR(150) NOT NULL
);
GO
IF COL_LENGTH(N'inventory.Machine', N'LocationId') IS NULL
    ALTER TABLE inventory.Machine ADD LocationId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Machine_Locations')
    ALTER TABLE inventory.Machine ADD CONSTRAINT FK_Machine_Locations
        FOREIGN KEY (LocationId) REFERENCES inventory.Locations(LocationId);
GO
IF OBJECT_ID(N'sales.DispenseAttempts', N'U') IS NULL
CREATE TABLE sales.DispenseAttempts (
    AttemptId BIGINT IDENTITY PRIMARY KEY,
    OrderItemId BIGINT NOT NULL REFERENCES sales.OrderItem(OrderItemId),
    AttemptNo INT NOT NULL CHECK (AttemptNo > 0),
    Result NVARCHAR(10) NOT NULL CHECK (Result IN (N'SUCCESS', N'JAM')),
    AttemptedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_DispenseAttempts_OrderItemId_AttemptNo UNIQUE (OrderItemId, AttemptNo)
);
GO
-- Parse once at ingestion; report scans use typed, persisted columns.
IF COL_LENGTH(N'iot.Telemetry',N'Temperature') IS NULL
ALTER TABLE iot.Telemetry ADD Temperature AS
 TRY_CONVERT(DECIMAL(8,3),JSON_VALUE(CASE WHEN ISJSON(Payload)=1 THEN Payload ELSE N'{}' END,'$.t')) PERSISTED;
GO
IF COL_LENGTH(N'iot.Telemetry',N'DurationSeconds') IS NULL
ALTER TABLE iot.Telemetry ADD DurationSeconds AS
 TRY_CONVERT(INT,JSON_VALUE(CASE WHEN ISJSON(Payload)=1 THEN Payload ELSE N'{}' END,'$.durationSeconds')) PERSISTED;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'sales.Order') AND name=N'IX_Order_CreatedAt')
CREATE INDEX IX_Order_CreatedAt ON sales.[Order](CreatedAt,MachineId) INCLUDE(Status,TotalAmount);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'sales.OrderItem') AND name=N'IX_OrderItem_OrderId')
CREATE INDEX IX_OrderItem_OrderId ON sales.OrderItem(OrderId) INCLUDE(ProductId,Quantity,UnitPrice,SlotId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'sales.Payment') AND name=N'IX_Payment_OrderId_PaymentId')
CREATE INDEX IX_Payment_OrderId_PaymentId ON sales.Payment(OrderId,PaymentId DESC) INCLUDE(PaymentMethod,Amount,Status);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'iot.Telemetry') AND name=N'IX_Telemetry_ReceivedAt')
CREATE INDEX IX_Telemetry_ReceivedAt ON iot.Telemetry(ReceivedAt) INCLUDE(DeviceId,Temperature,DurationSeconds);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'iot.Telemetry') AND name=N'IX_Telemetry_DeviceId_ReceivedAt')
CREATE INDEX IX_Telemetry_DeviceId_ReceivedAt ON iot.Telemetry(DeviceId,ReceivedAt) INCLUDE(Temperature,DurationSeconds);
-- Upgrade the index created by an earlier revision, without rebuilding on every run.
IF NOT EXISTS(SELECT 1 FROM sys.indexes i JOIN sys.index_columns c ON c.object_id=i.object_id AND c.index_id=i.index_id
 WHERE i.object_id=OBJECT_ID(N'iot.Telemetry') AND i.name=N'IX_Telemetry_DeviceId_ReceivedAt'
 AND COL_NAME(c.object_id,c.column_id)=N'Temperature')
BEGIN
 DROP INDEX IF EXISTS IX_Telemetry_DeviceId_ReceivedAt ON iot.Telemetry;
 CREATE INDEX IX_Telemetry_DeviceId_ReceivedAt ON iot.Telemetry(DeviceId,ReceivedAt) INCLUDE(Temperature,DurationSeconds);
END;
GO
-- A packet explicitly reports seconds represented by its temperature reading.
-- Missing/invalid duration is unknown coverage, never assumed to be a full hour.
-- Durations must not overlap within a device; producer contract: <=300 seconds.
CREATE OR ALTER VIEW iot.vw_TelemetryHourlySource
AS
SELECT d.MachineId,
       DATEADD(HOUR,DATEDIFF(HOUR,CONVERT(DATETIME2,'20000101'),t.ReceivedAt),CONVERT(DATETIME2,'20000101')) AS HourStart,
       SUM(CONVERT(BIGINT,t.DurationSeconds)) AS MonitoredSeconds,
       SUM(CONVERT(BIGINT,CASE WHEN t.Temperature BETWEEN 2 AND 8 THEN t.DurationSeconds ELSE 0 END)) AS InRangeSeconds,
       MIN(t.Temperature) AS MinTemp, MAX(t.Temperature) AS MaxTemp,
       SUM(CONVERT(DECIMAL(20,4),t.Temperature)*t.DurationSeconds) AS TemperatureSeconds
FROM iot.Telemetry t
JOIN iot.Device d ON d.DeviceId=t.DeviceId
WHERE t.Temperature IS NOT NULL AND t.DurationSeconds BETWEEN 1 AND 300
GROUP BY d.MachineId,
       DATEADD(HOUR,DATEDIFF(HOUR,CONVERT(DATETIME2,'20000101'),t.ReceivedAt),CONVERT(DATETIME2,'20000101'));
GO
-- Materialized hourly contract: refresh after ingestion, not every dashboard read.
IF OBJECT_ID(N'iot.TelemetryHourly',N'V') IS NOT NULL
    DROP VIEW IF EXISTS iot.TelemetryHourly;
GO
IF OBJECT_ID(N'iot.TelemetryHourly',N'U') IS NULL
CREATE TABLE iot.TelemetryHourly (
 MachineId INT NOT NULL REFERENCES inventory.Machine(MachineId),
 HourStart DATETIME2(0) NOT NULL,
 MonitoredSeconds BIGINT NOT NULL CHECK(MonitoredSeconds>0),
 InRangeSeconds BIGINT NOT NULL,
 MinTemp DECIMAL(8,3) NOT NULL,MaxTemp DECIMAL(8,3) NOT NULL,
 TemperatureSeconds DECIMAL(38,4) NOT NULL,
 CONSTRAINT PK_TelemetryHourly PRIMARY KEY(MachineId,HourStart),
 CONSTRAINT CK_TelemetryHourly_InRange CHECK(InRangeSeconds BETWEEN 0 AND MonitoredSeconds)
);
GO
