// TV4 – Cảnh báo (Admin, Operator): sắp hết hàng, hết hạn, nhiệt độ, cửa mở, kẹt hàng, mất kết nối
import { esc, dt, table, badge, toast, ALERT_LABEL } from '../ui.js';

export default {
  title: 'Cảnh báo', icon: 'bell', group: 'Vận hành', roles: ['Admin', 'Operator'],
  async render(el, { api, live }) {
    el.innerHTML = `
      <div class="card">
        <div class="toolbar">
          <div class="field"><label>Mức độ</label><select id="sev"><option value="">Tất cả</option><option value="HIGH">Cao</option><option value="MEDIUM">Trung bình</option><option value="LOW">Thấp</option></select></div>
          <span class="small muted">Danh sách tự cập nhật theo thời gian thực.</span>
        </div>
      </div>
      <div class="card"><div id="list"></div></div>`;
    const render = (rows) => {
      const sev = el.querySelector('#sev').value;
      el.querySelector('#list').innerHTML = table(rows.filter((r) => !sev || r.Severity === sev), [
        { key: 'Severity', label: 'Mức', render: badge },
        { key: 'AlertType', label: 'Loại', render: (v) => `<b>${esc(ALERT_LABEL[v] || v)}</b>` },
        { key: 'Serial', label: 'Máy', render: (v, r) => `${esc(v)}<br><span class="small muted">${esc(r.LocationName)}</span>` },
        { key: 'Message', label: 'Nội dung', render: (v) => `<span style="white-space:normal">${esc(v)}</span>` },
        { key: 'CreatedAt', label: 'Lúc', render: dt },
        { key: 'AckByName', label: 'Đã nhận', render: (v, r) => (v ? `${esc(v)}<br><span class="small muted">${dt(r.AckAt)}</span>` : '–') },
        { key: 'AlertId', label: '', render: (v, r) => `${r.AckBy ? '' : `<button class="btn sm" data-ack="${v}">Nhận xử lý</button>`} <button class="btn primary sm" data-resolve="${v}">Đã xử lý</button>` },
      ], { empty: 'Không có cảnh báo nào cần xử lý' });
    };
    const load = async () => render(await api.get('/api/iot/alerts'));
    el.querySelector('#sev').addEventListener('change', load);
    el.querySelector('#list').addEventListener('click', async (e) => {
      const a = e.target.closest('[data-ack]'), r = e.target.closest('[data-resolve]');
      const id = a?.dataset.ack || r?.dataset.resolve;
      if (!id) return;
      try { await api.put(`/api/iot/alerts/${id}/ack`, { resolve: !!r }); toast(r ? 'Đã đóng cảnh báo' : 'Đã nhận xử lý', 'ok'); load(); }
      catch (err) { toast(err.message, 'err'); }
    });
    const onHealth = () => load();
    live.addEventListener('health', onHealth);
    await load();
    return () => live.removeEventListener('health', onHealth);
  },
};
