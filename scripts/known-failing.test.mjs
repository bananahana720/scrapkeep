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
  NEW_AND_KNOWN_REDS,
  ONLY_KNOWN_REDS,
  TESTS_DIRECTORY,
  checkLedger,
  judgeFailures,
  judgeLines,
  mainRedLedger,
  parseLedger,
  pastReview,
  readMainReds,
  renderLedger,
  runFailure,
  testName,
  uncoveredChecks,
} from "./known-failing.mjs";
import { git } from "./lib/git.mjs";

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
  for (const name of tests)
    writeFileSync(path.join(root, TESTS_DIRECTORY, name + ".gd"), "extends SceneTree\n");
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
  assert.deepEqual(
    rows.map((entry) => [entry.test, entry.kind, entry.line]),
    [
      ["a_test", "red", 2],
      ["b_test", "flake", 4],
    ],
  );
});

test("a wrong header stops the parse and says what the header must be", () => {
  const { rows, problems } = parseLedger("test\towner\treason\n" + row("a_test") + "\n");
  assert.deepEqual(rows, []);
  assert.match(
    problems[0].message,
    /header must be: test TAB kind TAB cause TAB owner TAB added TAB review/,
  );
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
    assert.deepEqual(
      note.map((finding) => finding.level),
      ["info"],
    );
    const hold = await checkLedger(root, { today: "2026-11-24", promotion: true });
    assert.deepEqual(
      hold.map((finding) => finding.level),
      ["failure"],
    );
    assert.match(hold[0].message, /a_test is past its review date .* holds the promotion/);
    const weekly = await checkLedger(root, {
      today: "2026-11-24",
      promotion: true,
      notRun: new Set(["a_test"]),
    });
    assert.deepEqual(
      weekly.map((finding) => finding.level),
      ["info"],
    );
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
  assert.deepEqual(
    verdict.listed.map((entry) => entry.test),
    ["a_test"],
  );
  assert.deepEqual(verdict.unlisted, ["kest_set_piece_test"]);
  const lines = judgeLines(verdict);
  assert.match(
    lines[0],
    /^CARRIED a_test \(red; owner testing lane; review 2026-11-23\): why it fails$/,
  );
  assert.match(lines[1], /^NEW kest_set_piece_test: no row/);
  assert.match(lines[2], /different failing check in the same test is a new red/);
});

test("the judge command exits 1 only when a failed test has no row", () => {
  const root = fixture(ledger(row("a_test")));
  try {
    const run = (...names) =>
      spawnSync(process.execPath, [script, "--root", root, "--judge", ...names], {
        encoding: "utf8",
      });
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
    const run = (mode, at = root) =>
      spawnSync(process.execPath, [script, "--root", at, mode, "--today", "2026-12-01"], {
        encoding: "utf8",
      });
    assert.equal(run("--check").status, 0);
    assert.equal(run("--promotion").status, 1);
    assert.equal(run("--check", old).status, 1);
    rmSync(old, { recursive: true, force: true });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("the ledger prints as a Markdown table", () => {
  const { rows } = parseLedger(ledger(row("a_test")));
  assert.equal(
    renderLedger(rows).split("\n")[2],
    "| a_test | red | why it fails | testing lane | 2026-11-09 | 2026-11-23 |",
  );
});

test("the checked-in ledger parses, names real tests and gives every row a date", async () => {
  const { rows, problems } = parseLedger(readFileSync(path.join(repoRoot, LEDGER_FILE), "utf8"));
  assert.deepEqual(problems, []);
  assert.ok(rows.length > 0);
  const findings = await checkLedger(repoRoot, { today: "2026-11-09" });
  assert.deepEqual(findings, []);
});

const checked = (...rows) => [header + "\tcheck", ...rows].join("\n") + "\n";

test("with a check column, a red row must name its check and a flake row must not", () => {
  const good = parseLedger(
    checked(row("a_test") + "\tpin within 2 s ;; TIME-OUT", row("b_test", "flake") + "\t-"),
  );
  assert.deepEqual(good.problems, []);
  assert.deepEqual(good.rows[0].checks, ["pin within 2 s", "TIME-OUT"]);
  assert.equal(good.rows[1].checks, null);
  const bad = parseLedger(
    checked(row("a_test") + "\t-", row("b_test", "flake") + "\tsome check", row("c_test")),
  );
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
    assert.equal(
      findings.filter(
        (finding) => finding.level === "failure" && /check column/.test(finding.message),
      ).length,
      1,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a red row covers only the checks it names", () => {
  const [rowA] = parseLedger(
    checked(row("a_test") + "\tstage 5: more pockets ;; class * builds"),
  ).rows;
  assert.deepEqual(uncoveredChecks(rowA, { labels: ["stage 5: more pockets"] }), []);
  assert.deepEqual(uncoveredChecks(rowA, { labels: ["class 5 builds", "class 0 builds"] }), []);
  assert.deepEqual(
    uncoveredChecks(rowA, { labels: ["stage 5: more pockets", "stage 1: draw matches"] }),
    ["stage 1: draw matches"],
  );
  assert.deepEqual(
    uncoveredChecks(rowA, { labels: ["stage 5. more pockets", "xclass 5 builds"] }),
    ["stage 5. more pockets", "xclass 5 builds"],
  );
  assert.deepEqual(uncoveredChecks(rowA, { labels: [], timedOut: true }), ["TIME-OUT"]);
  assert.deepEqual(uncoveredChecks(rowA, { labels: [] }), ["ERROR-LINE"]);
  const [rowB] = parseLedger(checked(row("b_test") + "\tTIME-OUT ;; ERROR-LINE")).rows;
  assert.deepEqual(uncoveredChecks(rowB, { labels: [], timedOut: true }), []);
  assert.deepEqual(uncoveredChecks(rowB, { labels: [] }), []);
  assert.deepEqual(uncoveredChecks(rowB, { labels: ["any check"] }), ["any check"]);
  assert.deepEqual(
    uncoveredChecks(parseLedger(ledger(row("a_test"))).rows[0], { labels: ["x"] }),
    [],
  );
});

test("a kill or an error line beside a named check still needs its own word on the row (PR 1051 review)", () => {
  const [rowA] = parseLedger(checked(row("a_test") + "\tpin within 2 s")).rows;
  assert.deepEqual(uncoveredChecks(rowA, { labels: ["pin within 2 s"], timedOut: true }), [
    "TIME-OUT",
  ]);
  assert.deepEqual(uncoveredChecks(rowA, { labels: ["pin within 2 s"], errorLine: true }), [
    "ERROR-LINE",
  ]);
  assert.deepEqual(
    uncoveredChecks(rowA, { labels: ["pin within 2 s"], timedOut: true, errorLine: true }),
    ["TIME-OUT", "ERROR-LINE"],
  );
  const [rowB] = parseLedger(
    checked(row("b_test") + "\tpin within 2 s ;; TIME-OUT ;; ERROR-LINE"),
  ).rows;
  assert.deepEqual(
    uncoveredChecks(rowB, { labels: ["pin within 2 s"], timedOut: true, errorLine: true }),
    [],
  );
});

test("a star never stands for a kill or an error line, and a check of stars alone is refused", () => {
  const [wide] = parseLedger(checked(row("a_test") + "\tclass * builds ;; T*")).rows;
  assert.deepEqual(
    uncoveredChecks(wide, { labels: ["class 1 builds"], timedOut: true, errorLine: true }),
    ["TIME-OUT", "ERROR-LINE"],
  );
  const bad = parseLedger(checked(row("a_test") + "\t*", row("b_test") + "\tpin ;; * *"));
  assert.equal(bad.problems.length, 2);
  assert.match(bad.problems[0].message, /a check of stars alone covers every check/);
});

test("the checked-in ledger has the check column, and every named check is text its test can print", () => {
  const { rows, hasChecks } = parseLedger(readFileSync(path.join(repoRoot, LEDGER_FILE), "utf8"));
  assert.equal(hasChecks, true);
  const red = rows.filter((entry) => entry.kind === "red");
  assert.ok(red.length > 0);
  for (const entry of red) {
    const source = readFileSync(
      path.join(repoRoot, "sketches/core-loop/tests", entry.test + ".gd"),
      "utf8",
    );
    for (const named of entry.checks.filter(
      (check) => check !== "TIME-OUT" && check !== "ERROR-LINE",
    )) {
      const piece = named
        .split(/\d+|\*|: /)
        .map((part) => part.trim())
        .sort((a, b) => b.length - a.length)[0];
      assert.ok(
        piece.length >= 6 && source.includes(piece),
        `${entry.test}: no check "${named}" in its source`,
      );
    }
  }
  const tree = red.find((entry) => entry.test === "tree_play_test");
  if (tree)
    assert.deepEqual(
      tree.checks,
      [0, 1, 2, 3, 4, 5].map((index) => `class ${index} builds`),
    );
});

const checkedHeader = [...LEDGER_HEADER, "check"].join("\t");
const mainRow = (
  test,
  cause,
  check = "a check ;; another check",
  kind = "red",
  added = "2026-11-28",
) => [test, kind, cause, "coordinator", added, "2026-12-05", check].join("\t");
const mainLedger = (...rows) => [checkedHeader, ...rows].join("\n") + "\n";
const ON_MAIN = "red on main at 0d422144b on 2026-11-28: why it fails";

test("a row red on main may name no star, ERROR-LINE or TIME-OUT, and is told to write the exact check", () => {
  const plain = parseLedger(
    mainLedger(
      mainRow("a_test", "plain red", "class * builds ;; ERROR-LINE ;; TIME-OUT"),
      mainRow("b_test", ON_MAIN, "stage 1: draw matches ;; class 2 builds"),
    ),
  );
  assert.deepEqual(plain.problems, [], "a row not red on main keeps all three");
  for (const [check, said] of [
    ["class * builds", /may not name "class \* builds": a star matches other checks/],
    ["a check ;; *x", /may not name "\*x": a star matches other checks/],
    ["a check ;; ERROR-LINE", /may not name "ERROR-LINE": ERROR-LINE lets any error line/],
    ["TIME-OUT ;; a check", /may not name "TIME-OUT": TIME-OUT can never apply/],
  ]) {
    const { problems } = parseLedger(mainLedger(mainRow("a_test", ON_MAIN, check)));
    assert.equal(problems.length, 1, check);
    assert.equal(problems[0].line, 2, check);
    assert.match(problems[0].message, said, check);
    assert.match(
      problems[0].message,
      /; write the exact check as the test prints it between the square brackets of its -> FAIL line$/,
      check,
    );
  }
  const all = parseLedger(mainLedger(mainRow("a_test", ON_MAIN, "c* ;; ERROR-LINE ;; TIME-OUT")));
  assert.equal(all.problems.length, 3);
});

test("a red row whose cause starts with the commit and date it was seen red on main is a main red, and a near miss is refused", () => {
  const good = parseLedger(
    mainLedger(mainRow("a_test", ON_MAIN), mainRow("b_test", "red on a stage only")),
  );
  assert.deepEqual(good.problems, []);
  assert.deepEqual(
    good.rows.map((entry) => entry.main),
    [{ commit: "0d422144b", seen: "2026-11-28" }, null],
  );
  for (const [cause, kind, added, message] of [
    [
      "red on main at 0d42 on 2026-11-28: short commit",
      "red",
      "2026-11-28",
      /starts "red on main at/,
    ],
    ["red on main at 0d422144b: no date", "red", "2026-11-28", /starts "red on main at/],
    ["Red on main since yesterday", "red", "2026-11-28", /starts "red on main at/],
    [ON_MAIN, "flake", "2026-11-28", /only a red row can be red on main, not a flake/],
    [ON_MAIN, "red", "2026-11-27", /added \(2026-11-27\) before main was seen red \(2026-11-28\)/],
  ]) {
    const check = kind === "flake" ? "-" : "a check";
    const { problems } = parseLedger(mainLedger(mainRow("a_test", cause, check, kind, added)));
    assert.equal(problems.length, 1, cause);
    assert.match(problems[0].message, message);
  }
});

const TODAY = "2026-11-30";
const COVERED = "stage 1: draw matches";
const redOutput = (labels, { test = "a_test", before = "", verdict = true } = {}) =>
  before +
  labels.map((label) => `[${label}] got 1, want 2 -> FAIL`).join("\n") +
  "\n" +
  (verdict ? `${test}: FAIL (${labels.length} of 9 checks)\n` : "");
const PR_RED = { kind: "pr-red", newChecks: [] };
const redRun = (output, extra = {}, test = "a_test") => ({
  test: `tests/${test}.gd`,
  ok: false,
  exit: 1,
  signal: null,
  killed: false,
  timedOut: false,
  failure: runFailure(test, output, "linux"),
  ...extra,
});
const twice = (run) => [run, { ...run }];

test("runFailure reads a run's failing lines with the gate's reader and finds its FAIL verdict line", () => {
  const output = [
    "[stage 1: draw matches] got 1 -> FAIL",
    "[a check] ok -> PASS",
    "FAIL: the bake was abandoned",
    "ERROR: 1 resources still in use at exit (run with --verbose for details).",
    "a_test: FAIL (2 of 9 checks)",
    "",
  ].join("\n");
  assert.deepEqual(runFailure("tests/a_test.gd", output, "linux"), {
    labels: ["stage 1: draw matches", "unlabelled failing line: FAIL: the bake was abandoned"],
    errorLine: true,
    failVerdict: true,
  });
  assert.equal(runFailure("tests/a_test.gd", output, "darwin").errorLine, false);
  assert.equal(runFailure("tests/b_test.gd", output).failVerdict, false, "another test's verdict");
  assert.equal(runFailure("tests/a_test.gd", "a_test: PASS (9 checks)\n").failVerdict, false);
  for (const bad of [undefined, null, 3, Buffer.from(output)])
    assert.throws(() => runFailure("tests/a_test.gd", bad), TypeError, String(bad));
});

test("a red the ledger lists as red on main is marked only when it ended normally on its verdict line and failed only what its row names", () => {
  const lines = [];
  const { rows } = parseLedger(
    mainLedger(
      mainRow("a_test", ON_MAIN, COVERED),
      mainRow("c_test", "seen red on a stage", "a check"),
    ),
  );
  const ledger = mainRedLedger(rows, { log: (line) => lines.push(line), today: TODAY });

  const good = redRun(redOutput([COVERED]));
  const listed = ledger.settle("tests/a_test.gd", PR_RED, twice(good));
  assert.equal(listed.kind, "main-red");
  assert.match(
    lines.at(-1),
    /^ {2}known red on main: a_test \(.*KNOWN-FAILING\.tsv line 2; owner coordinator; check stage 1: draw matches\): red on main at 0d422144b on 2026-11-28/,
  );
  assert.equal(
    ledger.settle("tests/a_test.gd", PR_RED, twice(redRun(redOutput([COVERED]), { exit: 0 }))).kind,
    "main-red",
    "a test that prints its FAIL verdict and exits 0",
  );

  assert.equal(
    ledger.settle(
      "tests/b_test.gd",
      PR_RED,
      twice(redRun(redOutput(["x"], { test: "b_test" }), {}, "b_test")),
    ).kind,
    "pr-red",
    "unlisted",
  );
  assert.equal(
    ledger.settle(
      "tests/c_test.gd",
      PR_RED,
      twice(redRun(redOutput(["a check"], { test: "c_test" }), {}, "c_test")),
    ).kind,
    "pr-red",
    "a red row not seen on main",
  );
  for (const [why, bad, said] of [
    [
      "a new failing check",
      redRun(redOutput([COVERED, "a new check"])),
      /does not name: a new check/,
    ],
    [
      "a FAIL line with no -> FAIL",
      redRun(redOutput([COVERED], { before: "FAIL: the bake was abandoned\n" })),
      /does not name: unlabelled failing line: FAIL: the bake was abandoned/,
    ],
    [
      "an error line",
      redRun(redOutput([COVERED], { before: "SCRIPT ERROR: Invalid call\n" })),
      /does not name: ERROR-LINE/,
    ],
    [
      "no FAIL verdict line",
      redRun(redOutput([COVERED], { verdict: false })),
      /ended without its FAIL verdict line/,
    ],
    [
      "a crash signal",
      redRun(redOutput([COVERED]), { exit: null, signal: "SIGSEGV" }),
      /stopped \(SIGSEGV\)/,
    ],
    ["a crash exit code", redRun(redOutput([COVERED]), { exit: 139 }), /exit code 139/],
    [
      "a kill by the lane",
      redRun(redOutput([COVERED]), { exit: null, killed: true }),
      /stopped \(killed\)/,
    ],
    [
      "a time-out",
      redRun(redOutput([COVERED]), { exit: null, timedOut: true }),
      /stopped \(time-out\)/,
    ],
    ["no failing check", redRun(redOutput([])), /no failing check was printed/],
    ["no failure record", { ok: false, exit: 1 }, /no failure record/],
    ["no run object", undefined, /no failure record/],
  ]) {
    for (const [shape, runs, index] of [
      ["the first run bad and the rerun listed", [bad, good], "1 of 2"],
      ["the first run listed and the rerun bad", [good, bad], "2 of 2"],
      ["a batch run and an alone run listed, the rerun bad", [good, good, bad], "3 of 3"],
    ]) {
      assert.equal(
        ledger.settle("tests/a_test.gd", PR_RED, runs).kind,
        "pr-red",
        `${why}: ${shape}`,
      );
      assert.ok(
        lines
          .at(-1)
          .startsWith(
            `  a_test is listed as red on main, but counts as this change's red: run ${index}: `,
          ),
        `${why}: ${shape}: ${lines.at(-1)}`,
      );
      assert.match(lines.at(-1), said, `${why}: ${shape}`);
    }
  }
  for (const runs of [undefined, null, [], good])
    assert.equal(ledger.settle("tests/a_test.gd", PR_RED, runs).kind, "pr-red", String(runs));
  assert.match(lines.at(-1), /counts as this change's red: no run of it reached the rule$/);
  for (const kind of ["flaky", "base-red", "stopped"])
    assert.equal(ledger.settle("tests/a_test.gd", { ...PR_RED, kind }, twice(good)).kind, kind);

  ledger.passed("tests/a_test.gd");
  ledger.passed("tests/a_test.gd");
  ledger.passed("tests/b_test.gd");
  assert.match(
    lines.at(-1),
    /^ {2}a_test passed, but .* lists it as red on main at 0d422144b: remove its row once main is green$/,
  );
  assert.throws(() => mainRedLedger(undefined), TypeError);
});

test("a row past its review date marks nothing and the run says so", () => {
  const lines = [];
  const { rows } = parseLedger(mainLedger(mainRow("a_test", ON_MAIN, COVERED)));
  const ledger = mainRedLedger(rows, { log: (line) => lines.push(line), today: "2026-12-06" });
  assert.equal(
    ledger.settle("tests/a_test.gd", PR_RED, twice(redRun(redOutput([COVERED])))).kind,
    "pr-red",
  );
  assert.match(
    lines.at(-1),
    /a_test is listed as red on main, but counts as this change's red: its row is past its review date \(2026-12-05\)$/,
  );
  assert.equal(
    mainRedLedger(rows, { today: "2026-12-05" }).settle(
      "tests/a_test.gd",
      PR_RED,
      twice(redRun(redOutput([COVERED]))),
    ).kind,
    "main-red",
    "on its review date the row still holds",
  );
});

test("the summary line says whether a failing run's only reds are known reds on main, in a fixed form", () => {
  assert.equal(ONLY_KNOWN_REDS, "sketch:fast fail: only known reds on main");
  assert.equal(NEW_AND_KNOWN_REDS, "sketch:fast fail: new reds");
  const gate = readFileSync(
    path.resolve(fileURLToPath(import.meta.url), "../../project-guide/handoff/GATE.md"),
    "utf8",
  );
  for (const stated of [
    `\`${ONLY_KNOWN_REDS} (<count>): <tests>\``,
    `\`${NEW_AND_KNOWN_REDS} (<count>): <tests>; known reds on main (<count>): <tests>\``,
    "`known`, `new_reds`, `passed`, `line` and `only_known_reds`",
    "`npm run sketch:fast -- --test <name>` without `--base-check`",
    "when every run of the test in the invocation (its first run, in a warm batch or alone, the run alone after a batch, and the rerun) qualifies on its own",
    "an error line anywhere in the batch counts against every red test of it",
    "the ledger check refuses a star, `ERROR-LINE` or `TIME-OUT` in it",
  ])
    assert.ok(gate.includes(stated), `GATE.md states ${stated}`);
  assert.doesNotMatch(gate, /does not fail the job/);
  const { rows } = parseLedger(
    mainLedger(mainRow("a_test", ON_MAIN, COVERED), mainRow("b_test", ON_MAIN, COVERED)),
  );
  const make = () => {
    const ledger = mainRedLedger(rows, { today: TODAY });
    ledger.settle("tests/a_test.gd", PR_RED, twice(redRun(redOutput([COVERED]))));
    ledger.settle(
      "tests/b_test.gd",
      PR_RED,
      twice(redRun(redOutput([COVERED], { test: "b_test" }), {}, "b_test")),
    );
    return ledger;
  };
  assert.deepEqual(make().report(), {
    known: ["tests/a_test.gd", "tests/b_test.gd"],
    new_reds: [],
    passed: [],
    only_known_reds: true,
    line: "sketch:fast fail: only known reds on main (2): tests/a_test.gd tests/b_test.gd",
  });
  assert.deepEqual(make().report(["tests/y_test.gd"]), {
    known: ["tests/a_test.gd", "tests/b_test.gd"],
    new_reds: ["tests/y_test.gd"],
    passed: [],
    only_known_reds: false,
    line: "sketch:fast fail: new reds (1): tests/y_test.gd; known reds on main (2): tests/a_test.gd tests/b_test.gd",
  });
  const lines = [];
  const quiet = mainRedLedger(rows, { log: (line) => lines.push(line), today: TODAY });
  quiet.passed("tests/a_test.gd");
  lines.length = 0;
  assert.deepEqual(quiet.report(["tests/y_test.gd"]), {
    known: [],
    new_reds: ["tests/y_test.gd"],
    passed: ["tests/a_test.gd"],
    only_known_reds: false,
    line: null,
  });
  assert.deepEqual(lines, [
    "listed as red on main but passed here (remove the row once main is green): tests/a_test.gd",
  ]);
  assert.equal(mainRedLedger([]).report().line, null);
  assert.throws(() => mainRedLedger([]).report("tests/y_test.gd"), TypeError);
});

test("a main row in a ledger with no check column covers nothing", () => {
  const { rows } = parseLedger(
    [header, ["a_test", "red", ON_MAIN, "coordinator", "2026-11-28", "2026-12-05"].join("\t")].join(
      "\n",
    ),
  );
  assert.equal(rows[0].main?.commit, "0d422144b");
  assert.equal(
    mainRedLedger(rows, { today: TODAY }).settle(
      "tests/a_test.gd",
      PR_RED,
      twice(redRun(redOutput(["any"]))),
    ).kind,
    "pr-red",
  );
});

test("readMainReds reads the ledger at the base commit, and every red counts when it cannot", () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "known-failing-main-"));
  const run = (...args) =>
    git(
      [
        "-c",
        "user.name=t",
        "-c",
        "user.email=t@example.invalid",
        "-c",
        "commit.gpgsign=false",
        ...args,
      ],
      {
        cwd: root,
      },
    );
  const commitLedger = (text) => {
    mkdirSync(path.join(root, path.dirname(LEDGER_FILE)), { recursive: true });
    writeFileSync(path.join(root, LEDGER_FILE), text);
    run("add", LEDGER_FILE);
    run("commit", "-q", "-m", "ledger");
    return run("rev-parse", "HEAD");
  };
  try {
    run("init", "-q");
    writeFileSync(path.join(root, "README"), "x\n");
    run("add", "README");
    run("commit", "-q", "-m", "no ledger");
    const bare = run("rev-parse", "HEAD");
    const good = commitLedger(
      mainLedger(mainRow("a_test", ON_MAIN), mainRow("b_test", "plain red")),
    );
    const broken = commitLedger("test\towner\n");
    const wide = commitLedger(
      mainLedger(mainRow("a_test", ON_MAIN, "a check ;; ERROR-LINE"), mainRow("b_test", ON_MAIN)),
    );
    const empty = commitLedger("");
    const lines = [];
    const log = (line) => lines.push(line);
    assert.deepEqual(
      readMainReds(good, { cwd: root, log }).map((entry) => entry.test),
      ["a_test"],
    );
    assert.deepEqual(lines, []);
    for (const [ref, why] of [
      [bare, /could not be read at /],
      ["no-such-ref", /could not be read at no-such-ref/],
      [broken, /does not parse \(line 1: the header must be/],
      [wide, /does not parse \(line 2: a row red on main may not name "ERROR-LINE"/],
      [empty, /is empty at /],
    ]) {
      lines.length = 0;
      assert.deepEqual(readMainReds(ref, { cwd: root, log }), [], String(ref));
      assert.equal(lines.length, 1);
      assert.match(lines[0], why);
      assert.match(lines[0], /so every red counts against this change$/);
    }
    assert.deepEqual(readMainReds(good, { cwd: path.join(root, "absent"), log }), []);
    for (const bad of [undefined, "", 7])
      assert.throws(() => readMainReds(bad, { cwd: root }), TypeError);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("the checked-in ledger lists exactly the two tests the coordinator saw red on main at 0d422144b", () => {
  const { rows } = parseLedger(readFileSync(path.join(repoRoot, LEDGER_FILE), "utf8"));
  assert.deepEqual(
    rows.filter((entry) => entry.main).map((entry) => [entry.test, entry.main.commit]),
    [
      ["slice1_patch_and_w1_craft_test", "0d422144b"],
      ["stage_modifier_test", "0d422144b"],
    ],
  );
});
