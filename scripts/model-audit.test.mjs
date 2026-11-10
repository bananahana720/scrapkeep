import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const script = fileURLToPath(new URL("../sketches/core-loop/tools/model_audit.py", import.meta.url));
const has = (module) => spawnSync("python3", ["-c", `import ${module}`]).status === 0;
const numpy = has("numpy");
const pillow = numpy && has("PIL");

// A GLB with one unindexed triangle surface and, when given, clips on extra nodes. tris: [[p0, p1, p2, normal]].
// clips: [{ name, node, interpolation, degrees or metres: [...] }], one key every 1/30 s: a turn about Y, or a move along X.
// weights, more: one [w, w, w, w] per vertex, as WEIGHTS_0 and WEIGHTS_1.
// body: fields merged into the mesh node, such as scale or rotation.
// skin: { translation } places the surface by one joint at that translation (all four joint slots point at it; the
// joint indices are written as floats, which the reader takes, to keep the fixture to one buffer type).
function glb(tris, { clips = [], weights = null, more = null, body = {}, skin = null } = {}) {
  const floats = [];
  const view = (values, target) => {
    const at = floats.length * 4;
    floats.push(...values);
    return { buffer: 0, byteOffset: at, byteLength: values.length * 4, ...(target ? { target } : {}) };
  };
  const positions = tris.flatMap(([a, b, c]) => [...a, ...b, ...c]);
  const normals = tris.flatMap(([, , , n]) => [...n, ...n, ...n]);
  const count = tris.length * 3;
  const corners = tris.flatMap(([a, b, c]) => [a, b, c]);
  const bound = (pick) => [0, 1, 2].map((axis) => pick(...corners.map((corner) => corner[axis])));
  const json = {
    asset: { version: "2.0" },
    scene: 0,
    scenes: [{ nodes: [0, ...clips.map((_, i) => i + 1)] }],
    nodes: [{ name: "Body", mesh: 0, ...body }, ...clips.map((clip) => ({ name: clip.node }))],
    meshes: [{ primitives: [{ attributes: { POSITION: 0, NORMAL: 1 } }] }],
    buffers: [{ byteLength: 0 }],
    bufferViews: [view(positions, 34962), view(normals, 34962)],
    accessors: [
      { bufferView: 0, componentType: 5126, count, type: "VEC3", min: bound(Math.min), max: bound(Math.max) },
      { bufferView: 1, componentType: 5126, count, type: "VEC3" },
    ],
  };
  const accessor = (bufferView, fields) => {
    json.bufferViews.push(bufferView);
    json.accessors.push({ bufferView: json.bufferViews.length - 1, componentType: 5126, ...fields });
    return json.accessors.length - 1;
  };
  const attributes = json.meshes[0].primitives[0].attributes;
  if (weights) attributes.WEIGHTS_0 = accessor(view(weights.flat()), { count, type: "VEC4" });
  if (more) attributes.WEIGHTS_1 = accessor(view(more.flat()), { count, type: "VEC4" });
  if (skin) {
    const joint = json.nodes.push({ name: "Joint", translation: skin.translation }) - 1;
    json.scenes[0].nodes.push(joint);
    json.skins = [{ joints: [joint] }];
    json.nodes[0].skin = 0;
    attributes.JOINTS_0 = accessor(view(new Array(count * 4).fill(0)), { count, type: "VEC4" });
    attributes.WEIGHTS_0 ??= accessor(view(new Array(count).fill([1, 0, 0, 0]).flat()), { count, type: "VEC4" });
  }
  const animations = clips.map((clip, i) => {
    const keys = clip.degrees ?? clip.metres;
    const times = keys.map((_, key) => key / 30);
    const values = clip.degrees
      ? keys.flatMap((degrees) => [0, Math.sin((degrees * Math.PI) / 360), 0, Math.cos((degrees * Math.PI) / 360)])
      : keys.flatMap((metres) => [metres, 0, 0]);
    const input = accessor(view(times), { count: times.length, type: "SCALAR", min: [0], max: [times.at(-1)] });
    // A cubic spline stores an in-tangent, the value and an out-tangent for every key.
    const width = clip.degrees ? 4 : 3;
    const stored = clip.interpolation === "CUBICSPLINE"
      ? keys.flatMap((_, key) => [...new Array(width).fill(0), ...values.slice(key * width, (key + 1) * width), ...new Array(width).fill(0)])
      : values;
    const output = accessor(view(stored), { count: stored.length / width, type: clip.degrees ? "VEC4" : "VEC3" });
    return {
      name: clip.name,
      samplers: [{ input, output, interpolation: clip.interpolation ?? "LINEAR" }],
      channels: [{ sampler: 0, target: { node: i + 1, path: clip.degrees ? "rotation" : "translation" } }],
    };
  });
  if (animations.length > 0) json.animations = animations;
  const bin = Buffer.from(new Float32Array(floats).buffer);
  json.buffers[0].byteLength = bin.length;
  let text = Buffer.from(JSON.stringify(json));
  text = Buffer.concat([text, Buffer.alloc((4 - (text.length % 4)) % 4, 0x20)]);
  const header = Buffer.alloc(12);
  header.write("glTF", 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + text.length + 8 + bin.length, 8);
  const chunk = (length, type) => {
    const head = Buffer.alloc(8);
    head.writeUInt32LE(length, 0);
    head.write(type, 4);
    return head;
  };
  return Buffer.concat([header, chunk(text.length, "JSON"), text, chunk(bin.length, "BIN\0"), bin]);
}

const UP = [0, 1, 0];
const DOWN = [0, -1, 0];
// Counter-clockwise seen from above, so the winding faces up.
const tri = (x, normal = UP) => [[x, 0, 0], [x, 0, 1], [x + 1, 0, 0], normal];
const reversed = (x, normal) => [[x, 0, 0], [x + 1, 0, 0], [x, 0, 1], normal];
// A closed box, feet on the ground, outward normals.
function box(w, h, d) {
  const [x, z] = [w / 2, d / 2];
  const quad = (a, b, c, e, n) => [[a, b, c, n], [a, c, e, n]];
  return [
    ...quad([-x, 0, z], [x, 0, z], [x, h, z], [-x, h, z], [0, 0, 1]),
    ...quad([x, 0, -z], [-x, 0, -z], [-x, h, -z], [x, h, -z], [0, 0, -1]),
    ...quad([x, 0, z], [x, 0, -z], [x, h, -z], [x, h, z], [1, 0, 0]),
    ...quad([-x, 0, -z], [-x, 0, z], [-x, h, z], [-x, h, -z], [-1, 0, 0]),
    ...quad([-x, h, z], [x, h, z], [x, h, -z], [-x, h, -z], UP),
    ...quad([-x, 0, -z], [x, 0, -z], [x, 0, z], [-x, 0, z], DOWN),
  ];
}

function fixture(t) {
  const root = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-model-audit-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const write = (name, bytes) => {
    const file = path.join(root, name);
    writeFileSync(file, bytes);
    return file;
  };
  const run = (...args) => spawnSync("python3", [script, ...args], { encoding: "utf8" });
  const faults = (...files) => {
    const out = path.join(root, "faults.json");
    const result = run("faults", ...files, `--out=${out}`);
    assert.equal(result.status, 0, result.stderr);
    return { rows: JSON.parse(readFileSync(out, "utf8")), stdout: result.stdout };
  };
  return { root, write, run, faults };
}

test("faults: a sound mesh with an even fast move is clean", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  const file = f.write("clean.glb", glb(box(1, 2, 1), { clips: [{ name: "spin", node: "Wheel", degrees: [0, 20, 40, 60, 80, 100] }] }));
  const { rows, stdout } = f.faults(file);
  const [row] = rows;
  assert.equal(row.tris, 12);
  for (const key of ["degenerate", "zero_normal", "flipped", "doubled", "two_sided", "bad_weights", "zero_weights", "over4"]) {
    assert.equal(row[key], 0, key);
  }
  assert.equal(row.clips, 1);
  assert.deepEqual(row.snaps, [], "600 degrees a second at an even pace is a fast move, not a snap");
  assert.match(stdout, /scanned 1, clean 1/);
});

test("faults: each planted fault is counted once, under its own name", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  const file = f.write("planted.glb", glb([
    tri(0),
    tri(2, DOWN),                              // lit as if it faced down
    tri(4), tri(4),                            // drawn twice, same winding
    tri(6), reversed(6, DOWN),                 // a two-sided sheet
    [[8, 0, 0], [8, 0, 0], [8, 0, 0], UP],     // no area
    [[10, 0, 0], [10, 0, 1], [11, 0, 0], [0, 0, 0]], // no normal
  ]));
  const [row] = f.faults(file).rows;
  assert.equal(row.tris, 8);
  assert.equal(row.area_m2, 3.5);
  assert.equal(row.flipped, 1);
  assert.equal(row.flipped_m2, 0.5);
  assert.equal(row.doubled, 1);
  assert.equal(row.doubled_m2, 0.5);
  assert.equal(row.two_sided, 1);
  assert.equal(row.degenerate, 1);
  assert.equal(row.zero_normal, 3);
});

test("faults: a sheet's second copy is doubled whichever face came first", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  const [row] = f.faults(f.write("sheet.glb", glb([tri(0), reversed(0, DOWN), reversed(0, DOWN)]))).rows;
  assert.equal(row.two_sided, 1);
  assert.equal(row.doubled, 1);
  assert.equal(row.flipped, 0);
});

test("faults: a sound box stays sound under a turned, stretched or mirrored node, and a planted flip still shows", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  const turn = [0.3535534, 0.3535534, 0.1464466, 0.8535534]; // 45 degrees about X, then 45 about Y
  const bodies = { stretched: { rotation: turn, scale: [3, 1, 0.25] }, mirrored: { scale: [-1, 1, 1] }, big: { scale: [4, 4, 4] } };
  for (const [name, body] of Object.entries(bodies)) {
    const [sound] = f.faults(f.write(`${name}.glb`, glb(box(1, 2, 1), { body }))).rows;
    assert.equal(sound.flipped, 0, `${name}: a sound box`);
    assert.equal(sound.zero_normal, 0, `${name}: unit normals`);
    const [planted] = f.faults(f.write(`${name}-planted.glb`, glb([...box(1, 2, 1), tri(5, DOWN)], { body }))).rows;
    assert.equal(planted.flipped, 1, `${name}: the planted face`);
  }
});

test("faults: skin weights that do not sum to 1 are counted, and the ones that sum to 0 twice", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  const file = f.write("skin.glb", glb([tri(0)], { weights: [[1, 0, 0, 0], [0.5, 0.2, 0, 0], [0, 0, 0, 0]] }));
  const [row] = f.faults(file).rows;
  assert.equal(row.bad_weights, 2);
  assert.equal(row.zero_weights, 1);
  assert.equal(row.over4, 0);
});

test("faults: a skinned box carried by its joint stays sound, and a planted flip still shows", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  const skin = { translation: [6, 2, -3] };
  const [sound] = f.faults(f.write("skinned.glb", glb(box(1, 2, 1), { skin }))).rows;
  assert.equal(sound.flipped, 0);
  assert.equal(sound.bad_weights, 0);
  const [planted] = f.faults(f.write("skinned-planted.glb", glb([...box(1, 2, 1), tri(5, DOWN)], { skin }))).rows;
  assert.equal(planted.flipped, 1);
});

test("faults: a fifth influence is counted", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  const weights = [[0.25, 0.25, 0.25, 0.25], [0.2, 0.2, 0.2, 0.2], [1, 0, 0, 0]];
  const more = [[0, 0, 0, 0], [0.2, 0, 0, 0], [0, 0, 0, 0]];
  const [row] = f.faults(f.write("five.glb", glb([tri(0)], { weights, more }))).rows;
  assert.equal(row.over4, 1);
  assert.equal(row.bad_weights, 0);
});

test("faults: a one-frame jump is a snap, and a STEP sampler marks it held", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  const jump = [0, 1, 2, 172, 173, 174];
  const file = f.write("snap.glb", glb(box(1, 1, 1), { clips: [
    { name: "cast", node: "Hand", degrees: jump },
    { name: "beat", node: "Head", degrees: jump, interpolation: "STEP" },
    { name: "lurch", node: "Hull", metres: [0, 0.01, 0.02, 0.52, 0.53, 0.54] },
    { name: "dash", node: "Cart", metres: [0, 0.5, 1, 1.5, 2, 2.5] },
    { name: "whip", node: "Tail", degrees: jump, interpolation: "CUBICSPLINE" },
  ] }));
  const { rows, stdout } = f.faults(file);
  const snaps = rows[0].snaps;
  assert.equal(snaps.length, 4, "the even 15 m/s dash is a fast move, not a snap");
  const whip = snaps.find((snap) => snap.clip === "whip");
  assert.ok(Math.abs(whip.speed - 5100) < 1, `a cubic spline's values are read from between its tangents: ${whip.speed}`);
  const cast = snaps.find((snap) => snap.clip === "cast");
  assert.deepEqual({ node: cast.node, path: cast.path, t: cast.t, unit: cast.unit, held: cast.held },
    { node: "Hand", path: "rotation", t: 0.067, unit: "deg/s", held: false });
  assert.ok(Math.abs(cast.speed - 5100) < 1 && Math.abs(cast.beside - 30) < 1, `${cast.speed} beside ${cast.beside}`);
  assert.equal(snaps.find((snap) => snap.clip === "beat").held, true);
  const lurch = snaps.find((snap) => snap.clip === "lurch");
  assert.deepEqual({ node: lurch.node, path: lurch.path, unit: lurch.unit }, { node: "Hull", path: "translation", unit: "m/s" });
  assert.ok(Math.abs(lurch.speed - 15) < 0.1, `${lurch.speed}`);
  assert.match(stdout, /scanned 1, clean 0/, "a snap that is not held keeps the file off the clean count");
});

test("faults: a file that is not a GLB is an error row, and the run still exits 0", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  const bad = f.write("bad.glb", "fixture");
  const good = f.write("good.glb", glb(box(1, 1, 1)));
  const { rows, stdout } = f.faults(bad, good, path.join(f.root, "missing.glb"));
  assert.equal(rows.length, 3);
  assert.match(rows[0].error, /not a GLB/);
  assert.match(rows[2].error, /FileNotFoundError/);
  assert.match(stdout, /scanned 3, clean 1/);
});

test("outlines: the same shape overlaps fully, a different one less, and the sheet hides the names", { skip: !pillow && "python3 has no numpy or Pillow" }, (t) => {
  const f = fixture(t);
  const files = [
    f.write("cart_a.glb", glb(box(2, 1, 2))),
    f.write("cart_b.glb", glb(box(2, 1, 2))),
    f.write("mast.glb", glb(box(0.5, 4, 0.5))),
  ];
  const out = path.join(f.root, "outlines");
  const result = f.run("outlines", ...files, `--out=${out}`);
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(readFileSync(path.join(out, "outlines.json"), "utf8"));
  assert.deepEqual(report.pairs[0], [1, "cart_a", "cart_b"]);
  assert.ok(report.pairs[1][0] < 0.5 && report.pairs[2][0] < 0.5, JSON.stringify(report.pairs));
  assert.ok(report.area_px.cart_a > report.area_px.mast);
  const key = JSON.parse(readFileSync(path.join(out, "outlines-key.json"), "utf8"));
  assert.deepEqual(Object.keys(key), ["A", "B", "C"]);
  assert.deepEqual(Object.values(key).sort(), ["cart_a", "cart_b", "mast"]);
  assert.equal(readFileSync(path.join(out, "outlines-blind.jpg")).subarray(0, 2).toString("hex"), "ffd8");
});

test("outlines: the canvas holds the largest model whole, so a wide low shape is not cut at the feet", { skip: !pillow && "python3 has no numpy or Pillow" }, (t) => {
  const f = fixture(t);
  const out = path.join(f.root, "outlines");
  const result = f.run("outlines", f.write("tower.glb", glb(box(2, 20, 2))), f.write("slab.glb", glb(box(16, 0.2, 16))), `--out=${out}`);
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(readFileSync(path.join(out, "outlines.json"), "utf8"));
  // Orthographic, 35 degrees down, 30 degrees round: a box's outline area follows from its three visible faces.
  const [cos, sin] = [Math.cos((35 * Math.PI) / 180), Math.sin((35 * Math.PI) / 180)];
  const area = (w, h, d) => (w * d * sin + h * cos * (d * Math.sin(Math.PI / 6) + w * Math.cos(Math.PI / 6))) * 32 * 32;
  for (const [name, size] of [["tower", [2, 20, 2]], ["slab", [16, 0.2, 16]]]) {
    assert.ok(Math.abs(report.area_px[name] / area(...size) - 1) < 0.04, `${name}: ${report.area_px[name]} px against ${area(...size)}`);
  }
});

test("outlines: a skinned surface is placed by its joint", { skip: !pillow && "python3 has no numpy or Pillow" }, (t) => {
  const f = fixture(t);
  const out = path.join(f.root, "outlines");
  const files = [
    f.write("still.glb", glb(box(2, 1, 2))),
    f.write("carried.glb", glb(box(2, 1, 2), { skin: { translation: [6, 0, 0] } })),
    f.write("level.glb", glb(box(2, 1, 2), { skin: { translation: [0, 9, 0] } })),
  ];
  assert.equal(f.run("outlines", ...files, `--out=${out}`).status, 0);
  const pairs = JSON.parse(readFileSync(path.join(out, "outlines.json"), "utf8")).pairs;
  const overlap = (a, b) => pairs.find((pair) => pair.includes(a) && pair.includes(b))[0];
  assert.equal(overlap("still", "carried"), 0, "six metres to the side, the two boxes share nothing");
  assert.equal(overlap("still", "level"), 1, "lifted straight up, the feet come back to the shared ground point");
});

test("usage: an unknown mode, no files and outlines without --out all exit 2", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  assert.equal(f.run("nonsense").status, 2);
  assert.equal(f.run("faults").status, 2);
  assert.equal(f.run("outlines", f.write("a.glb", glb(box(1, 1, 1)))).status, 2);
});
