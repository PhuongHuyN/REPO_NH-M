// TV3 – Quản lý đơn hàng (Admin): lọc, xem chi tiết, xác nhận tiền chuyển khoản, hoàn tiền thủ công
import { esc, money, dt, table, badge, modal, toast, formData } from '../ui.js';

export default {
  title: 'Đơn hàng', icon: 'receipt', group: 'Vận hành', roles: ['Admin'],
  async render(el, { api }) {
    el.innerHTML = `
      <div class="card">
        <form class="toolbar" id="f">
          <div class="field"><label>Trạng thái</label><select name="status">
            <option value="">Tất cả</option><option value="PENDING">Chờ thanh toán</option><option value="PAID">Đã thanh toán</option>
            <option value="DISPENSED">Đã nhận hàng</option><option value="DISPENSE_FAILED">Kẹt hàng</option><option value="REFUNDED">Đã hoàn tiền</option>
            <option value="EXPIRED">Hết hạn</option><option value="CANCELLED">Đã hủy</option></select></div>
          <div class="field"><label>Mã máy (ID)</label><input name="machineId" type="number" min="1" placeholder="Tất cả"></div>
          <button class="btn primary">Lọc</button>
        </form>
      </div>
      <div class="card"><div id="list"></div></div>`;
    const load = async () => {
      const f = formData(el.querySelector('#f'));
      const qs = new URLSearchParams(Object.entries(f).filter(([, v]) => v)).toString();
      const rows = await api.get('/api/orders?limit=150' + (qs ? '&' + qs : ''));
      el.querySelector('#list').innerHTML = table(rows, [
        { key: 'orderId', label: 'Đơn', render: (v) => `<a href="#" data-id="${v}">#${v}</a>` },
        { key: 'createdAt', label: 'Thời gian', render: dt },
        { key: 'serial', label: 'Máy' },
        { key: 'items', label: 'Sản phẩm', render: (v) => esc(v.map((i) => `${i.productName} ×${i.qty}`).join(', ')) },
        { key: 'totalAmount', label: 'Tổng', cls: 'num', render: money },
        { key: 'paymentMethod', label: 'Thanh toán' },
        { key: 'status', label: 'Trạng thái', render: badge },
      ], { empty: 'Không có đơn hàng phù hợp' });
    };
    el.querySelector('#f').addEventListener('submit', (e) => { e.preventDefault(); load(); });
    el.querySelector('#list').addEventListener('click', async (e) => {
      const a = e.target.closest('[data-id]');
      if (!a) return;
      e.preventDefault();
      const o = await api.get(`/api/orders/${a.dataset.id}`);
      const canRefund = ['PAID', 'DISPENSE_FAILED'].includes(o.status);
      const canConfirm = o.status === 'PENDING';
      modal(`Đơn hàng #${o.orderId}`, `
        <p>${badge(o.status)} · Máy <b>${esc(o.serial)}</b> · ${dt(o.createdAt)} · ${esc(o.paymentMethod || 'chưa thanh toán')} ${o.gatewayTxnId ? `(${esc(o.gatewayTxnId)})` : ''}</p>
        ${table(o.items, [
          { key: 'columnNo', label: 'Ô' }, { key: 'productName', label: 'Sản phẩm' }, { key: 'batchCode', label: 'Lô (FIFO)' },
          { key: 'qty', label: 'SL', cls: 'num' }, { key: 'unitPrice', label: 'Đơn giá', cls: 'num', render: money },
          { key: 'dispenseAttempts', label: 'Lần nhả', cls: 'num' },
          { key: 'dispensed', label: 'Kết quả', render: (v, r) => (v ? '<span class="badge green">Đã nhả</span>' : r.dispenseResult === 'JAM' ? '<span class="badge red">Kẹt</span>' : '–') },
        ])}
        <p class="right"><b>Tổng: ${money(o.totalAmount)}</b></p>
        ${canConfirm ? `<div class="card" style="background:var(--line-soft);border:none;padding:14px">
          <p class="small" style="margin:0 0 8px">Chỉ xác nhận khi đã thấy <b>${money(o.totalAmount)}</b> với nội dung <b>FV${o.orderId}</b> vào tài khoản (sao kê / app ngân hàng).</p>
          <form class="row" id="cf"><input name="reference" placeholder="Mã giao dịch ngân hàng (nếu có)" maxlength="40" class="grow" style="width:auto">
          <button class="btn primary">Xác nhận đã nhận tiền</button></form></div>` : ''}
        ${canRefund ? `<form class="row" id="rf"><input name="reason" placeholder="Lý do hoàn tiền" required minlength="3" class="grow" style="width:auto">
          <button class="btn warn">Hoàn tiền</button></form>` : ''}`, {
        onMount: (body, close) => {
          body.querySelector('#rf')?.addEventListener('submit', async (ev) => {
            ev.preventDefault();
            try {
              const r = await api.post(`/api/orders/${o.orderId}/refund`, formData(ev.target));
              toast(`Đã hoàn ${money(r.Amount)}`, 'ok'); close(); load();
            } catch (err) { toast(err.message, 'err'); }
          });
          body.querySelector('#cf')?.addEventListener('submit', async (ev) => {
            ev.preventDefault();
            if (!confirm(`Xác nhận đã nhận ${money(o.totalAmount)} cho đơn #${o.orderId}? Máy sẽ nhả hàng ngay.`)) return;
            try {
              await api.post(`/api/orders/${o.orderId}/confirm-payment`, formData(ev.target));
              toast('Đã xác nhận thanh toán, máy đang nhả hàng', 'ok'); close(); load();
            } catch (err) { toast(err.message, 'err'); }
          });
        },
      });
    });
    await load();
  },
};
