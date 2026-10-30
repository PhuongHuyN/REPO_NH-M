// Tiện ích giao diện dùng chung (TV3 dựng khung)
export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

export function esc(v) {
  return String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
export const money = (v) => (v == null ? '–' : Number(v).toLocaleString('vi-VN') + ' đ');
export const num = (v, d = 0) => (v == null ? '–' : Number(v).toLocaleString('vi-VN', { maximumFractionDigits: d, minimumFractionDigits: d }));
export function dt(v) {
  if (!v) return '–';
  const d = new Date(v);
  return d.toLocaleString('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit', year: 'numeric' });
}
export const dshort = (v) => (v ? new Date(v).toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit' }) : '–');
export const dfull = (v) => (v ? new Date(v).toLocaleDateString('vi-VN') : '–');
export function time(v) { return v ? new Date(v).toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', second: '2-digit' }) : '–'; }
export function ago(seconds) {
  if (seconds == null) return 'chưa có tín hiệu';
  if (seconds < 60) return `${seconds} giây trước`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)} phút trước`;
  return `${Math.floor(seconds / 3600)} giờ trước`;
}
export const todayISO = (offset = 0) => new Date(Date.now() + 7 * 3600e3 - offset * 86400e3).toISOString().slice(0, 10);

export function toast(msg, type = '') {
  let box = $('#toasts');
  if (!box) { box = document.createElement('div'); box.id = 'toasts'; document.body.appendChild(box); }
  const t = document.createElement('div');
  t.className = `toast ${type}`;
  t.textContent = msg;
  box.appendChild(t);
  setTimeout(() => t.remove(), type === 'err' ? 6000 : 3500);
}

export function modal(title, html, { onMount, wide } = {}) {
  const back = document.createElement('div');
  back.className = 'modal-back';
  back.innerHTML = `<div class="modal" style="${wide ? 'max-width:1000px' : ''}"><header><h3>${esc(title)}</h3>
    <button class="btn ghost sm" data-close aria-label="Đóng">✕</button></header><div class="modal-body">${html}</div></div>`;
  const close = () => back.remove();
  back.addEventListener('click', (e) => { if (e.target === back || e.target.closest('[data-close]')) close(); });
  document.body.appendChild(back);
  if (onMount) onMount(back.querySelector('.modal-body'), close);
  return close;
}

export function confirmBox(message) {
  return new Promise((resolve) => {
    const close = modal('Xác nhận', `<p>${esc(message)}</p><div class="row" style="justify-content:flex-end">
      <button class="btn ghost" data-no>Hủy</button><button class="btn primary" data-yes>Đồng ý</button></div>`, {
      onMount: (body) => {
        body.querySelector('[data-yes]').onclick = () => { close(); resolve(true); };
        body.querySelector('[data-no]').onclick = () => { close(); resolve(false); };
      },
    });
  });
}

// Bảng dữ liệu đơn giản: cols = [{ key, label, render?, cls? }]
export function table(rows, cols, { empty = 'Không có dữ liệu' } = {}) {
  if (!rows || !rows.length) return `<div class="empty">${esc(empty)}</div>`;
  const head = cols.map((c) => `<th class="${c.cls || ''}">${esc(c.label)}</th>`).join('');
  const body = rows.map((r, i) => `<tr data-i="${i}">${cols.map((c) =>
    `<td class="${c.cls || ''}">${c.render ? c.render(r[c.key], r) : esc(r[c.key])}</td>`).join('')}</tr>`).join('');
  return `<div class="table-wrap"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

export const STATUS_BADGE = {
  ACTIVE: ['green', 'Hoạt động'], DEGRADED: ['orange', 'Suy giảm làm lạnh'], OFFLINE: ['red', 'Mất kết nối'],
  FAULT: ['red', 'Lỗi'], MAINTENANCE: ['yellow', 'Bảo trì'],
  PENDING: ['yellow', 'Chờ thanh toán'], PAID: ['blue', 'Đã thanh toán'], DISPENSED: ['green', 'Đã nhận hàng'],
  DISPENSE_FAILED: ['red', 'Kẹt hàng'], REFUNDED: ['orange', 'Đã hoàn tiền'], EXPIRED: ['', 'Hết hạn'], CANCELLED: ['', 'Đã hủy'],
  HIGH: ['red', 'Cao'], MEDIUM: ['orange', 'Trung bình'], LOW: ['yellow', 'Thấp'],
};
export function badge(code) {
  const [cls, text] = STATUS_BADGE[code] || ['', code];
  return `<span class="badge ${cls}">${esc(text)}</span>`;
}
export const ALERT_LABEL = {
  LOW_STOCK: 'Sắp hết hàng', EXPIRY: 'Hết hạn', TEMP_HIGH: 'Nhiệt độ cao', TEMP_LOW: 'Nhiệt độ thấp', DOOR_OPEN: 'Cửa mở',
  DISPENSE_JAM: 'Kẹt hàng', OFFLINE: 'Mất kết nối', FAULT: 'Lỗi máy',
};

export function formData(form) {
  const o = {};
  new FormData(form).forEach((v, k) => { o[k] = typeof v === 'string' ? v.trim() : v; });
  return o;
}

// Ảnh minh họa thật khi sản phẩm chưa có ảnh riêng (ImageUrl rỗng).
// Ảnh chính thức: trang Sản phẩm & giá → Sửa → Chọn ảnh (lưu ở web/uploads/products/).
const PHOTOS = [
  [/thơm|dứa|khóm/i, 'pineapple'], [/thanh long/i, 'dragon-fruit'], [/nho|dâu/i, 'dragon-fruit-grapes'],
  [/mix|nhiệt đới|trộn|combo|xoài|dưa lưới/i, 'fruit-salad'], [/dưa hấu|tropical|bowl/i, 'fruit-bowl'],
  [/ổi|cam|quýt|măng cụt/i, 'fruit-market'], [/táo|chuối|kiwi|việt quất/i, 'berry-banana-bowl'],
];
const DEFAULT_PHOTOS = ['fruit-bowl', 'fruit-salad', 'berry-banana-bowl', 'pineapple', 'dragon-fruit', 'fruit-market', 'dragon-fruit-grapes'];
export function productImage(name = '', url = null, id = 0) {
  if (url) return url;
  const hit = PHOTOS.find(([re]) => re.test(name));
  return `img/products/${hit ? hit[1] : DEFAULT_PHOTOS[Math.abs(Number(id) || 0) % DEFAULT_PHOTOS.length]}.jpg`;
}
