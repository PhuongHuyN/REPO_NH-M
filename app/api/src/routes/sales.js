/* =====================================================================
   TV3 – Bán hàng & Thanh toán  (/api/kiosk/*, /api/orders/*, /api/payments/*)
   SP: sales.sp_CreateOrder (TVP), sp_ConfirmPayment (idempotent), sp_RecordDispense,
       sp_Refund, sp_ExpirePendingOrders
   View: inventory.vw_StockStatus, sales.vw_OrderDetail, vw_PendingOrders, vw_DispenseQueue, iot.vw_MachineHealth
   ===================================================================== */
const crypto = require('crypto');
const db = require('../db');
const v = require('../lib/validate');
const jwt = require('../lib/jwt');
const config = require('../config');
const { HttpError } = require('../lib/http');
const vietqr = require('../lib/vietqr');

const METHODS = ['VIETQR', 'MOMO', 'VNPAY'];
const ORDER_PREFIX = 'FV'; // nội dung chuyển khoản: FV<mã đơn>

// Kiosk chỉ được thao tác trên máy mà tài khoản kiosk được giao
function machineFor(ctx, requested) {
  const id = v.int(requested ?? ctx.user.machines?.[0], 'machineId', { min: 1 });
  if (ctx.user.role === 'Kiosk' && !(ctx.user.machines || []).includes(id)) {
    throw new HttpError(403, 'Tài khoản kiosk không được gắn với máy này', 'FORBIDDEN_MACHINE');
  }
  return id;
}

function groupOrder(rows) {
  if (!rows.length) return null;
  const o = rows[0];
  return {
    orderId: o.OrderId, machineId: o.MachineId, serial: o.Serial, machineName: o.MachineName,
    status: o.OrderStatus, totalAmount: Number(o.TotalAmount), createdAt: o.CreatedAt, paidAt: o.PaidAt,
    completedAt: o.CompletedAt, paymentMethod: o.PaymentMethod, gatewayTxnId: o.GatewayTxnId,
    items: rows.map((x) => ({
      orderItemId: x.OrderItemId, columnNo: x.ColumnNo, productId: x.ProductId, productName: x.ProductName,
      batchCode: x.BatchCode, qty: x.Qty, unitPrice: Number(x.UnitPrice), lineTotal: Number(x.LineTotal),
      dispenseAttempts: x.DispenseAttempts, dispenseResult: x.DispenseResult, dispensed: !!x.ItemDispensed,
    })),
  };
}

async function confirmPayment(orderId, method, txn, amount) {
  // Callback cổng thanh toán không gắn người dùng => dùng pool Kiosk, UserId = NULL
  const r1 = await db.exec('Kiosk', 'sales.sp_ConfirmPayment', {
    OrderId: db.T.bigint(orderId), Method: db.T.vstr(method), GatewayTxnId: db.T.vstr(txn), Amount: db.T.dec(amount),
  });
  return r1.recordset[0];
}

module.exports = (r) => {
  // ---------- Màn hình kiosk ----------
  r.get('/api/kiosk/menu', {
    tag: 'Sales (TV3)', summary: 'Thực đơn của máy: cột, sản phẩm, giá, tồn + tình trạng máy', roles: ['Kiosk', 'Admin'],
  }, async (ctx) => {
    const machineId = machineFor(ctx, ctx.query.machineId);
    const [items, health] = await Promise.all([
      ctx.view('inventory.vw_StockStatus', { where: { MachineId: machineId }, orderBy: 'ColumnNo' }),
      ctx.view('iot.vw_MachineHealth', { where: { MachineId: machineId } }),
    ]);
    const m = health[0];
    if (!m) throw new HttpError(404, 'Máy không tồn tại hoặc không được giao', 'NOT_FOUND');
    return {
      machine: {
        machineId: m.MachineId, serial: m.Serial, name: m.MachineName, location: m.LocationName, status: m.Status,
        isServing: !!m.IsServing, lastTemp: m.LastTemp, degradedMessage: m.DegradedMessage,
      },
      support: { phone: config.supportPhone },
      items: items.filter((x) => x.ProductId).map((x) => ({
        columnId: x.ColumnId, columnNo: x.ColumnNo, productId: x.ProductId, name: x.ProductName,
        category: x.Category, description: x.Description, price: Number(x.Price), imageUrl: x.ImageUrl,
        remaining: x.Remaining, label: x.StockLabel,
      })),
    };
  });

  // ---------- Đơn hàng ----------
  r.post('/api/orders', {
    tag: 'Sales (TV3)', summary: 'Tạo đơn + giữ hàng theo FIFO (TVP giỏ hàng)', roles: ['Kiosk', 'Admin'],
    body: { machineId: 1, items: [{ columnId: 1, qty: 1 }, { columnId: 3, qty: 2 }] },
  }, async (ctx) => {
    const machineId = machineFor(ctx, ctx.body.machineId);
    const items = v.arr(ctx.body.items, 'items', { min: 1, max: 6 }).map((it, i) => ({
      ColumnId: v.int(it.columnId, `items[${i}].columnId`, { min: 1 }),
      Qty: v.int(it.qty, `items[${i}].qty`, { min: 1, max: 5 }),
    }));
    if (new Set(items.map((x) => x.ColumnId)).size !== items.length) throw v.bad('Mỗi sản phẩm chỉ xuất hiện 1 lần trong giỏ');
    const r1 = await ctx.exec('sales.sp_CreateOrder', {
      MachineId: db.T.int(machineId),
      Items: db.tvp('sales.OrderItemType', [['ColumnId', 'int'], ['Qty', 'tinyint']], items),
    }, { outputs: { OrderId: 'bigint' } });
    ctx.status = 201;
    return r1.recordset[0];
  });

  r.get('/api/orders', {
    tag: 'Sales (TV3)', summary: 'Danh sách đơn gần đây (lọc status, machineId)', roles: ['Admin'],
  }, async (ctx) => {
    const rows = await ctx.view('sales.vw_OrderDetail', {
      where: {
        OrderStatus: ctx.query.status || undefined,
        MachineId: v.int(ctx.query.machineId, 'machineId', { optional: true }),
        CreatedAt_from: v.date(ctx.query.from, 'from', { optional: true }),
      },
      orderBy: 'OrderId DESC', top: 600,
    });
    const map = new Map();
    for (const x of rows) { if (!map.has(x.OrderId)) map.set(x.OrderId, []); map.get(x.OrderId).push(x); }
    return [...map.values()].slice(0, Number(ctx.query.limit) || 200).map(groupOrder);
  });

  r.get('/api/orders/pending', { tag: 'Sales (TV3)', summary: 'Đơn đang chờ thanh toán', roles: ['Admin'] },
    async (ctx) => ctx.view('sales.vw_PendingOrders', { orderBy: 'CreatedAt' }));

  r.get('/api/orders/:id', { tag: 'Sales (TV3)', summary: 'Chi tiết đơn hàng', roles: ['Kiosk', 'Admin'] }, async (ctx) => {
    const rows = await ctx.view('sales.vw_OrderDetail', { where: { OrderId: db.T.bigint(v.int(ctx.params.id, 'OrderId', { min: 1 })) }, orderBy: 'OrderItemId' });
    const o = groupOrder(rows);
    if (!o) throw new HttpError(404, 'Không tìm thấy đơn hàng', 'NOT_FOUND');
    return o;
  });

  r.post('/api/orders/:id/cancel', { tag: 'Sales (TV3)', summary: 'Khách hủy đơn đang chờ thanh toán', roles: ['Kiosk', 'Admin'] },
    async (ctx) => {
      const r1 = await ctx.exec('sales.sp_ExpirePendingOrders', { OrderId: db.T.bigint(v.int(ctx.params.id, 'OrderId', { min: 1 })) });
      return r1.recordset[0];
    });

  r.post('/api/orders/:id/refund', {
    tag: 'Sales (TV3)', summary: 'Hoàn tiền thủ công', roles: ['Admin'], body: { reason: 'Khách phản ánh sản phẩm dập' },
  }, async (ctx) => {
    const r1 = await ctx.exec('sales.sp_Refund', {
      OrderId: db.T.bigint(v.int(ctx.params.id, 'OrderId', { min: 1 })),
      Reason: db.T.str(v.str(ctx.body.reason, 'Lý do', { min: 3, max: 200 })),
      RefundedBy: db.T.int(ctx.user.sub),
    });
    return r1.recordset[0];
  });

  // ---------- Nhả hàng (bộ điều khiển máy báo về) ----------
  r.get('/api/dispense-queue', {
    tag: 'Sales (TV3)', summary: 'Hàng chờ nhả của máy', roles: ['Kiosk', 'Admin'], auth: 'user-or-device',
  }, async (ctx) => {
    const machineId = ctx.user.role === 'Device'
      ? v.int(ctx.query.machineId, 'machineId', { min: 1 }) : machineFor(ctx, ctx.query.machineId);
    return ctx.view('sales.vw_DispenseQueue', { where: { MachineId: machineId }, orderBy: 'PaidAt' });
  });

  r.post('/api/orders/items/:itemId/dispense', {
    tag: 'Sales (TV3)', summary: 'Bộ điều khiển máy báo kết quả nhả hàng (kẹt 3 lần -> tự hoàn tiền)', roles: ['Admin'],
    auth: 'user-or-device', body: { result: 'SUCCESS', errorCode: null },
  }, async (ctx) => {
    const r1 = await ctx.exec('sales.sp_RecordDispense', {
      OrderItemId: db.T.bigint(v.int(ctx.params.itemId, 'OrderItemId', { min: 1 })),
      Result: db.T.vstr(v.oneOf(ctx.body.result, 'result', ['SUCCESS', 'JAM'])),
      ErrorCode: db.T.vstr(v.str(ctx.body.errorCode, 'errorCode', { max: 30, optional: true }) ?? null),
    });
    return r1.recordset[0];
  });

  // ---------- Thanh toán chuyển khoản VietQR ----------
  // Kiosk xin mã QR: số tài khoản cửa hàng + số tiền + nội dung "FV<mã đơn>" để đối soát tự động
  r.post('/api/payments/qr', {
    tag: 'Sales (TV3)', summary: 'Sinh mã VietQR (EMVCo/NAPAS) cho đơn đang chờ thanh toán', roles: ['Kiosk', 'Admin'],
    body: { orderId: 1 },
  }, async (ctx) => {
    const orderId = v.int(ctx.body.orderId, 'orderId', { min: 1 });
    const rows = await ctx.view('sales.vw_OrderDetail', { where: { OrderId: db.T.bigint(orderId) } });
    const o = groupOrder(rows);
    if (!o) throw new HttpError(404, 'Không tìm thấy đơn hàng', 'NOT_FOUND');
    if (o.status !== 'PENDING') throw new HttpError(409, 'Đơn hàng không còn chờ thanh toán', 'NOT_PENDING');
    const p = config.payment;
    if (!p.bankBin || !p.accountNo) {
      throw new HttpError(503, 'Máy chưa được cấu hình tài khoản nhận tiền. Vui lòng liên hệ quản trị viên.', 'PAYMENT_NOT_CONFIGURED');
    }
    const content = `${ORDER_PREFIX}${orderId}`;
    const qrContent = vietqr.build({ bankBin: p.bankBin, accountNo: p.accountNo, amount: o.totalAmount, content });
    return {
      orderId, method: 'VIETQR', amount: o.totalAmount, content,
      bankName: p.bankName, accountNo: p.accountNo, accountName: p.accountName,
      qrContent, qrSvg: vietqr.toSvg(qrContent),
      createdAt: o.createdAt, expiresInSeconds: 300,
    };
  });

  // Webhook dịch vụ đối soát ngân hàng (SePay): báo mỗi giao dịch tiền vào tài khoản.
  // Header: Authorization: Apikey <SEPAY_API_KEY>. Tìm "FV<số>" trong nội dung để biết đơn nào.
  r.post('/api/payments/sepay-webhook', {
    auth: 'public', tag: 'Sales (TV3)', summary: 'Webhook giao dịch ngân hàng (SePay) – tự xác nhận đơn',
    body: { id: 92704, gateway: 'Vietcombank', transferType: 'in', transferAmount: 25000, content: 'FV1024 chuyen tien', referenceCode: 'FT2603...' },
  }, async (ctx) => {
    const key = config.payment.sepayApiKey;
    const auth = String(ctx.req.headers.authorization || '');
    const given = auth.replace(/^Apikey\s+/i, '');
    if (!key || given.length !== key.length || !crypto.timingSafeEqual(Buffer.from(given), Buffer.from(key))) {
      throw new HttpError(401, 'Khóa webhook không hợp lệ', 'BAD_SIGNATURE');
    }
    const b = ctx.body || {};
    if (b.transferType && b.transferType !== 'in') return { success: true, ignored: 'not incoming' };
    const m = /FV\s?(\d{1,12})/i.exec(`${b.content || ''} ${b.description || ''}`);
    if (!m) return { success: true, ignored: 'no order code' };
    const amount = v.num(b.transferAmount, 'transferAmount', { min: 1 });
    const txn = `SEPAY-${v.str(String(b.id ?? b.referenceCode ?? ''), 'id', { min: 1, max: 50 })}`;
    const result = await confirmPayment(Number(m[1]), 'VIETQR', txn, amount);
    return { success: true, ...result };
  });

  // Webhook chung cho cổng thanh toán khác – xác thực chữ ký HMAC-SHA256
  r.post('/api/payments/callback', {
    auth: 'public', tag: 'Sales (TV3)', summary: 'Webhook cổng thanh toán (chữ ký HMAC-SHA256)',
    body: { orderId: 1, method: 'VIETQR', gatewayTxnId: 'VIETQR-1-ABCD', amount: 25000, signature: 'hex(HMAC(secret, "orderId|txn|amount"))' },
  }, async (ctx) => {
    const b = ctx.body;
    const orderId = v.int(b.orderId, 'orderId', { min: 1 });
    const txn = v.str(b.gatewayTxnId, 'gatewayTxnId', { min: 4, max: 64 });
    const amount = v.num(b.amount, 'amount', { min: 1 });
    const expected = jwt.hmac(config.paymentSecret, `${orderId}|${txn}|${amount}`);
    if (typeof b.signature !== 'string' || b.signature.length !== expected.length
        || !crypto.timingSafeEqual(Buffer.from(b.signature), Buffer.from(expected))) {
      throw new HttpError(401, 'Chữ ký callback không hợp lệ', 'BAD_SIGNATURE');
    }
    return confirmPayment(orderId, v.oneOf(b.method, 'method', METHODS), txn, amount);
  });

  // CHỈ CHẾ ĐỘ DEMO (DB_MODE=demo): giả lập khách đã chuyển khoản để chạy thử giao diện khi chưa có ngân hàng / SQL Server
  r.post('/api/demo/orders/:id/pay', {
    tag: 'Demo', summary: '(Chỉ DB_MODE=demo) Giả lập khách đã chuyển khoản', roles: ['Kiosk', 'Admin'],
  }, async (ctx) => {
    if (config.dbMode !== 'demo') throw new HttpError(404, 'Chức năng chỉ dùng ở chế độ demo', 'NOT_FOUND');
    const orderId = v.int(ctx.params.id, 'OrderId', { min: 1 });
    const o = groupOrder(await ctx.view('sales.vw_OrderDetail', { where: { OrderId: db.T.bigint(orderId) } }));
    if (!o) throw new HttpError(404, 'Không tìm thấy đơn hàng', 'NOT_FOUND');
    return confirmPayment(orderId, 'VIETQR', `DEMO-${orderId}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`, o.totalAmount);
  });

  // Quản trị viên xác nhận thủ công khi đã thấy tiền về tài khoản (webhook lỗi / khách chuyển sai nội dung)
  r.post('/api/orders/:id/confirm-payment', {
    tag: 'Sales (TV3)', summary: 'Xác nhận thủ công đã nhận tiền chuyển khoản', roles: ['Admin'],
    body: { reference: 'FT26032...', note: 'Đối chiếu sao kê' },
  }, async (ctx) => {
    const orderId = v.int(ctx.params.id, 'OrderId', { min: 1 });
    const rows = await ctx.view('sales.vw_OrderDetail', { where: { OrderId: db.T.bigint(orderId) } });
    const o = groupOrder(rows);
    if (!o) throw new HttpError(404, 'Không tìm thấy đơn hàng', 'NOT_FOUND');
    const ref = v.str(ctx.body.reference, 'Mã giao dịch ngân hàng', { max: 40, optional: true });
    const txn = `MANUAL-${orderId}-${(ref || crypto.randomBytes(3).toString('hex')).replace(/[^\w-]/g, '').toUpperCase()}`.slice(0, 64);
    const r1 = await ctx.exec('sales.sp_ConfirmPayment', {
      OrderId: db.T.bigint(orderId), Method: db.T.vstr('VIETQR'), GatewayTxnId: db.T.vstr(txn), Amount: db.T.dec(o.totalAmount),
    });
    return r1.recordset[0];
  });
};
