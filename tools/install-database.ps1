param([string]$Server='localhost',[string]$Database='FreshVendDB',
 [ValidateSet('None','Small','Large')][string]$Seed='None')
$ErrorActionPreference='Stop'
try {
 if($Database -notmatch '^[A-Za-z][A-Za-z0-9_]{0,100}$'){throw 'Invalid database name'}
 if(-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)){throw 'Install Microsoft sqlcmd first'}
 $root=Split-Path $PSScriptRoot -Parent
 $run=Join-Path $root ('.local-test/install/'+$Database+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
 New-Item -ItemType Directory -Force $run | Out-Null
 $files=@('00_database','01_schemas','02_tables_audit','02_tables_auth','02_tables_inventory',
 '02_tables_iot','02_tables_report','02_tables_sales','03_foreign_keys','10_procs_auth',
 '11_procs_inventory','12_procs_sales','13_procs_iot','14_procs_report','20_objects_auth',
 '21_objects_inventory','22_objects_sales','23_objects_iot','24_objects_report','30_index_inventory','40_security')
 # Never silently skip mandatory files. Seeds are explicit because they add demo business data.
 if($Seed -ne 'None'){$files+='80_seed_small'}
 if($Seed -eq 'Large'){$files+='81_seed_large'}
 $files+='50_backup'
 foreach($name in $files){if(-not(Test-Path (Join-Path $root "sql/$name.sql"))){throw "Missing sql/$name.sql"}}
 foreach($name in $files){
  Write-Output "RUN sql/$name.sql"
  $staged=Join-Path $run "$name.sql"
  $source=(Get-Content (Join-Path $root "sql/$name.sql") -Raw -Encoding UTF8).Replace('FreshVendDB',$Database)
  [IO.File]::WriteAllText($staged,$source,(New-Object Text.UTF8Encoding($true)))
  & sqlcmd -S $Server -E -C -I -b -V 11 -f 65001 -i $staged -o "$staged.log" -u
  if($LASTEXITCODE -ne 0){Get-Content "$staged.log" -Encoding Unicode -Tail 18;throw "FAILED sql/$name.sql; log: $staged.log"}
 }
 @{Database=$Database;Server=$Server;Seed=$Seed;CompletedAt=(Get-Date).ToString('o');Files=$files;Status='PASS'} |
  ConvertTo-Json -Depth 4 | Set-Content (Join-Path $run 'result.json') -Encoding UTF8
 Write-Output "HOAN TAT: $Database; logs: $run"
 exit 0
} catch {Write-Error $_ -ErrorAction Continue;exit 1}
