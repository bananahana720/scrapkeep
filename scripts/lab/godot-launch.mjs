// The harness's `launch` for real Godot (JL-17): one headless process per
// trial, running the sketch's src/jev/jev_run.gd at --fixed-fps 90 so one
// frame is one physics tick. The harness spawns it in its own process group
// and kills the group on stall.
//
//   node scripts/lab/godot-launch.mjs <scenario> [--arm scripted|random|jev]
//     [-n trials] [--seed N] [--mode kinematic|rigid] [--snapshot-every D]
//     [--hold-ticks k] [--max-ticks N] [--call-cap N] [--root runs-dir]
//     [--cache verdict-dir] [--replay] [--sketch dir]
//
// The sketch is sketches/ball-lab unless --sketch names another Godot project
// with the same runner, such as a lab branch's sketches/cable-bench in its own
// worktree (JL-26). A sketch with a stage layer in metrics/index.mjs STAGES
// records that layer too, and a sketch outside this repository has its own
// repository's head and dirty flag stamped into the record's versions.
//
// The binary is the one sketch-smoke.mjs pins, or GODOT_BIN.
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

import { TIMING } from "../../tools/jev-player/protocol/protocol.mjs";
import { binary } from "../sketch-smoke.mjs";
import { runBatch, UsageError } from "./harness.mjs";
import { STAGES, registryFor } from "./metrics/index.mjs";
import { EXIT } from "./metrics/status.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const hereRoot = path.resolve(here, "../..");

export const GODOT_BINARY = binary;
export const SKETCH = path.resolve(here, "../../sketches/ball-lab");
export const RUNNER = "res://src/jev/jev_run.gd";
export const MODES = Object.freeze(["kinematic", "rigid"]);

// Where a watched trial's side files go (JL-31): beside trials/, never inside
// a trial's io directory, which validateTrial() closes to protocol files.
// `io` is <run>/trials/<NNN>; marks for the whole run share one JSONL file.
export function watchPaths(io, marksRoot) {
  const run = path.dirname(path.dirname(io));
  const runId = path.basename(run);
  const trial = path.basename(io);
  return {
    run,
    runId,
    trial,
    dir: path.join(run, "watch", trial),
    marks: path.join(marksRoot, `${runId}.jsonl`),
  };
}

// `maxTicks` ends every trial early (0 runs to the scenario's own end);
// `intentTimeoutS` replaces the protocol's 30 s block limit; `env` is added to
// the harness's environment for each Godot process; `sketch` is the Godot
// project directory. `watch` ({marks, shots?, markAt?}) opens a visible window
// at real time with the runner's overlay instead of running headless; without
// it the arguments are the headless runner's, unchanged.
export function godotLaunch({
  mode = "kinematic",
  godot = GODOT_BINARY,
  maxTicks = 0,
  intentTimeoutS,
  env = {},
  sketch = SKETCH,
  watch = null,
} = {}) {
  if (!MODES.includes(mode)) {
    throw new Error(
      `physics mode must be one of ${MODES.join(", ")}, got ${mode}`,
    );
  }
  if (!Number.isInteger(maxTicks) || maxTicks < 0) {
    throw new Error(`maxTicks must be a whole number >= 0, got ${maxTicks}`);
  }
  if (!existsSync(path.join(sketch, "project.godot"))) {
    throw new Error(`no project.godot in the sketch directory ${sketch}`);
  }
  const name = path.basename(sketch);
  const engine =
    watch === null ? ["--headless", "--fixed-fps", String(TIMING.tick_hz)] : ["--audio-driver", "Dummy"];
  const watchArgs = (io) => {
    if (watch === null) return [];
    const paths = watchPaths(io, watch.marks);
    return [
      `--watch=${paths.dir}`,
      `--marks=${paths.marks}`,
      ...(watch.shots?.length > 0 ? [`--shots=${watch.shots.join(",")}`] : []),
      ...(watch.markAt === undefined ? [] : [`--mark-at=${watch.markAt}`]),
    ];
  };
  const launch = ({ io, scenario, seed, snapshotEvery, holdTicks }) => ({
    command: godot,
    args: [
      ...engine,
      "--path",
      sketch,
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
      ...watchArgs(io),
    ],
    env,
  });
  launch.label = [
    watch === null ? "godot-headless" : "godot-watch",
    path.basename(godot),
    mode,
    ...(maxTicks > 0 ? [`max-ticks ${maxTicks}`] : []),
    ...(sketch === SKETCH ? [] : [`sketch ${name}`]),
  ].join(" ");
  launch.sketch = { name, path: sketch };
  return launch;
}

// runBatch's registry and measure for a sketch with a stage layer; {} for any
// other, which leaves the harness's defaults.
export function stageFor(sketch) {
  const name = path.basename(sketch);
  if (!Object.hasOwn(STAGES, name)) return {};
  return { registry: registryFor(name), measure: STAGES[name].measure };
}

// The sketch's own repository head and dirty flag, for a sketch that lives in
// another worktree than this one; {} for a sketch inside this repository.
export function sketchVersions(sketch) {
  const git = (...args) =>
    spawnSync("git", ["-C", sketch, ...args], { encoding: "utf8" });
  const top = git("rev-parse", "--show-toplevel");
  const here = path.resolve(hereRoot);
  if (top.status !== 0 || path.resolve(top.stdout.trim()) === here) return {};
  return {
    sketch_repository: top.stdout.trim(),
    sketch_head: git("rev-parse", "HEAD").stdout.trim(),
    sketch_branch: git("branch", "--show-current").stdout.trim(),
    sketch_dirty:
      git("status", "--porcelain").stdout.trim() === "" ? "false" : "true",
  };
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
      sketch: { type: "string" },
    },
  });
  if (positionals.length !== 1) {
    throw new Error(
      "usage: godot-launch.mjs <scenario> [--arm scripted|random|jev] [-n N] [--seed N] [--mode kinematic|rigid] [--snapshot-every D] [--hold-ticks k] [--max-ticks N] [--call-cap N] [--root DIR] [--cache DIR] [--replay] [--sketch DIR]",
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
    sketch: values.sketch === undefined ? SKETCH : path.resolve(values.sketch),
  };
}

async function main(argv) {
  let options;
  let launch;
  try {
    options = parse(argv);
    launch = godotLaunch({
      mode: options.mode,
      maxTicks: options.maxTicks,
      sketch: options.sketch,
    });
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
      ...stageFor(options.sketch),
      runs: {
        ...(options.root === undefined ? {} : { root: options.root }),
        versions: sketchVersions(options.sketch),
      },
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
