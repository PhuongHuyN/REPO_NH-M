// Bọc Chart.js; nếu thư viện không tải được (máy không có Internet) thì vẽ biểu đồ cột đơn giản bằng HTML/CSS
const GREEN = '#1f5a43', ORANGE = '#ec6b39', BLUE = '#4a7fc1', RED = '#d14343';

// Biểu đồ cột dự phòng bằng HTML/CSS khi không tải được Chart.js (máy không có Internet)
function fallback(canvas, config) {
  const ds = config.data.datasets[0];
  const vals = ds.data.map(Number);
  const max = Math.max(1, ...vals);
  const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  canvas.parentElement.innerHTML = `<div class="fb-chart" title="${esc(ds.label || '')}">${config.data.labels.map((l, i) => `
    <div class="fb-row"><span class="fb-label">${esc(l)}</span><span class="fb-bar"><span style="width:${(vals[i] * 100 / max).toFixed(1)}%"></span></span>
    <span class="fb-val">${fmtVnd(vals[i])}</span></div>`).join('')}</div>`;
  return { destroy() {} };
}

export function chart(canvas, config) {
  if (!canvas) return { destroy() {} };
  if (!window.Chart) return fallback(canvas, config);
  window.Chart.defaults.font.family = 'Be Vietnam Pro, Segoe UI, sans-serif';
  window.Chart.defaults.color = '#87918c';
  window.Chart.defaults.borderColor = '#eef1ec';
  return new window.Chart(canvas, { ...config, options: { responsive: true, maintainAspectRatio: false, ...(config.options || {}) } });
}

export const fmtVnd = (v) => (v >= 1e6 ? (v / 1e6).toFixed(1) + ' tr' : v >= 1e3 ? Math.round(v / 1e3) + 'k' : Math.round(v * 10) / 10);

export function revenueLine(canvas, labels, revenue, orders) {
  return chart(canvas, {
    type: 'bar',
    data: {
      labels,
      datasets: [
        { type: 'bar', label: 'Doanh thu (đ)', data: revenue, backgroundColor: 'rgba(31,90,67,.85)', borderRadius: 6, yAxisID: 'y' },
        { type: 'line', label: 'Số đơn', data: orders, borderColor: ORANGE, backgroundColor: ORANGE, tension: .3, yAxisID: 'y1' },
      ],
    },
    options: {
      interaction: { mode: 'index', intersect: false },
      scales: { y: { ticks: { callback: fmtVnd } }, y1: { position: 'right', grid: { drawOnChartArea: false } } },
    },
  });
}

export function tempLine(canvas, points, min, max) {
  return chart(canvas, {
    type: 'line',
    data: {
      labels: points.map((p) => new Date(p.RecordedAt).toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' })),
      datasets: [
        { label: 'Nhiệt độ (°C)', data: points.map((p) => p.Temperature), borderColor: BLUE, pointRadius: 0, tension: .25 },
        { label: `Ngưỡng cao ${max}°C`, data: points.map(() => max), borderColor: RED, borderDash: [6, 4], pointRadius: 0 },
        { label: `Ngưỡng thấp ${min}°C`, data: points.map(() => min), borderColor: GREEN, borderDash: [6, 4], pointRadius: 0 },
      ],
    },
    options: { scales: { y: { suggestedMin: 0, suggestedMax: 12 } } },
  });
}

export function hbar(canvas, labels, data, label) {
  return chart(canvas, {
    type: 'bar',
    data: { labels, datasets: [{ label, data, backgroundColor: 'rgba(236,107,57,.85)', borderRadius: 6 }] },
    options: { indexAxis: 'y', plugins: { legend: { display: false } }, scales: { x: { ticks: { callback: fmtVnd } } } },
  });
}
