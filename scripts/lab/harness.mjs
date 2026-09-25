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
// trial_abort_rate counts every trial whose outcome is not `complete`.
//
//   node scripts/lab/harness.mjs <scenario> [--arm scripted|random|jev]
//     [-n trials] [--seed N] [--call-cap N] [--root runs-dir]
//     [--stall-at N | --crash-at N | --invalid-at N | --error-at N]
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdir, readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { performance } from "node:perf_hooks";
import { setTimeout as sleep } from "node:timers/promises";
import { fileURLToPath } from "node:url";

import { instrumentIdentity } from "../../tools/jev-player/decide.mjs";
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
import { createRun } from "./record.mjs";
import { wilson } from "./stats.mjs";

export const FAKE_GODOT = fileURLToPath(
  new URL("./fake-godot.mjs", import.meta.url),
);

// callCap is the runaway guard EV-0484 asks JL-11 for: the most arm calls one
// batch may make. Forced answers never count. 1000 is provisional; it covers
// twenty trials of the longest scripted scenario many times over, and JL-14
// sets it per batch for the live jev arm.
export const DEFAULTS = Object.freeze({
  trials: 1,
  seed: 1,
  callCap: 1000,
  watchdogFloorMs: WATCHDOG_FLOOR_MS,
  pollMs: 10,
});

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
}) {
  await mkdir(io, { recursive: true });
  const entry = {
    trial,
    io: null,
    seed,
    outcome: null,
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
            message: `the batch call cap of ${budget.cap} arm calls is reached`,
          };
          break;
        } else {
          budget.used += 1;
          entry.arm_calls += 1;
          try {
            choice = await arm.choose({ seq, state: state.jev.state, offered });
          } catch (error) {
            abort = {
              reason: "arm_error",
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
        message: `${rejected.file} failed validation: ${first.path} ${first.message}`,
      };
    }
    if (abort !== null && !stalled && !gone) {
      const message = { protocol: PROTOCOL, ...abort };
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
  if (stalled) {
    entry.outcome = "stall";
  } else if (rejected !== null) {
    entry.outcome = "invalid";
  } else if (Object.hasOwn(files, "done.json")) {
    entry.outcome = JSON.parse(files["done.json"]).reason ?? "invalid";
  } else if (Object.hasOwn(files, "error.json")) {
    entry.outcome = `error:${JSON.parse(files["error.json"]).code}`;
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
} = {}) {
  if (!Object.hasOwn(ARMS, armName ?? "")) {
    throw new Error(
      `unknown arm "${armName}"; one of ${Object.keys(ARMS).join(", ")}`,
    );
  }
  if (!slug.test(scenario ?? "")) {
    throw new Error(`scenario "${scenario}" is not a slug`);
  }
  if (!Number.isInteger(trials) || trials < 1) {
    throw new Error(`trials must be a whole number >= 1, got ${trials}`);
  }
  if (!Number.isInteger(callCap) || callCap < 1) {
    throw new Error(`the call cap must be a whole number >= 1, got ${callCap}`);
  }
  if (!Number.isInteger(seed)) {
    throw new Error(`seed must be a whole number, got ${seed}`);
  }
  if (!(watchdogFloorMs > 0)) {
    throw new Error(`watchdogFloorMs must be > 0, got ${watchdogFloorMs}`);
  }
  const armInstrument =
    armName === "jev" ? (instrument ?? instrumentIdentity()) : null;
  // play.mjs's pattern: the record keeps this object, so what the batch learns
  // (per-trial outcomes, calls spent) is filled in before finish().
  const config = {
    scenario,
    arm: armName,
    requested_trials: trials,
    seed,
    call_cap: callCap,
    watchdog_floor_ms: watchdogFloorMs,
    launcher: launch.label ?? "custom",
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
    const trialSeed = seed + trial;
    const arm = createArm(armName, {
      seed: trialSeed,
      ...(armInstrument === null ? {} : { instrument: armInstrument }),
    });
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
    });
    entry.io = path.relative(run.directory, io);
    config.trials.push(entry);
    if (budget.capped) break;
  }
  config.arm_calls = budget.used;
  config.capped = budget.capped;

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
  const outcomes = config.trials.map((entry) => entry.outcome);
  const result = outcomes.includes("invalid")
    ? "invalid"
    : budget.capped
      ? "inconclusive"
      : ended > 0
        ? "fail"
        : "pass";
  const record = await run.finish({ result });
  return {
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
    const value = words.shift();
    if (word === "--arm") {
      options.arm = value;
    } else if (word === "--root") {
      options.root = path.resolve(value);
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
      "usage: harness.mjs <scenario> [--arm scripted|random|jev] [-n N] [--seed N] [--call-cap N] [--root DIR]",
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
    launchFlags,
  } = options;
  const { record, trials: done } = await runBatch({
    scenario,
    arm,
    trials,
    seed,
    callCap,
    launch: fakeGodot(launchFlags),
    runs: root === undefined ? {} : { root },
  });
  for (const entry of done) {
    const note =
      entry.abort === null
        ? ""
        : ` (abort ${entry.abort.reason}: ${entry.abort.message})`;
    console.log(
      `trial ${entry.trial}: ${entry.outcome}, ${entry.snapshots} snapshots, ${entry.arm_calls} arm calls, ${entry.forced} forced${note}`,
    );
  }
  const rate = record.kris.trial_abort_rate;
  console.log(
    `trial_abort_rate ${rate.value.toFixed(2)} over ${rate.n}; result ${record.result}`,
  );
  console.log(`run record: ${record.id}`);
  console.log("Automated; not a feel verdict.");
  process.exit(record.result === "pass" ? 0 : 1);
}
