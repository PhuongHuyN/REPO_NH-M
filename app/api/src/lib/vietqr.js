/* =====================================================================
   Sinh nội dung mã VietQR (chuẩn EMVCo QR / NAPAS 247) để khách chuyển khoản
   bằng bất kỳ app ngân hàng nào. Không cần bên thứ ba – app ngân hàng tự đọc
   số tài khoản, số tiền và nội dung chuyển khoản.
   Cấu trúc: các trường TLV (ID 2 ký tự + độ dài 2 ký tự + giá trị), kết thúc bằng CRC16-CCITT (0x1021, 0xFFFF).
   ===================================================================== */

function tlv(id, value) {
  const v = String(value);
  return id + String(v.length).padStart(2, '0') + v;
}

function crc16(str) {
  let crc = 0xffff;
  for (const b of Buffer.from(str, 'utf8')) {
    crc ^= b << 8;
    for (let i = 0; i < 8; i++) crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}

// Nội dung chuyển khoản chỉ nên chứa chữ không dấu, số, khoảng trắng
function plain(s, max) {
  return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D')
    .replace(/[^A-Za-z0-9 ]/g, '').trim().slice(0, max);
}

/**
 * @param {object} o
 * @param {string} o.bankBin   mã BIN ngân hàng (6 số), vd. 970436
 * @param {string} o.accountNo số tài khoản nhận
 * @param {number} o.amount    số tiền (VND, số nguyên)
 * @param {string} o.content   nội dung chuyển khoản, vd. "FV1024"
 */
function build({ bankBin, accountNo, amount, content }) {
  if (!/^\d{6}$/.test(String(bankBin || ''))) throw new Error('PAYMENT_BANK_BIN phải gồm 6 chữ số');
  if (!/^[0-9A-Za-z]{4,19}$/.test(String(accountNo || ''))) throw new Error('PAYMENT_ACCOUNT_NO không hợp lệ');
  const merchant = tlv('00', 'A000000727')
    + tlv('01', tlv('00', bankBin) + tlv('01', accountNo))
    + tlv('02', 'QRIBFTTA'); // chuyển nhanh NAPAS247 tới tài khoản
  let s = tlv('00', '01')
    + tlv('01', amount ? '12' : '11') // 12 = mã dùng 1 lần (có số tiền)
    + tlv('38', merchant)
    + tlv('53', '704')
    + (amount ? tlv('54', String(Math.round(amount))) : '')
    + tlv('58', 'VN');
  const c = plain(content, 25);
  if (c) s += tlv('62', tlv('08', c));
  s += '6304';
  return s + crc16(s);
}

// Vẽ chuỗi thành ảnh SVG (mức sửa lỗi M, viền trắng 4 ô theo chuẩn)
function toSvg(text, size = 256) {
  const QRCode = require('./qrcode');
  const Level = require('./qrcode/QRErrorCorrectLevel');
  const qr = new QRCode(-1, Level.M);
  qr.addData(text);
  qr.make();
  const n = qr.getModuleCount();
  const q = 4;
  let d = '';
  for (let r = 0; r < n; r++) {
    for (let c = 0; c < n; c++) if (qr.isDark(r, c)) d += `M${c + q} ${r + q}h1v1h-1z`;
  }
  const w = n + q * 2;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${w}" width="${size}" height="${size}" shape-rendering="crispEdges">`
    + `<rect width="${w}" height="${w}" fill="#fff"/><path fill="#000" d="${d}"/></svg>`;
}

module.exports = { build, toSvg, crc16, tlv, plain };
