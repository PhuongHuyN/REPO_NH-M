// Chuyển lỗi SQL Server thành mã HTTP + thông báo tiếng Việt.
// Lỗi nghiệp vụ do procedure THROW 50xxx: thông điệp đã là tiếng Việt, giữ nguyên.
const NOT_FOUND = new Set([50010, 50020, 50022, 50030, 50103, 50105, 50107, 50110, 50115, 50202,
  50205, 50212, 50216, 50302, 50311, 50320, 50330, 50340]);
const CONFLICT = new Set([50003, 50101, 50104, 50106, 50109, 50117, 50118, 50201, 50203, 50206, 50207, 50210,
  50213, 50214, 50215, 50217, 50218, 50219, 50301, 50321, 50331]);
const PERMISSION = new Set([229, 230, 262, 297, 300, 916, 33504]);  // permission denied / RLS block

function sqlNumber(err) {
  return err.number ?? err.originalError?.info?.number ?? err.originalError?.number;
}

function mapSqlError(err) {
  const n = sqlNumber(err);
  const msg = err.originalError?.info?.message || err.message || 'Lỗi không xác định';
  if (n >= 50000 && n < 51000) {
    const status = NOT_FOUND.has(n) ? 404 : CONFLICT.has(n) ? 409 : 400;
    return { status, code: `DB_${n}`, message: msg };
  }
  if (PERMISSION.has(n)) return { status: 403, code: `DB_${n}`, message: 'CSDL từ chối quyền truy cập cho vai trò hiện tại (RBAC)' };
  if (n === 2627 || n === 2601) return { status: 409, code: `DB_${n}`, message: 'Dữ liệu bị trùng (vi phạm UNIQUE)' };
  if (n === 547) return { status: 400, code: 'DB_547', message: 'Dữ liệu vi phạm ràng buộc CHECK / khóa ngoại' };
  if (n === 1205) return { status: 409, code: 'DB_1205', message: 'Giao dịch bị chọn làm nạn nhân deadlock, vui lòng thử lại' };
  if (['ESOCKET', 'ELOGIN', 'ETIMEOUT', 'ECONNCLOSED', 'ENOTOPEN', 'EINSTLOOKUP'].includes(err.code)) {
    return { status: 503, code: 'DB_UNAVAILABLE', message: 'Không kết nối được SQL Server: ' + msg };
  }
  return null;
}

module.exports = { mapSqlError, sqlNumber };
