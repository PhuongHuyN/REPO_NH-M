param([string]$Server='.\SQLEXPRESS',[switch]$RequireAll)
$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
$testDb='FreshVendTV5_Week2_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$outputRoot=Join-Path $repoRoot ".local-test/week2/$testDb"
New-Item -ItemType Directory -Force $outputRoot | Out-Null
$checks=[Collections.Generic.List[object]]::new()
function Run-Sql([string]$Relative,[switch]$OwnerDependency) {
 $name=Split-Path $Relative -Leaf
 $text=(Get-Content (Join-Path $repoRoot $Relative) -Raw -Encoding UTF8).Replace('FreshVendDB',$testDb)
 $file=Join-Path $outputRoot $name
 [IO.File]::WriteAllText($file,$text,(New-Object Text.UTF8Encoding($true)))
 & sqlcmd -S $Server -E -C -I -b -r 1 -d $testDb -i $file -o "$file.log" -u 2>"$file.stderr.log"
 $failed=$LASTEXITCODE -ne 0
 $checks.Add(@{Name=$Relative;Status=$(if($failed){'BLOCKED'}else{'PASS'});Log="$name.log"})
 if($failed -and -not $OwnerDependency) { Get-Content "$file.log" -Encoding Unicode -Tail 15; Get-Content "$file.stderr.log" -Tail 15; throw "$Relative failed" }
 Write-Output "$(if($failed){'BLOCKED'}else{'PASS'}) $Relative"
}
try {
 & sqlcmd -S $Server -E -C -I -b -Q "CREATE DATABASE [$testDb] COLLATE Vietnamese_CI_AS; ALTER DATABASE [$testDb] SET COMPATIBILITY_LEVEL=160;"
 if($LASTEXITCODE -ne 0) { throw 'Cannot create isolated test database' }
 foreach($file in @('01_schemas.sql','02_tables_auth.sql','02_tables_inventory.sql','02_tables_iot.sql','02_tables_report.sql','02_tables_sales.sql')) { Run-Sql "sql/$file" }
 Run-Sql 'sql/03_foreign_keys.sql' -OwnerDependency
 foreach($file in @('11_procs_inventory.sql','12_procs_sales.sql','13_procs_iot.sql')) { Run-Sql "sql/$file" -OwnerDependency }
 Run-Sql 'sql/14_procs_report.sql'
 Run-Sql 'sql/24_objects_report.sql'
 # Baseline read/test fixtures are NOT production seeds or integration proof.
 Run-Sql 'tests/sql/fixtures_report.sql'
 Run-Sql 'sql/80_seed_small.sql' -OwnerDependency
 Run-Sql 'sql/81_seed_large.sql' -OwnerDependency
 Run-Sql 'tests/sql/224_verify_runner.sql'
 Run-Sql 'tests/sql/26_verify_ingest.sql'
 $connection=New-Object System.Data.SqlClient.SqlConnection("Server=$Server;Database=$testDb;Integrated Security=True;TrustServerCertificate=True;Encrypt=False")
 $connection.Open()
 try {
  $cmd=$connection.CreateCommand()
  $cmd.CommandText='SELECT Module,Status,COUNT(*) Total FROM report.vw_LatestTestRun GROUP BY Module,Status ORDER BY Module,Status'
  $adapter=New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
  $table=New-Object System.Data.DataTable
  [void]$adapter.Fill($table)
  $result=@($table.Rows | ForEach-Object { @{Module=$_.Module;Status=$_.Status;Count=[int]$_.Total} })
  $result | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $outputRoot 'results.json')
  $result | ForEach-Object { Write-Output "$($_.Module) $($_.Status) $($_.Count)" }
  if($RequireAll -and ($result | Where-Object Status -ne 'PASS')) { throw 'Week 2 acceptance not all PASS; inspect results and owner issues.' }
 } finally { $connection.Close() }
 Write-Output "Runner integrity PASS; per-case acceptance recorded separately: $testDb"
} finally {
 $checks | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $outputRoot 'checks.json')
 Set-Content -Encoding UTF8 (Join-Path $repoRoot '.local-test/week2/latest.txt') $outputRoot
}
