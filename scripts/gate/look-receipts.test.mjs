import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

import * as render from "./model-render-receipt.mjs";
import * as census from "./stand-ins-receipt.mjs";

const HEAD = "abc1234";
const KINDS = ["chaser", "lobber", "swatter", "hooker", "netcaster", "boom_tender"];

// A committed scratch repo for the dirty-checkout checks.
function repo() {
  const dir = mkdtempSync(path.join(os.tmpdir(), "look-receipts-git-"));
  const git = (...args) => spawnSync("git", ["-c", "user.name=t", "-c", "user.email=t@t", ...args], { cwd: dir, encoding: "utf8" });
  git("init", "-q");
  writeFileSync(path.join(dir, "a.txt"), "one");
  git("add", "a.txt");
  git("commit", "-q", "-m", "one");
  return { dir, head: git("rev-parse", "HEAD").stdout.trim() };
}

// --- models-render ---

function compareLog({ kinds = KINDS, failed = [], plant = "", judged = kinds.length } = {}) {
  const lines = kinds.map((k) => `${failed.includes(k) ? "FAIL" : "PASS"} ${k}: view 0 brightness 0.95 of authored (0.400, authored 0.420), near-black 0.01 (authored 0.01)`);
  lines.push(`SUMMARY ${JSON.stringify({ judged, pinned: 6, failed, plant })}`);
  lines.push(`model_render_check: ${failed.length ? `FAIL (${failed.length})` : "PASS"} (${judged} kinds, ...)`);
  return { log: lines.join("\n") };
}
const plantedLog = (failed = ["hooker"]) => compareLog({ failed, plant: "dark_hooker" });

test("models-render: every kind judged, none failed, the plant caught -> pass", () => {
  const r = render.buildReceipt(compareLog(), plantedLog(), HEAD);
  assert.deepEqual(Object.keys(r), ["head", "pass", "measured", "plant_caught"]);
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /^all 6 generated enemy models render/);
  assert.match(r.measured, /how a model looks to a person still need the PC look/);
});

test("models-render: a dark model is a miss and is named", () => {
  const r = render.buildReceipt(compareLog({ failed: ["netcaster"] }), plantedLog(["netcaster", "hooker"]), HEAD);
  assert.equal(r.pass, false);
  assert.match(r.measured, /^1 of 6 generated enemy models render too dark beside the authored ones: netcaster/);
});

test("models-render: fewer kinds than the pin, and no data, are misses", () => {
  const few = render.buildReceipt(compareLog({ kinds: KINDS.slice(0, 5) }), plantedLog(), HEAD);
  assert.equal(few.pass, false);
  assert.match(few.measured, /^5 kinds judged with 5 verdict lines, pinned 6/);
  const none = render.buildReceipt({ log: render.NO_DISPLAY }, { log: render.NO_DISPLAY }, HEAD);
  assert.equal(none.pass, false);
  assert.equal(none.plant_caught, false);
  assert.match(none.measured, /^no SUMMARY line, so no model was judged: not run: the shoot needs a graphics display/);
});

test("models-render: a plant not caught, or caught for the wrong kind, voids the pass", () => {
  assert.equal(render.buildReceipt(compareLog(), plantedLog([]), HEAD).pass, false);
  assert.equal(render.buildReceipt(compareLog(), plantedLog(["lobber"]), HEAD).plant_caught, false);
  assert.equal(render.buildReceipt(compareLog(), { log: "" }, HEAD).plant_caught, false);
  // A hooker that already fails in the real run says nothing about the plant.
  assert.equal(render.buildReceipt(compareLog({ failed: ["hooker"] }), plantedLog(), HEAD).plant_caught, false);
});

test("models-render: a plant switch that reached the real shoot fails the receipt", () => {
  const r = render.buildReceipt(compareLog({ failed: ["hooker"], plant: "dark_hooker" }), plantedLog(), HEAD);
  assert.equal(r.pass, false);
  assert.match(r.measured, /^the real shoot ran planted \(dark_hooker\)/);
});

test("models-render: the producer takes the head from git, refuses a dirty checkout, and fails with no display", () => {
  const { dir, head } = repo();
  let ran = 0;
  const ok = render.produce({ cwd: dir, run: () => { ran += 1; return { real: compareLog(), plant: plantedLog() }; } });
  assert.equal(ok.head, head);
  assert.equal(ok.pass, true);
  const stub = render.produce({ cwd: dir });
  assert.equal(stub.pass, false, "the default runner shoots nothing, so it never passes");
  writeFileSync(path.join(dir, "a.txt"), "two");
  assert.throws(() => render.produce({ cwd: dir, run: () => { ran += 1; return {}; } }), /refusing: uncommitted changes/);
  assert.equal(ran, 1, "a dirty checkout never runs the shoot");
});

// --- no-code-stand-ins ---

const STAKE = { file: "stakes.gd", mesh: "CylinderMesh", shape: "SableStakes/Stake/MeshInstance3D", row: "W1-23", path: "SableStakes/Stake1/m", stage: 1 };
const SPHERE = { file: "build_read.gd", mesh: "SphereMesh", shape: "SubViewport/Node3D/MeshInstance3D", row: "W1-46", path: "PauseMenu/BuildRead/m", stage: 1 };
const BOX = { file: "activities.gd", mesh: "BoxMesh", shape: "Activities/Activity_enemy_camp/PlantedStandIn", row: "", path: "Activities/Activity_enemy_camp/PlantedStandIn", stage: 1 };

function censusRun({ surfaces = census.PINNED_SURFACES, standIns = [], fresh = [], stale = [], plant = "", ok, fail = 0 } = {}) {
  const failing = fail + (fresh.length ? 1 : 0) + (stale.length ? 1 : 0);
  const lines = ["[the pin reads]  -> PASS", `[no primitive surface outside the pin] ${fresh.length} new -> ${fresh.length ? "FAIL" : "PASS"}`];
  for (let i = 0; i < fail; i += 1) lines.push("[child ran clean] exit 1 -> FAIL");
  lines.push(`SUMMARY ${JSON.stringify({ surfaces, pinned: census.PINNED_SURFACES, stand_ins: standIns, new: fresh, stale, plant })}`);
  lines.push(`${census.TEST}: ${failing ? `FAIL (${failing})` : "PASS (11 checks)"}`);
  return { ok: ok ?? failing === 0, log: lines.join("\n") };
}
const censusPlant = (fresh = [BOX]) => censusRun({ surfaces: census.PINNED_SURFACES + 1, fresh, plant: "dam_box" });

test("no-code-stand-ins: no stand-in, no new primitive, enough surfaces, the plant caught -> pass", () => {
  const r = census.buildReceipt(censusRun(), censusPlant(), HEAD);
  assert.deepEqual(Object.keys(r), ["head", "pass", "measured", "plant_caught"]);
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /^129 primitive surfaces counted .*; no code-built stand-in left; plant: .* failed and named it new; what is not judged/);
});

test("no-code-stand-ins: a stand-in the pin allows still fails and is named by file and row; one ruled to wait is held", () => {
  const r = census.buildReceipt(censusRun({ standIns: [SPHERE, STAKE] }), censusPlant(), HEAD);
  assert.equal(r.pass, false);
  assert.match(r.measured, /1 code-built stand-in\(s\) left: SubViewport\/Node3D\/MeshInstance3D in build_read\.gd \(SphereMesh, owed by W1-46\)/);
  assert.match(r.measured, /waiting: SableStakes\/Stake\/MeshInstance3D in stakes\.gd \(CylinderMesh, owed by W1-23\) \(project-guide\/handoff\/DECISIONS\.md:117/);
  const held = census.buildReceipt(censusRun({ standIns: [STAKE] }), censusPlant(), HEAD);
  assert.equal(held.pass, true);
  assert.match(held.measured, /no code-built stand-in left but those ruled to wait/);
});

test("no-code-stand-ins: fewer surfaces than the pin, no data, a new primitive and a stale row are misses", () => {
  const few = census.buildReceipt(censusRun({ surfaces: census.PINNED_SURFACES - 1 }), censusPlant(), HEAD);
  assert.equal(few.pass, false);
  assert.match(few.measured, /^the census counted 128 primitive surfaces, pinned at least 129/);
  const none = census.buildReceipt({ ok: false, log: "runner exit 1, no prim_census_test.log" }, { ok: false, log: "" }, HEAD);
  assert.equal(none.pass, false);
  assert.equal(none.plant_caught, false);
  assert.match(none.measured, /^no SUMMARY line, so nothing was counted/);
  const fresh = census.buildReceipt(censusRun({ fresh: [{ ...BOX, shape: "Dam/Gate/MeshInstance3D" }] }), censusPlant(), HEAD);
  assert.equal(fresh.pass, false);
  assert.match(fresh.measured, /1 new primitive\(s\) no pin row covers: Dam\/Gate\/MeshInstance3D in activities\.gd/);
  const stale = census.buildReceipt(censusRun({ stale: [{ line: 15, file: "build_read.gd", mesh: "SphereMesh", shape: "x", row: "W1-46" }] }), censusPlant(), HEAD);
  assert.equal(stale.pass, false);
  assert.match(stale.measured, /stale stand-in row\(s\): pin line 15 build_read\.gd/);
});

test("no-code-stand-ins: a plant not caught voids the pass", () => {
  assert.equal(census.buildReceipt(censusRun(), censusRun({ plant: "dam_box" }), HEAD).plant_caught, false, "the planted run passed");
  assert.equal(census.buildReceipt(censusRun(), censusPlant([{ ...BOX, shape: "Dam/Other/MeshInstance3D" }]), HEAD).plant_caught, false, "failed for another box");
  assert.equal(census.buildReceipt(censusRun(), { ok: false, log: "" }, HEAD).plant_caught, false);
});

test("no-code-stand-ins: a plant switch that reached the counting run fails the receipt", () => {
  const r = census.buildReceipt(censusPlant(), censusPlant(), HEAD);
  assert.equal(r.pass, false);
  assert.match(r.measured, /^the counting run ran planted \(dam_box\)/);
});

test("no-code-stand-ins: the producer runs the test then the plant, takes the head from git, refuses a dirty checkout", () => {
  const { dir, head } = repo();
  const calls = [];
  const run = (cwd, name, env = {}) => { calls.push([name, env]); return env.PRIM_PLANT ? censusPlant() : censusRun(); };
  const r = census.produce({ cwd: dir, run });
  assert.equal(r.head, head);
  assert.equal(r.pass, true);
  assert.deepEqual(calls, [["prim_census_test", {}], ["prim_census_test", { PRIM_PLANT: "dam_box" }]]);
  writeFileSync(path.join(dir, "a.txt"), "two");
  assert.throws(() => census.produce({ cwd: dir, run }), /refusing: uncommitted changes/);
  assert.equal(calls.length, 2, "a dirty checkout never runs the test");
});
