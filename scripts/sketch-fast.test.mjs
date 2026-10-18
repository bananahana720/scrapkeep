import assert from "node:assert/strict";
import test from "node:test";
import {
  canaries,
  classify,
  classifyFailure,
  indexFromFiles,
  nodeTestsFor,
  parseArgs,
  placeholderIncrease,
  plan,
  referrers,
  selectTests,
  timingsFromReceipt,
} from "./sketch-fast.mjs";
import { importWithRetry } from "./sketch-smoke.mjs";

const files = (entries) => indexFromFiles(new Map(Object.entries(entries)));

test("classify splits sketch, node and docs paths and folds .uid onto its script", () => {
  const out = classify([
    "sketches/core-loop/src/a.gd",
    "sketches/core-loop/src/a.gd.uid",
    "scripts/x.mjs",
    "tests/y.test.js",
    "docs/z.md",
    "package-lock.json",
  ]);
  assert.deepEqual(out.godot, ["src/a.gd"]);
  assert.deepEqual(out.node, ["scripts/x.mjs", "tests/y.test.js"]);
  assert.deepEqual(out.docs, ["docs/z.md"]);
  assert.deepEqual(out.other, ["package-lock.json"]);
});

test("referrers match a whole res:// path, not a longer one", () => {
  const index = files({
    "src/a.gd": "",
    "src/b.gd": 'const A := preload("res://src/a.gd")',
    "src/c.gd": 'const S := preload("res://src/a.gdshader")',
    "tests/a_test.gd": 'load("res://src/a.gd.bak")',
  });
  assert.deepEqual(referrers(index, "src/a.gd"), ["src/b.gd"]);
});

test("selection takes changed tests, direct and stem-named tests, and one step through non-hub files", () => {
  const index = files({
    "src/core/leaf.gd": "",
    "src/core/mid.gd": 'preload("res://src/core/leaf.gd")',
    "tests/changed_test.gd": "",
    "tests/direct_test.gd": 'preload("res://src/core/leaf.gd")',
    "tests/leaf_shape_test.gd": "",
    "tests/through_test.gd": 'preload("res://src/core/mid.gd")',
    "tests/unrelated_test.gd": "",
    "tests/support/t.gd": "",
  });
  const { picked, hubs, unmapped } = selectTests(index, ["tests/changed_test.gd", "src/core/leaf.gd", "assets/x.bin"]);
  assert.equal(picked.get("tests/changed_test.gd").tier, 0);
  assert.equal(picked.get("tests/direct_test.gd").tier, 1);
  assert.equal(picked.get("tests/leaf_shape_test.gd").tier, 1);
  assert.equal(picked.get("tests/through_test.gd").tier, 2);
  assert.equal(picked.has("tests/unrelated_test.gd"), false);
  assert.deepEqual(hubs, []);
  assert.deepEqual(unmapped, ["assets/x.bin"]);
});

test("a hub's own tests are selected but nothing is reached through a hub", () => {
  const entries = { "src/leaf.gd": "", "src/hub.gd": 'preload("res://src/leaf.gd")' };
  for (let i = 0; i < 4; i++) entries[`tests/h${i}_test.gd`] = 'preload("res://src/hub.gd")';
  const index = files(entries);
  const throughHub = selectTests(index, ["src/leaf.gd"], { hub: 3 });
  assert.equal(throughHub.picked.size, 0);
  const hubChanged = selectTests(index, ["src/hub.gd"], { hub: 3 });
  assert.equal(hubChanged.picked.size, 4);
  assert.deepEqual(hubChanged.hubs, ["src/hub.gd"]);
});

test("canaries are the cheapest timed tests that load the whole game", () => {
  const index = files({
    "src/game.gd": "",
    "tests/a_test.gd": 'preload("res://src/game.gd")',
    "tests/b_test.gd": 'preload("res://src/game.gd")',
    "tests/c_test.gd": 'preload("res://src/game.gd")',
    "tests/d_test.gd": "",
  });
  const timings = { "tests/a_test.gd": 9000, "tests/b_test.gd": 1000, "tests/c_test.gd": 3000, "tests/d_test.gd": 10 };
  assert.deepEqual(canaries(index, timings, 2), ["tests/b_test.gd", "tests/c_test.gd"]);
});

test("plan keeps tiers within the budget, keeps changed tests, runs cheapest first and lists bots", () => {
  const picked = new Map([
    ["tests/changed_test.gd", { tier: 0, why: "changed" }],
    ["tests/slow_direct_test.gd", { tier: 1, why: "names" }],
    ["tests/fast_direct_test.gd", { tier: 1, why: "names" }],
    ["tests/second_test.gd", { tier: 2, why: "through" }],
    ["tests/solo_test.gd", { tier: 1, why: "names" }],
    ["tests/bot_x_test.gd", { tier: 1, why: "names" }],
  ]);
  const timings = {
    "tests/changed_test.gd": 500_000,
    "tests/slow_direct_test.gd": 40_000,
    "tests/fast_direct_test.gd": 2_000,
    "tests/second_test.gd": 10_000,
    "tests/solo_test.gd": 20_000,
  };
  const out = plan({
    picked,
    timings,
    budgetMs: 293_000,
    width: 2,
    solo: (test) => test.includes("solo"),
    bots: (test) => test.includes("bot_"),
  });
  assert.deepEqual(out.parallel.map((row) => row.test), ["tests/changed_test.gd", "tests/fast_direct_test.gd", "tests/slow_direct_test.gd"]);
  assert.deepEqual(out.solo.map((row) => row.test), ["tests/solo_test.gd"]);
  assert.deepEqual(out.deferred.map((row) => row.test), ["tests/second_test.gd"]);
  assert.deepEqual(out.bots, ["tests/bot_x_test.gd"]);
});

test("a failure is flaky when the rerun passes, base-red when the base fails too, else the PR's", () => {
  assert.equal(classifyFailure({ rerunOk: true, baseOk: null }), "flaky");
  assert.equal(classifyFailure({ rerunOk: false, baseOk: false }), "base-red");
  assert.equal(classifyFailure({ rerunOk: false, baseOk: true }), "pr-red");
  assert.equal(classifyFailure({ rerunOk: false, baseOk: null }), "pr-red");
});

test("node tests: changed tests plus tests importing a changed module by file name", () => {
  const texts = {
    "scripts/a.test.mjs": 'import { x } from "./a.mjs";',
    "tests/b.test.js": "import { y } from '../scripts/b.mjs';",
    "tests/c.test.js": 'import { z } from "../scripts/ab.mjs";',
  };
  const all = Object.keys(texts);
  assert.deepEqual(nodeTestsFor(["scripts/a.mjs"], all, (file) => texts[file]), ["scripts/a.test.mjs"]);
  assert.deepEqual(nodeTestsFor(["tests/c.test.js", "scripts/b.mjs"], all, (file) => texts[file]), ["tests/b.test.js", "tests/c.test.js"]);
});

test("placeholder increase is per kind and place, so a fix elsewhere cannot hide a new one", () => {
  const base = [{ kind: "park", where: "park_dam", count: 3 }, { kind: "icon", where: "x", count: 2 }];
  assert.deepEqual(placeholderIncrease(base, [{ kind: "park", where: "park_dam", count: 3 }]), []);
  assert.deepEqual(placeholderIncrease(base, [{ kind: "park", where: "park_dam", count: 1 }, { kind: "attack", where: "E40", count: 1 }]), ["attack E40: 0 -> 1"]);
});

test("timings fold only passing test rows from a smoke receipt", () => {
  const receipt = {
    results: [
      { label: "sketches/core-loop import", ok: true, ms: 20000 },
      { label: "sketches/core-loop res://tests/a_test.gd", ok: true, ms: 1234.4 },
      { label: "sketches/core-loop res://tests/b_test.gd", ok: false, ms: 180000 },
    ],
  };
  assert.deepEqual(timingsFromReceipt(receipt), { "tests/a_test.gd": 1234 });
});

test("parseArgs defaults to origin/main and a 15 minute budget", () => {
  assert.deepEqual(parseArgs([]), { base: "origin/main", budgetS: 900, dryRun: false, receipt: "fast", width: null, baseCheck: true });
  assert.equal(parseArgs(["--base", "stage/alpha-w17", "--budget", "600"]).budgetS, 600);
  assert.throws(() => parseArgs(["--budget", "0"]));
});

test("import retries once after a crashed import and stops after two", () => {
  const exits = [null, 0];
  const calls = [];
  const run = (job) => {
    calls.push(job.label);
    const exit = exits.shift();
    return { label: job.label, exit, ok: exit === 0 };
  };
  const once = importWithRetry("core-loop", ["--headless"], run, () => {});
  assert.equal(once.ok, true);
  assert.deepEqual(calls, ["core-loop import", "core-loop import (retry)"]);
  const twice = importWithRetry("core-loop", ["--headless"], () => ({ exit: null, ok: false }), () => {});
  assert.equal(twice.ok, false);
  assert.equal(twice.results.length, 2);
  const clean = importWithRetry("core-loop", ["--headless"], () => ({ exit: 0, ok: false }), () => {});
  assert.equal(clean.results.length, 1, "an import that exits 0 with error lines is not retried");
});
