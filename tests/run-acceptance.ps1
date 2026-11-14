param([string]$Server='.\SQLEXPRESS',[string]$Database=('FreshVend_QA239_'+(Get-Date -Format 'yyyyMMdd_HHmmss')),[switch]$Installed)
$ErrorActionPreference='Stop'
if($Database -notmatch '^FreshVend_QA[A-Za-z0-9_]+$'){throw 'QA database required'}
$root=Split-Path $PSScriptRoot -Parent
$out=Join-Path $root ('.local-test/acceptance/'+$Database+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force $out | Out-Null
$results=[Collections.Generic.List[object]]::new()
if(-not $Installed){& (Join-Path $root '99_run_all.bat') $Server $Database;if($LASTEXITCODE){throw 'Install failed'}}
function Run-Sql([string]$Name,[string]$Text){
 $connection=New-Object System.Data.SqlClient.SqlConnection("Server=$Server;Database=$Database;Integrated Security=True;TrustServerCertificate=True;Encrypt=False")
 $record=@{Name=$Name;StartedAt=(Get-Date).ToString('o');Status='NOT RUN';Tables=@();Messages=@();Error=$null}
 $messages=[Collections.Generic.List[string]]::new()
 $connection.add_InfoMessage([System.Data.SqlClient.SqlInfoMessageEventHandler]{param($sender,$event) $messages.Add($event.Message)})
 try {
  $connection.Open()
  $settings=$connection.CreateCommand();$settings.CommandText='SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF; ';[void]$settings.ExecuteNonQuery()
  foreach($batch in [regex]::Split($Text.Replace('FreshVendDB',$Database),'(?im)^\s*GO\s*$')){
   if(-not $batch.Trim()){continue}
   $cmd=$connection.CreateCommand();$cmd.CommandTimeout=180
   $cmd.CommandText=$batch
   $reader=$cmd.ExecuteReader()
   try {
    do {
     if($reader.FieldCount -gt 0){
      $table=[Collections.Generic.List[object]]::new()
      while($reader.Read()){
       $row=[ordered]@{}
       for($i=0;$i -lt $reader.FieldCount;$i++){$v=$reader.GetValue($i);$row[$reader.GetName($i)]=$(if($v -is [DBNull]){$null}elseif($v -is [DateTime]){$v.ToString('o')}else{$v})}
       $table.Add($row)
      }
      $record.Tables+=,@($table.ToArray())
     }
    } while($reader.NextResult())
   } finally {$reader.Close()}
  }
  $cases=@($record.Tables | ForEach-Object {$_} | Where-Object {($_.Contains('TestNo') -or $_.Contains('TestCode') -or $_.Contains('TestCase')) -and $_.Contains('Passed')})
  $record.Cases=$cases
  $record.Status=$(if(@($cases | Where-Object { -not $_.Passed }).Count){'FAIL'}else{'PASS'})
 } catch {$record.Status='ERROR';$record.Error=$_.Exception.GetBaseException().Message}
 finally {
  $connection.Dispose();$record.Messages=$messages.ToArray();$record.CompletedAt=(Get-Date).ToString('o')
  $results.Add($record)
  $record | ConvertTo-Json -Depth 14 | Set-Content (Join-Path $out "$Name.json") -Encoding UTF8
  Write-Output "$Name $($record.Status) $($record.Error)"
 }
}
function File([string]$Relative){Run-Sql (Split-Path $Relative -Leaf) (Get-Content (Join-Path $root $Relative) -Raw -Encoding UTF8)}
File 'tests/sql/239_inventory_fixture.sql'
File 'sql/08_seed_inventory.sql'
File 'sql/10_procs_auth.sql'
foreach($file in @('tests_auth.sql','tests_inventory.sql','tests_sales.sql','tests_audit.sql','tests_security.sql')){File "tests/$file"}
File 'tests/sql/fixtures_report.sql'
Run-Sql 'runner' "EXEC report.sp_RunAllTests @RunBy=N'SCRUM-239 actual SQL acceptance';"
File 'tests/tests_iot.sql'
File 'tests/tests_report.sql'
Run-Sql 'environment' "SELECT @@VERSION Version,DB_NAME() [Database],SYSDATETIMEOFFSET() RunAt; SELECT compatibility_level,collation_name FROM sys.databases WHERE name=DB_NAME(); SELECT 'Orders' Kind,COUNT_BIG(*) Total FROM sales.[Order] UNION ALL SELECT 'Telemetry',COUNT_BIG(*) FROM iot.Telemetry;"
$results.ToArray() | ConvertTo-Json -Depth 15 | Set-Content (Join-Path $out 'results.json') -Encoding UTF8
Set-Content (Join-Path $root '.local-test/acceptance/latest.txt') $out -Encoding UTF8
Write-Output "Actual results (inspect per-case failures and blocked cases): $out"
if(@($results | Where-Object Status -ne 'PASS').Count){exit 2}
