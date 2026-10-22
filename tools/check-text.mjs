import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || '.');
const extensions = new Set(['.html', '.js', '.css', '.sql']);
const skipDirs = new Set(['.git', 'node_modules']);
const allowed = new Set([
  '\u00E1', '\u00E9', '\u00ED', '\u00F3', '\u00FA', '\u00F1', '\u00FC',
  '\u00C1', '\u00C9', '\u00CD', '\u00D3', '\u00DA', '\u00D1', '\u00DC',
  '\u00BF', '\u00A1'
]);
const labels = new Map([
  ['\uFFFD', 'carácter de reemplazo'],
  ['\u2013', 'guion medio'],
  ['\u2014', 'guion largo'],
  ['\u00B7', 'punto medio'],
  ['\u2022', 'viñeta'],
  ['\u2026', 'puntos suspensivos'],
  ['\u00C3', 'mojibake'],
  ['\u00C2', 'mojibake']
]);

function walk(dir, files = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!skipDirs.has(entry.name)) walk(path.join(dir, entry.name), files);
      continue;
    }
    if (extensions.has(path.extname(entry.name))) files.push(path.join(dir, entry.name));
  }
  return files;
}

let problems = 0;
const files = walk(root);

for (const file of files) {
  const content = fs.readFileSync(file, 'utf8');
  const lines = content.split(/\r?\n/);

  lines.forEach((line, lineIndex) => {
    for (let column = 0; column < line.length; column++) {
      const ch = line[column];
      const code = ch.codePointAt(0);
      const isControl = code < 32 && ch !== '\t';
      const isAllowed = code < 128 || allowed.has(ch);

      if (isControl || !isAllowed) {
        problems++;
        const hex = 'U+' + code.toString(16).toUpperCase().padStart(4, '0');
        const label = labels.get(ch) || 'carácter no permitido';
        const relative = path.relative(root, file);
        console.log(`${relative}:${lineIndex + 1}:${column + 1} ${hex} (${label})`);
      }
    }
  });
}

if (problems > 0) {
  console.error(`\n${problems} problema(s) de texto encontrados.`);
  process.exitCode = 1;
} else {
  console.log(`OK: ${files.length} archivos sin caracteres extraños.`);
}
