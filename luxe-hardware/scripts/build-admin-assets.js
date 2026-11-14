// Упаковывает файлы панели администратора (admin/*) в модуль lib/admin-assets.mjs,
// чтобы функция Netlify могла отдавать их без чтения с диска. Запускается при каждой сборке.
const fs = require('node:fs');
const path = require('node:path');
const dir = path.join(__dirname, '..', 'admin');
const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8' };
const files = {};
for (const name of fs.readdirSync(dir).sort()) {
  const type = TYPES[path.extname(name)];
  if (type) files[name] = { type, body: fs.readFileSync(path.join(dir, name), 'utf8') };
}
const out = '// Сгенерировано scripts/build-admin-assets.js — не редактировать вручную, правьте admin/*.\n'
  + 'export default ' + JSON.stringify(files, null, 1) + ';\n';
fs.writeFileSync(path.join(__dirname, '..', 'lib', 'admin-assets.mjs'), out);
console.log('admin assets:', Object.keys(files).join(', '));
