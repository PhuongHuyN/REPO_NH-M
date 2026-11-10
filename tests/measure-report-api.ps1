param([string]$BaseUrl='http://127.0.0.1:3000',[ValidateRange(100,100000)][int]$Requests=100)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$out=Join-Path $root ('.local-test/api-perf/'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force $out | Out-Null
$rows=[Collections.Generic.List[object]]::new(); $results=[Collections.Generic.List[object]]::new()
$status='BLOCKED'; $reason='Not started'
try {
 $health=Invoke-RestMethod "$BaseUrl/api/health" -TimeoutSec 10
 if($health.db.mode -ne 'sqlserver') { throw 'BLOCKED: demo timings are not SQL Server evidence.' }
 $token=[Environment]::GetEnvironmentVariable('FRESHVEND_QA_ADMIN_TOKEN','Process')
 if(-not $token) { throw 'BLOCKED: a real Admin token is required in the process environment.' }
 $headers=@{Authorization="Bearer $token"}
 foreach($route in @('/api/reports/kpi','/api/reports/peak-hours?from=2026-08-06&to=2026-11-03','/api/reports/revenue-growth?year=2026')) {
  [void](Invoke-WebRequest "$BaseUrl$route" -Headers $headers -UseBasicParsing -TimeoutSec 15)
  for($i=1;$i -le $Requests;$i++) {
   $sample=@{Route=$route;Iteration=$i;HttpStatus=0;Success=$false;ElapsedMs=0}
   $time=Measure-Command {
    try { $r=Invoke-WebRequest "$BaseUrl$route" -Headers $headers -UseBasicParsing -TimeoutSec 15; $sample.HttpStatus=[int]$r.StatusCode; $sample.Success=$r.StatusCode -ge 200 -and $r.StatusCode -lt 300 }
    catch { if($_.Exception.Response) { $sample.HttpStatus=[int]$_.Exception.Response.StatusCode } }
   }
   $sample.ElapsedMs=$time.TotalMilliseconds; $rows.Add($sample)
  }
  $selected=@($rows | Where-Object Route -eq $route); $sorted=@($selected.ElapsedMs | Sort-Object)
  $p95=$sorted[[Math]::Ceiling(0.95*$sorted.Count)-1]; $errors=@($selected | Where-Object Success -eq $false).Count
  $results.Add(@{Route=$route;Samples=$sorted.Count;P95Ms=$p95;Errors=$errors;Passed=($p95 -le 500 -and $errors -eq 0)})
 }
 $status=$(if(@($results | Where-Object Passed -eq $false).Count){'FAIL'}else{'PASS'})
 $reason='All timed samples retained, including failures; nearest-rank p95 evaluated per route.'
} catch { $reason=$_.Exception.Message }
finally {
 $rows.ToArray() | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $out 'samples.json')
 @{Status=$status;Reason=$reason;Routes=$results.ToArray()} | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $out 'summary.json')
 Write-Output "$status $reason"
}
if($status -ne 'PASS') { exit 2 }
