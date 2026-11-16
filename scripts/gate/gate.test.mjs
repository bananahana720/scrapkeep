import assert from "node:assert/strict";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import path from "node:path";

import { indexFromFiles } from "../sketch-fast.mjs";
import { parseLedger } from "../known-failing.mjs";
import { place, sortChanges, testsToRerun } from "./carry.mjs";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import { WEEKLY_HEADER, chunks, classifyFailure, errorCounts, gateLists, importOutcome, nearLimit, numbered, parseSmokeLog, parseWeekly, parseWindow, renderReceipt, windowNames, namedPool, testName, retime, shardVerdict, soloEnvironment, soloTests, failedChecks, whatFailed } from "./shard.mjs";
import { WEEKLY_MAX_DAYS, checkTally, checkWeeklySweep, expectedShards, isDeferred, isPass, planHead, tallyRows } from "./tally.mjs";
import { WEEKLY_FILE, checkWeekly } from "./weekly.mjs";

const repoRoot = fileURLToPath(new URL("../..", import.meta.url));
const ledger = parseLedger(
  [
    "test\tkind\tcause\towner\tadded\treview",
    "red_test\tred\tpin off by 2 s\tcoordinator\t2026-11-09\t2026-11-23",
    "wobble_test\tflake\ttimed in wall milliseconds\ttesting lane\t2026-11-09\t2026-11-23",
  ].join("\n"),
).rows;

test("the gate lists split the sorted tests by the bot marker and number from 1", () => {
  const lists = gateLists(path.join(repoRoot, "sketches", "core-loop"));
  assert.ok(lists.tests.length > 1000);
  // The bot tier as a whole: the weekly list (ruling ca) moves bot tests out of the promotion list, not out of the tree.
  assert.ok(lists.bots.length + lists.weekly.bots.length >= 30);
  assert.deepEqual([...lists.tests].sort(), lists.tests);
  assert.ok(lists.bots.includes("alpha_bot_sweep_test") && !lists.tests.includes("alpha_bot_sweep_test"));
  assert.equal(numbered(["a_test", "b_test"]), "     1\ta_test.gd\n     2\tb_test.gd");
});

test("a window is counted from 1 with both ends included and must fit the list", () => {
  assert.deepEqual(parseWindow("361-720", 1087), { first: 361, last: 720 });
  assert.throws(() => parseWindow("0-5", 10), /does not fit/);
  assert.throws(() => parseWindow("5-11", 10), /does not fit/);
  assert.throws(() => parseWindow("first third", 10), /FIRST-LAST/);
  assert.deepEqual(chunks(["a", "b", "c", "d", "e"], 2), [["a", "b"], ["c", "d"], ["e"]]);
});

test("a runner log yields one result per test and ignores import and summary lines", () => {
  const log = [
    "PASS sketches/core-loop import exit=0 3.9s",
    "PASS sketches/core-loop res://tests/a_test.gd exit=0 12.0s",
    "FAIL sketches/core-loop res://tests/b_test.gd exit=null 360.1s",
    "  >> [small median] 119.1 s -> FAIL",
    "slowest 2:",
    "  360.1s sketches/core-loop res://tests/b_test.gd",
  ].join("\n");
  assert.deepEqual(parseSmokeLog(log), [
    { test: "a_test", ok: true, exit: "0", seconds: 12 },
    { test: "b_test", ok: false, exit: "null", seconds: 360.1 },
  ]);
});

test("error lines are counted by kind", () => {
  const text = "ERROR: a leak\nWARNING: 3 ObjectDB instances leaked at exit\n   SCRIPT ERROR: bad call\nResource still in use\nnot an ERROR line\n";
  assert.deepEqual(errorCounts(text), { error: 1, script_error: 1, in_use: 1, freed: 0, leaked_warning: 1 });
});

test("a failure is carried only with a ledger row, and blocks when it fails alone without one", () => {
  assert.equal(classifyFailure("red_test", [false, false], ledger).call, "carried");
  assert.equal(classifyFailure("wobble_test", [true, true], ledger).call, "carried");
  assert.equal(classifyFailure("wobble_test", [true, false], ledger).call, "carried");
  const mismatch = classifyFailure("wobble_test", [false, false, false, false], ledger);
  assert.equal(mismatch.call, "mismatch");
  assert.match(mismatch.note, /failed every solo run/);
  assert.deepEqual(shardVerdict([mismatch]), { ok: false, line: "RED: 1 listed as a flake but red alone (wobble_test)" });
  const flake = classifyFailure("fresh_test", [true, true], ledger);
  assert.equal(flake.call, "new-flake");
  assert.equal(flake.alone, "2/2 pass alone");
  assert.equal(classifyFailure("fresh_test", [true, false], ledger).call, "new-red");
  assert.equal(classifyFailure("fresh_test", [false, false], ledger).call, "new-red");
});

test("a failed test with a red row is carried from its first run and is not rerun alone", () => {
  // The first run already shows which check failed, and that run is read against the row, so a rerun adds only time.
  // (Trial gate on 375fe11a, 15 Nov: two such reruns took 832 s of the bot shard's 6922 s.)
  const failedACheck = () => ({ timedOut: false, failLines: 1 });
  assert.deepEqual(soloTests(["red_test", "wobble_test", "fresh_test"], ledger, failedACheck), ["wobble_test", "fresh_test"]);
  // A time-out, a kill or a run with no failing check does not show which check failed, so it is still rerun.
  assert.deepEqual(soloTests(["red_test"], ledger, () => ({ timedOut: true, failLines: 0 })), ["red_test"]);
  assert.deepEqual(soloTests(["red_test"], ledger, () => ({ timedOut: false, failLines: 0 })), ["red_test"]);
  assert.deepEqual(soloTests(["red_test"], ledger, () => null), ["red_test"]);
  const carried = classifyFailure("red_test", [], ledger);
  assert.equal(carried.call, "carried");
  assert.equal(carried.alone, "not rerun: red row, a check failed in the first run");
  // By test name alone the call is the same with solo runs; what each failed run did is read separately (whatFailed).
  for (const runs of [[false], [true], [false, false], [true, true]]) assert.equal(classifyFailure("red_test", runs, ledger).call, "carried");
  // Without a row, no solo run is never a pass.
  assert.equal(classifyFailure("fresh_test", [], ledger).call, "new-red");
});

test("a red row carries only the check it names; another failing check in the same test is a new red (ruling dx)", () => {
  const named = parseLedger(["test\tkind\tcause\towner\tadded\treview\tcheck", "red_test\tred\tpin off by 2 s\tcoordinator\t2026-11-09\t2026-11-23\tpin within 2 s"].join("\n")).rows;
  assert.equal(classifyFailure("red_test", [], named, null, { labels: ["pin within 2 s"] }).call, "carried");
  const second = classifyFailure("red_test", [], named, null, { labels: ["pin within 2 s", "stage 1 draw"] });
  assert.equal(second.call, "new-red");
  assert.match(second.note, /fails a check its row does not name: stage 1 draw/);
  assert.deepEqual(shardVerdict([second]), { ok: false, line: "RED: 1 new red (red_test)" });
  // The same holds when the test was rerun alone.
  assert.equal(classifyFailure("red_test", [false], named, null, { labels: ["stage 1 draw"] }).call, "new-red");
  // A killed run is not the named check either.
  assert.equal(classifyFailure("red_test", [false], named, null, { labels: [], timedOut: true }).call, "new-red");
  assert.deepEqual(failedChecks("[a] 1 -> PASS\n  >> [pin within 2 s] got 3 -> FAIL\n[pin within 2 s] got 3 -> FAIL\n[stage 1 draw] got \"x\", want \"y\" -> FAIL\n"), ["pin within 2 s", "stage 1 draw"]);
});

test("every failed run of a listed test is read against its row, not only the last one (PR 1051 review)", () => {
  const named = parseLedger(["test\tkind\tcause\towner\tadded\treview\tcheck", "red_test\tred\tpin off by 2 s\tcoordinator\t2026-11-09\t2026-11-23\tpin within 2 s"].join("\n")).rows;
  const pin = "[pin within 2 s] got 3 -> FAIL\n";
  const other = "[stage 1 draw] got 1 -> FAIL\n";
  // First run killed after an unnamed check failed; alone it fails only the named check.
  const mixed = whatFailed([{ ok: false, text: other, timedOut: true }, { ok: false, text: pin, timedOut: false }]);
  assert.deepEqual(mixed, { labels: ["stage 1 draw", "pin within 2 s"], timedOut: true, errorLine: false });
  assert.equal(classifyFailure("red_test", [false], named, null, mixed).call, "new-red");
  // Every solo run passed: the first run is still read, so a retry does not decide the call.
  const retried = whatFailed([{ ok: false, text: other, timedOut: false }, { ok: true, text: "[a] 1 -> PASS\n", timedOut: false }]);
  assert.deepEqual(retried.labels, ["stage 1 draw"]);
  assert.equal(classifyFailure("red_test", [true], named, null, retried).call, "new-red");
  assert.equal(classifyFailure("red_test", [true], named, null, whatFailed([{ ok: false, text: pin, timedOut: false }, { ok: true, text: "", timedOut: false }])).call, "carried");
  // A passing run's lines are not read; an ERROR line of a failed run is.
  assert.deepEqual(whatFailed([{ ok: false, text: pin + "ERROR: resumed after await\n", timedOut: false }, { ok: true, text: other, timedOut: false }]), { labels: ["pin within 2 s"], timedOut: false, errorLine: true });
  assert.equal(whatFailed([{ ok: false, text: pin + "SCRIPT ERROR: Invalid call\n", timedOut: false }]).errorLine, true);
  // A failed run with no log, and a failing line the pattern cannot label, are never read as nothing.
  assert.deepEqual(whatFailed([{ ok: false, text: null, timedOut: false }]).labels, ["a failed run left no log"]);
  assert.deepEqual(failedChecks("CUA check -> FAIL: door\n[pin within 2 s] got 3 -> FAIL\n"), ["unlabelled failing line: CUA check -> FAIL: door", "pin within 2 s"]);
});

test("a load time-out never hides a check the row does not name (PR 1051, second review)", () => {
  const named = parseLedger(["test\tkind\tcause\towner\tadded\treview\tcheck", "red_test\tred\tpin off by 2 s\tcoordinator\t2026-11-09\t2026-11-23\tpin within 2 s"].join("\n")).rows;
  const loaded = { threads: 32, runs: [{ timedOut: true, failLines: 0, load: 20 }, { timedOut: true, failLines: 0, load: 20 }] };
  // First run failed an unnamed check and was killed; both solo runs were killed under load with no check.
  const hidden = classifyFailure("red_test", [false, false], named, loaded, { labels: ["stage 1 draw"], timedOut: true, errorLine: false });
  assert.equal(hidden.call, "new-red");
  assert.match(hidden.note, /stage 1 draw/);
  // Only the kill is unnamed: that is what a retime on a quiet machine can settle.
  assert.equal(classifyFailure("red_test", [false, false], named, loaded, { labels: ["pin within 2 s"], timedOut: true, errorLine: false }).call, "suspect-load");
  assert.equal(classifyFailure("red_test", [false, false], named, loaded, { labels: [], timedOut: true, errorLine: false }).call, "suspect-load");
  // A passing check line is not a failing check, and an error line counts as the runner counts it: at column 0.
  assert.deepEqual(failedChecks("[x] expected -> FAIL, got it -> PASS\n"), []);
  // The last arrow on the line is the verdict: a failing check whose detail quotes "-> PASS" still fails.
  assert.deepEqual(failedChecks('[stage 1 draw] wanted an "a -> PASS" line, got none -> FAIL\n'), ["stage 1 draw"]);
  assert.equal(whatFailed([{ ok: false, text: "[pin within 2 s] got 3 -> FAIL\n  child: ERROR: echoed\n   ERROR: indented\n", timedOut: false }]).errorLine, false);
});

test("a shard is red only for a new red, and its verdict names what it carried", () => {
  const carried = classifyFailure("red_test", [false, false], ledger);
  const flake = classifyFailure("fresh_test", [true, true], ledger);
  const red = classifyFailure("broken_test", [false, false], ledger);
  assert.deepEqual(shardVerdict([]), { ok: true, line: "PASS, no new red" });
  assert.deepEqual(shardVerdict([carried, flake]), { ok: true, line: "PASS, no new red (1 carried on the ledger, 1 new load flake for its owner to fix)" });
  assert.deepEqual(shardVerdict([carried, red]), { ok: false, line: "RED: 1 new red (broken_test)" });
});

test("tests at or past 85% of their limit are listed, nearest first", () => {
  const results = [
    { test: "fast_test", seconds: 20 },
    { test: "close_test", seconds: 325 },
    { test: "closer_test", seconds: 175 },
  ];
  const limits = { fast_test: 180_000, close_test: 360_000, closer_test: 180_000 };
  assert.deepEqual(nearLimit(results, (name) => limits[name]).map((result) => result.test), ["closer_test", "close_test"]);
});

test("the receipt leads with the verdict and lists steps, failures and error counts", () => {
  const failures = [classifyFailure("red_test", [false, false], ledger)];
  const text = renderReceipt({
    title: "Gate shard: tests 1-2 on abcd1234",
    head: "abcd1234",
    box: "4 vCPU Xeon, 15 GB",
    godot: "Godot_v4.7.2",
    scale: 1.5,
    window: "non-bot list 1 to 2 of 1087",
    steps: { "import-1": { exit: 0, seconds: 90 }, chunk00: { exit: 1, seconds: 400 } },
    results: [{ test: "a_test", ok: true, seconds: 12 }, { test: "red_test", ok: false, seconds: 30 }],
    failures,
    counts: errorCounts(""),
    slow: [],
    verdict: shardVerdict(failures),
    startedAt: "2026-11-09T20:00:00Z",
    finishedAt: "2026-11-09T20:40:00Z",
  });
  assert.match(text, /^# Gate shard: tests 1-2 on abcd1234\n\n\*\*Verdict: PASS, no new red \(1 carried on the ledger\)\.\*\* 1 of 2 passed on the first run\./);
  assert.match(text, /Time limits scaled by 1\.5/);
  assert.match(text, /\| chunk00 \| 1 \| 400 s \|/);
  assert.match(text, /\| red_test \| 0\/2 pass alone \| carried \| red, owner coordinator, review 2026-11-23: pin off by 2 s \|/);
});

test("changed paths sort into game files, test files and the rest", () => {
  assert.deepEqual(
    sortChanges([
      "sketches/core-loop/src/core/flow.gd",
      "sketches/core-loop/tests/kest_kit_test.gd",
      "sketches/core-loop/tests/support/probe.gd",
      "sketches/core-loop/DESIGN-NOTES.md",
      "scripts/sketch-smoke.mjs",
    ]),
    {
      game: ["sketches/core-loop/src/core/flow.gd"],
      tests: ["tests/kest_kit_test.gd", "tests/support/probe.gd"],
      other: ["sketches/core-loop/DESIGN-NOTES.md", "scripts/sketch-smoke.mjs"],
    },
  );
});

test("a changed test file reruns every test that reaches it, however many steps away", () => {
  const index = indexFromFiles(
    new Map(
      Object.entries({
        "tests/kest_kit_test.gd": 'const Probe = preload("res://tests/support/probe.gd")\n',
        "tests/kest_set_piece_test.gd": 'extends "res://tests/kest_kit_test.gd"\n',
        "tests/kest_finale_test.gd": 'extends "res://tests/kest_set_piece_test.gd"\n',
        "tests/support/probe.gd": "extends RefCounted\n",
        "tests/other_test.gd": "extends SceneTree\n",
        "src/uses_probe.gd": 'const Probe = preload("res://tests/support/probe.gd")\n',
      }),
    ),
  );
  const direct = testsToRerun(index, ["tests/kest_kit_test.gd"]);
  assert.deepEqual([...direct.keys()].sort(), ["tests/kest_finale_test.gd", "tests/kest_kit_test.gd", "tests/kest_set_piece_test.gd"]);
  assert.equal(direct.get("tests/kest_kit_test.gd"), "changed");
  assert.equal(direct.get("tests/kest_set_piece_test.gd"), "reaches tests/kest_kit_test.gd");
  const support = testsToRerun(index, ["tests/support/probe.gd"]);
  assert.deepEqual([...support.keys()].sort(), ["tests/kest_finale_test.gd", "tests/kest_kit_test.gd", "tests/kest_set_piece_test.gd"]);
  assert.equal(testsToRerun(index, ["tests/deleted_test.gd"]).size, 0);
});

test("a test is placed in the list its shard reads", () => {
  const lists = { tests: ["a_test", "b_test"], bots: ["bot_a_test"] };
  assert.equal(place("b_test", lists), "non-bot list 2");
  assert.equal(place("bot_a_test", lists), "bot list 1");
  assert.equal(place("gone_test", lists), "not in a gate list");
});

const plan = (rows) => ["## Gate-side", "| Check | Verdict |", "| --- | --- |", "| placeholders | PASS |", "", "## Tally", "| Shard | Verdict |", "| --- | --- |", ...rows, "", "## Verdict"].join("\n");
const full = [
  "| tests 1-5 | PASS. Receipt tests-1-5.md |",
  "| tests 6-10 | PASS. Receipt tests-6-10.md |",
  "| bots 1 | PASS 5/5. Receipt bots-1.md |",
  "| bots 2 | PASS 5/5. Receipt bots-2.md |",
  "| bands A | PASS. Receipt bands-A.md |",
  "| bands B | PASS. Receipt bands-B.md |",
  "| bands C | PASS. Receipt bands-C.md |",
  "| red team cautious | CLEAR. Receipt red-team-cautious.md |",
];
const counts = { testCount: 10, botCount: 10 };

test("only the shard tables of a plan are read", () => {
  const rows = tallyRows(plan(full));
  assert.equal(rows.length, 8);
  assert.deepEqual(rows[0], { shard: "tests 1-5", verdict: "PASS. Receipt tests-1-5.md", line: 9 });
  assert.deepEqual(expectedShards(10), ["bots 1", "bots 2", "bands A", "bands B", "bands C", "red team"]);
});

test("a full tally passes", () => {
  assert.deepEqual(checkTally(tallyRows(plan(full)), counts), []);
});

test("the wave gate needs every test window and the scoped row, and lets a release shard wait", () => {
  const wave = { ...counts, scope: "wave" };
  const tests = ["| tests 1-5 | PASS. Receipt tests-1-5.md |", "| tests 6-10 | PASS. Receipt tests-6-10.md |"];
  const scoped = "| scoped | PASS 4/4: world1_run_test, posture_bands_flume_test, bot_run_end_test, session_test. Receipt scoped.md |";
  assert.deepEqual(checkTally(tallyRows(plan([...tests, scoped])), wave), [], "no row at all for bots, bands or the red team");
  const deferred = ["| bands B | DEFERRED to the release gate; last read PASS on f165fbb4, receipt w36-f165fbb4/bands-B |", "| red team | DEFERRED to the release gate; last read CLEAR on f165fbb4, receipt w36-f165fbb4/redteam |"];
  assert.deepEqual(checkTally(tallyRows(plan([...tests, scoped, ...deferred])), wave), []);
  assert.match(checkTally(tallyRows(plan(tests)), wave).join("\n"), /no row for "scoped"/);
  assert.match(checkTally(tallyRows(plan([tests[0], scoped])), wave).join("\n"), /non-bot tests 6 to 10 have no row/);
  assert.match(checkTally(tallyRows(plan([...tests, "| scoped | RED world1_run_test fell. Receipt scoped.md |"])), wave).join("\n"), /"scoped" does not open with PASS/);
  assert.match(checkTally(tallyRows(plan([...tests, scoped, "| bands A | RED posture_bands_flume_test. Receipt bands-A.md |"])), wave).join("\n"), /"bands A" does not open with PASS/, "a release shard that was read and is red still blocks");
  assert.match(checkTally(tallyRows(plan([...tests, scoped, "| bands B | DEFERRED to the release gate |"])), wave).join("\n"), /"bands B" names no receipt/);
  assert.match(checkTally(tallyRows(plan(["| tests 1-5 | DEFERRED. Receipt old.md |", tests[1], scoped])), wave).join("\n"), /"tests 1-5" does not open with PASS/, "a test window is never deferred");
  assert.match(checkTally(tallyRows(plan([...tests, "| scoped | DEFERRED. Receipt old.md |"])), wave).join("\n"), /"scoped" does not open with PASS/, "the scoped row is never deferred");
});

test("the release gate defers nothing", () => {
  const rows = full.map((row) => (row.startsWith("| bands B") ? "| bands B | DEFERRED to the release gate; last read PASS, receipt bands-B.md |" : row));
  assert.match(checkTally(tallyRows(plan(rows)), counts).join("\n"), /"bands B" does not open with PASS/);
  assert.match(checkTally(tallyRows(plan(full.slice(0, 5))), counts).join("\n"), /no row for "bands B"/);
  assert.equal(isDeferred("**DEFERRED** to the release gate"), true);
  assert.equal(isDeferred("PASS, deferred nothing"), false);
});

test("an empty verdict, a missing shard, a gap in the tests and a missing receipt are each named", () => {
  const rows = [...full];
  rows[1] = "| tests 7-10 | PASS. Receipt tests-7-10.md |";
  rows[2] = "| bots 1 | |";
  rows[4] = "| bands A | PASS, identical to the last head |";
  rows.pop();
  const problems = checkTally(tallyRows(plan(rows)), counts).join("\n");
  assert.match(problems, /"bots 1" has an empty verdict/);
  assert.match(problems, /"bands A" names no receipt/);
  assert.match(problems, /no row for "red team"/);
  assert.match(problems, /non-bot tests 6 to 6 have no row/);
});

test("a red row blocks until a newer row for the same shard is not red", () => {
  const red = [...full];
  red[4] = "| bands A | RED, one new deterministic red. Receipt bands-A.md |";
  assert.match(checkTally(tallyRows(plan(red)), counts).join("\n"), /"bands A" does not open with PASS/);
  const reread = plan(red) + "\n\n## Head moved\n| Shard | Verdict |\n| --- | --- |\n| bands A | PASS after the re-pin. Receipt bands-A-2.md |\n";
  assert.deepEqual(checkTally(tallyRows(reread), counts), []);
});

test("a verdict passes only when it opens with PASS or CLEAR, however a red is worded", () => {
  for (const verdict of ["PASS, no new red. Receipt a.md", "**PASS** 5/5", "Verdict: PASS, no new red", "**Verdict: PASS, no new red (1 carried on the ledger).**", "CLEAR. 0 blockers"]) assert.equal(isPass(verdict), true, verdict);
  for (const verdict of ["RED 4/5", "NEW RED posture_bands_test", "Verdict: RED: 1 new red (foo_test). receipt gate/x", "red: foo_test failed alone, receipt gate/y", "1 new red", "FAIL", "passed mostly", "see the receipt"]) assert.equal(isPass(verdict), false, verdict);
  const worded = [...full];
  worded[0] = "| tests 1-5 | red: foo_test failed alone, receipt gate/y |";
  assert.match(checkTally(tallyRows(plan(worded)), counts).join("\n"), /"tests 1-5" does not open with PASS/);
});

test("\"receipts\" counts as naming a receipt", () => {
  const rows = [...full];
  rows[4] = "| bands A | PASS. receipts in gate/z |";
  assert.deepEqual(checkTally(tallyRows(plan(rows)), counts), []);
});

test("the tally refuses a plan that gates another head", () => {
  assert.equal(planHead("/mnt/project-files/gate/w32-58a6de62-gate-plan.md"), "58a6de62");
  assert.equal(planHead("notes.md"), null);
  const rows = tallyRows(plan(full));
  assert.deepEqual(checkTally(rows, { ...counts, planHead: "58a6de62", head: "58a6de6200f5d9e63434d3bfe5435606968ecf94" }), []);
  assert.match(checkTally(rows, { ...counts, planHead: "58a6de62", head: "8180ec6cc0000000000000000000000000000000" }).join("\n"), /the plan gates 58a6de62 and this checkout is at 8180ec6c/);
});

test("tests on the weekly list hold a promotion until a sweep within a week is on the tally", () => {
  const today = new Date(Date.UTC(2026, 10, 20));
  const weekly = { ...counts, weeklyCount: 64, today };
  const withRow = (verdict) => tallyRows(plan([...full, `| weekly sweep | ${verdict} |`]));
  assert.deepEqual(checkTally(tallyRows(plan(full)), { ...counts, today }), [], "no list, no hold");
  assert.match(checkTally(tallyRows(plan(full)), weekly).join("\n"), /no row for "weekly sweep": 64 tests are on the weekly list/);
  assert.deepEqual(checkTally(withRow("PASS 2026-11-13 on 3997358b, tests 55/55, bots 9/9. Receipts weekly-tests/receipt.md"), weekly), [], "seven days old still counts");
  assert.match(checkTally(withRow("PASS 2026-11-12 on 3997358b. Receipt weekly.md"), weekly).join("\n"), /the weekly sweep last ran on 2026-11-12, 8 days ago; a promotion needs one within 7 days/);
  assert.match(checkTally(withRow("PASS on 3997358b. Receipt weekly.md"), weekly).join("\n"), /"weekly sweep" gives no day the sweep ran/);
  assert.match(checkTally(withRow("PASS 2026-13-45. Receipt weekly.md"), weekly).join("\n"), /gives no day the sweep ran/);
  assert.match(checkTally(withRow("PASS 2026-11-21. Receipt weekly.md"), weekly).join("\n"), /is dated 2026-11-21, which is after today/);
  assert.match(checkTally(withRow("RED 2026-11-19, mind_boss_test failed alone. Receipt weekly.md"), weekly).join("\n"), /"weekly sweep" does not open with PASS/);
  assert.match(checkTally(withRow("PASS 2026-11-19, 64 of 64"), weekly).join("\n"), /"weekly sweep" names no receipt/);
  // The newest row wins, as for every shard: an old sweep is cured by a new row, not by editing the old one.
  const rerun = plan([...full, "| weekly sweep | PASS 2026-11-01. Receipt old.md |"]) + "\n\n## Sweep rerun\n| Shard | Verdict |\n| --- | --- |\n| weekly sweep | PASS 2026-11-20. Receipt new.md |\n";
  assert.deepEqual(checkTally(tallyRows(rerun), weekly), []);
  assert.equal(WEEKLY_MAX_DAYS, 7);
  assert.deepEqual(checkWeeklySweep([], { weeklyCount: 0 }), []);
});

// A sketch folder with these test files, and the weekly list beside it when one is given.
function listsOf(files) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "gate-weekly-"));
  mkdirSync(path.join(dir, "tests"));
  for (const [name, text] of Object.entries(files)) writeFileSync(path.join(dir, name === "WEEKLY.tsv" ? "." : "tests", name), text);
  return gateLists(dir, path.join(dir, "WEEKLY.tsv"));
}
const weeklyHead = WEEKLY_HEADER.join("\t") + "\n";
const plainTest = "extends SceneTree\n";
const botTest = "# smoke: bots\nextends SceneTree\n";

test("the weekly list takes its tests out of the promotion lists and keeps them in their own", () => {
  const lists = listsOf({
    "a_test.gd": plainTest,
    "b_test.gd": plainTest,
    "bot_c_test.gd": botTest,
    "bot_d_test.gd": botTest,
    "WEEKLY.tsv": weeklyHead + "b_test\tworld2\tparked by ruling at\tworlds 2 and 3 reopen\nbot_d_test\told-map-bots\tthe launched game does not use the map\tnever\n",
  });
  assert.deepEqual(lists, { tests: ["a_test"], bots: ["bot_c_test"], weekly: { tests: ["b_test"], bots: ["bot_d_test"] } });
});

test("with no weekly list the promotion lists hold every test", () => {
  assert.deepEqual(listsOf({ "a_test.gd": plainTest, "bot_c_test.gd": botTest }), { tests: ["a_test"], bots: ["bot_c_test"], weekly: { tests: [], bots: [] } });
});

test("a weekly list that does not parse, or names a missing test, is an error and never a silent skip", () => {
  assert.throws(() => listsOf({ "a_test.gd": plainTest, "WEEKLY.tsv": "test\tgroup\n" }), /does not parse: line 1/);
  assert.throws(() => listsOf({ "a_test.gd": plainTest, "WEEKLY.tsv": "" }), /does not parse: line 1/);
  assert.throws(() => listsOf({ "a_test.gd": plainTest, "WEEKLY.tsv": weeklyHead + "gone_test\tworld2\twhy\twhen\n" }), /names tests that do not exist: gone_test/);
  const { problems } = parseWeekly(weeklyHead + "a_test\tworld2\t\twhen\ntests/b_test.gd\tworld2\twhy\twhen\na_ok\tg\tr\tw\na_ok\tg\tr\tw\n");
  assert.equal(problems.length, 3);
  assert.match(problems.join("\n"), /line 2: a row needs/);
  assert.match(problems.join("\n"), /line 3: "tests\/b_test.gd" must be the test's base name/);
  assert.match(problems.join("\n"), /line 5: a_ok is listed twice/);
});

test("the docs check fails a weekly list that does not parse or names a test with no file", () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "weekly-check-"));
  try {
    assert.deepEqual(checkWeekly(root), []);
    mkdirSync(path.join(root, "project-guide/handoff"), { recursive: true });
    mkdirSync(path.join(root, "sketches/core-loop/tests"), { recursive: true });
    writeFileSync(path.join(root, "sketches/core-loop/tests/a_test.gd"), plainTest);
    writeFileSync(path.join(root, WEEKLY_FILE), weeklyHead + "a_test\tworld2\twhy\twhen\n");
    assert.deepEqual(checkWeekly(root), []);
    writeFileSync(path.join(root, WEEKLY_FILE), weeklyHead + "a_test\tworld2\twhy\twhen\ngone_test\tworld2\twhy\twhen\nb_test\tworld2\t\twhen\n");
    const findings = checkWeekly(root);
    assert.deepEqual(findings.map((finding) => [finding.level, finding.line]), [["failure", 4], ["failure", 3]]);
    assert.match(findings[1].message, /gone_test has no file/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a shard reads its import the way the runner does: a signal is the engine's crash, a script error is not clean", () => {
  assert.equal(importOutcome(0, "[ DONE ] reimport\n"), "ok");
  assert.equal(importOutcome("SIGSEGV", "[   0% ] reimport | NotoSans-Bold.ttf\n"), "engine crash");
  assert.equal(importOutcome("SIGABRT", "malloc(): smallbin double linked list corrupted\n"), "engine crash");
  assert.equal(importOutcome(139, ""), "engine crash");
  assert.equal(importOutcome("SIGKILL", ""), "failed", "the shard's own time limit is not an engine crash");
  assert.equal(importOutcome(0, "SCRIPT ERROR: Parse Error: Could not preload resource file\n"), "script errors");
});

const timedOut = { timedOut: true, failLines: 0 };
const loaded = (load, extra = {}) => ({ ...timedOut, load, ...extra });
const evidence = (...runs) => ({ threads: 32, runs });

test("a solo rerun gets a lock folder of its own inside the shard's out folder", () => {
  const out = mkdtempSync(path.join(os.tmpdir(), "gate-solo-"));
  try {
    const first = { SCRAPKEEP_LOCK_DIR: "/shared/locks", SMOKE_SLOTS: "3" };
    const solo = soloEnvironment(first, out, "solo-logs-1");
    assert.equal(solo.SCRAPKEEP_LOCK_DIR, path.join(out, "solo-locks"));
    assert.notEqual(solo.SCRAPKEEP_LOCK_DIR, first.SCRAPKEEP_LOCK_DIR);
    assert.equal(solo.SMOKE_SLOTS, "1");
    assert.equal(solo.SMOKE_LOG_DIR, path.join(out, "solo-logs-1"));
    assert.ok(existsSync(solo.SCRAPKEEP_LOCK_DIR));
    assert.equal(first.SCRAPKEEP_LOCK_DIR, "/shared/locks");
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});

test("two time-outs at load 58 on 32 threads with no failing check are suspect-load, never a new red (10 Nov)", () => {
  const runs = evidence(loaded(58), loaded(61));
  const call = classifyFailure("music_params_test", [false, false], ledger, runs);
  assert.equal(call.call, "suspect-load");
  assert.equal(classifyFailure("music_params_test", [false, false], ledger).call, "new-red", "without the evidence it is the old call");
  assert.equal(classifyFailure("fresh_test", [false, false], ledger, evidence(loaded(58, { failLines: 1 }), loaded(58))).call, "new-red");
  assert.equal(classifyFailure("fresh_test", [false, false], ledger, evidence(loaded(58), { timedOut: false, failLines: 0, load: 58 })).call, "new-red", "a failure that is not a time-out is not the machine's");
  assert.equal(classifyFailure("fresh_test", [false, false], ledger, evidence(loaded(16), loaded(3))).call, "new-red", "load at the line (32 x 0.5) is not over it");
  assert.equal(classifyFailure("fresh_test", [false, false], ledger, evidence(loaded(5), loaded(17))).call, "suspect-load", "one run over the line is enough");
  assert.equal(classifyFailure("fresh_test", [true, true], ledger, evidence(loaded(99), loaded(99))).call, "new-flake");
  assert.equal(classifyFailure("red_test", [false, false], ledger, runs).call, "carried");
  assert.equal(classifyFailure("wobble_test", [true, false], ledger, evidence(loaded(5), loaded(90))).call, "carried");
});

test("a listed flake whose every solo run timed out under load is suspect-load, not a mismatch", () => {
  const four = evidence(loaded(70), loaded(70), loaded(70), loaded(70));
  assert.equal(classifyFailure("wobble_test", [false, false, false, false], ledger).call, "mismatch");
  assert.equal(classifyFailure("wobble_test", [false, false, false, false], ledger, four).call, "suspect-load");
  assert.equal(classifyFailure("wobble_test", [false, false], ledger, evidence(loaded(70, { failLines: 2 }), loaded(70))).call, "mismatch");
});

test("suspect-load blocks as INCONCLUSIVE, and a real red beside it keeps the shard RED and names both", () => {
  const suspect = classifyFailure("music_params_test", [false, false], ledger, evidence(loaded(58), loaded(58)));
  const red = classifyFailure("broken_test", [false, false], ledger);
  const flake = classifyFailure("fresh_test", [true, true], ledger);
  assert.deepEqual(shardVerdict([suspect, flake]), { ok: false, inconclusive: true, line: 'INCONCLUSIVE: 1 time-out(s) under load (music_params_test); rerun alone on a quiet machine with "node scripts/gate/shard.mjs retime"' });
  assert.deepEqual(shardVerdict([suspect, red]), { ok: false, line: "RED: 1 new red (broken_test); 1 time-out(s) under load (music_params_test)" });
});

test("a plan row that opens with INCONCLUSIVE is not a pass", () => {
  assert.equal(isPass('INCONCLUSIVE: 1 time-out(s) under load (a_test); rerun alone. Receipt x.md'), false);
  assert.equal(isPass("**Verdict: INCONCLUSIVE: 2 time-out(s) under load (a_test)**"), false);
});

test("the receipt shows the load of every step, and a dash for a step saved before load was recorded", () => {
  const failures = [];
  const text = renderReceipt({
    title: "Gate shard: tests 1-2 on abcd1234",
    head: "abcd1234",
    box: "32 vCPU, 64 GB",
    threads: 32,
    godot: "Godot_v4.7.2",
    scale: 1,
    window: "non-bot list 1 to 2 of 1087",
    steps: { "import-1": { exit: 0, seconds: 90 }, chunk00: { exit: 0, seconds: 400, load_start: 12.5, load_end: 58 } },
    results: [{ test: "a_test", ok: true, seconds: 12 }],
    failures,
    counts: errorCounts(""),
    slow: [],
    verdict: shardVerdict(failures),
    startedAt: "2026-11-10T20:00:00Z",
    finishedAt: "2026-11-10T20:40:00Z",
  });
  assert.match(text, /\| Step \| Exit \| Wall \| Load \|/);
  assert.match(text, /\| chunk00 \| 0 \| 400 s \| 12\.5 to 58 \|/);
  assert.match(text, /\| import-1 \| 0 \| 90 s \| - \|/);
  assert.match(text, /read against 32 threads/);
});

// retime with a fake runner, load reader and sleep: no engine starts.
async function retimeWith({ tests = ["a_test", "b_test"], runs = 2, outcome, loads = [3], known = ["a_test", "b_test"] }) {
  const out = mkdtempSync(path.join(os.tmpdir(), "gate-retime-"));
  const ran = [];
  let sleeps = 0;
  let reads = 0;
  const load = () => loads[Math.min(reads++, loads.length - 1)];
  const sleep = async () => {
    sleeps++;
  };
  const runSolo = async (test, run) => {
    ran.push(`${test}#${run}`);
    return { exit: 0, seconds: 100, ok: true, timedOut: false, failLines: 0, ...outcome?.(test, run) };
  };
  const logged = [];
  const log = console.log;
  console.log = (line) => logged.push(line);
  try {
    const code = await retime({ tests, known, runs, out, maxLoad: 8, threads: 32, bots: false, head: "abcd1234ef", load, sleep, runSolo, refuse: () => {} });
    const receipt = existsSync(path.join(out, "receipt.md")) ? readFileSync(path.join(out, "receipt.md"), "utf8") : null;
    return { code, ran, sleeps, receipt, logged };
  } finally {
    console.log = log;
    rmSync(out, { recursive: true, force: true });
  }
}

test("retime: every run passing alone is PASS and exit 0, with one table row per run", async () => {
  const result = await retimeWith({});
  assert.equal(result.code, 0);
  assert.deepEqual(result.ran, ["a_test#1", "a_test#2", "b_test#1", "b_test#2"]);
  assert.match(result.receipt, /^# Gate retime: a_test, b_test on abcd1234\n\n\*\*Verdict: PASS: every run passed alone on a quiet machine\.\*\*/);
  assert.match(result.receipt, /\| a_test \| 1 \| 0 \| 100 s \| 3 \| no \| 0 \|/);
  assert.equal(result.receipt.split("\n").filter((line) => /^\| [ab]_test /.test(line)).length, 4);
});

test("retime: a failing check alone is RED and exit 1", async () => {
  const result = await retimeWith({ outcome: (test, run) => (test === "b_test" && run === 2 ? { ok: false, exit: 1, failLines: 1 } : {}) });
  assert.equal(result.code, 1);
  assert.match(result.receipt, /Verdict: RED: b_test failed a check alone\./);
  const crash = await retimeWith({ outcome: (test) => (test === "a_test" ? { ok: false, exit: 134 } : {}) });
  assert.equal(crash.code, 1, "a failure that is not a time-out is red");
});

test("retime: time-outs only are INCONCLUSIVE and exit 2", async () => {
  const result = await retimeWith({ outcome: (test, run) => (test === "a_test" && run === 1 ? { ok: false, exit: "null", timedOut: true } : {}) });
  assert.equal(result.code, 2);
  assert.match(result.receipt, /Verdict: INCONCLUSIVE: 1 time-out\(s\) even on a quiet machine \(a_test\)/);
  assert.match(result.receipt, /\| a_test \| 1 \| null \| 100 s \| 3 \| yes \| 0 \|/);
});

test("retime: an unknown test name stops before any run", async () => {
  const out = mkdtempSync(path.join(os.tmpdir(), "gate-retime-"));
  let ran = 0;
  try {
    await assert.rejects(
      retime({ tests: ["a_test", "no_such_test"], known: ["a_test"], runs: 1, out, maxLoad: 8, threads: 32, bots: false, head: "abcd1234ef", load: () => 0, sleep: async () => {}, runSolo: async () => ran++, refuse: () => {} }),
      /not in the non-bot gate lists: no_such_test/,
    );
    assert.equal(ran, 0);
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});

test("retime waits while the load is above the line, and gives up with exit 2 when the machine never goes quiet", async () => {
  const waits = await retimeWith({ tests: ["a_test"], runs: 1, loads: [40, 30, 9, 3, 3] });
  assert.equal(waits.code, 0);
  assert.equal(waits.sleeps, 3);
  const never = await retimeWith({ tests: ["a_test"], runs: 1, loads: [55] });
  assert.equal(never.code, 2);
  assert.deepEqual(never.ran, []);
  assert.equal(never.sleeps, 90);
  assert.equal(never.receipt, null);
  assert.match(never.logged.join("\n"), /the machine never went quiet/);
});

test("a run window is FIRST-LAST or test names joined by commas, in the list's order", () => {
  const list = ["a_test", "b_test", "c_test", "d_test"];
  assert.deepEqual(windowNames("2-3", list), { names: ["b_test", "c_test"], label: "2 to 3 of 4 (b_test to c_test)" });
  assert.deepEqual(windowNames("d_test,b_test.gd", list), { names: ["b_test", "d_test"], label: "named, 2 of 4: b_test, d_test" });
  assert.throws(() => windowNames("b_test,x_test", list), /not on this list: x_test/);
  assert.throws(() => windowNames("", list), /FIRST-LAST/);
  assert.throws(() => windowNames("0-5", list), /does not fit/);
});

test("a named window draws on the promotion list and the weekly names; a weekly run on the weekly list alone", () => {
  const lists = { tests: ["b_test"], bots: ["c_bot_test"], weekly: { tests: ["a_test"], bots: ["a_bot_test"] } };
  assert.deepEqual(namedPool(lists, { bots: true, weekly: false }), ["a_bot_test", "c_bot_test"]);
  assert.deepEqual(namedPool(lists, { bots: false, weekly: false }), ["a_test", "b_test"]);
  assert.deepEqual(namedPool(lists, { bots: true, weekly: true }), ["a_bot_test"]);
  assert.equal(testName(" tests/x_test.gd "), "x_test");
});
