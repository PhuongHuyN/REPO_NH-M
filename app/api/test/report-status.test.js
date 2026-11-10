const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFile } = require('node:fs/promises');
const path = require('node:path');

test('TV5: blocked SQL prerequisites and demo data cannot announce all PASS', async () => {
  const source = await readFile(path.join(__dirname, '../../web/js/test-results.js'), 'utf8');
  const { testStatus, summarizeTests, resultNotice } = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));
  const rows = [
    { Module: 'auth', Passed: false, Status: 'BLOCKED' },
    { Module: 'iot', Passed: true, Status: 'PASS', Source: 'DEMO' },
    { Module: 'report', Passed: true, Status: 'PASS' },
    { Module: 'sales', Passed: false, Status: 'FAIL' },
  ];
  assert.equal(testStatus(rows[1]), 'BLOCKED');
  const result = summarizeTests(rows);
  assert.equal(result.reduce((n, x) => n + x.Blocked, 0), 2);
  assert.equal(result.reduce((n, x) => n + x.Passed, 0), 1);
  assert.equal(resultNotice(result).kind, 'err');
  assert.equal(resultNotice(summarizeTests([rows[2]])).kind, 'ok');
  assert.equal(resultNotice([]).kind, 'err');
});
