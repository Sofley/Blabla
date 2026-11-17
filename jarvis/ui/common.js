// Общее для всех сцен Джарвиса: связь с программой (/state), речь -> амплитуда, HUD, модель головы.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

export const THEMES = {
  'голубой': [57, 198, 255], 'золотой': [255, 190, 70], 'красный': [255, 85, 70],
  'зеленый': [70, 255, 160], 'фиолетовый': [175, 115, 255],
};
const MODE_TEXT = { idle: 'ожидание', listening: 'слушаю', thinking: 'анализ', speaking: 'передача' };
const VOWELS = 'аеёиоуыэюяaeiouy';
const SCENE_PAGES = { tube: 'index.html', mirror: 'mirror.html', panda: 'panda.html' };

export const params = new URLSearchParams(location.search);
export const state = { mode: 'idle', text: '', speak_id: 0, speak_ms: 0, theme: '', visible: true, scene: '' };

// демо — только если явно попросили (?demo) или страница открыта файлом без Джарвиса
let speakStart = 0, envelope = [0], lastSpeakId = -1, amp = 0, demo = params.has('demo') || location.protocol === 'file:';
let linked = false, failures = 0;
let onTheme = () => {};
const $ = id => document.getElementById(id);

function makeEnvelope(text) {
  const env = [];
  for (const ch of text.toLowerCase()) {
    if (VOWELS.includes(ch)) env.push(1);
    else if (/[a-zа-я]/.test(ch)) env.push(.35);
    else if (/[,.!?;:—\-\n]/.test(ch)) env.push(0, 0);
    else env.push(.1);
  }
  return env.map((_, i) => { const w = env.slice(Math.max(0, i - 1), i + 2); return w.reduce((a, b) => a + b, 0) / w.length; })
    .concat([0]);
}

export function applyState(s) {
  const prevTheme = state.theme;
  Object.assign(state, s);
  // Джарвис переключил сцену голосом — открываем другую страницу
  const page = SCENE_PAGES[state.scene];
  if (page && !demo && !location.pathname.endsWith(page) && !(page === 'index.html' && location.pathname.endsWith('/'))) {
    location.replace(page);
    return;
  }
  if (state.speak_id !== lastSpeakId && state.mode === 'speaking') {
    lastSpeakId = state.speak_id;
    speakStart = performance.now();
    envelope = makeEnvelope(state.text || '');
  }
  if (state.theme !== prevTheme) {
    const rgb = THEMES[state.theme] || THEMES['голубой'];
    document.documentElement.style.setProperty('--c', rgb.join(','));
    onTheme(new THREE.Color().setRGB(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255));
  }
  $('status').textContent = MODE_TEXT[state.mode] || state.mode;
  if ($('sub').textContent !== state.text) $('sub').textContent = state.text || '';
}

// ---------------------------------------------------------------- заставка запуска
let bootEl = null, bootShown = 0, bootLast = 0, bootHideAt = 0;
function bootSetup() {
  const css = document.createElement('style');
  css.textContent = `
    .jboot { position: fixed; inset: 0; z-index: 50; display: flex; align-items: center; justify-content: center;
      background: radial-gradient(ellipse at center, rgba(2,6,12,.72), rgba(0,0,0,.94)); color: rgb(var(--c, 57,198,255));
      font-family: "Bahnschrift", "Segoe UI", system-ui, sans-serif; transition: opacity 1s ease, background 1.6s ease;
      pointer-events: none; }
    .jboot.dark { background: #000; }
    .jboot.gone { opacity: 0; }
    .jboot .box { width: min(78%, 420px); display: grid; gap: 14px; }
    .jboot h2 { margin: 0; text-align: center; font-size: clamp(26px, 7vw, 40px); letter-spacing: .5em; text-indent: .5em;
      font-weight: 600; text-shadow: 0 0 18px rgba(var(--c, 57,198,255), .9); animation: jbglow 2.4s ease-in-out infinite; }
    .jboot .jb-sub { text-align: center; font-size: 11px; letter-spacing: .45em; opacity: .7; text-transform: uppercase; }
    .jboot .bar { height: 3px; background: rgba(var(--c, 57,198,255), .18); border-radius: 2px; overflow: hidden; }
    .jboot .bar i { display: block; height: 100%; width: 0; background: rgb(var(--c, 57,198,255));
      box-shadow: 0 0 10px rgb(var(--c, 57,198,255)); transition: width .4s ease; }
    .jboot ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 7px; font-size: 13px; letter-spacing: .06em; }
    .jboot li { display: flex; justify-content: space-between; gap: 12px; opacity: 0; transform: translateY(6px);
      transition: opacity .35s, transform .35s; color: #d9eefc; }
    .jboot li.on { opacity: 1; transform: none; }
    .jboot li b { font-weight: 600; color: rgb(var(--c, 57,198,255)); text-transform: uppercase; font-size: 11px; letter-spacing: .15em; }
    .jboot li b.bad { color: #ff8a7a; }
    .jboot li b.wait { animation: jbblink 1s steps(2) infinite; }
    @keyframes jbglow { 50% { opacity: .75; } }
    @keyframes jbblink { 50% { opacity: .2; } }
    @media (prefers-reduced-motion: reduce) { .jboot h2, .jboot li b.wait { animation: none; } }`;
  document.head.appendChild(css);
  bootEl = document.createElement('div');
  bootEl.className = 'jboot dark';
  bootEl.innerHTML = '<div class="box"><h2>ДЖАРВИС</h2><div class="jb-sub">запуск систем</div><div class="bar"><i></i></div><ul></ul></div>';
  document.body.appendChild(bootEl);
  setTimeout(() => bootEl && bootEl.classList.remove('dark'), 900);   // сцена проявляется из темноты
}
function bootTick(now) {
  const b = state.boot;
  if (!b || (!b.active && !bootEl)) return;
  if (!bootEl) { if (!b.active) return; bootSetup(); }
  const lines = b.lines || [];
  // строки появляются по одной, даже если системы готовы мгновенно
  if (bootShown < lines.length && now - bootLast > 380) { bootShown++; bootLast = now; }
  const ul = bootEl.querySelector('ul');
  lines.forEach((l, i) => {
    let li = ul.children[i];
    if (!li) { li = document.createElement('li'); li.innerHTML = '<span></span><b></b>'; ul.appendChild(li); }
    li.firstChild.textContent = l.text;
    const st = l.status === '...' ? 'проверка' : l.status;
    li.lastChild.textContent = st;
    li.lastChild.className = l.status === '...' ? 'wait' : /ошибк|нет|не /.test(l.status) ? 'bad' : '';
    li.classList.toggle('on', i < bootShown);
  });
  const done = lines.filter(l => l.status !== '...').length;
  bootEl.querySelector('.bar i').style.width = (b.active ? Math.min(92, done * 16) : 100) + '%';
  if (!b.active && bootShown >= lines.length) {
    if (!bootHideAt) bootHideAt = now + 700;
    if (now > bootHideAt) { bootEl.classList.add('gone'); const el = bootEl; setTimeout(() => el.remove(), 1100); bootEl = null; }
  }
}

// ---------------------------------------------------------------- демо-режим (без Джарвиса или с ?demo)
const DEMO = [
  { mode: 'idle', text: '', ms: 2500 },
  { mode: 'listening', text: 'Да, сэр?', ms: 2500 },
  { mode: 'thinking', text: 'напиши маме что я скоро буду', ms: 2500 },
  { mode: 'speaking', text: 'Сообщение для «Мама»: Скоро буду, хлеб куплю. Отправить, сэр?', ms: 5000 },
];
let demoIdx = -1, demoNext = 0;

export function startLink({ defaultTheme, themeChanged }) {
  onTheme = themeChanged;
  // демо-страница (пульт) управляет сценой через postMessage
  addEventListener('message', e => {
    const s = e.data && e.data.jarvis;
    if (!s) return;
    demo = true; demoNext = Infinity;
    applyState({ ...s, speak_id: s.mode === 'speaking' ? (s.speak_id || performance.now()) : state.speak_id });
  });
  applyState({ theme: params.get('theme') || defaultTheme });
  setInterval(async () => {
    if (demo) return;
    try {
      const r = await fetch('/state', { cache: 'no-store' });
      const s = await r.json();
      if (!s.theme) s.theme = defaultTheme;
      applyState(s);
      linked = true; failures = 0;
    } catch (e) {
      // связь с Джарвисом прервалась (например, он перезапускается) — просто ждём и пробуем снова;
      // в демо уходим, только если Джарвиса не было с самого начала
      failures++;
      if (!linked && failures > 40) demo = true;
    }
  }, 70);
  if (params.has('mode')) {  // для снимков: ?demo&mode=speaking&t=1200
    const d = DEMO.find(x => x.mode === params.get('mode'));
    demo = true; demoNext = Infinity;
    applyState({ mode: d.mode, text: d.text, speak_id: 1, speak_ms: d.ms });
    speakStart = performance.now() - Number(params.get('t') || 0);
  }
}

// ---------------------------------------------------------------- амплитуда речи и HUD (каждый кадр)
let bars = null;
export function tick(now, t) {
  if (demo && now >= demoNext) {
    demoIdx = (demoIdx + 1) % DEMO.length;
    const d = DEMO[demoIdx];
    demoNext = now + d.ms;
    applyState({ mode: d.mode, text: d.text, speak_id: demoIdx + now, speak_ms: d.ms });
  }
  let target = 0;
  if (state.mode === 'speaking') {
    const frac = (now - speakStart) / Math.max(400, state.speak_ms || 1);
    if (frac >= 0 && frac < 1) {
      target = envelope[Math.min(envelope.length - 1, Math.floor(frac * envelope.length))] * (.75 + .35 * Math.random());
    }
  }
  amp += (target - amp) * .45;
  bootTick(now);

  if (!bars) bars = Array.from({ length: 31 }, () => $('eq').appendChild(document.createElement('div')));
  const mode = state.mode;
  bars.forEach((b, i) => {
    const c = 1 - Math.abs(i - 15) / 16;
    const h = mode === 'speaking' ? 3 + 26 * amp * c * (.5 + .5 * Math.sin(t * 17 + i * 1.7)) ** 2 + 5 * amp * Math.random()
      : mode === 'thinking' ? 3 + 9 * Math.max(0, Math.sin(t * 6 - i * .5))
        : 2 + 3 * (.5 + .5 * Math.sin(t * 2 + i * .5));
    b.style.height = h.toFixed(1) + 'px';
    b.style.opacity = (.35 + .65 * c).toFixed(2);
  });
  $('clock').textContent = new Date().toLocaleTimeString('ru-RU');
  $('hud').style.opacity = state.visible === false ? 0 : 1;
  return amp;
}

// ---------------------------------------------------------------- голова
// Координаты лица в модели (высота модели = 2): рот ~0.115, подбородок ~-0.1, нос 0.28, глаза ~0.47.
export const FACE = { mouthY: 0.115, pivotY: 0.22, pivotZ: -0.2, frontZ: 0.45, cutY: -0.22, eyeY: 0.47, eyeX: 0.17 };

export const JAW_GLSL = `
  uniform float uMouthY, uPivotY, uPivotZ, uFrontZ;
  vec3 jawMove(vec3 p, float amp){
    float below = smoothstep(uMouthY + .012, uMouthY - .03, p.y) * smoothstep(-.42, -.12, p.y);
    float front = smoothstep(uPivotZ, uFrontZ, p.z);
    float ang = amp * .34 * below * front;
    vec2 r = vec2(p.y - uPivotY, p.z - uPivotZ);
    float c = cos(ang), s = sin(ang);
    r = vec2(c * r.x - s * r.y, s * r.x + c * r.y);
    return vec3(p.x, r.x + uPivotY, r.y + uPivotZ);
  }`;

export function faceUniforms() {
  return {
    uMouthY: { value: FACE.mouthY }, uPivotY: { value: FACE.pivotY }, uPivotZ: { value: FACE.pivotZ },
    uFrontZ: { value: FACE.frontZ }, uCutY: { value: FACE.cutY },
  };
}

export function loadHead(url = './models/head.glb') {
  return new Promise((resolve, reject) => new GLTFLoader().load(url, gltf => {
    let mesh = null;
    gltf.scene.traverse(o => { if (o.isMesh && !mesh) mesh = o; });
    const geo = mesh.geometry.clone();
    geo.applyMatrix4(mesh.matrixWorld);
    geo.computeBoundingBox();
    const size = new THREE.Vector3(), centre = new THREE.Vector3();
    geo.boundingBox.getSize(size); geo.boundingBox.getCenter(centre);
    geo.translate(-centre.x, -centre.y, -centre.z);
    const k = 2.0 / size.y;
    geo.scale(k, k, k);
    geo.computeVertexNormals();
    resolve(geo);
  }, undefined, reject));
}
