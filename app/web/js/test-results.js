// Browser module; shared status policy is also exercised by Node tests.
export function testStatus(row) {
  if (row.Source === 'DEMO' || row.Status === 'BLOCKED') return 'BLOCKED';
  if (row.Status === 'FAIL') return 'FAIL';
  return row.Passed === true || row.Passed === 1 ? 'PASS' : 'FAIL';
}

export function summarizeTests(rows) {
  const modules = new Map();
  for (const row of rows) {
    const summary = modules.get(row.Module) || { Module: row.Module, Total: 0, Passed: 0, Failed: 0, Blocked: 0 };
    summary.Total += 1;
    summary[{ PASS: 'Passed', FAIL: 'Failed', BLOCKED: 'Blocked' }[testStatus(row)]] += 1;
    modules.set(row.Module, summary);
  }
  return [...modules.values()];
}

export function resultNotice(summary) {
  const count = (key) => summary.reduce((total, row) => total + Number(row[key] || 0), 0);
  const failed = count('Failed'), blocked = count('Blocked'), total = count('Total');
  if (!total) return { text: 'Chưa có ca kiểm thử được thực thi', kind: 'err' };
  if (failed || blocked) return { text: `${failed} ca lỗi, ${blocked} ca chưa chạy do thiếu điều kiện`, kind: 'err' };
  return { text: `${total} ca kiểm thử đã đạt`, kind: 'ok' };
}
