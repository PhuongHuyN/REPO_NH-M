from pathlib import Path
import importlib.util
import re
ROOT=Path(__file__).resolve().parents[1]
def load(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/file)
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module
catalog=load('week2','tools/build_week2_runner.py')
assert len(catalog.CASES)==33
assert {row[0] for row in catalog.CASES}=={'auth','inventory','sales','iot','report'}
sql=(ROOT/'sql/14_procs_report.sql').read_text(encoding='utf-8-sig')
runner=sql.split('CREATE OR ALTER PROCEDURE report.sp_RunAllTests')[1]
assert 'BEGIN TRAN;' in runner and 'ROLLBACK;' in runner and "N'BLOCKED'" in runner
assert 'IIF(@Actual=@Expected' in runner
assert 'Runner-valid' not in runner  # no synthetic always-PASS completion case
assert 'iot.sp_MaintainPartitions' in runner and 'sys.partition_schemes' in runner
generator=load('seed','tools/complete_tv5.py')
for large,name in [(False,'80_seed_small.sql'),(True,'81_seed_large.sql')]:
    text=(ROOT/'sql'/name).read_text(encoding='utf-8-sig')
    assert text==generator.seed(large)
    for proc in ['auth.sp_CreateUser','iot.sp_RegisterMachine','inventory.sp_AddProduct','inventory.sp_AddBatch','inventory.sp_Restock','sales.sp_CreateOrder','sales.sp_ConfirmPayment','sales.sp_RecordDispense']:
        assert re.search(r'EXEC\s+'+re.escape(proc),text),proc
    assert 'INSERT sales.[Order]' not in text and 'INSERT inventory.Product' not in text
    assert 'INSERT auth.[User]' not in text
    assert 'GENERATE_SERIES' in text and 'report.SeedRuns' in text
for path in [ROOT/'sql/02_tables_report.sql',ROOT/'sql/14_procs_report.sql',ROOT/'sql/80_seed_small.sql',ROOT/'sql/81_seed_large.sql']:
    text=re.sub(r'--[^\n]*','',path.read_text(encoding='utf-8-sig'))
    assert not re.search(r'(CREATE\s+(?:OR ALTER\s+)?(?:TABLE|VIEW|PROCEDURE|FUNCTION)|ALTER TABLE)\s+(iot|sales|inventory)\.',text,re.I),path.name
print('PASS SCRUM-224 contracts: 33 honest cases, rollback, real-procedure seeds, no owner schema repair')
