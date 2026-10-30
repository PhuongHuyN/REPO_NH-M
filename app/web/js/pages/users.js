// TV1 – Quản lý người dùng (Admin): tạo tài khoản, khóa/mở, giao máy, thống kê đăng nhập
import { esc, dt, dfull, table, toast, formData, modal } from '../ui.js';

export default {
  title: 'Người dùng', icon: 'users', group: 'Quản trị', roles: ['Admin'],
  async render(el, { api }) {
    el.innerHTML = `
      <div class="card"><h3>Tạo tài khoản</h3>
        <form class="form-grid" id="add">
          <div class="field"><label>Tên đăng nhập</label><input name="username" required minlength="3" maxlength="50"></div>
          <div class="field"><label>Họ tên</label><input name="fullName" required></div>
          <div class="field"><label>Email</label><input name="email" type="email"></div>
          <div class="field"><label>Vai trò</label><select name="role"><option>Operator</option><option>Admin</option><option>Kiosk</option></select></div>
          <div class="field"><label>Mật khẩu (≥ 8 ký tự)</label><input name="password" type="password" minlength="8" required></div>
          <button class="btn primary">Tạo</button>
        </form>
      </div>
      <div class="card"><h3>Tài khoản</h3><div id="list"></div></div>
      <div class="card"><h3>Hoạt động đăng nhập</h3><div id="act"></div></div>`;
    const machines = await api.get('/api/iot/machines');
    const load = async () => {
      const [rows, act] = await Promise.all([api.get('/api/auth/users'), api.get('/api/auth/login-activity')]);
      el.querySelector('#list').innerHTML = table(rows, [
        { key: 'Username', label: 'Tài khoản', render: (v, r) => `<b>${esc(v)}</b><br><span class="small muted">${esc(r.FullName)}</span>` },
        { key: 'RoleName', label: 'Vai trò', render: (v) => `<span class="badge ${v === 'Admin' ? 'blue' : v === 'Operator' ? 'green' : ''}">${esc(v)}</span>` },
        { key: 'IsActive', label: 'Trạng thái', render: (v, r) => (v ? '<span class="badge green">Hoạt động</span>' : `<span class="badge red">Đã khóa</span>${r.FailedLogins >= 5 ? '<br><span class="small muted">sai MK 5 lần</span>' : ''}`) },
        { key: 'AssignedMachines', label: 'Máy được giao', render: (v) => esc(v || '–') },
        { key: 'LastLoginAt', label: 'Đăng nhập cuối', render: dt },
        { key: 'UserId', label: '', render: (v, r) => `${r.RoleName !== 'Admin' ? `<button class="btn sm" data-assign="${v}">Giao máy</button>` : ''}
            <button class="btn ${r.IsActive ? 'danger' : 'primary'} sm" data-toggle="${v}" data-active="${r.IsActive ? 1 : 0}">${r.IsActive ? 'Khóa' : 'Mở khóa'}</button>` },
      ]);
      el.querySelector('#act').innerHTML = table(act, [
        { key: 'LoginDate', label: 'Ngày', render: dfull }, { key: 'SuccessCount', label: 'Thành công', cls: 'num' },
        { key: 'FailedCount', label: 'Thất bại', cls: 'num', render: (v) => (v ? `<b style="color:var(--red)">${v}</b>` : 0) },
        { key: 'DistinctUsers', label: 'Số tài khoản', cls: 'num' },
      ]);
      el._rows = rows;
    };
    el.querySelector('#add').addEventListener('submit', async (e) => {
      e.preventDefault();
      try { await api.post('/api/auth/users', formData(e.target)); toast('Đã tạo tài khoản', 'ok'); e.target.reset(); load(); }
      catch (err) { toast(err.message, 'err'); }
    });
    el.querySelector('#list').addEventListener('click', async (e) => {
      const t = e.target.closest('[data-toggle]'), a = e.target.closest('[data-assign]');
      if (t) {
        try { await api.put(`/api/auth/users/${t.dataset.toggle}/active`, { active: t.dataset.active === '0' }); toast('Đã cập nhật', 'ok'); load(); }
        catch (err) { toast(err.message, 'err'); }
      }
      if (a) {
        const u = el._rows.find((r) => r.UserId === Number(a.dataset.assign));
        const assigned = new Set(String(u.MachineIds || '').split(',').filter(Boolean).map(Number));
        modal(`Giao máy cho ${u.Username}`, `<p class="small muted">Tài khoản chỉ xem và thao tác được trên các máy được chọn.</p>
          <div class="stack" id="ml">${machines.map((m) => `<label style="display:flex;gap:8px;font-weight:500"><input type="checkbox" style="width:auto" value="${m.MachineId}" ${assigned.has(m.MachineId) ? 'checked' : ''}>
          ${esc(m.Serial)} – ${esc(m.MachineName)}</label>`).join('')}</div>`, {
          onMount: (body) => body.querySelector('#ml').addEventListener('change', async (ev) => {
            const cb = ev.target;
            try { await api.post(`/api/auth/users/${u.UserId}/machines`, { machineId: Number(cb.value), unassign: !cb.checked }); toast('Đã cập nhật phân công', 'ok'); load(); }
            catch (err) { cb.checked = !cb.checked; toast(err.message, 'err'); }
          }),
        });
      }
    });
    await load();
  },
};
