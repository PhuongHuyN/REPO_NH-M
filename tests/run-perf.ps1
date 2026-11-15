param(
 [string]$Server='.\SQLEXPRESS',
 [Parameter(Mandatory=$true)][ValidatePattern('^FreshVend[A-Za-z0-9_]*$')][string]$Database,
 [string]$OwnerIndexScript,
 [switch]$ControlOnly
)
$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
$output=Join-Path $repoRoot ('.local-test/perf/'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force $output | Out-Null
$connection=New-Object System.Data.SqlClient.SqlConnection("Server=$Server;Database=$Database;Integrated Security=True;TrustServerCertificate=True;Encrypt=False")
$samples=[Collections.Generic.List[object]]::new()
$messages=[Collections.Generic.List[string]]::new()
$plans=[Collections.Generic.List[string]]::new()
$summary=@{Database=$Database;ControlOnly=[bool]$ControlOnly;Before='NOT RUN';After='BLOCKED';Reason='Chưa có index script của owner';Output=$output}
$onInfo=[System.Data.SqlClient.SqlInfoMessageEventHandler]{param($sender,$event) $messages.Add($event.Message)}
$connection.add_InfoMessage($onInfo)
function Snapshot-Indexes {
 $cmd=$connection.CreateCommand()
 $cmd.CommandText="SELECT OBJECT_SCHEMA_NAME(i.object_id) SchemaName,OBJECT_NAME(i.object_id) TableName,i.name IndexName,i.type_desc,[key]=c.key_ordinal,COL_NAME(c.object_id,c.column_id) ColumnName,c.is_included_column FROM sys.indexes i JOIN sys.index_columns c ON c.object_id=i.object_id AND c.index_id=i.index_id WHERE OBJECT_SCHEMA_NAME(i.object_id) IN('report','inventory','sales','iot') ORDER BY SchemaName,TableName,IndexName,c.index_column_id"
 $adapter=New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $table=New-Object System.Data.DataTable
 [void]$adapter.Fill($table)
 return ,@($table.Rows | ForEach-Object { @{Schema=$_.SchemaName;Table=$_.TableName;Index=$_.IndexName;Column=$_.ColumnName;Ordinal=[int]$_.key;Included=[bool]$_.is_included_column} })
}
function Measure-Phase([string]$Phase) {
 $text=(Get-Content (Join-Path $repoRoot 'tests/70_perf_tests.sql') -Raw -Encoding UTF8).Replace('FreshVendDB',$Database)
 $text=[regex]::Replace($text,'(?im)^\s*GO\s*$','')
 $prefix="SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF; EXEC sys.sp_set_session_context @key=N'TV5PerfPhase',@value=N'$Phase'; EXEC sys.sp_set_session_context @key=N'TV5PerfControl',@value=$([int][bool]$ControlOnly); EXEC sys.sp_set_session_context @key=N'TV5OwnerIndexApplied',@value=$(if($Phase -eq 'AFTER'){1}else{0});"
 $cmd=$connection.CreateCommand(); $cmd.CommandTimeout=180; $cmd.CommandText=$prefix+$text
 $reader=$cmd.ExecuteReader()
 $pendingPlans=[Collections.Generic.List[string]]::new()
 try {
  do {
   while($reader.Read()) {
    if($reader.FieldCount -eq 1 -and $reader.GetName(0) -like '*Showplan*') {
     $pendingPlans.Add([string]$reader.GetValue(0))
    } elseif($reader.FieldCount -gt 0 -and $reader.GetName(0) -eq 'RecordType') {
     $sample=[ordered]@{}
     for($col=0;$col -lt $reader.FieldCount;$col++) { $sample[$reader.GetName($col)]=$reader.GetValue($col) }
     $sample['Plans']=@()
     for($i=0;$i -lt $pendingPlans.Count;$i++) {
      $name="$Phase-$($sample.QueryName)-$($sample.Iteration)-$i.sqlplan"
      $planPath=Join-Path $output $name
      [IO.File]::WriteAllText($planPath,$pendingPlans[$i],(New-Object Text.UTF8Encoding($false)))
      $sample.Plans+=@($name); $plans.Add($name)
     }
     $pendingPlans.Clear()
     $samples.Add($sample)
    }
   }
  } while($reader.NextResult())
 } finally { $reader.Close() }
 $summary[$Phase.Substring(0,1)+$Phase.Substring(1).ToLower()]='MEASURED'
}
try {
 $connection.Open()
 $before=Snapshot-Indexes
 $before | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $output 'indexes-before.json')
 Measure-Phase 'BEFORE'
 if($OwnerIndexScript) {
  $resolved=(Resolve-Path -LiteralPath $OwnerIndexScript).Path
  $ownerText=(Get-Content -LiteralPath $resolved -Raw -Encoding UTF8).Replace('FreshVendDB',$Database)
  $summary.OwnerIndexScript=$resolved; $summary.OwnerIndexSHA256=(Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash
  foreach($batch in [regex]::Split($ownerText,'(?im)^\s*GO\s*$')) {
   if($batch.Trim()) { $cmd=$connection.CreateCommand(); $cmd.CommandText=$batch; [void]$cmd.ExecuteNonQuery() }
  }
  $after=Snapshot-Indexes
  $after | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $output 'indexes-after.json')
  if(($before | ConvertTo-Json -Depth 6 -Compress) -eq ($after | ConvertTo-Json -Depth 6 -Compress)) { $summary.Reason='Index metadata không đổi; không gán nhãn AFTER giả.' }
  else { Measure-Phase 'AFTER'; $summary.Reason='Owner index script đã áp dụng; số liệu cần đánh giá, không mặc định cải thiện.' }
 }
} catch {
 $summary.Before=$(if($_.Exception.Message -match 'BLOCKED'){'BLOCKED'}else{'FAIL'})
 $summary.Reason=$_.Exception.Message
 Write-Output "$($summary.Before): $($summary.Reason)"
} finally {
 if($connection.State -eq 'Open') { $connection.Close() }
 $samples.ToArray() | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $output 'samples.json')
 $messages.ToArray() | Set-Content -Encoding UTF8 (Join-Path $output 'statistics-time-io.txt')
 $summary.PlanCount=$plans.Count
 $summary | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $output 'summary.json')
 Set-Content -Encoding UTF8 (Join-Path $repoRoot '.local-test/perf/latest.txt') $output
 Write-Output "Performance artifacts: $output"
}
if($summary.Before -ne 'MEASURED' -or $summary.After -ne 'MEASURED' -or $ControlOnly) { exit 2 }
