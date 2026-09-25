import { cp, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";

import { RUNS_ROOT, SCHEMA } from "./record.mjs";
import { EPOCHS_ROOT, epochStatus } from "../../tools/jev-player/preflight.mjs";
import { getMetric } from "./metrics/index.mjs";
import { EXIT, evaluate, worstExit } from "./metrics/status.mjs";
import { newcombe, wilson } from "./stats.mjs";

const repositoryRoot = path.resolve(import.meta.dirname, "../..");
const ARTIFACTS_ROOT = path.join(repositoryRoot, "artifacts");
export const TOLERANCE = 0.1;
const DAY_MS = 86_400_000;
const slug = /^[a-z0-9][a-z0-9-]*$/;
const pinDay = /^jev-lab-\d{4}-\d{2}-\d{2}$/;
const RESULT_EXIT = {
  pass: EXIT.pass,
  fail: EXIT.fail,
  inconclusive: EXIT.inconclusive,
  invalid: EXIT.invalid,
};

// Metrics compared against a pin as a proportion of n trials. The registry
// has no unit field, so the list lives here; a severity-weighted score and a
// share of time are treated as n Bernoulli trials, which is an approximation.
export const RATES = [
  "corpus_blind_weighted",
  "dead_tier",
  "first_pass_review",
  "flake_rate",
];

const USAGE = `Usage:
  node scripts/lab/gate.mjs --pin <run_id> --as <name> [--runs dir] [--artifacts dir] [--epochs dir]
  node scripts/lab/gate.mjs <run_id|run dir> --against <pin name|pin dir> [--runs dir] [--artifacts dir] [--epochs dir]
Exit codes: 0 pass, 1 a metric past its fail limit or a conclusive regression, 2 usage, 3 inconclusive, 4 instrument invalid.`;

class UsageError extends Error {}

const outcome = (exit, text) => ({ exit, text });

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value === null || typeof value !== "object") return value;
  return Object.fromEntries(
    Object.keys(value)
      .toSorted()
      .map((key) => [key, canonical(value[key])]),
  );
}

async function hasRun(directory) {
  try {
    await readFile(path.join(directory, "run.json"));
    return true;
  } catch (error) {
    if (["ENOENT", "ENOTDIR"].includes(error.code)) return false;
    throw error;
  }
}

async function readRun(directory) {
  try {
    return JSON.parse(await readFile(path.join(directory, "run.json"), "utf8"));
  } catch (error) {
    if (error instanceof SyntaxError) return null;
    throw error;
  }
}

async function resolveRun(reference, runs) {
  for (const directory of [path.join(runs, reference), path.resolve(reference)])
    if (await hasRun(directory)) return directory;
  throw new UsageError(`no run.json for run ${reference} under ${runs}`);
}

async function pinDays(artifacts) {
  try {
    return (await readdir(artifacts)).filter((day) => pinDay.test(day)).sort();
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

// A name pinned on several days resolves to the newest.
async function resolvePin(reference, artifacts) {
  if (slug.test(reference)) {
    for (const day of (await pinDays(artifacts)).toReversed()) {
      const directory = path.join(artifacts, day, "pins", reference);
      if (await hasRun(directory)) return directory;
    }
  } else if (await hasRun(path.resolve(reference))) {
    return path.resolve(reference);
  }
  throw new UsageError(`no pin named ${reference} under ${artifacts}`);
}

function wellFormed(measure) {
  return (
    measure !== null &&
    typeof measure === "object" &&
    (measure.value === null || Number.isFinite(measure.value)) &&
    Number.isInteger(measure.n) &&
    measure.n >= 0
  );
}

function render(status, id, measure, tty) {
  const text = `${status.glyph} ${status.word} ${id} ${measure.value} n=${measure.n}`;
  return tty ? `${status.ansi}${text}\x1b[0m` : text;
}

function assessMetrics(record, tty, epochValid) {
  const found = [];
  for (const [kind, bucket] of [
    ["kpi", record.kpis],
    ["kri", record.kris],
  ]) {
    if (bucket === null || typeof bucket !== "object") {
      found.push(outcome(EXIT.invalid, `the record has no ${kind}s object`));
      continue;
    }
    for (const [id, measure] of Object.entries(bucket)) {
      let metric;
      try {
        metric = getMetric(id);
      } catch {
        found.push(outcome(EXIT.invalid, `${id} is not in the registry`));
        continue;
      }
      if (metric.kind !== kind || !wellFormed(measure)) {
        found.push(
          outcome(EXIT.invalid, `${id} is not a well-formed ${metric.kind}`),
        );
        continue;
      }
      const status = evaluate(metric, measure, { epochValid });
      found.push(outcome(status.exit, render(status, id, measure, tty)));
    }
  }
  return found;
}

// What a run shows on its own: its schema, recorded result, tree state and
// every metric's status. epochValid comes from the run's epoch record.
function assessRun(record, label, tty, epochValid = false) {
  if (record?.schema !== SCHEMA)
    return [outcome(EXIT.invalid, `${label} is not a ${SCHEMA} record`)];
  const found = [];
  if (!Object.hasOwn(RESULT_EXIT, record.result))
    found.push(outcome(EXIT.invalid, `${label} has no valid result`));
  else
    found.push(
      outcome(RESULT_EXIT[record.result], `${label} result ${record.result}`),
    );
  const { sources, dirty, head } = record.provenance ?? {};
  if (sources?.matched === false)
    found.push(
      outcome(
        EXIT.inconclusive,
        `${label} sources changed during the run; reported ${sources.reported_result ?? "unknown"}`,
      ),
    );
  if (dirty !== false)
    found.push(
      outcome(EXIT.inconclusive, `${label} ran on a dirty tree at ${head}`),
    );
  return [...found, ...assessMetrics(record, tty, epochValid)];
}

function reading(record, id) {
  const measure = record.kpis?.[id] ?? record.kris?.[id];
  const usable =
    wellFormed(measure) &&
    measure.n >= 1 &&
    measure.value !== null &&
    measure.value >= 0 &&
    measure.value <= 1;
  return usable
    ? { x: Math.round(measure.value * measure.n), n: measure.n }
    : null;
}

const round = (value) => Number(value.toFixed(4));
const interval = ({ lower, upper }) => `[${round(lower)}, ${round(upper)}]`;

// Newcombe's interval for the change, signed so that positive is better. It
// passes when the whole interval clears -TOLERANCE, regresses when all of it
// lies below, and is inconclusive when it straddles.
function compareRate(id, candidate, pin) {
  const before = reading(pin, id);
  if (before === null) return [];
  const after = reading(candidate, id);
  if (after === null)
    return [
      outcome(
        EXIT.inconclusive,
        `compare ${id}: the pin has a rate and the candidate has none, inconclusive`,
      ),
    ];
  const better = getMetric(id).thresholds.worse === "lower";
  const change = better
    ? newcombe(after.x, after.n, before.x, before.n)
    : newcombe(before.x, before.n, after.x, after.n);
  let exit = EXIT.inconclusive;
  let verdict = "inconclusive";
  if (change.lower >= -TOLERANCE) {
    exit = EXIT.pass;
    verdict = "within tolerance";
  } else if (change.upper < -TOLERANCE) {
    exit = EXIT.fail;
    verdict = "regressed";
  }
  const text = [
    `compare ${id}`,
    `${after.x}/${after.n} ${interval(wilson(after.x, after.n))}`,
    `against ${before.x}/${before.n} ${interval(wilson(before.x, before.n))}:`,
    `improvement ${round(change.estimate)} ${interval(change)},`,
    `tolerance ${TOLERANCE}, ${verdict}`,
  ].join(" ");
  return [outcome(exit, text)];
}

function againstPin(candidate, pin, name) {
  const found = [];
  if (
    JSON.stringify(canonical(candidate.provenance?.instrument ?? null)) !==
    JSON.stringify(canonical(pin.provenance?.instrument ?? null))
  )
    found.push(
      outcome(
        EXIT.invalid,
        `the candidate's instrument differs from pin ${name}'s; its epoch must pass controls and be pinned`,
      ),
    );
  const ageDays =
    (Date.parse(candidate.started_at) - Date.parse(pin.finished_at)) / DAY_MS;
  const age = evaluate(getMetric("evidence_age_d"), {
    value: Number.isFinite(ageDays) ? Math.max(0, ageDays) : Number.NaN,
    n: 1,
  });
  if (age.gate === "fail" || age.gate === "inconclusive")
    found.push(
      outcome(
        EXIT.inconclusive,
        `pin ${name} is stale: ${Number.isFinite(ageDays) ? round(ageDays) : "unknown"} d older than the candidate`,
      ),
    );
  for (const id of RATES) found.push(...compareRate(id, candidate, pin));
  return found;
}

// A run that carries an instrument identity is pinnable only when that
// epoch's record shows passed controls and a passed blind corpus (plan § 4).
// A run without one (no jev arm) has no epoch to prove.
async function pinRun({
  reference,
  name,
  runs,
  artifacts,
  epochs,
  tty,
  out,
  err,
}) {
  if (!slug.test(name)) throw new UsageError(`pin name ${name} is not a slug`);
  const source = await resolveRun(reference, runs);
  const record = await readRun(source);
  const instrument = record?.provenance?.instrument ?? null;
  const epoch = await epochStatus(instrument, epochs);
  const found = assessRun(record, `run ${reference}`, tty, epoch.valid);
  if (instrument !== null && !epoch.valid)
    found.push(
      outcome(
        EXIT.invalid,
        `run ${reference}'s epoch has not passed controls and the blind corpus: ${epoch.reason}`,
      ),
    );
  for (const { text } of found) out.write(`${text}\n`);
  const exit = worstExit(found.map((one) => one.exit));
  if (exit !== EXIT.pass) {
    err.write(`refusing to pin ${reference}: on its own it exits ${exit}\n`);
    return exit;
  }
  const day = `jev-lab-${new Date().toISOString().slice(0, 10)}`;
  const target = path.join(artifacts, day, "pins", name);
  await mkdir(path.dirname(target), { recursive: true });
  try {
    await mkdir(target);
  } catch (error) {
    if (error.code === "EEXIST")
      throw new UsageError(`pin ${name} already exists at ${target}`);
    throw error;
  }
  await cp(source, target, { recursive: true, force: false });
  await writeFile(
    path.join(target, "pin.json"),
    JSON.stringify(
      {
        name,
        run_id: record.id,
        source,
        pinned_at: new Date().toISOString(),
      },
      null,
      2,
    ) + "\n",
  );
  out.write(`pinned ${record.id} as ${name} at ${target}\n`);
  return EXIT.pass;
}

async function gateRun({
  reference,
  against,
  runs,
  artifacts,
  epochs,
  tty,
  out,
}) {
  const candidateDirectory = await resolveRun(reference, runs);
  const pinDirectory = await resolvePin(against, artifacts);
  const candidate = await readRun(candidateDirectory);
  const pin = await readRun(pinDirectory);
  const bothValid = candidate?.schema === SCHEMA && pin?.schema === SCHEMA;
  if (bothValid && candidate.type !== pin.type)
    throw new UsageError(
      `candidate type ${candidate.type} cannot be gated against a ${pin.type} pin`,
    );
  const epoch = await epochStatus(
    candidate?.provenance?.instrument ?? null,
    epochs,
  );
  const found = assessRun(
    candidate,
    `candidate ${reference}`,
    tty,
    epoch.valid,
  );
  if (pin?.schema !== SCHEMA)
    found.push(
      outcome(EXIT.invalid, `pin ${against} is not a ${SCHEMA} record`),
    );
  else if (bothValid) found.push(...againstPin(candidate, pin, against));
  for (const { text } of found) out.write(`${text}\n`);
  const exit = worstExit(found.map((one) => one.exit));
  out.write(`gate exit ${exit}\n`);
  return exit;
}

export async function main(
  argv,
  { out = process.stdout, err = process.stderr } = {},
) {
  try {
    let parsed;
    try {
      parsed = parseArgs({
        args: argv,
        options: {
          pin: { type: "string" },
          as: { type: "string" },
          against: { type: "string" },
          runs: { type: "string" },
          artifacts: { type: "string" },
          epochs: { type: "string" },
        },
        allowPositionals: true,
        strict: true,
      });
    } catch (error) {
      throw new UsageError(error.message);
    }
    const { values, positionals } = parsed;
    const common = {
      runs: path.resolve(values.runs ?? RUNS_ROOT),
      artifacts: path.resolve(values.artifacts ?? ARTIFACTS_ROOT),
      epochs: path.resolve(values.epochs ?? EPOCHS_ROOT),
      tty: out.isTTY === true,
      out,
      err,
    };
    const pinning = values.pin !== undefined || values.as !== undefined;
    if (
      pinning &&
      values.pin &&
      values.as &&
      !values.against &&
      positionals.length === 0
    )
      return await pinRun({
        ...common,
        reference: values.pin,
        name: values.as,
      });
    if (!pinning && values.against && positionals.length === 1)
      return await gateRun({
        ...common,
        reference: positionals[0],
        against: values.against,
      });
    throw new UsageError("expected --pin with --as, or one run with --against");
  } catch (error) {
    if (!(error instanceof UsageError)) throw error;
    err.write(`${error.message}\n${USAGE}\n`);
    return EXIT.usage;
  }
}

// Node exits 1 on an uncaught error, which would read as a failed KRI; a gate
// that could not measure reports an invalid instrument instead.
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  try {
    process.exitCode = await main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`${error.stack ?? error}\n`);
    process.exitCode = EXIT.invalid;
  }
}
