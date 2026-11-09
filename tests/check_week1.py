"""Static acceptance for SCRUM-209/210/211; no SQL Server required."""
from pathlib import Path
import re
import subprocess
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
