param([string]$Server='.\SQLEXPRESS',[switch]$Resume,[switch]$LargeOnly)
$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
$testDb='FreshVendTV5_Test_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$outputRoot=Join-Path $repoRoot '.local-test/tv5'
New-Item -ItemType Directory -Force $outputRoot | Out-Null
function Invoke-TestSql([string]$File,[string]$Name) {
    $sqlText=Get-Content -LiteralPath $File -Raw -Encoding UTF8
    $sqlText=$sqlText.Replace('FreshVendDB',$testDb)
    $prepared=Join-Path $outputRoot $Name
    [IO.File]::WriteAllText($prepared,$sqlText,(New-Object Text.UTF8Encoding($true)))
    & sqlcmd -S $Server -E -C -I -b -r 1 -d $testDb -i $prepared -o "$prepared.log" -u
    if($LASTEXITCODE -ne 0) { Get-Content "$prepared.log" -Encoding Unicode -Tail 25; throw "SQL failed: $Name" }
    Write-Output "PASS $Name"
}
function Invoke-ClientChecks {
    $connection=New-Object System.Data.SqlClient.SqlConnection("Server=$Server;Database=$testDb;Integrated Security=True;TrustServerCertificate=True;Encrypt=False")
    $connection.Open()
    try {
        function Query([string]$Text) {
            $command=$connection.CreateCommand()
            $command.CommandText="SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_WARNINGS ON; SET ANSI_PADDING ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF; $Text"
            $adapter=New-Object System.Data.SqlClient.SqlDataAdapter($command)
            $data=New-Object System.Data.DataSet
            [void]$adapter.Fill($data)
            return ,$data
        }
        $dashboard=Query "EXEC report.sp_DashboardKpi @AsOf='20261103'"
        $oracle=Query "SELECT COALESCE(SUM(TotalAmount),0) Revenue,COUNT(*) Orders FROM sales.[Order] WHERE Status=N'paid' AND CreatedAt>='2026-11-02T17:00:00' AND CreatedAt<'2026-11-03T17:00:00'"
        if($dashboard.Tables.Count -ne 3 -or $dashboard.Tables[1].Rows.Count -ne 14) { throw 'Dashboard result shape mismatch' }
        if($dashboard.Tables[0].Rows[0].RevenueToday -ne $oracle.Tables[0].Rows[0].Revenue -or $dashboard.Tables[0].Rows[0].OrdersToday -ne $oracle.Tables[0].Rows[0].Orders) { throw 'Dashboard revenue/order mismatch' }
        $growth=Query 'EXEC report.sp_RevenueGrowth @Year=2026'
        $oracle=Query "SELECT SUM(TotalAmount) Revenue,COUNT(*) Orders FROM sales.[Order] WHERE Status=N'paid'"
        if($growth.Tables[0].Rows.Count -ne 12 -or ($growth.Tables[0].Rows | Measure-Object Revenue -Sum).Sum -ne $oracle.Tables[0].Rows[0].Revenue) { throw 'Growth revenue mismatch' }
        $peak=Query "SET DATEFIRST 1; EXEC report.sp_PeakHours '20260806','20261103'; SET DATEFIRST 7; EXEC report.sp_PeakHours '20260806','20261103';"
        if($peak.Tables[0].Rows.Count -ne 24 -or ($peak.Tables[0].Rows | Measure-Object Total -Sum).Sum -ne $oracle.Tables[0].Rows[0].Orders) { throw 'Peak count mismatch' }
        for($hour=0;$hour -lt 24;$hour++) {
            foreach($day in @('T2','T3','T4','T5','T6','T7','CN','Total')) {
                if($peak.Tables[0].Rows[$hour][$day] -ne $peak.Tables[1].Rows[$hour][$day]) { throw 'DATEFIRST changed peak results' }
            }
        }
        $export=Query "DECLARE @u INT=(SELECT UserId FROM auth.[User] WHERE Username=N'admin01'); EXEC report.sp_ExportSales '20260806','20261103',@u,@FileFormat=N'PDF';"
        if(($export.Tables[0].Rows | Measure-Object LineTotal -Sum).Sum -ne $oracle.Tables[0].Rows[0].Revenue) { throw 'Export rows mismatch' }
        $log=Query 'SELECT TOP(1) FileFormat,Status,ISJSON(Params) ValidJson,[RowCount] FROM report.ExportLogs ORDER BY ExportId DESC'
        if($log.Tables[0].Rows[0].FileFormat -ne 'PDF' -or $log.Tables[0].Rows[0].Status -ne 'PENDING' -or $log.Tables[0].Rows[0].ValidJson -ne 1 -or $log.Tables[0].Rows[0].RowCount -ne $export.Tables[0].Rows.Count) { throw 'Export log mismatch' }
        Write-Output 'PASS client-oracles: dashboard, growth, DATEFIRST, export and JSON log'
    } finally { $connection.Close() }
}
if($Resume) {
    $testDb=(Get-Content (Join-Path $outputRoot 'database.txt')).Trim()
    foreach($file in @('04_report_dependencies.sql','24_objects_report.sql','07_procs_report.sql')) { Invoke-TestSql (Join-Path $repoRoot "sql/$file") "resume-$file" }
    Invoke-TestSql (Join-Path $repoRoot 'tests/sql/37_verify_report.sql') 'verify-report.sql'
    Invoke-ClientChecks
    Invoke-TestSql (Join-Path $repoRoot 'tests/sql/38_perf_report.sql') 'performance.sql'
    exit 0
}
& sqlcmd -S $Server -E -C -b -Q "CREATE DATABASE [$testDb] COLLATE Vietnamese_CI_AS; ALTER DATABASE [$testDb] SET COMPATIBILITY_LEVEL=160; SELECT CONVERT(VARCHAR(40),SERVERPROPERTY('ProductVersion')) Version;" -W
if($LASTEXITCODE -ne 0) { throw 'Cannot create isolated SQL Server 2022 test database.' }
Set-Content (Join-Path $outputRoot 'database.txt') $testDb
$files=@('01_schemas.sql','02_tables_auth.sql','02_tables_inventory.sql','02_tables_sales.sql','02_tables_iot.sql','02_tables_report.sql','03_foreign_keys.sql','04_report_dependencies.sql','24_objects_report.sql','07_procs_report.sql')
foreach($file in $files) { Invoke-TestSql (Join-Path $repoRoot "sql/$file") $file }
if(-not $LargeOnly) {
    Invoke-TestSql (Join-Path $repoRoot 'sql/05_seed_small.sql') 'small-1.sql'
    Invoke-TestSql (Join-Path $repoRoot 'tests/sql/35_verify_seed.sql') 'verify-small.sql'
    Invoke-TestSql (Join-Path $repoRoot 'sql/05_seed_small.sql') 'small-2.sql'
    Invoke-TestSql (Join-Path $repoRoot 'tests/sql/35_verify_seed.sql') 'verify-small-rerun.sql'
}
Invoke-TestSql (Join-Path $repoRoot 'sql/06_seed_large.sql') 'large-1.sql'
Invoke-TestSql (Join-Path $repoRoot 'tests/sql/35_verify_seed.sql') 'verify-large.sql'
Invoke-TestSql (Join-Path $repoRoot 'sql/06_seed_large.sql') 'large-2.sql'
Invoke-TestSql (Join-Path $repoRoot 'tests/sql/35_verify_seed.sql') 'verify-large-rerun.sql'
foreach($file in $files) { Invoke-TestSql (Join-Path $repoRoot "sql/$file") "rerun-$file" }
Invoke-TestSql (Join-Path $repoRoot 'tests/sql/37_verify_report.sql') 'verify-report.sql'
Invoke-ClientChecks
Invoke-TestSql (Join-Path $repoRoot 'tests/sql/38_perf_report.sql') 'performance.sql'
Write-Output "Database retained for review: $testDb"
