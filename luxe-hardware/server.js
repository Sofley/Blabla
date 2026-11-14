// Luxe Hardware — сервер сайта-визитки.
// Без внешних зависимостей: нужен только Node.js 20.12+ (рекомендуется 22).
//
// Что делает:
//   • раздаёт сайт из ./public;
//   • /api/lead     — принимает заявку, сохраняет её и пересылает продавцу в Telegram;
//   • /api/track    — принимает анонимные события визитов (источник, устройство, клики);
//   • /admin        — закрытая паролем панель статистики для администратора;
//   • /api/telegram/<секрет> — webhook бота: команды /stats и /leads прямо в Telegram.

'use strict';

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

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
// Для сайта-визитки (сотни–тысячи визитов в день) этого достаточно.
// Если трафик вырастет — заменить на SQLite/Postgres, интерфейс тот же.
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

// ---------- Товары ----------
// Каталог хранится в data/products.json и редактируется из админки (/admin/products.html).
// Пустой каталог — нормальное состояние: сайт показывает только истории и контакты.
let products = [];
try { products = JSON.parse(fs.readFileSync(PRODUCTS_FILE, 'utf8')); } catch { products = []; }
function saveProducts() {
  const tmp = PRODUCTS_FILE + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(products, null, 2));
  fs.renameSync(tmp, PRODUCTS_FILE); // атомарная запись — файл не побьётся при сбое
}
const SHAPES = ['clasp', 'zipper', 'lock', 'snap', 'chain', 'buckle', 'dring', 'stud'];
const FINISH_KEYS = ['champagne', 'nickel', 'silver', 'bronze'];
const TAGS = ['bags', 'clutches', 'belts', 'small'];
function cleanProduct(b) {
  const errors = [];
  const id = str(b.id, 24).toUpperCase();
  if (!/^[A-Z0-9][A-Z0-9-]{1,23}$/.test(id)) errors.push('Артикул: латиница, цифры и дефис, 2–24 символа');
  const title = str(b.title, 120);
  if (title.length < 2) errors.push('Укажите название');
  const price = b.price === '' || b.price == null ? null : Math.round(Number(b.price));
  if (price !== null && !(price >= 0 && price < 10_000_000)) errors.push('Цена — число');
  const moq = Math.max(1, Math.round(Number(b.moq) || 1));
  const finishes = (Array.isArray(b.finishes) ? b.finishes : []).filter((f) => FINISH_KEYS.includes(f));
  const specs = {};
  for (const line of String(b.specs || '').split('\n')) {
    const i = line.indexOf(':'); if (i < 1) continue;
    const k = str(line.slice(0, i), 40), v = str(line.slice(i + 1), 120);
    if (k && v && Object.keys(specs).length < 12) specs[k] = v;
  }
  const photo = /^\/uploads\/[a-f0-9]{24}\.(jpg|png|webp)$/.test(b.photo) ? b.photo : '';
  return {
    errors,
    product: {
      id, title, price, moq,
      use: str(b.use, 160), desc: str(b.desc, 1200), unit: str(b.unit, 12) || 'шт.',
      tags: (Array.isArray(b.tags) ? b.tags : []).filter((t) => TAGS.includes(t)),
      draw: SHAPES.includes(b.draw) ? b.draw : '',
      photo, specs,
      finishes: finishes.length ? finishes : [...FINISH_KEYS],
      finish: finishes.includes(b.finish) ? b.finish : (finishes[0] || 'champagne'),
      hidden: b.hidden === true,
    },
  };
}
function removeUnusedPhoto(photo) {
  if (!photo || products.some((p) => p.photo === photo)) return;
  fs.unlink(path.join(UPLOADS_DIR, path.basename(photo)), () => {});
}
const IMAGE_SIGNATURES = [
  { ext: 'jpg', test: (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  { ext: 'png', test: (b) => b.slice(0, 4).toString('hex') === '89504e47' },
  { ext: 'webp', test: (b) => b.slice(0, 4).toString() === 'RIFF' && b.slice(8, 12).toString() === 'WEBP' },
];

async function handleProductsAdmin(req, res, p) {
  if (p === '/admin/api/products' && req.method === 'GET') return sendJson(res, 200, products);
  if (p === '/admin/api/products' && req.method === 'POST') {
    const b = await readBody(req, 32_768);
    const { errors, product } = cleanProduct(b);
    const prevId = str(b.prevId, 24).toUpperCase();
    const idx = products.findIndex((x) => x.id === (prevId || product.id));
    if (!prevId && idx !== -1) errors.push('Такой артикул уже есть');
    if (prevId && product.id !== prevId && products.some((x) => x.id === product.id)) errors.push('Такой артикул уже есть');
    if (errors.length) return sendJson(res, 422, { ok: false, errors });
    if (prevId && idx !== -1) {
      const old = products[idx];
      products[idx] = { ...product, createdAt: old.createdAt, updatedAt: Date.now() };
      saveProducts(); if (old.photo !== product.photo) removeUnusedPhoto(old.photo);
    } else {
      products.push({ ...product, createdAt: Date.now() }); saveProducts();
    }
    return sendJson(res, 200, { ok: true, product });
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
    const b = await readBody(req, 7_000_000);
    const m = String(b.data || '').match(/^data:image\/[a-z]+;base64,(.+)$/);
    if (!m) return sendJson(res, 422, { ok: false, error: 'Нужен файл JPG, PNG или WebP' });
    const buf = Buffer.from(m[1], 'base64');
    if (buf.length > 5 * 1024 * 1024) return sendJson(res, 413, { ok: false, error: 'Фото больше 5 МБ' });
    const sig = IMAGE_SIGNATURES.find((x) => x.test(buf));
    if (!sig) return sendJson(res, 422, { ok: false, error: 'Нужен файл JPG, PNG или WebP' });
    const name = crypto.randomBytes(12).toString('hex') + '.' + sig.ext;
    fs.writeFileSync(path.join(UPLOADS_DIR, name), buf);
    return sendJson(res, 200, { ok: true, url: '/uploads/' + name });
  }
  return sendJson(res, 404, { ok: false });
}

// ---------- Определение источника трафика ----------
const SOURCE_LABELS = {
  instagram: 'Instagram', telegram: 'Telegram', youtube: 'YouTube', google: 'Google',
  yandex: 'Яндекс', vk: 'ВКонтакте', direct: 'Прямой заход', other: 'Другие сайты',
};
function classifySource(utmSource, referrer, selfHost) {
  const s = String(utmSource || '').toLowerCase().trim();
  if (s) {
    if (/^(ig|insta|instagram)/.test(s)) return 'instagram';
    if (/^(tg|telegram)/.test(s)) return 'telegram';
    if (/^(yt|youtube)/.test(s)) return 'youtube';
    if (/^(google|gmb|gbp|maps)/.test(s)) return 'google';
    if (/^(yandex|ya)/.test(s)) return 'yandex';
    if (/^(vk|vkontakte)/.test(s)) return 'vk';
    return 'other';
  }
  let host = '';
  try { host = new URL(referrer).hostname.toLowerCase(); } catch { return 'direct'; }
  if (!host || host === selfHost) return 'direct';
  if (/(^|\.)instagram\.com$/.test(host)) return 'instagram';
  if (/(^|\.)(t\.me|telegram\.org|telegram\.me)$/.test(host)) return 'telegram';
  if (/(^|\.)(youtube\.com|youtu\.be)$/.test(host)) return 'youtube';
  if (/(^|\.)google\.[a-z.]+$/.test(host)) return 'google';
  if (/(^|\.)(yandex\.[a-z]+|ya\.ru)$/.test(host)) return 'yandex';
  if (/(^|\.)(vk\.com|vk\.ru)$/.test(host)) return 'vk';
  return 'other';
}

const BOT_UA = /bot|crawl|spider|slurp|preview|headless|lighthouse|facebookexternalhit|telegrambot|whatsapp/i;

// ---------- Утилиты HTTP ----------
const MIME = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.webp': 'image/webp', '.avif': 'image/avif', '.ico': 'image/x-icon', '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8', '.woff2': 'font/woff2',
};
const CSP = [
  "default-src 'self'",
  "script-src 'self' https://mc.yandex.ru https://yastatic.net https://www.googletagmanager.com",
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
  "font-src 'self' https://fonts.gstatic.com",
  "img-src 'self' data: https:",
  "connect-src 'self' https://mc.yandex.ru https://mc.yandex.com https://*.google-analytics.com https://*.analytics.google.com https://www.googletagmanager.com",
  "frame-src https://mc.yandex.ru https://mc.yandex.com",
  "base-uri 'self'", "form-action 'self'", "frame-ancestors 'none'",
].join('; ');

function securityHeaders(res) {
  res.setHeader('Content-Security-Policy', CSP);
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
const str = (v, max) => String(v ?? '').replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, max);

// Простой rate-limit в памяти
const buckets = new Map();
function rateLimited(key, max, windowMs) {
  const now = Date.now();
  const b = (buckets.get(key) || []).filter((t) => now - t < windowMs);
  b.push(now); buckets.set(key, b);
  return b.length > max;
}
setInterval(() => { const now = Date.now(); for (const [k, v] of buckets) if (!v.some((t) => now - t < 3_600_000)) buckets.delete(k); }, 600_000).unref();

// ---------- Статика ----------
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
    const isHtml = ext === '.html';
    res.writeHead(200, {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      'Cache-Control': isHtml ? 'no-cache' : 'public, max-age=86400',
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
  const p = rest.join(':');
  const eq = (a, b) => {
    const ha = crypto.createHash('sha256').update(a).digest();
    const hb = crypto.createHash('sha256').update(b).digest();
    return crypto.timingSafeEqual(ha, hb);
  };
  return eq(u, CFG.adminUser) & eq(p, CFG.adminPassword) ? true : false;
}
function requireAdmin(req, res) {
  if (checkAdmin(req)) return true;
  if (!CFG.adminPassword) {
    res.writeHead(503, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Панель отключена: задайте ADMIN_PASSWORD в .env');
    return false;
  }
  if (rateLimited('admin:' + ipHash(clientIp(req)), 20, 600_000)) { res.writeHead(429); res.end(); return false; }
  res.writeHead(401, { 'WWW-Authenticate': 'Basic realm="Luxe Hardware admin", charset="UTF-8"' });
  res.end('Требуется авторизация');
  return false;
}

// ---------- Статистика ----------
const DAY = 86_400_000;
function dayKey(t) { return new Date(t + 3 * 3600_000).toISOString().slice(0, 10); } // дни по Москве

function computeStats(days) {
  const now = Date.now();
  const from = now - days * DAY;
  const evs = events.filter((e) => e.t >= from);
  const lds = leads.filter((l) => l.t >= from);
  const pv = evs.filter((e) => e.type === 'pageview');

  const sessions = new Map(); // sid -> первый pageview сессии
  for (const e of pv) if (!sessions.has(e.sid)) sessions.set(e.sid, e);
  const visitors = new Set(pv.map((e) => e.vid));

  const bySource = {};
  for (const s of sessions.values()) bySource[s.src] = (bySource[s.src] || 0) + 1;
  const leadsBySource = {};
  for (const l of lds) leadsBySource[l.src || 'direct'] = (leadsBySource[l.src || 'direct'] || 0) + 1;
  const sources = Object.keys(SOURCE_LABELS).map((k) => ({
    key: k, label: SOURCE_LABELS[k], sessions: bySource[k] || 0, leads: leadsBySource[k] || 0,
  })).filter((s) => s.sessions || s.leads).sort((a, b) => b.sessions - a.sessions);

  const daily = [];
  for (let i = days - 1; i >= 0; i--) daily.push({ day: dayKey(now - i * DAY), sessions: 0, leads: 0 });
  const idx = Object.fromEntries(daily.map((d, i) => [d.day, i]));
  for (const s of sessions.values()) { const i = idx[dayKey(s.t)]; if (i !== undefined) daily[i].sessions++; }
  for (const l of lds) { const i = idx[dayKey(l.t)]; if (i !== undefined) daily[i].leads++; }

  const count = (arr, key) => {
    const m = {}; for (const x of arr) { const k = key(x); if (k) m[k] = (m[k] || 0) + 1; }
    return Object.entries(m).map(([name, n]) => ({ name, n })).sort((a, b) => b.n - a.n);
  };
  const clicks = count(evs.filter((e) => e.type === 'event'), (e) => e.name);
  const products = count(evs.filter((e) => e.name === 'product_open'), (e) => e.label);
  const devices = count([...sessions.values()], (s) => s.device);
  const regions = count([...sessions.values()], (s) => s.tz).slice(0, 8);
  const campaigns = count([...sessions.values()], (s) => s.campaign).slice(0, 8);
  const referrers = count([...sessions.values()].filter((s) => s.src === 'other'), (s) => s.refHost).slice(0, 8);

  return {
    days, generatedAt: now,
    totals: {
      sessions: sessions.size, visitors: visitors.size, pageviews: pv.length, leads: lds.length,
      conversion: sessions.size ? +(lds.length / sessions.size * 100).toFixed(1) : 0,
    },
    sources, daily, clicks, products, devices, regions, campaigns, referrers,
    recentLeads: lds.slice(-25).reverse().map((l) => ({
      id: l.id, t: l.t, name: l.name, contact: l.contact, channel: l.channel,
      items: l.items, comment: l.comment, src: SOURCE_LABELS[l.src] || l.src, delivered: l.delivered,
    })),
  };
}

// ---------- Telegram ----------
const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
async function tg(method, payload) {
  if (!CFG.tgToken) return { ok: false, description: 'TELEGRAM_BOT_TOKEN не задан' };
  try {
    const r = await fetch(`https://api.telegram.org/bot${CFG.tgToken}/${method}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload), signal: AbortSignal.timeout(8000),
    });
    return await r.json();
  } catch (e) { return { ok: false, description: e.message }; }
}
// Кнопка «Ответить клиенту» — сразу открывает чат с клиентом в Telegram, если он оставил @ник или телефон.
function replyButtons(contact) {
  const c = contact.trim();
  const rows = [];
  const nick = c.match(/^@?([a-zA-Z][a-zA-Z0-9_]{4,31})$/);
  const digits = c.replace(/[^\d+]/g, '');
  if (nick) rows.push([{ text: `Написать @${nick[1]}`, url: `https://t.me/${nick[1]}` }]);
  else if (/^\+?\d{10,15}$/.test(digits)) {
    const intl = digits.startsWith('+') ? digits : digits.startsWith('8') && digits.length === 11 ? '+7' + digits.slice(1) : '+' + digits;
    rows.push([{ text: 'Открыть в Telegram', url: `https://t.me/${intl}` }]);
  }
  return rows.length ? { inline_keyboard: rows } : undefined;
}
function leadMessage(l) {
  return [
    `<b>Новая заявка №${l.id}</b>`,
    '',
    `<b>Имя:</b> ${esc(l.name)}`,
    `<b>Контакт:</b> ${esc(l.contact)}`,
    `<b>Ответить через:</b> ${esc(l.channel)}`,
    l.items ? `\n<b>Позиции:</b>\n${esc(l.items)}` : '',
    l.comment ? `\n<b>Комментарий:</b>\n${esc(l.comment)}` : '',
    '',
    `<i>Источник: ${esc(SOURCE_LABELS[l.src] || l.src)}${l.campaign ? ' · ' + esc(l.campaign) : ''}</i>`,
  ].filter((x) => x !== '').join('\n');
}
function statsMessage(days) {
  const s = computeStats(days);
  const lines = s.sources.map((x) => `• ${x.label}: ${x.sessions} виз. / ${x.leads} заяв.`);
  const top = s.clicks.slice(0, 5).map((c) => `• ${EVENT_LABELS[c.name] || c.name}: ${c.n}`);
  return [
    `<b>Статистика за ${days} дн.</b>`,
    `Визиты: <b>${s.totals.sessions}</b> · посетители: <b>${s.totals.visitors}</b>`,
    `Заявки: <b>${s.totals.leads}</b> · конверсия: <b>${s.totals.conversion}%</b>`,
    '', '<b>Источники</b>', ...(lines.length ? lines : ['нет данных']),
    '', '<b>Действия</b>', ...(top.length ? top : ['нет данных']),
  ].join('\n');
}
const EVENT_LABELS = {
  tg_click: 'Клик «Telegram»', phone_click: 'Клик по телефону', email_click: 'Клик по почте',
  product_open: 'Открыта карточка товара', request_add: 'Добавлено в запрос', lead_submit: 'Отправлена заявка',
  social_click: 'Переход в соцсеть', samples_click: 'Интерес к боксу образцов', story_open: 'Читали истории недели',
};

// ---------- Обработчики API ----------
async function handleTrack(req, res) {
  const ua = String(req.headers['user-agent'] || '');
  if (BOT_UA.test(ua)) return sendJson(res, 204, {});
  const ip = ipHash(clientIp(req));
  if (rateLimited('track:' + ip, 120, 60_000)) return sendJson(res, 429, { ok: false });
  let b; try { b = await readBody(req, 4096); } catch (e) { return sendJson(res, e.status || 400, { ok: false }); }
  const type = b.type === 'event' ? 'event' : 'pageview';
  const host = String(req.headers.host || '').split(':')[0];
  let refHost = ''; try { refHost = new URL(b.ref).hostname; } catch { /* нет реферера */ }
  append(EVENTS_FILE, events, {
    t: Date.now(), type,
    name: type === 'event' ? str(b.name, 40) : undefined,
    label: type === 'event' ? str(b.label, 80) : undefined,
    vid: str(b.vid, 40), sid: str(b.sid, 40),
    path: str(b.path, 200),
    src: classifySource(b.utm_source, b.ref, host),
    medium: str(b.utm_medium, 60) || undefined,
    campaign: str(b.utm_campaign, 80) || undefined,
    refHost: refHost || undefined,
    device: /Mobi|Android|iPhone/i.test(ua) ? 'Телефон' : /iPad|Tablet/i.test(ua) ? 'Планшет' : 'Компьютер',
    tz: str(b.tz, 50) || undefined,
    lang: str(b.lang, 12) || undefined,
    ip,
  });
  sendJson(res, 204, {});
}

async function handleLead(req, res) {
  const ip = ipHash(clientIp(req));
  if (rateLimited('lead:' + ip, 5, 600_000)) return sendJson(res, 429, { ok: false, error: 'Слишком много заявок. Попробуйте через 10 минут или напишите нам в Telegram.' });
  let b; try { b = await readBody(req, 16_384); } catch (e) { return sendJson(res, e.status || 400, { ok: false, error: 'Некорректный запрос' }); }

  // Антиспам: скрытое поле-ловушка и слишком быстрое заполнение
  if (b.website || Number(b.elapsed) < 2500) return sendJson(res, 200, { ok: true, id: 0 });

  const lead = {
    name: str(b.name, 80), contact: str(b.contact, 80),
    channel: ['Telegram', 'Звонок', 'Email'].includes(b.channel) ? b.channel : 'Telegram',
    items: str(b.items, 1500), comment: str(b.comment, 1500),
  };
  if (lead.name.length < 2 || lead.contact.length < 5) return sendJson(res, 422, { ok: false, error: 'Укажите имя и контакт для связи' });
  if (b.consent !== true) return sendJson(res, 422, { ok: false, error: 'Нужно согласие на обработку персональных данных' });

  const host = String(req.headers.host || '').split(':')[0];
  Object.assign(lead, {
    id: (leads.at(-1)?.id || 0) + 1, t: Date.now(),
    src: classifySource(b.utm_source, b.ref, host),
    campaign: str(b.utm_campaign, 80) || undefined,
    vid: str(b.vid, 40), ip,
  });
  const r = await tg('sendMessage', {
    chat_id: CFG.tgChatId, text: leadMessage(lead), parse_mode: 'HTML',
    disable_web_page_preview: true, reply_markup: replyButtons(lead.contact),
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
  // Отвечаем только в чат администратора — посторонние не увидят статистику.
  if (String(msg.chat.id) !== String(CFG.tgChatId)) {
    await tg('sendMessage', { chat_id: msg.chat.id, text: 'Здравствуйте! Это служебный бот Luxe Hardware. Напишите менеджеру — он ответит в течение 15 минут.' });
    return;
  }
  const [cmd, arg] = msg.text.trim().split(/\s+/);
  if (/^\/stats/.test(cmd)) {
    const d = Math.min(Math.max(parseInt(arg, 10) || 7, 1), 365);
    await tg('sendMessage', { chat_id: msg.chat.id, text: statsMessage(d), parse_mode: 'HTML' });
  } else if (/^\/leads/.test(cmd)) {
    const last = leads.slice(-5).reverse();
    const text = last.length ? last.map((l) => `№${l.id} · ${new Date(l.t).toLocaleString('ru-RU', { timeZone: 'Europe/Moscow' })}\n${esc(l.name)} — ${esc(l.contact)}`).join('\n\n') : 'Заявок пока нет';
    await tg('sendMessage', { chat_id: msg.chat.id, text: `<b>Последние заявки</b>\n\n${text}`, parse_mode: 'HTML' });
  } else {
    await tg('sendMessage', { chat_id: msg.chat.id, text: 'Команды:\n/stats — статистика за 7 дней\n/stats 30 — за 30 дней\n/leads — последние заявки' });
  }
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
    if (req.method === 'GET' && p === '/api/products') {
      res.setHeader('Cache-Control', 'no-cache');
      return sendJson(res, 200, products.filter((x) => !x.hidden).map(({ createdAt, updatedAt, hidden, ...x }) => x));
    }
    if (req.method === 'GET' && p.startsWith('/uploads/')) return serveFile(res, UPLOADS_DIR, p.slice('/uploads'.length));

    if (p === '/admin' || p.startsWith('/admin/')) {
      if (!requireAdmin(req, res)) return;
      if (p === '/admin/api/stats') {
        const d = Math.min(Math.max(parseInt(url.searchParams.get('days'), 10) || 30, 1), 365);
        return sendJson(res, 200, computeStats(d));
      }
      if (p.startsWith('/admin/api/products') || p === '/admin/api/upload') return await handleProductsAdmin(req, res, p);
      if (p === '/admin/api/leads.csv') {
        const rows = [['№', 'Дата', 'Имя', 'Контакт', 'Канал', 'Позиции', 'Комментарий', 'Источник']]
          .concat(leads.map((l) => [l.id, new Date(l.t).toISOString(), l.name, l.contact, l.channel, l.items, l.comment, SOURCE_LABELS[l.src] || l.src]));
        const csv = '﻿' + rows.map((r) => r.map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`).join(';')).join('\r\n');
        res.writeHead(200, { 'Content-Type': 'text/csv; charset=utf-8', 'Content-Disposition': 'attachment; filename="leads.csv"', 'Cache-Control': 'no-store' });
        return res.end(csv);
      }
      return serveFile(res, ADMIN_DIR, p === '/admin' ? '/' : p.slice('/admin'.length), { 'Cache-Control': 'no-store', 'X-Robots-Tag': 'noindex' });
    }

    if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); res.end(); return; }
    return serveFile(res, PUBLIC_DIR, p);
  } catch (e) {
    console.error(e);
    if (!res.headersSent) sendJson(res, e.status || 500, { ok: false, error: e.status ? 'Некорректный запрос' : 'Ошибка сервера' });
  }
});

if (require.main === module) {
  server.listen(CFG.port, () => {
    console.log(`Luxe Hardware: http://localhost:${CFG.port}`);
    if (!CFG.adminPassword) console.log('• ADMIN_PASSWORD не задан — панель /admin выключена');
    if (!CFG.tgToken || !CFG.tgChatId) console.log('• Telegram не настроен — заявки сохраняются только в data/leads.jsonl');
  });
}

module.exports = { classifySource, computeStats, replyButtons, cleanProduct };
