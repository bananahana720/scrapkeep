import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { CAP, overCap, scanCover, scanFaults } from "./far-faults.mjs";

// SG-16: every park prop's far mesh stays under the inside-out cap (scripts/far-faults.mjs).
const numpy = spawnSync("python3", ["-c", "import numpy"]).status === 0;

// A GLB of unindexed triangles with per-face normals: [[p0, p1, p2, normal]].
function glb(tris) {
  const floats = [...tris.flatMap(([a, b, c]) => [...a, ...b, ...c]), ...tris.flatMap(([, , , n]) => [...n, ...n, ...n])];
  const count = tris.length * 3;
  const corners = tris.flatMap(([a, b, c]) => [a, b, c]);
  const bound = (pick) => [0, 1, 2].map((axis) => pick(...corners.map((corner) => corner[axis])));
  const json = {
    asset: { version: "2.0" },
    scene: 0,
    scenes: [{ nodes: [0] }],
    nodes: [{ name: "Body", mesh: 0 }],
    meshes: [{ primitives: [{ attributes: { POSITION: 0, NORMAL: 1 } }] }],
    buffers: [{ byteLength: floats.length * 4 }],
    bufferViews: [
      { buffer: 0, byteOffset: 0, byteLength: count * 12, target: 34962 },
      { buffer: 0, byteOffset: count * 12, byteLength: count * 12, target: 34962 },
    ],
    accessors: [
      { bufferView: 0, componentType: 5126, count, type: "VEC3", min: bound(Math.min), max: bound(Math.max) },
      { bufferView: 1, componentType: 5126, count, type: "VEC3" },
    ],
  };
  const bin = Buffer.from(new Float32Array(floats).buffer);
  let text = Buffer.from(JSON.stringify(json));
  text = Buffer.concat([text, Buffer.alloc((4 - (text.length % 4)) % 4, 0x20)]);
  const header = Buffer.alloc(12);
  header.writeUInt32LE(0x46546c67, 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + text.length + 8 + bin.length, 8);
  const chunk = (data, type) => {
    const head = Buffer.alloc(8);
    head.writeUInt32LE(data.length, 0);
    head.writeUInt32LE(type, 4);
    return Buffer.concat([head, data]);
  };
  return Buffer.concat([header, chunk(text, 0x4e4f534a), chunk(bin, 0x004e4942)]);
}

// A unit quad facing up, as two triangles; `flip` winds the second one the other way with the same up normal.
const UP = [0, 1, 0];
const quad = (x, flip = false) => [
  [[x, 0, 0], [x, 0, 1], [x + 1, 0, 0], UP],
  flip ? [[x + 1, 0, 0], [x + 1, 0, 1], [x, 0, 1], UP] : [[x + 1, 0, 0], [x, 0, 1], [x + 1, 0, 1], UP],
];

test("far faults: every park prop's far mesh is under the inside-out cap", { skip: !numpy && "python3 has no numpy" }, () => {
  const rows = scanFaults();
  assert.ok(rows.length >= 280, `${rows.length} far meshes scanned`);
  const over = overCap(rows);
  assert.deepEqual(over, [], over.map((o) => `${o.file} ${(o.share * 100).toFixed(2)}%`).join("; "));
});

test("far faults: a planted flipped far mesh under the props glob fails, a sound one passes", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "far-faults-plant-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  mkdirSync(path.join(dir, "assets/models/park/props/dam"), { recursive: true });
  writeFileSync(path.join(dir, "assets/models/park/props/dam/sound_lod2.glb"), glb([...quad(0), ...quad(2)]));
  writeFileSync(path.join(dir, "assets/models/park/props/dam/planted_lod2.glb"), glb([...quad(0), ...quad(2, true)]));
  const rows = scanFaults(["assets/models/park/props/*/*_lod2.glb"], dir);
  assert.equal(rows.length, 2);
  const over = overCap(rows);
  assert.equal(over.length, 1, JSON.stringify(rows.map((r) => [r.file, r.flipped_m2, r.area_m2])));
  assert.match(over[0].file, /planted_lod2\.glb$/);
  assert.ok(over[0].share > CAP);
});

test("far cover: every park prop LOD fills LOD0's outline", { skip: !numpy && "python3 has no numpy" }, () => {
  const rows = scanCover();
  assert.ok(rows.length >= 560, `${rows.length} LODs scored`);
  const thin = rows.filter((row) => row.under);
  assert.deepEqual(thin, [], thin.map((row) => `${row.file} ${(row.cover * 100).toFixed(1)}%`).join("; "));
});

test("far cover: a planted LOD that lost a part fails, a whole one passes", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "far-cover-plant-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const props = path.join(dir, "assets/models/park/props/dam");
  mkdirSync(props, { recursive: true });
  // A wall of four upright unit squares side by side; the hollow LOD keeps only the two outer ones, as the drum kept its rings.
  const N = [0, 0, 1];
  const panel = (x) => [
    [[x, 0, 0], [x + 1, 0, 0], [x, 1, 0], N],
    [[x + 1, 0, 0], [x + 1, 1, 0], [x, 1, 0], N],
  ];
  const wall = [0, 1, 2, 3].flatMap((x) => panel(x - 2));
  for (const name of ["whole", "hollow"]) writeFileSync(path.join(props, `${name}.glb`), glb(wall));
  for (const lod of ["_lod1", "_lod2"]) {
    writeFileSync(path.join(props, `whole${lod}.glb`), glb(wall));
    writeFileSync(path.join(props, `hollow${lod}.glb`), glb(lod === "_lod2" ? [...panel(-2), ...panel(1)] : wall));
  }
  const rows = scanCover(["assets/models/park/props/*/*.glb"], dir);
  assert.equal(rows.length, 4);
  const thin = rows.filter((row) => row.under);
  assert.equal(thin.length, 1, JSON.stringify(rows));
  assert.match(thin[0].file, /hollow_lod2\.glb$/);
});

test("far cover: between the floor and the target a LOD fails with triangles to spare and passes at the cap", { skip: !numpy && "python3 has no numpy" }, (t) => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "far-cover-band-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const props = path.join(dir, "assets/models/park/props/dam");
  mkdirSync(props, { recursive: true });
  const N = [0, 0, 1];
  const span = (x0, x1) => [
    [[x0, 0, 0], [x1, 0, 0], [x0, 1, 0], N],
    [[x1, 0, 0], [x1, 1, 0], [x0, 1, 0], N],
  ];
  // LOD0: 24 unit panels in a row (48 triangles). Both LODs keep 20 of them, about 0.83 of the outline: "lean" as one
  // long quad (2 triangles, room to spare under the cap), "capped" as 20 panels (40 triangles, at the cap).
  const panels = (n) => Array.from({ length: n }, (_, i) => span(i - 12, i - 11)).flat();
  for (const name of ["lean", "capped"]) {
    writeFileSync(path.join(props, `${name}.glb`), glb(panels(24)));
    writeFileSync(path.join(props, `${name}_lod1.glb`), glb(panels(24)));
  }
  writeFileSync(path.join(props, "lean_lod2.glb"), glb(span(-12, 8)));
  writeFileSync(path.join(props, "capped_lod2.glb"), glb(panels(20)));
  const rows = scanCover(["assets/models/park/props/*/*.glb"], dir);
  const lod2 = Object.fromEntries(rows.filter((row) => row.file.endsWith("_lod2.glb")).map((row) => [path.basename(row.file), row]));
  assert.ok(lod2["lean_lod2.glb"].cover > 0.8 && lod2["lean_lod2.glb"].cover < 0.85, JSON.stringify(lod2));
  assert.equal(lod2["lean_lod2.glb"].under, true);
  assert.equal(lod2["capped_lod2.glb"].under, false, JSON.stringify(lod2));
});
