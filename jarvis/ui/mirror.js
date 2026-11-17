// Джарвис: лицо-маска проступает из клубящейся глубины волшебного зеркала в резной золотой раме.
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { THEMES, state, startLink, tick, JAW_GLSL, faceUniforms, loadHead } from './common.js';

const RX = 1.55, RY = 2.05, MY = 0.25;   // полуоси и центр зеркала

// ---------------------------------------------------------------- рендер
const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.setSize(innerWidth, innerHeight);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = .9;
document.body.prepend(renderer.domElement);

const scene = new THREE.Scene();
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = .55;
const camera = new THREE.PerspectiveCamera(30, innerWidth / innerHeight, 0.1, 100);
const camBase = new THREE.Vector3(0, 0.6, 15.2);
camera.position.copy(camBase);

const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(innerWidth, innerHeight), 0.35, 0.4, 0.92);
composer.addPass(bloom);
composer.addPass(new OutputPass());

const color = new THREE.Color().setRGB(...THEMES['зеленый'].map(v => v / 255));
const targetColor = color.clone();
const U = {
  uTime: { value: 0 }, uColor: { value: color }, uAmp: { value: 0 }, uActive: { value: 0 }, uAppear: { value: .35 },
  uSwirl: { value: .3 },
};

// ---------------------------------------------------------------- стена и свет
const wall = new THREE.Mesh(new THREE.PlaneGeometry(30, 22), new THREE.ShaderMaterial({
  uniforms: U,
  vertexShader: `varying vec2 vP; void main(){ vP = position.xy; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.); }`,
  fragmentShader: `uniform vec3 uColor; uniform float uTime, uActive; varying vec2 vP;
    float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
    void main(){
      vec2 p = vP - vec2(0., ${MY.toFixed(2)});
      float r = length(p * vec2(1., .8));
      float glow = exp(-r * .55) * (.5 + .5 * uActive);
      float flick = .93 + .07 * sin(uTime * 7.3) * sin(uTime * 3.1);
      // узор обоев: ромбы
      vec2 q = abs(fract(vP * vec2(.9, .65)) - .5);
      float pat = smoothstep(.02, 0., abs(q.x + q.y - .42)) * .5;
      vec3 base = vec3(.035, .022, .018) * (1. + pat);
      vec3 c = base * flick + vec3(.32, .2, .09) * glow * .09 * flick + uColor * glow * .03 * uActive;
      c *= 1. - smoothstep(4., 11., r);
      gl_FragColor = vec4(c + (h(vP * 50. + uTime) - .5) * .006, 1.);
    }`,
}));
wall.position.z = -1.2;
scene.add(wall);

scene.add(new THREE.AmbientLight(0x30241a, .5));
const warm = new THREE.PointLight(0xffc27a, 7, 20, 1.5);
warm.position.set(-3.2, 3.5, 4);
scene.add(warm);
const warm2 = new THREE.PointLight(0xff9a50, 3, 20, 1.5);
warm2.position.set(3.5, -1.5, 3.5);
scene.add(warm2);
const magic = new THREE.PointLight(color, 4, 8, 1.8);
magic.position.set(0, MY, 1.2);
scene.add(magic);

// ---------------------------------------------------------------- стекло с клубящейся дымкой
const glass = new THREE.Mesh(new THREE.CircleGeometry(1, 128), new THREE.ShaderMaterial({
  uniforms: U, depthWrite: false,
  vertexShader: `varying vec2 vUv; void main(){ vUv = position.xy; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.); }`,
  fragmentShader: `uniform vec3 uColor; uniform float uTime, uActive, uAmp, uAppear, uSwirl; varying vec2 vUv;
    float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
    float noise(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.-2.*f);
      return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y); }
    float fbm(vec2 p){ float v = 0., a = .5; for (int i = 0; i < 5; i++){ v += a*noise(p); p *= 2.03; a *= .5; } return v; }
    void main(){
      vec2 p = vUv;
      float r = length(p);
      // вихрь: чем ближе к центру, тем сильнее закручено
      float ang = uTime * uSwirl * .35 + (1. - r) * 2.2 * (.6 + uSwirl);
      mat2 rot = mat2(cos(ang), -sin(ang), sin(ang), cos(ang));
      vec2 q = rot * p * 2.2;
      float smoke = fbm(q + vec2(uTime * .05, -uTime * .07));
      smoke = smoothstep(.35, .95, fbm(q * 1.4 + smoke * 1.8 - uTime * .04));
      vec3 deep = vec3(.01, .02, .03);
      vec3 tint = mix(uColor, vec3(.55, .9, .8), .35);
      vec3 c = deep + tint * smoke * (.08 + .22 * uActive + .25 * uAmp);
      // свечение вокруг лица
      c += tint * exp(-r * r * 3.) * (.05 + .2 * uAppear + .2 * uAmp);
      // блик на стекле
      float streak = exp(-pow((p.x + p.y * .55 + .45) * 7., 2.)) * smoothstep(1., .3, r);
      c += vec3(.9, .95, 1.) * streak * .05;
      // тёмный край у рамы
      c *= smoothstep(1.02, .7, r) * .85 + .15;
      gl_FragColor = vec4(c, 1.);
    }`,
}));
glass.scale.set(RX, RY, 1);
glass.position.set(0, MY, 0);
scene.add(glass);

// ---------------------------------------------------------------- резная золотая рама
const gold = new THREE.MeshStandardMaterial({ color: 0xe2b356, metalness: 1, roughness: .26, envMapIntensity: .7 });
const darkGold = new THREE.MeshStandardMaterial({ color: 0x9a6a22, metalness: 1, roughness: .4, envMapIntensity: .5 });

class Ellipse3 extends THREE.Curve {
  constructor(rx, ry, z = 0) { super(); this.rx = rx; this.ry = ry; this.z = z; }
  getPoint(t, target = new THREE.Vector3()) {
    const a = t * Math.PI * 2;
    return target.set(Math.cos(a) * this.rx, Math.sin(a) * this.ry, this.z);
  }
}
const frame = new THREE.Group();
frame.position.set(0, MY, 0);
scene.add(frame);
for (const [dr, rad, mat, z] of [[.02, .055, gold, .05], [.17, .15, gold, .1], [.33, .05, darkGold, .06], [.42, .07, gold, .04]]) {
  frame.add(new THREE.Mesh(new THREE.TubeGeometry(new Ellipse3(RX + dr, RY + dr, z), 220, rad, 20, true), mat));
}
// бусины по кругу
const BEADS = 64;
const beads = new THREE.InstancedMesh(new THREE.SphereGeometry(.05, 16, 12), gold, BEADS);
const m4 = new THREE.Matrix4();
for (let i = 0; i < BEADS; i++) {
  const a = i / BEADS * Math.PI * 2;
  m4.makeTranslation(Math.cos(a) * (RX + .27), Math.sin(a) * (RY + .27), .14);
  beads.setMatrixAt(i, m4);
}
frame.add(beads);
// завитки-волюты
function scroll(x, y, s, flip, rot = 0) {
  const g = new THREE.Group();
  const big = new THREE.Mesh(new THREE.TorusGeometry(.26, .055, 14, 48, Math.PI * 1.6), gold);
  const small = new THREE.Mesh(new THREE.TorusGeometry(.12, .04, 12, 36, Math.PI * 1.7), gold);
  small.position.set(.2, -.16, 0);
  small.rotation.z = Math.PI;
  const knob = new THREE.Mesh(new THREE.SphereGeometry(.06, 16, 12), gold);
  knob.position.set(.27, -.2, 0);
  g.add(big, small, knob);
  g.scale.set(flip ? -s : s, s, s);
  g.rotation.z = rot;
  g.position.set(x, y, .12);
  frame.add(g);
}
scroll(-.38, RY + .62, 1.1, false, -.2); scroll(.38, RY + .62, 1.1, true, .2);
scroll(-.32, -RY - .55, .85, false, Math.PI + .3); scroll(.32, -RY - .55, .85, true, -Math.PI - .3);
scroll(-RX - .55, .35, .7, false, Math.PI / 2); scroll(RX + .55, .35, .7, true, -Math.PI / 2);
// камни
const gemMat = new THREE.MeshStandardMaterial({ color, emissive: color, emissiveIntensity: .8, metalness: .2, roughness: .1 });
const crown = new THREE.Mesh(new THREE.OctahedronGeometry(.17), gemMat);
crown.scale.set(1, 1.4, .6);
crown.position.set(0, RY + .68, .22);
frame.add(crown);
const crownTop = new THREE.Mesh(new THREE.SphereGeometry(.09, 16, 12), gold);
crownTop.position.set(0, RY + 1.0, .15);
frame.add(crownTop);
const gems = [crown];
for (const [x, y, s] of [[0, -RY - .55, .1], [-RX - .45, .35, .08], [RX + .45, .35, .08]]) {
  const gem = new THREE.Mesh(new THREE.OctahedronGeometry(s), gemMat);
  gem.position.set(x, y, .2);
  frame.add(gem);
  gems.push(gem);
}

// ---------------------------------------------------------------- лицо-маска
const head = new THREE.Group();
const HEAD_SCALE = 1.95, HEAD_Y = MY - .82, HEAD_Z = -1.1;
head.scale.setScalar(HEAD_SCALE);
head.position.set(0, HEAD_Y, HEAD_Z);
scene.add(head);
const faceU = { ...U, ...faceUniforms() };
const vert = `
  uniform float uAmp, uTime;
  varying vec3 vN, vV, vP;
  ${JAW_GLSL}
  void main(){
    vec3 p = jawMove(position, uAmp);
    vec4 mv = modelViewMatrix * vec4(p, 1.);
    vN = normalize(normalMatrix * normal); vV = normalize(-mv.xyz); vP = position;
    gl_Position = projectionMatrix * mv;
  }`;
const maskMat = new THREE.ShaderMaterial({
  uniforms: faceU, transparent: true, depthWrite: false,
  vertexShader: vert,
  fragmentShader: `
    uniform vec3 uColor; uniform float uTime, uAmp, uAppear, uCutY, uMouthY;
    varying vec3 vN, vV, vP;
    void main(){
      vec3 n = normalize(vN), v = normalize(vV);
      float facing = max(dot(n, v), 0.);
      // от лица остаётся только маска: передняя часть, без шеи и затылка
      float mask = smoothstep(.0, .45, vP.z) * smoothstep(uCutY - .05, uCutY + .18, vP.y);
      // овал маски: края мягко растворяются
      mask *= smoothstep(.6, .4, length((vP.xy - vec2(0., .38)) * vec2(1., .66)));
      mask *= smoothstep(.05, .55, facing);
      if (mask <= .002) discard;
      float key = max(dot(n, normalize(vec3(-.45, .55, .9))), 0.);
      float fill = max(dot(n, normalize(vec3(.6, -.2, .7))), 0.);
      vec3 pale = mix(vec3(.82, .93, .86), uColor, .22);
      vec3 c = pale * (.1 + key * .7) + mix(pale, uColor, .6) * fill * .16;
      // тёмные глазницы
      float eyes = exp(-pow((abs(vP.x) - .17) / .07, 2.) - pow((vP.y - .47) / .045, 2.));
      c *= 1. - eyes * .55;
      // рот: щель светится, когда говорит
      float lips = exp(-pow((vP.y - uMouthY) / .016, 2.)) * smoothstep(.13, .03, abs(vP.x)) * smoothstep(.4, .52, vP.z);
      c = mix(c, uColor * .9 + .2, lips * uAmp * .6);
      // лицо растворяется в дымке по краям
      float a = mask * uAppear * (.82 + .18 * sin(uTime * 1.3 + vP.y * 3.));
      gl_FragColor = vec4(c, a);
    }`,
});
const maskDepth = new THREE.ShaderMaterial({
  uniforms: faceU, colorWrite: false, vertexShader: vert,
  fragmentShader: `uniform float uCutY; varying vec3 vP; void main(){ if (vP.z < .05 || vP.y < uCutY) discard; gl_FragColor = vec4(0.); }`,
});
loadHead().then(geo => {
  const d = new THREE.Mesh(geo, maskDepth); d.renderOrder = 1;
  const m = new THREE.Mesh(geo, maskMat); m.renderOrder = 2;
  head.add(d, m);
  window.__headReady = true;
});

// ---------------------------------------------------------------- золотая пыль
const DUST = 160;
const dPos = new Float32Array(DUST * 3), dVel = new Float32Array(DUST);
for (let i = 0; i < DUST; i++) {
  dPos.set([(Math.random() - .5) * 7, (Math.random() - .5) * 8, Math.random() * 3], i * 3);
  dVel[i] = .05 + Math.random() * .15;
}
const dGeo = new THREE.BufferGeometry();
dGeo.setAttribute('position', new THREE.BufferAttribute(dPos, 3));
scene.add(new THREE.Points(dGeo, new THREE.ShaderMaterial({
  uniforms: U, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
  vertexShader: `void main(){ vec4 mv = modelViewMatrix*vec4(position,1.); gl_Position = projectionMatrix*mv; gl_PointSize = 26. / -mv.z; }`,
  fragmentShader: `void main(){ float a = smoothstep(.5, 0., length(gl_PointCoord - .5)); gl_FragColor = vec4(vec3(1., .78, .4) * a * .5, 1.); }`,
})));

// ---------------------------------------------------------------- связь и анимация
startLink({ defaultTheme: 'зеленый', themeChanged: c => targetColor.copy(c) });

const clock = new THREE.Clock();
function animate() {
  requestAnimationFrame(animate);
  const now = performance.now();
  const t = clock.getElapsedTime();
  const mode = state.mode;
  const amp = tick(now, t);

  color.lerp(targetColor, .06);
  gemMat.color.copy(color); gemMat.emissive.copy(color);
  magic.color.copy(color);
  U.uTime.value = t;
  U.uAmp.value = amp;
  const active = mode === 'idle' ? 0 : mode === 'speaking' ? .7 + amp * .4 : mode === 'thinking' ? .8 : .6;
  U.uActive.value += (active - U.uActive.value) * .05;
  const appear = mode === 'idle' ? .35 : mode === 'thinking' ? .65 : mode === 'listening' ? .85 : 1;
  U.uAppear.value += (appear - U.uAppear.value) * .04;
  const swirl = mode === 'thinking' ? 2.2 : mode === 'speaking' ? .8 + amp : mode === 'listening' ? .6 : .3;
  U.uSwirl.value += (swirl - U.uSwirl.value) * .03;
  magic.intensity = 2 + 6 * U.uActive.value + 6 * amp;
  gemMat.emissiveIntensity = .5 + 1.2 * U.uActive.value + amp;
  bloom.strength = .35 + .2 * amp + .1 * U.uActive.value;
  warm.intensity = 7 * (.92 + .08 * Math.sin(t * 7.3) * Math.sin(t * 3.1));

  // лицо: плавно покачивается, выплывает вперёд, когда говорит
  head.position.y = HEAD_Y + Math.sin(t * .8) * .04;
  head.position.z = HEAD_Z + U.uAppear.value * .12 + amp * .05;
  head.rotation.y = Math.sin(t * .27) * .12;
  head.rotation.x = Math.sin(t * .4) * .03 - amp * .04;
  head.rotation.z = Math.sin(t * .33) * .02;
  crown.rotation.y = t * .6;

  for (let i = 0; i < DUST; i++) {
    let y = dPos[i * 3 + 1] + dVel[i] * .01;
    if (y > 4) y = -4;
    dPos[i * 3 + 1] = y;
    dPos[i * 3] += Math.sin(t * .5 + i) * .0015;
  }
  dGeo.attributes.position.needsUpdate = true;

  camera.position.x = camBase.x + Math.sin(t * .11) * .25;
  camera.position.y = camBase.y + Math.sin(t * .15) * .08;
  camera.lookAt(0, .45, 0);
  composer.render();
}
animate();

addEventListener('resize', () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
  composer.setSize(innerWidth, innerHeight);
});
