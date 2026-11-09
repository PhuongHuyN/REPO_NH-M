USE FreshVendDB;


GO
-- ==========================================
-- 1. FUNCTIONS (Hàm module IoT)
-- ==========================================
-- Kiểm tra nhiệt độ có nằm trong ngưỡng an toàn của máy hay không
CREATE OR ALTER FUNCTION iot.fn_IsTempInRange
(@MachineId INT, @Temp DECIMAL (5, 2))
RETURNS BIT
AS
BEGIN
  DECLARE @r AS BIT;
  SELECT @r = CASE WHEN @Temp BETWEEN MinTemp AND MaxTemp THEN 1 ELSE 0 END
  FROM   iot.MachineThresholds
  WHERE  MachineId = @MachineId;
  -- Máy chưa có ngưỡng riêng thì dùng mặc định 2–8°C
  RETURN ISNULL(@r, CASE WHEN @Temp BETWEEN 2.00 AND 8.00 THEN 1 ELSE 0 END);
END


GO
-- ==========================================
-- 2. VIEWS (Giao diện hiển thị module IoT)
-- ==========================================
-- View tổng hợp trạng thái máy và thông số telemetry mới nhất
CREATE OR ALTER VIEW iot.v_MachineStatus
AS
SELECT m.MachineId,
       m.Serial,
       m.MachineName,
       m.Status AS MachineStatus,
       l.LocationName,
       l.District,
       t.Temperature,
       t.Humidity,
       t.DoorOpen,
       t.RecordedAt AS LastTelemetryAt,
       iot.fn_IsTempInRange(m.MachineId, t.Temperature) AS IsTempNormal
FROM   iot.Machines AS m
       LEFT OUTER JOIN
       iot.Locations AS l
       ON m.LocationId = l.LocationId
       OUTER APPLY (SELECT   TOP 1 Temperature,
                                   Humidity,
                                   DoorOpen,
                                   RecordedAt
                    FROM     iot.Telemetry
                    WHERE    MachineId = m.MachineId
                    ORDER BY RecordedAt DESC) AS t;