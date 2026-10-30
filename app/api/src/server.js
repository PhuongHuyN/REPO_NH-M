// Điểm khởi động API: node src/server.js
const http = require('http');
const config = require('./config');
const db = require('./db');

// Chưa có SQL Server: dùng CSDL giả lập (cùng bộ dữ liệu mẫu với kiểm thử) để làm & demo giao diện
if (config.dbMode === 'demo') db.useDemo(require('../test/fakeDb').create());

const { handle } = require('./app');
const jobs = require('./jobs');

const server = http.createServer((req, res) => { handle(req, res); });
server.listen(config.port, () => {
  console.log(`FreshVend đang chạy tại http://localhost:${config.port}`);
  console.log(`  Bảng điều khiển : http://localhost:${config.port}/`);
  console.log(`  Màn hình kiosk  : http://localhost:${config.port}/kiosk`);
  console.log(`  Tài liệu API    : http://localhost:${config.port}/api-docs`);
  if (config.dbMode === 'demo') {
    console.log('  Cơ sở dữ liệu   : CHẾ ĐỘ DEMO – dữ liệu giả lập trong bộ nhớ, tắt máy chủ là mất (đổi DB_MODE=sqlserver trong api/.env khi đã có CSDL)');
    console.log('  Tài khoản demo  : admin / Admin@2026 · operator01 / Operator@2026 · kiosk01 / Kiosk@2026');
  } else db.ping()
    .then((r) => console.log(`  Cơ sở dữ liệu   : đã kết nối ${r.db || r.mode}`))
    .catch((e) => console.error(`  Cơ sở dữ liệu   : CHƯA kết nối được – ${e.message}\n  -> Kiểm tra SQL Server và file api/.env`));
  if (config.jobsFallback) jobs.start();
});

async function shutdown() {
  console.log('Đang tắt API...');
  jobs.stop();
  server.close();
  await db.close();
  process.exit(0);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
