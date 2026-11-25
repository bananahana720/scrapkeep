import { spawn, spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  realpathSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  LEDGER_FILE,
  TIME_OUT,
  judgeFailures,
  parseLedger,
  uncoveredChecks,
} from "../known-failing.mjs";
import { WEEKLY_FILE, weeklyNames as readWeeklyNames } from "./weekly.mjs";

export { WEEKLY_FILE, WEEKLY_HEADER, parseWeekly } from "./weekly.mjs";
import {
  IMPORT_TRIES,
  binary as smokeGodotBinary,
  failingLines,
  importTry,
  isBot,
  jobCount,
  scriptErrorCount,
  testScripts,
  testTimeoutMs,
  timeScale,
  withoutTeardownNoise,
} from "../sketch-smoke.mjs";
import {
  checkImportStamp,
  godotIdentity,
  hasValidUidCache,
  isCleanImportPass,
  writeImportStamp,
} from "../import-stamp.mjs";
import { scratchHomeEnv } from "../godot-home.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const SKETCH = "sketches/core-loop";
const TIMINGS_FILE = path.join(root, "scripts", "sketch-fast.timings.json");
const CLOUD_GODOT = "/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64";
const IMPORT_TIMEOUT_MS = 900_000;
const DEFAULT_CHUNK = 90;
const DEFAULT_SOLO_RUNS = 2;
export const BOT_ALONE = new Set([
  "restart_latency_test",
  "world1_run_test",
  "run_tier_test",
  "posture_bands_swarm_test",
  "bot_skill_bar_test",
  "alpha_posture_bands_w23_test",
]);
const NEAR_LIMIT = 0.85;
const DEFAULT_RETIME_RUNS = 3;
export const QUIET_FACTOR = 0.25;
export const QUIET_POLL_MS = 20_000;
export const QUIET_POLLS = 90;

export function gateLists(sketchDir, weeklyFile = path.join(root, WEEKLY_FILE)) {
  const weeklyNames = readWeeklyNames(root, weeklyFile);
  const lists = { tests: [], bots: [], weekly: { tests: [], bots: [] } };
  for (const script of testScripts(sketchDir)) {
    const name = path.posix.basename(script, ".gd");
    const source = readFileSync(path.join(sketchDir, "tests", name + ".gd"), "utf8");
    const into = weeklyNames.delete(name) ? lists.weekly : lists;
    (isBot(source) ? into.bots : into.tests).push(name);
  }
  if (weeklyNames.size > 0)
    throw new Error(`${WEEKLY_FILE} names tests that do not exist: ${[...weeklyNames].join(", ")}`);
  return lists;
}

export function numbered(names) {
  return names.map((name, index) => `${String(index + 1).padStart(6)}\t${name}.gd`).join("\n");
}

export function parseWindow(text, total) {
  const match = /^(\d+)-(\d+)$/.exec(text ?? "");
  if (!match) throw new Error(`a window is written FIRST-LAST, such as 361-720; got "${text}"`);
  const first = Number(match[1]);
  const last = Number(match[2]);
  if (first < 1 || last < first || last > total)
    throw new Error(`window ${text} does not fit a list of ${total}`);
  return { first, last };
}

export const testName = (text) =>
  text
    .trim()
    .replace(/^tests\//, "")
    .replace(/\.gd$/, "");

export function namedPool(lists, { bots, weekly }) {
  const from = weekly ? lists.weekly : lists;
  const list = bots ? from.bots : from.tests;
  return weekly ? list : [...list, ...(bots ? lists.weekly.bots : lists.weekly.tests)].sort();
}

export function windowNames(text, list) {
  if (/^\d+-\d+$/.test(text ?? "")) {
    const { first, last } = parseWindow(text, list.length);
    const names = list.slice(first - 1, last);
    return {
      names,
      label: `${first} to ${last} of ${list.length} (${names[0]} to ${names[names.length - 1]})`,
    };
  }
  const asked = new Set((text ?? "").split(",").map(testName).filter(Boolean));
  if (asked.size === 0)
    throw new Error(
      `a window is written FIRST-LAST, such as 361-720, or as test names joined by commas; got "${text}"`,
    );
  const unknown = [...asked].filter((name) => !list.includes(name));
  if (unknown.length > 0) throw new Error(`not on this list: ${unknown.join(", ")}`);
  const names = list.filter((name) => asked.has(name));
  return { names, label: `named, ${names.length} of ${list.length}: ${names.join(", ")}` };
}

export function chunks(names, size) {
  const out = [];
  for (let index = 0; index < names.length; index += size)
    out.push(names.slice(index, index + size));
  return out;
}

function readShardTimings(file = TIMINGS_FILE) {
  try {
    return JSON.parse(readFileSync(file, "utf8")).tests ?? {};
  } catch {
    return {};
  }
}

export function orderChunksByDuration(names, size, timings = {}) {
  if (names.length === 0) return [];
  const durationOf = (name) => {
    const raw = timings[`tests/${name}.gd`];
    return typeof raw === "number" && Number.isFinite(raw) && raw >= 0 ? raw : 0;
  };
  const sorted = [...names].sort(
    (a, b) => durationOf(b) - durationOf(a) || (a < b ? -1 : a > b ? 1 : 0),
  );
  const count = Math.ceil(names.length / size);
  if (count <= 1) return [sorted];
  const bins = Array.from({ length: count }, () => ({ totalMs: 0, tests: [] }));
  for (const name of sorted) {
    let best = null;
    for (const bin of bins) {
      if (bin.tests.length >= size) continue;
      if (!best || bin.totalMs < best.totalMs) best = bin;
    }
    best.tests.push(name);
    best.totalMs += durationOf(name);
  }
  return bins.filter((bin) => bin.tests.length > 0).map((bin) => bin.tests);
}

export function parseSmokeLog(text) {
  const results = [];
  for (const match of text.matchAll(
    /^(PASS|FAIL) \S+ res:\/\/tests\/(\w+)\.gd exit=(\S+) ([\d.]+)s$/gm,
  )) {
    results.push({
      test: match[2],
      ok: match[1] === "PASS",
      exit: match[3],
      seconds: Number(match[4]),
    });
  }
  return results;
}

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

export const SUSPECT_LOAD_FACTOR = 0.5;

export function classifyFailure(test, soloResults, ledgerRows, evidence = null, failed = null) {
  const carried = callFailure(test, soloResults, ledgerRows);
  const unnamed =
    failed && carried.call === "carried" && carried.row.kind === "red"
      ? uncoveredChecks(carried.row, failed)
      : [];
  const call =
    unnamed.length > 0
      ? {
          ...carried,
          call: "new-red",
          note: `fails a check its row does not name: ${unnamed.join("; ")}. The row covers only ${carried.row.checks.join("; ")} (ruling dx): fix it, or have the coordinator add the check to the row with its cause`,
        }
      : carried;
  const loadCanExplain = unnamed.every((word) => word === TIME_OUT);
  if ((call.call === "new-red" || call.call === "mismatch") && evidence && loadCanExplain) {
    const failed = evidence.runs.filter((_, index) => !soloResults[index]);
    const line = evidence.threads * SUSPECT_LOAD_FACTOR;
    if (
      failed.length > 0 &&
      failed.every((run) => run.timedOut && run.failLines === 0) &&
      failed.some((run) => run.load > line)
    ) {
      const peak = Math.max(...failed.map((run) => run.load));
      return {
        ...call,
        call: "suspect-load",
        note: `${failed.length} solo run(s) timed out with no failing check, one at load ${peak} on ${evidence.threads} threads; rerun alone on a quiet machine with retime`,
      };
    }
  }
  return call;
}

function callFailure(test, soloResults, ledgerRows) {
  const soloPasses = soloResults.filter(Boolean).length;
  const row = judgeFailures([test], ledgerRows).listed[0] ?? null;
  const alone =
    row?.kind === "red" && soloResults.length === 0
      ? "not rerun: red row, a check failed in the first run"
      : `${soloPasses}/${soloResults.length} pass alone`;
  if (row && row.kind === "flake" && soloResults.length > 0 && soloPasses === 0) {
    return {
      test,
      call: "mismatch",
      alone,
      row,
      note: `listed as a flake (owner ${row.owner}: ${row.cause}) but it failed every solo run. Read the solo log, then re-list it as red with its failing check or fix it; until then it blocks`,
    };
  }
  if (row)
    return {
      test,
      call: "carried",
      alone,
      row,
      note: `${row.kind}, owner ${row.owner}, review ${row.review}: ${row.cause}`,
    };
  if (soloResults.length > 0 && soloPasses === soloResults.length) {
    return {
      test,
      call: "new-flake",
      alone,
      row: null,
      note: `fails under load only. No flake row is added since ruling dx: the test's owner fixes it`,
    };
  }
  return {
    test,
    call: "new-red",
    alone,
    row: null,
    note: "no ledger row and it fails alone: a new red, which blocks (ruling ai)",
  };
}

export function failedChecks(text) {
  const labels = [];
  for (const raw of text.split("\n")) {
    const line = raw.replace(/^\s*(?:>> )?/, "").trimEnd();
    if (
      (!/-> FAIL\b/.test(line) && !/^FAIL\b/.test(line)) ||
      line.lastIndexOf("-> PASS") > line.lastIndexOf("-> FAIL")
    )
      continue;
    const label = line.match(/^\[(.+?)\] .*-> FAIL\b/)?.[1] ?? `unlabelled failing line: ${line}`;
    if (!labels.includes(label)) labels.push(label);
  }
  return labels;
}

export function whatFailed(runs, platform = process.platform) {
  const failed = runs.filter((run) => !run.ok);
  const labels = [];
  for (const run of failed) {
    for (const label of run.text === null ? ["a failed run left no log"] : failedChecks(run.text))
      if (!labels.includes(label)) labels.push(label);
  }
  return {
    labels,
    timedOut: failed.some((run) => run.timedOut),
    errorLine: failed.some(
      (run) =>
        run.text !== null &&
        /^(?:SCRIPT ERROR|ERROR)\b/m.test(withoutTeardownNoise(run.text, platform)),
    ),
  };
}

export function soloTests(failed, ledgerRows, firstRun) {
  const red = new Set(ledgerRows.filter((row) => row.kind === "red").map((row) => row.test));
  return failed.filter((test) => {
    const first = firstRun(test);
    return !(red.has(test) && first && !first.timedOut && first.failLines > 0);
  });
}

export function shardVerdict(failures) {
  const count = (call) => failures.filter((failure) => failure.call === call).length;
  const named = (call) =>
    failures
      .filter((failure) => failure.call === call)
      .map((failure) => failure.test)
      .join(", ");
  const blocking = [];
  if (count("new-red") > 0)
    blocking.push(
      `${count("new-red")} new red${count("new-red") === 1 ? "" : "s"} (${named("new-red")})`,
    );
  if (count("mismatch") > 0)
    blocking.push(`${count("mismatch")} listed as a flake but red alone (${named("mismatch")})`);
  const suspect =
    count("suspect-load") > 0
      ? `${count("suspect-load")} time-out(s) under load (${named("suspect-load")})`
      : null;
  if (blocking.length > 0)
    return { ok: false, line: `RED: ${[...blocking, ...(suspect ? [suspect] : [])].join("; ")}` };
  if (suspect)
    return {
      ok: false,
      inconclusive: true,
      line: `INCONCLUSIVE: ${suspect}; rerun alone on a quiet machine with "node scripts/gate/shard.mjs retime"`,
    };
  const parts = [];
  if (count("carried") > 0) parts.push(`${count("carried")} carried on the ledger`);
  if (count("new-flake") > 0)
    parts.push(
      `${count("new-flake")} new load flake${count("new-flake") === 1 ? "" : "s"} for ${count("new-flake") === 1 ? "its owner" : "their owners"} to fix`,
    );
  return { ok: true, line: `PASS, no new red${parts.length ? ` (${parts.join(", ")})` : ""}` };
}

export function nearLimit(results, limitMsOf, threshold = NEAR_LIMIT) {
  return results
    .map((result) => ({ ...result, limit: limitMsOf(result.test) / 1000 }))
    .filter((result) => result.seconds >= result.limit * threshold)
    .sort((a, b) => b.seconds / b.limit - a.seconds / a.limit);
}

const loadCell = (step) =>
  step.load_start === undefined ? "-" : `${step.load_start} to ${step.load_end}`;
const loadNow = () => Math.round(os.loadavg()[0] * 10) / 10;

export function renderReceipt({
  title,
  head,
  box,
  threads,
  godot,
  scale,
  window,
  steps,
  results,
  failures,
  counts,
  slow,
  verdict,
  startedAt,
  finishedAt,
}) {
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
  if (scale !== 1)
    lines.push(
      `- Time limits scaled by ${scale} (SMOKE_TIME_SCALE). Compare against a base read with the same scale.`,
    );
  lines.push("", "## Steps", "", "| Step | Exit | Wall | Load |", "| --- | --- | --- | --- |");
  for (const [name, step] of Object.entries(steps))
    lines.push(`| ${name} | ${step.exit} | ${step.seconds} s | ${loadCell(step)} |`);
  lines.push("", "## Failures", "");
  if (failures.length === 0) lines.push("None.");
  else {
    lines.push("| Test | Alone | Call | Why |", "| --- | --- | --- | --- |");
    for (const failure of failures)
      lines.push(
        `| ${failure.test} | ${failure.alone} | ${failure.call} | ${failure.note.replaceAll("|", "\\|")} |`,
      );
    lines.push(
      "",
      "A carried red must fail the check its row names; a different failing check in the same test is a new red. Read the failing lines below before posting.",
    );
    for (const failure of failures.filter((entry) => entry.lines?.length > 0))
      lines.push(
        "",
        `Failing lines of ${failure.test} ${failure.linesFrom ?? "alone"} (${failure.call}):`,
        "",
        "```",
        ...failure.lines,
        "```",
      );
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
    for (const result of slow)
      lines.push(
        `| ${result.test} | ${result.seconds.toFixed(1)} s | ${result.limit.toFixed(0)} s |`,
      );
  }
  lines.push(
    "",
    "## What moved against the last promoted head",
    "",
    "(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)",
    "",
  );
  return lines.join("\n");
}

function parseArguments(argv) {
  const options = {
    command: argv[0],
    bots: false,
    weekly: false,
    window: null,
    out: null,
    chunk: DEFAULT_CHUNK,
    lanes: null,
    solo: DEFAULT_SOLO_RUNS,
    runs: DEFAULT_RETIME_RUNS,
    maxLoad: null,
  };
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
  if (!["list", "run", "retime"].includes(options.command))
    throw new Error("the first argument is list, run or retime");
  if (options.command === "run" && (!options.window || !options.out))
    throw new Error(
      "run needs --tests or --bots with FIRST-LAST or a_test,b_test, and --out <folder>",
    );
  if (options.command === "retime" && (!options.window || !options.out))
    throw new Error("retime needs --tests a_test,b_test and --out <folder>");
  if (options.maxLoad !== null && !(options.maxLoad >= 0))
    throw new Error("--max-load takes a number from 0");
  for (const key of ["chunk", "solo", "runs"])
    if (!Number.isSafeInteger(options[key]) || options[key] < 1)
      throw new Error(`--${key} takes a whole number from 1`);
  options.lanes ??= options.bots ? 1 : 2;
  if (!Number.isSafeInteger(options.lanes) || options.lanes < 1)
    throw new Error("--lanes takes a whole number from 1");
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

export function importOutcome(exit, output) {
  return importTry({
    exit: typeof exit === "number" ? exit : null,
    signal: typeof exit === "string" ? exit : null,
    scriptErrors: scriptErrorCount(output),
  });
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

export function soloEnvironment(env, out, logDir) {
  const locks = path.join(out, "solo-locks");
  mkdirSync(locks, { recursive: true });
  return {
    ...env,
    SMOKE_SLOTS: "1",
    SMOKE_LOG_DIR: path.join(out, logDir),
    SCRAPKEEP_LOCK_DIR: locks,
  };
}

const smokeArgs = (bots, tests, { noBatch = false } = {}) => [
  path.join(root, "scripts", "sketch-smoke.mjs"),
  "--sketch",
  "core-loop",
  ...(bots ? ["--bots"] : []),
  ...(noBatch ? ["--no-batch"] : []),
  ...tests.flatMap((test) => ["--test", test]),
];

const failLineCount = (testLog) =>
  existsSync(testLog) ? (readFileSync(testLog, "utf8").match(/-> FAIL/g) ?? []).length : 0;
function soloOutcome(out, name, logDir, test) {
  const parsed = parseSmokeLog(readFileSync(path.join(out, name + ".log"), "utf8")).find(
    (result) => result.test === test,
  );
  const failLines = failLineCount(path.join(out, logDir, test + ".log"));
  return {
    ok: Boolean(parsed?.ok),
    exit: parsed?.exit ?? "none",
    seconds: parsed?.seconds ?? 0,
    timedOut: parsed?.exit === "null",
    failLines,
  };
}

function checkoutGuard(head) {
  const problem = () => {
    if (git("rev-parse", "HEAD") !== head) return "the checkout moved during the run";
    if (git("status", "--porcelain", "--untracked-files=no"))
      return "the checkout has uncommitted changes; a gate shard runs a clean head";
    const extra = git(
      "status",
      "--porcelain",
      "--untracked-files=all",
      "--",
      `${SKETCH}/tests`,
      WEEKLY_FILE,
    )
      .split("\n")
      .filter((line) => /^\?\? .*\.(gd|tsv)$/.test(line))
      .map((line) => line.slice(3));
    if (extra.length > 0)
      return `untracked test or list files change the gate lists: ${extra.slice(0, 5).join(", ")}${extra.length > 5 ? ` and ${extra.length - 5} more` : ""}`;
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
    console.log(
      `${new Date().toISOString().slice(11, 19)}Z end ${name} exit=${state.steps[name].exit} wall=${state.steps[name].seconds}s load=${state.steps[name].load_end}`,
    );
  };
}

export function renderRetimeReceipt({
  title,
  head,
  box,
  threads,
  maxLoad,
  rows,
  verdict,
  startedAt,
  finishedAt,
}) {
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
    ...rows.map(
      (row) =>
        `| ${row.test} | ${row.run} | ${row.exit} | ${row.seconds} s | ${row.load} | ${row.timedOut ? "yes" : "no"} | ${row.failLines} |`,
    ),
    "",
  ];
  return lines.join("\n");
}

export async function retime({
  tests,
  known,
  runs,
  out,
  maxLoad,
  threads,
  bots,
  head,
  box = "",
  load,
  sleep,
  runSolo,
  refuse,
}) {
  const unknown = tests.filter((test) => !known.includes(test));
  if (unknown.length > 0)
    throw new Error(`not in the ${bots ? "bot" : "non-bot"} gate lists: ${unknown.join(", ")}`);
  mkdirSync(out, { recursive: true });
  const stateFile = path.join(out, "state.json");
  const state = existsSync(stateFile)
    ? JSON.parse(readFileSync(stateFile, "utf8"))
    : {
        head,
        tests,
        bots,
        runs,
        max_load: maxLoad,
        threads,
        started_at: new Date().toISOString(),
        steps: {},
      };
  if (state.head !== head)
    throw new Error(
      `${out} holds a run on ${state.head.slice(0, 8)} and the checkout is at ${head.slice(0, 8)}; use a new folder for a new head`,
    );
  if (state.tests.join(",") !== tests.join(",") || state.bots !== bots || state.runs !== runs)
    throw new Error(
      `${out} holds a different retime (${state.tests.join(",")}, ${state.runs} runs)`,
    );
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
            console.log(
              `the machine never went quiet: load stayed above ${maxLoad} for ${(QUIET_POLLS * QUIET_POLL_MS) / 60_000} minutes before ${name}; nothing was run for it`,
            );
            return 2;
          }
          await sleep(QUIET_POLL_MS);
        }
      }
      await step(name, () => runSolo(test, run));
    }
  }
  refuse();
  const rows = tests.flatMap((test) =>
    Array.from({ length: runs }, (_, index) => {
      const result = state.steps[`retime-${test}-${index + 1}`];
      return {
        test,
        run: index + 1,
        exit: result.exit,
        seconds: result.seconds,
        load: result.load_start,
        ok: result.ok,
        timedOut: result.timedOut,
        failLines: result.failLines,
      };
    }),
  );
  const failed = rows.filter((row) => !row.ok);
  const red = failed.filter((row) => row.failLines > 0 || !row.timedOut);
  const names = (list) => [...new Set(list.map((row) => row.test))].join(", ");
  const verdict =
    red.length > 0
      ? { code: 1, line: `RED: ${names(red)} failed a check alone` }
      : failed.length > 0
        ? {
            code: 2,
            line: `INCONCLUSIVE: ${failed.length} time-out(s) even on a quiet machine (${names(failed)}); read the logs`,
          }
        : { code: 0, line: "PASS: every run passed alone on a quiet machine" };
  const title = `Gate retime: ${tests.join(", ")} on ${head.slice(0, 8)}`;
  writeFileSync(
    path.join(out, "receipt.md"),
    renderRetimeReceipt({
      title,
      head,
      box,
      threads,
      maxLoad,
      rows,
      verdict,
      startedAt: state.started_at,
      finishedAt: new Date().toISOString(),
    }),
  );
  console.log(`${title}: ${verdict.line}. Receipt: ${path.join(out, "receipt.md")}`);
  return verdict.code;
}

export function godotBinary(env = process.env, exists = existsSync) {
  const godot =
    env.GODOT_BIN ||
    (exists(CLOUD_GODOT) ? CLOUD_GODOT : exists(smokeGodotBinary) ? smokeGodotBinary : null);
  if (!godot || !exists(godot))
    throw new Error("Godot not found; run `bash tools/cloud/setup.sh` or set GODOT_BIN");
  return godot;
}

async function runRetime(options) {
  const lists = gateLists(path.join(root, SKETCH));
  const known = namedPool(lists, options);
  const tests = options.window.split(",").filter(Boolean);
  const unknown = tests.filter((test) => !known.includes(test));
  if (unknown.length > 0)
    throw new Error(
      `not in the ${options.bots ? "bot" : "non-bot"} gate lists: ${unknown.join(", ")}`,
    );
  const godot = godotBinary();
  const head = git("rev-parse", "HEAD");
  const refuse = checkoutGuard(head);
  refuse();
  const threads = os.availableParallelism();
  const env = { ...process.env, GODOT_BIN: godot };
  const runSolo = async (test, run) => {
    const name = `retime-${test}-${run}`;
    const logDir = `logs-${test}-${run}`;
    await runToFile(
      process.execPath,
      smokeArgs(options.bots, [test], { noBatch: true }),
      path.join(options.out, name + ".log"),
      soloEnvironment(env, options.out, logDir),
    );
    return soloOutcome(options.out, name, logDir, test);
  };
  return retime({
    tests,
    known,
    runs: options.runs,
    out: options.out,
    maxLoad: options.maxLoad ?? threads * QUIET_FACTOR,
    threads,
    bots: options.bots,
    head,
    box: boxLine(),
    load: loadNow,
    sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
    runSolo,
    refuse,
  });
}

async function run(options) {
  const sketchDir = path.join(root, SKETCH);
  const lists = gateLists(sketchDir);
  const from = options.weekly ? lists.weekly : lists;
  const list = options.bots ? from.bots : from.tests;
  const { names, label } = windowNames(
    options.window,
    /^\d+-\d+$/.test(options.window) ? list : namedPool(lists, options),
  );
  const godot = godotBinary();
  const scale = timeScale();
  const head = git("rev-parse", "HEAD");
  const refuse = checkoutGuard(head);
  refuse();
  const ledger = parseLedger(readFileSync(path.join(root, LEDGER_FILE), "utf8"));
  if (ledger.problems.length > 0)
    throw new Error(
      `${LEDGER_FILE} does not parse; run \`node scripts/known-failing.mjs --check\``,
    );
  if (!ledger.hasChecks)
    throw new Error(
      `${LEDGER_FILE} has no check column, so a red row would carry every check of its test (ruling dx); run \`node scripts/known-failing.mjs --check\``,
    );

  mkdirSync(options.out, { recursive: true });
  const stateFile = path.join(options.out, "state.json");
  const state = existsSync(stateFile)
    ? JSON.parse(readFileSync(stateFile, "utf8"))
    : {
        head,
        window: options.window,
        bots: options.bots,
        weekly: options.weekly,
        chunk: options.chunk,
        solo: options.solo,
        scale,
        started_at: new Date().toISOString(),
        steps: {},
      };
  if (state.head !== head)
    throw new Error(
      `${options.out} holds a run on ${state.head.slice(0, 8)} and the checkout is at ${head.slice(0, 8)}; use a new folder for a new head`,
    );
  if (
    state.window !== options.window ||
    state.bots !== options.bots ||
    Boolean(state.weekly) !== options.weekly
  )
    throw new Error(
      `${options.out} holds a different window (${state.weekly ? "weekly " : ""}${state.bots ? "bots" : "tests"} ${state.window})`,
    );
  for (const [key, now] of [
    ["chunk", options.chunk],
    ["solo", options.solo],
    ["scale", scale],
  ]) {
    if (state[key] !== undefined && state[key] !== now)
      throw new Error(
        `${options.out} was started with ${key} ${state[key]} and this run has ${now}; resume with the same value or use a new folder`,
      );
  }
  const save = () => writeFileSync(stateFile, JSON.stringify(state, null, 2) + "\n");
  save();

  const env = { ...process.env, GODOT_BIN: godot, SMOKE_SLOTS: process.env.SMOKE_SLOTS ?? "3" };
  const step = stepper(state, save, refuse, loadNow);
  const threads = os.availableParallelism();
  state.threads ??= threads;

  const cachedImport =
    process.env.SMOKE_FORCE_IMPORT !== "1"
      ? checkImportStamp(root, SKETCH, { godot: godotIdentity(godot) })
      : { ok: false };
  if (cachedImport.ok) {
    await step("import-1", async () => {
      writeFileSync(
        path.join(options.out, "import-1.log"),
        `import cached: ${SKETCH}/.godot stamp matches HEAD ${head.slice(0, 9)}\n`,
      );
      return { exit: 0, seconds: 0, outcome: "ok", cached: true };
    });
  } else {
    let imported = "failed";
    for (let pass = 1; pass <= IMPORT_TRIES; pass++) {
      const file = path.join(options.out, `import-${pass}.log`);
      await step(`import-${pass}`, async () => {
        const importEnv = {
          ...env,
          ...scratchHomeEnv(() => mkdtempSync(path.join(os.tmpdir(), "gate-import-"))),
        };
        const ran = await runToFile(
          godot,
          ["--headless", "--path", sketchDir, "--import"],
          file,
          importEnv,
          IMPORT_TIMEOUT_MS,
        );
        const output = readFileSync(file, "utf8");
        const outcome = importOutcome(ran.exit, output);
        const cleanPass = isCleanImportPass({
          status: typeof ran.exit === "number" ? ran.exit : null,
          signal: typeof ran.exit === "string" ? ran.exit : null,
          output,
          uidCacheValid: hasValidUidCache(root, SKETCH),
        });
        return { ...ran, outcome, cleanPass };
      });
      const stepInfo = state.steps[`import-${pass}`];
      imported = stepInfo.outcome ?? "ok";
      if (imported !== "ok") console.log(`import ${pass} of ${IMPORT_TRIES}: ${imported}`);
      if (imported === "ok" && (pass >= 2 || stepInfo.cleanPass)) break;
    }
    if (imported !== "ok")
      throw new Error(
        `the last import was not clean (${imported}); no test ran. Read ${options.out}/import-*.log, then start again in a new folder`,
      );
    writeImportStamp(root, SKETCH, { godot: godotIdentity(godot) });
  }

  const groups = options.bots
    ? names.map((name) => [name])
    : orderChunksByDuration(names, options.chunk, readShardTimings());
  const groupName = (index) =>
    options.bots ? `bot-${names[index]}` : `chunk${String(index).padStart(2, "0")}`;
  const activeLanes = Math.min(options.lanes, groups.length);
  const autoChunkJobs =
    !options.bots && !env.SMOKE_JOBS && activeLanes > 1
      ? String(Math.max(2, Math.floor(jobCount() / activeLanes)))
      : null;
  const firstEnv = {
    ...env,
    ...(autoChunkJobs ? { SMOKE_JOBS: autoChunkJobs } : {}),
    ...(!options.bots
      ? {
          SMOKE_BATCH: env.SMOKE_BATCH ?? "1",
          ...(env.SMOKE_BATCH_SIZE ? { SMOKE_BATCH_SIZE: env.SMOKE_BATCH_SIZE } : {}),
        }
      : {}),
    SMOKE_LOG_DIR: path.join(options.out, "logs"),
  };
  const runGroup = (index) =>
    step(groupName(index), () =>
      runToFile(
        process.execPath,
        smokeArgs(options.bots, groups[index]),
        path.join(options.out, groupName(index) + ".log"),
        firstEnv,
      ),
    );
  const alone = (index) => options.bots && options.lanes > 1 && BOT_ALONE.has(names[index]);
  const shared = groups.map((_, index) => index).filter((index) => !alone(index));
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(options.lanes, shared.length) }, async () => {
      while (next < shared.length) await runGroup(shared[next++]);
    }),
  );
  for (const index of groups.keys()) if (alone(index)) await runGroup(index);

  const results = groups.flatMap((_, index) =>
    parseSmokeLog(readFileSync(path.join(options.out, groupName(index) + ".log"), "utf8")),
  );
  const seen = new Set(results.map((result) => result.test));
  const missing = names.filter((name) => !seen.has(name));
  const failed = [
    ...results.filter((result) => !result.ok).map((result) => result.test),
    ...missing,
  ];

  const solo = new Map(failed.map((test) => [test, []]));
  const soloEvidence = new Map(failed.map((test) => [test, { threads: state.threads, runs: [] }]));
  const soloRun = async (test, attempt) => {
    const name = `solo-${test}-${attempt}`;
    const logDir = `solo-logs-${attempt}`;
    await step(name, () =>
      runToFile(
        process.execPath,
        smokeArgs(options.bots, [test], { noBatch: true }),
        path.join(options.out, name + ".log"),
        soloEnvironment(env, options.out, logDir),
      ),
    );
    const outcome = soloOutcome(options.out, name, logDir, test);
    solo.get(test).push(outcome.ok);
    soloEvidence.get(test).runs.push({
      timedOut: outcome.timedOut,
      failLines: outcome.failLines,
      load: state.steps[name].load_start ?? 0,
    });
  };
  const flakeRow = (test) => judgeFailures([test], ledger.rows).listed[0]?.kind === "flake";
  const firstRun = (test) => {
    const result = results.find((entry) => entry.test === test);
    return result
      ? {
          timedOut: result.exit === "null",
          failLines: failLineCount(path.join(options.out, "logs", test + ".log")),
        }
      : null;
  };
  for (const test of soloTests(failed, ledger.rows, firstRun)) {
    for (let attempt = 1; attempt <= options.solo; attempt++) {
      await soloRun(test, attempt);
      const last = soloEvidence.get(test).runs.at(-1);
      if (!solo.get(test).at(-1) && !last.timedOut && last.failLines > 0 && !flakeRow(test)) break;
    }
    if (
      classifyFailure(test, solo.get(test), ledger.rows, soloEvidence.get(test)).call === "mismatch"
    ) {
      for (let attempt = options.solo + 1; attempt <= options.solo * 2; attempt++)
        await soloRun(test, attempt);
    }
  }
  refuse();

  const failures = failed.map((test) => {
    const lastFailed = solo.get(test).lastIndexOf(false) + 1;
    const soloLog =
      lastFailed > 0 ? path.join(options.out, `solo-logs-${lastFailed}`, test + ".log") : null;
    const read = (file) => (existsSync(file) ? readFileSync(file, "utf8") : null);
    const firstText = read(path.join(options.out, "logs", test + ".log"));
    const shownText = soloLog ? read(soloLog) : firstText;
    const lines = shownText === null ? [] : failingLines(shownText, 12);
    const runs = [
      { ok: false, text: firstText, timedOut: firstRun(test)?.timedOut ?? true },
      ...solo.get(test).map((ok, index) => ({
        ok,
        text: read(path.join(options.out, `solo-logs-${index + 1}`, test + ".log")),
        timedOut: soloEvidence.get(test).runs[index].timedOut,
      })),
    ];
    const failure = classifyFailure(
      test,
      solo.get(test),
      ledger.rows,
      soloEvidence.get(test),
      whatFailed(runs),
    );
    return {
      ...failure,
      lines,
      linesFrom: soloLog ? "alone" : "in its first run",
      ...(missing.includes(test)
        ? { note: `no verdict line in the first run (killed or never started); ${failure.note}` }
        : {}),
    };
  });
  const logsDir = path.join(options.out, "logs");
  const allLogs = existsSync(logsDir)
    ? readdirSync(logsDir)
        .filter((name) => !name.includes("import"))
        .map((name) => readFileSync(path.join(logsDir, name), "utf8"))
        .join("\n")
    : "";
  const limitMsOf = (test) =>
    testTimeoutMs(readFileSync(path.join(sketchDir, "tests", test + ".gd"), "utf8"), scale);
  const verdict =
    missing.length === names.length
      ? { ok: false, line: "RED: no test produced a verdict line; read the first log" }
      : shardVerdict(failures);
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
  console.log(
    `${summary.title}: ${verdict.line}. Receipt: ${path.join(options.out, "receipt.md")}`,
  );
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
