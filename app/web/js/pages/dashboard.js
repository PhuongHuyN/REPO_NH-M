// TV5 – Dashboard tổng quan (Admin): KPI, doanh thu 14 ngày, top sản phẩm, đội máy realtime
import { esc, money, num, table, badge, ago, dshort } from '../ui.js';
import { icon } from '../icons.js';
import { revenueLine, hbar } from '../charts.js';

const kpi = (ic, label, value, sub, cls = '', id = '') =>
  `<div class="kpi-card ${cls}" ${id ? `id="${id}"` : ''}><div class="label"><span class="chip">${icon(ic, 16)}</span>${label}</div>
   <div class="value">${value}</div><div class="sub">${sub}</div></div>`;

export default {
  title: 'Tổng quan', icon: 'dashboard', group: 'Tổng quan', roles: ['Admin'],
  async render(el, { api, live, lastHealth, go }) {
    const data = await api.get('/api/reports/kpi');
    const k = data.kpi;
    const diff = k.RevenueYesterday ? ((k.RevenueToday - k.RevenueYesterday) * 100 / k.RevenueYesterday) : null;
    el.innerHTML = `
      <div class="grid kpi">
        ${kpi('chart', 'Doanh thu hôm nay', money(k.RevenueToday), diff == null ? 'Chưa có số liệu hôm qua' : `${diff >= 0 ? '+' : '−'}${num(Math.abs(diff), 1)}% so với hôm qua`)}
        ${kpi('receipt', 'Đơn hàng hôm nay', num(k.OrdersToday), 'đơn đã thanh toán', 'info')}
        ${kpi('monitor', 'Máy đang hoạt động', `${k.MachinesActive}/${k.MachinesTotal}`, 'trên tổng số máy', k.MachinesActive < k.MachinesTotal ? 'warn' : '')}
        ${kpi('bell', 'Cảnh báo chưa xử lý', num(k.OpenAlerts), `${k.HighAlerts} cảnh báo mức cao`, k.HighAlerts ? 'danger' : k.OpenAlerts ? 'warn' : '', 'kAlerts')}
        ${kpi('alert', 'Tỷ lệ kẹt hàng', `${num(k.JamRatePercent, 2)}%`, 'mục tiêu dưới 2%', k.JamRatePercent >= 2 ? 'danger' : '')}
        ${kpi('thermo', 'Tuân thủ chuỗi lạnh', `${num(k.ColdChainPercent, 2)}%`, 'trong ngưỡng 2–8°C, 30 ngày', k.ColdChainPercent < 99 ? 'warn' : '')}
      </div>
      <div class="grid two">
        <div class="card"><h3>Doanh thu 14 ngày</h3><div class="chart-box"><canvas id="cRev"></canvas></div></div>
        <div class="card"><h3>Top sản phẩm 30 ngày</h3><div class="chart-box"><canvas id="cTop"></canvas></div></div>
      </div>
      <div class="card"><h3>Tình trạng đội máy <span class="small muted" id="fleetAt">đang chờ dữ liệu…</span></h3><div id="fleet"></div></div>`;
    el.querySelector('#kAlerts').style.cursor = 'pointer';
    el.querySelector('#kAlerts').onclick = () => go('alerts');

    const c1 = revenueLine(el.querySelector('#cRev'), data.daily.map((d) => dshort(d.SalesDate)),
      data.daily.map((d) => Number(d.Revenue)), data.daily.map((d) => d.Orders));
    const c2 = hbar(el.querySelector('#cTop'), data.topProducts.map((p) => p.ProductName), data.topProducts.map((p) => Number(p.Revenue)), 'Doanh thu');

    const renderFleet = (h) => {
      el.querySelector('#fleetAt').textContent = `cập nhật ${new Date(h.at).toLocaleTimeString('vi-VN')}`;
      el.querySelector('#fleet').innerHTML = table(h.machines, [
        { key: 'Serial', label: 'Máy', render: (v, r) => `<b>${esc(v)}</b><br><span class="small muted">${esc(r.MachineName)}</span>` },
        { key: 'LocationName', label: 'Địa điểm' },
        { key: 'Status', label: 'Trạng thái', render: (v) => badge(v) },
        { key: 'LastTemp', label: 'Nhiệt độ', cls: 'num', render: (v, r) => v == null ? '–' : `<b style="color:${v > r.MaxTemp || v < r.MinTemp ? 'var(--red)' : 'inherit'}">${num(v, 1)}°C</b>` },
        { key: 'DoorOpen', label: 'Cửa', render: (v) => (v ? '<span class="badge orange">Mở</span>' : '<span class="badge green">Đóng</span>') },
        { key: 'SecondsSinceHeartbeat', label: 'Tín hiệu', render: (v) => esc(ago(v)) },
        { key: 'OpenAlerts', label: 'Cảnh báo', cls: 'num' },
      ]);
    };
    if (lastHealth()) renderFleet(lastHealth());
    const onHealth = (e) => renderFleet(e.detail);
    live.addEventListener('health', onHealth);
    return () => { live.removeEventListener('health', onHealth); c1.destroy(); c2.destroy(); };
  },
};
