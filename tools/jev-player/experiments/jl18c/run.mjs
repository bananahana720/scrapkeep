// JL-18c: the pre-registered Jev-as-player redesign experiment.
//
// Every input is fixed in states.json, questions.json and design.json, and the
// pre-registration pins their sha256 and this file's. --dry-run prints every
// request body and the call count; --live refuses to start unless the pins
// match, then makes exactly the budgeted calls once, with no retries.
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { appendFile, mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

import {
  apiKey,
  buildQuestions,
  instrumentIdentity,
  loadQuestionSet,
  offeredOptions,
} from "../../decide.mjs";

export const EXPERIMENT_DIR = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(EXPERIMENT_DIR, "..", "..", "..", "..");
export const PREREGISTRATION = path.join(
  repositoryRoot,
  "artifacts/jev-lab-2026-09-25/experiments/jl18c/PREREGISTRATION.md",
);
const DEFAULT_OUT = path.join(repositoryRoot, "artifacts/local/tasks/JL-18c/live");
// decide.mjs keeps its endpoint private and this card may not edit it.
const ENDPOINT = "https://api.typesafe.ai/v1/systemone";
const INPUTS = ["states.json", "questions.json", "design.json", "run.mjs"];
const TOKEN_FIELDS = [
  "input_tokens",
  "output_tokens",
  "cache_read_input_tokens",
  "cache_creation_input_tokens",
];

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");
const round = (value) =>
  value === null || value === undefined ? null : Number(value.toFixed(4));
const finite = (value) => (Number.isFinite(value) ? value : null);

export function loadExperiment(dir = EXPERIMENT_DIR) {
  const bytes = Object.fromEntries(
    INPUTS.map((name) => [name, readFileSync(path.join(dir, name))]),
  );
  const parse = (name) => JSON.parse(bytes[name].toString("utf8"));
  return {
    design: parse("design.json"),
    states: parse("states.json"),
    questions: parse("questions.json"),
    hashes: Object.fromEntries(
      INPUTS.map((name) => [name, sha256(bytes[name])]),
    ),
  };
}

// The pre-registration lists each input as "`<file>` sha256 `<hex>`".
export function lockMismatches(text, experiment = loadExperiment()) {
  return INPUTS.filter(
    (name) => !text.includes(`\`${name}\` sha256 \`${experiment.hashes[name]}\``),
  ).map(
    (name) =>
      `${name} sha256 ${experiment.hashes[name]} is not pinned in the pre-registration`,
  );
}

function permutations(items) {
  if (items.length <= 1) return [items];
  return items.flatMap((item, index) =>
    permutations(items.toSpliced(index, 1)).map((rest) => [item, ...rest]),
  );
}

function fill(template, values) {
  return Object.entries(values).reduce(
    (text, [name, value]) => text.replaceAll(`{${name}}`, value),
    template,
  );
}

function cellOptions(experiment, cell) {
  const { options } = experiment.states.states[cell.state];
  if (cell.options === undefined) return options;
  return cell.options.map((id) => options.find((option) => option.id === id));
}

const itemKey = (item) => `${item.option}__${item.question}`;

function ordersFor(experiment, cell) {
  if (cell.call === "comprehension") {
    const keys = experiment.questions.comprehension.items[cell.state].map(itemKey);
    return [keys, keys.toReversed()];
  }
  return permutations(cellOptions(experiment, cell).map((option) => option.id));
}

function bodyFor(experiment, cell, order, questions, model) {
  const { state } = experiment.states.states[cell.state];
  const byId = Object.fromEntries(
    cellOptions(experiment, cell).map((option) => [option.id, option]),
  );
  if (cell.call === "choice" || cell.call === "intent-only") {
    const ordered = order.map((id) => byId[id]);
    const built = buildQuestions(
      offeredOptions({ state, options: ordered }),
      questions,
    );
    return {
      model,
      state,
      questions: cell.call === "choice" ? built : { intent: built.intent },
    };
  }
  if (cell.call === "preference") {
    const { preamble, template } = experiment.questions.preference;
    return {
      model,
      state,
      questions: Object.fromEntries(
        order.map((id) => [
          id,
          { type: "noul", instructions: fill(template, { preamble, why: byId[id].why }) },
        ]),
      ),
    };
  }
  const { template, items, questions: texts } = experiment.questions.comprehension;
  const byKey = Object.fromEntries(items[cell.state].map((item) => [itemKey(item), item]));
  const { options } = experiment.states.states[cell.state];
  return {
    model,
    state,
    questions: Object.fromEntries(
      order.map((key) => {
        const item = byKey[key];
        const why = options.find((option) => option.id === item.option).why;
        return [
          key,
          { type: "noul", instructions: fill(template, { why, question: texts[item.question] }) },
        ];
      }),
    ),
  };
}

// Repeats are the outer loop so every cell is spread across the run's time.
export function buildPlan(experiment, questions = loadQuestionSet(experiment.design.question_set)) {
  const { design } = experiment;
  if (questions.version !== design.question_set)
    throw new Error(`The design asks under ${design.question_set}, not ${questions.version}.`);
  const { model } = instrumentIdentity(questions);
  const cells = design.cells.map((cell) => ({ cell, orders: ordersFor(experiment, cell) }));
  const plan = [];
  for (let repeat = 1; repeat <= design.repeats; repeat += 1) {
    for (const { cell, orders } of cells) {
      for (const order of orders) {
        plan.push({
          index: plan.length,
          cell: cell.id,
          design: cell.design,
          call: cell.call,
          state: cell.state,
          repeat,
          order,
          body: bodyFor(experiment, cell, order, questions, model),
        });
      }
    }
  }
  return plan;
}

// A call that throws is kept as a failed result and never retried. onResult
// sees each result as it lands, so a crash mid-run keeps every paid answer.
export async function runPlan(plan, send, budget, onResult = async () => {}) {
  if (plan.length !== budget)
    throw new Error(`The plan has ${plan.length} calls; the budget is ${budget}.`);
  const results = [];
  for (const call of plan) {
    const started = Date.now();
    let reply = null;
    let error = null;
    try {
      reply = await send(call.body);
    } catch (caught) {
      error = caught.message;
    }
    const result = {
      index: call.index,
      cell: call.cell,
      design: call.design,
      call: call.call,
      state: call.state,
      repeat: call.repeat,
      order: call.order,
      body_sha256: sha256(JSON.stringify(call.body)),
      error,
      answers: reply?.answers ?? null,
      usage: reply?.usage ?? {},
      model: reply?.model ?? null,
      latencyMs: Date.now() - started,
    };
    results.push(result);
    await onResult(result);
  }
  return results;
}

function liveSender(key) {
  return async (body) => {
    const response = await fetch(ENDPOINT, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Jev ${response.status}: ${text.slice(0, 300)}`);
    }
    const data = await response.json();
    return { answers: data.answers, usage: data.usage, model: data.model };
  };
}

const mean = (values) =>
  values.length === 0 ? null : values.reduce((sum, value) => sum + value, 0) / values.length;

function stats(values) {
  if (values.length === 0) return { n: 0, mean: null, min: null, max: null, sd: null };
  const centre = mean(values);
  const variance =
    values.length < 2
      ? 0
      : values.reduce((sum, value) => sum + (value - centre) ** 2, 0) / (values.length - 1);
  return {
    n: values.length,
    mean: round(centre),
    min: round(Math.min(...values)),
    max: round(Math.max(...values)),
    sd: round(Math.sqrt(variance)),
  };
}

// The square root of the mean within-order sample variance: repeat noise with
// the order held fixed, which is what the position and comparison lines scale.
function pooledSd(groups) {
  const variances = groups
    .filter((values) => values.length >= 2)
    .map((values) => {
      const centre = mean(values);
      return values.reduce((sum, value) => sum + (value - centre) ** 2, 0) / (values.length - 1);
    });
  return variances.length === 0 ? 0 : Math.sqrt(mean(variances));
}

function groupByOrder(results) {
  const groups = new Map();
  for (const result of results) {
    const key = result.order.join(">");
    if (!groups.has(key)) groups.set(key, { order: result.order, results: [] });
    groups.get(key).results.push(result);
  }
  return [...groups.values()];
}

function noiseLine(lines, groups) {
  return round(Math.max(lines.noise_floor, lines.noise_multiplier * pooledSd(groups)));
}

function positionsOf(results, probe, read) {
  const width = results[0].order.length;
  return Array.from({ length: width }, (_, position) => ({
    position: position + 1,
    ...stats(
      results
        .filter((result) => result.order.indexOf(probe) === position)
        .map(read)
        .filter((value) => value !== null),
    ),
  }));
}

function withPositionEffect(lines, groups, positions) {
  const means = positions.map((entry) => entry.mean).filter((value) => value !== null);
  const range = means.length === 0 ? null : round(Math.max(...means) - Math.min(...means));
  const line = noiseLine(lines, groups);
  return { position_range: range, position_line: line, position_effect: range !== null && range > line };
}

function thresholdCell(cell, results, lines) {
  const { probe, kind } = cell.rule;
  const read = (result) => finite(result.answers?.intent?.probabilities?.[probe]);
  const meets = (value) =>
    kind === "min" ? value >= lines.min_probability : value <= lines.max_probability;
  const orders = groupByOrder(results).map(({ order, results: runs }) => {
    const readings = runs.map(read).filter((value) => value !== null);
    const centre = round(mean(readings));
    return {
      order,
      readings,
      mean: centre,
      min: readings.length === 0 ? null : Math.min(...readings),
      passed: centre !== null && meets(centre),
    };
  });
  const all = results.map(read).filter((value) => value !== null);
  const positions = positionsOf(results, probe, read);
  const groups = orders.map((entry) => entry.readings);
  return {
    kind: "threshold",
    rule: cell.rule,
    passed: orders.every((entry) => entry.passed),
    orders,
    positions,
    ...stats(all),
    pooled_sd: round(pooledSd(groups)),
    ...withPositionEffect(lines, groups, positions),
  };
}

function preferenceCell(cell, results, lines, ids) {
  const { probe, kind } = cell.rule;
  const noulOf = (result, id) => finite(result.answers?.[id]?.noul);
  const orders = groupByOrder(results).map(({ order, results: runs }) => {
    const means = Object.fromEntries(
      ids.map((id) => [id, round(mean(runs.map((run) => noulOf(run, id)).filter((v) => v !== null)))]),
    );
    const others = ids.filter((id) => id !== probe).map((id) => means[id]);
    const complete = Object.values(means).every((value) => value !== null);
    const gap =
      kind === "min"
        ? round(means[probe] - Math.max(...others))
        : round(Math.max(...others) - means[probe]);
    const passed =
      complete &&
      gap >= lines.dominance_margin &&
      (kind === "min"
        ? means[probe] >= lines.min_probability
        : means[probe] <= lines.max_probability);
    return {
      order,
      readings: runs.map((run) => noulOf(run, probe)).filter((v) => v !== null),
      means,
      gap: complete ? gap : null,
      passed,
    };
  });
  const read = (result) => noulOf(result, probe);
  const positions = positionsOf(results, probe, read);
  const groups = orders.map((entry) => entry.readings);
  return {
    kind: "preference",
    rule: cell.rule,
    passed: orders.every((entry) => entry.passed),
    orders,
    options: Object.fromEntries(
      ids.map((id) => [
        id,
        round(mean(results.map((result) => noulOf(result, id)).filter((v) => v !== null))),
      ]),
    ),
    positions,
    ...stats(results.map(read).filter((value) => value !== null)),
    pooled_sd: round(pooledSd(groups)),
    ...withPositionEffect(lines, groups, positions),
  };
}

function comprehensionCell(cell, results, lines, items) {
  const side = lines.comprehension_side;
  const read = items.map((item) => {
    const key = itemKey(item);
    const readings = results
      .map((result) => finite(result.answers?.[key]?.noul))
      .filter((value) => value !== null);
    return {
      item: key,
      expected: item.expected,
      basis: item.basis,
      readings,
      mean: round(mean(readings)),
      correct:
        readings.length > 0 &&
        readings.every((value) => (item.expected ? value > side : value < side)),
    };
  });
  return {
    kind: "comprehension",
    read: read.filter((item) => item.basis === "stated").every((item) => item.correct),
    items: read,
  };
}

function comparisonValue(comparison, cell) {
  if (comparison.reads === "probe") {
    const { probe } = cell.rule;
    return (result) => finite(result.answers?.intent?.probabilities?.[probe]);
  }
  const [first, second] = comparison.share_of;
  return (result) => {
    const probabilities = result.answers?.intent?.probabilities ?? {};
    const a = finite(probabilities[first]);
    const b = finite(probabilities[second]);
    return a === null || b === null || a + b === 0 ? null : a / (a + b);
  };
}

function compare(comparison, byCell, cellsById, lines) {
  const sides = {};
  const groups = [];
  for (const side of ["baseline", "treatment"]) {
    const id = comparison[side];
    const value = comparisonValue(comparison, cellsById[id]);
    const perOrder = groupByOrder(byCell[id] ?? []).map(({ results }) =>
      results.map(value).filter((reading) => reading !== null),
    );
    groups.push(...perOrder);
    sides[side] = round(mean(perOrder.flat()));
  }
  const lift =
    sides.baseline === null || sides.treatment === null
      ? null
      : round(sides.treatment - sides.baseline);
  const line = noiseLine(lines, groups);
  return {
    id: comparison.id,
    reads: comparison.reads,
    baseline: comparison.baseline,
    treatment: comparison.treatment,
    baseline_mean: sides.baseline,
    treatment_mean: sides.treatment,
    lift,
    line,
    indicated: lift !== null && Math.abs(lift) > line,
  };
}

function totals(results) {
  return Object.fromEntries(
    TOKEN_FIELDS.map((field) => {
      const reported = results
        .map((result) => result.usage?.[field])
        .filter((value) => Number.isFinite(value));
      return [field, reported.length === 0 ? null : reported.reduce((sum, v) => sum + v, 0)];
    }),
  );
}

export function analyse(experiment, results) {
  const { design } = experiment;
  const { lines } = design;
  const cellsById = Object.fromEntries(design.cells.map((cell) => [cell.id, cell]));
  const byCell = Object.groupBy(results, (result) => result.cell);
  const cells = {};
  for (const cell of design.cells) {
    const runs = byCell[cell.id] ?? [];
    const base = { design: cell.design, call: cell.call, state: cell.state, calls: runs.length };
    if (cell.call === "comprehension") {
      const items = experiment.questions.comprehension.items[cell.state];
      cells[cell.id] = { ...base, ...comprehensionCell(cell, runs, lines, items) };
    } else if (cell.call === "preference") {
      const ids = cellOptions(experiment, cell).map((option) => option.id);
      cells[cell.id] = { ...base, ...preferenceCell(cell, runs, lines, ids) };
    } else {
      cells[cell.id] = { ...base, ...thresholdCell(cell, runs, lines) };
    }
  }
  const comparisons = design.comparisons.map((comparison) =>
    compare(comparison, byCell, cellsById, lines),
  );
  const byComparison = Object.fromEntries(comparisons.map((entry) => [entry.id, entry]));
  const wrong = (basis) =>
    Object.entries(cells)
      .filter(([, cell]) => cell.kind === "comprehension")
      .flatMap(([id, cell]) =>
        cell.items
          .filter((item) => item.basis === basis && !item.correct)
          .map((item) => ({ cell: id, item: item.item, mean: item.mean })),
      );
  const rule = design.explanations;
  const explanations = {
    reading: { stated_wrong: wrong("stated"), implied_wrong: wrong("implied") },
    position: Object.entries(cells)
      .filter(([, cell]) => cell.position_effect === true)
      .map(([id]) => id),
    framing: byComparison.framing.indicated,
    sibling: comparisons
      .filter((entry) => entry.id.startsWith("sibling") && entry.indicated)
      .map((entry) => entry.id),
    random_buff: byComparison["random-buff"].indicated,
    priming: byComparison.priming.indicated,
    preference:
      cells[rule.preference.read].read === true &&
      rule.preference.below_line.every(
        (id) => cells[id].mean !== null && cells[id].mean < lines.min_probability,
      ),
    dominance_scope: cells[rule.scope].passed
      ? "the free heal was taken in every order, so the discount is specific to caches or their buffs"
      : "the free heal was not taken in every order, so Jev does not reliably take a free dominant option in this domain",
  };
  const failed = results.filter((result) => result.error !== null).length;
  const models = [
    ...new Set(results.filter((result) => result.error === null).map((result) => result.model)),
  ];
  const candidates = Object.entries(design.verdict.candidates)
    .filter(([, ids]) => ids.every((id) => cells[id].passed === true))
    .map(([name]) => name);
  const leads = design.verdict.leads.filter((id) => cells[id].passed === true);
  let verdict;
  let reason;
  if (failed >= lines.blocked_failed_calls) {
    verdict = "blocked";
    reason = `${failed} calls failed, at or above the ${lines.blocked_failed_calls}-call line`;
  } else if (models.length > 1) {
    verdict = "blocked";
    reason = `the run resolved more than one model: ${models.join(", ")}`;
  } else if (candidates.length > 0) {
    verdict = "candidate";
    reason = `every verdict cell of ${candidates.join(" and ")} passed in every order`;
  } else {
    verdict = "park";
    reason = "no design passed every verdict cell in every order";
  }
  return {
    calls: results.length,
    failed,
    models,
    tokens: totals(results),
    cells,
    comparisons,
    explanations,
    verdict: { verdict, reason, candidates, leads },
  };
}

const fmt = (value) => (value === null || value === undefined ? "n/a" : String(value));

export function renderReport(analysis) {
  const lines = [];
  for (const [id, cell] of Object.entries(analysis.cells)) {
    if (cell.kind === "comprehension") {
      const stated = cell.items.filter((item) => item.basis === "stated");
      const implied = cell.items.filter((item) => item.basis === "implied");
      const misses = cell.items.filter((item) => !item.correct).map((item) => `${item.item}=${fmt(item.mean)}`);
      lines.push(
        `${cell.read ? "read" : "misread"} ${id} comprehension: stated ${stated.filter((i) => i.correct).length}/${stated.length} correct, implied ${implied.filter((i) => i.correct).length}/${implied.length}${misses.length ? `; wrong ${misses.join(", ")}` : ""}`,
      );
      continue;
    }
    const passedOrders = cell.orders.filter((entry) => entry.passed).length;
    const byPosition = cell.positions.map((entry) => `${entry.position}:${fmt(entry.mean)}±${fmt(entry.sd)}`).join(" ");
    const options =
      cell.kind === "preference"
        ? `; option means ${Object.entries(cell.options).map(([o, v]) => `${o}=${fmt(v)}`).join(" ")}`
        : "";
    lines.push(
      `${cell.passed ? "pass" : "fail"} ${id} ${cell.call}: P(${cell.rule.probe}) mean ${fmt(cell.mean)} min ${fmt(cell.min)}; orders ${passedOrders}/${cell.orders.length}; by position ${byPosition} (range ${fmt(cell.position_range)}, line ${fmt(cell.position_line)}${cell.position_effect ? ", position effect" : ""})${options}`,
    );
  }
  for (const entry of analysis.comparisons) {
    lines.push(
      `compare ${entry.id}: ${entry.treatment} ${fmt(entry.treatment_mean)} vs ${entry.baseline} ${fmt(entry.baseline_mean)} (${entry.reads}), lift ${fmt(entry.lift)}, line ${fmt(entry.line)}${entry.indicated ? ", indicated" : ""}`,
    );
  }
  const { explanations: why } = analysis;
  lines.push(
    `reading: ${why.reading.stated_wrong.length} stated and ${why.reading.implied_wrong.length} implied items wrong`,
    `position: ${why.position.length ? why.position.join(", ") : "none"}`,
    `framing ${why.framing}; sibling ${why.sibling.length ? why.sibling.join(", ") : "none"}; random buff ${why.random_buff}; priming ${why.priming}; preference ${why.preference}`,
    `scope: ${why.dominance_scope}`,
    `verdict ${analysis.verdict.verdict}: ${analysis.verdict.reason}; candidates ${analysis.verdict.candidates.join(", ") || "none"}; leads ${analysis.verdict.leads.join(", ") || "none"}`,
    `${analysis.calls} calls, ${analysis.failed} failed; models ${analysis.models.join(", ") || "none"}`,
    `tokens ${TOKEN_FIELDS.map((field) => `${field}=${analysis.tokens[field]}`).join(" ")}`,
  );
  return lines.join("\n") + "\n";
}

async function main(argv) {
  const { values } = parseArgs({
    args: argv,
    options: {
      "dry-run": { type: "boolean" },
      live: { type: "boolean" },
      out: { type: "string" },
    },
    strict: true,
  });
  if (values["dry-run"] === values.live) {
    process.stderr.write("Pass exactly one of --dry-run or --live.\n");
    return 2;
  }
  const experiment = loadExperiment();
  const questions = loadQuestionSet(experiment.design.question_set);
  const plan = buildPlan(experiment, questions);
  const { budget } = experiment.design;
  if (values["dry-run"]) {
    for (const call of plan) {
      process.stdout.write(
        `# call ${call.index + 1}/${plan.length} cell=${call.cell} design=${call.design} repeat=${call.repeat} order=${call.order.join(">")}\n${JSON.stringify(call.body)}\n`,
      );
    }
    process.stdout.write(`${plan.length} calls (budget ${budget}); no call made\n`);
    return plan.length === budget ? 0 : 1;
  }
  const mismatches = lockMismatches(readFileSync(PREREGISTRATION, "utf8"), experiment);
  if (mismatches.length > 0) {
    process.stderr.write(`${mismatches.join("\n")}\nRefusing to call.\n`);
    return 3;
  }
  const key = apiKey();
  if (key === null) {
    process.stderr.write("No TypeSafe API key; set TYPESAFE_API_KEY.\n");
    return 2;
  }
  const started = new Date();
  const out = path.resolve(values.out ?? DEFAULT_OUT);
  await mkdir(out, { recursive: true });
  const stamp = started.toISOString().replaceAll(":", "-");
  const stream = path.join(out, `jl18c-${stamp}.calls.jsonl`);
  const results = await runPlan(plan, liveSender(key), budget, (result) =>
    appendFile(stream, JSON.stringify(result) + "\n"),
  );
  const analysis = analyse(experiment, results);
  const file = path.join(out, `jl18c-${stamp}.json`);
  await writeFile(
    file,
    JSON.stringify(
      {
        started_at: started.toISOString(),
        finished_at: new Date().toISOString(),
        hashes: experiment.hashes,
        instrument: instrumentIdentity(questions),
        budget,
        results,
        analysis,
      },
      null,
      2,
    ) + "\n",
  );
  process.stdout.write(renderReport(analysis) + `result ${file}\n`);
  return 0;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.exitCode = await main(process.argv.slice(2));
}
