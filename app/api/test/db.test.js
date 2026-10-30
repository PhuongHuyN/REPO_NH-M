// Kiểm thử tầng db.js với driver mssql GIẢ (không cần SQL Server):
// xác nhận câu lệnh gửi đi có set SESSION_CONTEXT trong cùng batch, chỉ EXEC procedure,
// tham số được bind (không nối chuỗi) và TVP được dựng đúng kiểu.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const db = require('../src/db');

function fakeMssql(log) {
  const type = (name) => { const f = (...a) => ({ name, args: a }); f.typeName = name; return f; };
  class Table {
    constructor(path) { this.path = path; this.columns = { list: [], add: (n, t) => this.columns.list.push([n, t]) }; this.rows = { list: [], add: (...r) => this.rows.list.push(r) }; }
  }
  class Request {
    constructor() { this.inputs = {}; this.outputs = {}; }
    input(n, t, v) { this.inputs[n] = v === undefined ? t : { t, v }; return this; }
    output(n, t) { this.outputs[n] = t; return this; }
    async query(text) { log.push({ text, inputs: this.inputs, outputs: this.outputs }); return { recordsets: [[{ ok: 1 }]], recordset: [{ ok: 1 }], output: { OrderId: 99 } }; }
  }
  class ConnectionPool {
    constructor(cfg) { log.push({ pool: cfg.user }); }
    async connect() { return this; }
    request() { return new Request(); }
    async close() {}
  }
  return { ConnectionPool, Table, MAX: 'MAX', Int: type('Int'), BigInt: type('BigInt'), TinyInt: type('TinyInt'), SmallInt: type('SmallInt'),
    NVarChar: type('NVarChar'), VarChar: type('VarChar'), Decimal: type('Decimal'), Bit: type('Bit'), Date: type('Date'), DateTime2: type('DateTime2') };
}

test('exec: set SESSION_CONTEXT + EXEC procedure với tham số bind', async () => {
  const log = [];
  db.useDemo(null);
  db.useDriver(fakeMssql(log));
  await db.exec('Operator', 'inventory.sp_UpdatePrice', { ProductId: db.T.int(3), NewPrice: db.T.dec(28000) }, { userId: 2 });
  const q = log.find((x) => x.text);
  assert.equal(log[0].pool, 'fv_operator_app', 'Operator phải dùng login riêng');
  assert.match(q.text, /EXEC sys\.sp_set_session_context @key = N'UserId', @value = @__uid;/);
  assert.match(q.text, /EXEC inventory\.sp_UpdatePrice @ProductId = @ProductId, @NewPrice = @NewPrice;/);
  assert.equal(q.inputs.__uid.v, 2);
  assert.equal(q.inputs.ProductId.v, 3);
  assert.ok(!q.text.includes('28000'), 'giá trị không được nối vào chuỗi SQL');
});

test('exec: TVP + OUTPUT', async () => {
  const log = [];
  db.useDriver(fakeMssql(log));
  const r = await db.exec('Kiosk', 'sales.sp_CreateOrder', {
    MachineId: db.T.int(1),
    Items: db.tvp('sales.OrderItemType', [['ColumnId', 'int'], ['Qty', 'tinyint']], [{ ColumnId: 5, Qty: 2 }]),
  }, { outputs: { OrderId: 'bigint' } });
  const q = log.find((x) => x.text);
  assert.match(q.text, /@Items = @Items, @OrderId = @OrderId OUTPUT;/);
  assert.equal(q.inputs.Items.path, 'sales.OrderItemType');
  assert.deepEqual(q.inputs.Items.rows.list, [[5, 2]]);
  assert.equal(r.output.OrderId, 99);
});

test('view: chỉ SELECT từ view, WHERE dùng tham số, ORDER BY được kiểm tra', async () => {
  const log = [];
  db.useDriver(fakeMssql(log));
  await db.view('Admin', 'sales.vw_OrderDetail', { where: { OrderStatus: 'PAID', CreatedAt_from: '2026-10-01' }, orderBy: 'OrderId DESC', top: 50 });
  const q = log.find((x) => x.text);
  assert.match(q.text, /SELECT TOP \(50\) \* FROM sales\.vw_OrderDetail WHERE \[OrderStatus\] = @w0 AND \[CreatedAt\] >= @w1 ORDER BY \[OrderId\] DESC;/);
  await assert.rejects(() => db.view('Admin', 'sales.Orders; DROP TABLE x', {}), /không hợp lệ/);
  await assert.rejects(() => db.view('Admin', 'sales.vw_OrderDetail', { orderBy: 'OrderId; DROP' }), /không hợp lệ/);
  await assert.rejects(() => db.exec('Admin', 'xp_cmdshell', {}), /không hợp lệ/);
});
