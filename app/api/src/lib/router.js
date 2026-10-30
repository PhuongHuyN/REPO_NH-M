// Router tối giản: khớp METHOD + đường dẫn có tham số (:id), lưu metadata để sinh tài liệu OpenAPI
class Router {
  constructor() { this.routes = []; }

  add(method, path, meta, handler) {
    const keys = [];
    const pattern = new RegExp('^' + path.replace(/\//g, '\\/').replace(/:(\w+)/g, (_, k) => { keys.push(k); return '([^/]+)'; }) + '\\/?$');
    this.routes.push({ method, path, pattern, keys, meta: meta || {}, handler });
  }
  get(p, m, h)    { this.add('GET', p, m, h); }
  post(p, m, h)   { this.add('POST', p, m, h); }
  put(p, m, h)    { this.add('PUT', p, m, h); }
  delete(p, m, h) { this.add('DELETE', p, m, h); }

  match(method, pathname) {
    let pathMatched = false;
    for (const r of this.routes) {
      const m = r.pattern.exec(pathname);
      if (!m) continue;
      pathMatched = true;
      if (r.method !== method) continue;
      const params = {};
      r.keys.forEach((k, i) => { params[k] = decodeURIComponent(m[i + 1]); });
      return { route: r, params };
    }
    return { route: null, methodNotAllowed: pathMatched };
  }
}

module.exports = { Router };
