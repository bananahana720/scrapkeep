// One shard of the promotion gate, resumable.
//
//   node scripts/gate/shard.mjs list                 the numbered non-bot list
//   node scripts/gate/shard.mjs list --bots          the numbered bot list
//   node scripts/gate/shard.mjs run --tests 361-720 --out <folder>
//   node scripts/gate/shard.mjs run --bots 16-20 --out <folder>
//   add --weekly to list or run the weekly names instead (WEEKLY.tsv, ruling ca)
//
// `run` imports the sketch twice, runs its window of the sorted list (non-bot
// tests in chunks, bot tests one at a time), reruns every failure alone, sorts
// the failures with the known-failing ledger and writes <folder>/receipt.md
// and <folder>/shard.json. Every step is recorded in <folder>/state.json, so
// the same command picks up where a killed run stopped. It never edits the
// checkout, commits or pushes. project-guide/handoff/GATE.md is the recipe.

import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, readdirSync, realpathSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { LEDGER_FILE, judgeFailures, parseLedger } from "../known-failing.mjs";
import { failingLines, isBot, testScripts, testTimeoutMs, timeScale } from "../sketch-smoke.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const SKETCH = "sketches/core-loop";
const CLOUD_GODOT = "/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64";
const IMPORT_TIMEOUT_MS = 900_000;
const DEFAULT_CHUNK = 60;
const DEFAULT_SOLO_RUNS = 2;
const NEAR_LIMIT = 0.85;

// Tests a promotion does not run (ruling ca): they run when a change touches their files
// (the fast lane) and in a weekly sweep. One row per test, beside the known-failing ledger
// (sketch-lint allows no list file under tests/).
export const WEEKLY_FILE = "project-guide/handoff/WEEKLY.tsv";
export const WEEKLY_HEADER = ["test", "group", "reason", "returns-when"];

export function parseWeekly(text) {
  const lines = (text || "").split("\n").map((line) => line.replace(/\r$/, ""));
  const problems = [];
  const rows = [];
  if (lines[0] !== WEEKLY_HEADER.join("\t")) return { rows, problems: [`line 1: the header must be: ${WEEKLY_HEADER.join(" TAB ")}`] };
  const seen = new Set();
  lines.slice(1).forEach((line, index) => {
    if (line.trim() === "") return;
    const cells = line.split("\t").map((cell) => cell.trim());
    if (cells.length !== WEEKLY_HEADER.length || cells.some((cell) => cell === "")) problems.push(`line ${index + 2}: a row needs ${WEEKLY_HEADER.join(", ")}, with no cell empty`);
    else if (!/^[a-z0-9_]+$/.test(cells[0])) problems.push(`line ${index + 2}: "${cells[0]}" must be the test's base name, with no folder and no .gd`);
    else if (seen.has(cells[0])) problems.push(`line ${index + 2}: ${cells[0]} is listed twice`);
    else {
      seen.add(cells[0]);
      rows.push({ test: cells[0], group: cells[1], reason: cells[2], returnsWhen: cells[3] });
    }
  });
  return { rows, problems };
}

// The two gate lists: every top-level test, sorted as `LC_ALL=C sort` sorts
// the file names, split by the "# smoke: bots" marker. Names carry no .gd.
// `tests` and `bots` are what a promotion runs; `weekly` holds the names
// WEEKLY.tsv takes out of them. A list file that does not parse, or names a
// test that does not exist, is an error: it never skips nothing, or everything,
// silently.
export function gateLists(sketchDir, weeklyFile = path.join(root, WEEKLY_FILE)) {
  const weeklyNames = new Set();
  if (existsSync(weeklyFile)) {
    const { rows, problems } = parseWeekly(readFileSync(weeklyFile, "utf8"));
    if (problems.length > 0) throw new Error(`${WEEKLY_FILE} does not parse: ${problems.join("; ")}`);
    for (const row of rows) weeklyNames.add(row.test);
  }
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

// What one failed test means for the promotion.
//   carried    it has a ledger row (a red that fails alone, or a known flake)
//   mismatch   its row says flake and it failed every solo run: the run contradicts the
//              ledger, so it blocks until someone reads it and re-lists or fixes it
//   new-flake  no row, and every solo run passed: record a flake row, it does not block
//   new-red    no row, and it failed alone: it blocks (ruling ai)
export function classifyFailure(test, soloResults, ledgerRows) {
  const soloPasses = soloResults.filter(Boolean).length;
  const row = judgeFailures([test], ledgerRows).listed[0] ?? null;
  const alone = `${soloPasses}/${soloResults.length} pass alone`;
  if (row && row.kind === "flake" && soloResults.length > 0 && soloPasses === 0) {
    return { test, call: "mismatch", alone, row, note: `listed as a flake (owner ${row.owner}: ${row.cause}) but it failed every solo run. Read the solo log, then re-list it as red with its failing check or fix it; until then it blocks` };
  }
  if (row) return { test, call: "carried", alone, row, note: `${row.kind}, owner ${row.owner}, review ${row.review}: ${row.cause}` };
  if (soloResults.length > 0 && soloPasses === soloResults.length) {
    return { test, call: "new-flake", alone, row: null, note: `fails under load only; add a flake row to ${LEDGER_FILE}` };
  }
  return { test, call: "new-red", alone, row: null, note: "no ledger row and it fails alone: a new red, which blocks (ruling ai)" };
}

export function shardVerdict(failures) {
  const count = (call) => failures.filter((failure) => failure.call === call).length;
  const named = (call) => failures.filter((failure) => failure.call === call).map((failure) => failure.test).join(", ");
  const blocking = [];
  if (count("new-red") > 0) blocking.push(`${count("new-red")} new red${count("new-red") === 1 ? "" : "s"} (${named("new-red")})`);
  if (count("mismatch") > 0) blocking.push(`${count("mismatch")} listed as a flake but red alone (${named("mismatch")})`);
  if (blocking.length > 0) return { ok: false, line: `RED: ${blocking.join("; ")}` };
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

export function renderReceipt({ title, head, box, godot, scale, window, steps, results, failures, counts, slow, verdict, startedAt, finishedAt }) {
  const passed = results.filter((result) => result.ok).length;
  const lines = [
    `# ${title}`,
    "",
    `**Verdict: ${verdict.line}.** ${passed} of ${results.length} passed on the first run.`,
    "",
    `- Head: ${head}, a clean checkout, recorded before the first step and checked before each one.`,
    `- Box: ${box}. Godot: ${godot}.`,
    `- Window: ${window}. Run ${startedAt} to ${finishedAt} by \`scripts/gate/shard.mjs\`; no runner patch, no commits, no pushes.`,
  ];
  if (scale !== 1) lines.push(`- Time limits scaled by ${scale} (SMOKE_TIME_SCALE). Compare against a base read with the same scale.`);
  lines.push("", "## Steps", "", "| Step | Exit | Wall |", "| --- | --- | --- |");
  for (const [name, step] of Object.entries(steps)) lines.push(`| ${name} | ${step.exit} | ${step.seconds} s |`);
  lines.push("", "## Failures", "");
  if (failures.length === 0) lines.push("None.");
  else {
    lines.push("| Test | Alone | Call | Why |", "| --- | --- | --- | --- |");
    for (const failure of failures) lines.push(`| ${failure.test} | ${failure.alone} | ${failure.call} | ${failure.note.replaceAll("|", "\\|")} |`);
    lines.push("", "A carried red must fail the check its row names; a different failing check in the same test is a new red. Read the solo logs before posting.");
    for (const failure of failures.filter((entry) => entry.lines?.length > 0)) lines.push("", `Failing lines of ${failure.test} alone (${failure.call}):`, "", "```", ...failure.lines, "```");
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
  const options = { command: argv[0], bots: false, weekly: false, window: null, out: null, chunk: DEFAULT_CHUNK, lanes: null, solo: DEFAULT_SOLO_RUNS };
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
    else throw new Error(`unknown argument ${argument}`);
  }
  if (!["list", "run"].includes(options.command)) throw new Error("the first argument is list or run");
  if (options.command === "run" && (!options.window || !options.out)) throw new Error("run needs --tests FIRST-LAST or --bots FIRST-LAST, and --out <folder>");
  for (const key of ["chunk", "solo"]) if (!Number.isSafeInteger(options[key]) || options[key] < 1) throw new Error(`--${key} takes a whole number from 1`);
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

async function run(options) {
  const sketchDir = path.join(root, SKETCH);
  const lists = gateLists(sketchDir);
  const from = options.weekly ? lists.weekly : lists;
  const list = options.bots ? from.bots : from.tests;
  const { first, last } = parseWindow(options.window, list.length);
  const names = list.slice(first - 1, last);
  const godot = process.env.GODOT_BIN || (existsSync(CLOUD_GODOT) ? CLOUD_GODOT : null);
  if (!godot || !existsSync(godot)) throw new Error("Godot not found; run `bash tools/cloud/setup.sh` or set GODOT_BIN");
  const scale = timeScale();
  const head = git("rev-parse", "HEAD");
  // The lists are built from the files on disk, so an untracked test or list file changes
  // every window's numbering without changing the head. Checked before each step and once
  // more after the last one.
  const checkoutProblem = () => {
    if (git("rev-parse", "HEAD") !== head) return "the checkout moved during the run";
    if (git("status", "--porcelain", "--untracked-files=no")) return "the checkout has uncommitted changes; a gate shard runs a clean head";
    const extra = git("status", "--porcelain", "--untracked-files=all", "--", `${SKETCH}/tests`, WEEKLY_FILE).split("\n").filter((line) => /^\?\? .*\.(gd|tsv)$/.test(line)).map((line) => line.slice(3));
    if (extra.length > 0) return `untracked test or list files change the gate lists: ${extra.slice(0, 5).join(", ")}${extra.length > 5 ? ` and ${extra.length - 5} more` : ""}`;
    return null;
  };
  const refuse = () => {
    const problem = checkoutProblem();
    if (problem) throw new Error(problem);
  };
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
  const smoke = path.join(root, "scripts", "sketch-smoke.mjs");
  const step = async (name, action) => {
    if (state.steps[name]) return;
    refuse();
    console.log(`${new Date().toISOString().slice(11, 19)}Z start ${name}`);
    state.steps[name] = await action();
    save();
    console.log(`${new Date().toISOString().slice(11, 19)}Z end ${name} exit=${state.steps[name].exit} wall=${state.steps[name].seconds}s`);
  };
  const smokeArgs = (tests) => [smoke, "--sketch", "core-loop", ...(options.bots ? ["--bots"] : []), ...tests.flatMap((test) => ["--test", test])];

  for (const pass of [1, 2]) {
    await step(`import-${pass}`, () => runToFile(godot, ["--headless", "--path", sketchDir, "--import"], path.join(options.out, `import-${pass}.log`), env, IMPORT_TIMEOUT_MS));
  }

  const groups = options.bots ? names.map((name) => [name]) : chunks(names, options.chunk);
  const groupName = (index) => (options.bots ? `bot-${names[index]}` : `chunk${String(index).padStart(2, "0")}`);
  const firstEnv = { ...env, SMOKE_LOG_DIR: path.join(options.out, "logs") };
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(options.lanes, groups.length) }, async () => {
      while (next < groups.length) {
        const index = next++;
        await step(groupName(index), () => runToFile(process.execPath, smokeArgs(groups[index]), path.join(options.out, groupName(index) + ".log"), firstEnv));
      }
    }),
  );

  const results = groups.flatMap((_, index) => parseSmokeLog(readFileSync(path.join(options.out, groupName(index) + ".log"), "utf8")));
  const seen = new Set(results.map((result) => result.test));
  const missing = names.filter((name) => !seen.has(name));
  const failed = [...results.filter((result) => !result.ok).map((result) => result.test), ...missing];

  const solo = new Map(failed.map((test) => [test, []]));
  const soloRun = async (test, attempt) => {
    const name = `solo-${test}-${attempt}`;
    const soloEnv = { ...env, SMOKE_SLOTS: "1", SMOKE_LOG_DIR: path.join(options.out, `solo-logs-${attempt}`) };
    await step(name, () => runToFile(process.execPath, smokeArgs([test]), path.join(options.out, name + ".log"), soloEnv));
    const parsed = parseSmokeLog(readFileSync(path.join(options.out, name + ".log"), "utf8")).find((result) => result.test === test);
    solo.get(test).push(Boolean(parsed?.ok));
  };
  for (const test of failed) {
    for (let attempt = 1; attempt <= options.solo; attempt++) await soloRun(test, attempt);
    // A listed flake that failed every solo run would block as a mismatch. Some flakes fail
    // alone one run in three, so it gets the same number of runs again before that call.
    if (classifyFailure(test, solo.get(test), ledger.rows).call === "mismatch") {
      for (let attempt = options.solo + 1; attempt <= options.solo * 2; attempt++) await soloRun(test, attempt);
    }
  }
  refuse();

  const failures = failed.map((test) => {
    const failure = classifyFailure(test, solo.get(test), ledger.rows);
    const lastFailed = solo.get(test).lastIndexOf(false) + 1;
    const soloLog = lastFailed > 0 ? path.join(options.out, `solo-logs-${lastFailed}`, test + ".log") : null;
    const lines = soloLog && existsSync(soloLog) ? failingLines(readFileSync(soloLog, "utf8"), 12) : [];
    return { ...failure, lines, ...(missing.includes(test) ? { note: `no verdict line in the first run (killed or never started); ${failure.note}` } : {}) };
  });
  const logsDir = path.join(options.out, "logs");
  const allLogs = existsSync(logsDir) ? readdirSync(logsDir).filter((name) => !name.includes("import")).map((name) => readFileSync(path.join(logsDir, name), "utf8")).join("\n") : "";
  const limitMsOf = (test) => testTimeoutMs(readFileSync(path.join(sketchDir, "tests", test + ".gd"), "utf8"), scale);
  const verdict = missing.length === names.length ? { ok: false, line: "RED: no test produced a verdict line; read the first log" } : shardVerdict(failures);
  const summary = {
    title: `Gate shard: ${options.weekly ? "weekly " : ""}${options.bots ? "bots" : "tests"} ${options.window} on ${head.slice(0, 8)}`,
    head,
    box: boxLine(),
    godot: path.basename(godot),
    scale,
    window: `${options.weekly ? "weekly " : ""}${options.bots ? "bot" : "non-bot"} list ${first} to ${last} of ${list.length} (${names[0]} to ${names[names.length - 1]}), ${names.length} tests`,
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
  return verdict.ok ? 0 : 1;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.command === "list") {
    const lists = gateLists(path.join(root, SKETCH));
    const from = options.weekly ? lists.weekly : lists;
    console.log(numbered(options.bots ? from.bots : from.tests));
    return 0;
  }
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
