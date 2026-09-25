import test from "node:test";
import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { STATUS, evaluate } from "../scripts/lab/metrics/status.mjs";
import {
  METRICS,
  getMetric,
  mergeLayers,
} from "../scripts/lab/metrics/index.mjs";
import { wilson, newcombe, distribution } from "../scripts/lab/stats.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const labDir = path.join(root, "scripts/lab");
const statusFile = path.join(labDir, "metrics/status.mjs");

// Transcribed from plan § 4, the KPI/KRI layer table. Sentinels carry ●.
// `stomp_ram_split` and `route_choice` are the plan's unquoted
// "stomp/ram split" and "route choice" given snake_case ids.
const PLAN = {
  mechanics: {
    kpi: ["lever_effect", "feel_drift", "stomp_ram_split", "route_choice"],
    kri: [
      "unreachable_scenarios",
      "tunnel_nan",
      "stuck_per_trial",
      "dead_tier",
    ],
  },
  agent: {
    kpi: [
      "corpus_blind_weighted",
      "corpus_authored_weighted",
      "margin_vs_scripted",
      "tokens_per_decision",
    ],
    kri: [
      "blind_severe_misses",
      "dominance_controls",
      "instrument_changed",
      "authored_blind_gap",
      "corpus_label_edits",
      "control_separation",
      "intent_churn_min",
      "low_conf_rate",
      "latency_p95_ms",
      "api_error_rate",
      "replay_repro",
    ],
  },
  stability: {
    kpi: ["suite_wall_s"],
    kri: ["suite_pass", "engine_crash", "flake_rate", "trial_abort_rate"],
  },
  pipeline: {
    kpi: ["jev_tokens_batch"],
    kri: ["record_invalid", "evidence_age_d"],
  },
  tdd: {
    kpi: ["first_red_s", "triage_agreement"],
    kri: ["untested_change", "triage_misroute"],
  },
  program: {
    kpi: ["first_pass_review", "cycle_time_h", "tokens_per_card"],
    kri: [
      "rework_per_card",
      "blocked_cards",
      "escaped_defects",
      "overclaim",
      "model_substitution",
      "untracked_commits",
      "event_time_skew",
    ],
  },
  human: { kpi: ["agent_agreement"], kri: ["unplayed_green"] },
};

const PLAN_SENTINELS = [
  "tunnel_nan",
  "blind_severe_misses",
  "dominance_controls",
  "instrument_changed",
  "corpus_label_edits",
  "replay_repro",
  "suite_pass",
  "engine_crash",
  "record_invalid",
  "blocked_cards",
  "model_substitution",
  "untracked_commits",
];

// The plan's amber and red limits are stored as warn and fail, the gate
// effects they trigger, so no status word appears outside STATUS. Rates and
// percentages are fractions; event_time_skew is in hours.
const PLAN_THRESHOLDS = {
  stuck_per_trial: { worse: "higher", warn: 0.2, fail: 0.5 },
  dead_tier: { worse: "lower", warn: 0.05, fail: 0.01 },
  corpus_blind_weighted: { worse: "lower", warn: 0.9, fail: 0.8 },
  authored_blind_gap: { worse: "higher", warn: 0.1, fail: 0.2 },
  intent_churn_min: { worse: "higher", warn: 20, fail: 40 },
  latency_p95_ms: { worse: "higher", warn: 600, fail: 1000 },
  flake_rate: { worse: "higher", warn: 0.01, fail: 0.05 },
  evidence_age_d: { worse: "higher", warn: 3, fail: 7 },
  first_pass_review: { worse: "lower", warn: 0.7, fail: 0.5 },
  event_time_skew: { worse: "higher", warn: 1, fail: 24 },
  unplayed_green: { worse: "higher", warn: 2, fail: 4 },
};

const HEX = /#[0-9a-f]{6}\b/i;
const STATUS_WORD = /\b(green|amber|red|insufficient)\b/i;

function leaks(text) {
  return text
    .split("\n")
    .map((line, index) => ({ line: index + 1, text: line }))
    .filter(({ text: line }) => HEX.test(line) || STATUS_WORD.test(line));
}

async function labFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true, recursive: true });
  return entries
    .filter((entry) => entry.isFile())
    .map((entry) => path.join(entry.parentPath, entry.name));
}

test("STATUS owns colour, glyph, ANSI, gate effect and exit code per status", () => {
  assert.deepEqual(Object.keys(STATUS), [
    "green",
    "amber",
    "red",
    "insufficient",
  ]);
  const expected = {
    green: {
      hex: "#7fd9a0",
      glyph: "●",
      rgb: "127;217;160",
      gate: "pass",
      exit: 0,
    },
    amber: {
      hex: "#ffd166",
      glyph: "▲",
      rgb: "255;209;102",
      gate: "warn",
      exit: 0,
    },
    red: {
      hex: "#ef476f",
      glyph: "■",
      rgb: "239;71;111",
      gate: "fail",
      exit: 1,
    },
    insufficient: {
      hex: "#5e7a82",
      glyph: "○",
      rgb: "94;122;130",
      gate: "inconclusive",
      exit: 3,
    },
  };
  for (const [word, want] of Object.entries(expected)) {
    const entry = STATUS[word];
    assert.equal(entry.word, word);
    assert.equal(entry.hex, want.hex, `${word} hex`);
    assert.equal(entry.glyph, want.glyph, `${word} glyph`);
    assert.equal(entry.ansi, `\x1b[38;2;${want.rgb}m`, `${word} ansi`);
    assert.equal(entry.gate, want.gate, `${word} gate effect`);
    assert.equal(entry.exit, want.exit, `${word} exit code`);
    assert.ok(Object.isFrozen(entry), `${word} entry is frozen`);
  }
  assert.ok(Object.isFrozen(STATUS));
});

test("the leak scanner flags hex colours and status words", () => {
  assert.equal(leaks("const c = '#EF476F';").length, 1);
  assert.equal(leaks("return 'Red';").length, 1);
  assert.equal(leaks("a metric shows insufficient").length, 1);
  assert.equal(leaks("status.amber").length, 1);
  assert.deepEqual(leaks("unplayed_green required entered #fff"), []);
});

test("no hex colour or status word appears under scripts/lab outside STATUS", async () => {
  const files = await labFiles(labDir);
  assert.ok(files.includes(statusFile), "status.mjs exists");
  const found = [];
  for (const file of files.filter((candidate) => candidate !== statusFile)) {
    for (const hit of leaks(await readFile(file, "utf8"))) {
      found.push(
        `${path.relative(root, file)}:${hit.line}: ${hit.text.trim()}`,
      );
    }
  }
  assert.deepEqual(found, []);
});

test("the registry defines every plan metric once, in its layer and kind", () => {
  const want = Object.entries(PLAN).flatMap(([layer, kinds]) =>
    Object.entries(kinds).flatMap(([kind, ids]) =>
      ids.map((id) => ({ id, layer, kind })),
    ),
  );
  const got = METRICS.map(({ id, layer, kind }) => ({ id, layer, kind }));
  const byId = (a, b) => a.id.localeCompare(b.id);
  assert.deepEqual(got.toSorted(byId), want.toSorted(byId));
  assert.equal(
    new Set(METRICS.map((metric) => metric.id)).size,
    METRICS.length,
  );
});

test("every metric has exactly the registry shape", () => {
  const keys = [
    "id",
    "layer",
    "kind",
    "sentinel",
    "thresholds",
    "min_n",
    "says",
  ];
  for (const metric of METRICS) {
    assert.deepEqual(
      Object.keys(metric).toSorted(),
      keys.toSorted(),
      metric.id,
    );
    assert.equal(typeof metric.sentinel, "boolean", metric.id);
    assert.ok(Number.isInteger(metric.min_n) && metric.min_n >= 1, metric.id);
    assert.ok(
      typeof metric.says === "string" && metric.says.length > 10,
      metric.id,
    );
    assert.ok(Object.isFrozen(metric), `${metric.id} is frozen`);
  }
});

test("sentinels and thresholds match the plan", () => {
  const sentinels = METRICS.filter((metric) => metric.sentinel).map(
    (metric) => metric.id,
  );
  assert.deepEqual(sentinels.toSorted(), PLAN_SENTINELS.toSorted());
  for (const metric of METRICS) {
    assert.deepEqual(
      metric.thresholds,
      PLAN_THRESHOLDS[metric.id] ?? null,
      metric.id,
    );
  }
});

test("mergeLayers rejects a duplicate id and a malformed metric", () => {
  const one = {
    id: "x_rate",
    layer: "agent",
    kind: "kri",
    sentinel: false,
    thresholds: null,
    min_n: 1,
    says: "A test metric for the merge.",
  };
  assert.equal(mergeLayers([one]).length, 1);
  assert.throws(
    () => mergeLayers([one], [{ ...one, layer: "program" }]),
    /duplicate metric id x_rate/,
  );
  assert.throws(() => mergeLayers([{ ...one, kind: "kpx" }]), /x_rate/);
  assert.throws(() => mergeLayers([{ ...one, min_n: 0 }]), /x_rate/);
  assert.throws(() => mergeLayers([{ ...one, extra: 1 }]), /x_rate/);
  assert.throws(
    () =>
      mergeLayers([
        {
          ...one,
          sentinel: true,
          thresholds: { worse: "higher", warn: 1, fail: 2 },
        },
      ]),
    /x_rate/,
  );
  assert.throws(
    () =>
      mergeLayers([
        { ...one, thresholds: { worse: "higher", warn: 2, fail: 1 } },
      ]),
    /x_rate/,
  );
  assert.throws(
    () =>
      mergeLayers([
        { ...one, thresholds: { worse: "lower", warn: 1, fail: 2 } },
      ]),
    /x_rate/,
  );
});

test("getMetric throws on an id outside the registry", () => {
  assert.equal(getMetric("flake_rate").layer, "stability");
  assert.throws(
    () => getMetric("not_a_metric"),
    /unknown metric id not_a_metric/,
  );
});

test("below min_n a metric is insufficient, never green", () => {
  const flake = getMetric("flake_rate");
  assert.equal(
    evaluate(flake, { value: 0, n: flake.min_n - 1 }),
    STATUS.insufficient,
  );
  assert.equal(
    evaluate(flake, { value: 0.9, n: flake.min_n - 1 }),
    STATUS.insufficient,
  );
  assert.equal(evaluate(flake, { value: 0, n: flake.min_n }), STATUS.green);
  assert.equal(
    evaluate(flake, { value: Number.NaN, n: 100 }),
    STATUS.insufficient,
  );
  assert.equal(evaluate(flake, { value: null, n: 100 }), STATUS.insufficient);
  const untiered = getMetric("tokens_per_decision");
  assert.equal(evaluate(untiered, { value: 12, n: 0 }), STATUS.insufficient);
  assert.equal(
    evaluate(untiered, { value: 12, n: untiered.min_n }),
    STATUS.green,
  );
  for (const metric of METRICS) {
    assert.equal(
      evaluate(metric, { value: 0, n: 0 }),
      STATUS.insufficient,
      metric.id,
    );
  }
});

test("a sentinel goes to the red status on one occurrence, whatever n is", () => {
  for (const metric of METRICS.filter((candidate) => candidate.sentinel)) {
    assert.equal(evaluate(metric, { value: 1, n: 1 }), STATUS.red, metric.id);
    assert.equal(
      evaluate(metric, { value: 1, n: 0 }),
      STATUS.red,
      `${metric.id} n=0`,
    );
    assert.equal(
      evaluate(metric, { value: true, n: 1 }),
      STATUS.red,
      `${metric.id} true`,
    );
    assert.equal(
      evaluate(metric, { value: 0, n: metric.min_n }),
      STATUS.green,
      metric.id,
    );
    assert.equal(
      evaluate(metric, { value: false, n: metric.min_n }),
      STATUS.green,
      metric.id,
    );
  }
});

test("thresholds are strict and respect the direction that is worse", () => {
  const stuck = getMetric("stuck_per_trial");
  const n = stuck.min_n;
  assert.equal(evaluate(stuck, { value: 0.2, n }), STATUS.green);
  assert.equal(evaluate(stuck, { value: 0.21, n }), STATUS.amber);
  assert.equal(evaluate(stuck, { value: 0.5, n }), STATUS.amber);
  assert.equal(evaluate(stuck, { value: 0.51, n }), STATUS.red);
  const review = getMetric("first_pass_review");
  const m = review.min_n;
  assert.equal(evaluate(review, { value: 0.7, n: m }), STATUS.green);
  assert.equal(evaluate(review, { value: 0.69, n: m }), STATUS.amber);
  assert.equal(evaluate(review, { value: 0.5, n: m }), STATUS.amber);
  assert.equal(evaluate(review, { value: 0.49, n: m }), STATUS.red);
});

// Published 95% intervals from the papers' worked examples, reproduced to four
// decimals only with the exact normal quantile (z = 1.959964), not z = 1.96.
// Wilson score interval (method 3): R. G. Newcombe, "Two-sided confidence
// intervals for the single proportion: comparison of seven methods",
// Statistics in Medicine 17 (1998) 857-872.
// Hybrid score difference (method 10): R. G. Newcombe, "Interval estimation
// for the difference between independent proportions: comparison of eleven
// methods", Statistics in Medicine 17 (1998) 873-890.
const WILSON_REFERENCE = [
  { x: 81, n: 263, lower: 0.2553, upper: 0.3662 },
  { x: 15, n: 148, lower: 0.0624, upper: 0.1605 },
  { x: 0, n: 20, lower: 0.0, upper: 0.1611 },
  { x: 1, n: 29, lower: 0.0061, upper: 0.1718 },
];

const NEWCOMBE_REFERENCE = [
  { x1: 56, n1: 70, x2: 48, n2: 80, lower: 0.0524, upper: 0.3339 },
  { x1: 9, n1: 10, x2: 3, n2: 10, lower: 0.1705, upper: 0.809 },
  { x1: 6, n1: 7, x2: 2, n2: 7, lower: 0.0582, upper: 0.8062 },
  { x1: 5, n1: 56, x2: 0, n2: 29, lower: -0.0381, upper: 0.1926 },
  { x1: 0, n1: 10, x2: 0, n2: 20, lower: -0.1611, upper: 0.2775 },
  { x1: 0, n1: 10, x2: 0, n2: 10, lower: -0.2775, upper: 0.2775 },
  { x1: 10, n1: 10, x2: 0, n2: 20, lower: 0.6791, upper: 1.0 },
  { x1: 10, n1: 10, x2: 0, n2: 10, lower: 0.6075, upper: 1.0 },
];

const round4 = (value) => Math.round(value * 1e4) / 1e4;

test("Wilson intervals match Newcombe (1998a)", () => {
  for (const ref of WILSON_REFERENCE) {
    const got = wilson(ref.x, ref.n);
    assert.equal(got.estimate, ref.x / ref.n);
    assert.deepEqual(
      [round4(got.lower), round4(got.upper)],
      [ref.lower, ref.upper],
      `${ref.x}/${ref.n}`,
    );
  }
  assert.throws(() => wilson(1, 0), RangeError);
  assert.throws(() => wilson(3, 2), RangeError);
  assert.throws(() => wilson(1.5, 4), RangeError);
});

test("Newcombe differences match Newcombe (1998b)", () => {
  for (const ref of NEWCOMBE_REFERENCE) {
    const got = newcombe(ref.x1, ref.n1, ref.x2, ref.n2);
    assert.equal(got.estimate, ref.x1 / ref.n1 - ref.x2 / ref.n2);
    assert.deepEqual(
      [round4(got.lower), round4(got.upper)],
      [ref.lower, ref.upper],
      `${ref.x1}/${ref.n1} - ${ref.x2}/${ref.n2}`,
    );
  }
});

// Shared with tools/agent-player/report.py: each set goes to its
// _distribution through python3 and must produce the identical row.
const PERCENTILE_FIXTURE = [
  [],
  [5],
  [3, 1, 2],
  [4, 1, 3, 2],
  Array.from({ length: 20 }, (_, index) => index + 1),
  Array.from({ length: 21 }, (_, index) => 21 - index),
  Array.from({ length: 100 }, (_, index) => (index * 37) % 100),
  [0.3, 12.75, 0.3, 7, 2.5, 99.1, 0, 41.2, 3.3],
  [2, -1, "NaN", "Infinity", 8, true, null, "7", 4],
];

function pyValue(value) {
  return value === "NaN" || value === "Infinity" ? `__${value}__` : value;
}

function reportRows(sets) {
  const payload = JSON.stringify(sets.map((set) => set.map(pyValue))).replace(
    /"__(NaN|Infinity)__"/g,
    "$1",
  );
  const script = [
    "import json, sys",
    "sys.path.insert(0, 'tools/agent-player')",
    "from report import _distribution",
    "for values in json.loads(sys.stdin.read()):",
    "    print(_distribution(values))",
  ].join("\n");
  const run = spawnSync("python3", ["-c", script], {
    cwd: root,
    input: payload,
    encoding: "utf8",
  });
  assert.equal(
    run.status,
    0,
    `python3 report.py failed: ${run.error ?? run.stderr}`,
  );
  return run.stdout.trimEnd().split("\n");
}

function jsValue(value) {
  if (value === "NaN") return Number.NaN;
  if (value === "Infinity") return Number.POSITIVE_INFINITY;
  return value;
}

function row({ n, p50, p95, max }) {
  if (n === 0) return "0 | unavailable | unavailable | unavailable";
  return `${n} | ${p50.toFixed(2)} | ${p95.toFixed(2)} | ${max.toFixed(2)}`;
}

test("nearest-rank p50/p95 equal report.py on the shared fixture", () => {
  const expected = reportRows(PERCENTILE_FIXTURE);
  const got = PERCENTILE_FIXTURE.map((set) =>
    row(distribution(set.map(jsValue))),
  );
  assert.deepEqual(got, expected);
});

test("nearest-rank picks the ceil(n*f)th ordered value", () => {
  const twenty = Array.from({ length: 20 }, (_, index) => index + 1);
  assert.deepEqual(distribution(twenty), { n: 20, p50: 10, p95: 19, max: 20 });
  assert.deepEqual(distribution([9, 1]), { n: 2, p50: 1, p95: 9, max: 9 });
  assert.deepEqual(distribution([]), { n: 0, p50: null, p95: null, max: null });
});
