// The known-failing ledger: project-guide/handoff/KNOWN-FAILING.tsv.
//
// A promotion may carry a red test only while that test has a row here with a
// cause, an owner and a review date (ruling bq, Andrew, 9 Nov 2026). A red row
// also names the checks it covers, and carries no other failing check of that
// test (ruling dx, Andrew, 15 Nov 2026; `uncoveredChecks`). At a
// promotion the row never changes how a test runs or whether a run fails; it
// changes what a failure means. In the fast lane a flake row buys more head
// runs before the test is the pull request's red (scripts/sketch-fast.mjs).
//
//   node scripts/known-failing.mjs --check            structure only
//   node scripts/known-failing.mjs --promotion        structure, and no row past its review date
//   node scripts/known-failing.mjs --judge a_test b_test
//   node scripts/known-failing.mjs --print            the ledger as a Markdown table
//
// --check is a stage of `npm run check:docs`. --promotion is a step of the
// promotion gate (scripts/gate/tally.mjs runs it). --judge is how a gate shard
// sorts the tests that failed solo: a listed test is carried, an unlisted one
// is a new red, and it exits 1 when any name is unlisted.

import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { weeklyNames } from "./gate/weekly.mjs";

export const LEDGER_FILE = "project-guide/handoff/KNOWN-FAILING.tsv";
export const LEDGER_HEADER = ["test", "kind", "cause", "owner", "added", "review"];
export const TESTS_DIRECTORY = "sketches/core-loop/tests";
// red: fails alone, on the head and on main, with the check the cause names.
// flake: passes alone and fails under load, or fails some runs alone.
export const KINDS = ["red", "flake"];
// The seventh column (ruling dx, 15 Nov 2026): the checks a red row covers, as the test prints them between
// the square brackets of a "-> FAIL" line, joined by " ;; ". A star stands for any text ("class * builds").
// TIME-OUT covers a run killed at its limit, and ERROR-LINE a run that fails with no failing check (an ERROR
// line at exit). A flake row has "-": the listed flakes keep their allowance until each is fixed.
export const CHECK_COLUMN = "check";
export const CHECK_SEPARATOR = ";;";
export const TIME_OUT = "TIME-OUT";
export const ERROR_LINE = "ERROR-LINE";

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

// "res://tests/a_test.gd", "a_test.gd" and "a_test" all name the same row.
export function testName(text) {
  return String(text)
    .trim()
    .replace(/^.*\//, "")
    .replace(/\.gd$/, "");
}

export function parseLedger(text) {
  const lines = (text || "").split("\n").map((line) => line.replace(/\r$/, ""));
  const problems = [];
  const rows = [];
  const header = lines[0] ?? "";
  const columns = [...LEDGER_HEADER, CHECK_COLUMN];
  const hasChecks = header === columns.join("\t");
  if (!hasChecks && header !== LEDGER_HEADER.join("\t")) {
    problems.push({ line: 1, message: `the header must be: ${columns.join(" TAB ")}` });
    return { rows, problems, hasChecks };
  }
  const width = hasChecks ? columns.length : LEDGER_HEADER.length;
  const seen = new Map();
  lines.slice(1).forEach((line, index) => {
    const number = index + 2;
    if (line.trim() === "") return;
    const cells = line.split("\t").map((cell) => cell.trim());
    if (cells.length !== width || cells.some((cell) => cell === "")) {
      problems.push({ line: number, message: `a row needs ${(hasChecks ? columns : LEDGER_HEADER).join(", ")}, with no cell empty` });
      return;
    }
    const [test, kind, cause, owner, added, review, check] = cells;
    const named = hasChecks && check !== "-" ? check.split(CHECK_SEPARATOR).map((part) => part.trim()).filter(Boolean) : null;
    const row = { test, kind, cause, owner, added, review, checks: kind === "red" ? named : null, line: number };
    if (hasChecks && kind === "red" && !named?.length) problems.push({ line: number, message: `a red row names the check it covers in the ${CHECK_COLUMN} column (ruling dx), not "-"` });
    if (hasChecks && kind === "flake" && check !== "-") problems.push({ line: number, message: `a flake row has "-" in the ${CHECK_COLUMN} column` });
    if (test !== testName(test)) problems.push({ line: number, message: `"${test}" must be the test's base name, with no folder and no .gd` });
    if (!KINDS.includes(kind)) problems.push({ line: number, message: `kind "${kind}" must be one of: ${KINDS.join(", ")}` });
    for (const [label, value] of [["added", added], ["review", review]]) {
      if (!ISO_DATE.test(value)) problems.push({ line: number, message: `${label} "${value}" must be a date written YYYY-MM-DD` });
    }
    if (ISO_DATE.test(added) && ISO_DATE.test(review) && review < added) {
      problems.push({ line: number, message: `the review date ${review} is before the row was added (${added})` });
    }
    if (seen.has(test)) problems.push({ line: number, message: `${test} already has a row on line ${seen.get(test)}` });
    else seen.set(test, number);
    rows.push(row);
  });
  return { rows, problems, hasChecks };
}

const checkPattern = (named) => new RegExp("^" + named.split("*").map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join(".*") + "$");

// What a failed run did that its red row does not cover. `failed` is { labels, timedOut }: the labels of the
// run's failing checks, and whether it was killed at its limit. A run with no failing check failed some other
// way: TIME-OUT when it was killed, ERROR-LINE otherwise. A row with no named checks (a flake row, or a ledger
// without the column) covers by test name only, so nothing is uncovered.
export function uncoveredChecks(row, { labels = [], timedOut = false } = {}) {
  if (!row?.checks) return [];
  const patterns = row.checks.map(checkPattern);
  const did = labels.length > 0 ? labels : [timedOut ? TIME_OUT : ERROR_LINE];
  return did.filter((label) => !patterns.some((pattern) => pattern.test(label)));
}

// Rows whose review date has passed. The day itself is still in time.
export function pastReview(rows, today) {
  return rows.filter((row) => ISO_DATE.test(row.review) && row.review < today);
}

export function pastReviewLine(row, today) {
  return `${row.test} is past its review date (${row.review}, today ${today}; owner ${row.owner}): fix the test and remove the row, or have the coordinator re-date it. Until then it holds the promotion`;
}

// Sorts failed test names into carried rows and new reds.
export function judgeFailures(names, rows) {
  const byTest = new Map(rows.map((row) => [row.test, row]));
  const listed = [];
  const unlisted = [];
  for (const name of [...new Set(names.map(testName))]) {
    if (byTest.has(name)) listed.push(byTest.get(name));
    else unlisted.push(name);
  }
  return { listed, unlisted };
}

export function judgeLines({ listed, unlisted }) {
  const lines = [];
  for (const row of listed) {
    lines.push(`CARRIED ${row.test} (${row.kind}; owner ${row.owner}; review ${row.review}): ${row.cause}`);
  }
  for (const name of unlisted) {
    lines.push(`NEW ${name}: no row in ${LEDGER_FILE}. A deterministic red blocks and goes to the pull request's owner (ruling ai)`);
  }
  if (listed.length > 0) {
    lines.push("A carried red must fail the check its row names. A different failing check in the same test is a new red.");
  }
  return lines;
}

export function renderLedger(rows) {
  const checks = rows.some((row) => row.checks);
  const lines = [`| Test | Kind | Cause | Owner | Added | Review |${checks ? " Check |" : ""}`, `| --- | --- | --- | --- | --- | --- |${checks ? " --- |" : ""}`];
  for (const row of rows) {
    lines.push(`| ${row.test} | ${row.kind} | ${row.cause.replaceAll("|", "\\|")} | ${row.owner} | ${row.added} | ${row.review} |${checks ? ` ${(row.checks ?? ["-"]).join(` ${CHECK_SEPARATOR} `).replaceAll("|", "\\|")} |` : ""}`);
  }
  return lines.join("\n");
}

export async function readLedger(root) {
  const file = path.join(root, LEDGER_FILE);
  if (!existsSync(file)) return null;
  return parseLedger(await readFile(file, "utf8"));
}

// Findings in the shape check-docs prints: { level, file, line, message }.
// With `promotion`, a row past its review date is a failure; without it, a note.
// `notRun` names the tests a promotion does not run (the weekly list, ruling ca):
// their rows are judged by the weekly sweep, so a late one is a note here.
// `requireChecks` is what the real callers pass: the checked-in ledger must have the check column.
export async function checkLedger(root, { today = new Date().toISOString().slice(0, 10), promotion = false, notRun = new Set(), requireChecks = false } = {}) {
  const ledger = await readLedger(root);
  if (ledger === null) return [];
  const findings = ledger.problems.map((problem) => ({ level: "failure", file: LEDGER_FILE, line: problem.line, message: problem.message }));
  if (requireChecks && !ledger.hasChecks && ledger.problems.length === 0) {
    findings.push({ level: "failure", file: LEDGER_FILE, line: 1, message: `the ledger has no ${CHECK_COLUMN} column: every red row must name the check it covers (ruling dx)` });
  }
  const tests = path.join(root, TESTS_DIRECTORY);
  if (existsSync(tests)) {
    for (const row of ledger.rows) {
      if (!existsSync(path.join(tests, row.test + ".gd"))) {
        findings.push({ level: "failure", file: LEDGER_FILE, line: row.line, message: `${row.test} has no file ${TESTS_DIRECTORY}/${row.test}.gd; remove the row or fix the name` });
      }
    }
  }
  for (const row of pastReview(ledger.rows, today)) {
    const weekly = notRun.has(row.test);
    findings.push({ level: promotion && !weekly ? "failure" : "info", file: LEDGER_FILE, line: row.line, message: weekly ? `${row.test} is past its review date (${row.review}) and is on the weekly list, so it does not hold the promotion; the weekly sweep judges it` : pastReviewLine(row, today) });
  }
  return findings;
}

function parseArguments(argv) {
  const options = { root: process.cwd(), mode: null, names: [], today: undefined };
  for (let index = 0; index < argv.length; index++) {
    const argument = argv[index];
    if (["--check", "--promotion", "--judge", "--print"].includes(argument)) {
      if (options.mode) throw new Error("pass one of --check, --promotion, --judge or --print");
      options.mode = argument.slice(2);
    } else if (argument === "--root" && argv[index + 1]) options.root = path.resolve(argv[++index]);
    else if (argument === "--today" && argv[index + 1]) options.today = argv[++index];
    else if (options.mode === "judge" && !argument.startsWith("--")) options.names.push(argument);
    else throw new Error(`unknown argument ${argument}`);
  }
  if (!options.mode) throw new Error("pass one of --check, --promotion, --judge or --print");
  if (options.today !== undefined && !ISO_DATE.test(options.today)) throw new Error("--today takes a date written YYYY-MM-DD");
  return options;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const ledger = await readLedger(options.root);
  if (ledger === null) throw new Error(`${LEDGER_FILE} not found under ${options.root}`);
  if (options.mode === "print") {
    console.log(renderLedger(ledger.rows));
    return 0;
  }
  if (options.mode === "judge") {
    if (ledger.problems.length > 0) throw new Error(`${LEDGER_FILE} does not parse; run --check first`);
    const verdict = judgeFailures(options.names, ledger.rows);
    for (const line of judgeLines(verdict)) console.log(line);
    console.log(`known-failing judge: ${verdict.listed.length} carried, ${verdict.unlisted.length} new.`);
    return verdict.unlisted.length > 0 ? 1 : 0;
  }
  const notRun = options.mode === "promotion" ? weeklyNames(options.root) : new Set();
  const findings = await checkLedger(options.root, { today: options.today, promotion: options.mode === "promotion", notRun, requireChecks: true });
  for (const finding of findings) {
    console.log(`${finding.level.toUpperCase()} known-failing ${finding.file}:${finding.line} ${finding.message}`);
  }
  const failures = findings.filter((finding) => finding.level === "failure").length;
  const kinds = KINDS.map((kind) => `${ledger.rows.filter((row) => row.kind === kind).length} ${kind}`).join(", ");
  console.log(`known-failing ${failures ? "fail" : "pass"}: ${ledger.rows.length} rows (${kinds}), ${failures} failures.`);
  return failures ? 1 : 0;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    process.exitCode = await main();
  } catch (error) {
    console.error("known-failing: " + (error?.message ?? error));
    process.exitCode = 2;
  }
}
