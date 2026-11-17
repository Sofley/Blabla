// Красивые переходы между режимами Джарвиса: волшебный дым, цифровой распад, акварель.
// Уход со сцены: экран заволакивает эффектом (cover 0 → 1), затем открывается новая страница,
// и на ней тот же эффект рассеивается (cover 1 → 0), пока проявляется новая сцена.

const SCENE_OF_PAGE = p => p.includes('panda') ? 'panda' : p.includes('mirror') ? 'mirror' : 'tube';
const KEY = 'jarvis-transition';

export function effectFor(from, to) {
  if (to === 'tube' || from === 'tube' && to !== 'panda') return 'digital';
  if (from === 'tube' && to === 'panda') return 'ink';
  return 'smoke';                                   // Шрек ↔ панда и всё остальное
}

let canvas = null, ctx = null, seeds = null;
function setup(kind) {
  if (!canvas) {
    canvas = document.createElement('canvas');
    canvas.style.cssText = 'position:fixed;inset:0;width:100%;height:100%;z-index:60;pointer-events:none';
    document.body.appendChild(canvas);
    ctx = canvas.getContext('2d');
  }
  const dpr = Math.min(devicePixelRatio || 1, 2);
  canvas.width = innerWidth * dpr; canvas.height = innerHeight * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  // случайности фиксируем, чтобы уход и появление выглядели как один эффект
  let s = 7;
  const rnd = () => (s = (s * 16807) % 2147483647) / 2147483647;
  const W = innerWidth, H = innerHeight;
  if (kind === 'smoke') {
    seeds = Array.from({ length: 90 }, () => ({ x: rnd() * W, y: rnd() * H, r: (.12 + rnd() * .35) * Math.max(W, H),
      a: rnd() * Math.PI * 2, sp: .3 + rnd(), t: rnd(), g: rnd() }));
  } else if (kind === 'digital') {
    const cell = 18, cols = Math.ceil(W / cell), rows = Math.ceil(H / cell);
    seeds = { cell, cols, rows, th: Array.from({ length: cols * rows }, (_, i) => {
      const y = Math.floor(i / cols) / rows;
      return Math.min(.98, rnd() * .55 + y * .45);    // заполняется волной сверху вниз
    }), ch: Array.from({ length: cols * rows }, () => '01░▒▓<>/\\#'.charAt(Math.floor(rnd() * 10))) };
  } else {
    seeds = Array.from({ length: 26 }, () => ({ x: (.15 + rnd() * .7) * W, y: (.1 + rnd() * .8) * H,
      r: (.18 + rnd() * .4) * Math.max(W, H), d: rnd() * .3, w: rnd() }));
  }
}

function themeRGB() {
  const v = getComputedStyle(document.documentElement).getPropertyValue('--c').trim();
  return v ? v.split(',').map(Number) : [57, 198, 255];
}

function draw(kind, c, t, entering) {
  const W = innerWidth, H = innerHeight;
  ctx.clearRect(0, 0, W, H);
  if (c <= 0) return;
  const [cr, cg, cb] = themeRGB();
  if (kind === 'smoke') {
    // база тумана, чтобы в конце экран был полностью скрыт
    ctx.fillStyle = `rgba(214,224,222,${Math.pow(c, 2.2) * .97})`;
    ctx.fillRect(0, 0, W, H);
    for (const p of seeds) {
      const drift = entering ? (1 - c) : c;
      const x = p.x + Math.cos(p.a + t * .4 * p.sp) * 60 * drift + (entering ? (p.x - W / 2) * (1 - c) * .6 : 0);
      const y = p.y + Math.sin(p.a + t * .3 * p.sp) * 50 * drift - (entering ? (1 - c) * 160 * p.sp : 0);
      const r = p.r * (.4 + .9 * c);
      const g = ctx.createRadialGradient(x, y, 0, x, y, r);
      const shade = p.g < .5 ? '235,240,238' : `${Math.round(180 + cr * .25)},${Math.round(200 + cg * .2)},${Math.round(195 + cb * .2)}`;
      g.addColorStop(0, `rgba(${shade},${.55 * c})`);
      g.addColorStop(.6, `rgba(${shade},${.25 * c})`);
      g.addColorStop(1, `rgba(${shade},0)`);
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
    }
  } else if (kind === 'digital') {
    const { cell, cols, rows, th, ch } = seeds;
    ctx.font = `${cell - 4}px Consolas, monospace`;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    for (let i = 0; i < th.length; i++) {
      const k = (c - th[i]) / .08;
      if (k <= 0) continue;
      const x = (i % cols) * cell, y = Math.floor(i / cols) * cell;
      const edge = k < 1;
      ctx.fillStyle = edge ? `rgba(${cr},${cg},${cb},.85)` : '#02060c';
      ctx.fillRect(x, y, cell - 1, cell - 1);
      if (!edge && (i * 7 + Math.floor(t * 12)) % 11 === 0) {
        ctx.fillStyle = `rgba(${cr},${cg},${cb},.55)`;
        ctx.fillText(ch[(i + Math.floor(t * 8)) % ch.length], x + cell / 2, y + cell / 2 + 1);
      }
    }
    // луч сканера и полосы «глитча»
    const sy = (entering ? 1 - c : c) * H;
    const grad = ctx.createLinearGradient(0, sy - 30, 0, sy + 4);
    grad.addColorStop(0, `rgba(${cr},${cg},${cb},0)`); grad.addColorStop(1, `rgba(${cr},${cg},${cb},.9)`);
    ctx.fillStyle = grad; ctx.fillRect(0, sy - 30, W, 34);
    for (let b = 0; b < 4; b++) {
      const by = ((t * 300 + b * 137) % H);
      ctx.fillStyle = `rgba(${cr},${cg},${cb},${.12 * c})`;
      ctx.fillRect((Math.sin(t * 20 + b) * 30), by, W, 3 + b * 2);
    }
  } else {
    // акварель: синие кляксы расплываются, затем всё заливает бумагой
    for (const p of seeds) {
      const k = Math.max(0, Math.min(1, (c - p.d) / (1 - p.d)));
      if (k <= 0) continue;
      const r = p.r * Math.pow(k, .8);
      const g = ctx.createRadialGradient(p.x, p.y, r * .2, p.x, p.y, r);
      const col = p.w < .5 ? '45,95,140' : '90,150,185';
      g.addColorStop(0, `rgba(${col},${.92 * k})`);
      g.addColorStop(.7, `rgba(${col},${.7 * k})`);
      g.addColorStop(1, `rgba(${col},0)`);
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, Math.PI * 2); ctx.fill();
    }
    ctx.fillStyle = `rgba(243,236,220,${Math.pow(c, 5)})`;
    ctx.fillRect(0, 0, W, H);
  }
}

function animate(kind, from, to, ms, entering) {
  setup(kind);
  const t0 = performance.now();
  return new Promise(res => {
    const step = now => {
      const k = Math.min(1, (now - t0) / ms);
      const e = k < .5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;   // плавно
      draw(kind, from + (to - from) * e, (now - t0) / 1000, entering);
      if (k < 1) requestAnimationFrame(step);
      else { if (to === 0) { canvas.remove(); canvas = null; } res(); }
    };
    requestAnimationFrame(step);
  });
}

let leaving = false;
// Уйти на другую сцену с красивым переходом
export async function goTo(page) {
  if (leaving) return;
  leaving = true;
  const from = SCENE_OF_PAGE(location.pathname), to = SCENE_OF_PAGE(page);
  const kind = effectFor(from, to);
  try { sessionStorage.setItem(KEY, JSON.stringify({ kind, at: Date.now() })); } catch (e) { /* без памяти — без появления */ }
  await animate(kind, 0, 1, kind === 'digital' ? 900 : 1200, false);
  location.replace(page);
}

// Появление на новой сцене (вызывается при загрузке страницы)
export function arrive(isReady) {
  let info = null;
  try { info = JSON.parse(sessionStorage.getItem(KEY) || 'null'); sessionStorage.removeItem(KEY); } catch (e) { /* нет */ }
  if (!info || Date.now() - info.at > 8000) return;
  setup(info.kind);
  draw(info.kind, 1, 0, true);                      // сразу закрыто, пока сцена грузится
  const t0 = performance.now();
  const wait = () => {
    if ((isReady && isReady()) || performance.now() - t0 > 2500) {
      animate(info.kind, 1, 0, info.kind === 'digital' ? 1100 : 1600, true);
    } else requestAnimationFrame(wait);
  };
  requestAnimationFrame(wait);
}
export { setup as _setup, draw as _draw };   // для проверки кадров
