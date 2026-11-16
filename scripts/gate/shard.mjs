// One shard of the promotion gate, resumable.
//
//   node scripts/gate/shard.mjs list                 the numbered non-bot list
//   node scripts/gate/shard.mjs list --bots          the numbered bot list
//   node scripts/gate/shard.mjs run --tests 361-720 --out <folder>
//   node scripts/gate/shard.mjs run --bots 16-20 --out <folder>
//   node scripts/gate/shard.mjs run --bots a_test,b_test --out <folder>   named tests (the wave gate's scoped shard)
//   node scripts/gate/shard.mjs retime --tests a_test,b_test --out <folder> [--runs 3] [--bots] [--max-load <n>]
//   add --weekly to list or run the weekly names instead (WEEKLY.tsv, ruling ca)
//
// Exit codes: 0 PASS, 1 RED, 2 INCONCLUSIVE (time-outs under load) or a refusal. `retime` waits for a quiet
// machine, then runs the named tests alone, and says whether a time-out was the machine's.
//
// `run` imports the sketch twice (a third time when the second was not clean), runs its window of the sorted list (non-bot
// tests in chunks, bot tests one at a time or, with --lanes n, n at a time with the BOT_ALONE tests alone
// afterwards), reruns every failure alone (once when a check fails alone and the test has no flake row; not at all
// when the test has a red row and its first run failed a check without timing out: the row carries it whatever a
// rerun says), sorts
// the failures with the known-failing ledger and writes <folder>/receipt.md
// and <folder>/shard.json. Every step is recorded in <folder>/state.json, so
// the same command picks up where a killed run stopped. It never edits the
// checkout, commits or pushes. project-guide/handoff/GATE.md is the recipe.

import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, readdirSync, realpathSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { LEDGER_FILE, judgeFailures, parseLedger, uncoveredChecks } from "../known-failing.mjs";
import { WEEKLY_FILE, weeklyNames as readWeeklyNames } from "./weekly.mjs";

export { WEEKLY_FILE, WEEKLY_HEADER, parseWeekly } from "./weekly.mjs";
import { IMPORT_TRIES, failingLines, importTry, isBot, scriptErrorCount, testScripts, testTimeoutMs, timeScale } from "../sketch-smoke.mjs";
import { writeImportStamp } from "../import-stamp.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const SKETCH = "sketches/core-loop";
const CLOUD_GODOT = "/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64";
const IMPORT_TIMEOUT_MS = 900_000;
const DEFAULT_CHUNK = 60;
const DEFAULT_SOLO_RUNS = 2;
// Bot tests that never share the PC with another bot lane: the wall clock decides their result, or they
// fill the machine alone. Every other bot test is driven by ticks at a fixed frame rate.
export const BOT_ALONE = new Set([
  "restart_latency_test", // pass or fail is a wall-time median
  "world1_run_test", // launches the real game, which runs on the wall clock
  "run_tier_test", // fresh-process children with a 70 s wall cap
  "posture_bands_swarm_test", // starts one child per thread pair (48 at once on the PC)
  "bot_skill_bar_test", // 16 children at once
  "alpha_posture_bands_w23_test", // 12 children at once
]);
const NEAR_LIMIT = 0.85;
const DEFAULT_RETIME_RUNS = 3;
const QUIET_FACTOR = 0.25;
export const QUIET_POLL_MS = 20_000;
export const QUIET_POLLS = 90;

// The two gate lists: every top-level test, sorted as `LC_ALL=C sort` sorts
// the file names, split by the "# smoke: bots" marker. Names carry no .gd.
// `tests` and `bots` are what a promotion runs; `weekly` holds the names
// WEEKLY.tsv takes out of them. A list file that does not parse, or names a
// test that does not exist, is an error: it never skips nothing, or everything,
// silently.
export function gateLists(sketchDir, weeklyFile = path.join(root, WEEKLY_FILE)) {
  const weeklyNames = readWeeklyNames(root, weeklyFile);
  const lists = { tests: [], bots: [], weekly: { tests: [], bots: [] } };
  for (const script of testScripts(sketchDir)) {
    const name = path.posix.basename(script, ".gd");
    const source = readFileSync(path.join(sketchDir, "tests", name + ".gd"), "utf8");
    const into = weeklyNames.delete(name) ? lists.weekly : lists;
    (isBot(source) ? into.bots : into.tests).push(name);
  }
  if (weeklyNames.size > 0) throw new Error(`${WEEKLY_FILE} names tests that do not exist: ${[...weeklyNames].join(", ")}`);
  return lists;
}

export function numbered(names) {
  return names.map((name, index) => `${String(index + 1).padStart(6)}\t${name}.gd`).join("\n");
}

// "361-720" is tests 361 to 720 of the list, counted from 1, both ends included.
export function parseWindow(text, total) {
  const match = /^(\d+)-(\d+)$/.exec(text ?? "");
  if (!match) throw new Error(`a window is written FIRST-LAST, such as 361-720; got "${text}"`);
  const first = Number(match[1]);
  const last = Number(match[2]);
  if (first < 1 || last < first || last > total) throw new Error(`window ${text} does not fit a list of ${total}`);
  return { first, last };
}

// A test's name as the lists hold it: no folder, no .gd.
export const testName = (text) => text.trim().replace(/^tests\//, "").replace(/\.gd$/, "");

// The bot or non-bot list a named window draws on: the promotion list and, unless the run is on the weekly list itself,
// the weekly names too, because the wave gate's scoped shard runs what the diff reaches.
export function namedPool(lists, { bots, weekly }) {
  const from = weekly ? lists.weekly : lists;
  const list = bots ? from.bots : from.tests;
  return weekly ? list : [...list, ...(bots ? lists.weekly.bots : lists.weekly.tests)].sort();
}

// The tests a run window names: "361-720" (see parseWindow), or test names joined by commas, each on `list`, in the
// list's order (the wave gate's scoped shard, ruling cy). `label` says which in the receipt.
export function windowNames(text, list) {
  if (/^\d+-\d+$/.test(text ?? "")) {
    const { first, last } = parseWindow(text, list.length);
    const names = list.slice(first - 1, last);
    return { names, label: `${first} to ${last} of ${list.length} (${names[0]} to ${names[names.length - 1]})` };
  }
  const asked = new Set((text ?? "").split(",").map(testName).filter(Boolean));
  if (asked.size === 0) throw new Error(`a window is written FIRST-LAST, such as 361-720, or as test names joined by commas; got "${text}"`);
  const unknown = [...asked].filter((name) => !list.includes(name));
  if (unknown.length > 0) throw new Error(`not on this list: ${unknown.join(", ")}`);
  const names = list.filter((name) => asked.has(name));
  return { names, label: `named, ${names.length} of ${list.length}: ${names.join(", ")}` };
}

export function chunks(names, size) {
  const out = [];
  for (let index = 0; index < names.length; index += size) out.push(names.slice(index, index + size));
  return out;
}

// The runner prints one "PASS|FAIL <sketch> res://tests/<name>.gd exit=<n> <s>s" line per test.
export function parseSmokeLog(text) {
  const results = [];
  for (const match of text.matchAll(/^(PASS|FAIL) \S+ res:\/\/tests\/(\w+)\.gd exit=(\S+) ([\d.]+)s$/gm)) {
    results.push({ test: match[2], ok: match[1] === "PASS", exit: match[3], seconds: Number(match[4]) });
  }
  return results;
}

// Lines the gate greps every log for. An exit-leak ERROR fails a run even when every check passed.
export function errorCounts(text) {
  const count = (pattern) => (text.match(pattern) ?? []).length;
  return {
    error: count(/^ERROR\b/gm),
    script_error: count(/^\s*SCRIPT ERROR\b/gm),
    in_use: count(/still in use/g),
    freed: count(/previously freed/g),
    leaked_warning: count(/leaked at exit/g),
  };
}

// A headless Godot test wants about two threads, so a run started above half the thread count was not alone.
export const SUSPECT_LOAD_FACTOR = 0.5;

// What one failed test means for the promotion.
//   carried       it has a ledger row (a red that fails alone, or a known flake)
//   mismatch      its row says flake and it failed every solo run: the run contradicts the
//                 ledger, so it blocks until someone reads it and re-lists or fixes it
//   new-flake     no row, and every solo run passed: record a flake row, it does not block
//   new-red       no row, and it failed alone: it blocks (ruling ai)
//   suspect-load  would be new-red or mismatch, but every failed solo run timed out with no failing check
//                 line and one started on an overloaded machine: it blocks, and is neither red nor pass
// `evidence` is { threads, runs: [{ timedOut, failLines, load }] }, one run per entry of soloResults.
// `failed` is { labels, timedOut } for the run that decides the call (the last failed solo run, or the first run
// when the test was not rerun). A red row carries only the checks it names (ruling dx): any other failing check,
// a time-out or an error line the row does not name makes the failure a new red.
export function classifyFailure(test, soloResults, ledgerRows, evidence = null, failed = null) {
  const carried = callFailure(test, soloResults, ledgerRows);
  const unnamed = failed && carried.call === "carried" && carried.row.kind === "red" ? uncoveredChecks(carried.row, failed) : [];
  const call = unnamed.length > 0 ? { ...carried, call: "new-red", note: `fails a check its row does not name: ${unnamed.join("; ")}. The row covers only ${carried.row.checks.join("; ")} (ruling dx): fix it, or have the coordinator add the check to the row with its cause` } : carried;
  if ((call.call === "new-red" || call.call === "mismatch") && evidence) {
    const failed = evidence.runs.filter((_, index) => !soloResults[index]);
    const line = evidence.threads * SUSPECT_LOAD_FACTOR;
    if (failed.length > 0 && failed.every((run) => run.timedOut && run.failLines === 0) && failed.some((run) => run.load > line)) {
      const peak = Math.max(...failed.map((run) => run.load));
      return { ...call, call: "suspect-load", note: `${failed.length} solo run(s) timed out with no failing check, one at load ${peak} on ${evidence.threads} threads; rerun alone on a quiet machine with retime` };
    }
  }
  return call;
}

function callFailure(test, soloResults, ledgerRows) {
  const soloPasses = soloResults.filter(Boolean).length;
  const row = judgeFailures([test], ledgerRows).listed[0] ?? null;
  const alone = row?.kind === "red" && soloResults.length === 0 ? "not rerun: red row, a check failed in the first run" : `${soloPasses}/${soloResults.length} pass alone`;
  if (row && row.kind === "flake" && soloResults.length > 0 && soloPasses === 0) {
    return { test, call: "mismatch", alone, row, note: `listed as a flake (owner ${row.owner}: ${row.cause}) but it failed every solo run. Read the solo log, then re-list it as red with its failing check or fix it; until then it blocks` };
  }
  if (row) return { test, call: "carried", alone, row, note: `${row.kind}, owner ${row.owner}, review ${row.review}: ${row.cause}` };
  if (soloResults.length > 0 && soloPasses === soloResults.length) {
    return { test, call: "new-flake", alone, row: null, note: `fails under load only; add a flake row to ${LEDGER_FILE}` };
  }
  return { test, call: "new-red", alone, row: null, note: "no ledger row and it fails alone: a new red, which blocks (ruling ai)" };
}

// The labels of a log's failing checks, once each in the order they first fail: the text between the square
// brackets of a "[label] ... -> FAIL" line (the runner repeats a failing line with a ">>" mark).
export function failedChecks(text) {
  const labels = [];
  for (const match of text.matchAll(/^\s*(?:>> )?\[(.+?)\] .*-> FAIL\s*$/gm)) if (!labels.includes(match[1])) labels.push(match[1]);
  return labels;
}

// The failed tests that are rerun alone. A test with a red row whose first run failed a check is not: the row
// carries it whatever a solo run says (callFailure), so the run could not change the call, and the receipt prints
// the first run's failing lines beside the row's cause. A red-row test that timed out, was killed or printed no
// failing check is still rerun, so the receipt always shows which check failed.
// `firstRun(test)` is { timedOut, failLines } for the first run, or null when it left no verdict line.
// (Trial gate on 375fe11a, 15 Nov 2026: two such reruns took 832 s of the bot shard's 6922 s.)
export function soloTests(failed, ledgerRows, firstRun) {
  const red = new Set(ledgerRows.filter((row) => row.kind === "red").map((row) => row.test));
  return failed.filter((test) => {
    const first = firstRun(test);
    return !(red.has(test) && first && !first.timedOut && first.failLines > 0);
  });
}

export function shardVerdict(failures) {
  const count = (call) => failures.filter((failure) => failure.call === call).length;
  const named = (call) => failures.filter((failure) => failure.call === call).map((failure) => failure.test).join(", ");
  const blocking = [];
  if (count("new-red") > 0) blocking.push(`${count("new-red")} new red${count("new-red") === 1 ? "" : "s"} (${named("new-red")})`);
  if (count("mismatch") > 0) blocking.push(`${count("mismatch")} listed as a flake but red alone (${named("mismatch")})`);
  const suspect = count("suspect-load") > 0 ? `${count("suspect-load")} time-out(s) under load (${named("suspect-load")})` : null;
  if (blocking.length > 0) return { ok: false, line: `RED: ${[...blocking, ...(suspect ? [suspect] : [])].join("; ")}` };
  if (suspect) return { ok: false, inconclusive: true, line: `INCONCLUSIVE: ${suspect}; rerun alone on a quiet machine with "node scripts/gate/shard.mjs retime"` };
  const parts = [];
  if (count("carried") > 0) parts.push(`${count("carried")} carried on the ledger`);
  if (count("new-flake") > 0) parts.push(`${count("new-flake")} new load flake${count("new-flake") === 1 ? "" : "s"} to list`);
  return { ok: true, line: `PASS, no new red${parts.length ? ` (${parts.join(", ")})` : ""}` };
}

// Tests that finished at or past 85% of their time limit: the next slow box kills them.
export function nearLimit(results, limitMsOf, threshold = NEAR_LIMIT) {
  return results
    .map((result) => ({ ...result, limit: limitMsOf(result.test) / 1000 }))
    .filter((result) => result.seconds >= result.limit * threshold)
    .sort((a, b) => b.seconds / b.limit - a.seconds / a.limit);
}

const loadCell = (step) => (step.load_start === undefined ? "-" : `${step.load_start} to ${step.load_end}`);
const loadNow = () => Math.round(os.loadavg()[0] * 10) / 10;

export function renderReceipt({ title, head, box, threads, godot, scale, window, steps, results, failures, counts, slow, verdict, startedAt, finishedAt }) {
  const passed = results.filter((result) => result.ok).length;
  const lines = [
    `# ${title}`,
    "",
    `**Verdict: ${verdict.line}.** ${passed} of ${results.length} passed on the first run.`,
    "",
    `- Head: ${head}, a clean checkout, recorded before the first step and checked before each one.`,
    `- Box: ${box}. Godot: ${godot}.${threads ? ` Load is the 1-minute average, read against ${threads} threads.` : ""}`,
    `- Window: ${window}. Run ${startedAt} to ${finishedAt} by \`scripts/gate/shard.mjs\`; no runner patch, no commits, no pushes.`,
  ];
  if (scale !== 1) lines.push(`- Time limits scaled by ${scale} (SMOKE_TIME_SCALE). Compare against a base read with the same scale.`);
  lines.push("", "## Steps", "", "| Step | Exit | Wall | Load |", "| --- | --- | --- | --- |");
  for (const [name, step] of Object.entries(steps)) lines.push(`| ${name} | ${step.exit} | ${step.seconds} s | ${loadCell(step)} |`);
  lines.push("", "## Failures", "");
  if (failures.length === 0) lines.push("None.");
  else {
    lines.push("| Test | Alone | Call | Why |", "| --- | --- | --- | --- |");
    for (const failure of failures) lines.push(`| ${failure.test} | ${failure.alone} | ${failure.call} | ${failure.note.replaceAll("|", "\\|")} |`);
    lines.push("", "A carried red must fail the check its row names; a different failing check in the same test is a new red. Read the failing lines below before posting.");
    for (const failure of failures.filter((entry) => entry.lines?.length > 0)) lines.push("", `Failing lines of ${failure.test} ${failure.linesFrom ?? "alone"} (${failure.call}):`, "", "```", ...failure.lines, "```");
  }
  lines.push(
    "",
    "## Error lines in every test's log",
    "",
    `\`^ERROR\` ${counts.error}, \`SCRIPT ERROR\` ${counts.script_error}, "still in use" ${counts.in_use}, "previously freed" ${counts.freed}, "leaked at exit" warnings ${counts.leaked_warning}. The count covers passing tests too (logs/ holds one file per test).`,
    "",
    "## Tests near their time limit",
    "",
  );
  if (slow.length === 0) lines.push("None at or past 85% of its limit.");
  else {
    lines.push("| Test | Time | Limit |", "| --- | --- | --- |");
    for (const result of slow) lines.push(`| ${result.test} | ${result.seconds.toFixed(1)} s | ${result.limit.toFixed(0)} s |`);
  }
  lines.push("", "## What moved against the last promoted head", "", "(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)", "");
  return lines.join("\n");
}

function parseArguments(argv) {
  const options = { command: argv[0], bots: false, weekly: false, window: null, out: null, chunk: DEFAULT_CHUNK, lanes: null, solo: DEFAULT_SOLO_RUNS, runs: DEFAULT_RETIME_RUNS, maxLoad: null };
  for (let index = 1; index < argv.length; index++) {
    const argument = argv[index];
    const value = () => {
      if (argv[index + 1] === undefined) throw new Error(`${argument} needs a value`);
      return argv[++index];
    };
    if (argument === "--bots") {
      options.bots = true;
      if (options.command === "run") options.window = value();
    } else if (argument === "--weekly") options.weekly = true;
    else if (argument === "--tests") options.window = value();
    else if (argument === "--out") options.out = path.resolve(value());
    else if (argument === "--chunk") options.chunk = Number(value());
    else if (argument === "--lanes") options.lanes = Number(value());
    else if (argument === "--solo") options.solo = Number(value());
    else if (argument === "--runs") options.runs = Number(value());
    else if (argument === "--max-load") options.maxLoad = Number(value());
    else throw new Error(`unknown argument ${argument}`);
  }
  if (!["list", "run", "retime"].includes(options.command)) throw new Error("the first argument is list, run or retime");
  if (options.command === "run" && (!options.window || !options.out)) throw new Error("run needs --tests or --bots with FIRST-LAST or a_test,b_test, and --out <folder>");
  if (options.command === "retime" && (!options.window || !options.out)) throw new Error("retime needs --tests a_test,b_test and --out <folder>");
  if (options.maxLoad !== null && !(options.maxLoad >= 0)) throw new Error("--max-load takes a number from 0");
  for (const key of ["chunk", "solo", "runs"]) if (!Number.isSafeInteger(options[key]) || options[key] < 1) throw new Error(`--${key} takes a whole number from 1`);
  options.lanes ??= options.bots ? 1 : 2;
  if (!Number.isSafeInteger(options.lanes) || options.lanes < 1) throw new Error("--lanes takes a whole number from 1");
  return options;
}

function git(...args) {
  const result = spawnSync("git", ["-C", root, ...args], { encoding: "utf8" });
  if (result.status !== 0) throw new Error(`git ${args.join(" ")} failed: ${result.stderr.trim()}`);
  return result.stdout.trim();
}

function boxLine() {
  const cpus = os.cpus();
  return `${cpus.length} vCPU ${cpus[0]?.model ?? "unknown CPU"}, ${Math.round(os.totalmem() / 2 ** 30)} GB`;
}

// runToFile reports a signal by name in `exit`; importTry wants the code and the signal apart.
export function importOutcome(exit, output) {
  return importTry({ exit: typeof exit === "number" ? exit : null, signal: typeof exit === "string" ? exit : null, scriptErrors: scriptErrorCount(output) });
}

function runToFile(command, args, file, env, timeoutMs) {
  return new Promise((resolve) => {
    const started = Date.now();
    const chunksOut = [];
    const child = spawn(command, args, { cwd: root, env });
    const timer = timeoutMs ? setTimeout(() => child.kill("SIGKILL"), timeoutMs) : null;
    child.stdout.on("data", (data) => chunksOut.push(data));
    child.stderr.on("data", (data) => chunksOut.push(data));
    child.on("close", (status, signal) => {
      if (timer) clearTimeout(timer);
      writeFileSync(file, Buffer.concat(chunksOut));
      resolve({ exit: status ?? signal, seconds: Math.round((Date.now() - started) / 1000) });
    });
  });
}

// The solo pool lives in the lock folder, so a private folder makes "one slot" mean this shard's own slot.
export function soloEnvironment(env, out, logDir) {
  const locks = path.join(out, "solo-locks");
  mkdirSync(locks, { recursive: true });
  return { ...env, SMOKE_SLOTS: "1", SMOKE_LOG_DIR: path.join(out, logDir), SCRAPKEEP_LOCK_DIR: locks };
}

const smokeArgs = (bots, tests) => [path.join(root, "scripts", "sketch-smoke.mjs"), "--sketch", "core-loop", ...(bots ? ["--bots"] : []), ...tests.flatMap((test) => ["--test", test])];

// What a solo run did, read from the runner's line and the test's own log.
const failLineCount = (testLog) => (existsSync(testLog) ? (readFileSync(testLog, "utf8").match(/-> FAIL/g) ?? []).length : 0);
function soloOutcome(out, name, logDir, test) {
  const parsed = parseSmokeLog(readFileSync(path.join(out, name + ".log"), "utf8")).find((result) => result.test === test);
  const failLines = failLineCount(path.join(out, logDir, test + ".log"));
  return { ok: Boolean(parsed?.ok), exit: parsed?.exit ?? "none", seconds: parsed?.seconds ?? 0, timedOut: parsed?.exit === "null", failLines };
}

// The lists are built from the files on disk, so an untracked test or list file changes
// every window's numbering without changing the head. Checked before each step and once
// more after the last one.
function checkoutGuard(head) {
  const problem = () => {
    if (git("rev-parse", "HEAD") !== head) return "the checkout moved during the run";
    if (git("status", "--porcelain", "--untracked-files=no")) return "the checkout has uncommitted changes; a gate shard runs a clean head";
    const extra = git("status", "--porcelain", "--untracked-files=all", "--", `${SKETCH}/tests`, WEEKLY_FILE).split("\n").filter((line) => /^\?\? .*\.(gd|tsv)$/.test(line)).map((line) => line.slice(3));
    if (extra.length > 0) return `untracked test or list files change the gate lists: ${extra.slice(0, 5).join(", ")}${extra.length > 5 ? ` and ${extra.length - 5} more` : ""}`;
    return null;
  };
  return () => {
    const found = problem();
    if (found) throw new Error(found);
  };
}

function stepper(state, save, refuse, load) {
  return async (name, action) => {
    if (state.steps[name]) return;
    refuse();
    const loadStart = load();
    console.log(`${new Date().toISOString().slice(11, 19)}Z start ${name} load=${loadStart}`);
    state.steps[name] = { ...(await action()), load_start: loadStart, load_end: load() };
    save();
    console.log(`${new Date().toISOString().slice(11, 19)}Z end ${name} exit=${state.steps[name].exit} wall=${state.steps[name].seconds}s load=${state.steps[name].load_end}`);
  };
}

export function renderRetimeReceipt({ title, head, box, threads, maxLoad, rows, verdict, startedAt, finishedAt }) {
  const lines = [
    `# ${title}`,
    "",
    `**Verdict: ${verdict.line}.**`,
    "",
    `- Head: ${head}, a clean checkout, recorded before the first step and checked before each one.`,
    `- Box: ${box}. Each run waited for the 1-minute load to be at or under ${maxLoad} (${threads} threads).`,
    `- Run ${startedAt} to ${finishedAt} by \`scripts/gate/shard.mjs retime\`.`,
    "",
    "| Test | Run | Exit | Wall | Load at start | Timed out | Failing check lines |",
    "| --- | --- | --- | --- | --- | --- | --- |",
    ...rows.map((row) => `| ${row.test} | ${row.run} | ${row.exit} | ${row.seconds} s | ${row.load} | ${row.timedOut ? "yes" : "no"} | ${row.failLines} |`),
    "",
  ];
  return lines.join("\n");
}

// Reruns the named tests alone, one at a time, each run starting only when the machine is quiet.
// `runSolo(test, run)` returns { ok, exit, seconds, timedOut, failLines }; the caller owns the engine.
export async function retime({ tests, known, runs, out, maxLoad, threads, bots, head, box = "", load, sleep, runSolo, refuse }) {
  const unknown = tests.filter((test) => !known.includes(test));
  if (unknown.length > 0) throw new Error(`not in the ${bots ? "bot" : "non-bot"} gate lists: ${unknown.join(", ")}`);
  mkdirSync(out, { recursive: true });
  const stateFile = path.join(out, "state.json");
  const state = existsSync(stateFile) ? JSON.parse(readFileSync(stateFile, "utf8")) : { head, tests, bots, runs, max_load: maxLoad, threads, started_at: new Date().toISOString(), steps: {} };
  if (state.head !== head) throw new Error(`${out} holds a run on ${state.head.slice(0, 8)} and the checkout is at ${head.slice(0, 8)}; use a new folder for a new head`);
  if (state.tests.join(",") !== tests.join(",") || state.bots !== bots || state.runs !== runs) throw new Error(`${out} holds a different retime (${state.tests.join(",")}, ${state.runs} runs)`);
  const save = () => writeFileSync(stateFile, JSON.stringify(state, null, 2) + "\n");
  save();
  const step = stepper(state, save, refuse, load);
  for (const test of tests) {
    for (let run = 1; run <= runs; run++) {
      const name = `retime-${test}-${run}`;
      if (!state.steps[name]) {
        let polls = 0;
        while (load() > maxLoad) {
          if (++polls > QUIET_POLLS) {
            console.log(`the machine never went quiet: load stayed above ${maxLoad} for ${(QUIET_POLLS * QUIET_POLL_MS) / 60_000} minutes before ${name}; nothing was run for it`);
            return 2;
          }
          await sleep(QUIET_POLL_MS);
        }
      }
      await step(name, () => runSolo(test, run));
    }
  }
  refuse();
  const rows = tests.flatMap((test) => Array.from({ length: runs }, (_, index) => {
    const result = state.steps[`retime-${test}-${index + 1}`];
    return { test, run: index + 1, exit: result.exit, seconds: result.seconds, load: result.load_start, ok: result.ok, timedOut: result.timedOut, failLines: result.failLines };
  }));
  const failed = rows.filter((row) => !row.ok);
  const red = failed.filter((row) => row.failLines > 0 || !row.timedOut);
  const names = (list) => [...new Set(list.map((row) => row.test))].join(", ");
  const verdict = red.length > 0 ? { code: 1, line: `RED: ${names(red)} failed a check alone` } : failed.length > 0 ? { code: 2, line: `INCONCLUSIVE: ${failed.length} time-out(s) even on a quiet machine (${names(failed)}); read the logs` } : { code: 0, line: "PASS: every run passed alone on a quiet machine" };
  const title = `Gate retime: ${tests.join(", ")} on ${head.slice(0, 8)}`;
  writeFileSync(path.join(out, "receipt.md"), renderRetimeReceipt({ title, head, box, threads, maxLoad, rows, verdict, startedAt: state.started_at, finishedAt: new Date().toISOString() }));
  console.log(`${title}: ${verdict.line}. Receipt: ${path.join(out, "receipt.md")}`);
  return verdict.code;
}

function godotBinary() {
  const godot = process.env.GODOT_BIN || (existsSync(CLOUD_GODOT) ? CLOUD_GODOT : null);
  if (!godot || !existsSync(godot)) throw new Error("Godot not found; run `bash tools/cloud/setup.sh` or set GODOT_BIN");
  return godot;
}

async function runRetime(options) {
  const lists = gateLists(path.join(root, SKETCH));
  const known = namedPool(lists, options);
  const tests = options.window.split(",").filter(Boolean);
  const unknown = tests.filter((test) => !known.includes(test));
  if (unknown.length > 0) throw new Error(`not in the ${options.bots ? "bot" : "non-bot"} gate lists: ${unknown.join(", ")}`);
  const godot = godotBinary();
  const head = git("rev-parse", "HEAD");
  const refuse = checkoutGuard(head);
  refuse();
  const threads = os.availableParallelism();
  const env = { ...process.env, GODOT_BIN: godot };
  const runSolo = async (test, run) => {
    const name = `retime-${test}-${run}`;
    const logDir = `logs-${test}-${run}`;
    await runToFile(process.execPath, smokeArgs(options.bots, [test]), path.join(options.out, name + ".log"), soloEnvironment(env, options.out, logDir));
    return soloOutcome(options.out, name, logDir, test);
  };
  return retime({ tests, known, runs: options.runs, out: options.out, maxLoad: options.maxLoad ?? threads * QUIET_FACTOR, threads, bots: options.bots, head, box: boxLine(), load: loadNow, sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)), runSolo, refuse });
}

async function run(options) {
  const sketchDir = path.join(root, SKETCH);
  const lists = gateLists(sketchDir);
  const from = options.weekly ? lists.weekly : lists;
  const list = options.bots ? from.bots : from.tests;
  const { names, label } = windowNames(options.window, /^\d+-\d+$/.test(options.window) ? list : namedPool(lists, options));
  const godot = godotBinary();
  const scale = timeScale();
  const head = git("rev-parse", "HEAD");
  const refuse = checkoutGuard(head);
  refuse();
  // Read before the first step, so the calls below use the ledger of the gated head.
  const ledger = parseLedger(readFileSync(path.join(root, LEDGER_FILE), "utf8"));
  if (ledger.problems.length > 0) throw new Error(`${LEDGER_FILE} does not parse; run \`node scripts/known-failing.mjs --check\``);

  mkdirSync(options.out, { recursive: true });
  const stateFile = path.join(options.out, "state.json");
  const state = existsSync(stateFile) ? JSON.parse(readFileSync(stateFile, "utf8")) : { head, window: options.window, bots: options.bots, weekly: options.weekly, chunk: options.chunk, solo: options.solo, scale, started_at: new Date().toISOString(), steps: {} };
  if (state.head !== head) throw new Error(`${options.out} holds a run on ${state.head.slice(0, 8)} and the checkout is at ${head.slice(0, 8)}; use a new folder for a new head`);
  if (state.window !== options.window || state.bots !== options.bots || Boolean(state.weekly) !== options.weekly) throw new Error(`${options.out} holds a different window (${state.weekly ? "weekly " : ""}${state.bots ? "bots" : "tests"} ${state.window})`);
  for (const [key, now] of [["chunk", options.chunk], ["solo", options.solo], ["scale", scale]]) {
    if (state[key] !== undefined && state[key] !== now) throw new Error(`${options.out} was started with ${key} ${state[key]} and this run has ${now}; resume with the same value or use a new folder`);
  }
  const save = () => writeFileSync(stateFile, JSON.stringify(state, null, 2) + "\n");
  save();

  const env = { ...process.env, GODOT_BIN: godot, SMOKE_SLOTS: process.env.SMOKE_SLOTS ?? "3" };
  const step = stepper(state, save, refuse, loadNow);
  const threads = os.availableParallelism();
  state.threads ??= threads;

  // Two imports always (the second is quick and is the one that counts), and a third when the
  // second was not clean. A crashed import is the engine's, so it is tried again; the shard stops
  // only when the last try was not clean, before any test can print a misleading red.
  let imported = "failed";
  for (let pass = 1; pass <= IMPORT_TRIES && (pass <= 2 || imported !== "ok"); pass++) {
    const file = path.join(options.out, `import-${pass}.log`);
    await step(`import-${pass}`, async () => {
      const ran = await runToFile(godot, ["--headless", "--path", sketchDir, "--import"], file, env, IMPORT_TIMEOUT_MS);
      return { ...ran, outcome: importOutcome(ran.exit, readFileSync(file, "utf8")) };
    });
    imported = state.steps[`import-${pass}`].outcome ?? "ok"; // a step from before outcomes were recorded
    if (imported !== "ok") console.log(`import ${pass} of ${IMPORT_TRIES}: ${imported}`);
  }
  if (imported !== "ok") throw new Error(`the last import was not clean (${imported}); no test ran. Read ${options.out}/import-*.log, then start again in a new folder`);
  writeImportStamp(root, SKETCH);

  const groups = options.bots ? names.map((name) => [name]) : chunks(names, options.chunk);
  const groupName = (index) => (options.bots ? `bot-${names[index]}` : `chunk${String(index).padStart(2, "0")}`);
  const firstEnv = { ...env, SMOKE_LOG_DIR: path.join(options.out, "logs") };
  const runGroup = (index) => step(groupName(index), () => runToFile(process.execPath, smokeArgs(options.bots, groups[index]), path.join(options.out, groupName(index) + ".log"), firstEnv));
  // With more than one bot lane, the bot tests in BOT_ALONE wait and run one at a time after the lanes drain.
  const alone = (index) => options.bots && options.lanes > 1 && BOT_ALONE.has(names[index]);
  const shared = groups.map((_, index) => index).filter((index) => !alone(index));
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(options.lanes, shared.length) }, async () => {
      while (next < shared.length) await runGroup(shared[next++]);
    }),
  );
  for (const index of groups.keys()) if (alone(index)) await runGroup(index);

  const results = groups.flatMap((_, index) => parseSmokeLog(readFileSync(path.join(options.out, groupName(index) + ".log"), "utf8")));
  const seen = new Set(results.map((result) => result.test));
  const missing = names.filter((name) => !seen.has(name));
  const failed = [...results.filter((result) => !result.ok).map((result) => result.test), ...missing];

  const solo = new Map(failed.map((test) => [test, []]));
  const soloEvidence = new Map(failed.map((test) => [test, { threads: state.threads, runs: [] }]));
  const soloRun = async (test, attempt) => {
    const name = `solo-${test}-${attempt}`;
    const logDir = `solo-logs-${attempt}`;
    await step(name, () => runToFile(process.execPath, smokeArgs(options.bots, [test]), path.join(options.out, name + ".log"), soloEnvironment(env, options.out, logDir)));
    const outcome = soloOutcome(options.out, name, logDir, test);
    solo.get(test).push(outcome.ok);
    soloEvidence.get(test).runs.push({ timedOut: outcome.timedOut, failLines: outcome.failLines, load: state.steps[name].load_start ?? 0 });
  };
  const flakeRow = (test) => judgeFailures([test], ledger.rows).listed[0]?.kind === "flake";
  const firstRun = (test) => {
    const result = results.find((entry) => entry.test === test);
    return result ? { timedOut: result.exit === "null", failLines: failLineCount(path.join(options.out, "logs", test + ".log")) } : null;
  };
  for (const test of soloTests(failed, ledger.rows, firstRun)) {
    for (let attempt = 1; attempt <= options.solo; attempt++) {
      await soloRun(test, attempt);
      // A check that failed alone settles the call (new-red, or carried by a red row), so a second
      // run adds nothing. A pass, a time-out and a flake row still get every run.
      const last = soloEvidence.get(test).runs.at(-1);
      if (!solo.get(test).at(-1) && !last.timedOut && last.failLines > 0 && !flakeRow(test)) break;
    }
    // A listed flake that failed every solo run would block as a mismatch. Some flakes fail
    // alone one run in three, so it gets the same number of runs again before that call.
    if (classifyFailure(test, solo.get(test), ledger.rows, soloEvidence.get(test)).call === "mismatch") {
      for (let attempt = options.solo + 1; attempt <= options.solo * 2; attempt++) await soloRun(test, attempt);
    }
  }
  refuse();

  const failures = failed.map((test) => {
    const lastFailed = solo.get(test).lastIndexOf(false) + 1;
    const soloLog = lastFailed > 0 ? path.join(options.out, `solo-logs-${lastFailed}`, test + ".log") : null;
    // A test that was not rerun (a red row) shows the failing lines of its first run.
    const shownLog = soloLog ?? (solo.get(test).length === 0 ? path.join(options.out, "logs", test + ".log") : null);
    const shownText = shownLog && existsSync(shownLog) ? readFileSync(shownLog, "utf8") : null;
    const lines = shownText === null ? [] : failingLines(shownText, 12);
    // The run the row is read against: the last failed solo run, or the first run when there was none. When
    // every solo run passed there is no failed run alone to read, and the row carries as before.
    const timedOut = lastFailed > 0 ? Boolean(soloEvidence.get(test).runs[lastFailed - 1]?.timedOut) : Boolean(firstRun(test)?.timedOut);
    const failure = classifyFailure(test, solo.get(test), ledger.rows, soloEvidence.get(test), shownText === null ? null : { labels: failedChecks(shownText), timedOut });
    return { ...failure, lines, linesFrom: soloLog ? "alone" : "in its first run", ...(missing.includes(test) ? { note: `no verdict line in the first run (killed or never started); ${failure.note}` } : {}) };
  });
  const logsDir = path.join(options.out, "logs");
  const allLogs = existsSync(logsDir) ? readdirSync(logsDir).filter((name) => !name.includes("import")).map((name) => readFileSync(path.join(logsDir, name), "utf8")).join("\n") : "";
  const limitMsOf = (test) => testTimeoutMs(readFileSync(path.join(sketchDir, "tests", test + ".gd"), "utf8"), scale);
  const verdict = missing.length === names.length ? { ok: false, line: "RED: no test produced a verdict line; read the first log" } : shardVerdict(failures);
  const summary = {
    title: `Gate shard: ${options.weekly ? "weekly " : ""}${options.bots ? "bots" : "tests"} ${options.window} on ${head.slice(0, 8)}`,
    head,
    box: boxLine(),
    threads: state.threads,
    godot: path.basename(godot),
    scale,
    window: `${options.weekly ? "weekly " : ""}${options.bots ? "bot" : "non-bot"} list ${label}, ${names.length} tests`,
    steps: state.steps,
    results,
    failures,
    counts: errorCounts(allLogs),
    slow: nearLimit(results, limitMsOf),
    verdict,
    startedAt: state.started_at,
    finishedAt: new Date().toISOString(),
  };
  writeFileSync(path.join(options.out, "shard.json"), JSON.stringify(summary, null, 2) + "\n");
  writeFileSync(path.join(options.out, "receipt.md"), renderReceipt(summary));
  console.log(`${summary.title}: ${verdict.line}. Receipt: ${path.join(options.out, "receipt.md")}`);
  return verdict.ok ? 0 : verdict.inconclusive ? 2 : 1;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.command === "list") {
    const lists = gateLists(path.join(root, SKETCH));
    const from = options.weekly ? lists.weekly : lists;
    console.log(numbered(options.bots ? from.bots : from.tests));
    return 0;
  }
  if (options.command === "retime") return runRetime(options);
  return run(options);
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    process.exitCode = await main();
  } catch (error) {
    console.error("gate shard: " + (error?.message ?? error));
    process.exitCode = 2;
  }
}
