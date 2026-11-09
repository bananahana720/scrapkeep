import assert from "node:assert/strict";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import path from "node:path";

import { indexFromFiles } from "../sketch-fast.mjs";
import { parseLedger } from "../known-failing.mjs";
import { place, sortChanges, testsToRerun } from "./carry.mjs";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import { WEEKLY_HEADER, chunks, classifyFailure, errorCounts, gateLists, nearLimit, numbered, parseSmokeLog, parseWeekly, parseWindow, renderReceipt, shardVerdict } from "./shard.mjs";
import { checkTally, expectedShards, isPass, planHead, tallyRows } from "./tally.mjs";
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
  assert.ok(lists.bots.length >= 30);
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

test("a shard is red only for a new red, and its verdict names what it carried", () => {
  const carried = classifyFailure("red_test", [false, false], ledger);
  const flake = classifyFailure("fresh_test", [true, true], ledger);
  const red = classifyFailure("broken_test", [false, false], ledger);
  assert.deepEqual(shardVerdict([]), { ok: true, line: "PASS, no new red" });
  assert.deepEqual(shardVerdict([carried, flake]), { ok: true, line: "PASS, no new red (1 carried on the ledger, 1 new load flake to list)" });
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
