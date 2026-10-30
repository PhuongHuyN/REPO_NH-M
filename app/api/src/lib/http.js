// Tiện ích HTTP tối giản: đọc body JSON, trả JSON/CSV, phục vụ file tĩnh (web/)
const fs = require('fs');
const path = require('path');

class HttpError extends Error {
  constructor(status, message, code) {
    super(message);
    this.status = status;
    this.code = code || 'ERROR';
  }
}

function readJson(req, limit = 1024 * 1024) {
  return new Promise((resolve, reject) => {
    if (req.method === 'GET' || req.method === 'HEAD' || req.method === 'DELETE') return resolve({});
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > limit) { reject(new HttpError(413, 'Dữ liệu gửi lên quá lớn', 'PAYLOAD_TOO_LARGE')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => {
      const text = Buffer.concat(chunks).toString('utf8').trim();
      if (!text) return resolve({});
      try { resolve(JSON.parse(text)); } catch { reject(new HttpError(400, 'Body không phải JSON hợp lệ', 'BAD_JSON')); }
    });
    req.on('error', reject);
  });
}

function sendJson(res, status, data) {
  const body = JSON.stringify(data, (k, v) => (typeof v === 'bigint' ? Number(v) : v));
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(body);
}

function sendCsv(res, filename, rows) {
  const cols = rows.length ? Object.keys(rows[0]) : [];
  const esc = (v) => {
    if (v === null || v === undefined) return '';
    if (v instanceof Date) v = v.toISOString();
    const s = String(v);
    return /[",\n\r;]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const lines = [cols.join(','), ...rows.map((r) => cols.map((c) => esc(r[c])).join(','))];
  res.writeHead(200, {
    'Content-Type': 'text/csv; charset=utf-8',
    'Content-Disposition': `attachment; filename="${filename}"`,
  });
  res.end('﻿' + lines.join('\r\n'));   // BOM để Excel đọc đúng tiếng Việt
}

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json', '.woff2': 'font/woff2',
};

function serveStatic(rootDir, req, res, uploadDir) {
  let rel = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (uploadDir && rel.startsWith('/uploads/')) { rootDir = uploadDir; rel = rel.slice('/uploads'.length); }
  if (rel === '/' || rel === '/index.html') rel = '/admin.html';
  if (rel === '/kiosk') rel = '/kiosk.html';
  if (rel === '/admin') rel = '/admin.html';
  const file = path.normalize(path.join(rootDir, rel));
  if (!file.startsWith(rootDir + path.sep)) { res.writeHead(403); return res.end('Forbidden'); }
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) { res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }); return res.end('Không tìm thấy'); }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
    fs.createReadStream(file).pipe(res);
  });
}

module.exports = { HttpError, readJson, sendJson, sendCsv, serveStatic };
