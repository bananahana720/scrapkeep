import assert from "node:assert/strict";
import test from "node:test";
import { BOSSES, COLUMNS, TARGETS, aggregate, buildTable, cellVerdict, describeDoc, estimate, gradeRun, median, meets, pickBuilds, planCells, renderTable, shardJobs, wilson } from "./lib.mjs";

const docs = (n, stage = 2) => Array.from({ length: n }, (_, i) => ({ file: `s${stage}/d${i}.json`, stage, mass: 100 + i * 10, parts: i % 5, pilot: "tarn" }));
const builds = () => Object.fromEntries([2, 3, 4, 5, 6].map((s) => [s, pickBuilds(docs(24, s))]));

test("the targets are the ruling's numbers", () => {
  assert.equal(TARGETS.fight.novice.max, 0.15);
  assert.deepEqual(TARGETS.fight.learner1, { min: 0.15, max: 0.35 });
  assert.equal(TARGETS.fight.learner5.min, 0.6);
  assert.equal(TARGETS.fight.expert.min, 0.85);
  assert.equal(TARGETS.fight.expertTop.min, 0.97);
  assert.equal(TARGETS.world.novice.max, 0.5);
  assert.equal(TARGETS.world.learner1.min, 0.8);
  assert.equal(TARGETS.earliestLearnerBossDeathS, 45);
});

test("a boss run wins on defeated_s, loses on death and times out on a stall", () => {
  const boss = (outcome, b) => ({ outcome, boss: b });
  assert.deepEqual(gradeRun("boss", boss("until", { defeated_s: 61.2, seconds: 61.2, hp_lost: 40 })), { result: "win", fightS: 61.2, hpLost: 40 });
  assert.equal(gradeRun("boss", boss("won", { defeated_s: 80 })).result, "win");
  const loss = gradeRun("boss", boss("died", { defeated_s: null, died_s: 33, seconds: 33.01, hp_lost: 115 }));
  assert.deepEqual([loss.result, loss.diedS], ["loss", 33]);
  assert.equal(gradeRun("boss", boss("boss_stalled", { defeated_s: null, seconds: 420 })).result, "timeout");
  assert.equal(gradeRun("boss", boss("ticks_done", { defeated_s: null, seconds: 400 })).result, "timeout");
  assert.equal(gradeRun("boss", { outcome: "stalled", boss: null }).result, "error");
  assert.equal(gradeRun("boss", null).result, "error");
});

test("a Warden run wins when its stage note shows the break", () => {
  const row = (outcome, note) => ({ outcome, stage_reached: 4, stages: [{ stage: 3, warden_broken_s: 50 }, note] });
  const won = gradeRun("warden", row("until", { stage: 4, warden_engaged_s: 20, warden_broken_s: 52.5, hp_lost: 12 }), { stage: 4 });
  assert.deepEqual(won, { result: "win", fightS: 32.5, hpLost: 12 });
  assert.equal(gradeRun("warden", row("died", { stage: 4, warden_engaged_s: 20, warden_broken_s: null, hp_lost: 90 }), { stage: 4 }).result, "loss");
  for (const outcome of ["stalled", "fight_capped", "ticks_done"]) assert.equal(gradeRun("warden", row(outcome, { stage: 4, warden_broken_s: null }), { stage: 4 }).result, "timeout");
});

test("a park run wins by reaching the Warden", () => {
  assert.equal(gradeRun("world", { outcome: "reached", game_seconds: 90 }).result, "win");
  assert.equal(gradeRun("world", { outcome: "died" }).result, "loss");
  assert.equal(gradeRun("world", { outcome: "stalled" }).result, "timeout");
});

test("Wilson intervals match known values", () => {
  const w = wilson(8, 16);
  assert.ok(Math.abs(w.lo - 0.2800) < 0.002 && Math.abs(w.hi - 0.7200) < 0.002, JSON.stringify(w));
  const z = wilson(0, 10);
  assert.equal(z.lo, 0);
  assert.ok(Math.abs(z.hi - 0.2775) < 0.002);
  assert.deepEqual(wilson(0, 0), { lo: 0, hi: 1 });
  assert.equal(median([3, 1, 2, null]), 2);
  assert.equal(median([1, 2, 3, 4]), 2.5);
});

test("pickBuilds takes the 40th to 60th and 90th and up, never fewer than three", () => {
  const p = pickBuilds(docs(21).reverse());
  assert.deepEqual(p.ordinary.map((d) => d.mass), [180, 190, 200, 210, 220]);
  assert.deepEqual(p.top.map((d) => d.mass), [280, 290, 300]);
  const q = pickBuilds(docs(30));
  assert.equal(q.top.length, 3);
  assert.equal(q.ordinary.length >= 3, true);
  const small = pickBuilds(docs(4));
  assert.equal(small.ordinary.length >= 3, true);
  assert.equal(small.top.length, 3);
  assert.equal(pickBuilds(docs(2)).top.length, 2);
  assert.deepEqual(pickBuilds([]).ordinary, []);
  // Mass first, then parts.
  const tie = pickBuilds([{ file: "a", mass: 5, parts: 3 }, { file: "b", mass: 5, parts: 1 }, { file: "c", mass: 1, parts: 9 }]);
  assert.deepEqual(tie.ranked.map((d) => d.file), ["c", "b", "a"]);
});

test("describeDoc reads the RunStore envelope", () => {
  const d = describeDoc("s2/x.json", JSON.stringify({ generation: 1, run: { stage: 2, class_id: "tarn", mass: 120.5, heft_class: 2, parts: ["a", "b"], hp: 90, max_hp: 115 } }));
  assert.deepEqual(d, { file: "s2/x.json", stage: 2, pilot: "tarn", mass: 120.5, heft_class: 2, parts: 2, hp: 90, max_hp: 115 });
});

test("planCells counts jobs per cell and column, rotates builds and shares seeds across columns", () => {
  const all = planCells({ builds: builds(), seeds: 16 });
  assert.equal(all.length, 3 * 5 * 16 + 6 * 5 * 16 + 3 * 2 * 16);
  const brindle = all.filter((j) => j.cell === "brindle");
  assert.equal(brindle.length, 80);
  assert.ok(brindle.every((j) => j.args.includes("--to-boss=1") && j.args.includes("--until=2") && j.args.includes("--from-stage=2")));
  const top = brindle.filter((j) => j.column === "expertTop");
  assert.ok(top.every((j) => j.build === "top" && j.band === "expert"));
  assert.equal(new Set(top.map((j) => j.entrance)).size, builds()[2].top.length);
  assert.deepEqual(brindle.filter((j) => j.column === "novice").map((j) => j.seed), brindle.filter((j) => j.column === "learner1").map((j) => j.seed));
  const l5 = brindle.find((j) => j.column === "learner5");
  assert.ok(l5.args.includes("--band=learner") && l5.args.includes("--attempt=5"));
  const w3 = all.find((j) => j.cell === "w3");
  assert.ok(w3.args.includes("--until=3") && w3.args.includes("--ticks=29700") && w3.policy === "brawler");
  const world1 = all.filter((j) => j.cell === "world1");
  assert.ok(world1.every((j) => j.entrance === null && !j.missing && !j.args.some((a) => a.startsWith("--from-stage")) && j.args.includes("--stop-at=engaged:2") && j.policy === "skipper"));
  const world3 = all.find((j) => j.cell === "world3");
  assert.ok(world3.args.includes("--from-stage=5") && world3.args.includes("--stop-at=engaged:6") && world3.entrance);
  assert.equal(new Set(all.map((j) => j.id)).size, all.length);
});

test("planCells filters by kind, id and column, and flags a stage with no builds", () => {
  const jobs = planCells({ builds: builds(), seeds: 2, cells: ["boss", "warden"], only: ["w1", "brindle"], columns: ["novice", "expert"] });
  assert.deepEqual([...new Set(jobs.map((j) => j.cell))].sort(), ["brindle", "w1"]);
  assert.equal(jobs.length, 2 * 2 * 2);
  assert.ok(planCells({ builds: {}, seeds: 1, only: ["w2"] }).every((j) => j.missing));
  assert.ok(!planCells({ builds: {}, seeds: 1, only: ["w1", "world1"] }).some((j) => j.missing));
});

test("sharding splits the job list evenly, deterministically and without overlap", () => {
  const all = planCells({ builds: builds(), seeds: 4 });
  const shards = [1, 2, 3].map((i) => shardJobs(all, `${i}/3`));
  assert.equal(shards.reduce((s, x) => s + x.length, 0), all.length);
  assert.equal(new Set(shards.flat().map((j) => j.id)).size, all.length);
  assert.deepEqual(shardJobs(all, "2/3").map((j) => j.id), shards[1].map((j) => j.id));
  assert.equal(shardJobs(all, null), all);
  assert.throws(() => shardJobs(all, "0/3"));
  assert.throws(() => shardJobs(all, "x"));
});

test("a target is met by the point estimate", () => {
  assert.equal(meets({ max: 0.15 }, 0.15), true);
  assert.equal(meets({ max: 0.15 }, 0.2), false);
  assert.equal(meets({ min: 0.15, max: 0.35 }, 0.1), false);
  assert.equal(meets({ min: 0.15, max: 0.35 }, 0.25), true);
  assert.equal(meets(null, 0.5), null);
});

const run = (cell, kind, stage, column, result, extra = {}) => ({ id: `${cell}-${column}-${Math.random()}`, cell, kind, stage, column, grade: { result, ...extra } });

test("the table marks each column ✓ or ✗ against its target and reports the growth ratio", () => {
  const runs = [];
  for (let i = 0; i < 20; i++) {
    runs.push(run("brindle", "boss", 2, "novice", i < 2 ? "win" : "loss", { fightS: 70, hpLost: 100, diedS: 50 }));
    runs.push(run("brindle", "boss", 2, "learner1", i < 7 ? "win" : "loss", { fightS: 80, hpLost: 90, diedS: i === 19 ? 30 : 60 }));
    runs.push(run("brindle", "boss", 2, "expert", i < 19 ? "win" : "timeout", { fightS: 60, hpLost: 30 }));
    runs.push(run("brindle", "boss", 2, "expertTop", "win", { fightS: 30, hpLost: 10 }));
  }
  for (let i = 0; i < 10; i++) runs.push(run("world1", "world", 1, "novice", i < 8 ? "win" : "loss", { fightS: 100 }));
  const table = buildTable(runs);
  const b = table.find((c) => c.cell === "brindle");
  assert.equal(b.columns.novice.ok, true);
  assert.equal(b.columns.learner1.ok, true);
  assert.equal(b.columns.expert.ok, true);
  assert.equal(b.columns.expertTop.ok, true);
  assert.equal(b.growthRatio, 0.5);
  assert.deepEqual(b.tell, { earlyDeaths: 1, earliestDeathS: 30, ok: false });
  assert.equal(cellVerdict(b), "fail");
  const w = table.find((c) => c.cell === "world1");
  assert.equal(w.columns.novice.ok, false);
  assert.equal(table[0].cell, "brindle");
  const md = renderTable(table, { label: "t" });
  assert.match(md, /\| brindle \| 10% \(20\) \[\d+%-\d+%\] ✓ vs <= 15% \|/);
  assert.match(md, /35% \(20\) \[\d+%-\d+%\] ✓ vs 15%-35%/);
  assert.match(md, /95% \(20\) \[\d+%-\d+%\] ✓ vs >= 85% \(1 timeout\)/);
  assert.match(md, /80% \(10\) \[\d+%-\d+%\] ✗ vs <= 50%/);
  assert.match(md, /1 ✗ \(earliest 30\.0 s\)/);
  assert.match(md, /Cells with a ✗: brindle, world1\./);
  assert.ok(aggregate([{ result: "win", fightS: 1 }]).rate === 1);
});

test("a cell short of its target shows ✗ and a timeout is not a win", () => {
  const runs = Array.from({ length: 10 }, (_, i) => run("w1", "warden", 1, "expert", i < 5 ? "win" : "timeout", { fightS: 20 }));
  const [c] = buildTable(runs);
  assert.equal(c.columns.expert.rate, 0.5);
  assert.equal(c.columns.expert.ok, false);
  assert.match(renderTable([c]), /50% \(10\) \[\d+%-\d+%\] ✗ vs >= 85% \(5 timeout\)/);
});

test("the dry-run estimate scales with jobs and parallelism", () => {
  const jobs = planCells({ builds: builds(), seeds: 1 });
  const e = estimate(jobs, 4, { boss: 100, warden: 100, world: 100 });
  assert.equal(e.jobs, jobs.length);
  assert.equal(e.wallSeconds, Math.ceil((jobs.length * 100) / 4));
  assert.equal(BOSSES.length, 3);
  assert.equal(COLUMNS.length, 5);
});
