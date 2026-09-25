// The harness's `launch` for real Godot (JL-17): one headless ball-lab process
// per trial, running sketches/ball-lab/src/jev/jev_run.gd at --fixed-fps 90 so
// one frame is one physics tick. The harness spawns it in its own process
// group and kills the group on stall.
//
//   node scripts/lab/godot-launch.mjs <scenario> [--arm scripted|random|jev]
//     [-n trials] [--seed N] [--mode kinematic|rigid] [--snapshot-every D]
//     [--hold-ticks k] [--max-ticks N] [--call-cap N] [--root runs-dir]
//     [--cache verdict-dir] [--replay]
//
// The binary is the one sketch-smoke.mjs pins, or GODOT_BIN.
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

import { TIMING } from "../../tools/jev-player/protocol/protocol.mjs";
import { binary } from "../sketch-smoke.mjs";
import { runBatch, UsageError } from "./harness.mjs";
import { EXIT } from "./metrics/status.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));

export const GODOT_BINARY = binary;
export const SKETCH = path.resolve(here, "../../sketches/ball-lab");
export const RUNNER = "res://src/jev/jev_run.gd";
export const MODES = Object.freeze(["kinematic", "rigid"]);

// `maxTicks` ends every trial early (0 runs to the scenario's own end);
// `intentTimeoutS` replaces the protocol's 30 s block limit; `env` is added to
// the harness's environment for each Godot process.
export function godotLaunch({
  mode = "kinematic",
  godot = GODOT_BINARY,
  maxTicks = 0,
  intentTimeoutS,
  env = {},
} = {}) {
  if (!MODES.includes(mode)) {
    throw new Error(
      `physics mode must be one of ${MODES.join(", ")}, got ${mode}`,
    );
  }
  if (!Number.isInteger(maxTicks) || maxTicks < 0) {
    throw new Error(`maxTicks must be a whole number >= 0, got ${maxTicks}`);
  }
  const launch = ({ io, scenario, seed, snapshotEvery, holdTicks }) => ({
    command: godot,
    args: [
      "--headless",
      "--fixed-fps",
      String(TIMING.tick_hz),
      "--path",
      SKETCH,
      "--script",
      RUNNER,
      "--",
      `--io=${io}`,
      `--scenario=${scenario}`,
      `--seed=${seed}`,
      `--mode=${mode}`,
      `--snapshot-every=${snapshotEvery}`,
      `--hold-ticks=${holdTicks}`,
      ...(maxTicks > 0 ? [`--max-ticks=${maxTicks}`] : []),
      ...(intentTimeoutS === undefined
        ? []
        : [`--intent-timeout-s=${intentTimeoutS}`]),
    ],
    env,
  });
  launch.label = [
    "godot-headless",
    path.basename(godot),
    mode,
    ...(maxTicks > 0 ? [`max-ticks ${maxTicks}`] : []),
  ].join(" ");
  return launch;
}

function parse(argv) {
  const { values, positionals } = parseArgs({
    args: argv,
    allowPositionals: true,
    options: {
      arm: { type: "string", default: "scripted" },
      trials: { type: "string", short: "n" },
      seed: { type: "string" },
      mode: { type: "string", default: "kinematic" },
      "snapshot-every": { type: "string" },
      "hold-ticks": { type: "string" },
      "max-ticks": { type: "string" },
      "call-cap": { type: "string" },
      root: { type: "string" },
      cache: { type: "string" },
      replay: { type: "boolean", default: false },
    },
  });
  if (positionals.length !== 1) {
    throw new Error(
      "usage: godot-launch.mjs <scenario> [--arm scripted|random|jev] [-n N] [--seed N] [--mode kinematic|rigid] [--snapshot-every D] [--hold-ticks k] [--max-ticks N] [--call-cap N] [--root DIR] [--cache DIR] [--replay]",
    );
  }
  const whole = (name) => {
    const text = values[name];
    if (text === undefined) return undefined;
    if (!/^-?\d+$/.test(text)) {
      throw new Error(`--${name} must be a whole number, got ${text}`);
    }
    return Number(text);
  };
  return {
    scenario: positionals[0],
    arm: values.arm,
    trials: whole("trials"),
    seed: whole("seed"),
    mode: values.mode,
    snapshotEvery: whole("snapshot-every"),
    holdTicks: whole("hold-ticks"),
    maxTicks: whole("max-ticks") ?? 0,
    callCap: whole("call-cap"),
    root: values.root === undefined ? undefined : path.resolve(values.root),
    cache: values.cache === undefined ? undefined : path.resolve(values.cache),
    replay: values.replay,
  };
}

async function main(argv) {
  let options;
  let launch;
  try {
    options = parse(argv);
    launch = godotLaunch({ mode: options.mode, maxTicks: options.maxTicks });
  } catch (error) {
    console.error(error.message);
    return EXIT.usage;
  }
  if (!existsSync(GODOT_BINARY)) {
    console.error(`Godot binary not found at ${GODOT_BINARY}; set GODOT_BIN`);
    return EXIT.usage;
  }
  const defined = (entries) =>
    Object.fromEntries(entries.filter(([, value]) => value !== undefined));
  let batch;
  try {
    batch = await runBatch({
      launch,
      ...defined([
        ["scenario", options.scenario],
        ["arm", options.arm],
        ["trials", options.trials],
        ["seed", options.seed],
        ["callCap", options.callCap],
        ["snapshotEvery", options.snapshotEvery],
        ["holdTicks", options.holdTicks],
        ["replay", options.replay],
        ["verdictCache", options.cache],
      ]),
      runs: options.root === undefined ? {} : { root: options.root },
    });
  } catch (error) {
    if (!(error instanceof UsageError)) throw error;
    console.error(error.message);
    return EXIT.usage;
  }
  if (batch.record === null) {
    const { preflight } = batch;
    console.log(`preflight refused the batch: ${batch.reason}`);
    console.log(
      `preflight: ${preflight.questions_version}/${preflight.controls_version}, ${preflight.calls} live calls, models ${preflight.resolved_models.join(", ")}, tokens ${JSON.stringify(preflight.tokens)}`,
    );
    for (const control of preflight.controls) {
      console.log(
        `  ${control.id}: ${control.passed ? "passed" : `did not pass (${control.reason})`}`,
      );
    }
    console.log(`preflight result: ${JSON.stringify(preflight)}`);
    console.log("No trial ran and no run record was written.");
    return batch.exit;
  }
  const { record, trials, directory } = batch;
  if (batch.preflight !== null) {
    console.log(`preflight: ${batch.preflight.calls} live calls`);
  }
  for (const entry of trials) {
    const note =
      entry.abort === null
        ? ""
        : ` (abort ${entry.abort.reason}/${entry.abort.cause}: ${entry.abort.message})`;
    console.log(
      `trial ${entry.trial}: ${entry.outcome}, exit ${entry.exit.code}, ${entry.snapshots} snapshots, ${entry.arm_calls} arm calls, ${entry.forced} forced, trace_hash ${entry.trace_hash}${note}`,
    );
  }
  const rate = record.kris.trial_abort_rate;
  console.log(
    `${record.config.launcher}; D ${record.config.snapshot_every}, k ${record.config.hold_ticks}`,
  );
  console.log(
    `trial_abort_rate ${rate.value.toFixed(2)} over ${rate.n}; engine_crash ${record.kris.engine_crash.value}; result ${record.result}`,
  );
  if (options.arm === "jev") {
    const { model, calls, cache_hits: hits } = record.provenance.jev;
    console.log(`jev: ${calls} live calls, ${hits} cache hits, model ${model}`);
  }
  console.log(`run record: ${record.id} at ${directory}`);
  console.log("Automated; not a feel verdict.");
  return EXIT[record.result];
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.exitCode = await main(process.argv.slice(2));
}
