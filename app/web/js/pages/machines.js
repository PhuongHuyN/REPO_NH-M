// TV4 – Giám sát đội máy (Admin, Operator): trạng thái realtime, biểu đồ nhiệt độ, ngưỡng, xóa lỗi, đăng ký máy
import { esc, num, dt, ago, badge, modal, toast, formData } from '../ui.js';
import { icon } from '../icons.js';
import { tempLine } from '../charts.js';

export default {
  title: 'Máy & chuỗi lạnh', icon: 'snowflake', group: 'Vận hành', roles: ['Admin', 'Operator'],
  async render(el, { api, user, live }) {
    const isAdmin = user.role === 'Admin';
    el.innerHTML = `
      ${isAdmin ? `<div class="card"><h3>Đăng ký máy mới</h3><form class="form-grid" id="reg">
        <div class="field"><label>Serial</label><input name="serial" placeholder="FV-HCM-021" required></div>
        <div class="field"><label>Tên máy</label><input name="machineName" required></div>
        <div class="field"><label>Địa điểm</label><select name="locationId" id="locSel"></select></div>
        <div class="field"><label>Số cột</label><input name="columnCount" type="number" min="1" max="20" value="6"></div>
        <div class="field"><label>Sức chứa / cột</label><input name="capacity" type="number" min="1" max="20" value="10"></div>
        <button class="btn primary">Đăng ký</button></form></div>` : ''}
      <div class="row between"><span class="muted small" id="at">Đang tải…</span><span class="small muted">Bấm vào thẻ máy để xem chi tiết</span></div>
      <div class="machine-cards" id="cards"></div>`;

    const render = (machines) => {
      el.querySelector('#cards').innerHTML = machines.map((m) => {
        const bad = m.LastTemp != null && (m.LastTemp > m.MaxTemp || m.LastTemp < m.MinTemp);
        return `<div class="m-card ${m.Status}" data-id="${m.MachineId}">
          <div class="row between"><b>${esc(m.Serial)}</b>${badge(m.Status)}</div>
          <div class="small muted">${esc(m.MachineName)}</div>
          <div class="row between" style="margin-top:8px"><span class="temp ${bad ? 'bad' : ''}">${m.LastTemp == null ? '–' : num(m.LastTemp, 1)}°C</span>
            <span class="small right">Ngưỡng ${num(m.MinTemp, 1)}–${num(m.MaxTemp, 1)}°C<br>Cửa: ${m.DoorOpen ? '<b style="color:var(--orange)">MỞ</b>' : 'đóng'}</span></div>
          <div class="row between small muted" style="margin-top:6px"><span class="row" style="gap:5px">${icon('signal',14)} ${esc(ago(m.SecondsSinceHeartbeat))}</span><span class="row" style="gap:5px">${icon('bell',14)} ${m.OpenAlerts} cảnh báo</span></div>
        </div>`;
      }).join('') || '<div class="empty">Không có máy nào</div>';
    };
    const load = async () => { render(await api.get('/api/iot/machines')); el.querySelector('#at').textContent = 'Cập nhật ' + new Date().toLocaleTimeString('vi-VN'); };
    const onHealth = (e) => { render(e.detail.machines); el.querySelector('#at').textContent = 'Realtime ' + new Date(e.detail.at).toLocaleTimeString('vi-VN'); };
    live.addEventListener('health', onHealth);

    if (isAdmin) {
      const locs = await api.get('/api/iot/locations');
      el.querySelector('#locSel').innerHTML = locs.map((l) => `<option value="${l.locationId}">${esc(l.name)}</option>`).join('');
      el.querySelector('#reg').addEventListener('submit', async (e) => {
        e.preventDefault();
        const f = formData(e.target);
        try {
          await api.post('/api/iot/machines', { ...f, locationId: Number(f.locationId), columnCount: Number(f.columnCount), capacity: Number(f.capacity) }); // @roles Admin
          toast('Đã đăng ký máy – nhớ giao máy cho Operator ở trang Người dùng', 'ok'); e.target.reset(); load();
        } catch (err) { toast(err.message, 'err'); }
      });
    }

    el.querySelector('#cards').addEventListener('click', async (e) => {
      const card = e.target.closest('[data-id]');
      if (!card) return;
      const id = Number(card.dataset.id);
      const m = (await api.get('/api/iot/machines')).find((x) => x.MachineId === id);
      const points = await api.get(`/api/iot/machines/${id}/telemetry?hours=24`);
      modal(`${m.Serial} – ${m.MachineName}`, `
        <p>${badge(m.Status)} · ${esc(m.LocationName)} · firmware ${esc(m.FirmwareVersion)} · tín hiệu cuối ${dt(m.LastHeartbeat)}</p>
        <div class="chart-box"><canvas id="tc"></canvas></div>
        <p class="small muted">${points.length} lần đo trong 24 giờ </p>
        ${m.Status !== 'ACTIVE' ? `<form class="row" id="cf"><input name="note" placeholder="Ghi chú sửa chữa" class="grow" style="width:auto"><button class="btn warn">Xóa trạng thái lỗi → ACTIVE</button></form>` : ''}
        ${isAdmin ? `<h3 style="margin-top:16px">Ngưỡng cảnh báo & thông điệp hiển thị</h3><form class="form-grid" id="tf">
          <div class="field"><label>Thấp (°C)</label><input name="minTemp" type="number" step="0.1" value="${m.MinTemp}"></div>
          <div class="field"><label>Cao (°C)</label><input name="maxTemp" type="number" step="0.1" value="${m.MaxTemp}"></div>
          <div class="field"><label>Cửa mở tối đa (phút)</label><input name="doorOpenMaxMinutes" type="number" value="${m.DoorOpenMaxMinutes}"></div>
          <div class="field"><label>Số lần vượt liên tiếp</label><input name="consecutiveBreaches" type="number" value="${m.ConsecutiveBreaches}"></div>
          <div class="field" style="grid-column:1/-1"><label>Thông điệp khi suy giảm làm lạnh (hiện trên kiosk)</label><input name="degradedMessage" value="${esc(m.DegradedMessage || '')}"></div>
          <button class="btn primary">Lưu ngưỡng</button></form>` : ''}`, {
        wide: true,
        onMount: (body, close) => {
          tempLine(body.querySelector('#tc'), points, Number(m.MinTemp), Number(m.MaxTemp));
          body.querySelector('#cf')?.addEventListener('submit', async (ev) => {
            ev.preventDefault();
            try { await api.put(`/api/iot/machines/${id}/clear-fault`, formData(ev.target)); toast('Máy đã hoạt động trở lại', 'ok'); close(); load(); }
            catch (err) { toast(err.message, 'err'); }
          });
          body.querySelector('#tf')?.addEventListener('submit', async (ev) => {
            ev.preventDefault();
            const f = formData(ev.target);
            try {
              await api.put(`/api/iot/machines/${id}/thresholds`, { minTemp: Number(f.minTemp), maxTemp: Number(f.maxTemp), // @roles Admin
                doorOpenMaxMinutes: Number(f.doorOpenMaxMinutes), consecutiveBreaches: Number(f.consecutiveBreaches), degradedMessage: f.degradedMessage });
              toast('Đã lưu ngưỡng', 'ok'); close(); load();
            } catch (err) { toast(err.message, 'err'); }
          });
        },
      });
    });
    await load();
    return () => live.removeEventListener('health', onHealth);
  },
};
