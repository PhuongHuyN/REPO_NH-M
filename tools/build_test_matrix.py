"""Maintain the concrete three-case contract per Week-1 procedure, then render it."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]
# (procedure, valid input, valid oracle, negative input/oracle, second negative input/oracle)
CATALOG=[
('auth.sp_CreateUser','Username=qa_new, Password=QaPass123!, RoleName=Operator, FullName=QA','Tạo đúng 1 user, role đúng; mật khẩu không lưu plain text','Username=ab','50001; không tạo user','Username=admin đã có','50003; không tạo user trùng'),
('auth.sp_Login','Admin hoạt động + mật khẩu đúng; ClientInfo=QA','Success=1, đúng UserId/RoleName; reset failed count, ghi LoginActivity','Mật khẩu sai 1 lần','Success=0, failed count +1, không trả quyền','Sai liên tiếp 5 lần trên fixture riêng','Success=0, tài khoản khóa, lần sau không đăng nhập; không coi là exception 500xx'),
('auth.sp_ChangePassword','UserId=U hoạt động, OldPassword đúng, NewPassword=Different123!','Đổi salt/hash; mật khẩu cũ không đăng nhập được','OldPassword sai','50011; hash giữ nguyên','NewPassword ngắn 7 ký tự','50002; hash giữ nguyên'),
('auth.sp_AssignMachine','UserId=Operator U, MachineId=M có thật, Unassign=0','Một assignment; gọi lại không trùng','UserId=-1','50020; không assignment','UserId=Admin','50021; không giao máy cho Admin'),
('auth.sp_DeactivateUser','UserId=Operator U hoạt động, Activate=0; SESSION_CONTEXT UserId=Admin A','IsActive=0; phiên đăng nhập mới bị từ chối','UserId=-1','50030; không thay user khác','UserId=A, Activate=0, SESSION_CONTEXT UserId=A','50031; không tự vô hiệu hóa'),
('inventory.sp_AddProduct','ProductName=QA_NEW, Price=15000, ShelfLifeHours=24, Category=Trái cây cắt sẵn','Đúng ProductId, ProductName, Price; SKU duy nhất','Price=0','50102; không thêm sản phẩm','ProductName đã tồn tại','50101; không thêm trùng'),
('inventory.sp_UpdateProduct','ProductId=P, tên mới duy nhất, ShelfLifeHours=24, IsActive=1','Đúng cột thay đổi, không sửa giá bằng đường vòng','ProductId=-1','50103; không update','ProductName trùng sản phẩm khác','50101; không update'),
('inventory.sp_UpdatePrice','ProductId=P, NewPrice khác giá cũ và >0, UpdatedBy=A','OldPrice/NewPrice đúng, temporal history thêm phiên bản','ProductId=-1','50103; không history mới','NewPrice bằng giá hiện tại','50104; không update/history'),
('inventory.sp_AssignColumn','ColumnId=C rỗng trên máy được giao, ProductId=P, UpdatedBy=U','ColumnId/ColumnNo đúng alias Slot; gán đúng sản phẩm','ColumnId=-1','50105; không update','Cột còn ít nhất một hộp','50106; không đổi sản phẩm'),
('inventory.sp_AddBatch','ProductId=P hoạt động, Quantity=20, PreparedAt UTC=T, Supplier=QA','ExpiryAt=T+ShelfLifeHours; BatchCode duy nhất','ProductId=-1','50107; không lô mới','Quantity=0','50113; không lô mới'),
('inventory.sp_Restock','MachineId=M được giao, UserId=U, Items TVP có C/B/Qty=2 hợp lệ, Note=QA','Tồn theo lô +2, phiếu/chi tiết/movement đủ, giao dịch atomic','Items TVP rỗng','50111; không đổi tồn/phiếu','Qty làm vượt Capacity (kèm dòng trước hợp lệ)','50117; rollback tất cả dòng, không nạp một phần'),
('inventory.sp_RemoveExpired','MachineId=M; có một lô hết hạn và một lô còn hạn','Chỉ rút lô hết hạn; trả RemovedLines/RemovedQty đúng','MachineId=-1','Không thay tồn, 0 dòng; nếu owner chốt mã lỗi mới thì cập nhật oracle trước chạy','MachineId=M, không có lô hết hạn','0 dòng/hộp, không xóa lô còn hạn (ca âm nghiệp vụ)'),
('sales.sp_CreateOrder','MachineId=M ACTIVE, Items TVP ColumnId=C/Qty=1 còn tồn chưa hết hạn, CustomerId=NULL','PENDING, TotalAmount đúng, FIFO trừ tồn đúng lô, ExpiresAt +5 phút','Items TVP rỗng','50200; không đơn/tồn thay đổi','Qty vượt tồn hợp lệ','50201; toàn bộ rollback'),
('sales.sp_ConfirmPayment','OrderId=O PENDING chưa hết hạn, Method=VIETQR, GatewayTxnId=QA-UNIQUE, Amount đúng','PAID; một payment; callback y hệt lần hai IsDuplicate=1','Amount khác TotalAmount','50208; chưa PAID, không payment mới','O quá hạn 5 phút','50207; không thu tiền thành công'),
('sales.sp_RecordDispense','OrderItemId=I thuộc PAID, Result=SUCCESS, ErrorCode=NULL','Ghi một DispenseEvents; toàn đơn nhả đủ → DISPENSED','Result=UNKNOWN','50211; không event','OrderItemId=-1','50212; không event/hoàn tiền'),
('sales.sp_Refund','OrderId=O PAID chưa nhả, Reason=QA, RefundedBy=A','Đúng phần chưa nhả được hoàn; một Refund; tồn trả đúng','OrderId=-1','50216; không refund','OrderId của đơn PENDING','50217; không refund'),
('sales.sp_ExpirePendingOrders','OrderId=O PENDING quá hạn; hoặc NULL cho batch','EXPIRED, trả tồn đúng; trả số đơn hết hạn','OrderId của đơn PAID','Không đổi trạng thái hoặc tồn (ca âm trạng thái)','OrderId đã EXPIRED','Không trả tồn hai lần; 0 thay đổi'),
('iot.sp_RegisterMachine','Serial=QA-NEW, MachineName=QA, LocationId=L có thật, FirmwareVersion=1.0','Máy ACTIVE + thresholds 2..8; không tạo bản sao inventory','Serial đã tồn tại','50301; không máy/threshold mới','LocationId=-1','50302; không máy mới'),
('iot.sp_IngestTelemetry','Payload JSON array [{machineId:M,temp:4,hum:65,door:0}]','Một telemetry đúng M và dữ liệu, heartbeat UTC cập nhật','Payload=not-json','50310; không telemetry','Payload machineId không tồn tại','50311; không telemetry'),
('iot.sp_AcknowledgeAlert','AlertId=AL mở, UserId=A','AckBy/AckAt đúng, không tự resolve cảnh báo','AlertId=-1','50320; không update','AL đã acknowledge','50321; không ghi đè AckBy'),
('iot.sp_ClearFault','MachineId=M FAULT, UserId=A, Note=QA','ACTIVE, đóng cảnh báo của máy, trả OldStatus/NewStatus','MachineId=-1','50330; không update','M đang ACTIVE','50331; không tạo chuyển trạng thái giả'),
('iot.sp_UpdateThreshold','MachineId=M, MinTemp=2, MaxTemp=8, DoorOpenMaxMinutes=2, ConsecutiveBreaches=3, DegradedMessage=QA','Đúng một threshold và cột trả về','MachineId=-1','50340; không update','MinTemp=8, MaxTemp=2','50341; không update'),
('iot.sp_CheckHeartbeat','Minutes=5; M heartbeat 6 phút trước, M2 heartbeat 1 phút trước','Chỉ M OFFLINE, một cảnh báo mở, gọi lại không trùng','Thực thi bằng Kiosk sau 40_security','229/permission denied, không thay máy; BLOCKED khi chưa có security','CSDL test READ_ONLY với máy cần update','3906; không thay đổi trạng thái; dọn READ_WRITE trong finally'),
('iot.sp_AggregateHourly','Telemetry của giờ đang tổng hợp, nhiệt độ 2 và 8 và vượt ngưỡng','Hourly đúng min/max/avg/count, phút thật 0..60, upsert lặp không tăng','Thực thi bằng Operator sau 40_security','229, không sửa hourly; BLOCKED khi chưa có security','CSDL test READ_ONLY với dữ liệu cần MERGE','3906; không ghi một phần; khôi phục READ_WRITE trong finally'),
('report.sp_DashboardKpi','AsOf=2026-11-03, MachineId=NULL','3 result sets; net doanh thu PAID/DISPENSED, 14 ngày, top 5, máy ACTIVE','MachineId=-1','50401; không trả KPI giả','AsOf=9999-12-31','50401; không tràn ngày'),
('report.sp_RevenueGrowth','Year=2026','12 tháng, QtySold/PrevRevenue đúng; LAG, running sum đúng','Year=1999','50401','Year=9999','50401'),
('report.sp_PeakHours','From=2026-08-06, To=2026-11-03','24 hàng T2..CN; tổng đơn đúng; DATEFIRST 1/7 không đổi','From > To','50401','To=9999-12-31','50401'),
('report.sp_ExportSales','From/To hợp lệ, UserId có thật, LocationId=NULL, FileFormat=CSV','Audit rows PAID/DISPENSED/REFUNDED/DISPENSE_FAILED; Params JSON; log PENDING','From=NULL','50402; không log','UserId=-1','50402; không log'),
('report.sp_RefreshDailySummary','Date=2026-08-06, ToDate=2026-11-03','Gross chi tiết, discount phân bổ, net đúng; lặp không nhân, refund loại summary cũ','Date > ToDate','50403; không ghi','ToDate=9999-12-31','50403; không ghi'),
('report.sp_RunAllTests','RunBy=QA, phiên test độc lập','18 ca, đúng BatchId, kết thúc và ghi log thật; lỗi không biến PASS','RunBy rỗng','50404; không tạo kết quả','RunBy dài 101 ký tự','50404; không tạo kết quả'),
]
def build():
    definitions='\n'.join(p.read_text(encoding='utf-8-sig') for p in (ROOT/'sql').glob('*.sql'))
    exists=set(re.findall(r'CREATE\s+(?:OR\s+ALTER\s+)?PROCEDURE\s+([\w.]+)',definitions,re.I))
    entries=[]
    for index,(proc,good,oracle,bad1,e1,bad2,e2) in enumerate(CATALOG,1):
        module=proc.split('.')[0]
        for kind,inp,expected in [('OK',good,oracle),('ERR1',bad1,e1),('ERR2',bad2,e2)]:
            entries.append({'id':f'UT-{module.upper()}-{index:02d}-{kind}', 'module':module,'procedure':proc,
              'kind':kind,'input':inp,'expected':expected,'definition':'present' if proc in exists else 'planned',
              'execution':'NOT RUN' if proc in exists else 'BLOCKED: procedure chưa có'})
    target=ROOT/'docs/TestCases_Week1.json'
    target.write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    rows=['# Ma trận Unit Test Tuần 1 — SCRUM-211','',
      'Kế hoạch test, **không phải kết quả thực thi**. 30 procedure / 90 ca; 23 procedure có định nghĩa và 7 procedure chờ owner. Dữ liệu ký hiệu U/A/M/L/C/P/B/O/I/AL phải được resolve bằng khóa fixture, không hardcode ID của CSDL khác.',
      '', 'Tiền điều kiện: CSDL test riêng; Admin A, Operator U, Kiosk K; máy M, địa điểm L, ngăn C, sản phẩm P, lô B, đơn O, chi tiết I, alert AL theo từng trạng thái trong Input. Mỗi ca ghi baseline (tồn, tổng tiền, row count), gọi procedure đúng một lần hoặc số lần nêu rõ, đối chiếu Expected bằng SELECT độc lập và ERROR_NUMBER. Dọn fixture bằng rollback khi transaction còn hợp lệ; lỗi XACT_ABORT rollback toàn bộ thì dựng lại fixture cho ca sau.',
      '', 'Nguồn oracle: SQL chủ module + app/api/test/fakeDb.js + tests/tests_inventory.sql + tests/tests_sales.sql. Các case auth/Restock/RemoveExpired là kế hoạch từ hợp đồng mock, chưa có đủ implementation. Chưa nhận xác nhận trực tiếp từ bốn owner: cần Toàn/Huy/Ân/Dũng review Expected trước Sprint 2. Không giả nhận xét hoặc kết quả của thành viên khác.', '']
    for module in ['auth','inventory','sales','iot','report']:
        rows+=['## '+module,'','| ID | Procedure / sẵn sàng | Input / bước gọi | Expected / oracle |','|---|---|---|---|']
        for e in entries:
            if e['module']==module:
                rows.append('| '+' | '.join([e['id'],e['procedure']+' ('+e['definition']+')',e['input'],e['expected']])+' |')
        rows+=['']
    rows+=['## Ca bổ sung bắt buộc','',
      '- Multi-line có discount: fn_RevenueByLocation không nhân Order.TotalAmount theo số chi tiết. Ranking/summary dùng gross, NetRevenue trừ discount; không so net và gross tùy tiện.',
      '- FailureRate: 0/50=0, 1/50=0.02 không đạt <2%, 1/100=0.01 đạt; retry JAM→SUCCESS đếm cả hai; không lần nhả NULL. Dựng nhiều OrderItem thay vì AttemptNo=100 (owner giới hạn 1..3).',
      '- Cold-chain: ngưỡng 2/8 bao gồm biên, 8.01 ngoài; hourly có 30 phút ngoài trong 60 phút →50%; không hourly →NULL; dữ liệu phút -1/61/NULL không được trình bày thành tuân thủ hợp lệ. Raw→hourly chờ #21.',
      '- RANK tie: hai sản phẩm cùng doanh thu cùng địa điểm phải cùng rank; reset fixture/location riêng tránh doanh thu nền làm mất tie.',
      '- Export invalid date/user/location/format không ghi log; CSV quoting, formula injection, PDF rendering và xác nhận SUCCESS/FAILED thuộc lớp ứng dụng, chưa nghiệm thu bằng SELECT.',
      '- Seed small/large độc lập và chạy lại; hiện phải báo BLOCKED #20 trước full seed, không tạo view/bảng thay owner trong test production.',
      '- Upstream faults của procedure không có tham số là ca âm ngữ cảnh, không bịa tham số sai. Chỉ chạy READ_ONLY/DENY trên CSDL test riêng và luôn phục hồi trạng thái trong finally.', '']
    (ROOT/'docs/TestCases_Week1.md').write_text('\n'.join(rows),encoding='utf-8-sig')
    plan=ROOT/'docs/TestPlan.md'
    main=plan.read_text(encoding='utf-8-sig').split('\n## 12. Ma trận unit chi tiết')[0].rstrip()
    matrix='\n'.join(rows[1:]).replace('\n## ','\n### ')
    plan.write_text((main+'\n\n## 12. Ma trận unit chi tiết (tự sinh từ catalog)\n'+matrix).rstrip()+'\n',encoding='utf-8-sig')
    assert len(entries)==90
    assert exists <= {x[0] for x in CATALOG}, f'Unplanned procedures: {exists-{x[0] for x in CATALOG}}'
    print(f'Generated {len(CATALOG)} procedures / {len(entries)} planned unit cases; {len(exists)} definitions present')
    return entries
if __name__=='__main__': build()
