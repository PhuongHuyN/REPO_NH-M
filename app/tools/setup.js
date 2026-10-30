#!/usr/bin/env node
// Chuẩn bị máy mới sau khi clone:  npm run setup
// - Tạo api/.env từ api/.env.example nếu chưa có (không ghi đè file đã có)
// - Kiểm tra phiên bản Node, rồi chạy kiểm tra đồng bộ FE ⇄ BE
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const env = path.join(ROOT, 'api/.env');
const example = path.join(ROOT, 'api/.env.example');

const major = Number(process.versions.node.split('.')[0]);
if (major < 18) { console.error(`✘ Node.js ${process.versions.node} quá cũ – cài Node 20 LTS (https://nodejs.org)`); process.exit(1); }
if (!fs.existsSync(path.join(ROOT, 'api/node_modules/mssql'))) console.warn('⚠ Chưa cài thư viện – chạy: npm install');

if (fs.existsSync(env)) console.log('✔ api/.env đã có – giữ nguyên');
else { fs.copyFileSync(example, env); console.log('✔ Đã tạo api/.env từ api/.env.example → mở file này điền DB_* và PAYMENT_* của máy bạn'); }

require('./check-sync.js');
