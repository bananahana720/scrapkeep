import assert from "node:assert/strict";
import test from "node:test";
import { PERSONAS, PILOTS, carryList, grade, hitches, logErrors, pileUps, planWave, readBotJob, renderMarkdown } from "./lib.mjs";

const job = (over = {}) => ({ id: "speedrunner-tarn-2500", kind: "bot", persona: "speedrunner", policy: "skipper", pilot: "tarn", seed: 2500, stages: null, args: [], ...over });
const result = (over = {}) => ({ job: job(), exit: 0, timedOut: false, row: { outcome: "won", stage_reached: 7, game_seconds: 600, stages: [], beats: [] }, errors: [], piles: [], perf: { spikes: [], loads: 0, p99: 4 }, ...over });

test("a wave's runs cover every persona and new cells each wave", () => {
  const w15 = planWave({ wave: 15 });
  assert.equal(w15.length, 10);
  for (const p of PERSONAS) assert.equal(w15.filter((j) => j.persona === p.id).length, 2);
  const cells = new Set();
  for (const w of [15, 16, 17]) for (const j of planWave({ wave: w })) cells.add(j.persona + j.pilot);
  assert.equal(cells.size, PERSONAS.length * PILOTS.length);
  const seeds = new Set([...planWave({ wave: 15 }), ...planWave({ wave: 16 })].map((j) => j.seed));
  assert.equal(seeds.size, 20);
  assert.throws(() => planWave({ wave: 1.5 }));
});

test("quick runs stop after stage 1 and carried runs replay their seed", () => {
  const jobs = planWave({ wave: 3, count: 2, quick: true, carry: [{ persona: "greedy", pilot: "tally", seed: 1311, title: "x" }, { persona: "nobody", pilot: "tally", seed: 1 }] });
  assert.equal(jobs.length, 3);
  assert.ok(jobs.every((j) => j.args.includes("--stages=1")));
  assert.equal(jobs[2].seed, 1311);
  const rider = planWave({ wave: 0, count: 5 }).find((j) => j.persona === "line-rider");
  assert.deepEqual(rider.args, ["--from-stage=" + (1 + (rider.seed % 6)), "--ticks=8100"]);
  assert.ok(jobs[2].args.includes("--late-offer=take"));
});

test("crashes, timeouts and skipper stalls are blockers; camper stalls without a break are expected", () => {
  const f = grade([
    result({ exit: 139, row: null }),
    result({ timedOut: true, row: null }),
    result({ row: { outcome: "stalled", stage_reached: 2, stages: [{ stage: 2, stall_state: "beacon" }], beats: [] } }),
    result({ job: job({ policy: "camper", persona: "cautious" }), row: { outcome: "stalled", stage_reached: 1, stages: [{ stage: 1, warden_broken_s: null }], beats: [] } }),
    result({ job: job({ policy: "random", persona: "first-timer", pilot: "tally" }), row: { outcome: "stalled", stage_reached: 3, stages: [{ stage: 3 }], beats: [] } }),
  ]);
  const keys = f.map((x) => `${x.severity} ${x.key}`);
  assert.deepEqual(keys.filter((k) => k.startsWith("blocker")).sort(), ["blocker crash", "blocker freeze", "blocker stall:stage 2:tarn"]);
  assert.ok(keys.includes("major stall:stage 3:tally"));
  assert.ok(f.every((x) => !x.key.includes("stage 1")));
});

test("pile-ups need three hits from two sources worth a third of max HP", () => {
  const hit = (tick, amount, source) => ({ tick, event: "player_hit", args: [amount, source] });
  const events = [{ tick: 0, event: "stage_entered", args: [1, false] }, hit(100, 15, "chaser"), hit(120, 15, "lobber"), hit(150, 10, "chaser"), { tick: 300, event: "player_died", args: [] }, hit(1000, 10, "chaser"), hit(1010, 10, "chaser"), hit(1020, 10, "chaser")];
  const piles = pileUps(events, { 1: 100 });
  assert.equal(piles.length, 1);
  assert.deepEqual(piles[0].sources, ["chaser", "lobber"]);
  assert.equal(piles[0].died, true);
  const f = grade([result({ piles }), result({ piles })]);
  assert.equal(f[0].severity, "major");
  assert.equal(f[0].runs.length, 2);
});

test("hitches ignore the bot's own cost and stage loads, and repeats become major", () => {
  const ticks = Array.from({ length: 400 }, (_, i) => i + 1);
  const usec = ticks.map((t) => (t === 250 ? 50_000 : t === 305 ? 60_000 : t === 350 ? 45_000 : 5_000));
  const bot = ticks.map((t) => (t === 350 ? 40_000 : 1000));
  const events = [{ tick: 300, event: "stage_entered", args: [2, false] }];
  const h = hitches({ samples: { tick_wall: { ticks, usec }, bot_driver: { ticks, usec: bot } } }, events);
  assert.deepEqual(h.spikes, [{ tick: 250, stage: null, ms: 49 }]);
  assert.equal(h.loads, 1);
  const r1 = result({ perf: { spikes: [{ tick: 900, stage: 2, ms: 40 }, { tick: 50, stage: 1, ms: 90 }], loads: 0, p99: 4 } });
  const r2 = result({ job: job({ id: "other", seed: 2501 }), perf: { spikes: [{ tick: 901, stage: 2, ms: 41 }], loads: 0, p99: 12 } });
  const r3 = result({ job: job({ id: "same-seed" }), perf: { spikes: [{ tick: 50, stage: 1, ms: 80 }], loads: 0, p99: 4 } });
  const f = grade([r1, r2, r3], { hitchTriage: { tested: 2, alone: 2, noMix: 0 } });
  const shared = f.find((x) => x.key === "hitch:shared");
  assert.equal(shared.severity, "major");
  assert.equal(shared.runs.length, 2);
  assert.equal(shared.counts["still hitched without the music mix"], 0);
  assert.equal(f.find((x) => x.key === "hitch:scattered").title, "2 scattered ticks over 33 ms");
  assert.equal(f.find((x) => x.key === "cpu-p99").severity, "watch");
});

test("log errors group by message with numbers folded", () => {
  const errs = logErrors("SCRIPT ERROR: Invalid index 3 on base Array\n   at x\nSCRIPT ERROR: Invalid index 7 on base Array\nERROR: thing\nWARNING: fine\n");
  assert.deepEqual(errs.map((e) => [e.script, e.count]), [[true, 2], [false, 1]]);
});

test("readBotJob tolerates a run cut short and the page ranks blockers first", () => {
  const r = readBotJob(job(), { exit: 1, timedOut: false, log: "", bots: "", runs: "{bad", events: "", profile: null });
  assert.equal(r.row, null);
  const findings = grade([r, result({ row: { outcome: "won", stage_reached: 7, game_seconds: 60, stages: [{ stage: 1, warden_fight_s: 0.01, warden_engaged_s: 3, warden_broken_s: 4.5, parts: ["a"] }, { stage: 2, warden_fight_s: 2, warden_engaged_s: 3, warden_broken_s: 30 }], beats: [] } })], { placeholders: { total: 5, byKind: { park: 5 } } });
  assert.deepEqual(findings.map((f) => f.severity), ["blocker", "major", "watch"]);
  const page = renderMarkdown({ wave: 15, commit: "abcdef0123456", started: "now", minutes: 1, results: [r], findings });
  assert.match(page, /1 blocker, 1 major, 0 minor, 1 to watch/);
  assert.match(page, /1\. \*\*BLOCKER\*\* · stability · A run crashed/);
  assert.deepEqual(carryList(findings), [{ persona: "speedrunner", pilot: "tarn", seed: 2500, title: "A run crashed" }]);
});
