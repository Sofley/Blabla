// Оживлённая картинка в объёме (2.5D): ваша иллюстрация разложена по глубине — фон, большое лицо
// в тумане и герой — и плавно «облетается» камерой. Тело дышит, глаза моргают, рот двигается
// в такт речи Джарвиса, плывёт туман, блестит вода. Картинка показывается в полном разрешении.
//
// Картинка берётся из ui/user/poster.jpg (или .png) либо выбирается мышкой кнопкой на странице
// (запоминается в окне). Точки лица подобраны под присланный постер 1280×720; для другой
// картинки положите рядом ui/user/poster.json с такими же полями.
import * as THREE from 'three';
import { state, startLink, tick, lookAt } from './common.js';

const DEFAULT_POINTS = {
  size: [1280, 720],
  focusX: 640,                                             // что держать по центру узкого окна
  eyes: [[604, 266, 12, 7], [648, 259, 12, 7]],            // x, y, радиус по x, по y
  ghostEyes: [[585, 101, 26, 15], [670, 86, 24, 14]],
  mouth: [627, 304, 24, 13],                               // губы героя
  ghostMouth: [637, 150, 46, 26],                          // открытый рот большого лица
  head: [628, 262, 72, 66],
  body: [630, 440, 165, 150],
  hands: [630, 385, 45, 40],
  legs: [630, 590, 95, 50],
  ghost: [630, 120, 200, 135],
  water: 610,                                              // ниже — вода
};

const renderer = new THREE.WebGLRenderer({ antialias: false });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.setSize(innerWidth, innerHeight);
document.body.prepend(renderer.domElement);
const scene = new THREE.Scene();
const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

const v4 = () => ({ value: new THREE.Vector4() });
const U = {
  uTex: { value: null }, uSize: { value: new THREE.Vector2(1280, 720) }, uView: v4(),
  uTime: { value: 0 }, uAmp: { value: 0 }, uBreath: { value: 0 }, uBlink: { value: 0 }, uGhostBlink: { value: 0 },
  uBrow: { value: 0 }, uLook: { value: new THREE.Vector2() },
  uNod: { value: 0 }, uActive: { value: 0 }, uCam: { value: new THREE.Vector2() },
  uEyeL: v4(), uEyeR: v4(), uGEyeL: v4(), uGEyeR: v4(), uMouth: v4(), uGMouth: v4(),
  uHead: v4(), uBody: v4(), uHands: v4(), uLegs: v4(), uGhost: v4(), uWater: { value: 610 },
};

const mat = new THREE.ShaderMaterial({
  uniforms: U,
  vertexShader: `varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0., 1.); }`,
  fragmentShader: `
    uniform sampler2D uTex; uniform vec2 uSize, uCam; uniform vec4 uView;
    uniform float uTime, uAmp, uBreath, uBlink, uGhostBlink, uNod, uActive, uWater, uBrow;
    uniform vec2 uLook;
    uniform vec4 uEyeL, uEyeR, uGEyeL, uGEyeR, uMouth, uGMouth, uHead, uBody, uHands, uLegs, uGhost;
    varying vec2 vUv;

    float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
    float noise(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.-2.*f);
      return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y); }
    float fbm(vec2 p){ float v = 0., a = .5; for (int i = 0; i < 5; i++){ v += a*noise(p); p *= 2.02; a *= .5; } return v; }
    float ell(vec2 p, vec4 e){ vec2 d = (p - e.xy) / e.zw; return 1. - smoothstep(.55, 1., length(d)); }
    // выпуклость, как у шара: 1 в центре, 0 на краю
    float dome(vec2 p, vec4 e){ vec2 d = (p - e.xy) / e.zw; float r = dot(d, d); return r < 1. ? sqrt(1. - r) : 0.; }
    float soft(vec2 p, vec4 e){ vec2 d = (p - e.xy) / e.zw; return 1. - smoothstep(.85, 1.08, length(d)); }
    vec3 img(vec2 px){ return texture2D(uTex, vec2(px.x, uSize.y - px.y) / uSize).rgb; }

    // карта глубины: 0 — дальний фон, 1 — ближе всего к зрителю
    float depth(vec2 p){
      float d = .05 + .1 * smoothstep(uWater - 80., 720., p.y);             // фон, вода ближе
      d = max(d, (.22 + .1 * dome(p, uGhost)) * soft(p, uGhost));            // лицо в тумане
      float hero = max(max(soft(p, uBody), soft(p, uHead)), soft(p, uLegs));
      float vol = max(max(.55 + .3 * dome(p, uBody), .62 + .3 * dome(p, uHead)), .55 + .2 * dome(p, uLegs));
      vol = max(vol, (.85 + .15 * dome(p, uHands)) * soft(p, uHands));
      return mix(d, vol, hero);
    }

    vec3 blink(vec2 p, vec3 c, vec4 e, float b){
      vec2 d = (p - e.xy) / e.zw;
      if (length(d) > 1.25 || b <= 0.) return c;
      float lidY = -1.2 + b * 2.5;
      float lid = smoothstep(lidY + .25, lidY - .1, d.y) * smoothstep(1.25, .9, length(d));
      return mix(c, img(vec2(p.x, e.y - e.w * 1.45)), lid);
    }

    void main(){
      vec2 p = vec2(uView.x + vUv.x * uView.z, uView.y + (1. - vUv.y) * uView.w);   // пиксель картинки
      // объём: ближние слои сдвигаются сильнее дальних (дважды — для точности на краях)
      float z = depth(p);
      vec2 par = uCam * (z - .35);
      z = depth(p - par);
      p -= uCam * (z - .35);

      vec2 q = p;
      float wb = ell(p, uBody);
      vec2 anchor = vec2(uBody.x, uBody.y + uBody.w * .9);
      q = mix(q, anchor + (q - anchor) / (1. + uBreath * .014), wb);                // дыхание
      float wh = ell(p, uHead * vec4(1., 1., 1.25, 1.25));
      q.y -= wh * (uNod * 2.2);                                                      // кивки
      q.x -= wh * sin(uTime * .7) * .8;
      float wg = ell(p, uGhost);
      q = mix(q, uGhost.xy + (q - uGhost.xy) / (1. + sin(uTime * .6) * .008), wg);

      // рот героя: нижняя губа и подбородок уходят вниз, в щели темнота
      vec2 md = (p - uMouth.xy) / uMouth.zw;
      float mw = smoothstep(1., .35, length(md * vec2(1., .55)));
      float open = uAmp * 13.;
      q.y -= mw * smoothstep(-.1, .25, md.y) * open;
      // щёки и уголки рта: рот чуть растягивается в ширину
      q.x = mix(q.x, uMouth.x + (q.x - uMouth.x) / (1. + uAmp * .12), mw * smoothstep(.2, -.3, md.y));
      // брови поднимаются на ударных слогах и когда слушает
      for (int k = 0; k < 4; k++) {
        vec4 e = k == 0 ? uEyeL : k == 1 ? uEyeR : k == 2 ? uGEyeL : uGEyeR;
        float bw = ell(p, vec4(e.x, e.y - e.w * 1.7, e.z * 1.9, e.w * 1.9));
        q.y += bw * uBrow * (k < 2 ? 3. : 6.);
      }
      // рот большого лица растягивается
      vec2 gd = (p - uGMouth.xy) / uGMouth.zw;
      float gw = smoothstep(1.3, .4, length(gd));
      q.y = mix(q.y, uGMouth.y + (q.y - uGMouth.y) / (1. + uAmp * .9), gw);
      // рябь на воде
      float wl = smoothstep(uWater - 10., uWater + 30., p.y) * (1. - soft(p, uLegs));
      q.x += wl * sin(p.y * .35 + uTime * 2.) * 1.2;

      // зрачки смотрят на курсор: содержимое глаза сдвигается внутри глазницы
      for (int k = 0; k < 4; k++) {
        vec4 e = k == 0 ? uEyeL : k == 1 ? uEyeR : k == 2 ? uGEyeL : uGEyeR;
        float ew = 1. - smoothstep(.45, .95, length((p - e.xy) / e.zw));
        q -= ew * uLook * vec2(e.z * .45, e.w * .35);
      }
      vec3 c = img(q);
      float gap = mw * smoothstep(-.05, .1, md.y) * smoothstep(open * .16 + .1, open * .06, md.y);
      c = mix(c, vec3(.1, .045, .04), gap * smoothstep(.0, .3, uAmp) * .92);

      c = blink(p, c, uEyeL, uBlink);
      c = blink(p, c, uEyeR, uBlink);
      c = blink(p, c, uGEyeL, uGhostBlink);
      c = blink(p, c, uGEyeR, uGhostBlink);

      // свет с той стороны, куда смотрит камера, — подчёркивает объём героя
      float hero = max(soft(p, uBody), soft(p, uHead));
      vec2 nrm = (p - uBody.xy) / uBody.zw;
      c *= 1. + hero * dot(normalize(vec2(-uCam.x, uCam.y) + 1e-4), nrm) * .05 * length(uCam) / 6.;

      // туман плывёт вокруг героя (не поверх него)
      float m = fbm(vec2(p.x * .006 - uTime * .025, p.y * .012 + uTime * .01));
      float mist = smoothstep(.5, .8, m) * (1. - hero) * (.25 + .25 * smoothstep(400., 60., p.y));
      c = mix(c, vec3(.97, .96, .93), mist * .5);
      c += wl * smoothstep(.82, .97, noise(vec2(p.x * .06 + uTime * .3, p.y * .5))) * .16;
      c += vec3(.12, .08, .02) * wg * uActive * .6;
      gl_FragColor = vec4(c, 1.);
    }`,
});
scene.add(new THREE.Mesh(new THREE.PlaneGeometry(2, 2), mat));

// ---------------------------------------------------------------- картинка и точки
let P = DEFAULT_POINTS;
function applyPoints() {
  const set = (u, a) => u.value.set(...a);
  U.uSize.value.set(...P.size);
  set(U.uEyeL, P.eyes[0]); set(U.uEyeR, P.eyes[1]);
  set(U.uGEyeL, P.ghostEyes[0]); set(U.uGEyeR, P.ghostEyes[1]);
  set(U.uMouth, P.mouth); set(U.uGMouth, P.ghostMouth);
  set(U.uHead, P.head); set(U.uBody, P.body); set(U.uHands, P.hands); set(U.uLegs, P.legs); set(U.uGhost, P.ghost);
  U.uWater.value = P.water;
  fit();
}
// картинка по высоте окна, по центру — focusX; небольшой запас по краям для облёта камеры
const MARGIN = 10;
function fit() {
  const [w, h] = P.size;
  const winAspect = innerWidth / innerHeight;
  let vh = h - MARGIN * 2, vw = vh * winAspect;
  if (vw > w - MARGIN * 2) { vw = w - MARGIN * 2; vh = vw / winAspect; }
  const x0 = Math.min(Math.max(P.focusX - vw / 2, MARGIN), w - vw - MARGIN);
  U.uView.value.set(x0, (h - vh) / 2, vw, vh);
}

async function loadImage() {
  const tryUrl = url => new Promise(res => new THREE.TextureLoader().load(url, t => res(t), undefined, () => res(null)));
  let tex = await tryUrl('./user/poster.jpg') || await tryUrl('./user/poster.png');
  if (!tex) {
    let saved = null;
    try { saved = localStorage.getItem('jarvis-poster'); } catch (e) { /* нет хранилища */ }
    if (saved) tex = await tryUrl(saved);
  }
  try {
    const r = await fetch('./user/poster.json');
    if (r.ok) P = { ...DEFAULT_POINTS, ...(await r.json()) };
  } catch (e) { /* свои точки не заданы */ }
  if (!tex) { document.getElementById('pick').style.display = 'flex'; return; }
  tex.colorSpace = THREE.NoColorSpace;
  tex.generateMipmaps = false;               // без размытия: картинка в исходном качестве
  tex.minFilter = THREE.LinearFilter;
  tex.magFilter = THREE.LinearFilter;
  tex.anisotropy = renderer.capabilities.getMaxAnisotropy();
  U.uTex.value = tex;
  applyPoints();
  window.__headReady = true;
}
document.getElementById('file').addEventListener('change', e => {
  const f = e.target.files[0];
  if (!f) return;
  const rd = new FileReader();
  rd.onload = () => {
    try { localStorage.setItem('jarvis-poster', rd.result); } catch (err) { alert('Картинка слишком большая'); }
    location.reload();
  };
  rd.readAsDataURL(f);
});
loadImage();

// ---------------------------------------------------------------- анимация
startLink({ defaultTheme: 'голубой', themeChanged: () => {} });
const clock = new THREE.Clock();
let blinkStart = -9, nextBlink = 2.5, gBlinkStart = -9, gNextBlink = 4;
const lid = (t, start) => { const k = (t - start) / .18; return k < 0 || k > 1 ? 0 : Math.sin(k * Math.PI); };
const cam = new THREE.Vector2();
const fixedT = new URLSearchParams(location.search).get('cam');   // для снимков: ?cam=-1 / 1

function frame() {
  requestAnimationFrame(frame);
  const now = performance.now();
  const t = clock.getElapsedTime();
  const mode = state.mode;
  const amp = tick(now, t);
  if (!U.uTex.value) return;

  if (t > nextBlink) { blinkStart = t; nextBlink = t + 2.2 + Math.random() * 3.5; }
  if (t > gNextBlink) { gBlinkStart = t; gNextBlink = t + 3 + Math.random() * 4; }
  // плавный облёт камеры (в пикселях картинки), сильнее когда Джарвис активен
  const reach = 7 + 3 * U.uActive.value;
  const target = fixedT !== null ? new THREE.Vector2(Number(fixedT) * reach, 0)
    : new THREE.Vector2(Math.sin(t * .31) * reach, Math.sin(t * .23 + 1) * reach * .45);
  cam.lerp(target, .08);
  U.uCam.value.copy(cam);
  U.uTime.value = t;
  U.uAmp.value = amp;
  const lk = lookAt();
  U.uLook.value.set(lk.x, lk.y);
  U.uBreath.value = Math.sin(t * 1.6);
  U.uBlink.value = lid(t, blinkStart);
  U.uGhostBlink.value = lid(t, gBlinkStart);
  // мимика: брови от ударных слогов, удивление когда слушает, хмурится когда думает
  const browTarget = mode === 'speaking' ? Math.max(0, amp - .45) * 2 : mode === 'listening' ? .7 : mode === 'thinking' ? -.5 : 0;
  U.uBrow.value += (browTarget - U.uBrow.value) * .25;
  U.uNod.value = Math.sin(t * 1.6) * .4 + (mode === 'speaking' ? Math.sin(t * 7) * amp * 2.2 : 0)
    + (mode === 'listening' ? .8 : 0);
  const active = mode === 'idle' ? 0 : mode === 'speaking' ? .6 + amp * .4 : .5;
  U.uActive.value += (active - U.uActive.value) * .05;
  renderer.render(scene, camera);
}
frame();

addEventListener('resize', () => { renderer.setSize(innerWidth, innerHeight); fit(); });
