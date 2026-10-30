// TV5 – Chạy unit test trong CSDL (report.sp_RunAllTests) và xem kết quả
import { esc, dt, table, toast } from '../ui.js';
import { icon } from '../icons.js';

export default {
  title: 'Kiểm thử hệ thống', icon: 'flask', group: 'Quản trị', roles: ['Admin'],
  async render(el, { api }) {
    el.innerHTML = `
      <div class="card">
        <div class="row between"><div><h3 style="margin:0">Kiểm thử cơ sở dữ liệu</h3>
          <span class="small muted">Chạy bộ kiểm thử tự động của từng module. Dữ liệu thật không bị thay đổi.</span></div>
          <button class="btn primary" id="run">${icon('activity',16)} Chạy kiểm thử</button></div>
      </div>
      <div class="card"><h3>Tổng hợp</h3><div id="sum"></div></div>
      <div class="card"><h3>Chi tiết lần chạy gần nhất</h3><div id="det"></div></div>`;
    const show = (summary, details) => {
      el.querySelector('#sum').innerHTML = table(summary, [
        { key: 'Module', label: 'Module' }, { key: 'Total', label: 'Tổng', cls: 'num' },
        { key: 'Passed', label: 'Đạt', cls: 'num', render: (v) => `<b style="color:var(--green-700)">${v}</b>` },
        { key: 'Failed', label: 'Lỗi', cls: 'num', render: (v) => (v ? `<b style="color:var(--red)">${v}</b>` : 0) },
      ], { empty: 'Chưa chạy test' });
      el.querySelector('#det').innerHTML = table(details, [
        { key: 'Passed', label: '', render: (v) => (v ? `<span class="badge green">${icon('check',12)} Đạt</span>` : `<span class="badge red">${icon('x',12)} Lỗi</span>`) },
        { key: 'Module', label: 'Module' }, { key: 'TestCase', label: 'Ca kiểm thử', render: (v) => `<span style="white-space:normal">${esc(v)}</span>` },
        { key: 'Expected', label: 'Mong đợi' }, { key: 'Actual', label: 'Thực tế', render: (v, r) => `<span style="white-space:normal;color:${r.Passed ? 'inherit' : 'var(--red)'}">${esc(v)}</span>` },
        { key: 'RunAt', label: 'Lúc', render: dt },
      ], { empty: 'Chưa có kết quả' });
    };
    el.querySelector('#run').addEventListener('click', async (e) => {
      e.target.disabled = true;
      e.target.innerHTML = 'Đang chạy…';
      try {
        const r = await api.post('/api/reports/run-tests');
        show(r.summary, r.details);
        const failed = r.summary.reduce((a, s) => a + s.Failed, 0);
        toast(failed ? `${failed} ca kiểm thử lỗi` : 'Tất cả ca kiểm thử đều đạt', failed ? 'err' : 'ok');
      } catch (err) { toast(err.message, 'err'); }
      finally { e.target.disabled = false; e.target.innerHTML = `${icon('activity',16)} Chạy kiểm thử`; }
    });
    const last = await api.get('/api/reports/test-results');
    const mods = [...new Set(last.map((x) => x.Module))].map((m) => {
      const xs = last.filter((x) => x.Module === m);
      return { Module: m, Total: xs.length, Passed: xs.filter((x) => x.Passed).length, Failed: xs.filter((x) => !x.Passed).length };
    });
    show(mods, last);
  },
};
