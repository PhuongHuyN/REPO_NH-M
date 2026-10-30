#!/usr/bin/env node
/* =====================================================================
   TV4 – Chương trình bộ điều khiển máy (mô phỏng ESP32 khi chưa lắp phần cứng)
   Mỗi máy: đọc "cảm biến DHT22" -> gửi JSON tới POST /api/iot/telemetry (header X-Device-Key)
            hỏi hàng chờ nhả /api/dispense-queue mỗi 1,5 giây -> quay "servo" -> báo kết quả
   Chạy:  node simulator/esp32.js                      (máy 1–5, 5 giây/lần)
          node simulator/esp32.js --machines 1,3 --interval 2
          node simulator/esp32.js --count 20           (máy 1..20, dùng sau 06_seed_large)
          node simulator/esp32.js --overheat 3         (máy 3 nóng dần lên ~10°C -> cảnh báo)
          node simulator/esp32.js --door 2             (máy 2 mở cửa liên tục -> cảnh báo DOOR_OPEN)
          node simulator/esp32.js --jam 1              (máy 1 kẹt mọi lần nhả -> hoàn tiền tự động)
          node simulator/esp32.js --offline 4          (máy 4 im lặng -> job đánh dấu OFFLINE sau 5 phút)
   Biến môi trường: API_URL (mặc định http://localhost:3000), DEVICE_API_KEY
   Yêu cầu Node.js >= 18 (có sẵn fetch). Không cần cài thêm thư viện.
   ===================================================================== */
// Đọc api/.env (nếu có) để dùng chung DEVICE_API_KEY và PORT với API
try {
  const envFile = require('path').join(__dirname, '..', 'api', '.env');
  for (const line of require('fs').readFileSync(envFile, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2];
  }
} catch { /* không có .env thì dùng mặc định */ }

const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf('--' + name);
  return i >= 0 ? (args[i + 1] && !args[i + 1].startsWith('--') ? args[i + 1] : true) : def;
};
const list = (v) => (v === undefined || v === true ? [] : String(v).split(',').map(Number).filter(Boolean));

const API = (process.env.API_URL || opt('api', `http://localhost:${process.env.PORT || 3000}`)).replace(/\/$/, '');
const KEY = process.env.DEVICE_API_KEY || opt('key', '');
if (!KEY) { console.error('Thiếu DEVICE_API_KEY (đặt trong api/.env hoặc --key)'); process.exit(1); }
const INTERVAL = Number(opt('interval', 5)) * 1000;
const machines = list(opt('machines')).length ? list(opt('machines'))
  : Array.from({ length: Number(opt('count', 5)) }, (_, i) => i + 1);
const overheat = new Set(list(opt('overheat')));
const door = new Set(list(opt('door')));
const jam = new Set(list(opt('jam')));
const offline = new Set(list(opt('offline')));
const BATCH = Number(opt('batch', 1));     // số lần đo gom trong 1 gói (mô phỏng gửi lại khi có mạng)

const state = Object.fromEntries(machines.map((m) => [m, { temp: 3.5 + Math.random() * 2, buffer: [], tick: 0 }]));
const ts = () => {
  const d = new Date(Date.now() + 7 * 3600e3);          // giờ Việt Nam, khớp SYSDATETIME() của SQL Server
  return d.toISOString().slice(0, 19);
};
const log = (m, ...x) => console.log(`[${new Date().toLocaleTimeString('vi-VN')}] máy ${String(m).padStart(2)} |`, ...x);

async function call(method, path, body) {
  const res = await fetch(API + path, {
    method,
    headers: { 'Content-Type': 'application/json', 'X-Device-Key': KEY },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { const e = new Error(data.message || res.statusText); e.status = res.status; throw e; }
  return data;
}

// "Cảm biến DHT22": nhiệt độ dao động quanh 4–5°C, máy --overheat nóng dần tới ~10.5°C
function readSensor(m) {
  const s = state[m];
  s.tick += 1;
  const target = overheat.has(m) ? 10.5 : 4.5;
  s.temp += (target - s.temp) * (overheat.has(m) ? 0.35 : 0.2) + (Math.random() - 0.5) * 0.4;
  return {                                        // không gửi 't' => máy chủ lấy SYSDATETIME()
    temp: Math.round(s.temp * 10) / 10,
    hum: Math.round(75 + Math.random() * 10),
    door: door.has(m) ? 1 : 0,
  };
}

async function telemetry(m) {
  if (offline.has(m)) return;                     // máy mất mạng: không gửi gì
  const s = state[m];
  s.buffer.push(readSensor(m));
  if (s.buffer.length < BATCH) return;
  const readings = s.buffer.splice(0);
  try {
    const r = await call('POST', '/api/iot/telemetry', { machineId: m, readings });
    const last = readings[readings.length - 1];
    log(m, `🌡 ${last.temp}°C${last.door ? ' 🚪MỞ' : ''} -> trạng thái ${r.Status}`);
  } catch (e) {
    // Offline Mode: gắn thời điểm đo (giờ VN) rồi giữ lại, gửi bù khi có mạng
    readings.forEach((x) => { if (!x.t) x.t = ts(); });
    s.buffer.unshift(...readings);
    if (s.buffer.length > 500) s.buffer.splice(0, s.buffer.length - 500);
    log(m, `⚠ không gửi được (${e.message}) – lưu đệm ${s.buffer.length} bản ghi`);
  }
}

// "Servo": nhả hàng các đơn đã thanh toán
async function dispense(m) {
  if (offline.has(m)) return;
  let queue = [];
  try { queue = await call('GET', `/api/dispense-queue?machineId=${m}`); } catch { return; }
  for (const item of queue) {
    const result = jam.has(m) ? 'JAM' : 'SUCCESS';
    try {
      const r = await call('POST', `/api/orders/items/${item.OrderItemId}/dispense`, result === 'JAM' ? { result, errorCode: 'E_MOTOR_STALL' } : { result });
      log(m, `${result === 'JAM' ? '❌ kẹt' : '✅ nhả'} ô ${item.ColumnNo} đơn #${r.OrderId} (lần ${r.AttemptNo}) -> đơn ${r.OrderStatus}`);
    } catch (e) { log(m, `lỗi nhả hàng: ${e.message}`); }
  }
}

console.log(`FreshVend ESP32 simulator -> ${API} | máy: ${machines.join(',')} | chu kỳ ${INTERVAL / 1000}s`);
if (overheat.size) console.log('  quá nhiệt:', [...overheat].join(','));
if (door.size) console.log('  mở cửa:', [...door].join(','));
if (jam.size) console.log('  kẹt hàng:', [...jam].join(','));
if (offline.size) console.log('  mất mạng:', [...offline].join(','));

// Cảm biến gửi theo chu kỳ INTERVAL; hàng chờ nhả hỏi nhanh hơn để khách nhận hàng ngay sau khi trả tiền
const DISPENSE_POLL = 1500;
let busy = false;
async function pollDispense() {
  if (busy) return;
  busy = true;
  try { await Promise.all(machines.map(dispense)); } finally { busy = false; }
}
const sendTelemetry = () => Promise.all(machines.map(telemetry));
sendTelemetry();
setInterval(sendTelemetry, INTERVAL);
setInterval(pollDispense, DISPENSE_POLL);
