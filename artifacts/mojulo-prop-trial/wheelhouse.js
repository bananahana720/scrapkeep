// Dam sluice wheelhouse, mojulo `code` kind program body: function (params, ctx) -> workbench spec.
// A port of gate_wheelhouse in sketches/core-loop/tools/blender/park/props/dam.py, for a
// side-by-side trial against the Blender kit. Same frame as the Blender recipe: metres in the
// program, x right, y back (the wheel wall faces -y), z up, floor at z = 0; emitted in cm.
// Soft toy rule (DECISIONS.md:203): machines and planks are exact rounded boxes (crisp, bevelled);
// round bodies (the tarp, the canvas patch) are sampled fields, which come out smooth.
const P = params;
const V = P.variant;
const S = 100;
const C = {
  concrete: '#9a9a94', concrete_light: '#b8b7ae', concrete_stain: '#7d7a70',
  timber: '#8a6a46', timber_dark: '#5d4630', timber_grey: '#8e8470', timber_pale: '#a8885c',
  canvas: '#d9d2bc', canvas_dark: '#b9b095', cable: '#2a3231', iron: '#4a4e4c',
  iron_light: '#6b706c', rust: '#8a5a44',
};
const ROUND = { hard: P.bevel, hard_smooth: P.bevelSmooth, fine: P.bevelFine };

const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255);
const hex = (c) => '#' + c.map((v) => Math.round(Math.min(Math.max(v, 0), 1) * 255).toString(16).padStart(2, '0')).join('');
const shade = (h, f) => hex(rgb(h).map((v) => v * f));
const mix = (a, b, t) => hex(rgb(a).map((v, i) => v + (rgb(b)[i] - v) * t));
const tint = (h, amount = 0.08) => shade(h, 1 + (Math.random() * 2 - 1) * amount);
const deg = (a) => (a * 180) / Math.PI;
const cm = (p) => p.map((v) => v * S);

// Blender Euler XYZ: R = Rz * Ry * Rx, the same order mojulo's transform uses.
const rotate = (r, p) => {
  const [rx, ry, rz] = r;
  let [x, y, z] = p;
  [y, z] = [y * Math.cos(rx) - z * Math.sin(rx), y * Math.sin(rx) + z * Math.cos(rx)];
  [x, z] = [x * Math.cos(ry) + z * Math.sin(ry), -x * Math.sin(ry) + z * Math.cos(ry)];
  [x, y] = [x * Math.cos(rz) - y * Math.sin(rz), x * Math.sin(rz) + y * Math.cos(rz)];
  return [x, y, z];
};
const add = (a, b) => a.map((v, i) => v + b[i]);
const sub = (a, b) => a.map((v, i) => v - b[i]);
const len = (a) => Math.hypot(...a);

const out = { fields: [] };
const counts = { box: 0, lathe: 0, sweep: 0, soft: 0 };
// Mojulo's exact kernel takes 8 to 256 facets; Blender's 6-sided rods round up to 8.
const exact = (tintHex, terms, segments = P.segments) => out.fields.push({ exact: true, segments: Math.max(8, segments), tint: tintHex, terms });

function box(size, loc, color, rot = [0, 0, 0], style = 'hard', jit = 0) {
  const s = size.map((v) => v + (jit ? (Math.random() * 2 - 1) * jit : 0));
  const round = Math.min(ROUND[style], 0.45 * Math.min(...s));
  counts.box += 1;
  exact(color, [{ op: 'transform', rotate: rot.map(deg), translate: cm(loc),
    terms: [{ op: 'add', shape: { kind: 'box', center: [0, 0, 0], size: cm(s), round: round * S } }] }], P.boxSegments);
}
// A box whose long axis runs from a to b (Blender's beam: width w, height h, length |b - a|).
function beam(a, b, w, color, h = null) {
  const d = sub(b, a);
  const L = len(d);
  const pitch = Math.acos(d[2] / L);
  const yaw = Math.atan2(d[1], d[0]);
  box([w, h || w, L], a.map((v, i) => v + d[i] / 2), color, [0, pitch, yaw]);
}
function lathe(a, b, r1, r2, color, segments) {
  counts.lathe += 1;
  exact(color, [{ op: 'add', shape: { kind: 'lathe', axisFrom: cm(a), axisTo: cm(b),
    profile: [{ t: 0, radius: r1 * S }, { t: 1, radius: r2 * S }] } }], segments);
}
const rod = (a, b, r, color, segs = 6, r2 = null) => lathe(a, b, r, r2 == null ? r : r2, color, segs);
function cyl(r, depth, loc, color, segs = 10, rot = [0, 0, 0], r2 = null) {
  const half = rotate(rot, [0, 0, depth / 2]);
  lathe(sub(loc, half), add(loc, half), r, r2 == null ? r : r2, color, segs);
}
// A closed tube around local z, scaled in local x/y, rotated and placed.
function torus(big, small, loc, color, rot = [0, 0, 0], scale = [1, 1], major = 12) {
  const path = [];
  for (let k = 0; k <= major; k += 1) {
    const a = (Math.PI * 2 * k) / major;
    path.push(cm(add(loc, rotate(rot, [big * scale[0] * Math.cos(a), big * scale[1] * Math.sin(a), 0]))));
  }
  counts.sweep += 1;
  exact(color, [{ op: 'add', shape: { kind: 'sweep', path, radius: small * S } }], 8);
}
function ring(rIn, rOut, depth, loc, color, rot = [0, 0, 0]) {
  const half = rotate(rot, [0, 0, depth / 2]);
  const a = cm(sub(loc, half));
  const b = cm(add(loc, half));
  const pr = (r) => [{ t: 0, radius: r * S }, { t: 1, radius: r * S }];
  counts.lathe += 1;
  exact(color, [
    { op: 'add', shape: { kind: 'lathe', axisFrom: a, axisTo: b, profile: pr(rOut) } },
    { op: 'subtract', shape: { kind: 'lathe', axisFrom: cm(sub(loc, half.map((v) => v * 1.5))), axisTo: cm(add(loc, half.map((v) => v * 1.5))), profile: pr(rIn) } },
  ], 12);
}
// A slumped soft body (tarp, canvas): a sampled ellipsoid with a little noise, so it reads smooth.
function soft(r, loc, color, scale, rot = [0, 0, 0]) {
  counts.soft += 1;
  out.fields.push({ cells: P.softCells, tint: color, terms: [
    { op: 'transform', translate: [0, 0, 0], terms: [
      { op: 'transform', rotate: rot.map(deg), translate: cm(loc),
        terms: [{ op: 'add', shape: { kind: 'ellipsoid', center: [0, 0, 0], radii: cm(scale.map((s) => s * r)) } }] },
    ] },
    { op: 'displace', noise: { amplitude: r * S * 0.06, scale: r * S * 0.9, octaves: 2, seed: 11 } },
  ] });
}
function chain(a, b, color, link = 0.12, radius = 0.022, sag = 0.3) {
  const d = sub(b, a);
  const L = len(d);
  const n = Math.max(2, Math.floor(L / (link * 0.8)));
  const u = d.map((v) => v / L);
  const yaw = Math.atan2(u[1], u[0]);
  const pitch = -Math.asin(Math.max(-1, Math.min(1, u[2])));
  for (let k = 0; k <= n; k += 1) {
    const t = k / n;
    const pos = add(a, d.map((v) => v * t));
    pos[2] -= sag * 4 * t * (1 - t);
    // Local x follows the chord; odd links roll a quarter turn about it.
    torus(link * 0.5, radius, pos, color, [(Math.PI / 2) * (k % 2), pitch, yaw], [1.0, 0.7], 6);
  }
}

// 1. Concrete plinth with chipped corners and a stain band.
box([4.0, 3.2, 0.4], [0, 0, 0.2], C.concrete, [0, 0, 0], 'hard_smooth');
box([4.1, 0.5, 0.18], [0, -1.55, 0.09], C.concrete_light, [0, 0, 0], 'hard_smooth');
for (const [x, y] of [[-1.9, -1.5], [1.9, 1.5], [1.95, -1.4]]) {
  box([0.28, 0.28, 0.14], [x, y, 0.45], mix(C.concrete, C.concrete_stain, 0.5), [0, 0, Math.random() * 1.5]);
}
// 2. Corner posts.
for (const x of [-1.75, 1.75]) for (const y of [-1.3, 1.3]) beam([x, y, 0.4], [x, y, 2.35], 0.2, tint(C.timber_dark, 0.05));
// 3. Wall planks: back, sides, front (a door of paler planks, set a hair proud).
for (let i = 0; i < 16; i += 1) box([0.2, 0.12, 1.9], [-1.58 + i * 0.21, 1.3, 1.35], tint(C.timber), [0, 0, 0], 'hard', 0.004);
for (const s of [-1, 1]) {
  for (let i = 0; i < 11; i += 1) {
    if (V === 'b' && s === 1 && (i === 3 || i === 4)) continue; // two planks came away
    box([0.12, 0.2, 1.9], [s * 1.75, -1.05 + i * 0.21, 1.35], tint(s === 1 ? C.timber_grey : C.timber), [0, 0, 0], 'hard', 0.004);
  }
}
for (let i = 0; i < 16; i += 1) {
  const x = -1.58 + i * 0.21;
  const door = x >= -0.62 && x <= 0.1;
  box([0.2, 0.12, door ? 1.75 : 1.9], [x, -1.3, door ? 1.275 : 1.35], tint(door ? C.timber_pale : C.timber), [0, 0, 0], 'hard', 0.004);
}
for (const z of [0.7, 1.9]) beam([-1.78, -1.38, z], [1.78, -1.38, z], 0.1, C.timber_dark, 0.08);
// 4. Roof: plank rows up each slope; the ridge dips in the sagging variant.
const sag = V === 'b' ? 0.38 : 0;
const rise = 0.75, half = 1.85, rows = 8, segs = 6;
const theta = Math.atan2(rise, half);
const segLen = 3.9 / segs;
for (const s of [-1, 1]) {
  for (let r = 0; r < rows; r += 1) {
    const t = (r + 0.5) / rows;
    for (let j = 0; j < segs; j += 1) {
      if (V === 'b' && s === -1 && (j === 2 || j === 3) && r >= 5) continue; // hole in the sagging roof
      const x = -1.95 + (j + 0.5) * segLen;
      const dip = sag * (1 - (x / 1.95) ** 2) * (0.35 + 0.65 * t);
      const slope = sag ? Math.atan2((sag * 2 * x) / 1.95 ** 2, 1) : 0;
      box([segLen + 0.02, 0.5, 0.07], [x, s * half * (1 - t), 2.35 + rise * t - dip],
        tint((r + j) % 3 ? C.timber_grey : C.timber_dark, 0.07), [-s * theta, slope, 0], 'fine', 0.005);
    }
  }
}
for (let j = 0; j < 5; j += 1) {
  const x = -1.9 + j * 0.95;
  const dip = sag * (1 - (x / 1.95) ** 2) * 0.4;
  for (const s of [-1, 1]) beam([x, s * half, 2.3], [x, 0, 2.3 + rise - dip - 0.05], 0.11, C.timber_dark, 0.09);
}
beam([-1.95, 0, 2.3 + rise - 0.02], [1.95, 0, 2.3 + rise - 0.02 - sag * 0.4], 0.14, C.timber_dark);
if (V === 'b') {
  soft(0.8, [-0.15, -0.5, 2.55], C.canvas_dark, [1.5, 1.0, 0.22], [0.4, 0, 0.1]);
  box([1.6, 0.26, 0.07], [-0.6, -1.95, 0.1], C.timber_grey, [0, 0, 0.35], 'fine');
  box([1.2, 0.24, 0.07], [0.3, -2.1, 0.22], C.timber_dark, [0.05, 0, -0.5], 'fine');
  box([1.0, 0.22, 0.07], [-1.8, -1.85, 0.07], C.timber_pale, [0, 0, 1.2], 'fine');
} else {
  soft(0.45, [-1.3, -1.7, 0.3], C.canvas, [1.0, 0.8, 0.7]); // folded tarp
}
// 5. The big hand wheel on the front wall: rim, hub, spokes, grips, chained shut.
const wx = 0.95, wy = -1.72, wz = 1.35, wr = 0.78;
const face = [Math.PI / 2, 0, 0];
box([0.34, 0.3, 1.5], [wx, -1.5, 1.1], C.timber_dark);
cyl(0.09, 0.5, [wx, -1.65, wz], C.iron, 8, face);
torus(wr, 0.075, [wx, wy, wz], V === 'a' ? C.iron_light : C.rust, face, [1, 1], P.rimSegments);
cyl(0.2, 0.2, [wx, wy, wz], C.iron, 10, face);
for (let k = 0; k < 8; k += 1) {
  const a = (Math.PI * 2 * k) / 8 + 0.2;
  rod([wx + 0.1 * Math.cos(a), wy, wz + 0.1 * Math.sin(a)], [wx + wr * Math.cos(a), wy, wz + wr * Math.sin(a)], 0.045, C.iron, 6);
}
for (let k = 0; k < 4; k += 1) {
  const a = (Math.PI * 2 * k) / 4 + 0.2;
  cyl(0.06, 0.28, [wx + (wr + 0.02) * Math.cos(a), wy - 0.05, wz + (wr + 0.02) * Math.sin(a)], C.timber_dark, 6, face);
}
const ringX = wx - 0.05;
ring(0.05, 0.12, 0.08, [ringX, -1.85, 0.5], C.iron, [Math.PI / 2, 0, 0]);
if (V === 'a') {
  chain([wx, wy - 0.12, wz + wr], [ringX, -1.85, 0.55], C.cable, 0.12, 0.022, 0.3);
  chain([wx + wr, wy - 0.12, wz], [ringX + 0.1, -1.85, 0.55], C.cable, 0.12, 0.022, 0.35);
} else {
  chain([wx, wy - 0.12, wz + wr], [ringX + 0.4, -2.3, 0.1], C.cable, 0.12, 0.022, 0.3);
  chain([wx + wr, wy - 0.12, wz], [ringX, -1.85, 0.55], C.cable, 0.12, 0.022, 0.3);
}
box([0.22, 0.14, 0.26], [wx + 0.02, wy - 0.18, wz + 0.3], C.iron, [0, 0, 0], 'hard_smooth'); // padlock
// 6. A short-handled mallet dropped by the step.
cyl(0.07, 0.9, [-1.0, -2.35, 0.07], C.timber_dark, 6, [0, Math.PI / 2, 0.3]);
cyl(0.13, 0.32, [-0.5, -2.2, 0.13], C.iron, 8, [0, Math.PI / 2, 0.3]);

console.log('parts', JSON.stringify(counts), 'fields', out.fields.length);
return out;
