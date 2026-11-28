import { existsSync, readdirSync, readFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { withScratchGodotEnv } from "../godot-home.mjs";
import { runProcess } from "./proc.mjs";

const errorLine = /^(SCRIPT ERROR|ERROR|FAIL)\b/m;
const TEARDOWN_NOISE =
  /^ERROR: \d+ (?:RID allocations of type '\w*RendererDummy\w*' were leaked|resources still in use) at exit\b.*\r?\n?/gm;

export const withoutTeardownNoise = (output, platform = process.platform) =>
  platform === "darwin" ? output.replace(TEARDOWN_NOISE, "") : output;

export const TIMEOUT_MS = 180_000;
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

const SOLO_MARKER = /^#\s*smoke:\s*solo\b/;
const BOT_MARKER = /^#\s*smoke:\s*bots\b/;
const FIXED_FPS_MARKER = /^#\s*smoke:.*\bfixed-fps=(\d+)\b/;
const MAX_FIXED_FPS = 1000;
const MARKER_LINES = 5;

const TIMEOUT_MARKER = /^#\s*smoke:.*\btimeout=(\d+)s\b/;
const MAX_TIMEOUT_MS = 360_000;
const MAX_BOT_TIMEOUT_MS = 1_800_000;
const BOT_TIMEOUT_MS = 1_200_000;

export function isBot(source) {
  return source.split("\n", MARKER_LINES).some((line) => BOT_MARKER.test(line.replace(/\r$/, "")));
}

export function testFixedFps(source) {
  for (const line of source.split("\n", MARKER_LINES)) {
    const match = FIXED_FPS_MARKER.exec(line.replace(/\r$/, ""));
    if (match) {
      const fps = Number(match[1]);
      if (Number.isSafeInteger(fps) && fps >= 1 && fps <= MAX_FIXED_FPS) return fps;
    }
  }
  return null;
}

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

export function jobCount(env = process.env, cpus = os.cpus().length, load = os.loadavg()[0]) {
  if (env.SMOKE_JOBS) return Math.max(1, Number(env.SMOKE_JOBS) || 1);
  const idle = cpus - load;
  return Math.min(16, Math.max(2, Math.floor(idle * 0.75)));
}

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

const BATCH_SOLO =
  /get_ticks_|OS\.set_environment|ProjectSettings\.set|OS\.(execute|create_process|kill)|\b(warm|hitch|cold)\b|change_scene|take_over_path/;
export const BATCH_MAX_TESTS = 8;
export const BATCH_MAX_MS = 60_000;
export const BATCH_TEST_MAX_MS = 15_000;
export const SMOKE_BATCH_SIZE_DEFAULT = 24;
export const SMOKE_BATCH_TEST_MAX_MS = 25_000;
export const SMOKE_BATCH_FALLBACK_MS = 10_000;

export function smokeBatchSize(env = process.env) {
  const raw = env.SMOKE_BATCH_SIZE;
  if (raw === undefined || raw === "") return SMOKE_BATCH_SIZE_DEFAULT;
  const size = Number(raw);
  if (!Number.isSafeInteger(size) || size < 1) {
    throw new Error("SMOKE_BATCH_SIZE must be a positive integer");
  }
  return size;
}

export function batchable(source) {
  const firstCode =
    source
      .split("\n")
      .map((line) => line.replace(/\r$/, "").trim())
      .find((line) => line !== "" && !line.startsWith("#")) ?? "";
  return /^extends SceneTree$/.test(firstCode) && !isSolo(source) && !BATCH_SOLO.test(source);
}

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

export function batchHasOutsideError(outside, platform = process.platform) {
  const clean = withoutTeardownNoise(outside ?? "", platform);
  return errorLine.test(clean);
}

export function evaluateBatchOutput(
  output,
  tests,
  { code = 0, signal = null, platform = process.platform } = {},
) {
  const { done, cut, rest, outside } = splitBatch(output, tests);
  const outsideError = batchHasOutsideError(outside, platform);
  const unexpectedExit =
    signal !== null || code === null || (code !== 0 && done.every((row) => row.exit === 0));
  return {
    done,
    cut,
    rest,
    outside,
    outsideError,
    unexpectedExit,
    tainted: outsideError || unexpectedExit,
  };
}

export async function runGodotBatch({
  binary,
  sketchDir,
  tests,
  timeoutMs,
  fixedFps = null,
  prefix = "godot-batch-",
  onChild,
  platform = process.platform,
}) {
  const fpsArgs = fixedFps ? ["--fixed-fps", String(fixedFps)] : [];
  let spawned = null;
  const result = await withScratchGodotEnv(
    (env) =>
      runProcess(
        binary,
        ["--headless", ...fpsArgs, "--path", sketchDir, "--script", "res://tools/test_batch.gd"],
        {
          env: { ...env, SCRAPKEEP_TEST_BATCH: tests.join(",") },
          timeoutMs,
          onChild: (child) => {
            spawned = child;
            onChild?.(child);
          },
        },
      ),
    { prefix, dirs: null },
  );
  return {
    ...evaluateBatchOutput(result.output, tests, {
      code: result.exit,
      signal: result.signal,
      platform,
    }),
    code: result.exit,
    signal: result.signal,
    output: result.output,
    timedOut: result.timedOut,
    child: spawned,
  };
}

export function soloWidth(env = process.env, cpus = os.cpus().length) {
  if (env.SMOKE_SOLO_JOBS !== undefined && env.SMOKE_SOLO_JOBS !== "") {
    const requested = Math.floor(Number(env.SMOKE_SOLO_JOBS));
    if (Number.isFinite(requested) && requested >= 1) {
      return Math.min(requested, Math.max(1, cpus));
    }
  }
  return 1;
}

const skipWord = /\bSKIP\b/;
const skippedCount = /\b([1-9]\d*) skipped\b/;

export function skipLines(output) {
  return output
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => skipWord.test(line) || skippedCount.test(line));
}

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

export function globToRegExp(glob) {
  const body = glob
    .split("*")
    .map((part) => part.replace(/[.+?^${}()|[\]\\]/g, "\\$&"))
    .join(".*");
  return new RegExp(`^${body}$`);
}

export function matchesGlob(glob, name) {
  return globToRegExp(glob.replace(/\.gd$/, "")).test(name.replace(/\.gd$/, ""));
}

export function selectTests(scripts, globs) {
  return scripts.filter((script) => {
    const name = path.posix.basename(script);
    return globs.some((glob) => matchesGlob(glob, name));
  });
}

export const MISSING_VERDICT = "no verdict line: the test ended early";

const failVerdictLine = /^[\w.-]+: FAIL\b/m;

export function judge({ test, status, output: raw, platform = process.platform }) {
  const output = withoutTeardownNoise(raw, platform);
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

const FAILING_LINE = /-> FAIL\b|^\s*(?:SCRIPT ERROR|ERROR|FAIL)\b|\btimed[ _]out\b/;
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

export function logFileName(label) {
  return (
    label
      .replace(/^.* res:\/\/tests\//, "")
      .replace(/\.gd$/, "")
      .replace(/[^\w.-]+/g, "_") + ".log"
  );
}

export const scriptErrorCount = (output) => (output.match(/^SCRIPT ERROR\b/gm) ?? []).length;

export const IMPORT_TRIES = 3;
const CRASH_SIGNALS = new Set(["SIGSEGV", "SIGABRT"]);
const CRASH_CODES = new Set([139, 134]);

export function importTry({ exit, signal = null, scriptErrors = 0 }) {
  if (exit === 0) return scriptErrors > 0 ? "script errors" : "ok";
  return CRASH_SIGNALS.has(signal) || CRASH_CODES.has(exit) ? "engine crash" : "failed";
}

export async function importWithRetry(name, base, run, log = console.log) {
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
