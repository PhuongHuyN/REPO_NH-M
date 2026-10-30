#!/usr/bin/env node
/* =====================================================================
   KIỂM TRA ĐỒNG BỘ FE ⇄ BE  —  chạy:  npm run check   (hoặc node tools/check-sync.js)
   Không cần SQL Server, không cần cài thêm thư viện.
   1. Mọi lời gọi API trong web/js/** và simulator/ phải khớp 1 route thật của api/src (đúng METHOD + đường dẫn)
   2. Trang (web/js/pages) cho vai trò nào thì API trang đó gọi cũng phải cho vai trò đó (cảnh báo)
   3. Mọi biến môi trường đọc trong api/src/config.js phải có trong api/.env.example
   4. Mọi trang trong web/js/pages phải được khai báo trong web/js/admin.js
   5. Phiên bản Node >= 18
   Có lỗi -> thoát mã 1 (CI đỏ, không được merge).
   ===================================================================== */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const rel = (p) => path.relative(ROOT, p).replace(/\\/g, '/');
const errors = [];
const warns = [];

// ---------- 5. Node ----------
const major = Number(process.versions.node.split('.')[0]);
if (major < 18) errors.push(`Node.js ${process.versions.node} quá cũ – cần >= 18 (xem .nvmrc)`);

// ---------- Lấy danh sách route THẬT từ router của API ----------
process.env.LOG_REQUESTS = 'false';
const { router } = require(path.join(ROOT, 'api/src/app.js'));
const SPECIAL = [{ method: 'GET', path: '/api/stream', roles: ['Admin', 'Operator'] }]; // SSE xử lý riêng trong app.js
const routeOf = (method, p) => {
  if (SPECIAL.some((s) => s.method === method && s.path === p)) return { meta: { roles: ['Admin', 'Operator'] }, path: p };
  const m = router.match(method, p);
  return m.route ? m.route : null;
};

// ---------- 1. Quét lời gọi API phía FE + bộ điều khiển máy ----------
function walk(dir, out = []) {
  for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, f.name);
    if (f.isDirectory()) { if (f.name !== 'node_modules' && f.name !== 'uploads') walk(p, out); }
    else if (f.name.endsWith('.js')) out.push(p);
  }
  return out;
}
const files = [...(fs.existsSync(path.join(ROOT, 'web/js')) ? walk(path.join(ROOT, 'web/js')) : []), path.join(ROOT, 'simulator/esp32.js')].filter(fs.existsSync);
const CALL_PATTERNS = [
  { re: /\bapi\.(get|post|put|delete|download)\(\s*(['"`])((?:(?!\2).)*?)\2/g, method: (m) => (m[1] === 'download' ? 'GET' : m[1].toUpperCase()), url: (m) => m[3] },
  { re: /\bcall\(\s*'(GET|POST|PUT|DELETE)'\s*,\s*(['"`])((?:(?!\2).)*?)\2/g, method: (m) => m[1], url: (m) => m[3] },
  { re: /new EventSource\(\s*(['"`])((?:(?!\1).)*?)\1/g, method: () => 'GET', url: (m) => m[2] },
];
const calls = [];
for (const file of files) {
  const src = fs.readFileSync(file, 'utf8');
  for (const pat of CALL_PATTERNS) {
    for (const m of src.matchAll(pat.re)) {
      const raw = pat.url(m);
      if (!raw.startsWith('/api/')) continue;
      const clean = raw.replace(/\$\{[^}]*\}/g, '1').split('?')[0];
      const line = src.slice(0, m.index).split('\n').length;
      calls.push({ file, line, method: pat.method(m), raw, clean });
    }
  }
}
for (const c of calls) {
  const r = routeOf(c.method, c.clean);
  if (!r) {
    const other = ['GET', 'POST', 'PUT', 'DELETE'].filter((x) => x !== c.method && routeOf(x, c.clean));
    errors.push(`${rel(c.file)}:${c.line}  ${c.method} ${c.raw}  → API không có route này${other.length ? ` (chỉ có ${other.join('/')})` : ''}`);
  }
  c.route = r;
}

// ---------- 2. Vai trò trang ⇄ vai trò API ----------
for (const c of calls.filter((x) => x.route && x.file.includes(`${path.sep}pages${path.sep}`))) {
  const src = fs.readFileSync(c.file, 'utf8');
  const m = src.match(/roles:\s*\[([^\]]*)\]/);
  if (!m) continue;
  // Dòng gọi API có chú thích "// @roles Admin" = nút đó đã được ẩn với vai trò khác
  const lineText = src.split('\n')[c.line - 1] || '';
  const tag = lineText.match(/@roles\s+([\w, ]+)/);
  const pageRoles = tag ? tag[1].split(/[\s,]+/).filter(Boolean) : [...m[1].matchAll(/'(\w+)'/g)].map((x) => x[1]);
  const apiRoles = c.route.meta && c.route.meta.roles;
  if (!apiRoles) continue;
  const missing = pageRoles.filter((r) => !apiRoles.includes(r));
  if (missing.length) warns.push(`${rel(c.file)}:${c.line}  trang cho ${missing.join(', ')} nhưng ${c.method} ${c.clean.replace(/\/1(?=\/|$)/g, '/:id')} chỉ cho ${apiRoles.join(', ')} → nhớ ẩn nút / bắt lỗi 403`);
}

// ---------- 3. Biến môi trường ----------
const cfg = fs.readFileSync(path.join(ROOT, 'api/src/config.js'), 'utf8');
const usedKeys = new Set([...cfg.matchAll(/\b(?:env|bool|demoPay)\('([A-Z0-9_]+)'/g)].map((m) => m[1]));
const exPath = path.join(ROOT, 'api/.env.example');
const exKeys = new Set(fs.existsSync(exPath) ? [...fs.readFileSync(exPath, 'utf8').matchAll(/^\s*([A-Z0-9_]+)\s*=/gm)].map((m) => m[1]) : []);
const OPTIONAL_ENV = new Set(['UPLOAD_DIR', 'WEB_DIR']); // có giá trị mặc định hợp lý, không bắt buộc khai báo
for (const k of usedKeys) if (!exKeys.has(k) && !OPTIONAL_ENV.has(k)) errors.push(`api/.env.example thiếu biến ${k} (đang dùng trong api/src/config.js)`);
if (fs.existsSync(path.join(ROOT, 'api/.env'))) {
  const envKeys = new Set([...fs.readFileSync(path.join(ROOT, 'api/.env'), 'utf8').matchAll(/^\s*([A-Z0-9_]+)\s*=/gm)].map((m) => m[1]));
  const lack = [...exKeys].filter((k) => !envKeys.has(k));
  if (lack.length) warns.push(`api/.env của bạn thiếu ${lack.join(', ')} → mở api/.env.example chép thêm (đang dùng giá trị mặc định)`);
}

// ---------- 4. Trang đã khai báo trong admin.js ----------
const adminPath = path.join(ROOT, 'web/js/admin.js');
const pagesDir = path.join(ROOT, 'web/js/pages');
if (fs.existsSync(adminPath) && fs.existsSync(pagesDir)) {
  const adminJs = fs.readFileSync(adminPath, 'utf8');
  const listed = (adminJs.match(/PAGE_FILES\s*=\s*\[([^\]]*)\]/) || [, ''])[1];
  for (const f of fs.readdirSync(pagesDir).filter((x) => x.endsWith('.js'))) {
    const name = f.replace(/\.js$/, '');
    if (!listed.includes(`'${name}'`) && !adminJs.includes(`./pages/${f}`)) errors.push(`web/js/pages/${f} chưa có trong PAGE_FILES của web/js/admin.js`);
  }
}

// ---------- Kết quả ----------
const routeCount = router.routes.length;
console.log(`FreshVend · kiểm tra đồng bộ FE ⇄ BE`);
console.log(`  ${routeCount} route API · ${calls.length} lời gọi từ web/ + simulator/ · ${usedKeys.size} biến môi trường`);
warns.forEach((w) => console.log('  ⚠ ' + w));
if (errors.length) {
  errors.forEach((e) => console.error('  ✘ ' + e));
  console.error(`\n✘ ${errors.length} lỗi đồng bộ – sửa trước khi commit / tạo Pull Request.`);
  process.exit(1);
}
console.log('  ✔ FE và BE khớp nhau');
