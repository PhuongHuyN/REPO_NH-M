#!/usr/bin/env node
// Chạy thử TOÀN BỘ giao diện khi CHƯA có SQL Server:  npm run demo
//  - API + web ở chế độ DB_MODE=demo (dữ liệu giả lập trong bộ nhớ)
//  - Bộ điều khiển máy (simulator) để máy "nhả hàng" sau khi thanh toán
// Dừng: Ctrl + C
const { spawn } = require('child_process');
const path = require('path');
const ROOT = path.join(__dirname, '..');
process.env.DB_MODE = 'demo';
const config = require(path.join(ROOT, 'api/src/config.js'));
const env = { ...process.env, DB_MODE: 'demo', DEVICE_API_KEY: config.deviceApiKey, PORT: String(config.port) };

const procs = [];
function run(name, args, filter) {
  const p = spawn(process.execPath, args, { cwd: ROOT, env });
  const out = (buf) => String(buf).split(/\r?\n/).filter((l) => l && (!filter || filter.test(l))).forEach((l) => console.log(`[${name}] ${l}`));
  p.stdout.on('data', out);
  p.stderr.on('data', out);
  p.on('exit', (code) => { if (code) console.log(`[${name}] dừng (mã ${code})`); });
  procs.push(p);
}
run('api', [path.join('api', 'src', 'server.js')], /^(?!.*(GET \/api\/(stream|dispense-queue|kiosk\/menu|orders\/\d+ |iot\/machines|health)|POST \/api\/iot\/telemetry)).*/);
setTimeout(() => run('máy', [path.join('simulator', 'esp32.js'), '--interval', '5'], /nhả|kẹt|Lỗi|lỗi|hoàn/i), 1500);
const stop = () => { procs.forEach((p) => p.kill()); process.exit(0); };
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
