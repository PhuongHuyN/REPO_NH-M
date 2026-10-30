/* =====================================================================
   FreshVend Console – khung ứng dụng (TV3 dựng khung, TV1 phần đăng nhập)
   - Router theo hash (#/dashboard), menu lọc theo vai trò
   - Server-Sent Events /api/stream: tình trạng máy + cảnh báo cập nhật mỗi 2 giây
   ===================================================================== */
import { Api } from './api.js';
import { $, esc, toast, modal, formData } from './ui.js';
import { icon } from './icons.js';

// Danh sách trang (thứ tự = thứ tự trên menu). Trang nạp động: file nào CHƯA có trong web/js/pages
// thì tự ẩn khỏi menu thay vì làm hỏng cả giao diện -> mỗi thành viên push trang của mình lúc nào cũng được.
// Thêm trang mới: tạo web/js/pages/<ten>.js rồi thêm '<ten>' vào mảng này.
const PAGE_FILES = ['dashboard', 'reports', 'orders', 'restock', 'products', 'machines', 'alerts', 'users', 'tests'];
const PAGES = {};
const loaded = await Promise.all(PAGE_FILES.map((k) => import(`./pages/${k}.js`).then((m) => [k, m.default]).catch((e) => { console.warn(`[FreshVend] Trang '${k}' chưa có hoặc bị lỗi:`, e.message); return [k, null]; })));
loaded.forEach(([k, p]) => { if (p) PAGES[k] = p; });

const api = new Api('admin');
const GROUPS = ['Tổng quan', 'Vận hành', 'Quản trị'];
const ROLE_LABEL = { Admin: 'Quản trị viên', Operator: 'Nhân viên vận hành' };

// Gắn icon cho các phần tử tĩnh có data-ico
function paintIcons(root = document) {
  root.querySelectorAll('[data-ico]').forEach((el) => { el.innerHTML = icon(el.dataset.ico, Number(el.dataset.size) || 18); });
}
paintIcons();

// ---------- Realtime (SSE) ----------
const live = new EventTarget();
let source = null;
let lastHealth = null;
function setLive(ok, text) {
  $('#liveDot').className = `dot ${ok ? 'green' : 'red'}`;
  $('#liveText').textContent = text;
}
function connectLive() {
  if (source) source.close();
  if (!window.EventSource || !api.token) return;
  source = new EventSource(`/api/stream?token=${encodeURIComponent(api.token)}`);
  source.addEventListener('health', (e) => {
    lastHealth = JSON.parse(e.data);
    setLive(true, `Trực tuyến · ${new Date(lastHealth.at).toLocaleTimeString('vi-VN')}`);
    const n = lastHealth.alerts.length;
    const badge = document.querySelector('[data-page="alerts"] .count');
    if (badge) { badge.textContent = n; badge.classList.toggle('hidden', !n); }
    live.dispatchEvent(new CustomEvent('health', { detail: lastHealth }));
  });
  source.onerror = () => setLive(false, 'Mất kết nối thời gian thực');
}

// ---------- Chế độ demo (DB_MODE=demo): chưa kết nối SQL Server ----------
fetch('/api/health').then((r) => r.json()).then((h) => {
  const demo = h?.db?.mode === 'demo';
  $('#loginDemo').classList.toggle('hidden', !demo);
  $('#demoBadge').classList.toggle('hidden', !demo);
}).catch(() => {});
$('#loginDemo').addEventListener('click', (e) => {
  const b = e.target.closest('[data-demo]');
  if (!b) return;
  const [u, p] = b.dataset.demo.split('|');
  $('#lu').value = u; $('#lp').value = p;
});

// ---------- Đăng nhập (TV1) ----------
$('#pwToggle').addEventListener('click', () => {
  const inp = $('#lp');
  const show = inp.type === 'password';
  inp.type = show ? 'text' : 'password';
  $('#pwToggle').innerHTML = icon(show ? 'eyeOff' : 'eye');
  $('#pwToggle').setAttribute('aria-label', show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu');
});

$('#loginForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const f = formData(e.target);
  $('#loginErr').textContent = '';
  if (!f.username || !f.password) { $('#loginErr').textContent = 'Vui lòng nhập tên đăng nhập và mật khẩu'; return; }
  const btn = $('#loginBtn');
  btn.disabled = true; btn.innerHTML = '<span class="spinner" style="width:18px;height:18px;border-width:2px"></span> Đang đăng nhập…';
  try {
    const user = await api.login(f.username, f.password);
    if (user.role === 'Kiosk') { api.logout(); throw new Error('Tài khoản thiết bị chỉ dùng cho màn hình bán hàng'); }
    $('#lp').value = '';
    boot();
  } catch (err) {
    $('#loginErr').textContent = err.offline ? 'Không kết nối được máy chủ. Vui lòng thử lại sau.' : err.message;
  } finally { btn.disabled = false; btn.textContent = 'Đăng nhập'; }
});

function logout() {
  if (source) source.close();
  api.logout();
  location.hash = '';
  showLogin();
}
function showLogin() {
  $('#appView').classList.add('hidden');
  $('#loginView').classList.remove('hidden');
  $('#lu').focus();
}

// ---------- Menu người dùng ----------
const drop = $('#userDrop');
$('#userBtn').addEventListener('click', (e) => {
  e.stopPropagation();
  drop.classList.toggle('hidden');
  $('#userBtn').setAttribute('aria-expanded', String(!drop.classList.contains('hidden')));
});
document.addEventListener('click', () => drop.classList.add('hidden'));
$('#logoutBtn').addEventListener('click', logout);
window.addEventListener('fv:logout', () => { toast('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại', 'err'); showLogin(); });
$('#menuBtn').addEventListener('click', () => $('#sidebar').classList.toggle('open'));
$('#backdrop').addEventListener('click', () => $('#sidebar').classList.remove('open'));

$('#pwBtn').addEventListener('click', () => {
  modal('Đổi mật khẩu', `<form class="stack" id="pwForm">
      <div><label>Mật khẩu hiện tại</label><input type="password" name="oldPassword" autocomplete="current-password" required></div>
      <div><label>Mật khẩu mới</label><input type="password" name="newPassword" minlength="8" autocomplete="new-password" required>
        <div class="small muted" style="margin-top:4px">Tối thiểu 8 ký tự, khác mật khẩu hiện tại.</div></div>
      <div class="row" style="justify-content:flex-end"><button type="button" class="btn" data-close>Hủy</button><button class="btn primary">Lưu thay đổi</button></div></form>`, {
    onMount: (body, close) => body.querySelector('#pwForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      try { await api.put('/api/auth/password', formData(e.target)); toast('Đã đổi mật khẩu', 'ok'); close(); }
      catch (err) { toast(err.message, 'err'); }
    }),
  });
});

// ---------- Router ----------
let dispose = null;
function allowed(page) { return !page.roles || page.roles.includes(api.user?.role); }
function defaultPage() {
  const first = api.user?.role === 'Admin' ? 'dashboard' : 'restock';
  if (PAGES[first] && allowed(PAGES[first])) return first;
  return Object.keys(PAGES).find((k) => allowed(PAGES[k])) || null; // trang đầu tiên đang có
}

function renderNav(current) {
  $('#nav').innerHTML = GROUPS.map((g) => {
    const items = Object.entries(PAGES).filter(([, p]) => p.group === g && allowed(p));
    if (!items.length) return '';
    return `<div class="group">${esc(g)}</div>` + items.map(([key, p]) =>
      `<a href="#/${key}" data-page="${key}" class="${key === current ? 'active' : ''}">${icon(p.icon, 18)}<span>${esc(p.title)}</span>
       ${key === 'alerts' ? '<span class="count hidden">0</span>' : ''}</a>`).join('');
  }).join('');
}

async function route() {
  if (!api.token) return showLogin();
  let key = location.hash.replace(/^#\//, '') || defaultPage();
  if (!PAGES[key] || !allowed(PAGES[key])) key = defaultPage();
  renderNav(key);
  if (!key) {
    $('#pageTitle').textContent = 'FreshVend';
    $('#page').innerHTML = `<div class="card empty">${icon('package', 28)}<p>Chưa có trang nào trong <code>web/js/pages/</code>. Các thành viên push trang của mình là menu tự hiện.</p></div>`;
    return;
  }
  const page = PAGES[key];
  $('#sidebar').classList.remove('open');
  $('#pageTitle').textContent = page.title;
  $('#crumb').textContent = page.group === page.title ? 'FreshVend Operations' : `FreshVend Operations · ${page.group}`;
  document.title = `${page.title} · FreshVend Console`;
  if (typeof dispose === 'function') dispose();
  dispose = null;
  const el = $('#page');
  el.innerHTML = '<div class="empty"><span class="spinner"></span></div>';
  try {
    dispose = await page.render(el, { api, user: api.user, live, lastHealth: () => lastHealth, go: (p) => { location.hash = '#/' + p; } });
  } catch (err) {
    el.innerHTML = `<div class="card empty">${icon('alert', 28)}<p>Không tải được dữ liệu: ${esc(err.message)}</p></div>`;
  }
}
window.addEventListener('hashchange', route);

function boot() {
  $('#loginView').classList.add('hidden');
  $('#appView').classList.remove('hidden');
  const u = api.user;
  $('#userName').textContent = u.fullName;
  $('#userRole').textContent = ROLE_LABEL[u.role] || u.role;
  $('#avatar').textContent = String(u.fullName || u.username).split(/\s+/).slice(-2).map((w) => w[0]).join('').toUpperCase();
  connectLive();
  route();
}

if (api.token) boot(); else showLogin();
