-- QA-only bridge for the existing inventory seed. This is NOT the QD-1 production migration.
USE FreshVendDB;
GO
IF DB_NAME() NOT LIKE N'FreshVend[_]QA%' THROW 50491,N'QA fixtures only.',1;
IF EXISTS(SELECT 1 FROM iot.Machines) OR EXISTS(SELECT 1 FROM inventory.Machine)
 THROW 50491,N'Fixture requires a clean installation with no machines.',1;
SET IDENTITY_INSERT iot.Machines ON;
INSERT iot.Machines(MachineId,Serial,MachineName,Status)
VALUES(1,N'VM-BK-01',N'QA BK1',N'ACTIVE'),(2,N'VM-BK-02',N'QA BK2',N'ACTIVE'),
(3,N'VM-VT-01',N'QA VT1',N'ACTIVE'),(4,N'VM-VT-02',N'QA VT2',N'ACTIVE'),(5,N'VM-CM-01',N'QA CM1',N'ACTIVE');
SET IDENTITY_INSERT iot.Machines OFF;
INSERT iot.MachineThresholds(MachineId) SELECT MachineId FROM iot.Machines;
GO
