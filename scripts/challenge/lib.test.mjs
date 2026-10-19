import assert from "node:assert/strict";
import test from "node:test";
import { BOSSES, COLUMNS, TARGETS, aggregate, buildTable, cellVerdict, describeDoc, estimate, gradeRun, mergeLibraryIndexes, wallStats, checkMerge, planHash, jobKey, dedupeBy, bucketInfo, fightStart, median, meets, pickBuilds, planCells, renderTable, shardJobs, wilson } from "./lib.mjs";

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
  assert.deepEqual(gradeRun("boss", boss("until", { defeated_s: 61.2, seconds: 61.2, hp_lost: 40 })), { result: "win", fightS: 61.2, hpLost: 40, largestShare: null, largestSource: null, hp45Share: null });
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
  assert.deepEqual(won, { result: "win", fightS: 32.5, hpLost: 12, largestShare: null, largestSource: null, hp45Share: null });
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
  assert.match(md, /\| brindle \| 64\.0 \| 34% \(slag\) \| 22% \/ 22% \|/);
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
  assert.equal(b.columns.learner1.ok, true);
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
  assert.match(md, /35% \(20\) \[\d+%-\d+%\] ✓ vs 15%-35%/);
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
  assert.deepEqual(gradeRun("warden", row("fight_capped"), { stage: 1 }), { result: "timeout", reason: "fight_capped", fightS: null, hpLost: 5, largestShare: null, largestSource: null, hp45Share: null });
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
