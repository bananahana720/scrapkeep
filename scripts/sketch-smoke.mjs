import { spawnSync } from "node:child_process";
import {
  realpathSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { checkImportStamp, godotIdentity, writeImportStamp } from "./import-stamp.mjs";
import { resolveGodotBinary, withScratchGodotEnv } from "./godot-home.mjs";
import {
  BATCH_MAX_MS,
  BATCH_MAX_TESTS,
  BATCH_TEST_MAX_MS,
  IMPORT_TRIES,
  MISSING_VERDICT,
  SMOKE_BATCH_FALLBACK_MS,
  SMOKE_BATCH_SIZE_DEFAULT,
  SMOKE_BATCH_TEST_MAX_MS,
  TIMEOUT_MS,
  batchHasOutsideError,
  batchable,
  countChecks,
  failingLines,
  globToRegExp,
  hasVerdictLine,
  importTry,
  importWithRetry as importWithRetryBase,
  isBot,
  isSolo,
  isSoloScript,
  jobCount,
  judge,
  logFileName,
  matchesGlob,
  runGodotBatch,
  scriptErrorCount,
  selectTests,
  sketchDirectories,
  skipLines,
  smokeBatchSize,
  smokeWidth,
  soloWidth,
  splitBatch,
  takeBatch,
  takeBatchPacked,
  testFixedFps,
  testScripts,
  testTimeoutMs,
  timeScale,
  withoutTeardownNoise,
} from "./lib/godot-test-runner.mjs";
import {
  FOREIGN_CLAIM_MAX_MS,
  HEARTBEAT_MS,
  QUIET_HOLD,
  QUIET_MAX_MS,
  STALE_CLAIM_MS,
  acquireMachine,
  acquireSlot,
  holdQuietSync,
  machineSlotCount,
  namedRunMustWait,
  quietHolder,
  waitForMachine,
} from "./lib/machine-lock.mjs";
import { runProcess } from "./lib/proc.mjs";
import { runnerReceiptFileName, runnerReceiptPath, writeJsonReceipt } from "./lib/receipt.mjs";

export {
  BATCH_MAX_MS,
  BATCH_MAX_TESTS,
  BATCH_TEST_MAX_MS,
  FOREIGN_CLAIM_MAX_MS,
  HEARTBEAT_MS,
  IMPORT_TRIES,
  MISSING_VERDICT,
  QUIET_HOLD,
  QUIET_MAX_MS,
  SMOKE_BATCH_FALLBACK_MS,
  SMOKE_BATCH_SIZE_DEFAULT,
  SMOKE_BATCH_TEST_MAX_MS,
  STALE_CLAIM_MS,
  acquireMachine,
  acquireSlot,
  batchHasOutsideError,
  batchable,
  countChecks,
  failingLines,
  globToRegExp,
  hasVerdictLine,
  holdQuietSync,
  importTry,
  isBot,
  isSolo,
  isSoloScript,
  jobCount,
  judge,
  logFileName,
  machineSlotCount,
  matchesGlob,
  namedRunMustWait,
  quietHolder,
  scriptErrorCount,
  selectTests,
  sketchDirectories,
  skipLines,
  smokeBatchSize,
  smokeWidth,
  soloWidth,
  splitBatch,
  takeBatch,
  takeBatchPacked,
  testFixedFps,
  testScripts,
  testTimeoutMs,
  timeScale,
  waitForMachine,
  withoutTeardownNoise,
};

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const TIMINGS_FILE = path.join(root, "scripts", "sketch-fast.timings.json");
export const binary = resolveGodotBinary() ?? "";
const SLOWEST = 10;
const RECEIPT_SCHEMA = "scrapkeep-smoke-receipt/1";

export function splitFlags(text) {
  return (text || "").split(/\s+/).filter(Boolean);
}

export function parseArgs(argv, env = {}) {
  const options = {
    sketches: [],
    tests: [],
    flags: null,
    receipt: null,
    strict: false,
    bots: false,
    batch: env.SMOKE_BATCH !== "0",
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--sketch" && argv[i + 1]) options.sketches.push(argv[++i]);
    else if (arg === "--test" && argv[i + 1]) options.tests.push(argv[++i]);
    else if (arg === "--flags" && argv[i + 1] !== undefined) options.flags = argv[++i];
    else if (arg === "--receipt" && argv[i + 1]) options.receipt = argv[++i];
    else if (arg === "--strict-verdict") options.strict = true;
    else if (arg === "--bots") options.bots = true;
    else if (arg === "--no-batch") options.batch = false;
  }
  options.flags = splitFlags(options.flags ?? env.SMOKE_FLAGS);
  options.named = options.tests.length > 0;
  options.receipt ??= options.named ? "named" : options.bots ? "bots" : "smoke";
  return options;
}

export function validateRun(options, available) {
  if (options.named && options.sketches.length !== 1)
    return "sketch:smoke --test requires exactly one --sketch";
  if (options.receipt !== null && !/^[A-Za-z0-9._-]+$/.test(options.receipt))
    return `sketch:smoke --receipt takes a bare label for artifacts/local/receipts/<label>-<tree>-<stamp>.json, not a path (${options.receipt})`;
  const missing = options.sketches.filter((name) => !available.includes(name));
  if (missing.length > 0) return `sketch:smoke has no sketch named ${missing.join(", ")}`;
  return null;
}

export function noMatchMessage(sketch, globs) {
  return `sketch:smoke found no test in ${sketch} matching ${globs.join(", ")}`;
}

function git(args) {
  const result = spawnSync("git", ["-C", root, ...args], { encoding: "utf8" });
  if (result.status !== 0 || result.error) return null;
  return result.stdout.trim();
}

function gitState() {
  const status = git(["status", "--porcelain"]);
  return {
    head: git(["rev-parse", "HEAD"]),
    tree: git(["rev-parse", "HEAD^{tree}"]),
    clean: status === null ? null : status === "",
    dirty_paths: status === null ? null : status.split("\n").filter(Boolean).slice(0, 20),
  };
}

function godotState() {
  const result = spawnSync(binary, ["--version"], { encoding: "utf8", timeout: 20_000 });
  return { binary, version: result.status === 0 ? result.stdout.trim() : null };
}

function countStems(directory) {
  const music = path.join(directory, "assets", "music_ace");
  if (!existsSync(music)) return 0;
  return readdirSync(music, { recursive: true }).filter((name) => String(name).endsWith(".ogg"))
    .length;
}

export function receiptFileName(label, tree, startedAt) {
  return runnerReceiptFileName(label, tree, startedAt);
}

export function parseQuarantine(text) {
  return (text || "")
    .split("\n")
    .map((line) => line.replace(/\r$/, ""))
    .filter((line) => line.trim() !== "")
    .slice(1)
    .map((line) => {
      const [test, owner, reason, added, deadline] = line.split("\t");
      return { test, owner, reason, added, deadline };
    });
}

export function quarantinedNames(text) {
  return new Set(parseQuarantine(text).map((entry) => entry.test));
}

export function readQuarantine(directory) {
  return new Set(readQuarantineEntries(directory).map((entry) => entry.test));
}

export function readQuarantineEntries(directory) {
  const file = path.join(directory, "tests", "QUARANTINE.tsv");
  if (!existsSync(file)) return [];
  return parseQuarantine(readFileSync(file, "utf8"));
}

export function quarantineNote(entry) {
  return `quarantined: ${entry.test} (${entry.owner}: ${entry.reason})`;
}

export function expiredQuarantine(entries, today = new Date().toISOString().slice(0, 10)) {
  return entries.filter(
    (entry) => /^\d{4}-\d{2}-\d{2}$/.test(entry.deadline ?? "") && entry.deadline < today,
  );
}

export function expiredLine(entry) {
  return `quarantine expired: ${entry.test} (${entry.owner}) deadline ${entry.deadline}; fix the test or have the coordinator extend the row in tests/QUARANTINE.tsv`;
}

export function quarantineRecord(entry, { ok, exit, signal = null, failing }) {
  return {
    test: entry.test,
    owner: entry.owner,
    reason: entry.reason,
    deadline: entry.deadline,
    result: ok ? "green" : "red",
    exit: exit ?? null,
    signal,
    failing_checks: failing,
  };
}

export function quarantineRecords(results) {
  return results
    .filter((result) => result.quarantined && result.quarantine)
    .map((result) =>
      quarantineRecord(result.quarantine, {
        ok: result.ok,
        exit: result.exit,
        signal: result.signal,
        failing: result.fails,
      }),
    );
}

export function quarantineLines(records) {
  const how = (record) => (record.signal ? `signal ${record.signal}` : `exit ${record.exit}`);
  const red = records.filter((record) => record.result === "red");
  const green = records.filter((record) => record.result === "green");
  const lines = [];
  if (red.length > 0) {
    lines.push(`quarantined (red) ${red.length} (known red; not a failure):`);
    for (const record of red)
      lines.push(
        `  ${record.test}: ${record.failing_checks} failing checks, ${how(record)} (${record.owner}: ${record.reason}; deadline ${record.deadline})`,
      );
  }
  if (green.length > 0) {
    lines.push(`quarantined but green: remove from quarantine (${green.length}):`);
    for (const record of green)
      lines.push(`  ${record.test} (${record.owner}; deadline ${record.deadline})`);
  }
  return lines;
}

export function quarantineVerdict(results) {
  const label = (result) => result.label.replace(/^.* res:\/\/tests\//, "").replace(/\.gd$/, "");
  const quarantined = results.filter((result) => result.quarantined);
  return {
    failed: results.filter((result) => !result.ok && !result.quarantined),
    quarantined_red: quarantined.filter((result) => !result.ok).map(label),
    quarantine_stale: quarantined.filter((result) => result.ok).map(label),
  };
}

export function runPasses(results) {
  return quarantineVerdict(results).failed.length === 0;
}

export function gateFlagsError(options) {
  if (["gate", "gate-bots"].includes(options.receipt) && options.flags.length > 0) {
    return `sketch:smoke: a gate run (--receipt ${options.receipt}) refuses launch flags from --flags or SMOKE_FLAGS because a gate runs the shipping defaults`;
  }
  return null;
}

export function emitReceipt(receipt, write = writeReceipt, log = console.log) {
  const target = path.join(root, "artifacts", "local", "receipts");
  try {
    log(`receipt ${write(receipt)}`);
    return null;
  } catch (error) {
    log(`sketch:smoke could not write the receipt under ${target}: ${error.message}`);
    return 3;
  }
}

export function buildReceipt({
  label,
  argv,
  root: repoRoot,
  git: gitInfo,
  godot,
  sketches,
  flags,
  width,
  lockWaitMs,
  startedAt,
  wallMs,
  stems,
  results,
  botTierNotRun = [],
  expired = [],
  timeScale: scale = 1,
}) {
  const rows = results.map((result) => ({
    label: result.label,
    ok: result.ok,
    exit: result.exit,
    ms: result.ms,
    solo: Boolean(result.solo),
    passes: result.passes,
    fails: result.fails,
    verdict_line: result.verdict_line,
    skips: result.skips,
    ...(result.quarantined ? { quarantined: true } : {}),
  }));
  const verdict = quarantineVerdict(results);
  const totals = {
    runs: rows.length,
    failed: verdict.failed.length,
    skipped: rows.filter((row) => row.skips.length > 0).length,
    missing_verdict: rows.filter(
      (row) => row.verdict_line === false && (row.skips.length === 0 || row.passes + row.fails > 0),
    ).length,
    quarantined_red: verdict.quarantined_red,
    quarantine_stale: verdict.quarantine_stale,
  };
  return {
    schema: RECEIPT_SCHEMA,
    label,
    argv,
    root: repoRoot,
    head: gitInfo?.head ?? null,
    tree: gitInfo?.tree ?? null,
    clean: gitInfo?.clean ?? null,
    dirty_paths: gitInfo?.dirty_paths ?? null,
    godot,
    sketches,
    flags,
    ...(scale !== 1 ? { time_scale: scale } : {}),
    width,
    lock_wait_ms: lockWaitMs,
    started_at: startedAt,
    wall_ms: wallMs,
    stems,
    quarantined: quarantineRecords(results),
    quarantine_expired: expired.map((entry) => ({
      test: entry.test,
      owner: entry.owner,
      deadline: entry.deadline,
    })),
    results: rows,
    bot_tier_not_run: botTierNotRun,
    totals,
    ok: totals.failed === 0,
  };
}

function keepOutput(job, output, env = process.env) {
  if (env.SMOKE_LOG_DIR) {
    mkdirSync(env.SMOKE_LOG_DIR, { recursive: true });
    writeFileSync(path.join(env.SMOKE_LOG_DIR, logFileName(job.label)), output);
  }
  if (env.SMOKE_FULL) console.log(output);
}

function report(job, status, output, ms, signal = null) {
  const { ok, verdict, skips, reason } = judge({ test: job.test, status, output });
  const quarantined = Boolean(job.quarantined);
  const { passes, fails } = countChecks(output);
  console.log(`${ok ? "PASS" : "FAIL"} ${job.label} exit=${status} ${(ms / 1000).toFixed(1)}s`);
  if (!ok) {
    const failing = [...(reason ? [reason] : []), ...failingLines(output)];
    if (failing.length > 0)
      console.log(
        `failing lines (${passes} checks passed, ${fails} failed):\n${failing.map((line) => "  >> " + line).join("\n")}`,
      );
    if (!process.env.SMOKE_FULL) console.log(output.split("\n").slice(-40).join("\n"));
  }
  keepOutput(job, output);
  if (reason) console.log(reason);
  if (process.env.SMOKE_DEBUG_ARGS) console.log(`  args: ${job.args.join(" ")}`);
  return {
    label: job.label,
    ok,
    exit: status,
    ms,
    solo: Boolean(job.solo),
    passes,
    fails,
    verdict_line: verdict,
    skips,
    test: Boolean(job.test),
    quarantined,
    signal: signal ?? null,
    ...(quarantined && job.quarantine ? { quarantine: job.quarantine } : {}),
  };
}

export async function spawnCollect(
  command,
  args,
  { env = process.env, timeoutMs = TIMEOUT_MS } = {},
) {
  const res = await runProcess(command, args, { env, timeoutMs, killGraceMs: 5_000 });
  return {
    status: res.exit,
    signal: res.signal,
    output: res.error ? res.output + String(res.error.message ?? res.error) : res.output,
  };
}

async function runImport(job) {
  const started = Date.now();
  const result = await withScratchGodotEnv((env) => spawnCollect(binary, job.args, { env }), {
    prefix: "sketch-smoke-",
    homeOnly: true,
  });
  return {
    ...report(job, result.status, result.output, Date.now() - started, result.signal),
    scriptErrors: scriptErrorCount(result.output),
  };
}

export function importWithRetry(name, base, run = runImport, log = console.log) {
  return importWithRetryBase(name, base, run, log);
}

async function runAsync(job) {
  const started = Date.now();
  const res = await withScratchGodotEnv(
    (env) => runProcess(binary, job.args, { env, timeoutMs: job.timeoutMs || TIMEOUT_MS }),
    { prefix: "sketch-smoke-", dirs: null },
  );
  return report(job, res.exit, res.output, Date.now() - started, res.signal);
}

function readSmokeTimings(file = TIMINGS_FILE) {
  try {
    return JSON.parse(readFileSync(file, "utf8")).tests ?? {};
  } catch {
    return {};
  }
}

async function runBatchJobs(batchJobs) {
  const directory = batchJobs[0].directory;
  const fixedFps = batchJobs[0].fixedFps ?? null;
  const rels = batchJobs.map((job) => job.rel);
  const timeoutMs = batchJobs.reduce((sum, job) => sum + (job.timeoutMs || TIMEOUT_MS), 0);
  const batch = await runGodotBatch({
    binary,
    sketchDir: directory,
    tests: rels,
    timeoutMs,
    fixedFps,
    prefix: "sketch-smoke-",
  });
  if (batch.tainted) {
    const soloResults = [];
    for (const job of batchJobs) soloResults.push(await runAsync(job));
    return soloResults;
  }
  const byRel = new Map(batchJobs.map((job) => [job.rel, job]));
  const out = [];
  const reruns = [];
  for (const row of batch.done) {
    const job = byRel.get(row.test);
    if (!job) continue;
    const verdict = judge({ test: job.test, status: row.exit, output: row.output });
    if (verdict.ok) out.push(report(job, row.exit, row.output, row.ms, null));
    else reruns.push(job);
  }
  for (const rel of [...(batch.cut ? [batch.cut] : []), ...batch.rest]) {
    const job = byRel.get(rel);
    if (job) reruns.push(job);
  }
  for (const job of reruns) out.push(await runAsync(job));
  return out;
}

async function pool(
  jobs,
  width,
  { batchSize = SMOKE_BATCH_SIZE_DEFAULT, explicitBatchSize = false } = {},
) {
  const results = [];
  const queue = [...jobs];
  const batchableCount = jobs.filter((job) => job.canBatch).length;
  const effectiveBatchSize =
    batchSize <= 1
      ? 1
      : explicitBatchSize || width <= 1
        ? batchSize
        : Math.min(batchSize, Math.max(2, Math.ceil(batchableCount / width)));
  const effectiveBatchMaxMs = Math.max(BATCH_MAX_MS, effectiveBatchSize * 8_000);
  async function worker() {
    while (queue.length > 0) {
      const first = queue[0];
      const batch =
        effectiveBatchSize > 1 && first?.canBatch
          ? takeBatchPacked(
              queue,
              (row) =>
                Boolean(row.canBatch) &&
                row.directory === first.directory &&
                (row.fixedFps ?? null) === (first.fixedFps ?? null),
              effectiveBatchSize,
              effectiveBatchMaxMs,
            )
          : [];
      if (batch.length > 1) {
        results.push(...(await runBatchJobs(batch)));
        continue;
      }
      const job = batch[0] ?? queue.shift();
      results.push(await runAsync(job));
    }
  }
  await Promise.all(Array.from({ length: Math.min(width, jobs.length) }, worker));
  return results;
}

export function writeReceipt(receipt) {
  return writeJsonReceipt(
    runnerReceiptPath(root, receipt.label, receipt.tree, receipt.started_at),
    receipt,
  );
}

async function main() {
  const argv = process.argv.slice(2);
  const options = parseArgs(argv, process.env);
  const refusal = gateFlagsError(options);
  if (refusal) {
    console.error(refusal);
    process.exit(2);
  }
  const all = sketchDirectories(path.join(root, "sketches"));
  const error = validateRun(
    options,
    all.map((directory) => path.basename(directory)),
  );
  if (error) {
    console.error(error);
    process.exit(2);
  }
  const sketches =
    options.sketches.length === 0
      ? all
      : all.filter((directory) => options.sketches.includes(path.basename(directory)));
  if (!binary || !existsSync(binary)) {
    console.error(`Godot binary not found${binary ? ` at ${binary}` : ""}; set GODOT_BIN`);
    process.exit(2);
  }
  if (sketches.length === 0) {
    console.log("sketch:smoke found no sketches/*/project.godot");
    return;
  }
  const named = options.named;
  const botTierNotRun = [];
  const plans = sketches.map((directory) => {
    const selected = named
      ? selectTests(testScripts(directory), options.tests)
      : testScripts(directory);
    const scripts = selected.filter((script) => {
      const bots = isBot(
        readFileSync(path.join(directory, script.replace(/^res:\/\//, "")), "utf8"),
      );
      if (options.bots) return bots;
      if (named || !bots) return true;
      botTierNotRun.push(path.posix.basename(script));
      return false;
    });
    return { directory, scripts };
  });
  if (named && plans[0].scripts.length === 0) {
    console.error(noMatchMessage(path.basename(plans[0].directory), options.tests));
    process.exit(2);
  }
  if (options.bots && plans.every((plan) => plan.scripts.length === 0)) {
    console.error("sketch:smoke found no bot-tier tests in the selected sketches");
    process.exit(2);
  }
  let scale;
  let batchSize;
  try {
    scale = timeScale();
    batchSize = smokeBatchSize();
  } catch (problem) {
    console.error(`sketch:smoke: ${problem.message}`);
    process.exit(2);
  }
  const explicitBatchSize = Boolean(process.env.SMOKE_BATCH_SIZE);
  if (scale !== 1) console.log(`sketch:smoke: time limits scaled by ${scale} (SMOKE_TIME_SCALE)`);
  const waited = await acquireMachine();
  if (waited > 0) console.log(`sketch:smoke waited ${(waited / 1000).toFixed(0)}s for the machine`);
  const totalTests = plans.reduce((sum, plan) => sum + plan.scripts.length, 0);
  const width = smokeWidth({
    bots: options.bots,
    named,
    testCount: totalTests,
    env: process.env,
  });
  const startedAt = new Date().toISOString();
  const started = Date.now();
  const results = [];
  const expired = [];
  const jobs = [];
  const solo = [];
  const userArgs = options.flags.length > 0 ? ["--", ...options.flags] : [];
  const timings = readSmokeTimings();
  for (const { directory, scripts } of plans) {
    const name = path.relative(root, directory);
    const base = ["--headless", "--path", directory];
    const quarantineRows = readQuarantineEntries(directory);
    const quarantine = new Set(quarantineRows.map((row) => row.test));
    expired.push(...expiredQuarantine(quarantineRows));
    const stampOk =
      process.env.SMOKE_FORCE_IMPORT !== "1" &&
      checkImportStamp(root, name, { godot: godotIdentity(binary) }).ok;
    if (stampOk) {
      const cached = {
        label: `${name} import`,
        ok: true,
        exit: 0,
        ms: 0,
        solo: false,
        passes: 0,
        fails: 0,
        verdict_line: null,
        skips: [],
        test: false,
        quarantined: false,
        signal: null,
      };
      console.log(`PASS ${cached.label} exit=0 0.0s (cached)`);
      results.push(cached);
    } else {
      const imported = await importWithRetry(name, base);
      results.push(...imported.results);
      if (!imported.ok) {
        console.error(
          `${name} import failed ${IMPORT_TRIES} times (${imported.tries.map((row) => row.outcome).join(", ")}); tests not run`,
        );
        process.exit(1);
      }
      writeImportStamp(root, name, { godot: godotIdentity(binary) });
    }
    const hasBatchDriver = existsSync(path.join(directory, "tools", "test_batch.gd"));
    if (!named && !options.bots)
      jobs.push({ label: `${name} boot`, args: [...base, "--quit-after", "300"] });
    for (const script of scripts) {
      const rel = script.replace(/^res:\/\//, "");
      const source = readFileSync(path.join(directory, rel), "utf8");
      const isSoloJob = isSolo(source);
      const fixedFps = testFixedFps(source);
      const fixedFpsArgs = fixedFps ? ["--fixed-fps", String(fixedFps)] : [];
      const timeoutMs = testTimeoutMs(source, scale);
      const timedMs = timings[rel];
      const canBatch =
        options.batch &&
        batchSize > 1 &&
        userArgs.length === 0 &&
        hasBatchDriver &&
        !isSoloJob &&
        (!Number.isFinite(timedMs) || timedMs <= SMOKE_BATCH_TEST_MAX_MS) &&
        batchable(source);
      const job = {
        label: `${name} ${script}`,
        args: [...base, ...fixedFpsArgs, "--script", script, ...userArgs],
        test: script,
        rel,
        directory,
        fixedFps,
        ms: Number.isFinite(timedMs) ? timedMs : SMOKE_BATCH_FALLBACK_MS,
        canBatch,
        solo: isSoloJob,
        timeoutMs,
        quarantined: quarantine.has(path.posix.basename(script, ".gd")),
        quarantine: quarantineRows.find((row) => row.test === path.posix.basename(script, ".gd")),
      };
      (isSoloJob ? solo : jobs).push(job);
    }
  }
  jobs.sort((a, b) => {
    const aBoot = a.test ? 1 : 0;
    const bBoot = b.test ? 1 : 0;
    if (aBoot !== bBoot) return aBoot - bBoot;
    return (b.ms ?? 0) - (a.ms ?? 0);
  });
  results.push(...(await pool(jobs, width, { batchSize, explicitBatchSize })));
  const soloStarted = Date.now();
  results.push(...(await pool(solo, soloWidth(), { batchSize: 1 })));
  const soloSeconds = (Date.now() - soloStarted) / 1000;
  const ok = runPasses(results) && expired.length === 0;
  const slowest = [...results].sort((a, b) => b.ms - a.ms).slice(0, SLOWEST);
  console.log(`slowest ${slowest.length}:`);
  for (const result of slowest) console.log(`  ${(result.ms / 1000).toFixed(1)}s ${result.label}`);
  const skipped = results.filter((result) => result.skips.length > 0);
  if (!named && !options.bots) {
    console.log(`bot tier: ${botTierNotRun.length} not run (npm run sketch:bots)`);
    for (const name of botTierNotRun) console.log(`  ${name}`);
  }
  console.log(`skipped ${skipped.length} (passed without running every check; not a failure):`);
  for (const result of skipped) {
    console.log(`  ${result.label}`);
    for (const line of result.skips.slice(0, 3)) console.log(`    ${line}`);
  }
  for (const line of quarantineLines(quarantineRecords(results))) console.log(line);
  for (const entry of expired) console.log(expiredLine(entry));
  const unverdicted = results.filter(
    (result) => result.verdict_line === false && result.skips.length === 0,
  );
  const names = unverdicted
    .slice(0, 10)
    .map((result) => result.label.replace(/^.* res:\/\/tests\//, ""));
  console.log(
    `${unverdicted.length} tests lack a verdict line${names.length > 0 ? ` (${names.join(", ")}${unverdicted.length > names.length ? ", ..." : ""})` : ""}`,
  );
  console.log(
    `sketch:smoke ${ok ? "pass" : "fail"}: ${sketches.length} sketches, ${results.length} runs, ${width} at a time, ${solo.length} solo (${soloSeconds.toFixed(0)}s), ${((Date.now() - started) / 1000).toFixed(0)}s. Headless boot and sketch tests only; feel needs Andrew's play.`,
  );
  const receipt = buildReceipt({
    label: options.receipt,
    argv,
    root,
    git: gitState(),
    godot: godotState(),
    sketches: sketches.map((directory) => path.relative(root, directory)),
    flags: options.flags,
    width,
    lockWaitMs: waited,
    startedAt,
    wallMs: Date.now() - started,
    stems: Object.fromEntries(
      sketches.map((directory) => [path.relative(root, directory), countStems(directory)]),
    ),
    results,
    botTierNotRun,
    expired,
    timeScale: scale,
  });
  const receiptFailure = emitReceipt(receipt);
  process.exit(receiptFailure ?? (ok ? 0 : 1));
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) main();
