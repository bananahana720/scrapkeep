import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import path from "node:path";

import { weeklyNames } from "./gate/weekly.mjs";
import { globToRegExp, withoutTeardownNoise } from "./lib/godot-test-runner.mjs";
import { isMain } from "./lib/cli.mjs";
import { gitOptional } from "./lib/git.mjs";

export const LEDGER_FILE = "project-guide/handoff/KNOWN-FAILING.tsv";
export const LEDGER_HEADER = ["test", "kind", "cause", "owner", "added", "review"];
export const TESTS_DIRECTORY = "sketches/core-loop/tests";
export const KINDS = ["red", "flake"];
export const CHECK_COLUMN = "check";
export const CHECK_SEPARATOR = ";;";
export const TIME_OUT = "TIME-OUT";
export const ERROR_LINE = "ERROR-LINE";

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
export const MAIN_RED = /^red on main at ([0-9a-f]{7,40}) on (\d{4}-\d{2}-\d{2}):\s/;
const MAIN_RED_FORM = "red on main at <commit> on <YYYY-MM-DD>: ";

export function testName(text) {
  return String(text).trim().replace(/^.*\//, "").replace(/\.gd$/, "");
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
      problems.push({
        line: number,
        message: `a row needs ${(hasChecks ? columns : LEDGER_HEADER).join(", ")}, with no cell empty`,
      });
      return;
    }
    const [test, kind, cause, owner, added, review, check] = cells;
    const named =
      hasChecks && check !== "-"
        ? check
            .split(CHECK_SEPARATOR)
            .map((part) => part.trim())
            .filter(Boolean)
        : null;
    const onMain = MAIN_RED.exec(cause);
    const row = {
      test,
      kind,
      cause,
      owner,
      added,
      review,
      checks: kind === "red" ? named : null,
      main: kind === "red" && onMain ? { commit: onMain[1], seen: onMain[2] } : null,
      line: number,
    };
    if (/^red on main\b/i.test(cause) && !onMain)
      problems.push({
        line: number,
        message: `a cause that says the test is red on main starts "${MAIN_RED_FORM}"`,
      });
    if (onMain && kind !== "red")
      problems.push({ line: number, message: `only a red row can be red on main, not a ${kind}` });
    if (onMain && ISO_DATE.test(added) && onMain[2] > added)
      problems.push({
        line: number,
        message: `the row was added (${added}) before main was seen red (${onMain[2]})`,
      });
    if (hasChecks && kind === "red" && !named?.length)
      problems.push({
        line: number,
        message: `a red row names the check it covers in the ${CHECK_COLUMN} column (ruling dx), not "-"`,
      });
    if (kind === "red" && named?.some((part) => /^[*\s]+$/.test(part)))
      problems.push({
        line: number,
        message: `a check of stars alone covers every check of the test; name the check (ruling dx)`,
      });
    if (hasChecks && kind === "flake" && check !== "-")
      problems.push({ line: number, message: `a flake row has "-" in the ${CHECK_COLUMN} column` });
    if (test !== testName(test))
      problems.push({
        line: number,
        message: `"${test}" must be the test's base name, with no folder and no .gd`,
      });
    if (!KINDS.includes(kind))
      problems.push({
        line: number,
        message: `kind "${kind}" must be one of: ${KINDS.join(", ")}`,
      });
    for (const [label, value] of [
      ["added", added],
      ["review", review],
    ]) {
      if (!ISO_DATE.test(value))
        problems.push({
          line: number,
          message: `${label} "${value}" must be a date written YYYY-MM-DD`,
        });
    }
    if (ISO_DATE.test(added) && ISO_DATE.test(review) && review < added) {
      problems.push({
        line: number,
        message: `the review date ${review} is before the row was added (${added})`,
      });
    }
    if (seen.has(test))
      problems.push({
        line: number,
        message: `${test} already has a row on line ${seen.get(test)}`,
      });
    else seen.set(test, number);
    rows.push(row);
  });
  return { rows, problems, hasChecks };
}

const RESERVED = [TIME_OUT, ERROR_LINE];
const checkPattern = (named) => globToRegExp(named);

export function uncoveredChecks(row, { labels = [], timedOut = false, errorLine = false } = {}) {
  if (!row?.checks) return [];
  const patterns = row.checks.filter((named) => !RESERVED.includes(named)).map(checkPattern);
  const words = [
    ...(timedOut ? [TIME_OUT] : []),
    ...(errorLine || (labels.length === 0 && !timedOut) ? [ERROR_LINE] : []),
  ];
  return [
    ...labels.filter((label) => !patterns.some((pattern) => pattern.test(label))),
    ...words.filter((word) => !row.checks.includes(word)),
  ];
}

export function pastReview(rows, today) {
  return rows.filter((row) => ISO_DATE.test(row.review) && row.review < today);
}

export function pastReviewLine(row, today) {
  return `${row.test} is past its review date (${row.review}, today ${today}; owner ${row.owner}): fix the test and remove the row, or have the coordinator re-date it. Until then it holds the promotion`;
}

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
    lines.push(
      `CARRIED ${row.test} (${row.kind}; owner ${row.owner}; review ${row.review}): ${row.cause}`,
    );
  }
  for (const name of unlisted) {
    lines.push(
      `NEW ${name}: no row in ${LEDGER_FILE}. A deterministic red blocks and goes to the pull request's owner (ruling ai)`,
    );
  }
  if (listed.length > 0) {
    lines.push(
      "A carried red must fail the check its row names. A different failing check in the same test is a new red.",
    );
  }
  return lines;
}

export function readMainReds(ref, { cwd, log = () => {} } = {}) {
  if (typeof ref !== "string" || ref === "")
    throw new TypeError("readMainReds(ref): ref must name a commit");
  const text = gitOptional(["show", `${ref}:${LEDGER_FILE}`], { cwd, trim: false });
  const unread = (why) => {
    log(
      `known red on main: ${LEDGER_FILE} ${why} at ${ref}, so every red counts against this change`,
    );
    return [];
  };
  if (text === null) return unread("could not be read");
  if (text.trim() === "") return unread("is empty");
  const { rows, problems } = parseLedger(text);
  if (problems.length > 0)
    return unread(`does not parse (line ${problems[0].line}: ${problems[0].message})`);
  return rows.filter((row) => row.main);
}

export function mainRedLedger(rows, { log = () => {}, platform = process.platform } = {}) {
  if (!Array.isArray(rows)) throw new TypeError("mainRedLedger(rows): rows must be an array");
  const listed = new Map(
    rows.filter((row) => row.main && row.checks?.length > 0).map((row) => [row.test, row]),
  );
  const known = [];
  const passed = [];
  return {
    passed(test) {
      const row = listed.get(testName(test));
      if (!row || passed.includes(row.test)) return;
      passed.push(row.test);
      log(
        `  ${row.test} passed, but ${LEDGER_FILE} lists it as red on main at ${row.main.commit}: remove its row once main is green`,
      );
    },
    settle(test, verdict) {
      const row = listed.get(testName(test));
      if (!row || verdict.kind !== "pr-red") return verdict;
      const run = verdict.rerun;
      if (typeof run?.output !== "string") return verdict;
      const unnamed = uncoveredChecks(row, {
        labels: run.checks ?? [],
        timedOut: run.timedOut === true,
        errorLine: /^(?:SCRIPT ERROR|ERROR)\b/m.test(withoutTeardownNoise(run.output, platform)),
      });
      if (unnamed.length > 0) {
        log(
          `  ${row.test} is red on main, but fails what its row does not name: ${unnamed.join("; ")}; the row covers ${row.checks.join(` ${CHECK_SEPARATOR} `)}`,
        );
        return verdict;
      }
      known.push(row.test);
      log(
        `  known red on main: ${row.test} (${LEDGER_FILE} line ${row.line}; owner ${row.owner}; check ${row.checks.join(` ${CHECK_SEPARATOR} `)}): ${row.cause}`,
      );
      return { ...verdict, kind: "main-red" };
    },
    report() {
      if (known.length > 0)
        log(`known red on main (listed in ${LEDGER_FILE}; not this change): ${known.join(", ")}`);
      if (passed.length > 0)
        log(
          `listed as red on main but passed here (remove the row once main is green): ${passed.join(", ")}`,
        );
      return { known: [...known], passed: [...passed] };
    },
  };
}

export function renderLedger(rows) {
  const checks = rows.some((row) => row.checks);
  const lines = [
    `| Test | Kind | Cause | Owner | Added | Review |${checks ? " Check |" : ""}`,
    `| --- | --- | --- | --- | --- | --- |${checks ? " --- |" : ""}`,
  ];
  for (const row of rows) {
    lines.push(
      `| ${row.test} | ${row.kind} | ${row.cause.replaceAll("|", "\\|")} | ${row.owner} | ${row.added} | ${row.review} |${checks ? ` ${(row.checks ?? ["-"]).join(` ${CHECK_SEPARATOR} `).replaceAll("|", "\\|")} |` : ""}`,
    );
  }
  return lines.join("\n");
}

export async function readLedger(root) {
  const file = path.join(root, LEDGER_FILE);
  if (!existsSync(file)) return null;
  return parseLedger(await readFile(file, "utf8"));
}

export async function checkLedger(
  root,
  {
    today = new Date().toISOString().slice(0, 10),
    promotion = false,
    notRun = new Set(),
    requireChecks = false,
  } = {},
) {
  const ledger = await readLedger(root);
  if (ledger === null) return [];
  const findings = ledger.problems.map((problem) => ({
    level: "failure",
    file: LEDGER_FILE,
    line: problem.line,
    message: problem.message,
  }));
  if (requireChecks && !ledger.hasChecks && ledger.problems.length === 0) {
    findings.push({
      level: "failure",
      file: LEDGER_FILE,
      line: 1,
      message: `the ledger has no ${CHECK_COLUMN} column: every red row must name the check it covers (ruling dx)`,
    });
  }
  const tests = path.join(root, TESTS_DIRECTORY);
  if (existsSync(tests)) {
    for (const row of ledger.rows) {
      if (!existsSync(path.join(tests, row.test + ".gd"))) {
        findings.push({
          level: "failure",
          file: LEDGER_FILE,
          line: row.line,
          message: `${row.test} has no file ${TESTS_DIRECTORY}/${row.test}.gd; remove the row or fix the name`,
        });
      }
    }
  }
  for (const row of pastReview(ledger.rows, today)) {
    const weekly = notRun.has(row.test);
    findings.push({
      level: promotion && !weekly ? "failure" : "info",
      file: LEDGER_FILE,
      line: row.line,
      message: weekly
        ? `${row.test} is past its review date (${row.review}) and is on the weekly list, so it does not hold the promotion; the weekly sweep judges it`
        : pastReviewLine(row, today),
    });
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
  if (options.today !== undefined && !ISO_DATE.test(options.today))
    throw new Error("--today takes a date written YYYY-MM-DD");
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
    if (ledger.problems.length > 0)
      throw new Error(`${LEDGER_FILE} does not parse; run --check first`);
    const verdict = judgeFailures(options.names, ledger.rows);
    for (const line of judgeLines(verdict)) console.log(line);
    console.log(
      `known-failing judge: ${verdict.listed.length} carried, ${verdict.unlisted.length} new.`,
    );
    return verdict.unlisted.length > 0 ? 1 : 0;
  }
  const notRun = options.mode === "promotion" ? weeklyNames(options.root) : new Set();
  const findings = await checkLedger(options.root, {
    today: options.today,
    promotion: options.mode === "promotion",
    notRun,
    requireChecks: true,
  });
  for (const finding of findings) {
    console.log(
      `${finding.level.toUpperCase()} known-failing ${finding.file}:${finding.line} ${finding.message}`,
    );
  }
  const failures = findings.filter((finding) => finding.level === "failure").length;
  const kinds = KINDS.map(
    (kind) => `${ledger.rows.filter((row) => row.kind === kind).length} ${kind}`,
  ).join(", ");
  console.log(
    `known-failing ${failures ? "fail" : "pass"}: ${ledger.rows.length} rows (${kinds}), ${failures} failures.`,
  );
  return failures ? 1 : 0;
}

if (isMain(import.meta.url)) {
  try {
    process.exitCode = await main();
  } catch (error) {
    console.error("known-failing: " + (error?.message ?? error));
    process.exitCode = 2;
  }
}
