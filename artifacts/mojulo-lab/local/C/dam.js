// Spillway dam face, mojulo `code` kind program body: function (params, ctx) -> workbench spec.
// Board: docs/art/reference/spillway/spillway-landmarks-dam-face.jpg (320 m crest, ~120 m face,
// two crest towers, reactor 22 m above the toe; the plinth stays empty, TADR-011).
// Frame, metres: x downstream, y across the canyon, z up, toe at z = 0. Emitted in cm.
const P = params;
const S = 100;
const R = P.radius;
const H = P.height;
const half = P.crest / 2 / R;
const cx = R;
const seg = P.segments;
const m = (v) => (Array.isArray(v) ? v.map(m) : v * S);
const C = {
  concrete: '#cdc6b4', concreteShade: '#b9b09b', stain: '#9a6a4a', mineral: '#a7a89a', joint: '#8f8a7c',
  petrol: '#2f6b6a', oxide: '#9a4f32', brass: '#b8913f', water: '#bfe2ee', foam: '#eef6f7', river: '#5aa6a6',
  sand: '#c79a6b', sandDark: '#a8774f', sandLight: '#dcb68a', canvas: '#e6d8b8', steel: '#5d6a6e', green: '#6f8f3d',
};
const ft = (z) => P.toe * Math.pow(1 - Math.min(Math.max(z, 0), H) / H, P.flare);
const rd = (z) => R - ft(z);
const ax = (z) => ({ x: cx * S, y: 0, z: z * S });
const at = (r, phi, z) => [cx - r * Math.cos(phi), r * Math.sin(phi), z];
const deg = (a) => (a * 180) / Math.PI;
const PROF = 24;
const faceLathe = (off, z0, z1) => ({
  kind: 'lathe', axisFrom: ax(z0), axisTo: ax(z1),
  profile: Array.from({ length: PROF + 1 }, (_, i) => {
    const t = i / PROF;
    return { t, radius: (rd(z0 + t * (z1 - z0)) + off) * S };
  }),
});
const ring = (r, z0, z1) => ({ kind: 'lathe', axisFrom: ax(z0), axisTo: ax(z1), profile: [{ t: 0, radius: r * S }, { t: 1, radius: r * S }] });
const sector = (a0, a1, z0, z1, rIn = 0, rOut = R + 60) => {
  const n = 24;
  const pts = [];
  for (let i = 0; i <= n; i += 1) { const a = a0 + (a1 - a0) * (i / n); const p = at(rOut, a, 0); pts.push([p[0] * S, p[1] * S]); }
  if (rIn <= 0) pts.push([cx * S, 0]);
  else for (let i = n; i >= 0; i -= 1) { const a = a0 + (a1 - a0) * (i / n); const p = at(rIn, a, 0); pts.push([p[0] * S, p[1] * S]); }
  return { kind: 'extrude', profile: { points: pts }, axisFrom: { x: 0, y: 0, z: z0 * S }, axisTo: { x: 0, y: 0, z: z1 * S } };
};
const field = (id, tint, terms) => ({ id, exact: true, segments: seg, tint, terms });
const boxAt = (r, phi, z, size, extra = {}) => {
  const p = at(r, phi, z);
  return { op: 'transform', rotate: [0, 0, deg(Math.PI - phi)], translate: m(p), terms: [{ op: 'add', shape: { kind: 'box', center: [0, 0, 0], size: m(size) }, ...extra }] };
};
const out = { fields: [], sweeps: [] };
const sweep = (path, radius, tint, sides = 8) => out.sweeps.push({ path: path.map(m), radius: radius * S, sides, tint });

// 1. Dam body: between the downstream face rd(z) and the upstream face R + thick, inside the arch sector.
const gateHalf = P.gates * P.gateWidth / 2 / R + P.pierWidth / 2 / R;
out.fields.push(field('dam', C.concrete, [
  { id: 'body', op: 'add', shape: ring(R + P.thick, 0, H) },
  { id: 'face', op: 'subtract', shape: faceLathe(0, -1, H + 1) },
  { id: 'arch', op: 'intersect', shape: sector(-half, half, -1, H + 1, 0, R + P.thick + 1) },
  ...Array.from({ length: P.gates }, (_, g) => {
    const a = (-(P.gates * P.gateWidth) / 2 + (g + 0.5) * P.gateWidth) / R;
    return { id: `gate${g}`, op: 'subtract', shape: sector(a - (P.gateWidth / 2 - 0.5) / R, a + (P.gateWidth / 2 - 0.5) / R, H - P.gateDrop, H + 2, R - 2, R + P.thick + 2) };
  }),
  ...Array.from({ length: P.bands }, (_, i) => {
    const z = (i + 1) * (H / (P.bands + 1));
    return { id: `band${i}`, op: 'subtract', shape: faceLathe(0.35, z - 0.35, z + 0.35) };
  }),
]));

// 2. Oxide streaks: thin proud skins hanging from the crest and the bands, as on the board.
for (let i = 0; i < P.stains; i += 1) {
  let a = -half * 0.95 + Math.random() * half * 1.9;
  if (Math.abs(a) < gateHalf + 3 / R) a += Math.sign(a || 1) * (gateHalf + 6 / R);
  const w = (1.2 + Math.random() * 3.2) / R;
  const z1 = Math.random() < 0.5 ? H - 1 : H * (0.3 + Math.random() * 0.6);
  const z0 = Math.max(2, z1 - 8 - Math.random() * 38);
  out.fields.push(field(`stain${i}`, i % 4 === 0 ? C.mineral : C.stain, [
    { op: 'add', shape: faceLathe(0.6, z0, z1) },
    { op: 'subtract', shape: faceLathe(-0.05, z0 - 1, z1 + 1) },
    { op: 'intersect', shape: sector(a, a + w, z0, z1) },
  ]));
}

// 3. Repair joints: vertical ribs following the face curve.
for (let k = 0; k < P.joints; k += 1) {
  const phi = -half + ((k + 0.5) / P.joints) * 2 * half;
  if (Math.abs(phi) < gateHalf + 2 / R) continue;
  const path = Array.from({ length: 13 }, (_, i) => { const z = 1 + (i / 12) * (H - 3); return at(rd(z) - 0.05, phi, z); });
  sweep(path, 0.22, C.joint, 6);
}

// 4. Water sheet down the spillway: a pale skin standing off the face, foam apron at the toe.
out.fields.push(field('sheet', C.water, [
  { op: 'add', shape: faceLathe(-0.4, 0.5, H - P.gateDrop + 0.5) },
  { op: 'subtract', shape: faceLathe(-0.4 - P.sheet, -1, H + 2) },
  { op: 'intersect', shape: sector(-gateHalf + P.pierWidth / R, gateHalf - P.pierWidth / R, 0, H) },
  { op: 'subtract', shape: sector(-P.pierWidth / 2 / R, P.pierWidth / 2 / R, H * 0.45, H + 2) },
]));
// Spray streaks: brighter ribbons inside each lane, starting at the gate lip.
for (let i = 0; i < P.spray; i += 1) {
  const lane = i % 2 ? 1 : -1;
  const a = lane * (P.pierWidth / 2 + 1 + Math.random() * (P.gateWidth - 3)) / R;
  const zTop = H - P.gateDrop + 0.3 - Math.random() * 8;
  const path = Array.from({ length: 10 }, (_, k) => { const z = zTop - (k / 9) * (zTop - 1); return at(rd(z) - 0.9 - P.sheet - Math.random() * 0.3, a + (Math.random() - 0.5) * 0.4 / R, z); });
  sweep(path, 0.25 + Math.random() * 0.35, C.foam, 6);
}
out.fields.push(field('foam', C.foam, [
  { op: 'add', shape: { kind: 'sphere', center: m([ft(0) + 12, 0, -24]), radius: 27 * S } },
  { op: 'intersect', shape: { kind: 'box', center: m([ft(0) + 12, 0, 1.5]), size: m([40, 80, 3]) } },
]));

// 5. Crest: towers flanking the spillway, gantry between them, parapet rails along both edges.
for (const s of [-1, 1]) {
  const phi = s * (gateHalf + P.tower[1] / 2 / R);
  const r = R + P.thick / 2;
  out.fields.push(field(`tower${s}`, C.concreteShade, [
    boxAt(r, phi, H + P.tower[2] / 2 - 6, [P.tower[0], P.tower[1], P.tower[2] + 12]),
    ...[0.25, 0.55, 0.85].map((f) => ({ ...boxAt(r - P.tower[0] / 2, phi, H + P.tower[2] * f - 4, [1.6, 2.2, 3.2]), combine: 'subtract' })),
  ]));
  out.fields.push(field(`cap${s}`, C.petrol, [
    boxAt(r, phi, H + P.tower[2] + 1.2, [P.tower[0] + 1.6, P.tower[1] + 1.6, 2.4]),
    boxAt(r, phi, H + P.tower[2] + 3.4, [P.tower[0] * 0.55, P.tower[1] * 0.55, 2.2]),
  ]));
  out.fields.push(field(`trim${s}`, C.oxide, [boxAt(r, phi, H + P.tower[2] * 0.62, [P.tower[0] + 0.8, P.tower[1] + 0.8, 1.2])]));
  // Petrol enamel panels on the tower's downstream face and a brass lamp bracket.
  out.fields.push(field(`panel${s}`, C.petrol, [0.38, 0.8].map((f) => boxAt(r - P.tower[0] / 2 - 0.2, phi, H + P.tower[2] * f - 4, [0.6, P.tower[1] * 0.7, P.tower[2] * 0.18]))));
  sweep([at(r - P.tower[0] / 2, phi, H + P.tower[2] * 0.95), at(r - P.tower[0] / 2 - 2.4, phi, H + P.tower[2] * 0.95), at(r - P.tower[0] / 2 - 2.4, phi, H + P.tower[2] * 0.95 - 1.2)], 0.12, C.brass, 6);
  sweep([at(r, phi, H + P.tower[2] + 4.5), at(r, phi, H + P.tower[2] + 9)], 0.18, C.brass, 6);
}
// Gate frames: petrol lintel and jambs around each opening, and the centre pier.
out.fields.push(field('gateFrames', C.petrol, [
  boxAt(R - 1, 0, H + 1.5, [3, P.gates * P.gateWidth + 2 * P.pierWidth, 3]),
  ...Array.from({ length: P.gates + 1 }, (_, g) => boxAt(R - 1, (-(P.gates * P.gateWidth) / 2 + g * P.gateWidth) / R, H - P.gateDrop / 2 + 1, [3, P.pierWidth * 0.6, P.gateDrop + 2])),
]));
const gz = H + P.tower[2] * 0.72;
const gr = R + P.thick / 2;
const ga = gateHalf;
const gN = 16;
for (const off of [-1.6, 1.6]) for (const dz of [0, 3.2]) sweep(Array.from({ length: 5 }, (_, i) => at(gr + off, -ga + (2 * ga * i) / 4, gz + dz)), 0.28, C.petrol, 8);
for (let i = 0; i < gN; i += 1) {
  const a0 = -ga + (2 * ga * i) / gN;
  const a1 = -ga + (2 * ga * (i + 1)) / gN;
  for (const off of [-1.6, 1.6]) {
    sweep([at(gr + off, a0, gz), at(gr + off, a1, gz + 3.2)], 0.14, C.steel, 6);
    sweep([at(gr + off, a0, gz), at(gr + off, a0, gz + 3.2)], 0.14, C.steel, 6);
  }
}
const rails = [R + 0.4, R + P.thick - 0.4];
for (const r of rails) {
  const n = 64;
  const pts = (lo, hi) => Array.from({ length: n + 1 }, (_, i) => at(r, lo + ((hi - lo) * i) / n, H + 1.15));
  sweep(pts(-half, -gateHalf - P.tower[1] / R), 0.07, C.steel, 6);
  sweep(pts(gateHalf + P.tower[1] / R, half), 0.07, C.steel, 6);
  for (let i = 0; i <= P.posts; i += 1) {
    const phi = -half + (2 * half * i) / P.posts;
    if (Math.abs(phi) < gateHalf + P.tower[1] / R) continue;
    sweep([at(r, phi, H), at(r, phi, H + 1.15)], 0.06, C.steel, 6);
  }
}

// 6. Abutment service shelves with canopies, on the canyon side of each arch end.
for (const s of [-1, 1]) {
  const phi = s * (half - 6 / R);
  for (const z of P.shelves) {
    const r = rd(z) - 2;
    out.fields.push(field(`shelf${s}_${z}`, C.concreteShade, [boxAt(r, phi, z, [5, 14, 0.8])]));
    out.fields.push(field(`canopy${s}_${z}`, C.canvas, [boxAt(r - 0.6, phi, z + 3.4, [5.6, 10, 0.25])]));
    for (const dy of [-4.5, 4.5]) { const a = phi + dy / R; sweep([at(r - 2.2, a, z + 0.4), at(r - 2.2, a, z + 3.3)], 0.1, C.brass, 6); }
    sweep(Array.from({ length: 6 }, (_, i) => at(r - 2.4, phi + (-6 + 2.4 * i) / R, z + 1.1)), 0.05, C.steel, 6);
  }
}

// 7. Canyon walls: terraced sandstone tiers stepping back from each abutment, downstream and up.
const wallTerms = [];
const ledges = [];
for (const s of [-1, 1]) {
  const yEdge = at(R, s * half, 0)[1];
  for (let tier = 0; tier < P.tiers; tier += 1) {
    const zTop = Math.min(H + 40, (tier + 1) * ((H + 40) / P.tiers) + (Math.random() - 0.5) * 6);
    const back = tier * P.tierStep;
    for (let b = 0; b < P.blocks; b += 1) {
      const x0 = -80 + (b / P.blocks) * (P.length + 80);
      const len = (P.length + 80) / P.blocks + 4;
      const jitter = (Math.random() - 0.5) * 5;
      const inset = -10 + back + jitter;
      const depth = 40;
      const y = s * (Math.abs(yEdge) + inset + depth / 2 + Math.max(0, (x0 - at(R, half, 0)[0]) * 0.15));
      wallTerms.push({ op: 'add', shape: { kind: 'box', center: m([x0 + len / 2, y, zTop / 2 - 1]), size: m([len, depth, zTop + 2]), round: 1.2 * S } });
      if (tier < P.tiers - 1 && Math.random() < P.shrubChance) ledges.push([x0 + Math.random() * len, y - s * (depth / 2 - 3 - Math.random() * 4), zTop + 1]);
    }
  }
}
// mojulo 3.0.0 refuses a displace that follows two or more shape terms; a zero transform groups them into one.
out.fields.push({ id: 'canyon', exact: false, cells: P.canyonCells, tint: C.sand, terms: [
  { op: 'transform', translate: [0, 0, 0], terms: wallTerms.map((t, i) => (i === 0 ? t : { ...t, op: 'add', blend: 2.5 * S })) },
  { op: 'displace', noise: { amplitude: 1.4 * S, scale: 18 * S, octaves: 4, persistence: 0.5, seed: 11 } },
] });
// Shrubs: low clumps of three spheres on the terrace ledges, as on the board.
ledges.forEach(([x, y, z], i) => {
  const r = 1.6 + Math.random() * 2.2;
  out.fields.push({ id: `shrub${i}`, exact: true, segments: 10, tint: i % 3 ? C.green : '#57782f', terms: [0, 1, 2].map((k) => ({
    op: 'add', shape: { kind: 'sphere', center: m([x + (k - 1) * r * 0.9, y + (Math.random() - 0.5) * r, z + r * 0.4 + (k === 1 ? r * 0.3 : 0)]), radius: r * (k === 1 ? 1 : 0.75) * S },
  })) });
});

// 8. Valley floor, river and the empty reactor plinth at the toe.
out.fields.push(field('floor', C.sandLight, [
  { op: 'add', shape: { kind: 'box', center: m([P.length / 2 - 20, 0, -1.5]), size: m([P.length + 120, 2 * at(R, half, 0)[1] + 120, 3]) } },
  { op: 'subtract', shape: { kind: 'capsule', a: m([ft(0) + 10, 0, 2]), b: m([P.length, 0, 2]), radius: 0.5 * P.river * S } },
]));
out.fields.push(field('river', C.river, [
  { op: 'add', shape: { kind: 'capsule', a: m([ft(0) + 10, 0, 1.4]), b: m([P.length, 0, 1.4]), radius: 0.5 * P.river * S } },
  { op: 'intersect', shape: { kind: 'box', center: m([P.length / 2, 0, -0.6]), size: m([P.length * 2, P.river + 4, 1.6]) } },
]));
const px = ft(0) + 9;
out.fields.push(field('plinth', C.concreteShade, [
  { op: 'add', shape: { kind: 'box', center: m([px, 0, P.plinth / 2]), size: m([14, 14, P.plinth]) } },
  { op: 'subtract', shape: { kind: 'box', center: m([px, 0, P.plinth - 0.3]), size: m([10, 10, 0.8]) } },
]));
out.fields.push(field('plinthRing', C.brass, [
  { op: 'add', shape: { kind: 'box', center: m([px, 0, P.plinth - 1.2]), size: m([14.6, 14.6, 1]) } },
  { op: 'subtract', shape: { kind: 'box', center: m([px, 0, P.plinth - 1.2]), size: m([13.4, 13.4, 2]) } },
]));
for (let i = 0; i < P.boulders; i += 1) {
  const x = ft(0) + 20 + Math.random() * (P.length - 40);
  const y = (Math.random() < 0.5 ? -1 : 1) * (P.river / 2 + 3 + Math.random() * 50);
  const r = 1 + Math.random() * 3.5;
  out.fields.push({ id: `boulder${i}`, exact: true, segments: 12, tint: i % 2 ? C.sand : C.sandDark,
    terms: [{ op: 'add', shape: { kind: 'sphere', center: m([x, y, -r * 0.35]), radius: r * S } }] });
}
console.log('fields', out.fields.length, 'sweeps', out.sweeps.length, 'toe offset m', ft(0).toFixed(1), 'arch half deg', deg(half).toFixed(1));
return out;
