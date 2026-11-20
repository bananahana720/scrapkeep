import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import {
  constBand,
  evaluate,
  joinRuns,
  otherWorld,
  pacingBand,
  parseArgs,
  passed,
  phaseCount,
  receiptRow,
  renderTable,
  ROWS_FILE,
  world1Placeholders,
} from "./world1-bands.mjs";

const SPEC = JSON.parse(readFileSync(ROWS_FILE, "utf8"));

// A routed world 1 run as tools/bot_run.gd and the run log write it: bot record and log line.
function run(
  policy,
  seed,
  { kills = 20, parts = 3, rout = [400, 100], phase = 4, flourishes, extra = {} } = {},
) {
  const bot = {
    run_id: `bot-${seed}`,
    policy,
    seed,
    outcome: rout ? "stages_done" : "stalled",
    stages: [
      { stage: 1, exit_s: rout ? rout[0] / 2 : 200 },
      { stage: 2, exit_s: rout ? rout[0] / 2 : 200 },
      { stage: 3, exit_s: 0 },
    ],
    boss: rout ? { entered_run_s: rout[0], defeated_s: rout[1] } : null,
    game_seconds: rout ? rout[0] + rout[1] : 300,
    ...extra,
  };
  const log = {
    run_id: `bot-${seed}`,
    tallies: { kills },
    brindle_phase_reached: phase,
    stages: [
      { part_ids_at_exit: ["a"] },
      { part_ids_at_exit: Array.from({ length: parts }, (_, i) => `p${i}`) },
      null,
    ],
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

const HEAD = "0123456789abcdef0123456789abcdef01234567";

// A measured column, inside its band, for every band the difficulty row records for the cell.
function bandColumns(cell) {
  const bands = SPEC.rows.find((r) => r.id === "difficulty").targets?.[cell] ?? {};
  return Object.fromEntries(
    Object.entries(bands).map(([col, t]) => [
      col,
      {
        rate:
          t.min != null && t.max != null ? (t.min + t.max) / 2 : t.max != null ? t.max / 2 : t.min,
      },
    ]),
  );
}

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
    frames: Object.fromEntries(
      SPEC.frame_scenes.map((s) => [
        s,
        { pass: true, p99_ms: 12, over_hitch: 0, budget: { hitch_ms: 33 } },
      ]),
    ),
    challenge: {
      table: SPEC.challenge_cells.map((cell) => ({
        cell,
        columns: { expert: { ok: true }, ...bandColumns(cell) },
      })),
    },
    sitting: true,
    playFindings: { rows: [], problems: [] },
    ledger: { rows: [], problems: [] },
    today: "2026-11-15",
    head: HEAD,
    receipts: Object.fromEntries(
      SPEC.rows
        .filter((r) => r.source === "receipt")
        .map((r) => [r.id, { head: HEAD, pass: true, measured: "ok", plant_caught: true }]),
    ),
  };
}

test("a finished world 1 passes every row", () => {
  const rows = evaluate(SPEC, finished());
  const off = rows.filter((r) => !["pass", "info", "his call"].includes(r.verdict));
  // No run carries the panels, rogue or secrets fields yet, and the panel band file is not in the input.
  assert.deepEqual(
    off.map((r) => r.id),
    ["panels-at-brindle", "rogue-reached", "secrets-completionist", "secrets-skipper"],
  );
  assert.ok(off.every((r) => r.status === "report" && !r.blocks));
  assert.equal(passed(rows), true);
  assert.match(renderTable(rows), /READY \(every gate row passes\)/);
});

test("today's world 1 shape: missing pacing file and a short seed list block, report rows do not", () => {
  const inputs = { ...finished(), pacing: null, sitting: false };
  inputs.runs = [
    ...seeds("skipper", { kills: 13, parts: 2 }),
    ...seeds("completionist", { kills: 19, parts: 5 }).slice(0, 6),
  ];
  const rows = evaluate(SPEC, inputs);
  assert.deepEqual(
    rows.filter((r) => r.blocks).map((r) => r.id),
    ["runs-complete", "run-length-skipper", "brindle-length"],
  );
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
  withField.runs = withField.runs.map((r) => ({
    ...r,
    bot: {
      ...r.bot,
      stages: r.bot.stages.map((st) => ({
        ...st,
        secrets_found: r.bot.policy === "completionist" && st.stage === 1 ? ["wall"] : [],
      })),
    },
  }));
  const graded = evaluate(SPEC, withField);
  assert.equal(row(graded, "secrets-skipper").verdict, "pass");
  assert.equal(row(graded, "secrets-completionist").verdict, "pass");
});

test("panels read RUN_BAND from the drop sim test", () => {
  const inputs = finished();
  inputs.runs = inputs.runs.map((r) => ({ ...r, bot: { ...r.bot, panels: Array(4).fill("rib") } }));
  inputs.bandTexts = {
    [SPEC.rows.find((r) => r.id === "panels-at-brindle").band_from.file]:
      "const RUN_BAND := [5.0, 14.0]\n",
  };
  const r = row(evaluate(SPEC, inputs), "panels-at-brindle");
  assert.equal(r.verdict, "miss");
  assert.match(r.threshold, /^5-14 \(panels_drop_sim_test.gd RUN_BAND\)/);
});

test("beats: a missing row, a long beat and a long repeat run each miss", () => {
  const inputs = finished();
  inputs.beatRowsText = BEATS_TEXT.replace('"tarn_sign_on"', '"tarn"');
  inputs.runs[0].log.flourishes = FULL_BEATS.map((b) =>
    b.id === "brindle_rout" ? { ...b, s: 7.5 } : b,
  );
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
  const joined = joinRuns(
    '{"run_id":"bot-1","policy":"skipper"}\n',
    '{"run_id":"bot-1","tallies":{"kills":1}}\n{"run_id":"bot-1","tallies":{"kills":3}}\n',
  );
  assert.equal(joined.length, 1);
  assert.equal(joined[0].log.tallies.kills, 3);
});

test("the rows file names a status and a known source on every row", () => {
  for (const r of SPEC.rows) {
    assert.ok(["gate", "report", "info", "sitting"].includes(r.status), r.id);
    if (r.status === "sitting") {
      assert.equal(r.source, undefined, r.id);
      continue;
    }
    assert.ok(
      [
        "bots",
        "pacing",
        "beats",
        "placeholders",
        "frames",
        "challenge",
        "findings",
        "ledger",
        "receipt",
      ].includes(r.source),
      r.id,
    );
    // A receipt row says which command writes its receipt and which planted fault that check must catch.
    // A promise row (docs/promises) is a receipt row that reports until its card closes, then gates.
    if (r.source === "receipt")
      assert.ok(["gate", "report"].includes(r.status) && r.producer && r.plant, r.id);
    if (r.status === "report")
      assert.ok(Array.isArray(r.enforced_from) && r.enforced_from.length, r.id);
  }
  assert.equal(new Set(SPEC.rows.map((r) => r.id)).size, SPEC.rows.length);
});

test("a promise row reports until its card closes: no receipt or a failing one never blocks, and the table names the card", () => {
  const promises = SPEC.rows.filter((r) => r.source === "receipt" && r.status === "report");
  assert.ok(promises.length > 0);
  for (const r of promises) assert.match(r.enforced_from.join(" "), /^W1-\d+$/, r.id);
  const inputs = finished();
  const [unrun, failing] = promises;
  delete inputs.receipts[unrun.id];
  inputs.receipts[failing.id] = {
    head: HEAD,
    pass: false,
    measured: "0 of 11 packs",
    plant_caught: true,
  };
  const rows = evaluate(SPEC, inputs);
  assert.equal(row(rows, unrun.id).verdict, "no data");
  assert.equal(row(rows, failing.id).verdict, "miss");
  assert.ok(!row(rows, unrun.id).blocks && !row(rows, failing.id).blocks);
  assert.equal(passed(rows), true);
  assert.match(renderTable(rows), new RegExp(`report until ${unrun.enforced_from[0]}`));
});

test("review: a pacing band without numeric min/max, or another schema, never passes", () => {
  assert.equal(pacingBand({ min_s: 390, max_s: 420 }), null);
  assert.equal(pacingBand({ min: 390, max: null }), null);
  const inputs = finished();
  inputs.pacing = { ...PACING, run: { ...PACING.run, skipper: { min_s: 390, max_s: 420 } } };
  const r = row(evaluate(SPEC, inputs), "run-length-skipper");
  assert.equal(r.verdict, "no data");
  assert.ok(r.blocks);
  assert.equal(
    row(evaluate(SPEC, { ...finished(), pacing: { ...PACING, schema: 2 } }), "run-length-skipper")
      .verdict,
    "no data",
  );
});

test("review: a gate median over partly missing runs is no data, not a pass", () => {
  const inputs = finished();
  inputs.runs = inputs.runs.map((r, i) =>
    r.bot.policy === "skipper" && i > 0 ? { ...r, log: { ...r.log, stages: [] } } : r,
  );
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
  inputs.runs = inputs.runs.map((r) =>
    r.bot.policy === "skipper"
      ? {
          ...r,
          bot: {
            ...r.bot,
            stages: [
              { stage: 1, exit_s: 200 },
              { stage: 2, exit_s: 400 },
            ],
          },
        }
      : r,
  );
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
  inputs.runs = inputs.runs.map((r, i) =>
    r.bot.policy === "skipper" && i > 0
      ? { ...r, bot: { ...r.bot, game_seconds: undefined, stages: [] } }
      : r,
  );
  const rows = evaluate(SPEC, inputs);
  assert.equal(row(rows, "run-length-skipper").verdict, "no data");
  assert.ok(row(rows, "run-length-skipper").blocks);
  assert.equal(row(rows, "stage-length-skipper").verdict, "no data");
});

test("the difficulty row grades stored rates again: its own recorded bands, and Learner a1 as information at fights", () => {
  const col = (rate, ok) => ({ rate, ok, n: 24, total: 24, excluded: {} });
  const inputs = finished();
  inputs.challenge.table = SPEC.challenge_cells.map((cell) => ({
    cell,
    kind: cell.startsWith("park") ? "world" : cell === "brindle" ? "boss" : "warden",
    columns: { expert: col(1, true) },
  }));
  const w1 = inputs.challenge.table.find((c) => c.cell === "w1");
  // An older table stored Learner a1 at a Warden as a miss; today it is information only.
  w1.columns.learner1 = col(0.71, false);
  w1.columns.novice = col(0.33, false);
  const spec = {
    ...SPEC,
    rows: SPEC.rows.map((r) => (r.id === "difficulty" ? { ...r, targets: undefined } : r)),
  };
  assert.match(row(evaluate(spec, inputs), "difficulty").measured, /w1 fail/);
  const banded = {
    ...SPEC,
    rows: SPEC.rows.map((r) =>
      r.id === "difficulty" ? { ...r, targets: { w1: { novice: { max: 0.35 } } } } : r,
    ),
  };
  assert.match(row(evaluate(banded, inputs), "difficulty").measured, /w1 pass/);
  w1.columns.novice = col(0.375, true);
  assert.match(row(evaluate(banded, inputs), "difficulty").measured, /w1 fail/);
  // The shipped band is ruling cu's <= 20% (ruling dt): 4 of 24 (16.7%) passes it, 5 of 24 (20.8%) does not.
  // The shipped row also records a Learner a5 band, so that column must be measured for the cell to be graded.
  w1.columns.learner5 = col(0.45, true);
  w1.columns.novice = col(4 / 24, true);
  assert.match(row(evaluate(SPEC, inputs), "difficulty").measured, /w1 pass/);
  w1.columns.novice = col(5 / 24, true);
  assert.match(row(evaluate(SPEC, inputs), "difficulty").measured, /w1 fail/);
  // Today's target applies to a stored pass: 33% was marked ✓ on an old table, and <= 15% fails it.
  w1.columns.novice = col(0.33, true);
  assert.match(row(evaluate(spec, inputs), "difficulty").measured, /w1 fail/);
  // The shipped row: the last measured w1 Novice, 35%, misses ruling cu's band, and the bands are printed.
  w1.columns.novice = col(0.35, true);
  const shipped = row(evaluate(SPEC, inputs), "difficulty");
  assert.match(shipped.measured, /w1 fail/);
  assert.match(
    shipped.threshold,
    /recorded: w1 novice <= 20%, w1 learner5 >= 30% <= 60%, w2 novice <= 15%/,
  );
  // Ruling cu: w1 Learner a5 wins 30 to 60%. 14 of 24 (58.3%) is inside; 15 of 24 (62.5%) and 7 of 24 (29.2%) are not.
  w1.columns.novice = col(4 / 24, true);
  w1.columns.learner5 = col(14 / 24, true);
  assert.match(row(evaluate(SPEC, inputs), "difficulty").measured, /w1 pass/);
  w1.columns.learner5 = col(15 / 24, true);
  assert.match(row(evaluate(SPEC, inputs), "difficulty").measured, /w1 fail/);
  w1.columns.learner5 = col(7 / 24, false);
  assert.match(row(evaluate(SPEC, inputs), "difficulty").measured, /w1 fail/);
  w1.columns.learner5 = col(14 / 24, true);
  // An incomplete column is never a pass: a banded one counts as not measured, any other as incomplete.
  w1.columns.novice = { ...col(0.1, true), incomplete: true };
  assert.match(row(evaluate(SPEC, inputs), "difficulty").measured, /w1 not measured \(novice\)/);
  w1.columns.novice = col(0.1, true);
  w1.columns.expert = { ...col(1, true), incomplete: true };
  assert.match(row(evaluate(SPEC, inputs), "difficulty").measured, /w1 incomplete/);
});

// --- The done rows (ruling dt) ------------------------------------------------------------------

const finding = (id, grade, meets = "The warning does not say where safe ground is") => ({
  id,
  grade,
  meets,
  evidence: "film",
  owner: "look",
  added: "2026-11-10",
  review: "2026-11-20",
});

test("done: every one of the 11 areas has a gate row and one row only Andrew decides", () => {
  const areas = [
    "Core feel",
    "Wardens and bosses",
    "In-run growth",
    "Progression across runs",
    "Pilots",
    "Stages and world",
    "Look",
    "Sound and music",
    "Clarity",
    "Difficulty and pacing",
    "Stability",
  ];
  assert.deepEqual([...new Set(SPEC.rows.map((r) => r.area))].sort(), [...areas].sort());
  for (const area of areas) {
    assert.ok(
      SPEC.rows.some((r) => r.area === area && r.status === "gate"),
      `${area} has no gate row`,
    );
    assert.equal(
      SPEC.rows.filter((r) => r.area === area && r.status === "sitting").length,
      1,
      `${area} needs one sitting row`,
    );
  }
});

test("done: an open major finding in world 1 blocks; another world's finding and a regraded one do not", () => {
  const inputs = finished();
  inputs.playFindings = {
    rows: [
      finding("PF-16", "major"),
      finding("PF-42", "blocker", "World 2 stage 3, the Dig: the Warden never breaks"),
      finding("PF-01", "check"),
    ],
    problems: [],
  };
  let rows = evaluate(SPEC, inputs);
  assert.equal(row(rows, "findings-open").measured, "1 (PF-16)");
  assert.ok(row(rows, "findings-open").blocks);
  assert.equal(row(rows, "findings-undecided").measured, "1 (PF-01)");
  assert.ok(row(rows, "findings-undecided").blocks);
  assert.equal(passed(rows), false);
  assert.equal(otherWorld(finding("PF-41", "major", "World 2, the sinkhole")), true);
  assert.equal(
    otherWorld(finding("PF-46", "major", "The dam's construction incline snags")),
    false,
  );
  inputs.playFindings = {
    rows: [finding("PF-42", "blocker", "World 2 stage 3, the Dig: the Warden never breaks")],
    problems: [],
  };
  rows = evaluate(SPEC, inputs);
  assert.equal(row(rows, "findings-open").verdict, "pass");
  // A file that does not parse, or is missing, is no data and still blocks: silence is never a pass.
  inputs.playFindings = { rows: [], problems: [{ line: 2, message: "bad" }] };
  assert.equal(row(evaluate(SPEC, inputs), "findings-open").verdict, "no data");
  inputs.playFindings = null;
  assert.ok(row(evaluate(SPEC, inputs), "findings-open").blocks);
  // Without --sitting the finding rows are not graded (a finding never holds a promotion, ruling cn).
  assert.equal(
    row(
      evaluate(SPEC, {
        ...finished(),
        sitting: false,
        playFindings: { rows: [finding("PF-16", "major")], problems: [] },
      }),
      "findings-open",
    ).verdict,
    "not run",
  );
});

test("done: a known-failing row past its review date blocks, on the day itself it does not", () => {
  const inputs = finished();
  inputs.ledger = {
    rows: [
      { test: "a_test", review: "2026-11-15" },
      { test: "b_test", review: "2026-11-14" },
    ],
    problems: [],
  };
  const late = row(evaluate(SPEC, inputs), "ledger-reviewed");
  assert.match(late.measured, /^1 of 2 past review on 2026-11-15 \(b_test\)/);
  assert.ok(late.blocks);
  inputs.today = "2026-11-14";
  assert.equal(row(evaluate(SPEC, inputs), "ledger-reviewed").verdict, "pass");
});

test("done: a receipt passes only for the head judged, with its planted fault shown caught", () => {
  const spec = { id: "release-gate", producer: "the gate", plant: "a red test" };
  assert.deepEqual(
    receiptRow(spec, { head: HEAD, pass: true, measured: "CLEAN", plant_caught: true }, HEAD),
    { measured: "CLEAN", pass: true },
  );
  assert.equal(
    receiptRow(spec, { head: HEAD.slice(0, 9), pass: true, plant_caught: true }, HEAD).pass,
    true,
  );
  // No receipt, no head, or another head: no data.
  assert.match(receiptRow(spec, null, HEAD).measured, /^no receipt \(the gate\)/);
  assert.equal(receiptRow(spec, { pass: true, plant_caught: true }, HEAD).noData, true);
  const stale = receiptRow(spec, { head: "ffffffffffff", pass: true, plant_caught: true }, HEAD);
  assert.match(stale.measured, /^stale receipt: written at fffffffff, judging 012345678/);
  assert.equal(stale.pass, false);
  // No head to judge against, or one too short to name a commit: a receipt from any commit must not pass.
  for (const none of [null, undefined, "", "0", "012345", "not-a-sha"]) {
    const unjudged = receiptRow(
      spec,
      { head: HEAD, pass: true, measured: "CLEAN", plant_caught: true },
      none,
    );
    assert.equal(unjudged.pass, false, String(none));
    assert.equal(unjudged.noData, true, String(none));
    assert.match(unjudged.measured, /^no head to judge the receipt against/);
  }
  assert.throws(() => parseArgs(["--head", "0"]), /--head takes 7 to 40 hex/);
  assert.throws(() => parseArgs(["--today", "1"]), /--today takes YYYY-MM-DD/);
  assert.equal(parseArgs(["--head", HEAD.slice(0, 9)]).head, HEAD.slice(0, 9));
  // A pass whose plant was never shown caught is void: a check never seen failing decides nothing.
  const blind = receiptRow(spec, { head: HEAD, pass: true, measured: "CLEAN" }, HEAD);
  assert.match(blind.measured, /^void, the planted fault was not shown caught: CLEAN/);
  assert.equal(blind.pass, false);
  assert.equal(
    receiptRow(spec, { head: HEAD, pass: false, measured: "2 new reds", plant_caught: true }, HEAD)
      .pass,
    false,
  );
  // In the table: one missing receipt keeps world 1 NOT READY and names the command that writes it.
  const inputs = finished();
  delete inputs.receipts["release-gate"];
  const rows = evaluate(SPEC, inputs);
  assert.equal(row(rows, "release-gate").verdict, "no data");
  assert.match(row(rows, "release-gate").measured, /pc\.mjs run/);
  assert.match(renderTable(rows), /NOT READY \(1 gate row\(s\): release-gate\)/);
});

test("done: the rows only Andrew decides are listed, never graded, and never block", () => {
  const rows = evaluate(SPEC, finished());
  const his = rows.filter((r) => r.status === "sitting");
  assert.equal(his.length, 11);
  assert.ok(his.every((r) => r.verdict === "his call" && !r.blocks));
  const text = renderTable(rows);
  assert.match(text, /Only Andrew decides these, at his sitting \(listed, never graded\):/);
  assert.match(text, /- Sound and music: by ear/);
  assert.doesNotMatch(text, /\| by ear/);
});

test("done: CLI takes receipts, a head and a date", () => {
  const args = parseArgs([
    "--receipt",
    "release-gate=r.json",
    "--receipts",
    "dir",
    "--head",
    HEAD,
    "--today",
    "2026-11-20",
    "--sitting",
  ]);
  assert.equal(args.receipts["release-gate"], "r.json");
  assert.deepEqual(args.receiptDirs, ["dir"]);
  assert.equal(args.head, HEAD);
  assert.equal(args.today, "2026-11-20");
  assert.throws(() => parseArgs(["--receipt", "nofile"]), /--receipt takes/);
});

test("done: a difficulty cell that never measured its recorded band is no data, not a pass", () => {
  // Seeded fault: the w1 cell holds only an Expert tick, so ruling cu's Novice and Learner bands were never applied.
  const inputs = finished();
  inputs.challenge.table = inputs.challenge.table.map((c) =>
    c.cell === "w1" ? { cell: "w1", columns: { expert: { ok: true } } } : c,
  );
  const rows = evaluate(SPEC, inputs);
  const d = row(rows, "difficulty");
  assert.equal(d.verdict, "no data");
  assert.match(d.measured, /w1 not measured \(novice, learner5\)/);
  assert.equal(passed(rows), false);
  // An incomplete column counts as not measured too.
  const partial = finished();
  partial.challenge.table.find((c) => c.cell === "w1").columns.novice.incomplete = true;
  assert.match(row(evaluate(SPEC, partial), "difficulty").measured, /w1 not measured \(novice\)/);
});
