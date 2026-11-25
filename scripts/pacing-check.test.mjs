import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  DEFAULT_BUDGET,
  PacingError,
  buildJobs,
  evaluate,
  fieldCount,
  loadBudget,
  median,
  parseArgs,
  readRows,
  renderMarkdown,
  stageSeconds,
} from "./pacing-check.mjs";

const budget = loadBudget(DEFAULT_BUDGET);
const parks = budget.stages.filter((s) => s.stage !== "boss");

function row({
  policy = "skipper",
  seed = 1,
  dam = 200,
  flume = 200,
  boss = 100,
  outcome = "stages_done",
  note = {},
} = {}) {
  return {
    policy,
    seed,
    class: "tarn",
    outcome,
    game_seconds: dam + flume + boss,
    boss: outcome === "stages_done" ? { seconds: boss - 5 } : null,
    stages: [
      { stage: 1, exit_s: dam, ...note },
      { stage: 2, exit_s: flume, ...note },
      { stage: 3, exit_s: 0 },
    ],
  };
}

test("the budget's run bands agree with its stage bands", () => {
  for (const policy of budget.measure.policies) {
    const lo = budget.stages.reduce((sum, s) => sum + s[policy].min, 0);
    const hi = budget.stages.reduce((sum, s) => sum + s[policy].max, 0);
    assert.ok(
      lo <= budget.run[policy].max,
      `${policy}: stage minimums ${lo} s exceed the run maximum`,
    );
    assert.ok(
      hi >= budget.run[policy].min,
      `${policy}: stage maximums ${hi} s fall short of the run minimum`,
    );
    for (const s of [budget.run[policy], ...budget.stages.map((st) => st[policy])])
      assert.ok(s.floor <= s.min && s.min <= s.max, `${policy}: floor <= min <= max`);
  }
});

test("the required optional content fits between the park bands", () => {
  const result = evaluate(budget, []);
  for (const p of result.planned)
    assert.ok(
      p.required_s <= p.room_s,
      `${p.park}: ${p.required_s} s required, ${p.room_s} s of room`,
    );
});

test("parseArgs needs a source and checks its numbers", () => {
  assert.throws(() => parseArgs([]), PacingError);
  assert.throws(() => parseArgs(["--run", "--jobs=0"]), PacingError);
  assert.throws(() => parseArgs(["--run", "--level=hard"]), PacingError);
  assert.throws(() => parseArgs(["--run", "--seeds=1,x"]), PacingError);
  assert.throws(() => parseArgs(["--run", "--seeds"]), PacingError);
  assert.throws(() => parseArgs(["--budget"]), PacingError);
  const args = parseArgs(["--run", "--seeds=1,2", "--pilots=seed", "--level=target", "--jobs=2"]);
  assert.deepEqual(args.seeds, [1, 2]);
  assert.deepEqual(args.pilots, ["seed"]);
  assert.equal(args.level, "target");
});

test("median handles odd, even and empty lists", () => {
  assert.equal(median([3, 1, 2]), 2);
  assert.equal(median([4, 1, 2, 3]), 2.5);
  assert.equal(median([]), null);
});

test("stageSeconds reads a park's exit and the boss as what follows the last park", () => {
  const r = row({ dam: 130, flume: 150, boss: 95 });
  assert.equal(stageSeconds(r, parks[0], parks), 130);
  assert.equal(stageSeconds(r, parks[1], parks), 150);
  assert.equal(
    stageSeconds(
      r,
      budget.stages.find((s) => s.stage === "boss"),
      parks,
    ),
    95,
  );
  const stalled = row({ outcome: "stalled" });
  assert.equal(
    stageSeconds(
      stalled,
      budget.stages.find((s) => s.stage === "boss"),
      parks,
    ),
    null,
  );
  stalled.stages[1].exit_s = 0;
  assert.equal(stageSeconds(stalled, parks[1], parks), null);
});

test("fieldCount counts lists, numbers and flags, and leaves an absent field pending", () => {
  assert.equal(fieldCount({ a: ["x", "y"] }, "a"), 2);
  assert.equal(fieldCount({ a: 3 }, "a"), 3);
  assert.equal(fieldCount({ a: true }, "a"), 1);
  assert.equal(fieldCount({}, "a"), null);
  assert.equal(fieldCount(undefined, "a"), null);
});

test("the floor passes today's short runs and fails a stall", () => {
  const today = [1, 2, 3].flatMap((seed) => [
    row({ seed, dam: 128, flume: 150, boss: 93 }),
    row({ seed, policy: "completionist", dam: 207, flume: 156, boss: 94 }),
  ]);
  assert.equal(evaluate(budget, today, "floor").pass, true);
  assert.equal(evaluate(budget, today, "target").pass, false);
  const stalled = [...today, row({ seed: 4, outcome: "stalled" })];
  const result = evaluate(budget, stalled, "floor");
  assert.equal(result.pass, false);
  assert.equal(
    result.checks.find((c) => c.id === "reach" && c.policy === "skipper").status,
    "fail",
  );
  assert.equal(result.runs.skipper.stalled[0].seed, 4);
});

test("the floor fails a median under its floor", () => {
  const short = [
    row({ dam: 60, flume: 60, boss: 50 }),
    row({ policy: "completionist", dam: 400, flume: 400, boss: 120 }),
  ];
  const result = evaluate(budget, short, "floor");
  assert.equal(result.pass, false);
  assert.equal(result.checks.find((c) => c.id === "dam" && c.policy === "skipper").status, "fail");
});

test("the target passes a world 1 that fills its bands and content", () => {
  const full = {
    activities_finished: ["a", "b", "c", "d"],
    rogues_beaten: 1,
    secrets_found: ["s"],
    rib_caches_taken: 2,
    events_joined: [],
  };
  const rows = [1, 2, 3].flatMap((seed) => [
    row({ seed, dam: 185, flume: 190, boss: 110, note: { ...full, secrets_found: [] } }),
    row({ seed, policy: "completionist", dam: 480, flume: 490, boss: 120, note: full }),
  ]);
  const result = evaluate(budget, rows, "target");
  assert.deepEqual(
    result.checks.filter((c) => c.status !== "pass"),
    [],
  );
  assert.deepEqual(
    result.content.filter((c) => c.status !== "pass"),
    [],
  );
  assert.equal(result.pass, true);
  const run = result.checks.find((c) => c.id === "run" && c.policy === "completionist");
  assert.ok(Math.abs(run.human_min - (1090 * budget.human_per_bot.value) / 60) < 1e-9);
});

test("a skipper that finds a secret fails the target", () => {
  const rows = [
    row({ dam: 220, flume: 230, boss: 120, note: { secrets_found: ["wall"] } }),
    row({
      policy: "completionist",
      dam: 480,
      flume: 490,
      boss: 120,
      note: { secrets_found: ["wall"] },
    }),
  ];
  const secret = evaluate(budget, rows, "target").content.find(
    (c) => c.slot === "secrets" && c.park === "dam",
  );
  assert.equal(secret.status, "fail");
});

test("readRows reads a folder and its children, and the report names the verdict", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "pacing-"));
  mkdirSync(path.join(dir, "skipper-tarn-1"));
  writeFileSync(path.join(dir, "bots.ndjson"), `${JSON.stringify(row())}\n`);
  writeFileSync(
    path.join(dir, "skipper-tarn-1", "bots.ndjson"),
    `${JSON.stringify(row({ seed: 2 }))}\n\n`,
  );
  const rows = readRows([dir]);
  assert.equal(rows.length, 2);
  const report = renderMarkdown(evaluate(budget, rows, "floor"));
  assert.match(report, /Verdict: FAIL/);
  assert.match(report, /reach Brindle's rout \| completionist \| 0\/0/);
  assert.match(renderMarkdown(evaluate(budget, [], "floor")), /NOTHING MEASURED/);
});

test("buildJobs plays every policy, pilot and seed with the budget's flags", () => {
  const jobs = buildJobs(budget, { seeds: [1, 2], pilots: ["tarn", "seed"] }, "/tmp/out");
  assert.equal(jobs.length, budget.measure.policies.length * 4);
  const first = jobs[0].args;
  assert.ok(
    first.includes("--policy=skipper") &&
      first.includes("--pilot=tarn") &&
      first.includes("--seeds=1"),
  );
  for (const flag of budget.measure.bot_args) assert.ok(first.includes(flag));
  assert.ok(
    !jobs.find((j) => j.label === "skipper seed 1").args.some((a) => a.startsWith("--pilot=")),
  );
  const explore = (label) =>
    jobs.find((j) => j.label === label).args.some((a) => a.startsWith("--explore-by="));
  assert.equal(explore("skipper tarn 1"), false);
  assert.equal(explore("completionist tarn 1"), true);
});

test("a launched run that wrote no row counts against reach", () => {
  const rows = [row(), row({ policy: "completionist", dam: 400, flume: 400, boss: 120 })];
  assert.equal(evaluate(budget, rows, "floor").pass, true);
  const result = evaluate(budget, rows, "floor", { skipper: 2, completionist: 1 });
  assert.equal(result.pass, false);
  assert.equal(result.runs.skipper.runs, 2);
  assert.equal(result.runs.skipper.rows, 1);
});

test("readRows reads a folder named twice once", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "pacing-"));
  mkdirSync(path.join(dir, "a"));
  writeFileSync(path.join(dir, "a", "bots.ndjson"), `${JSON.stringify(row())}\n`);
  assert.equal(readRows([dir, path.join(dir, "a")]).length, 1);
});
