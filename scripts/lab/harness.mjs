// The trial harness (JL-11): runs N trials of one scenario for one arm, one
// <io> directory per trial, over protocol v1 (tools/jev-player/protocol/
// PROTOCOL.md), and writes one scrapkeep-run/1 record per batch.
//
// Godot is whatever `launch({io, scenario, seed, trial})` names as
// {command, args}. fakeGodot() points it at scripts/lab/fake-godot.mjs; the
// real Godot runner (JL-17) plugs in through the same function.
//
// Outcomes follow PROTOCOL.md's "Timeouts and exit codes" table: complete,
// aborted, error:<code>, stall, crash, invalid. Two Node-side decisions:
//   - A Godot file that fails its validator (hello or a state) ends the trial
//     as `invalid`. Node writes abort.json with reason `arm_error` first, so
//     Godot finishes at once instead of blocking 30 s for an intent that will
//     never come. v1's abort reasons are closed; arm_error is the nearest one
//     (Node, not the engine, cannot go on), and the message names the file.
//   - An arm that throws, answers an intent that fails validateIntent(), or is
//     refused by the per-batch call cap also aborts with `arm_error`; Godot
//     then writes done.json {reason: aborted} and the outcome is `aborted`.
//     A replaying jev arm with no cached verdict aborts with `replay_miss`.
//   - A jev verdict from a model other than the batch's anchor aborts with
//     cause `model_mismatch`, which voids the batch: the instrument changed
//     under it. The trial ends `aborted` and the batch stops there.
// A live jev batch runs preflight.mjs's controls first, through the batch's
// own decideFn. A failed preflight returns exit 6 before any run record or
// Godot process exists. The preflight's one resolved model anchors the batch:
// a cached verdict from another model is a miss, asked again live and counted
// in config.model_mismatches. A replay makes no call, so it runs no preflight
// and is anchored on its first verdict's model instead.
// abort.json carries only the protocol reason. The trial entry in the run
// record adds abort.cause (ABORT_EFFECT's keys), which decides what the abort
// means for the batch and feeds api_error_rate. trial_abort_rate counts every
// trial whose outcome is not `complete`; engine_crash counts `crash` trials.
//
// Trial i of a batch with seed s runs with seed s * 1000 + i, so batches whose
// seeds differ share no trial seed; a batch is therefore capped at 1000 trials.
//
//   node scripts/lab/harness.mjs <scenario> [--arm scripted|random|jev]
//     [-n trials] [--seed N] [--call-cap N] [--root runs-dir]
//     [--cache verdict-dir] [--replay]
//     [--stall-at N | --crash-at N | --invalid-at N | --error-at N]
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdir, readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { performance } from "node:perf_hooks";
import { setTimeout as sleep } from "node:timers/promises";
import { fileURLToPath } from "node:url";

import {
  decide,
  instrumentIdentity,
  loadQuestionSet,
} from "../../tools/jev-player/decide.mjs";
import {
  beforeJevBatch,
  loadControls,
  PREFLIGHT_EXIT,
} from "../../tools/jev-player/preflight.mjs";
import {
  ARMS,
  fileName,
  offeredOptions,
  PROTOCOL,
  validateAbort,
  validateHello,
  validateIntent,
  validateState,
  validateTrial,
  WATCHDOG_FLOOR_MS,
  watchdogMs,
  writeAtomic,
} from "../../tools/jev-player/protocol/protocol.mjs";
import { createArm } from "./arms.mjs";
import { METRICS } from "./metrics/index.mjs";
import { EXIT } from "./metrics/status.mjs";
import { createRun } from "./record.mjs";
import { wilson } from "./stats.mjs";
import {
  anchoredCache,
  openVerdictCache,
  VERDICT_CACHE_ROOT,
} from "./verdict-cache.mjs";

export const FAKE_GODOT = fileURLToPath(
  new URL("./fake-godot.mjs", import.meta.url),
);

// callCap is the runaway guard EV-0484 asks JL-11 for: the most arm calls one
// batch may make. Forced answers never count. 1000 is provisional; it covers
// twenty trials of the longest scripted scenario many times over. For the jev
// arm a cache hit is still an arm call, so live Jev calls never exceed it.
export const DEFAULTS = Object.freeze({
  trials: 1,
  seed: 1,
  callCap: 1000,
  watchdogFloorMs: WATCHDOG_FLOOR_MS,
  pollMs: 10,
});

export const TRIAL_SEED_STRIDE = 1000;

// What each Node-side abort cause says about the batch. An API failure or the
// call cap says nothing about the game, so it can only leave the batch
// inconclusive; a broken arm or answer, or a replay that cannot reproduce, is
// a failure of the run itself. A verdict from another model means the
// instrument moved, so it voids the batch. A cause not listed here fails.
const ABORT_EFFECT = {
  node_invalid: "invalid",
  model_mismatch: "invalid",
  arm_throw: "fail",
  intent_invalid: "fail",
  replay_miss: "fail",
  call_cap: "inconclusive",
  api_error: "inconclusive",
};

// Worst first: an invalid instrument voids the batch, then any conclusive
// failure (crash, stall, error:*, a failing abort) outranks an inconclusive
// trial, so a cap or an API error later in a batch cannot hide a crash.
const RESULT_ORDER = ["invalid", "fail", "inconclusive", "pass"];

function trialEffect({ outcome, abort }) {
  if (outcome === "complete") return "pass";
  if (outcome === "invalid") return "invalid";
  if (
    outcome === "aborted" &&
    abort !== null &&
    Object.hasOwn(ABORT_EFFECT, abort.cause ?? "")
  ) {
    return ABORT_EFFECT[abort.cause];
  }
  return "fail";
}

// runBatch's argument errors; the CLI exits EXIT.usage on these alone.
export class UsageError extends Error {
  name = "UsageError";
}

export function batchResult(trials) {
  const effects = new Set(trials.map(trialEffect));
  return RESULT_ORDER.find((result) => effects.has(result));
}

const slug = /^[a-z0-9][a-z0-9-]*$/;
const MAX_ERRORS = 50;

// PROTOCOL.md's limit, max(floor, 20 x nearest-rank median step), with the
// floor injectable so tests need not wait 30 s. watchdogMs() owns the formula
// with a fixed 30 s floor; scaling every step by 30 s / floor and the result
// back again gives the same formula at any floor, without a second copy of it.
export function watchdogLimit(stepsMs, floorMs = WATCHDOG_FLOOR_MS) {
  if (floorMs === WATCHDOG_FLOOR_MS) return watchdogMs(stepsMs);
  const scale = WATCHDOG_FLOOR_MS / floorMs;
  return watchdogMs(stepsMs.map((step) => step * scale)) / scale;
}

export function fakeGodot({ stallAt, crashAt, invalidAt, errorAt } = {}) {
  const flags = [];
  for (const [flag, value] of [
    ["--stall-at", stallAt],
    ["--crash-at", crashAt],
    ["--invalid-at", invalidAt],
    ["--error-at", errorAt],
  ]) {
    if (value !== undefined) flags.push(flag, String(value));
  }
  const launch = ({ io, scenario, seed }) => ({
    command: process.execPath,
    args: [
      FAKE_GODOT,
      "--io",
      io,
      "--scenario",
      scenario,
      "--seed",
      String(seed),
      ...flags,
    ],
  });
  launch.label = ["fake-godot", ...flags].join(" ");
  return launch;
}

async function readJson(io, name) {
  try {
    return { value: JSON.parse(await readFile(path.join(io, name), "utf8")) };
  } catch {
    return { errors: [{ path: "(root)", message: "is not JSON" }] };
  }
}

function parseOrUndefined(text) {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

async function readTrialFiles(io) {
  const files = {};
  for (const name of await readdir(io)) {
    if (!name.endsWith(".tmp")) {
      files[name] = await readFile(path.join(io, name), "utf8");
    }
  }
  return files;
}

const medianOf = (values) => {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  return Number(sorted[Math.ceil(sorted.length / 2) - 1].toFixed(1));
};

async function runTrial({
  trial,
  io,
  scenario,
  armName,
  arm,
  seed,
  launch,
  floorMs,
  pollMs,
  budget,
  run,
  anchor,
}) {
  await mkdir(io, { recursive: true });
  const entry = {
    trial,
    io: null,
    seed,
    outcome: null,
    trace_hash: null,
    abort: null,
    exit: { code: null, signal: null },
    snapshots: 0,
    intents: 0,
    forced: 0,
    arm_calls: 0,
    median_step_ms: null,
    watchdog_ms: null,
    waiting_for: null,
    events_tmp_only: false,
    errors: [],
  };
  const { command, args } = launch({ io, scenario, seed, trial });
  const child = spawn(command, args, { stdio: ["ignore", "ignore", "pipe"] });
  let stderr = "";
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk) => {
    stderr = (stderr + chunk).slice(-2000);
  });
  let gone = false;
  const exited = new Promise((resolve) => {
    child.on("exit", (code, signal) => {
      entry.exit = { code, signal };
      gone = true;
      resolve();
    });
    child.on("error", (error) => {
      stderr += error.message;
      gone = true;
      resolve();
    });
  });

  const steps = [];
  let afterIntent = false;
  let stalled = false;
  let rejected = null; // a Godot file Node refused: {file, errors}
  let abort = null; // what Node writes to abort.json

  const kill = async (waitingFor) => {
    stalled = true;
    entry.waiting_for = waitingFor;
    child.kill("SIGKILL");
    await exited;
  };
  // Polls for the first of `names`. The watchdog runs only while Node waits
  // for Godot: from spawn, from hello, and from each intent's rename; never
  // while an arm is choosing.
  const waitFor = async (names) => {
    const limit = watchdogLimit(steps, floorMs);
    entry.watchdog_ms = limit;
    const started = performance.now();
    for (;;) {
      const exitedBefore = gone;
      const present = new Set(await readdir(io));
      const hit = names.find((name) => present.has(name));
      if (hit !== undefined) {
        if (afterIntent) steps.push(performance.now() - started);
        afterIntent = false;
        return hit;
      }
      if (exitedBefore) return null;
      if (performance.now() - started > limit) {
        await kill(names[0]);
        return null;
      }
      await sleep(pollMs);
    }
  };

  try {
    if (
      (await waitFor(["hello.json", "done.json", "error.json"])) ===
      "hello.json"
    ) {
      const hello = await readJson(io, "hello.json");
      const errors = hello.errors ?? validateHello(hello.value);
      if (errors.length === 0 && hello.value.scenario !== scenario) {
        errors.push({ path: "scenario", message: `must be ${scenario}` });
      }
      if (errors.length > 0) rejected = { file: "hello.json", errors };
      for (let seq = 0; rejected === null && abort === null; seq += 1) {
        const name = fileName("state", seq);
        if ((await waitFor([name, "done.json", "error.json"])) !== name) break;
        const read = await readJson(io, name);
        const stateErrors = read.errors ?? validateState(read.value);
        if (stateErrors.length > 0) {
          rejected = { file: name, errors: stateErrors };
          break;
        }
        const state = read.value;
        entry.snapshots += 1;
        const offered = offeredOptions(state.jev);
        let choice;
        if (offered.length === 1) {
          // One offered option: the answer is fixed, so no arm is asked.
          choice = {
            intent: offered[0].id,
            source: "forced",
            meta: arm.forcedMeta(),
          };
          entry.forced += 1;
        } else if (budget.used >= budget.cap) {
          budget.capped = true;
          abort = {
            reason: "arm_error",
            cause: "call_cap",
            message: `the batch call cap of ${budget.cap} arm calls is reached`,
          };
          break;
        } else {
          budget.used += 1;
          entry.arm_calls += 1;
          try {
            choice = await arm.choose({
              seq,
              state: state.jev.state,
              offered,
              jev: state.jev,
            });
            if (choice.jev !== undefined) {
              const model = choice.jev.model ?? null;
              const expected = anchor.model ?? run.provenance.jev.model;
              if (expected !== null && model !== expected) {
                abort = {
                  reason: "arm_error",
                  cause: "model_mismatch",
                  message: `${armName} arm: a ${choice.source} verdict came from ${model}, but the batch is anchored on ${expected}`,
                };
                break;
              }
              run.jev(choice.jev);
            }
          } catch (error) {
            abort = {
              reason: "arm_error",
              cause: "arm_throw",
              ...error.abort,
              message: `${armName} arm: ${error.message}`,
            };
            break;
          }
        }
        const intent = {
          protocol: PROTOCOL,
          seq,
          intent: choice.intent,
          arm: armName,
          source: choice.source,
          meta: choice.meta,
        };
        const intentErrors = validateIntent(intent, { state });
        if (intentErrors.length > 0) {
          const [first] = intentErrors;
          abort = {
            reason: "arm_error",
            cause: "intent_invalid",
            message: `${armName} arm answered ${fileName("intent", seq)} invalidly: ${first.path} ${first.message}`,
          };
          break;
        }
        await writeAtomic(path.join(io, fileName("intent", seq)), intent);
        entry.intents += 1;
        afterIntent = true;
      }
    }
    if (rejected !== null && abort === null) {
      const [first] = rejected.errors;
      abort = {
        reason: "arm_error",
        cause: "node_invalid",
        message: `${rejected.file} failed validation: ${first.path} ${first.message}`,
      };
    }
    if (abort !== null && !stalled && !gone) {
      const message = {
        protocol: PROTOCOL,
        reason: abort.reason,
        message: abort.message,
      };
      if (validateAbort(message).length > 0) {
        throw new Error(
          `harness built an invalid abort.json: ${JSON.stringify(message)}`,
        );
      }
      await writeAtomic(path.join(io, "abort.json"), message);
      entry.abort = abort;
      await waitFor(["done.json", "error.json"]);
    } else if (abort !== null) {
      entry.abort = abort;
    }
    if (!stalled && !gone) {
      // Godot has written its last file; it still has to exit in time.
      const timer = new AbortController();
      const late = sleep(watchdogLimit(steps, floorMs), "late", {
        signal: timer.signal,
      }).catch(() => "cancelled");
      if (
        (await Promise.race([exited.then(() => "exited"), late])) === "late"
      ) {
        await kill("exit");
      }
      timer.abort();
    }
  } finally {
    if (!gone) {
      child.kill("SIGKILL");
      await exited;
    }
  }

  const files = await readTrialFiles(io);
  const errors = validateTrial(files);
  entry.errors = errors.slice(0, MAX_ERRORS);
  entry.events_tmp_only =
    existsSync(path.join(io, "events.ndjson.tmp")) &&
    !Object.hasOwn(files, "events.ndjson");
  entry.median_step_ms = medianOf(steps);
  // validateTrial has already reported a malformed done.json or error.json;
  // here it only has to end as invalid instead of throwing past the record.
  const done = Object.hasOwn(files, "done.json")
    ? parseOrUndefined(files["done.json"])
    : undefined;
  entry.trace_hash = done?.trace_hash ?? null;
  if (stalled) {
    entry.outcome = "stall";
  } else if (rejected !== null) {
    entry.outcome = "invalid";
  } else if (Object.hasOwn(files, "done.json")) {
    entry.outcome = done?.reason ?? "invalid";
  } else if (Object.hasOwn(files, "error.json")) {
    const code = parseOrUndefined(files["error.json"])?.code;
    entry.outcome = code === undefined ? "invalid" : `error:${code}`;
  } else {
    entry.outcome = "crash";
  }
  if (errors.length > 0 && !["stall", "crash"].includes(entry.outcome)) {
    entry.outcome = "invalid";
  }
  if (stderr.trim() !== "") entry.stderr = stderr.trim();
  return entry;
}

export async function runBatch({
  scenario,
  arm: armName,
  trials = DEFAULTS.trials,
  seed = DEFAULTS.seed,
  callCap = DEFAULTS.callCap,
  launch = fakeGodot(),
  watchdogFloorMs = DEFAULTS.watchdogFloorMs,
  pollMs = DEFAULTS.pollMs,
  runs = {},
  instrument,
  decideFn,
  verdictCache = VERDICT_CACHE_ROOT,
  replay = false,
  preflight = beforeJevBatch,
  controls,
} = {}) {
  if (!Object.hasOwn(ARMS, armName ?? "")) {
    throw new UsageError(
      `unknown arm "${armName}"; one of ${Object.keys(ARMS).join(", ")}`,
    );
  }
  if (!slug.test(scenario ?? "")) {
    throw new UsageError(`scenario "${scenario}" is not a slug`);
  }
  if (!Number.isInteger(trials) || trials < 1 || trials > TRIAL_SEED_STRIDE) {
    throw new UsageError(
      `trials must be a whole number from 1 to ${TRIAL_SEED_STRIDE}, got ${trials}`,
    );
  }
  if (!Number.isInteger(callCap) || callCap < 1) {
    throw new UsageError(
      `the call cap must be a whole number >= 1, got ${callCap}`,
    );
  }
  if (!Number.isSafeInteger(seed * TRIAL_SEED_STRIDE + trials)) {
    throw new UsageError(`seed must be a whole number, got ${seed}`);
  }
  if (!(watchdogFloorMs > 0)) {
    throw new UsageError(`watchdogFloorMs must be > 0, got ${watchdogFloorMs}`);
  }
  if (replay && armName !== "jev") {
    throw new UsageError(`replay needs the jev arm, not ${armName}`);
  }
  let armOptions = {};
  let armInstrument = null;
  const anchor = { model: null, mismatches: 0 };
  let preflightResult = null;
  let preflightSummary = null;
  if (armName === "jev") {
    const questions = loadQuestionSet();
    armInstrument = instrument ?? instrumentIdentity(questions);
    let cache = openVerdictCache(verdictCache);
    if (!replay) {
      const checked = await preflight({
        questions,
        decideFn: decideFn ?? decide,
        controls: controls ?? loadControls(),
        start: async () => true,
      });
      preflightResult = checked.controls;
      const models = preflightResult.resolved_models ?? [];
      preflightSummary = {
        passed: checked.exit === 0 && checked.started === true,
        controls_version: preflightResult.controls_version ?? null,
        controls_sha: preflightResult.controls_sha ?? null,
        calls: preflightResult.calls ?? null,
        resolved_models: models,
      };
      let reason = null;
      if (!preflightSummary.passed) {
        const failed = (preflightResult.controls ?? [])
          .filter((control) => !control.passed)
          .map((control) => `${control.id}: ${control.reason}`);
        reason = `the preflight failed: ${failed.join("; ") || "no control passed"}`;
      } else if (models.length !== 1 || typeof models[0] !== "string") {
        const count =
          models.length === 1 ? "1 model" : `${models.length} models`;
        reason = `the preflight resolved ${count} (${models.join(", ")}), so the batch has no single model to anchor on`;
      }
      if (reason !== null) {
        return {
          exit: PREFLIGHT_EXIT,
          reason,
          preflight: preflightResult,
          record: null,
          trials: [],
          directory: null,
          id: null,
        };
      }
      anchor.model = models[0];
      cache = anchoredCache(cache, anchor);
    }
    armOptions = {
      questions,
      instrument: armInstrument,
      cache,
      replay,
      ...(decideFn === undefined ? {} : { decideFn }),
    };
  }
  // play.mjs's pattern: the record keeps this object, so what the batch learns
  // (per-trial outcomes, calls spent) is filled in before finish().
  const config = {
    scenario,
    arm: armName,
    requested_trials: trials,
    seed,
    trial_seed_stride: TRIAL_SEED_STRIDE,
    call_cap: callCap,
    watchdog_floor_ms: watchdogFloorMs,
    launcher: launch.label ?? "custom",
    ...(armName === "jev"
      ? {
          replay,
          verdict_cache: armOptions.cache.directory,
          preflight: preflightSummary,
          anchor_model: anchor.model,
          model_mismatches: 0,
        }
      : {}),
    arm_calls: 0,
    capped: false,
    trials: [],
  };
  const run = await createRun({
    type: "batch",
    label: `${scenario}-${armName}`,
    registry: METRICS,
    config,
    instrument: armInstrument,
    ...runs,
  });
  const budget = { cap: callCap, used: 0, capped: false };
  for (let trial = 0; trial < trials; trial += 1) {
    // Each trial's arm gets its own seed, so trial i replays alone.
    const trialSeed = seed * TRIAL_SEED_STRIDE + trial;
    const arm = createArm(armName, { seed: trialSeed, ...armOptions });
    const io = path.join(
      run.directory,
      "trials",
      String(trial).padStart(3, "0"),
    );
    const entry = await runTrial({
      trial,
      io,
      scenario,
      armName,
      arm,
      seed: trialSeed,
      launch,
      floorMs: watchdogFloorMs,
      pollMs,
      budget,
      run,
      anchor,
    });
    entry.io = path.relative(run.directory, io);
    config.trials.push(entry);
    if (budget.capped || entry.abort?.cause === "model_mismatch") break;
  }
  config.arm_calls = budget.used;
  config.capped = budget.capped;
  if (armName === "jev") {
    config.anchor_model = anchor.model ?? run.provenance.jev.model;
    config.model_mismatches = anchor.mismatches;
  }

  const n = config.trials.length;
  const ended = config.trials.filter(
    (entry) => entry.outcome !== "complete",
  ).length;
  const interval = wilson(ended, n);
  run.kri("trial_abort_rate", {
    value: ended / n,
    n,
    ci: [interval.lower, interval.upper],
  });
  run.kri("engine_crash", {
    value: config.trials.filter((entry) => entry.outcome === "crash").length,
    n,
    ci: null,
  });
  if (armName === "jev") {
    const apiErrors = config.trials.filter(
      (entry) => entry.abort?.cause === "api_error",
    ).length;
    const attempts = run.provenance.jev.calls + apiErrors;
    if (attempts === 0) {
      run.kri("api_error_rate", { value: null, n: 0, ci: null });
    } else {
      const errors = wilson(apiErrors, attempts);
      run.kri("api_error_rate", {
        value: apiErrors / attempts,
        n: attempts,
        ci: [errors.lower, errors.upper],
      });
    }
    if (apiErrors > 0) {
      run.limit(
        `${apiErrors} of ${attempts} Jev calls ended in an API error; an API failure says nothing about the game, so those trials count as inconclusive, not failed.`,
      );
    }
    if (replay) {
      run.limit(
        `Replay: every verdict came from ${config.verdict_cache}; no Jev call was made, so no preflight ran and the batch is anchored on its first verdict's model.`,
      );
    } else {
      run.limit(
        `Preflight: controls ${preflightSummary.controls_version} passed in ${preflightSummary.calls} live calls; the batch is anchored on ${anchor.model}.`,
      );
    }
    if (anchor.mismatches > 0) {
      run.limit(
        `${anchor.mismatches} cached verdicts came from another model than the anchor ${anchor.model}; each was asked again live.`,
      );
    }
    if (
      config.trials.some((entry) => entry.abort?.cause === "model_mismatch")
    ) {
      run.limit(
        "A verdict came from another model than the batch's anchor, so the instrument changed mid-batch; the batch stopped there and is void.",
      );
    }
  }
  if (budget.capped) {
    run.limit(
      `The batch call cap of ${callCap} arm calls was reached; ${n} of ${trials} trials ran.`,
    );
  }
  run.limit(`Automated trials against ${config.launcher}; not a feel verdict.`);
  if (config.launcher.startsWith("fake-godot")) {
    run.limit(
      "fake-godot replays scripted snapshots; no physics was simulated.",
    );
  }
  const record = await run.finish({ result: batchResult(config.trials) });
  return {
    exit: EXIT[record.result],
    reason: null,
    preflight: preflightResult,
    record,
    trials: config.trials,
    directory: run.directory,
    id: run.id,
  };
}

function parseArgs(argv) {
  const options = { launchFlags: {} };
  const numbers = {
    "-n": "trials",
    "--trials": "trials",
    "--seed": "seed",
    "--call-cap": "callCap",
  };
  const fakeFlags = {
    "--stall-at": "stallAt",
    "--crash-at": "crashAt",
    "--invalid-at": "invalidAt",
    "--error-at": "errorAt",
  };
  const words = [...argv];
  while (words.length > 0) {
    const word = words.shift();
    if (!word.startsWith("-")) {
      if (options.scenario !== undefined)
        throw new Error(`unexpected argument ${word}`);
      options.scenario = word;
      continue;
    }
    if (word === "--replay") {
      options.replay = true;
      continue;
    }
    const value = words.shift();
    if (word === "--arm") {
      options.arm = value;
    } else if (word === "--root" && value !== undefined) {
      options.root = path.resolve(value);
    } else if (word === "--cache" && value !== undefined) {
      options.cache = path.resolve(value);
    } else if (
      Object.hasOwn(numbers, word) &&
      Number.isInteger(Number(value))
    ) {
      options[numbers[word]] = Number(value);
    } else if (
      Object.hasOwn(fakeFlags, word) &&
      Number.isInteger(Number(value))
    ) {
      options.launchFlags[fakeFlags[word]] = Number(value);
    } else {
      throw new Error(
        `unknown or malformed option ${word} ${value ?? ""}`.trim(),
      );
    }
  }
  if (options.scenario === undefined) {
    throw new Error(
      "usage: harness.mjs <scenario> [--arm scripted|random|jev] [-n N] [--seed N] [--call-cap N] [--root DIR] [--cache DIR] [--replay]",
    );
  }
  return options;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exit(2);
  }
  const {
    scenario,
    arm = "scripted",
    trials,
    seed,
    callCap,
    root,
    cache,
    replay = false,
    launchFlags,
  } = options;
  let batch;
  try {
    batch = await runBatch({
      scenario,
      arm,
      trials,
      seed,
      callCap,
      launch: fakeGodot(launchFlags),
      runs: root === undefined ? {} : { root },
      replay,
      ...(cache === undefined ? {} : { verdictCache: cache }),
    });
  } catch (error) {
    if (!(error instanceof UsageError)) throw error;
    console.error(error.message);
    process.exit(EXIT.usage);
  }
  if (batch.record === null) {
    console.log(`preflight refused the batch: ${batch.reason}`);
    console.log("No trial ran and no run record was written.");
    process.exit(batch.exit);
  }
  const { record, trials: done } = batch;
  if (batch.preflight !== null) {
    console.log(
      `preflight: ${batch.preflight.calls} live calls; anchored on ${record.config.anchor_model}`,
    );
  }
  for (const entry of done) {
    const note =
      entry.abort === null
        ? ""
        : ` (abort ${entry.abort.reason}/${entry.abort.cause}: ${entry.abort.message})`;
    console.log(
      `trial ${entry.trial}: ${entry.outcome}, ${entry.snapshots} snapshots, ${entry.arm_calls} arm calls, ${entry.forced} forced, trace_hash ${entry.trace_hash}${note}`,
    );
  }
  const rate = record.kris.trial_abort_rate;
  console.log(
    `trial_abort_rate ${rate.value.toFixed(2)} over ${rate.n}; engine_crash ${record.kris.engine_crash.value}; result ${record.result}`,
  );
  if (arm === "jev") {
    const { model, calls, cache_hits: hits } = record.provenance.jev;
    console.log(
      `jev: ${calls} live calls, ${hits} cache hits, model ${model}, ${record.config.model_mismatches} stale hits asked again${replay ? ", replay" : ""}`,
    );
  }
  console.log(`run record: ${record.id}`);
  console.log("Automated; not a feel verdict.");
  process.exit(EXIT[record.result]);
}
