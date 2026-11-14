// Marvan на бесплатном хостинге Netlify.
// Тот же функционал, что у server.js, но вместо диска — хранилище Netlify Blobs.
// Логика общая: ../../lib/core.js
import { getStore } from '@netlify/blobs';
import crypto from 'node:crypto';
import core from '../../lib/core.js';
import demoProducts from '../../demo-products.json' with { type: 'json' };
import ADMIN_FILES from '../../lib/admin-assets.mjs';

const env = (k, d = '') => Netlify.env.get(k) || d;
const store = (name) => getStore({ name, consistency: 'strong' });

const json = (status, obj, headers = {}) => new Response(status === 204 ? null : JSON.stringify(obj), {
  status, headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...headers },
});
async function body(req, limit) {
  const text = await req.text();
  if (text.length > limit) throw Object.assign(new Error('too large'), { status: 413 });
  try { return JSON.parse(text || '{}'); } catch { throw Object.assign(new Error('bad json'), { status: 400 }); }
}
const ipHash = (ctx) => crypto.createHash('sha256').update(env('IP_SALT', ctx.site?.id || 'salt') + (ctx.ip || '')).digest('hex').slice(0, 16);

// ---------- Хранилище ----------
// События храним прямо в ключах: ev/<день>/<время>-<случай>.<данные> — так статистика читается
// одним списком ключей на день, без тысяч отдельных запросов. Каждое событие — отдельный ключ, без гонок.
const b64 = (s) => Buffer.from(s).toString('base64url');
const unb64 = (s) => Buffer.from(s, 'base64url').toString('utf8');
async function saveEvent(ev) {
  const short = { ...ev };
  let data = b64(JSON.stringify(short));
  for (const drop of ['path', 'refHost', 'lang', 'label', 'campaign']) {
    if (data.length <= 520) break;
    delete short[drop]; data = b64(JSON.stringify(short));
  }
  if (data.length > 520) return;
  const key = `ev/${core.dayKey(ev.t)}/${ev.t}-${crypto.randomBytes(3).toString('hex')}.${data}`;
  await store('events').set(key, '1');
}
async function loadEvents(days) {
  const now = Date.now();
  const dayList = Array.from({ length: days + 1 }, (_, i) => core.dayKey(now - i * core.DAY));
  const s = store('events');
  const lists = await Promise.all(dayList.map((d) => s.list({ prefix: `ev/${d}/` })));
  const out = [];
  for (const { blobs } of lists) for (const { key } of blobs) {
    try { out.push(JSON.parse(unb64(key.slice(key.indexOf('.') + 1)))); } catch { /* битый ключ */ }
  }
  return out;
}
async function loadLeads() {
  const s = store('leads');
  const { blobs } = await s.list();
  const all = await Promise.all(blobs.map((b) => s.get(b.key, { type: 'json' })));
  return all.filter(Boolean);
}
async function loadProducts() { return (await store('site').get('products', { type: 'json' })) || []; }
const saveProducts = (list) => store('site').setJSON('products', list);
async function removeUnusedPhoto(products, photo) {
  if (!photo || products.some((p) => p.photo === photo)) return;
  await store('uploads').delete(photo.replace('/uploads/', ''));
}

// ---------- Админ-доступ ----------
function isAdmin(req) {
  const pass = env('ADMIN_PASSWORD');
  if (!pass) return false;
  const h = req.headers.get('authorization') || '';
  if (!h.startsWith('Basic ')) return false;
  const [u, ...rest] = Buffer.from(h.slice(6), 'base64').toString('utf8').split(':');
  const eq = (a, b) => crypto.timingSafeEqual(crypto.createHash('sha256').update(a).digest(), crypto.createHash('sha256').update(b).digest());
  const okUser = eq(u, env('ADMIN_USER', 'admin')), okPass = eq(rest.join(':'), pass);
  return okUser && okPass;
}
const askLogin = () => new Response('Требуется авторизация', {
  status: 401, headers: { 'WWW-Authenticate': 'Basic realm="Marvan admin", charset="UTF-8"', 'Content-Type': 'text/plain; charset=utf-8' },
});

// ---------- Обработчики ----------
async function track(req, ctx) {
  const ua = req.headers.get('user-agent') || '';
  if (core.BOT_UA.test(ua)) return json(204);
  const ev = core.makeEvent(await body(req, 4096), ua, new URL(req.url).hostname, ipHash(ctx));
  ctx.waitUntil(saveEvent(ev));
  return json(204);
}

async function lead(req, ctx) {
  const v = core.validateLead(await body(req, 16_384), new URL(req.url).hostname, ipHash(ctx));
  if (v.spam) return json(200, { ok: true, id: 0 });
  if (v.error) return json(422, { ok: false, error: v.error });
  const l = { ...v.lead, id: Number(String(v.lead.t).slice(-6)) };
  const r = await core.tg(env('TELEGRAM_BOT_TOKEN'), 'sendMessage', {
    chat_id: env('TELEGRAM_CHAT_ID'), text: core.leadMessage(l), parse_mode: 'HTML',
    disable_web_page_preview: true, reply_markup: core.replyButtons(l.contact),
  });
  l.delivered = !!r.ok;
  if (!r.ok) console.warn('Telegram не доставил заявку:', r.description);
  await store('leads').setJSON(`${l.t}-${crypto.randomBytes(3).toString('hex')}`, l);
  return json(200, { ok: true, id: l.id });
}

async function telegramWebhook(req) {
  if (req.headers.get('x-telegram-bot-api-secret-token') !== env('TELEGRAM_WEBHOOK_SECRET')) return new Response(null, { status: 403 });
  const u = await body(req, 65_536).catch(() => ({}));
  const msg = u.message; if (!msg?.text) return new Response('ok');
  const send = (text) => core.tg(env('TELEGRAM_BOT_TOKEN'), 'sendMessage', { chat_id: msg.chat.id, text, parse_mode: 'HTML' });
  if (String(msg.chat.id) !== String(env('TELEGRAM_CHAT_ID'))) await send(core.BOT_STRANGER);
  else {
    const [cmd, arg] = msg.text.trim().split(/\s+/);
    if (/^\/stats/.test(cmd)) {
      const d = Math.min(Math.max(parseInt(arg, 10) || 7, 1), 90);
      await send(core.statsMessage(await loadEvents(d), await loadLeads(), d));
    } else if (/^\/leads/.test(cmd)) await send(core.leadsListMessage(await loadLeads()));
    else await send(core.BOT_HELP);
  }
  return new Response('ok');
}

async function adminApi(req, p, url) {
  if (p === '/admin/api/stats') {
    const d = Math.min(Math.max(parseInt(url.searchParams.get('days'), 10) || 30, 1), 90);
    const [events, leads] = await Promise.all([loadEvents(d), loadLeads()]);
    return json(200, core.computeStats(events, leads, d));
  }
  if (p === '/admin/api/leads.csv') {
    const leads = (await loadLeads()).sort((a, b) => a.t - b.t);
    return new Response(core.leadsCsv(leads), { headers: { 'Content-Type': 'text/csv; charset=utf-8', 'Content-Disposition': 'attachment; filename="leads.csv"', 'Cache-Control': 'no-store' } });
  }
  if (p === '/admin/api/products' && req.method === 'GET') return json(200, await loadProducts());
  if (p === '/admin/api/products' && req.method === 'POST') {
    const products = await loadProducts();
    const r = core.upsertProduct(products, await body(req, 32_768));
    if (r.errors) return json(422, { ok: false, errors: r.errors });
    await saveProducts(r.products); await removeUnusedPhoto(r.products, r.oldPhoto);
    return json(200, { ok: true, product: r.product });
  }
  const del = p.match(/^\/admin\/api\/products\/([A-Z0-9-]+)$/);
  if (del && req.method === 'DELETE') {
    const products = await loadProducts();
    const gone = products.find((x) => x.id === del[1]);
    if (!gone) return json(404, { ok: false });
    const rest = products.filter((x) => x !== gone);
    await saveProducts(rest); await removeUnusedPhoto(rest, gone.photo);
    return json(200, { ok: true });
  }
  if (p === '/admin/api/products/import-demo' && req.method === 'POST') {
    const products = await loadProducts();
    let added = 0;
    for (const d of demoProducts) if (!products.some((x) => x.id === d.id)) { products.push({ ...d, createdAt: Date.now() + added }); added++; }
    await saveProducts(products);
    return json(200, { ok: true, added });
  }
  if (p === '/admin/api/upload' && req.method === 'POST') {
    const img = core.parseImage((await body(req, 7_000_000)).data);
    if (img.error) return json(img.status, { ok: false, error: img.error });
    const name = crypto.randomBytes(12).toString('hex') + '.' + img.ext;
    await store('uploads').set(name, new Blob([img.buf], { type: img.type }), { metadata: { type: img.type } });
    return json(200, { ok: true, url: '/uploads/' + name });
  }
  return json(404, { ok: false });
}

function adminPage(p) {
  const file = p === '/admin' || p === '/admin/' ? 'index.html' : p.slice('/admin/'.length);
  const f = ADMIN_FILES[file];
  if (!f) return new Response('Не найдено', { status: 404 });
  return new Response(f.body, { headers: { 'Content-Type': f.type, 'Cache-Control': 'no-store', 'X-Robots-Tag': 'noindex', 'Content-Security-Policy': core.CSP } });
}

async function upload(p) {
  const name = p.slice('/uploads/'.length);
  if (!/^[a-f0-9]{24}\.(jpg|png|webp)$/.test(name)) return new Response('Не найдено', { status: 404 });
  const entry = await store('uploads').getWithMetadata(name, { type: 'arrayBuffer' });
  if (entry === null) return new Response('Не найдено', { status: 404 });
  return new Response(entry.data, { headers: { 'Content-Type': entry.metadata?.type || 'image/jpeg', 'Cache-Control': 'public, max-age=31536000, immutable' } });
}

export default async (req, ctx) => {
  const url = new URL(req.url);
  const p = url.pathname;
  try {
    if (req.method === 'POST' && p === '/api/track') return await track(req, ctx);
    if (req.method === 'POST' && p === '/api/lead') return await lead(req, ctx);
    if (req.method === 'POST' && env('TELEGRAM_WEBHOOK_SECRET') && p === '/api/telegram/' + env('TELEGRAM_WEBHOOK_SECRET')) return await telegramWebhook(req);
    if (req.method === 'GET' && p === '/api/products') return json(200, core.publicProducts(await loadProducts()), { 'Cache-Control': 'no-cache' });
    if (req.method === 'GET' && p === '/healthz') return json(200, { ok: true });
    if (req.method === 'GET' && p.startsWith('/uploads/')) return await upload(p);
    if (p === '/admin' || p.startsWith('/admin/')) {
      if (!env('ADMIN_PASSWORD')) return new Response('Панель отключена: задайте ADMIN_PASSWORD в настройках Netlify', { status: 503 });
      if (!isAdmin(req)) return askLogin();
      return p.startsWith('/admin/api/') ? await adminApi(req, p, url) : adminPage(p);
    }
    return json(404, { ok: false });
  } catch (e) {
    if (!e.status) console.error(e);
    return json(e.status || 500, { ok: false, error: e.status ? 'Некорректный запрос' : 'Ошибка сервера' });
  }
};

export const config = {
  path: ['/api/*', '/admin', '/admin/*', '/uploads/*', '/healthz'],
};
