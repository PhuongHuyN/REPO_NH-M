/* =====================================================================
   TV2 – Sản phẩm & Tồn kho  (/api/inventory/*)
   SP: inventory.sp_AddProduct, sp_UpdatePrice, sp_AssignColumn, sp_AddBatch, sp_Restock (TVP), sp_RemoveExpired
   View/TVF: vw_ProductCatalog, vw_StockStatus, vw_AvailableBatches, vw_ExpiringBatches, fn_PriceHistory
   ===================================================================== */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const db = require('../db');
const config = require('../config');
const { HttpError } = require('../lib/http');
const v = require('../lib/validate');

const STAFF = ['Admin', 'Operator'];

module.exports = (r) => {
  r.get('/api/inventory/products', { tag: 'Inventory (TV2)', summary: 'Danh mục sản phẩm', roles: STAFF },
    async (ctx) => ctx.view('inventory.vw_ProductCatalog', { orderBy: 'ProductId' }));

  r.post('/api/inventory/products', {
    tag: 'Inventory (TV2)', summary: 'Thêm sản phẩm', roles: STAFF,
    body: { productName: 'Sầu riêng Ri6', price: 59000, shelfLifeHours: 24, category: 'Trái cây cắt sẵn', description: 'Hộp 200g' },
  }, async (ctx) => {
    const b = ctx.body;
    const r1 = await ctx.exec('inventory.sp_AddProduct', {
      ProductName: db.T.str(v.str(b.productName, 'Tên sản phẩm', { min: 1, max: 100 })),
      Price: db.T.dec(v.num(b.price, 'Giá', { min: 1, max: 10000000 })),
      ShelfLifeHours: db.T.int(v.int(b.shelfLifeHours, 'Hạn dùng (giờ)', { min: 1, max: 120 })),
      Category: db.T.str(v.str(b.category, 'Nhóm', { max: 50, optional: true }) ?? null),
      Description: db.T.str(v.str(b.description, 'Mô tả', { max: 300, optional: true }) ?? null),
      ImageUrl: db.T.str(v.str(b.imageUrl, 'Ảnh', { max: 300, optional: true }) ?? null),
    });
    ctx.status = 201;
    return r1.recordset[0];
  });

  r.put('/api/inventory/products/:id', {
    tag: 'Inventory (TV2)', summary: 'Sửa thông tin sản phẩm / ngừng bán', roles: STAFF,
    body: { productName: 'Dưa hấu cắt sẵn', category: 'Trái cây cắt sẵn', description: 'Hộp 250g', shelfLifeHours: 24, isActive: true },
  }, async (ctx) => {
    const b = ctx.body;
    const r1 = await ctx.exec('inventory.sp_UpdateProduct', {
      ProductId: db.T.int(v.int(ctx.params.id, 'ProductId', { min: 1 })),
      ProductName: db.T.str(v.str(b.productName, 'Tên sản phẩm', { min: 1, max: 100 })),
      Category: db.T.str(v.str(b.category, 'Nhóm', { max: 50, optional: true }) ?? null),
      Description: db.T.str(v.str(b.description, 'Mô tả', { max: 300, optional: true }) ?? null),
      ImageUrl: db.T.str(v.str(b.imageUrl, 'Ảnh', { max: 300, optional: true }) ?? null),
      ShelfLifeHours: db.T.int(v.int(b.shelfLifeHours, 'Hạn dùng (giờ)', { min: 1, max: 120 })),
      IsActive: db.T.bit(b.isActive === undefined ? true : !!b.isActive),
    });
    return r1.recordset[0];
  });

  // Ảnh sản phẩm: gửi base64 trong JSON (không cần thư viện multipart), lưu vào web/uploads/products
  r.post('/api/inventory/products/:id/image', {
    tag: 'Inventory (TV2)', summary: 'Tải ảnh sản phẩm (JPG/PNG/WebP ≤ 2 MB, base64)', roles: STAFF,
    bodyLimit: 4 * 1024 * 1024, body: { dataUrl: 'data:image/jpeg;base64,/9j/4AAQ...' },
  }, async (ctx) => {
    const id = v.int(ctx.params.id, 'ProductId', { min: 1 });
    const m = /^data:image\/(jpeg|png|webp);base64,([A-Za-z0-9+/=]+)$/.exec(String(ctx.body.dataUrl || ''));
    if (!m) throw v.bad('Ảnh phải là JPG, PNG hoặc WebP');
    const buf = Buffer.from(m[2], 'base64');
    if (buf.length > 2 * 1024 * 1024) throw v.bad('Ảnh tối đa 2 MB');
    const sig = { jpeg: [0xff, 0xd8], png: [0x89, 0x50], webp: [0x52, 0x49] }[m[1]];
    if (buf[0] !== sig[0] || buf[1] !== sig[1]) throw v.bad('Nội dung tệp không đúng định dạng ảnh');
    const rows = await ctx.view('inventory.vw_ProductCatalog', { where: { ProductId: id } });
    const p = rows[0];
    if (!p) throw new HttpError(404, 'Không tìm thấy sản phẩm', 'NOT_FOUND');
    const dir = path.join(config.uploadDir, 'products');
    fs.mkdirSync(dir, { recursive: true });
    const file = `${id}-${crypto.randomBytes(4).toString('hex')}.${m[1] === 'jpeg' ? 'jpg' : m[1]}`;
    fs.writeFileSync(path.join(dir, file), buf);
    const url = `/uploads/products/${file}`;
    const r1 = await ctx.exec('inventory.sp_UpdateProduct', {
      ProductId: db.T.int(id), ProductName: db.T.str(p.ProductName), Category: db.T.str(p.Category ?? null),
      Description: db.T.str(p.Description ?? null), ImageUrl: db.T.str(url),
      ShelfLifeHours: db.T.int(p.ShelfLifeHours), IsActive: db.T.bit(p.IsActive === undefined ? true : !!p.IsActive),
    });
    // Xóa ảnh cũ do hệ thống tải lên trước đó
    if (p.ImageUrl && p.ImageUrl.startsWith('/uploads/products/')) {
      fs.rm(path.join(config.uploadDir, 'products', path.basename(p.ImageUrl)), { force: true }, () => {});
    }
    return r1.recordset[0];
  });

  r.put('/api/inventory/products/:id/price', {
    tag: 'Inventory (TV2)', summary: 'Đổi giá (Temporal Table lưu lịch sử)', roles: STAFF, body: { price: 28000 },
  }, async (ctx) => {
    const r1 = await ctx.exec('inventory.sp_UpdatePrice', {
      ProductId: db.T.int(v.int(ctx.params.id, 'ProductId', { min: 1 })),
      NewPrice: db.T.dec(v.num(ctx.body.price, 'Giá', { min: 1, max: 10000000 })),
    });
    return r1.recordset[0];
  });

  r.get('/api/inventory/products/:id/price-history', {
    tag: 'Inventory (TV2)', summary: 'Lịch sử giá (FOR SYSTEM_TIME ALL)', roles: STAFF,
  }, async (ctx) => ctx.tvf('inventory.fn_PriceHistory', [db.T.int(v.int(ctx.params.id, 'ProductId', { min: 1 }))], { orderBy: 'ValidFrom DESC' }));

  r.get('/api/inventory/stock', {
    tag: 'Inventory (TV2)', summary: 'Tồn kho theo cột (lọc ?machineId=)', roles: STAFF,
  }, async (ctx) => ctx.view('inventory.vw_StockStatus', {
    where: { MachineId: v.int(ctx.query.machineId, 'machineId', { optional: true }) },
    orderBy: 'MachineId, ColumnNo',
  }));

  r.put('/api/inventory/columns/:id', {
    tag: 'Inventory (TV2)', summary: 'Đổi sản phẩm cho cột (chỉ khi cột rỗng)', roles: STAFF, body: { productId: 3 },
  }, async (ctx) => {
    const r1 = await ctx.exec('inventory.sp_AssignColumn', {
      ColumnId: db.T.int(v.int(ctx.params.id, 'ColumnId', { min: 1 })),
      ProductId: db.T.int(v.int(ctx.body.productId, 'ProductId', { min: 1, optional: true }) ?? null),
    });
    return r1.recordset[0];
  });

  r.get('/api/inventory/batches', { tag: 'Inventory (TV2)', summary: 'Lô hàng còn có thể châm', roles: STAFF },
    async (ctx) => ctx.view('inventory.vw_AvailableBatches', {
      where: { ProductId: v.int(ctx.query.productId, 'productId', { optional: true }) }, orderBy: 'ExpiryAt',
    }));

  r.post('/api/inventory/batches', {
    tag: 'Inventory (TV2)', summary: 'Nhập lô hàng mới từ bếp trung tâm', roles: STAFF,
    body: { productId: 1, quantity: 40, supplier: 'Bếp trung tâm Quận 7' },
  }, async (ctx) => {
    const r1 = await ctx.exec('inventory.sp_AddBatch', {
      ProductId: db.T.int(v.int(ctx.body.productId, 'ProductId', { min: 1 })),
      Quantity: db.T.int(v.int(ctx.body.quantity, 'Số lượng', { min: 1, max: 1000 })),
      Supplier: db.T.str(v.str(ctx.body.supplier, 'Nhà cung cấp', { max: 100, optional: true }) ?? null),
    });
    ctx.status = 201;
    return r1.recordset[0];
  });

  r.post('/api/inventory/restock', {
    tag: 'Inventory (TV2)', summary: 'Châm hàng nhiều dòng trong 1 giao dịch (TVP)', roles: STAFF,
    body: { machineId: 1, note: 'Châm ca sáng', items: [{ columnId: 1, batchId: 1, qty: 2 }, { columnId: 2, batchId: 2, qty: 1 }] },
  }, async (ctx) => {
    const items = v.arr(ctx.body.items, 'items', { min: 1, max: 20 }).map((it, i) => ({
      ColumnId: v.int(it.columnId, `items[${i}].columnId`, { min: 1 }),
      BatchId: v.int(it.batchId, `items[${i}].batchId`, { min: 1 }),
      Qty: v.int(it.qty, `items[${i}].qty`, { min: 1, max: 20 }),
    }));
    const seen = new Set();
    for (const it of items) {
      const k = `${it.ColumnId}-${it.BatchId}`;
      if (seen.has(k)) throw v.bad('Mỗi cặp cột + lô chỉ được xuất hiện 1 lần');
      seen.add(k);
    }
    const r1 = await ctx.exec('inventory.sp_Restock', {
      MachineId: db.T.int(v.int(ctx.body.machineId, 'MachineId', { min: 1 })),
      UserId: db.T.int(ctx.user.sub),
      Items: db.tvp('inventory.RestockItemType', [['ColumnId', 'int'], ['BatchId', 'int'], ['Qty', 'smallint']], items),
      Note: db.T.str(v.str(ctx.body.note, 'Ghi chú', { max: 200, optional: true }) ?? null),
    });
    ctx.status = 201;
    return r1.recordset[0];
  });

  r.get('/api/inventory/expiring', { tag: 'Inventory (TV2)', summary: 'Lô sắp hết hạn (6 giờ) / đã hết hạn', roles: STAFF },
    async (ctx) => ctx.view('inventory.vw_ExpiringBatches', {
      where: { MachineId: v.int(ctx.query.machineId, 'machineId', { optional: true }) }, orderBy: 'ExpiryAt',
    }));

  r.post('/api/inventory/remove-expired', {
    tag: 'Inventory (TV2)', summary: 'Rút hàng hết hạn (thủ công, job chạy hằng giờ)', roles: STAFF, body: { machineId: 1 },
  }, async (ctx) => {
    const r1 = await ctx.exec('inventory.sp_RemoveExpired', {
      MachineId: db.T.int(v.int(ctx.body.machineId, 'MachineId', { min: 1, optional: true }) ?? null),
    });
    return r1.recordset[0];
  });
};
