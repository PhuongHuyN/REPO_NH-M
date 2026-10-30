/* =====================================================================
   TV5 – Báo cáo & Phân tích  (/api/reports/*)  – chỉ Admin (Operator bị DENY ở cả API và CSDL)
   SP: report.sp_DashboardKpi, sp_PeakHours (PIVOT), sp_RevenueGrowth (LAG), sp_ExportSales,
       sp_RefreshDailySummary (MERGE), sp_RunAllTests
   View/TVF: vw_ProductRanking, vw_ColdChainCompliance, vw_LatestTestRun, fn_RevenueByLocation
   ===================================================================== */
const db = require('../db');
const v = require('../lib/validate');
const { sendCsv } = require('../lib/http');

const ADMIN = ['Admin'];
const today = () => new Date(Date.now() + 7 * 3600 * 1000).toISOString().slice(0, 10);   // giờ Việt Nam
const daysAgo = (n) => new Date(Date.now() + 7 * 3600 * 1000 - n * 86400000).toISOString().slice(0, 10);

module.exports = (r) => {
  r.get('/api/reports/kpi', { tag: 'Reports (TV5)', summary: 'KPI tổng quan + doanh thu 14 ngày + top sản phẩm', roles: ADMIN },
    async (ctx) => {
      const r1 = await ctx.exec('report.sp_DashboardKpi');
      return { kpi: r1.recordsets[0]?.[0] || {}, daily: r1.recordsets[1] || [], topProducts: r1.recordsets[2] || [] };
    });

  r.get('/api/reports/revenue-growth', { tag: 'Reports (TV5)', summary: 'Doanh thu theo tháng, tăng trưởng (LAG), lũy kế', roles: ADMIN },
    async (ctx) => (await ctx.exec('report.sp_RevenueGrowth', {
      Year: db.T.int(v.int(ctx.query.year, 'year', { min: 2020, max: 2100, optional: true }) ?? null),
    })).recordset);

  r.get('/api/reports/peak-hours', { tag: 'Reports (TV5)', summary: 'Ma trận giờ × thứ (PIVOT)', roles: ADMIN },
    async (ctx) => (await ctx.exec('report.sp_PeakHours', {
      From: db.T.date(v.date(ctx.query.from, 'from', { optional: true }) ?? null),
      To: db.T.date(v.date(ctx.query.to, 'to', { optional: true }) ?? null),
    })).recordset);

  r.get('/api/reports/ranking', { tag: 'Reports (TV5)', summary: 'Xếp hạng sản phẩm theo địa điểm (RANK)', roles: ADMIN },
    async (ctx) => ctx.view('report.vw_ProductRanking', { orderBy: 'LocationId, RankInLocation' }));

  r.get('/api/reports/cold-chain', { tag: 'Reports (TV5)', summary: 'Tỷ lệ tuân thủ chuỗi lạnh 30 ngày', roles: ADMIN },
    async (ctx) => ctx.view('report.vw_ColdChainCompliance', { orderBy: 'MachineId' }));

  r.get('/api/reports/revenue-by-location', { tag: 'Reports (TV5)', summary: 'Doanh thu theo địa điểm (inline TVF)', roles: ADMIN },
    async (ctx) => ctx.tvf('report.fn_RevenueByLocation', [
      db.T.date(v.date(ctx.query.from, 'from', { optional: true }) ?? daysAgo(29)),
      db.T.date(v.date(ctx.query.to, 'to', { optional: true }) ?? today()),
    ], { orderBy: 'Revenue DESC' }));

  r.get('/api/reports/export.csv', { tag: 'Reports (TV5)', summary: 'Xuất CSV bán hàng (ghi ExportLogs)', roles: ADMIN },
    async (ctx) => {
      const from = v.date(ctx.query.from, 'from', { optional: true }) ?? daysAgo(29);
      const to = v.date(ctx.query.to, 'to', { optional: true }) ?? today();
      const r1 = await ctx.exec('report.sp_ExportSales', {
        From: db.T.date(from), To: db.T.date(to),
        LocationId: db.T.int(v.int(ctx.query.locationId, 'locationId', { optional: true }) ?? null),
        UserId: db.T.int(ctx.user.sub),
      });
      sendCsv(ctx.res, `freshvend_sales_${from}_${to}.csv`, r1.recordset);
      return ctx.sent();
    });

  r.post('/api/reports/refresh', {
    tag: 'Reports (TV5)', summary: 'Cập nhật bảng tổng hợp (MERGE)', roles: ADMIN, body: { date: '2026-11-01', toDate: '2026-11-02' },
  }, async (ctx) => (await ctx.exec('report.sp_RefreshDailySummary', {
    Date: db.T.date(v.date(ctx.body.date, 'date', { optional: true }) ?? null),
    ToDate: db.T.date(v.date(ctx.body.toDate, 'toDate', { optional: true }) ?? null),
  })).recordset[0]);

  r.post('/api/reports/run-tests', { tag: 'Reports (TV5)', summary: 'Chạy toàn bộ unit test trong CSDL', roles: ADMIN },
    async (ctx) => {
      const r1 = await ctx.exec('report.sp_RunAllTests');
      const sets = r1.recordsets;
      // 2 tập kết quả cuối là tổng hợp theo module và chi tiết
      return { summary: sets[sets.length - 2] || [], details: sets[sets.length - 1] || [] };
    });

  r.get('/api/reports/test-results', { tag: 'Reports (TV5)', summary: 'Kết quả lần chạy test gần nhất', roles: ADMIN },
    async (ctx) => ctx.view('report.vw_LatestTestRun', { orderBy: 'TestId' }));
};
