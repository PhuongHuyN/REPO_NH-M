#!/usr/bin/env node
/* =====================================================================
   FV-20 (SCRUM-214) – Kiểm thử tích hợp app ↔ SQL Server thật
   Gọi lần lượt các API ĐỌC của 5 module bằng 3 tài khoản (admin, operator01,
   kiosk01) + 2 ca phân quyền, rồi PHÂN LOẠI LỖI THEO MODULE.
   KHÔNG ghi dữ liệu (chỉ GET, trừ đăng nhập) → chạy nhiều lần không sao.

   Cách chạy (2 cửa sổ PowerShell, đứng trong app\api):
     1) npm start                      ← app chạy với DB_MODE=sqlserver trong .env
     2) node tools/smoke-sqlserver.js  ← script này
   Kết quả: in bảng ra màn hình + ghi docs/evidence/SCRUM-214-smoke.md
   Biến môi trường (không bắt buộc): SMOKE_URL (mặc định http://localhost:3000)
   ===================================================================== */
const fs = require('fs');
const path = require('path');

const BASE = process.env.SMOKE_URL || 'http://localhost:3000';
const ACCOUNTS = {
  Admin: ['admin', 'Admin@2026'],
  Operator: ['operator01', 'Operator@2026'],
  Kiosk: ['kiosk01', 'Kiosk@2026'],
};

// [module, vai trò, đường dẫn, mã HTTP mong đợi, mô tả]
const CASES = [
  ['auth', 'Admin', '/api/auth/me', 200, 'Thông tin tài khoản đang đăng nhập'],
  ['auth', 'Admin', '/api/auth/users', 200, 'Danh sách người dùng (auth.vw_UserPermissions)'],
  ['auth', 'Admin', '/api/auth/login-activity', 200, 'Thống kê đăng nhập (audit.vw_LoginActivity)'],
  ['inventory', 'Admin', '/api/inventory/products', 200, 'Danh mục sản phẩm (vw_ProductCatalog)'],
  ['inventory', 'Admin', '/api/inventory/products/1/price-history', 200, 'Lịch sử giá (fn_PriceHistory)'],
  ['inventory', 'Admin', '/api/inventory/stock', 200, 'Tồn kho theo cột (vw_StockStatus)'],
  ['inventory', 'Admin', '/api/inventory/batches', 200, 'Lô còn châm được (vw_AvailableBatches)'],
  ['inventory', 'Admin', '/api/inventory/expiring', 200, 'Hàng sắp/đã hết hạn (vw_ExpiringBatches)'],
  ['inventory', 'Operator', '/api/inventory/stock', 200, 'Operator xem tồn kho (RLS: chỉ máy được giao)'],
  ['sales', 'Admin', '/api/orders', 200, 'Danh sách đơn (vw_OrderDetail)'],
  ['sales', 'Admin', '/api/orders/pending', 200, 'Đơn chờ thanh toán (vw_PendingOrders)'],
  ['sales', 'Kiosk', '/api/kiosk/menu', 200, 'Thực đơn kiosk (vw_StockStatus + vw_MachineHealth)'],
  ['sales', 'Kiosk', '/api/dispense-queue', 200, 'Hàng chờ nhả (vw_DispenseQueue)'],
  ['iot', 'Admin', '/api/iot/machines', 200, 'Sức khỏe máy (vw_MachineHealth)'],
  ['iot', 'Admin', '/api/iot/alerts', 200, 'Cảnh báo đang mở (vw_OpenAlerts)'],
  ['iot', 'Admin', '/api/iot/machines/1/telemetry', 200, 'Cảm biến 6 giờ (fn_RecentTelemetry)'],
  ['iot', 'Operator', '/api/iot/machines', 200, 'Operator xem máy (RLS)'],
  ['report', 'Admin', '/api/reports/kpi', 200, 'KPI dashboard (sp_DashboardKpi)'],
  ['report', 'Admin', '/api/reports/ranking', 200, 'Xếp hạng sản phẩm (vw_ProductRanking)'],
  ['report', 'Admin', '/api/reports/cold-chain', 200, 'Chuỗi lạnh (vw_ColdChainCompliance)'],
  ['report', 'Admin', '/api/reports/test-results', 200, 'Kết quả test gần nhất (vw_LatestTestRun)'],
  ['security', 'Operator', '/api/reports/kpi', 403, 'Operator KHÔNG được xem báo cáo tài chính'],
  ['security', 'Kiosk', '/api/inventory/products', 403, 'Kiosk KHÔNG được vào quản lý sản phẩm'],
];

async function call(method, url, token, body) {
  const t0 = Date.now();
  try {
    const res = await fetch(BASE + url, {
      method,
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let data; try { data = JSON.parse(text); } catch { data = text; }
    return { status: res.status, data, ms: Date.now() - t0 };
  } catch (e) {
    return { status: 0, data: { error: 'NO_CONNECTION', message: e.message }, ms: Date.now() - t0 };
  }
}

const short = (s, n = 110) => String(s ?? '').replace(/\s+/g, ' ').replace(/\|/g, '/').slice(0, n);

(async () => {
  const health = await call('GET', '/api/health');
  if (health.status === 0) {
    console.error(`Không gọi được ${BASE}. Hãy chạy "npm start" trong app\\api trước.`);
    process.exit(2);
  }
  console.log(`API: ${BASE} | /api/health → ${health.status} ${short(JSON.stringify(health.data), 160)}\n`);

  const tokens = {};
  const rows = [];
  for (const [role, [u, p]] of Object.entries(ACCOUNTS)) {
    const r = await call('POST', '/api/auth/login', null, { username: u, password: p });
    tokens[role] = r.data && r.data.token;
    rows.push({ module: 'auth', role, url: `POST /api/auth/login (${u})`, expect: 200, ...r,
      desc: 'Đăng nhập (auth.sp_Login qua login fv_kiosk_app)' });
  }

  for (const [module, role, url, expect, desc] of CASES) {
    if (!tokens[role]) {
      rows.push({ module, role, url: `GET ${url}`, expect, status: -1, data: { error: 'SKIP', message: `Chưa đăng nhập được ${role}` }, ms: 0, desc });
      continue;
    }
    const r = await call('GET', url, tokens[role]);
    rows.push({ module, role, url: `GET ${url}`, expect, ...r, desc });
  }

  // ---------- In bảng + phân loại theo module ----------
  const ok = (x) => x.status === x.expect;
  const detail = (x) => {
    if (ok(x)) return Array.isArray(x.data) ? `${x.data.length} dòng` : 'OK';
    const d = x.data || {};
    return short(`${d.error || ''} ${d.message || (typeof d === 'string' ? d : '')}`);
  };
  const lines = [];
  lines.push(`# SCRUM-214 – Kết quả chạy app với SQL Server thật`, '');
  lines.push(`- Thời điểm: ${new Date().toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })}`);
  lines.push(`- API: ${BASE} — /api/health: ${health.status} ${short(JSON.stringify(health.data), 200)}`);
  lines.push(`- Lệnh: \`node tools/smoke-sqlserver.js\` (chỉ đọc, không ghi dữ liệu)`, '');
  lines.push('## Tổng hợp theo module', '', '| Module | Đạt | Lỗi |', '|---|---|---|');
  const mods = [...new Set(rows.map((x) => x.module))];
  for (const m of mods) {
    const r = rows.filter((x) => x.module === m);
    lines.push(`| ${m} | ${r.filter(ok).length}/${r.length} | ${r.filter((x) => !ok(x)).length} |`);
  }
  lines.push('', '## Chi tiết', '', '| # | Module | Vai trò | API | Mong đợi | Thực tế | Kết quả | Ghi chú |', '|---|---|---|---|---|---|---|---|');
  rows.forEach((x, i) => {
    lines.push(`| ${i + 1} | ${x.module} | ${x.role} | ${x.url} | ${x.expect} | ${x.status} | ${ok(x) ? 'ĐẠT' : '**LỖI**'} | ${short(x.desc, 70)} — ${detail(x)} |`);
  });
  const fails = rows.filter((x) => !ok(x));
  lines.push('', `**Tổng: ${rows.length - fails.length}/${rows.length} đạt.**`);

  console.log(lines.slice(lines.indexOf('## Tổng hợp theo module')).join('\n'));
  const out = path.resolve(__dirname, '..', '..', '..', 'docs', 'evidence', 'SCRUM-214-smoke.md');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, lines.join('\n') + '\n', 'utf8');
  console.log(`\nĐã ghi: ${out}`);
  process.exit(fails.length ? 1 : 0);
})();
