// Kiểm thử tích hợp API trên CSDL giả lập trong bộ nhớ (test/fakeDb.js) – chạy: npm test
process.env.LOG_REQUESTS = 'false';
Object.assign(process.env, {
  PAYMENT_BANK_BIN: '970436', PAYMENT_ACCOUNT_NO: '1234567890', PAYMENT_ACCOUNT_NAME: 'CONG TY FRESHVEND',
  PAYMENT_BANK_NAME: 'Vietcombank', SEPAY_API_KEY: 'test-sepay-key', DEVICE_API_KEY: 'test-device-key',
});
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const db = require('../src/db');
const jwt = require('../src/lib/jwt');
const config = require('../src/config');

db.useDemo(require('./fakeDb').create());
const { handle } = require('../src/app');

let server, base;
before(async () => {
  server = http.createServer(handle);
  await new Promise((r) => server.listen(0, r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

async function call(method, path, { token, body, headers = {} } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data; try { data = JSON.parse(text); } catch { data = text; }
  return { status: res.status, data };
}
const DEV = () => ({ 'X-Device-Key': config.deviceApiKey });
const login = async (u, p) => (await call('POST', '/api/auth/login', { body: { username: u, password: p } })).data.token;

test('TV1 – đăng nhập đúng trả JWT, sai trả 401', async () => {
  const ok = await call('POST', '/api/auth/login', { body: { username: 'admin', password: 'Admin@2026' } });
  assert.equal(ok.status, 200);
  assert.equal(ok.data.user.role, 'Admin');
  const bad = await call('POST', '/api/auth/login', { body: { username: 'admin', password: 'sai-mat-khau' } });
  assert.equal(bad.status, 401);
});

test('TV1 – thiếu token bị 401, Operator gọi báo cáo bị 403', async () => {
  assert.equal((await call('GET', '/api/reports/kpi')).status, 401);
  const op = await login('operator01', 'Operator@2026');
  assert.equal((await call('GET', '/api/reports/kpi', { token: op })).status, 403);
});

test('TV1 – RLS: operator01 chỉ thấy 3 máy được giao', async () => {
  const op = await login('operator01', 'Operator@2026');
  const r = await call('GET', '/api/iot/machines', { token: op });
  assert.equal(r.status, 200);
  assert.deepEqual(r.data.map((m) => m.Serial), ['FV-HCM-001', 'FV-HCM-002', 'FV-HCM-003']);
});

test('TV2 – châm hàng vượt sức chứa trả 409, dữ liệu sai trả 400', async () => {
  const op = await login('operator01', 'Operator@2026');
  const stock = (await call('GET', '/api/inventory/stock?machineId=1', { token: op })).data;
  const col = stock.find((c) => c.ColumnNo === 1);
  const batches = (await call('GET', `/api/inventory/batches?productId=${col.ProductId}`, { token: op })).data;
  const r = await call('POST', '/api/inventory/restock', {
    token: op, body: { machineId: 1, items: [{ columnId: col.ColumnId, batchId: batches[0].BatchId, qty: 9 }] },
  });
  assert.equal(r.status, 409);
  assert.match(r.data.message, /sức chứa/);
  const r2 = await call('POST', '/api/inventory/restock', { token: op, body: { machineId: 1, items: [] } });
  assert.equal(r2.status, 400);
});

test('TV2 – đổi giá ghi lịch sử', async () => {
  const admin = await login('admin', 'Admin@2026');
  const before = (await call('GET', '/api/inventory/products/2/price-history', { token: admin })).data.length;
  assert.equal((await call('PUT', '/api/inventory/products/2/price', { token: admin, body: { price: 36000 } })).status, 200);
  const after = (await call('GET', '/api/inventory/products/2/price-history', { token: admin })).data.length;
  assert.equal(after, before + 1);
});

test('TV3 – luồng mua hàng: tạo đơn -> VietQR -> ngân hàng báo tiền về -> máy nhả hàng -> DISPENSED', async () => {
  const kiosk = await login('kiosk01', 'Kiosk@2026');
  const menu = (await call('GET', '/api/kiosk/menu', { token: kiosk })).data;
  const item = menu.items.find((i) => i.remaining > 0);
  const created = await call('POST', '/api/orders', { token: kiosk, body: { machineId: 1, items: [{ columnId: item.columnId, qty: 1 }] } });
  assert.equal(created.status, 201);
  const orderId = created.data.OrderId;
  const qr = await call('POST', '/api/payments/qr', { token: kiosk, body: { orderId } });
  assert.equal(qr.status, 200);
  assert.equal(qr.data.content, `FV${orderId}`);
  assert.match(qr.data.qrContent, /^000201010212.*970436.*1234567890.*6304[0-9A-F]{4}$/);
  // Kiosk không tự xác nhận thanh toán được
  assert.equal((await call('POST', `/api/orders/${orderId}/confirm-payment`, { token: kiosk, body: {} })).status, 403);
  const hook = { id: 5001, gateway: 'Vietcombank', transferType: 'in', transferAmount: qr.data.amount, content: `MBVCB.123 FV${orderId} thanh toan` };
  assert.equal((await call('POST', '/api/payments/sepay-webhook', { body: hook, headers: { Authorization: 'Apikey sai' } })).status, 401);
  const paid = await call('POST', '/api/payments/sepay-webhook', { body: hook, headers: { Authorization: 'Apikey test-sepay-key' } });
  assert.equal(paid.status, 200);
  assert.equal(paid.data.Status, 'PAID');
  const dup = await call('POST', '/api/payments/sepay-webhook', { body: hook, headers: { Authorization: 'Apikey test-sepay-key' } });
  assert.equal(dup.data.IsDuplicate, true, 'webhook trùng phải idempotent');
  const order = (await call('GET', `/api/orders/${orderId}`, { token: kiosk })).data;
  // Màn hình kiosk không được tự báo nhả hàng – chỉ bộ điều khiển máy (X-Device-Key)
  assert.equal((await call('POST', `/api/orders/items/${order.items[0].orderItemId}/dispense`, { token: kiosk, body: { result: 'SUCCESS' } })).status, 403);
  const queue = (await call('GET', '/api/dispense-queue?machineId=1', { headers: DEV() })).data;
  assert.ok(queue.some((q) => q.OrderItemId === order.items[0].orderItemId));
  const d = await call('POST', `/api/orders/items/${order.items[0].orderItemId}/dispense`, { headers: DEV(), body: { result: 'SUCCESS' } });
  assert.equal(d.data.OrderStatus, 'DISPENSED');
});

test('TV3 – kẹt 3 lần thì tự hoàn tiền, máy chuyển FAULT', async () => {
  const kiosk = await login('kiosk03', 'Kiosk@2026');
  const admin = await login('admin', 'Admin@2026');
  const menu = (await call('GET', '/api/kiosk/menu', { token: kiosk })).data;
  const item = menu.items.find((i) => i.remaining > 0);
  const o = (await call('POST', '/api/orders', { token: kiosk, body: { machineId: 3, items: [{ columnId: item.columnId, qty: 1 }] } })).data;
  const conf = await call('POST', `/api/orders/${o.OrderId}/confirm-payment`, { token: admin, body: { reference: 'FT26TEST' } });
  assert.equal(conf.data.Status, 'PAID');
  const detail = (await call('GET', `/api/orders/${o.OrderId}`, { token: kiosk })).data;
  let last;
  for (let i = 0; i < 3; i++) {
    last = await call('POST', `/api/orders/items/${detail.items[0].orderItemId}/dispense`, { headers: DEV(), body: { result: 'JAM', errorCode: 'E_TEST' } });
  }
  assert.equal(last.data.OrderStatus, 'REFUNDED');
  const menu2 = (await call('GET', '/api/kiosk/menu', { token: kiosk })).data;
  assert.equal(menu2.machine.status, 'FAULT');
  // Operator sửa máy
  const op = await login('operator01', 'Operator@2026');
  assert.equal((await call('PUT', '/api/iot/machines/3/clear-fault', { token: op, body: { note: 'test' } })).status, 200);
});

test('TV2 – sửa sản phẩm, tải ảnh, không cho ngừng bán khi đang ở trên máy', async () => {
  const admin = await login('admin', 'Admin@2026');
  const p = (await call('GET', '/api/inventory/products', { token: admin })).data.find((x) => x.ProductId === 1);
  const upd = await call('PUT', '/api/inventory/products/1', { token: admin, body: { productName: p.ProductName, category: p.Category, description: 'Hộp 300g', shelfLifeHours: p.ShelfLifeHours, isActive: true } });
  assert.equal(upd.status, 200);
  assert.equal(upd.data.Description, 'Hộp 300g');
  const stop = await call('PUT', '/api/inventory/products/1', { token: admin, body: { productName: p.ProductName, shelfLifeHours: p.ShelfLifeHours, isActive: false } });
  assert.equal(stop.status, 409);
  const bad = await call('POST', '/api/inventory/products/1/image', { token: admin, body: { dataUrl: 'data:image/png;base64,AAAA' } });
  assert.equal(bad.status, 400);
  const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
  const img = await call('POST', '/api/inventory/products/1/image', { token: admin, body: { dataUrl: `data:image/png;base64,${png}` } });
  assert.equal(img.status, 200);
  assert.match(img.data.ImageUrl, /^\/uploads\/products\/1-[0-9a-f]{8}\.png$/);
  const served = await fetch(base + img.data.ImageUrl);
  assert.equal(served.status, 200);
  require('fs').rmSync(require('path').join(config.uploadDir, 'products', require('path').basename(img.data.ImageUrl)), { force: true });
});

test('TV3 – kiosk không được đặt hàng cho máy khác', async () => {
  const kiosk = await login('kiosk01', 'Kiosk@2026');
  const r = await call('POST', '/api/orders', { token: kiosk, body: { machineId: 2, items: [{ columnId: 7, qty: 1 }] } });
  assert.equal(r.status, 403);
});

test('TV3 – webhook sai chữ ký bị 401, đúng chữ ký thì PAID', async () => {
  const kiosk = await login('kiosk02', 'Kiosk@2026');
  const menu = (await call('GET', '/api/kiosk/menu', { token: kiosk })).data;
  const item = menu.items.find((i) => i.remaining > 0);
  const o = (await call('POST', '/api/orders', { token: kiosk, body: { machineId: 2, items: [{ columnId: item.columnId, qty: 1 }] } })).data;
  const body = { orderId: o.OrderId, method: 'VNPAY', gatewayTxnId: 'VNPAY-TEST-1', amount: Number(o.TotalAmount) };
  assert.equal((await call('POST', '/api/payments/callback', { body: { ...body, signature: 'abc' } })).status, 401);
  const signature = jwt.hmac(config.paymentSecret, `${body.orderId}|${body.gatewayTxnId}|${body.amount}`);
  const ok = await call('POST', '/api/payments/callback', { body: { ...body, signature } });
  assert.equal(ok.status, 200);
  assert.equal(ok.data.Status, 'PAID');
});

test('TV4 – thiết bị gửi telemetry bằng X-Device-Key; 3 lần quá nhiệt sinh cảnh báo', async () => {
  const bad = await call('POST', '/api/iot/telemetry', { body: { machineId: 2, readings: [{ temp: 4 }] }, headers: { 'X-Device-Key': 'sai' } });
  assert.equal(bad.status, 401);
  const r = await call('POST', '/api/iot/telemetry', {
    body: { machineId: 2, readings: [{ temp: 10.1, door: 0 }, { temp: 10.3, door: 0 }, { temp: 10.5, door: 0 }] },
    headers: { 'X-Device-Key': config.deviceApiKey },
  });
  assert.equal(r.status, 200);
  assert.equal(r.data.Status, 'DEGRADED');
  const admin = await login('admin', 'Admin@2026');
  const alerts = (await call('GET', '/api/iot/alerts?machineId=2', { token: admin })).data;
  assert.ok(alerts.some((a) => a.AlertType === 'TEMP_HIGH'));
});

test('TV5 – báo cáo, xuất CSV và chạy test', async () => {
  const admin = await login('admin', 'Admin@2026');
  const peak = (await call('GET', '/api/reports/peak-hours', { token: admin })).data;
  assert.equal(peak.length, 24);
  const growth = (await call('GET', '/api/reports/revenue-growth', { token: admin })).data;
  assert.equal(growth.length, 12);
  const res = await fetch(`${base}/api/reports/export.csv`, { headers: { Authorization: `Bearer ${admin}` } });
  assert.equal(res.status, 200);
  assert.match(res.headers.get('content-type'), /text\/csv/);
  const tests = (await call('POST', '/api/reports/run-tests', { token: admin })).data;
  assert.ok(tests.summary.length > 0);
});

test('Swagger – openapi.json liệt kê đầy đủ API', async () => {
  const spec = (await call('GET', '/api/openapi.json')).data;
  assert.equal(spec.openapi, '3.0.3');
  assert.ok(Object.keys(spec.paths).length >= 40);
});
