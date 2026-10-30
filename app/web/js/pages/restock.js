// TV2 – Châm hàng (Admin, Operator): xem tồn theo cột, chọn lô + số lượng nhiều cột => 1 lần gọi sp_Restock (TVP)
import { esc, money, dt, table, toast, formData, modal } from '../ui.js';

export default {
  title: 'Châm hàng & tồn kho', icon: 'package', group: 'Vận hành', roles: ['Admin', 'Operator'],
  async render(el, { api }) {
    const machines = await api.get('/api/iot/machines');
    if (!machines.length) { el.innerHTML = '<div class="card empty">Tài khoản của bạn chưa được giao máy nào. Vui lòng liên hệ quản trị viên.</div>'; return; }
    el.innerHTML = `
      <div class="card">
        <div class="toolbar">
          <div class="field"><label>Máy</label><select id="mSel">${machines.map((m) => `<option value="${m.MachineId}">${esc(m.Serial)} – ${esc(m.MachineName)}</option>`).join('')}</select></div>
          <button class="btn" id="newBatch">+ Nhập lô mới</button>
          <button class="btn ghost" id="rmExp">Rút hàng hết hạn</button>
        </div>
        <p class="small muted" style="margin:10px 0 0">Chọn lô và số lượng cho các ô cần châm, sau đó bấm <b>Xác nhận châm hàng</b>. Nếu một dòng không hợp lệ, toàn bộ lần châm sẽ không được ghi nhận.</p>
      </div>
      <div class="card"><h3>Tồn kho theo cột <span id="mInfo" class="small muted"></span></h3><div id="cols"></div>
        <div class="row" style="justify-content:flex-end;margin-top:12px"><input id="note" placeholder="Ghi chú (vd. Châm ca sáng)" style="max-width:320px">
        <button class="btn primary" id="submit">Xác nhận châm hàng</button></div></div>
      <div class="card"><h3>Lô sắp hết hạn (6 giờ) / đã hết hạn</h3><div id="exp"></div></div>`;

    const mSel = el.querySelector('#mSel');
    let stock = [], batches = [];
    const load = async () => {
      const mid = Number(mSel.value);
      [stock, batches] = await Promise.all([api.get(`/api/inventory/stock?machineId=${mid}`), api.get('/api/inventory/batches')]);
      const products = await api.get('/api/inventory/products').catch(() => []);
      el.querySelector('#mInfo').textContent = `${stock[0]?.Serial || ''} · ${stock[0]?.MachineStatus || ''}`;
      el.querySelector('#cols').innerHTML = `<div class="col-row head"><div>Ô</div><div>Sản phẩm</div><div>Tồn / sức chứa</div><div>Lô để châm</div><div>Số lượng</div></div>` +
        stock.map((c) => {
          const free = c.Capacity - c.Remaining - c.ExpiredQty;
          const opts = batches.filter((b) => b.ProductId === c.ProductId);
          const pct = Math.round((c.Remaining * 100) / c.Capacity);
          return `<div class="col-row" data-col="${c.ColumnId}">
            <div><span class="col-no">${c.ColumnNo}</span></div>
            <div>${c.ProductId ? `<b>${esc(c.ProductName)}</b><br><span class="small muted">${money(c.Price)}</span>` : '<span class="muted">Cột trống</span>'}
              ${c.Remaining + c.ExpiredQty === 0 ? `<br><select class="small" data-assign="${c.ColumnId}" style="margin-top:4px"><option value="">Đổi sản phẩm…</option>${products.map((p) => `<option value="${p.ProductId}">${esc(p.ProductName)}</option>`).join('')}</select>` : ''}</div>
            <div><div class="bar ${pct === 0 ? 'empty' : pct <= 20 ? 'low' : ''}"><span style="width:${pct}%"></span></div>
              <span class="small">${c.Remaining}/${c.Capacity} ${c.ExpiredQty ? `<span class="badge red">${c.ExpiredQty} hết hạn</span>` : ''} ${c.NearestExpiry ? `· HSD ${dt(c.NearestExpiry)}` : ''}</span></div>
            <div>${c.ProductId ? `<select data-batch>${opts.length ? opts.map((b) => `<option value="${b.BatchId}">${esc(b.BatchCode)} · còn ${b.Available} · HSD ${dt(b.ExpiryAt)}</option>`).join('') : '<option value="">Chưa có lô – nhập lô mới</option>'}</select>` : ''}</div>
            <div>${c.ProductId ? `<input data-qty type="number" min="0" max="${Math.max(0, free)}" value="0" title="Còn trống ${free}">` : ''}</div>
          </div>`;
        }).join('');
      const exp = await api.get(`/api/inventory/expiring?machineId=${mid}`);
      el.querySelector('#exp').innerHTML = table(exp, [
        { key: 'ColumnNo', label: 'Ô' }, { key: 'ProductName', label: 'Sản phẩm' }, { key: 'BatchCode', label: 'Lô' },
        { key: 'Qty', label: 'SL', cls: 'num' }, { key: 'ExpiryAt', label: 'Hết hạn', render: dt },
        { key: 'ExpiryLabel', label: '', render: (v) => `<span class="badge ${v === 'ĐÃ HẾT HẠN' ? 'red' : 'orange'}">${esc(v)}</span>` },
      ], { empty: 'Không có lô nào sắp hết hạn' });
    };

    mSel.addEventListener('change', load);
    el.querySelector('#cols').addEventListener('change', async (e) => {
      const s = e.target.closest('[data-assign]');
      if (!s || !s.value) return;
      try { await api.put(`/api/inventory/columns/${s.dataset.assign}`, { productId: Number(s.value) }); toast('Đã đổi sản phẩm cho cột', 'ok'); load(); }
      catch (err) { toast(err.message, 'err'); }
    });
    el.querySelector('#submit').addEventListener('click', async () => {
      const items = [...el.querySelectorAll('.col-row[data-col]')].map((r) => ({
        columnId: Number(r.dataset.col), batchId: Number(r.querySelector('[data-batch]')?.value || 0), qty: Number(r.querySelector('[data-qty]')?.value || 0),
      })).filter((x) => x.qty > 0);
      if (!items.length) return toast('Nhập số lượng cho ít nhất một cột', 'err');
      if (items.some((x) => !x.batchId)) return toast('Có cột chưa chọn lô hàng', 'err');
      try {
        const r = await api.post('/api/inventory/restock', { machineId: Number(mSel.value), note: el.querySelector('#note').value || null, items });
        toast(`Đã châm ${r.TotalQty} hộp (${r.Lines} dòng) – phiếu #${r.RestockId}`, 'ok');
        load();
      } catch (err) { toast(err.message, 'err'); }
    });
    el.querySelector('#rmExp').addEventListener('click', async () => {
      try { const r = await api.post('/api/inventory/remove-expired', { machineId: Number(mSel.value) }); toast(`Đã rút ${r.RemovedQty} hộp hết hạn`, 'ok'); load(); }
      catch (err) { toast(err.message, 'err'); }
    });
    el.querySelector('#newBatch').addEventListener('click', async () => {
      const products = await api.get('/api/inventory/products');
      modal('Nhập lô hàng mới', `<form class="stack" id="bf">
        <div><label>Sản phẩm</label><select name="productId">${products.map((p) => `<option value="${p.ProductId}">${esc(p.ProductName)} (HSD ${p.ShelfLifeHours}h)</option>`).join('')}</select></div>
        <div><label>Số hộp</label><input name="quantity" type="number" min="1" max="1000" value="40" required></div>
        <div><label>Nhà cung cấp / bếp</label><input name="supplier" value="Bếp trung tâm FreshVend"></div>
        <button class="btn primary">Tạo lô</button></form>`, {
        onMount: (body, close) => body.querySelector('#bf').addEventListener('submit', async (ev) => {
          ev.preventDefault();
          const f = formData(ev.target);
          try {
            const b = await api.post('/api/inventory/batches', { productId: Number(f.productId), quantity: Number(f.quantity), supplier: f.supplier });
            toast(`Đã tạo lô ${b.BatchCode}`, 'ok'); close(); load();
          } catch (err) { toast(err.message, 'err'); }
        }),
      });
    });
    await load();
  },
};
