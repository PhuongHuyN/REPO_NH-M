/* =====================================================================
   FreshVend API – khung ứng dụng (TV2 dựng khung)
   - Xác thực: Bearer JWT (người dùng) hoặc X-Device-Key (thiết bị)
   - Phân quyền lớp 1 ở API (meta.roles); lớp 2 trong SQL Server (login riêng mỗi vai trò + RLS)
   - Lỗi THROW 50xxx của procedure được chuyển thành mã HTTP phù hợp
   ===================================================================== */
const config = require('./config');
const db = require('./db');
const jwt = require('./lib/jwt');
const { Router } = require('./lib/router');
const { HttpError, readJson, sendJson, serveStatic } = require('./lib/http');
const { mapSqlError } = require('./lib/errors');
const { buildSpec, swaggerHtml } = require('./openapi');

const router = new Router();
require('./routes/auth')(router);
require('./routes/inventory')(router);
require('./routes/sales')(router);
require('./routes/iot')(router);
require('./routes/report')(router);

// Health check + tài liệu
router.get('/api/health', { auth: 'public', tag: 'Hệ thống', summary: 'Kiểm tra API và kết nối CSDL' }, async () => {
  const info = await db.ping();
  return { status: 'ok', db: info, time: new Date().toISOString() };
});
router.get('/api/openapi.json', { auth: 'public', tag: 'Hệ thống', summary: 'Tài liệu OpenAPI 3' }, async () => buildSpec(router));

const SENT = Symbol('sent');

function authenticate(req, route) {
  const mode = route.meta.auth || 'user';
  if (mode === 'public') return null;
  const deviceKey = req.headers['x-device-key'];
  if ((mode === 'device' || mode === 'user-or-device') && deviceKey) {
    if (deviceKey !== config.deviceApiKey) throw new HttpError(401, 'X-Device-Key không hợp lệ', 'BAD_DEVICE_KEY');
    return { sub: null, role: 'Device', username: 'device' };
  }
  if (mode === 'device') throw new HttpError(401, 'Thiếu X-Device-Key', 'NO_DEVICE_KEY');
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  const user = token && jwt.verify(token, config.jwtSecret);
  if (!user) throw new HttpError(401, 'Chưa đăng nhập hoặc phiên đã hết hạn', 'UNAUTHORIZED');
  if (route.meta.roles && !route.meta.roles.includes(user.role)) {
    throw new HttpError(403, `Vai trò ${user.role} không được phép thực hiện thao tác này`, 'FORBIDDEN');
  }
  return user;
}

function makeContext(req, res, params, query, body, user) {
  const ip = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').toString().split(',')[0].trim();
  const role = user?.role || 'Kiosk';
  const opts = { userId: user?.sub ?? null };
  return {
    req, res, params, query, body, user, ip, status: 200,
    exec: (proc, p = {}, o = {}) => db.exec(role, proc, p, { ...opts, ...o }),
    view: (name, q = {}) => db.view(role, name, q, opts),
    tvf: (name, args = [], q = {}) => db.tvf(role, name, args, q, opts),
    sent: () => SENT,
  };
}

// ---------- Server-Sent Events: đẩy tình trạng máy mỗi 2 giây (yêu cầu dashboard < 2s) ----------
function handleStream(req, res, url) {
  const user = jwt.verify(url.searchParams.get('token'), config.jwtSecret);
  if (!user || !['Admin', 'Operator'].includes(user.role)) { sendJson(res, 401, { error: 'UNAUTHORIZED' }); return; }
  res.writeHead(200, { 'Content-Type': 'text/event-stream; charset=utf-8', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
  let busy = false;
  const push = async () => {
    if (busy) return;
    busy = true;
    try {
      const [machines, alerts] = await Promise.all([
        db.view(user.role, 'iot.vw_MachineHealth', { orderBy: 'MachineId' }, { userId: user.sub }),
        db.view(user.role, 'iot.vw_OpenAlerts', { orderBy: 'CreatedAt DESC', top: 20 }, { userId: user.sub }),
      ]);
      res.write(`event: health\ndata: ${JSON.stringify({ at: new Date().toISOString(), machines, alerts })}\n\n`);
    } catch (e) {
      res.write(`event: error\ndata: ${JSON.stringify({ message: e.message })}\n\n`);
    } finally { busy = false; }
  };
  push();
  const timer = setInterval(push, 2000);
  req.on('close', () => clearInterval(timer));
}

async function handle(req, res) {
  const started = Date.now();
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Device-Key');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }

  const url = new URL(req.url, 'http://localhost');
  if (!url.pathname.startsWith('/api/') && url.pathname !== '/api-docs') return serveStatic(config.webDir, req, res, config.uploadDir);
  if (url.pathname === '/api-docs') { res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' }); return res.end(swaggerHtml); }
  if (url.pathname === '/api/stream') return handleStream(req, res, url);

  let status = 500;
  try {
    const { route, params, methodNotAllowed } = router.match(req.method, url.pathname);
    if (!route) throw new HttpError(methodNotAllowed ? 405 : 404, methodNotAllowed ? 'Phương thức không được hỗ trợ' : 'Không tìm thấy API', 'NOT_FOUND');
    const user = authenticate(req, route);
    const body = await readJson(req, route.meta.bodyLimit);
    const query = Object.fromEntries(url.searchParams.entries());
    const ctx = makeContext(req, res, params, query, body, user);
    const result = await route.handler(ctx);
    status = ctx.status;
    if (result !== SENT) sendJson(res, ctx.status, result === undefined ? { ok: true } : result);
  } catch (err) {
    const mapped = err instanceof HttpError ? { status: err.status, code: err.code, message: err.message } : mapSqlError(err);
    if (mapped) { status = mapped.status; sendJson(res, mapped.status, { error: mapped.code, message: mapped.message }); }
    else {
      console.error('[LỖI]', err);
      sendJson(res, 500, { error: 'INTERNAL', message: 'Lỗi máy chủ: ' + err.message });
    }
  } finally {
    if (process.env.LOG_REQUESTS !== 'false') {
      console.log(`${new Date().toISOString()} ${req.method} ${url.pathname} -> ${res.statusCode || status} (${Date.now() - started} ms)`);
    }
  }
}

module.exports = { handle, router };
