# Báo cáo tích hợp app ↔ SQL Server thật (FV-20 / SCRUM-214)

| Mục | Nội dung |
|---|---|
| Người thực hiện | Nguyễn Phương Huy (TV2, Leader) |
| Ngày chạy | 12/11/2026 16:23 (giờ VN) |
| Môi trường | Windows 11, SQL Server 2025 Enterprise Developer (17.0.1000.7), Node.js 26.13, app `DB_MODE=sqlserver` |
| Mã nguồn | `main` sau PR #43 (`de3f780`) |
| Cách chạy | `npm start` (app/api) + `node tools/smoke-sqlserver.js` — 26 lệnh gọi API **chỉ đọc**, 3 tài khoản (admin, operator01, kiosk01) |
| Bằng chứng | [`docs/evidence/SCRUM-214-smoke.md`](evidence/SCRUM-214-smoke.md) (file do script tự ghi) |

## 1. Kết quả tổng hợp: 19/26 đạt

| Module | Phụ trách | Đạt | Lỗi | Nguyên nhân | Task xử lý |
|---|---|---|---|---|---|
| auth | Huy (FV-21) | 4/6 | 2 | Thiếu `auth.vw_UserPermissions`, `audit.vw_LoginActivity` (lỗi 208 Invalid object name) | **SCRUM-215** (Huy) |
| inventory | Huy | 6/6 | 0 | — | — |
| sales | Thiên Ân | 3/4 | 1 | `GET /api/kiosk/menu` cần `iot.vw_MachineHealth` (thuộc iot) — **không phải lỗi của sales** | SCRUM-259 (Dũng) |
| iot | Dũng | 0/4 | 4 | Thiếu `iot.vw_MachineHealth`, `iot.vw_OpenAlerts`, `iot.fn_RecentTelemetry` | **SCRUM-259** (Dũng) |
| report | Xuân Anh | 4/4 | 0 | — (2 view trả 0 dòng vì chưa có đơn hàng thật, không phải lỗi) | — |
| security | Huy (FV-22) | 2/2 | 0 | Operator bị chặn báo cáo (403), Kiosk bị chặn quản lý sản phẩm (403) | — |

**Kết luận:** kết nối, đăng nhập 3 vai trò, phân quyền 4 login và Row-Level Security chạy đúng trên SQL thật.
Toàn bộ 7 lỗi cùng một loại — **thiếu đối tượng CSDL (lỗi 208)** ở 2 nhóm: view auth/audit (SCRUM-215)
và 3 đối tượng iot (SCRUM-259). Không có lỗi sai tham số, sai tên cột hay sai quyền.

## 2. Những điểm đã kiểm chứng đạt

| Hạng mục | Bằng chứng |
|---|---|
| App kết nối SQL Server bằng login SQL (Mixed Mode, TCP 1433) | `/api/health` → `ok: true, mode: sqlserver` |
| `auth.sp_Login` chạy qua login `fv_kiosk_app` cho cả 3 vai trò | Dòng 1–3 |
| Row-Level Security: operator01 chỉ thấy 3 máy được giao | Dòng 12: 36 cột = 3 máy × 12 (Admin thấy 60 = 5 × 12) |
| DENY schema report cho Operator → API trả 403 | Dòng 25 |
| Kiosk không gọi được API quản lý sản phẩm → 403 | Dòng 26 |
| Toàn bộ view/TVF inventory trả đúng dữ liệu seed | Dòng 7–11 (36 sản phẩm, 60 ngăn, 35 lô, 18 dòng sắp/đã hết hạn) |

## 3. Vấn đề chung giữa các module (cần nhóm quyết định)

| # | Vấn đề | Ảnh hưởng | Đề xuất |
|---|---|---|---|
| V1 | **Lệch múi giờ.** `app/api/src/db.js` đặt `useUTC: false` (coi giờ trong CSDL là giờ VN). inventory, sales, auth lưu `SYSUTCDATETIME()` (UTC); iot lưu `SYSDATETIME()` (giờ VN) | Giờ hết hạn, giờ tạo đơn… của inventory/sales hiện **sớm hơn thực tế 7 tiếng** trên giao diện; giờ iot hiện đúng | Họp chốt 1 chuẩn: **lưu UTC ở mọi module + `useUTC: true`** (ít sửa nhất: đổi `SYSDATETIME()` của iot và 1 dòng `db.js`) |
| V2 | `03_foreign_keys.sql` vẫn tham chiếu bảng cũ (`iot.Device`, `iot.Alert`) | Không cài được cả hệ thống từ máy trống bằng 1 lần chạy | SCRUM-201 (Xuân Anh) |
| V3 | Hai bảng máy `inventory.Machine` và `iot.Machines` (QĐ-1) | Cảnh báo của inventory/sales phải nối máy qua `Serial = MachineCode`; nhánh `tv4-iot` chưa gộp được | SCRUM-207 (Dũng) — khi đổi, gỡ RLS trước (xem đầu file `40_security.sql`) |

## 4. Việc tiếp theo

1. SCRUM-259 (Dũng): tạo 3 đối tượng iot → chạy lại `sql/40_security.sql` để cấp quyền cho chúng.
2. SCRUM-215 (Huy): `20_objects_auth.sql` (2 view + trigger ChangeLog).
3. Chạy lại `node tools/smoke-sqlserver.js` → mục tiêu **26/26**, cập nhật bảng mục 1.
4. Kiểm thử luồng **ghi** (tạo đơn → thanh toán → nhả hàng; châm hàng) trên SQL thật — làm trong SCRUM-226 / SCRUM-223.

## 5. Cách chạy lại

```powershell
# Cửa sổ 1
cd $HOME\Desktop\REPO_NH-M\app\api
npm install
(Get-Content .env.example) -replace '^DB_MODE=demo$','DB_MODE=sqlserver' | Set-Content .env -Encoding utf8
npm start
# Cửa sổ 2
cd $HOME\Desktop\REPO_NH-M\app\api
node tools/smoke-sqlserver.js
```
Yêu cầu trước: CSDL dựng đủ theo bảng thứ tự trong `README.md` (00 → 30, cuối cùng `40_security.sql`),
SQL Server bật Mixed Mode và TCP/IP cổng 1433.
