// Джарвис: голова-голограмма в прозрачной энергетической трубе командного центра.
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { THEMES, state, startLink, tick, JAW_GLSL, faceUniforms, loadHead } from './common.js';

// ---------------------------------------------------------------- рендер
const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.setSize(innerWidth, innerHeight);
document.body.prepend(renderer.domElement);

const scene = new THREE.Scene();
scene.fog = new THREE.FogExp2(0x02050a, 0.055);
const camera = new THREE.PerspectiveCamera(34, innerWidth / innerHeight, 0.1, 100);
const camBase = new THREE.Vector3(0, 0.75, 13.2);
camera.position.copy(camBase);

const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(innerWidth, innerHeight), 0.8, 0.5, 0.35);
composer.addPass(bloom);
composer.addPass(new OutputPass());

const color = new THREE.Color().setRGB(...THEMES['голубой'].map(v => v / 255));
const targetColor = color.clone();
const U = {
  uTime: { value: 0 }, uColor: { value: color }, uAmp: { value: 0 }, uBright: { value: 1 }, uActive: { value: 0 },
};

scene.add(new THREE.AmbientLight(0x223344, .6));
const themed = [];  // материалы, которые перекрашиваются вместе с темой
const tint = m => { themed.push(m); return m; };
const coreLight = new THREE.PointLight(color, 25, 12, 1.6);
coreLight.position.set(0, 0.3, 0.6);
scene.add(coreLight);

// ---------------------------------------------------------------- пол с сеткой
const floorMat = new THREE.ShaderMaterial({
  uniforms: U, transparent: true, depthWrite: false,
  vertexShader: `varying vec3 vP; void main(){ vP = (modelMatrix*vec4(position,1.)).xyz;
    gl_Position = projectionMatrix*viewMatrix*vec4(vP,1.); }`,
  fragmentShader: `uniform vec3 uColor; uniform float uTime, uActive; varying vec3 vP;
    void main(){
      vec2 q = vP.xz * 1.6;
      vec2 g = abs(fract(q - .5) - .5) / fwidth(q);
      float line = 1. - min(min(g.x, g.y), 1.);
      float r = length(vP.xz);
      float fade = exp(-r * .22);
      float ring = exp(-pow((r - 2.3) * 7., 2.)) + exp(-pow((r - 3.1 - .2*sin(uTime)) * 12., 2.)) * .6;
      float pulse = exp(-pow((r - mod(uTime * 1.6, 9.)) * 3., 2.)) * (.25 + uActive * .5);
      vec3 c = uColor * (line * .06 * fade + ring * .35 + pulse * fade * .3);
      gl_FragColor = vec4(c, clamp(fade + ring, 0., 1.));
    }`,
});
const floor = new THREE.Mesh(new THREE.PlaneGeometry(40, 40), floorMat);
floor.rotation.x = -Math.PI / 2;
floor.position.y = -2.35;
scene.add(floor);

// ---------------------------------------------------------------- дальние пульты командного центра
const consoles = new THREE.Group();
const lightsGeo = new THREE.PlaneGeometry(0.12, 0.05);
const blinkers = [];
for (let side of [-1, 1]) {
  for (let k = 0; k < 3; k++) {
    const x = side * (4.2 + k * 1.4), z = -2.5 - k * 1.6;
    const desk = new THREE.Mesh(new THREE.BoxGeometry(1.3, 0.8, 0.6),
      new THREE.MeshStandardMaterial({ color: 0x0a1018, metalness: .8, roughness: .35 }));
    desk.position.set(x, -1.95, z);
    desk.rotation.y = -side * 0.5;
    consoles.add(desk);
    const screen = new THREE.Mesh(new THREE.PlaneGeometry(1.1, 0.6),
      tint(new THREE.MeshBasicMaterial({ color, transparent: true, opacity: .06 })));
    screen.position.set(0, 0.75, 0.05);
    screen.rotation.x = -0.25;
    desk.add(screen);
    for (let n = 0; n < 6; n++) {
      const m = new THREE.Mesh(lightsGeo, n % 3 ? tint(new THREE.MeshBasicMaterial({ color })) : new THREE.MeshBasicMaterial({ color: 0xff4060 }));
      m.position.set(-0.5 + n * 0.2, 0.25, 0.31);
      m.userData.phase = Math.random() * 10;
      desk.add(m);
      blinkers.push(m);
    }
  }
}
scene.add(consoles);

// ---------------------------------------------------------------- труба
const TUBE_R = 1.35, TUBE_BOTTOM = -1.95, TUBE_TOP = 2.55, TUBE_H = TUBE_TOP - TUBE_BOTTOM;
const tubeMat = new THREE.ShaderMaterial({
  uniforms: U, transparent: true, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending,
  vertexShader: `varying vec3 vN, vV; varying vec2 vUv;
    void main(){ vUv = uv; vec4 mv = modelViewMatrix*vec4(position,1.);
      vN = normalize(normalMatrix*normal); vV = normalize(-mv.xyz); gl_Position = projectionMatrix*mv; }`,
  fragmentShader: `uniform vec3 uColor; uniform float uTime, uActive; varying vec3 vN, vV; varying vec2 vUv;
    void main(){
      float f = pow(1. - abs(dot(normalize(vN), normalize(vV))), 3.);
      float streak = pow(.5 + .5*sin(vUv.x * 6.2831 * 18.), 24.) * .08;
      float band = exp(-pow((fract(vUv.y - uTime * .12) - .5) * 14., 2.)) * (.08 + .22 * uActive);
      float hex = step(.96, fract(vUv.y * 40.)) * .05;
      float ends = smoothstep(.12, 0., vUv.y) + smoothstep(.88, 1., vUv.y);
      vec3 c = uColor * (f * .35 + streak * .4 + band * .35 + hex * .4 + .004 + ends * .06);
      gl_FragColor = vec4(c, 1.);
    }`,
});
const tube = new THREE.Mesh(new THREE.CylinderGeometry(TUBE_R, TUBE_R, TUBE_H, 96, 1, true), tubeMat);
tube.position.y = (TUBE_TOP + TUBE_BOTTOM) / 2;
scene.add(tube);

// столб света внутри
const beamMat = new THREE.ShaderMaterial({
  uniforms: U, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
  vertexShader: `varying vec2 vUv; varying vec3 vN, vV; void main(){ vUv = uv; vec4 mv = modelViewMatrix*vec4(position,1.);
    vN = normalize(normalMatrix*normal); vV = normalize(-mv.xyz); gl_Position = projectionMatrix*mv; }`,
  fragmentShader: `uniform vec3 uColor; uniform float uTime, uActive, uAmp; varying vec2 vUv; varying vec3 vN, vV;
    void main(){
      float core = pow(abs(dot(normalize(vN), normalize(vV))), 2.);
      float fall = smoothstep(0., .25, vUv.y) * smoothstep(1., .7, vUv.y);
      float waves = .7 + .3 * sin(vUv.y * 30. - uTime * 3.);
      gl_FragColor = vec4(uColor * core * fall * waves * (.008 + .015 * uActive + .02 * uAmp), 1.);
    }`,
});
const beam = new THREE.Mesh(new THREE.CylinderGeometry(TUBE_R * 0.92, TUBE_R * 0.92, TUBE_H, 48, 1, true), beamMat);
beam.position.copy(tube.position);
scene.add(beam);

// основание и крышка
const metal = new THREE.MeshStandardMaterial({ color: 0x111a24, metalness: .9, roughness: .3 });
function cap(y, flip) {
  const g = new THREE.Group();
  const base = new THREE.Mesh(new THREE.CylinderGeometry(TUBE_R + .25, TUBE_R + .45, .42, 96), metal);
  g.add(base);
  const step = new THREE.Mesh(new THREE.CylinderGeometry(TUBE_R + .5, TUBE_R + .62, .14, 96), metal);
  step.position.y = flip ? .26 : -.26;
  g.add(step);
  const glowMat = tint(new THREE.MeshBasicMaterial({ color }));
  for (const [r, dy, w] of [[TUBE_R + .02, flip ? -.22 : .22, .035], [TUBE_R + .47, 0, .02], [TUBE_R + .6, flip ? .2 : -.2, .015]]) {
    const ring = new THREE.Mesh(new THREE.TorusGeometry(r, w, 12, 128), glowMat);
    ring.rotation.x = Math.PI / 2;
    ring.position.y = dy;
    g.add(ring);
  }
  // огоньки по кругу
  const dots = new THREE.InstancedMesh(new THREE.BoxGeometry(.06, .06, .02), glowMat, 36);
  const m4 = new THREE.Matrix4();
  for (let i = 0; i < 36; i++) {
    const a = i / 36 * Math.PI * 2;
    m4.makeRotationY(-a).setPosition(Math.cos(a) * (TUBE_R + .36), 0, Math.sin(a) * (TUBE_R + .36));
    dots.setMatrixAt(i, m4);
  }
  g.add(dots);
  g.position.y = y;
  g.userData.glow = glowMat;
  scene.add(g);
  return g;
}
const bottomCap = cap(TUBE_BOTTOM - .2, false);
const topCap = cap(TUBE_TOP + .2, true);

// ---------------------------------------------------------------- частицы энергии
const P_COUNT = 520;
const pPos = new Float32Array(P_COUNT * 3), pSpeed = new Float32Array(P_COUNT);
for (let i = 0; i < P_COUNT; i++) {
  const r = Math.sqrt(Math.random()) * (TUBE_R - .1), a = Math.random() * Math.PI * 2;
  pPos.set([Math.cos(a) * r, TUBE_BOTTOM + Math.random() * TUBE_H, Math.sin(a) * r], i * 3);
  pSpeed[i] = .15 + Math.random() * .5;
}
const pGeo = new THREE.BufferGeometry();
pGeo.setAttribute('position', new THREE.BufferAttribute(pPos, 3));
const particles = new THREE.Points(pGeo, new THREE.ShaderMaterial({
  uniforms: U, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
  vertexShader: `uniform float uTime; varying float vA; void main(){
      vec4 mv = modelViewMatrix*vec4(position,1.); gl_Position = projectionMatrix*mv;
      gl_PointSize = 34. / -mv.z; vA = smoothstep(${TUBE_BOTTOM.toFixed(2)}, ${(TUBE_BOTTOM + 1).toFixed(2)}, position.y)
        * smoothstep(${TUBE_TOP.toFixed(2)}, ${(TUBE_TOP - 1).toFixed(2)}, position.y); }`,
  fragmentShader: `uniform vec3 uColor; varying float vA; void main(){
      float d = length(gl_PointCoord - .5); float a = smoothstep(.5, 0., d);
      gl_FragColor = vec4(uColor * a * vA * .7, 1.); }`,
}));
scene.add(particles);

// ---------------------------------------------------------------- кольца-интерфейс вокруг головы
const hudRings = [];
for (const [r, w, tilt, seg] of [[1.05, .012, .25, 1], [1.12, .006, -.35, .35], [.98, .02, .05, .18]]) {
  const geo = new THREE.RingGeometry(r, r + w, 128, 1, 0, Math.PI * 2 * seg);
  const ring = new THREE.Mesh(geo, tint(new THREE.MeshBasicMaterial({
    color, transparent: true, opacity: .5, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, depthWrite: false })));
  ring.rotation.x = Math.PI / 2 + tilt;
  ring.position.y = .1;
  scene.add(ring);
  hudRings.push(ring);
}

// ---------------------------------------------------------------- голова
const head = new THREE.Group();
const HEAD_SCALE = 1.95, HEAD_Y = -0.5;
head.position.y = HEAD_Y;
head.scale.setScalar(HEAD_SCALE);
scene.add(head);
const headMat = new THREE.ShaderMaterial({
  uniforms: {
    ...U, ...faceUniforms(),
  },
  transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
  vertexShader: `
    uniform float uAmp, uTime;
    varying vec3 vN, vV, vP;
    ${JAW_GLSL}
    void main(){
      vec3 p = jawMove(position, uAmp);
      float glitch = step(.985, fract(sin(floor(uTime * 14.) * 91.7) * 4375.)) * step(.5, fract(p.y * 6. + uTime));
      p.x += glitch * .035;
      vec4 mv = modelViewMatrix * vec4(p, 1.);
      vN = normalize(normalMatrix * normal); vV = normalize(-mv.xyz); vP = position;
      gl_Position = projectionMatrix * mv;
    }`,
  fragmentShader: `
    uniform vec3 uColor; uniform float uTime, uAmp, uBright, uCutY, uMouthY;
    varying vec3 vN, vV, vP;
    void main(){
      float keep = smoothstep(uCutY - .22, uCutY, vP.y);
      if (keep <= 0.) discard;
      vec3 n = normalize(vN), v = normalize(vV);
      float f = pow(1. - max(dot(n, v), 0.), 2.4);
      float light = max(dot(n, normalize(vec3(.3, .6, 1.))), 0.);
      float scan = .62 + .38 * sin(vP.y * 160. - uTime * 6.);
      float band = exp(-pow((fract(vP.y * .35 - uTime * .22) - .5) * 9., 2.));
      float flick = .93 + .07 * sin(uTime * 41.) * sin(uTime * 17.);
      vec3 c = uColor * ((.012 + light * .11 + f * .55) * scan + band * .06) * flick * uBright;
      // свечение губ, когда говорит
      float lips = exp(-pow((vP.y - uMouthY) / .018, 2.)) * smoothstep(.13, .03, abs(vP.x)) * smoothstep(.4, .52, vP.z);
      c += uColor * lips * uAmp * .28;
      gl_FragColor = vec4(c * keep, 1.);
    }`,
});
const depthMat = new THREE.ShaderMaterial({
  uniforms: headMat.uniforms, colorWrite: false,
  vertexShader: headMat.vertexShader,
  fragmentShader: 'uniform float uCutY; varying vec3 vP; void main(){ if (vP.y < uCutY - .1) discard; gl_FragColor = vec4(0.); }',
});

loadHead().then(geo => {
  const back = new THREE.Mesh(geo, depthMat);
  back.renderOrder = 1;
  const holo = new THREE.Mesh(geo, headMat);
  holo.renderOrder = 2;
  head.add(back, holo);
  window.__headReady = true;
});

startLink({ defaultTheme: 'голубой', themeChanged: c => targetColor.copy(c) });

// ---------------------------------------------------------------- анимация
const clock = new THREE.Clock();
function frame() {
  requestAnimationFrame(frame);
  const now = performance.now();
  const t = clock.getElapsedTime();
  const mode = state.mode;

  const amp = tick(now, t);

  color.lerp(targetColor, .06);
  for (const m of themed) m.color.copy(color);
  coreLight.color.copy(color);
  U.uTime.value = t;
  U.uAmp.value = amp;
  const active = mode === 'idle' ? 0 : mode === 'speaking' ? .7 + amp * .5 : mode === 'thinking' ? .8 : .6;
  U.uActive.value += (active - U.uActive.value) * .05;
  U.uBright.value = (mode === 'idle' ? .8 : 1) + amp * .55;
  coreLight.intensity = 4 + 8 * amp + 3 * U.uActive.value;
  bloom.strength = .75 + .35 * amp + .15 * U.uActive.value;

  // голова: дыхание, лёгкие повороты, кивки во время речи
  head.position.y = HEAD_Y + Math.sin(t * .9) * .05;
  head.rotation.y = Math.sin(t * .23) * .22 + Math.sin(t * .61) * .05;
  head.rotation.x = Math.sin(t * .4) * .04 - amp * .05;
  head.rotation.z = Math.sin(t * .31) * .02;

  // частицы поднимаются
  const speed = mode === 'thinking' ? 3.2 : mode === 'speaking' ? 1.6 + amp * 2 : mode === 'listening' ? 1.3 : .6;
  for (let i = 0; i < P_COUNT; i++) {
    let y = pPos[i * 3 + 1] + pSpeed[i] * speed * .016;
    if (y > TUBE_TOP) y = TUBE_BOTTOM;
    pPos[i * 3 + 1] = y;
  }
  pGeo.attributes.position.needsUpdate = true;

  // кольца
  const rs = mode === 'thinking' ? 2.2 : mode === 'listening' ? .8 : .3;
  hudRings.forEach((r, i) => {
    r.rotation.z += (i % 2 ? -1 : 1) * rs * .01 * (i + 1);
    const pulse = mode === 'listening' ? .5 + .5 * Math.sin(t * 4 + i) : 1;
    r.material.opacity = ((.1 + .25 * U.uActive.value) * pulse + amp * .15) * .6;
    r.position.y = .1 + Math.sin(t * .7 + i) * .08;
  });
  topCap.rotation.y = t * .1 * rs;
  bottomCap.rotation.y = -t * .1 * rs;
  blinkers.forEach(b => { b.visible = Math.sin(t * 2 + b.userData.phase * 3) > -.3; });

  // камера медленно плывёт
  camera.position.x = camBase.x + Math.sin(t * .13) * .35;
  camera.position.y = camBase.y + Math.sin(t * .17) * .12;
  camera.lookAt(0, .05, 0);

  composer.render();
}
frame();

addEventListener('resize', () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
  composer.setSize(innerWidth, innerHeight);
});
