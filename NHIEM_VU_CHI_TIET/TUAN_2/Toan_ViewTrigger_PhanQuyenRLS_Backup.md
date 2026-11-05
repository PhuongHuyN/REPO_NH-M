# Toàn – Tuần 2: Sprint 2 – Đủ object & nối app với SQL Server thật

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Huỳnh Nhật Toàn
- **Email:** htoan2851@gmail.com
- **Tuần:** 2 (Sprint 2 – Đủ object & nối app với SQL Server thật)
- **Thời gian:** 13/11/2026 → 19/11/2026
- **Vai trò:** TV1 – Người dùng & Bảo mật (schema auth, audit), RBAC/RLS, Backup, cài đặt
- **Mức độ ưu tiên:** Highest
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-215, SCRUM-216, SCRUM-217

**Mục tiêu Sprint:** Đủ view/function/trigger/phần khó của 5 module; phân quyền 4 login; app chạy DB_MODE=sqlserver qua trọn kịch bản châm hàng → mua → nhả hàng → cảnh báo → báo cáo.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-21 (SCRUM-215) | 20_objects_auth.sql: vw_UserPermissions, audit.vw_LoginActivity, trigger ghi ChangeLog | 13/11/2026 | 14/11/2026 | High | FV-08 |
| FV-22 (SCRUM-216) | 40_security.sql: 4 login ứng dụng, database role, GRANT/DENY theo bảng ALLOW, Row-Level Security | 15/11/2026 | 17/11/2026 | Highest | FV-21, FV-18, FV-10, FV-12 |
| FV-23 (SCRUM-217) | 50_backup.sql (Full/Diff/Log) và 99_run_all.bat (tạo CSDL từ máy trống bằng 1 lệnh) | 18/11/2026 | 19/11/2026 | High | FV-22, FV-16 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-21 (SCRUM-215) – 20_objects_auth.sql: vw_UserPermissions, audit.vw_LoginActivity, trigger ghi ChangeLog

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 13/11/2026 → 14/11/2026 |
| Mức ưu tiên | High |
| Epic | E1 – Người dùng & Bảo mật (auth, audit) |
| Phụ thuộc | FV-08 (SCRUM-202) (Toàn) |
| Người hỗ trợ | Không |

### 1. MỤC TIÊU
20_objects_auth.sql: vw_UserPermissions, audit.vw_LoginActivity, trigger ghi ChangeLog. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Trang *Người dùng* đọc `auth.vw_UserPermissions`; Admin xem thống kê đăng nhập từ `audit.vw_LoginActivity`. Đề yêu cầu audit trail cho mọi thao tác thủ công – trigger của bạn là mẫu để cả nhóm dùng lại.

### 3. PHẠM VI CÔNG VIỆC
- `auth.vw_UserPermissions`: cột như fakeDb.js dòng 517–523 (`MachineIds` dạng chuỗi dùng `STRING_AGG`).
- `audit.vw_LoginActivity`: `LoginDate, SuccessCount, FailedCount, DistinctUsers`.
- `auth.trg_Users_Audit` AFTER INSERT, UPDATE trên `auth.[User]`: ghi `OldData/NewData` bằng `FOR JSON PATH` (bỏ cột PasswordHash, Salt).

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. View người dùng**
```sql
CREATE OR ALTER VIEW auth.vw_UserPermissions AS
SELECT u.UserId, u.Username, u.FullName, u.Email, r.RoleName, u.IsActive, u.FailedLogins, u.LastLoginAt, u.CreatedAt,
       COUNT(um.MachineId) AS MachineCount,
       STRING_AGG(CAST(um.MachineId AS VARCHAR(10)), ',') WITHIN GROUP (ORDER BY um.MachineId) AS MachineIds
FROM auth.[User] u
LEFT JOIN auth.UserRole ur ON ur.UserId = u.UserId LEFT JOIN auth.Role r ON r.RoleId = ur.RoleId
LEFT JOIN auth.UserMachine um ON um.UserId = u.UserId
GROUP BY u.UserId, u.Username, u.FullName, u.Email, r.RoleName, u.IsActive, u.FailedLogins, u.LastLoginAt, u.CreatedAt;
```
Thêm cột `AssignedMachines` (danh sách Serial) bằng JOIN bảng máy theo QĐ-1.

**Bước 2. Trigger audit**
```sql
CREATE OR ALTER TRIGGER auth.trg_Users_Audit ON auth.[User] AFTER INSERT, UPDATE AS
BEGIN
  SET NOCOUNT ON;
  INSERT audit.ChangeLog (TableName, RecordId, Action, OldData, NewData, UserId)
  SELECT N'auth.User', CAST(i.UserId AS NVARCHAR(50)), CASE WHEN d.UserId IS NULL THEN 'INSERT' ELSE 'UPDATE' END,
    (SELECT d.Username, d.FullName, d.IsActive, d.FailedLogins FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
    (SELECT i.Username, i.FullName, i.IsActive, i.FailedLogins FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
    TRY_CAST(SESSION_CONTEXT(N'UserId') AS INT)
  FROM inserted i LEFT JOIN deleted d ON d.UserId = i.UserId;
END
```
- **Lưu ý:** trigger DML phải cùng schema với bảng, nên tên là `auth.trg_Users_Audit` (không phải `audit.`).

**Bước 3. Chạy thử**
`EXEC auth.sp_DeactivateUser @UserId = 2, @Activate = 0;` → `SELECT * FROM audit.ChangeLog ORDER BY ChangeId DESC;` thấy OldData IsActive=true, NewData IsActive=false.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/20_objects_auth.sql` (tạo mới)
- `app/web/js/pages/users.js` (cột hiển thị)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu ra cho:** Huy, Dũng dùng mẫu trigger FOR JSON nếu muốn audit thao tác châm hàng/xóa lỗi máy.

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | View | SELECT * FROM auth.vw_UserPermissions | operator01 có MachineIds '1,2,3' |
| 2 | Trigger | Khóa 1 user | 1 dòng ChangeLog có JSON cũ/mới |
| 3 | Không lộ mật khẩu | Đọc NewData | Không có PasswordHash/Salt |

**Kết quả cần lưu lại:** Ảnh audit.ChangeLog.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 2 view đúng cột API
- [ ] Trigger xử lý nhiều dòng, không ghi mật khẩu
- [ ] PR merge

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b feature/SCRUM-215-auth-objects
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/20_objects_auth.sql
git commit -m "feat(sql-auth): 2 view + trg_Users_Audit (FOR JSON)"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-215-auth-objects
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-215-auth-objects`.
7. **Mô tả PR:** tiêu đề `[SCRUM-215] 20_objects_auth.sql: vw_UserPermissions, audit.vw_LoginActivity, trigger ghi ChangeLog`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-215`; dán ảnh bằng chứng: Ảnh audit.ChangeLog.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-215-auth-objects
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-215 |
| Branch | `feature/SCRUM-215-auth-objects` |
| Commit | `feat(sql-auth): 2 view + trg_Users_Audit (FOR JSON)` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/20_objects_auth.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 14/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-215
- **Bằng chứng hoàn thành:** Ảnh audit.ChangeLog
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-22 (SCRUM-216) – 40_security.sql: 4 login ứng dụng, database role, GRANT/DENY theo bảng ALLOW, Row-Level Security

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 15/11/2026 → 17/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E1 – Người dùng & Bảo mật (auth, audit) |
| Phụ thuộc | FV-21 (SCRUM-215) (Toàn), FV-18 (SCRUM-212) (Huy), FV-10 (SCRUM-204) (Ân), FV-12 (SCRUM-206) (Dũng) |
| Người hỗ trợ | Huy |

### 1. MỤC TIÊU
40_security.sql: 4 login ứng dụng, database role, GRANT/DENY theo bảng ALLOW, Row-Level Security. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Đề yêu cầu RBAC: Operator không được xem số liệu tài chính. API kết nối bằng 4 login tách biệt (`app/api/.env.example` dòng 23–30): `fv_admin_app`, `fv_operator_app`, `fv_kiosk_app`, `fv_device_app`. Quyền mỗi login phải **đúng y** bảng `ALLOW` trong `app/api/test/fakeDb.js` dòng 16–28 – test API đang kiểm tra theo bảng này.

### 3. PHẠM VI CÔNG VIỆC
- Tạo 4 LOGIN + USER, 4 ROLE `r_admin`, `r_operator`, `r_kiosk`, `r_device`.
- GRANT theo bảng ALLOW; `DENY SELECT, EXECUTE ON SCHEMA::report TO r_operator`.
- RLS: `auth.fn_MachineFilter` + `SECURITY POLICY` trên bảng máy – Operator chỉ thấy máy được giao (đọc `SESSION_CONTEXT(N'UserId')` mà `db.js` đặt trước mỗi lệnh).
- Mật khẩu login đúng như `.env.example`.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Login và role**
```sql
USE master;
IF SUSER_ID(N'fv_operator_app') IS NULL
  CREATE LOGIN fv_operator_app WITH PASSWORD = N'FreshVend@Operator2026', CHECK_POLICY = OFF;
GO
USE FreshVendDB;
IF USER_ID(N'fv_operator_app') IS NULL CREATE USER fv_operator_app FOR LOGIN fv_operator_app;
IF DATABASE_PRINCIPAL_ID(N'r_operator') IS NULL CREATE ROLE r_operator;
ALTER ROLE r_operator ADD MEMBER fv_operator_app;
GO
```
Lặp lại cho admin, kiosk, device.

**Bước 2. GRANT theo ALLOW**
```sql
GRANT EXECUTE, SELECT ON SCHEMA::inventory TO r_operator;
GRANT SELECT ON iot.vw_MachineHealth TO r_operator;
GRANT SELECT ON iot.vw_OpenAlerts TO r_operator;
GRANT SELECT ON iot.fn_RecentTelemetry TO r_operator;
GRANT EXECUTE ON iot.sp_AcknowledgeAlert TO r_operator;
GRANT EXECUTE ON iot.sp_ClearFault TO r_operator;
GRANT EXECUTE ON auth.sp_Login TO r_operator, r_kiosk;
GRANT EXECUTE ON auth.sp_ChangePassword TO r_operator, r_kiosk;
DENY SELECT, EXECUTE ON SCHEMA::report TO r_operator;
-- Kiosk: sales.sp_CreateOrder/ConfirmPayment/RecordDispense/ExpirePendingOrders, inventory.vw_StockStatus, sales.vw_OrderDetail, sales.vw_DispenseQueue, iot.vw_MachineHealth
-- Device: iot.sp_IngestTelemetry, sales.sp_RecordDispense, sales.vw_DispenseQueue, iot.vw_MachineHealth
ALTER ROLE db_owner ADD MEMBER fv_admin_app;   -- hoặc GRANT CONTROL ON DATABASE
```
- **Lưu ý:** GRANT trên object chỉ chạy được khi object đã tồn tại → file 40 chạy **sau** toàn bộ 1x, 2x.

**Bước 3. Row-Level Security**
```sql
CREATE OR ALTER FUNCTION auth.fn_MachineFilter (@MachineId INT)
RETURNS TABLE WITH SCHEMABINDING AS RETURN
  SELECT 1 AS ok WHERE IS_MEMBER(N'r_operator') = 0
     OR EXISTS (SELECT 1 FROM auth.UserMachine a
                WHERE a.MachineId = @MachineId AND a.UserId = CAST(SESSION_CONTEXT(N'UserId') AS INT));
GO
IF NOT EXISTS (SELECT 1 FROM sys.security_policies WHERE name = N'MachinePolicy')
  CREATE SECURITY POLICY auth.MachinePolicy
    ADD FILTER PREDICATE auth.fn_MachineFilter(MachineId) ON iot.Machines
    WITH (STATE = ON);
```
(Đổi `iot.Machines` theo QĐ-1.)

**Bước 4. Kiểm tra**
```sql
EXEC sp_set_session_context N'UserId', 2;      -- operator01
EXECUTE AS USER = N'fv_operator_app';
SELECT MachineId FROM iot.Machines;              -- chỉ 1, 2, 3
SELECT TOP 1 * FROM report.vw_ProductRanking;    -- lỗi 229
REVERT;
```

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/40_security.sql` (tạo mới)
- `app/api/test/fakeDb.js dòng 16–28` (bảng ALLOW)
- `app/api/.env.example dòng 23–30`
- `app/api/src/db.js` (đặt SESSION_CONTEXT)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** đủ object của 5 module trên main (view iot của Dũng, view sales của Ân, view inventory của Huy). **Đầu ra cho:** Huy (FV-20 nối app), Dũng (FV-29 simulator dùng fv_device_app).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | RLS | EXECUTE AS fv_operator_app, UserId=2 | Chỉ thấy máy 1,2,3 |
| 2 | DENY report | Operator SELECT report.* | Lỗi 229 → API trả 403 |
| 3 | Kiosk | fv_kiosk_app EXEC inventory.sp_AddProduct | Lỗi 229 |
| 4 | Chạy lại | F5 lần 2 | Không lỗi |

**Kết quả cần lưu lại:** Ảnh 4 test EXECUTE AS.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] Quyền 4 login khớp bảng ALLOW
- [ ] RLS lọc đúng máy
- [ ] Chạy lại không lỗi
- [ ] PR merge

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b feature/SCRUM-216-security-rbac-rls
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/40_security.sql
git commit -m "feat(sql-security): login ứng dụng, RBAC GRANT/DENY, RLS theo máy được giao"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-216-security-rbac-rls
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-216-security-rbac-rls`.
7. **Mô tả PR:** tiêu đề `[SCRUM-216] 40_security.sql: 4 login ứng dụng, database role, GRANT/DENY theo bảng ALLOW, Row-Level Security`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-216`; dán ảnh bằng chứng: Ảnh 4 test EXECUTE AS.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-216-security-rbac-rls
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-216 |
| Branch | `feature/SCRUM-216-security-rbac-rls` |
| Commit | `feat(sql-security): login ứng dụng, RBAC GRANT/DENY, RLS theo máy được giao` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/40_security.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 17/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-216
- **Bằng chứng hoàn thành:** Ảnh 4 test EXECUTE AS
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-23 (SCRUM-217) – 50_backup.sql (Full/Diff/Log) và 99_run_all.bat (tạo CSDL từ máy trống bằng 1 lệnh)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 18/11/2026 → 19/11/2026 |
| Mức ưu tiên | High |
| Epic | E1 – Người dùng & Bảo mật (auth, audit) |
| Phụ thuộc | FV-22 (SCRUM-216) (Toàn), FV-16 (SCRUM-210) (Anh) |
| Người hỗ trợ | Anh |

### 1. MỤC TIÊU
50_backup.sql (Full/Diff/Log) và 99_run_all.bat (tạo CSDL từ máy trống bằng 1 lệnh). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Đề yêu cầu 99,9% uptime và không mất dữ liệu → cần chiến lược sao lưu. Cả nhóm (và giảng viên) cần **một lệnh** để dựng CSDL từ đầu thay vì chạy tay 25 file.

### 3. PHẠM VI CÔNG VIỆC
- `sql/50_backup.sql`: đặt Recovery FULL; mẫu BACKUP FULL/DIFFERENTIAL/LOG; mẫu RESTORE ... WITH STOPAT.
- `99_run_all.bat` ở thư mục gốc repo: gọi `sqlcmd` chạy các file theo đúng thứ tự trong MASTER_PLAN.md, dừng khi lỗi.
- Tham số server: mặc định `localhost`, cho phép `99_run_all.bat .\SQLEXPRESS`.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Kiểm tra sqlcmd**
PowerShell: `sqlcmd -?`. Nếu chưa có: cài *Microsoft Command Line Utilities for SQL Server* (đi kèm SSMS 20 hoặc tải riêng).

**Bước 2. Viết 99_run_all.bat**
```bat
@echo off
chcp 65001 >nul
set SERVER=%1
if "%SERVER%"=="" set SERVER=localhost
for %%F in (00_database 01_schemas 02_tables_audit 02_tables_auth 02_tables_inventory 02_tables_iot 02_tables_report 02_tables_sales 03_foreign_keys 10_procs_auth 11_procs_inventory 12_procs_sales 13_procs_iot 14_procs_report 20_objects_auth 21_objects_inventory 22_objects_sales 23_objects_iot 24_objects_report 30_index_inventory 40_security 45_jobs 80_seed_small) do (
  echo === %%F
  sqlcmd -S %SERVER% -E -b -f 65001 -i sql\%%F.sql || (echo LOI tai %%F & exit /b 1)
)
echo HOAN TAT
```
- `-E`: đăng nhập Windows; `-b`: dừng khi lỗi; `-f 65001`: đọc file UTF-8 (tiếng Việt).

**Bước 3. Backup**
```sql
ALTER DATABASE FreshVendDB SET RECOVERY FULL;
BACKUP DATABASE FreshVendDB TO DISK = N'C:\FreshVendBackup\FreshVendDB_full.bak' WITH INIT, COMPRESSION;
BACKUP DATABASE FreshVendDB TO DISK = N'C:\FreshVendBackup\FreshVendDB_diff.bak' WITH DIFFERENTIAL, INIT;
BACKUP LOG FreshVendDB TO DISK = N'C:\FreshVendBackup\FreshVendDB_log.trn' WITH INIT;
```
Ghi chú lịch đề xuất: Full Chủ nhật, Diff hằng ngày, Log 15 phút (SQL Express không có Agent → dùng Task Scheduler).

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/50_backup.sql` (mới)
- `99_run_all.bat` (mới, thư mục gốc)
- `NHIEM_VU_CHI_TIET/MASTER_PLAN.md` (thứ tự file)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu vào:** Anh chốt tên file (FV-16). **Đầu ra cho:** Huy (FV-20, FV-35), Toàn (FV-38 InstallGuide).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Máy trống | Xóa FreshVendDB, chạy 99_run_all.bat | In HOAN TAT, không lỗi |
| 2 | Lỗi giữa chừng | Cố ý làm sai 1 file | Dừng và in tên file lỗi |
| 3 | Backup | Chạy 50_backup | 3 file .bak/.trn được tạo |

**Kết quả cần lưu lại:** Ảnh cửa sổ cmd in HOAN TAT.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 99_run_all.bat dựng CSDL sạch trong 1 lệnh
- [ ] 50_backup chạy được
- [ ] PR merge

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b feature/SCRUM-217-backup-run-all
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/50_backup.sql 99_run_all.bat
git commit -m "feat(sql): 50_backup và 99_run_all.bat"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-217-backup-run-all
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-217-backup-run-all`.
7. **Mô tả PR:** tiêu đề `[SCRUM-217] 50_backup.sql (Full/Diff/Log) và 99_run_all.bat (tạo CSDL từ máy trống bằng 1 lệnh)`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-217`; dán ảnh bằng chứng: Ảnh cửa sổ cmd in HOAN TAT.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-217-backup-run-all
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-217 |
| Branch | `feature/SCRUM-217-backup-run-all` |
| Commit | `feat(sql): 50_backup và 99_run_all.bat` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- 99_run_all.bat
- sql/50_backup.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 19/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-217
- **Bằng chứng hoàn thành:** Ảnh cửa sổ cmd in HOAN TAT
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
