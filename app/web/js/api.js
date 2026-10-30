// Gọi REST API: tự gắn JWT, chuyển lỗi thành Error có message tiếng Việt từ CSDL
const KEY = { admin: 'fv_admin_session', kiosk: 'fv_kiosk_session' };

function storage() {
  try { return window.localStorage; } catch { return null; }
}

export class Api {
  constructor(app) { this.key = KEY[app]; this.session = null; this.load(); }
  load() {
    try { this.session = JSON.parse(storage()?.getItem(this.key) || 'null'); } catch { this.session = null; }
  }
  save(session) {
    this.session = session;
    try { session ? storage()?.setItem(this.key, JSON.stringify(session)) : storage()?.removeItem(this.key); } catch { /* bỏ qua */ }
  }
  get user() { return this.session?.user || null; }
  get token() { return this.session?.token || null; }

  async request(method, path, body) {
    let res;
    try {
      res = await fetch(path, {
        method,
        headers: { 'Content-Type': 'application/json', ...(this.token ? { Authorization: `Bearer ${this.token}` } : {}) },
        body: body !== undefined ? JSON.stringify(body) : undefined,
      });
    } catch (e) {
      const err = new Error('Không kết nối được máy chủ');
      err.offline = true;
      throw err;
    }
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { data = text; }
    if (!res.ok) {
      const err = new Error(data?.message || `Lỗi ${res.status}`);
      err.status = res.status; err.code = data?.error;
      if (res.status === 401 && path !== '/api/auth/login') { this.save(null); window.dispatchEvent(new CustomEvent('fv:logout')); }
      if (res.status === 503) err.offline = true;
      throw err;
    }
    return data;
  }
  get(p) { return this.request('GET', p); }
  post(p, b = {}) { return this.request('POST', p, b); }
  put(p, b = {}) { return this.request('PUT', p, b); }

  async login(username, password) {
    const data = await this.post('/api/auth/login', { username, password });
    this.save({ token: data.token, user: data.user });
    return data.user;
  }
  logout() { this.save(null); }

  async download(path, filename) {
    const res = await fetch(path, { headers: { Authorization: `Bearer ${this.token}` } });
    if (!res.ok) { let m = `Lỗi ${res.status}`; try { m = (await res.json()).message; } catch { /* */ } throw new Error(m); }
    const blob = await res.blob();
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);
  }
}
