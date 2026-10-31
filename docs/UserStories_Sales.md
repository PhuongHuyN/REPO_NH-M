# User Story — Module Bán hàng 

> **Dự án:** FreshVend — máy bán trái cây tươi tự động  
> **Module:** `sales` (Kiosk + đơn hàng + thanh toán QR)  
> **Sản phẩm kèm:** [`State.drawio`](./State.drawio) — State Diagram trạng thái đơn hàng  

---

## 1. Actor

| Actor | Mô tả |
|-------|--------|
| **Khách hàng** | Người mua tại máy (kiosk), không cần đăng nhập |
| **Hệ thống** | API + job hết hạn đơn + webhook ngân hàng + bộ điều khiển máy |
| **Nhân viên / Admin** | Theo dõi đơn, xác nhận tiền thủ công, hoàn tiền khi cần |

---

## 2. User Story khách hàng

### US-S01 — Xem sản phẩm tại máy
**Là** khách hàng đứng trước máy FreshVend,  
**tôi muốn** xem danh sách sản phẩm còn hàng (tên, giá, ảnh),  
**để** chọn món phù hợp trước khi mua.

**Acceptance criteria**
- [ ] Kiosk chỉ hiện sản phẩm còn tồn tại máy đang dùng
- [ ] Hiển thị tên, giá, ảnh sản phẩm rõ ràng trên màn hình cảm ứng

---

### US-S02 — Giỏ hàng / chọn số lượng
**Là** khách hàng,  
**tôi muốn** thêm/bớt sản phẩm vào giỏ và xem tổng tiền,  
**để** kiểm soát đơn trước khi thanh toán.

**Acceptance criteria**
- [ ] Có thể thêm, tăng/giảm, xoá món trong giỏ
- [ ] Tổng tiền cập nhật đúng theo đơn giá × số lượng
- [ ] Không cho đặt vượt số lượng còn trong khay

---

### US-S03 — Thanh toán QR dưới 30 giây
**Là** khách hàng,  
**tôi muốn** thanh toán bằng mã VietQR và được hệ thống xác nhận nhanh,  
**để** không phải chờ lâu tại máy.

**Acceptance criteria**
- [ ] Sau khi bấm thanh toán, đơn ở trạng thái `PENDING` và hiện mã VietQR (số TK, số tiền, nội dung `FV…`)
- [ ] Khi tiền về (webhook) hoặc admin xác nhận, đơn chuyển `PENDING` → `PAID`
- [ ] Thời gian từ lúc quét/chuyển khoản thành công đến khi kiosk nhận trạng thái `PAID` **< 30 giây** (trong điều kiện mạng bình thường)
- [ ] Đơn `PENDING` quá **5 phút** tự chuyển `EXPIRED`, trả hàng về kho

---

### US-S04 — Nhận hàng
**Là** khách hàng đã thanh toán thành công,  
**tôi muốn** máy nhả đúng sản phẩm đã mua,  
**để** hoàn tất giao dịch.

**Acceptance criteria**
- [ ] Sau `PAID`, bộ điều khiển máy thực hiện nhả hàng
- [ ] Nhả thành công → đơn `DISPENSED`, kiosk báo “Mời nhận hàng”
- [ ] Màn hình theo dõi trạng thái đơn; không tự “giả” đã thanh toán/nhả hàng

---

### US-S05 — Thông báo khi kẹt hàng / hoàn tiền
**Là** khách hàng,  
**tôi muốn** được thông báo rõ khi máy kẹt hàng và biết đã/được hoàn tiền,  
**để** không mất tiền khi không nhận được hàng.

**Acceptance criteria**
- [ ] Nhả hàng thất bại → `PAID` → `DISPENSE_FAILED`, kiosk hiện thông báo lỗi / hướng dẫn hỗ trợ
- [ ] Hệ thống hoàn tiền → `DISPENSE_FAILED` → `REFUNDED` (tự động sau đủ lần thử lỗi, hoặc thao tác staff)
- [ ] Kiosk hiển thị trạng thái hoàn tiền; có hotline hỗ trợ khi cần

---

## 3. State Diagram đơn hàng (tóm tắt)

Luồng bắt buộc (chi tiết trong `docs/State.drawio`):

```
                    ┌──────────┐
                    │ EXPIRED  │  (cuối)
                    └────▲─────┘
                         │ quá 5 phút
┌───────┐   tạo đơn   ┌──┴──────┐  xác nhận tiền   ┌──────┐  nhả OK   ┌───────────┐
│ start │────────────►│ PENDING │─────────────────►│ PAID │─────────►│ DISPENSED │ (cuối)
└───────┘             └─────────┘                  └──┬───┘          └───────────┘
                                                      │ kẹt / lỗi
                                                      ▼
                                              ┌────────────────┐  hoàn tiền  ┌──────────┐
                                              │ DISPENSE_FAILED│────────────►│ REFUNDED │ (cuối)
                                              └────────────────┘             └──────────┘
```

| Từ | Đến | Điều kiện |
|----|-----|-----------|
| — | `PENDING` | Khách tạo đơn trên kiosk |
| `PENDING` | `PAID` | Thanh toán QR thành công (webhook / xác nhận) |
| `PENDING` | `EXPIRED` | Quá 5 phút chưa thanh toán |
| `PAID` | `DISPENSED` | Nhả hàng thành công |
| `PAID` | `DISPENSE_FAILED` | Kẹt / nhả thất bại |
| `DISPENSE_FAILED` | `REFUNDED` | Hoàn tiền cho khách |

---

## 4. Liên kết FR trong SRS

| User Story | FR (SRS) |
|------------|----------|
| US-S01 … US-S05 | **FR-03** — Khách hàng mua hàng tại máy, thanh toán QR |
