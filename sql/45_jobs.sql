-- =============================================================================
-- FILE         : 45_jobs.sql
-- PROJECT      : FreshVend
-- DESCRIPTION  : Lịch chạy SQL Agent Jobs; SQL Express sử dụng cơ chế fallback ứng dụng.
-- RUN ORDER    : Chạy sau khi các stored procedure liên quan đã được tạo.
-- =============================================================================
DECLARE @EngineEdition AS INT = CONVERT (INT, SERVERPROPERTY(N'EngineEdition'));

IF @EngineEdition = 4
    BEGIN
        PRINT N'[45-jobs] SQL Server Express không hỗ trợ SQL Server Agent. Vui lòng bật JOBS_FALLBACK=true trong file cấu hình ứng dụng/host scheduler.';
        RETURN;
    END

DECLARE @Today AS INT = CONVERT (INT, CONVERT (CHAR (8), GETDATE(), 112));

DECLARE @Jobs TABLE (
    JobName           SYSNAME        NOT NULL PRIMARY KEY,
    ScheduleName      SYSNAME        NOT NULL,
    JobDescription    NVARCHAR (512) NOT NULL,
    StepName          SYSNAME        NOT NULL,
    StepCommand       NVARCHAR (MAX) NOT NULL,
    FrequencyType     INT            NOT NULL,
    FrequencyInterval INT            NOT NULL,
    SubdayType        INT            NOT NULL,
    SubdayInterval    INT            NOT NULL,
    RecurrenceFactor  INT            NOT NULL);

INSERT  INTO @Jobs (
    JobName,
    ScheduleName,
    JobDescription,
    StepName,
    StepCommand,
    FrequencyType,
    FrequencyInterval,
    SubdayType,
    SubdayInterval,
    RecurrenceFactor
)
VALUES             (N'FV_Minute', N'FV_Minute_Schedule', N'Chạy kiểm tra heartbeat và hủy đơn hàng quá hạn mỗi phút.', N'Chạy các tác vụ theo phút', N'EXEC iot.sp_CheckHeartbeat @Minutes = 5; EXEC sales.sp_ExpirePendingOrders;', 4, 1, 4, 1, 1),
                   (N'FV_Hourly', N'FV_Hourly_Schedule', N'Tổng hợp telemetry hàng giờ, xóa hàng tồn kho hết hạn và làm mới báo cáo.', N'Chạy các tác vụ theo giờ', N'EXEC iot.sp_AggregateHourly; EXEC inventory.sp_RemoveExpired; EXEC report.sp_RefreshDailySummary;', 4, 1, 8, 1, 1),
                   (N'FV_Monthly', N'FV_Monthly_Schedule', N'Bảo trì các partition telemetry hàng tháng.', N'Bảo trì partition telemetry', N'EXEC iot.sp_MaintainPartitions;', 16, 1, 1, 0, 1);

DECLARE @JobName AS SYSNAME, @ScheduleName AS SYSNAME, @JobDescription AS NVARCHAR (512), @StepName AS SYSNAME, @StepCommand AS NVARCHAR (MAX), @FrequencyType AS INT, @FrequencyInterval AS INT, @SubdayType AS INT, @SubdayInterval AS INT, @RecurrenceFactor AS INT, @JobId AS UNIQUEIDENTIFIER, @StepId AS INT, @ScheduleId AS INT;

DECLARE JobCursor CURSOR LOCAL FAST_FORWARD
    FOR SELECT   JobName,
                 ScheduleName,
                 JobDescription,
                 StepName,
                 StepCommand,
                 FrequencyType,
                 FrequencyInterval,
                 SubdayType,
                 SubdayInterval,
                 RecurrenceFactor
        FROM     @Jobs
        ORDER BY JobName;

BEGIN TRY
    OPEN JobCursor;
    FETCH NEXT FROM JobCursor INTO @JobName, @ScheduleName, @JobDescription, @StepName, @StepCommand, @FrequencyType, @FrequencyInterval, @SubdayType, @SubdayInterval, @RecurrenceFactor;
    WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @JobId = NULL;
            SELECT @JobId = job_id
            FROM   msdb.dbo.sysjobs
            WHERE  name = @JobName;
            IF @JobId IS NULL
                BEGIN
                    EXECUTE msdb.dbo.sp_add_job @job_name = @JobName, @enabled = 1, @description = @JobDescription, @start_step_id = 1, @job_id = @JobId OUTPUT;
                END
            ELSE
                BEGIN
                    -- Job đã tồn tại: giữ nguyên ID, bật enable và đồng bộ mô tả.
                    EXECUTE msdb.dbo.sp_update_job @job_id = @JobId, @enabled = 1, @description = @JobDescription;
                END
            SET @StepId = NULL;
            SELECT @StepId = step_id
            FROM   msdb.dbo.sysjobsteps
            WHERE  job_id = @JobId
                   AND step_name = @StepName;
            IF @StepId IS NULL
                BEGIN
                    -- Đã sửa lỗi: Bỏ từ khóa OUTPUT ở tham số @step_id
                    EXECUTE msdb.dbo.sp_add_jobstep @job_id = @JobId, @step_name = @StepName, @subsystem = N'TSQL', @database_name = N'FreshVendDB', @command = @StepCommand, @on_success_action = 1, @on_fail_action = 2, @retry_attempts = 3, @retry_interval = 1;
                END
            ELSE
                BEGIN
                    EXECUTE msdb.dbo.sp_update_jobstep @job_id = @JobId, @step_id = @StepId, @subsystem = N'TSQL', @database_name = N'FreshVendDB', @command = @StepCommand, @on_success_action = 1, @on_fail_action = 2, @retry_attempts = 3, @retry_interval = 1;
                END
            SET @ScheduleId = NULL;
            SELECT @ScheduleId = schedule_id
            FROM   msdb.dbo.sysschedules
            WHERE  name = @ScheduleName;
            IF @ScheduleId IS NULL
                BEGIN
                    EXECUTE msdb.dbo.sp_add_schedule @schedule_name = @ScheduleName, @enabled = 1, @freq_type = @FrequencyType, @freq_interval = @FrequencyInterval, @freq_subday_type = @SubdayType, @freq_subday_interval = @SubdayInterval, @freq_relative_interval = 0, @freq_recurrence_factor = @RecurrenceFactor, @active_start_date = @Today, @active_start_time = 0, @active_end_date = 99991231, @schedule_id = @ScheduleId OUTPUT;
                END
            ELSE
                BEGIN
                    EXECUTE msdb.dbo.sp_update_schedule @schedule_id = @ScheduleId, @enabled = 1, @freq_type = @FrequencyType, @freq_interval = @FrequencyInterval, @freq_subday_type = @SubdayType, @freq_subday_interval = @SubdayInterval, @freq_relative_interval = 0, @freq_recurrence_factor = @RecurrenceFactor, @active_start_date = @Today, @active_start_time = 0, @active_end_date = 99991231;
                END
            IF NOT EXISTS (SELECT 1
                           FROM   msdb.dbo.sysjobschedules
                           WHERE  job_id = @JobId
                                  AND schedule_id = @ScheduleId)
                EXECUTE msdb.dbo.sp_attach_schedule @job_id = @JobId, @schedule_id = @ScheduleId;
            IF NOT EXISTS (SELECT 1
                           FROM   msdb.dbo.sysjobservers
                           WHERE  job_id = @JobId)
                EXECUTE msdb.dbo.sp_add_jobserver @job_id = @JobId, @server_name = N'(LOCAL)';
            PRINT N'[45-jobs] Đã cấu hình thành công job: ' + @JobName + N'.';
            FETCH NEXT FROM JobCursor INTO @JobName, @ScheduleName, @JobDescription, @StepName, @StepCommand, @FrequencyType, @FrequencyInterval, @SubdayType, @SubdayInterval, @RecurrenceFactor;
        END
    CLOSE JobCursor;
    DEALLOCATE JobCursor;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'JobCursor') >= 0
        CLOSE JobCursor;
    IF CURSOR_STATUS('local', 'JobCursor') > -3
        DEALLOCATE JobCursor;
    THROW;
END CATCH

PRINT N'[45-jobs] Đã cấu hình thành công tất cả 3 SQL Agent jobs.';