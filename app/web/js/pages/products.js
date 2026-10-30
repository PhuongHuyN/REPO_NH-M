// TV2 – Sản phẩm & giá (Admin, Operator): thêm/sửa sản phẩm, ảnh, đổi giá, lịch sử giá (Temporal Table)
import { esc, money, dt, table, modal, toast, formData, productImage } from '../ui.js';
import { icon } from '../icons.js';

const thumb = (url, r) => `<img class="thumb" src="${esc(productImage(r?.ProductName, url, r?.ProductId))}" alt="" loading="lazy">`;

// Đọc file ảnh, thu nhỏ về cạnh dài tối đa 800px, nén JPEG để gửi lên máy chủ
function readImage(file) {
  return new Promise((resolve, reject) => {
    if (!/^image\/(jpeg|png|webp)$/.test(file.type)) return reject(new Error('Chỉ nhận ảnh JPG, PNG hoặc WebP'));
    const img = new Image();
    img.onload = () => {
      const k = Math.min(1, 800 / Math.max(img.width, img.height));
      const c = document.createElement('canvas');
      c.width = Math.round(img.width * k); c.height = Math.round(img.height * k);
      const g = c.getContext('2d');
      g.fillStyle = '#fff'; g.fillRect(0, 0, c.width, c.height);
      g.drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(img.src);
      resolve(c.toDataURL('image/jpeg', 0.85));
    };
    img.onerror = () => reject(new Error('Không đọc được ảnh'));
    img.src = URL.createObjectURL(file);
  });
}

export default {
  title: 'Sản phẩm & giá', icon: 'tag', group: 'Vận hành', roles: ['Admin', 'Operator'],
  async render(el, { api }) {
    el.innerHTML = `
      <div class="card">
        <div class="card-head"><h3 style="margin:0">Danh mục sản phẩm</h3>
          <button class="btn primary" id="addBtn">${icon('plus', 16)} Thêm sản phẩm</button></div>
        <div id="list"></div>
      </div>`;

    const load = async () => {
      const rows = await api.get('/api/inventory/products');
      el._rows = rows;
      el.querySelector('#list').innerHTML = table(rows, [
        { key: 'ImageUrl', label: '', render: thumb },
        { key: 'ProductName', label: 'Sản phẩm', render: (v, r) => `<b>${esc(v)}</b><br><span class="small muted">${esc(r.Category || '')}${r.Description ? ' · ' + esc(r.Description) : ''}</span>` },
        { key: 'Price', label: 'Giá bán', cls: 'num', render: money },
        { key: 'PriceSince', label: 'Áp dụng từ', render: dt },
        { key: 'ShelfLifeHours', label: 'Hạn dùng', cls: 'num', render: (v) => `${v} giờ` },
        { key: 'ColumnCount', label: 'Đang bán ở', cls: 'num', render: (v) => `${v} ô` },
        { key: 'IsActive', label: 'Trạng thái', render: (v) => (v === false || v === 0 ? '<span class="badge">Ngừng bán</span>' : '<span class="badge green">Đang bán</span>') },
        { key: 'ProductId', label: '', render: (v) => `<button class="btn sm" data-edit="${v}">${icon('edit', 14)} Sửa</button>
            <button class="btn sm" data-price="${v}">Đổi giá</button> <button class="btn ghost sm" data-hist="${v}">Lịch sử giá</button>` },
      ], { empty: 'Chưa có sản phẩm' });
    };

    // ---- Thêm mới ----
    el.querySelector('#addBtn').addEventListener('click', () => {
      modal('Thêm sản phẩm', `<form class="stack" id="af">
          <div><label>Tên sản phẩm</label><input name="productName" required maxlength="100"></div>
          <div class="form-grid">
            <div class="field"><label>Giá bán (VNĐ)</label><input name="price" type="number" min="1000" step="1000" required></div>
            <div class="field"><label>Hạn dùng sau khi sơ chế (giờ)</label><input name="shelfLifeHours" type="number" min="1" max="120" value="24" required></div>
          </div>
          <div><label>Nhóm hàng</label><input name="category" value="Trái cây cắt sẵn" maxlength="50"></div>
          <div><label>Mô tả ngắn (quy cách, khối lượng)</label><input name="description" maxlength="300" placeholder="VD: Hộp 250g"></div>
          <p class="small muted">Ảnh sản phẩm thêm sau khi lưu, bằng nút <b>Sửa</b>.</p>
          <div class="row" style="justify-content:flex-end"><button type="button" class="btn" data-close>Hủy</button><button class="btn primary">Lưu</button></div>
        </form>`, {
        onMount: (body, close) => body.querySelector('#af').addEventListener('submit', async (e) => {
          e.preventDefault();
          const f = formData(e.target);
          try {
            await api.post('/api/inventory/products', { ...f, price: Number(f.price), shelfLifeHours: Number(f.shelfLifeHours) });
            toast('Đã thêm sản phẩm', 'ok'); close(); load();
          } catch (err) { toast(err.message, 'err'); }
        }),
      });
    });

    const editModal = (row) => {
      modal(`Sửa sản phẩm`, `<form class="stack" id="ef">
          <div class="img-edit">
            <div class="preview" id="pv">${row.ImageUrl ? `<img src="${esc(row.ImageUrl)}" alt="" style="width:100%;height:100%;object-fit:cover;border-radius:8px">` : icon('image', 32)}</div>
            <div>
              <label class="btn sm" style="margin:0">${icon('upload', 14)} Chọn ảnh…<input type="file" id="file" accept="image/jpeg,image/png,image/webp" hidden></label>
              <p class="small muted" style="margin:8px 0 0">JPG/PNG/WebP, nên dùng ảnh chụp thật, nền sáng, tỉ lệ vuông.</p>
            </div>
          </div>
          <div><label>Tên sản phẩm</label><input name="productName" required maxlength="100" value="${esc(row.ProductName)}"></div>
          <div class="form-grid">
            <div class="field"><label>Nhóm hàng</label><input name="category" maxlength="50" value="${esc(row.Category || '')}"></div>
            <div class="field"><label>Hạn dùng (giờ)</label><input name="shelfLifeHours" type="number" min="1" max="120" required value="${row.ShelfLifeHours}"></div>
          </div>
          <div><label>Mô tả ngắn</label><input name="description" maxlength="300" value="${esc(row.Description || '')}"></div>
          <label style="display:flex;gap:8px;align-items:center;font-weight:500"><input type="checkbox" name="isActive" ${row.IsActive === false || row.IsActive === 0 ? '' : 'checked'}> Đang kinh doanh</label>
          <p class="small muted" style="margin:0">Giá bán đổi bằng nút <b>Đổi giá</b> để hệ thống lưu lịch sử.</p>
          <div class="row" style="justify-content:flex-end"><button type="button" class="btn" data-close>Đóng</button><button class="btn primary">Lưu thay đổi</button></div>
        </form>`, {
        onMount: (body, close) => {
          body.querySelector('#file').addEventListener('change', async (e) => {
            const file = e.target.files[0];
            if (!file) return;
            try {
              const dataUrl = await readImage(file);
              const r = await api.post(`/api/inventory/products/${row.ProductId}/image`, { dataUrl });
              row.ImageUrl = r.ImageUrl;
              body.querySelector('#pv').innerHTML = `<img src="${esc(r.ImageUrl)}" alt="" style="width:100%;height:100%;object-fit:cover;border-radius:8px">`;
              toast('Đã cập nhật ảnh', 'ok'); load();
            } catch (err) { toast(err.message, 'err'); }
            e.target.value = '';
          });
          body.querySelector('#ef').addEventListener('submit', async (e) => {
            e.preventDefault();
            const f = formData(e.target);
            try {
              await api.put(`/api/inventory/products/${row.ProductId}`, {
                productName: f.productName, category: f.category || null, description: f.description || null,
                shelfLifeHours: Number(f.shelfLifeHours), isActive: e.target.isActive.checked, imageUrl: row.ImageUrl || null,
              });
              toast('Đã lưu sản phẩm', 'ok'); close(); load();
            } catch (err) { toast(err.message, 'err'); }
          });
        },
      });
    };

    el.querySelector('#list').addEventListener('click', async (e) => {
      const ed = e.target.closest('[data-edit]'), p = e.target.closest('[data-price]'), h = e.target.closest('[data-hist]');
      if (ed) editModal(el._rows.find((r) => r.ProductId === Number(ed.dataset.edit)));
      if (p) {
        const row = el._rows.find((r) => r.ProductId === Number(p.dataset.price));
        modal(`Đổi giá: ${row.ProductName}`, `<form class="stack" id="pf"><p>Giá hiện tại: <b>${money(row.Price)}</b></p>
          <div><label>Giá mới (VNĐ)</label><input name="price" type="number" min="1000" step="1000" required value="${Number(row.Price)}"></div>
          <div class="row" style="justify-content:flex-end"><button type="button" class="btn" data-close>Hủy</button><button class="btn primary">Lưu giá mới</button></div></form>`, {
          onMount: (body, close) => body.querySelector('#pf').addEventListener('submit', async (ev) => {
            ev.preventDefault();
            try { await api.put(`/api/inventory/products/${row.ProductId}/price`, { price: Number(formData(ev.target).price) }); toast('Đã đổi giá', 'ok'); close(); load(); }
            catch (err) { toast(err.message, 'err'); }
          }),
        });
      }
      if (h) {
        const hist = await api.get(`/api/inventory/products/${h.dataset.hist}/price-history`);
        modal('Lịch sử giá', table(hist, [
          { key: 'Price', label: 'Giá', cls: 'num', render: money },
          { key: 'ValidFrom', label: 'Từ', render: dt },
          { key: 'ValidTo', label: 'Đến', render: (v, r) => (r.IsCurrent ? '<span class="badge green">Hiện tại</span>' : dt(v)) },
        ]));
      }
    });
    await load();
  },
};
