"""Publish concise, actual SQL benchmark evidence from successful local test logs."""
from pathlib import Path
import re
import sys

if '--historical' not in sys.argv:
    raise SystemExit('Historical 04/11 only; use build_week1_evidence.py for current schema. Pass --historical to rebuild archived measurements.')
root=Path(__file__).resolve().parents[1]
primary=root/'.local-test/tv5-small-to-large'
standalone=root/'.local-test/tv5'

def timings(folder):
    for name in ['verify-large-rerun.sql.log','verify-report.sql.log']:
        evidence=(folder/name).read_text(encoding='utf-16')
        if re.search(r'^Msg\s+\d+',evidence,re.MULTILINE):
            raise SystemExit('SQL failure in '+str(folder/name))
    assert 'PASS: function/view' in (folder/'verify-report.sql.log').read_text(encoding='utf-16')
    log=(folder/'performance.sql.log').read_text(encoding='utf-16')
    if 'Msg 50492' in log: raise SystemExit('Performance failure in '+str(folder))
    rows=[]
    for line in log.splitlines():
        match=re.fullmatch(r'((?:sp_|fn_|vw_)\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*',line)
        if match: rows.append(match.groups())
    assert len(rows)==11, f'Missing benchmark rows: {len(rows)}'
    return rows

def benchmark_table(folder):
    rows=timings(folder)
    text='| Đối tượng | Cold | Lượt 1 | Lượt 2 | Lượt 3 | Lượt 4 | Lượt 5 | Max warm |\n|---|---:|---:|---:|---:|---:|---:|---:|\n'
    text+=''.join('| '+' | '.join(row)+' |\n' for row in rows)
    return text

db=(primary/'database.txt').read_text(encoding='utf-8-sig').strip()
body=f'''# TestReport — kết quả thực thi TV5

Ngày kiểm tra: 04/11/2026. Môi trường: Windows, SQL Server Express 2022 16.0.1000.6, compatibility 160, Vietnamese_CI_AS; CPU Intel Core i5-8250U 1.60 GHz, 8 logical processors. Chạy một client sqlcmd cục bộ, không có tải cạnh tranh chủ động. CSDL kiểm thử được giữ lại, không sửa CSDL ứng dụng.

## Kết quả nghiệm thu SQL

Lệnh: `powershell -NoProfile -File tests/run-tv5.ps1`.
CSDL: `{db}`. Log gốc: `.local-test/tv5-small-to-large/` (không commit).

| Nhóm kiểm tra | Kết quả |
|---|---|
| Tạo cấu trúc từ schema repo và chạy lại toàn bộ object | PASS |
| Small: 3 địa điểm, 5 máy, 10 sản phẩm, 50 đơn, 500 telemetry | PASS |
| Small chạy hai lần | PASS, không trùng và không tăng revenue |
| Small→large: tổng 20 máy, 15 sản phẩm, 5.000 đơn, 200.000 telemetry | PASS |
| Large chạy hai lần | PASS, số lượng và tổng tiền giữ nguyên |
| Chi tiết, slot, product, payment, thời gian 90 ngày và giờ cao điểm | PASS |
| 7 procedure × 1 ca đúng + 2 ca sai | 21/21 PASS |
| Revenue TVF đủ/rỗng/đảo khoảng | PASS |
| Failure rate, máy lạ/không lần nhả, đúng 2% và dưới 2% | PASS |
| Ranking giảm dần, tổng tỷ trọng và đồng hạng | PASS |
| Cold chain 2°C, 8°C, 8.001°C, thời lượng không đều | PASS: 120/240 giây = 50% |
| JSON lỗi, thiếu duration, không dữ liệu | PASS: không tạo coverage giả |
| paid→refunded→refresh | PASS: xóa summary cũ |
| SQL client đối chiếu KPI, tăng trưởng, DATEFIRST 1/7, xuất dòng và log JSON/PDF PENDING | PASS |

Các lỗi chạy thật phát hiện trong quá trình sửa đã được xử lý: RowCount là từ khóa cần bracket, dependency bảng/cột cũ, seed thiếu chi tiết, telemetry/summary nhân đôi khi chạy lại, tổng KPI bị nhân do cross join, thiếu index Payment.OrderId, phân tích lại JSON làm báo cáo chậm. Không sử dụng kết quả PASS seed hoặc số đo cũ để nghiệm thu.

## Hiệu năng thực tế (ms)

Một lượt khởi động/đo đầu và năm lượt warm. Dataset large 5.000 đơn, 200.000 raw telemetry và toàn bộ hourly tương ứng. Tiêu chí nghiêm ngặt: mỗi lượt warm của yêu cầu nghiệp vụ <500 ms. `sp_RefreshTelemetryHourly` đo cập nhật một ngày UTC như job định kỳ; backfill 90 ngày nằm trong thời gian seed. `sp_RefreshDailySummary` đo 90 ngày. `sp_ExportSales` đo 30 ngày và trả dòng thật.

{benchmark_table(primary)}
`sp_RunAllTests` là bộ điều phối chạy toàn suite, chỉ báo thời gian tham khảo; không áp ngân sách một truy vấn cho tổng suite. Các số trên là elapsed phía SQL, không bao gồm tải CSV/PDF qua HTTP. Không khẳng định SLA cho tải cạnh tranh hoặc máy khác.

## Kiểm thử ứng dụng và tài liệu

`npm test --prefix app`: 16/16 PASS; kiểm tra đồng bộ 56 route, 59 lời gọi và 30 biến môi trường PASS. Đây là test API với fake DB, được tách biệt với bằng chứng SQL thực ở trên.

`python tools/build_testplan_docx.py`: tạo TestPlan.docx và xác thực cấu trúc ZIP/XML, chứa đầy đủ nội dung TestPlan.md. Chưa kiểm tra trình bày bằng Microsoft Word trên giao diện.

## Phạm vi còn phụ thuộc nhóm

- Các procedure nghiệp vụ auth/inventory/sales/iot chưa có định nghĩa trong repo: ma trận khung đã có, kiểm thử SQL nghiệp vụ các module này BLOCKED đến khi chủ module cung cấp.
- Đăng nhập, phân quyền DB thực, luồng mua hàng thực xuyên TV1–TV4, tạo/mở file PDF và xác nhận export SUCCESS/FAILED: chưa nghiệm thu end-to-end trên DB thật; thuộc các ca INT-04–06 của TestPlan.
- Cần owner IoT đưa `report.sp_RefreshTelemetryHourly` vào lịch sau ingest; seed tự refresh. View hiển thị toàn lịch sử hourly đã tổng hợp.
- PR trên tv5-report cần ít nhất một bạn review; chưa có review của người khác trong phiên làm việc này.

Không dùng các phụ thuộc này để đánh dấu PASS toàn hệ thống. SCRUM 34 là User Story và khung Test Plan, không phải triển khai tính năng PDF ứng dụng.
'''
if '--standalone' in sys.argv:
    db2=(standalone/'database.txt').read_text(encoding='utf-8-sig').strip()
    body+=f'''\n## Seed lớn độc lập\n\nLệnh: `powershell -NoProfile -File tests/run-tv5.ps1 -LargeOnly`.\nCSDL sạch: `{db2}`. Không chạy seed nhỏ trước. Tạo/rerun object, large/rerun seed, kiểm tra dữ liệu, 21 ca procedure, oracle client và hiệu năng đều PASS. Log gốc `.local-test/tv5/`.\n\n{benchmark_table(standalone)}'''
(root/'docs/TestReport.md').write_text('> HISTORICAL 04/11: see Week1_Anh_Validation.md for current schema.\n\n'+body,encoding='utf-8-sig')
print('Wrote docs/TestReport.md from actual SQL logs')
