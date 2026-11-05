// =====================================================================
// TV2 – Sản phẩm & Tồn kho: kiểm thử API module inventory
// Mỗi stored procedure có 1 ca đúng + 2 ca sai (theo Kế hoạch, Tuần 2 mục b).
// Chạy trên CSDL giả lập (test/fakeDb.js) – chạy: npm test (trong thư mục app/)
// File riêng của TV2 để không xung đột với api.test.js của cả nhóm.
// =====================================================================
process.env.LOG_REQUESTS = 'false';
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const db = require('../src/db');

db.useDemo(require('./fakeDb').create());
const { handle } = require('../src/app');

let server, base, admin, op;
before(async () => {
  server = http.createServer(handle);
  await new Promise((r) => server.listen(0, r));
  base = `http://127.0.0.1:${server.address().port}`;
  admin = await login('admin', 'Admin@2026');
  op = await login('operator01', 'Operator@2026');      // được giao máy 1, 2, 3
});
after(() => server.close());

async function call(method, path, { token, body } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data; try { data = JSON.parse(text); } catch { data = text; }
  return { status: res.status, data };
}
async function login(username, password) {
  return (await call('POST', '/api/auth/login', { body: { username, password } })).data.token;
}
const stockOf = async (machineId) => (await call('GET', `/api/inventory/stock?machineId=${machineId}`, { token: admin })).data;

// Máy mới đăng ký có các cột rỗng → dùng cho ca đổi sản phẩm của cột và châm hàng thành công
let newMachine;
async function emptyMachine() {
  if (newMachine) return newMachine;
  const r = await call('POST', '/api/iot/machines', {
    token: admin, body: { serial: 'FV-TV2-TEST', machineName: 'Máy kiểm thử TV2', locationId: 1, columnCount: 3, capacity: 5 },
  });
  assert.equal(r.status, 201);
  newMachine = r.data.MachineId;
  return newMachine;
}

// ---------------------------------------------------------------- sp_AddProduct
test('TV2 – sp_AddProduct: thêm sản phẩm mới trả 201 và có trong danh mục', async () => {
  const r = await call('POST', '/api/inventory/products', {
    token: admin, body: { productName: 'Bưởi da xanh bóc múi', price: 42000, shelfLifeHours: 36, category: 'Trái cây cắt sẵn' },
  });
  assert.equal(r.status, 201);
  assert.equal(r.data.Price, 42000);
  const list = (await call('GET', '/api/inventory/products', { token: admin })).data;
  assert.ok(list.some((p) => p.ProductId === r.data.ProductId));
});

test('TV2 – sp_AddProduct sai: trùng tên trả 409 (50101), giá 0 trả 400', async () => {
  const dup = await call('POST', '/api/inventory/products', {
    token: admin, body: { productName: 'dưa hấu cắt miếng', price: 25000, shelfLifeHours: 24 },
  });
  assert.equal(dup.status, 409);
  assert.equal(dup.data.error, 'DB_50101');
  const zero = await call('POST', '/api/inventory/products', {
    token: admin, body: { productName: 'Sản phẩm giá 0', price: 0, shelfLifeHours: 24 },
  });
  assert.equal(zero.status, 400);
});

// ---------------------------------------------------------------- sp_UpdateProduct
test('TV2 – sp_UpdateProduct sai: sản phẩm không tồn tại 404 (50103), đổi trùng tên 409 (50101)', async () => {
  const none = await call('PUT', '/api/inventory/products/99999', {
    token: admin, body: { productName: 'Không có', shelfLifeHours: 24, isActive: true },
  });
  assert.equal(none.status, 404);
  assert.equal(none.data.error, 'DB_50103');
  const dup = await call('PUT', '/api/inventory/products/2', {
    token: admin, body: { productName: 'Dưa hấu cắt miếng', shelfLifeHours: 24, isActive: true },
  });
  assert.equal(dup.status, 409);
  assert.equal(dup.data.error, 'DB_50101');
});

// ---------------------------------------------------------------- sp_UpdatePrice
test('TV2 – sp_UpdatePrice: trả giá cũ/giá mới, danh mục hiện giá mới', async () => {
  const r = await call('PUT', '/api/inventory/products/3/price', { token: admin, body: { price: 27000 } });
  assert.equal(r.status, 200);
  assert.equal(r.data.NewPrice, 27000);
  assert.notEqual(r.data.OldPrice, 27000);
  const p = (await call('GET', '/api/inventory/products', { token: admin })).data.find((x) => x.ProductId === 3);
  assert.equal(p.Price, 27000);
});

test('TV2 – sp_UpdatePrice sai: giá trùng giá hiện tại 409 (50104), sản phẩm không tồn tại 404', async () => {
  const cur = (await call('GET', '/api/inventory/products', { token: admin })).data.find((x) => x.ProductId === 4).Price;
  const same = await call('PUT', '/api/inventory/products/4/price', { token: admin, body: { price: cur } });
  assert.equal(same.status, 409);
  assert.equal(same.data.error, 'DB_50104');
  const none = await call('PUT', '/api/inventory/products/99999/price', { token: admin, body: { price: 30000 } });
  assert.equal(none.status, 404);
});

// ---------------------------------------------------------------- sp_AssignColumn
test('TV2 – sp_AssignColumn: gán sản phẩm cho cột rỗng', async () => {
  const m = await emptyMachine();
  const col = (await stockOf(m)).find((c) => c.ColumnNo === 1);
  assert.equal(col.ProductId, null);
  const r = await call('PUT', `/api/inventory/columns/${col.ColumnId}`, { token: admin, body: { productId: 5 } });
  assert.equal(r.status, 200);
  assert.equal(r.data.ProductId, 5);
});

test('TV2 – sp_AssignColumn sai: cột còn hàng 409 (50106), cột máy không được giao 404 (50105)', async () => {
  const busy = (await stockOf(1)).find((c) => c.Remaining > 0);
  const r1 = await call('PUT', `/api/inventory/columns/${busy.ColumnId}`, { token: op, body: { productId: 2 } });
  assert.equal(r1.status, 409);
  assert.equal(r1.data.error, 'DB_50106');
  const other = (await stockOf(4))[0];                    // máy 4 không giao cho operator01
  const r2 = await call('PUT', `/api/inventory/columns/${other.ColumnId}`, { token: op, body: { productId: 2 } });
  assert.equal(r2.status, 404);
  assert.equal(r2.data.error, 'DB_50105');
});

// ---------------------------------------------------------------- sp_AddBatch
test('TV2 – sp_AddBatch: nhập lô mới, hạn dùng = giờ làm + ShelfLifeHours', async () => {
  const r = await call('POST', '/api/inventory/batches', { token: op, body: { productId: 5, quantity: 20 } });
  assert.equal(r.status, 201);
  assert.match(r.data.BatchCode, /^LO\d{6}$/);
  const hours = (new Date(r.data.ExpiryAt) - new Date(r.data.PreparedAt)) / 3600000;
  const shelf = (await call('GET', '/api/inventory/products', { token: admin })).data.find((x) => x.ProductId === 5).ShelfLifeHours;
  assert.equal(hours, shelf);
});

test('TV2 – sp_AddBatch sai: sản phẩm không tồn tại 404 (50107), số lượng 0 trả 400', async () => {
  const none = await call('POST', '/api/inventory/batches', { token: op, body: { productId: 99999, quantity: 10 } });
  assert.equal(none.status, 404);
  assert.equal(none.data.error, 'DB_50107');
  const zero = await call('POST', '/api/inventory/batches', { token: op, body: { productId: 1, quantity: 0 } });
  assert.equal(zero.status, 400);
});

// ---------------------------------------------------------------- sp_Restock (TVP)
test('TV2 – sp_Restock: châm hàng vào cột rỗng, tồn kho tăng đúng số lượng', async () => {
  const m = await emptyMachine();
  const col = (await stockOf(m)).find((c) => c.ColumnNo === 1);       // đã gán sản phẩm 5 ở ca trước
  const lot = (await call('GET', '/api/inventory/batches?productId=5', { token: admin })).data[0];
  const r = await call('POST', '/api/inventory/restock', {
    token: admin, body: { machineId: m, note: 'Kiểm thử TV2', items: [{ columnId: col.ColumnId, batchId: lot.BatchId, qty: 3 }] },
  });
  assert.equal(r.status, 201);
  assert.equal(r.data.TotalQty, 3);
  const after = (await stockOf(m)).find((c) => c.ColumnId === col.ColumnId);
  assert.equal(after.Remaining, 3);
});

test('TV2 – sp_Restock sai: lô sai sản phẩm 400 (50114), máy không được giao 404 (50110)', async () => {
  const col = (await stockOf(1)).find((c) => c.ColumnNo === 6);
  const lots = (await call('GET', '/api/inventory/batches', { token: op })).data;
  const wrong = lots.find((b) => b.ProductId !== col.ProductId);
  const r1 = await call('POST', '/api/inventory/restock', {
    token: op, body: { machineId: 1, items: [{ columnId: col.ColumnId, batchId: wrong.BatchId, qty: 1 }] },
  });
  assert.equal(r1.status, 400);
  assert.equal(r1.data.error, 'DB_50114');
  const col4 = (await stockOf(4))[0];
  const r2 = await call('POST', '/api/inventory/restock', {
    token: op, body: { machineId: 4, items: [{ columnId: col4.ColumnId, batchId: lots[0].BatchId, qty: 1 }] },
  });
  assert.equal(r2.status, 404);
  assert.equal(r2.data.error, 'DB_50110');
});

// ---------------------------------------------------------------- sp_RemoveExpired + view
test('TV2 – sp_RemoveExpired: trả số dòng/số hộp đã rút, sau đó không còn lô ĐÃ HẾT HẠN', async () => {
  const r = await call('POST', '/api/inventory/remove-expired', { token: op, body: { machineId: 1 } });
  assert.equal(r.status, 200);
  assert.ok(Number.isInteger(r.data.RemovedLines) && r.data.RemovedLines >= 0);
  assert.ok(Number.isInteger(r.data.RemovedQty) && r.data.RemovedQty >= 0);
  const exp = (await call('GET', '/api/inventory/expiring?machineId=1', { token: op })).data;
  assert.ok(exp.every((x) => x.ExpiryLabel !== 'ĐÃ HẾT HẠN'));
});

test('TV2 – sp_RemoveExpired sai: thiếu token 401, machineId không phải số 400', async () => {
  assert.equal((await call('POST', '/api/inventory/remove-expired', { body: { machineId: 1 } })).status, 401);
  assert.equal((await call('POST', '/api/inventory/remove-expired', { token: op, body: { machineId: 'abc' } })).status, 400);
});

// ---------------------------------------------------------------- Phân quyền
test('TV2 – RBAC: tài khoản Kiosk không gọi được API tồn kho (403)', async () => {
  const kiosk = await login('kiosk01', 'Kiosk@2026');
  assert.equal((await call('GET', '/api/inventory/stock', { token: kiosk })).status, 403);
  assert.equal((await call('POST', '/api/inventory/batches', { token: kiosk, body: { productId: 1, quantity: 5 } })).status, 403);
});
