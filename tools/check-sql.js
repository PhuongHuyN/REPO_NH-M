#!/usr/bin/env node
/*
 * Basic repository SQL validation. The lexer catches unclosed strings,
 * identifiers/comments, and unbalanced parentheses without SQL Server.
 * CI also requires SQLFluff's T-SQL parser for grammar-level parsing.
 */
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const SQL_DIR = path.join(ROOT, 'sql');
const requireParser = process.argv.includes('--require-parser');
const files = [];

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.isFile() && entry.name.toLowerCase().endsWith('.sql')) files.push(full);
  }
}

function checkLexicalStructure(file) {
  const source = fs.readFileSync(file, 'utf8');
  const stack = [];
  let state = 'code';
  let blockDepth = 0;
  let line = 1;
  for (let i = 0; i < source.length; i += 1) {
    const ch = source[i];
    const next = source[i + 1];

    if (ch === '\n') line += 1;
    if (state === 'line-comment') {
      if (ch === '\n') state = 'code';
      continue;
    }
    if (state === 'block-comment') {
      if (ch === '/' && next === '*') { blockDepth += 1; i += 1; continue; }
      if (ch === '*' && next === '/') {
        blockDepth -= 1;
        i += 1;
        if (blockDepth === 0) state = 'code';
      }
      continue;
    }
    if (state === 'string' || state === 'bracket' || state === 'quoted-identifier') {
      const close = state === 'string' ? "'" : state === 'bracket' ? ']' : '"';
      if (ch === close && next === close) { i += 1; continue; }
      if (ch === close) state = 'code';
      continue;
    }

    if (ch === '-' && next === '-') { state = 'line-comment'; i += 1; continue; }
    if (ch === '/' && next === '*') { state = 'block-comment'; blockDepth = 1; i += 1; continue; }
    if (ch === "'") { state = 'string'; continue; }
    if (ch === '[') { state = 'bracket'; continue; }
    if (ch === '"') { state = 'quoted-identifier'; continue; }
    if (ch === '(') stack.push(line);
    if (ch === ')') {
      if (!stack.length) return `unexpected ')' on line ${line}`;
      stack.pop();
    }
  }

  if (state === 'string') return 'unclosed string literal';
  if (state === 'bracket') return 'unclosed bracketed identifier';
  if (state === 'quoted-identifier') return 'unclosed quoted identifier';
  if (state === 'block-comment') return 'unclosed block comment';
  if (stack.length) return `unclosed '(' opened on line ${stack[stack.length - 1]}`;
  if (!source.trim()) return 'empty SQL file';
  return null;
}

if (!fs.existsSync(SQL_DIR)) {
  console.error('SQL directory not found:', SQL_DIR);
  process.exit(1);
}
walk(SQL_DIR);
files.sort();
if (files.length === 0) {
  console.error('No .sql files found under sql/.');
  process.exit(1);
}

const errors = [];
for (const file of files) {
  const issue = checkLexicalStructure(file);
  if (issue) errors.push(`${path.relative(ROOT, file).replace(/\\/g, '/')}: ${issue}`);
}

let parserAvailable = false;
if (errors.length === 0) {
  try {
    execFileSync('sqlfluff', ['--version'], { cwd: ROOT, stdio: 'ignore' });
    parserAvailable = true;
  } catch {
    if (requireParser) errors.push('SQLFluff is required but not installed (install tools/requirements-sql-check.txt).');
  }
}

if (errors.length === 0 && parserAvailable) {
  for (const file of files) {
    try {
      execFileSync('sqlfluff', ['lint', '--dialect', 'tsql', '--rules', 'PRS', file], {
        cwd: ROOT,
        stdio: 'pipe',
        maxBuffer: 8 * 1024 * 1024,
        encoding: 'utf8',
      });
    } catch (error) {
      const output = `${error.stdout || ''}${error.stderr || ''}`.trim();
      errors.push(`${path.relative(ROOT, file).replace(/\\/g, '/')}: SQLFluff T-SQL parse failed${output ? `\n${output}` : ''}`);
    }
  }
}

if (errors.length) {
  errors.forEach((error) => console.error(`✘ ${error}`));
  console.error(`\nSQL validation failed (${errors.length} issue${errors.length === 1 ? '' : 's'}).`);
  process.exit(1);
}

const batches = files.reduce((total, file) => total + (fs.readFileSync(file, 'utf8').match(/^\s*GO\s*$/gim) || []).length, 0);
console.log(`SQL structure check passed: ${files.length} files, ${batches} GO batch separators.`);
if (parserAvailable) console.log('SQLFluff T-SQL parser rule (PRS) passed for every file.');
else console.log('SQLFluff not installed: structural checks only (CI installs and requires SQLFluff).');
