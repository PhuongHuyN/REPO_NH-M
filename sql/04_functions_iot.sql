USE FreshVendDB;
GO

-- =============================================================================
-- Function: iot.fn_RecentTelemetry — Lấy dữ liệu telemetry gần nhất của máy trong N giờ
-- =============================================================================
CREATE OR ALTER FUNCTION iot.fn_RecentTelemetry
(
    @MachineId INT,
    @Hours INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        ReadingId,
        MachineId,
        RecordedAt,
        Temperature,
        Humidity,
        DoorOpen
    FROM iot.Telemetry
    WHERE MachineId = @MachineId
      AND RecordedAt >= DATEADD(HOUR, -@Hours, SYSDATETIME())
);
GO

PRINT N'[04-iot] Tạo Function iot.fn_RecentTelemetry thành công.';
GO