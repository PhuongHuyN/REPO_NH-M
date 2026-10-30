// Sinh tài liệu OpenAPI 3 tự động từ metadata của router + trang Swagger UI
function buildSpec(router) {
  const paths = {};
  for (const r of router.routes) {
    const p = r.path.replace(/:(\w+)/g, '{$1}');
    paths[p] = paths[p] || {};
    const auth = r.meta.auth || 'user';
    const op = {
      tags: [r.meta.tag || 'Khác'],
      summary: r.meta.summary || '',
      description: [
        auth === 'public' ? 'Không cần đăng nhập.' : auth === 'device' ? 'Header **X-Device-Key** (thiết bị ESP32).' : 'Cần **Bearer JWT**.',
        r.meta.roles ? `Vai trò: ${r.meta.roles.join(', ')}.` : '',
        auth === 'user-or-device' ? 'Hoặc header X-Device-Key.' : '',
      ].filter(Boolean).join(' '),
      parameters: r.keys.map((k) => ({ name: k, in: 'path', required: true, schema: { type: 'string' } })),
      responses: {
        200: { description: 'Thành công' }, 201: { description: 'Đã tạo' },
        400: { description: 'Dữ liệu không hợp lệ' }, 401: { description: 'Chưa đăng nhập' },
        403: { description: 'Không đủ quyền (API hoặc CSDL)' }, 404: { description: 'Không tìm thấy' },
        409: { description: 'Xung đột nghiệp vụ (hết hàng, trạng thái sai...)' },
      },
    };
    if (auth === 'device') op.security = [{ deviceKey: [] }];
    else if (auth === 'user-or-device') op.security = [{ bearer: [] }, { deviceKey: [] }];
    else if (auth !== 'public') op.security = [{ bearer: [] }];
    if (r.meta.body) {
      op.requestBody = { required: true, content: { 'application/json': { schema: { type: 'object' }, example: r.meta.body } } };
    }
    paths[p][r.method.toLowerCase()] = op;
  }
  return {
    openapi: '3.0.3',
    info: {
      title: 'FreshVend API',
      version: '1.0.0',
      description: 'API trung tâm của hệ thống máy bán trái cây FreshVend. Mọi thao tác ghi gọi Stored Procedure trên SQL Server; '
        + 'phân quyền 2 lớp: kiểm tra vai trò ở API và GRANT/DENY + Row-Level Security trong CSDL.',
    },
    servers: [{ url: '/' }],
    components: {
      securitySchemes: {
        bearer: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
        deviceKey: { type: 'apiKey', in: 'header', name: 'X-Device-Key' },
      },
    },
    paths,
  };
}

const swaggerHtml = `<!doctype html><html lang="vi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>FreshVend API Docs</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.17.14/swagger-ui.css">
</head><body><div id="swagger"></div>
<script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.17.14/swagger-ui-bundle.js"></script>
<script>window.ui = SwaggerUIBundle({ url: '/api/openapi.json', dom_id: '#swagger', persistAuthorization: true });</script>
</body></html>`;

module.exports = { buildSpec, swaggerHtml };
