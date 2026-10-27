import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import {
  constBand,
  evaluate,
  joinRuns,
  pacingBand,
  parseArgs,
  passed,
  phaseCount,
  renderTable,
  ROWS_FILE,
  world1Placeholders,
} from "./world1-bands.mjs";

const SPEC = JSON.parse(readFileSync(ROWS_FILE, "utf8"));

// A routed world 1 run as tools/bot_run.gd and the run log write it: bot record and log line.
function run(policy, seed, { kills = 20, parts = 3, rout = [400, 100], phase = 4, flourishes, extra = {} } = {}) {
  const bot = {
    run_id: `bot-${seed}`,
    policy,
    seed,
    outcome: rout ? "stages_done" : "stalled",
    stages: [{ stage: 1, exit_s: rout ? rout[0] / 2 : 200 }, { stage: 2, exit_s: rout ? rout[0] / 2 : 200 }, { stage: 3, exit_s: 0 }],
    boss: rout ? { entered_run_s: rout[0], defeated_s: rout[1] } : null,
    game_seconds: rout ? rout[0] + rout[1] : 300,
    ...extra,
  };
  const log = {
    run_id: `bot-${seed}`,
    tallies: { kills },
    brindle_phase_reached: phase,
    stages: [{ part_ids_at_exit: ["a"] }, { part_ids_at_exit: Array.from({ length: parts }, (_, i) => `p${i}`) }, null],
  };
  if (flourishes) log.flourishes = flourishes;
  return { bot, log };
}

const seeds = (policy, opts) => [1, 2, 3, 4, 5, 6, 7, 8].map((s) => run(policy, s, opts));
const row = (rows, id) => rows.find((r) => r.id === id);
const band = (min, max) => ({ min, max, floor: 0 });
const PACING = {
  schema: 1,
  run: { skipper: band(390, 510), completionist: band(900, 1200) },
  stages: [
    { id: "dam", stage: 1, skipper: band(180, 300), completionist: band(420, 600) },
    { id: "flume", stage: 2, skipper: band(180, 300), completionist: band(420, 600) },
    { id: "brindle", stage: "boss", skipper: band(90, 180), completionist: band(90, 180) },
  ],
  beats_repeat_max_s: 30,
};
const BEATS_TEXT = SPEC.beats.map((id) => `"${id}": {}`).join("\n");
const FULL_BEATS = SPEC.beats.map((id) => ({ id, s: 4, full: true, skipped: false, held: 0 }));

function finished() {
  return {
    runs: [
      ...seeds("skipper", { kills: 16, parts: 2, rout: [380, 100], flourishes: FULL_BEATS }),
      ...seeds("completionist", { kills: 34, parts: 6, rout: [940, 120], flourishes: FULL_BEATS }),
      run("skipper", 9, { flourishes: SPEC.beats.map((id) => ({ id, s: 2, full: false })) }),
    ],
    pacing: PACING,
    findings: [],
    beatRowsText: BEATS_TEXT,
    phases: 3,
    frames: Object.fromEntries(SPEC.frame_scenes.map((s) => [s, { pass: true, p99_ms: 12, over_hitch: 0, budget: { hitch_ms: 33 } }])),
    challenge: { table: SPEC.challenge_cells.map((cell) => ({ cell, columns: { expert: { ok: true } } })) },
    sitting: true,
  };
}

test("a finished world 1 passes every row", () => {
  const rows = evaluate(SPEC, finished());
  const off = rows.filter((r) => !["pass", "info"].includes(r.verdict));
  // No run carries the panels, rogue or secrets fields yet, and the panel band file is not in the input.
  assert.deepEqual(off.map((r) => r.id), ["panels-at-brindle", "rogue-reached", "secrets-completionist", "secrets-skipper"]);
  assert.ok(off.every((r) => r.status === "report" && !r.blocks));
  assert.equal(passed(rows), true);
  assert.match(renderTable(rows), /READY \(every gate row passes\)/);
});

test("today's world 1 shape: missing pacing file and a short seed list block, report rows do not", () => {
  const inputs = { ...finished(), pacing: null, sitting: false };
  inputs.runs = [...seeds("skipper", { kills: 13, parts: 2 }), ...seeds("completionist", { kills: 19, parts: 5 }).slice(0, 6)];
  const rows = evaluate(SPEC, inputs);
  assert.deepEqual(rows.filter((r) => r.blocks).map((r) => r.id), ["runs-complete", "run-length-skipper", "brindle-length"]);
  assert.equal(row(rows, "kills-skipper").verdict, "miss");
  assert.equal(row(rows, "kills-skipper").blocks, false);
  assert.equal(row(rows, "difficulty").verdict, "not run");
  assert.equal(passed(rows), false);
});

test("a stall or a fight short of the final phase blocks", () => {
  const inputs = finished();
  inputs.runs = [...inputs.runs.slice(0, 15), run("completionist", 8, { rout: null })];
  inputs.runs[0] = run("skipper", 1, { phase: 2, flourishes: FULL_BEATS });
  const rows = evaluate(SPEC, inputs);
  assert.equal(row(rows, "brindle-routed").verdict, "miss");
  assert.equal(row(rows, "brindle-phases").verdict, "miss");
  assert.ok(row(rows, "brindle-routed").blocks);
});

test("pacing rows grade bot seconds against the pacing file's band", () => {
  const inputs = finished();
  inputs.pacing = { ...PACING, run: { ...PACING.run, skipper: band(390, 420) } };
  const r = row(evaluate(SPEC, inputs), "run-length-skipper");
  assert.equal(r.verdict, "miss");
  assert.equal(r.threshold, "run 390-420 s");
  assert.match(r.measured, /run median 480 s \(8.0 bot-min\)/);
  assert.match(row(evaluate(SPEC, inputs), "brindle-length").measured, /brindle median 100 s/);
});

test("a field no unit has landed reads as no data, never as zero", () => {
  const rows = evaluate(SPEC, finished());
  assert.equal(row(rows, "secrets-skipper").verdict, "no data");
  const withField = finished();
  withField.runs = withField.runs.map((r) => ({ ...r, bot: { ...r.bot, stages: r.bot.stages.map((st) => ({ ...st, secrets_found: r.bot.policy === "completionist" && st.stage === 1 ? ["wall"] : [] })) } }));
  const graded = evaluate(SPEC, withField);
  assert.equal(row(graded, "secrets-skipper").verdict, "pass");
  assert.equal(row(graded, "secrets-completionist").verdict, "pass");
});

test("panels read RUN_BAND from the drop sim test", () => {
  const inputs = finished();
  inputs.runs = inputs.runs.map((r) => ({ ...r, bot: { ...r.bot, panels: Array(4).fill("rib") } }));
  inputs.bandTexts = { [SPEC.rows.find((r) => r.id === "panels-at-brindle").band_from.file]: "const RUN_BAND := [5.0, 14.0]\n" };
  const r = row(evaluate(SPEC, inputs), "panels-at-brindle");
  assert.equal(r.verdict, "miss");
  assert.match(r.threshold, /^5-14 \(panels_drop_sim_test.gd RUN_BAND\)/);
});

test("beats: a missing row, a long beat and a long repeat run each miss", () => {
  const inputs = finished();
  inputs.beatRowsText = BEATS_TEXT.replace('"tarn_sign_on"', '"tarn"');
  inputs.runs[0].log.flourishes = FULL_BEATS.map((b) => (b.id === "brindle_rout" ? { ...b, s: 7.5 } : b));
  inputs.runs[16].log.flourishes = SPEC.beats.map((id) => ({ id, s: 4, full: false }));
  const rows = evaluate(SPEC, inputs);
  assert.match(row(rows, "beats-present").measured, /no row: tarn_sign_on/);
  assert.match(row(rows, "beats-each-short").measured, /brindle_rout 7.50 s/);
  assert.equal(row(rows, "beats-repeat-length").verdict, "miss");
});

test("frames and the challenge table need every world 1 scene and cell", () => {
  const inputs = finished();
  delete inputs.frames.slag_bowl;
  inputs.challenge.table = inputs.challenge.table.filter((c) => c.cell !== "park2");
  const rows = evaluate(SPEC, inputs);
  assert.match(row(rows, "frames").measured, /slag_bowl missing/);
  assert.match(row(rows, "difficulty").measured, /park2 missing/);
  assert.ok(row(rows, "difficulty").blocks);
});

test("placeholders count world 1 parks and everything shared, not other worlds' parks", () => {
  const findings = [
    { kind: "park", where: "park_islands", what: "1 greybox" },
    { kind: "park", where: "park_flume", what: "1 greybox", count: 2 },
    { kind: "icon", where: "x", what: "glyph" },
  ];
  assert.equal(world1Placeholders(findings).length, 2);
  const r = row(evaluate(SPEC, { ...finished(), findings }), "placeholders");
  assert.match(r.measured, /^3 /);
  assert.ok(r.blocks);
});

test("helpers: phase count, const band, run join", () => {
  assert.equal(phaseCount('const PHASE_NAMES := ["Requisition", "Furnace", "Scuttle"]'), 3);
  assert.equal(phaseCount("nothing"), null);
  assert.deepEqual(constBand("const RUN_BAND := [5.0, 14.0]", "RUN_BAND"), { min: 5, max: 14 });
  const joined = joinRuns('{"run_id":"bot-1","policy":"skipper"}\n', '{"run_id":"bot-1","tallies":{"kills":1}}\n{"run_id":"bot-1","tallies":{"kills":3}}\n');
  assert.equal(joined.length, 1);
  assert.equal(joined[0].log.tallies.kills, 3);
});

test("the rows file names a status and a known source on every row", () => {
  for (const r of SPEC.rows) {
    assert.ok(["gate", "report", "info"].includes(r.status), r.id);
    assert.ok(["bots", "pacing", "beats", "placeholders", "frames", "challenge"].includes(r.source), r.id);
    if (r.status === "report") assert.ok(Array.isArray(r.enforced_from) && r.enforced_from.length, r.id);
  }
  assert.equal(new Set(SPEC.rows.map((r) => r.id)).size, SPEC.rows.length);
});

test("review: a pacing band without numeric min/max, or another schema, never passes", () => {
  assert.equal(pacingBand({ min_s: 390, max_s: 420 }), null);
  assert.equal(pacingBand({ min: 390, max: null }), null);
  const inputs = finished();
  inputs.pacing = { ...PACING, run: { ...PACING.run, skipper: { min_s: 390, max_s: 420 } } };
  const r = row(evaluate(SPEC, inputs), "run-length-skipper");
  assert.equal(r.verdict, "no data");
  assert.ok(r.blocks);
  assert.equal(row(evaluate(SPEC, { ...finished(), pacing: { ...PACING, schema: 2 } }), "run-length-skipper").verdict, "no data");
});

test("review: a gate median over partly missing runs is no data, not a pass", () => {
  const inputs = finished();
  inputs.runs = inputs.runs.map((r, i) => (r.bot.policy === "skipper" && i > 0 ? { ...r, log: { ...r.log, stages: [] } } : r));
  const rows = evaluate(SPEC, inputs);
  assert.equal(row(rows, "drops-skipper").verdict, "no data");
  assert.ok(row(rows, "drops-skipper").blocks);
  assert.equal(row(rows, "drops-explore-pays").verdict, "no data");
});

test("review: band_from with the field present but no band file reads no data", () => {
  const inputs = finished();
  inputs.runs = inputs.runs.map((r) => ({ ...r, bot: { ...r.bot, panels: [] } }));
  assert.equal(row(evaluate(SPEC, inputs), "panels-at-brindle").verdict, "no data");
});

test("review: each park, not only the shortest, sits in its stage band", () => {
  const inputs = finished();
  inputs.runs = inputs.runs.map((r) => (r.bot.policy === "skipper" ? { ...r, bot: { ...r.bot, stages: [{ stage: 1, exit_s: 200 }, { stage: 2, exit_s: 400 }] } } : r));
  const r = row(evaluate(SPEC, inputs), "stage-length-skipper");
  assert.equal(r.verdict, "miss");
  assert.match(r.measured, /dam median 200 s.*flume median 400 s/);
});

test("review: a repeat beat with no length is no data; seeds must be 1 to 8", () => {
  const inputs = finished();
  inputs.runs[16].log.flourishes = SPEC.beats.map((id) => ({ id, full: false }));
  assert.equal(row(evaluate(SPEC, inputs), "beats-repeat-length").verdict, "no data");
  const stray = finished();
  stray.runs[7] = run("skipper", 99, { flourishes: FULL_BEATS });
  assert.equal(row(evaluate(SPEC, stray), "runs-complete").verdict, "miss");
});

test("review: CLI values are never flags, frames need a path", () => {
  assert.throws(() => parseArgs(["--bots", "--json"]), /needs a value/);
  assert.throws(() => parseArgs(["--frames", "dam="]), /--frames takes/);
  assert.equal(parseArgs(["--frames", "dam=a.json", "--sitting"]).frames.dam, "a.json");
});

test("review: pacing rows need every run of the policy to carry the measure", () => {
  const inputs = finished();
  inputs.runs = inputs.runs.map((r, i) => (r.bot.policy === "skipper" && i > 0 ? { ...r, bot: { ...r.bot, game_seconds: undefined, stages: [] } } : r));
  const rows = evaluate(SPEC, inputs);
  assert.equal(row(rows, "run-length-skipper").verdict, "no data");
  assert.ok(row(rows, "run-length-skipper").blocks);
  assert.equal(row(rows, "stage-length-skipper").verdict, "no data");
});

test("the difficulty row grades stored rates again: its own recorded bands, and Learner a1 as information at fights", () => {
  const col = (rate, ok) => ({ rate, ok, n: 24, total: 24, excluded: {} });
  const inputs = finished();
  inputs.challenge.table = SPEC.challenge_cells.map((cell) => ({ cell, kind: cell.startsWith("park") ? "world" : cell === "brindle" ? "boss" : "warden", columns: { expert: col(1, true) } }));
  const w1 = inputs.challenge.table.find((c) => c.cell === "w1");
  // An older table stored Learner a1 at a Warden as a miss; today it is information only.
  w1.columns.learner1 = col(0.71, false);
  w1.columns.novice = col(0.33, false);
  const spec = { ...SPEC, rows: SPEC.rows.map((r) => (r.id === "difficulty" ? { ...r, targets: undefined } : r)) };
  assert.match(row(evaluate(spec, inputs), "difficulty").measured, /w1 fail/);
  const banded = { ...SPEC, rows: SPEC.rows.map((r) => (r.id === "difficulty" ? { ...r, targets: { w1: { novice: { max: 0.35 } } } } : r)) };
  assert.match(row(evaluate(banded, inputs), "difficulty").measured, /w1 pass/);
  w1.columns.novice = col(0.375, true);
  assert.match(row(evaluate(banded, inputs), "difficulty").measured, /w1 fail/);
  // Today's target applies to a stored pass: 33% was marked ✓ on an old table, and <= 15% fails it.
  w1.columns.novice = col(0.33, true);
  assert.match(row(evaluate(spec, inputs), "difficulty").measured, /w1 fail/);
  // The shipped row: w1 Novice 33% passes its recorded <= 35% band, and the bands are printed.
  const shipped = row(evaluate(SPEC, inputs), "difficulty");
  assert.match(shipped.measured, /w1 pass/);
  assert.match(shipped.threshold, /recorded: w1 novice <= 35%/);
  // An incomplete column is never a pass.
  w1.columns.novice = { ...col(0.1, true), incomplete: true };
  assert.match(row(evaluate(SPEC, inputs), "difficulty").measured, /w1 incomplete/);
});
