// Kiểm tra dữ liệu đầu vào ở tầng API (CSDL vẫn kiểm tra lại – "phòng thủ 2 lớp")
const { HttpError } = require('./http');

function bad(message) { return new HttpError(400, message, 'VALIDATION'); }

function int(v, name, { min = -Infinity, max = Infinity, optional = false } = {}) {
  if ((v === undefined || v === null || v === '') && optional) return undefined;
  const n = Number(v);
  if (!Number.isInteger(n)) throw bad(`${name} phải là số nguyên`);
  if (n < min || n > max) throw bad(`${name} phải trong khoảng ${min}–${max}`);
  return n;
}

function num(v, name, { min = -Infinity, max = Infinity, optional = false } = {}) {
  if ((v === undefined || v === null || v === '') && optional) return undefined;
  const n = Number(v);
  if (!Number.isFinite(n)) throw bad(`${name} phải là số`);
  if (n < min || n > max) throw bad(`${name} phải trong khoảng ${min}–${max}`);
  return n;
}

function str(v, name, { min = 0, max = 4000, optional = false } = {}) {
  if ((v === undefined || v === null || v === '') && optional) return undefined;
  if (typeof v !== 'string') throw bad(`${name} phải là chuỗi`);
  const s = v.trim();
  if (s.length < min) throw bad(`${name} không được để trống${min > 1 ? ` (tối thiểu ${min} ký tự)` : ''}`);
  if (s.length > max) throw bad(`${name} tối đa ${max} ký tự`);
  return s;
}

function oneOf(v, name, list, { optional = false } = {}) {
  if ((v === undefined || v === null || v === '') && optional) return undefined;
  if (!list.includes(v)) throw bad(`${name} chỉ nhận: ${list.join(', ')}`);
  return v;
}

function date(v, name, { optional = false } = {}) {
  if ((v === undefined || v === null || v === '') && optional) return undefined;
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v) || Number.isNaN(Date.parse(v))) throw bad(`${name} phải có dạng YYYY-MM-DD`);
  return v;
}

function bool(v) { return v === true || v === 'true' || v === 1 || v === '1'; }

function arr(v, name, { min = 1, max = 50 } = {}) {
  if (!Array.isArray(v)) throw bad(`${name} phải là mảng`);
  if (v.length < min) throw bad(`${name} phải có ít nhất ${min} phần tử`);
  if (v.length > max) throw bad(`${name} tối đa ${max} phần tử`);
  return v;
}

module.exports = { int, num, str, oneOf, date, bool, arr, bad };
