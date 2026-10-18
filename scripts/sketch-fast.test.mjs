import assert from "node:assert/strict";
import test from "node:test";
import {
  mergedBranch,
  carriedPrs,
  failingChecks,
  hygieneFindings,
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

test("unit_suite always runs, park data pulls every park test, and movement changes name shard proofs", () => {
  const index = files({
    "src/movement/ball.gd": "",
    "assets/park/park_dam/bake.json": "",
    "tests/unit_suite_test.gd": "",
    "tests/park_park_dam_test.gd": "",
    "tests/park_park_pit_test.gd": "",
    "tests/park_bake_fresh_test.gd": "",
    "tests/posture_bands_reactor_test.gd": "",
    "tests/alpha_posture_bands_test.gd": "",
  });
  const { picked, shards, unmapped } = selectTests(index, ["assets/park/park_dam/bake.json", "src/movement/ball.gd"]);
  assert.equal(picked.get("tests/unit_suite_test.gd").tier, 0);
  assert.ok(picked.has("tests/park_park_pit_test.gd"));
  assert.ok(picked.has("tests/park_bake_fresh_test.gd"));
  assert.deepEqual([...shards.keys()].sort(), ["tests/alpha_posture_bands_test.gd", "tests/posture_bands_reactor_test.gd"]);
  assert.equal(picked.has("tests/posture_bands_reactor_test.gd"), false);
  assert.deepEqual(unmapped, ["src/movement/ball.gd"]);
  assert.equal(selectTests(index, []).picked.size, 0);
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

test("a failure is flaky when the rerun passes, base-red when the base fails the same checks, else the PR's", () => {
  assert.equal(classifyFailure({ rerunOk: true, baseOk: null }).kind, "flaky");
  assert.equal(classifyFailure({ rerunOk: false, baseOk: false }).kind, "base-red");
  assert.equal(classifyFailure({ rerunOk: false, baseOk: true }).kind, "pr-red");
  assert.equal(classifyFailure({ rerunOk: false, baseOk: null }).kind, "pr-red");
  const grew = classifyFailure({ rerunOk: false, baseOk: false, headChecks: ["a", "b"], baseChecks: ["a"] });
  assert.deepEqual(grew, { kind: "pr-red", newChecks: ["b"] });
  assert.equal(classifyFailure({ rerunOk: false, baseOk: false, headChecks: ["a"], baseChecks: ["a", "c"] }).kind, "base-red");
});

test("failing checks are named by their bracket label, so measured values do not differ", () => {
  const output = "[Spillway skipper breaks it in 50 to 90 s] median 48.5 s -> FAIL\n[ok] x -> PASS\nplain line 3 -> FAIL (got 2)\n";
  assert.deepEqual(failingChecks(output), ["Spillway skipper breaks it in 50 to 90 s", "plain line 3"]);
});

test("hygiene fails added symlinks, root files and new top-level folders only", () => {
  const z = "0".repeat(40);
  const raw = [
    `:000000 120000 ${z} ${z} A\tnode_modules`,
    `:000000 100644 ${z} ${z} A\tNOTES.md`,
    `:000000 100644 ${z} ${z} A\tstray/x.txt`,
    `:000000 100644 ${z} ${z} A\tscripts/ok.mjs`,
    `:100644 100644 ${z} ${z} M\tREADME.md`,
  ];
  assert.deepEqual(hygieneFindings(raw, new Set(["scripts", "sketches"])), [
    "symlink added: node_modules",
    "root file added: NOTES.md",
    "new top-level folder: stray/x.txt",
  ]);
});

test("merged branch names come from GitHub and git merge subjects", () => {
  assert.equal(mergedBranch("Merge pull request #76 from bananahana720/claude/project-thread-xzaxq4"), "claude/project-thread-xzaxq4");
  assert.equal(mergedBranch("Merge remote-tracking branch 'origin/claude/sinkhole-bake-rkry23' into claude/z"), "claude/sinkhole-bake-rkry23");
  assert.equal(mergedBranch("Merge branch 'stage/alpha-w16'"), "stage/alpha-w16");
  assert.equal(mergedBranch("Merge BOT-LINE adb779a8: every pilot"), null);
});

test("carried PRs: an exact head is current, a named PR that moved on is stale unless already contained", () => {
  const heads = new Map([["79", "c".repeat(40)], ["61", "a".repeat(40)]]);
  const merges = [
    { merge: "m1", carried: "a".repeat(40), subject: "Merge branch x" },
    { merge: "m2", carried: "b".repeat(40), subject: "Merge pull request #79 from someone/bake" },
    { merge: "m3", carried: "d".repeat(40), subject: "Merge local work" },
  ];
  const rows = carriedPrs(merges, { prHeads: heads }, () => false);
  assert.deepEqual(rows.map((row) => [row.prs, row.stale]), [[["61"], false], [["79"], true], [[], false]]);
  assert.equal(carriedPrs(merges, { prHeads: heads }, () => true)[1].stale, false);
  const byBranch = carriedPrs(
    [{ merge: "m4", carried: "e".repeat(40), subject: "Merge remote-tracking branch 'origin/claude/bake-x' into claude/y" }],
    { prHeads: new Map([["80", "f".repeat(40)]]), branchHeads: new Map([["claude/bake-x", "f".repeat(40)]]) },
    () => false,
  );
  assert.deepEqual([byBranch[0].prs, byBranch[0].branch, byBranch[0].stale], [["80"], "claude/bake-x", true]);
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
  assert.deepEqual(parseArgs([]), { base: "origin/main", budgetS: 900, dryRun: false, receipt: "fast", width: null, baseCheck: true, pre: [] });
  assert.deepEqual(parseArgs(["--pre", "#91", "--pre", "67"]).pre, ["91", "67"]);
  assert.throws(() => parseArgs(["--pre", "abc"]));
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
