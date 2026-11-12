param([string]$Server='.\SQLEXPRESS')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$db='FreshVend_FK201_Test_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$out=Join-Path $root ".local-test/fk201/$db"
New-Item -ItemType Directory -Force $out | Out-Null
$results=[Collections.Generic.List[object]]::new()
foreach($name in @('00_database.sql','01_schemas.sql','02_tables_auth.sql','02_tables_audit.sql','02_tables_inventory.sql','02_tables_iot.sql','02_tables_report.sql','02_tables_sales.sql','03_foreign_keys.sql')) {
 $text=(Get-Content (Join-Path $root "sql/$name") -Raw -Encoding UTF8).Replace('FreshVendDB',$db)
 $file=Join-Path $out $name; [IO.File]::WriteAllText($file,$text,(New-Object Text.UTF8Encoding($true)))
 & sqlcmd -S $Server -E -C -I -b -i $file -o "$file.log" -u
 if($LASTEXITCODE -ne 0){ Get-Content "$file.log" -Encoding Unicode -Tail 12; throw "$name failed" }
 Write-Output "PASS $name"
}
$conn=New-Object System.Data.SqlClient.SqlConnection("Server=$Server;Database=$db;Integrated Security=True;TrustServerCertificate=True;Encrypt=False")
$conn.Open()
function Query([string]$Sql,[int]$Expected=0) {
 $cmd=$conn.CreateCommand(); $cmd.CommandText="SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF; $Sql"
 try { [void]$cmd.ExecuteNonQuery(); if($Expected){throw "Expected error $Expected was not raised"} }
 catch { $base=$_.Exception.GetBaseException(); if(-not $Expected -or $base.Number -ne $Expected){throw}; $results.Add(@{Expected=$Expected;Actual=[int]$base.Number;Status='PASS'}) }
}
$fk=[regex]::Replace((Get-Content (Join-Path $out '03_foreign_keys.sql') -Raw -Encoding UTF8),'(?im)^\s*GO\s*$','')
try {
 Query "DECLARE @before INT=(SELECT COUNT(*) FROM sys.foreign_keys); EXEC sys.sp_set_session_context @key=N'fk_count',@value=@before;"
 Query $fk
 Query $fk
 Query "IF (SELECT COUNT(*) FROM sys.foreign_keys)<>CONVERT(INT,SESSION_CONTEXT(N'fk_count')) THROW 50092,N'Duplicate FK on rerun',1; IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE is_disabled=1 OR is_not_trusted=1) THROW 50092,N'Untrusted FK',1;"
 $results.Add(@{Check='clean install and rerun x2';Status='PASS'})
 Query "INSERT auth.[User](Username,PasswordHash,FullName,Email) VALUES(N'qa_fk',N'NOT_A_LOGIN',N'QA',N'qa_fk@fixture.local'); INSERT iot.Machines(Serial,MachineName) VALUES(N'QA-FK-M',N'QA'); INSERT inventory.Category(CategoryName) VALUES(N'QA FK'); INSERT inventory.Product(SKU,ProductName,CategoryId,UnitPrice) SELECT N'QA-FK-P',N'QA',CategoryId,10 FROM inventory.Category WHERE CategoryName=N'QA FK';"
 $u="(SELECT UserId FROM auth.[User] WHERE Username=N'qa_fk')"
 $m="(SELECT MachineId FROM iot.Machines WHERE Serial=N'QA-FK-M')"
 $p="(SELECT ProductId FROM inventory.Product WHERE SKU=N'QA-FK-P')"
 foreach($sql in @(
 "INSERT report.ExportLogs(UserId,ReportName) VALUES(-1,N'QA')",
 "INSERT inventory.RestockEvent(MachineId,UserId) VALUES($m,-1)",
 "INSERT inventory.RestockEvent(MachineId,UserId) VALUES(-1,$u)",
 "INSERT report.DailySalesSummary(SummaryDate,MachineId,ProductId) VALUES('20261112',$m,-1)",
 "INSERT report.DailySalesSummary(SummaryDate,MachineId,ProductId) VALUES('20261112',-1,$p)",
 "INSERT auth.UserMachine(UserId,MachineId) VALUES($u,-1)",
 "INSERT iot.Alerts(MachineId,AlertType,AckBy) VALUES($m,N'QA',-1)",
 "INSERT audit.ChangeLog(TableName,RecordId,Action,UserId) VALUES(N'QA',N'1',N'INSERT',-1)"
 )) { Query $sql 547 }
 Query "INSERT inventory.Slot(MachineId,SlotCode,ProductId,Capacity,CurrentStock) VALUES($m,N'QA',$p,5,0); INSERT report.ExportLogs(UserId,ReportName) VALUES($u,N'QA'); INSERT inventory.RestockEvent(MachineId,UserId) VALUES($m,$u); INSERT auth.UserMachine(UserId,MachineId) VALUES($u,$m);"
 Query 'ALTER TABLE report.ExportLogs NOCHECK CONSTRAINT FK_ExportLogs_UserId;'
 Query $fk
 Query "IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_ExportLogs_UserId' AND (is_disabled=1 OR is_not_trusted=1)) THROW 50092,N'FK not retrusted',1;"
 $results.Add(@{Check='valid canonical rows and re-trust disabled FK';Status='PASS'})
 Query "DECLARE @id INT=$m; SET IDENTITY_INSERT inventory.Machine ON; INSERT inventory.Machine(MachineId,MachineCode,MachineName) VALUES(@id,N'OTHER-MACHINE',N'Conflict'); SET IDENTITY_INSERT inventory.Machine OFF;"
 Query $fk 50090
 Query "DELETE inventory.Machine WHERE MachineCode=N'OTHER-MACHINE';"
 Query $fk
 $results.Add(@{Check='conflicting legacy machine IDs rejected without remapping';Status='PASS'})
 Query "ALTER TABLE report.ExportLogs NOCHECK CONSTRAINT FK_ExportLogs_UserId; INSERT report.ExportLogs(UserId,ReportName) VALUES(-1,N'ORPHAN');"
 Query $fk 547
 Query "DELETE report.ExportLogs WHERE UserId=-1;"
 Query $fk
 $results.Add(@{Check='orphan historical data blocks trust validation; clean retry succeeds';Status='PASS'})
 # Missing mandatory dependency must fail before dropping/rebinding the other FKs.
 Query "EXEC sp_rename N'audit.ChangeLog',N'ChangeLog_ReviewHidden';"
 Query $fk 50090
 Query "EXEC sp_rename N'audit.ChangeLog_ReviewHidden',N'ChangeLog';"
 Query $fk
 $results.Add(@{Check='missing prerequisite rejected; recovery rerun succeeds';Status='PASS'})
 Write-Output 'PASS: fresh install, idempotence, orphan rejection, canonical machine mapping, trust and recovery'
} finally {
 $conn.Close()
 @{Database=$db;Results=$results.ToArray()} | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $out 'results.json')
 Set-Content -Encoding UTF8 (Join-Path $root '.local-test/fk201/latest.txt') $out
}
