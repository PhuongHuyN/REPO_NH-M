/* =====================================================================
   TV1 – Người dùng & Bảo mật  (/api/auth/*)
   SP: auth.sp_Login, sp_CreateUser, sp_ChangePassword, sp_AssignMachine, sp_DeactivateUser
   View: auth.vw_UserPermissions, audit.vw_LoginActivity
   ===================================================================== */
const db = require('../db');
const jwt = require('../lib/jwt');
const v = require('../lib/validate');
const { HttpError } = require('../lib/http');
const config = require('../config');

// Chống dò mật khẩu ở tầng API: tối đa 10 lần SAI / phút / IP (CSDL còn khóa sau 5 lần sai / tài khoản)
const failures = new Map();
function recentFailures(ip) {
  const now = Date.now();
  const list = (failures.get(ip) || []).filter((t) => now - t < 60000);
  failures.set(ip, list);
  return list;
}
function rateLimit(ip) {
  if (recentFailures(ip).length >= 10) throw new HttpError(429, 'Đăng nhập sai quá nhiều lần, thử lại sau 1 phút', 'RATE_LIMIT');
}
function recordFailure(ip) { recentFailures(ip).push(Date.now()); }

module.exports = (r) => {
  r.post('/api/auth/login', {
    auth: 'public', tag: 'Auth (TV1)', summary: 'Đăng nhập – trả JWT + danh sách máy được giao',
    body: { username: 'admin', password: 'Admin@2026' },
  }, async (ctx) => {
    rateLimit(ctx.ip);
    const username = v.str(ctx.body.username, 'Tên đăng nhập', { min: 3, max: 50 });
    const password = v.str(ctx.body.password, 'Mật khẩu', { min: 1, max: 128 });
    // Đăng nhập dùng pool Kiosk (quyền tối thiểu: chỉ EXEC auth.sp_Login)
    const r1 = await db.exec('Kiosk', 'auth.sp_Login', {
      Username: db.T.vstr(username), Password: db.T.str(password),
      ClientInfo: db.T.str(`${ctx.ip} | ${(ctx.req.headers['user-agent'] || '').slice(0, 150)}`),
    });
    const row = r1.recordsets[0]?.[0];
    if (!row || !row.Success) {
      recordFailure(ctx.ip);
      throw new HttpError(401, row?.Message || 'Sai tên đăng nhập hoặc mật khẩu', 'LOGIN_FAILED');
    }
    const machines = (r1.recordsets[1] || []).map((m) => m.MachineId);
    const user = { sub: row.UserId, username: row.Username, fullName: row.FullName, role: row.RoleName, machines };
    // Màn hình kiosk chạy liên tục nên phiên dài hơn (mặc định 30 ngày, đặt KIOSK_SESSION_HOURS)
    const hours = user.role === 'Kiosk' ? config.kioskSessionHours : config.jwtExpiresHours;
    const token = jwt.sign(user, config.jwtSecret, hours * 3600);
    return { token, user, expiresInHours: hours };
  });

  r.get('/api/auth/me', { tag: 'Auth (TV1)', summary: 'Thông tin người dùng hiện tại (từ JWT)' },
    async (ctx) => ({ user: ctx.user }));

  r.put('/api/auth/password', {
    tag: 'Auth (TV1)', summary: 'Đổi mật khẩu', roles: ['Admin', 'Operator', 'Kiosk'],
    body: { oldPassword: 'Operator@2026', newPassword: 'Operator@2027' },
  }, async (ctx) => {
    const r1 = await ctx.exec('auth.sp_ChangePassword', {
      UserId: db.T.int(ctx.user.sub),
      OldPassword: db.T.str(v.str(ctx.body.oldPassword, 'Mật khẩu cũ', { min: 1 })),
      NewPassword: db.T.str(v.str(ctx.body.newPassword, 'Mật khẩu mới', { min: 8, max: 128 })),
    });
    return r1.recordset[0];
  });

  r.get('/api/auth/users', { tag: 'Auth (TV1)', summary: 'Danh sách tài khoản + máy được giao', roles: ['Admin'] },
    async (ctx) => ctx.view('auth.vw_UserPermissions', { orderBy: 'UserId', where: { RoleName: ctx.query.role } }));

  r.post('/api/auth/users', {
    tag: 'Auth (TV1)', summary: 'Tạo tài khoản', roles: ['Admin'],
    body: { username: 'operator03', password: 'Operator@2026', fullName: 'Lê Văn Cường', role: 'Operator', email: 'cuong@freshvend.vn' },
  }, async (ctx) => {
    const b = ctx.body;
    const r1 = await ctx.exec('auth.sp_CreateUser', {
      Username: db.T.vstr(v.str(b.username, 'Tên đăng nhập', { min: 3, max: 50 })),
      Password: db.T.str(v.str(b.password, 'Mật khẩu', { min: 8, max: 128 })),
      FullName: db.T.str(v.str(b.fullName, 'Họ tên', { min: 1, max: 100 })),
      RoleName: db.T.str(v.oneOf(b.role, 'Vai trò', ['Admin', 'Operator', 'Kiosk'])),
      Email: db.T.vstr(v.str(b.email, 'Email', { max: 100, optional: true }) ?? null),
    });
    ctx.status = 201;
    return r1.recordset[0];
  });

  r.put('/api/auth/users/:id/active', {
    tag: 'Auth (TV1)', summary: 'Khóa / mở khóa tài khoản', roles: ['Admin'], body: { active: false },
  }, async (ctx) => {
    const r1 = await ctx.exec('auth.sp_DeactivateUser', {
      UserId: db.T.int(v.int(ctx.params.id, 'UserId', { min: 1 })),
      Activate: db.T.bit(v.bool(ctx.body.active)),
    });
    return r1.recordset[0];
  });

  r.post('/api/auth/users/:id/machines', {
    tag: 'Auth (TV1)', summary: 'Giao / gỡ máy cho Operator hoặc Kiosk', roles: ['Admin'], body: { machineId: 1, unassign: false },
  }, async (ctx) => {
    const r1 = await ctx.exec('auth.sp_AssignMachine', {
      UserId: db.T.int(v.int(ctx.params.id, 'UserId', { min: 1 })),
      MachineId: db.T.int(v.int(ctx.body.machineId, 'MachineId', { min: 1 })),
      Unassign: db.T.bit(v.bool(ctx.body.unassign)),
    });
    return r1.recordset;
  });

  r.get('/api/auth/login-activity', { tag: 'Auth (TV1)', summary: 'Thống kê đăng nhập theo ngày', roles: ['Admin'] },
    async (ctx) => ctx.view('audit.vw_LoginActivity', { orderBy: 'LoginDate DESC', top: 30 }));
};
