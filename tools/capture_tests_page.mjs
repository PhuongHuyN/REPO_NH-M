// Real browser screenshot of DEMO UI only; never claimed as SQL E2E evidence.
import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import net from 'node:net';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(root, 'docs/evidence/week2');
const profile = path.join(root, '.local-test/browser-profile');
const pause = (ms) => new Promise((r) => setTimeout(r, ms));
const port = async () => {
  const server = net.createServer();
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const value = server.address().port;
  await new Promise((r) => server.close(r));
  return value;
};
const apiPort = await port(), browserPort = await port();
await mkdir(output, { recursive: true });
await mkdir(profile, { recursive: true });
const api = spawn(process.execPath, ['app/api/src/server.js'], { cwd: root, env: { ...process.env, DB_MODE: 'demo', PORT: String(apiPort), JOBS_FALLBACK: 'false' }, windowsHide: true, stdio: 'ignore' });
let browser, socket;
const pending = new Map();
let id = 0;
async function eventually(fn) {
  for (let attempt = 0; attempt < 80; attempt++) {
    try { const result = await fn(); if (result) return result; } catch { /* startup */ }
    await pause(250);
  }
  throw new Error('Browser/API did not reach the required state');
}
function command(method, params = {}) {
  const requestId = ++id;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(requestId); reject(new Error(method + ' timed out')); }, 20000);
    pending.set(requestId, { resolve: (value) => { clearTimeout(timer); resolve(value); }, reject });
    socket.send(JSON.stringify({ id: requestId, method, params }));
  });
}
try {
  await eventually(async () => (await fetch(`http://127.0.0.1:${apiPort}/api/health`)).ok);
  browser = spawn(process.env.FV_QA_BROWSER || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', [
    '--headless=new', '--disable-gpu', '--no-first-run', `--remote-debugging-port=${browserPort}`, `--user-data-dir=${profile}`, 'about:blank',
  ], { windowsHide: true, stdio: 'ignore' });
  const target = await eventually(async () => (await fetch(`http://127.0.0.1:${browserPort}/json/list`)).json().then((items) => items.find((x) => x.type === 'page')));
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }); });
  socket.addEventListener('message', (event) => {
    const response = JSON.parse(event.data);
    if (!response.id) return;
    const promise = pending.get(response.id); pending.delete(response.id);
    if (response.error) promise?.reject(new Error(response.error.message)); else promise?.resolve(response.result);
  });
  await command('Page.enable');
  await command('Emulation.setDeviceMetricsOverride', { width: 1440, height: 1100, deviceScaleFactor: 1, mobile: false });
  await command('Page.navigate', { url: `http://127.0.0.1:${apiPort}/` });
  await eventually(async () => (await command('Runtime.evaluate', { expression: 'Boolean(document.querySelector("#loginForm"))', returnByValue: true })).result.value);
  const auth = await command('Runtime.evaluate', { expression: `(async()=>{const r=await fetch('/api/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:'admin',password:'Admin@2026'})});const data=await r.json();if(!r.ok)throw Error('demo login failed');localStorage.setItem('fv_admin_session',JSON.stringify({token:data.token,user:data.user}));return 'ready';})()`, awaitPromise: true, returnByValue: true });
  if (auth.exceptionDetails) throw new Error('Demo login failed');
  await command('Page.navigate', { url: `http://127.0.0.1:${apiPort}/#/tests` });
  await eventually(async () => (await command('Runtime.evaluate', { expression: 'Boolean(document.querySelector("#run"))', returnByValue: true })).result.value);
  await command('Runtime.evaluate', { expression: 'document.querySelector("#run").click()' });
  await eventually(async () => (await command('Runtime.evaluate', { expression: 'document.querySelector("#det")?.textContent.includes("DEMO:")', returnByValue: true })).result.value);
  const badges = await command('Runtime.evaluate', { expression: 'document.querySelectorAll("#det .badge.green").length', returnByValue: true });
  if (badges.result.value !== 0) throw new Error('Demo tests are incorrectly marked PASS');
  const metrics = await command('Page.getLayoutMetrics');
  const screenshot = await command('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true, clip: { x: 0, y: 0, width: 1440, height: Math.max(1100, metrics.cssContentSize.height), scale: 1 } });
  await writeFile(path.join(output, '224-tests-demo-blocked.png'), Buffer.from(screenshot.data, 'base64'));
  await writeFile(path.join(output, '224-ui.json'), JSON.stringify({ source: 'DEMO', sqlE2e: false, noGreenPassBadges: true, capturedAt: new Date().toISOString(), image: '224-tests-demo-blocked.png' }, null, 2));
  console.log('PASS actual browser UI: DEMO results BLOCKED; screenshot saved (not SQL E2E proof)');
} finally {
  if (socket?.readyState === WebSocket.OPEN) { try { await command('Browser.close'); } catch { /* closed */ } socket.close(); }
  if (browser && browser.exitCode === null) browser.kill();
  if (api.exitCode === null) api.kill();
}
