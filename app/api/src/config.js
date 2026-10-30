// Đọc cấu hình từ biến môi trường và file .env (không cần thư viện dotenv)
const fs = require('fs');
const path = require('path');

function loadDotEnv(file) {
  if (!fs.existsSync(file)) return;
  for (const raw of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const i = line.indexOf('=');
    if (i < 0) continue;
    const key = line.slice(0, i).trim();
    let val = line.slice(i + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) val = val.slice(1, -1);
    if (process.env[key] === undefined) process.env[key] = val;
  }
}
loadDotEnv(path.join(__dirname, '..', '.env'));

const env = (k, d) => (process.env[k] !== undefined && process.env[k] !== '' ? process.env[k] : d);
const bool = (k, d) => String(env(k, d)).toLowerCase() === 'true';

// DB_MODE=demo      : chạy bằng CSDL giả lập trong bộ nhớ (chưa cần SQL Server) – dùng khi đang làm FE
// DB_MODE=sqlserver : kết nối SQL Server thật (sau khi đã chạy FreshVend_FULL.sql)
const dbMode = String(env('DB_MODE', 'demo')).toLowerCase() === 'sqlserver' ? 'sqlserver' : 'demo';
const demoPay = (k, v) => env(k, dbMode === 'demo' ? v : '');

module.exports = {
  port: Number(env('PORT', 3000)),
  dbMode,
  db: {
    server: env('DB_SERVER', 'localhost'),
    port: env('DB_INSTANCE', '') ? undefined : Number(env('DB_PORT', 1433)),
    instanceName: env('DB_INSTANCE', '') || undefined,
    database: env('DB_NAME', 'FreshVendDB'),
    encrypt: bool('DB_ENCRYPT', 'false'),
    trustServerCertificate: bool('DB_TRUST_CERT', 'true'),
    logins: {
      Admin:    { user: env('DB_ADMIN_USER', 'fv_admin_app'),       password: env('DB_ADMIN_PASSWORD', 'FreshVend@Admin2026') },
      Operator: { user: env('DB_OPERATOR_USER', 'fv_operator_app'), password: env('DB_OPERATOR_PASSWORD', 'FreshVend@Operator2026') },
      Kiosk:    { user: env('DB_KIOSK_USER', 'fv_kiosk_app'),       password: env('DB_KIOSK_PASSWORD', 'FreshVend@Kiosk2026') },
      Device:   { user: env('DB_DEVICE_USER', 'fv_device_app'),     password: env('DB_DEVICE_PASSWORD', 'FreshVend@Device2026') },
    },
  },
  jwtSecret: env('JWT_SECRET', 'doi-chuoi-bi-mat-nay-truoc-khi-trien-khai'),
  jwtExpiresHours: Number(env('JWT_EXPIRES_HOURS', 8)),
  kioskSessionHours: Number(env('KIOSK_SESSION_HOURS', 720)),
  deviceApiKey: env('DEVICE_API_KEY', 'freshvend-device-key-2026'),
  paymentSecret: env('PAYMENT_WEBHOOK_SECRET', 'freshvend-payment-secret-2026'),
  jobsFallback: bool('JOBS_FALLBACK', 'false'),
  supportPhone: demoPay('SUPPORT_PHONE', '1900 6868'),           // số hotline hiện trên màn hình kiosk
  payment: {
    // Chế độ demo: nếu chưa điền thì dùng tài khoản minh họa để kiosk vẫn hiện được mã QR (KHÔNG chuyển tiền thật)
    bankBin: demoPay('PAYMENT_BANK_BIN', '970436'),   // mã BIN ngân hàng theo NAPAS, vd. 970436 (Vietcombank)
    bankName: demoPay('PAYMENT_BANK_NAME', 'Vietcombank (DEMO)'),
    accountNo: demoPay('PAYMENT_ACCOUNT_NO', '0000000000'),
    accountName: demoPay('PAYMENT_ACCOUNT_NAME', 'FRESHVEND DEMO'),
    sepayApiKey: env('SEPAY_API_KEY', ''),            // khóa webhook dịch vụ đối soát ngân hàng (SePay)
  },
  uploadDir: path.resolve(env('UPLOAD_DIR', path.join(__dirname, '..', '..', 'web', 'uploads'))),
  webDir: path.resolve(env('WEB_DIR', path.join(__dirname, '..', '..', 'web'))),
};
