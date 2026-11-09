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
  const root = fixture(ledger(row("a_test")));
  try {
    const run = (mode) => spawnSync(process.execPath, [script, "--root", root, mode, "--today", "2026-12-01"], { encoding: "utf8" });
    assert.equal(run("--check").status, 0);
    assert.equal(run("--promotion").status, 1);
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
