// Общая логика сайта — без доступа к диску и сети.
// Используется и обычным сервером (server.js), и бесплатным хостингом Netlify (netlify/functions/site.mjs).
'use strict';

const str = (v, max) => String(v ?? '').replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, max);
const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

// ---------- Источники трафика ----------
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
const deviceOf = (ua) => (/Mobi|Android|iPhone/i.test(ua) ? 'Телефон' : /iPad|Tablet/i.test(ua) ? 'Планшет' : 'Компьютер');

// Событие визита из тела запроса /api/track
function makeEvent(b, ua, host, ipHash) {
  const type = b.type === 'event' ? 'event' : 'pageview';
  let refHost = ''; try { refHost = new URL(b.ref).hostname; } catch { /* нет реферера */ }
  return {
    t: Date.now(), type,
    name: type === 'event' ? str(b.name, 40) : undefined,
    label: type === 'event' ? str(b.label, 80) : undefined,
    vid: str(b.vid, 40), sid: str(b.sid, 40),
    path: str(b.path, 200),
    src: classifySource(b.utm_source, b.ref, host),
    medium: str(b.utm_medium, 60) || undefined,
    campaign: str(b.utm_campaign, 80) || undefined,
    refHost: refHost || undefined,
    device: deviceOf(ua),
    tz: str(b.tz, 50) || undefined,
    lang: str(b.lang, 12) || undefined,
    ip: ipHash,
  };
}

// ---------- Заявки ----------
// Возвращает { spam } | { error } | { lead } (без id и delivered)
function validateLead(b, host, ipHash) {
  if (b.website || Number(b.elapsed) < 2500) return { spam: true }; // ловушка и слишком быстрое заполнение
  const lead = {
    name: str(b.name, 80), contact: str(b.contact, 80),
    channel: ['Telegram', 'Звонок', 'Email'].includes(b.channel) ? b.channel : 'Telegram',
    items: str(b.items, 1500), comment: str(b.comment, 1500),
  };
  if (lead.name.length < 2 || lead.contact.length < 5) return { error: 'Укажите имя и контакт для связи' };
  if (b.consent !== true) return { error: 'Нужно согласие на обработку персональных данных' };
  Object.assign(lead, {
    t: Date.now(),
    src: classifySource(b.utm_source, b.ref, host),
    campaign: str(b.utm_campaign, 80) || undefined,
    vid: str(b.vid, 40), ip: ipHash,
  });
  return { lead };
}
function leadsCsv(leads) {
  const rows = [['№', 'Дата', 'Имя', 'Контакт', 'Канал', 'Позиции', 'Комментарий', 'Источник']]
    .concat(leads.map((l) => [l.id, new Date(l.t).toISOString(), l.name, l.contact, l.channel, l.items, l.comment, SOURCE_LABELS[l.src] || l.src]));
  return '﻿' + rows.map((r) => r.map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`).join(';')).join('\r\n');
}

// ---------- Товары ----------
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
// Применяет сохранение товара к списку. Возвращает { errors } или { products, product, oldPhoto }
function upsertProduct(products, body) {
  const { errors, product } = cleanProduct(body);
  const prevId = str(body.prevId, 24).toUpperCase();
  const idx = products.findIndex((x) => x.id === (prevId || product.id));
  if (!prevId && idx !== -1) errors.push('Такой артикул уже есть');
  if (prevId && product.id !== prevId && products.some((x) => x.id === product.id)) errors.push('Такой артикул уже есть');
  if (errors.length) return { errors };
  const next = [...products];
  let oldPhoto = '';
  if (prevId && idx !== -1) {
    const old = next[idx]; oldPhoto = old.photo !== product.photo ? old.photo : '';
    next[idx] = { ...product, createdAt: old.createdAt, updatedAt: Date.now() };
  } else {
    next.push({ ...product, createdAt: Date.now() });
  }
  return { products: next, product, oldPhoto };
}
const publicProducts = (products) => products.filter((x) => !x.hidden).map(({ createdAt, updatedAt, hidden, ...x }) => x);
const IMAGE_SIGNATURES = [
  { ext: 'jpg', type: 'image/jpeg', test: (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  { ext: 'png', type: 'image/png', test: (b) => b.slice(0, 4).toString('hex') === '89504e47' },
  { ext: 'webp', type: 'image/webp', test: (b) => b.slice(0, 4).toString() === 'RIFF' && b.slice(8, 12).toString() === 'WEBP' },
];
// Проверяет фото из data:URL. Возвращает { error, status } или { buf, ext, type }
function parseImage(dataUrl) {
  const m = String(dataUrl || '').match(/^data:image\/[a-z]+;base64,(.+)$/);
  if (!m) return { status: 422, error: 'Нужен файл JPG, PNG или WebP' };
  const buf = Buffer.from(m[1], 'base64');
  if (buf.length > 5 * 1024 * 1024) return { status: 413, error: 'Фото больше 5 МБ' };
  const sig = IMAGE_SIGNATURES.find((x) => x.test(buf));
  if (!sig) return { status: 422, error: 'Нужен файл JPG, PNG или WebP' };
  return { buf, ext: sig.ext, type: sig.type };
}

// ---------- Статистика ----------
const DAY = 86_400_000;
// Дни считаются по местному времени (по умолчанию Ташкент, UTC+5; меняется переменной TZ_OFFSET_HOURS)
const TZ_OFFSET = Number((typeof process !== 'undefined' && process.env.TZ_OFFSET_HOURS) || 5);
const dayKey = (t) => new Date(t + TZ_OFFSET * 3600_000).toISOString().slice(0, 10);

function computeStats(events, leads, days) {
  const now = Date.now();
  const from = now - days * DAY;
  const evs = events.filter((e) => e.t >= from).sort((a, b) => a.t - b.t);
  const lds = leads.filter((l) => l.t >= from).sort((a, b) => a.t - b.t);
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
  const ss = [...sessions.values()];
  return {
    days, generatedAt: now,
    totals: {
      sessions: sessions.size, visitors: visitors.size, pageviews: pv.length, leads: lds.length,
      conversion: sessions.size ? +(lds.length / sessions.size * 100).toFixed(1) : 0,
    },
    sources, daily,
    clicks: count(evs.filter((e) => e.type === 'event'), (e) => e.name),
    products: count(evs.filter((e) => e.name === 'product_open'), (e) => e.label),
    devices: count(ss, (s) => s.device),
    regions: count(ss, (s) => s.tz).slice(0, 8),
    campaigns: count(ss, (s) => s.campaign).slice(0, 8),
    referrers: count(ss.filter((s) => s.src === 'other'), (s) => s.refHost).slice(0, 8),
    recentLeads: lds.slice(-25).reverse().map((l) => ({
      id: l.id, t: l.t, name: l.name, contact: l.contact, channel: l.channel,
      items: l.items, comment: l.comment, src: SOURCE_LABELS[l.src] || l.src, delivered: l.delivered,
    })),
  };
}

// ---------- Telegram ----------
const EVENT_LABELS = {
  tg_click: 'Клик «Telegram»', phone_click: 'Клик по телефону', email_click: 'Клик по почте',
  product_open: 'Открыта карточка товара', request_add: 'Добавлено в запрос', lead_submit: 'Отправлена заявка',
  social_click: 'Переход в соцсеть', samples_click: 'Интерес к боксу образцов', story_open: 'Читали истории недели',
};
async function tg(token, method, payload) {
  if (!token) return { ok: false, description: 'TELEGRAM_BOT_TOKEN не задан' };
  try {
    const r = await fetch(`https://api.telegram.org/bot${token}/${method}`, {
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
function statsMessage(events, leads, days) {
  const s = computeStats(events, leads, days);
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
function leadsListMessage(leads) {
  const last = [...leads].sort((a, b) => a.t - b.t).slice(-5).reverse();
  const text = last.length ? last.map((l) => `№${l.id} · ${new Date(l.t).toLocaleString('ru-RU', { timeZone: 'Asia/Tashkent' })}\n${esc(l.name)} — ${esc(l.contact)}`).join('\n\n') : 'Заявок пока нет';
  return `<b>Последние заявки</b>\n\n${text}`;
}
const BOT_HELP = 'Команды:\n/stats — статистика за 7 дней\n/stats 30 — за 30 дней\n/leads — последние заявки';
const BOT_STRANGER = 'Здравствуйте! Это служебный бот Marvan. Напишите менеджеру — он ответит в течение 15 минут.';

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

module.exports = {
  str, esc, SOURCE_LABELS, classifySource, BOT_UA, deviceOf, makeEvent, validateLead, leadsCsv,
  SHAPES, FINISH_KEYS, TAGS, cleanProduct, upsertProduct, publicProducts, parseImage,
  DAY, dayKey, computeStats, EVENT_LABELS, tg, replyButtons, leadMessage, statsMessage, leadsListMessage,
  BOT_HELP, BOT_STRANGER, CSP,
};
