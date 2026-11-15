# Phụ lục Báo cáo — Data Dictionary từ CSDL thật

Snapshot 2026-11-15T01:02:58.1366268+07:00; CSDL `FreshVend_QA239_20261115_005521`. Sinh từ sys.tables/columns/types/indexes/foreign_keys; không phải tài liệu đã được Toàn duyệt. Giữ cả bảng máy legacy và bảng temporal history đang tồn tại, không vẽ schema đích thay schema thực.

## audit.AuditLog

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| AuditId | bigint | Không | 1 | 1 | 0 |  |
| UserId | int | Có | 0 | 0 | 0 |  |
| Action | nvarchar(50) | Không | 0 | 0 | 0 |  |
| ObjectName | nvarchar(128) | Có | 0 | 0 | 0 |  |
| Detail | nvarchar(max) | Có | 0 | 0 | 0 |  |
| IpAddress | nvarchar(45) | Có | 0 | 0 | 0 |  |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## audit.ChangeLog

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| ChangeId | bigint | Không | 1 | 1 | 0 |  |
| TableName | nvarchar(128) | Không | 0 | 0 | 0 |  |
| RecordId | nvarchar(50) | Không | 0 | 0 | 0 |  |
| Action | nvarchar(10) | Không | 0 | 0 | 0 |  |
| OldData | nvarchar(max) | Có | 0 | 0 | 0 |  |
| NewData | nvarchar(max) | Có | 0 | 0 | 0 |  |
| UserId | int | Có | 0 | 0 | 0 |  |
| ChangedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## auth.LoginHistory

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| LoginId | bigint | Không | 1 | 1 | 0 |  |
| UserId | int | Có | 0 | 0 | 0 |  |
| LoginAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| IpAddress | nvarchar(45) | Có | 0 | 0 | 0 |  |
| UserAgent | nvarchar(500) | Có | 0 | 0 | 0 |  |
| IsSuccess | bit | Không | 0 | 0 | 0 |  |
| FailReason | nvarchar(200) | Có | 0 | 0 | 0 |  |
| Username | nvarchar(50) | Có | 0 | 0 | 0 |  |

## auth.Permission

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| PermissionId | int | Không | 1 | 1 | 0 |  |
| PermissionName | nvarchar(100) | Không | 0 | 0 | 0 |  |
| Module | nvarchar(50) | Không | 0 | 0 | 0 |  |
| Description | nvarchar(250) | Có | 0 | 0 | 0 |  |

## auth.RefreshToken

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| TokenId | int | Không | 1 | 1 | 0 |  |
| UserId | int | Không | 0 | 0 | 0 |  |
| Token | nvarchar(500) | Không | 0 | 0 | 0 |  |
| ExpiresAt | datetime2(0) | Không | 0 | 0 | 0 |  |
| IsRevoked | bit | Không | 0 | 0 | 0 | `((0))` |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| RevokedAt | datetime2(0) | Có | 0 | 0 | 0 |  |
| IpAddress | nvarchar(45) | Có | 0 | 0 | 0 |  |
| UserAgent | nvarchar(500) | Có | 0 | 0 | 0 |  |

## auth.Role

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| RoleId | int | Không | 1 | 1 | 0 |  |
| RoleName | nvarchar(50) | Không | 0 | 0 | 0 |  |
| Description | nvarchar(250) | Có | 0 | 0 | 0 |  |
| IsActive | bit | Không | 0 | 0 | 0 | `((1))` |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## auth.RolePermission

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| RolePermissionId | int | Không | 1 | 1 | 0 |  |
| RoleId | int | Không | 0 | 0 | 0 |  |
| PermissionId | int | Không | 0 | 0 | 0 |  |
| GrantedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## auth.User

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| UserId | int | Không | 1 | 1 | 0 |  |
| Username | nvarchar(50) | Không | 0 | 0 | 0 |  |
| PasswordHash | nvarchar(256) | Không | 0 | 0 | 0 |  |
| FullName | nvarchar(100) | Không | 0 | 0 | 0 |  |
| Email | nvarchar(150) | Có | 0 | 0 | 0 |  |
| PhoneNumber | nvarchar(15) | Có | 0 | 0 | 0 |  |
| AvatarUrl | nvarchar(500) | Có | 0 | 0 | 0 |  |
| IsActive | bit | Không | 0 | 0 | 0 | `((1))` |
| IsDeleted | bit | Không | 0 | 0 | 0 | `((0))` |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| UpdatedAt | datetime2(0) | Có | 0 | 0 | 0 |  |
| Salt | uniqueidentifier | Không | 0 | 0 | 0 | `(newid())` |
| FailedLogins | tinyint | Không | 0 | 0 | 0 | `((0))` |
| LastLoginAt | datetime2(0) | Có | 0 | 0 | 0 |  |

## auth.UserMachine

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| UserId | int | Không | 1 | 0 | 0 |  |
| MachineId | int | Không | 1 | 0 | 0 |  |
| AssignedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## auth.UserRole

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| UserRoleId | int | Không | 1 | 1 | 0 |  |
| UserId | int | Không | 0 | 0 | 0 |  |
| RoleId | int | Không | 0 | 0 | 0 |  |
| AssignedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| AssignedBy | int | Có | 0 | 0 | 0 |  |

## inventory.Category

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| CategoryId | int | Không | 1 | 1 | 0 |  |
| CategoryName | nvarchar(100) | Không | 0 | 0 | 0 |  |
| Description | nvarchar(300) | Có | 0 | 0 | 0 |  |
| ParentId | int | Có | 0 | 0 | 0 |  |
| DisplayOrder | smallint | Không | 0 | 0 | 0 | `((0))` |
| IsActive | bit | Không | 0 | 0 | 0 | `((1))` |

## inventory.Machine

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| MachineId | int | Không | 1 | 1 | 0 |  |
| MachineCode | nvarchar(20) | Không | 0 | 0 | 0 |  |
| MachineName | nvarchar(100) | Không | 0 | 0 | 0 |  |
| Location | nvarchar(200) | Có | 0 | 0 | 0 |  |
| Latitude | decimal(10,7) | Có | 0 | 0 | 0 |  |
| Longitude | decimal(10,7) | Có | 0 | 0 | 0 |  |
| Status | nvarchar(20) | Không | 0 | 0 | 0 | `(N'offline')` |
| InstallDate | date | Có | 0 | 0 | 0 |  |
| LastServiceDate | date | Có | 0 | 0 | 0 |  |
| IsActive | bit | Không | 0 | 0 | 0 | `((1))` |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| UpdatedAt | datetime2(0) | Có | 0 | 0 | 0 |  |

## inventory.Product

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| ProductId | int | Không | 1 | 1 | 0 |  |
| SKU | nvarchar(30) | Không | 0 | 0 | 0 |  |
| ProductName | nvarchar(150) | Không | 0 | 0 | 0 |  |
| CategoryId | int | Không | 0 | 0 | 0 |  |
| SupplierId | int | Có | 0 | 0 | 0 |  |
| UnitPrice | decimal(12,2) | Không | 0 | 0 | 0 |  |
| Unit | nvarchar(20) | Không | 0 | 0 | 0 | `(N'kg')` |
| WeightGram | int | Có | 0 | 0 | 0 |  |
| Description | nvarchar(500) | Có | 0 | 0 | 0 |  |
| ImageUrl | nvarchar(500) | Có | 0 | 0 | 0 |  |
| ShelfLifeDays | smallint | Có | 0 | 0 | 0 |  |
| StorageTempMin | decimal(4,1) | Có | 0 | 0 | 0 |  |
| StorageTempMax | decimal(4,1) | Có | 0 | 0 | 0 |  |
| IsActive | bit | Không | 0 | 0 | 0 | `((1))` |
| IsDeleted | bit | Không | 0 | 0 | 0 | `((0))` |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| UpdatedAt | datetime2(0) | Có | 0 | 0 | 0 |  |
| ShelfLifeHours | int | Không | 0 | 0 | 0 | `((24))` |
| ValidFrom | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| ValidTo | datetime2(0) | Không | 0 | 0 | 0 | `(CONVERT([datetime2](0),'9999-12-31 23:59:59'))` |

## inventory.ProductHistory

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| ProductId | int | Không | 0 | 0 | 0 |  |
| SKU | nvarchar(30) | Không | 0 | 0 | 0 |  |
| ProductName | nvarchar(150) | Không | 0 | 0 | 0 |  |
| CategoryId | int | Không | 0 | 0 | 0 |  |
| SupplierId | int | Có | 0 | 0 | 0 |  |
| UnitPrice | decimal(12,2) | Không | 0 | 0 | 0 |  |
| Unit | nvarchar(20) | Không | 0 | 0 | 0 |  |
| WeightGram | int | Có | 0 | 0 | 0 |  |
| Description | nvarchar(500) | Có | 0 | 0 | 0 |  |
| ImageUrl | nvarchar(500) | Có | 0 | 0 | 0 |  |
| ShelfLifeDays | smallint | Có | 0 | 0 | 0 |  |
| StorageTempMin | decimal(4,1) | Có | 0 | 0 | 0 |  |
| StorageTempMax | decimal(4,1) | Có | 0 | 0 | 0 |  |
| IsActive | bit | Không | 0 | 0 | 0 |  |
| IsDeleted | bit | Không | 0 | 0 | 0 |  |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 |  |
| UpdatedAt | datetime2(0) | Có | 0 | 0 | 0 |  |
| ShelfLifeHours | int | Không | 0 | 0 | 0 |  |
| ValidFrom | datetime2(0) | Không | 0 | 0 | 0 |  |
| ValidTo | datetime2(0) | Không | 0 | 0 | 0 |  |

## inventory.RestockEvent

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| RestockId | int | Không | 1 | 1 | 0 |  |
| MachineId | int | Không | 0 | 0 | 0 |  |
| UserId | int | Không | 0 | 0 | 0 |  |
| RestockedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| Note | nvarchar(200) | Có | 0 | 0 | 0 |  |

## inventory.RestockItem

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| RestockItemId | int | Không | 1 | 1 | 0 |  |
| RestockId | int | Không | 0 | 0 | 0 |  |
| SlotId | int | Không | 0 | 0 | 0 |  |
| BatchId | int | Không | 0 | 0 | 0 |  |
| Qty | smallint | Không | 0 | 0 | 0 |  |

## inventory.Slot

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| SlotId | int | Không | 1 | 1 | 0 |  |
| MachineId | int | Không | 0 | 0 | 0 |  |
| SlotCode | nvarchar(10) | Không | 0 | 0 | 0 |  |
| ProductId | int | Có | 0 | 0 | 0 |  |
| Capacity | smallint | Không | 0 | 0 | 0 |  |
| CurrentStock | smallint | Không | 0 | 0 | 0 | `((0))` |
| IsActive | bit | Không | 0 | 0 | 0 | `((1))` |
| UpdatedAt | datetime2(0) | Có | 0 | 0 | 0 |  |

## inventory.SlotStock

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| StockId | bigint | Không | 1 | 1 | 0 |  |
| SlotId | int | Không | 0 | 0 | 0 |  |
| BatchId | int | Không | 0 | 0 | 0 |  |
| Quantity | smallint | Không | 0 | 0 | 0 |  |
| LoadedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## inventory.StockBatch

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| BatchId | int | Không | 1 | 1 | 0 |  |
| ProductId | int | Không | 0 | 0 | 0 |  |
| SupplierId | int | Có | 0 | 0 | 0 |  |
| BatchCode | nvarchar(30) | Không | 0 | 0 | 0 |  |
| Quantity | int | Không | 0 | 0 | 0 |  |
| UnitCost | decimal(12,2) | Không | 0 | 0 | 0 |  |
| ImportDate | date | Không | 0 | 0 | 0 |  |
| ExpiryDate | date | Có | 0 | 0 | 0 |  |
| Note | nvarchar(500) | Có | 0 | 0 | 0 |  |
| CreatedBy | int | Có | 0 | 0 | 0 |  |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| PreparedAt | datetime2(0) | Có | 0 | 0 | 0 | `(sysutcdatetime())` |
| ExpiryAt | datetime2(0) | Có | 0 | 0 | 0 |  |

## inventory.StockMovement

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| MovementId | bigint | Không | 1 | 1 | 0 |  |
| SlotId | int | Không | 0 | 0 | 0 |  |
| BatchId | int | Có | 0 | 0 | 0 |  |
| MovementType | nvarchar(10) | Không | 0 | 0 | 0 |  |
| Quantity | int | Không | 0 | 0 | 0 |  |
| Reason | nvarchar(200) | Có | 0 | 0 | 0 |  |
| CreatedBy | int | Có | 0 | 0 | 0 |  |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## inventory.Supplier

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| SupplierId | int | Không | 1 | 1 | 0 |  |
| SupplierName | nvarchar(150) | Không | 0 | 0 | 0 |  |
| ContactPerson | nvarchar(100) | Có | 0 | 0 | 0 |  |
| PhoneNumber | nvarchar(15) | Có | 0 | 0 | 0 |  |
| Email | nvarchar(150) | Có | 0 | 0 | 0 |  |
| Address | nvarchar(300) | Có | 0 | 0 | 0 |  |
| TaxCode | nvarchar(20) | Có | 0 | 0 | 0 |  |
| IsActive | bit | Không | 0 | 0 | 0 | `((1))` |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| UpdatedAt | datetime2(0) | Có | 0 | 0 | 0 |  |

## iot.Alerts

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| AlertId | int | Không | 1 | 1 | 0 |  |
| MachineId | int | Có | 0 | 0 | 0 |  |
| AlertType | nvarchar(50) | Không | 0 | 0 | 0 |  |
| Severity | nvarchar(20) | Có | 0 | 0 | 0 |  |
| Message | nvarchar(255) | Có | 0 | 0 | 0 |  |
| RefKey | nvarchar(100) | Có | 0 | 0 | 0 |  |
| CreatedAt | datetime2(0) | Có | 0 | 0 | 0 | `(sysdatetime())` |
| AckBy | int | Có | 0 | 0 | 0 |  |
| AckAt | datetime2(0) | Có | 0 | 0 | 0 |  |
| ResolvedAt | datetime2(0) | Có | 0 | 0 | 0 |  |

## iot.Locations

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| LocationId | int | Không | 1 | 1 | 0 |  |
| LocationName | nvarchar(100) | Không | 0 | 0 | 0 |  |
| LocationType | nvarchar(50) | Có | 0 | 0 | 0 |  |
| Address | nvarchar(255) | Có | 0 | 0 | 0 |  |
| District | nvarchar(100) | Có | 0 | 0 | 0 |  |

## iot.Machines

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| MachineId | int | Không | 1 | 1 | 0 |  |
| Serial | nvarchar(50) | Không | 0 | 0 | 0 |  |
| MachineName | nvarchar(100) | Không | 0 | 0 | 0 |  |
| LocationId | int | Có | 0 | 0 | 0 |  |
| Status | nvarchar(20) | Có | 0 | 0 | 0 | `('ACTIVE')` |
| FirmwareVersion | nvarchar(20) | Có | 0 | 0 | 0 |  |
| LastHeartbeat | datetime2(0) | Có | 0 | 0 | 0 |  |
| InstalledAt | datetime2(0) | Có | 0 | 0 | 0 | `(sysdatetime())` |

## iot.MachineThresholds

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| MachineId | int | Không | 1 | 0 | 0 |  |
| MinTemp | decimal(5,2) | Có | 0 | 0 | 0 | `((2.00))` |
| MaxTemp | decimal(5,2) | Có | 0 | 0 | 0 | `((8.00))` |
| DoorOpenMaxMinutes | int | Có | 0 | 0 | 0 | `((2))` |
| ConsecutiveBreaches | int | Có | 0 | 0 | 0 | `((3))` |
| DegradedMessage | nvarchar(255) | Có | 0 | 0 | 0 | `(N'Nhiệt độ tủ lạnh vượt ngưỡng an toàn, vui lòng kiểm tra.')` |

## iot.Telemetry

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| ReadingId | bigint | Không | 1 | 1 | 0 |  |
| MachineId | int | Có | 0 | 0 | 0 |  |
| RecordedAt | datetime2(0) | Có | 0 | 0 | 0 | `(sysdatetime())` |
| Temperature | decimal(5,2) | Có | 0 | 0 | 0 |  |
| Humidity | decimal(5,2) | Có | 0 | 0 | 0 |  |
| DoorOpen | bit | Có | 0 | 0 | 0 |  |

## iot.TelemetryHourly

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| MachineId | int | Không | 1 | 0 | 0 |  |
| HourStart | datetime2(0) | Không | 1 | 0 | 0 |  |
| MinTemp | decimal(5,2) | Có | 0 | 0 | 0 |  |
| MaxTemp | decimal(5,2) | Có | 0 | 0 | 0 |  |
| AvgTemp | decimal(5,2) | Có | 0 | 0 | 0 |  |
| ReadingCount | int | Có | 0 | 0 | 0 |  |
| MinutesOutOfRange | int | Có | 0 | 0 | 0 |  |

## report.DailySalesSummary

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| SummaryDate | date | Không | 1 | 0 | 0 |  |
| MachineId | int | Không | 1 | 0 | 0 |  |
| ProductId | int | Không | 1 | 0 | 0 |  |
| QtySold | int | Không | 0 | 0 | 0 | `((0))` |
| Revenue | decimal(18,2) | Không | 0 | 0 | 0 | `((0.00))` |
| OrderCount | int | Không | 0 | 0 | 0 | `((0))` |
| AvgUnitPrice | decimal(12,2) | Có | 0 | 0 | 0 |  |
| TotalDiscount | decimal(18,2) | Không | 0 | 0 | 0 | `((0.00))` |
| NetRevenue | decimal(19,2) | Có | 0 | 0 | 1 |  |
| RefreshedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## report.ExportLogs

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| ExportId | int | Không | 1 | 1 | 0 |  |
| UserId | int | Không | 0 | 0 | 0 |  |
| ReportName | nvarchar(150) | Không | 0 | 0 | 0 |  |
| Params | nvarchar(max) | Có | 0 | 0 | 0 |  |
| FileFormat | nvarchar(10) | Không | 0 | 0 | 0 | `(N'EXCEL')` |
| FilePath | nvarchar(500) | Có | 0 | 0 | 0 |  |
| FileSizeBytes | bigint | Có | 0 | 0 | 0 |  |
| RowCount | int | Có | 0 | 0 | 0 |  |
| DurationMs | int | Có | 0 | 0 | 0 |  |
| Status | nvarchar(10) | Không | 0 | 0 | 0 | `(N'PENDING')` |
| ErrorMessage | nvarchar(500) | Có | 0 | 0 | 0 |  |
| ExportedAt | datetime2(3) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## report.SeedItems

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| Kind | nvarchar(30) | Không | 1 | 0 | 0 |  |
| ItemKey | nvarchar(100) | Không | 1 | 0 | 0 |  |
| ObjectId | bigint | Không | 0 | 0 | 0 |  |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## report.SeedRuns

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| Profile | nvarchar(10) | Không | 1 | 0 | 0 |  |
| HistoryEnd | date | Không | 0 | 0 | 0 |  |
| CompletedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| OrdersCreated | int | Không | 0 | 0 | 0 |  |
| TelemetryCreated | int | Không | 0 | 0 | 0 |  |

## report.TestResults

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| TestId | int | Không | 1 | 1 | 0 |  |
| Module | nvarchar(50) | Không | 0 | 0 | 0 |  |
| TestCase | nvarchar(150) | Không | 0 | 0 | 0 |  |
| Expected | nvarchar(500) | Không | 0 | 0 | 0 |  |
| Actual | nvarchar(500) | Có | 0 | 0 | 0 |  |
| ErrorDetail | nvarchar(max) | Có | 0 | 0 | 0 |  |
| Passed | bit | Không | 0 | 0 | 0 | `((0))` |
| DurationMs | int | Có | 0 | 0 | 0 |  |
| RunBy | nvarchar(100) | Có | 0 | 0 | 0 |  |
| RunAt | datetime2(3) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| BatchId | uniqueidentifier | Có | 0 | 0 | 0 | `(newid())` |
| Status | nvarchar(10) | Không | 0 | 0 | 0 | `(N'FAIL')` |

## sales.DispenseEvents

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| EventId | bigint | Không | 1 | 1 | 0 |  |
| OrderItemId | bigint | Không | 0 | 0 | 0 |  |
| AttemptNo | tinyint | Không | 0 | 0 | 0 |  |
| Result | nvarchar(10) | Không | 0 | 0 | 0 |  |
| ErrorCode | nvarchar(30) | Có | 0 | 0 | 0 |  |
| EventAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## sales.Order

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| OrderId | bigint | Không | 1 | 1 | 0 |  |
| OrderCode | nvarchar(30) | Không | 0 | 0 | 0 |  |
| MachineId | int | Không | 0 | 0 | 0 |  |
| CustomerId | int | Có | 0 | 0 | 0 |  |
| PromotionId | int | Có | 0 | 0 | 0 |  |
| Subtotal | decimal(14,2) | Không | 0 | 0 | 0 |  |
| DiscountAmount | decimal(14,2) | Không | 0 | 0 | 0 | `((0))` |
| TotalAmount | decimal(14,2) | Không | 0 | 0 | 0 |  |
| Status | nvarchar(20) | Không | 0 | 0 | 0 | `(N'PENDING')` |
| Note | nvarchar(500) | Có | 0 | 0 | 0 |  |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |
| ExpiresAt | datetime2(0) | Không | 0 | 0 | 0 | `(dateadd(minute,(5),sysutcdatetime()))` |
| PaidAt | datetime2(0) | Có | 0 | 0 | 0 |  |
| CompletedAt | datetime2(0) | Có | 0 | 0 | 0 |  |
| UpdatedAt | datetime2(0) | Có | 0 | 0 | 0 |  |

## sales.OrderItem

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| OrderItemId | bigint | Không | 1 | 1 | 0 |  |
| OrderId | bigint | Không | 0 | 0 | 0 |  |
| SlotId | int | Không | 0 | 0 | 0 |  |
| ColumnId | int | Không | 0 | 0 | 1 |  |
| StockId | bigint | Có | 0 | 0 | 0 |  |
| BatchId | int | Có | 0 | 0 | 0 |  |
| ProductId | int | Không | 0 | 0 | 0 |  |
| Quantity | smallint | Không | 0 | 0 | 0 |  |
| Qty | smallint | Không | 0 | 0 | 1 |  |
| UnitPrice | decimal(12,2) | Không | 0 | 0 | 0 |  |
| LineTotal | decimal(25,4) | Có | 0 | 0 | 1 |  |

## sales.Payment

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| PaymentId | bigint | Không | 1 | 1 | 0 |  |
| OrderId | bigint | Không | 0 | 0 | 0 |  |
| PaymentMethod | nvarchar(20) | Không | 0 | 0 | 0 |  |
| Method | nvarchar(20) | Không | 0 | 0 | 1 |  |
| Amount | decimal(14,2) | Không | 0 | 0 | 0 |  |
| Currency | char(3) | Không | 0 | 0 | 0 | `('VND')` |
| TransactionRef | nvarchar(100) | Có | 0 | 0 | 0 |  |
| GatewayTxnId | nvarchar(100) | Có | 0 | 0 | 0 |  |
| Status | nvarchar(15) | Không | 0 | 0 | 0 | `(N'pending')` |
| PaidAt | datetime2(0) | Có | 0 | 0 | 0 |  |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## sales.Promotion

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| PromotionId | int | Không | 1 | 1 | 0 |  |
| PromoCode | nvarchar(30) | Không | 0 | 0 | 0 |  |
| Description | nvarchar(300) | Có | 0 | 0 | 0 |  |
| DiscountType | nvarchar(10) | Không | 0 | 0 | 0 |  |
| DiscountValue | decimal(12,2) | Không | 0 | 0 | 0 |  |
| MinOrderAmount | decimal(12,2) | Có | 0 | 0 | 0 |  |
| MaxUses | int | Có | 0 | 0 | 0 |  |
| UsedCount | int | Không | 0 | 0 | 0 | `((0))` |
| StartDate | datetime2(0) | Không | 0 | 0 | 0 |  |
| EndDate | datetime2(0) | Không | 0 | 0 | 0 |  |
| IsActive | bit | Không | 0 | 0 | 0 | `((1))` |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## sales.Refund

| Cột | Kiểu | NULL | PK | Identity | Computed | Default |
|---|---|---|---|---|---|---|
| RefundId | bigint | Không | 1 | 1 | 0 |  |
| PaymentId | bigint | Không | 0 | 0 | 0 |  |
| OrderId | bigint | Không | 0 | 0 | 0 |  |
| Amount | decimal(14,2) | Không | 0 | 0 | 0 |  |
| RefundAmount | decimal(14,2) | Không | 0 | 0 | 0 |  |
| Reason | nvarchar(300) | Có | 0 | 0 | 0 |  |
| Status | nvarchar(15) | Không | 0 | 0 | 0 | `(N'pending')` |
| ProcessedBy | int | Có | 0 | 0 | 0 |  |
| ProcessedAt | datetime2(0) | Có | 0 | 0 | 0 |  |
| RefundedAt | datetime2(0) | Không | 0 | 0 | 0 |  |
| CreatedAt | datetime2(0) | Không | 0 | 0 | 0 | `(sysutcdatetime())` |

## Khóa ngoại thực tế

| FK | Từ | Đến | Enabled / Trusted |
|---|---|---|---|
| FK__Alerts__MachineI__7A3223E8 | iot.Alerts.MachineId | iot.Machines.MachineId | True / True |
| FK__Machines__Locati__662B2B3B | iot.Machines.LocationId | iot.Locations.LocationId | True / True |
| FK__MachineTh__Machi__6BE40491 | iot.MachineThresholds.MachineId | iot.Machines.MachineId | True / True |
| FK__Telemetry__Machi__73852659 | iot.Telemetry.MachineId | iot.Machines.MachineId | True / True |
| FK__Telemetry__Machi__7755B73D | iot.TelemetryHourly.MachineId | iot.Machines.MachineId | True / True |
| FK_Alerts_AckBy | iot.Alerts.AckBy | auth.User.UserId | True / True |
| FK_audit_AuditLog_auth_User | audit.AuditLog.UserId | auth.User.UserId | True / True |
| FK_audit_ChangeLog_auth_User | audit.ChangeLog.UserId | auth.User.UserId | True / True |
| FK_auth_LoginHistory_User | auth.LoginHistory.UserId | auth.User.UserId | True / True |
| FK_auth_RefreshToken_User | auth.RefreshToken.UserId | auth.User.UserId | True / True |
| FK_auth_RolePermission_Permission | auth.RolePermission.PermissionId | auth.Permission.PermissionId | True / True |
| FK_auth_RolePermission_Role | auth.RolePermission.RoleId | auth.Role.RoleId | True / True |
| FK_auth_UserMachine_User | auth.UserMachine.UserId | auth.User.UserId | True / True |
| FK_auth_UserRole_AssignedBy | auth.UserRole.AssignedBy | auth.User.UserId | True / True |
| FK_auth_UserRole_Role | auth.UserRole.RoleId | auth.Role.RoleId | True / True |
| FK_auth_UserRole_User | auth.UserRole.UserId | auth.User.UserId | True / True |
| FK_DailySalesSummary_MachineId | report.DailySalesSummary.MachineId | iot.Machines.MachineId | True / True |
| FK_DailySalesSummary_ProductId | report.DailySalesSummary.ProductId | inventory.Product.ProductId | True / True |
| FK_ExportLogs_UserId | report.ExportLogs.UserId | auth.User.UserId | True / True |
| FK_inventory_Category_Parent | inventory.Category.ParentId | inventory.Category.CategoryId | True / True |
| FK_inventory_Product_Cat | inventory.Product.CategoryId | inventory.Category.CategoryId | True / True |
| FK_inventory_Product_Sup | inventory.Product.SupplierId | inventory.Supplier.SupplierId | True / True |
| FK_inventory_RestockItem_Batch | inventory.RestockItem.BatchId | inventory.StockBatch.BatchId | True / True |
| FK_inventory_RestockItem_Event | inventory.RestockItem.RestockId | inventory.RestockEvent.RestockId | True / True |
| FK_inventory_RestockItem_Slot | inventory.RestockItem.SlotId | inventory.Slot.SlotId | True / True |
| FK_inventory_Slot_Machine | inventory.Slot.MachineId | iot.Machines.MachineId | True / True |
| FK_inventory_Slot_Product | inventory.Slot.ProductId | inventory.Product.ProductId | True / True |
| FK_inventory_SlotStock_Batch | inventory.SlotStock.BatchId | inventory.StockBatch.BatchId | True / True |
| FK_inventory_SlotStock_Slot | inventory.SlotStock.SlotId | inventory.Slot.SlotId | True / True |
| FK_inventory_StockBatch_auth_User | inventory.StockBatch.CreatedBy | auth.User.UserId | True / True |
| FK_inventory_StockBatch_Product | inventory.StockBatch.ProductId | inventory.Product.ProductId | True / True |
| FK_inventory_StockBatch_Supplier | inventory.StockBatch.SupplierId | inventory.Supplier.SupplierId | True / True |
| FK_inventory_StockMovement_auth_User | inventory.StockMovement.CreatedBy | auth.User.UserId | True / True |
| FK_inventory_StockMovement_Batch | inventory.StockMovement.BatchId | inventory.StockBatch.BatchId | True / True |
| FK_inventory_StockMovement_Slot | inventory.StockMovement.SlotId | inventory.Slot.SlotId | True / True |
| FK_OrderItem_SlotStock | sales.OrderItem.StockId | inventory.SlotStock.StockId | True / True |
| FK_OrderItem_StockBatch | sales.OrderItem.BatchId | inventory.StockBatch.BatchId | True / True |
| FK_RestockEvent_Machine | inventory.RestockEvent.MachineId | iot.Machines.MachineId | True / True |
| FK_RestockEvent_User | inventory.RestockEvent.UserId | auth.User.UserId | True / True |
| FK_sales_DispenseEvents_OrderItem | sales.DispenseEvents.OrderItemId | sales.OrderItem.OrderItemId | True / True |
| FK_sales_Order_auth_User | sales.Order.CustomerId | auth.User.UserId | True / True |
| FK_sales_Order_iot_Machines | sales.Order.MachineId | iot.Machines.MachineId | True / True |
| FK_sales_Order_Promotion | sales.Order.PromotionId | sales.Promotion.PromotionId | True / True |
| FK_sales_OrderItem_inventory_Product | sales.OrderItem.ProductId | inventory.Product.ProductId | True / True |
| FK_sales_OrderItem_inventory_Slot | sales.OrderItem.SlotId | inventory.Slot.SlotId | True / True |
| FK_sales_OrderItem_Order | sales.OrderItem.OrderId | sales.Order.OrderId | True / True |
| FK_sales_OrderItem_SlotStock | sales.OrderItem.StockId | inventory.SlotStock.StockId | True / True |
| FK_sales_OrderItem_StockBatch | sales.OrderItem.BatchId | inventory.StockBatch.BatchId | True / True |
| FK_sales_Payment_Order | sales.Payment.OrderId | sales.Order.OrderId | True / True |
| FK_sales_Refund_auth_User | sales.Refund.ProcessedBy | auth.User.UserId | True / True |
| FK_sales_Refund_Order | sales.Refund.OrderId | sales.Order.OrderId | True / True |
| FK_sales_Refund_Payment | sales.Refund.PaymentId | sales.Payment.PaymentId | True / True |
| FK_UserMachine_MachineId | auth.UserMachine.MachineId | iot.Machines.MachineId | True / True |
