import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import {
  ARMS,
  MIN_VALID,
  RULES,
  SEEDS,
  STAGES,
  driverAudioReads,
  evaluateGates,
  gate1,
  gate2,
  gate4,
  gateBotArgs,
  groupByArm,
  instrumentVoid,
  planGateJobs,
  stripComments,
  summarizeRun,
  withControls,
} from "./gates-lib.mjs";

const run = (arm, stage, seed, rep, o = {}) => ({
  id: `${arm}-s${stage}-seed${seed}-r${rep}`,
  arm,
  stage,
  seed,
  rep,
  void: null,
  ...o,
});
const arm = (name, make) =>
  STAGES.flatMap((st) =>
    SEEDS.flatMap((sd) => [0, 1, 2].map((r) => run(name, st, sd, r, make(st, sd, r)))),
  );
const diedAt = (s) => ({ outcome: "died", died: true, cleared: false, death_after_hit_s: s });
const stalled = { outcome: "stalled", died: false, cleared: false, death_after_hit_s: null };
const hull = (v) => ({ hull_per_min: v });

test("the rule numbers are the comment's, and the plan is 8 arms of 90 runs", () => {
  assert.equal(RULES.gate1.deathWithinS, 120);
  assert.deepEqual(RULES.gate2, {
    windowS: 120,
    lowerShare: 0.8,
    ratioMax: 0.75,
    minContested: 10,
  });
  assert.equal(RULES.gate4.clearMin, 0.85);
  assert.deepEqual(RULES.instrument, { circleShareMin: 0.8, ridePerS: 30 });
  const jobs = planGateJobs();
  assert.equal(jobs.length, 8 * 6 * 5 * 3);
  assert.equal(new Set(jobs.map((j) => j.id)).size, jobs.length);
});

test("three runs of a seed are the same seed, told apart by repeat; the A/A arm runs the same seeds", () => {
  const a = planGateJobs({ arms: ["orbit"], stages: [2], seeds: [3] });
  const b = planGateJobs({ arms: ["orbit_b"], stages: [2], seeds: [3] });
  assert.deepEqual(
    a.map((j) => j.runSeed),
    [3, 3, 3],
  );
  assert.deepEqual(
    b.map((j) => j.runSeed),
    [3, 3, 3],
  );
  assert.equal(new Set(a.map((j) => j.id)).size, 3);
  assert.deepEqual(
    a.map((j) => j.rep),
    [0, 1, 2],
  );
  assert.ok(gateBotArgs(a[0], "/o").includes("--seeds=3"));
});

test("every run is fresh at --fixed-fps 90 and carries its plant", () => {
  const jobs = planGateJobs({ stages: [1, 4], seeds: [1], runs: 1 });
  const j1 = jobs.find((j) => j.arm === "orbit" && j.stage === 1);
  const j4 = jobs.find((j) => j.arm === "orbit_rut" && j.stage === 4);
  assert.ok(!j1.args.some((a) => a.startsWith("--from-stage")));
  assert.ok(
    j4.args.includes("--from-stage=4") &&
      j4.args.includes("--until=4") &&
      j4.args.includes("--plant=rut=1"),
  );
  const argv = gateBotArgs(j4, "/o");
  assert.deepEqual(argv.slice(0, 3), ["--headless", "--fixed-fps", "90"]);
  assert.ok(argv.includes("--policy=orbit") && argv.includes("--table=park"));
  assert.ok(jobs.find((j) => j.arm === "deaf").args.includes("--bot-no-mix=1"));
  assert.ok(
    jobs.find((j) => j.arm === "deaf_hidden").args.includes("--plant=hide_pack_telegraphs=1"),
  );
  assert.ok(jobs.find((j) => j.arm === "orbit_passive").args.includes("--plant=packs_passive=1"));
  assert.ok(jobs.find((j) => j.arm === "orbit_dmg2").args.includes("--plant=damage=2"));
});

test("summarizeRun reads the stage note and applies the instrument check", () => {
  const job = { id: "x", arm: "orbit", stage: 2, seed: 1, rep: 0 };
  const note = {
    stage: 2,
    first_contact_s: 10,
    first_hit_s: 12,
    exit_s: 52,
    hull_lost_120s: 30,
    alive_120s: 40,
    fight_s: 30,
    circle_s: 27,
    circle_share: 0.9,
    line_rides: 0,
    evasions: 3,
    telegraph_reads: 5,
  };
  const s = summarizeRun({ outcome: "died", stages: [{ stage: 1 }, note] }, job);
  assert.equal(s.void, null);
  assert.equal(s.death_after_hit_s, 40);
  assert.equal(s.hull_per_min, 45);
  assert.equal(s.dodges, 3);
  assert.match(summarizeRun(null, job).void, /no record/);
  assert.match(summarizeRun({ outcome: "died", stages: [] }, job).void, /no stage note/);
  assert.equal(summarizeRun({ outcome: "lost", stages: [{ stage: 1 }, note] }, job).died, true);
  assert.equal(summarizeRun({ outcome: "won", stages: [{ stage: 1 }, note] }, job).cleared, true);
  assert.equal(summarizeRun({ outcome: "stalled", stages: [{ stage: 1 }, note] }, job).died, false);
  assert.match(
    summarizeRun({ outcome: "died", stages: [{ ...note, circle_share: 0.5 }] }, job).void,
    /circle_share/,
  );
});

test("instrument checks: orbit circle_share 0.8 of the window, terrain one ride per 30 s of window, no line in reach is void", () => {
  assert.equal(instrumentVoid({ alive_120s: 100, circle_s: 80, circle_share: 0.8 }, "orbit"), null);
  assert.match(
    instrumentVoid({ alive_120s: 100, circle_s: 79, circle_share: 0.79 }, "orbit"),
    /circle_share/,
  );
  assert.match(
    instrumentVoid({ alive_120s: 0, circle_s: 0, circle_share: null }, "orbit"),
    /no contact window/,
  );
  assert.equal(
    instrumentVoid({ alive_120s: 60, line_rides: 2, lines_in_reach: 1 }, "terrain"),
    null,
  );
  assert.equal(
    instrumentVoid({ alive_120s: 54.86, line_rides: 3, lines_in_reach: 1 }, "terrain"),
    null,
  );
  assert.match(
    instrumentVoid({ alive_120s: 61, line_rides: 2, lines_in_reach: 1 }, "terrain"),
    /need 2\.0/,
  );
  assert.match(
    instrumentVoid({ alive_120s: 10, line_rides: 0, lines_in_reach: 1 }, "terrain"),
    /need 1\.0/,
  );
  assert.match(
    instrumentVoid({ alive_120s: 60, line_rides: 0, lines_in_reach: 0 }, "terrain"),
    /no line within reach/,
  );
  assert.equal(instrumentVoid({ alive_120s: 0 }, "deaf"), null);
});

test("gate 1 passes when every run dies within 120 s of its first hit on every stage", () => {
  const r = gate1(arm("orbit", () => diedAt(60)));
  assert.equal(r.verdict, "PASS");
  assert.ok(r.stages.every((s) => s.status === "pass" && s.medianDeathAfterHitS === 60));
});

test("gate 1 fails on a single stall to the cap, even among deaths", () => {
  const runs = arm("orbit", (st, sd, r) =>
    st === 3 && sd === 2 && r === 1 ? stalled : diedAt(30),
  );
  const r = gate1(runs);
  assert.equal(r.verdict, "FAIL");
  assert.equal(r.stages.find((s) => s.stage === 3).status, "fail");
  assert.deepEqual(r.stages.find((s) => s.stage === 3).notDiedOutcomes, ["stalled"]);
});

test("gate 1: the median is 120 s at most (120 passes, 121 fails), taken over seeds' medians", () => {
  assert.equal(gate1(arm("orbit", () => diedAt(120))).verdict, "PASS");
  assert.equal(gate1(arm("orbit", () => diedAt(120.5))).verdict, "FAIL");
  assert.equal(gate1(arm("orbit", (st, sd) => diedAt(sd === 5 ? 200 : 50))).verdict, "PASS");
  assert.equal(gate1(arm("orbit", (st, sd, r) => diedAt(r === 0 ? 300 : 40))).verdict, "PASS");
});

test("gate 1 control expectations: planted x4 packs reads PASS, passive packs reads FAIL", () => {
  const positive = gate1(arm("orbit_rut", () => diedAt(25)));
  const negative = gate1(arm("orbit_passive", () => stalled));
  assert.equal(positive.verdict, "PASS");
  assert.equal(negative.verdict, "FAIL");
  const c = withControls(gate1(arm("orbit", () => diedAt(90))), positive, negative);
  assert.equal(c.broken, false);
  assert.equal(c.reading, "PASS");
});

test("gate 1 reads VOID, not PASS, when voided runs leave a seed short, and FAIL still wins over VOID", () => {
  const voidSeed = arm("orbit", (st, sd, r) =>
    st === 2 && sd === 1 && r < 2
      ? { ...diedAt(30), void: "orbit: circle_share 0.1 < 0.8" }
      : diedAt(30),
  );
  assert.equal(gate1(voidSeed).verdict, "VOID");
  const oneVoid = arm("orbit", (st, sd, r) =>
    st === 2 && sd === 1 && r === 0 ? { ...diedAt(30), void: "x" } : diedAt(30),
  );
  assert.equal(gate1(oneVoid).verdict, "PASS");
  assert.equal(MIN_VALID, 2);
  const mixed = arm("orbit", (st, sd, r) =>
    st === 2 && sd === 1 && r < 2
      ? { ...diedAt(30), void: "x" }
      : st === 4 && sd === 1 && r === 0
        ? stalled
        : diedAt(30),
  );
  assert.equal(gate1(mixed).verdict, "FAIL");
});

const pairs2 = (a, b) => [
  arm("T", (st, sd) => hull(a(st, sd))),
  arm("O", (st, sd) => hull(b(st, sd))),
];
const idx = (st, sd) => (st - 1) * 5 + (sd - 1);

test("gate 2 passes at exactly 24 of 30 lower and a pooled median ratio of 0.75", () => {
  const [t, o] = pairs2(
    (st, sd) => (idx(st, sd) < 24 ? 75 : 130),
    () => 100,
  );
  const r = gate2(t, o);
  assert.equal(r.pairs, 30);
  assert.equal(r.A.lower, 24);
  assert.equal(r.A.need, 24);
  assert.equal(r.A.pooledMedianRatio, 0.75);
  assert.equal(r.verdict, "PASS");
  assert.equal(r.winner, "A");
});

test("gate 2 fails at 23 of 30 lower, and fails on a ratio of 0.76 with every pair lower", () => {
  const [t, o] = pairs2(
    (st, sd) => (idx(st, sd) < 23 ? 50 : 130),
    () => 100,
  );
  assert.equal(gate2(t, o).A.lower, 23);
  assert.equal(gate2(t, o).verdict, "FAIL");
  const [t2, o2] = pairs2(
    () => 76,
    () => 100,
  );
  const r = gate2(t2, o2);
  assert.equal(r.A.lower, 30);
  assert.equal(r.verdict, "FAIL");
});

test("gate 2 pairs by stage and seed, and each arm's value is the median of its three runs", () => {
  const t = arm("T", (st, sd, r) => hull(r === 0 ? 1000 : 10));
  const o = arm("O", (st, sd, r) => hull(r === 2 ? 1 : 100));
  const r = gate2(t, o);
  assert.equal(r.A.pooledMedianRatio, 0.1);
  assert.equal(r.verdict, "PASS");
});

test("gate 2 ties and zero-loss pairs never read as a win", () => {
  const zero = gate2(
    ...pairs2(
      () => 0,
      () => 0,
    ),
  );
  assert.equal(zero.A.lower, 0);
  assert.equal(zero.contested, 0);
  assert.equal(zero.verdict, "FAIL");
  const noLoss = gate2(
    ...pairs2(
      () => 5,
      () => 0,
    ),
  );
  assert.equal(noLoss.verdict, "FAIL");
  assert.equal(noLoss.winner, "B");
});

test("gate 2 leaves tied pairs out, and needs 10 contested pairs to name a winner", () => {
  const [t, o] = pairs2(
    (st, sd) => (idx(st, sd) < 16 ? 0 : 20),
    (st, sd) => (idx(st, sd) < 16 ? 0 : 50),
  );
  const r = gate2(t, o);
  assert.equal(r.ties, 16);
  assert.equal(r.contested, 14);
  assert.equal(r.A.need, 12);
  assert.equal(r.A.pooledMedianRatio, 0.4);
  assert.equal(r.verdict, "PASS");
  const [t2, o2] = pairs2(
    (st, sd) => (idx(st, sd) < 21 ? 0 : 20),
    (st, sd) => (idx(st, sd) < 21 ? 0 : 50),
  );
  assert.equal(gate2(t2, o2).verdict, "FAIL");
  assert.equal(gate2(t2, o2).winner, "none");
});

test("gate 2 control expectations: damage x2 on arm B names A the winner; A/A names nobody", () => {
  const a = arm("orbit", (st, sd) => hull(40 + sd));
  const b = arm("orbit_dmg2", (st, sd) => hull(2 * (40 + sd)));
  const pos = gate2(a, b);
  assert.equal(pos.winner, "A");
  assert.equal(pos.verdict, "PASS");
  const same = arm("orbit_b", (st, sd) => hull(40 + sd + (idx(st, sd) % 2 ? 3 : -3)));
  const neg = gate2(a, same);
  assert.equal(neg.verdict, "FAIL");
  assert.equal(neg.winner, "none");
  assert.equal(gate2(a, a).verdict, "FAIL");
  const c = withControls(
    gate2(
      arm("T", () => hull(30)),
      arm("O", () => hull(100)),
    ),
    pos,
    neg,
  );
  assert.equal(c.broken, false);
});

test("gate 2 with voided pairs is VOID unless A has already won", () => {
  const t = arm("T", (st, sd, r) => ({
    ...hull(10),
    void: st === 1 && sd === 1 && r < 2 ? "x" : null,
  }));
  const o = arm("O", () => hull(100));
  const r = gate2(t, o);
  assert.equal(r.voidPairs, 1);
  assert.equal(r.verdict, "PASS");
  const flat = gate2(
    arm("T", (st, sd, r) => ({ ...hull(100), void: st === 1 && sd === 1 && r < 2 ? "x" : null })),
    o,
  );
  assert.equal(flat.verdict, "FAIL");
  const short = gate2(
    arm("T", (st, sd, r) => ({
      ...hull(idx(st, sd) < 15 ? 10 : 130),
      void: idx(st, sd) >= 20 && r < 2 ? "x" : null,
    })),
    o,
  );
  assert.equal(short.voidPairs, 10);
  assert.equal(short.A.lower, 15);
  assert.equal(short.verdict, "VOID");
});

const clear = (n) => (st, sd, r) =>
  r < 3 && idx(1, sd) * 3 + r < n
    ? { outcome: "until", cleared: true }
    : { outcome: "died", cleared: false };
test("gate 4 needs 85% on every stage: 13 of 15 passes, 12 of 15 fails", () => {
  const stage = (st, clears) =>
    arm("deaf", (s, sd, r) =>
      s === st ? { cleared: (sd - 1) * 3 + r < clears } : { cleared: true },
    );
  assert.equal(gate4(arm("deaf", () => ({ cleared: true }))).verdict, "PASS");
  assert.equal(gate4(stage(5, 13)).verdict, "PASS");
  const r = gate4(stage(5, 12));
  assert.equal(r.verdict, "FAIL");
  assert.equal(r.stages.find((x) => x.stage === 5).rate, 0.8);
  assert.equal(r.stages.filter((x) => x.status === "fail").length, 1);
  assert.ok(clear(0));
});

test("gate 4 control expectations: today's stage reads PASS, hidden pack telegraphs read FAIL", () => {
  const pos = gate4(arm("deaf", () => ({ cleared: true })));
  const neg = gate4(arm("deaf_hidden", (st, sd, r) => ({ cleared: (sd + r) % 3 === 0 })));
  assert.equal(pos.verdict, "PASS");
  assert.equal(neg.verdict, "FAIL");
  assert.equal(withControls(pos, pos, neg).broken, false);
});

test("gate 4 is incomplete (VOID) over 10% void runs, and VOID when the driver reads audio", () => {
  const holes = arm("deaf", (st, sd, r) =>
    st === 2 && sd <= 2 ? { cleared: true, void: "no record" } : { cleared: true },
  );
  assert.equal(gate4(holes).verdict, "VOID");
  const ok = arm("deaf", () => ({ cleared: true }));
  assert.equal(gate4(ok, { auditFree: false }).verdict, "VOID");
});

test("gate 4's on-beat follow-on is pending until gate 3 supplies a rate, then needs 10 points", () => {
  const ok = arm("deaf", () => ({ cleared: true }));
  assert.match(gate4(ok).onBeat, /pending/);
  const beat = Object.fromEntries(STAGES.map((s) => [s, 0.95]));
  assert.equal(gate4(ok, { onBeatRates: beat }).verdict, "PASS");
  assert.equal(gate4(ok, { onBeatRates: { ...beat, 3: 0.7 } }).verdict, "FAIL");
});

test("a control reading wrong withholds the reading", () => {
  const good = gate1(arm("orbit", () => diedAt(10)));
  const bad = gate1(arm("orbit_passive", () => diedAt(10)));
  const c = withControls(good, good, bad);
  assert.equal(c.broken, true);
  assert.match(c.reading, /BROKEN/);
  assert.equal(c.controls.negative.ok, false);
  assert.equal(withControls(good, bad, good).controls.positive.ok, true);
});

test("evaluateGates runs all three gates with their controls from per-arm runs", () => {
  const runs = [
    ...arm("orbit", () => diedAt(70)),
    ...arm("orbit_rut", () => diedAt(20)),
    ...arm("orbit_passive", () => stalled),
    ...arm("terrain", () => hull(30)),
    ...arm("orbit", () => hull(100)).map((r) => ({ ...r, id: r.id + "~", ...hull(100) })),
  ];
  const orbit = arm("orbit", () => ({ ...diedAt(70), ...hull(100) }));
  const byArm = groupByArm([
    ...orbit,
    ...arm("orbit_rut", () => diedAt(20)),
    ...arm("orbit_passive", () => stalled),
    ...arm("terrain", () => hull(30)),
    ...arm("orbit_dmg2", () => hull(200)),
    ...arm("orbit_b", (st, sd) => hull(100 + (idx(st, sd) % 2 ? 4 : -4))),
    ...arm("deaf", () => ({ cleared: true })),
    ...arm("deaf_hidden", () => ({ cleared: false })),
  ]);
  assert.ok(runs.length > 0);
  const ev = evaluateGates(byArm);
  assert.equal(ev.gate1.real.verdict, "PASS");
  assert.deepEqual(
    [ev.gate1.controls.positive.got, ev.gate1.controls.negative.got],
    ["PASS", "FAIL"],
  );
  assert.equal(ev.gate2.real.verdict, "PASS");
  assert.deepEqual(
    [ev.gate2.controls.positive.got, ev.gate2.controls.negative.got],
    ["PASS", "FAIL"],
  );
  assert.equal(ev.gate4.real.verdict, "PASS");
  assert.deepEqual(
    [ev.gate4.controls.positive.got, ev.gate4.controls.negative.got],
    ["PASS", "FAIL"],
  );
  assert.ok(Object.values(ev).every((g) => !g.broken));
});

test("every arm in the table is planned, and each gate's arms exist", () => {
  for (const g of Object.values(ARMS)) assert.ok(g.policy && g.gates.length);
  const names = [
    "orbit",
    "orbit_rut",
    "orbit_passive",
    "terrain",
    "orbit_dmg2",
    "orbit_b",
    "deaf",
    "deaf_hidden",
  ];
  assert.deepEqual(Object.keys(ARMS), names);
});

test("the audio-read scan flags a read and ignores comments", () => {
  assert.equal(
    driverAudioReads("var x = 1  # the beat is not read\n# audio engine\nvar s = 'a # b'").length,
    0,
  );
  assert.equal(
    driverAudioReads("var o = game.presentation.audio.beat_offset_s()").length >= 1,
    true,
  );
  assert.equal(driverAudioReads("var c = _game.presentation.audio.engine.clock").length >= 1, true);
  assert.equal(stripComments('var a = "#x"  # note'), 'var a = "#x"  ');
});

test("tools/bot_driver.gd makes no audio or beat reads", () => {
  const gd = readFileSync(
    new URL("../../sketches/core-loop/tools/bot_driver.gd", import.meta.url),
    "utf8",
  );
  assert.deepEqual(driverAudioReads(gd), []);
  const kite = readFileSync(
    new URL("../../sketches/core-loop/tools/bot_kite.gd", import.meta.url),
    "utf8",
  );
  assert.deepEqual(driverAudioReads(kite), []);
});

test("gate 4 sizes a stage by the runs a seed was given, and is parked", () => {
  const runs = [];
  for (const seed of SEEDS)
    for (let rep = 0; rep < 2; rep++) runs.push({ stage: 1, seed, rep, cleared: true });
  const ev = evaluateGates({ deaf: runs, deaf_hidden: runs }, { stages: [1], runs: 2 });
  assert.equal(ev.gate4.real.stages[0].status, "pass");
  assert.equal(ev.gate4.parked, true);
  assert.equal(ev.gate1.parked, undefined);
});
