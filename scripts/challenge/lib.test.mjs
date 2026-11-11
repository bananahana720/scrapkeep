import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { BOSSES, COLUMNS, TARGETS, aggregate, buildTable, cellVerdict, describeDoc, estimate, gradeRun, mergeLibraryIndexes, wallStats, checkMerge, planHash, jobKey, dedupeBy, bucketInfo, fightStart, median, meets, pickBuilds, planCells, renderTable, shardJobs, wilson, maxJobs, settledMark, columnTarget, MAX_RUN_TIER, botArgs, qaRows, playerReport, renderPlayerReport, QA_KINDS, FAIRNESS, fairnessOf, fairnessPool, fairnessByCell, renderFairness } from "./lib.mjs";

const docs = (n, stage = 2) => Array.from({ length: n }, (_, i) => ({ file: `s${stage}/d${i}.json`, stage, mass: 100 + i * 10, parts: i % 5, pilot: "tarn" }));
const builds = () => Object.fromEntries([2, 3, 4, 5, 6].map((s) => [s, pickBuilds(docs(24, s))]));

test("the targets are the ruling's numbers", () => {
  assert.equal(TARGETS.fight.novice.max, 0.15);
  // Learner attempt 1 at bosses and Wardens is information only (DECISIONS section 5, 19 Oct 19:00).
  assert.equal(TARGETS.fight.learner1, undefined);
  assert.equal(TARGETS.fight.learner5.min, 0.6);
  assert.equal(TARGETS.fight.expert.min, 0.85);
  assert.equal(TARGETS.fight.expertTop.min, 0.97);
  assert.equal(TARGETS.world.novice.max, 0.5);
  assert.equal(TARGETS.world.learner1.min, 0.8);
  assert.equal(TARGETS.earliestLearnerBossDeathS, 45);
});

test("a boss run wins on defeated_s, loses on death and times out on a stall", () => {
  const boss = (outcome, b) => ({ outcome, boss: b });
  assert.deepEqual(gradeRun("boss", boss("until", { defeated_s: 61.2, seconds: 61.2, hp_lost: 40 })), { result: "win", fightS: 61.2, hpLost: 40, largestShare: null, largestSource: null, hp45Share: null, largestHullShare: null, hull45Share: null });
  assert.equal(gradeRun("boss", boss("won", { defeated_s: 80 })).result, "win");
  const loss = gradeRun("boss", boss("died", { defeated_s: null, died_s: 33, seconds: 33.01, hp_lost: 115 }));
  assert.deepEqual([loss.result, loss.diedS], ["loss", 33]);
  assert.equal(gradeRun("boss", boss("boss_stalled", { defeated_s: null, seconds: 420 })).result, "timeout");
  assert.equal(gradeRun("boss", boss("ticks_done", { defeated_s: null, seconds: 400 })).result, "timeout");
  assert.equal(gradeRun("boss", { outcome: "stalled", boss: null }).result, "error");
  assert.equal(gradeRun("boss", boss("boss", { defeated_s: null, seconds: 2 })).result, "error");
  assert.equal(gradeRun("boss", null).result, "error");
});

test("a Warden run wins when its stage note shows the break", () => {
  const row = (outcome, note) => ({ outcome, stage_reached: 4, stages: [{ stage: 3, warden_broken_s: 50 }, note] });
  const won = gradeRun("warden", row("until", { stage: 4, warden_engaged_s: 20, warden_broken_s: 52.5, hp_lost: 12 }), { stage: 4 });
  assert.deepEqual(won, { result: "win", fightS: 32.5, hpLost: 12, largestShare: null, largestSource: null, hp45Share: null, largestHullShare: null, hull45Share: null });
  assert.equal(gradeRun("warden", row("died", { stage: 4, warden_engaged_s: 20, warden_broken_s: null, hp_lost: 90 }), { stage: 4 }).result, "loss");
  for (const outcome of ["stalled", "fight_capped", "ticks_done"]) assert.equal(gradeRun("warden", row(outcome, { stage: 4, warden_broken_s: null }), { stage: 4 }).result, "timeout");
});

test("a fight carries the comps report: largest hit share and first-45 s damage", () => {
  const row = { outcome: "died", max_hp: 100, boss: { defeated_s: null, died_s: 70, seconds: 70, hp_lost: 130, largest_hit: 34, largest_hit_share: 0.34, largest_hit_source: "slag", hp_lost_45s: 22 } };
  const g = gradeRun("boss", row);
  assert.deepEqual([g.largestShare, g.largestSource, g.hp45Share], [0.34, "slag", 0.22]);
  // No hit in the first 45 s is a zero share, not a missing one.
  assert.equal(gradeRun("boss", { outcome: "won", max_hp: 80, boss: { defeated_s: 50 } }).hp45Share, 0);
  const w = gradeRun("warden", { outcome: "until", max_hp: 90, stages: [{ stage: 2, max_hp: 120, warden_engaged_s: 5, warden_broken_s: 60, largest_hit: 30 }] }, { stage: 2 });
  assert.equal(w.largestShare, 0.25); // the stage note's max_hp wins over the record's
  const a = aggregate([g, { ...g, largestShare: 0.5, largestSource: "charge", hp45Share: 0.4 }, { result: "error" }]);
  assert.deepEqual([a.largestShare, a.largestSource, a.medianHp45Share, a.maxHp45Share], [0.5, "charge", 0.31, 0.4]);
  // A Warden the bot never engaged reports nothing, so it cannot pull the 45 s median toward zero.
  const cold = gradeRun("warden", { outcome: "stalled", max_hp: 90, stages: [{ stage: 2, max_hp: 90, warden_engaged_s: null, warden_fight_s: null }] }, { stage: 2 });
  assert.deepEqual([cold.result, cold.largestShare, cold.hp45Share], ["timeout", null, null]);
  const runs = [{ cell: "brindle", kind: "boss", stage: 2, column: "learner1", grade: g }, { cell: "brindle", kind: "boss", stage: 2, column: "expert", grade: { result: "win", fightS: 64, largestShare: 0.2, largestSource: "slag", hp45Share: 0.1 } }];
  const md = renderTable(buildTable(runs));
  assert.match(md, /## Fight report/);
  assert.match(md, /\| brindle \| 64\.0 \| 34% \(slag\) \| 22% \/ 22% \| - \| - \|/);
  // Scrap armour: the hull columns show what reached the hull; a pre-hull row reads blank, not zero.
  const armoured = gradeRun("boss", { outcome: "won", max_hp: 100, boss: { defeated_s: 40, hp_lost: 210, hp_lost_45s: 150, largest_hit: 30, largest_hit_share: 0.3, largest_hit_source: "lane", hull_lost: 12, hull_lost_45s: 12, largest_hull_hit: 6, largest_hull_hit_share: 0.06 } });
  assert.deepEqual([armoured.hp45Share, armoured.hull45Share, armoured.largestHullShare], [1.5, 0.12, 0.06]);
  assert.deepEqual([g.hull45Share, g.largestHullShare], [null, null]);
  const md2 = renderTable(buildTable([{ cell: "mind", kind: "boss", stage: 5, column: "learner1", grade: armoured }]));
  assert.match(md2, /\| mind \| - \| 30% \(lane\) \| 150% \/ 150% \| 6% \| 12% \/ 12% \|/);
});

test("a park run wins by reaching the Warden", () => {
  assert.equal(gradeRun("world", { outcome: "reached", game_seconds: 90 }).result, "win");
  assert.equal(gradeRun("world", { outcome: "died" }).result, "loss");
  // run_ended(false) after a death the run cannot survive reads "lost" (bot_driver.gd): a loss, not a stall.
  assert.equal(gradeRun("warden", { outcome: "lost", stage_reached: 1, stages: [{ stage: 1 }] }).result, "loss");
  assert.equal(gradeRun("world", { outcome: "lost" }).result, "loss");
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
  const all = planCells({ builds: builds() });
  assert.equal(all.length, 3 * 5 * 24 + 6 * 5 * 24 + 6 * 2 * 16);
  const brindle = all.filter((j) => j.cell === "brindle");
  assert.equal(brindle.length, 120);
  assert.ok(brindle.every((j) => j.args.includes("--to-boss=1") && j.args.includes("--until=2") && j.args.includes("--from-stage=2")));
  const top = brindle.filter((j) => j.column === "expertTop");
  assert.ok(top.every((j) => j.build === "top" && j.band === "expert"));
  assert.equal(new Set(top.map((j) => j.entrance)).size, builds()[2].top.length);
  assert.deepEqual(brindle.filter((j) => j.column === "novice").map((j) => j.seed), brindle.filter((j) => j.column === "learner1").map((j) => j.seed));
  const l5 = brindle.find((j) => j.column === "learner5");
  assert.ok(l5.args.includes("--band=learner") && l5.args.includes("--attempt=5"));
  const w3 = all.find((j) => j.cell === "w3");
  assert.ok(w3.args.includes("--until=3") && w3.args.includes("--fight-limit=240") && w3.args.includes("--stage-limit=600") && w3.args.includes("--ticks=63000"));
  assert.equal(w3.policy, "skipper");
  assert.equal(brindle[0].policy, "brawler");
  assert.equal(planCells({ builds: builds(), seeds: 1, only: ["w3"], wardenPersona: "brawler" })[0].policy, "brawler");
  // Parks are the default park measure: park N stops at its own Warden, so a park run never fights a Warden.
  const park1 = all.filter((j) => j.cell === "park1");
  assert.ok(park1.length && park1.every((j) => j.kind === "world" && j.entrance === null && !j.args.some((a) => a.startsWith("--from-stage")) && j.args.includes("--stop-at=engaged:1")));
  const park4 = all.find((j) => j.cell === "park4");
  assert.ok(park4.args.includes("--from-stage=4") && park4.args.includes("--stop-at=engaged:4") && park4.entrance);
  assert.notDeepEqual(park4.seed, all.find((j) => j.cell === "w4").seed);
  assert.ok(!all.some((j) => j.cell === "world1"), "the world chain runs only when asked for");
  // pilot.* dials need --tune-unruled on the game side; the harness passes it only when asked.
  assert.ok(!all.some((j) => j.args.includes("--tune-unruled")));
  const unruled = planCells({ builds: builds(), seeds: 1, only: ["brindle"], tune: "pilot.regen_delay_mult=2", tuneUnruled: true })[0];
  assert.ok(unruled.args.includes("--tune=pilot.regen_delay_mult=2") && unruled.args.includes("--tune-unruled"));
  const chain = planCells({ builds: builds(), seeds: 2, cells: ["world"] });
  const world1 = chain.filter((j) => j.cell === "world1");
  assert.ok(world1.every((j) => j.entrance === null && !j.missing && !j.args.some((a) => a.startsWith("--from-stage")) && j.args.includes("--stop-at=engaged:2") && j.policy === "skipper"));
  const world3 = chain.find((j) => j.cell === "world3");
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
    runs.push(run("brindle", "boss", 2, "expert", i < 19 ? "win" : "timeout", { fightS: 60, hpLost: 30, reason: "boss_stalled" }));
    runs.push(run("brindle", "boss", 2, "expertTop", "win", { fightS: 30, hpLost: 10 }));
  }
  for (let i = 0; i < 10; i++) runs.push(run("park1", "world", 1, "novice", i < 8 ? "win" : "loss", { fightS: 100 }));
  for (let i = 0; i < 10; i++) runs.push(run("world1", "world", 1, "novice", i < 8 ? "win" : "loss", { fightS: 100 }));
  const table = buildTable(runs);
  const b = table.find((c) => c.cell === "brindle");
  assert.equal(b.columns.novice.ok, true);
  assert.equal(b.columns.learner1.ok, null);
  assert.equal(b.columns.learner1.target, null);
  assert.equal(b.columns.expert.ok, true);
  assert.equal(b.columns.expertTop.ok, true);
  assert.equal(b.growthRatio, 0.5);
  assert.deepEqual(b.tell, { earlyDeaths: 1, earliestDeathS: 30, ok: false });
  assert.equal(cellVerdict(b), "fail");
  const p = table.find((c) => c.cell === "park1");
  assert.equal(p.columns.novice.ok, false);
  // The world chain is information only (ruling 19 Oct 04:32Z): same runs, no target, no ✓/✗, never failing.
  const w = table.find((c) => c.cell === "world1");
  assert.equal(w.columns.novice.target, null);
  assert.equal(w.columns.novice.ok, null);
  assert.equal(cellVerdict(w), "info");
  assert.equal(table[0].cell, "brindle");
  const md = renderTable(table, { label: "t" });
  assert.match(md, /\| brindle \| 10% \(20\) \[\d+%-\d+%\] ✓ vs <= 15% \(18 died\) \|/);
  // Learner a1 at a fight cell prints its rate with no mark and no target.
  assert.match(md, /\| 35% \(20\) \[\d+%-\d+%\] \(13 died\) \|/);
  assert.match(md, /Learner a1 at bosses and Wardens is information only/);
  assert.match(md, /95% \(20\) \[\d+%-\d+%\] ✓ vs >= 85% \(1 capped\)/);
  assert.match(md, /80% \(10\) \[\d+%-\d+%\] ✗ vs <= 50%/);
  assert.match(md, /1 ✗ \(earliest 30\.0 s\)/);
  assert.match(md, /## Parks \(reach the Warden\)[\s\S]*\| park1 \| 80% \(10\) \[\d+%-\d+%\] ✗ vs <= 50%/);
  assert.match(md, /## World chains \(information only, not graded\)[\s\S]*\| world1 \| 80% \(10\) \[\d+%-\d+%\] \(2 died\) \|/);
  assert.match(md, /Cells with a ✗: brindle, park1\./);
  assert.ok(aggregate([{ result: "win", fightS: 1 }]).rate === 1);
});

test("a cell short of its target shows ✗ and a timeout is not a win", () => {
  const runs = Array.from({ length: 10 }, (_, i) => run("w1", "warden", 1, "expert", i < 5 ? "win" : "timeout", { fightS: 20, reason: "stalled" }));
  const [c] = buildTable(runs);
  assert.equal(c.columns.expert.rate, 0.5);
  assert.equal(c.columns.expert.ok, false);
  assert.match(renderTable([c]), /50% \(10\) \[\d+%-\d+%\] ✗ vs >= 85% \(5 stalled\)/);
});

test("the dry-run estimate scales with jobs and parallelism", () => {
  const jobs = planCells({ builds: builds(), seeds: 1 });
  const e = estimate(jobs, 4, { boss: 100, warden: 100, world: 100 });
  assert.equal(e.jobs, jobs.length);
  assert.equal(e.wallSeconds, Math.ceil((jobs.length * 100) / 4));
  assert.equal(BOSSES.length, 3);
  assert.equal(COLUMNS.length, 5);
});

test("a fight cap and a stall are timeouts shown beside deaths", () => {
  const row = (outcome) => ({ outcome, stage_reached: 1, stages: [{ stage: 1, warden_engaged_s: 20, warden_broken_s: null, hp_lost: 5 }] });
  assert.deepEqual(gradeRun("warden", row("fight_capped"), { stage: 1 }), { result: "timeout", reason: "fight_capped", fightS: null, hpLost: 5, largestShare: null, largestSource: null, hp45Share: null, largestHullShare: null, hull45Share: null });
  assert.equal(gradeRun("warden", row("stalled"), { stage: 1 }).reason, "stalled");
  const a = aggregate([{ result: "win" }, { result: "loss" }, { result: "timeout", reason: "fight_capped" }, { result: "timeout", reason: "stalled" }]);
  assert.deepEqual([a.losses, a.capped, a.stalled, a.rate], [1, 1, 1, 0.25]);
  const [c] = buildTable([run("w2", "warden", 2, "expert", "win"), run("w2", "warden", 2, "expert", "loss"), run("w2", "warden", 2, "expert", "timeout", { reason: "fight_capped" }), run("w2", "warden", 2, "expert", "timeout", { reason: "stalled" })]);
  assert.match(renderTable([c]), /\(1 died, 1 capped, 1 stalled\)/);
});

test("shard libraries join into one index and run folders carry no machine paths that matter", () => {
  const idx = (n, pilot) => Array.from({ length: n }, (_, i) => ({ file: `s2/${pilot}-${i}.json`, stage: 2, mass: i }));
  const merged = mergeLibraryIndexes([{ dir: "/a", index: idx(2, "tarn") }, { dir: "/b", index: [...idx(2, "tally"), ...idx(1, "tarn")] }]);
  assert.equal(merged.length, 4);
  assert.deepEqual(merged.map((d) => d.from).sort(), ["/a", "/a", "/b", "/b"]);
  // Grading reads the record only, never the entrance path.
  const runs = [{ id: "x", cell: "w1", kind: "warden", stage: 1, column: "expert", entrance: "/other/machine/s2/a.json", row: { outcome: "until", stage_reached: 2, game_seconds: 90, stages: [{ stage: 1, warden_engaged_s: 5, warden_broken_s: 30, hp_lost: 1 }] } }];
  assert.equal(buildTable(runs)[0].columns.expert.wins, 1);
  const w = wallStats([{ kind: "boss", wallS: 100, row: { game_seconds: 80 } }, { kind: "boss", wallS: 300, row: { game_seconds: 90 } }, { kind: "boss", wallS: 200, row: { game_seconds: 70 } }]);
  assert.deepEqual(w.boss, { jobs: 3, medianWallS: 200, maxWallS: 300, medianGameS: 80 });
  const shardsOfLib = [1, 2, 3].map((i) => shardJobs(Array.from({ length: 48 }, (_, k) => ({ id: k })), `${i}/3`));
  assert.equal(shardsOfLib.flat().length, 48);
});

test("errors and kills are excluded from n and the rate; over 10% excluded makes the column incomplete", () => {
  const g = (result, extra = {}) => ({ result, ...extra });
  const a = aggregate([...Array(9).fill(g("win")), g("loss"), g("error")]);
  assert.deepEqual([a.n, a.total, a.rate, a.excluded, a.incomplete], [10, 11, 0.9, { error: 1, killed: 0 }, false]);
  const b = aggregate([...Array(7).fill(g("win")), g("killed"), g("killed"), g("error")]);
  assert.equal(b.incomplete, true);
  assert.equal(b.n, 7);
  const runs = [...Array(7).fill(0).map(() => run("w2", "warden", 2, "expert", "win")), run("w2", "warden", 2, "expert", "killed"), run("w2", "warden", 2, "expert", "error")];
  const [c] = buildTable(runs);
  assert.equal(c.columns.expert.ok, null);
  assert.equal(cellVerdict(c), "incomplete");
  const md = renderTable([c]);
  assert.match(md, /incomplete: 7 of 9 counted \(excluded: 1 error, 1 killed\)/);
  assert.match(md, /Incomplete cells.*w2/);
  const ok = buildTable([...Array(19).fill(0).map(() => run("w2", "warden", 2, "expert", "win")), run("w2", "warden", 2, "expert", "killed")])[0];
  assert.equal(ok.columns.expert.ok, true);
  assert.match(renderTable([ok]), /100% \(19\).*✓ vs >= 85% \(excluded: 1 killed\)/);
  assert.equal(gradeRun("boss", { resumed: false, outcome: "until", boss: { defeated_s: 50 } }).result, "error");
  assert.equal(gradeRun("boss", { resumed: true, outcome: "until", boss: { defeated_s: 50 } }).result, "win");
});

test("the Warden fight clock is the later of the turn and the engagement", () => {
  assert.equal(fightStart({ warden_fight_s: 30, warden_engaged_s: 20 }), 30);
  assert.equal(fightStart({ warden_fight_s: null, warden_engaged_s: 20 }), 20);
  assert.equal(fightStart({ warden_fight_s: 5, warden_engaged_s: null }), 5);
  const row = { outcome: "until", stages: [{ stage: 1, warden_fight_s: 30, warden_engaged_s: 20, warden_broken_s: 70 }] };
  assert.equal(gradeRun("warden", row, { stage: 1 }).fightS, 40);
});

test("a plan hash and job key tell experiments apart", () => {
  const o = { libraryLabel: "lib", libraryDigest: "d", cells: ["boss"], only: null, seeds: 24, columns: ["expert"], persona: "brawler", wardenPersona: "skipper", parkPersona: "skipper", tune: "" };
  const h = planHash(o);
  assert.equal(h, planHash({ ...o }));
  for (const change of [{ seeds: 16 }, { columns: ["novice"] }, { persona: "skipper" }, { tune: "x" }, { libraryLabel: "other" }, { libraryDigest: "e" }]) assert.notEqual(planHash({ ...o, ...change }), h);
  const j = { id: "w1-expert-40300" };
  assert.notEqual(jobKey(j, { libraryLabel: "lib", plan: h, commit: "aaaaaaaa11" }), jobKey(j, { libraryLabel: "lib", plan: h, commit: "bbbbbbbb11" }));
  assert.equal(dedupeBy([{ id: 1, v: "old" }, { id: 2 }, { id: 1, v: "new" }]).find((r) => r.id === 1).v, "new");
});

test("merging refuses different plans or commits and missing shards", () => {
  const m = (i, over = {}) => ({ shard: `${i}/3`, plan_hash: "p", commit: "c", library: "lib", ...over });
  assert.deepEqual(checkMerge([m(1), m(2), m(3)]).errors, []);
  assert.match(checkMerge([m(1), m(3)]).errors[0], /shard 2\/3 is missing/);
  assert.match(checkMerge([m(1), m(2), m(3, { commit: "d" })]).errors[0], /commit/);
  assert.match(checkMerge([m(1), m(2), m(3, { plan_hash: "q" })]).errors[0], /plan hash/);
  const mixed = checkMerge([m(1), m(2), m(3, { commit: "d" })], { allowMixed: true });
  assert.deepEqual(mixed.errors, []);
  assert.equal(mixed.warnings.length, 1);
  assert.ok(checkMerge([m(1), m(2, { shard: "2/4" }), m(3)]).errors.length > 0);
  assert.ok(checkMerge([m(1), m(1), m(2), m(3)]).errors.some((e) => /twice/.test(e)));
  assert.ok(checkMerge([null]).errors.length > 0);
  assert.deepEqual(checkMerge([{ shard: null, plan_hash: "p", commit: "c", library: "l" }]).errors, []);
});

test("overlapping buckets are reported and mark the Expert-top column and the ratio", () => {
  const small = pickBuilds(docs(4, 2));
  assert.ok(small.overlap > 0);
  assert.equal(pickBuilds(docs(40, 2)).overlap, 0);
  const info = bucketInfo({ 2: small });
  assert.equal(info[2].docs, 4);
  const runs = [run("brindle", "boss", 2, "expert", "win", { fightS: 50 }), run("brindle", "boss", 2, "expertTop", "win", { fightS: 40 })];
  const table = buildTable(runs, info);
  assert.equal(table[0].overlap, small.overlap);
  const md = renderTable(table, { buckets: info });
  assert.match(md, /✓ vs >= 97% \(overlaps ordinary\)/);
  assert.match(md, /0\.8 \(overlaps ordinary\)/);
  assert.match(md, /## Build buckets/);
  assert.match(md, /\| 2 \| 4 \| \d \| \d \| \d \(Expert top overlaps ordinary\) \|/);
  assert.match(md, /top\/ord \(reported, not graded\)/);
  assert.doesNotMatch(renderTable(buildTable(runs, { 2: pickBuilds(docs(40, 2)) }), {}), /overlaps ordinary/);
});

test("the 45 s check covers Learner attempt 1 and attempt 5", () => {
  const runs = [
    run("brindle", "boss", 2, "learner1", "loss", { diedS: 60 }),
    run("brindle", "boss", 2, "learner5", "loss", { diedS: 40 }),
    run("brindle", "boss", 2, "learner5", "win", {}),
  ];
  const [c] = buildTable(runs);
  assert.deepEqual(c.tell, { earlyDeaths: 1, earliestDeathS: 40, ok: false });
  assert.equal(cellVerdict(c), "fail");
  const clean = buildTable([run("brindle", "boss", 2, "learner5", "loss", { diedS: 50 })])[0];
  assert.equal(clean.tell.ok, true);
});

test("--tier passes --run-tier to every job, joins the plan hash only when set, and titles the table", () => {
  const jobs = planCells({ builds: {}, seeds: 2, cells: ["warden"], only: ["w1"], tier: 1 });
  assert.ok(jobs.length > 0 && jobs.every((j) => j.args.includes("--run-tier=1") && !j.args.some((a) => a.startsWith("--from-stage="))));
  assert.ok(planCells({ builds: {}, seeds: 1, cells: ["warden"], only: ["w1"] }).every((j) => !j.args.some((a) => a.startsWith("--run-tier"))));
  const plan = { cells: ["warden"], only: ["w1"], seeds: 24, columns: ["expert"], tune: "" };
  assert.equal(planHash({ ...plan, tier: 0 }), planHash(plan));
  assert.notEqual(planHash({ ...plan, tier: 1 }), planHash(plan));
  assert.notEqual(planHash({ ...plan, tier: 1 }), planHash({ ...plan, tier: 2 }));
  assert.match(renderTable([], { run_tier: 1 }), /Run tier 1 \(HARD ladder rung 1/);
  const gd = readFileSync(new URL("../../sketches/core-loop/src/core/run_tier.gd", import.meta.url), "utf8");
  assert.equal(Number(/^const TOP := (\d+)$/m.exec(gd)?.[1]), MAX_RUN_TIER, "lib.mjs MAX_RUN_TIER mirrors run_tier.gd TOP");
  assert.doesNotMatch(renderTable([], {}), /Run tier/);
});

test("every band run plays with the play watch on", () => {
  const args = botArgs({ policy: "skipper", seed: 7, args: ["--band=novice"] }, "/tmp/out");
  assert.ok(args.includes("--qa-log=1") && args.includes("--table=park"));
  assert.equal(args.at(-1), "--band=novice");
});

test("the player report gathers the watch's rows by kind and place, worst kind first", () => {
  const file = [
    { kind: "objective", stage: 1, s: 1, at: [0, 0, 0], flow: "stage", goal: "roll", id: "find_activity" },
    { kind: "stuck", stage: 1, s: 40.5, at: [101.2, 8, -44.9], flow: "beacon", goal: "camp", v: [0, 0, 0] },
    { kind: "wedged", stage: 1, s: 90, at: [12.4, 3.1, 407.7], flow: "stage", goal: "fight chaser", n: [1, 0.2, 0] },
  ].map((row) => JSON.stringify(row)).join("\n") + "\n{cut short";
  const rows = qaRows(file);
  assert.deepEqual(rows.map((row) => row.kind), ["stuck", "wedged"], "objective rows and a torn line are left out");
  assert.deepEqual(Object.keys(rows[0]), ["kind", "stage", "s", "at", "flow", "goal"]);
  const runs = [
    { id: "w1-novice-1", cell: "w1", qa: rows },
    { id: "w1-expert-1", cell: "w1", qa: [{ kind: "wedged", stage: 1, s: 12, at: [9.6, 2.9, 411.0], flow: "stage", goal: "roll to spillway sheet" }] },
    { id: "park1-novice-1", cell: "park1", qa: [] },
    { id: "w1-novice-2", cell: "w1" },
  ];
  const report = playerReport(runs);
  assert.equal(report.runs, 4);
  assert.equal(report.watched, 3, "a run recorded without the watch is not counted as clean");
  assert.deepEqual(report.kinds.wedged, { rows: 2, runs: 2 });
  assert.deepEqual(report.kinds.stuck, { rows: 1, runs: 1 });
  assert.deepEqual(report.kinds.fell, { rows: 0, runs: 0 });
  assert.deepEqual(report.places.map((place) => [place.kind, place.near.join(","), place.runs]), [["wedged", "10,0,410", 2], ["stuck", "100,10,-40", 1]], "two runs at one spot are one place");
  assert.deepEqual(report.places[0].goals, ["fight chaser", "roll to spillway sheet"]);
  const md = renderPlayerReport(report);
  assert.match(md, /read 3 of 4 runs/);
  assert.match(md, /\| wedged \| 2 \| 2 \|/);
  assert.match(md, /\| wedged \| 1 \| 10, 0, 410 \| 2 \| 2 \| w1 \|/);
  assert.ok(md.indexOf("| wedged | 1 | 10, 0, 410") < md.indexOf("| stuck | 1 | 100, 10, -40"));
  assert.match(renderPlayerReport(playerReport([{ id: "a", cell: "w1" }])), /No run carried the play watch's rows/);
  assert.match(renderPlayerReport(playerReport([{ id: "a", cell: "w1", qa: [] }])), /No place was reported/);
  assert.deepEqual(QA_KINDS.slice(0, 3), ["wedged", "fell", "blank"]);
});

// --- wave 36 unit measure: the whole-World-1 clear and the fairness numbers ---------------------------------------

test("w1clear is selected only by name, never by --only=w1 or the default cells", () => {
  const ids = (jobs) => [...new Set(jobs.map((j) => j.cell))];
  assert.deepEqual(ids(planCells({ builds: builds(), only: ["w1"], seeds: 2, columns: ["expert"] })), ["w1"]);
  assert.ok(!ids(planCells({ builds: builds(), seeds: 2, columns: ["expert"] })).includes("w1clear"), "not in the default cells");
  assert.deepEqual(planCells({ builds: builds(), cells: ["clear"], seeds: 2, columns: ["expert"] }), [], "--cells=clear alone selects nothing");
  const jobs = planCells({ builds: builds(), only: ["w1clear"], seeds: 2, columns: ["novice", "learner1", "learner5", "expert", "expertTop"] });
  assert.deepEqual(ids(jobs), ["w1clear"]);
  assert.deepEqual([...new Set(jobs.map((j) => j.column))], ["novice", "learner1", "learner5", "expert"], "a fresh run has no top build, so no top column");
  assert.equal(jobs.length, 8);
  assert.ok(jobs.every((j) => j.kind === "clear" && j.entrance === null && !j.missing));
  const args = jobs[0].args.join(" ");
  assert.match(args, /--until=2/);
  assert.ok(!args.includes("--to-boss"), "--to-boss would enter Brindle on the first tick");
  assert.match(args, /--ticks=\d+/);
  assert.ok(!args.includes("--from-stage"), "it starts at stage 1");
  // the same seeds as w1, so the two cells pair on stage 1; the Warden persona drives the whole run
  const w1seeds = planCells({ builds: builds(), only: ["w1"], seeds: 2, columns: ["expert"] }).map((j) => j.seed);
  assert.deepEqual(jobs.filter((j) => j.column === "expert").map((j) => j.seed), w1seeds);
  assert.ok(jobs.every((j) => j.policy === "skipper"));
  // the existing w1 plan is unchanged by the new cell's existence
  const w1 = planCells({ builds: builds(), only: ["w1"], seeds: 2, columns: ["expert"] });
  assert.equal(w1.length, 2);
  assert.ok(w1.every((j) => j.kind === "warden" && j.args.some((a) => a === "--until=1")));
});

test("a w1clear run is graded by where it ended: cleared, died or capped, with the stage and game seconds", () => {
  const won = gradeRun("clear", { outcome: "won", stage_reached: 2, game_seconds: 640.5, boss: { defeated_s: 70 } });
  assert.deepEqual(won, { result: "win", fightS: 640.5, hpLost: null, end: "clear", stage: 2, gameS: 640.5, where: "boss" });
  const dead = gradeRun("clear", { outcome: "died", stage_reached: 1, game_seconds: 212.04, boss: null });
  assert.deepEqual([dead.result, dead.end, dead.stage, dead.gameS, dead.where], ["loss", "death", 1, 212.04, "s1"]);
  // a stage 2 death and a boss death read apart
  assert.equal(gradeRun("clear", { outcome: "died", stage_reached: 2, game_seconds: 400, boss: null }).where, "s2");
  assert.equal(gradeRun("clear", { outcome: "died", stage_reached: 2, game_seconds: 500, boss: { defeated_s: null, died_s: 40 } }).where, "boss");
  const capped = gradeRun("clear", { outcome: "stalled", stage_reached: 2, game_seconds: 900, boss: null });
  assert.deepEqual([capped.result, capped.end, capped.reason, capped.stage], ["timeout", "cap", "stalled", 2]);
  assert.equal(gradeRun("clear", { outcome: "ticks_done", stage_reached: 2, game_seconds: 1800, boss: { defeated_s: null } }).end, "cap");
  assert.equal(gradeRun("clear", { outcome: "gave_up", stage_reached: 1 }).result, "error");
  assert.equal(gradeRun("clear", null).result, "error");
  // in the table: information only, in its own section, never a fail
  const runs = [won, dead, capped].map((grade, i) => ({ cell: "w1clear", kind: "clear", stage: 1, column: "expert", band: "expert", seed: i, grade }));
  const table = buildTable(runs);
  assert.equal(table[0].info, true);
  assert.equal(cellVerdict(table[0]), "info");
  assert.equal(table[0].columns.expert.target, null);
  assert.equal(table[0].ends.expert, "boss: 0 died / 0 capped / 1 cleared, s1: 1 died / 0 capped / 0 cleared, s2: 0 died / 1 capped / 0 cleared");
  const text = renderTable(table);
  assert.match(text, /## Whole World 1 clear/);
  assert.ok(!text.includes("## World chains"));
});

// A fixed fake trace: three runs of one cell and arm.
const seg = (hit, s, extra = {}) => ({ contact: true, hit, first_hit_s: s, opened_by_hit: false, ...extra });
const fake = (cell, column, f) => ({ cell, column, band: column, grade: { result: "win" }, row: { resumed: true, fairness: f } });
const hullOf = (telegraphed, untelegraphed, contact = 0, unknown = 0) => ({ telegraphed, untelegraphed, contact, unknown });
const trace = (cell = "w1", column = "expert") => [
  fake(cell, column, { hull: hullOf(40, 10), killing_hit: { source: "chaser", bucket: "telegraphed" }, slow_s: 30, fast_s: 60, slow_hull: 30, fast_hull: 20, first_hit: { s1: seg(true, 6) } }),
  fake(cell, column, { hull: hullOf(10, 40, 5), killing_hit: { source: "lobber", bucket: "untelegraphed" }, slow_s: 30, fast_s: 60, slow_hull: 40, fast_hull: 10, first_hit: { s1: seg(true, 2) } }),
  fake(cell, column, { hull: hullOf(0, 0), killing_hit: null, slow_s: 20, fast_s: 40, slow_hull: 0, fast_hull: 0, first_hit: { s1: seg(false, null) } }),
];

test("the three fairness numbers come out of a fixed trace by the plan's arithmetic", () => {
  const p = fairnessPool(trace());
  // F1: 50 telegraphed of 100 hull from sources that publish telegraphs = 0.5; contact hull is outside the share.
  assert.equal(p.telegraphShare, 0.5);
  assert.equal(p.hull.contact, 5);
  assert.deepEqual([p.kills, p.killsShown], [2, 1]);
  // F2: slow 70 hull over 80 s = 0.875 per s; fast 30 hull over 160 s = 0.1875 per s; the ratio is 4.666...
  assert.ok(Math.abs(p.stopTax - 0.875 / 0.1875) < 1e-9);
  assert.equal(p.fastShare, 160 / 240);
  // F3: readings 6 s, 2 s and one stage with no hit (later than any): the median is 6 s, and the no-hit stage is counted.
  assert.equal(p.firstHitS, 6);
  assert.deepEqual([p.firstHitN, p.noHit], [3, 1]);
});

test("each fairness number moves the wrong way on a planted unfair trace, so its pass is not by default", () => {
  const fair = fairnessPool([fake("w1", "expert", { hull: hullOf(50, 0), killing_hit: { source: "chaser", bucket: "telegraphed" }, slow_s: 30, fast_s: 60, slow_hull: 40, fast_hull: 5, first_hit: { s1: seg(true, 8) } })]);
  assert.ok(fair.telegraphShare >= FAIRNESS.telegraphShare, "F1 passes when every hit was shown");
  assert.ok(fair.stopTax >= FAIRNESS.stopTax, "F2 passes when the tax falls on the stopped ball");
  assert.ok(fair.firstHitS >= FAIRNESS.firstHitS, "F3 passes when the first hit comes late");
  // the plants: an untelegraphed drain, a tax on fast balls, a spawn with no ring
  const unfair = fairnessPool([fake("w1", "expert", { hull: hullOf(20, 30), killing_hit: { source: "drain_plant", bucket: "untelegraphed" }, slow_s: 30, fast_s: 60, slow_hull: 10, fast_hull: 40, first_hit: { s1: seg(true, 0.5) } })]);
  assert.ok(unfair.telegraphShare < FAIRNESS.telegraphShare);
  assert.ok(unfair.stopTax < FAIRNESS.stopTax);
  assert.ok(unfair.firstHitS < FAIRNESS.firstHitS);
  const text = renderFairness(fairnessByCell([fake("w1", "expert", { hull: hullOf(20, 30), killing_hit: { source: "drain_plant", bucket: "untelegraphed" }, slow_s: 30, fast_s: 60, slow_hull: 10, fast_hull: 40, first_hit: { s1: seg(true, 0.5) } })])).join("\n");
  assert.equal((text.match(/✗/g) ?? []).length, 4, "share, killing hit, stop tax and first hit each fail");
});

test("the pass lines live in fairness.json and nowhere else", () => {
  const json = JSON.parse(readFileSync(new URL("./fairness.json", import.meta.url), "utf8"));
  assert.deepEqual([FAIRNESS.tellS, FAIRNESS.telegraphShare, FAIRNESS.stopTax, FAIRNESS.firstHitS], [json.tellS, json.telegraphShare, json.stopTax, json.firstHitS]);
  for (const file of ["lib.mjs", "../../sketches/core-loop/tools/bot_driver.gd", "../../sketches/core-loop/tools/bot_fairness.gd", "../../sketches/core-loop/tests/bot_fairness_test.gd"]) {
    const text = readFileSync(new URL(file, import.meta.url), "utf8");
    assert.ok(!/telegraphShare:\s*0\.95|FAIR_SEEN_S|LINE_SHARE|LINE_TAX|LINE_FIRST_HIT_S|tellS:\s*0\.6/.test(text), file + " carries a copy of a line");
  }
});

test("a fairness field missing from a record reads as not measured, never as 0", () => {
  assert.equal(fairnessOf({ row: {} }), null);
  assert.equal(fairnessOf({ row: null }), null);
  assert.equal(fairnessOf({}), null);
  const part = fairnessOf({ row: { fairness: { hull: { telegraphed: 10, untelegraphed: 0 } } } });
  assert.deepEqual([part.slowS, part.fastS, part.segments, part.killing], [null, null, null, null]);
  const p = fairnessPool([{ row: { outcome: "won" } }, fake("w1", "novice", { hull: hullOf(10, 0) })]);
  assert.equal(p.telegraphShare, 1);
  assert.equal(p.stopTax, null);
  assert.equal(p.stopTaxNote, "not measured");
  assert.equal(p.firstHitS, null, "an unmeasured first hit is null, not 0 s");
  assert.deepEqual([p.runs, p.measured], [2, 1]);
  // no hull lost has no share; no hull at cruise has no tax; neither is a pass
  const none = fairnessPool([fake("w1", "novice", { hull: hullOf(0, 0), slow_s: 10, fast_s: 10, slow_hull: 0, fast_hull: 0, first_hit: {} })]);
  assert.equal(none.telegraphShare, null);
  assert.equal(none.stopTax, null);
  assert.equal(none.stopTaxNote, "no hull lost at cruise");
  assert.equal(fairnessByCell([{ cell: "w1", column: "novice", row: { outcome: "won" } }]), null);
  const text = renderFairness(fairnessByCell([{ cell: "w1", column: "novice", row: { outcome: "won" } }, fake("w1", "novice", { hull: hullOf(10, 0) })])).join("\n");
  assert.match(text, /F2 not measured/);
  assert.match(text, /F3 not measured/);
});

test("fairness lines are per cell and per arm, and leave out error and unresumed runs", () => {
  const runs = [...trace("w1", "learner1"), ...trace("w1", "learner5"), ...trace("brindle", "learner1")];
  const lines = fairnessByCell(runs);
  assert.deepEqual(lines.map((l) => `${l.cell}/${l.column}/${l.measured}`), ["w1/learner1/3", "w1/learner5/3", "brindle/learner1/3"]);
  // an error and an unresumed run are not counted behind the line
  const bad = [fake("w1", "expert", { hull: hullOf(1, 0) }), { ...fake("w1", "expert", { hull: hullOf(0, 9) }), grade: { result: "error" } }, { ...fake("w1", "expert", { hull: hullOf(0, 9) }), row: { resumed: false, fairness: { hull: hullOf(0, 9) } } }];
  const [only] = fairnessByCell(bad);
  assert.deepEqual([only.runs, only.telegraphShare], [1, 1]);
  assert.match(renderFairness(lines).join("\n"), /w1 learner1 \(3 of 3 runs measured\)/);
});

test("F1 carries no mark while unknown hull is over the line, and prints contact beside it", () => {
  const unknownHeavy = fairnessPool([fake("w1", "expert", { hull: hullOf(50, 0, 0, 10), killing_hit: null, first_hit: {} })]);
  assert.equal(unknownHeavy.shareMarked, false);
  const text = renderFairness([{ cell: "w1", column: "expert", ...unknownHeavy }]).join("\n");
  assert.match(text, /no mark: unknown hull over the line/);
  assert.match(text, /unknown 10\.0 hull/);
  const clean = fairnessPool([fake("w1", "expert", { hull: hullOf(50, 0, 7, 1), first_hit: {} })]);
  assert.equal(clean.shareMarked, true);
  assert.equal(clean.hull.contact, 7);
  assert.equal(clean.telegraphShare, 1, "contact is outside the share");
});

test("an unlisted source's hull lost F1's mark only once it reads unknown (round 3), not contact (round 2)", () => {
  // One run: 57 hull telegraphed and 4 from a source on no list. Round 2's classifier filed the 4 as contact; round 3 files
  // them as unknown. 4 of 61 is 6.6%, over unknownMaxShare.
  const round2 = fairnessPool([fake("w1", "expert", { hull: hullOf(57, 0, 4, 0), first_hit: {} })]);
  const round3 = fairnessPool([fake("w1", "expert", { hull: hullOf(57, 0, 0, 4), first_hit: {} })]);
  assert.ok(4 / 61 > FAIRNESS.unknownMaxShare);
  assert.equal(round2.shareMarked, true, "planted: as contact the hidden hull keeps the pass mark");
  assert.equal(round3.shareMarked, false);
  const line = renderFairness([{ cell: "w1", column: "expert", ...round3 }]).join("\n");
  assert.match(line, /F1 100% of 57\.0 hull shown \(no mark: unknown hull over the line\)/);
  assert.ok(!/✓/.test(line.split("\n").find((l) => l.startsWith("- w1")).split(";")[0]), "no pass mark on F1");
  // at the line exactly the mark stays
  const atLine = fairnessPool([fake("w1", "expert", { hull: hullOf(95, 0, 0, 5), first_hit: {} })]);
  assert.equal(atLine.shareMarked, true);
});

test("F3 says 'no hit in half' at an even split and 'no hit in over half' past it", () => {
  const even = fairnessPool([fake("w1", "expert", { hull: hullOf(1, 0), first_hit: { s1: seg(true, 4), s2: seg(false, null) } })]);
  assert.deepEqual([even.firstHitN, even.noHit, even.firstHitS], [2, 1, Infinity]);
  const evenText = renderFairness([{ cell: "w1", column: "expert", ...even }]).join("\n");
  assert.match(evenText, /F3 first hit no hit in half median over 2 stage readings/);
  assert.ok(!/over half/.test(evenText));
  const over = fairnessPool([fake("w1", "expert", { hull: hullOf(1, 0), first_hit: { s1: seg(true, 4), s2: seg(false, null), boss: seg(false, null) } })]);
  assert.match(renderFairness([{ cell: "w1", column: "expert", ...over }]).join("\n"), /F3 first hit no hit in over half median over 3 stage readings/);
});

test("F3: a hit that opened contact is its own case, and no-hit stages are counted and can move the line", () => {
  const p = fairnessPool([fake("w1", "expert", { hull: hullOf(1, 0), first_hit: { s1: seg(true, null, { opened_by_hit: true }), s2: seg(true, 1), boss: seg(false, null) } })]);
  assert.equal(p.openedByHit, 1);
  assert.equal(p.firstHitN, 2, "the opened-by-hit stage has no pack-to-hit time");
  assert.equal(p.noHit, 1);
  assert.equal(p.firstHitS, Infinity === p.firstHitS ? Infinity : (1 + Infinity) / 2);
  const text = renderFairness([{ cell: "w1", column: "expert", ...p }]).join("\n");
  assert.match(text, /1 of 2 took no hit, 1 opened by a hit/);
  // three stages, two no-hit: the median is a no-hit stage, the best case, and the line holds; one early hit alone fails it
  const quiet = fairnessPool([fake("w1", "expert", { hull: hullOf(1, 0), first_hit: { s1: seg(false, null), s2: seg(false, null), boss: seg(true, 0.4) } })]);
  assert.ok(quiet.firstHitS >= FAIRNESS.firstHitS);
  const loud = fairnessPool([fake("w1", "expert", { hull: hullOf(1, 0), first_hit: { s1: seg(true, 0.4), s2: seg(true, 0.2), boss: seg(false, null) } })]);
  assert.ok(loud.firstHitS < FAIRNESS.firstHitS);
});

test("the table gains one fairness line per cell and arm", () => {
  const runs = [...trace("w1", "expert"), ...trace("w1", "novice")].map((r, i) => ({ ...r, kind: "warden", stage: 1, seed: i, grade: { result: "win", fightS: 1 } }));
  const text = renderTable(buildTable(runs), { fairness: fairnessByCell(runs) });
  assert.match(text, /## Fairness/);
  assert.equal((text.match(/^- w1 (novice|expert) /gm) ?? []).length, 2);
  // the two summary sentences are scoped so a fairness ✗ never sits beside "No cell has a ✗"
  assert.match(text, /(No cell has a ✗|Cells with a ✗) against a win-rate target/);
  assert.match(text, /Fairness lines with a ✗: w1 (novice|expert) F[123]/);
});

test("the job cap follows cores and memory, never below 6", () => {
  const gib = 2 ** 30;
  assert.equal(maxJobs(4, 15 * gib), 6); // the cloud box keeps the old cap
  assert.equal(maxJobs(32, 64 * gib), 32); // one a core when memory allows
  assert.equal(maxJobs(32, 40 * gib), 20); // memory binds at 2 GiB a job
  assert.equal(maxJobs(2, 4 * gib), 6);
});

test("early stop settles a column only when the seeds left cannot change its mark (ruling dg)", () => {
  const g = (wins, losses, errors = 0) => [...Array(wins).fill({ result: "win" }), ...Array(losses).fill({ result: "loss" }), ...Array(errors).fill({ result: "error" })];
  const expert = { min: 0.85 };
  assert.equal(settledMark({ grades: g(1, 5), left: 18, target: expert }), false); // 19 of 24 at best: 79%
  assert.equal(settledMark({ grades: g(20, 0), left: 4, target: expert }), null); // 20 of 24 at worst: 83%
  assert.equal(settledMark({ grades: g(21, 0), left: 3, target: expert }), true); // 21 of 24 at worst: 87.5%
  assert.equal(settledMark({ grades: g(4, 6), left: 14, target: { max: 0.15 } }), false); // 4 of 24 at best: 17%
  assert.equal(settledMark({ grades: g(0, 10), left: 14, target: { max: 0.15 } }), null); // 14 of 24 still possible
  assert.equal(settledMark({ grades: g(5, 0), left: 19, target: null }), null); // no target: every seed runs
  assert.equal(settledMark({ grades: g(1, 5), left: 18, target: expert, tellOpen: true }), null); // the 45 s tell is still clean
  assert.equal(settledMark({ grades: g(1, 5, 1), left: 17, target: expert }), null); // over the excluded share
  assert.equal(settledMark({ grades: g(3, 0), left: 0, target: expert }), null); // nothing left to skip
  assert.equal(columnTarget("w1", "warden", "expert")?.min, 0.85);
  assert.equal(columnTarget("w1clear", "clear", "expert"), null);
});
