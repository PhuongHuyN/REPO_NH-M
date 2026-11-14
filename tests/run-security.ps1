param([string]$Server='.\SQLEXPRESS')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$database='FreshVend_S230_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$out=Join-Path $root ".local-test/security/$database"
New-Item -ItemType Directory -Force $out | Out-Null
& (Join-Path $root '99_run_all.bat') $Server $database
if($LASTEXITCODE -ne 0){throw 'Clean installation failed'}
foreach($name in @('tests_auth.sql','demo_security.sql')){
 $source=(Get-Content (Join-Path $PSScriptRoot $name) -Raw -Encoding UTF8).Replace('FreshVendDB',$database)
 $file=Join-Path $out $name
 [IO.File]::WriteAllText($file,$source,(New-Object Text.UTF8Encoding($true)))
 & sqlcmd -S $Server -E -C -I -b -d $database -i $file -o "$file.log" -u
 if($LASTEXITCODE -ne 0){Get-Content "$file.log" -Encoding Unicode -Tail 8;throw "$name failed"}
 Write-Output "PASS $name; log: $file.log"
}
@{Server=$Server;Database=$database;CompletedAt=(Get-Date).ToString('o');Auth='18/18 PASS';StopAt='PASS';Logs=$out} |
 ConvertTo-Json | Set-Content (Join-Path $out 'result.json') -Encoding UTF8
Write-Output "Security acceptance PASS; retained QA databases and logs: $out"
