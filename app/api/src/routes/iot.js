/* =====================================================================
   TV4 – IoT & Chuỗi lạnh  (/api/iot/*)
   SP: iot.sp_RegisterMachine, sp_IngestTelemetry (OPENJSON), sp_AcknowledgeAlert,
       sp_ClearFault, sp_UpdateThreshold, sp_CheckHeartbeat
   View/TVF: iot.vw_MachineHealth, vw_OpenAlerts, fn_RecentTelemetry
   ===================================================================== */
const db = require('../db');
const v = require('../lib/validate');

const STAFF = ['Admin', 'Operator'];

module.exports = (r) => {
  // ESP32 / simulator gửi dữ liệu cảm biến – xác thực bằng X-Device-Key
  r.post('/api/iot/telemetry', {
    auth: 'device', tag: 'IoT (TV4)', summary: 'ESP32 gửi gói dữ liệu cảm biến (JSON)',
    body: { machineId: 3, readings: [{ t: '2026-11-02T08:00:00', temp: 4.5, hum: 80, door: 0 }] },
  }, async (ctx) => {
    const b = ctx.body;
    v.int(b.machineId, 'machineId', { min: 1 });
    v.arr(b.readings, 'readings', { min: 1, max: 500 });
    const r1 = await ctx.exec('iot.sp_IngestTelemetry', { Payload: db.T.json(b) });
    return r1.recordset[0];
  });

  r.get('/api/iot/machines', { tag: 'IoT (TV4)', summary: 'Tình trạng đội máy (RLS: Operator chỉ thấy máy được giao)', roles: STAFF },
    async (ctx) => ctx.view('iot.vw_MachineHealth', {
      where: { Status: ctx.query.status || undefined, LocationId: v.int(ctx.query.locationId, 'locationId', { optional: true }) },
      orderBy: 'MachineId',
    }));

  r.get('/api/iot/locations', { tag: 'IoT (TV4)', summary: 'Danh sách địa điểm (từ vw_MachineHealth)', roles: STAFF },
    async (ctx) => {
      const rows = await ctx.view('iot.vw_MachineHealth', { orderBy: 'LocationId' });
      const map = new Map();
      for (const m of rows) {
        if (!map.has(m.LocationId)) map.set(m.LocationId, { locationId: m.LocationId, name: m.LocationName, type: m.LocationType, district: m.District, machines: 0 });
        map.get(m.LocationId).machines += 1;
      }
      return [...map.values()];
    });

  r.post('/api/iot/machines', {
    tag: 'IoT (TV4)', summary: 'Đăng ký máy mới (tự tạo cột + ngưỡng mặc định)', roles: ['Admin'],
    body: { serial: 'FV-HCM-021', machineName: 'Bitexco – Tầng 5', locationId: 1, columnCount: 6, capacity: 10 },
  }, async (ctx) => {
    const b = ctx.body;
    const r1 = await ctx.exec('iot.sp_RegisterMachine', {
      Serial: db.T.vstr(v.str(b.serial, 'Serial', { min: 3, max: 30 })),
      MachineName: db.T.str(v.str(b.machineName, 'Tên máy', { min: 1, max: 100 })),
      LocationId: db.T.int(v.int(b.locationId, 'LocationId', { min: 1 })),
      ColumnCount: db.T.tinyint(v.int(b.columnCount ?? 6, 'Số cột', { min: 1, max: 20 })),
      Capacity: db.T.tinyint(v.int(b.capacity ?? 10, 'Sức chứa', { min: 1, max: 20 })),
    });
    ctx.status = 201;
    return r1.recordset[0];
  });

  r.get('/api/iot/machines/:id/telemetry', {
    tag: 'IoT (TV4)', summary: 'Dữ liệu cảm biến N giờ gần nhất (?hours=6)', roles: STAFF,
  }, async (ctx) => ctx.tvf('iot.fn_RecentTelemetry', [
    db.T.int(v.int(ctx.params.id, 'MachineId', { min: 1 })),
    db.T.int(v.int(ctx.query.hours ?? 6, 'hours', { min: 1, max: 168 })),
  ], { orderBy: 'RecordedAt', top: 5000 }));

  r.put('/api/iot/machines/:id/thresholds', {
    tag: 'IoT (TV4)', summary: 'Cấu hình ngưỡng nhiệt độ & thông điệp graceful degradation', roles: ['Admin'],
    body: { minTemp: 2, maxTemp: 8, doorOpenMaxMinutes: 2, consecutiveBreaches: 3, degradedMessage: 'Máy đang bảo trì làm lạnh' },
  }, async (ctx) => {
    const b = ctx.body;
    const r1 = await ctx.exec('iot.sp_UpdateThreshold', {
      MachineId: db.T.int(v.int(ctx.params.id, 'MachineId', { min: 1 })),
      MinTemp: db.T.dec(v.num(b.minTemp, 'Ngưỡng thấp', { min: -5, max: 15 })),
      MaxTemp: db.T.dec(v.num(b.maxTemp, 'Ngưỡng cao', { min: -5, max: 15 })),
      DoorOpenMaxMinutes: db.T.tinyint(v.int(b.doorOpenMaxMinutes ?? 2, 'Phút mở cửa', { min: 1, max: 60 })),
      ConsecutiveBreaches: db.T.tinyint(v.int(b.consecutiveBreaches ?? 3, 'Số lần vượt liên tiếp', { min: 1, max: 10 })),
      DegradedMessage: db.T.str(v.str(b.degradedMessage, 'Thông điệp', { max: 200, optional: true }) ?? null),
    });
    return r1.recordset[0];
  });

  r.put('/api/iot/machines/:id/clear-fault', {
    tag: 'IoT (TV4)', summary: 'Xóa trạng thái lỗi sau khi sửa máy', roles: STAFF, body: { note: 'Đã thay motor' },
  }, async (ctx) => {
    const r1 = await ctx.exec('iot.sp_ClearFault', {
      MachineId: db.T.int(v.int(ctx.params.id, 'MachineId', { min: 1 })),
      UserId: db.T.int(ctx.user.sub),
      Note: db.T.str(v.str(ctx.body.note, 'Ghi chú', { max: 200, optional: true }) ?? null),
    });
    return r1.recordset[0];
  });

  r.get('/api/iot/alerts', { tag: 'IoT (TV4)', summary: 'Cảnh báo chưa xử lý', roles: STAFF },
    async (ctx) => ctx.view('iot.vw_OpenAlerts', {
      where: { MachineId: v.int(ctx.query.machineId, 'machineId', { optional: true }), Severity: ctx.query.severity || undefined },
      orderBy: 'CreatedAt DESC', top: 500,
    }));

  r.put('/api/iot/alerts/:id/ack', {
    tag: 'IoT (TV4)', summary: 'Xác nhận / đóng cảnh báo', roles: STAFF, body: { resolve: true },
  }, async (ctx) => {
    const r1 = await ctx.exec('iot.sp_AcknowledgeAlert', {
      AlertId: db.T.bigint(v.int(ctx.params.id, 'AlertId', { min: 1 })),
      UserId: db.T.int(ctx.user.sub),
      Resolve: db.T.bit(v.bool(ctx.body.resolve)),
    });
    return r1.recordset[0];
  });
};
