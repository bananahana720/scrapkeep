import assert from "node:assert/strict";
import test from "node:test";
import { nodeTestsForPaths,
  defaultWidth,
  mergedBranch,
  carriedPrs,
  failingChecks,
  hygieneFindings,
  canaries,
  classify,
  cacheableBaseRun,
  settleBaseEntry,
  trustedBaseEntry,
  LEDGER_FLAKE_RUNS,
  classifyFailure,
  ledgerFlakes,
  settleLedgerFlake,
  indexFromFiles,
  lanePool,
  nodeTestsFor,
  parseArgs,
  batchable,
  splitBatch,
  takeBatch,
  placeholderIncrease,
  plan,
  referrers,
  selectTests,
  timingsFromReceipt,
  DEFAULT_ESTIMATE_MS,
  usableBaseRun,
  LOG_HEAD_LINES,
  LOG_TAIL_LINES,
  cappedLog,
  failedRunLog,
  failedRunLogName,
  receiptBaseName,
  signalReason,
} from "./sketch-fast.mjs";
import { IMPORT_TRIES, importTry, importWithRetry, quarantineRecord, scriptErrorCount } from "./sketch-smoke.mjs";

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

test("a ledger flake that is red twice gets more head runs: one green is flaky, red every time is still the PR's", () => {
  const rows = [
    { test: "audio_bake_cancel_test", kind: "flake" },
    { test: "warden_counter_pulse_test", kind: "red" },
  ];
  assert.deepEqual([...ledgerFlakes(rows)], ["audio_bake_cancel_test"]);
  const prRed = classifyFailure({ rerunOk: false, baseOk: true });
  const red = { ok: false, killed: false };
  const green = { ok: true, killed: false };
  assert.deepEqual(settleLedgerFlake(prRed, [red, green]), { kind: "flaky", newChecks: [], ledger: true });
  assert.deepEqual(settleLedgerFlake(prRed, Array(LEDGER_FLAKE_RUNS).fill(red)), { kind: "pr-red", newChecks: [], ledgerRuns: LEDGER_FLAKE_RUNS });
  // A run the lane stopped is not a verdict, whatever came before it.
  assert.equal(settleLedgerFlake(prRed, [red, { ok: false, killed: true }]).kind, "stopped");
  // New failing checks stay named when every extra run is red.
  const grew = classifyFailure({ rerunOk: false, baseOk: false, headChecks: ["a", "b"], baseChecks: ["a"] });
  assert.deepEqual(settleLedgerFlake(grew, [red, red, red]).newChecks, ["b"]);
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

test("timings fold reads fast-lane rows and gate shard rows as well as smoke labels", () => {
  const receipt = {
    results: [
      { test: "tests/c_test.gd", ok: true, ms: 700 },
      { test: "d_test", ok: true, seconds: 63.7 },
      { test: "e_test", ok: false, seconds: 360 },
      { test: "tests/stopped_test.gd", ok: true, ms: 0 },
    ],
  };
  assert.deepEqual(timingsFromReceipt(receipt), { "tests/c_test.gd": 700, "tests/d_test.gd": 63700 });
});

test("a bot-named test with no timings row goes to the bot shards; a test with a row stays in the lane", () => {
  const picked = new Map([
    ["tests/bot_planted_unknown_test.gd", { tier: 1, why: "names" }],
    ["tests/planted_sweep_unknown_test.gd", { tier: 1, why: "names" }],
    ["tests/bot_known_test.gd", { tier: 1, why: "names" }],
    ["tests/known_fast_test.gd", { tier: 1, why: "names" }],
  ]);
  const out = plan({ picked, timings: { "tests/known_fast_test.gd": 2_000, "tests/bot_known_test.gd": 5_000 }, budgetMs: 600_000, width: 2 });
  assert.deepEqual(out.bots, ["tests/bot_planted_unknown_test.gd", "tests/planted_sweep_unknown_test.gd"]);
  assert.deepEqual(out.parallel.map((row) => row.test), ["tests/known_fast_test.gd", "tests/bot_known_test.gd"]);
});

test("a test with no timings row is priced at 180 s", () => {
  assert.equal(DEFAULT_ESTIMATE_MS, 180_000);
  const picked = new Map([["tests/air_planted_unknown_test.gd", { tier: 1, why: "names" }]]);
  const out = plan({ picked, timings: {}, budgetMs: 600_000, width: 2 });
  assert.equal(out.parallel[0].ms, 180_000);
  assert.equal(out.estimateMs, 90_000);
});

test("parseArgs defaults to origin/main and a 15 minute budget", () => {
  assert.deepEqual(parseArgs([]), { base: "origin/main", budgetS: 900, dryRun: false, receipt: "fast", width: null, baseCheck: true, batch: true, pre: [] });
  assert.deepEqual(parseArgs(["--pre", "#91", "--pre", "67"]).pre, ["91", "67"]);
  assert.throws(() => parseArgs(["--pre", "abc"]));
  assert.equal(parseArgs(["--base", "stage/alpha-w17", "--budget", "600"]).budgetS, 600);
  assert.throws(() => parseArgs(["--budget", "0"]));
});

test("import: an engine crash or a script error is tried again, up to three tries, and only the last try decides", () => {
  assert.equal(IMPORT_TRIES, 3);
  const runner = (rows) => {
    const calls = [];
    const left = [...rows];
    return { calls, run: (job) => (calls.push(job.label), { label: job.label, ok: false, ...left.shift() }) };
  };
  const said = [];
  // Node reports a crash as a signal; a shell reports 128 + the signal.
  const crashed = runner([{ exit: null, signal: "SIGSEGV" }, { exit: 134 }, { exit: 0 }]);
  const third = importWithRetry("core-loop", ["--headless"], crashed.run, (line) => said.push(line));
  assert.equal(third.ok, true);
  assert.deepEqual(crashed.calls, ["core-loop import", "core-loop import (try 2)", "core-loop import (try 3)"]);
  assert.deepEqual(third.tries.map((row) => row.outcome), ["engine crash", "engine crash", "ok"]);
  assert.equal(third.results.length, 1, "a crash that a retry cleared is not a failed row of the run");
  assert.equal(third.results[0].exit, 0);
  assert.deepEqual(said, ["core-loop import try 1 of 3: engine crash (exit=SIGSEGV); trying again", "core-loop import try 2 of 3: engine crash (exit=134); trying again"]);
  // Three crashes stop the run, and every try is a row.
  const dead = importWithRetry("core-loop", ["--headless"], () => ({ exit: 139, ok: false }), () => {});
  assert.equal(dead.ok, false);
  assert.equal(dead.results.length, 3);
  // A clean exit that still prints SCRIPT ERROR is not a pass: tried again, and it fails when the last try still prints one.
  const healed = runner([{ exit: 0, scriptErrors: 12 }, { exit: 0, scriptErrors: 0 }]);
  assert.equal(importWithRetry("core-loop", ["--headless"], healed.run, () => {}).ok, true);
  assert.equal(healed.calls.length, 2);
  const broken = importWithRetry("core-loop", ["--headless"], () => ({ exit: 0, scriptErrors: 1, ok: false }), () => {});
  assert.equal(broken.ok, false);
  assert.deepEqual(broken.tries.map((row) => row.outcome), ["script errors", "script errors", "script errors"]);
  // Any other failure (a time limit, an exit code) is tried again too, and a first clean try is the only one.
  assert.equal(importTry({ exit: null, signal: "SIGTERM" }), "failed");
  assert.equal(importTry({ exit: 1 }), "failed");
  const clean = importWithRetry("core-loop", ["--headless"], () => ({ exit: 0, ok: false }), () => {});
  assert.equal(clean.results.length, 1, "other error lines on a clean exit do not ask for another import");
  assert.equal(scriptErrorCount("ok\nSCRIPT ERROR: Parse Error\n   at: x\nnote: SCRIPT ERROR mid-line\nSCRIPT ERROR: again\n"), 2);
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

test("a changed test also picks the tests that extend it", () => {
  const index = files({
    "tests/kest_kit_test.gd": "extends SceneTree\n",
    "tests/kest_set_piece_test.gd": 'extends "res://tests/kest_kit_test.gd"\n',
    "tests/other_test.gd": "extends SceneTree\n",
  });
  const { picked } = selectTests(index, ["tests/kest_kit_test.gd"]);
  assert.equal(picked.get("tests/kest_kit_test.gd").why, "changed");
  assert.equal(picked.get("tests/kest_set_piece_test.gd").why, "reaches the changed test tests/kest_kit_test.gd");
  assert.equal(picked.has("tests/other_test.gd"), false);
});

test("a changed test picks a test two steps away, and a loop of references ends", () => {
  const index = files({
    "tests/dress_material_test.gd": 'extends SceneTree\nconst LOOP := preload("res://tests/dress_wog_fallback_test.gd")\n',
    "tests/dress_wog_test.gd": 'extends "res://tests/dress_material_test.gd"\n',
    "tests/dress_wog_fallback_test.gd": 'extends "res://tests/dress_wog_test.gd"\n',
    "tests/other_test.gd": "extends SceneTree\n",
  });
  const { picked } = selectTests(index, ["tests/dress_material_test.gd"]);
  assert.deepEqual([...picked.keys()].filter((test) => test.includes("dress")).sort(), ["tests/dress_material_test.gd", "tests/dress_wog_fallback_test.gd", "tests/dress_wog_test.gd"]);
  assert.equal(picked.get("tests/dress_material_test.gd").why, "changed");
  assert.equal(picked.has("tests/other_test.gd"), false);
});

test("a red run's log keeps a short output whole and names how the run ended", () => {
  const output = "Godot Engine v4.7.2\nFAIL: the rescue cue plays\nhandle_crash: Program crashed with signal 6\n";
  const text = failedRunLog({ test: "tests/audio_rescue_test.gd", where: "head", attempt: 1, head: "abc123", exit: null, signal: "SIGABRT", timedOut: false, ms: 4210, reason: "exit null", output });
  assert.match(text, /^test: tests\/audio_rescue_test\.gd\nran on: the head \(abc123\), run 1 there\nexit: none, signal SIGABRT\nseconds: 4\.2\nreason: exit null\n--- stdout and stderr ---\n/);
  assert.ok(text.endsWith("--- stdout and stderr ---\n" + output));
  const base = failedRunLog({ test: "tests/a_test.gd", where: "base", attempt: 2, head: "def456", exit: 1, signal: null, timedOut: true, ms: 0, reason: "timed out", output: "" });
  assert.match(base, /ran on: the merge base \(def456\), run 2 there\nexit: 1, stopped at its time limit\n/);
});

test("a long log keeps its first and last lines and says how many it cut", () => {
  const lines = Array.from({ length: LOG_HEAD_LINES + LOG_TAIL_LINES + 50 }, (_, index) => `line ${index + 1}`);
  const kept = cappedLog(lines.join("\n") + "\n").split("\n");
  assert.equal(kept.length, LOG_HEAD_LINES + LOG_TAIL_LINES + 1);
  assert.equal(kept[0], "line 1");
  assert.equal(kept[LOG_HEAD_LINES - 1], `line ${LOG_HEAD_LINES}`);
  assert.equal(kept[LOG_HEAD_LINES], `[sketch:fast cut 50 lines here; ${lines.length} lines printed]`);
  assert.equal(kept[LOG_HEAD_LINES + 1], `line ${LOG_HEAD_LINES + 51}`);
  assert.equal(kept.at(-1), `line ${lines.length}`);
  assert.ok(LOG_TAIL_LINES >= 200, "the last 200 lines of a red run are always kept");
  const exact = Array.from({ length: LOG_HEAD_LINES + LOG_TAIL_LINES }, (_, index) => `line ${index + 1}`).join("\n");
  assert.equal(cappedLog(exact), exact);
  assert.equal(cappedLog(""), "");
  assert.equal(cappedLog("a\nb\nc\nd", 1, 0), "a\n[sketch:fast cut 3 lines here; 4 lines printed]");
});

test("each red run of a test gets its own log file beside the receipt", () => {
  assert.equal(failedRunLogName("tests/audio_rescue_test.gd", "head", 1), "audio_rescue_test.head-1.log");
  assert.equal(failedRunLogName("tests/audio_rescue_test.gd", "head", 2), "audio_rescue_test.head-2.log");
  assert.equal(failedRunLogName("tests/audio_rescue_test.gd", "base", 1), "audio_rescue_test.base-1.log");
  assert.equal(failedRunLogName("tests/trees/child_test.gd", "head", 1), "trees__child_test.head-1.log");
  assert.equal(receiptBaseName("fast", "0123456789abcdef0123", "2026-11-10T03:20:11.123Z"), "fast-0123456789ab-2026-11-10T03-20-11-123Z");
});

test("a crash signal is named as a crash, and only a plain kill points at the memory limit", () => {
  assert.match(signalReason("SIGABRT"), /^ended on SIGABRT before its time limit \(a crash/);
  assert.match(signalReason("SIGSEGV"), /^ended on SIGSEGV /);
  assert.match(signalReason("SIGKILL"), /memory limit/);
  assert.match(signalReason(null), /memory limit/);
});

test("the default width is one lane per idle core, between 2 and 8", () => {
  assert.equal(defaultWidth(4, 0.1), 4);
  assert.equal(defaultWidth(4, 1.6), 2);
  assert.equal(defaultWidth(4, 0), 4);
  assert.equal(defaultWidth(32, 30), 2);
  assert.equal(defaultWidth(32, 4), 8);
  assert.equal(defaultWidth(2, 0), 2);
});

test("a plain SceneTree test batches; a timed, solo or extended one does not", () => {
  assert.equal(batchable("extends SceneTree\n\nfunc _initialize():\n\tquit(0)\n"), true);
  assert.equal(batchable('extends "res://tests/rivet_kit_test.gd"\n'), false);
  assert.equal(batchable("extends SceneTree\nvar t := Time.get_ticks_msec()\n"), false);
  assert.equal(batchable("extends SceneTree\n# the warm cache\n"), false);
  assert.equal(batchable("extends SceneTree\nfunc f():\n\tOS.execute('x', [])\n"), false);
});

test("takeBatch takes consecutive batchable rows within the test and time caps", () => {
  const rows = (list) => list.map(([test, ms, ok = true]) => ({ test, ms, ok }));
  const can = (row) => row.ok;
  const q1 = rows([["a", 10_000], ["b", 10_000], ["c", 10_000, false], ["d", 1]]);
  assert.deepEqual(takeBatch(q1, can).map((row) => row.test), ["a", "b"]);
  assert.deepEqual(q1.map((row) => row.test), ["c", "d"]);
  assert.deepEqual(takeBatch(q1, can), []);
  const q2 = rows([["a", 100_000], ["b", 30_000], ["c", 1]]);
  assert.deepEqual(takeBatch(q2, can).map((row) => row.test), ["a"]);
  const q3 = rows(Array.from({ length: 10 }, (_, i) => [`t${i}`, 1]));
  assert.equal(takeBatch(q3, can).length, 8);
});

test("splitBatch gives each test its own output and names a cut-off test", () => {
  const out = ["Godot", "BATCH START tests/a.gd", "x -> PASS", "a: PASS", "BATCH END tests/a.gd exit=0 ms=5", "BATCH START tests/b.gd", "y -> FAIL", "crash"].join("\n");
  const split = splitBatch(out, ["tests/a.gd", "tests/b.gd", "tests/c.gd"]);
  assert.deepEqual(split.done, [{ test: "tests/a.gd", exit: 0, ms: 5, output: "x -> PASS\na: PASS" }]);
  assert.equal(split.cut, "tests/b.gd");
  assert.deepEqual(split.rest, ["tests/c.gd"]);
});

test("nodeTestsForPaths: a park prop recipe or file faces the far-mesh fault check, other sketch paths do not", () => {
  assert.deepEqual(nodeTestsForPaths(["assets/models/park/props/dam/cable_drum_a_lod2.glb"]), ["scripts/far-faults.test.mjs"]);
  assert.deepEqual(nodeTestsForPaths(["tools/blender/park/props/kit.py", "src/game.gd"]), ["scripts/far-faults.test.mjs"]);
  assert.deepEqual(nodeTestsForPaths(["tools/model_audit.py"]), ["scripts/far-faults.test.mjs"]);
  assert.deepEqual(nodeTestsForPaths(["src/core/palette.gd"]), ["scripts/palette-gd.test.mjs"]);
  assert.deepEqual(nodeTestsForPaths(["tools/icons/generate_icons.py", "tools/blender/common.py"]), ["scripts/palette-gd.test.mjs"]);
  assert.deepEqual(nodeTestsForPaths(["src/world/park/park_dam.json", "assets/models/world_one/ambush_altar.glb"]), []);
});
