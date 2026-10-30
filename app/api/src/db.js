/* =====================================================================
   Tầng truy cập CSDL – NGUYÊN TẮC: API KHÔNG viết SQL nghiệp vụ.
   - Ghi dữ liệu  : chỉ EXEC stored procedure (exec)
   - Đọc dữ liệu  : chỉ SELECT từ VIEW hoặc hàm bảng (view / tvf) với điều kiện đơn giản
   - Mỗi vai trò dùng một connection pool với login SQL riêng (RBAC thực thi trong SQL Server)
   - Mỗi lệnh gửi KÈM sp_set_session_context 'UserId' TRONG CÙNG BATCH để Row-Level Security
     không bị "lẫn" người dùng khi connection pool tái sử dụng kết nối.
   ===================================================================== */
const config = require('./config');

let driver = null;       // module 'mssql' (hoặc driver giả lập khi chạy test)
let demo = null;         // CSDL giả lập trong bộ nhớ – dùng cho kiểm thử (api/test) và DB_MODE=demo
const pools = new Map();

function sqlLib() {
  if (!driver) driver = require('mssql');
  return driver;
}
function useDriver(d) { driver = d; pools.clear(); }
function useDemo(d) { demo = d; }

const ROLES = ['Admin', 'Operator', 'Kiosk', 'Device'];

async function getPool(role) {
  if (!ROLES.includes(role)) throw new Error(`Vai trò không hợp lệ: ${role}`);
  if (!pools.has(role)) {
    const S = sqlLib();
    const login = config.db.logins[role];
    const pool = new S.ConnectionPool({
      server: config.db.server,
      port: config.db.port,
      database: config.db.database,
      user: login.user,
      password: login.password,
      options: {
        encrypt: config.db.encrypt,
        trustServerCertificate: config.db.trustServerCertificate,
        instanceName: config.db.instanceName,
        enableArithAbort: true,
        useUTC: false,          // DATETIME2 trong CSDL là giờ địa phương (Asia/Ho_Chi_Minh)
      },
      pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
      requestTimeout: 30000,
    });
    const p = pool.connect().catch((e) => { pools.delete(role); throw e; });
    pools.set(role, p);
  }
  return pools.get(role);
}

// ---------- Kiểu tham số ----------
const T = {
  int:      (v) => ({ __t: 'int', v }),
  bigint:   (v) => ({ __t: 'bigint', v }),
  tinyint:  (v) => ({ __t: 'tinyint', v }),
  str:      (v) => ({ __t: 'nvarchar', v }),
  vstr:     (v) => ({ __t: 'varchar', v }),
  dec:      (v) => ({ __t: 'decimal', v }),
  bit:      (v) => ({ __t: 'bit', v }),
  date:     (v) => ({ __t: 'date', v }),
  datetime: (v) => ({ __t: 'datetime2', v }),
  json:     (v) => ({ __t: 'nvarchar', v: typeof v === 'string' ? v : JSON.stringify(v) }),
};

function sqlType(t) {
  const S = sqlLib();
  switch (t) {
    case 'int': return S.Int;
    case 'bigint': return S.BigInt;
    case 'tinyint': return S.TinyInt;
    case 'smallint': return S.SmallInt;
    case 'nvarchar': return S.NVarChar(S.MAX);
    case 'varchar': return S.VarChar(S.MAX);
    case 'decimal': return S.Decimal(18, 2);
    case 'bit': return S.Bit;
    case 'date': return S.VarChar(10);        // 'YYYY-MM-DD' – để SQL Server tự chuyển, tránh lệch múi giờ
    case 'datetime2': return S.VarChar(30);
    default: throw new Error('Kiểu không hỗ trợ: ' + t);
  }
}

function infer(v) {
  if (v && v.__t) return v;
  if (v && v.__tvp) return v;
  if (v === null || v === undefined) return { __t: 'nvarchar', v: null };
  if (typeof v === 'boolean') return { __t: 'bit', v };
  if (typeof v === 'number') return Number.isInteger(v) ? { __t: Math.abs(v) > 2147483647 ? 'bigint' : 'int', v } : { __t: 'decimal', v };
  if (v instanceof Date) return { __t: 'datetime2', v };
  return { __t: 'nvarchar', v: String(v) };
}

// Table-Valued Parameter: tvp('sales.OrderItemType', [['ColumnId','int'],['Qty','tinyint']], rows)
function tvp(typeName, columns, rows) {
  return { __tvp: true, typeName, columns, rows };
}

function bind(req, name, value) {
  const p = infer(value);
  if (p.__tvp) {
    const S = sqlLib();
    const table = new S.Table(p.typeName);
    for (const [col, t] of p.columns) table.columns.add(col, sqlType(t), { nullable: false });
    for (const r of p.rows) table.rows.add(...p.columns.map(([col]) => r[col]));
    req.input(name, table);
    return;
  }
  req.input(name, sqlType(p.__t), p.v);
}

const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;
const OBJ = /^[a-z]+\.(sp|vw|fn)_[A-Za-z0-9_]+$/;
function checkIdent(name) { if (!IDENT.test(name)) throw new Error('Tên cột không hợp lệ: ' + name); return name; }

function contextPrefix(req, userId) {
  req.input('__uid', sqlLib().Int, userId ?? null);
  return "EXEC sys.sp_set_session_context @key = N'UserId', @value = @__uid;\n";
}

// ---------- EXEC stored procedure ----------
async function exec(role, proc, params = {}, opts = {}) {
  if (demo) return demo.exec(role, proc, params, opts);
  if (!OBJ.test(proc)) throw new Error('Tên procedure không hợp lệ: ' + proc);
  const pool = await getPool(role);
  const req = pool.request();
  let text = contextPrefix(req, opts.userId);
  const args = [];
  for (const [k, v] of Object.entries(params)) {
    if (v === undefined) continue;
    checkIdent(k);
    bind(req, k, v);
    args.push(`@${k} = @${k}`);
  }
  for (const [k, t] of Object.entries(opts.outputs || {})) {
    checkIdent(k);
    req.output(k, sqlType(t));
    args.push(`@${k} = @${k} OUTPUT`);
  }
  text += `EXEC ${proc} ${args.join(', ')};`;
  const r = await req.query(text);
  return { recordsets: r.recordsets || [], recordset: (r.recordsets && r.recordsets[0]) || [], output: r.output || {} };
}

// ---------- SELECT từ VIEW / hàm bảng ----------
function buildWhere(req, where) {
  const conds = [];
  let i = 0;
  for (const [col, val] of Object.entries(where || {})) {
    if (val === undefined || val === '') continue;
    checkIdent(col.replace(/(_from|_to|_in)$/, ''));
    const pname = `w${i++}`;
    if (col.endsWith('_from')) { bind(req, pname, val); conds.push(`[${col.slice(0, -5)}] >= @${pname}`); }
    else if (col.endsWith('_to')) { bind(req, pname, val); conds.push(`[${col.slice(0, -3)}] < @${pname}`); }
    else if (col.endsWith('_in') && Array.isArray(val)) {
      const names = val.map((v, j) => { const n = `${pname}_${j}`; bind(req, n, v); return '@' + n; });
      conds.push(`[${col.slice(0, -3)}] IN (${names.join(', ') || 'NULL'})`);
    } else if (val === null) conds.push(`[${col}] IS NULL`);
    else { bind(req, pname, val); conds.push(`[${col}] = @${pname}`); }
  }
  return conds.length ? ' WHERE ' + conds.join(' AND ') : '';
}

function buildOrder(orderBy) {
  if (!orderBy) return '';
  const parts = orderBy.split(',').map((s) => s.trim()).map((s) => {
    const [c, dir] = s.split(/\s+/);
    checkIdent(c);
    return `[${c}]${dir && /^desc$/i.test(dir) ? ' DESC' : ''}`;
  });
  return ' ORDER BY ' + parts.join(', ');
}

async function view(role, name, q = {}, opts = {}) {
  if (demo) return demo.view(role, name, q, opts);
  if (!OBJ.test(name)) throw new Error('Tên view không hợp lệ: ' + name);
  const pool = await getPool(role);
  const req = pool.request();
  let text = contextPrefix(req, opts.userId);
  const top = q.top ? `TOP (${Math.min(Number(q.top) || 100, 5000)}) ` : '';
  text += `SELECT ${top}* FROM ${name}${buildWhere(req, q.where)}${buildOrder(q.orderBy)};`;
  const r = await req.query(text);
  return r.recordset || [];
}

async function tvf(role, name, args = [], q = {}, opts = {}) {
  if (demo) return demo.tvf(role, name, args, q, opts);
  if (!OBJ.test(name)) throw new Error('Tên hàm không hợp lệ: ' + name);
  const pool = await getPool(role);
  const req = pool.request();
  let text = contextPrefix(req, opts.userId);
  const names = args.map((a, i) => { bind(req, `a${i}`, a); return `@a${i}`; });
  const top = q.top ? `TOP (${Math.min(Number(q.top) || 100, 20000)}) ` : '';
  text += `SELECT ${top}* FROM ${name}(${names.join(', ')})${buildWhere(req, q.where)}${buildOrder(q.orderBy)};`;
  const r = await req.query(text);
  return r.recordset || [];
}

async function ping() {
  if (demo) return { ok: true, mode: 'demo' };
  const pool = await getPool('Kiosk');
  const r = await pool.request().query('SELECT DB_NAME() AS db, SYSDATETIME() AS now, @@VERSION AS version');
  return { ok: true, mode: 'sqlserver', ...r.recordset[0] };
}

async function close() {
  for (const p of pools.values()) { try { (await p).close(); } catch { /* bỏ qua */ } }
  pools.clear();
}

module.exports = { exec, view, tvf, tvp, T, ping, close, useDriver, useDemo, ROLES };
