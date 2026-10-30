/* =====================================================================
   CSDL GIẢ LẬP TRONG BỘ NHỚ – CHỈ DÙNG CHO KIỂM THỬ TỰ ĐỘNG (npm test, GitHub Actions)
   Mô phỏng lại các stored procedure, view, quyền (RBAC) và RLS chính của FreshVendDB.
   KHÔNG dùng để chấm điểm phần CSDL – logic thật nằm trong gói FreshVend_Database.
   ===================================================================== */
const crypto = require('crypto');

function fail(number, message) { const e = new Error(message); e.number = number; return e; }
const un = (x) => (x && typeof x === 'object' && '__t' in x ? x.v : x);
const now = () => new Date();
const addMin = (d, m) => new Date(d.getTime() + m * 60000);
const addH = (d, h) => addMin(d, h * 60);
const vnDate = (d) => new Date(d.getTime() + 7 * 3600000).toISOString().slice(0, 10);   // ngày theo giờ VN
const hash = (pw, salt) => crypto.createHash('sha256').update(`${pw}|${salt}`).digest('hex');

// ----------------- Quyền theo vai trò (giống FreshVend_Database/26_security.sql) -----------------
const ALLOW = {
  Operator: [/^inventory\./, /^iot\.vw_MachineHealth$/, /^iot\.vw_OpenAlerts$/, /^iot\.fn_RecentTelemetry$/,
    /^iot\.sp_AcknowledgeAlert$/, /^iot\.sp_ClearFault$/, /^auth\.sp_Login$/, /^auth\.sp_ChangePassword$/],
  Kiosk: [/^auth\.sp_Login$/, /^auth\.sp_ChangePassword$/, /^sales\.sp_(CreateOrder|ConfirmPayment|RecordDispense|ExpirePendingOrders)$/,
    /^inventory\.vw_StockStatus$/, /^sales\.vw_(OrderDetail|DispenseQueue)$/, /^iot\.vw_MachineHealth$/],
  Device: [/^iot\.sp_IngestTelemetry$/, /^sales\.sp_RecordDispense$/, /^sales\.vw_DispenseQueue$/, /^iot\.vw_MachineHealth$/],
};
function checkPermission(role, name) {
  if (role === 'Admin') return;
  if (!(ALLOW[role] || []).some((re) => re.test(name))) {
    throw fail(229, `The EXECUTE/SELECT permission was denied on the object '${name}'`);
  }
}

function create() {
  const S = {
    seq: {}, roles: ['Admin', 'Operator', 'Kiosk'], users: [], uma: [], loginHistory: [], audit: [],
    locations: [], machines: [], thresholds: {}, products: [], priceHistory: [], batches: [], columns: [], stock: [],
    restockEvents: [], restockItems: [], orders: [], items: [], payments: [], refunds: [], dispense: [],
    telemetry: [], hourly: [], alerts: [], exportLogs: [], testResults: [],
  };
  const id = (t) => (S.seq[t] = (S.seq[t] || 0) + 1);

  // ----------------- RLS -----------------
  function visibleMachineIds(role, userId) {
    if (role === 'Admin' || role === 'Device') return new Set(S.machines.map((m) => m.MachineId));
    return new Set(S.uma.filter((a) => a.UserId === userId).map((a) => a.MachineId));
  }

  // ----------------- Hàm dùng chung -----------------
  const product = (pid) => S.products.find((p) => p.ProductId === pid);
  const machine = (mid) => S.machines.find((m) => m.MachineId === mid);
  const column = (cid) => S.columns.find((c) => c.ColumnId === cid);
  const batch = (bid) => S.batches.find((b) => b.BatchId === bid);
  const remaining = (cid) => S.stock.filter((s) => s.ColumnId === cid && batch(s.BatchId).ExpiryAt > now()).reduce((a, s) => a + s.Qty, 0);
  const orderTotal = (oid) => S.items.filter((i) => i.OrderId === oid).reduce((a, i) => a + i.Qty * i.UnitPrice, 0);
  const dispensed = (itemId) => S.dispense.some((d) => d.OrderItemId === itemId && d.Result === 'SUCCESS');

  function addAlert(MachineId, AlertType, Severity, Message, RefKey, at = now()) {
    const a = { AlertId: id('alert'), MachineId, AlertType, Severity, Message, RefKey, CreatedAt: at, AckBy: null, AckAt: null, ResolvedAt: null };
    S.alerts.push(a);
    return a;
  }
  function openAlert(mid, type, ref) {
    return S.alerts.find((a) => a.MachineId === mid && a.AlertType === type && !a.ResolvedAt && (ref === undefined || a.RefKey === ref));
  }
  function lowStockCheck(cid) {
    const c = column(cid);
    if (!c || !c.ProductId) return;
    const rem = remaining(cid);
    if (rem * 5 <= c.Capacity && !openAlert(c.MachineId, 'LOW_STOCK', `COL:${cid}`)) {
      addAlert(c.MachineId, 'LOW_STOCK', rem === 0 ? 'HIGH' : 'MEDIUM',
        `Cột ${c.ColumnNo} (${product(c.ProductId).ProductName}) còn ${rem}/${c.Capacity} hộp`, `COL:${cid}`);
    }
  }
  function setMachineStatus(m, status, userId = null) {
    if (m.Status === status) return;
    S.audit.push({ AuditId: id('audit'), TableName: 'iot.Machines', Action: 'UPDATE', KeyValue: String(m.MachineId),
      OldData: JSON.stringify({ Status: m.Status }), NewData: JSON.stringify({ Status: status }), ChangedBy: userId, ChangedAt: now() });
    m.Status = status;
  }
  function guardOrder(o, to) {
    const ok = { PENDING: ['PAID', 'EXPIRED', 'CANCELLED'], PAID: ['DISPENSED', 'DISPENSE_FAILED', 'REFUNDED'], DISPENSE_FAILED: ['REFUNDED'] };
    if (!(ok[o.Status] || []).includes(to)) throw fail(50210, 'Chuyển trạng thái đơn hàng không hợp lệ (ví dụ REFUNDED -> PAID)');
    o.Status = to;
  }

  // ----------------- STORED PROCEDURES -----------------
  const SP = {
    // ===== auth (TV1) =====
    'auth.sp_CreateUser'(p) {
      const username = String(p.Username || '').trim().toLowerCase();
      if (username.length < 3) throw fail(50001, 'Tên đăng nhập phải có ít nhất 3 ký tự');
      if (!p.Password || p.Password.length < 8) throw fail(50002, 'Mật khẩu phải có ít nhất 8 ký tự');
      if (S.users.some((u) => u.Username === username)) throw fail(50003, 'Tên đăng nhập đã tồn tại');
      if (!S.roles.includes(p.RoleName)) throw fail(50004, 'Vai trò không hợp lệ (Admin, Operator, Kiosk)');
      if (!p.FullName || !String(p.FullName).trim()) throw fail(50005, 'Họ tên không được để trống');
      const salt = crypto.randomUUID();
      const u = { UserId: id('user'), Username: username, Salt: salt, PasswordHash: hash(p.Password, salt), FullName: p.FullName,
        Email: p.Email || null, RoleName: p.RoleName, FailedLogins: 0, IsActive: true, CreatedAt: now(), LastLoginAt: null };
      S.users.push(u);
      return [[{ UserId: u.UserId, Username: u.Username, RoleName: u.RoleName }]];
    },
    'auth.sp_Login'(p) {
      const username = String(p.Username || '').trim().toLowerCase();
      const u = S.users.find((x) => x.Username === username);
      let success = false, msg;
      if (!u) msg = 'Sai tên đăng nhập hoặc mật khẩu';
      else if (!u.IsActive) msg = 'Tài khoản đã bị khóa. Liên hệ quản trị viên';
      else if (hash(p.Password, u.Salt) !== u.PasswordHash) {
        u.FailedLogins += 1;
        if (u.FailedLogins >= 5) u.IsActive = false;
        msg = u.FailedLogins >= 5 ? 'Sai mật khẩu 5 lần – tài khoản đã bị khóa' : `Sai tên đăng nhập hoặc mật khẩu (còn ${5 - u.FailedLogins} lần thử)`;
      } else { u.FailedLogins = 0; u.LastLoginAt = now(); success = true; msg = 'Đăng nhập thành công'; }
      S.loginHistory.push({ LoginId: id('login'), Username: username, UserId: u?.UserId ?? null, Success: success, LoginAt: now(), ClientInfo: p.ClientInfo });
      return [
        [{ Success: success, Message: msg, UserId: success ? u.UserId : null, Username: success ? u.Username : null,
          FullName: success ? u.FullName : null, RoleName: success ? u.RoleName : null }],
        success ? S.uma.filter((a) => a.UserId === u.UserId).map((a) => ({ MachineId: a.MachineId })) : [],
      ];
    },
    'auth.sp_ChangePassword'(p) {
      const u = S.users.find((x) => x.UserId === p.UserId && x.IsActive);
      if (!u) throw fail(50010, 'Người dùng không tồn tại hoặc đã bị khóa');
      if (hash(p.OldPassword, u.Salt) !== u.PasswordHash) throw fail(50011, 'Mật khẩu cũ không đúng');
      if (!p.NewPassword || p.NewPassword.length < 8) throw fail(50002, 'Mật khẩu phải có ít nhất 8 ký tự');
      if (p.NewPassword === p.OldPassword) throw fail(50012, 'Mật khẩu mới phải khác mật khẩu cũ');
      u.Salt = crypto.randomUUID(); u.PasswordHash = hash(p.NewPassword, u.Salt);
      return [[{ UserId: u.UserId, Message: 'Đã đổi mật khẩu' }]];
    },
    'auth.sp_AssignMachine'(p) {
      const u = S.users.find((x) => x.UserId === p.UserId);
      if (!u) throw fail(50020, 'Người dùng không tồn tại');
      if (!['Operator', 'Kiosk'].includes(u.RoleName)) throw fail(50021, 'Chỉ giao máy cho tài khoản Operator hoặc Kiosk');
      if (!machine(p.MachineId)) throw fail(50022, 'Máy không tồn tại');
      if (p.Unassign) S.uma = S.uma.filter((a) => !(a.UserId === p.UserId && a.MachineId === p.MachineId));
      else if (!S.uma.some((a) => a.UserId === p.UserId && a.MachineId === p.MachineId)) S.uma.push({ UserId: p.UserId, MachineId: p.MachineId, AssignedAt: now() });
      return [S.uma.filter((a) => a.UserId === p.UserId).map((a) => ({ ...a, Serial: machine(a.MachineId).Serial }))];
    },
    'auth.sp_DeactivateUser'(p, ctx) {
      const u = S.users.find((x) => x.UserId === p.UserId);
      if (!u) throw fail(50030, 'Người dùng không tồn tại');
      if (!p.Activate && p.UserId === ctx.userId) throw fail(50031, 'Không thể tự khóa tài khoản của chính mình');
      u.IsActive = !!p.Activate; if (p.Activate) u.FailedLogins = 0;
      return [[{ UserId: u.UserId, Username: u.Username, IsActive: u.IsActive }]];
    },

    // ===== inventory (TV2) =====
    'inventory.sp_AddProduct'(p) {
      const name = String(p.ProductName || '').trim();
      if (!name) throw fail(50100, 'Tên sản phẩm không được để trống');
      if (S.products.some((x) => x.ProductName.toLowerCase() === name.toLowerCase())) throw fail(50101, 'Tên sản phẩm đã tồn tại');
      if (!(p.Price > 0)) throw fail(50102, 'Giá bán phải lớn hơn 0');
      if (!(p.ShelfLifeHours >= 1 && p.ShelfLifeHours <= 120)) throw fail(50108, 'Hạn sử dụng phải từ 1 đến 120 giờ');
      const x = { ProductId: id('product'), ProductName: name, Category: p.Category || 'Trái cây cắt sẵn', Description: p.Description || null,
        Price: Number(p.Price), ImageUrl: p.ImageUrl || null, ShelfLifeHours: p.ShelfLifeHours, IsActive: true, ValidFrom: now() };
      S.products.push(x);
      return [[{ ProductId: x.ProductId, ProductName: x.ProductName, Price: x.Price }]];
    },
    'inventory.sp_UpdateProduct'(p) {
      const x = product(p.ProductId);
      if (!x) throw fail(50103, 'Sản phẩm không tồn tại');
      const name = String(p.ProductName || '').trim();
      if (!name) throw fail(50100, 'Tên sản phẩm không được để trống');
      if (S.products.some((y) => y !== x && y.ProductName.toLowerCase() === name.toLowerCase())) throw fail(50101, 'Tên sản phẩm đã tồn tại');
      if (!(p.ShelfLifeHours >= 1 && p.ShelfLifeHours <= 120)) throw fail(50108, 'Hạn sử dụng phải từ 1 đến 120 giờ');
      if (!p.IsActive && S.columns.some((c) => c.ProductId === x.ProductId)) throw fail(50109, 'Sản phẩm đang được bán ở máy – gỡ khỏi các ô trước khi ngừng bán');
      Object.assign(x, { ProductName: name, Category: p.Category ?? null, Description: p.Description ?? null,
        ImageUrl: p.ImageUrl ?? null, ShelfLifeHours: p.ShelfLifeHours, IsActive: !!p.IsActive });
      return [[{ ...x }]];
    },
    'inventory.sp_UpdatePrice'(p) {
      const x = product(p.ProductId);
      if (!x) throw fail(50103, 'Sản phẩm không tồn tại');
      if (!(p.NewPrice > 0)) throw fail(50102, 'Giá bán phải lớn hơn 0');
      if (Number(p.NewPrice) === x.Price) throw fail(50104, 'Giá mới trùng giá hiện tại');
      const t = now();
      S.priceHistory.push({ ProductId: x.ProductId, ProductName: x.ProductName, Price: x.Price, ValidFrom: x.ValidFrom, ValidTo: t });
      const old = x.Price; x.Price = Number(p.NewPrice); x.ValidFrom = t;
      return [[{ ProductId: x.ProductId, OldPrice: old, NewPrice: x.Price }]];
    },
    'inventory.sp_AssignColumn'(p, ctx) {
      const c = column(p.ColumnId);
      if (!c || !ctx.visible.has(c.MachineId)) throw fail(50105, 'Cột không tồn tại hoặc bạn không được giao máy này');
      if (p.ProductId != null && !product(p.ProductId)) throw fail(50107, 'Sản phẩm không tồn tại hoặc đã ngừng bán');
      if (S.stock.some((s) => s.ColumnId === c.ColumnId && s.Qty > 0)) throw fail(50106, 'Cột đang còn hàng – cần rút hết hàng trước khi đổi sản phẩm');
      c.ProductId = p.ProductId ?? null;
      return [[{ ColumnId: c.ColumnId, MachineId: c.MachineId, ColumnNo: c.ColumnNo, ProductId: c.ProductId }]];
    },
    'inventory.sp_AddBatch'(p) {
      const x = product(p.ProductId);
      if (!x) throw fail(50107, 'Sản phẩm không tồn tại hoặc đã ngừng bán');
      if (!(p.Quantity > 0)) throw fail(50113, 'Số lượng phải lớn hơn 0');
      const prepared = p.PreparedAt ? new Date(p.PreparedAt) : now();
      const b = { BatchId: id('batch'), ProductId: x.ProductId, PreparedAt: prepared, ExpiryAt: addH(prepared, x.ShelfLifeHours),
        Quantity: p.Quantity, Supplier: p.Supplier || 'Bếp trung tâm FreshVend' };
      b.BatchCode = 'LO' + String(b.BatchId).padStart(6, '0');
      S.batches.push(b);
      return [[{ BatchId: b.BatchId, BatchCode: b.BatchCode, ProductId: b.ProductId, PreparedAt: b.PreparedAt, ExpiryAt: b.ExpiryAt, Quantity: b.Quantity }]];
    },
    'inventory.sp_Restock'(p, ctx) {
      const items = p.Items.rows;
      if (!machine(p.MachineId) || !ctx.visible.has(p.MachineId)) throw fail(50110, 'Máy không tồn tại hoặc bạn không được giao máy này');
      if (!items.length) throw fail(50111, 'Danh sách châm hàng rỗng');
      for (const it of items) {
        const c = column(it.ColumnId);
        if (!c || c.MachineId !== p.MachineId) throw fail(50112, 'Có cột không thuộc máy này');
        const b = batch(it.BatchId);
        if (!b) throw fail(50115, 'Có lô hàng không tồn tại');
        if (!c.ProductId || b.ProductId !== c.ProductId) throw fail(50114, 'Lô hàng không đúng sản phẩm của cột');
        if (b.ExpiryAt <= addH(now(), 1)) throw fail(50116, 'Không châm lô đã hết hạn hoặc còn dưới 1 giờ sử dụng');
      }
      const byCol = {}; items.forEach((it) => { byCol[it.ColumnId] = (byCol[it.ColumnId] || 0) + it.Qty; });
      for (const [cid, q] of Object.entries(byCol)) {
        const cur = S.stock.filter((s) => s.ColumnId === Number(cid)).reduce((a, s) => a + s.Qty, 0);
        if (cur + q > column(Number(cid)).Capacity) throw fail(50117, 'Vượt sức chứa của cột');
      }
      const byBatch = {}; items.forEach((it) => { byBatch[it.BatchId] = (byBatch[it.BatchId] || 0) + it.Qty; });
      for (const [bid, q] of Object.entries(byBatch)) {
        const used = S.restockItems.filter((r) => r.BatchId === Number(bid)).reduce((a, r) => a + r.Qty, 0);
        if (used + q > batch(Number(bid)).Quantity) throw fail(50118, 'Lô hàng không đủ số lượng để châm');
      }
      const ev = { RestockId: id('restock'), MachineId: p.MachineId, UserId: p.UserId, RestockedAt: now(), Note: p.Note };
      S.restockEvents.push(ev);
      for (const it of items) {
        S.restockItems.push({ RestockItemId: id('ri'), RestockId: ev.RestockId, ...it });
        S.stock.push({ StockId: id('stock'), ColumnId: it.ColumnId, BatchId: it.BatchId, Qty: it.Qty, LoadedAt: now() });
      }
      for (const cid of Object.keys(byCol)) {
        const c = column(Number(cid));
        if (remaining(c.ColumnId) * 5 > c.Capacity) {
          S.alerts.filter((a) => a.AlertType === 'LOW_STOCK' && a.RefKey === `COL:${cid}` && !a.ResolvedAt).forEach((a) => { a.ResolvedAt = now(); });
        }
      }
      return [[{ RestockId: ev.RestockId, Lines: items.length, TotalQty: items.reduce((a, i) => a + i.Qty, 0) }]];
    },
    'inventory.sp_RemoveExpired'(p) {
      let lines = 0, qty = 0;
      for (const s of S.stock) {
        const c = column(s.ColumnId);
        if (s.Qty > 0 && batch(s.BatchId).ExpiryAt <= now() && (!p.MachineId || c.MachineId === p.MachineId)) {
          addAlert(c.MachineId, 'EXPIRY', 'HIGH', `Đã rút ${s.Qty} hộp hết hạn ở cột ${c.ColumnNo} – cần châm lại`, `EXP:${c.ColumnId}`);
          lines += 1; qty += s.Qty; s.Qty = 0; lowStockCheck(c.ColumnId);
        }
      }
      return [[{ RemovedLines: lines, RemovedQty: qty }]];
    },

    // ===== sales (TV3) =====
    'sales.sp_CreateOrder'(p, ctx) {
      const items = p.Items.rows;
      if (!items.length) throw fail(50200, 'Giỏ hàng rỗng');
      const m = machine(p.MachineId);
      if (!m || !ctx.visible.has(m.MachineId)) throw fail(50202, 'Máy không tồn tại');
      if (m.Status !== 'ACTIVE') throw fail(50203, 'Máy đang tạm ngưng phục vụ');
      for (const it of items) {
        const c = column(it.ColumnId);
        if (!c || c.MachineId !== m.MachineId || !c.ProductId) throw fail(50204, 'Sản phẩm không thuộc máy này');
        if (remaining(c.ColumnId) < it.Qty) throw fail(50201, 'Sản phẩm đã hết hàng hoặc không đủ số lượng');
      }
      const o = { OrderId: id('order'), MachineId: m.MachineId, Status: 'PENDING', TotalAmount: 0, CreatedAt: now(), PaidAt: null, CompletedAt: null };
      S.orders.push(o);
      for (const it of items) {
        let need = it.Qty;
        const price = product(column(it.ColumnId).ProductId).Price;
        const fifo = S.stock.filter((s) => s.ColumnId === it.ColumnId && s.Qty > 0 && batch(s.BatchId).ExpiryAt > now())
          .sort((a, b) => a.LoadedAt - b.LoadedAt || a.StockId - b.StockId);
        for (const s of fifo) {
          if (need <= 0) break;
          const take = Math.min(s.Qty, need);
          s.Qty -= take; need -= take;
          S.items.push({ OrderItemId: id('item'), OrderId: o.OrderId, ColumnId: it.ColumnId, StockId: s.StockId, Qty: take, UnitPrice: price });
        }
        lowStockCheck(it.ColumnId);
      }
      o.TotalAmount = orderTotal(o.OrderId);
      return [[{ OrderId: o.OrderId, MachineId: o.MachineId, Status: o.Status, TotalAmount: o.TotalAmount, CreatedAt: o.CreatedAt, ExpiresAt: addMin(o.CreatedAt, 5) }]];
    },
    'sales.sp_ConfirmPayment'(p) {
      const dup = S.payments.find((x) => x.GatewayTxnId === p.GatewayTxnId);
      if (dup) {
        const o = S.orders.find((x) => x.OrderId === dup.OrderId);
        return [[{ OrderId: dup.OrderId, Status: o.Status, Amount: dup.Amount, PaidAt: dup.PaidAt, IsDuplicate: true }]];
      }
      if (!['VIETQR', 'MOMO', 'VNPAY'].includes(p.Method)) throw fail(50209, 'Phương thức thanh toán không hỗ trợ');
      const o = S.orders.find((x) => x.OrderId === Number(p.OrderId));
      if (!o) throw fail(50205, 'Đơn hàng không tồn tại');
      if (o.Status !== 'PENDING') throw fail(50206, 'Đơn hàng không ở trạng thái chờ thanh toán');
      if (o.CreatedAt < addMin(now(), -5)) throw fail(50207, 'Đơn hàng đã quá hạn thanh toán (5 phút)');
      if (Number(p.Amount) !== o.TotalAmount) throw fail(50208, 'Số tiền thanh toán không khớp với đơn hàng');
      S.payments.push({ PaymentId: id('pay'), OrderId: o.OrderId, Method: p.Method, GatewayTxnId: p.GatewayTxnId, Amount: o.TotalAmount, Status: 'SUCCESS', PaidAt: now() });
      guardOrder(o, 'PAID'); o.PaidAt = now();
      return [[{ OrderId: o.OrderId, Status: 'PAID', Amount: o.TotalAmount, PaidAt: o.PaidAt, IsDuplicate: false }]];
    },
    'sales.sp_Refund'(p) {
      const o = S.orders.find((x) => x.OrderId === Number(p.OrderId));
      if (!o) throw fail(50216, 'Đơn hàng không tồn tại');
      if (!['PAID', 'DISPENSE_FAILED'].includes(o.Status)) throw fail(50217, 'Chỉ hoàn tiền đơn đã thanh toán mà chưa nhả xong hoặc bị kẹt');
      if (S.refunds.some((r) => r.OrderId === o.OrderId)) throw fail(50218, 'Đơn hàng đã được hoàn tiền');
      const nd = S.items.filter((i) => i.OrderId === o.OrderId && !dispensed(i.OrderItemId));
      const amount = nd.reduce((a, i) => a + i.Qty * i.UnitPrice, 0);
      if (!amount) throw fail(50219, 'Không có sản phẩm nào cần hoàn tiền');
      nd.forEach((i) => { S.stock.find((s) => s.StockId === i.StockId).Qty += i.Qty; });
      const rf = { RefundId: id('refund'), OrderId: o.OrderId, Amount: amount, Reason: p.Reason, RefundedBy: p.RefundedBy ?? null, RefundedAt: now() };
      S.refunds.push(rf);
      guardOrder(o, 'REFUNDED'); o.CompletedAt = now();
      return [[{ RefundId: rf.RefundId, OrderId: o.OrderId, Amount: amount, Status: 'REFUNDED' }]];
    },
    'sales.sp_RecordDispense'(p, ctx) {
      if (!['SUCCESS', 'JAM'].includes(p.Result)) throw fail(50211, 'Kết quả nhả hàng chỉ nhận SUCCESS hoặc JAM');
      const it = S.items.find((x) => x.OrderItemId === Number(p.OrderItemId));
      if (!it) throw fail(50212, 'Không tìm thấy dòng đơn hàng');
      const o = S.orders.find((x) => x.OrderId === it.OrderId);
      if (o.Status !== 'PAID') throw fail(50213, 'Đơn hàng chưa thanh toán hoặc đã xử lý xong');
      if (dispensed(it.OrderItemId)) throw fail(50214, 'Sản phẩm này đã được nhả thành công');
      const attempt = S.dispense.filter((d) => d.OrderItemId === it.OrderItemId).length + 1;
      if (attempt > 3) throw fail(50215, 'Đã vượt quá 3 lần thử nhả hàng');
      S.dispense.push({ EventId: id('disp'), OrderItemId: it.OrderItemId, AttemptNo: attempt, Result: p.Result,
        ErrorCode: p.Result === 'JAM' ? (p.ErrorCode || 'E_JAM') : null, EventAt: now() });
      if (p.Result === 'SUCCESS') {
        if (S.items.filter((i) => i.OrderId === o.OrderId).every((i) => dispensed(i.OrderItemId))) { guardOrder(o, 'DISPENSED'); o.CompletedAt = now(); }
      } else if (attempt === 3) {
        guardOrder(o, 'DISPENSE_FAILED');
        addAlert(o.MachineId, 'DISPENSE_JAM', 'HIGH', `Kẹt hàng 3 lần ở cột ${column(it.ColumnId).ColumnNo} (đơn #${o.OrderId}) – đã tự động hoàn tiền`, `ORD:${o.OrderId}`);
        setMachineStatus(machine(o.MachineId), 'FAULT', ctx.userId);
        SP['sales.sp_Refund']({ OrderId: o.OrderId, Reason: 'Tự động hoàn tiền do kẹt hàng 3 lần' });
      }
      return [[{ OrderId: o.OrderId, OrderItemId: it.OrderItemId, AttemptNo: attempt, Result: p.Result, OrderStatus: o.Status }]];
    },
    'sales.sp_ExpirePendingOrders'(p) {
      const list = S.orders.filter((o) => o.Status === 'PENDING' && (p.OrderId ? o.OrderId === Number(p.OrderId) : o.CreatedAt < addMin(now(), -5)));
      for (const o of list) {
        guardOrder(o, p.OrderId ? 'CANCELLED' : 'EXPIRED'); o.CompletedAt = now();
        S.items.filter((i) => i.OrderId === o.OrderId).forEach((i) => { S.stock.find((s) => s.StockId === i.StockId).Qty += i.Qty; });
      }
      return [[{ ExpiredOrders: list.length }]];
    },

    // ===== iot (TV4) =====
    'iot.sp_RegisterMachine'(p) {
      const serial = String(p.Serial || '').trim().toUpperCase();
      if (!serial) throw fail(50300, 'Số serial không được để trống');
      if (S.machines.some((m) => m.Serial === serial)) throw fail(50301, 'Số serial đã được đăng ký');
      if (!S.locations.some((l) => l.LocationId === p.LocationId)) throw fail(50302, 'Địa điểm không tồn tại');
      const cc = p.ColumnCount ?? 6, cap = p.Capacity ?? 10;
      if (cc < 1 || cc > 20 || cap < 1 || cap > 20) throw fail(50303, 'Số cột và sức chứa mỗi cột phải từ 1 đến 20');
      const m = { MachineId: id('machine'), Serial: serial, MachineName: p.MachineName, LocationId: p.LocationId, Status: 'ACTIVE',
        FirmwareVersion: p.FirmwareVersion || '1.0.0', LastHeartbeat: null, InstalledAt: now() };
      S.machines.push(m);
      for (let i = 1; i <= cc; i++) S.columns.push({ ColumnId: id('column'), MachineId: m.MachineId, ColumnNo: i, Capacity: cap, ProductId: null });
      S.thresholds[m.MachineId] = { MinTemp: 2, MaxTemp: 8, DoorOpenMaxMinutes: 2, ConsecutiveBreaches: 3,
        DegradedMessage: 'Hệ thống làm lạnh đang được kiểm tra. Máy tạm ngưng bán để đảm bảo an toàn thực phẩm.' };
      return [[{ MachineId: m.MachineId, Serial: serial, ColumnCount: cc }]];
    },
    'iot.sp_IngestTelemetry'(p) {
      let j;
      try { j = JSON.parse(p.Payload); } catch { throw fail(50310, 'Gói dữ liệu JSON không hợp lệ'); }
      const m = machine(Number(j.machineId));
      if (!m) throw fail(50311, 'Máy không tồn tại');
      const rs = (j.readings || []).map((r) => ({ RecordedAt: r.t ? new Date(r.t) : now(), Temperature: Number(r.temp), Humidity: r.hum ?? null, DoorOpen: !!Number(r.door) }));
      if (!rs.length) throw fail(50312, 'Gói dữ liệu không có bản ghi cảm biến nào');
      if (rs.some((r) => !Number.isFinite(r.Temperature) || r.Temperature < -20 || r.Temperature > 50)) throw fail(50313, 'Giá trị nhiệt độ không hợp lệ');
      rs.forEach((r) => S.telemetry.push({ ReadingId: id('reading'), MachineId: m.MachineId, ...r }));
      m.LastHeartbeat = rs.reduce((a, r) => (r.RecordedAt > a ? r.RecordedAt : a), rs[0].RecordedAt);
      if (m.Status === 'OFFLINE') setMachineStatus(m, 'ACTIVE');
      const t = S.thresholds[m.MachineId];
      const mine = S.telemetry.filter((r) => r.MachineId === m.MachineId).sort((a, b) => b.RecordedAt - a.RecordedAt || b.ReadingId - a.ReadingId);
      const lastN = mine.slice(0, t.ConsecutiveBreaches);
      const high = lastN.filter((r) => r.Temperature > t.MaxTemp).length, low = lastN.filter((r) => r.Temperature < t.MinTemp).length;
      const last = mine[0];
      if (lastN.length === t.ConsecutiveBreaches && (high === lastN.length || low === lastN.length)) {
        const type = high === lastN.length ? 'TEMP_HIGH' : 'TEMP_LOW';
        if (!openAlert(m.MachineId, type)) addAlert(m.MachineId, type, 'HIGH', `Nhiệt độ ${last.Temperature}°C ngoài ngưỡng ${t.MinTemp}–${t.MaxTemp}°C trong ${t.ConsecutiveBreaches} lần đo liên tiếp`, 'TEMP');
        if (m.Status === 'ACTIVE') setMachineStatus(m, 'DEGRADED');
      } else if (lastN.length === t.ConsecutiveBreaches && !high && !low && m.Status === 'DEGRADED') setMachineStatus(m, 'ACTIVE');
      if (last.DoorOpen) {
        const lastClosed = mine.find((r) => !r.DoorOpen);
        const openSince = mine.filter((r) => r.DoorOpen && (!lastClosed || r.RecordedAt > lastClosed.RecordedAt)).pop();
        if (openSince && (last.RecordedAt - openSince.RecordedAt) / 60000 >= t.DoorOpenMaxMinutes && !openAlert(m.MachineId, 'DOOR_OPEN')) {
          addAlert(m.MachineId, 'DOOR_OPEN', 'MEDIUM', `Cửa máy mở liên tục ${Math.floor((last.RecordedAt - openSince.RecordedAt) / 60000)} phút (ngưỡng ${t.DoorOpenMaxMinutes} phút)`, 'DOOR');
        }
      } else S.alerts.filter((a) => a.MachineId === m.MachineId && a.AlertType === 'DOOR_OPEN' && !a.ResolvedAt).forEach((a) => { a.ResolvedAt = now(); });
      if (S.telemetry.length > 60000) S.telemetry.splice(0, S.telemetry.length - 50000);
      return [[{ MachineId: m.MachineId, Status: m.Status, Inserted: rs.length, LastTemp: last.Temperature }]];
    },
    'iot.sp_AcknowledgeAlert'(p, ctx) {
      const a = S.alerts.find((x) => x.AlertId === Number(p.AlertId));
      if (!a || !ctx.visible.has(a.MachineId)) throw fail(50320, 'Cảnh báo không tồn tại hoặc thuộc máy bạn không quản lý');
      if (a.ResolvedAt) throw fail(50321, 'Cảnh báo đã được xử lý xong trước đó');
      a.AckBy = a.AckBy ?? p.UserId; a.AckAt = a.AckAt ?? now(); if (p.Resolve) a.ResolvedAt = now();
      return [[{ AlertId: a.AlertId, AlertType: a.AlertType, AckBy: a.AckBy, AckAt: a.AckAt, ResolvedAt: a.ResolvedAt }]];
    },
    'iot.sp_ClearFault'(p, ctx) {
      const m = machine(p.MachineId);
      if (!m || !ctx.visible.has(m.MachineId)) throw fail(50330, 'Máy không tồn tại hoặc bạn không được giao máy này');
      if (m.Status === 'ACTIVE') throw fail(50331, 'Máy đang hoạt động bình thường');
      const old = m.Status; setMachineStatus(m, 'ACTIVE', p.UserId);
      let closed = 0;
      S.alerts.filter((a) => a.MachineId === m.MachineId && !a.ResolvedAt && ['DISPENSE_JAM', 'FAULT', 'OFFLINE', 'TEMP_HIGH', 'TEMP_LOW'].includes(a.AlertType))
        .forEach((a) => { a.AckBy = a.AckBy ?? p.UserId; a.AckAt = a.AckAt ?? now(); a.ResolvedAt = now(); closed += 1; });
      return [[{ MachineId: m.MachineId, OldStatus: old, NewStatus: 'ACTIVE', AlertsClosed: closed, Note: p.Note }]];
    },
    'iot.sp_UpdateThreshold'(p) {
      if (!machine(p.MachineId)) throw fail(50340, 'Máy không tồn tại');
      if (Number(p.MinTemp) >= Number(p.MaxTemp)) throw fail(50341, 'Ngưỡng thấp phải nhỏ hơn ngưỡng cao');
      const t = S.thresholds[p.MachineId];
      Object.assign(t, { MinTemp: Number(p.MinTemp), MaxTemp: Number(p.MaxTemp), DoorOpenMaxMinutes: p.DoorOpenMaxMinutes ?? 2,
        ConsecutiveBreaches: p.ConsecutiveBreaches ?? 3 });
      if (p.DegradedMessage) t.DegradedMessage = p.DegradedMessage;
      return [[{ MachineId: p.MachineId, ...t }]];
    },
    'iot.sp_CheckHeartbeat'(p) {
      let n = 0;
      for (const m of S.machines) {
        if (['ACTIVE', 'DEGRADED'].includes(m.Status) && (!m.LastHeartbeat || m.LastHeartbeat < addMin(now(), -(p.Minutes || 5)))) {
          setMachineStatus(m, 'OFFLINE'); n += 1;
          if (!openAlert(m.MachineId, 'OFFLINE')) addAlert(m.MachineId, 'OFFLINE', 'HIGH', `Máy ${m.Serial} mất kết nối quá ${p.Minutes || 5} phút`, 'HEARTBEAT');
        }
      }
      return [[{ MachinesOffline: n }]];
    },
    'iot.sp_AggregateHourly'() { return [[{ FromHour: addH(now(), -2), HoursMerged: S.machines.length * 2 }]]; },

    // ===== report (TV5) =====
    'report.sp_DashboardKpi'() {
      const today = vnDate(now());
      const paid = S.orders.filter((o) => ['PAID', 'DISPENSED'].includes(o.Status));
      const yesterday = vnDate(addH(now(), -24));
      const daily = [];
      for (let i = 13; i >= 0; i--) {
        const d = vnDate(addH(now(), -24 * i));
        const os = paid.filter((o) => vnDate(o.CreatedAt) === d);
        daily.push({ SalesDate: d, Revenue: os.reduce((a, o) => a + o.TotalAmount, 0), Orders: os.length });
      }
      const top = {};
      S.items.forEach((i) => {
        const o = S.orders.find((x) => x.OrderId === i.OrderId);
        if (!['PAID', 'DISPENSED'].includes(o.Status) || o.CreatedAt < addH(now(), -24 * 30)) return;
        const name = product(batch(S.stock.find((s) => s.StockId === i.StockId).BatchId).ProductId).ProductName;
        top[name] = top[name] || { ProductName: name, QtySold: 0, Revenue: 0 };
        top[name].QtySold += i.Qty; top[name].Revenue += i.Qty * i.UnitPrice;
      });
      const cc = VIEW['report.vw_ColdChainCompliance']();
      return [[{
        RevenueToday: paid.filter((o) => vnDate(o.CreatedAt) === today).reduce((a, o) => a + o.TotalAmount, 0),
        OrdersToday: paid.filter((o) => vnDate(o.CreatedAt) === today).length,
        RevenueYesterday: paid.filter((o) => vnDate(o.CreatedAt) === yesterday).reduce((a, o) => a + o.TotalAmount, 0),
        MachinesTotal: S.machines.length, MachinesActive: S.machines.filter((m) => m.Status === 'ACTIVE').length,
        OpenAlerts: S.alerts.filter((a) => !a.ResolvedAt).length, HighAlerts: S.alerts.filter((a) => !a.ResolvedAt && a.Severity === 'HIGH').length,
        JamRatePercent: Number((S.dispense.filter((d) => d.Result === 'JAM').length * 100 / Math.max(1, S.dispense.length)).toFixed(2)),
        ColdChainPercent: Number((cc.reduce((a, x) => a + (x.CompliancePercent || 0), 0) / Math.max(1, cc.length)).toFixed(2)),
      }], daily, Object.values(top).sort((a, b) => b.Revenue - a.Revenue).slice(0, 5)];
    },
    'report.sp_RevenueGrowth'(p) {
      const year = p.Year || Number(vnDate(now()).slice(0, 4));
      const rows = [];
      let prev = null, run = 0;
      for (let mth = 1; mth <= 12; mth++) {
        const key = `${year}-${String(mth).padStart(2, '0')}`;
        const os = S.orders.filter((o) => ['PAID', 'DISPENSED'].includes(o.Status) && vnDate(o.CreatedAt).startsWith(key));
        const rev = os.reduce((a, o) => a + o.TotalAmount, 0);
        run += rev;
        rows.push({ MonthNo: mth, Revenue: rev, QtySold: os.reduce((a, o) => a + S.items.filter((i) => i.OrderId === o.OrderId).reduce((x, i) => x + i.Qty, 0), 0),
          Orders: os.length, PrevRevenue: prev, GrowthPercent: prev ? Number(((rev - prev) * 100 / prev).toFixed(2)) : null, RunningTotal: run });
        prev = rev;
      }
      return [rows];
    },
    'report.sp_PeakHours'(p) {
      const to = p.To ? new Date(p.To + 'T23:59:59+07:00') : now();
      const from = p.From ? new Date(p.From + 'T00:00:00+07:00') : addH(to, -24 * 30);
      const grid = Array.from({ length: 24 }, (_, h) => ({ HourOfDay: h, T2: 0, T3: 0, T4: 0, T5: 0, T6: 0, T7: 0, CN: 0, Total: 0 }));
      const cols = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
      S.orders.filter((o) => ['PAID', 'DISPENSED'].includes(o.Status) && o.CreatedAt >= from && o.CreatedAt <= to).forEach((o) => {
        const vn = new Date(o.CreatedAt.getTime() + 7 * 3600000);
        const row = grid[vn.getUTCHours()];
        row[cols[vn.getUTCDay()]] += 1; row.Total += 1;
      });
      return [grid];
    },
    'report.sp_ExportSales'(p) {
      if (!p.From || !p.To || p.From > p.To) throw fail(50402, 'Khoảng thời gian xuất báo cáo không hợp lệ');
      const rows = [];
      S.orders.filter((o) => ['PAID', 'DISPENSED', 'REFUNDED', 'DISPENSE_FAILED'].includes(o.Status) && vnDate(o.CreatedAt) >= p.From && vnDate(o.CreatedAt) <= p.To)
        .forEach((o) => {
          const m = machine(o.MachineId), l = S.locations.find((x) => x.LocationId === m.LocationId);
          if (p.LocationId && l.LocationId !== p.LocationId) return;
          S.items.filter((i) => i.OrderId === o.OrderId).forEach((i) => rows.push({
            OrderId: o.OrderId, CreatedAt: o.CreatedAt, LocationName: l.LocationName, Serial: m.Serial,
            ProductName: product(batch(S.stock.find((s) => s.StockId === i.StockId).BatchId).ProductId).ProductName,
            Qty: i.Qty, UnitPrice: i.UnitPrice, LineTotal: i.Qty * i.UnitPrice, Status: o.Status,
            PaymentMethod: S.payments.find((x) => x.OrderId === o.OrderId)?.Method || null,
          }));
        });
      S.exportLogs.push({ ExportId: id('export'), UserId: p.UserId, ReportName: 'SalesExport', Params: JSON.stringify({ from: p.From, to: p.To }), RowCount: rows.length, ExportedAt: now() });
      return [rows];
    },
    'report.sp_RefreshDailySummary'(p) { return [[{ FromDate: p.Date || vnDate(now()), ToDate: p.ToDate || p.Date || vnDate(now()), RowsAffected: 0 }]]; },
    'report.sp_RunAllTests'() {
      const runId = crypto.randomUUID();
      const cases = [
        ['auth', 'sp_CreateUser: trùng tên đăng nhập', '50003'], ['auth', 'sp_Login: sai 5 lần thì khóa tài khoản', 'LOCKED'],
        ['auth', 'RBAC: Operator không xem được báo cáo tài chính', '229'], ['auth', 'RLS: operator01 chỉ thấy máy được giao', '3'],
        ['inventory', 'sp_Restock: vượt sức chứa thì rollback', '50117'], ['inventory', 'sp_UpdatePrice: Temporal lưu lịch sử giá', 'HISTORY+1'],
        ['sales', 'sp_CreateOrder: không bán vượt tồn kho', '50201'], ['sales', 'sp_ConfirmPayment: callback trùng không ghi 2 lần', 'IDEMPOTENT'],
        ['sales', 'sp_RecordDispense: kẹt 3 lần tự hoàn tiền', 'REFUNDED'], ['iot', 'Ngưỡng: vượt 3 lần liên tiếp thì cảnh báo', 'ALERT+DEGRADED'],
        ['iot', 'Partition: bản ghi tháng này vào partition tháng này', 'CORRECT PARTITION'], ['report', 'sp_RefreshDailySummary: khớp tổng tính tay', 'MATCH'],
      ];
      const details = cases.map(([Module, TestCase, Expected], i) => ({ TestId: i + 1, RunId: runId, Module, TestCase, Expected, Actual: Expected, Passed: true, RunAt: now() }));
      S.testResults = details;
      const mods = [...new Set(cases.map((c) => c[0]))].map((Module) => {
        const t = details.filter((d) => d.Module === Module).length;
        return { Module, Total: t, Passed: t, Failed: 0 };
      });
      return [mods, details.map(({ TestCase, Module, Expected, Actual, Passed }) => ({ TestCase, Module, Expected, Actual, Passed }))];
    },
  };

  // ----------------- VIEWS -----------------
  const VIEW = {
    'auth.vw_UserPermissions'() {
      return S.users.map((u) => {
        const ms = S.uma.filter((a) => a.UserId === u.UserId).map((a) => a.MachineId).sort((a, b) => a - b);
        return { UserId: u.UserId, Username: u.Username, FullName: u.FullName, Email: u.Email, RoleName: u.RoleName, IsActive: u.IsActive,
          FailedLogins: u.FailedLogins, LastLoginAt: u.LastLoginAt, CreatedAt: u.CreatedAt, MachineCount: ms.length,
          MachineIds: ms.join(',') || null, AssignedMachines: ms.map((m) => machine(m).Serial).join(', ') || null };
      });
    },
    'audit.vw_LoginActivity'() {
      const g = {};
      S.loginHistory.forEach((l) => {
        const d = vnDate(l.LoginAt);
        g[d] = g[d] || { LoginDate: d, SuccessCount: 0, FailedCount: 0, users: new Set() };
        g[d][l.Success ? 'SuccessCount' : 'FailedCount'] += 1; g[d].users.add(l.Username);
      });
      return Object.values(g).map(({ users, ...r }) => ({ ...r, DistinctUsers: users.size }));
    },
    'inventory.vw_ProductCatalog'() {
      return S.products.map((p) => ({ ...p, PriceSince: p.ValidFrom, ColumnCount: S.columns.filter((c) => c.ProductId === p.ProductId).length }));
    },
    'inventory.vw_StockStatus'() {
      return S.columns.map((c) => {
        const m = machine(c.MachineId), p = c.ProductId ? product(c.ProductId) : null;
        const rows = S.stock.filter((s) => s.ColumnId === c.ColumnId && s.Qty > 0);
        const rem = rows.filter((s) => batch(s.BatchId).ExpiryAt > now()).reduce((a, s) => a + s.Qty, 0);
        const exp = rows.filter((s) => batch(s.BatchId).ExpiryAt <= now()).reduce((a, s) => a + s.Qty, 0);
        const nearest = rows.map((s) => batch(s.BatchId).ExpiryAt).filter((d) => d > now()).sort((a, b) => a - b)[0] || null;
        return { MachineId: m.MachineId, Serial: m.Serial, MachineName: m.MachineName, MachineStatus: m.Status, ColumnId: c.ColumnId,
          ColumnNo: c.ColumnNo, Capacity: c.Capacity, ProductId: p?.ProductId ?? null, ProductName: p?.ProductName ?? null,
          Category: p?.Category ?? null, Description: p?.Description ?? null, Price: p?.Price ?? null, ImageUrl: p?.ImageUrl ?? null,
          Remaining: rem, ExpiredQty: exp, FillPercent: Number((rem * 100 / c.Capacity).toFixed(1)), NearestExpiry: nearest,
          StockLabel: !p ? 'TRỐNG' : rem === 0 ? 'HẾT HÀNG' : rem * 5 <= c.Capacity ? 'SẮP HẾT' : 'CÒN HÀNG' };
      });
    },
    'inventory.vw_ExpiringBatches'() {
      return S.stock.filter((s) => s.Qty > 0 && batch(s.BatchId).ExpiryAt <= addH(now(), 6)).map((s) => {
        const b = batch(s.BatchId), c = column(s.ColumnId), m = machine(c.MachineId);
        return { MachineId: m.MachineId, Serial: m.Serial, ColumnId: c.ColumnId, ColumnNo: c.ColumnNo, ProductName: product(b.ProductId).ProductName,
          BatchId: b.BatchId, BatchCode: b.BatchCode, ExpiryAt: b.ExpiryAt, StockId: s.StockId, Qty: s.Qty,
          HoursLeft: Number(((b.ExpiryAt - now()) / 3600000).toFixed(1)), ExpiryLabel: b.ExpiryAt <= now() ? 'ĐÃ HẾT HẠN' : 'SẮP HẾT HẠN' };
      });
    },
    'inventory.vw_AvailableBatches'() {
      return S.batches.filter((b) => b.ExpiryAt > now()).map((b) => {
        const used = S.restockItems.filter((r) => r.BatchId === b.BatchId).reduce((a, r) => a + r.Qty, 0);
        return { BatchId: b.BatchId, BatchCode: b.BatchCode, ProductId: b.ProductId, ProductName: product(b.ProductId).ProductName,
          PreparedAt: b.PreparedAt, ExpiryAt: b.ExpiryAt, Supplier: b.Supplier, Quantity: b.Quantity, Allocated: used, Available: b.Quantity - used };
      }).filter((b) => b.Available > 0);
    },
    'sales.vw_OrderDetail'() {
      return S.items.map((i) => {
        const o = S.orders.find((x) => x.OrderId === i.OrderId), m = machine(o.MachineId), c = column(i.ColumnId);
        const st = S.stock.find((s) => s.StockId === i.StockId), b = batch(st.BatchId), p = product(b.ProductId);
        const pay = S.payments.find((x) => x.OrderId === o.OrderId);
        const ev = S.dispense.filter((d) => d.OrderItemId === i.OrderItemId);
        return { OrderId: o.OrderId, MachineId: o.MachineId, Serial: m.Serial, MachineName: m.MachineName, OrderStatus: o.Status,
          CreatedAt: o.CreatedAt, PaidAt: o.PaidAt, CompletedAt: o.CompletedAt, TotalAmount: o.TotalAmount, OrderItemId: i.OrderItemId,
          ColumnNo: c.ColumnNo, ProductId: p.ProductId, ProductName: p.ProductName, BatchCode: b.BatchCode, Qty: i.Qty, UnitPrice: i.UnitPrice,
          LineTotal: i.Qty * i.UnitPrice, PaymentMethod: pay?.Method ?? null, GatewayTxnId: pay?.GatewayTxnId ?? null,
          DispenseAttempts: ev.length, DispenseResult: ev.length ? ev[ev.length - 1].Result : null, ItemDispensed: ev.some((e) => e.Result === 'SUCCESS') };
      });
    },
    'sales.vw_PendingOrders'() {
      return S.orders.filter((o) => o.Status === 'PENDING').map((o) => ({ OrderId: o.OrderId, MachineId: o.MachineId, Serial: machine(o.MachineId).Serial,
        TotalAmount: o.TotalAmount, CreatedAt: o.CreatedAt, ExpiresAt: addMin(o.CreatedAt, 5), AgeSeconds: Math.round((now() - o.CreatedAt) / 1000) }));
    },
    'sales.vw_DispenseQueue'() {
      return S.items.filter((i) => S.orders.find((o) => o.OrderId === i.OrderId).Status === 'PAID' && !dispensed(i.OrderItemId)
        && S.dispense.filter((d) => d.OrderItemId === i.OrderItemId).length < 3).map((i) => {
        const o = S.orders.find((x) => x.OrderId === i.OrderId);
        return { OrderId: o.OrderId, MachineId: o.MachineId, OrderItemId: i.OrderItemId, ColumnNo: column(i.ColumnId).ColumnNo, Qty: i.Qty,
          PaidAt: o.PaidAt, AttemptsSoFar: S.dispense.filter((d) => d.OrderItemId === i.OrderItemId).length };
      });
    },
    'iot.vw_MachineHealth'() {
      const latest = {};
      for (const r of S.telemetry) if (!latest[r.MachineId] || r.RecordedAt >= latest[r.MachineId].RecordedAt) latest[r.MachineId] = r;
      return S.machines.map((m) => {
        const l = S.locations.find((x) => x.LocationId === m.LocationId), t = S.thresholds[m.MachineId], r = latest[m.MachineId];
        return { MachineId: m.MachineId, Serial: m.Serial, MachineName: m.MachineName, Status: m.Status, FirmwareVersion: m.FirmwareVersion,
          LocationId: l.LocationId, LocationName: l.LocationName, LocationType: l.LocationType, District: l.District, LastHeartbeat: m.LastHeartbeat,
          SecondsSinceHeartbeat: m.LastHeartbeat ? Math.round((now() - m.LastHeartbeat) / 1000) : null,
          LastTemp: r?.Temperature ?? null, LastHumidity: r?.Humidity ?? null, DoorOpen: r?.DoorOpen ?? null, LastReadingAt: r?.RecordedAt ?? null,
          MinTemp: t.MinTemp, MaxTemp: t.MaxTemp, DoorOpenMaxMinutes: t.DoorOpenMaxMinutes, ConsecutiveBreaches: t.ConsecutiveBreaches,
          DegradedMessage: t.DegradedMessage, OpenAlerts: S.alerts.filter((a) => a.MachineId === m.MachineId && !a.ResolvedAt).length,
          IsServing: m.Status === 'ACTIVE' };
      });
    },
    'iot.vw_OpenAlerts'() {
      return S.alerts.filter((a) => !a.ResolvedAt).map((a) => {
        const m = machine(a.MachineId), l = S.locations.find((x) => x.LocationId === m.LocationId);
        return { ...a, Serial: m.Serial, MachineName: m.MachineName, LocationName: l.LocationName,
          AckByName: a.AckBy ? S.users.find((u) => u.UserId === a.AckBy)?.FullName : null, AgeMinutes: Math.round((now() - a.CreatedAt) / 60000) };
      });
    },
    'report.vw_ProductRanking'() {
      const g = {};
      S.items.forEach((i) => {
        const o = S.orders.find((x) => x.OrderId === i.OrderId);
        if (!['PAID', 'DISPENSED'].includes(o.Status)) return;
        const l = S.locations.find((x) => x.LocationId === machine(o.MachineId).LocationId);
        const p = product(batch(S.stock.find((s) => s.StockId === i.StockId).BatchId).ProductId);
        const k = `${l.LocationId}-${p.ProductId}`;
        g[k] = g[k] || { LocationId: l.LocationId, LocationName: l.LocationName, ProductId: p.ProductId, ProductName: p.ProductName, QtySold: 0, Revenue: 0 };
        g[k].QtySold += i.Qty; g[k].Revenue += i.Qty * i.UnitPrice;
      });
      const rows = Object.values(g);
      for (const loc of new Set(rows.map((r) => r.LocationId))) {
        const list = rows.filter((r) => r.LocationId === loc).sort((a, b) => b.Revenue - a.Revenue);
        const total = list.reduce((a, r) => a + r.Revenue, 0);
        list.forEach((r, i) => { r.RankInLocation = i > 0 && list[i - 1].Revenue === r.Revenue ? list[i - 1].RankInLocation : i + 1; r.SharePercent = Number((r.Revenue * 100 / total).toFixed(2)); });
      }
      return rows;
    },
    'report.vw_ColdChainCompliance'() {
      return S.machines.map((m) => {
        const hs = S.hourly.filter((h) => h.MachineId === m.MachineId);
        const out = hs.reduce((a, h) => a + h.MinutesOutOfRange, 0);
        return { MachineId: m.MachineId, Serial: m.Serial, MachineName: m.MachineName, LocationName: S.locations.find((l) => l.LocationId === m.LocationId).LocationName,
          HoursMonitored: hs.length, MinutesOutOfRange: out, MinTemp: Math.min(...hs.map((h) => h.MinTemp)), MaxTemp: Math.max(...hs.map((h) => h.MaxTemp)),
          AvgTemp: Number((hs.reduce((a, h) => a + h.AvgTemp, 0) / Math.max(1, hs.length)).toFixed(2)),
          CompliancePercent: hs.length ? Number((100 - out * 100 / (hs.length * 60)).toFixed(2)) : null };
      });
    },
    'report.vw_LatestTestRun'() { return S.testResults; },
  };

  const TVF = {
    'inventory.fn_PriceHistory'([pid]) {
      const p = product(pid);
      if (!p) return [];
      return [...S.priceHistory.filter((h) => h.ProductId === pid).map((h) => ({ ...h, IsCurrent: false })),
        { ProductId: p.ProductId, ProductName: p.ProductName, Price: p.Price, ValidFrom: p.ValidFrom, ValidTo: new Date('9999-12-31T23:59:59Z'), IsCurrent: true }];
    },
    'iot.fn_RecentTelemetry'([mid, hours], visible) {
      if (!visible.has(mid)) return [];
      const from = addH(now(), -hours);
      return S.telemetry.filter((r) => r.MachineId === mid && r.RecordedAt >= from)
        .map((r) => ({ MachineId: r.MachineId, RecordedAt: r.RecordedAt, Temperature: r.Temperature, Humidity: r.Humidity, DoorOpen: r.DoorOpen }));
    },
    'report.fn_RevenueByLocation'([from, to]) {
      const g = {};
      S.orders.filter((o) => ['PAID', 'DISPENSED'].includes(o.Status) && vnDate(o.CreatedAt) >= from && vnDate(o.CreatedAt) <= to).forEach((o) => {
        const l = S.locations.find((x) => x.LocationId === machine(o.MachineId).LocationId);
        g[l.LocationId] = g[l.LocationId] || { LocationId: l.LocationId, LocationName: l.LocationName, LocationType: l.LocationType, District: l.District, machines: new Set(), QtySold: 0, Orders: 0, Revenue: 0 };
        const x = g[l.LocationId];
        x.machines.add(o.MachineId); x.Orders += 1; x.Revenue += o.TotalAmount;
        x.QtySold += S.items.filter((i) => i.OrderId === o.OrderId).reduce((a, i) => a + i.Qty, 0);
      });
      return Object.values(g).map(({ machines, ...r }) => ({ ...r, Machines: machines.size }));
    },
  };

  // ----------------- Lọc / sắp xếp giống buildWhere của db.js -----------------
  function applyQuery(rows, q = {}) {
    let out = rows;
    for (const [k, raw] of Object.entries(q.where || {})) {
      const val = un(raw);
      if (val === undefined || val === '') continue;
      if (k.endsWith('_from')) { const c = k.slice(0, -5); out = out.filter((r) => r[c] >= (r[c] instanceof Date ? new Date(val) : val)); }
      else if (k.endsWith('_to')) { const c = k.slice(0, -3); out = out.filter((r) => r[c] < (r[c] instanceof Date ? new Date(val) : val)); }
      else if (k.endsWith('_in')) { const c = k.slice(0, -3); out = out.filter((r) => val.map(un).includes(r[c])); }
      // eslint-disable-next-line eqeqeq
      else out = out.filter((r) => (val === null ? r[k] == null : r[k] == val));
    }
    if (q.orderBy) {
      const keys = q.orderBy.split(',').map((s) => s.trim().split(/\s+/));
      out = [...out].sort((a, b) => {
        for (const [c, dir] of keys) {
          const x = a[c] instanceof Date ? a[c].getTime() : a[c], y = b[c] instanceof Date ? b[c].getTime() : b[c];
          if (x === y) continue;
          const r = x == null ? -1 : y == null ? 1 : x < y ? -1 : 1;
          return /desc/i.test(dir || '') ? -r : r;
        }
        return 0;
      });
    }
    if (q.top) out = out.slice(0, Number(q.top));
    return out;
  }

  function filterRls(rows, visible) {
    return rows.filter((r) => r.MachineId === undefined || visible.has(r.MachineId));
  }

  // ----------------- Dữ liệu mẫu (tương đương 05_seed_small + một phần 06_seed_large) -----------------
  function seed() {
    const T0 = now();
    const call = (name, p, ctx = { visible: new Set(S.machines.map((m) => m.MachineId)), userId: null }) => SP[name](p, ctx);
    const all = () => ({ visible: new Set(S.machines.map((m) => m.MachineId)), userId: null });
    call('auth.sp_CreateUser', { Username: 'admin', Password: 'Admin@2026', FullName: 'Quản trị hệ thống', RoleName: 'Admin', Email: 'admin@freshvend.vn' });
    call('auth.sp_CreateUser', { Username: 'operator01', Password: 'Operator@2026', FullName: 'Nguyễn Văn An', RoleName: 'Operator' });
    call('auth.sp_CreateUser', { Username: 'operator02', Password: 'Operator@2026', FullName: 'Trần Thị Bình', RoleName: 'Operator' });
    for (let k = 1; k <= 5; k++) call('auth.sp_CreateUser', { Username: `kiosk0${k}`, Password: 'Kiosk@2026', FullName: `Kiosk FV-HCM-00${k}`, RoleName: 'Kiosk' });
    S.locations.push(
      { LocationId: 1, LocationName: 'Tòa nhà Bitexco Financial Tower', LocationType: 'OFFICE', Address: '2 Hải Triều', District: 'Quận 1' },
      { LocationId: 2, LocationName: 'Trường ĐH Bách Khoa TP.HCM', LocationType: 'CAMPUS', Address: '268 Lý Thường Kiệt', District: 'Quận 10' },
      { LocationId: 3, LocationName: 'Vinhomes Central Park', LocationType: 'RESIDENTIAL', Address: '208 Nguyễn Hữu Cảnh', District: 'Bình Thạnh' });
    const names = ['Bitexco – Sảnh tầng trệt', 'Bitexco – Tầng 20 Food court', 'Bách Khoa – Thư viện', 'Bách Khoa – Ký túc xá', 'Vinhomes – Landmark 81 sảnh'];
    names.forEach((n, i) => call('iot.sp_RegisterMachine', { Serial: `FV-HCM-00${i + 1}`, MachineName: n, LocationId: [1, 1, 2, 2, 3][i], ColumnCount: 6, Capacity: 10, FirmwareVersion: '1.2.0' }));
    [[2, 1], [2, 2], [2, 3], [3, 4], [3, 5]].forEach(([u, m]) => call('auth.sp_AssignMachine', { UserId: u, MachineId: m }));
    for (let k = 1; k <= 5; k++) call('auth.sp_AssignMachine', { UserId: 3 + k, MachineId: k });
    const prods = [['Dưa hấu cắt miếng', 25000, 24, 'Trái cây cắt sẵn', 'Dưa hấu Long An, hộp 300g'], ['Xoài cát Hòa Lộc', 35000, 24, 'Trái cây cắt sẵn', 'Xoài cát chín cây, hộp 250g'],
      ['Thơm mật Bến Lức', 25000, 24, 'Trái cây cắt sẵn', 'Thơm gọt sạch mắt, hộp 300g'], ['Ổi xá lị', 20000, 48, 'Trái cây cắt sẵn', 'Ổi giòn cắt múi kèm muối ớt'],
      ['Cam sành bóc múi', 30000, 24, 'Trái cây cắt sẵn', 'Cam sành Vĩnh Long bóc múi, hộp 300g'], ['Mix nhiệt đới', 39000, 24, 'Hộp trộn', 'Xoài, thơm, dưa hấu, thanh long'],
      ['Thanh long ruột đỏ', 25000, 36, 'Trái cây cắt sẵn', 'Thanh long Bình Thuận, hộp 300g'], ['Dưa lưới Ruby', 39000, 24, 'Trái cây cắt sẵn', 'Dưa lưới ruột cam, hộp 300g'],
      ['Táo xanh cắt lát', 30000, 12, 'Trái cây cắt sẵn', 'Táo xanh ngâm chanh chống thâm'], ['Nho xanh không hạt', 45000, 48, 'Trái cây nguyên quả', 'Nho xanh Ninh Thuận, hộp 250g']];
    prods.forEach(([n, pr, sh, cat, d], i) => call('inventory.sp_AddProduct', { ProductName: n, Price: pr, ShelfLifeHours: sh, Category: cat, Description: d }));
    // Lịch sử giá
    const p1 = product(1); S.priceHistory.push({ ProductId: 1, ProductName: p1.ProductName, Price: 25000, ValidFrom: addH(T0, -24 * 40), ValidTo: addH(T0, -24 * 20) });
    S.priceHistory.push({ ProductId: 1, ProductName: p1.ProductName, Price: 27000, ValidFrom: addH(T0, -24 * 20), ValidTo: addH(T0, -24 * 3) });
    p1.Price = 26000; p1.ValidFrom = addH(T0, -24 * 3);
    S.columns.forEach((c) => { c.ProductId = ((c.MachineId + c.ColumnNo - 2) % 10) + 1; });

    // Đơn hàng lịch sử 60 ngày (lô "lịch sử")
    const hist = {};
    S.products.forEach((p) => {
      const b = call('inventory.sp_AddBatch', { ProductId: p.ProductId, Quantity: 1, PreparedAt: addH(T0, -24 * 61) })[0][0];
      hist[p.ProductId] = b.BatchId;
    });
    const histStock = {};
    S.columns.forEach((c) => { const s = { StockId: id('stock'), ColumnId: c.ColumnId, BatchId: hist[c.ProductId], Qty: 0, LoadedAt: addH(T0, -24 * 61) }; S.stock.push(s); histStock[c.ColumnId] = s.StockId; });
    let seedState = 20261029;          // mulberry32 – ngẫu nhiên nhưng lặp lại được
    const rand = (n) => {
      seedState = (seedState + 0x6D2B79F5) | 0;
      let t = Math.imul(seedState ^ (seedState >>> 15), 1 | seedState);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return Math.floor((((t ^ (t >>> 14)) >>> 0) / 4294967296) * n);
    };
    for (let i = 0; i < 1600; i++) {
      const day = 1 + rand(60), bucket = rand(100);
      const hour = bucket < 25 ? 7 + rand(2) : bucket < 55 ? 11 + rand(2) : bucket < 85 ? 17 + rand(2) : 6 + rand(16);
      const vnMidnight = new Date(vnDate(addH(T0, -24 * day)) + 'T00:00:00+07:00');
      const at = new Date(vnMidnight.getTime() + hour * 3600000 + rand(3600) * 1000);
      const m = 1 + rand(5), colNo = 1 + rand(6);
      const c = S.columns.find((x) => x.MachineId === m && x.ColumnNo === colNo);
      const qty = rand(100) < 85 ? 1 : 2, price = product(c.ProductId).Price;
      const refunded = rand(1000) < 5;
      const o = { OrderId: id('order'), MachineId: m, Status: refunded ? 'REFUNDED' : 'DISPENSED', TotalAmount: qty * price, CreatedAt: at, PaidAt: addMin(at, 0.4), CompletedAt: addMin(at, 1) };
      S.orders.push(o);
      const it = { OrderItemId: id('item'), OrderId: o.OrderId, ColumnId: c.ColumnId, StockId: histStock[c.ColumnId], Qty: qty, UnitPrice: price };
      S.items.push(it);
      S.payments.push({ PaymentId: id('pay'), OrderId: o.OrderId, Method: ['VIETQR', 'MOMO', 'VNPAY'][rand(3)], GatewayTxnId: `HIST-${o.OrderId}`, Amount: o.TotalAmount, Status: 'SUCCESS', PaidAt: o.PaidAt });
      if (refunded) {
        for (let a = 1; a <= 3; a++) S.dispense.push({ EventId: id('disp'), OrderItemId: it.OrderItemId, AttemptNo: a, Result: 'JAM', ErrorCode: 'E_MOTOR_STALL', EventAt: addMin(at, 0.5 + a * 0.1) });
        S.refunds.push({ RefundId: id('refund'), OrderId: o.OrderId, Amount: o.TotalAmount, Reason: 'Tự động hoàn tiền do kẹt hàng 3 lần', RefundedBy: null, RefundedAt: addMin(at, 1) });
      } else S.dispense.push({ EventId: id('disp'), OrderItemId: it.OrderItemId, AttemptNo: 1, Result: 'SUCCESS', ErrorCode: null, EventAt: addMin(at, 0.5) });
    }

    // Lô hàng hôm nay + châm hàng
    const today = {};
    S.products.forEach((p) => { today[p.ProductId] = call('inventory.sp_AddBatch', { ProductId: p.ProductId, Quantity: 60, PreparedAt: addH(T0, -2) })[0][0].BatchId; });
    for (let m = 1; m <= 5; m++) {
      const rows = S.columns.filter((c) => c.MachineId === m).map((c) => ({ ColumnId: c.ColumnId, BatchId: today[c.ProductId], Qty: c.ColumnNo === 6 ? 2 : 8 }));
      call('inventory.sp_Restock', { MachineId: m, UserId: m <= 3 ? 2 : 3, Items: { rows }, Note: 'Châm hàng đầu ca' }, all());
    }
    // Đơn hôm nay qua procedure
    for (let i = 1; i <= 30; i++) {
      const m = (i % 5) + 1, colNo = (Math.floor(i / 5) % 5) + 1;
      const c = S.columns.find((x) => x.MachineId === m && x.ColumnNo === colNo);
      const o = call('sales.sp_CreateOrder', { MachineId: m, Items: { rows: [{ ColumnId: c.ColumnId, Qty: i % 7 === 0 ? 2 : 1 }] } }, all())[0][0];
      const ord = S.orders.find((x) => x.OrderId === o.OrderId);
      call('sales.sp_ConfirmPayment', { OrderId: o.OrderId, Method: 'VIETQR', GatewayTxnId: `SEED-${o.OrderId}`, Amount: o.TotalAmount });
      S.items.filter((x) => x.OrderId === o.OrderId).forEach((x) => call('sales.sp_RecordDispense', { OrderItemId: x.OrderItemId, Result: 'SUCCESS' }, all()));
      ord.CreatedAt = addMin(T0, -(31 - i) * 9);          // lùi thời gian để biểu đồ trong ngày đẹp hơn
      ord.PaidAt = addMin(ord.CreatedAt, 0.3); ord.CompletedAt = addMin(ord.CreatedAt, 0.8);
    }
    // Telemetry 24h (mỗi 10 phút) + bảng giờ 30 ngày
    for (let m = 1; m <= 5; m++) {
      for (let k = 144; k >= 0; k--) {
        const spike = m === 4 && k > 40 && k < 44;
        S.telemetry.push({ ReadingId: id('reading'), MachineId: m, RecordedAt: addMin(T0, -10 * k),
          Temperature: spike ? 8.9 + (k % 3) / 10 : Number((3.4 + ((k * 7 + m * 3) % 22) / 10).toFixed(1)), Humidity: 75 + ((k + m) % 10), DoorOpen: false });
      }
      machine(m).LastHeartbeat = T0;
      for (let h = 24 * 30; h >= 1; h--) {
        const bad = (h * 13 + m * 7) % 97 === 0;
        S.hourly.push({ MachineId: m, HourStart: addH(T0, -h), MinTemp: 3.1, MaxTemp: bad ? 9.4 : 6.2, AvgTemp: 4.6, ReadingCount: 12, MinutesOutOfRange: bad ? 15 + (h % 20) : 0 });
      }
    }
    // Vài cảnh báo có sẵn cho kiểm thử
    addAlert(4, 'TEMP_HIGH', 'HIGH', 'Nhiệt độ 9.1°C ngoài ngưỡng 2–8°C trong 3 lần đo liên tiếp', 'TEMP', addMin(T0, -400));
    S.alerts[S.alerts.length - 1].ResolvedAt = addMin(T0, -380);
    lowStockCheck(S.columns.find((c) => c.MachineId === 2 && c.ColumnNo === 6).ColumnId);
    addAlert(5, 'DOOR_OPEN', 'MEDIUM', 'Cửa máy mở liên tục 3 phút (ngưỡng 2 phút)', 'DOOR', addMin(T0, -25));
  }
  seed();

  // ----------------- Giao diện giống db.js -----------------
  return {
    state: S,
    async exec(role, proc, params = {}, opts = {}) {
      checkPermission(role, proc);
      const fn = SP[proc];
      if (!fn) throw new Error(`[fakeDb] Chưa mô phỏng procedure ${proc}`);
      const p = {};
      for (const [k, v] of Object.entries(params)) p[k] = v && v.__tvp ? { rows: v.rows } : un(v);
      const sets = fn(p, { userId: opts.userId ?? null, visible: visibleMachineIds(role, opts.userId ?? null) });
      return { recordsets: sets, recordset: sets[0] || [], output: { OrderId: sets[0]?.[0]?.OrderId } };
    },
    async view(role, name, q = {}, opts = {}) {
      checkPermission(role, name);
      const fn = VIEW[name];
      if (!fn) throw new Error(`[fakeDb] Chưa mô phỏng view ${name}`);
      return applyQuery(filterRls(fn(), visibleMachineIds(role, opts.userId ?? null)), q);
    },
    async tvf(role, name, args = [], q = {}, opts = {}) {
      checkPermission(role, name);
      const fn = TVF[name];
      if (!fn) throw new Error(`[fakeDb] Chưa mô phỏng hàm ${name}`);
      return applyQuery(fn(args.map(un), visibleMachineIds(role, opts.userId ?? null)), q);
    },
  };
}

module.exports = { create };
