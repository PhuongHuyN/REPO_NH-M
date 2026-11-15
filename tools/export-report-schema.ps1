param([string]$Server='.\SQLEXPRESS',[Parameter(Mandatory=$true)][string]$Database)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$out=Join-Path $root 'docs/evidence/SCRUM-240'
New-Item -ItemType Directory -Force $out | Out-Null
$connection=New-Object System.Data.SqlClient.SqlConnection("Server=$Server;Database=$Database;Integrated Security=True;TrustServerCertificate=True;Encrypt=False")
try {
 $connection.Open()
 $cmd=$connection.CreateCommand()
 $cmd.CommandText=@'
SELECT s.name SchemaName,t.name TableName,c.name ColumnName,ty.name TypeName,c.max_length,c.precision,c.scale,
 c.is_nullable,c.is_identity,c.is_computed,c.column_id,t.temporal_type_desc,
 CASE WHEN EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.indexes i ON i.object_id=ic.object_id AND i.index_id=ic.index_id
 WHERE i.is_primary_key=1 AND ic.object_id=c.object_id AND ic.column_id=c.column_id) THEN 1 ELSE 0 END IsPrimaryKey,
 dc.definition DefaultValue
FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN sys.columns c ON c.object_id=t.object_id
JOIN sys.types ty ON ty.user_type_id=c.user_type_id LEFT JOIN sys.default_constraints dc ON dc.object_id=c.default_object_id
WHERE s.name IN('auth','audit','inventory','sales','iot','report') ORDER BY s.name,t.name,c.column_id;
SELECT fk.name ForeignKey,OBJECT_SCHEMA_NAME(fk.parent_object_id) ChildSchema,OBJECT_NAME(fk.parent_object_id) ChildTable,
 COL_NAME(fkc.parent_object_id,fkc.parent_column_id) ChildColumn,OBJECT_SCHEMA_NAME(fk.referenced_object_id) ParentSchema,
 OBJECT_NAME(fk.referenced_object_id) ParentTable,COL_NAME(fkc.referenced_object_id,fkc.referenced_column_id) ParentColumn,
 fk.is_disabled,fk.is_not_trusted
FROM sys.foreign_keys fk JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id=fk.object_id ORDER BY ForeignKey,fkc.constraint_column_id;
'@
 $adapter=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$data=New-Object System.Data.DataSet;[void]$adapter.Fill($data)
 function Rows($table){@($table.Rows | ForEach-Object {$row=[ordered]@{};foreach($col in $table.Columns){$row[$col.ColumnName]=$(if($_[$col] -is [DBNull]){$null}else{$_[$col]})};$row})}
 @{CapturedAt=(Get-Date).ToString('o');Server=$Server;Database=$Database;Columns=(Rows $data.Tables[0]);ForeignKeys=(Rows $data.Tables[1])} |
  ConvertTo-Json -Depth 8 | Set-Content (Join-Path $out 'schema.json') -Encoding UTF8
 Write-Output "Schema snapshot saved: $out/schema.json"
} finally {$connection.Dispose()}
