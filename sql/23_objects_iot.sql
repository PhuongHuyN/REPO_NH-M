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
-- Trả readings trong cửa sổ giờ mà API truyền vào. Operator chỉ được xem máy
-- đã gán trong auth.UserMachine; Admin/service role giữ phạm vi theo RBAC hiện có.
CREATE OR ALTER FUNCTION iot.fn_RecentTelemetry
(
  @MachineId INT,
  @Hours     INT
)
RETURNS TABLE
AS
RETURN
(
  SELECT t.MachineId,
         t.RecordedAt,
         t.Temperature,
         t.Humidity,
         t.DoorOpen
  FROM iot.Telemetry AS t
  WHERE t.MachineId = @MachineId
    AND @Hours > 0
    AND t.RecordedAt >= DATEADD(HOUR, -@Hours, SYSUTCDATETIME())
    AND
    (
      IS_MEMBER(N'r_operator') <> 1
      OR EXISTS
      (
        SELECT 1
        FROM auth.UserMachine AS um
        WHERE um.UserId = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserId'))
          AND um.MachineId = @MachineId
      )
    )
);
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
                    ORDER BY RecordedAt DESC, ReadingId DESC) AS t;
GO

-- Hợp đồng dùng bởi API /api/iot/machines, SSE và /api/kiosk/menu.
-- Giữ alias khớp fakeDb để UI không cần chuyển đổi cấu trúc bản ghi.
CREATE OR ALTER VIEW iot.vw_MachineHealth
AS
SELECT m.MachineId,
       m.Serial,
       m.MachineName,
       m.Status,
       m.FirmwareVersion,
       m.LocationId,
       l.LocationName,
       l.LocationType,
       l.District,
       m.LastHeartbeat,
       CASE WHEN m.LastHeartbeat IS NULL THEN NULL
            ELSE DATEDIFF(SECOND, m.LastHeartbeat, SYSUTCDATETIME()) END AS SecondsSinceHeartbeat,
       t.Temperature AS LastTemp,
       t.Humidity AS LastHumidity,
       t.DoorOpen,
       t.RecordedAt AS LastReadingAt,
       COALESCE(th.MinTemp, CONVERT(DECIMAL(5,2), 2.00)) AS MinTemp,
       COALESCE(th.MaxTemp, CONVERT(DECIMAL(5,2), 8.00)) AS MaxTemp,
       COALESCE(th.DoorOpenMaxMinutes, 2) AS DoorOpenMaxMinutes,
       COALESCE(th.ConsecutiveBreaches, 3) AS ConsecutiveBreaches,
       COALESCE(th.DegradedMessage, N'Nhiệt độ tủ lạnh vượt ngưỡng an toàn, vui lòng kiểm tra.') AS DegradedMessage,
       alerts.OpenAlerts,
       CONVERT(BIT, CASE WHEN m.Status = N'ACTIVE' THEN 1 ELSE 0 END) AS IsServing
FROM iot.Machines AS m
LEFT JOIN iot.Locations AS l ON l.LocationId = m.LocationId
LEFT JOIN iot.MachineThresholds AS th ON th.MachineId = m.MachineId
OUTER APPLY
(
  SELECT TOP (1) tel.Temperature, tel.Humidity, tel.DoorOpen, tel.RecordedAt
  FROM iot.Telemetry AS tel
  WHERE tel.MachineId = m.MachineId
  ORDER BY tel.RecordedAt DESC, tel.ReadingId DESC
) AS t
OUTER APPLY
(
  SELECT COUNT(*) AS OpenAlerts
  FROM iot.Alerts AS a
  WHERE a.MachineId = m.MachineId AND a.ResolvedAt IS NULL
) AS alerts;
GO

-- Cảnh báo chưa giải quyết kèm thông tin máy/địa điểm/người nhận như fakeDb.
-- Join Machines chủ đích để filter RLS máy áp dụng cho Operator.
CREATE OR ALTER VIEW iot.vw_OpenAlerts
AS
SELECT a.AlertId,
       a.MachineId,
       a.AlertType,
       a.Severity,
       a.Message,
       a.RefKey,
       a.CreatedAt,
       a.AckBy,
       a.AckAt,
       a.ResolvedAt,
       m.Serial,
       m.MachineName,
       l.LocationName,
       u.FullName AS AckByName,
       DATEDIFF(MINUTE, a.CreatedAt, SYSUTCDATETIME()) AS AgeMinutes
FROM iot.Alerts AS a
INNER JOIN iot.Machines AS m ON m.MachineId = a.MachineId
LEFT JOIN iot.Locations AS l ON l.LocationId = m.LocationId
LEFT JOIN auth.[User] AS u ON u.UserId = a.AckBy
WHERE a.ResolvedAt IS NULL;
GO

PRINT N'[23-iot] Đã tạo fn_RecentTelemetry, vw_MachineHealth và vw_OpenAlerts.';
GO
