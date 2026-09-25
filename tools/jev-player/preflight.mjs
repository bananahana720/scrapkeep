// Preflight controls and the instrument epoch (plan § 1).
//
// Before any batch that includes the jev arm, three controls ask Jev about
// states whose answer is not in doubt: a free cache, a lethal ram, and one
// state under two wordings. Each runs with its options as listed and again
// reversed, live, never from a verdict cache. A failure stops the batch with
// exit 6 before any Godot process starts.
//
// An epoch is one instrument identity (question set sha, model, confidence
// floor, option gate version). Its record holds the control results and the
// blind-corpus result, and the epoch counts as valid only when both passed.
// scripts/lab/gate.mjs reads that validity for lever_effect and for --pin.
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

import { decide, instrumentIdentity, loadQuestionSet } from "./decide.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(here, "..", "..");

export const PREFLIGHT_EXIT = 6;
export const CONTROLS_DIR = path.join(here, "controls");
export const DEFAULT_CONTROLS = "c1";
export const EPOCH_SCHEMA = "scrapkeep-epoch/1";
export const EPOCHS_ROOT = path.join(repositoryRoot, "artifacts/local/epochs");
// JL-18 fills this in from score.mjs's report through blindResult().
export const BLIND_NOT_RUN = Object.freeze({
  status: "not-run",
  passed: false,
});

const TOKEN_FIELDS = [
  "input_tokens",
  "output_tokens",
  "cache_read_input_tokens",
  "cache_creation_input_tokens",
];

export function loadControls(version = DEFAULT_CONTROLS, dir = CONTROLS_DIR) {
  const bytes = readFileSync(path.join(dir, `${version}.json`));
  const sha = createHash("sha256").update(bytes).digest("hex");
  return { ...JSON.parse(bytes), sha };
}

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value === null || typeof value !== "object") return value;
  return Object.fromEntries(
    Object.keys(value)
      .toSorted()
      .map((key) => [key, canonical(value[key])]),
  );
}

// One file per instrument, named by the hash of its canonical form, so key
// order never splits an epoch and a rerun replaces the earlier record.
export function instrumentKey(instrument) {
  return createHash("sha256")
    .update(JSON.stringify(canonical(instrument)))
    .digest("hex");
}

// The same questions with only the intent instruction replaced.
function neutralWording(questions, text) {
  return { ...questions, intent: { ...questions.intent, instructions: text } };
}

const ORDERS = [
  ["given", (options) => options],
  ["reversed", (options) => options.toReversed()],
];

// A call that throws is kept as a failed run, so a live preflight retains
// every answer it paid for and the control fails instead of the process.
async function ask(decideFn, state, options, questions) {
  const offered = options.map((option) => option.id);
  let decision;
  try {
    decision = await decideFn(state, options, { questions });
  } catch (error) {
    return {
      error: error.message,
      choice: null,
      probabilities: null,
      gatedOut: [],
      offered,
      usage: {},
      model: null,
    };
  }
  return {
    error: null,
    choice: decision.rawIntent,
    intent: decision.intent,
    confidence: decision.confidence,
    probabilities: decision.probabilities,
    gatedOut: decision.gatedOut,
    offered,
    usage: decision.usage ?? {},
    model: decision.model ?? null,
    latencyMs: decision.latencyMs,
  };
}

// P(probe) for one run, or the reason there is none. A probe the option gate
// dropped means the control measured PRECONDITION, not Jev.
function probeReading(run, probe) {
  if (run.error !== null)
    return {
      p: null,
      missing: `the call failed in the ${run.order} order: ${run.error}`,
    };
  if (run.gatedOut?.includes(probe) || !run.offered.includes(probe))
    return {
      p: null,
      missing: `${probe} was not offered in the ${run.order} order`,
    };
  const p = run.probabilities?.[probe];
  if (typeof p !== "number" || !Number.isFinite(p))
    return {
      p: null,
      missing: `no probability for ${probe} in the ${run.order} order`,
    };
  return { p, missing: null };
}

async function thresholdControl(control, questions, decideFn) {
  const runs = [];
  for (const [order, arrange] of ORDERS) {
    const run = await ask(
      decideFn,
      control.state,
      arrange(control.options),
      questions,
    );
    run.order = order;
    const { p, missing } = probeReading(run, control.probe);
    run.p = p;
    run.missing = missing;
    runs.push(run);
  }
  const misses = runs.map((run) => {
    if (run.missing !== null) return run.missing;
    if (control.kind === "min-probability" && run.p < control.min)
      return `P(${control.probe}) ${run.p} < ${control.min} in the ${run.order} order`;
    if (control.kind === "max-probability" && run.p > control.max)
      return `P(${control.probe}) ${run.p} > ${control.max} in the ${run.order} order`;
    return null;
  });
  return summary(
    control,
    runs,
    misses.filter((miss) => miss !== null),
  );
}

async function wordingControl(control, questions, neutral, decideFn) {
  const runs = [];
  const misses = [];
  for (const [order, arrange] of ORDERS) {
    const pair = {};
    for (const [wording, asked] of [
      ["current", questions],
      ["neutral", neutral],
    ]) {
      const run = await ask(
        decideFn,
        control.state,
        arrange(control.options),
        asked,
      );
      run.order = order;
      run.wording = wording;
      pair[wording] = run;
      runs.push(run);
    }
    const failed = [pair.current, pair.neutral].find((run) => run.error);
    if (failed !== undefined)
      misses.push(
        `the call failed under the ${failed.wording} wording in the ${order} order: ${failed.error}`,
      );
    else if (pair.current.choice !== pair.neutral.choice)
      misses.push(
        `${pair.current.choice} under the current wording, ${pair.neutral.choice} under the neutral one, in the ${order} order`,
      );
  }
  return summary(control, runs, misses);
}

function summary(control, runs, misses) {
  return {
    id: control.id,
    kind: control.kind,
    passed: misses.length === 0,
    reason: misses.length === 0 ? "passed in both orders" : misses.join("; "),
    runs,
  };
}

// Runs every control live through the injected decideFn and returns pass or
// fail per control with its probabilities. There is no cache parameter: each
// call reaches decideFn.
export async function runControls({
  questions = loadQuestionSet(),
  decideFn,
  controls = loadControls(),
} = {}) {
  if (typeof decideFn !== "function")
    throw new Error("runControls needs an injected decideFn.");
  const neutral = neutralWording(questions, controls.neutral_intent);
  const results = [];
  for (const control of controls.controls) {
    if (control.kind === "same-choice")
      results.push(await wordingControl(control, questions, neutral, decideFn));
    else results.push(await thresholdControl(control, questions, decideFn));
  }
  const runs = results.flatMap((result) => result.runs);
  // Each field is totalled on its own; a field no call reported stays null.
  const tokens = Object.fromEntries(
    TOKEN_FIELDS.map((field) => {
      const reported = runs
        .map((run) => run.usage[field])
        .filter((value) => Number.isFinite(value));
      return [
        field,
        reported.length === 0
          ? null
          : reported.reduce((sum, value) => sum + value, 0),
      ];
    }),
  );
  return {
    instrument: instrumentIdentity(questions),
    questions_version: questions.version,
    controls_version: controls.version,
    controls_sha: controls.sha,
    passed: results.every((result) => result.passed),
    controls: results,
    calls: runs.length,
    tokens,
    resolved_models: [...new Set(runs.map((run) => run.model))],
  };
}

// The contract for the batch runner (JL-18): controls first, and start() only
// when they pass, so a failure never reaches a Godot process.
export async function beforeJevBatch({ questions, decideFn, controls, start }) {
  const result = await runControls({ questions, decideFn, controls });
  if (!result.passed)
    return { exit: PREFLIGHT_EXIT, controls: result, started: null };
  return { exit: 0, controls: result, started: await start() };
}

// Reduces a score.mjs report to its blind aggregate. Case ids never cross,
// so the prompt author sees numbers only (plan § 1, blind corpus).
export function blindResult(report, instrument) {
  if (
    JSON.stringify(canonical(report.instrument)) !==
    JSON.stringify(canonical(instrument))
  )
    throw new Error(
      "The blind report was scored under a different instrument.",
    );
  const summary = report.blind?.summary ?? null;
  const passed = report.gate.exit === 0 && summary !== null;
  return {
    status: passed ? "pass" : report.gate.exit === 3 ? "inconclusive" : "fail",
    passed,
    exit: report.gate.exit,
    reason: report.gate.reason,
    cases: summary?.cases ?? 0,
    weighted: summary?.weighted ?? null,
    severe_misses: summary?.severeMisses?.length ?? 0,
    diagnostic: diagnosticResult(report.blind?.diagnostic),
  };
}

// score.mjs's state-diagnostic subscore, which already carries counts only.
function diagnosticResult(diagnostic) {
  if (diagnostic === null || typeof diagnostic !== "object") return null;
  return {
    cases: diagnostic.cases,
    weighted: diagnostic.weighted,
    plain_pass: diagnostic.plainPass,
    severe_misses: diagnostic.severeMisses,
  };
}

export function epochRecord({
  questions,
  controls,
  blind = BLIND_NOT_RUN,
  now = new Date(),
}) {
  if (controls.instrument.questions_sha !== questions.sha)
    throw new Error("The controls ran under a different question set.");
  return {
    schema: EPOCH_SCHEMA,
    instrument: controls.instrument,
    questions_version: questions.version,
    // The instrument names the model alias; these are the models that answered.
    resolved_models: controls.resolved_models ?? [],
    controls: {
      version: controls.controls_version,
      sha: controls.controls_sha,
      passed: controls.passed === true,
      results: controls.controls.map((result) => ({
        id: result.id,
        passed: result.passed,
        reason: result.reason,
        runs: result.runs.map((run) => ({
          order: run.order,
          ...(run.wording === undefined ? {} : { wording: run.wording }),
          choice: run.choice,
          p: run.p ?? null,
          probabilities: run.probabilities ?? null,
          error: run.error ?? null,
        })),
      })),
    },
    blind: { ...blind },
    valid: controls.passed === true && blind.passed === true,
    written_at: now.toISOString(),
  };
}

// True when the record holds runs and every one of them is a failed call: the
// run measured the API, not the instrument.
function allCallsFailed(record) {
  const results = record.controls?.results;
  if (!Array.isArray(results)) return false;
  const runs = results.flatMap((result) => result.runs ?? []);
  return runs.length > 0 && runs.every((run) => (run.error ?? null) !== null);
}

// An all-error run never replaces an existing record for its instrument; it is
// kept beside it as <key>.error.json, which readEpoch never reads. The path
// written is returned either way.
export async function writeEpochRecord(record, dir = EPOCHS_ROOT) {
  await mkdir(dir, { recursive: true });
  const key = instrumentKey(record.instrument);
  let file = path.join(dir, `${key}.json`);
  if (allCallsFailed(record) && existsSync(file)) {
    file = path.join(dir, `${key}.error.json`);
  }
  const temporary = `${file}.tmp-${process.pid}`;
  await writeFile(temporary, JSON.stringify(record, null, 2) + "\n");
  await rename(temporary, file);
  return file;
}

export async function readEpoch(instrument, dir = EPOCHS_ROOT) {
  if (instrument === null || typeof instrument !== "object") return null;
  let record;
  try {
    record = JSON.parse(
      await readFile(
        path.join(dir, `${instrumentKey(instrument)}.json`),
        "utf8",
      ),
    );
  } catch (error) {
    if (
      ["ENOENT", "ENOTDIR"].includes(error.code) ||
      error instanceof SyntaxError
    )
      return null;
    throw error;
  }
  const same =
    JSON.stringify(canonical(record?.instrument)) ===
    JSON.stringify(canonical(instrument));
  return record?.schema === EPOCH_SCHEMA && same ? record : null;
}

// Validity is recomputed, never read from the stored `valid` flag: the
// controls count as passed only when every stored per-control result passed.
export async function epochStatus(instrument, dir = EPOCHS_ROOT) {
  if (instrument === null || typeof instrument !== "object")
    return { valid: false, reason: "the run carries no instrument" };
  const record = await readEpoch(instrument, dir);
  if (record === null)
    return {
      valid: false,
      reason: `no epoch record for this instrument under ${dir}`,
    };
  const results = record.controls?.results;
  if (
    record.controls?.passed !== true ||
    !Array.isArray(results) ||
    !results.every((result) => result?.passed === true)
  )
    return { valid: false, reason: "its controls failed" };
  if (record.blind?.passed !== true)
    return {
      valid: false,
      reason: `its blind corpus is ${record.blind?.status ?? "missing"}`,
    };
  return { valid: true, reason: "controls and blind corpus passed" };
}

// Live CLI: node tools/jev-player/preflight.mjs [--questions q1-original]
// [--controls c1] [--out dir] [--epochs dir]. Writes the full control result
// to --out and the epoch record (blind not run) to --epochs, then exits 6 on
// any failed control.
async function main(argv) {
  const { values } = parseArgs({
    args: argv,
    options: {
      questions: { type: "string" },
      controls: { type: "string" },
      out: { type: "string" },
      epochs: { type: "string" },
    },
    strict: true,
  });
  const questions = loadQuestionSet(values.questions);
  const controls = loadControls(values.controls);
  const started = new Date();
  const result = await runControls({ questions, decideFn: decide, controls });
  const out = path.resolve(
    values.out ?? path.join(repositoryRoot, "artifacts/local/preflight"),
  );
  await mkdir(out, { recursive: true });
  const stamp = started.toISOString().replaceAll(":", "-");
  const file = path.join(out, `controls-${stamp}.json`);
  await writeFile(
    file,
    JSON.stringify(
      {
        started_at: started.toISOString(),
        finished_at: new Date().toISOString(),
        ...result,
      },
      null,
      2,
    ) + "\n",
  );
  const epoch = await writeEpochRecord(
    epochRecord({ questions, controls: result, blind: BLIND_NOT_RUN }),
    path.resolve(values.epochs ?? EPOCHS_ROOT),
  );
  for (const control of result.controls) {
    const readings = control.runs
      .map(
        (run) =>
          `${run.wording ? `${run.wording}/` : ""}${run.order} ${run.choice}${run.p === undefined || run.p === null ? "" : ` p=${run.p}`}`,
      )
      .join(", ");
    process.stdout.write(
      `${control.passed ? "pass" : "fail"} ${control.id}: ${readings}; ${control.reason}\n`,
    );
  }
  process.stdout.write(
    `${result.calls} calls; models ${result.resolved_models.join(", ")}\n` +
      `tokens ${TOKEN_FIELDS.map((field) => `${field}=${result.tokens[field]}`).join(" ")}\n` +
      `result ${file}\nepoch ${epoch}\n`,
  );
  return result.passed ? 0 : PREFLIGHT_EXIT;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.exitCode = await main(process.argv.slice(2));
}
