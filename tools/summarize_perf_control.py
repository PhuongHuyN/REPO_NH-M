from pathlib import Path
import json,shutil,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
source=Path((ROOT/'.local-test/perf/latest.txt').read_text(encoding='utf-8-sig').strip())
summary=json.loads((source/'summary.json').read_text(encoding='utf-8-sig'))
samples=json.loads((source/'samples.json').read_text(encoding='utf-8-sig'))
out=ROOT/'docs/evidence/week2/perf-control';out.mkdir(parents=True,exist_ok=True)
rows=[]
for query in sorted({r['QueryName'] for r in samples}):
 selected=[r for r in samples if r['QueryName']==query]
 cold=next(r for r in selected if r['Iteration']==0)
 cpu=[];reads=[]
 for name in cold['Plans']:
  doc=ET.parse(source/name)
  if not any(n.tag.endswith('RelOp') for n in doc.iter()):continue
  shutil.copy2(source/name,out/name)
  for n in doc.iter():
   if n.tag.endswith('QueryTimeStats') and 'CpuTime' in n.attrib:cpu.append(int(n.attrib['CpuTime']))
   if n.tag.endswith('RunTimeCountersPerThread') and 'ActualLogicalReads' in n.attrib:reads.append(int(n.attrib['ActualLogicalReads']))
 rows.append({'Query':query,'ColdMs':cold['ElapsedMs'],'WarmMaxMs':max(r['ElapsedMs'] for r in selected if r['Iteration']>0),'CpuMs':sum(cpu) if cpu else None,'LogicalReads':sum(reads) if reads else None,'After':'BLOCKED'})
shutil.copy2(source/'statistics-time-io.txt',out/'statistics-time-io.txt')
(out/'measurements.json').write_text(json.dumps({'acceptance':False,'controlOnly':True,'database':summary['Database'],'rows':rows},indent=2)+'\n',encoding='utf-8')
table='\n'.join('| '+ ' | '.join(str(r[k]) for k in ['Query','ColdMs','WarmMaxMs','CpuMs','LogicalReads','After'])+' |' for r in rows)
(ROOT/'docs/Week2_Performance.md').write_text('''# SCRUM-225 — bằng chứng và giới hạn

Công cụ đã triển khai: tests/70_perf_tests.sql, tests/run-perf.ps1, tests/measure-report-api.ps1.

## Control run thật, không phải nghiệm thu LARGE

Đã thu 5 query × (1 cold +5 warm), 60 actual execution plans và STATISTICS TIME/IO trên SQL Server 2022, CSDL FreshVendTV5_Week2_20261110_170803. Dataset control có 50 đơn/1 hourly, không có 200.000 telemetry. Không dùng số đo này khẳng định SLA hoặc before/after index trên seed lớn.

| Query | Cold ms | Max warm ms | CPU cold ms | Logical reads cold | AFTER |
|---|---:|---:|---:|---:|---|
'''+table+'''

Actual XML .sqlplan và log TIME/IO ở docs/evidence/week2/perf-control. None nghĩa SQL Server không expose trường đó; không bịa số 0. Chưa có ảnh SSMS Execution Plan, chưa có AFTER và chưa chứng minh logical reads giảm.

## Chạy nghiệm thu khi đủ phụ thuộc

1. Chạy seed LARGE qua procedure thật; xác minh 5.000 đơn/200.000 telemetry và seed lần hai giữ nguyên tiền.
2. powershell -NoProfile -File tests/run-perf.ps1 -Database QA_DB -OwnerIndexScript script_index_duoc_owner_duyet.sql
3. Công cụ lưu metadata index trước/sau và SHA256 script; chỉ gán AFTER khi index thực sự thay đổi. Không tự tạo/xóa index module khác. Mở actual .sqlplan bằng SSMS, lưu ảnh Ctrl+M.
4. Đăng nhập Admin thật, truyền token qua biến môi trường process FRESHVEND_QA_ADMIN_TOKEN; chạy tests/measure-report-api.ps1 -Requests 100. Đo KPI/peak/growth; giữ cả mẫu lỗi/timeout; p95 nearest-rank từng route ≤500 ms và error count=0.

Hiện nghiệm thu BLOCKED: auth/Restock/view máy/partition/index owner chưa được bàn giao, seed LARGE chưa chạy được. Không đo API demo rồi ghi PASS. Run-perf -ControlOnly chủ động trả mã khác 0 vì không phải nghiệm thu.
''',encoding='utf-8-sig')
print('Published actual control measurements; acceptance remains BLOCKED')
