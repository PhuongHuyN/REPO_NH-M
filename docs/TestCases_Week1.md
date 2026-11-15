# Ma trận Unit Test Tuần 1 — SCRUM-211

Kế hoạch test, **không phải kết quả thực thi**. 30 procedure / 90 ca; 23 procedure có định nghĩa và 7 procedure chờ owner. Dữ liệu ký hiệu U/A/M/L/C/P/B/O/I/AL phải được resolve bằng khóa fixture, không hardcode ID của CSDL khác.

Tiền điều kiện: CSDL test riêng; Admin A, Operator U, Kiosk K; máy M, địa điểm L, ngăn C, sản phẩm P, lô B, đơn O, chi tiết I, alert AL theo từng trạng thái trong Input. Mỗi ca ghi baseline (tồn, tổng tiền, row count), gọi procedure đúng một lần hoặc số lần nêu rõ, đối chiếu Expected bằng SELECT độc lập và ERROR_NUMBER. Dọn fixture bằng rollback khi transaction còn hợp lệ; lỗi XACT_ABORT rollback toàn bộ thì dựng lại fixture cho ca sau.

Nguồn oracle: SQL chủ module + app/api/test/fakeDb.js + tests/tests_inventory.sql + tests/tests_sales.sql. Các case auth/Restock/RemoveExpired là kế hoạch từ hợp đồng mock, chưa có đủ implementation. Chưa nhận xác nhận trực tiếp từ bốn owner: cần Toàn/Huy/Ân/Dũng review Expected trước Sprint 2. Không giả nhận xét hoặc kết quả của thành viên khác.

## auth

| ID | Procedure / sẵn sàng | Input / bước gọi | Expected / oracle |
|---|---|---|---|
| UT-AUTH-01-OK | auth.sp_CreateUser (planned) | Username=qa_new, Password=QaPass123!, RoleName=Operator, FullName=QA | Tạo đúng 1 user, role đúng; mật khẩu không lưu plain text |
| UT-AUTH-01-ERR1 | auth.sp_CreateUser (planned) | Username=ab | 50001; không tạo user |
| UT-AUTH-01-ERR2 | auth.sp_CreateUser (planned) | Username=admin đã có | 50003; không tạo user trùng |
| UT-AUTH-02-OK | auth.sp_Login (planned) | Admin hoạt động + mật khẩu đúng; ClientInfo=QA | Success=1, đúng UserId/RoleName; reset failed count, ghi LoginActivity |
| UT-AUTH-02-ERR1 | auth.sp_Login (planned) | Mật khẩu sai 1 lần | Success=0, failed count +1, không trả quyền |
| UT-AUTH-02-ERR2 | auth.sp_Login (planned) | Sai liên tiếp 5 lần trên fixture riêng | Success=0, tài khoản khóa, lần sau không đăng nhập; không coi là exception 500xx |
| UT-AUTH-03-OK | auth.sp_ChangePassword (planned) | UserId=U hoạt động, OldPassword đúng, NewPassword=Different123! | Đổi salt/hash; mật khẩu cũ không đăng nhập được |
| UT-AUTH-03-ERR1 | auth.sp_ChangePassword (planned) | OldPassword sai | 50011; hash giữ nguyên |
| UT-AUTH-03-ERR2 | auth.sp_ChangePassword (planned) | NewPassword ngắn 7 ký tự | 50002; hash giữ nguyên |
| UT-AUTH-04-OK | auth.sp_AssignMachine (planned) | UserId=Operator U, MachineId=M có thật, Unassign=0 | Một assignment; gọi lại không trùng |
| UT-AUTH-04-ERR1 | auth.sp_AssignMachine (planned) | UserId=-1 | 50020; không assignment |
| UT-AUTH-04-ERR2 | auth.sp_AssignMachine (planned) | UserId=Admin | 50021; không giao máy cho Admin |
| UT-AUTH-05-OK | auth.sp_DeactivateUser (planned) | UserId=Operator U hoạt động, Activate=0; SESSION_CONTEXT UserId=Admin A | IsActive=0; phiên đăng nhập mới bị từ chối |
| UT-AUTH-05-ERR1 | auth.sp_DeactivateUser (planned) | UserId=-1 | 50030; không thay user khác |
| UT-AUTH-05-ERR2 | auth.sp_DeactivateUser (planned) | UserId=A, Activate=0, SESSION_CONTEXT UserId=A | 50031; không tự vô hiệu hóa |

## inventory

| ID | Procedure / sẵn sàng | Input / bước gọi | Expected / oracle |
|---|---|---|---|
| UT-INVENTORY-06-OK | inventory.sp_AddProduct (present) | ProductName=QA_NEW, Price=15000, ShelfLifeHours=24, Category=Trái cây cắt sẵn | Đúng ProductId, ProductName, Price; SKU duy nhất |
| UT-INVENTORY-06-ERR1 | inventory.sp_AddProduct (present) | Price=0 | 50102; không thêm sản phẩm |
| UT-INVENTORY-06-ERR2 | inventory.sp_AddProduct (present) | ProductName đã tồn tại | 50101; không thêm trùng |
| UT-INVENTORY-07-OK | inventory.sp_UpdateProduct (present) | ProductId=P, tên mới duy nhất, ShelfLifeHours=24, IsActive=1 | Đúng cột thay đổi, không sửa giá bằng đường vòng |
| UT-INVENTORY-07-ERR1 | inventory.sp_UpdateProduct (present) | ProductId=-1 | 50103; không update |
| UT-INVENTORY-07-ERR2 | inventory.sp_UpdateProduct (present) | ProductName trùng sản phẩm khác | 50101; không update |
| UT-INVENTORY-08-OK | inventory.sp_UpdatePrice (present) | ProductId=P, NewPrice khác giá cũ và >0, UpdatedBy=A | OldPrice/NewPrice đúng, temporal history thêm phiên bản |
| UT-INVENTORY-08-ERR1 | inventory.sp_UpdatePrice (present) | ProductId=-1 | 50103; không history mới |
| UT-INVENTORY-08-ERR2 | inventory.sp_UpdatePrice (present) | NewPrice bằng giá hiện tại | 50104; không update/history |
| UT-INVENTORY-09-OK | inventory.sp_AssignColumn (present) | ColumnId=C rỗng trên máy được giao, ProductId=P, UpdatedBy=U | ColumnId/ColumnNo đúng alias Slot; gán đúng sản phẩm |
| UT-INVENTORY-09-ERR1 | inventory.sp_AssignColumn (present) | ColumnId=-1 | 50105; không update |
| UT-INVENTORY-09-ERR2 | inventory.sp_AssignColumn (present) | Cột còn ít nhất một hộp | 50106; không đổi sản phẩm |
| UT-INVENTORY-10-OK | inventory.sp_AddBatch (present) | ProductId=P hoạt động, Quantity=20, PreparedAt UTC=T, Supplier=QA | ExpiryAt=T+ShelfLifeHours; BatchCode duy nhất |
| UT-INVENTORY-10-ERR1 | inventory.sp_AddBatch (present) | ProductId=-1 | 50107; không lô mới |
| UT-INVENTORY-10-ERR2 | inventory.sp_AddBatch (present) | Quantity=0 | 50113; không lô mới |
| UT-INVENTORY-11-OK | inventory.sp_Restock (planned) | MachineId=M được giao, UserId=U, Items TVP có C/B/Qty=2 hợp lệ, Note=QA | Tồn theo lô +2, phiếu/chi tiết/movement đủ, giao dịch atomic |
| UT-INVENTORY-11-ERR1 | inventory.sp_Restock (planned) | Items TVP rỗng | 50111; không đổi tồn/phiếu |
| UT-INVENTORY-11-ERR2 | inventory.sp_Restock (planned) | Qty làm vượt Capacity (kèm dòng trước hợp lệ) | 50117; rollback tất cả dòng, không nạp một phần |
| UT-INVENTORY-12-OK | inventory.sp_RemoveExpired (planned) | MachineId=M; có một lô hết hạn và một lô còn hạn | Chỉ rút lô hết hạn; trả RemovedLines/RemovedQty đúng |
| UT-INVENTORY-12-ERR1 | inventory.sp_RemoveExpired (planned) | MachineId=-1 | Không thay tồn, 0 dòng; nếu owner chốt mã lỗi mới thì cập nhật oracle trước chạy |
| UT-INVENTORY-12-ERR2 | inventory.sp_RemoveExpired (planned) | MachineId=M, không có lô hết hạn | 0 dòng/hộp, không xóa lô còn hạn (ca âm nghiệp vụ) |

## sales

| ID | Procedure / sẵn sàng | Input / bước gọi | Expected / oracle |
|---|---|---|---|
| UT-SALES-13-OK | sales.sp_CreateOrder (present) | MachineId=M ACTIVE, Items TVP ColumnId=C/Qty=1 còn tồn chưa hết hạn, CustomerId=NULL | PENDING, TotalAmount đúng, FIFO trừ tồn đúng lô, ExpiresAt +5 phút |
| UT-SALES-13-ERR1 | sales.sp_CreateOrder (present) | Items TVP rỗng | 50200; không đơn/tồn thay đổi |
| UT-SALES-13-ERR2 | sales.sp_CreateOrder (present) | Qty vượt tồn hợp lệ | 50201; toàn bộ rollback |
| UT-SALES-14-OK | sales.sp_ConfirmPayment (present) | OrderId=O PENDING chưa hết hạn, Method=VIETQR, GatewayTxnId=QA-UNIQUE, Amount đúng | PAID; một payment; callback y hệt lần hai IsDuplicate=1 |
| UT-SALES-14-ERR1 | sales.sp_ConfirmPayment (present) | Amount khác TotalAmount | 50208; chưa PAID, không payment mới |
| UT-SALES-14-ERR2 | sales.sp_ConfirmPayment (present) | O quá hạn 5 phút | 50207; không thu tiền thành công |
| UT-SALES-15-OK | sales.sp_RecordDispense (present) | OrderItemId=I thuộc PAID, Result=SUCCESS, ErrorCode=NULL | Ghi một DispenseEvents; toàn đơn nhả đủ → DISPENSED |
| UT-SALES-15-ERR1 | sales.sp_RecordDispense (present) | Result=UNKNOWN | 50211; không event |
| UT-SALES-15-ERR2 | sales.sp_RecordDispense (present) | OrderItemId=-1 | 50212; không event/hoàn tiền |
| UT-SALES-16-OK | sales.sp_Refund (present) | OrderId=O PAID chưa nhả, Reason=QA, RefundedBy=A | Đúng phần chưa nhả được hoàn; một Refund; tồn trả đúng |
| UT-SALES-16-ERR1 | sales.sp_Refund (present) | OrderId=-1 | 50216; không refund |
| UT-SALES-16-ERR2 | sales.sp_Refund (present) | OrderId của đơn PENDING | 50217; không refund |
| UT-SALES-17-OK | sales.sp_ExpirePendingOrders (present) | OrderId=O PENDING quá hạn; hoặc NULL cho batch | EXPIRED, trả tồn đúng; trả số đơn hết hạn |
| UT-SALES-17-ERR1 | sales.sp_ExpirePendingOrders (present) | OrderId của đơn PAID | Không đổi trạng thái hoặc tồn (ca âm trạng thái) |
| UT-SALES-17-ERR2 | sales.sp_ExpirePendingOrders (present) | OrderId đã EXPIRED | Không trả tồn hai lần; 0 thay đổi |

## iot

| ID | Procedure / sẵn sàng | Input / bước gọi | Expected / oracle |
|---|---|---|---|
| UT-IOT-18-OK | iot.sp_RegisterMachine (present) | Serial=QA-NEW, MachineName=QA, LocationId=L có thật, FirmwareVersion=1.0 | Máy ACTIVE + thresholds 2..8; không tạo bản sao inventory |
| UT-IOT-18-ERR1 | iot.sp_RegisterMachine (present) | Serial đã tồn tại | 50301; không máy/threshold mới |
| UT-IOT-18-ERR2 | iot.sp_RegisterMachine (present) | LocationId=-1 | 50302; không máy mới |
| UT-IOT-19-OK | iot.sp_IngestTelemetry (present) | Payload JSON array [{machineId:M,temp:4,hum:65,door:0}] | Một telemetry đúng M và dữ liệu, heartbeat UTC cập nhật |
| UT-IOT-19-ERR1 | iot.sp_IngestTelemetry (present) | Payload=not-json | 50310; không telemetry |
| UT-IOT-19-ERR2 | iot.sp_IngestTelemetry (present) | Payload machineId không tồn tại | 50311; không telemetry |
| UT-IOT-20-OK | iot.sp_AcknowledgeAlert (present) | AlertId=AL mở, UserId=A | AckBy/AckAt đúng, không tự resolve cảnh báo |
| UT-IOT-20-ERR1 | iot.sp_AcknowledgeAlert (present) | AlertId=-1 | 50320; không update |
| UT-IOT-20-ERR2 | iot.sp_AcknowledgeAlert (present) | AL đã acknowledge | 50321; không ghi đè AckBy |
| UT-IOT-21-OK | iot.sp_ClearFault (present) | MachineId=M FAULT, UserId=A, Note=QA | ACTIVE, đóng cảnh báo của máy, trả OldStatus/NewStatus |
| UT-IOT-21-ERR1 | iot.sp_ClearFault (present) | MachineId=-1 | 50330; không update |
| UT-IOT-21-ERR2 | iot.sp_ClearFault (present) | M đang ACTIVE | 50331; không tạo chuyển trạng thái giả |
| UT-IOT-22-OK | iot.sp_UpdateThreshold (present) | MachineId=M, MinTemp=2, MaxTemp=8, DoorOpenMaxMinutes=2, ConsecutiveBreaches=3, DegradedMessage=QA | Đúng một threshold và cột trả về |
| UT-IOT-22-ERR1 | iot.sp_UpdateThreshold (present) | MachineId=-1 | 50340; không update |
| UT-IOT-22-ERR2 | iot.sp_UpdateThreshold (present) | MinTemp=8, MaxTemp=2 | 50341; không update |
| UT-IOT-23-OK | iot.sp_CheckHeartbeat (present) | Minutes=5; M heartbeat 6 phút trước, M2 heartbeat 1 phút trước | Chỉ M OFFLINE, một cảnh báo mở, gọi lại không trùng |
| UT-IOT-23-ERR1 | iot.sp_CheckHeartbeat (present) | Thực thi bằng Kiosk sau 40_security | 229/permission denied, không thay máy; BLOCKED khi chưa có security |
| UT-IOT-23-ERR2 | iot.sp_CheckHeartbeat (present) | CSDL test READ_ONLY với máy cần update | 3906; không thay đổi trạng thái; dọn READ_WRITE trong finally |
| UT-IOT-24-OK | iot.sp_AggregateHourly (present) | Telemetry của giờ đang tổng hợp, nhiệt độ 2 và 8 và vượt ngưỡng | Hourly đúng min/max/avg/count, phút thật 0..60, upsert lặp không tăng |
| UT-IOT-24-ERR1 | iot.sp_AggregateHourly (present) | Thực thi bằng Operator sau 40_security | 229, không sửa hourly; BLOCKED khi chưa có security |
| UT-IOT-24-ERR2 | iot.sp_AggregateHourly (present) | CSDL test READ_ONLY với dữ liệu cần MERGE | 3906; không ghi một phần; khôi phục READ_WRITE trong finally |

## report

| ID | Procedure / sẵn sàng | Input / bước gọi | Expected / oracle |
|---|---|---|---|
| UT-REPORT-25-OK | report.sp_DashboardKpi (present) | AsOf=2026-11-03, MachineId=NULL | 3 result sets; net doanh thu PAID/DISPENSED, 14 ngày, top 5, máy ACTIVE |
| UT-REPORT-25-ERR1 | report.sp_DashboardKpi (present) | MachineId=-1 | 50401; không trả KPI giả |
| UT-REPORT-25-ERR2 | report.sp_DashboardKpi (present) | AsOf=9999-12-31 | 50401; không tràn ngày |
| UT-REPORT-26-OK | report.sp_RevenueGrowth (present) | Year=2026 | 12 tháng, QtySold/PrevRevenue đúng; LAG, running sum đúng |
| UT-REPORT-26-ERR1 | report.sp_RevenueGrowth (present) | Year=1999 | 50401 |
| UT-REPORT-26-ERR2 | report.sp_RevenueGrowth (present) | Year=9999 | 50401 |
| UT-REPORT-27-OK | report.sp_PeakHours (present) | From=2026-08-06, To=2026-11-03 | 24 hàng T2..CN; tổng đơn đúng; DATEFIRST 1/7 không đổi |
| UT-REPORT-27-ERR1 | report.sp_PeakHours (present) | From > To | 50401 |
| UT-REPORT-27-ERR2 | report.sp_PeakHours (present) | To=9999-12-31 | 50401 |
| UT-REPORT-28-OK | report.sp_ExportSales (present) | From/To hợp lệ, UserId có thật, LocationId=NULL, FileFormat=CSV | Audit rows PAID/DISPENSED/REFUNDED/DISPENSE_FAILED; Params JSON; log PENDING |
| UT-REPORT-28-ERR1 | report.sp_ExportSales (present) | From=NULL | 50402; không log |
| UT-REPORT-28-ERR2 | report.sp_ExportSales (present) | UserId=-1 | 50402; không log |
| UT-REPORT-29-OK | report.sp_RefreshDailySummary (present) | Date=2026-08-06, ToDate=2026-11-03 | Gross chi tiết, discount phân bổ, net đúng; lặp không nhân, refund loại summary cũ |
| UT-REPORT-29-ERR1 | report.sp_RefreshDailySummary (present) | Date > ToDate | 50403; không ghi |
| UT-REPORT-29-ERR2 | report.sp_RefreshDailySummary (present) | ToDate=9999-12-31 | 50403; không ghi |
| UT-REPORT-30-OK | report.sp_RunAllTests (present) | RunBy=QA, phiên test độc lập | 18 ca, đúng BatchId, kết thúc và ghi log thật; lỗi không biến PASS |
| UT-REPORT-30-ERR1 | report.sp_RunAllTests (present) | RunBy rỗng | 50404; không tạo kết quả |
| UT-REPORT-30-ERR2 | report.sp_RunAllTests (present) | RunBy dài 101 ký tự | 50404; không tạo kết quả |

## Ca bổ sung bắt buộc

- Multi-line có discount: fn_RevenueByLocation không nhân Order.TotalAmount theo số chi tiết. Ranking/summary dùng gross, NetRevenue trừ discount; không so net và gross tùy tiện.
- FailureRate: 0/50=0, 1/50=0.02 không đạt <2%, 1/100=0.01 đạt; retry JAM→SUCCESS đếm cả hai; không lần nhả NULL. Dựng nhiều OrderItem thay vì AttemptNo=100 (owner giới hạn 1..3).
- Cold-chain: ngưỡng 2/8 bao gồm biên, 8.01 ngoài; hourly có 30 phút ngoài trong 60 phút →50%; không hourly →NULL; dữ liệu phút -1/61/NULL không được trình bày thành tuân thủ hợp lệ. Raw→hourly chờ #21.
- RANK tie: hai sản phẩm cùng doanh thu cùng địa điểm phải cùng rank; reset fixture/location riêng tránh doanh thu nền làm mất tie.
- Export invalid date/user/location/format không ghi log; CSV quoting, formula injection, PDF rendering và xác nhận SUCCESS/FAILED thuộc lớp ứng dụng, chưa nghiệm thu bằng SELECT.
- Seed small/large độc lập và chạy lại; hiện phải báo BLOCKED #20 trước full seed, không tạo view/bảng thay owner trong test production.
- Upstream faults của procedure không có tham số là ca âm ngữ cảnh, không bịa tham số sai. Chỉ chạy READ_ONLY/DENY trên CSDL test riêng và luôn phục hồi trạng thái trong finally.
