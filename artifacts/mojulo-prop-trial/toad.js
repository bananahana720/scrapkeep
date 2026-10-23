// Spillway puddle toad body, mojulo `code` kind: a static port of tools/blender/ambient/puddle_toad.py
// (rest pose only; mojulo has no bones or clips). Sampled fields with smooth unions, so the dome,
// eye bumps and thighs melt into one soft-toy body. Palette from ambient_kinds.gd "puddle_toad".
// Authored in the Blender recipe's Godot frame (metres, y up, facing -z); g() maps to mojulo cm, z up.
const P = params;
const S = 100;
const g = ([x, y, z]) => [x * S, z * S, y * S];
const rad = ([x, y, z]) => [x * S, z * S, y * S];
const ell = (c, r) => ({ kind: 'ellipsoid', center: g(c), radii: rad(r) });
const pal = { body: '#8a79c8', spots: '#6e5ea8', cream: '#efe8f2', eye: '#2b2238' };
const BY = 0.08, RX = 0.10, RY = 0.075, RZ = 0.105;
const blend = P.blend * S;
const field = (tint, shapes, cells) => ({ cells, tint, terms: shapes.map((s, i) => ({ op: 'add', shape: s, blend: i ? blend : undefined })) });

const body = [ell([0, BY, 0], [RX, RY, RZ])];
for (const s of [-1, 1]) {
  body.push(ell([0.052 * s, 0.182, -0.032], [0.044, 0.052, 0.044]));
  body.push(ell([0.052 * s, 0.14, -0.03], [0.052, 0.04, 0.05]));
  body.push(ell([0.092 * s, 0.045, 0.035], [0.03, 0.037, 0.05]));
}
const spots = [];
for (const [x, z, r] of [[0.05, 0.035, 0.032], [-0.05, 0.05, 0.028], [0, 0.07, 0.021]]) {
  const k = Math.max(0.2, 1 - (x / RX) ** 2 - (z / RZ) ** 2);
  spots.push(ell([x, BY + RY * Math.sqrt(k) - 0.006, z], [r, 0.012, r]));
}
for (const s of [-1, 1]) spots.push(ell([0.074 * s, 0.017, -0.075], [0.04, 0.02, 0.052]));
const cream = [ell([0, 0.03, -0.02], [0.075, 0.03, 0.08]), ell([0, 0.058, -0.078], [0.05, 0.032, 0.034])];
const eyes = [-1, 1].map((s) => ell([0.057 * s, 0.19, -0.072], [0.022, 0.025, 0.014]));
const mouth = [[-0.056, 0.097, -0.081], [-0.03, 0.087, -0.1], [0, 0.084, -0.106], [0.03, 0.087, -0.1], [0.056, 0.097, -0.081]];

return {
  fields: [
    field(pal.body, body, P.cells),
    field(pal.cream, cream, P.smallCells),
    ...spots.map((s) => field(pal.spots, [s], P.spotCells)),
    ...eyes.map((s) => field(pal.eye, [s], P.spotCells)),
    { exact: true, segments: 8, tint: pal.eye, terms: [{ op: 'add', shape: { kind: 'sweep', path: mouth.map(g), radius: 0.006 * S } }] },
  ],
};
