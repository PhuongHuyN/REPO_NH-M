USE FreshVendDB;
GO

-- =============================================================================
-- 1. iot.vw_MachineHealth — Trạng thái hoạt động thời gian thực của máy
-- =============================================================================
CREATE OR ALTER VIEW iot.vw_MachineHealth AS
SELECT 
    m.MachineId,
    m.Serial,
    m.MachineName,
    m.Status,
    m.FirmwareVersion,
    l.LocationId,
    l.LocationName,
    l.LocationType,
    l.District,
    m.LastHeartbeat,
    DATEDIFF(SECOND, m.LastHeartbeat, SYSDATETIME()) AS SecondsSinceHeartbeat,
    latest.Temperature AS LastTemp,
    latest.Humidity AS LastHumidity,
    latest.DoorOpen,
    latest.RecordedAt AS LastReadingAt,
    ISNULL(t.MinTemp, 2.00) AS MinTemp,
    ISNULL(t.MaxTemp, 8.00) AS MaxTemp,
    ISNULL(t.DoorOpenMaxMinutes, 2) AS DoorOpenMaxMinutes,
    ISNULL(t.ConsecutiveBreaches, 3) AS ConsecutiveBreaches,
    t.DegradedMessage,
    (SELECT COUNT(*) FROM iot.Alerts a WHERE a.MachineId = m.MachineId AND a.ResolvedAt IS NULL) AS OpenAlerts,
    CASE WHEN m.Status = 'ACTIVE' THEN 1 ELSE 0 END AS IsServing
FROM iot.Machines m
LEFT JOIN iot.Locations l ON m.LocationId = l.LocationId
LEFT JOIN iot.MachineThresholds t ON m.MachineId = t.MachineId
OUTER APPLY (
    SELECT TOP 1 Temperature, Humidity, DoorOpen, RecordedAt
    FROM iot.Telemetry telemetry
    WHERE telemetry.MachineId = m.MachineId
    ORDER BY RecordedAt DESC
) latest;
GO

PRINT N'[05-iot] Tạo View iot.vw_MachineHealth thành công.';
GO

-- =============================================================================
-- 2. iot.vw_OpenAlerts — Danh sách các cảnh báo chưa được giải quyết
-- =============================================================================
CREATE OR ALTER VIEW iot.vw_OpenAlerts AS
SELECT 
    a.AlertId,
    a.MachineId,
    m.Serial,
    m.MachineName,
    l.LocationName,
    a.AlertType,
    a.Severity,
    a.Message,
    a.RefKey,
    a.CreatedAt,
    DATEDIFF(MINUTE, a.CreatedAt, SYSDATETIME()) AS AgeMinutes,
    a.AckBy,
    a.AckAt
FROM iot.Alerts a
JOIN iot.Machines m ON a.MachineId = m.MachineId
LEFT JOIN iot.Locations l ON m.LocationId = l.LocationId
WHERE a.ResolvedAt IS NULL;
GO

PRINT N'[05-iot] Tạo View iot.vw_OpenAlerts thành công.';
GO