param([string]$Server='.\SQLEXPRESS',[Parameter(Mandatory=$true)][ValidatePattern('^FreshVend[A-Za-z0-9_]*$')][string]$Database,[string]$BaseUrl='http://127.0.0.1:3000')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$out=Join-Path $root ('.local-test/integration/'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force $out | Out-Null
$missing=[Collections.Generic.List[string]]::new()
$connection=New-Object System.Data.SqlClient.SqlConnection("Server=$Server;Database=$Database;Integrated Security=True;TrustServerCertificate=True;Encrypt=False")
try {
 $connection.Open()
 $cmd=$connection.CreateCommand()
 $cmd.CommandText="SELECT Name FROM (VALUES(N'auth.sp_Login'),(N'auth.sp_AssignMachine'),(N'inventory.sp_Restock'),(N'inventory.sp_RemoveExpired'),(N'iot.vw_MachineHealth'),(N'iot.vw_OpenAlerts'),(N'sales.vw_DispenseQueue'),(N'inventory.vw_StockStatus')) x(Name) WHERE OBJECT_ID(Name) IS NULL"
 $reader=$cmd.ExecuteReader(); while($reader.Read()) { $missing.Add([string]$reader.GetValue(0)) }; $reader.Close()
 $cmd.CommandText="SELECT COUNT(*) FROM report.SeedRuns WHERE Profile=N'SMALL'"
 if([int]$cmd.ExecuteScalar() -ne 1) { $missing.Add('Procedure-driven SMALL seed has not completed') }
 $cmd.CommandText="SELECT COUNT(*) FROM sys.security_policies WHERE is_enabled=1"
 if([int]$cmd.ExecuteScalar() -eq 0) { $missing.Add('RLS/security owner setup is not ready') }
} catch { $missing.Add('SQL preflight: '+$_.Exception.Message) }
finally { if($connection.State -eq 'Open') { $connection.Close() } }
try {
 $health=Invoke-RestMethod "$BaseUrl/api/health" -TimeoutSec 3
 if($health.db.mode -ne 'sqlserver' -or $health.db.db -ne $Database) { $missing.Add('API is demo or targets a different database') }
} catch { $missing.Add('API with SQL Server is not reachable') }
$names=@('Operator login sees exactly three assigned machines','Add batch and restock','Kiosk buys two items and receives VietQR','Payment callback sets PAID','Simulator dispenses and order DISPENSED','Stock decremented from FIFO lot','Machine 3 overheat creates alert and pause','Machine 1 jams and is REFUNDED','Admin report contains new order','Operator report request returns 403')
$steps=for($i=0;$i -lt $names.Count;$i++) { @{Step=$i+1;Name=$names[$i];Status=$(if($missing.Count){'BLOCKED'}else{'NOT RUN'});Evidence=$null;Actual=$null} }
@{Database=$Database;BaseUrl=$BaseUrl;Prerequisites=$missing.ToArray();Steps=@($steps);SqlE2ePassed=$false;RunAt=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json -Depth 7 | Set-Content -Encoding UTF8 (Join-Path $out 'manifest.json')
Set-Content -Encoding UTF8 (Join-Path $root '.local-test/integration/latest.txt') $out
Write-Output "Integration preflight: $($missing.Count) missing prerequisites. No step is marked PASS. Evidence: $out"
# A successful preflight is not successful execution of the ten-step scenario.
if($missing.Count) { exit 2 }
