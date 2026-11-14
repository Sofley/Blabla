const test = require('node:test');
const assert = require('node:assert');
const { spawn } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');
const { classifySource, replyButtons } = require('../server.js');

test('источник: UTM-метка важнее реферера', () => {
  assert.equal(classifySource('instagram', 'https://google.com/', 'site.ru'), 'instagram');
  assert.equal(classifySource('tg', '', 'site.ru'), 'telegram');
  assert.equal(classifySource('YouTube', '', 'site.ru'), 'youtube');
});
test('источник: по рефереру', () => {
  assert.equal(classifySource('', 'https://l.instagram.com/?u=x', 'site.ru'), 'instagram');
  assert.equal(classifySource('', 'https://t.me/luxe', 'site.ru'), 'telegram');
  assert.equal(classifySource('', 'https://www.youtube.com/watch?v=1', 'site.ru'), 'youtube');
  assert.equal(classifySource('', 'https://www.google.ru/', 'site.ru'), 'google');
  assert.equal(classifySource('', 'https://yandex.ru/search', 'site.ru'), 'yandex');
  assert.equal(classifySource('', '', 'site.ru'), 'direct');
  assert.equal(classifySource('', 'https://site.ru/privacy.html', 'site.ru'), 'direct');
  assert.equal(classifySource('', 'https://leatherforum.ru/t/1', 'site.ru'), 'other');
});
test('кнопка «Ответить» в Telegram: ник и телефон', () => {
  assert.equal(replyButtons('@elena_leather').inline_keyboard[0][0].url, 'https://t.me/elena_leather');
  assert.equal(replyButtons('8 (999) 123-45-67').inline_keyboard[0][0].url, 'https://t.me/+79991234567');
  assert.equal(replyButtons('a@b.ru'), undefined);
});

test('HTTP: заявка, антиспам и закрытая админка', async (t) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'lh-'));
  const port = 3900 + Math.floor(Math.random() * 90);
  const srv = spawn(process.execPath, [path.join(__dirname, '..', 'server.js')], {
    env: { ...process.env, PORT: String(port), DATA_DIR: dir, ADMIN_PASSWORD: 'secret', TELEGRAM_BOT_TOKEN: '' },
    stdio: 'ignore',
  });
  t.after(() => srv.kill());
  const base = `http://127.0.0.1:${port}`;
  for (let i = 0; i < 50; i++) { try { await fetch(base + '/healthz'); break; } catch { await new Promise((r) => setTimeout(r, 100)); } }
  const post = (body) => fetch(base + '/api/lead', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

  const good = { name: 'Елена', contact: '@elena_leather', channel: 'Telegram', consent: true, elapsed: 5000, utm_source: 'youtube' };
  let r = await post(good); let j = await r.json();
  assert.equal(r.status, 200); assert.equal(j.id, 1);

  r = await post({ ...good, consent: false }); assert.equal(r.status, 422);
  r = await post({ ...good, website: 'spam.com' }); j = await r.json(); assert.equal(j.id, 0); // ловушка: тихо отброшено
  r = await post({ ...good, elapsed: 300 }); j = await r.json(); assert.equal(j.id, 0);      // слишком быстро — бот

  r = await fetch(base + '/admin'); assert.equal(r.status, 401);
  const auth = { Authorization: 'Basic ' + Buffer.from('admin:wrong').toString('base64') };
  r = await fetch(base + '/admin', { headers: auth }); assert.equal(r.status, 401);
  const ok = { Authorization: 'Basic ' + Buffer.from('admin:secret').toString('base64') };
  r = await fetch(base + '/admin/api/stats?days=7', { headers: ok }); j = await r.json();
  assert.equal(j.totals.leads, 1);
  assert.equal(j.sources.find((s) => s.key === 'youtube').leads, 1);

  r = await fetch(base + '/../server.js'); assert.notEqual(r.status, 200);
  r = await fetch(base + '/%2e%2e/server.js'); assert.notEqual(r.status, 200);
});
