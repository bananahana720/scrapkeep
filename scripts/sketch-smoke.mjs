import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const recordedBinary =
  "/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64";
export const binary = process.env.GODOT_BIN || recordedBinary;
const errorLine = /^(SCRIPT ERROR|ERROR|FAIL)\b/m;
const TIMEOUT_MS = 120_000;
const SLOWEST = 10;
const RECEIPT_SCHEMA = "scrapkeep-smoke-receipt/1";
const NAMED_WIDTH = 2;

export function sketchDirectories(sketchRoot) {
  if (!existsSync(sketchRoot)) return [];
  return readdirSync(sketchRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join(sketchRoot, entry.name))
    .filter((directory) => existsSync(path.join(directory, "project.godot")))
    .sort();
}

export function testScripts(directory) {
  const tests = path.join(directory, "tests");
  if (!existsSync(tests)) return [];
  return readdirSync(tests)
    .filter((name) => name.endsWith(".gd"))
    .sort()
    .map((name) => "res://tests/" + name);
}

// A test whose pass or fail reads a wall-clock measurement (a CPU or frame-time cap, a
// real-time freeze) declares it in a comment among its first lines: "# smoke: solo". The
// runner runs those files one at a time after the parallel batch, so load from sibling
// tests cannot push the measurement over its cap. Only the head of the file is read, so
// a mention further down (or in a string) does not opt a test in.
const SOLO_MARKER = /^#\s*smoke:\s*solo\b/;
const MARKER_LINES = 5;

export function isSolo(source) {
  return source
    .split("\n", MARKER_LINES)
    .some((line) => SOLO_MARKER.test(line.replace(/\r$/, "")));
}

export function isSoloScript(directory, script) {
  try {
    return isSolo(readFileSync(path.join(directory, script.replace(/^res:\/\//, "")), "utf8"));
  } catch {
    return false;
  }
}

// Each headless Godot is one mostly single-threaded process, so tests run side by side.
// The pool sizes itself to the idle cores (other agents share this machine), keeps at
// least 2 and at most 8, and SMOKE_JOBS overrides it.
export function jobCount() {
  if (process.env.SMOKE_JOBS) return Math.max(1, Number(process.env.SMOKE_JOBS) || 1);
  const idle = os.cpus().length - os.loadavg()[0];
  return Math.min(8, Math.max(2, Math.floor(idle / 3)));
}

// A test that prints SKIP, or "N skipped" with N above zero, passed without checking
// something. The run still passes, but the summary lists it so a missing asset stays visible.
const skipWord = /\bSKIP\b/;
const skippedCount = /\b([1-9]\d*) skipped\b/;

export function skipLines(output) {
  return output
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => skipWord.test(line) || skippedCount.test(line));
}

// CONTRACTS.md: a test prints one line per check ending in "-> PASS" or "-> FAIL" and a
// final "NAME: PASS" line. Some tests print no check lines, so the counts are tolerant.
const verdictLine = /^[\w.-]+: (PASS|FAIL)\b/m;

export function hasVerdictLine(output) {
  return verdictLine.test(output.replace(/\r/g, ""));
}

export function countChecks(output) {
  const lines = output.split("\n");
  return {
    passes: lines.filter((line) => line.includes("-> PASS")).length,
    fails: lines.filter((line) => line.includes("-> FAIL")).length,
  };
}

// --test GLOB matches a test file's base name; * is the only wildcard and a trailing .gd
// on either side is ignored.
export function globToRegExp(glob) {
  const body = glob
    .replace(/\.gd$/, "")
    .split("*")
    .map((part) => part.replace(/[.+?^${}()|[\]\\]/g, "\\$&"))
    .join(".*");
  return new RegExp(`^${body}$`);
}

export function matchesGlob(glob, name) {
  return globToRegExp(glob).test(name.replace(/\.gd$/, ""));
}

export function selectTests(scripts, globs) {
  return scripts.filter((script) => {
    const name = path.posix.basename(script);
    return globs.some((glob) => matchesGlob(glob, name));
  });
}

export function splitFlags(text) {
  return (text || "").split(/\s+/).filter(Boolean);
}

export function parseArgs(argv, env = {}) {
  const options = { sketches: [], tests: [], flags: null, receipt: null, strict: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--sketch" && argv[i + 1]) options.sketches.push(argv[++i]);
    else if (arg === "--test" && argv[i + 1]) options.tests.push(argv[++i]);
    else if (arg === "--flags" && argv[i + 1] !== undefined) options.flags = argv[++i];
    else if (arg === "--receipt" && argv[i + 1]) options.receipt = argv[++i];
    else if (arg === "--strict-verdict") options.strict = true;
  }
  options.flags = splitFlags(options.flags ?? env.SMOKE_FLAGS);
  options.named = options.tests.length > 0;
  options.receipt ??= options.named ? "named" : "smoke";
  return options;
}

// Returns an error message, or null when the arguments are usable.
export function validateRun(options, available) {
  if (options.named && options.sketches.length !== 1) return "sketch:smoke --test requires exactly one --sketch";
  const missing = options.sketches.filter((name) => !available.includes(name));
  if (missing.length > 0) return `sketch:smoke has no sketch named ${missing.join(", ")}`;
  return null;
}

export function noMatchMessage(sketch, globs) {
  return `sketch:smoke found no test in ${sketch} matching ${globs.join(", ")}`;
}

// Parallel lanes share one machine. Each run sizes its pool from the idle cores, so
// several runs starting together all see idle cores and overload it (load 73 on 32
// threads, 2026-09-29, turned healthy tests into timeouts). One full run holds the machine
// at a time; the others wait, then size their pool from the load they find. The directory
// is fixed to /tmp, not os.tmpdir(), so agents with different TMPDIR values share it.
function lockPath() {
  return path.join(process.env.SCRAPKEEP_LOCK_DIR || "/tmp", "scrapkeep-sketch-smoke.lock");
}

function lockHolder() {
  try {
    const pid = Number(readFileSync(path.join(lockPath(), "pid"), "utf8"));
    process.kill(pid, 0);
    return pid;
  } catch {
    return 0;
  }
}

export async function acquireMachine(pollMs = 2000) {
  const lock = lockPath();
  const started = Date.now();
  let told = false;
  for (;;) {
    try {
      mkdirSync(lock);
      writeFileSync(path.join(lock, "pid"), String(process.pid));
      process.on("exit", () => rmSync(lock, { recursive: true, force: true }));
      return Date.now() - started;
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
      const holder = lockHolder();
      if (!holder && Date.now() - started > pollMs) rmSync(lock, { recursive: true, force: true });
      if (!told) console.log(`sketch:smoke waiting for another run to finish (pid ${holder || "unknown"})`);
      told = true;
      await new Promise((resolve) => setTimeout(resolve, pollMs));
    }
  }
}

// A named run never takes the lock; it only yields while a live full run holds it.
export function namedRunMustWait(holderCheck = lockHolder) {
  return holderCheck() > 0;
}

export async function waitForMachine({ pollMs = 2000, holderCheck = lockHolder, sleep = (ms) => new Promise((r) => setTimeout(r, ms)) } = {}) {
  const started = Date.now();
  let told = false;
  while (namedRunMustWait(holderCheck)) {
    if (!told) console.log(`sketch:smoke waiting for a full run to finish (pid ${holderCheck()})`);
    told = true;
    await sleep(pollMs);
  }
  return Date.now() - started;
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
  return readdirSync(music, { recursive: true }).filter((name) => String(name).endsWith(".ogg")).length;
}

export function receiptFileName(label, tree, startedAt) {
  const stamp = startedAt.replace(/[:.]/g, "-");
  return `${label}-${tree ? tree.slice(0, 12) : "nogit"}-${stamp}.json`;
}

export function buildReceipt({ label, argv, root: repoRoot, git: gitInfo, godot, sketches, flags, width, lockWaitMs, startedAt, wallMs, stems, results }) {
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
  }));
  const totals = {
    runs: rows.length,
    failed: rows.filter((row) => !row.ok).length,
    skipped: rows.filter((row) => row.skips.length > 0).length,
    missing_verdict: rows.filter((row) => row.verdict_line === false).length,
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
    width,
    lock_wait_ms: lockWaitMs,
    started_at: startedAt,
    wall_ms: wallMs,
    stems,
    results: rows,
    totals,
    ok: totals.failed === 0,
  };
}

// A job with a verdict check (a test, not an import or boot) reports whether it printed one.
function report(job, status, output, ms, strict) {
  const checks = job.test ? hasVerdictLine(output) : null;
  const clean = status === 0 && !errorLine.test(output);
  const ok = clean && !(strict && checks === false);
  const skips = skipLines(output);
  const { passes, fails } = countChecks(output);
  console.log(`${ok ? "PASS" : "FAIL"} ${job.label} exit=${status} ${(ms / 1000).toFixed(1)}s`);
  if (!ok) console.log(output.split("\n").slice(-40).join("\n"));
  if (process.env.SMOKE_DEBUG_ARGS) console.log(`  args: ${job.args.join(" ")}`);
  return { label: job.label, ok, exit: status, ms, solo: Boolean(job.solo), passes, fails, verdict_line: checks, skips, test: Boolean(job.test) };
}

// Import writes the sketch's .godot cache, so it runs alone before anything reads it.
function runSync(job, strict) {
  const started = Date.now();
  const result = spawnSync(binary, job.args, { encoding: "utf8", timeout: TIMEOUT_MS });
  return report(job, result.status, (result.stdout || "") + (result.stderr || ""), Date.now() - started, strict);
}

// Every test gets its own XDG_DATA_HOME, so user:// is never shared between parallel runs.
function runAsync(job, strict) {
  return new Promise((resolve) => {
    const started = Date.now();
    const dataHome = mkdtempSync(path.join(os.tmpdir(), "sketch-smoke-"));
    const child = spawn(binary, job.args, { env: { ...process.env, XDG_DATA_HOME: dataHome } });
    let output = "";
    child.stdout.on("data", (chunk) => (output += chunk));
    child.stderr.on("data", (chunk) => (output += chunk));
    const timer = setTimeout(() => child.kill("SIGKILL"), TIMEOUT_MS);
    child.on("close", (code) => {
      clearTimeout(timer);
      rmSync(dataHome, { recursive: true, force: true });
      resolve(report(job, code, output, Date.now() - started, strict));
    });
  });
}

async function pool(jobs, width, strict) {
  const results = [];
  let next = 0;
  async function worker() {
    while (next < jobs.length) {
      const job = jobs[next++];
      results.push(await runAsync(job, strict));
    }
  }
  await Promise.all(Array.from({ length: Math.min(width, jobs.length) }, worker));
  return results;
}

function writeReceipt(receipt) {
  const directory = path.join(root, "artifacts", "local", "receipts");
  mkdirSync(directory, { recursive: true });
  const file = path.join(directory, receiptFileName(receipt.label, receipt.tree, receipt.started_at));
  writeFileSync(file, JSON.stringify(receipt, null, 2) + "\n");
  return file;
}

async function main() {
  const argv = process.argv.slice(2);
  const options = parseArgs(argv, process.env);
  const all = sketchDirectories(path.join(root, "sketches"));
  const error = validateRun(options, all.map((directory) => path.basename(directory)));
  if (error) {
    console.error(error);
    process.exit(2);
  }
  const sketches = options.sketches.length === 0 ? all : all.filter((directory) => options.sketches.includes(path.basename(directory)));
  if (!existsSync(binary)) {
    console.error(`Godot binary not found at ${binary}; set GODOT_BIN`);
    process.exit(2);
  }
  if (sketches.length === 0) {
    console.log("sketch:smoke found no sketches/*/project.godot");
    return;
  }
  const named = options.named;
  const plans = sketches.map((directory) => {
    const scripts = named ? selectTests(testScripts(directory), options.tests) : testScripts(directory);
    return { directory, scripts };
  });
  if (named && plans[0].scripts.length === 0) {
    console.error(noMatchMessage(path.basename(plans[0].directory), options.tests));
    process.exit(2);
  }
  const waited = named ? await waitForMachine() : await acquireMachine();
  if (waited > 0) console.log(`sketch:smoke waited ${(waited / 1000).toFixed(0)}s for the machine`);
  const width = named ? Math.min(NAMED_WIDTH, jobCount()) : jobCount();
  const startedAt = new Date().toISOString();
  const started = Date.now();
  const results = [];
  const jobs = [];
  const solo = [];
  const userArgs = options.flags.length > 0 ? ["--", ...options.flags] : [];
  for (const { directory, scripts } of plans) {
    const name = path.relative(root, directory);
    const base = ["--headless", "--path", directory];
    results.push(runSync({ label: `${name} import`, args: [...base, "--import"] }, options.strict));
    if (!named) jobs.push({ label: `${name} boot`, args: [...base, "--quit-after", "300"] });
    for (const script of scripts) {
      const isSoloJob = isSoloScript(directory, script);
      const job = { label: `${name} ${script}`, args: [...base, "--script", script, ...userArgs], test: true, solo: isSoloJob };
      (isSoloJob ? solo : jobs).push(job);
    }
  }
  results.push(...(await pool(jobs, width, options.strict)));
  const soloStarted = Date.now();
  for (const job of solo) results.push(await runAsync(job, options.strict));
  const soloSeconds = (Date.now() - soloStarted) / 1000;
  const ok = results.every((result) => result.ok);
  const slowest = [...results].sort((a, b) => b.ms - a.ms).slice(0, SLOWEST);
  console.log(`slowest ${slowest.length}:`);
  for (const result of slowest) console.log(`  ${(result.ms / 1000).toFixed(1)}s ${result.label}`);
  const skipped = results.filter((result) => result.skips.length > 0);
  console.log(`skipped ${skipped.length} (passed without running every check; not a failure):`);
  for (const result of skipped) {
    console.log(`  ${result.label}`);
    for (const line of result.skips.slice(0, 3)) console.log(`    ${line}`);
  }
  const unverdicted = results.filter((result) => result.verdict_line === false);
  const names = unverdicted.slice(0, 10).map((result) => result.label.replace(/^.* res:\/\/tests\//, ""));
  console.log(
    `${unverdicted.length} tests lack a verdict line${names.length > 0 ? ` (${names.join(", ")}${unverdicted.length > names.length ? ", ..." : ""})` : ""}${options.strict ? "; --strict-verdict counts them as failures" : ""}`,
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
    stems: Object.fromEntries(sketches.map((directory) => [path.relative(root, directory), countStems(directory)])),
    results,
  });
  console.log(`receipt ${writeReceipt(receipt)}`);
  process.exit(ok ? 0 : 1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
