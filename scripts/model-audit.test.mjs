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
// clips: [{ name, node, interpolation, degrees: [...] }], one rotation key about Y every 1/30 s.
// weights: one [w, w, w, w] per vertex, to make the surface skinned.
function glb(tris, clips = [], weights = null) {
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
    nodes: [{ name: "Body", mesh: 0 }, ...clips.map((clip) => ({ name: clip.node }))],
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
  if (weights) json.meshes[0].primitives[0].attributes.WEIGHTS_0 = accessor(view(weights.flat()), { count, type: "VEC4" });
  const animations = clips.map((clip, i) => {
    const times = clip.degrees.map((_, key) => key / 30);
    const turns = clip.degrees.flatMap((degrees) => {
      const half = (degrees * Math.PI) / 360;
      return [0, Math.sin(half), 0, Math.cos(half)];
    });
    const input = accessor(view(times), { count: times.length, type: "SCALAR", min: [0], max: [times.at(-1)] });
    const output = accessor(view(turns), { count: times.length, type: "VEC4" });
    return {
      name: clip.name,
      samplers: [{ input, output, interpolation: clip.interpolation ?? "LINEAR" }],
      channels: [{ sampler: 0, target: { node: i + 1, path: "rotation" } }],
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
  const file = f.write("clean.glb", glb(box(1, 2, 1), [{ name: "spin", node: "Wheel", degrees: [0, 20, 40, 60, 80, 100] }]));
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

test("faults: skin weights that do not sum to 1 are counted, and the ones that sum to 0 twice", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  const file = f.write("skin.glb", glb([tri(0)], [], [[1, 0, 0, 0], [0.5, 0.2, 0, 0], [0, 0, 0, 0]]));
  const [row] = f.faults(file).rows;
  assert.equal(row.bad_weights, 2);
  assert.equal(row.zero_weights, 1);
  assert.equal(row.over4, 0);
});

test("faults: a one-frame jump is a snap, and a STEP sampler marks it held", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  const jump = [0, 1, 2, 172, 173, 174];
  const file = f.write("snap.glb", glb(box(1, 1, 1), [
    { name: "cast", node: "Hand", degrees: jump },
    { name: "beat", node: "Head", degrees: jump, interpolation: "STEP" },
  ]));
  const { rows, stdout } = f.faults(file);
  const snaps = rows[0].snaps;
  assert.equal(snaps.length, 2);
  const cast = snaps.find((snap) => snap.clip === "cast");
  assert.deepEqual({ node: cast.node, path: cast.path, t: cast.t, unit: cast.unit, held: cast.held },
    { node: "Hand", path: "rotation", t: 0.067, unit: "deg/s", held: false });
  assert.ok(Math.abs(cast.speed - 5100) < 1 && Math.abs(cast.beside - 30) < 1, `${cast.speed} beside ${cast.beside}`);
  assert.equal(snaps.find((snap) => snap.clip === "beat").held, true);
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
  assert.deepEqual(report.clipped, []);
  assert.ok(report.area_px.cart_a > report.area_px.mast);
  const key = JSON.parse(readFileSync(path.join(out, "outlines-key.json"), "utf8"));
  assert.deepEqual(Object.keys(key), ["A", "B", "C"]);
  assert.deepEqual(Object.values(key).sort(), ["cart_a", "cart_b", "mast"]);
  assert.equal(readFileSync(path.join(out, "outlines-blind.jpg")).subarray(0, 2).toString("hex"), "ffd8");
});

test("outlines: a model taller than the canvas is named as clipped", { skip: !pillow && "python3 has no numpy or Pillow" }, (t) => {
  const f = fixture(t);
  const out = path.join(f.root, "outlines");
  const result = f.run("outlines", f.write("tower.glb", glb(box(1, 40, 1))), `--out=${out}`);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(readFileSync(path.join(out, "outlines.json"), "utf8")).clipped, ["tower"]);
  assert.match(result.stdout, /clipped by the 12 m canvas/);
});

test("usage: an unknown mode, no files and outlines without --out all exit 2", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const f = fixture(t);
  assert.equal(f.run("nonsense").status, 2);
  assert.equal(f.run("faults").status, 2);
  assert.equal(f.run("outlines", f.write("a.glb", glb(box(1, 1, 1)))).status, 2);
});
