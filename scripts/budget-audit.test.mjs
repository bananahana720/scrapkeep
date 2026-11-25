import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { inspectGlb } from "./asset-inspect.mjs";
import {
  characters,
  evaluate,
  loadBudgets,
  measureRegistry,
  summarize,
} from "../sketches/core-loop/tools/budget_audit.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "..");
const sketch = path.join(repo, "sketches/core-loop");
const tool = path.join(sketch, "tools/budget_audit.mjs");
const budgetFile = path.join(sketch, "assets/asset_budgets.json");
const sha = (f) => createHash("sha256").update(fs.readFileSync(f)).digest("hex");

const budgets = {
  classes: {
    enemy: { tris: 1100, verts: 2100, draws: 3, set_by: "test" },
    prop: { tris: 270, verts: 610, draws: 1, set_by: "test" },
  },
  texture: { max_side: 2048 },
};
const asset = (over) => ({
  id: "a",
  path: "res://a.glb",
  class: "prop",
  ships: true,
  tris: 100,
  verts: 200,
  draws: 1,
  bones: 0,
  clips: 0,
  longest_clip_s: 0,
  texture_side: 0,
  exception: null,
  ...over,
});
const texture = (side, exception = null) =>
  asset({
    id: `t${side}`,
    class: "texture",
    tris: 0,
    verts: 0,
    draws: 0,
    texture_side: side,
    exception,
  });
const base = () => [
  asset({ id: "p" }),
  asset({ id: "e", class: "enemy", tris: 900, verts: 1500, draws: 2 }),
  texture(512),
];

function skinned(joints, clipLengths) {
  const nodes = [{ mesh: 0, skin: joints > 0 ? 0 : undefined }];
  for (let i = 0; i < joints; i++) nodes.push({});
  const pos = Buffer.alloc(36);
  pos.writeFloatLE(1, 12);
  pos.writeFloatLE(1, 28);
  const parts = [pos];
  const views = [{ buffer: 0, byteOffset: 0, byteLength: 36 }];
  const accessors = [{ bufferView: 0, componentType: 5126, count: 3, type: "VEC3" }];
  const animations = [];
  let offset = 36;
  for (const len of clipLengths) {
    const times = Buffer.alloc(8);
    times.writeFloatLE(0, 0);
    times.writeFloatLE(len, 4);
    const vals = Buffer.alloc(24);
    parts.push(times, vals);
    views.push(
      { buffer: 0, byteOffset: offset, byteLength: 8 },
      { buffer: 0, byteOffset: offset + 8, byteLength: 24 },
    );
    accessors.push(
      { bufferView: views.length - 2, componentType: 5126, count: 2, type: "SCALAR" },
      { bufferView: views.length - 1, componentType: 5126, count: 2, type: "VEC3" },
    );
    animations.push({
      samplers: [{ input: accessors.length - 2, output: accessors.length - 1 }],
      channels: [{ sampler: 0, target: { node: 0, path: "translation" } }],
    });
    offset += 32;
  }
  const bin = Buffer.concat(parts);
  const doc = {
    asset: { version: "2.0" },
    buffers: [{ byteLength: bin.length }],
    bufferViews: views,
    accessors,
    meshes: [{ primitives: [{ attributes: { POSITION: 0 } }] }],
    nodes,
    animations,
    scenes: [{ nodes: [0] }],
    scene: 0,
  };
  if (joints > 0) doc.skins = [{ joints: Array.from({ length: joints }, (_, i) => i + 1) }];
  if (!animations.length) delete doc.animations;
  const raw = Buffer.from(JSON.stringify(doc));
  const json = Buffer.alloc(Math.ceil(raw.length / 4) * 4, 0x20);
  raw.copy(json);
  const head = Buffer.alloc(20);
  head.writeUInt32LE(0x46546c67);
  head.writeUInt32LE(2, 4);
  head.writeUInt32LE(28 + json.length + bin.length, 8);
  head.writeUInt32LE(json.length, 12);
  head.writeUInt32LE(0x4e4f534a, 16);
  const bh = Buffer.alloc(8);
  bh.writeUInt32LE(bin.length);
  bh.writeUInt32LE(0x004e4942, 4);
  return Buffer.concat([head, json, bh, bin]);
}

test("inspect reports bones, clip count and longest clip", () => {
  const inv = inspectGlb(skinned(3, [0.5, 1.5, 1.0])).inventory;
  assert.equal(inv.bones, 3);
  assert.equal(inv.clips, 3);
  assert.equal(inv.longest_clip_s, 1.5);
  assert.equal(inv.animations, 3);
});

test("inspect reports zero bones and clips for a static asset", () => {
  const inv = inspectGlb(skinned(0, [])).inventory;
  assert.equal(inv.bones, 0);
  assert.equal(inv.clips, 0);
  assert.equal(inv.longest_clip_s, 0);
});

test("summarize gives nearest-rank median and p90", () => {
  const s = summarize([5, 1, 3, 2, 4, 6, 7, 8, 9, 10]);
  assert.equal(s.median, 5.5);
  assert.equal(s.p90, 9);
  assert.equal(summarize([7]).median, 7);
  assert.equal(summarize([]).median, 0);
});

test("a clean set passes with every category counted", () => {
  const r = evaluate(base(), budgets);
  assert.deepEqual(r.failures, []);
  assert.deepEqual(
    r.rows.map((x) => [x.category, x.count]),
    [
      ["enemy", 1],
      ["prop", 1],
      ["texture", 1],
    ],
  );
});

test("a planted empty category fails the run", () => {
  const withGhost = {
    ...budgets,
    classes: { ...budgets.classes, ghost: { tris: 10, verts: 10, draws: 1, set_by: "test" } },
  };
  const r = evaluate(base(), withGhost);
  assert.ok(
    r.failures.some((f) => /ghost.*no assets/.test(f)),
    r.failures.join("|"),
  );
});

test("a class marked no member yet is pending, not a failure", () => {
  const pending = {
    ...budgets,
    classes: {
      ...budgets.classes,
      later: { tris: 10, verts: 10, draws: 1, set_by: "none; no member yet" },
    },
  };
  const r = evaluate(base(), pending);
  assert.deepEqual(r.failures, []);
  assert.equal(r.rows.find((x) => x.category === "later").pending, true);
});

test("over the triangle cap fails; an exception raises that asset's cap", () => {
  const over = base().concat(asset({ id: "big", tris: 271 }));
  assert.ok(evaluate(over, budgets).failures.some((f) => /big.*tris/.test(f)));
  const ok = base().concat(asset({ id: "big", tris: 400, exception: { tris: 400 } }));
  assert.deepEqual(evaluate(ok, budgets).failures, []);
  const still = base().concat(asset({ id: "big", tris: 401, exception: { tris: 400 } }));
  assert.ok(evaluate(still, budgets).failures.some((f) => /big.*tris/.test(f)));
});

test("an unshipped model over its cap is a note, not a failure", () => {
  const r = evaluate(base().concat(asset({ id: "unwired", tris: 999, ships: false })), budgets);
  assert.deepEqual(r.failures, []);
  assert.ok(r.notes.some((n) => /unwired.*tris/.test(n)));
  assert.equal(r.rows.find((x) => x.category === "prop").count, 1);
});

test("verts and draws are capped too", () => {
  assert.ok(
    evaluate(base().concat(asset({ id: "v", verts: 611 })), budgets).failures.some((f) =>
      /v.*verts/.test(f),
    ),
  );
  assert.ok(
    evaluate(base().concat(asset({ id: "d", draws: 2 })), budgets).failures.some((f) =>
      /d.*draws/.test(f),
    ),
  );
});

test("a texture above 2048 passes only with an exception field", () => {
  assert.deepEqual(evaluate(base().concat(texture(2048)), budgets).failures, []);
  assert.ok(
    evaluate(base().concat(texture(4096)), budgets).failures.some((f) => /t4096.*texture/.test(f)),
  );
  assert.deepEqual(
    evaluate(base().concat(texture(4096, { max_side: 4096 })), budgets).failures,
    [],
  );
});

test("enemy bones at 40 pass and at 41 fail", () => {
  const e = (n) => base().concat(asset({ id: "rig", class: "enemy", tris: 100, bones: n }));
  assert.deepEqual(evaluate(e(40), budgets).failures, []);
  assert.ok(evaluate(e(41), budgets).failures.some((f) => /rig.*bones/.test(f)));
});

test("counted categories with zero assets each fail", () => {
  const r = evaluate([texture(512)], budgets);
  assert.equal(r.failures.filter((f) => /no assets/.test(f)).length, 2);
});

test("a nonfinite measurement is a structural failure", () => {
  const r = evaluate(base().concat(asset({ id: "nan", tris: Number.NaN })), budgets);
  assert.ok(r.failures.some((f) => /nan.*not finite/.test(f)));
});

test("per-character sums add shell, heft layers and pilot body", () => {
  const set = [
    asset({
      id: "pilot_sable_anim",
      path: "res://assets/models/pilot_sable_anim.glb",
      class: "pilot",
      tris: 4000,
      verts: 3000,
      bones: 20,
      clips: 5,
      longest_clip_s: 1.2,
    }),
    asset({
      id: "shell_sable",
      path: "res://assets/models/world_one/shell_sable.glb",
      class: "shell",
      tris: 10000,
      verts: 9000,
    }),
    asset({
      id: "shell_sable_c2",
      path: "res://assets/models/world_one/shell_sable_c2.glb",
      class: "detail",
      tris: 800,
      verts: 900,
    }),
    asset({
      id: "shell_sable_c3",
      path: "res://assets/models/world_one/shell_sable_c3.glb",
      class: "detail",
      tris: 900,
      verts: 950,
    }),
    asset({
      id: "shell_sable_felt",
      path: "res://assets/models/world_one/shell_sable_felt.glb",
      class: "shell",
      tris: 99999,
    }),
    asset({
      id: "shell_sable",
      path: "res://assets/models/shell_sable.glb",
      class: "shell",
      ships: false,
      tris: 77777,
    }),
  ];
  const c = characters(set);
  assert.equal(c.length, 1);
  assert.equal(c[0].name, "sable");
  assert.equal(c[0].tris, 4000 + 10000 + 800 + 900);
  assert.equal(c[0].parts, 4);
  assert.equal(c[0].bones, 20);
});

test("the real registry audits clean with every counted category nonzero", () => {
  const measured = measureRegistry(repo);
  assert.ok(measured.length > 100, `measured ${measured.length}`);
  const r = evaluate(measured, loadBudgets(repo));
  assert.deepEqual(r.failures, []);
  assert.ok(r.rows.filter((x) => !x.pending).every((x) => x.count > 0));
  assert.ok(characters(measured).length >= 6);
  assert.ok(
    r.rows.find((x) => x.category === "texture").stats.texture_side.max > 0,
    "texture sides read",
  );
  assert.ok(
    measured
      .filter((a) => a.class === "pilot" && a.id !== "pilot_patch_anim")
      .every((a) => a.bones > 0 && a.clips > 0),
    "pilot rigs read",
  );
});

test("the CLI exits 0, prints median, p90 and reference rows, and edits no budget file", () => {
  const before = sha(budgetFile);
  const child = spawnSync(process.execPath, [tool], { cwd: repo, encoding: "utf8" });
  assert.equal(child.status, 0, child.stdout + child.stderr);
  assert.match(child.stdout, /median/);
  assert.match(child.stdout, /p90/);
  assert.match(child.stdout, /Risk of Rain 2/);
  assert.match(child.stdout, /Gunfire Reborn/);
  assert.match(child.stdout, /Roboquest/);
  assert.match(child.stdout, /per whole character/i);
  assert.equal(sha(budgetFile), before);
});

test("the CLI exits 1 on a planted empty category", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "budget-audit-"));
  try {
    const b = JSON.parse(fs.readFileSync(budgetFile, "utf8"));
    b.classes.ghost = { tris: 1, verts: 1, draws: 1, set_by: "planted" };
    const f = path.join(dir, "budgets.json");
    fs.writeFileSync(f, JSON.stringify(b));
    const child = spawnSync(process.execPath, [tool, "--budgets", f], {
      cwd: repo,
      encoding: "utf8",
    });
    assert.equal(child.status, 1, child.stdout);
    assert.match(child.stdout + child.stderr, /ghost.*no assets/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
