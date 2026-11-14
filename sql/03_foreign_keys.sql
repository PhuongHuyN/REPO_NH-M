-- SCRUM-201: cross-schema FK installation, transactional and rerunnable.
-- Requires ALL 02_tables files. Missing mandatory tables are errors, never skipped.
-- Machine IDs must already describe the same physical machine in both schemas.
USE FreshVendDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @FK TABLE(Id INT IDENTITY,Name SYSNAME,Child NVARCHAR(256),Col SYSNAME,Parent NVARCHAR(256),ParentCol SYSNAME);
INSERT @FK(Name,Child,Col,Parent,ParentCol) VALUES
(N'FK_inventory_StockBatch_auth_User',N'inventory.StockBatch',N'CreatedBy',N'auth.User',N'UserId'),
(N'FK_inventory_StockMovement_auth_User',N'inventory.StockMovement',N'CreatedBy',N'auth.User',N'UserId'),
(N'FK_inventory_Slot_Machine',N'inventory.Slot',N'MachineId',N'iot.Machines',N'MachineId'),
(N'FK_RestockEvent_Machine',N'inventory.RestockEvent',N'MachineId',N'iot.Machines',N'MachineId'),
(N'FK_RestockEvent_User',N'inventory.RestockEvent',N'UserId',N'auth.User',N'UserId'),
(N'FK_sales_Order_iot_Machines',N'sales.Order',N'MachineId',N'iot.Machines',N'MachineId'),
(N'FK_sales_Order_auth_User',N'sales.Order',N'CustomerId',N'auth.User',N'UserId'),
(N'FK_sales_OrderItem_inventory_Slot',N'sales.OrderItem',N'SlotId',N'inventory.Slot',N'SlotId'),
(N'FK_sales_OrderItem_inventory_Product',N'sales.OrderItem',N'ProductId',N'inventory.Product',N'ProductId'),
(N'FK_OrderItem_StockBatch',N'sales.OrderItem',N'BatchId',N'inventory.StockBatch',N'BatchId'),
(N'FK_OrderItem_SlotStock',N'sales.OrderItem',N'StockId',N'inventory.SlotStock',N'StockId'),
(N'FK_sales_Refund_auth_User',N'sales.Refund',N'ProcessedBy',N'auth.User',N'UserId'),
(N'FK_Alerts_AckBy',N'iot.Alerts',N'AckBy',N'auth.User',N'UserId'),
(N'FK_audit_AuditLog_auth_User',N'audit.AuditLog',N'UserId',N'auth.User',N'UserId'),
(N'FK_audit_ChangeLog_auth_User',N'audit.ChangeLog',N'UserId',N'auth.User',N'UserId'),
(N'FK_DailySalesSummary_MachineId',N'report.DailySalesSummary',N'MachineId',N'iot.Machines',N'MachineId'),
(N'FK_DailySalesSummary_ProductId',N'report.DailySalesSummary',N'ProductId',N'inventory.Product',N'ProductId'),
(N'FK_ExportLogs_UserId',N'report.ExportLogs',N'UserId',N'auth.User',N'UserId'),
(N'FK_UserMachine_MachineId',N'auth.UserMachine',N'MachineId',N'iot.Machines',N'MachineId');
DECLARE @i INT=1,@max INT=(SELECT COUNT(*) FROM @FK),@name SYSNAME,@child NVARCHAR(256),@col SYSNAME,@parent NVARCHAR(256),@pc SYSNAME,
 @sql NVARCHAR(MAX),@existing SYSNAME,@message NVARCHAR(2048),@id INT,@ref INT;
BEGIN TRY
 BEGIN TRAN;
 -- Preflight every table and column before altering any constraint.
 WHILE @i<=@max
 BEGIN
  SELECT @child=Child,@col=Col,@parent=Parent,@pc=ParentCol FROM @FK WHERE Id=@i;
  IF OBJECT_ID(@child,N'U') IS NULL OR OBJECT_ID(@parent,N'U') IS NULL OR COL_LENGTH(@child,@col) IS NULL OR COL_LENGTH(@parent,@pc) IS NULL
  BEGIN
   SET @message=N'FK prerequisite missing: '+@child+N'.'+@col+N' -> '+@parent+N'.'+@pc+N'. Run all 02_tables scripts first.';
   THROW 50090,@message,1;
  END;
  IF @col=N'MachineId'
  BEGIN
   SET @sql=N'IF EXISTS(SELECT 1 FROM '+QUOTENAME(PARSENAME(@child,2))+N'.'+QUOTENAME(PARSENAME(@child,1))+N' c LEFT JOIN iot.Machines m ON m.MachineId=c.MachineId WHERE m.MachineId IS NULL) THROW 50090,N''Unmapped MachineId: complete QD-1 migration first.'',1;';
   EXEC sys.sp_executesql @sql;
   IF OBJECT_ID(N'inventory.Machine',N'U') IS NOT NULL
   BEGIN
    SET @sql=N'IF EXISTS(SELECT 1 FROM '+QUOTENAME(PARSENAME(@child,2))+N'.'+QUOTENAME(PARSENAME(@child,1))+N' c JOIN inventory.Machine old ON old.MachineId=c.MachineId JOIN iot.Machines m ON m.MachineId=c.MachineId WHERE old.MachineCode<>m.Serial) THROW 50090,N''Conflicting machine identities: migrate data before installing FK.'',1;';
    EXEC sys.sp_executesql @sql;
   END;
  END;
  SET @i+=1;
 END;
 SET @i=1;
 WHILE @i<=@max
 BEGIN
  SELECT @name=Name,@child=Child,@col=Col,@parent=Parent,@pc=ParentCol FROM @FK WHERE Id=@i;
  SET @id=OBJECT_ID(@child); SET @ref=OBJECT_ID(@parent);
  -- Remove only obsolete single-column machine FK to the legacy physical table.
  IF @parent=N'iot.Machines'
  BEGIN
   SET @sql=N'';
   SELECT @sql=@sql+N'ALTER TABLE '+QUOTENAME(PARSENAME(@child,2))+N'.'+QUOTENAME(PARSENAME(@child,1))+N' DROP CONSTRAINT '+QUOTENAME(f.name)+N';'
   FROM sys.foreign_keys f JOIN sys.foreign_key_columns k ON k.constraint_object_id=f.object_id
   WHERE f.parent_object_id=@id AND f.referenced_object_id=OBJECT_ID(N'inventory.Machine',N'U')
    AND COL_NAME(k.parent_object_id,k.parent_column_id)=@col
    AND (SELECT COUNT(*) FROM sys.foreign_key_columns x WHERE x.constraint_object_id=f.object_id)=1;
   IF @sql<>N'' EXEC sys.sp_executesql @sql;
  END;
  SET @existing=NULL;
  SELECT @existing=f.name FROM sys.foreign_keys f JOIN sys.foreign_key_columns k ON k.constraint_object_id=f.object_id
  WHERE f.parent_object_id=@id AND f.referenced_object_id=@ref
   AND COL_NAME(k.parent_object_id,k.parent_column_id)=@col AND COL_NAME(k.referenced_object_id,k.referenced_column_id)=@pc
   AND (SELECT COUNT(*) FROM sys.foreign_key_columns x WHERE x.constraint_object_id=f.object_id)=1;
  IF @existing IS NULL
  BEGIN
   IF EXISTS(SELECT 1 FROM sys.objects WHERE schema_id=SCHEMA_ID(PARSENAME(@child,2)) AND name=@name)
    THROW 50091,N'Constraint name already exists with another definition; manual inspection required.',1;
   SET @sql=N'ALTER TABLE '+QUOTENAME(PARSENAME(@child,2))+N'.'+QUOTENAME(PARSENAME(@child,1))+N' WITH CHECK ADD CONSTRAINT '+QUOTENAME(@name)+N' FOREIGN KEY('+QUOTENAME(@col)+N') REFERENCES '+QUOTENAME(PARSENAME(@parent,2))+N'.'+QUOTENAME(PARSENAME(@parent,1))+N'('+QUOTENAME(@pc)+N');';
   EXEC sys.sp_executesql @sql;
   SET @existing=@name;
  END;
  SET @sql=N'ALTER TABLE '+QUOTENAME(PARSENAME(@child,2))+N'.'+QUOTENAME(PARSENAME(@child,1))+N' WITH CHECK CHECK CONSTRAINT '+QUOTENAME(@existing)+N';';
  EXEC sys.sp_executesql @sql;
  SET @i+=1;
 END;
 COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
SELECT f.name,OBJECT_SCHEMA_NAME(f.parent_object_id)+N'.'+OBJECT_NAME(f.parent_object_id) Child,
 OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id) Parent,f.is_disabled,f.is_not_trusted
FROM sys.foreign_keys f JOIN sys.foreign_key_columns k ON k.constraint_object_id=f.object_id
JOIN @FK d ON f.parent_object_id=OBJECT_ID(d.Child) AND f.referenced_object_id=OBJECT_ID(d.Parent)
 AND COL_NAME(k.parent_object_id,k.parent_column_id)=d.Col AND COL_NAME(k.referenced_object_id,k.referenced_column_id)=d.ParentCol
ORDER BY Child,f.name;
GO
