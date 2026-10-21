-- =============================================================================
-- FILE        : 02_tables_report.sql
-- PROJECT     : FreshVend — Hệ thống máy bán trái cây tự động
-- DESCRIPTION : Tạo các bảng thuộc schema [report]
--               1. report.DailySalesSummary  — Tổng hợp doanh thu theo ngày/máy/sản phẩm
--               2. report.ExportLogs         — Nhật ký xuất báo cáo
--               3. report.TestResults        — Lưu kết quả chạy test case
-- VERSION     : 1.0.0
-- CREATED     : 2026-10-21
-- RUN ORDER   : Bước 2 — sau tất cả 02_tables_*.sql khác
--               (cần auth.User, inventory.Machine, inventory.Product tồn tại trước)
-- NOTE        : FK liên schema sang auth.User và inventory.*
--               đã được gom vào 03_foreign_keys.sql.
--               Chạy 03_foreign_keys.sql ngay sau script này.
-- =============================================================================

USE FreshVendDB;
GO

-- =============================================================================
-- ĐẢM BẢO SCHEMA report TỒN TẠI
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'report')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA report AUTHORIZATION dbo;';
    PRINT N'[02-report] Schema [report] đã được tạo.';
END
GO

-- =============================================================================
-- 1. report.DailySalesSummary
-- =============================================================================
-- Bảng tổng hợp doanh thu theo từng bộ (ngày, máy, sản phẩm).
-- Được nạp bởi stored procedure usp_report_RefreshDailySales (chạy nightly).
-- Khóa chính composite: (SummaryDate, MachineId, ProductId).

IF OBJECT_ID(N'report.DailySalesSummary', N'U') IS NOT NULL
    PRINT N'[02-report] report.DailySalesSummary đã tồn tại — bỏ qua.';
ELSE
BEGIN
    CREATE TABLE report.DailySalesSummary (
        -- ── Khóa chính composite ─────────────────────────────────────────────
        SummaryDate     DATE            NOT NULL,
        MachineId       INT             NOT NULL,   -- FK → inventory.Machine
        ProductId       INT             NOT NULL,   -- FK → inventory.Product

        -- ── Số liệu tổng hợp ─────────────────────────────────────────────────
        QtySold         INT             NOT NULL
            CONSTRAINT DF_report_DSS_QtySold    DEFAULT (0),
        Revenue         DECIMAL(18,2)   NOT NULL
            CONSTRAINT DF_report_DSS_Revenue    DEFAULT (0.00),

        -- ── Cột bổ sung hỗ trợ báo cáo nâng cao ─────────────────────────────
        OrderCount      INT             NOT NULL
            CONSTRAINT DF_report_DSS_OrderCount DEFAULT (0),   -- số đơn có chứa sản phẩm này
        AvgUnitPrice    DECIMAL(12,2)       NULL,               -- giá bán trung bình trong ngày
        TotalDiscount   DECIMAL(18,2)   NOT NULL
            CONSTRAINT DF_report_DSS_Discount   DEFAULT (0.00),
        NetRevenue      AS (Revenue - TotalDiscount) PERSISTED, -- cột tính toán, lưu vật lý

        -- ── Metadata ─────────────────────────────────────────────────────────
        RefreshedAt     DATETIME2(0)    NOT NULL
            CONSTRAINT DF_report_DSS_RefreshedAt DEFAULT SYSUTCDATETIME(),

        -- ── Ràng buộc ─────────────────────────────────────────────────────────
        CONSTRAINT PK_report_DailySalesSummary
            PRIMARY KEY (SummaryDate, MachineId, ProductId),

        CONSTRAINT CK_report_DSS_QtySold
            CHECK (QtySold >= 0),
        CONSTRAINT CK_report_DSS_Revenue
            CHECK (Revenue >= 0 AND TotalDiscount >= 0)
        -- FK sang inventory.Machine và inventory.Product → 03_foreign_keys.sql
    );

    -- Index hỗ trợ truy vấn theo ngày (dải thời gian)
    CREATE NONCLUSTERED INDEX IX_report_DSS_Date
        ON report.DailySalesSummary (SummaryDate DESC)
        INCLUDE (MachineId, ProductId, QtySold, Revenue);

    -- Index hỗ trợ truy vấn theo máy + ngày
    CREATE NONCLUSTERED INDEX IX_report_DSS_Machine_Date
        ON report.DailySalesSummary (MachineId, SummaryDate DESC);

    -- Index hỗ trợ truy vấn theo sản phẩm + ngày
    CREATE NONCLUSTERED INDEX IX_report_DSS_Product_Date
        ON report.DailySalesSummary (ProductId, SummaryDate DESC);

    PRINT N'[02-report] Bảng report.DailySalesSummary đã được tạo.';
END
GO

-- =============================================================================
-- 2. report.ExportLogs
-- =============================================================================
-- Ghi nhật ký mỗi lần người dùng xuất báo cáo (PDF, Excel, CSV…).
-- FK sang auth.User: ExportLogs.UserId → auth.User.UserId.

IF OBJECT_ID(N'report.ExportLogs', N'U') IS NOT NULL
    PRINT N'[02-report] report.ExportLogs đã tồn tại — bỏ qua.';
ELSE
BEGIN
    CREATE TABLE report.ExportLogs (
        -- ── Khóa chính ───────────────────────────────────────────────────────
        ExportId        INT             NOT NULL IDENTITY(1,1),

        -- ── Người xuất ───────────────────────────────────────────────────────
        UserId          INT             NOT NULL,   -- FK → auth.User (NOT NULL: xuất phải có user)

        -- ── Thông tin báo cáo ────────────────────────────────────────────────
        ReportName      NVARCHAR(150)   NOT NULL,   -- vd: 'DailySales', 'MachineStock'
        Params          NVARCHAR(MAX)       NULL,   -- JSON: tham số lọc (từ ngày, đến ngày, máy…)
        FileFormat      NVARCHAR(10)    NOT NULL    -- 'PDF','EXCEL','CSV','JSON'
            CONSTRAINT DF_report_ExportLogs_Format  DEFAULT (N'EXCEL'),
        FilePath        NVARCHAR(500)       NULL,   -- đường dẫn file trên server (nếu lưu file)
        FileSizeBytes   BIGINT              NULL,   -- kích thước file (bytes)
        RowCount        INT                 NULL,   -- số dòng dữ liệu được xuất
        DurationMs      INT                 NULL,   -- thời gian xử lý (milliseconds)
        Status          NVARCHAR(10)    NOT NULL    -- 'SUCCESS','FAILED','PENDING'
            CONSTRAINT DF_report_ExportLogs_Status  DEFAULT (N'PENDING'),
        ErrorMessage    NVARCHAR(500)       NULL,   -- ghi lỗi nếu Status = 'FAILED'

        -- ── Thời điểm ────────────────────────────────────────────────────────
        ExportedAt      DATETIME2(3)    NOT NULL
            CONSTRAINT DF_report_ExportLogs_ExportedAt DEFAULT SYSUTCDATETIME(),

        -- ── Ràng buộc ────────────────────────────────────────────────────────
        CONSTRAINT PK_report_ExportLogs
            PRIMARY KEY (ExportId),
        CONSTRAINT CK_report_ExportLogs_Format
            CHECK (FileFormat IN (N'PDF', N'EXCEL', N'CSV', N'JSON')),
        CONSTRAINT CK_report_ExportLogs_Status
            CHECK (Status IN (N'SUCCESS', N'FAILED', N'PENDING')),
        CONSTRAINT FK_report_ExportLogs_User
            FOREIGN KEY (UserId) REFERENCES auth.[User](UserId)
            ON DELETE NO ACTION
            ON UPDATE NO ACTION
        -- Ghi chú: FK tới auth.User tạo trực tiếp ở đây vì auth.User
        --          đã được tạo ở bước trước (02_tables_auth.sql).
        --          Nếu muốn tập trung tất cả FK, di chuyển vào 03_foreign_keys.sql.
    );

    -- Index hỗ trợ tra lịch sử xuất của từng user
    CREATE NONCLUSTERED INDEX IX_report_ExportLogs_User_Time
        ON report.ExportLogs (UserId, ExportedAt DESC);

    -- Index hỗ trợ lọc theo tên báo cáo + thời gian
    CREATE NONCLUSTERED INDEX IX_report_ExportLogs_Report_Time
        ON report.ExportLogs (ReportName, ExportedAt DESC);

    PRINT N'[02-report] Bảng report.ExportLogs đã được tạo.';
END
GO

-- =============================================================================
-- 3. report.TestResults
-- =============================================================================
-- Lưu kết quả từng test case khi chạy các script kiểm thử T-SQL.
-- Hỗ trợ theo dõi regression và lịch sử pass/fail theo thời gian.

IF OBJECT_ID(N'report.TestResults', N'U') IS NOT NULL
    PRINT N'[02-report] report.TestResults đã tồn tại — bỏ qua.';
ELSE
BEGIN
    CREATE TABLE report.TestResults (
        -- ── Khóa chính ───────────────────────────────────────────────────────
        TestId          INT             NOT NULL IDENTITY(1,1),

        -- ── Phân loại ────────────────────────────────────────────────────────
        Module          NVARCHAR(50)    NOT NULL,   -- 'auth','inventory','sales','iot','report'
        TestCase        NVARCHAR(150)   NOT NULL,   -- vd: 'TC-AUTH-02: Email trùng bị từ chối'

        -- ── Kịch bản kiểm thử ────────────────────────────────────────────────
        Expected        NVARCHAR(500)   NOT NULL,   -- kết quả kỳ vọng (mô tả hoặc giá trị)
        Actual          NVARCHAR(500)       NULL,   -- kết quả thực tế thu được
        ErrorDetail     NVARCHAR(MAX)       NULL,   -- thông báo lỗi chi tiết (ERROR_MESSAGE())

        -- ── Kết quả ──────────────────────────────────────────────────────────
        Passed          BIT             NOT NULL    -- 1 = PASS, 0 = FAIL
            CONSTRAINT DF_report_TestResults_Passed DEFAULT (0),

        -- ── Hiệu năng ────────────────────────────────────────────────────────
        DurationMs      INT                 NULL,   -- thời gian thực thi test (ms)

        -- ── Metadata ─────────────────────────────────────────────────────────
        RunBy           NVARCHAR(100)       NULL,   -- tên script hoặc user chạy test
        RunAt           DATETIME2(3)    NOT NULL
            CONSTRAINT DF_report_TestResults_RunAt  DEFAULT SYSUTCDATETIME(),
        BatchId         UNIQUEIDENTIFIER    NULL
            CONSTRAINT DF_report_TestResults_BatchId DEFAULT NEWID(),
                                                    -- nhóm các test cùng một lần chạy

        -- ── Ràng buộc ────────────────────────────────────────────────────────
        CONSTRAINT PK_report_TestResults
            PRIMARY KEY (TestId),
        CONSTRAINT CK_report_TestResults_Module
            CHECK (Module IN (N'auth', N'inventory', N'sales', N'iot', N'report', N'audit'))
    );

    -- Index hỗ trợ xem kết quả theo module + thời gian chạy
    CREATE NONCLUSTERED INDEX IX_report_TestResults_Module_RunAt
        ON report.TestResults (Module, RunAt DESC)
        INCLUDE (TestCase, Passed);

    -- Index hỗ trợ lọc nhanh các test FAIL
    CREATE NONCLUSTERED INDEX IX_report_TestResults_Passed_RunAt
        ON report.TestResults (Passed, RunAt DESC)
        WHERE Passed = 0;   -- filtered index — chỉ đánh index dòng FAIL

    -- Index hỗ trợ nhóm theo BatchId
    CREATE NONCLUSTERED INDEX IX_report_TestResults_Batch
        ON report.TestResults (BatchId, RunAt DESC);

    PRINT N'[02-report] Bảng report.TestResults đã được tạo.';
END
GO

-- =============================================================================
-- XÁC NHẬN KẾT QUẢ
-- =============================================================================

SELECT
    t.TABLE_SCHEMA                      AS [Schema],
    t.TABLE_NAME                        AS [Table],
    COUNT(c.COLUMN_NAME)                AS [Columns],
    STRING_AGG(
        CASE WHEN kcu.COLUMN_NAME IS NOT NULL
             THEN c.COLUMN_NAME COLLATE DATABASE_DEFAULT
        END, N', '
    ) WITHIN GROUP (ORDER BY kcu.ORDINAL_POSITION)  AS [PK Columns]
FROM INFORMATION_SCHEMA.TABLES t
JOIN INFORMATION_SCHEMA.COLUMNS c
    ON  c.TABLE_SCHEMA = t.TABLE_SCHEMA
    AND c.TABLE_NAME   = t.TABLE_NAME
LEFT JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
    ON  tc.TABLE_SCHEMA     = t.TABLE_SCHEMA
    AND tc.TABLE_NAME       = t.TABLE_NAME
    AND tc.CONSTRAINT_TYPE  = 'PRIMARY KEY'
LEFT JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
    ON  kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
    AND kcu.TABLE_SCHEMA    = tc.TABLE_SCHEMA
    AND kcu.COLUMN_NAME     = c.COLUMN_NAME
WHERE t.TABLE_SCHEMA = N'report'
GROUP BY t.TABLE_SCHEMA, t.TABLE_NAME
ORDER BY t.TABLE_NAME;
GO

PRINT N'';
PRINT N'================================================================';
PRINT N'  02_tables_report.sql hoàn tất. Tiếp theo: 03_foreign_keys.sql';
PRINT N'================================================================';
GO
