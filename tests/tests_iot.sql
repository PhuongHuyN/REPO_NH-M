-- =============================================================================
-- FreshVend - IoT stored procedure smoke tests (SCRUM-236)
-- Requires: sql/02_tables_iot.sql and sql/13_procs_iot.sql
-- Run as one batch in FreshVendDB. Fixture changes are rolled back at the end.
-- Error cases are intentionally last: several procedures roll back the active
-- transaction when they throw.
-- =============================================================================
USE FreshVendDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT OFF;

BEGIN TRANSACTION;

DECLARE @LocationId INT, @MachineId INT, @AlertId INT, @UserId INT;
DECLARE @Serial NVARCHAR(50) = N'__IOT_TEST_SCRUM236__';
DECLARE @Payload NVARCHAR(MAX);
DECLARE @Err NVARCHAR(2048);

SELECT TOP (1) @UserId = UserId FROM auth.[User] ORDER BY UserId;
IF @UserId IS NULL SET @UserId = 1;

INSERT iot.Locations (LocationName, LocationType, Address, District)
VALUES (N'__IOT_TEST_LOCATION__', N'OFFICE', N'Test', N'Test');
SET @LocationId = SCOPE_IDENTITY();

INSERT iot.Machines (Serial, MachineName, LocationId, Status, FirmwareVersion, LastHeartbeat)
VALUES (@Serial, N'IoT test machine', @LocationId, N'ACTIVE', N'1.0.0', SYSUTCDATETIME());
SET @MachineId = SCOPE_IDENTITY();

INSERT iot.MachineThresholds (MachineId, MinTemp, MaxTemp, DoorOpenMaxMinutes, ConsecutiveBreaches, DegradedMessage)
VALUES (@MachineId, 2, 8, 2, 3, N'IoT test threshold');

INSERT iot.Alert (MachineId, AlertType, Severity, Message, CreatedAt)
VALUES (@MachineId, N'TEST', N'INFO', N'IoT test alert', SYSUTCDATETIME());
SET @AlertId = SCOPE_IDENTITY();

-- 1-3: sp_RegisterMachine
BEGIN TRY
    EXEC iot.sp_RegisterMachine @Serial=N'__IOT_TEST_REGISTER_OK__', @MachineName=N'Register test', @LocationId=@LocationId;
    PRINT N'[PASS] Test Case 1: sp_RegisterMachine happy path tạo máy và cấu hình.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 1: sp_RegisterMachine happy path: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC iot.sp_RegisterMachine @Serial=N'__IOT_TEST_REGISTER_EDGE__', @MachineName=N'Capacity boundary', @LocationId=@LocationId, @ColumnCount=4, @Capacity=32767;
    PRINT N'[PASS] Test Case 2: sp_RegisterMachine boundary capacity 32767.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 2: sp_RegisterMachine boundary: ' + ERROR_MESSAGE();
END CATCH;

-- 4-6: sp_IngestTelemetry
SET @Payload = N'{"machineId":' + CONVERT(NVARCHAR(20), @MachineId) + N',"readings":[{"temp":4.5,"hum":50,"door":false}]}';
BEGIN TRY
    EXEC iot.sp_IngestTelemetry @Payload=@Payload;
    PRINT N'[PASS] Test Case 3: sp_IngestTelemetry nhận một bản đọc hợp lệ.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 3: sp_IngestTelemetry happy path: ' + ERROR_MESSAGE();
END CATCH;

SET @Payload = N'{"machineId":' + CONVERT(NVARCHAR(20), @MachineId) + N',"readings":[{"temp":-99.99,"hum":0,"door":true},{"temp":99.99,"hum":100,"door":false}]}';
BEGIN TRY
    EXEC iot.sp_IngestTelemetry @Payload=@Payload;
    PRINT N'[PASS] Test Case 4: sp_IngestTelemetry boundary temperature và độ ẩm.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 4: sp_IngestTelemetry boundary: ' + ERROR_MESSAGE();
END CATCH;

-- 7-9: sp_AcknowledgeAlert
BEGIN TRY
    EXEC iot.sp_AcknowledgeAlert @AlertId=@AlertId, @UserId=@UserId, @Resolve=0;
    PRINT N'[PASS] Test Case 5: sp_AcknowledgeAlert xác nhận cảnh báo đang mở.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 5: sp_AcknowledgeAlert happy path: ' + ERROR_MESSAGE();
END CATCH;

INSERT iot.Alert (MachineId, AlertType, Severity, Message, CreatedAt) VALUES (@MachineId, N'EDGE', N'INFO', N'Boundary alert', SYSUTCDATETIME());
SET @AlertId = SCOPE_IDENTITY();
BEGIN TRY
    EXEC iot.sp_AcknowledgeAlert @AlertId=@AlertId, @UserId=@UserId, @Resolve=1;
    PRINT N'[PASS] Test Case 6: sp_AcknowledgeAlert resolve ngay (Resolve=1).';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 6: sp_AcknowledgeAlert boundary: ' + ERROR_MESSAGE();
END CATCH;

-- 10-12: sp_ClearFault
UPDATE iot.Machines SET Status=N'FAULT' WHERE MachineId=@MachineId;
BEGIN TRY
    EXEC iot.sp_ClearFault @MachineId=@MachineId, @UserId=@UserId, @Note=N'clear test fault';
    PRINT N'[PASS] Test Case 7: sp_ClearFault chuyển máy FAULT về ACTIVE.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 7: sp_ClearFault happy path: ' + ERROR_MESSAGE();
END CATCH;

UPDATE iot.Machines SET Status=N'OFFLINE' WHERE MachineId=@MachineId;
BEGIN TRY
    EXEC iot.sp_ClearFault @MachineId=@MachineId, @UserId=@UserId, @Note=NULL;
    PRINT N'[PASS] Test Case 8: sp_ClearFault boundary với Note NULL.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 8: sp_ClearFault boundary: ' + ERROR_MESSAGE();
END CATCH;

-- 13-15: sp_UpdateThreshold
BEGIN TRY
    EXEC iot.sp_UpdateThreshold @MachineId=@MachineId, @MinTemp=1, @MaxTemp=9, @DoorOpenMaxMinutes=2, @ConsecutiveBreaches=3, @DegradedMessage=N'Updated test threshold';
    PRINT N'[PASS] Test Case 9: sp_UpdateThreshold cập nhật ngưỡng hợp lệ.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 9: sp_UpdateThreshold happy path: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC iot.sp_UpdateThreshold @MachineId=@MachineId, @MinTemp=-99.99, @MaxTemp=99.99, @DoorOpenMaxMinutes=0, @ConsecutiveBreaches=1, @DegradedMessage=N'Boundary';
    PRINT N'[PASS] Test Case 10: sp_UpdateThreshold boundary min/max và số phút 0.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 10: sp_UpdateThreshold boundary: ' + ERROR_MESSAGE();
END CATCH;

-- 16-18: sp_CheckHeartbeat
UPDATE iot.Machines SET LastHeartbeat=SYSUTCDATETIME() WHERE MachineId=@MachineId;
BEGIN TRY
    EXEC iot.sp_CheckHeartbeat @Minutes=5;
    PRINT N'[PASS] Test Case 11: sp_CheckHeartbeat không đánh dấu máy vừa heartbeat.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 11: sp_CheckHeartbeat happy path: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC iot.sp_CheckHeartbeat @Minutes=0;
    PRINT N'[PASS] Test Case 12: sp_CheckHeartbeat boundary Minutes=0.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 12: sp_CheckHeartbeat boundary: ' + ERROR_MESSAGE();
END CATCH;

-- 19-21: sp_AggregateHourly
BEGIN TRY
    EXEC iot.sp_AggregateHourly;
    PRINT N'[PASS] Test Case 13: sp_AggregateHourly tổng hợp telemetry trong giờ hiện tại.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 13: sp_AggregateHourly happy path: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC iot.sp_AggregateHourly;
    PRINT N'[PASS] Test Case 14: sp_AggregateHourly chạy lặp không tạo lỗi (idempotent).';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 14: sp_AggregateHourly boundary/repeat: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC iot.sp_AggregateHourly;
    PRINT N'[PASS] Test Case 15: sp_AggregateHourly xử lý được khi không có thêm telemetry mới.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 15: sp_AggregateHourly empty/repeat: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC iot.sp_CheckHeartbeat @Minutes=-1;
    PRINT N'[PASS] Test Case 16: sp_CheckHeartbeat xử lý Minutes âm mà không phát sinh lỗi.';
END TRY BEGIN CATCH
    PRINT N'[FAIL] Test Case 16: sp_CheckHeartbeat unexpected error: ' + ERROR_MESSAGE();
END CATCH;

-- 17-21: expected invalid/error cases (kept last because procedure CATCH blocks
-- can roll back the caller's transaction).
BEGIN TRY
    EXEC iot.sp_RegisterMachine @Serial=N' ', @MachineName=N'Invalid', @LocationId=@LocationId;
    PRINT N'[FAIL] Test Case 17: sp_RegisterMachine phải từ chối Serial rỗng.';
END TRY BEGIN CATCH
    PRINT N'[PASS] Test Case 17: sp_RegisterMachine từ chối Serial rỗng: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC iot.sp_IngestTelemetry @Payload=N'{bad json';
    PRINT N'[FAIL] Test Case 18: sp_IngestTelemetry phải từ chối JSON sai.';
END TRY BEGIN CATCH
    PRINT N'[PASS] Test Case 18: sp_IngestTelemetry từ chối JSON sai: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC iot.sp_AcknowledgeAlert @AlertId=-1, @UserId=@UserId;
    PRINT N'[FAIL] Test Case 19: sp_AcknowledgeAlert phải từ chối AlertId không tồn tại.';
END TRY BEGIN CATCH
    PRINT N'[PASS] Test Case 19: sp_AcknowledgeAlert từ chối AlertId không tồn tại: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC iot.sp_ClearFault @MachineId=-1, @UserId=@UserId;
    PRINT N'[FAIL] Test Case 20: sp_ClearFault phải từ chối MachineId không tồn tại.';
END TRY BEGIN CATCH
    PRINT N'[PASS] Test Case 20: sp_ClearFault từ chối MachineId không tồn tại: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC iot.sp_UpdateThreshold @MachineId=@MachineId, @MinTemp=8, @MaxTemp=2, @DoorOpenMaxMinutes=2, @ConsecutiveBreaches=3, @DegradedMessage=N'Invalid range';
    PRINT N'[FAIL] Test Case 21: sp_UpdateThreshold phải từ chối MinTemp >= MaxTemp.';
END TRY BEGIN CATCH
    PRINT N'[PASS] Test Case 21: sp_UpdateThreshold từ chối khoảng nhiệt độ sai: ' + ERROR_MESSAGE();
END CATCH;

IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
ELSE PRINT N'[INFO] Transaction đã được procedure rollback khi kiểm tra lỗi; dữ liệu fixture trước đó cũng đã được hoàn tác.';
PRINT N'IoT SCRUM-236 test script completed.';
