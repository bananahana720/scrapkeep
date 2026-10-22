import assert from "node:assert/strict";
import test from "node:test";
import {
  mergedBranch,
  carriedPrs,
  failingChecks,
  hygieneFindings,
  canaries,
  classify,
  cacheableBaseRun,
  settleBaseEntry,
  trustedBaseEntry,
  classifyFailure,
  indexFromFiles,
  lanePool,
  nodeTestsFor,
  parseArgs,
  placeholderIncrease,
  plan,
  referrers,
  selectTests,
  timingsFromReceipt,
  usableBaseRun,
} from "./sketch-fast.mjs";
import { importWithRetry, quarantineRecord } from "./sketch-smoke.mjs";

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
    "tests/park_props_test.gd": "",
    "tests/posture_bands_reactor_test.gd": "",
    "tests/alpha_posture_bands_test.gd": "",
  });
  const { picked, shards, unmapped } = selectTests(index, ["assets/park/park_dam/bake.json", "src/movement/ball.gd"]);
  assert.equal(picked.get("tests/unit_suite_test.gd").tier, 0);
  assert.ok(picked.has("tests/park_park_pit_test.gd"));
  assert.ok(picked.has("tests/park_bake_fresh_test.gd"));
  assert.ok(picked.has("tests/park_props_test.gd"));
  for (const rel of ["src/presentation/park_props.gd", "assets/models/park/props/bench.glb", "src/world/park/props/park_dam.json"]) {
    assert.ok(selectTests(index, [rel]).picked.has("tests/park_props_test.gd"), rel);
  }
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

test("the lane pool never runs more tasks than its width, and queued tasks still run", async () => {
  const inLane = lanePool(2);
  let live = 0;
  let peak = 0;
  const task = (ms) => inLane(async () => {
    live++;
    peak = Math.max(peak, live);
    await new Promise((resolve) => setTimeout(resolve, ms));
    live--;
    return ms;
  });
  // A confirm's rerun and base run queue behind the other worker's test, as in the lane.
  const results = await Promise.all([task(20), task(5), task(5), task(1), task(1)]);
  assert.deepEqual(results, [20, 5, 5, 1, 1]);
  assert.equal(peak, 2);
});

test("a throwing task frees its lane", async () => {
  const inLane = lanePool(1);
  await assert.rejects(inLane(async () => { throw new Error("boom"); }));
  assert.equal(await inLane(async () => "next"), "next");
});

test("only a clean base verdict is cached, never a timeout or a kill", () => {
  assert.equal(cacheableBaseRun({ exit: 0, killed: false, timedOut: false }), true);
  assert.equal(cacheableBaseRun({ exit: 1, killed: false, timedOut: false }), true);
  assert.equal(cacheableBaseRun({ exit: null, killed: false, timedOut: true }), false);
  assert.equal(cacheableBaseRun({ exit: null, killed: true, timedOut: false }), false);
  assert.equal(cacheableBaseRun({ exit: null, killed: false, timedOut: false }), false);
});

test("a base timeout counts only against a head that also timed out; a lane stop never counts", () => {
  const red = { ok: false, exit: 1, killed: false, timedOut: false };
  const slow = { ok: false, exit: null, killed: false, timedOut: true };
  const stopped = { ok: false, exit: null, killed: true, timedOut: false };
  assert.equal(usableBaseRun(red, red), red);
  assert.equal(usableBaseRun(red, slow), null);
  assert.equal(usableBaseRun(slow, slow), slow);
  assert.equal(usableBaseRun(red, stopped), null);
  assert.equal(usableBaseRun(red, null), null);
  const outsideKill = { ok: false, exit: null, killed: false, timedOut: false };
  assert.equal(usableBaseRun(red, outsideKill), null);
  assert.equal(usableBaseRun(slow, outsideKill), outsideKill);
});

test("a base that dies by the same non-SIGKILL signal as the head keeps its verdict", () => {
  const crash = (signal, checks = [], passes = 172) => ({ ok: false, exit: null, signal, killed: false, timedOut: false, checks, passes });
  const head = crash("SIGABRT");
  const base = crash("SIGABRT");
  assert.equal(usableBaseRun(head, base), base);
  assert.equal(classifyFailure({ rerunOk: false, baseOk: false, headChecks: head.checks, baseChecks: base.checks }).kind, "base-red");
  assert.equal(cacheableBaseRun(base), false);
  // A head-only crash: the base passed, so the head is the PR's red.
  const pass = { ok: true, exit: 0, signal: null, killed: false, timedOut: false, checks: [] };
  const kept = usableBaseRun(head, pass);
  assert.equal(kept, pass);
  assert.equal(classifyFailure({ rerunOk: false, baseOk: kept.ok, headChecks: head.checks, baseChecks: [] }).kind, "pr-red");
  // SIGKILL is the OOM killer or the lane's own timeout: no verdict.
  assert.equal(usableBaseRun(crash("SIGKILL"), crash("SIGKILL")), null);
  assert.equal(usableBaseRun(head, crash("SIGKILL")), null);
  // A different signal says nothing about the base.
  assert.equal(usableBaseRun(head, crash("SIGSEGV")), null);
  // Same signal, different failing checks: the head's new checks are the PR's.
  const headChecks = crash("SIGABRT", ["a", "b"]);
  const baseChecks = crash("SIGABRT", ["a"]);
  assert.equal(usableBaseRun(headChecks, baseChecks), null);
  // Same signal and checks, but the head aborted earlier (fewer passing checks): no base verdict, so pr-red.
  const early = crash("SIGABRT", [], 60);
  const dropped = usableBaseRun(early, base);
  assert.equal(dropped, null);
  assert.equal(classifyFailure({ rerunOk: false, baseOk: dropped ? dropped.ok : null }).kind, "pr-red");
});

test("a single base red is not trusted from the cache; a second agreeing run confirms it", () => {
  const first = settleBaseEntry(undefined, { ok: false, checks: ["a", "b"] });
  assert.equal(trustedBaseEntry(first), false);
  assert.equal(trustedBaseEntry(settleBaseEntry(first, { ok: false, checks: ["a", "b"] })), true);
  assert.equal(trustedBaseEntry(settleBaseEntry(first, { ok: false, checks: ["a"] })), false);
  assert.equal(trustedBaseEntry(settleBaseEntry(settleBaseEntry(undefined, { ok: false, checks: [] }), { ok: false, checks: [] })), false);
  assert.equal(trustedBaseEntry({ ok: true, checks: [] }), true);
});

test("a cached base red expires when a fresh base run passes", () => {
  const flaky = settleBaseEntry(undefined, { ok: false, checks: ["a"] });
  const after = settleBaseEntry(flaky, { ok: true, checks: [] });
  assert.deepEqual(after, { ok: true, checks: [] });
  const confirmed = settleBaseEntry(flaky, { ok: false, checks: ["a"] });
  assert.equal(trustedBaseEntry(settleBaseEntry(confirmed, { ok: true, checks: [] })) && settleBaseEntry(confirmed, { ok: true, checks: [] }).ok, true);
});

test("planted head red: a cached base red never hides a head-only red", () => {
  const cached = settleBaseEntry(undefined, { ok: false, checks: ["a"] });
  assert.equal(trustedBaseEntry(cached), false, "single-run red is rerun, not reused");
  const confirmed = settleBaseEntry(cached, { ok: false, checks: ["a"] });
  const grew = classifyFailure({ rerunOk: false, baseOk: false, headChecks: ["a", "x"], baseChecks: confirmed.checks, baseCached: true });
  assert.equal(grew.kind, "pr-red");
  assert.deepEqual(grew.newChecks, ["x"]);
  assert.equal(classifyFailure({ rerunOk: false, baseOk: false, headChecks: [], baseChecks: confirmed.checks, baseCached: true }).kind, "pr-red");
  assert.equal(classifyFailure({ rerunOk: false, baseOk: false, headChecks: [], baseChecks: [], baseCached: false }).kind, "base-red");
});

test("a fast-lane quarantine receipt entry carries owner, reason, deadline and the run's result", () => {
  const entry = { test: "a_test", owner: "Systems", reason: "why", added: "2026-10-22", deadline: "2026-10-29" };
  assert.deepEqual(quarantineRecord(entry, { ok: false, exit: null, signal: "SIGABRT", failing: 0 }), {
    test: "a_test", owner: "Systems", reason: "why", deadline: "2026-10-29", result: "red", exit: null, signal: "SIGABRT", failing_checks: 0,
  });
});
