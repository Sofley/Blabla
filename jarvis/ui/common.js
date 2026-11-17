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

let speakStart = 0, envelope = [0], lastSpeakId = -1, amp = 0, demo = params.has('demo');
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
    } catch (e) { demo = true; }
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
