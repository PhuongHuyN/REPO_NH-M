# Toàn – Tuần 1: Sprint 1 – Nền tảng CSDL

## THÔNG TIN NHIỆM VỤ
- **Thành viên:** Huỳnh Nhật Toàn
- **Email:** htoan2851@gmail.com
- **Tuần:** 1 (Sprint 1 – Nền tảng CSDL)
- **Thời gian:** 06/11/2026 → 12/11/2026
- **Vai trò:** TV1 – Người dùng & Bảo mật (schema auth, audit), RBAC/RLS, Backup, cài đặt
- **Mức độ ưu tiên:** Highest
- **Trạng thái:** Chưa bắt đầu
- **Task ID Jira (bổ sung sau khi tạo Jira):** SCRUM-200, SCRUM-201, SCRUM-202

**Mục tiêu Sprint:** Mọi bảng và stored procedure lõi của 5 module có trên main; chạy toàn bộ script trên CSDL trống không lỗi; xóa hết nhánh tồn đọng.

| Mã | Task | Bắt đầu | Hạn | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|---|
| FV-06 (SCRUM-200) | Sửa bảng auth và tạo 02_tables_audit.sql (AuditLog, ChangeLog), bảng giao máy | 06/11/2026 | 08/11/2026 | Highest | FV-01 |
| FV-07 (SCRUM-201) | Sửa 03_foreign_keys.sql cho khớp bảng thật (đang lỗi khi chạy từ đầu) | 09/11/2026 | 09/11/2026 | Highest | FV-06, FV-02 |
| FV-08 (SCRUM-202) | 10_procs_auth.sql: sp_Login, sp_CreateUser, sp_ChangePassword, sp_AssignMachine, sp_DeactivateUser + fn_HashPassword | 10/11/2026 | 12/11/2026 | Highest | FV-06 |

> Đọc trước: `MASTER_PLAN.md` (quyết định kỹ thuật, thứ tự file), `Cach_su_dung_GITHUB.md`. Đặc tả chạy được của mọi procedure/view nằm trong `app/api/test/fakeDb.js`.

---

## TASK FV-06 (SCRUM-200) – Sửa bảng auth và tạo 02_tables_audit.sql (AuditLog, ChangeLog), bảng giao máy

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 06/11/2026 → 08/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E1 – Người dùng & Bảo mật (auth, audit) |
| Phụ thuộc | FV-01 (SCRUM-195) (Huy) |
| Người hỗ trợ | Huy |

### 1. MỤC TIÊU
Sửa bảng auth và tạo 02_tables_audit.sql (AuditLog, ChangeLog), bảng giao máy. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Module auth/audit chưa có commit nào ngoài bảng khung ngày 21/10. `03_foreign_keys.sql` đang thêm FK vào `audit.AuditLog` và `audit.ChangeLog` – hai bảng chưa tồn tại nên script chạy tới file 03 là lỗi. API (`app/api/src/routes/auth.js`) cần thêm: muối mật khẩu, đếm số lần sai, giờ đăng nhập cuối, bảng giao máy cho Operator/Kiosk. `auth.LoginHistory.UserId` đang NOT NULL nên không ghi được lần đăng nhập sai tên.

### 3. PHẠM VI CÔNG VIỆC
- `sql/02_tables_auth.sql`: thêm cột `Salt`, `FailedLogins`, `LastLoginAt` vào `auth.[User]`; cho `LoginHistory.UserId` NULL và thêm cột `Username`.
- Tạo bảng `auth.UserMachine (UserId, MachineId, AssignedAt)` – FK sang bảng máy để ở 03.
- Tạo file `sql/02_tables_audit.sql`: `audit.AuditLog`, `audit.ChangeLog` (có `UserId`, `TableName`, `Action`, `OldData`, `NewData` NVARCHAR(MAX), `ChangedAt`).
- Dữ liệu mẫu: 3 vai trò Admin/Operator/Kiosk.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Đọc đặc tả**
- **Mở file:** `app/api/test/fakeDb.js` dòng 14–33 (quyền), 87–144 (procedure auth), 517–533 (view). Ghi ra giấy: cột nào API cần trả về.

**Bước 2. Tạo nhánh**
- Theo mục 9 bước 1–3. Nhánh `feature/FV-06-auth-audit-tables`.

**Bước 3. Thêm cột vào auth.[User]**
- **Mở file:** `sql/02_tables_auth.sql`, thêm cuối file:
```sql
IF COL_LENGTH(N'auth.[User]', N'Salt') IS NULL
  ALTER TABLE auth.[User] ADD Salt UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_auth_User_Salt DEFAULT NEWID();
IF COL_LENGTH(N'auth.[User]', N'FailedLogins') IS NULL
  ALTER TABLE auth.[User] ADD FailedLogins TINYINT NOT NULL CONSTRAINT DF_auth_User_FailedLogins DEFAULT 0;
IF COL_LENGTH(N'auth.[User]', N'LastLoginAt') IS NULL
  ALTER TABLE auth.[User] ADD LastLoginAt DATETIME2(0) NULL;
GO
ALTER TABLE auth.LoginHistory ALTER COLUMN UserId INT NULL;
IF COL_LENGTH(N'auth.LoginHistory', N'Username') IS NULL
  ALTER TABLE auth.LoginHistory ADD Username NVARCHAR(50) NULL;
GO
```
- **Lưu ý:** cột `Email` đang NOT NULL – API tạo Kiosk không có email, nên đổi thành NULL (`ALTER COLUMN Email NVARCHAR(150) NULL`).

**Bước 4. Bảng giao máy**
```sql
IF OBJECT_ID(N'auth.UserMachine', N'U') IS NULL
CREATE TABLE auth.UserMachine (
  UserId     INT NOT NULL CONSTRAINT FK_auth_UserMachine_User REFERENCES auth.[User](UserId),
  MachineId  INT NOT NULL,   -- FK sang bảng máy: thêm ở 03_foreign_keys
  AssignedAt DATETIME2(0) NOT NULL CONSTRAINT DF_auth_UserMachine_At DEFAULT SYSDATETIME(),
  CONSTRAINT PK_auth_UserMachine PRIMARY KEY (UserId, MachineId));
```

**Bước 5. File audit**
- **Tạo file:** `sql/02_tables_audit.sql` (chép phần đầu `USE FreshVendDB; GO` từ file auth).
```sql
IF OBJECT_ID(N'audit.ChangeLog', N'U') IS NULL
CREATE TABLE audit.ChangeLog (
  ChangeId  BIGINT IDENTITY CONSTRAINT PK_audit_ChangeLog PRIMARY KEY,
  TableName SYSNAME NOT NULL, RecordId NVARCHAR(50) NOT NULL,
  Action    VARCHAR(10) NOT NULL CONSTRAINT CK_audit_ChangeLog_Action CHECK (Action IN ('INSERT','UPDATE','DELETE')),
  OldData   NVARCHAR(MAX) NULL, NewData NVARCHAR(MAX) NULL,
  UserId    INT NULL,   -- FK ở 03
  ChangedAt DATETIME2(0) NOT NULL CONSTRAINT DF_audit_ChangeLog_At DEFAULT SYSDATETIME());
```
Tương tự `audit.AuditLog (AuditId, UserId, Action, Detail NVARCHAR(MAX), CreatedAt)` cho thao tác thủ công (châm hàng, xóa lỗi máy).

**Bước 6. Chạy thử**
- SSMS: CSDL trống → 00 → 01 → 02_tables_audit → 02_tables_auth → các 02 khác. Chạy lại file của bạn lần 2: không lỗi.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/02_tables_auth.sql` (sửa)
- `sql/02_tables_audit.sql` (tạo mới)
- `app/api/test/fakeDb.js dòng 14–33, 87–144, 517–533` (đặc tả)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu ra cho:** FV-07 (chính bạn sửa FK), FV-08 (procedure auth), Huy (FV-03 kiểm tra Operator được giao máy qua `auth.UserMachine`).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Chạy lại | F5 2 lần mỗi file | Không lỗi lần 2 |
| 2 | Đăng nhập sai tên | INSERT auth.LoginHistory (UserId, Username, IsSuccess) VALUES (NULL, N'khongco', 0) | Ghi được |
| 3 | Khóa chính giao máy | INSERT trùng (UserId, MachineId) | Lỗi 2627 |

**Kết quả cần lưu lại:** Ảnh Object Explorer schema auth, audit.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] auth.[User] có Salt, FailedLogins, LastLoginAt
- [ ] audit.AuditLog, audit.ChangeLog, auth.UserMachine tồn tại
- [ ] Chạy lại không lỗi
- [ ] PR merge, CI xanh

### 9. GITHUB WORKFLOW
1. **Kiểm tra nhánh hiện tại** – `git status` (sạch), `git branch`.
2. **Đồng bộ main mới nhất**
```powershell
git checkout main
git pull origin main
```
3. **Tạo nhánh riêng cho task**
```powershell
git checkout -b feature/SCRUM-200-auth-audit-tables
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/02_tables_auth.sql sql/02_tables_audit.sql
git commit -m "feat(sql-auth): thêm Salt, FailedLogins, UserMachine; tạo bảng audit"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-200-auth-audit-tables
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-200-auth-audit-tables`.
7. **Mô tả PR:** tiêu đề `[SCRUM-200] Sửa bảng auth và tạo 02_tables_audit.sql (AuditLog, ChangeLog), bảng giao máy`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-200`; dán ảnh bằng chứng: Ảnh Object Explorer schema auth, audit.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-200-auth-audit-tables
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-200 |
| Branch | `feature/SCRUM-200-auth-audit-tables` |
| Commit | `feat(sql-auth): thêm Salt, FailedLogins, UserMachine; tạo bảng audit` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/02_tables_auth.sql
- sql/02_tables_audit.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 08/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-200
- **Bằng chứng hoàn thành:** Ảnh Object Explorer schema auth, audit
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-07 (SCRUM-201) – Sửa 03_foreign_keys.sql cho khớp bảng thật (đang lỗi khi chạy từ đầu)

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 09/11/2026 → 09/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E1 – Người dùng & Bảo mật (auth, audit) |
| Phụ thuộc | FV-06 (SCRUM-200) (Toàn), FV-02 (SCRUM-196) (Huy) |
| Người hỗ trợ | Dũng, Anh |

### 1. MỤC TIÊU
Sửa 03_foreign_keys.sql cho khớp bảng thật (đang lỗi khi chạy từ đầu). Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
`sql/03_foreign_keys.sql` (tạo 21/10) tham chiếu 5 bảng không tồn tại: `audit.AuditLog`, `audit.ChangeLog` (FV-06 đã tạo), `iot.Device`, `iot.Alert` (bảng thật là `iot.Alerts`), `report.MachineStockSnapshot`. Nhánh TV5 cũng đang sửa file này – phải phối hợp với Anh để không đè nhau.

### 3. PHẠM VI CÔNG VIỆC
- Xóa khối FK của `iot.Device`, `report.MachineStockSnapshot`.
- Đổi `iot.Alert` → `iot.Alerts` (kiểm tra tên cột người xử lý trong `02_tables_iot.sql`).
- Theo QĐ-1: FK `MachineId` của `inventory.Slot`, `sales.[Order]`, `report.DailySalesSummary`, `inventory.RestockEvent`, `auth.UserMachine` trỏ về bảng máy đã chốt.
- Thêm FK mới: `RestockEvent.UserId → auth.[User]`, `audit.ChangeLog.UserId → auth.[User]`.
- Mỗi FK bọc `IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = ...)` + kiểm tra bảng tồn tại.

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Hỏi Anh trước khi sửa**
- Nhánh `check-nv-chua-hoan-thien-xa` của Anh có sửa file này. Nhắn Anh: ai merge trước? Đề xuất: **Anh merge trước (FV-15)**, bạn tạo nhánh sau khi đã merge để sửa trên bản mới nhất.

**Bước 2. Mẫu FK an toàn**
```sql
IF OBJECT_ID(N'inventory.RestockEvent', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_inventory_RestockEvent_User')
  ALTER TABLE inventory.RestockEvent WITH CHECK
    ADD CONSTRAINT FK_inventory_RestockEvent_User FOREIGN KEY (UserId) REFERENCES auth.[User](UserId);
GO
```

**Bước 3. Chạy kiểm tra**
- SSMS: CSDL trống → 00 → 01 → toàn bộ 02 → 03. **Không được có dòng đỏ.** Sau đó: `SELECT name, OBJECT_NAME(parent_object_id) FROM sys.foreign_keys ORDER BY 2;` và chụp ảnh danh sách.

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/03_foreign_keys.sql` (sửa)
- `sql/02_tables_iot.sql` (đọc tên bảng/cột)

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Phối hợp:** Anh (cùng sửa file – Anh merge trước), Dũng (tên bảng máy/cảnh báo), Huy (bảng mới inventory).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Chạy từ đầu | CSDL trống, 00 → 03 | Không lỗi |
| 2 | Chạy lại 03 | F5 lần 2 | Không lỗi, không tạo trùng FK |

**Kết quả cần lưu lại:** Ảnh danh sách sys.foreign_keys.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] 03_foreign_keys chạy sạch trên CSDL trống
- [ ] Không còn tham chiếu bảng không tồn tại
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
git checkout -b fix/SCRUM-201-foreign-keys
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/03_foreign_keys.sql
git commit -m "fix(sql): 03_foreign_keys tham chiếu đúng bảng hiện có"
```
5. **Push**
```powershell
git pull origin main
git push -u origin fix/SCRUM-201-foreign-keys
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: fix/SCRUM-201-foreign-keys`.
7. **Mô tả PR:** tiêu đề `[SCRUM-201] Sửa 03_foreign_keys.sql cho khớp bảng thật (đang lỗi khi chạy từ đầu)`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-201`; dán ảnh bằng chứng: Ảnh danh sách sys.foreign_keys.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d fix/SCRUM-201-foreign-keys
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-201 |
| Branch | `fix/SCRUM-201-foreign-keys` |
| Commit | `fix(sql): 03_foreign_keys tham chiếu đúng bảng hiện có` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/03_foreign_keys.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 09/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-201
- **Bằng chứng hoàn thành:** Ảnh danh sách sys.foreign_keys
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.

---

## TASK FV-08 (SCRUM-202) – 10_procs_auth.sql: sp_Login, sp_CreateUser, sp_ChangePassword, sp_AssignMachine, sp_DeactivateUser + fn_HashPassword

| Thuộc tính | Giá trị |
|---|---|
| Thời gian | 10/11/2026 → 12/11/2026 |
| Mức ưu tiên | Highest |
| Epic | E1 – Người dùng & Bảo mật (auth, audit) |
| Phụ thuộc | FV-06 (SCRUM-200) (Toàn) |
| Người hỗ trợ | Huy |

### 1. MỤC TIÊU
10_procs_auth.sql: sp_Login, sp_CreateUser, sp_ChangePassword, sp_AssignMachine, sp_DeactivateUser + fn_HashPassword. Hoàn thành khi đạt toàn bộ checklist ở mục 8.

### 2. BỐI CẢNH
Không có `auth.sp_Login` thì **không ai đăng nhập được** khi chạy app với SQL Server thật – đây là việc chặn cả nhóm. API gọi `sp_Login` bằng tài khoản Kiosk (quyền thấp nhất) và cần **2 bảng kết quả**: thông tin user và danh sách máy được giao.

### 3. PHẠM VI CÔNG VIỆC
- Tạo `sql/10_procs_auth.sql`.
- Function `auth.fn_HashPassword(@Password NVARCHAR(100), @Salt UNIQUEIDENTIFIER)` trả `HASHBYTES('SHA2_256', ...)`.
- 5 procedure đúng tham số, mã lỗi 50001–50031 như fakeDb.js dòng 87–144.
- Seed 3 tài khoản demo: admin/Admin@2026, operator01/Operator@2026, kiosk01/Kiosk@2026 (gọi sp_CreateUser).

### 4. CÁC BƯỚC THỰC HIỆN
**Bước 1. Hàm băm**
```sql
CREATE OR ALTER FUNCTION auth.fn_HashPassword (@Password NVARCHAR(100), @Salt UNIQUEIDENTIFIER)
RETURNS NVARCHAR(64) WITH SCHEMABINDING AS
BEGIN
  RETURN CONVERT(NVARCHAR(64), HASHBYTES('SHA2_256', @Password + N'|' + CONVERT(NVARCHAR(36), @Salt)), 2);
END
GO
```
- **Lưu ý:** không bao giờ lưu mật khẩu gốc.

**Bước 2. sp_Login trả 2 bảng**
```sql
CREATE OR ALTER PROCEDURE auth.sp_Login @Username NVARCHAR(50), @Password NVARCHAR(100), @ClientInfo NVARCHAR(200) = NULL
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @UserId INT, @Ok BIT = 0, @Msg NVARCHAR(200);
  -- 1) tìm user, 2) sai thì FailedLogins += 1, >= 5 thì IsActive = 0, 3) đúng thì FailedLogins = 0, LastLoginAt = now
  -- 4) INSERT auth.LoginHistory (UserId, Username, IsSuccess, FailReason, UserAgent)
  SELECT @Ok AS Success, @Msg AS Message, u.UserId, u.Username, u.FullName, r.RoleName
  FROM (SELECT 1 x) d LEFT JOIN auth.[User] u ON u.UserId = @UserId AND @Ok = 1
  LEFT JOIN auth.UserRole ur ON ur.UserId = u.UserId LEFT JOIN auth.Role r ON r.RoleId = ur.RoleId;
  SELECT MachineId FROM auth.UserMachine WHERE UserId = @UserId AND @Ok = 1;
END
```
- **Lưu ý:** sai mật khẩu **không THROW** mà trả `Success = 0` + thông báo (API tự trả 401). Câu thông báo copy đúng từ fakeDb.js dòng 104–110.

**Bước 3. 4 procedure còn lại**
- `sp_CreateUser`: 50001 (tên < 3 ký tự), 50002 (mật khẩu < 8), 50003 (trùng tên), 50004 (vai trò sai), 50005 (họ tên trống).
- `sp_ChangePassword`: 50010, 50011 (mật khẩu cũ sai), 50002.
- `sp_AssignMachine`: 50020, 50021 (chỉ Operator/Kiosk), 50022 (máy không tồn tại); trả danh sách máy kèm `Serial`.
- `sp_DeactivateUser @UserId, @Activate BIT`: 50030, 50031 (không tự khóa chính mình – so với `SESSION_CONTEXT(N'UserId')`). Không xóa user, chỉ đổi `IsActive`.

**Bước 4. Seed tài khoản demo**
Cuối file:
```sql
IF NOT EXISTS (SELECT 1 FROM auth.[User] WHERE Username = N'admin')
  EXEC auth.sp_CreateUser @Username = N'admin', @Password = N'Admin@2026', @FullName = N'Nguyễn Phương Huy', @RoleName = N'Admin', @Email = N'admin@freshvend.vn';
```
Tương tự operator01, operator02, kiosk01…kiosk05 (mật khẩu theo `app/README.md`).

**Bước 5. Chạy thử**
```sql
EXEC auth.sp_Login @Username = N'admin', @Password = N'Admin@2026';   -- Success = 1, bảng 2 rỗng
EXEC auth.sp_Login @Username = N'admin', @Password = N'sai';          -- Success = 0, còn 4 lần
```

### 5. FILE VÀ MODULE LIÊN QUAN
- `sql/10_procs_auth.sql` (tạo mới)
- `app/api/src/routes/auth.js` (tham số API truyền vào)
- `app/api/test/fakeDb.js dòng 87–144`

### 6. PHỐI HỢP VỚI THÀNH VIÊN KHÁC
**Đầu ra cho:** cả nhóm (đăng nhập với SQL thật), Huy (FV-20), Anh (ca test auth trong sp_RunAllTests).

### 7. TESTING
Thực hiện trong SSMS/trình duyệt như cột *Input*; lưu ảnh kết quả vào PR.

| # | Test case | Input | Expected output |
|---|---|---|---|
| 1 | Đăng nhập đúng | admin / Admin@2026 | Success=1, RoleName=Admin |
| 2 | Sai 5 lần | Gọi sai 5 lần | Lần 5: IsActive=0, thông báo khóa |
| 3 | Tạo trùng | sp_CreateUser admin | THROW 50003 |
| 4 | Tự khóa | sp_DeactivateUser chính mình | THROW 50031 |

**Kết quả cần lưu lại:** Ảnh SSMS 2 bảng kết quả của sp_Login.

### 8. TIÊU CHÍ NGHIỆM THU
- [ ] sp_Login trả đúng 2 bảng kết quả
- [ ] Mật khẩu chỉ lưu dạng băm + muối
- [ ] Đủ mã lỗi 50001–50031
- [ ] 3 tài khoản demo đăng nhập được
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
git checkout -b feature/SCRUM-202-auth-procs
```
4. **Commit** (chỉ add file của task)
```powershell
git status
git add sql/10_procs_auth.sql
git commit -m "feat(sql-auth): 5 procedure auth + fn_HashPassword"
```
5. **Push**
```powershell
git pull origin main
git push -u origin feature/SCRUM-202-auth-procs
```
6. **Tạo Pull Request:** mở link GitHub in ra sau khi push → `base: main` ← `compare: feature/SCRUM-202-auth-procs`.
7. **Mô tả PR:** tiêu đề `[SCRUM-202] 10_procs_auth.sql: sp_Login, sp_CreateUser, sp_ChangePassword, sp_AssignMachine, sp_DeactivateUser + fn_HashPassword`; nội dung theo mẫu (`Cach_su_dung_GITHUB.md` mục 5); *Related Jira Task*: `SCRUM-202`; dán ảnh bằng chứng: Ảnh SSMS 2 bảng kết quả của sp_Login.
8. **Kiểm tra conflict:** phải thấy *This branch has no conflicts*. Có conflict → `git fetch origin` → `git merge origin/main` → sửa → commit → push.
9. **Nhờ Leader review:** Reviewers → PhuongHuyN; chuyển task Jira sang *In Review*.
10. **Merge khi được chấp thuận** (Leader *Squash and merge*), rồi:
```powershell
git checkout main
git pull origin main
git branch -d feature/SCRUM-202-auth-procs
```

| Nội dung | Thông tin |
|---|---|
| Jira Issue | SCRUM-202 |
| Branch | `feature/SCRUM-202-auth-procs` |
| Commit | `feat(sql-auth): 5 procedure auth + fn_HashPassword` |
| Pull Request | (dán link PR) |
| Reviewer | Huy (Leader) |
| PR Status | Open / Review / Approved / Merged |
| Merge Date | (dd/mm/2026) |

### 10. DELIVERABLE
- sql/10_procs_auth.sql

### 11. DEADLINE VÀ BÁO CÁO
- **Deadline:** 12/11/2026, 22h
- **Kết quả cần báo cáo:** tình trạng mục 8 + link PR, comment vào task Jira SCRUM-202
- **Bằng chứng hoàn thành:** Ảnh SSMS 2 bảng kết quả của sp_Login
- **Những vấn đề cần báo Leader:** bị chặn bởi task phụ thuộc quá 1 ngày; phải sửa file của module khác; mã lỗi/tên cột lệch với `fakeDb.js`; không chạy được trên CSDL trống.
