/* Luxe Hardware — логика сайта. Без библиотек. */
(() => {
  'use strict';
  document.documentElement.classList.add('js');
  const S = window.SITE || {};
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const store = {
    get(k, d) { try { const v = localStorage.getItem(k); return v ? JSON.parse(v) : d; } catch { return d; } },
    set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch { /* приватный режим */ } },
  };

  // ============================================================
  //  ДАННЫЕ: покрытия и товары
  // ============================================================
  const FINISHES = {
    champagne: { name: 'Матовая шампань', short: 'Шампань', light: '#F1E5CB', mid: '#C4AA82', dark: '#7F6646',
      text: 'Тёплое золото без блеска. Самое универсальное: к чёрной, коньячной и бежевой коже.' },
    nickel: { name: 'Тёмный никель', short: 'Графит', light: '#9C9A96', mid: '#4D4C49', dark: '#1F1E1D',
      text: 'Глубокий графит. Для мужских аксессуаров и минималистичных моделей.' },
    silver: { name: 'Сатиновое серебро', short: 'Серебро', light: '#FAF9F6', mid: '#CFCBC4', dark: '#8A867F',
      text: 'Холодный приглушённый блеск без желтизны. Для серой, синей и белой кожи.' },
    bronze: { name: 'Античная бронза', short: 'Бронза', light: '#B9966F', mid: '#755D46', dark: '#3A2B1F',
      text: 'Патина с ручной брашировкой рельефа. Для винтажных и седельных изделий.' },
  };
  const FINISH_KEYS = Object.keys(FINISHES);

  const PRODUCTS = [
    { id: 'LH-101', draw: 'clasp', tags: ['clutches', 'bags'], finish: 'champagne',
      title: 'Поворотный замок «Clasp 38»', use: 'Клатчи, вечерние сумки, кросс-боди',
      desc: 'Классический поворотный замок для клапана: открывается одной рукой, не давит на мягкую кожу. Внутри — подпружиненный фиксатор с мягким щелчком.',
      specs: { 'Материал': 'ZAMAK-3', 'Размер': '38 × 24 мм', 'Кожа': '1,8–3,2 мм', 'Крепление': 'Усики + шайба' },
      price: 390, unit: 'компл.', moq: 10 },
    { id: 'LH-102', draw: 'zipper', tags: ['small', 'clutches', 'bags'], finish: 'nickel',
      title: 'Бегунок для молнии №5', use: 'Клатчи, кошельки, несессеры, барсетки',
      desc: 'Удлинённый плоский пуллер вместо кожаной кисточки: удобно ложится в пальцы и не гремит. Автостопор держит бегунок в любом положении.',
      specs: { 'Материал': 'ZAMAK + стальной стопор', 'Под молнию': 'Металл №5 (YKK, Riri)', 'Пуллер': '34 × 9 мм' },
      price: 115, unit: 'шт.', moq: 20 },
    { id: 'LH-103', draw: 'lock', tags: ['bags'], finish: 'bronze',
      title: 'Портфельный замок «Archive»', use: 'Портфели, деловые папки, саквояжи',
      desc: 'Нажимная защелка с ключом — по мотивам докторских саквояжей XIX века. Усиленная пружина выдерживает тяжёлый портфель с ноутбуком.',
      specs: { 'Материал': 'ZAMAK + стальной узел', 'Размер': '68 × 42 мм', 'Толщина': '8,5 мм', 'Комплект': 'Замок, ответка, 2 ключа' },
      price: 540, unit: 'компл.', moq: 5 },
    { id: 'LH-104', draw: 'snap', tags: ['bags'], finish: 'champagne',
      title: 'Карабин с вертлюгом «Saddle»', use: 'Плечевые ремни, мессенджеры, дорожные сумки',
      desc: 'Форма из шорного ремесла: вертлюг вращается бесшумно и не даёт ремню перекручиваться. Скруглённые края не заламывают торец кожи.',
      specs: { 'Материал': 'Цельная латунь', 'Ушко': '20 / 25 мм', 'Длина': '56 мм' },
      price: 260, unit: 'шт.', moq: 10 },
    { id: 'LH-105', draw: 'chain', tags: ['clutches', 'bags'], finish: 'champagne',
      title: 'Цепь плоская «Curb 8»', use: 'Вечерние клатчи, мини-сумки, багеты',
      desc: 'Алмазная шлифовка граней делает цепь гибкой, как лента: не заламывается и не цепляет ткань. Облегчённая — комфортна на плече.',
      specs: { 'Материал': 'Латунь', 'Звено': '8,5 × 2,2 мм', 'Нарезка': 'Метражом или 115 см' },
      price: 480, unit: 'м', moq: 5 },
    { id: 'LH-106', draw: 'buckle', tags: ['belts'], finish: 'bronze',
      title: 'Пряжка ременная «Contour»', use: 'Брючные ремни, портупеи, поясные сумки',
      desc: 'Лёгкий анатомический изгиб повторяет линию талии — пряжка не оттопыривается под пиджаком. Язычок отполирован с внутренней стороны.',
      specs: { 'Материал': 'Цельная латунь', 'Под ремень': '30 / 35 / 40 мм' },
      price: 310, unit: 'шт.', moq: 10 },
    { id: 'LH-107', draw: 'dring', tags: ['bags'], finish: 'silver',
      title: 'Полукольцо литое D-ring', use: 'Тоуты, шопперы, рюкзаки, крепление ремней',
      desc: 'Литое, без стыка, в отличие от гнутых проволочных колец. Плоская перемычка держит шлёвку по центру и не разгибается при рывке.',
      specs: { 'Материал': 'Цельная латунь', 'Внутр. ширина': '20 / 25 мм', 'Сечение': '4 мм' },
      price: 95, unit: 'шт.', moq: 20 },
    { id: 'LH-108', draw: 'stud', tags: ['small', 'belts'], finish: 'champagne',
      title: 'Кобурная кнопка винтовая', use: 'Кардхолдеры, ключницы, хлястики, клапаны',
      desc: 'Точёная на ЧПУ кнопка без пружин — нечему ломаться. Мягкая шейка для плавной фиксации, винт М3 в комплекте.',
      specs: { 'Материал': 'Точёная латунь', 'Головка': '7 / 8 / 9 мм', 'Крепление': 'Винт М3' },
      price: 85, unit: 'шт.', moq: 20 },
  ];
  const tiers = (p) => [
    { q: `от ${p.moq}`, v: p.price },
    { q: 'от 50', v: Math.round(p.price * 0.9) },
    { q: 'от 200', v: null },
  ];
  const rub = (n) => n.toLocaleString('ru-RU') + ' ₽';

  // ============================================================
  //  ИЛЛЮСТРАЦИИ: векторная фурнитура, окрашиваемая в выбранное покрытие
  // ============================================================
  let uid = 0;
  const rr = (x, y, w, h, r) => `M${x + r} ${y}h${w - 2 * r}a${r} ${r} 0 0 1 ${r} ${r}v${h - 2 * r}a${r} ${r} 0 0 1 -${r} ${r}h-${w - 2 * r}a${r} ${r} 0 0 1 -${r} -${r}v-${h - 2 * r}a${r} ${r} 0 0 1 ${r} -${r}z`;
  const ring = (cx, cy, R, r) => `M${cx - R} ${cy}a${R} ${R} 0 1 0 ${2 * R} 0a${R} ${R} 0 1 0 -${2 * R} 0zM${cx - r} ${cy}a${r} ${r} 0 1 1 ${2 * r} 0a${r} ${r} 0 1 1 -${2 * r} 0z`;

  const SHAPES = {
    clasp: (m, e) => `
      <path d="${rr(40, 66, 160, 108, 54)}" fill="${m}"/>
      <path d="${rr(52, 78, 136, 84, 42)}" fill="none" stroke="rgba(255,255,255,.45)" stroke-width="1.5"/>
      <path d="${rr(54, 80, 132, 80, 40)}" fill="none" stroke="rgba(0,0,0,.18)" stroke-width="1"/>
      <g transform="rotate(-18 120 120)">
        <path d="${rr(104, 52, 32, 136, 16)}" fill="${e}" stroke="rgba(0,0,0,.25)"/>
        <path d="${rr(110, 58, 20, 124, 10)}" fill="none" stroke="rgba(255,255,255,.4)"/>
      </g>
      <circle cx="120" cy="120" r="10" fill="${m}" stroke="rgba(0,0,0,.3)"/>
      <circle cx="66" cy="120" r="5" fill="${e}" stroke="rgba(0,0,0,.25)"/>
      <circle cx="174" cy="120" r="5" fill="${e}" stroke="rgba(0,0,0,.25)"/>`,
    zipper: (m, e) => `
      <path d="M90 28h60a6 6 0 0 1 6 7l-8 50a8 8 0 0 1-8 7h-40a8 8 0 0 1-8-7l-8-50a6 6 0 0 1 6-7z" fill="${e}" stroke="rgba(0,0,0,.25)"/>
      <path d="M100 40h40l-5 38h-30z" fill="none" stroke="rgba(255,255,255,.35)"/>
      <path d="${rr(110, 72, 20, 28, 8)}" fill="${m}" stroke="rgba(0,0,0,.3)"/>
      <path d="${rr(100, 92, 40, 128, 20)} ${rr(112, 176, 16, 30, 8)}" fill="${m}" fill-rule="evenodd" stroke="rgba(0,0,0,.18)"/>
      <path d="M108 104v62" stroke="rgba(255,255,255,.5)" stroke-width="2" stroke-linecap="round"/>`,
    lock: (m, e) => `
      <path d="${rr(44, 66, 152, 112, 16)}" fill="${m}"/>
      <path d="${rr(54, 76, 132, 92, 10)}" fill="none" stroke="rgba(255,255,255,.4)" stroke-width="1.5"/>
      <path d="${rr(56, 78, 128, 88, 9)}" fill="none" stroke="rgba(0,0,0,.18)"/>
      <path d="${rr(92, 46, 56, 30, 10)}" fill="${e}" stroke="rgba(0,0,0,.28)"/>
      <path d="M100 56h40" stroke="rgba(255,255,255,.4)" stroke-width="2" stroke-linecap="round"/>
      <circle cx="120" cy="124" r="15" fill="${e}" stroke="rgba(0,0,0,.25)"/>
      <path d="M120 116a5 5 0 0 1 3 9l2 9h-10l2-9a5 5 0 0 1 3-9z" fill="rgba(20,18,16,.6)"/>
      <circle cx="62" cy="84" r="3.5" fill="${e}"/><circle cx="178" cy="84" r="3.5" fill="${e}"/>
      <circle cx="62" cy="160" r="3.5" fill="${e}"/><circle cx="178" cy="160" r="3.5" fill="${e}"/>`,
    snap: (m, e) => `
      <path d="${ring(120, 50, 30, 18)}" fill="${m}" fill-rule="evenodd" stroke="rgba(0,0,0,.15)"/>
      <path d="${rr(108, 76, 24, 16, 6)}" fill="${e}" stroke="rgba(0,0,0,.25)"/>
      <path d="${rr(112, 90, 16, 18, 5)}" fill="${m}" stroke="rgba(0,0,0,.2)"/>
      <path d="${rr(78, 104, 84, 120, 42)} ${rr(94, 122, 52, 84, 26)}" fill="${m}" fill-rule="evenodd" stroke="rgba(0,0,0,.15)"/>
      <path d="${rr(140, 126, 12, 62, 6)}" fill="${e}" stroke="rgba(0,0,0,.3)"/>
      <path d="M90 150v34" stroke="rgba(255,255,255,.55)" stroke-width="2.5" stroke-linecap="round"/>
      <path d="M104 40a18 18 0 0 1 14-8" stroke="rgba(255,255,255,.6)" stroke-width="2" fill="none" stroke-linecap="round"/>`,
    chain: (m, e) => {
      let s = '';
      for (let i = 0; i < 6; i++) {
        const cx = 46 + i * 30, cy = 196 - i * 30, a = -45 + (i % 2 ? 10 : -10);
        s += `<g transform="translate(${cx} ${cy}) rotate(${a})"><path d="${rr(-28, -15, 56, 30, 15)} ${rr(-17, -6, 34, 12, 6)}" fill="${i % 2 ? e : m}" fill-rule="evenodd" stroke="rgba(0,0,0,.22)"/><path d="M-16 -11h32" stroke="rgba(255,255,255,.5)" stroke-width="1.5" stroke-linecap="round"/></g>`;
      }
      return s;
    },
    buckle: (m, e) => `
      <path d="${rr(40, 64, 160, 112, 30)} ${rr(58, 82, 124, 76, 18)}" fill="${m}" fill-rule="evenodd" stroke="rgba(0,0,0,.15)"/>
      <path d="${rr(48, 72, 144, 96, 24)}" fill="none" stroke="rgba(255,255,255,.4)" stroke-width="1.5"/>
      <path d="${rr(52, 112, 112, 14, 7)}" fill="${e}" stroke="rgba(0,0,0,.3)"/>
      <path d="M60 116h90" stroke="rgba(255,255,255,.45)" stroke-width="1.5" stroke-linecap="round"/>
      <path d="${rr(40, 108, 26, 24, 8)}" fill="${e}" stroke="rgba(0,0,0,.25)"/>`,
    dring: (m, e) => `
      <path d="M66 54h44a66 66 0 0 1 0 132h-44z M84 72h26a48 48 0 0 1 0 96h-26z" fill="${m}" fill-rule="evenodd" stroke="rgba(0,0,0,.15)"/>
      <path d="${rr(56, 50, 34, 140, 10)}" fill="${e}" stroke="rgba(0,0,0,.25)"/>
      <path d="M150 84a52 52 0 0 1 10 40" stroke="rgba(255,255,255,.55)" stroke-width="3" fill="none" stroke-linecap="round"/>
      <path d="M68 62v116" stroke="rgba(255,255,255,.35)" stroke-width="2" stroke-linecap="round"/>`,
    stud: (m, e) => `
      <path d="M72 106a48 40 0 0 1 96 0z" fill="${m}" stroke="rgba(0,0,0,.18)"/>
      <path d="${rr(68, 102, 104, 14, 7)}" fill="${e}" stroke="rgba(0,0,0,.25)"/>
      <path d="M92 84a30 22 0 0 1 26-14" stroke="rgba(255,255,255,.65)" stroke-width="3" fill="none" stroke-linecap="round"/>
      <path d="M106 116h28l-4 30h-20z" fill="${e}" stroke="rgba(0,0,0,.25)"/>
      <path d="${rr(82, 144, 76, 16, 8)}" fill="${m}" stroke="rgba(0,0,0,.2)"/>
      <path d="${rr(113, 158, 14, 46, 3)}" fill="${e}" stroke="rgba(0,0,0,.25)"/>
      ${[0, 1, 2, 3, 4].map((i) => `<path d="M113 ${166 + i * 8}h14" stroke="rgba(0,0,0,.25)"/>`).join('')}`,
  };

  function drawSvg(shape, finishKey) {
    const f = FINISHES[finishKey]; const id = 'g' + (++uid);
    return `<svg viewBox="0 0 240 240" role="img" aria-hidden="true">
      <defs>
        <linearGradient id="${id}m" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="${f.mid}"/><stop offset=".32" stop-color="${f.light}"/>
          <stop offset=".58" stop-color="${f.mid}"/><stop offset="1" stop-color="${f.dark}"/>
        </linearGradient>
        <linearGradient id="${id}e" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="${f.light}"/><stop offset=".5" stop-color="${f.mid}"/><stop offset="1" stop-color="${f.dark}"/>
        </linearGradient>
        <radialGradient id="${id}s"><stop offset="0" stop-color="rgba(34,32,30,.22)"/><stop offset="1" stop-color="rgba(34,32,30,0)"/></radialGradient>
      </defs>
      <ellipse cx="120" cy="224" rx="78" ry="9" fill="url(#${id}s)"/>
      ${SHAPES[shape](`url(#${id}m)`, `url(#${id}e)`)}
    </svg>`;
  }
  // Плавная смена покрытия: старая картинка растворяется, новая проявляется
  function swapSvg(host, html) {
    const old = host.firstElementChild;
    if (!old || matchMedia('(prefers-reduced-motion: reduce)').matches) { host.innerHTML = html; return; }
    const wrap = document.createElement('div'); wrap.innerHTML = html; const next = wrap.firstElementChild;
    host.style.position = 'relative';
    Object.assign(next.style, { position: 'absolute', inset: '0', margin: 'auto', opacity: '0', transition: 'opacity .6s cubic-bezier(.22,1,.36,1)' });
    old.style.transition = 'opacity .6s cubic-bezier(.22,1,.36,1)';
    host.appendChild(next);
    requestAnimationFrame(() => requestAnimationFrame(() => { next.style.opacity = '1'; old.style.opacity = '0'; }));
    setTimeout(() => { old.remove(); next.removeAttribute('style'); }, 650);
  }

  function swatches(host, current, onPick) {
    host.innerHTML = FINISH_KEYS.map((k) => `
      <button type="button" class="swatch" role="radio" aria-checked="${k === current}" data-f="${k}" aria-label="${FINISHES[k].name}">
        <span class="swatch__dot" style="background:linear-gradient(135deg,${FINISHES[k].light},${FINISHES[k].mid} 55%,${FINISHES[k].dark})"></span><span>${FINISHES[k].short}</span>
      </button>`).join('');
    host.onclick = (e) => {
      const b = e.target.closest('.swatch'); if (!b) return;
      $$('.swatch', host).forEach((x) => x.setAttribute('aria-checked', x === b));
      onPick(b.dataset.f);
    };
  }

  // ============================================================
  //  АНАЛИТИКА: откуда пришёл посетитель и что он делал
  // ============================================================
  const api = (p) => (S.apiBase || '') + p;
  const hasServer = /^https?:$/.test(location.protocol);
  const rid = () => (crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2) + Date.now().toString(36));
  const vid = store.get('lh_vid') || (store.set('lh_vid', rid()), store.get('lh_vid', rid()));
  let session; try { session = JSON.parse(sessionStorage.getItem('lh_s')); } catch { /* нет */ }
  if (!session) {
    const q = new URLSearchParams(location.search);
    session = { sid: rid(), ref: document.referrer, utm_source: q.get('utm_source') || '', utm_medium: q.get('utm_medium') || '', utm_campaign: q.get('utm_campaign') || '' };
    try { sessionStorage.setItem('lh_s', JSON.stringify(session)); } catch { /* нет */ }
    if (!store.get('lh_first')) store.set('lh_first', session); // первый источник — для заявки
  }
  const attribution = () => { const f = store.get('lh_first', session); return { ref: f.ref, utm_source: f.utm_source, utm_campaign: f.utm_campaign }; };

  function send(payload) {
    if (!hasServer) return;
    const body = JSON.stringify({ ...payload, vid, sid: session.sid, ref: session.ref, utm_source: session.utm_source, utm_medium: session.utm_medium, utm_campaign: session.utm_campaign, path: location.pathname, tz: Intl.DateTimeFormat().resolvedOptions().timeZone, lang: navigator.language });
    const blob = new Blob([body], { type: 'application/json' });
    if (!(navigator.sendBeacon && navigator.sendBeacon(api('/api/track'), blob))) {
      fetch(api('/api/track'), { method: 'POST', body, headers: { 'Content-Type': 'application/json' }, keepalive: true }).catch(() => {});
    }
  }
  function track(name, label) {
    send({ type: 'event', name, label });
    try { if (window.ym && S.analytics?.yandexMetrikaId) window.ym(+S.analytics.yandexMetrikaId, 'reachGoal', name); } catch { /* */ }
    try { if (window.gtag) window.gtag('event', name, { event_label: label }); } catch { /* */ }
  }
  send({ type: 'pageview' });
  document.addEventListener('click', (e) => {
    const el = e.target.closest('[data-track]');
    if (el) track(el.dataset.track, el.dataset.label || '');
  });

  // Внешние счётчики — только если указаны в config.js
  function loadScript(src) { const s = document.createElement('script'); s.async = true; s.src = src; document.head.appendChild(s); }
  const ymId = S.analytics?.yandexMetrikaId;
  if (ymId) {
    window.ym = window.ym || function () { (window.ym.a = window.ym.a || []).push(arguments); }; window.ym.l = +new Date();
    loadScript('https://mc.yandex.ru/metrika/tag.js');
    window.ym(+ymId, 'init', { clickmap: true, trackLinks: true, accurateTrackBounce: true, webvisor: true });
  }
  const gaId = S.analytics?.googleAnalyticsId;
  if (gaId) {
    loadScript('https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(gaId));
    window.dataLayer = window.dataLayer || []; window.gtag = function () { window.dataLayer.push(arguments); };
    window.gtag('js', new Date()); window.gtag('config', gaId);
  }

  // ============================================================
  //  КОНТАКТЫ И СОЦСЕТИ из config.js
  // ============================================================
  const tgUrl = (text) => `https://t.me/${S.telegram}${text ? '?text=' + encodeURIComponent(text) : ''}`;
  $$('.js-tg').forEach((a) => { a.href = tgUrl('Здравствуйте! Пишу с сайта Luxe Hardware.'); a.target = '_blank'; a.rel = 'noopener'; });
  $$('.js-tg-nick').forEach((s) => { s.textContent = '@' + S.telegram; });
  $$('.js-phone').forEach((a) => { a.href = 'tel:' + S.phoneHref; a.textContent = S.phone; });
  $$('.js-email').forEach((a) => { a.href = 'mailto:' + S.email; a.textContent = S.email; });
  $$('.js-address').forEach((s) => { s.textContent = S.address; });
  $$('.js-hours').forEach((s) => { s.textContent = S.hours; });
  $('#year').textContent = new Date().getFullYear();

  const ICONS = {
    telegram: ['Telegram', '<path d="M21.5 4.3 2.9 11.5c-1 .4-1 1.6.1 1.9l4.6 1.4 1.8 5.6c.2.7 1.1.9 1.6.4l2.6-2.4 4.8 3.5c.6.4 1.4.1 1.6-.6L22.9 5.6c.3-1-.6-1.7-1.4-1.3zM9.6 14.5l8.2-7.2-6.2 8.4-.3 3-1.7-4.2z" fill="currentColor"/>'],
    instagram: ['Instagram*', '<rect x="3" y="3" width="18" height="18" rx="5" fill="none" stroke="currentColor" stroke-width="1.6"/><circle cx="12" cy="12" r="4.2" fill="none" stroke="currentColor" stroke-width="1.6"/><circle cx="17.3" cy="6.7" r="1.1" fill="currentColor"/>'],
    youtube: ['YouTube', '<rect x="2.5" y="5.5" width="19" height="13" rx="4" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M10 9.2v5.6l5-2.8z" fill="currentColor"/>'],
    google: ['Google Карты', '<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z" fill="none" stroke="currentColor" stroke-width="1.6"/><circle cx="12" cy="10" r="2.4" fill="currentColor"/>'],
  };
  $('#socials').innerHTML = Object.entries(S.socials || {}).filter(([k, url]) => url && ICONS[k]).map(([k, url]) =>
    `<li><a href="${url}" target="_blank" rel="noopener" aria-label="${ICONS[k][0]}" title="${ICONS[k][0]}" data-track="social_click" data-label="${k}"><svg viewBox="0 0 24 24">${ICONS[k][1]}</svg></a></li>`).join('');
  if (!S.socials?.instagram) $('.legal').firstChild.textContent = '';

  // ============================================================
  //  HERO: смена покрытия меняет тон всей сцены
  // ============================================================
  const heroObj = $('#heroObject');
  heroObj.innerHTML = drawSvg('snap', 'champagne');
  swatches($('#heroSwatches'), 'champagne', (k) => {
    swapSvg(heroObj, drawSvg('snap', k));
    $('.stage').style.setProperty('--tone', FINISHES[k].mid);
    $('#heroFinishName').textContent = FINISHES[k].name;
  });

  // ============================================================
  //  КАТАЛОГ
  // ============================================================
  const grid = $('#grid');
  grid.innerHTML = PRODUCTS.map((p) => `
    <button class="card reveal" type="button" data-id="${p.id}" data-tags="${p.tags.join(' ')}" aria-haspopup="dialog">
      <div class="card__visual">${drawSvg(p.draw, p.finish)}</div>
      <div class="card__body">
        <span class="card__sku">${p.id}</span>
        <span class="card__title">${p.title}</span>
        <span class="card__use">${p.use}</span>
        <span class="card__foot">
          <span><span class="card__price">${rub(p.price)}</span> <span class="card__unit">/ ${p.unit}</span></span>
          <span class="card__dots" aria-label="4 покрытия">${FINISH_KEYS.map((k) => `<i style="background:${FINISHES[k].mid}"></i>`).join('')}</span>
        </span>
      </div>
    </button>`).join('');

  $('#filters').addEventListener('click', (e) => {
    const b = e.target.closest('.chip'); if (!b) return;
    $$('.chip').forEach((c) => { const on = c === b; c.classList.toggle('is-active', on); c.setAttribute('aria-selected', on); });
    const f = b.dataset.filter;
    $$('.card', grid).forEach((c, i) => {
      const show = f === 'all' || c.dataset.tags.split(' ').includes(f);
      c.classList.toggle('is-hidden', !show);
      c.classList.remove('is-entering');
      if (show) { c.style.animationDelay = (i * 40) + 'ms'; void c.offsetWidth; c.classList.add('is-entering'); }
    });
  });

  // ============================================================
  //  КАРТОЧКА ТОВАРА (модальное окно)
  // ============================================================
  const modal = $('#modal');
  let cur = null, curFinish = null;
  function openProduct(id) {
    const p = PRODUCTS.find((x) => x.id === id); if (!p) return;
    cur = p; curFinish = p.finish;
    $('#mSku').textContent = p.id;
    $('#mTitle').textContent = p.title;
    $('#mDesc').textContent = p.desc;
    $('#mSpecs').innerHTML = Object.entries({ 'Применение': p.use, ...p.specs, 'Мин. партия': `${p.moq} ${p.unit}`, 'Образец': 'от 1 шт.' })
      .map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`).join('');
    $('#mTiers').innerHTML = tiers(p).map((t) => `<div class="tier"><b>${t.v ? rub(t.v) : 'по запросу'}</b><span>${t.q} ${p.unit}</span></div>`).join('');
    $('#mObject').innerHTML = drawSvg(p.draw, curFinish);
    $('#mFinish').textContent = FINISHES[curFinish].name;
    swatches($('#mSwatches'), curFinish, (k) => {
      curFinish = k; swapSvg($('#mObject'), drawSvg(p.draw, k)); $('#mFinish').textContent = FINISHES[k].name; updateProductTg();
    });
    updateProductTg();
    modal.showModal();
    track('product_open', p.id);
  }
  function updateProductTg() {
    const a = $('.js-tg-product');
    a.href = tgUrl(`Здравствуйте! Интересует ${cur.id} «${cur.title}», покрытие «${FINISHES[curFinish].name}». Подскажите наличие и цену.`);
    a.target = '_blank'; a.rel = 'noopener';
  }
  grid.addEventListener('click', (e) => { const c = e.target.closest('.card'); if (c) openProduct(c.dataset.id); });
  $('#modalClose').addEventListener('click', () => modal.close());
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.close(); });
  $('#mAdd').addEventListener('click', () => {
    addPick({ id: cur.id, title: cur.title, finish: curFinish });
    track('request_add', cur.id);
    modal.close();
    toast(`${cur.id} добавлен в запрос`);
  });

  // ============================================================
  //  СПИСОК ПОЗИЦИЙ В ЗАЯВКЕ
  // ============================================================
  let picks = store.get('lh_picks', []);
  function addPick(item) {
    if (!picks.some((x) => x.id === item.id && x.finish === item.finish)) picks.push(item);
    store.set('lh_picks', picks); renderPicks();
  }
  function renderPicks() {
    const box = $('#picked');
    $('#clearItems').hidden = !picks.length;
    if (!picks.length) { box.innerHTML = '<span class="picked__empty">Добавьте позиции кнопкой «В запрос» в карточке товара — или опишите ниже.</span>'; return; }
    box.innerHTML = picks.map((x, i) => `<span class="pick"><i style="background:${FINISHES[x.finish]?.mid || '#ccc'}"></i>${x.id} · ${FINISHES[x.finish]?.short || ''}<button type="button" data-i="${i}" aria-label="Убрать ${x.id}">×</button></span>`).join('');
  }
  $('#picked').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-i]'); if (!b) return;
    picks.splice(+b.dataset.i, 1); store.set('lh_picks', picks); renderPicks();
  });
  $('#clearItems').addEventListener('click', () => { picks = []; store.set('lh_picks', picks); renderPicks(); });
  renderPicks();
  const picksText = () => picks.map((x) => `${x.id} «${x.title}» — ${FINISHES[x.finish]?.name || x.finish}`).join('\n');

  $('#samplesBtn').addEventListener('click', () => {
    const c = $('#leadForm [name=comment]');
    if (!/бокс/i.test(c.value)) c.value = ('Хочу заказать бокс образцов (2 800 ₽). ' + c.value).trim();
    $('#contacts').scrollIntoView({ behavior: 'smooth' });
    setTimeout(() => $('#leadForm [name=name]').focus({ preventScroll: true }), 700);
  });

  // ============================================================
  //  ФОРМА ЗАЯВКИ
  // ============================================================
  const form = $('#leadForm');
  const opened = Date.now();
  const status = $('#formStatus');
  function validate() {
    let ok = true;
    for (const name of ['name', 'contact']) {
      const inp = form.elements[name]; const bad = inp.value.trim().length < (name === 'name' ? 2 : 5);
      inp.closest('.field').classList.toggle('is-invalid', bad); if (bad && ok) inp.focus(); ok = ok && !bad;
    }
    const consentOk = form.elements.consent.checked;
    $('.err--consent').classList.toggle('is-shown', !consentOk);
    return ok && consentOk;
  }
  form.addEventListener('input', (e) => e.target.closest('.field')?.classList.remove('is-invalid'));
  form.elements.consent.addEventListener('change', () => $('.err--consent').classList.remove('is-shown'));

  function fallbackHtml(data) {
    const text = `Заявка с сайта\nИмя: ${data.name}\nКонтакт: ${data.contact}\n${data.items ? 'Позиции:\n' + data.items + '\n' : ''}${data.comment ? 'Комментарий: ' + data.comment : ''}`;
    return `Не удалось отправить автоматически. Отправьте заявку <a href="${tgUrl(text)}" target="_blank" rel="noopener">в Telegram</a> или <a href="mailto:${S.email}?subject=${encodeURIComponent('Заявка с сайта')}&body=${encodeURIComponent(text)}">на почту</a> — текст уже подставлен.`;
  }

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!validate()) return;
    const data = {
      name: form.elements.name.value.trim(), contact: form.elements.contact.value.trim(),
      channel: form.elements.channel.value, items: picksText(), comment: form.elements.comment.value.trim(),
      consent: true, website: form.elements.website.value, elapsed: Date.now() - opened, vid, ...attribution(),
    };
    const btn = $('#submitBtn'); btn.disabled = true; btn.textContent = 'Отправляем…';
    status.className = 'form-status'; status.textContent = '';
    try {
      if (!hasServer) throw new Error('offline');
      const r = await fetch(api('/api/lead'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
      const j = await r.json().catch(() => ({}));
      if (!r.ok || !j.ok) { if (j.error && r.status !== 500) { status.className = 'form-status is-err'; status.textContent = j.error; return; } throw new Error('fail'); }
      status.className = 'form-status is-ok';
      status.textContent = `Спасибо, ${data.name}! Заявка №${j.id} у менеджера — ответим в течение 15 минут в рабочее время.`;
      track('lead_submit', data.channel);
      form.reset(); picks = []; store.set('lh_picks', picks); renderPicks();
    } catch {
      status.className = 'form-status is-err'; status.innerHTML = fallbackHtml(data);
    } finally { btn.disabled = false; btn.textContent = 'Отправить заявку'; }
  });

  // ============================================================
  //  ПЛАВНЫЕ ПЕРЕХОДЫ: появление блоков и смена цвета страницы
  // ============================================================
  const toastEl = $('#toast'); let tt;
  function toast(msg) { toastEl.textContent = msg; toastEl.classList.add('is-shown'); clearTimeout(tt); tt = setTimeout(() => toastEl.classList.remove('is-shown'), 2600); }

  const io = new IntersectionObserver((entries) => entries.forEach((en) => {
    if (en.isIntersecting) { en.target.classList.add('is-in'); io.unobserve(en.target); }
  }), { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
  $$('.reveal').forEach((el) => {
    const sib = [...el.parentElement.children].filter((x) => x.classList.contains('reveal'));
    el.style.setProperty('--d', Math.min(sib.indexOf(el), 6) * 70 + 'ms');
    io.observe(el);
  });

  // Цвет фона страницы перетекает от секции к секции
  const BG = { hero: '#F6F4F0', catalog: '#ECE7DF', finishes: '#22201E', process: '#F6F4F0', contacts: '#ECE7DF' };
  const bgObs = new IntersectionObserver((entries) => entries.forEach((en) => {
    if (!en.isIntersecting) return;
    const c = BG[en.target.id]; if (!c) return;
    document.body.style.setProperty('--page-bg', c);
    document.body.classList.toggle('on-dark', en.target.id === 'finishes');
    document.querySelector('meta[name=theme-color]').content = c;
  }), { rootMargin: '-45% 0px -45% 0px' });
  Object.keys(BG).forEach((id) => { const el = document.getElementById(id); if (el) bgObs.observe(el); });

  const header = $('#header');
  addEventListener('scroll', () => header.classList.toggle('is-scrolled', scrollY > 8), { passive: true });

  const burger = $('#burger'), mnav = $('#mnav');
  burger.addEventListener('click', () => { const open = burger.getAttribute('aria-expanded') !== 'true'; burger.setAttribute('aria-expanded', open); mnav.hidden = !open; });
  mnav.addEventListener('click', (e) => { if (e.target.tagName === 'A') { burger.setAttribute('aria-expanded', 'false'); mnav.hidden = true; } });

  // Покрытия в тёмной секции
  $('#finishGrid').innerHTML = FINISH_KEYS.map((k) => {
    const f = FINISHES[k];
    return `<div class="finish reveal is-in"><div class="finish__plate" style="background:linear-gradient(115deg,${f.dark} 0%,${f.mid} 30%,${f.light} 48%,${f.mid} 62%,${f.dark} 100%)"></div><div class="finish__name">${f.name}</div><p class="finish__text">${f.text}</p></div>`;
  }).join('');
})();
