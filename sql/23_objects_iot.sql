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


GO
-- ==========================================
-- 3. TRIGGER (Ghi vết khi trạng thái máy đổi)
-- ==========================================
CREATE OR ALTER TRIGGER iot.trg_Machines_StatusChange
    ON iot.Machines
    AFTER UPDATE
    AS BEGIN
           SET NOCOUNT ON;
           IF NOT UPDATE (Status)
               RETURN;
           INSERT INTO audit.ChangeLog (
               TableName,
               RecordId,
               Action,
               OldData,
               NewData,
               UserId,
               ChangedAt
           )
           SELECT N'iot.Machines',
                  CONVERT (NVARCHAR (50), i.MachineId),
                  N'UPDATE',
                  (SELECT d.MachineId,
                          d.Status
                   FOR    JSON PATH, WITHOUT_ARRAY_WRAPPER),
                  (SELECT i.MachineId,
                          i.Status
                   FOR    JSON PATH, WITHOUT_ARRAY_WRAPPER),
                  TRY_CONVERT (INT, SESSION_CONTEXT(N'UserId')),
                  SYSUTCDATETIME()
           FROM   inserted AS i
                  INNER JOIN
                  deleted AS d
                  ON d.MachineId = i.MachineId
           WHERE  ISNULL(i.Status, N'') <> ISNULL(d.Status, N'');
           INSERT INTO iot.Alert (
               MachineId,
               AlertType,
               Severity,
               Message,
               CreatedAt
           )
           SELECT i.MachineId,
                  CASE i.Status WHEN N'FAULT' THEN N'FAULT' ELSE N'OFFLINE' END,
                  N'CRITICAL',
                  CASE i.Status WHEN N'FAULT' THEN N'Máy chuyển sang trạng thái lỗi.' ELSE N'Máy chuyển sang trạng thái ngoại tuyến.' END,
                  SYSUTCDATETIME()
           FROM   inserted AS i
                  INNER JOIN
                  deleted AS d
                  ON d.MachineId = i.MachineId
           WHERE  ISNULL(i.Status, N'') <> ISNULL(d.Status, N'')
                  AND i.Status IN (N'FAULT', N'OFFLINE');
       END


GO
-- =============================================================================
-- 3. Function & Views bổ sung phục vụ App (Theo cảnh báo thiếu hụt)
-- =============================================================================
-- Hàm lấy telemetry gần nhất của máy
CREATE OR ALTER FUNCTION iot.fn_RecentTelemetry
(@MachineId INT, @TopN INT=10)
RETURNS TABLE 
AS
RETURN 
    (SELECT   TOP (@TopN) ReadingId,
                          MachineId,
                          RecordedAt,
                          Temperature,
                          Humidity,
                          DoorOpen
     FROM     iot.Telemetry
     WHERE    MachineId = @MachineId
     ORDER BY RecordedAt DESC)



GO
-- View theo dõi sức khỏe máy (Machine Health)
CREATE OR ALTER VIEW iot.vw_MachineHealth
AS
SELECT m.MachineId,
       m.Serial AS MachineCode,
       m.MachineName,
       m.Status,
       m.LastHeartbeat,
       ISNULL(t.Temperature, 0) AS CurrentTemp,
       ISNULL(t.Humidity, 0) AS CurrentHumidity,
       ISNULL(t.DoorOpen, 0) AS IsDoorOpen
FROM   iot.Machines AS m
       OUTER APPLY (SELECT   TOP 1 Temperature,
                                   Humidity,
                                   DoorOpen
                    FROM     iot.Telemetry
                    WHERE    MachineId = m.MachineId
                    ORDER BY RecordedAt DESC) AS t;


GO
-- View danh sách cảnh báo chưa xử lý (Open Alerts)
CREATE OR ALTER VIEW iot.vw_OpenAlerts
AS
SELECT AlertId,
       MachineId,
       AlertType,
       Severity,
       Message,
       CreatedAt
FROM   iot.Alert
WHERE  ResolvedAt IS NULL;


GO
PRINT N'[23-objects-iot] Đã bổ sung thành công các đối tượng vw_MachineHealth, vw_OpenAlerts, fn_RecentTelemetry.';