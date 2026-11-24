import { spawn, spawnSync } from "node:child_process";
import {
  realpathSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmdirSync,
  rmSync,
  statSync,
  unlinkSync,
  utimesSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { checkImportStamp, writeImportStamp } from "./import-stamp.mjs";
import { scratchHomeEnv, userDataEnv } from "./godot-home.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const TIMINGS_FILE = path.join(root, "scripts", "sketch-fast.timings.json");
const recordedBinary = "/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64";
function defaultGodotBinary() {
  if (process.env.GODOT_BIN) return process.env.GODOT_BIN;
  const candidates =
    process.platform === "darwin"
      ? [path.join(os.homedir(), "Applications/Godot_4.7.2.app/Contents/MacOS/Godot")]
      : ["/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64", recordedBinary];
  return candidates.find((candidate) => existsSync(candidate)) ?? recordedBinary;
}
export const binary = defaultGodotBinary();
const errorLine = /^(SCRIPT ERROR|ERROR|FAIL)\b/m;
// On macOS the headless engine reports the dummy renderer's unreleased handles and the resources
// still loaded as it shuts down, after the verdict line, on tests that end clean on Linux (13 tests
// on the wave 43 stage, 16 Nov 2026). Only macOS skips them: on Linux an exit-leak line has named
// real faults (docs/decisions.tsv, the HDRI sky cycle) and still fails the run.
const TEARDOWN_NOISE =
  /^ERROR: \d+ (?:RID allocations of type '\w*RendererDummy\w*' were leaked|resources still in use) at exit\b.*\r?\n?/gm;
export const withoutTeardownNoise = (output, platform = process.platform) =>
  platform === "darwin" ? output.replace(TEARDOWN_NOISE, "") : output;
// 180 s since 2026-10-04: the solo bot bands (alpha_posture_bands_test, bot_chain_hand_test)
// legitimately run 110 to 120 s on a loaded machine; a hang still fails, three minutes later.
const TIMEOUT_MS = 180_000;
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
const BOT_MARKER = /^#\s*smoke:\s*bots\b/;
const MARKER_LINES = 5;

// A whole-run test that legitimately outgrows the cap declares a longer one in the same
// head comment ("# smoke: solo timeout=300s"). It can only raise the cap, never past 360 s.
const TIMEOUT_MARKER = /^#\s*smoke:.*\btimeout=(\d+)s\b/;
const MAX_TIMEOUT_MS = 360_000;
// Whole-run bot proofs have a separate tier and always use the solo phase.
const MAX_BOT_TIMEOUT_MS = 1_800_000;
const BOT_TIMEOUT_MS = 1_200_000;

export function isBot(source) {
  return source.split("\n", MARKER_LINES).some((line) => BOT_MARKER.test(line.replace(/\r$/, "")));
}

// SMOKE_TIME_SCALE stretches every test's time limit on a slow machine. It applies after
// the marker and the ceiling, so it is the one way past 360 s (1800 s for bots), and it
// never touches a limit a test sets for its own child processes. A run that used it says
// so in its output and its receipt, so two runs are compared with the same scale in mind.
const MAX_TIME_SCALE = 4;

export function timeScale(env = process.env) {
  const text = env.SMOKE_TIME_SCALE;
  if (text === undefined || text === "") return 1;
  const scale = Number(text);
  if (!Number.isFinite(scale) || scale < 1 || scale > MAX_TIME_SCALE) {
    throw new Error(`SMOKE_TIME_SCALE must be a number from 1 to ${MAX_TIME_SCALE}`);
  }
  return scale;
}

export function testTimeoutMs(source, scale = 1) {
  const bots = isBot(source);
  let limit = bots ? BOT_TIMEOUT_MS : TIMEOUT_MS;
  for (const line of source.split("\n", MARKER_LINES)) {
    const match = TIMEOUT_MARKER.exec(line.replace(/\r$/, ""));
    if (match) {
      limit = Math.min(
        bots ? MAX_BOT_TIMEOUT_MS : MAX_TIMEOUT_MS,
        Math.max(TIMEOUT_MS, Number(match[1]) * 1000),
      );
      break;
    }
  }
  return Math.round(limit * scale);
}

export function isSolo(source) {
  return source
    .split("\n", MARKER_LINES)
    .some(
      (line) =>
        SOLO_MARKER.test(line.replace(/\r$/, "")) || BOT_MARKER.test(line.replace(/\r$/, "")),
    );
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
// least 2 and at most 16, and SMOKE_JOBS overrides it.
export function jobCount(env = process.env, cpus = os.cpus().length, load = os.loadavg()[0]) {
  if (env.SMOKE_JOBS) return Math.max(1, Number(env.SMOKE_JOBS) || 1);
  const idle = cpus - load;
  return Math.min(16, Math.max(2, Math.floor(idle / 2)));
}

// Concurrency width for a smoke run: bots stay at 1; explicit SMOKE_JOBS is never clamped;
// only small ad-hoc named runs (<= NAMED_WIDTH tests) stay narrow when SMOKE_JOBS is unset.
export function smokeWidth({
  bots = false,
  named = false,
  testCount = 0,
  env = process.env,
  jobs = jobCount(env),
} = {}) {
  if (bots) return 1;
  if (env.SMOKE_JOBS) return jobs;
  if (named && testCount <= NAMED_WIDTH) return Math.min(NAMED_WIDTH, jobs);
  return jobs;
}

// Warm batching (tools/test_batch.gd): runs plain SceneTree tests in one Godot process so
// game scripts compile once per batch instead of once per test. Shared with sketch-fast.mjs.
const BATCH_SOLO =
  /get_ticks_|OS\.set_environment|ProjectSettings\.set|OS\.(execute|create_process|kill)|\b(warm|hitch|cold)\b|change_scene/;
export const BATCH_MAX_TESTS = 8;
export const BATCH_MAX_MS = 60_000;
export const BATCH_TEST_MAX_MS = 15_000;

export function batchable(source) {
  return (
    /^extends SceneTree\r?$/m.test(source.split("\n", 1)[0]) &&
    !isSolo(source) &&
    !BATCH_SOLO.test(source)
  );
}

// Takes consecutive batchable rows from the front of the queue, up to maxTests and maxMs.
export function takeBatch(queue, canBatch, maxTests = BATCH_MAX_TESTS, maxMs = BATCH_MAX_MS) {
  const batch = [];
  let ms = 0;
  while (
    queue.length > 0 &&
    batch.length < maxTests &&
    canBatch(queue[0]) &&
    (batch.length === 0 || ms + (queue[0].ms ?? 0) <= maxMs)
  ) {
    ms += queue[0].ms ?? 0;
    batch.push(queue.shift());
  }
  return batch;
}

// Packs non-adjacent batchable rows while preserving their relative order in `queue`.
// If the front row is not batchable, returns [] so the caller runs it alone without starving it.
export function takeBatchPacked(queue, canBatch, maxTests = BATCH_MAX_TESTS, maxMs = BATCH_MAX_MS) {
  if (queue.length === 0 || !canBatch(queue[0])) return [];
  const batch = [queue.shift()];
  let ms = batch[0].ms ?? 0;
  let index = 0;
  while (index < queue.length && batch.length < maxTests) {
    const row = queue[index];
    const rowMs = row.ms ?? 0;
    if (canBatch(row) && ms + rowMs <= maxMs) {
      batch.push(row);
      ms += rowMs;
      queue.splice(index, 1);
    } else {
      index++;
    }
  }
  return batch;
}

// Splits a batch's output into each test's own output by its BATCH START and BATCH END lines,
// plus `outside`: lines printed outside any test slice (such as process-level exit leaks).
export function splitBatch(output, tests) {
  const done = [];
  const outsideLines = [];
  let open = null;
  let lines = [];
  for (const line of output.split("\n")) {
    const start = /^BATCH START (\S+)/.exec(line);
    const end = /^BATCH END (\S+) exit=(-?\d+) ms=(\d+)/.exec(line);
    if (start) {
      open = start[1];
      lines = [];
    } else if (end && open === end[1]) {
      done.push({ test: open, exit: Number(end[2]), ms: Number(end[3]), output: lines.join("\n") });
      open = null;
    } else if (open) {
      lines.push(line);
    } else if (!/^BATCH DONE\b/.test(line)) {
      outsideLines.push(line);
    }
  }
  const ended = new Set(done.map((row) => row.test));
  return {
    done,
    cut: open,
    rest: tests.filter((test) => !ended.has(test) && test !== open),
    outside: outsideLines.join("\n"),
  };
}

// True when a warm batch printed an engine error or exit-leak ERROR outside individual test slices
// (after stripping macOS dummy-renderer shutdown noise), matching judge()'s errorLine contract.
// Benign Godot exit WARNINGs (e.g. ObjectDB instances leaked) do not fail judge() and do not force
// solo reruns; any ERROR:/SCRIPT ERROR:/FAIL outside a test slice forces solo reruns of the batch.
export function batchHasOutsideError(outside, platform = process.platform) {
  const clean = withoutTeardownNoise(outside ?? "", platform);
  return errorLine.test(clean);
}

// Solo tests run one at a time unless SMOKE_SOLO_JOBS widens the phase. A machine with cores to
// spare can run several side by side; a test whose verdict reads wall time still wants 1.
export function soloWidth(env = process.env) {
  return Math.max(1, Math.floor(Number(env.SMOKE_SOLO_JOBS)) || 1);
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
const verdictLine = /^([\w.-]+): (PASS|FAIL)\b/gm;

export function hasVerdictLine(output, script) {
  const name = script ? path.posix.basename(script, ".gd") : null;
  return [...output.replace(/\r/g, "").matchAll(verdictLine)].some(
    (match) => name === null || match[1] === name,
  );
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

// Returns an error message, or null when the arguments are usable.
export function validateRun(options, available) {
  if (options.named && options.sketches.length !== 1)
    return "sketch:smoke --test requires exactly one --sketch";
  const missing = options.sketches.filter((name) => !available.includes(name));
  if (missing.length > 0) return `sketch:smoke has no sketch named ${missing.join(", ")}`;
  return null;
}

export function noMatchMessage(sketch, globs) {
  return `sketch:smoke found no test in ${sketch} matching ${globs.join(", ")}`;
}

// Gates and named runs use the same pool. Keep its root independent of TMPDIR so
// worktrees share the limit; all participants must use the same SMOKE_SLOTS value.
function slotRoot() {
  return path.join(process.env.SCRAPKEEP_LOCK_DIR || "/tmp", "scrapkeep-sketch-smoke.slots");
}

export function machineSlotCount(env = process.env) {
  const slots = Number(env.SMOKE_SLOTS ?? 2);
  if (!Number.isSafeInteger(slots) || slots < 1)
    throw new Error("SMOKE_SLOTS must be a positive integer");
  return slots;
}

// Kept for compatibility; liveness is the heartbeat rule below.
export const FOREIGN_CLAIM_MAX_MS = 3 * 60 * 60 * 1000;
export const HEARTBEAT_MS = 15_000;
export const STALE_CLAIM_MS = 90_000;

function slotOwner(slot) {
  try {
    const owner = readdirSync(slot).find((name) => name.startsWith("claim-"));
    if (!owner) return null;
    const pid = Number(readFileSync(path.join(slot, owner), "utf8"));
    if (!Number.isSafeInteger(pid) || pid < 1) throw new Error(`invalid slot pid in ${slot}`);
    try {
      process.kill(pid, 0);
    } catch (error) {
      if (error.code === "ESRCH") return { owner, alive: false };
      if (error.code !== "EPERM") throw error;
    }
    // Heartbeat rule: a holder refreshes its claim's mtime, so a stale mtime is dead whatever the pid says (sandbox pids are unverifiable).
    const age = Date.now() - statSync(path.join(slot, owner)).mtimeMs;
    return { owner, alive: age < STALE_CLAIM_MS };
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

// Remove only this claim's file, then an empty directory. A racing reclaimer or
// delayed release cannot recursively delete a replacement owner's populated slot.
function releaseSlot(slot, owner) {
  try {
    unlinkSync(path.join(slot, owner));
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  try {
    rmdirSync(slot);
  } catch (error) {
    if (!["ENOENT", "ENOTEMPTY", "EEXIST"].includes(error.code)) throw error;
  }
}

function touch(target) {
  const now = new Date();
  try {
    utimesSync(target, now, now);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
}

// Waiter directories of killed runners: unlink-then-rmdir, never recursive.
function sweepStaleWaiters(directory, own) {
  for (const name of readdirSync(directory)) {
    if (!name.startsWith("claim-") || name === own) continue;
    const dir = path.join(directory, name);
    try {
      if (Date.now() - statSync(dir).mtimeMs < STALE_CLAIM_MS) continue;
      releaseSlot(dir, name);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  }
}

// The quiet hold: a frame-time reading must have the machine to itself. While a reading holds this file, no runner on
// this machine takes a slot in any pool (acquireSlot waits, whatever SCRAPKEEP_LOCK_DIR says, so gate steps wait too),
// and the reading starts only once the shared pool's slots are empty. It does not see work that never takes a slot from
// the shared pool: a running gate, the nightly run, the red team, a band read or an export. Do not start a reading
// while one of those runs. A written "check pgrep first" rule was broken four times in one day (17 Nov 2026).
// The holder blocks in spawnSync and cannot heartbeat, so a hold is alive while its pid is and it is under
// QUIET_MAX_MS old.
export const QUIET_HOLD = "scrapkeep-quiet-hold";
export const QUIET_MAX_MS = 2 * 60 * 60 * 1000;
// The lock is held for a few file calls; a minute old means its holder died.
const QUIET_LOCK_STALE_MS = 60 * 1000;

function quietRoot() {
  return process.env.SCRAPKEEP_QUIET_DIR || "/tmp";
}

export function quietHolder(directory = quietRoot()) {
  const file = path.join(directory, QUIET_HOLD);
  try {
    const pid = Number(readFileSync(file, "utf8"));
    if (!Number.isSafeInteger(pid) || pid < 1) return null;
    if (Date.now() - statSync(file).mtimeMs > QUIET_MAX_MS) return null;
    try {
      process.kill(pid, 0);
    } catch (error) {
      if (error.code === "ESRCH") return null;
      if (error.code !== "EPERM") throw error;
    }
    return pid;
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

// Take the hold, then wait until no runner holds a slot in the shared pool. Synchronous, for
// scripts/frametime-check.mjs. Replacing a dead hold happens under a short lock, so two readings that start together
// cannot both take it.
export function holdQuietSync({
  directory = slotRoot(),
  quietDirectory = quietRoot(),
  pollMs = 2000,
  timeoutMs = 45 * 60 * 1000,
  pid = process.pid,
  log = console.log,
  sleepSync = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms),
} = {}) {
  mkdirSync(directory, { recursive: true });
  mkdirSync(quietDirectory, { recursive: true });
  const file = path.join(quietDirectory, QUIET_HOLD);
  const lock = file + ".lock";
  const started = Date.now();
  const late = () => Date.now() - started > timeoutMs;
  const release = () => {
    try {
      if (Number(readFileSync(file, "utf8")) === pid) unlinkSync(file);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  };
  // Returns the pid that holds after this try: ours when the hold was free or dead.
  const claim = () => {
    for (;;) {
      try {
        mkdirSync(lock);
        break;
      } catch (error) {
        if (error.code !== "EEXIST") throw error;
        if (late())
          throw new Error(`the quiet hold's lock (${lock}) is stuck; no frame reading taken`);
        try {
          if (Math.abs(Date.now() - statSync(lock).mtimeMs) > QUIET_LOCK_STALE_MS)
            rmSync(lock, { recursive: true, force: true });
        } catch (gone) {
          if (gone.code !== "ENOENT") throw gone;
        }
        sleepSync(20);
      }
    }
    try {
      const other = quietHolder(quietDirectory);
      if (other !== null) return other;
      writeFileSync(file, String(pid));
      return pid;
    } finally {
      rmSync(lock, { recursive: true, force: true });
    }
  };
  for (;;) {
    let told = false;
    for (;;) {
      const other = claim();
      if (other === pid) break;
      if (late())
        throw new Error(
          `another frame reading (pid ${other}) still holds the machine after ${Math.round(timeoutMs / 60000)} min; no frame reading taken`,
        );
      if (!told)
        log(`waiting: another frame reading (pid ${other}) holds the machine quiet (${file})`);
      told = true;
      sleepSync(pollMs);
    }
    told = false;
    let lost = false;
    for (;;) {
      const busy = readdirSync(directory).filter(
        (name) => name.startsWith("slot-") && slotOwner(path.join(directory, name))?.alive,
      );
      // Read the hold after the scan: a runner publishes its slot and then checks the hold, so one side sees the other.
      if (quietHolder(quietDirectory) !== pid) {
        lost = true;
        break;
      }
      if (busy.length === 0) break;
      if (late()) {
        release();
        throw new Error(
          `${busy.length} test runner(s) still hold the machine after ${Math.round(timeoutMs / 60000)} min; no frame reading taken`,
        );
      }
      if (!told)
        log(`waiting for ${busy.length} test runner(s) to finish before the frame reading starts`);
      told = true;
      sleepSync(pollMs);
    }
    if (!lost) break;
  }
  // The age cap counts from the start of the reading, not from the start of the wait.
  touch(file);
  return { waitMs: Date.now() - started, release };
}

export async function acquireSlot({
  directory = slotRoot(),
  slots = machineSlotCount(),
  pollMs = 2000,
  heartbeatMs = HEARTBEAT_MS,
  sleep = (ms) => new Promise((r) => setTimeout(r, ms)),
  log = console.log,
  quietDirectory = quietRoot(),
  beforePublish = () => {},
} = {}) {
  if (!Number.isSafeInteger(slots) || slots < 1)
    throw new Error("slots must be a positive integer");
  mkdirSync(directory, { recursive: true });
  const started = Date.now();
  const claim = mkdtempSync(path.join(directory, `claim-${process.pid}-`));
  const owner = path.basename(claim);
  let told = false;
  let toldQuiet = false;
  const quietWait = async () => {
    const holder = quietHolder(quietDirectory);
    if (holder === null) return false;
    if (!toldQuiet)
      log(
        `sketch:smoke waiting: a frame reading (pid ${holder}) holds the machine quiet (${path.join(quietDirectory, QUIET_HOLD)})`,
      );
    toldQuiet = true;
    await sleep(pollMs);
    return true;
  };
  try {
    writeFileSync(path.join(claim, owner), String(process.pid));
    for (;;) {
      sweepStaleWaiters(directory, owner);
      touch(claim);
      if (await quietWait()) continue;
      for (let index = 0; index < slots; index++) {
        const slot = path.join(directory, `slot-${index}`);
        const holder = slotOwner(slot);
        if (holder && !holder.alive) releaseSlot(slot, holder.owner);
        try {
          // Publish an already populated directory atomically: no pid-write gap.
          beforePublish(); // a test seam: what happens between this runner's hold check and its publish
          // A long wait leaves the owner file older than the stale window. Refresh it while the claim is still private,
          // so the slot is never visible looking stale (a rename keeps the files' mtimes).
          touch(path.join(claim, owner));
          renameSync(claim, slot);
          // Publish, then check the hold again: the reading writes its hold and then scans the slots, so a runner that
          // slipped in between gives the slot back here before it starts anything.
          if (quietHolder(quietDirectory) !== null) {
            releaseSlot(slot, owner);
            mkdirSync(claim, { recursive: true });
            writeFileSync(path.join(claim, owner), String(process.pid));
            break;
          }
          let released = false;
          const claimFile = path.join(slot, owner);
          const beat = setInterval(() => touch(claimFile), heartbeatMs);
          beat.unref();
          return {
            slot,
            waitMs: Date.now() - started,
            release: () => {
              if (released) return;
              clearInterval(beat);
              releaseSlot(slot, owner);
              released = true;
            },
          };
        } catch (error) {
          if (!["EEXIST", "ENOTEMPTY"].includes(error.code)) throw error;
        }
      }
      if (quietHolder(quietDirectory) !== null) continue;
      if (!told) log(`sketch:smoke waiting for a machine slot (${slots} occupied)`);
      told = true;
      await sleep(pollMs);
    }
  } finally {
    rmSync(claim, { recursive: true, force: true });
  }
}

export async function acquireMachine(pollMs = 2000) {
  const lease = await acquireSlot({ pollMs });
  process.once("exit", lease.release);
  return lease.waitMs;
}

export function namedRunMustWait({ directory = slotRoot(), slots = machineSlotCount() } = {}) {
  return Array.from({ length: slots }, (_, index) =>
    slotOwner(path.join(directory, `slot-${index}`)),
  ).every((holder) => holder?.alive);
}

// Retained API: named runs now acquire a slot too, rather than bypassing the limit.
export async function waitForMachine(options = {}) {
  const lease = await acquireSlot(options);
  process.once("exit", lease.release);
  return lease.waitMs;
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
  const stamp = startedAt.replace(/[:.]/g, "-");
  return `${label}-${tree ? tree.slice(0, 12) : "nogit"}-${stamp}.json`;
}

// tests/QUARANTINE.tsv lets a known-red top-level test stay visible without failing the
// run. The test still runs; the coordinator owns the file.
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

// The rows themselves, for a lane that names the owner and reason of a quarantined failure.
export function readQuarantineEntries(directory) {
  const file = path.join(directory, "tests", "QUARANTINE.tsv");
  if (!existsSync(file)) return [];
  return parseQuarantine(readFileSync(file, "utf8"));
}

export function quarantineNote(entry) {
  return `quarantined: ${entry.test} (${entry.owner}: ${entry.reason})`;
}

// A row whose deadline is an ISO date before today is expired; the run fails until the row is
// removed or its deadline is extended by the coordinator. A free-text deadline ("wave 3") is
// not enforced because it has no date to compare.
export function expiredQuarantine(entries, today = new Date().toISOString().slice(0, 10)) {
  return entries.filter(
    (entry) => /^\d{4}-\d{2}-\d{2}$/.test(entry.deadline ?? "") && entry.deadline < today,
  );
}

export function expiredLine(entry) {
  return `quarantine expired: ${entry.test} (${entry.owner}) deadline ${entry.deadline}; fix the test or have the coordinator extend the row in tests/QUARANTINE.tsv`;
}

// One receipt entry per quarantined test that ran: the row plus that run's result.
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

// Human lines for the full gate: red rows with the failing-check count and exit or signal, then stale green rows.
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

// A quarantined test never fails the run. Green, it is stale and listed for removal.
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

// A gate runs the shipping defaults, so it takes no launch flags from anywhere.
export function gateFlagsError(options) {
  if (["gate", "gate-bots"].includes(options.receipt) && options.flags.length > 0) {
    return `sketch:smoke: a gate run (--receipt ${options.receipt}) refuses launch flags from --flags or SMOKE_FLAGS because a gate runs the shipping defaults`;
  }
  return null;
}

// A run whose receipt could not be written is not evidence. Returns the exit code that
// overrides the test result (3), or null when the receipt is on disk.
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

export const MISSING_VERDICT = "no verdict line: the test ended early";

const failVerdictLine = /^[\w.-]+: FAIL\b/m;

// A test ends with one verdict line. A skip line exempts it only when no check ran. A FAIL
// verdict fails the test whatever the exit code. The reason names the cause that applies.
export function judge({ test, status, output: raw, platform = process.platform }) {
  const output = withoutTeardownNoise(raw, platform);
  // A script path binds the verdict to its file stem. Boolean callers retain the
  // legacy API until their owners supply the path (play.mjs and sketch-nightly.mjs).
  const verdict = test ? hasVerdictLine(output, typeof test === "string" ? test : undefined) : null;

  const skips = skipLines(output);
  const { passes, fails } = countChecks(output);
  const missing = verdict === false && (skips.length === 0 || passes + fails > 0);
  const failVerdict = Boolean(test) && failVerdictLine.test(output.replace(/\r/g, ""));
  const ok = status === 0 && !errorLine.test(output) && !missing && !failVerdict;
  let reason = null;
  if (status === null) reason = "the test was killed at the time limit or by a signal";
  else if (status !== 0) reason = `the test exited with code ${status}`;
  else if (missing) reason = MISSING_VERDICT;
  else if (failVerdict) reason = "the test printed a FAIL verdict";
  else if (errorLine.test(output)) reason = "the test printed an error line";
  return { ok, verdict, skips, missing, reason };
}

// The lines of a test's output that say why it failed: failed checks, engine errors and
// time-outs. A long test prints them far above its last 40 lines, so a failure lists them
// first and nobody has to patch the runner to find them.
const FAILING_LINE = /-> FAIL\b|^\s*(?:SCRIPT ERROR|ERROR|FAIL)\b|\btimed[ _]out\b/;
// A passing check can carry the words ("exit 0, timed out false -> PASS").
const PASSING_LINE = /-> PASS\b/;
const MAX_FAILING_LINES = 60;

export function failingLines(output, limit = MAX_FAILING_LINES, platform = process.platform) {
  const counts = new Map();
  for (const line of withoutTeardownNoise(output, platform)
    .split("\n")
    .map((text) => text.replace(/\r$/, ""))
    .filter((text) => FAILING_LINE.test(text) && !PASSING_LINE.test(text)))
    counts.set(line, (counts.get(line) ?? 0) + 1);
  const lines = [...counts].map(([line, count]) => (count > 1 ? `${line} (x${count})` : line));
  if (lines.length <= limit) return lines;
  return [
    ...lines.slice(0, limit),
    `... ${lines.length - limit} more failing lines (set SMOKE_LOG_DIR for the full output)`,
  ];
}

// SMOKE_LOG_DIR keeps every test's whole output, pass or fail, one file per test, so a
// gate shard can compare check lines with the last promoted head. SMOKE_FULL=1 prints the
// same output to the terminal instead.
export function logFileName(label) {
  return (
    label
      .replace(/^.* res:\/\/tests\//, "")
      .replace(/\.gd$/, "")
      .replace(/[^\w.-]+/g, "_") + ".log"
  );
}

function keepOutput(job, output, env = process.env) {
  if (env.SMOKE_LOG_DIR) {
    mkdirSync(env.SMOKE_LOG_DIR, { recursive: true });
    writeFileSync(path.join(env.SMOKE_LOG_DIR, logFileName(job.label)), output);
  }
  if (env.SMOKE_FULL) console.log(output);
}

function report(job, status, output, ms, signal = null) {
  const { ok, verdict, skips, missing, reason } = judge({ test: job.test, status, output });
  const quarantined = Boolean(job.quarantined);
  const { passes, fails } = countChecks(output);
  console.log(`${ok ? "PASS" : "FAIL"} ${job.label} exit=${status} ${(ms / 1000).toFixed(1)}s`);
  if (!ok) {
    // The runner's own reason leads: a test killed at its limit prints nothing that says so.
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

export const scriptErrorCount = (output) => (output.match(/^SCRIPT ERROR\b/gm) ?? []).length;

// One child run with its output collected and a time limit, without blocking the event loop: a held
// machine slot keeps its heartbeat only while the loop is free, and an import can take minutes.
export function spawnCollect(command, args, { env = process.env, timeoutMs = TIMEOUT_MS } = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { env, stdio: ["ignore", "pipe", "pipe"] });
    let output = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => (output += chunk));
    child.stderr.on("data", (chunk) => (output += chunk));
    let kill = null;
    const timer = setTimeout(() => {
      child.kill("SIGTERM");
      kill = setTimeout(() => child.kill("SIGKILL"), 5_000);
    }, timeoutMs);
    child.on("error", (error) => {
      clearTimeout(timer);
      clearTimeout(kill);
      resolve({ status: null, signal: null, output: output + String(error.message) });
    });
    child.on("close", (status, signal) => {
      clearTimeout(timer);
      clearTimeout(kill);
      resolve({ status, signal, output });
    });
  });
}

// Import writes the sketch's .godot cache, so it runs alone before anything reads it.
async function runImport(job) {
  const started = Date.now();
  const result = await spawnCollect(binary, job.args, {
    env: {
      ...process.env,
      ...scratchHomeEnv(() => mkdtempSync(path.join(os.tmpdir(), "sketch-smoke-"))),
    },
  });
  return {
    ...report(job, result.status, result.output, Date.now() - started, result.signal),
    scriptErrors: scriptErrorCount(result.output),
  };
}

export const IMPORT_TRIES = 3;
const CRASH_SIGNALS = new Set(["SIGSEGV", "SIGABRT"]);
const CRASH_CODES = new Set([139, 134]); // 128 + the signal, when a shell reports it

// What one import try came to. Godot 4.7.2's threaded font reimport can crash the first import of
// a fresh .godot (signal 11 or 6, "malloc(): smallbin double linked list corrupted", last line a
// .ttf): an engine race, never the project's red, and it leaves .ctex files missing, so every test
// then fails its "no script errors" checks. An import can also exit 0 while scripts that preload
// those missing files still print SCRIPT ERROR; the next import finds the files there.
export function importTry({ exit, signal = null, scriptErrors = 0 }) {
  if (exit === 0) return scriptErrors > 0 ? "script errors" : "ok";
  return CRASH_SIGNALS.has(signal) || CRASH_CODES.has(exit) ? "engine crash" : "failed";
}

// Up to IMPORT_TRIES imports, stopping at the first that exits 0 with no SCRIPT ERROR line. The
// import fails only when the last try does, so the run stops there and no test prints a misleading
// red. On a pass, `results` holds the passing try alone (earlier tries are in `tries` and the log):
// a crash that a retry cleared is not a failed row of the run.
export async function importWithRetry(name, base, run = runImport, log = console.log) {
  const tries = [];
  for (let attempt = 1; attempt <= IMPORT_TRIES; attempt++) {
    const result = await run({
      label: `${name} import${attempt > 1 ? ` (try ${attempt})` : ""}`,
      args: [...base, "--import"],
    });
    const outcome = importTry(result);
    tries.push({ ...result, outcome });
    if (outcome === "ok") return { ok: true, results: [result], tries };
    log(
      `${name} import try ${attempt} of ${IMPORT_TRIES}: ${outcome} (exit=${result.exit ?? result.signal ?? "none"})${attempt < IMPORT_TRIES ? "; trying again" : ""}`,
    );
  }
  return { ok: false, results: tries, tries };
}

// Every test gets its own data home (and on macOS its own HOME), so user:// is never shared
// between parallel runs.
function runAsync(job) {
  return new Promise((resolve) => {
    const started = Date.now();
    const dataHome = mkdtempSync(path.join(os.tmpdir(), "sketch-smoke-"));
    const child = spawn(binary, job.args, { env: { ...process.env, ...userDataEnv(dataHome) } });
    let output = "";
    child.stdout.on("data", (chunk) => (output += chunk));
    child.stderr.on("data", (chunk) => (output += chunk));
    const timer = setTimeout(() => child.kill("SIGKILL"), job.timeoutMs || TIMEOUT_MS);
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      rmSync(dataHome, { recursive: true, force: true });
      resolve(report(job, code, output, Date.now() - started, signal));
    });
  });
}

function readSmokeTimings(file = TIMINGS_FILE) {
  try {
    return JSON.parse(readFileSync(file, "utf8")).tests ?? {};
  } catch {
    return {};
  }
}

// Run a warm batch of eligible non-solo tests in one Godot process via tools/test_batch.gd.
// Any test that fails inside the batch, is cut off, or shares a batch with an outside engine
// error / exit leak / unexpected non-zero batch exit is rerun alone in a fresh Godot process
// so warm batching can never add a false red or mask an exit leak.
async function runBatchJobs(batchJobs) {
  const directory = batchJobs[0].directory;
  const rels = batchJobs.map((job) => job.rel);
  const timeoutMs = batchJobs.reduce((sum, job) => sum + (job.timeoutMs || TIMEOUT_MS), 0);
  const dataHome = mkdtempSync(path.join(os.tmpdir(), "sketch-smoke-"));
  const result = await new Promise((resolve) => {
    const child = spawn(
      binary,
      ["--headless", "--path", directory, "--script", "res://tools/test_batch.gd"],
      {
        env: {
          ...process.env,
          ...userDataEnv(dataHome),
          SCRAPKEEP_TEST_BATCH: rels.join(","),
        },
      },
    );
    let output = "";
    child.stdout.on("data", (chunk) => (output += chunk));
    child.stderr.on("data", (chunk) => (output += chunk));
    const timer = setTimeout(() => child.kill("SIGKILL"), timeoutMs);
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      rmSync(dataHome, { recursive: true, force: true });
      resolve({ code, signal, output });
    });
  });
  const { done, cut, rest, outside } = splitBatch(result.output, rels);
  const outsideLeak = batchHasOutsideError(outside);
  const unexpectedExit =
    result.signal !== null ||
    result.code === null ||
    (result.code !== 0 && done.every((row) => row.exit === 0));
  if (outsideLeak || unexpectedExit) {
    const soloResults = [];
    for (const job of batchJobs) soloResults.push(await runAsync(job));
    return soloResults;
  }
  const byRel = new Map(batchJobs.map((job) => [job.rel, job]));
  const out = [];
  const reruns = [];
  for (const row of done) {
    const job = byRel.get(row.test);
    if (!job) continue;
    const verdict = judge({ test: job.test, status: row.exit, output: row.output });
    if (verdict.ok) out.push(report(job, row.exit, row.output, row.ms, null));
    else reruns.push(job);
  }
  for (const rel of [...(cut ? [cut] : []), ...rest]) {
    const job = byRel.get(rel);
    if (job) reruns.push(job);
  }
  for (const job of reruns) out.push(await runAsync(job));
  return out;
}

async function pool(jobs, width) {
  const results = [];
  const queue = [...jobs];
  async function worker() {
    while (queue.length > 0) {
      const first = queue[0];
      const batch = first?.canBatch
        ? takeBatchPacked(
            queue,
            (row) => Boolean(row.canBatch) && row.directory === first.directory,
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
  const directory = path.join(root, "artifacts", "local", "receipts");
  mkdirSync(directory, { recursive: true });
  const file = path.join(
    directory,
    receiptFileName(receipt.label, receipt.tree, receipt.started_at),
  );
  writeFileSync(file, JSON.stringify(receipt, null, 2) + "\n");
  return file;
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
  if (!existsSync(binary)) {
    console.error(`Godot binary not found at ${binary}; set GODOT_BIN`);
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
  try {
    scale = timeScale();
  } catch (problem) {
    console.error(`sketch:smoke: ${problem.message}`);
    process.exit(2);
  }
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
    const stampOk = process.env.SMOKE_FORCE_IMPORT !== "1" && checkImportStamp(root, name).ok;
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
      writeImportStamp(root, name);
    }
    const hasBatchDriver = existsSync(path.join(directory, "tools", "test_batch.gd"));
    if (!named && !options.bots)
      jobs.push({ label: `${name} boot`, args: [...base, "--quit-after", "300"] });
    for (const script of scripts) {
      const rel = script.replace(/^res:\/\//, "");
      const source = readFileSync(path.join(directory, rel), "utf8");
      const isSoloJob = isSolo(source);
      const timeoutMs = testTimeoutMs(source, scale);
      const timedMs = timings[rel];
      const canBatch =
        options.batch &&
        userArgs.length === 0 &&
        hasBatchDriver &&
        !isSoloJob &&
        Number.isFinite(timedMs) &&
        timedMs <= BATCH_TEST_MAX_MS &&
        batchable(source);
      const job = {
        label: `${name} ${script}`,
        args: [...base, "--script", script, ...userArgs],
        test: script,
        rel,
        directory,
        ms: Number.isFinite(timedMs) ? timedMs : BATCH_TEST_MAX_MS + 1,
        canBatch,
        solo: isSoloJob,
        timeoutMs,
        quarantined: quarantine.has(path.posix.basename(script, ".gd")),
        quarantine: quarantineRows.find((row) => row.test === path.posix.basename(script, ".gd")),
      };
      (isSoloJob ? solo : jobs).push(job);
    }
  }
  // Run longest-estimated parallel tests first (LPT) so slow/unbatched tests start at t=0
  // instead of tailing at the end of a chunk; boot stays first and solo keeps its order.
  jobs.sort((a, b) => {
    const aBoot = a.test ? 1 : 0;
    const bBoot = b.test ? 1 : 0;
    if (aBoot !== bBoot) return aBoot - bBoot;
    return (b.ms ?? 0) - (a.ms ?? 0);
  });
  results.push(...(await pool(jobs, width)));
  const soloStarted = Date.now();
  results.push(...(await pool(solo, soloWidth())));
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

// Node resolves the module's own path through symlinks, so the launch path must be resolved too
// (macOS keeps its temp folder behind one).
if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) main();
