// Bộ lập lịch DỰ PHÒNG khi SQL Server không có Agent (bản Express): JOBS_FALLBACK=true
// Gọi đúng các procedure mà SQL Agent Job gọi (FreshVend_Database/27_jobs.sql).
const db = require('./db');

const timers = [];
async function run(name, proc, params = {}) {
  try {
    const r = await db.exec('Admin', proc, params);
    console.log(`[job ${name}] ${proc} ->`, JSON.stringify(r.recordset[0] || {}));
  } catch (e) {
    console.error(`[job ${name}] ${proc} lỗi:`, e.message);
  }
}

function everyMinute() {
  run('minute', 'iot.sp_CheckHeartbeat', { Minutes: 5 });
  run('minute', 'sales.sp_ExpirePendingOrders');
}
function everyHour() {
  const vn = new Date(Date.now() + 7 * 3600 * 1000);
  const today = vn.toISOString().slice(0, 10);
  const yesterday = new Date(vn.getTime() - 86400000).toISOString().slice(0, 10);
  run('hour', 'iot.sp_AggregateHourly');
  run('hour', 'inventory.sp_RemoveExpired');
  run('hour', 'report.sp_RefreshDailySummary', { Date: db.T.date(yesterday), ToDate: db.T.date(today) });
}

function start() {
  console.log('Bật bộ lập lịch dự phòng (mỗi phút / mỗi giờ). Bảo trì partition hằng tháng cần quyền sysadmin – chạy tay iot.sp_MaintainPartitions.');
  timers.push(setInterval(everyMinute, 60 * 1000));
  timers.push(setInterval(everyHour, 60 * 60 * 1000));
  setTimeout(everyHour, 5000);
}
function stop() { timers.splice(0).forEach(clearInterval); }

module.exports = { start, stop };
