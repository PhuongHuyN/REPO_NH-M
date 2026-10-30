// TV5 – Báo cáo & phân tích (Admin): tăng trưởng (LAG), giờ cao điểm (PIVOT), xếp hạng (RANK), chuỗi lạnh, xuất CSV
import { money, num, table, toast, todayISO, formData } from '../ui.js';
import { icon } from '../icons.js';
import { chart, fmtVnd } from '../charts.js';

const DAYS = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

export default {
  title: 'Báo cáo', icon: 'chart', group: 'Tổng quan', roles: ['Admin'],
  async render(el, { api }) {
    const year = new Date().getFullYear();
    el.innerHTML = `
      <div class="card">
        <form class="toolbar" id="f">
          <div class="field"><label>Từ ngày</label><input type="date" name="from" value="${todayISO(29)}"></div>
          <div class="field"><label>Đến ngày</label><input type="date" name="to" value="${todayISO()}"></div>
          <div class="field"><label>Năm (tăng trưởng)</label><input type="number" name="year" value="${year}" min="2020" max="2100"></div>
          <button class="btn primary">Xem báo cáo</button>
          <button class="btn" type="button" id="csv">${icon('download',16)} Xuất CSV</button>
          <button class="btn ghost" type="button" id="refresh">${icon('refresh',16)} Cập nhật số liệu</button>
        </form>
      </div>
      <div class="grid two">
        <div class="card"><h3>Doanh thu theo tháng</h3><div class="chart-box"><canvas id="cGrowth"></canvas></div><div id="tGrowth"></div></div>
        <div class="card"><h3>Doanh thu theo địa điểm</h3><div id="tLoc"></div></div>
      </div>
      <div class="card"><h3>Giờ cao điểm <span class="small muted">Số đơn theo giờ và thứ</span></h3><div id="tPeak"></div></div>
      <div class="grid two">
        <div class="card"><h3>Sản phẩm bán chạy theo địa điểm</h3><div id="tRank"></div></div>
        <div class="card"><h3>Tuân thủ chuỗi lạnh 30 ngày</h3><div id="tCold"></div></div>
      </div>`;
    let growthChart = null;
    const load = async () => {
      const f = formData(el.querySelector('#f'));
      try {
        const [growth, loc, peak, rank, cold] = await Promise.all([
          api.get(`/api/reports/revenue-growth?year=${f.year}`),
          api.get(`/api/reports/revenue-by-location?from=${f.from}&to=${f.to}`),
          api.get(`/api/reports/peak-hours?from=${f.from}&to=${f.to}`),
          api.get('/api/reports/ranking'),
          api.get('/api/reports/cold-chain'),
        ]);
        growthChart?.destroy();
        growthChart = chart(el.querySelector('#cGrowth'), {
          type: 'bar',
          data: {
            labels: growth.map((g) => 'T' + g.MonthNo),
            datasets: [
              { type: 'bar', label: 'Doanh thu', data: growth.map((g) => Number(g.Revenue)), backgroundColor: 'rgba(31,138,95,.75)', borderRadius: 6 },
              { type: 'line', label: 'Lũy kế', data: growth.map((g) => Number(g.RunningTotal)), borderColor: '#f08a24', tension: .3 },
            ],
          },
          options: { scales: { y: { ticks: { callback: fmtVnd } } } },
        });
        el.querySelector('#tGrowth').innerHTML = table(growth.filter((g) => Number(g.Revenue) > 0), [
          { key: 'MonthNo', label: 'Tháng' }, { key: 'Orders', label: 'Đơn', cls: 'num', render: (v) => num(v) },
          { key: 'Revenue', label: 'Doanh thu', cls: 'num', render: money },
          { key: 'GrowthPercent', label: '% so tháng trước', cls: 'num', render: (v) => v == null ? '–' : `<span style="color:${v >= 0 ? 'var(--green-700)' : 'var(--red)'}">${v >= 0 ? '▲' : '▼'} ${num(Math.abs(v), 2)}%</span>` },
          { key: 'RunningTotal', label: 'Lũy kế', cls: 'num', render: money },
        ], { empty: `Chưa có doanh thu năm ${f.year}` });
        el.querySelector('#tLoc').innerHTML = table(loc, [
          { key: 'LocationName', label: 'Địa điểm' }, { key: 'LocationType', label: 'Loại' }, { key: 'Machines', label: 'Máy', cls: 'num' },
          { key: 'Orders', label: 'Đơn', cls: 'num', render: (v) => num(v) }, { key: 'Revenue', label: 'Doanh thu', cls: 'num', render: money },
        ]);
        const max = Math.max(1, ...peak.flatMap((r) => DAYS.map((d) => r[d])));
        el.querySelector('#tPeak').innerHTML = `<div class="table-wrap"><table class="heat"><thead><tr><th>Giờ</th>${DAYS.map((d) => `<th>${d}</th>`).join('')}<th>Tổng</th></tr></thead><tbody>
          ${peak.filter((r) => r.HourOfDay >= 6 && r.HourOfDay <= 22).map((r) => `<tr><td><b>${r.HourOfDay}h</b></td>${DAYS.map((d) => {
            const a = r[d] / max;
            return `<td style="background:rgba(240,138,36,${(a * 0.85).toFixed(2)});color:${a > .55 ? '#fff' : 'inherit'}">${r[d] || ''}</td>`;
          }).join('')}<td><b>${r.Total}</b></td></tr>`).join('')}</tbody></table></div>`;
        el.querySelector('#tRank').innerHTML = table(rank.filter((r) => r.RankInLocation <= 3), [
          { key: 'LocationName', label: 'Địa điểm' }, { key: 'RankInLocation', label: 'Hạng', cls: 'num' }, { key: 'ProductName', label: 'Sản phẩm' },
          { key: 'QtySold', label: 'SL', cls: 'num', render: (v) => num(v) }, { key: 'Revenue', label: 'Doanh thu', cls: 'num', render: money },
          { key: 'SharePercent', label: 'Tỷ trọng', cls: 'num', render: (v) => num(v, 1) + '%' },
        ]);
        el.querySelector('#tCold').innerHTML = table(cold, [
          { key: 'Serial', label: 'Máy' }, { key: 'LocationName', label: 'Địa điểm' },
          { key: 'AvgTemp', label: 'TB °C', cls: 'num', render: (v) => num(v, 2) },
          { key: 'MaxTemp', label: 'Cao nhất', cls: 'num', render: (v) => num(v, 1) },
          { key: 'MinutesOutOfRange', label: 'Phút ngoài ngưỡng', cls: 'num', render: (v) => num(v) },
          { key: 'CompliancePercent', label: 'Tuân thủ', cls: 'num', render: (v) => v == null ? '–' : `<b style="color:${v >= 99 ? 'var(--green-700)' : 'var(--orange)'}">${num(v, 2)}%</b>` },
        ]);
      } catch (err) { toast(err.message, 'err'); }
    };
    el.querySelector('#f').addEventListener('submit', (e) => { e.preventDefault(); load(); });
    el.querySelector('#csv').addEventListener('click', async () => {
      const f = formData(el.querySelector('#f'));
      try { await api.download(`/api/reports/export.csv?from=${f.from}&to=${f.to}`, `freshvend_sales_${f.from}_${f.to}.csv`); toast('Đã xuất file CSV', 'ok'); }
      catch (err) { toast(err.message, 'err'); }
    });
    el.querySelector('#refresh').addEventListener('click', async () => {
      const f = formData(el.querySelector('#f'));
      try { const r = await api.post('/api/reports/refresh', { date: f.from, toDate: f.to }); toast('Đã cập nhật số liệu', 'ok'); load(); }
      catch (err) { toast(err.message, 'err'); }
    });
    await load();
    return () => growthChart?.destroy();
  },
};
