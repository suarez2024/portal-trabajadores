import fs from 'node:fs';
import path from 'node:path';

function parseProperties(text) {
  const result = {};
  const lines = String(text || '').replace(/^\uFEFF/, '').split(/\r?\n/);
  let buffer = '';
  for (const rawLine of lines) {
    const line = buffer + rawLine;
    buffer = '';
    if (/\\$/.test(line) && !/\\\\$/.test(line)) {
      buffer = line.slice(0, -1);
      continue;
    }
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#') || trimmed.startsWith('!')) continue;
    let index = -1;
    for (let i = 0; i < line.length; i += 1) {
      if (line[i] === '\\') { i += 1; continue; }
      if (line[i] === '=' || line[i] === ':') { index = i; break; }
    }
    if (index === -1) continue;
    const key = line.slice(0, index).trim();
    if (!key) continue;
    result[key] = true;
  }
  return result;
}

const root = process.argv[2] || '.';
const en = parseProperties(fs.readFileSync(path.join(root, 'i18n/messages_en.properties'), 'utf8'));
const es = parseProperties(fs.readFileSync(path.join(root, 'i18n/messages_es.properties'), 'utf8'));

const enKeys = new Set(Object.keys(en));
const esKeys = new Set(Object.keys(es));
const missingEs = [...enKeys].filter(k => !esKeys.has(k));
const missingEn = [...esKeys].filter(k => !enKeys.has(k));

let problems = 0;
function walk(dir, files = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (entry.name === '.git' || entry.name === 'node_modules') continue;
      walk(path.join(dir, entry.name), files);
      continue;
    }
    if (entry.name.endsWith('.html') || entry.name.endsWith('.js')) files.push(path.join(dir, entry.name));
  }
  return files;
}

const files = walk(root);
const used = new Set();
const attr = /data-i18n(?:-placeholder|-title|-aria)?=["']([^"']+)["']/g;
for (const file of files) {
  if (file.includes('messages_')) continue;
  const content = fs.readFileSync(file, 'utf8');
  for (const match of content.matchAll(attr)) {
    used.add(match[1]);
  }
}

const missingKeys = [...used].filter(k => !enKeys.has(k));
for (const k of missingKeys) { console.log(`MISSING_KEY ${k}`); problems++; }
for (const k of missingEs) { console.log(`MISSING_ES ${k}`); problems++; }
for (const k of missingEn) { console.log(`MISSING_EN ${k}`); problems++; }

if (problems > 0) { console.error(`\n${problems} problema(s) i18n.`); process.exitCode = 1; }
else { console.log('OK: i18n keys complete.'); }
