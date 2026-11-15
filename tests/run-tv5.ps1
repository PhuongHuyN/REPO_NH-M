param([string]$Server='.\SQLEXPRESS',[switch]$RequireIntegration)
$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
$testDb='FreshVendTV5_Week1_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$outputRoot=Join-Path $repoRoot ".local-test/tv5-week1/$testDb"
New-Item -ItemType Directory -Force $outputRoot | Out-Null
$checks=[Collections.Generic.List[object]]::new()
function Invoke-TestSql([string]$File,[string]$Name,[switch]$AllowBlocked) {
    $sqlText=(Get-Content -LiteralPath $File -Raw -Encoding UTF8).Replace('FreshVendDB',$testDb)
    $prepared=Join-Path $outputRoot $Name
    [IO.File]::WriteAllText($prepared,$sqlText,(New-Object Text.UTF8Encoding($true)))
    & sqlcmd -S $Server -E -C -I -b -r 1 -d $testDb -i $prepared -o "$prepared.log" -u 2>"$prepared.stderr.log"
    $failed=$LASTEXITCODE -ne 0
    $checks.Add(@{Name=$Name;Status=$(if($failed){'BLOCKED'}else{'PASS'});Log="$Name.log"})
    if($failed) {
        if($AllowBlocked) { Write-Output "BLOCKED $Name (owner dependency; log retained)"; return }
        Get-Content "$prepared.log" -Encoding Unicode -Tail 12
        Get-Content "$prepared.stderr.log" -Tail 12
        throw "SQL failed: $Name"
    }
    Write-Output "PASS $Name"
}
try {
 & sqlcmd -S $Server -E -C -I -b -Q "CREATE DATABASE [$testDb] COLLATE Vietnamese_CI_AS; ALTER DATABASE [$testDb] SET COMPATIBILITY_LEVEL=160; SELECT CONVERT(VARCHAR(40),SERVERPROPERTY('ProductVersion')) Version;" -W
 if($LASTEXITCODE -ne 0) { throw 'Cannot create isolated database.' }
 $files=@('01_schemas.sql','02_tables_auth.sql','02_tables_inventory.sql','02_tables_iot.sql','02_tables_report.sql','02_tables_sales.sql')
 foreach($file in $files) { Invoke-TestSql (Join-Path $repoRoot "sql/$file") $file }
 # Never patch the owner's FK script or hide the integration failure.
 Invoke-TestSql (Join-Path $repoRoot 'sql/03_foreign_keys.sql') '03_foreign_keys.sql' -AllowBlocked
 foreach($file in @('14_procs_report.sql','24_objects_report.sql')) { Invoke-TestSql (Join-Path $repoRoot "sql/$file") $file }
 foreach($file in @('80_seed_small.sql','81_seed_large.sql')) { Invoke-TestSql (Join-Path $repoRoot "sql/$file") "preflight-$file" -AllowBlocked }
 Invoke-TestSql (Join-Path $repoRoot 'tests/sql/fixtures_report.sql') 'fixtures-report.sql'
 Invoke-TestSql (Join-Path $repoRoot 'tests/sql/fixtures_report.sql') 'fixtures-report-rerun.sql'
 foreach($file in @('02_tables_report.sql','14_procs_report.sql','24_objects_report.sql')) { Invoke-TestSql (Join-Path $repoRoot "sql/$file") "rerun-$file" }
 Invoke-TestSql (Join-Path $repoRoot 'tests/sql/37_verify_report.sql') 'verify-report.sql'
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
  $oracle=Query "SELECT COALESCE(SUM(TotalAmount),0) Revenue,COUNT(*) Orders FROM sales.[Order] WHERE Status IN(N'PAID',N'DISPENSED') AND CreatedAt>='2026-11-02T17:00:00' AND CreatedAt<'2026-11-03T17:00:00'"
  if($dashboard.Tables.Count -ne 3 -or $dashboard.Tables[1].Rows.Count -ne 14) { throw 'Dashboard result shape mismatch' }
  if($dashboard.Tables[0].Rows[0].RevenueToday -ne $oracle.Tables[0].Rows[0].Revenue -or $dashboard.Tables[0].Rows[0].OrdersToday -ne $oracle.Tables[0].Rows[0].Orders) { throw 'Dashboard revenue/order mismatch' }
  if($dashboard.Tables[0].Rows[0].MachinesActive -ne 4) { throw 'ACTIVE fleet count mismatch' }
  $growth=Query 'EXEC report.sp_RevenueGrowth @Year=2026'
  if($growth.Tables[0].Rows.Count -ne 12 -or ($growth.Tables[0].Rows | Measure-Object Revenue -Sum).Sum -ne $oracle.Tables[0].Rows[0].Revenue) { throw 'Growth revenue mismatch' }
  if(-not $growth.Tables[0].Columns.Contains('QtySold') -or -not $growth.Tables[0].Columns.Contains('PrevRevenue')) { throw 'Growth API contract mismatch' }
  $peak=Query "SET DATEFIRST 1; EXEC report.sp_PeakHours '20261103','20261103'; SET DATEFIRST 7; EXEC report.sp_PeakHours '20261103','20261103';"
  if($peak.Tables[0].Rows.Count -ne 24 -or ($peak.Tables[0].Rows | Measure-Object Total -Sum).Sum -ne $oracle.Tables[0].Rows[0].Orders) { throw 'Peak count mismatch' }
  for($hour=0;$hour -lt 24;$hour++) { foreach($day in @('T2','T3','T4','T5','T6','T7','CN','Total')) {
   if($peak.Tables[0].Rows[$hour][$day] -ne $peak.Tables[1].Rows[$hour][$day]) { throw 'DATEFIRST changed peak results' }
  } }
  $export=Query "DECLARE @u INT=(SELECT UserId FROM auth.[User] WHERE Username=N'admin01'); EXEC report.sp_ExportSales '20261103','20261103',@u,@FileFormat=N'CSV';"
  if($export.Tables[0].Rows.Count -ne 50) { throw 'Audit export must include refunded rows as fakeDb specifies' }
  $log=Query 'SELECT TOP(1) FileFormat,Status,ISJSON(Params) ValidJson,[RowCount] FROM report.ExportLogs ORDER BY ExportId DESC'
  if($log.Tables[0].Rows[0].FileFormat -ne 'CSV' -or $log.Tables[0].Rows[0].Status -ne 'PENDING' -or $log.Tables[0].Rows[0].ValidJson -ne 1 -or $log.Tables[0].Rows[0].RowCount -ne 50) { throw 'Export log mismatch' }
  Write-Output 'PASS client-oracles: dashboard, growth, DATEFIRST, audit export and JSON log'
  $checks.Add(@{Name='client-oracles';Status='PASS'})
 } finally { $connection.Close() }
 Write-Output "Report acceptance PASS; full integration status is recorded separately. Database: $testDb"
 if($RequireIntegration -and ($checks | Where-Object Status -eq 'BLOCKED')) { throw 'Full integration BLOCKED: see owner issues #19/#20/#21.' }
} finally {
 $checks | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $outputRoot 'checks.json')
 Set-Content -Encoding UTF8 (Join-Path $repoRoot '.local-test/tv5-week1/latest.txt') $outputRoot
}
