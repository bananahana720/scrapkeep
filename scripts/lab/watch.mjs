// `scrapkeep lab watch` (JL-31): one trial played in a visible Godot window
// through the real harness, with the runner's overlay showing each decision.
//
//   node scripts/lab/watch.mjs <scenario> [--arm scripted|random|jev]
//     [--mode kinematic|rigid] [--seed N] [-n trials] [--call-cap N]
//     [--root runs-dir] [--cache verdict-dir] [--marks marks-dir]
//     [--shots tick,tick] [--mark-at tick] [--sketch dir] [--no-page]
//
// It is runBatch with its `watch` flag and godotLaunch with its `watch`
// option, so the protocol, the trial files and trace_hash are the headless
// ones. What watch adds lives beside each trial, in <run>/watch/<NNN>/:
// session.json (arm, scenario, preflight verdict, call cap and the palette)
// written before Godot starts, and decisions.ndjson, one line per decision
// with what was offered, the probabilities, what was chosen, how it was chosen
// and how long it took. The overlay reads both; replay.mjs reads them too.
//
// A watch is never evidence. Its record carries config.watch and the gate
// refuses it. With --arm jev the preflight still runs and its verdict is shown,
// but a failure does not stop the trial: the run is a demo. Every live Jev
// call in the session, the preflight's included, counts against --call-cap
// (60 by default). Watch keeps its own verdict cache and runs root, so a demo
// verdict never answers an evidence batch.
import { existsSync, mkdirSync, realpathSync, writeFileSync } from "node:fs";
import { appendFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

import { decide } from "../../tools/jev-player/decide.mjs";
import { loadControls } from "../../tools/jev-player/preflight.mjs";
import { TIMING } from "../../tools/jev-player/protocol/protocol.mjs";
import {
  GODOT_BINARY,
  MODES,
  SKETCH,
  godotLaunch,
  sketchVersions,
  stageFor,
  watchPaths,
} from "./godot-launch.mjs";
import { JEV_DEFAULTS, runBatch, UsageError } from "./harness.mjs";
import { EXIT, INTENT, PAGE, SOURCE, WATCH } from "./metrics/status.mjs";
import { writeReplay } from "./replay.mjs";
import { openVerdictCache } from "./verdict-cache.mjs";

const repositoryRoot = path.resolve(import.meta.dirname, "../..");
const local = path.join(repositoryRoot, "artifacts/local");

// Records name paths inside the repository relative to it.
export function repoRelative(file) {
  const relative = path.relative(repositoryRoot, file);
  return relative.startsWith("..") || path.isAbsolute(relative)
    ? file
    : relative;
}

export const WATCH_DEFAULTS = Object.freeze({
  callCap: 60,
  root: path.join(local, "watch-runs"),
  cache: path.join(local, "watch-cache"),
  marks: path.join(local, "watch-marks"),
});

export const SESSION_SCHEMA = "scrapkeep-watch/1";
const TOKEN_FIELDS = [
  "input_tokens",
  "output_tokens",
  "cache_read_input_tokens",
  "cache_creation_input_tokens",
];

// preflight.mjs asks each threshold control in two orders and each wording
// control in two orders under two wordings.
export function plannedPreflightCalls(
  controls = loadControls(JEV_DEFAULTS.controls),
) {
  return controls.controls.reduce(
    (sum, control) => sum + (control.kind === "same-choice" ? 4 : 2),
    0,
  );
}

export function palette() {
  return {
    intents: INTENT,
    sources: SOURCE,
    watch: WATCH,
    status: WATCH.verdict,
    page: PAGE,
  };
}

// What the overlay shows for a decision. `kind` is a SOURCE key: a forced
// answer, a rule, a seeded draw, a cache hit, Jev under its confidence floor
// (fallback) and a failed call each keep their own label, so only `live` reads
// as Jev choosing now. A seeded draw is uniform over the offered options, so
// its bars are that; a rule ladder has no distribution to show.
export function decisionLine({ arm, event, verdict, counters }) {
  const { choice } = event;
  const failed = choice === null || (event.error ?? null) !== null;
  let kind;
  if (failed) kind = "failed";
  else if (choice.source === "forced") kind = "forced";
  else if (choice.meta?.low_confidence === true) kind = "fallback";
  else kind = choice.source;
  let probabilities = null;
  if (kind === "seeded") {
    probabilities = Object.fromEntries(
      event.offered.map((option) => [option.id, 1 / event.offered.length]),
    );
  } else if (["live", "cache", "fallback"].includes(kind)) {
    probabilities = verdict?.probabilities ?? null;
  }
  const offeredIds = new Set(event.offered.map((option) => option.id));
  const jev = event.state?.jev ?? { state: {}, options: [] };
  return {
    trial: event.trial,
    seq: event.seq,
    tick: event.tick,
    arm,
    kind,
    cached: choice?.source === "cache",
    intent: failed ? null : choice.intent,
    raw_intent: failed ? null : (choice.meta?.raw_intent ?? choice.intent),
    confidence: choice?.meta?.confidence ?? null,
    low_confidence: choice?.meta?.low_confidence === true,
    probabilities,
    rule: choice?.meta?.rule ?? null,
    offered: event.offered.map(({ id, why }) => ({ id, why })),
    gated: jev.options
      .map((option) => option.id)
      .filter((id) => !offeredIds.has(id)),
    latency_ms: Number(event.latencyMs.toFixed(1)),
    error: event.error ?? null,
    calls: { live: counters.live, cached: counters.cached, cap: counters.cap },
    tokens: Object.fromEntries(
      TOKEN_FIELDS.map((field) => [field, counters.tokens[field] ?? 0]),
    ),
    state: jev,
  };
}

function preflightView({ summary, controls, reason }) {
  return {
    passed: summary.passed,
    controls_version: summary.controls_version,
    calls: summary.calls ?? 0,
    models: summary.resolved_models,
    tokens: Object.fromEntries(
      TOKEN_FIELDS.map((field) => [field, controls?.tokens?.[field] ?? null]),
    ),
    reason,
    lines: (controls?.controls ?? []).map(
      (control) =>
        `${control.id}: ${control.passed ? "passed" : "did not pass"} (${control.reason})`,
    ),
  };
}

export async function runWatch({
  scenario,
  arm = "scripted",
  mode = "kinematic",
  seed,
  trials = 1,
  callCap = WATCH_DEFAULTS.callCap,
  root = WATCH_DEFAULTS.root,
  cache = WATCH_DEFAULTS.cache,
  marks = WATCH_DEFAULTS.marks,
  decideFn = decide,
  preflight,
  launch,
  runs = {},
  shots = [],
  markAt,
  sketch = SKETCH,
  watchdogFloorMs,
} = {}) {
  if (!Number.isInteger(callCap) || callCap < 1) {
    throw new UsageError(
      `the session call cap must be a whole number >= 1, got ${callCap}`,
    );
  }
  const planned = arm === "jev" ? plannedPreflightCalls() : 0;
  if (callCap < planned) {
    throw new UsageError(
      `--call-cap ${callCap} is below the ${planned} live calls the preflight makes before any decision; use at least ${planned}`,
    );
  }
  const counters = {
    live: 0,
    cached: 0,
    cap: callCap,
    tokens: Object.fromEntries(TOKEN_FIELDS.map((field) => [field, 0])),
  };
  let last = null;
  // The last line of defence: no call passes the session cap, whoever asks.
  const counted = async (...args) => {
    if (counters.live >= callCap) {
      throw new Error(`the session cap of ${callCap} live Jev calls is spent`);
    }
    counters.live += 1;
    const verdict = await decideFn(...args);
    for (const field of TOKEN_FIELDS)
      counters.tokens[field] += verdict?.usage?.[field] ?? 0;
    last = verdict;
    return verdict;
  };
  const verdicts = openVerdictCache(cache);
  const base =
    launch ?? godotLaunch({ mode, sketch, watch: { marks, shots, markAt } });
  let preflightShown = null;
  const sessions = [];
  const watched = (spec) => {
    const paths = watchPaths(spec.io, marks);
    mkdirSync(paths.dir, { recursive: true });
    const demo = arm === "jev";
    const armCap =
      arm === "jev"
        ? Math.max(0, callCap - (preflightShown?.calls ?? 0))
        : null;
    writeFileSync(
      path.join(paths.dir, "session.json"),
      JSON.stringify(
        {
          schema: SESSION_SCHEMA,
          run_id: paths.runId,
          trial: spec.trial,
          scenario,
          arm,
          mode,
          seed: spec.seed,
          demo,
          label: (demo ? WATCH.demo : WATCH.watch).record,
          banner: (demo ? WATCH.demo : WATCH.watch).banner,
          preflight: preflightShown,
          cap: {
            session: callCap,
            preflight_calls: preflightShown?.calls ?? 0,
            arm: armCap,
          },
          tick_hz: TIMING.tick_hz,
          snapshot_every: spec.snapshotEvery,
          hold_ticks: spec.holdTicks,
          marks: repoRelative(paths.marks),
          palette: palette(),
        },
        null,
        2,
      ) + "\n",
    );
    writeFileSync(path.join(paths.dir, "decisions.ndjson"), "");
    sessions.push({
      trial: spec.trial,
      io: spec.io,
      dir: paths.dir,
      marks: paths.marks,
    });
    return base(spec);
  };
  watched.label = base.label;
  watched.sketch = base.sketch;
  const onDecision = async (event) => {
    let verdict = null;
    if (event.choice?.source === "live") verdict = last;
    if (event.choice?.source === "cache") {
      counters.cached += 1;
      verdict = (await verdicts.get(event.choice.meta.verdict_key))?.verdict;
    }
    const line = decisionLine({ arm, event, verdict, counters });
    await appendFile(
      path.join(watchPaths(event.io, marks).dir, "decisions.ndjson"),
      JSON.stringify(line) + "\n",
    );
  };
  const batch = await runBatch({
    scenario,
    arm,
    trials,
    ...(seed === undefined ? {} : { seed }),
    launch: watched,
    decideFn: counted,
    ...(preflight === undefined ? {} : { preflight }),
    verdictCache: cache,
    ...(watchdogFloorMs === undefined ? {} : { watchdogFloorMs }),
    ...stageFor(sketch),
    runs: { root, versions: sketchVersions(sketch), ...runs },
    watch: {
      sessionCap: callCap,
      onPreflight: (shown) => {
        preflightShown = preflightView(shown);
      },
      onDecision,
    },
  });
  return { batch, sessions, preflight: preflightShown, counters };
}

function parse(argv) {
  const { values, positionals } = parseArgs({
    args: argv,
    allowPositionals: true,
    options: {
      arm: { type: "string", default: "scripted" },
      mode: { type: "string", default: "kinematic" },
      seed: { type: "string" },
      trials: { type: "string", short: "n" },
      "call-cap": { type: "string" },
      root: { type: "string" },
      cache: { type: "string" },
      marks: { type: "string" },
      shots: { type: "string" },
      "mark-at": { type: "string" },
      sketch: { type: "string" },
      "no-page": { type: "boolean", default: false },
    },
  });
  if (positionals.length !== 1) {
    throw new UsageError(
      "usage: scrapkeep lab watch <scenario> [--arm scripted|random|jev] [--mode kinematic|rigid] [--seed N] [-n N] [--call-cap N] [--root DIR] [--cache DIR] [--marks DIR] [--shots T,T] [--mark-at T] [--sketch DIR] [--no-page]",
    );
  }
  const whole = (name) => {
    const text = values[name];
    if (text === undefined) return undefined;
    if (!/^\d+$/.test(text)) {
      throw new UsageError(`--${name} must be a whole number, got ${text}`);
    }
    return Number(text);
  };
  if (!MODES.includes(values.mode)) {
    throw new UsageError(`--mode must be one of ${MODES.join(", ")}`);
  }
  const shots = (values.shots ?? "")
    .split(",")
    .filter((one) => one !== "")
    .map((one) => {
      if (!/^\d+$/.test(one))
        throw new UsageError(`--shots takes ticks, got ${one}`);
      return Number(one);
    });
  const resolved = (name) =>
    values[name] === undefined ? undefined : path.resolve(values[name]);
  return {
    scenario: positionals[0],
    arm: values.arm,
    mode: values.mode,
    seed: whole("seed"),
    trials: whole("trials") ?? 1,
    callCap: whole("call-cap") ?? WATCH_DEFAULTS.callCap,
    root: resolved("root") ?? WATCH_DEFAULTS.root,
    cache: resolved("cache") ?? WATCH_DEFAULTS.cache,
    marks: resolved("marks") ?? WATCH_DEFAULTS.marks,
    shots,
    markAt: whole("mark-at"),
    sketch: resolved("sketch") ?? SKETCH,
    page: !values["no-page"],
  };
}

async function main(argv) {
  let options;
  try {
    options = parse(argv);
  } catch (error) {
    console.error(error.message);
    return EXIT.usage;
  }
  if (!existsSync(GODOT_BINARY)) {
    console.error(`Godot binary not found at ${GODOT_BINARY}; set GODOT_BIN`);
    return EXIT.usage;
  }
  const { page, ...settings } = options;
  let watched;
  try {
    watched = await runWatch(settings);
  } catch (error) {
    if (!(error instanceof UsageError)) throw error;
    console.error(error.message);
    return EXIT.usage;
  }
  const { batch, sessions, preflight, counters } = watched;
  const { record, directory } = batch;
  const label = record.config.watch.label;
  if (preflight !== null) {
    console.log(
      `preflight ${preflight.controls_version}: ${preflight.passed ? "passed" : "did not pass"} in ${preflight.calls} live calls`,
    );
    for (const line of preflight.lines) console.log(`  ${line}`);
  }
  for (const entry of record.config.trials) {
    const note =
      entry.abort === null
        ? ""
        : ` (abort ${entry.abort.cause}: ${entry.abort.message})`;
    const judged = entry.scenario_result?.result ?? "unreported";
    console.log(
      `trial ${entry.trial}: ${entry.outcome}, scenario ${judged}, ${entry.snapshots} decisions, trace_hash ${entry.trace_hash}${note}`,
    );
    const errors = (entry.stderr ?? "")
      .split("\n")
      .filter((line) => /^(SCRIPT ERROR|ERROR)\b/.test(line));
    for (const line of errors.slice(0, 5)) console.log(`  Godot: ${line}`);
  }
  if (options.arm === "jev") {
    console.log(
      `jev: ${counters.live} live calls of ${options.callCap} in the session (preflight included), ${counters.cached} cache hits; input_tokens ${counters.tokens.input_tokens}, output_tokens ${counters.tokens.output_tokens}`,
    );
  }
  if (page) {
    for (const session of sessions) {
      const out = path.join(session.dir, "replay.html");
      await writeReplay(session.io, { out });
      console.log(`replay page: ${out}`);
    }
  }
  const marksFile = sessions[0]?.marks;
  if (marksFile !== undefined) console.log(`marks: ${marksFile}`);
  console.log(`run record: ${record.id} at ${directory}`);
  console.log(`${label}; the gate refuses watch records.`);
  return EXIT.pass;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = await main(process.argv.slice(2));
}
