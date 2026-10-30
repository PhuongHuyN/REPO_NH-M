/* =====================================================================
   TV3 – Màn hình kiosk: chọn hàng -> giỏ -> chuyển khoản VietQR -> máy nhả hàng
   - Mã QR theo chuẩn VietQR (NAPAS 247): app ngân hàng nào cũng quét được
   - Tiền về tài khoản -> webhook ngân hàng xác nhận đơn (PAID) -> bộ điều khiển máy nhả hàng
   - Màn hình chỉ theo dõi trạng thái đơn; không tự xác nhận thanh toán, không tự báo nhả hàng
   - Mất kết nối máy chủ hoặc máy không ACTIVE => hiện "Tạm ngưng phục vụ"
   ===================================================================== */
import { Api } from './api.js';
import { $, esc, money, toast, productImage } from './ui.js';
import { icon } from './icons.js';

document.querySelectorAll('[data-ico]').forEach((el) => { el.innerHTML = icon(el.dataset.ico, Number(el.dataset.size) || 18); });

const api = new Api('kiosk');
const state = { menu: null, cart: new Map(), category: '', order: null, timers: {}, phase: 'shop' };
const IDLE_RESET_MS = 90 * 1000;      // khách bỏ đi: xóa giỏ sau 90 giây không thao tác
const DISPENSE_TIMEOUT_MS = 60 * 1000; // quá 60 giây máy chưa báo nhả hàng -> hướng dẫn liên hệ hỗ trợ

function show(id) { ['setup', 'shop'].forEach((s) => $('#' + s).classList.toggle('hidden', s !== id)); }
function overlay(id, on) { $('#' + id).classList.toggle('hidden', !on); }
function clearTimers(...names) { names.forEach((n) => { clearInterval(state.timers[n]); clearTimeout(state.timers[n]); }); }
const supportText = () => (state.menu?.support?.phone ? `Hỗ trợ khách hàng: ${state.menu.support.phone}` : 'Vui lòng liên hệ nhân viên phụ trách máy.');

// ---------- Kích hoạt thiết bị ----------
$('#setupForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  $('#setupErr').textContent = '';
  if (!$('#kUser').value || !$('#kPass').value) { $('#setupErr').textContent = 'Vui lòng nhập đủ mã thiết bị và mã kích hoạt'; return; }
  try {
    const user = await api.login($('#kUser').value.trim(), $('#kPass').value);
    if (user.role !== 'Kiosk') { api.logout(); throw new Error('Đây không phải tài khoản thiết bị'); }
    if (!user.machines.length) { api.logout(); throw new Error('Thiết bị chưa được gắn với máy bán hàng nào'); }
    $('#kPass').value = '';
    start();
  } catch (err) { $('#setupErr').textContent = err.offline ? 'Không kết nối được máy chủ' : err.message; }
});

const machineId = () => api.user?.machines?.[0];

// ---------- Thực đơn ----------
async function loadMenu() {
  try {
    const menu = await api.get(`/api/kiosk/menu?machineId=${machineId()}`);
    state.menu = menu;
    // Giỏ hàng: cập nhật lại tồn, bỏ món đã hết
    for (const [col, it] of state.cart) {
      const p = menu.items.find((x) => x.columnId === col);
      if (!p || p.remaining <= 0) state.cart.delete(col);
      else state.cart.set(col, { ...p, qty: Math.min(it.qty, p.remaining, 5) });
    }
    renderHeader(); renderTabs(); renderGrid(); renderCart();
    const m = menu.machine;
    if (!m.isServing) {
      showOutOfOrder(m.status === 'OFFLINE' ? 'wifiOff' : m.status === 'DEGRADED' ? 'thermo' : 'alert',
        m.status === 'DEGRADED' ? 'Tạm ngưng bán để kiểm tra nhiệt độ bảo quản' : 'Máy tạm ngưng phục vụ',
        m.degradedMessage || 'Xin lỗi quý khách, máy đang được bảo trì. Vui lòng quay lại sau.');
    } else if (state.phase === 'shop') overlay('outOfOrder', false);
  } catch (err) {
    if (err.offline) {
      showOutOfOrder('wifiOff', 'Tạm thời mất kết nối', 'Máy vẫn bảo quản lạnh bình thường nhưng chưa nhận thanh toán được. Hệ thống sẽ tự kết nối lại.');
      $('#mState').innerHTML = '<span class="dot red" title="Mất kết nối"></span>';
    } else if (err.status !== 401) toast(err.message, 'err');
  }
}

function showOutOfOrder(ic, title, msg) {
  if (state.phase !== 'shop') return;
  $('#oooIcon').innerHTML = icon(ic, 36);
  $('#oooTitle').textContent = title;
  $('#oooMsg').textContent = msg;
  $('#oooSupport').textContent = supportText();
  overlay('outOfOrder', true);
}

function renderHeader() {
  const m = state.menu.machine;
  $('#mSerial').textContent = m.serial || m.name;
  $('#mName').textContent = m.location || m.name;
  const t = m.lastTemp != null ? Number(m.lastTemp) : null;
  const tOk = t != null && t >= 2 && t <= 8;
  $('#mTemp').classList.toggle('warn', t != null && !tOk);
  $('#mTemp').innerHTML = `${icon('thermo', 22)}<span><b>${t != null ? t.toFixed(1) : '–'}°C</b><small>${t == null ? 'Chưa có số đo' : tOk ? 'Nhiệt độ an toàn' : 'Đang kiểm tra nhiệt độ'}</small></span>`;
  $('#mState').innerHTML = `<span class="dot ${m.isServing ? 'green' : 'red'}" title="${m.isServing ? 'Đang phục vụ' : 'Tạm ngưng'}"></span>`;
  $('#techInfo').innerHTML = `<dt>Tài khoản</dt><dd>${esc(api.user?.username)}</dd><dt>Máy</dt><dd>${esc(m.serial)} – ${esc(m.name)}</dd>
    <dt>Địa điểm</dt><dd>${esc(m.location)}</dd><dt>Trạng thái</dt><dd>${esc(m.status)}</dd>
    <dt>Nhiệt độ</dt><dd>${m.lastTemp != null ? Number(m.lastTemp).toFixed(1) + '°C' : '–'}</dd><dt>Cập nhật</dt><dd>${new Date().toLocaleTimeString('vi-VN')}</dd>`;
}

function renderTabs() {
  const cats = [...new Set(state.menu.items.map((p) => p.category).filter(Boolean))];
  if (state.category && !cats.includes(state.category)) state.category = '';
  $('#tabs').classList.toggle('hidden', cats.length < 2);
  $('#tabs').innerHTML = ['', ...cats].map((c) => `<button data-cat="${esc(c)}" class="${c === state.category ? 'active' : ''}">${esc(c || 'Tất cả')}</button>`).join('');
}

function renderGrid() {
  const items = state.menu.items.filter((p) => !state.category || p.category === state.category);
  $('#grid').innerHTML = items.map((p) => {
    const inCart = state.cart.get(p.columnId)?.qty || 0;
    const soldOut = p.remaining <= 0;
    const low = !soldOut && p.remaining <= 3;
    return `<button class="p-card ${inCart ? 'in-cart' : ''} ${soldOut ? 'sold-out' : ''}" data-col="${p.columnId}" ${soldOut ? 'disabled' : ''}>
      <div class="p-img">
        <img src="${esc(productImage(p.name, p.imageUrl, p.productId ?? p.columnId))}" alt="" loading="lazy">
        <span class="slot">Ô ${p.columnNo}</span>
        <span class="p-stock ${soldOut ? 'out' : low ? 'low' : ''}"><i></i>${soldOut ? 'Hết hàng' : low ? `Chỉ còn ${p.remaining}` : 'Còn hàng'}</span>
      </div>
      <div class="p-body">
        <div class="name">${esc(p.name)}</div>
        <div class="desc">${esc(p.description || '')}</div>
        <div class="foot"><span class="price">${money(p.price)}</span>
          <span class="add">${inCart ? `<span class="qty-badge">${inCart}</span>` : ''}${icon('plus', 20)}</span></div>
      </div>
    </button>`;
  }).join('') || '<div class="empty">Máy đang được bổ sung hàng</div>';
}

function addToCart(columnId, delta = 1) {
  const p = state.menu.items.find((x) => x.columnId === columnId);
  if (!p) return;
  const cur = state.cart.get(columnId)?.qty || 0;
  const max = Math.min(5, p.remaining);
  const next = Math.max(0, Math.min(max, cur + delta));
  if (delta > 0 && next === cur) toast(cur >= 5 ? 'Tối đa 5 phần mỗi loại cho một lần mua' : 'Đã hết số lượng còn trong máy');
  if (next === 0) state.cart.delete(columnId); else state.cart.set(columnId, { ...p, qty: next });
  renderGrid(); renderCart();
}

function renderCart() {
  const items = [...state.cart.values()];
  $('#cartList').innerHTML = items.length ? items.map((i) => `
    <div class="cart-item">
      <img class="c-img" src="${esc(productImage(i.name, i.imageUrl, i.productId ?? i.columnId))}" alt="">
      <div><div class="n">${esc(i.name)}</div><div class="p">${money(i.price)}</div></div>
      <div class="line">${money(i.price * i.qty)}</div>
      <div class="stepper"><button data-dec="${i.columnId}" aria-label="Bớt">${icon('minus', 16)}</button><b>${i.qty}</b><button data-inc="${i.columnId}" aria-label="Thêm">${icon('plus', 16)}</button></div>
    </div>`).join('') : '<div class="cart-empty">Chạm vào sản phẩm để chọn</div>';
  const n = items.reduce((a, i) => a + i.qty, 0);
  $('#cartCount').textContent = n ? `${n} sản phẩm` : '';
  $('#cartTotal').textContent = money(items.reduce((a, i) => a + i.qty * i.price, 0));
  $('#checkout').disabled = !items.length || !state.menu?.machine.isServing;
}

$('#tabs').addEventListener('click', (e) => { const b = e.target.closest('[data-cat]'); if (b) { state.category = b.dataset.cat; renderTabs(); renderGrid(); } });
$('#grid').addEventListener('click', (e) => { const b = e.target.closest('[data-col]'); if (b) addToCart(Number(b.dataset.col), 1); });
$('#cartList').addEventListener('click', (e) => {
  const inc = e.target.closest('[data-inc]'), dec = e.target.closest('[data-dec]');
  if (inc) addToCart(Number(inc.dataset.inc), 1);
  if (dec) addToCart(Number(dec.dataset.dec), -1);
});

// Khách bỏ đi giữa chừng: xóa giỏ
function touchIdle() {
  clearTimers('idle');
  state.timers.idle = setTimeout(() => {
    if (state.phase === 'shop' && state.cart.size) { state.cart.clear(); renderGrid(); renderCart(); }
  }, IDLE_RESET_MS);
}
document.addEventListener('pointerdown', touchIdle);

// ---------- Thanh toán ----------
$('#checkout').addEventListener('click', async () => {
  $('#checkout').disabled = true;
  let order = null;
  try {
    const items = [...state.cart.values()].map((i) => ({ columnId: i.columnId, qty: i.qty }));
    order = await api.post('/api/orders', { machineId: machineId(), items });
    state.order = order;
    const qr = await api.post('/api/payments/qr', { orderId: order.OrderId });
    showPayment(order, qr);
  } catch (err) {
    if (order) { try { await api.post(`/api/orders/${order.OrderId}/cancel`); } catch { /* bỏ qua */ } state.order = null; }
    toast(err.code === 'PAYMENT_NOT_CONFIGURED' ? 'Máy chưa sẵn sàng nhận thanh toán. Vui lòng liên hệ nhân viên.' : err.message, 'err');
    await loadMenu();
  } finally { renderCart(); }
});

function showPayment(order, qr) {
  state.phase = 'pay';
  overlay('outOfOrder', false);
  overlay('payment', true);
  $('#payOrder').textContent = `Đơn #${order.OrderId}`;
  $('#payAmount').textContent = money(qr.amount);
  $('#payBank').textContent = qr.bankName || '–';
  $('#payAcc').textContent = qr.accountNo;
  $('#payName').textContent = qr.accountName || '–';
  $('#payContent').textContent = qr.content;
  $('#qr').innerHTML = qr.qrSvg; // SVG do máy chủ vẽ, không cần thư viện ngoài

  const expires = new Date(order.ExpiresAt).getTime() || Date.now() + qr.expiresInSeconds * 1000;
  clearTimers('count', 'poll');
  const tickCount = () => {
    const s = Math.max(0, Math.round((expires - Date.now()) / 1000));
    $('#countdown').textContent = `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
    if (s === 0) cancelOrder('Hết thời gian thanh toán, đơn hàng đã được hủy');
  };
  tickCount();
  state.timers.count = setInterval(tickCount, 500);
  // Chờ ngân hàng báo tiền về (webhook cập nhật đơn sang PAID)
  state.timers.poll = setInterval(async () => {
    try {
      const o = await api.get(`/api/orders/${order.OrderId}`);
      if (o.status === 'PENDING') return;
      if (['EXPIRED', 'CANCELLED'].includes(o.status)) return cancelOrder('Đơn hàng đã hết hạn thanh toán');
      onPaid(o);
    } catch { /* mạng chập chờn – thử lại lần sau */ }
  }, 2000);
}

async function cancelOrder(msg) {
  clearTimers('count', 'poll');
  if (state.order) {
    try {
      await api.post(`/api/orders/${state.order.OrderId}/cancel`);
    } catch {
      // Đơn có thể vừa được thanh toán đúng lúc bấm hủy -> kiểm tra lại
      try { const o = await api.get(`/api/orders/${state.order.OrderId}`); if (o.status !== 'PENDING' && !['EXPIRED', 'CANCELLED'].includes(o.status)) return onPaid(o); } catch { /* */ }
    }
  }
  state.order = null;
  state.phase = 'shop';
  overlay('payment', false);
  if (msg) toast(msg);
  await loadMenu();
}
$('#cancelPay').addEventListener('click', () => cancelOrder('Đã hủy đơn hàng'));

// ---------- Chế độ demo (DB_MODE=demo): chưa có SQL Server / ngân hàng ----------
let demoMode = false;
fetch('/api/health').then((r) => r.json()).then((h) => {
  demoMode = h?.db?.mode === 'demo';
  $('#demoPay').classList.toggle('hidden', !demoMode);
  $('#setupDemo').classList.toggle('hidden', !demoMode);
}).catch(() => {});
$('#fillKiosk').addEventListener('click', () => { $('#kUser').value = 'kiosk01'; $('#kPass').value = 'Kiosk@2026'; });
$('#demoPay').addEventListener('click', async () => {
  if (!state.order) return;
  $('#demoPay').disabled = true;
  try { await api.post(`/api/demo/orders/${state.order.OrderId}/pay`); } // màn hình tự chuyển khi thấy đơn PAID
  catch (err) { toast(err.message, 'err'); }
  finally { $('#demoPay').disabled = false; }
});

// ---------- Nhả hàng: bộ điều khiển máy thực hiện và báo về máy chủ, màn hình chỉ theo dõi ----------
function onPaid(order) {
  if (state.phase === 'dispense') return;
  state.phase = 'dispense';
  clearTimers('count', 'poll');
  overlay('payment', false);
  overlay('dispense', true);
  $('#dispIcon').className = 'big-icon'; $('#dispIcon').innerHTML = '<span class="spinner"></span>';
  $('#dispTitle').textContent = 'Đã nhận thanh toán';
  $('#dispMsg').textContent = 'Máy đang lấy hàng, vui lòng chờ trong giây lát…';
  $('#receipt').innerHTML = '';
  $('#doneBtn').classList.add('hidden');
  const started = Date.now();
  const check = async (o) => {
    if (o.status === 'DISPENSED' || o.status === 'REFUNDED' || o.status === 'DISPENSE_FAILED') return finishOrder(o);
    if (Date.now() - started > DISPENSE_TIMEOUT_MS) return finishOrder(o, true);
    const done = o.items.filter((i) => i.dispensed).length;
    if (o.items.length > 1) $('#dispMsg').textContent = `Đang lấy hàng ${done}/${o.items.length}…`;
  };
  check(order);
  state.timers.dispense = setInterval(async () => {
    try { await check(await api.get(`/api/orders/${order.orderId}`)); } catch { /* thử lại */ }
  }, 1500);
}

function finishOrder(o, timeout = false) {
  clearTimers('dispense');
  if (o.status === 'DISPENSED') {
    $('#dispIcon').className = 'big-icon'; $('#dispIcon').innerHTML = icon('checkCircle', 40);
    $('#dispTitle').textContent = 'Mời quý khách nhận hàng ở khay bên dưới';
    $('#dispMsg').textContent = 'Cảm ơn quý khách đã mua hàng.';
  } else if (o.status === 'REFUNDED') {
    $('#dispIcon').className = 'big-icon warn'; $('#dispIcon').innerHTML = icon('refund', 36);
    $('#dispTitle').textContent = 'Xin lỗi, máy không lấy được hàng';
    $('#dispMsg').textContent = `Đơn #${o.orderId} đã được chuyển sang hoàn tiền. ${supportText()}`;
  } else {
    $('#dispIcon').className = 'big-icon warn'; $('#dispIcon').innerHTML = icon('alert', 36);
    $('#dispTitle').textContent = timeout ? 'Máy chưa phản hồi' : 'Có sự cố khi lấy hàng';
    $('#dispMsg').textContent = `Vui lòng giữ lại mã đơn #${o.orderId}. ${supportText()}`;
  }
  const delivered = o.items.filter((i) => i.dispensed);
  $('#receipt').innerHTML = `<div class="r-row"><b>Đơn #${o.orderId}</b><span class="muted">${new Date(o.paidAt || o.createdAt).toLocaleString('vi-VN')}</span></div>
    ${o.items.map((i) => `<div class="r-row"><span>${esc(i.productName)} × ${i.qty}</span><span>${money(i.lineTotal)}</span></div>`).join('')}
    <div class="r-row r-total"><span>Tổng cộng</span><span>${money(o.totalAmount)}</span></div>
    ${o.status !== 'DISPENSED' && delivered.length ? `<div class="r-row small muted"><span>Đã nhả</span><span>${delivered.length}/${o.items.length} món</span></div>` : ''}`;
  $('#doneBtn').classList.remove('hidden');
  state.cart.clear();
  state.order = null;
  renderGrid(); renderCart();
  clearTimers('done');
  state.timers.done = setTimeout(backToShop, o.status === 'DISPENSED' ? 10000 : 30000);
}
async function backToShop() {
  clearTimers('done', 'dispense');
  state.phase = 'shop';
  overlay('dispense', false);
  await loadMenu();
}
$('#doneBtn').addEventListener('click', backToShop);

// ---------- Bảng kỹ thuật: chạm logo 5 lần trong 3 giây ----------
let taps = [];
$('#brand').addEventListener('click', () => {
  const now = Date.now();
  taps = taps.filter((t) => now - t < 3000).concat(now);
  if (taps.length >= 5) { taps = []; $('#techPanel').classList.remove('hidden'); }
});
$('#closeTech').addEventListener('click', () => $('#techPanel').classList.add('hidden'));
$('#refreshMenu').addEventListener('click', loadMenu);
$('#logoutKiosk').addEventListener('click', () => {
  if (!confirm('Hủy kích hoạt màn hình này? Cần mã kích hoạt để dùng lại.')) return;
  api.logout(); location.reload();
});
window.addEventListener('fv:logout', () => location.reload());

// ---------- Khởi động ----------
function tick() { $('#clock').textContent = new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' }); }
function start() {
  show('shop');
  loadMenu();
  tick();
  setInterval(tick, 10000);
  setInterval(() => { if (state.phase === 'shop') loadMenu(); }, 10000);
  touchIdle();
}
if (api.token) start(); else show('setup');
