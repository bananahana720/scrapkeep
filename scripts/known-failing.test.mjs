import assert from "node:assert/strict";
import { test } from "node:test";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  LEDGER_FILE,
  LEDGER_HEADER,
  TESTS_DIRECTORY,
  checkLedger,
  judgeFailures,
  judgeLines,
  parseLedger,
  pastReview,
  renderLedger,
  testName,
  uncoveredChecks,
} from "./known-failing.mjs";

const script = fileURLToPath(new URL("./known-failing.mjs", import.meta.url));
const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const header = LEDGER_HEADER.join("\t");
const row = (test, kind = "red", review = "2026-11-23", added = "2026-11-09") =>
  [test, kind, "why it fails", "testing lane", added, review].join("\t");
const ledger = (...rows) => [header, ...rows].join("\n") + "\n";

function fixture(text, tests = ["a_test", "b_test"]) {
  const root = mkdtempSync(path.join(os.tmpdir(), "known-failing-"));
  mkdirSync(path.join(root, path.dirname(LEDGER_FILE)), { recursive: true });
  mkdirSync(path.join(root, TESTS_DIRECTORY), { recursive: true });
  for (const name of tests) writeFileSync(path.join(root, TESTS_DIRECTORY, name + ".gd"), "extends SceneTree\n");
  writeFileSync(path.join(root, LEDGER_FILE), text);
  return root;
}

test("a test is named the same way with or without its folder and extension", () => {
  assert.equal(testName("res://tests/a_test.gd"), "a_test");
  assert.equal(testName("a_test.gd"), "a_test");
  assert.equal(testName(" a_test "), "a_test");
});

test("a well-formed ledger parses into rows with their line numbers", () => {
  const { rows, problems } = parseLedger(ledger(row("a_test"), "", row("b_test", "flake")));
  assert.deepEqual(problems, []);
  assert.deepEqual(rows.map((entry) => [entry.test, entry.kind, entry.line]), [["a_test", "red", 2], ["b_test", "flake", 4]]);
});

test("a wrong header stops the parse and says what the header must be", () => {
  const { rows, problems } = parseLedger("test\towner\treason\n" + row("a_test") + "\n");
  assert.deepEqual(rows, []);
  assert.match(problems[0].message, /header must be: test TAB kind TAB cause TAB owner TAB added TAB review/);
});

test("an empty cell, an unknown kind, a bad date, a path and a duplicate are each named", () => {
  const { problems } = parseLedger(
    ledger(
      "a_test\tred\t\ttesting lane\t2026-11-09\t2026-11-23",
      row("b_test", "cloud"),
      row("c_test", "red", "after the sitting"),
      row("tests/d_test.gd"),
      row("e_test", "red", "2026-11-01"),
      row("f_test"),
      row("f_test"),
    ),
  );
  const text = problems.map((problem) => `${problem.line}: ${problem.message}`).join("\n");
  assert.match(text, /2: a row needs/);
  assert.match(text, /3: kind "cloud" must be one of: red, flake/);
  assert.match(text, /4: review "after the sitting" must be a date/);
  assert.match(text, /5: "tests\/d_test\.gd" must be the test's base name/);
  assert.match(text, /6: the review date 2026-11-01 is before the row was added/);
  assert.match(text, /8: f_test already has a row on line 7/);
});

test("a row is in time on its review date and past it the day after", () => {
  const { rows } = parseLedger(ledger(row("a_test")));
  assert.deepEqual(pastReview(rows, "2026-11-23"), []);
  assert.equal(pastReview(rows, "2026-11-24").length, 1);
});

test("a row past its date is a note in the docs check and a failure at a promotion", async () => {
  const root = fixture(ledger(row("a_test"), row("b_test", "flake", "2026-12-01")));
  try {
    assert.deepEqual(await checkLedger(root, { today: "2026-11-20" }), []);
    const note = await checkLedger(root, { today: "2026-11-24" });
    assert.deepEqual(note.map((finding) => finding.level), ["info"]);
    const hold = await checkLedger(root, { today: "2026-11-24", promotion: true });
    assert.deepEqual(hold.map((finding) => finding.level), ["failure"]);
    assert.match(hold[0].message, /a_test is past its review date .* holds the promotion/);
    const weekly = await checkLedger(root, { today: "2026-11-24", promotion: true, notRun: new Set(["a_test"]) });
    assert.deepEqual(weekly.map((finding) => finding.level), ["info"]);
    assert.match(weekly[0].message, /on the weekly list, so it does not hold the promotion/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a row for a test with no file fails the check", async () => {
  const root = fixture(ledger(row("gone_test")));
  try {
    const findings = await checkLedger(root, { today: "2026-11-10" });
    assert.equal(findings.length, 1);
    assert.match(findings[0].message, /gone_test has no file/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a root with no ledger has nothing to check", async () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "known-failing-"));
  try {
    assert.deepEqual(await checkLedger(root), []);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("failed tests sort into carried rows and new reds, once each", () => {
  const { rows } = parseLedger(ledger(row("a_test"), row("b_test", "flake")));
  const verdict = judgeFailures(["res://tests/a_test.gd", "a_test", "kest_set_piece_test"], rows);
  assert.deepEqual(verdict.listed.map((entry) => entry.test), ["a_test"]);
  assert.deepEqual(verdict.unlisted, ["kest_set_piece_test"]);
  const lines = judgeLines(verdict);
  assert.match(lines[0], /^CARRIED a_test \(red; owner testing lane; review 2026-11-23\): why it fails$/);
  assert.match(lines[1], /^NEW kest_set_piece_test: no row/);
  assert.match(lines[2], /different failing check in the same test is a new red/);
});

test("the judge command exits 1 only when a failed test has no row", () => {
  const root = fixture(ledger(row("a_test")));
  try {
    const run = (...names) => spawnSync(process.execPath, [script, "--root", root, "--judge", ...names], { encoding: "utf8" });
    assert.equal(run("a_test").status, 0);
    const mixed = run("a_test", "b_test");
    assert.equal(mixed.status, 1);
    assert.match(mixed.stdout, /1 carried, 1 new/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("the promotion command holds on a past date and the check command does not", () => {
  const root = fixture(checked(row("a_test") + "\tpin within 2 s"));
  const old = fixture(ledger(row("a_test")));
  try {
    const run = (mode, at = root) => spawnSync(process.execPath, [script, "--root", at, mode, "--today", "2026-12-01"], { encoding: "utf8" });
    assert.equal(run("--check").status, 0);
    assert.equal(run("--promotion").status, 1);
    // The command checks the real ledger, which must have the check column.
    assert.equal(run("--check", old).status, 1);
    rmSync(old, { recursive: true, force: true });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("the ledger prints as a Markdown table", () => {
  const { rows } = parseLedger(ledger(row("a_test")));
  assert.equal(renderLedger(rows).split("\n")[2], "| a_test | red | why it fails | testing lane | 2026-11-09 | 2026-11-23 |");
});

test("the checked-in ledger parses, names real tests and gives every row a date", async () => {
  const { rows, problems } = parseLedger(readFileSync(path.join(repoRoot, LEDGER_FILE), "utf8"));
  assert.deepEqual(problems, []);
  assert.ok(rows.length > 0);
  const findings = await checkLedger(repoRoot, { today: "2026-11-09" });
  assert.deepEqual(findings, []);
});

// ---- the check a red row names (ruling dx) ----

const checked = (...rows) => [header + "\tcheck", ...rows].join("\n") + "\n";

test("with a check column, a red row must name its check and a flake row must not", () => {
  const good = parseLedger(checked(row("a_test") + "\tpin within 2 s ;; TIME-OUT", row("b_test", "flake") + "\t-"));
  assert.deepEqual(good.problems, []);
  assert.deepEqual(good.rows[0].checks, ["pin within 2 s", "TIME-OUT"]);
  assert.equal(good.rows[1].checks, null);
  const bad = parseLedger(checked(row("a_test") + "\t-", row("b_test", "flake") + "\tsome check", row("c_test")));
  assert.match(bad.problems[0].message, /a red row names the check it covers/);
  assert.match(bad.problems[1].message, /a flake row has "-"/);
  assert.match(bad.problems[2].message, /a row needs/);
});

test("a ledger without the check column still parses, and the docs check fails it", async () => {
  const text = ledger(row("a_test"));
  assert.deepEqual(parseLedger(text).problems, []);
  assert.equal(parseLedger(text).rows[0].checks, null);
  const root = fixture(text);
  try {
    const findings = await checkLedger(root, { today: "2026-11-10", requireChecks: true });
    assert.equal((await checkLedger(root, { today: "2026-11-10" })).length, 0);
    assert.equal(findings.filter((finding) => finding.level === "failure" && /check column/.test(finding.message)).length, 1);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a red row covers only the checks it names", () => {
  const [rowA] = parseLedger(checked(row("a_test") + "\tstage 5: more pockets ;; class * builds")).rows;
  assert.deepEqual(uncoveredChecks(rowA, { labels: ["stage 5: more pockets"] }), []);
  assert.deepEqual(uncoveredChecks(rowA, { labels: ["class 5 builds", "class 0 builds"] }), []);
  // The case that hid for a wave: a second failing check in a listed test (stage_modifier_test, wave 41).
  assert.deepEqual(uncoveredChecks(rowA, { labels: ["stage 5: more pockets", "stage 1: draw matches"] }), ["stage 1: draw matches"]);
  // A star is the only wildcard; every other character is literal.
  assert.deepEqual(uncoveredChecks(rowA, { labels: ["stage 5. more pockets", "xclass 5 builds"] }), ["stage 5. more pockets", "xclass 5 builds"]);
  // A time-out and a run that fails with no failing check are covered only by their own words.
  assert.deepEqual(uncoveredChecks(rowA, { labels: [], timedOut: true }), ["TIME-OUT"]);
  assert.deepEqual(uncoveredChecks(rowA, { labels: [] }), ["ERROR-LINE"]);
  const [rowB] = parseLedger(checked(row("b_test") + "\tTIME-OUT ;; ERROR-LINE")).rows;
  assert.deepEqual(uncoveredChecks(rowB, { labels: [], timedOut: true }), []);
  assert.deepEqual(uncoveredChecks(rowB, { labels: [] }), []);
  assert.deepEqual(uncoveredChecks(rowB, { labels: ["any check"] }), ["any check"]);
  // A row from a ledger with no check column covers nothing by name, so nothing is called uncovered.
  assert.deepEqual(uncoveredChecks(parseLedger(ledger(row("a_test"))).rows[0], { labels: ["x"] }), []);
});

test("a kill or an error line beside a named check still needs its own word on the row (PR 1051 review)", () => {
  const [rowA] = parseLedger(checked(row("a_test") + "\tpin within 2 s")).rows;
  // bot_fairness_test, wave 40 gate: the named check failed, then a SCRIPT ERROR, then the runner killed it.
  assert.deepEqual(uncoveredChecks(rowA, { labels: ["pin within 2 s"], timedOut: true }), ["TIME-OUT"]);
  assert.deepEqual(uncoveredChecks(rowA, { labels: ["pin within 2 s"], errorLine: true }), ["ERROR-LINE"]);
  assert.deepEqual(uncoveredChecks(rowA, { labels: ["pin within 2 s"], timedOut: true, errorLine: true }), ["TIME-OUT", "ERROR-LINE"]);
  const [rowB] = parseLedger(checked(row("b_test") + "\tpin within 2 s ;; TIME-OUT ;; ERROR-LINE")).rows;
  assert.deepEqual(uncoveredChecks(rowB, { labels: ["pin within 2 s"], timedOut: true, errorLine: true }), []);
});

test("a star never stands for a kill or an error line, and a check of stars alone is refused", () => {
  const [wide] = parseLedger(checked(row("a_test") + "\tclass * builds ;; T*")).rows;
  assert.deepEqual(uncoveredChecks(wide, { labels: ["class 1 builds"], timedOut: true, errorLine: true }), ["TIME-OUT", "ERROR-LINE"]);
  const bad = parseLedger(checked(row("a_test") + "\t*", row("b_test") + "\tpin ;; * *"));
  assert.equal(bad.problems.length, 2);
  assert.match(bad.problems[0].message, /a check of stars alone covers every check/);
});
