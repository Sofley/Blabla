// Собирает статический предпросмотр сайта (без сервера) в указанную папку:
//   node scripts/build-preview.js <папка>
// Товары берутся из demo-products.json, внизу страницы — переключатель «Без товаров / 1 товар / 8 товаров».
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const out = process.argv[2];
if (!out) { console.error('Укажите папку: node scripts/build-preview.js <папка>'); process.exit(1); }
fs.mkdirSync(out, { recursive: true });
const pub = (f) => fs.readFileSync(path.join(root, 'public', f), 'utf8');

// Страница: только содержимое <body> + свои стили и скрипты по относительным путям
const html = pub('index.html');
const title = html.match(/<title>[^<]*<\/title>/)[0];
const fonts = html.match(/<link href="https:\/\/fonts\.googleapis\.com[^>]*>/)[0];
let body = html.slice(html.indexOf('<body>') + 6, html.indexOf('</body>'));
body = body.replace(/href="\/privacy\.html"/g, 'href="privacy.html"');
const page = `${title}
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
${fonts}
<link rel="stylesheet" href="styles.css">
<style>
  .header { top: env(safe-area-inset-top, 0px); }
  .pv { position: fixed; z-index: 70; left: 50%; transform: translateX(-50%);
        bottom: calc(14px + env(safe-area-inset-bottom, 0px));
        display: flex; align-items: center; gap: 4px; padding: 5px; border-radius: 999px;
        background: #22201E; color: #F3EFE8; box-shadow: 0 12px 30px -10px rgba(34,32,30,.5);
        font: 500 12px/1 Inter, system-ui, sans-serif; max-width: calc(100% - 24px); }
  .pv span { padding: 0 8px 0 10px; color: #B3AA9D; white-space: nowrap; }
  .pv button { border: 0; border-radius: 999px; padding: 9px 12px; background: transparent; color: #F3EFE8; font: inherit; cursor: pointer; white-space: nowrap; }
  .pv button[aria-pressed="true"] { background: #F3EFE8; color: #22201E; }
  .pv button:focus-visible { outline: 2px solid #C4AA82; outline-offset: 2px; }
  @media (max-width: 520px) { .pv span { display: none; } }
  .toast { bottom: calc(76px + env(safe-area-inset-bottom, 0px)); }
</style>
${body}
<div class="pv" role="group" aria-label="Состояние каталога в предпросмотре">
  <span>Предпросмотр</span>
  <button type="button" data-n="0">Без товаров</button>
  <button type="button" data-n="1">1 товар</button>
  <button type="button" data-n="8" aria-pressed="true">8 товаров</button>
</div>
<script src="preview.js"></script>
<script src="config.js"></script>
<script src="stories.js"></script>
<script src="app.js"></script>
<script src="telegram.js"></script>
`;
fs.writeFileSync(path.join(out, 'index.html'), page);

const demo = JSON.parse(fs.readFileSync(path.join(root, 'demo-products.json'), 'utf8'));
fs.writeFileSync(path.join(out, 'preview.js'), `// Демо-товары для предпросмотра и переключатель состояний
window.PREVIEW_PRODUCTS = ${JSON.stringify(demo)};
(function () {
  var all = window.PREVIEW_PRODUCTS.slice();
  document.addEventListener('click', function (e) {
    var b = e.target.closest('.pv button'); if (!b || !window.__lhSetProducts) return;
    var n = +b.dataset.n;
    document.querySelectorAll('.pv button').forEach(function (x) { x.setAttribute('aria-pressed', String(x === b)); });
    window.__lhSetProducts(all.slice(0, n));
    var target = document.getElementById(n ? 'catalog' : 'stories');
    if (target) target.scrollIntoView({ behavior: 'smooth' });
  });
})();
`);
for (const f of ['styles.css', 'app.js', 'config.js', 'stories.js', 'telegram.js']) fs.writeFileSync(path.join(out, f), pub(f));
// Страница политики — отдельный документ со ссылкой назад на предпросмотр
fs.writeFileSync(path.join(out, 'privacy.html'), pub('privacy.html').replace('href="/"', 'href="index.html"'));
console.log('preview →', out);
