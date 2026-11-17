import assert from "node:assert/strict";
import { test } from "node:test";
import os from "node:os";
import path from "node:path";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";

import { checkTally, expectedShards, tallyRows, planHead } from "./tally.mjs";
import { SCOPED_ALWAYS, defaultBudget, challengeArgs, receiptBotShards, checkBands, compareBands, compareLines, compareRuns, gatePlan, loadBands, nodeSummary, planFileText, runPlan, sortedLines, spareWhileWaiting, stepEnv, worktreePool } from "./pc.mjs";

const names = (count, prefix) => Array.from({ length: count }, (_, index) => `${prefix}${String(index).padStart(4, "0")}_test`);
const lists = {
  tests: [...names(1047, "t"), "a_one_test", "c_one_test"].sort(),
  bots: [...names(21, "b"), "bot_a_test", "bot_c_test"].sort(),
  weekly: { tests: ["w_one_test"], bots: ["w_bot_test"] },
};
const bands = {
  A: [{ test: "a_one_test" }, { test: "bot_a_test", bots: true }],
  C_smoke: [{ test: "c_one_test" }, { test: "bot_c_test", bots: true }],
  B: { only: "w1", seeds: 24 },
  C_rungs: { only: "w1", bands: "expert", tiers: [{ tier: 1, seeds: 24 }, { tier: 5, seeds: 48 }] },
};
const head = "75099fa7080378295788d9741a0a03fdf9e594b2";
const plan = (extra = {}) => gatePlan({ wave: 34, head, lists, weekly: null, bands, persona: "cautious", ...extra });

test("the plan covers the non-bot list in three windows with no gap, five bot blocks, the bands, and exclusive steps last", () => {
  assert.equal(lists.tests.length, 1049);
  assert.equal(lists.bots.length, 23);
  const steps = plan();
  const windows = steps.filter((step) => step.id.startsWith("tests-")).map((step) => step.id.split("-").slice(1).map(Number));
  assert.equal(windows.length, 3);
  assert.equal(windows[0][0], 1);
  assert.equal(windows[2][1], 1049);
  windows.slice(1).forEach(([first], index) => assert.equal(first, windows[index][1] + 1));
  assert.equal(steps.filter((step) => step.id.startsWith("bots-")).length, 5);
  assert.deepEqual(steps.find((step) => step.id === "bots-5").args, ["--bots", "21-23"]);
  for (const id of ["bands-A", "bands-B", "bands-C", "node", "redteam", "compare", "plan-file"]) assert.ok(steps.some((step) => step.id === id), id);
  assert.equal(steps.some((step) => step.id.startsWith("weekly")), false);
  assert.deepEqual(steps.slice(-3).map((step) => step.id), ["redteam", "compare", "plan-file"]);
  assert.deepEqual(steps.filter((step) => step.exclusive).map((step) => step.id), ["redteam"]);
  assert.equal(steps.find((step) => step.id === "tests-1-350").weight, 6);
  assert.equal(steps.find((step) => step.id === "bots-1").weight, 8);
  assert.equal(steps.some((step) => step.id === "redteam"), true);
  assert.equal(plan({ persona: null }).some((step) => step.id === "redteam"), false, "no persona, no red team step");
});

test("the weekly steps appear only when weekly is on", () => {
  const steps = plan({ weekly: lists.weekly });
  assert.deepEqual(steps.filter((step) => step.id.startsWith("weekly")).map((step) => [step.id, step.weight, step.args.join(" ")]), [["weekly-tests", 6, "--weekly --tests 1-1"], ["weekly-bots", 8, "--weekly --bots 1-1"]]);
});

// Records the running weight at every start; each step takes `ms` of real time.
function harness(budget, steps, { done = new Set() } = {}) {
  const log = { peak: 0, used: 0, running: 0, started: [], aloneViolations: [] };
  const start = async (step) => {
    log.running++;
    log.used += step.weight;
    log.peak = Math.max(log.peak, log.used);
    if ((step.exclusive || step.weight > budget) && log.running > 1) log.aloneViolations.push(`${step.id} started with others running`);
    log.started.push(step.id);
    if (log.exclusiveNow) log.aloneViolations.push(`${step.id} started during ${log.exclusiveNow}`);
    if (step.exclusive || step.weight > budget) log.exclusiveNow = step.id;
    await new Promise((resolve) => setTimeout(resolve, step.ms ?? 10));
    if (log.exclusiveNow === step.id) log.exclusiveNow = null;
    log.running--;
    log.used -= step.weight;
    return 0;
  };
  return { log, run: () => runPlan(steps, { budget, start, isDone: (step) => (done.has(step.id) ? { exit: 0 } : null) }) };
}

const fake = (id, weight, extra = {}) => ({ id, weight, ms: 10, exclusive: false, ...extra });

test("the scheduler never runs above the budget, skips done steps, and keeps exclusive and oversized steps alone", async () => {
  const steps = [fake("a", 6, { ms: 10 }), fake("b", 6, { ms: 30 }), fake("c", 6, { ms: 30 }), fake("d", 8, { ms: 30 }), fake("skip", 6), fake("huge", 20), fake("e", 4), fake("x", 8, { exclusive: true }), fake("after", 2)];
  const { log, run } = harness(16, steps, { done: new Set(["skip"]) });
  const exits = await run();
  assert.ok(log.peak <= 16 || log.started.includes("huge"));
  assert.equal(log.started.includes("skip"), false);
  assert.deepEqual(log.aloneViolations, []);
  assert.equal(exits.size, steps.length);
  assert.equal(log.started.at(-2), "x", "the exclusive step runs after every other Godot step");
  assert.deepEqual(log.started, ["a", "b", "c", "d", "huge", "e", "x", "after"], "admission follows the plan's order");
});

test("a step that takes the whole budget keeps later steps out while a lighter step waits behind it", async () => {
  const steps = [fake("full", 16, { ms: 30 }), fake("wait", 6, { ms: 10 }), fake("gap", 8, { ms: 10 })];
  const { log, run } = harness(16, steps);
  await run();
  assert.equal(log.peak, 16, "the gap rule admits only what fits the budget now");
});

test("a scheduler that honours weights peaks at 14 on this input, and one that starts everything does not", async () => {
  const steps = [fake("a", 6, { ms: 10 }), fake("b", 6, { ms: 30 }), fake("c", 6, { ms: 30 }), fake("d", 8, { ms: 30 })];
  const { log, run } = harness(16, steps);
  await run();
  assert.equal(log.peak, 14);
  const naive = { used: 0, peak: 0 };
  await Promise.all(steps.map(async (step) => {
    naive.used += step.weight;
    naive.peak = Math.max(naive.peak, naive.used);
    await new Promise((resolve) => setTimeout(resolve, step.ms));
    naive.used -= step.weight;
  }));
  assert.equal(naive.peak, 26);
  assert.ok(naive.peak > 16, "the assertion can fail: starting everything breaks the budget");
});

test("spareWhileWaiting is the room a later step may take without ever delaying the waiting step", () => {
  // The wave 35 gate: two windows at 6 running, the third at 6 waiting, budget 16. One finishing frees 6, the head needs 2.
  assert.equal(spareWhileWaiting([6, 6], 6, 16), 4);
  // With a 2 already in the gap the head needs 4; a 6 finishing still frees 6, so 2 more may start.
  assert.equal(spareWhileWaiting([6, 6, 2], 6, 16), 2);
  // The lightest set that frees enough decides: an 8 or the two 3s could finish first, and the 3s free exactly 6.
  assert.equal(spareWhileWaiting([8, 3, 3], 8, 16), 0);
  // A head that already fits has no gap to fill, and one nothing can free room for gets no company.
  assert.equal(spareWhileWaiting([6], 6, 16), 0);
  assert.equal(spareWhileWaiting([], 20, 16), 0);
});

// Start and end order with real waits, to see who got in and whether the waiting step was held back.
function timeline(budget, steps) {
  const events = [];
  const start = async (step) => {
    events.push(`+${step.id}`);
    await new Promise((resolve) => setTimeout(resolve, step.ms));
    events.push(`-${step.id}`);
    return 0;
  };
  return { events, run: () => runPlan(steps, { budget, start }) };
}

test("a light step starts in the gap behind a waiting step, and the waiting step still starts the moment it fits", async () => {
  const steps = [fake("t1", 6, { ms: 40 }), fake("t2", 6, { ms: 120 }), fake("t3", 6, { ms: 20 }), fake("bots", 8, { ms: 20 }), fake("node", 2, { ms: 200 })];
  const { events, run } = timeline(16, steps);
  await run();
  assert.ok(events.indexOf("+node") < events.indexOf("-t1"), "node (2) starts while t1 and t2 run and t3 waits");
  assert.equal(events[events.indexOf("-t1") + 1], "+t3", "t3 starts as soon as t1 ends, with node still running");
  assert.ok(events.indexOf("+bots") > events.indexOf("-t1"), "bots (8) never fits the gap of 4");
});

test("a step that could delay the waiting step stays behind it, and nothing passes an exclusive step", async () => {
  const held = timeline(16, [fake("a", 6, { ms: 30 }), fake("b", 6, { ms: 60 }), fake("c", 6, { ms: 10 }), fake("five", 5, { ms: 10 })]);
  await held.run();
  assert.ok(held.events.indexOf("+five") > held.events.indexOf("+c"), "a 5 does not fit the spare of 4, so it keeps its place");
  const fenced = timeline(16, [fake("a", 6, { ms: 30 }), fake("b", 6, { ms: 30 }), fake("c", 6, { ms: 10 }), fake("x", 2, { ms: 10, exclusive: true }), fake("tiny", 1, { ms: 10 })]);
  await fenced.run();
  assert.ok(fenced.events.indexOf("+tiny") > fenced.events.indexOf("-x"), "tiny sits behind an exclusive step and waits for it");
  // The case a scheduler that fills any gap that fits gets wrong: `six` fits the raw free room of 6, but with it
  // running `c` (12) could not start when `a` ends. It must wait, and `c` must start the moment `a` ends.
  assert.equal(spareWhileWaiting([6, 4], 12, 16), 0, "raw free room is 6, the safe spare is 0");
  const tempting = timeline(16, [fake("a", 6, { ms: 30 }), fake("b", 4, { ms: 90 }), fake("c", 12, { ms: 10 }), fake("six", 6, { ms: 200 })]);
  await tempting.run();
  assert.equal(tempting.events[tempting.events.indexOf("-a") + 1], "+c", "c starts as soon as a ends");
  assert.ok(tempting.events.indexOf("+six") > tempting.events.indexOf("+c"), "six would have held c back, so it waits");
});

test("a step added by onExit runs before the barrier steps, and a done step still reports its exit", async () => {
  const steps = [fake("shard", 6), fake("last", 0, { barrier: true })];
  const order = [];
  const exits = await runPlan(steps, {
    budget: 16,
    start: async (step) => {
      order.push(step.id);
      return step.id === "retime-shard" ? 3 : 0;
    },
    isDone: (step) => (step.id === "shard" ? { exit: 2 } : null),
    onExit: (step, exit) => (step.id === "shard" && exit === 2 ? [fake("retime-shard", 2, { exclusive: true })] : []),
  });
  assert.deepEqual(order, ["retime-shard", "last"]);
  assert.equal(exits.get("shard"), 2);
  assert.equal(exits.get("retime-shard"), 3);
});

const runLine = (extra) => JSON.stringify({ cell: "w1", band: "expert", build: "x", seed: 1, attempt: 1, outcome: "win", game_seconds: 100, wallS: 5, qa: { a: 1 }, key: "k", commit: "c", comic_page: 3, ...extra });

test("compareRuns ignores wall time, the play watch and naming fields, and names the one field that moved", () => {
  const base = [runLine({}), runLine({ seed: 2 })].join("\n");
  assert.equal(compareRuns(base, base).code, 0);
  const noisy = [runLine({ wallS: 99, qa: { a: 2 }, key: "z", commit: "d", comic_page: 9, label: "x" }), runLine({ seed: 2 })].join("\n");
  assert.equal(compareRuns(base, noisy).code, 0);
  // The fairness record is a measurement: adding or changing it is not a different run, a moved outcome beside it still is.
  const plain = [runLine({ row: { outcome: "won" } }), runLine({ seed: 2 })].join("\n");
  const measured = [runLine({ row: { outcome: "won", fairness: { telegraph_share: 0.9, stop_tax: 3, first_hit_s: 4 } } }), runLine({ seed: 2 })].join("\n");
  assert.equal(compareRuns(plain, measured).code, 0);
  assert.equal(compareRuns(plain, [runLine({ row: { outcome: "died", fairness: { stop_tax: 1 } } }), runLine({ seed: 2 })].join("\n")).code, 1);
  const moved = compareRuns(base, [runLine({ game_seconds: 101 }), runLine({ seed: 2 })].join("\n"));
  assert.equal(moved.code, 1);
  assert.equal(moved.differing, 1);
  assert.equal(moved.diffs[0].fields[0].path, "/game_seconds");
  assert.equal(compareRuns("", base).code, 3);
  assert.equal(compareRuns(base, runLine({})).code, 3);
});

test("compareLines ignores wall seconds and order, and reports a line that moved", () => {
  const base = "x -> PASS (12.5s)\ny -> PASS\nnoise without an arrow\n";
  assert.equal(sortedLines(base).length, 2);
  assert.equal(compareLines(base, "y -> PASS\nx -> PASS (99.1s)\n").code, 0);
  const moved = compareLines(base, "y -> FAIL\nx -> PASS (3s)\n");
  assert.equal(moved.code, 1);
  assert.deepEqual(moved.onlyBase, ["y -> PASS"]);
  assert.deepEqual(moved.onlyHead, ["y -> FAIL"]);
});

test("compareLines drops a bot run's wall seconds as the runner prints them, and keeps its game seconds", () => {
  const line = (game, wall) => `bot_run: skipper seed 1 (runner_gunner) -> ticks_done at stage 4, 30000 ticks (${game} s game), ${wall} s wall\n`;
  assert.equal(compareLines(line("333.3", "247.6"), line("333.3", "301.2")).code, 0);
  assert.equal(compareLines(line("333.3", "247.6"), line("215.7", "247.6")).code, 1);
  const median = (seconds) => `[Spillway skipper breaks it in 45 to 90 s] median ${seconds} s of [54.59, 89.72] -> PASS\n`;
  assert.equal(compareLines(median("89.7"), median("88.1")).code, 1);
});

test("band comparison reads each band against the base, and reads null with no base", () => {
  const files = { base: {}, head: {} };
  const put = (rel, text) => ((files.base[rel] = text), (files.head[rel] = text));
  for (const [dir, prefix, tests] of [["bands-A", "", bands.A], ["bands-C", "smoke-", bands.C_smoke]]) for (const { test: name } of tests) (put(`${dir}/${prefix}${name}.lines`, "a -> PASS\n"), put(`${dir}/${prefix}${name}.exit`, "0\n"));
  put("bands-B/runs.ndjson", runLine({}));
  for (const { tier } of bands.C_rungs.tiers) put(`bands-C/t${tier}-runs.ndjson`, runLine({}));
  const read = (side, rel) => files[side][rel] ?? null;
  const same = compareBands(read, bands, true);
  assert.deepEqual([same.A.identical, same.B.identical, same.C.identical], [true, true, true]);
  files.head["bands-C/t5-runs.ndjson"] = runLine({ outcome: "loss" });
  files.head["bands-A/a_one_test.exit"] = "1\n";
  const moved = compareBands(read, bands, true);
  assert.deepEqual([moved.A.identical, moved.B.identical, moved.C.identical], [false, true, false]);
  assert.match(moved.C.notes.at(-1).text, /bands C rung 5: .*differing 1.*\/outcome/);
  assert.deepEqual(compareBands(read, bands, false).A, { identical: null, notes: [] });
});

function allPass(steps) {
  const results = {};
  for (const step of steps) {
    if (step.kind === "shard") results[step.id] = { exit: 0, verdict: "PASS, no new red (1 carried on the ledger)" };
    else if (step.kind.startsWith("bands-") || step.kind === "node") results[step.id] = { exit: 0, verdict: "1049 tests, 0 fail." };
    else if (step.kind === "redteam") results[step.id] = { exit: 0, blockers: 0 };
  }
  return results;
}
const same = { base: true, A: { identical: true, notes: [] }, B: { identical: true, notes: [] }, C: { identical: true, notes: [] } };
const today = new Date(Date.UTC(2026, 10, 12));

test("the plan file parses through the tally and passes when everything passed and every band matched", () => {
  const steps = plan({ weekly: lists.weekly });
  const text = planFileText({ wave: 34, head, persona: "cautious", base: "/g/w33-aaaaaaaa", results: allPass(steps), compare: same, steps, today });
  const rows = tallyRows(text);
  assert.equal(rows.length, 3 + 5 + 3 + 1 + 1);
  assert.deepEqual(checkTally(rows, { testCount: 1049, botCount: 23, planHead: planHead(`/g/w34-${head.slice(0, 8)}-gate-plan.md`), head, weeklyCount: 2, today }), []);
  assert.match(text, /\| weekly sweep \| PASS 2026-11-12\. Receipts weekly-tests\/receipt\.md, weekly-bots\/receipt\.md \|/);
  assert.equal(expectedShards(23).every((name) => rows.some((row) => row.shard.toLowerCase().startsWith(name.toLowerCase()))), true);
});

test("a band that moved, a missing base, a retimed shard and a missing persona each read as the tally needs", () => {
  const steps = plan();
  const results = allPass(steps);
  const moved = { ...same, B: { identical: false, notes: [{ ok: false, text: "bands B: 24 runs, identical 23, differing 1" }] } };
  const text = planFileText({ wave: 34, head, persona: "cautious", base: "/g/x", results, compare: moved, steps, today });
  assert.match(text, /\| bands B \| RED: the band moved against the base/);
  assert.match(checkTally(tallyRows(text), { testCount: 1049, botCount: 23 }).join("\n"), /"bands B" does not open with PASS/);
  assert.doesNotMatch(checkTally(tallyRows(text), { testCount: 1049, botCount: 23 }).join("\n"), /"bands A"/);
  assert.match(planFileText({ wave: 34, head, persona: "cautious", base: null, results, compare: { base: false }, steps, today }), /\| bands A \| NO BASE:/);
  const inconclusive = { ...results, "tests-351-700": { exit: 2, verdict: 'INCONCLUSIVE: 1 time-out(s) under load (x_test); rerun alone on a quiet machine with "node scripts/gate/shard.mjs retime"' }, "retime-tests-351-700": { exit: 0, verdict: "PASS: every run passed alone on a quiet machine" } };
  const retimed = planFileText({ wave: 34, head, persona: "cautious", base: "/g/x", results: inconclusive, compare: same, steps, today });
  assert.match(retimed, /\| tests 351-700 \| PASS after retime \(INCONCLUSIVE.*Receipts tests-351-700\/receipt\.md, retime-tests-351-700\/receipt\.md \|/);
  assert.equal(checkTally(tallyRows(retimed), { testCount: 1049, botCount: 23 }).length, 0);
  const open = { ...inconclusive, "retime-tests-351-700": undefined };
  const stuck = planFileText({ wave: 34, head, persona: "cautious", base: "/g/x", results: Object.fromEntries(Object.entries(open).filter(([, v]) => v)), compare: same, steps, today });
  assert.match(checkTally(tallyRows(stuck), { testCount: 1049, botCount: 23 }).join("\n"), /"tests 351-700" does not open with PASS/);
  const noPersona = planFileText({ wave: 34, head, persona: null, base: "/g/x", results, compare: same, steps: plan({ persona: null }), today });
  assert.match(noPersona, /red team <persona>` row is owed/);
  assert.match(checkTally(tallyRows(noPersona), { testCount: 1049, botCount: 23 }).join("\n"), /no row for "red team"/);
});

test("a step's environment keeps its data home and slot pool under the gate root and refuses anything else", () => {
  const env = stepEnv({ root: "/g", id: "tests-1-350", godot: "/bin/godot", base: { PATH: "/bin", XDG_DATA_HOME: "/home/real" } });
  assert.equal(env.XDG_DATA_HOME, "/g/xdg/tests-1-350/data");
  const mac = stepEnv({ root: "/g", id: "a", godot: "g", base: { HOME: "/Users/real" }, platform: "darwin" });
  assert.equal(mac.HOME, "/g/xdg/a/data", "Godot on macOS keeps user:// under HOME, so the step moves HOME too");
  assert.equal(stepEnv({ root: "/g", id: "a", godot: "g", base: { HOME: "/home/real" }, platform: "linux" }).HOME, "/home/real");
  assert.equal(env.SCRAPKEEP_LOCK_DIR, "/g/locks/tests-1-350");
  assert.deepEqual([env.SMOKE_SLOTS, env.SMOKE_FULL, env.GODOT_BIN], ["4", "1", "/bin/godot"]);
  assert.throws(() => stepEnv({ root: "/g", id: "../../home/andrew", godot: "g" }), /outside \/g/);
  assert.throws(() => stepEnv({ root: "/g", id: "", godot: "g" }), /outside/);
  assert.notEqual(stepEnv({ root: "/g", id: "a", godot: "g" }).SCRAPKEEP_LOCK_DIR, stepEnv({ root: "/g", id: "b", godot: "g" }).SCRAPKEEP_LOCK_DIR);
});

test("bands.json is rejected for an unknown test, a weekly test, or a bot flag that does not match", () => {
  const full = { tests: ["a_test"], bots: ["bot_test"], weekly: { tests: ["w_test"], bots: ["wb_test"] } };
  const with_ = (A) => ({ A, C_smoke: [], B: {}, C_rungs: {} });
  assert.deepEqual(checkBands(with_([{ test: "a_test" }, { test: "bot_test", bots: true }]), full), []);
  assert.match(checkBands(with_([{ test: "gone_test" }]), full)[0], /gone_test is not a non-bot test/);
  assert.match(checkBands(with_([{ test: "w_test" }]), full)[0], /w_test is on the weekly list/);
  assert.match(checkBands(with_([{ test: "bot_test" }]), full)[0], /bot_test is not a non-bot test/);
  const dir = mkdtempSync(path.join(os.tmpdir(), "pc-bands-"));
  try {
    mkdirSync(path.join(dir, "tests"));
    writeFileSync(path.join(dir, "bands.json"), JSON.stringify(with_([{ test: "gone_test" }])));
    assert.throws(() => loadBands(full, path.join(dir, "bands.json")), /gone_test/);
    writeFileSync(path.join(dir, "bands.json"), JSON.stringify({ A: [] }));
    assert.throws(() => loadBands(full, path.join(dir, "bands.json")), /no "C_smoke"/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("the shipped bands.json names real tests on the gate lists", async () => {
  const { gateLists } = await import("./shard.mjs");
  const real = gateLists(path.join(path.dirname(new URL(import.meta.url).pathname), "..", "..", "sketches", "core-loop"));
  assert.doesNotThrow(() => loadBands(real));
});

test("the worktree pool reuses a free worktree, prefers the one a step used, and adds one only when none is free", () => {
  const added = [];
  const saved = [];
  const pool = worktreePool({ dir: "/w", add: (dir) => added.push(dir), existing: ["1"], saveOwners: (map) => saved.push({ ...map }) });
  const first = pool.acquire("a");
  assert.equal(first, "/w/1");
  assert.equal(pool.acquire("b"), "/w/2", "the first is busy, so a second is added");
  assert.deepEqual(added, ["/w/2"]);
  pool.release("/w/2");
  pool.release("/w/1");
  assert.equal(pool.acquire("b"), "/w/2", "a step gets its own worktree back");
  assert.equal(pool.acquire("c"), "/w/1");
  assert.equal(added.length, 1);
  assert.equal(saved.at(-1).b, "2");
});

test("challenge arguments carry the label, jobs and resume the way the lane scripts did", () => {
  assert.deepEqual(challengeArgs({ only: "w1", seeds: 24, label: "w34-75099fa7-w1", resume: false }), ["scripts/challenge/run.mjs", "--only=w1", "--seeds=24", "--no-top", "--jobs=12", "--label=w34-75099fa7-w1"]);
  assert.deepEqual(challengeArgs({ only: "w1", seeds: 48, bands: "expert", tier: 5, label: "l", resume: true }).slice(2), ["--seeds=48", "--bands=expert", "--tier=5", "--no-top", "--jobs=12", "--label=l", "--resume"]);
  assert.equal(nodeSummary("ℹ tests 1049\nℹ pass 1049\nℹ fail 0\n").tests, 1049);
  assert.equal(nodeSummary("# tests 3\n# fail 1\n").fail, 1);
  assert.ok(Number.isNaN(nodeSummary("nothing").tests), "a missing summary is not zero failures");
});

test("the wave gate plan (--scoped) is the three windows, one scoped shard by name, the node suite and the plan file", () => {
  const waveLists = { ...lists, bots: [...lists.bots, ...SCOPED_ALWAYS].sort() };
  const steps = gatePlan({ wave: 37, head, lists: waveLists, weekly: lists.weekly, bands: null, persona: "cautious", scoped: ["bot_c_test", "bot_a_test.gd", "w_bot_test", "a_one_test"] });
  assert.deepEqual(steps.map((step) => step.id), ["scoped", "tests-1-350", "tests-351-700", "tests-701-1049", "weekly-tests", "weekly-bots", "node", "plan-file"]);
  assert.deepEqual(steps.find((step) => step.id === "scoped").args, ["--bots", "bot_a_test,bot_c_test,w_bot_test,world1_run_test", "--lanes", "2"]);
  assert.throws(() => gatePlan({ wave: 37, head, lists: waveLists, bands: null, scoped: ["no_such_test"] }), /on no gate list: no_such_test/);
  assert.throws(() => gatePlan({ wave: 37, head, lists, bands: null, scoped: [] }), /on no gate list: world1_run_test/);
  const text = planFileText({ wave: 37, head, persona: null, base: null, results: allPass(steps), compare: null, steps, today });
  const rows = tallyRows(text);
  assert.deepEqual(rows.map((row) => row.shard), ["scoped", "tests 1-350", "tests 351-700", "tests 701-1049", "weekly sweep"]);
  assert.deepEqual(checkTally(rows, { testCount: 1049, botCount: waveLists.bots.length, weeklyCount: 2, today, scope: "wave" }), []);
  assert.match(text, /tally\.mjs --wave --plan/);
  assert.notDeepEqual(checkTally(rows, { testCount: 1049, botCount: waveLists.bots.length, today }), [], "the release tally still wants every shard");
});

test("on the PC's default budget the wave gate's bot shard starts at once beside two test windows, with no wait", async () => {
  assert.equal(defaultBudget(32), 28, "the budget is the thread count less four, read against measured load");
  assert.equal(defaultBudget(2), 1);
  const waveLists = { ...lists, bots: [...lists.bots, ...SCOPED_ALWAYS].sort() };
  const steps = gatePlan({ wave: 42, head, lists: waveLists, weekly: null, bands: null, scoped: ["bot_a_test"] })
    .filter((step) => !step.barrier)
    .map((step) => ({ ...step, ms: step.id === "scoped" ? 120 : 40 }));
  const { log, run } = harness(defaultBudget(32), steps);
  let atThirdStart = null;
  const watch = steps.find((step) => step.id === "tests-701-1049");
  Object.defineProperty(watch, "ms", { get: () => ((atThirdStart ??= [...log.started]), 40) });
  await run();
  assert.deepEqual(log.started.slice(0, 3), ["scoped", "tests-1-350", "tests-351-700"], "the longest step starts first, beside two windows");
  assert.deepEqual(atThirdStart.slice(0, 4), ["scoped", "tests-1-350", "tests-351-700", "tests-701-1049"], "the third window takes the room a finished window leaves");
  assert.ok(log.peak <= 28);
  assert.deepEqual(log.aloneViolations, []);
});

test("the scoped names can come from a sketch:fast receipt's bot shards", () => {
  assert.deepEqual(receiptBotShards({ selection: { bot_shards: ["tests/bot_a_test.gd", "tests/world1_run_test.gd"] } }), ["bot_a_test", "world1_run_test"]);
  assert.throws(() => receiptBotShards({ selection: {} }), /no selection.bot_shards/);
});
