// Marvan — сервер сайта-визитки для своего VPS.
// Без внешних зависимостей: нужен только Node.js 20.12+ (рекомендуется 22).
// Для бесплатного хостинга Netlify используется netlify/functions/site.mjs — логика общая (lib/core.js).
//
// Что делает:
//   • раздаёт сайт из ./public;
//   • /api/lead     — принимает заявку, сохраняет её и пересылает продавцу в Telegram;
//   • /api/track    — принимает анонимные события визитов (источник, устройство, клики);
//   • /api/products — товары для сайта;
//   • /admin        — закрытая паролем панель статистики и управления товарами;
//   • /api/telegram/<секрет> — webhook бота: команды /stats и /leads прямо в Telegram.

'use strict';

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const core = require('./lib/core');

try { process.loadEnvFile(path.join(__dirname, '.env')); } catch { /* .env не обязателен */ }

const CFG = {
  port: Number(process.env.PORT) || 3000,
  adminUser: process.env.ADMIN_USER || 'admin',
  adminPassword: process.env.ADMIN_PASSWORD || '',
  tgToken: process.env.TELEGRAM_BOT_TOKEN || '',
  tgChatId: process.env.TELEGRAM_CHAT_ID || '',
  tgWebhookSecret: process.env.TELEGRAM_WEBHOOK_SECRET || '',
  ipSalt: process.env.IP_SALT || crypto.randomBytes(16).toString('hex'),
  dataDir: process.env.DATA_DIR || path.join(__dirname, 'data'),
  trustProxy: process.env.TRUST_PROXY === '1',
};

const PUBLIC_DIR = path.join(__dirname, 'public');
const ADMIN_DIR = path.join(__dirname, 'admin');
fs.mkdirSync(CFG.dataDir, { recursive: true });
const EVENTS_FILE = path.join(CFG.dataDir, 'events.jsonl');
const LEADS_FILE = path.join(CFG.dataDir, 'leads.jsonl');
const PRODUCTS_FILE = path.join(CFG.dataDir, 'products.json');
const UPLOADS_DIR = path.join(CFG.dataDir, 'uploads');
const DEMO_FILE = path.join(__dirname, 'demo-products.json');
fs.mkdirSync(UPLOADS_DIR, { recursive: true });

// ---------- Хранилище: JSON Lines + память ----------
function loadJsonl(file) {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8').split('\n').filter(Boolean).flatMap((line) => {
    try { return [JSON.parse(line)]; } catch { return []; }
  });
}
const events = loadJsonl(EVENTS_FILE);
const leads = loadJsonl(LEADS_FILE);
function append(file, list, item) {
  list.push(item);
  fs.appendFile(file, JSON.stringify(item) + '\n', (err) => err && console.error('write error', err));
}

let products = [];
try { products = JSON.parse(fs.readFileSync(PRODUCTS_FILE, 'utf8')); } catch { products = []; }
function saveProducts() {
  const tmp = PRODUCTS_FILE + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(products, null, 2));
  fs.renameSync(tmp, PRODUCTS_FILE); // атомарная запись — файл не побьётся при сбое
}
function removeUnusedPhoto(photo) {
  if (!photo || products.some((p) => p.photo === photo)) return;
  fs.unlink(path.join(UPLOADS_DIR, path.basename(photo)), () => {});
}

// ---------- Утилиты HTTP ----------
const MIME = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.webp': 'image/webp', '.avif': 'image/avif', '.ico': 'image/x-icon', '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8', '.woff2': 'font/woff2',
};
function securityHeaders(res) {
  res.setHeader('Content-Security-Policy', core.CSP);
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
}
function sendJson(res, status, obj) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(obj));
}
function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    let size = 0; const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > limit) { reject(Object.assign(new Error('too large'), { status: 413 })); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => {
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')); }
      catch { reject(Object.assign(new Error('bad json'), { status: 400 })); }
    });
    req.on('error', reject);
  });
}
function clientIp(req) {
  if (CFG.trustProxy) {
    const xf = req.headers['x-forwarded-for'];
    if (xf) return String(xf).split(',')[0].trim();
  }
  return req.socket.remoteAddress || '';
}
// IP — персональные данные, поэтому храним только солёный хэш (для подсчёта уникальных и антиспама).
const ipHash = (ip) => crypto.createHash('sha256').update(CFG.ipSalt + ip).digest('hex').slice(0, 16);
const hostOf = (req) => String(req.headers.host || '').split(':')[0];

// Простой rate-limit в памяти
const buckets = new Map();
function rateLimited(key, max, windowMs) {
  const now = Date.now();
  const b = (buckets.get(key) || []).filter((t) => now - t < windowMs);
  b.push(now); buckets.set(key, b);
  return b.length > max;
}
setInterval(() => { const now = Date.now(); for (const [k, v] of buckets) if (!v.some((t) => now - t < 3_600_000)) buckets.delete(k); }, 600_000).unref();

function serveFile(res, baseDir, urlPath, extraHeaders = {}) {
  let rel = decodeURIComponent(urlPath.split('?')[0]);
  if (rel.endsWith('/')) rel += 'index.html';
  const file = path.normalize(path.join(baseDir, rel));
  if (!file.startsWith(baseDir + path.sep)) { res.writeHead(403); res.end(); return; }
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }); res.end('Не найдено'); return;
    }
    const ext = path.extname(file).toLowerCase();
    res.writeHead(200, {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      'Cache-Control': ext === '.html' ? 'no-cache' : 'public, max-age=86400',
      ...extraHeaders,
    });
    fs.createReadStream(file).pipe(res);
  });
}

// ---------- Админ-доступ ----------
function checkAdmin(req) {
  if (!CFG.adminPassword) return false;
  const h = req.headers.authorization || '';
  if (!h.startsWith('Basic ')) return false;
  const [u, ...rest] = Buffer.from(h.slice(6), 'base64').toString('utf8').split(':');
  const eq = (a, b) => crypto.timingSafeEqual(crypto.createHash('sha256').update(a).digest(), crypto.createHash('sha256').update(b).digest());
  const okUser = eq(u, CFG.adminUser), okPass = eq(rest.join(':'), CFG.adminPassword);
  return okUser && okPass;
}
function requireAdmin(req, res) {
  if (checkAdmin(req)) return true;
  if (!CFG.adminPassword) {
    res.writeHead(503, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Панель отключена: задайте ADMIN_PASSWORD в .env');
    return false;
  }
  if (rateLimited('admin:' + ipHash(clientIp(req)), 20, 600_000)) { res.writeHead(429); res.end(); return false; }
  res.writeHead(401, { 'WWW-Authenticate': 'Basic realm="Marvan admin", charset="UTF-8"' });
  res.end('Требуется авторизация');
  return false;
}

// ---------- Обработчики API ----------
async function handleTrack(req, res) {
  const ua = String(req.headers['user-agent'] || '');
  if (core.BOT_UA.test(ua)) return sendJson(res, 204, {});
  const ip = ipHash(clientIp(req));
  if (rateLimited('track:' + ip, 120, 60_000)) return sendJson(res, 429, { ok: false });
  const b = await readBody(req, 4096);
  append(EVENTS_FILE, events, core.makeEvent(b, ua, hostOf(req), ip));
  sendJson(res, 204, {});
}

async function handleLead(req, res) {
  const ip = ipHash(clientIp(req));
  if (rateLimited('lead:' + ip, 5, 600_000)) return sendJson(res, 429, { ok: false, error: 'Слишком много заявок. Попробуйте через 10 минут или напишите нам в Telegram.' });
  const b = await readBody(req, 16_384);
  const v = core.validateLead(b, hostOf(req), ip);
  if (v.spam) return sendJson(res, 200, { ok: true, id: 0 });
  if (v.error) return sendJson(res, 422, { ok: false, error: v.error });
  const lead = { ...v.lead, id: (leads.at(-1)?.id || 0) + 1 };
  const r = await core.tg(CFG.tgToken, 'sendMessage', {
    chat_id: CFG.tgChatId, text: core.leadMessage(lead), parse_mode: 'HTML',
    disable_web_page_preview: true, reply_markup: core.replyButtons(lead.contact),
  });
  lead.delivered = !!r.ok;
  if (!r.ok) console.warn('Telegram не доставил заявку:', r.description);
  append(LEADS_FILE, leads, lead);
  sendJson(res, 200, { ok: true, id: lead.id });
}

async function handleTelegramWebhook(req, res) {
  if (req.headers['x-telegram-bot-api-secret-token'] !== CFG.tgWebhookSecret) { res.writeHead(403); res.end(); return; }
  let u; try { u = await readBody(req, 65_536); } catch { res.writeHead(200); res.end(); return; }
  res.writeHead(200); res.end();
  const msg = u.message; if (!msg?.text) return;
  const send = (text) => core.tg(CFG.tgToken, 'sendMessage', { chat_id: msg.chat.id, text, parse_mode: 'HTML' });
  // Отвечаем только в чат администратора — посторонние не увидят статистику.
  if (String(msg.chat.id) !== String(CFG.tgChatId)) return send(core.BOT_STRANGER);
  const [cmd, arg] = msg.text.trim().split(/\s+/);
  if (/^\/stats/.test(cmd)) return send(core.statsMessage(events, leads, Math.min(Math.max(parseInt(arg, 10) || 7, 1), 365)));
  if (/^\/leads/.test(cmd)) return send(core.leadsListMessage(leads));
  return send(core.BOT_HELP);
}

async function handleProductsAdmin(req, res, p) {
  if (p === '/admin/api/products' && req.method === 'GET') return sendJson(res, 200, products);
  if (p === '/admin/api/products' && req.method === 'POST') {
    const r = core.upsertProduct(products, await readBody(req, 32_768));
    if (r.errors) return sendJson(res, 422, { ok: false, errors: r.errors });
    products = r.products; saveProducts(); removeUnusedPhoto(r.oldPhoto);
    return sendJson(res, 200, { ok: true, product: r.product });
  }
  const del = p.match(/^\/admin\/api\/products\/([A-Z0-9-]+)$/);
  if (del && req.method === 'DELETE') {
    const i = products.findIndex((x) => x.id === del[1]);
    if (i === -1) return sendJson(res, 404, { ok: false });
    const [gone] = products.splice(i, 1); saveProducts(); removeUnusedPhoto(gone.photo);
    return sendJson(res, 200, { ok: true });
  }
  if (p === '/admin/api/products/import-demo' && req.method === 'POST') {
    const demo = JSON.parse(fs.readFileSync(DEMO_FILE, 'utf8'));
    let added = 0;
    for (const d of demo) if (!products.some((x) => x.id === d.id)) { products.push({ ...d, createdAt: Date.now() + added }); added++; }
    saveProducts();
    return sendJson(res, 200, { ok: true, added });
  }
  if (p === '/admin/api/upload' && req.method === 'POST') {
    const img = core.parseImage((await readBody(req, 7_000_000)).data);
    if (img.error) return sendJson(res, img.status, { ok: false, error: img.error });
    const name = crypto.randomBytes(12).toString('hex') + '.' + img.ext;
    fs.writeFileSync(path.join(UPLOADS_DIR, name), img.buf);
    return sendJson(res, 200, { ok: true, url: '/uploads/' + name });
  }
  return sendJson(res, 404, { ok: false });
}

// ---------- Маршрутизация ----------
const server = http.createServer(async (req, res) => {
  securityHeaders(res);
  const url = new URL(req.url, 'http://x');
  const p = url.pathname;
  try {
    if (req.method === 'POST' && p === '/api/track') return await handleTrack(req, res);
    if (req.method === 'POST' && p === '/api/lead') return await handleLead(req, res);
    if (req.method === 'POST' && CFG.tgWebhookSecret && p === '/api/telegram/' + CFG.tgWebhookSecret) return await handleTelegramWebhook(req, res);
    if (req.method === 'GET' && p === '/healthz') return sendJson(res, 200, { ok: true });
    if (req.method === 'GET' && p === '/api/products') return sendJson(res, 200, core.publicProducts(products));
    if (req.method === 'GET' && p.startsWith('/uploads/')) return serveFile(res, UPLOADS_DIR, p.slice('/uploads'.length));

    if (p === '/admin' || p.startsWith('/admin/')) {
      if (!requireAdmin(req, res)) return;
      if (p === '/admin/api/stats') {
        const d = Math.min(Math.max(parseInt(url.searchParams.get('days'), 10) || 30, 1), 365);
        return sendJson(res, 200, core.computeStats(events, leads, d));
      }
      if (p.startsWith('/admin/api/products') || p === '/admin/api/upload') return await handleProductsAdmin(req, res, p);
      if (p === '/admin/api/leads.csv') {
        res.writeHead(200, { 'Content-Type': 'text/csv; charset=utf-8', 'Content-Disposition': 'attachment; filename="leads.csv"', 'Cache-Control': 'no-store' });
        return res.end(core.leadsCsv(leads));
      }
      return serveFile(res, ADMIN_DIR, p === '/admin' ? '/' : p.slice('/admin'.length), { 'Cache-Control': 'no-store', 'X-Robots-Tag': 'noindex' });
    }

    if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); res.end(); return; }
    return serveFile(res, PUBLIC_DIR, p);
  } catch (e) {
    if (!e.status) console.error(e);
    if (!res.headersSent) sendJson(res, e.status || 500, { ok: false, error: e.status ? 'Некорректный запрос' : 'Ошибка сервера' });
  }
});

if (require.main === module) {
  server.listen(CFG.port, () => {
    console.log(`Marvan: http://localhost:${CFG.port}`);
    if (!CFG.adminPassword) console.log('• ADMIN_PASSWORD не задан — панель /admin выключена');
    if (!CFG.tgToken || !CFG.tgChatId) console.log('• Telegram не настроен — заявки сохраняются только в data/leads.jsonl');
  });
}

module.exports = { classifySource: core.classifySource, computeStats: core.computeStats, replyButtons: core.replyButtons, cleanProduct: core.cleanProduct };
