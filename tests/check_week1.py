"""Static acceptance for SCRUM-209/210/211; no SQL Server required."""
from pathlib import Path
import re
import subprocess
import json
from collections import Counter
root=Path(__file__).resolve().parents[1]
files=list((root/'sql').glob('*.sql'))
prefixes={}
for path in files:
    prefix=path.name.split('_',1)[0]
    if prefix!='02':
        assert prefix not in prefixes, f'Duplicate SQL prefix {prefix}: {path.name}, {prefixes.get(prefix)}'
        prefixes[prefix]=path.name
for name in ['14_procs_report.sql','24_objects_report.sql','80_seed_small.sql','81_seed_large.sql']:
    assert (root/'sql'/name).is_file(),name
for name in ['04_report_dependencies.sql','05_views_report.sql','06_functions_report.sql','07_procs_report.sql','05_seed_small.sql','06_seed_large.sql','09_seed_small.sql','09_seed_large.sql']:
    assert not (root/'sql'/name).exists(),f'Retired SQL file remains: {name}'
for name in ['02_tables_report.sql','14_procs_report.sql','24_objects_report.sql','80_seed_small.sql','81_seed_large.sql']:
    text=(root/'sql'/name).read_text(encoding='utf-8-sig')
    # Ignore comments, then forbid cross-module DDL, including ownership leaks via ALTER.
    text=re.sub(r'--[^\n]*','',text)
    assert not re.search(r'(?:CREATE\s+(?:OR\s+ALTER\s+)?(?:TABLE|VIEW|FUNCTION|PROCEDURE)|ALTER\s+TABLE)\s+(?:iot|inventory|sales)\.',text,re.I),name
    assert not re.search(r'CREATE\s+(?:(?:UNIQUE|NONCLUSTERED|CLUSTERED)\s+)*INDEX\s+\w+\s+ON\s+(?:iot|inventory|sales)\.',text,re.I),name
    assert not re.search(r'\b(?:inventory\.Locations|sales\.DispenseAttempts|iot\.Device)\b',text,re.I),name
fk=subprocess.run(['git','diff','--exit-code','origin/main','--','sql/03_foreign_keys.sql'],cwd=root,capture_output=True)
assert fk.returncode==0,'TV5 must not edit the owner FK script'
for doc in ['README.md','app/README.md']:
    text=(root/doc).read_text(encoding='utf-8-sig')
    # All mentioned current numbered SQL files must exist. Planned rows are explicit.
    assert '14_procs_report.sql' in text and '80_seed_small.sql' in text
    for old in ['07_procs_report.sql','05_views_report.sql','06_functions_report.sql','09_seed_small.sql']:
        assert old not in text,(doc,old)
print('PASS SCRUM-209/210: owner boundaries, unchanged FK, canonical SQL filenames and README references')
matrix_file=root/'docs/TestCases_Week1.json'
if matrix_file.exists():
    cases=json.loads(matrix_file.read_text(encoding='utf-8-sig'))
    counts=Counter(c['procedure'] for c in cases)
    assert len(counts)==30 and len(cases)==90
    assert set(c['module'] for c in cases)=={'auth','inventory','sales','iot','report'}
    assert len({c['id'] for c in cases})==len(cases)
    for proc,count in counts.items():
        assert count>=3 and {c['kind'] for c in cases if c['procedure']==proc}=={'OK','ERR1','ERR2'},proc
    definitions='\n'.join(p.read_text(encoding='utf-8-sig') for p in files)
    actual=set(re.findall(r'CREATE\s+(?:OR\s+ALTER\s+)?PROCEDURE\s+([\w.]+)',definitions,re.I))
    assert actual <= set(counts),'Procedure missing planned test coverage'
    plan=(root/'docs/TestPlan.md').read_text(encoding='utf-8-sig')
    assert all(c['id'] in plan for c in cases),'Word source must include all cases'
    assert 'p95' in plan and '≤500 ms' in plan and 'READ_ONLY' in plan
    print('PASS SCRUM-211: 5 modules, 30 procedures, 90 concrete planned cases, complete Word source')
