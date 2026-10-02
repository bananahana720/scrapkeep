import assert from "node:assert/strict";
import { test } from "node:test";

import {
  atLeast,
  atMost,
  evaluateBots,
  evaluatePerf,
  BY_HAND,
  evaluateReceipt,
  evaluateSitting,
  evaluateSweep,
  formatTable,
  median,
  readRunLog,
  sliceCell,
  summarizeRun,
} from "./checkpoint.mjs";

const run = (policy, seed, outcome, heft, parts, fightSeconds) => ({ policy, seed, outcome, heft, parts, fightSeconds });
const passing = () => ({
  completionist: [run("completionist", 1, "won", 2.2, 9, 25), run("completionist", 2, "won", 2.1, 8, 27), run("completionist", 3, "died", 1.9, 7, null)],
  skipper: [run("skipper", 1, "won", 1.0, 2, 90), run("skipper", 2, "died", 1.0, 3, null)],
  camper: [run("camper", 1, "died", 1.0, 1, null), run("camper", 2, "stalled", 1.0, 1, null)],
});
const byBand = (rows, band) => rows.find((r) => r.band === band);

test("thresholds are inclusive at the limit", () => {
  assert.equal(atMost(10, 10), true);
  assert.equal(atMost(10.01, 10), false);
  assert.equal(atLeast(0.6, 0.6), true);
  assert.equal(atLeast(null, 0.6), false);
  assert.equal(median([3, 1, 2, null]), 2);
  assert.equal(median([]), null);
});

test("a passing set of bots passes every bot band", () => {
  const rows = evaluateBots(passing());
  assert.equal(rows.length, 6);
  assert.deepEqual(rows.filter((r) => !r.pass), []);
});

test("a camper win, no skipper win and a slow explorer each miss their own band", () => {
  const camperWins = passing();
  camperWins.camper[0].outcome = "won";
  assert.equal(byBand(evaluateBots(camperWins), "camper cannot win").pass, false);

  const noSkipWin = passing();
  noSkipWin.skipper[0].outcome = "died";
  assert.equal(byBand(evaluateBots(noSkipWin), "skipper can win").pass, false);

  const lowRate = passing();
  lowRate.completionist[1].outcome = "died"; // 1 of 3 is 33 percent
  assert.equal(byBand(evaluateBots(lowRate), "explorer win rate").pass, false);

  const exactly60 = { completionist: Array.from({ length: 5 }, (_, i) => run("completionist", i, i < 3 ? "won" : "died", 2, 8, 25)), skipper: [], camper: [] };
  assert.equal(byBand(evaluateBots(exactly60), "explorer win rate").pass, true);
});

test("skipper must be slower, and the explorer bigger, than each other", () => {
  const fastSkip = passing();
  fastSkip.skipper[0].fightSeconds = 20;
  assert.equal(byBand(evaluateBots(fastSkip), "skipper slower than explorer (Warden fight)").pass, false);
  const sameHeft = passing();
  sameHeft.skipper[0].heft = 2.2;
  sameHeft.skipper[1].heft = 2.2;
  assert.equal(byBand(evaluateBots(sameHeft), "explorer heft above skipper").pass, false);
  const fewParts = passing();
  fewParts.skipper.forEach((r) => (r.parts = 20));
  assert.equal(byBand(evaluateBots(fewParts), "explorer parts above skipper").pass, false);
});

test("summarizeRun reads the last stage row that carries a value, and the fight from its posture block", () => {
  const line = {
    stages: [
      { heft_at_engage: 1.2, part_ids_at_exit: ["a"], ticks_to_warden_break: 18000, posture: { fight_ticks: 900 } },
      { heft_at_engage: 2.0, part_ids_at_exit: ["a", "b", "c"], ticks_to_warden_break: null },
    ],
  };
  const s = summarizeRun({ policy: "skipper", seed: 4, outcome: "won" }, line);
  assert.deepEqual([s.heft, s.parts, s.fightSeconds], [2.0, 3, 10]);
  const noPosture = summarizeRun({ policy: "skipper", seed: 5, outcome: "won" }, { stages: [{ ticks_to_warden_break: 900 }] });
  assert.equal(noPosture.fightSeconds, null);
  assert.equal(summarizeRun({ policy: "camper", seed: 1, outcome: "stalled" }, null).heft, null);
});

test("perf bands: CPU 10 ms and GPU 7 ms at the edge, and an invalid run misses", () => {
  const bench = (cpu, gpu) => ({ valid: true, size: [1920, 1080], display: "wayland", scene: "s3", table: "slice", stats: { process_ms: { p99: cpu }, gpu_ms: { p99: gpu } } });
  assert.deepEqual(evaluatePerf(bench(10, 7)).map((r) => r.pass), [true, true, true]);
  assert.deepEqual(evaluatePerf(bench(10.1, 7.1)).map((r) => r.pass), [true, false, false]);
  assert.equal(evaluatePerf({ ...bench(1, 1), display: "headless" })[0].pass, false);
  assert.equal(evaluatePerf(null)[1].pass, false);
});

test("sweep line is the slice cell's pass column; the receipt must match HEAD", () => {
  const defs = '"warden_plating": 110.0, "posture": {"curve": 2.0, "ram_shatters": false}';
  const cell = sliceCell(defs);
  assert.deepEqual(cell, { plating: 110, curve: 2, ram_shatters: "false" });
  const tsv = "plating\tcurve\tram_shatters\tgrown_median_s\tmid_median_s\tsmall_median_s\tsmall_to_grown\tpass\n110.0\t2.0\tfalse\t25.5\t54.5\t85.8\t3.36\tpass\n";
  assert.equal(evaluateSweep(tsv, cell).pass, true);
  assert.equal(evaluateSweep(tsv.replace("\tpass\n", "\tmiss\n"), cell).pass, false);
  assert.equal(evaluateSweep(tsv, { plating: 90, curve: 2, ram_shatters: "false" }).pass, false);
  const receipts = [{ label: "gate", head: "abc", started_at: "2026-10-02T10", ok: true, clean: true, totals: { failed: 0, runs: 9 } }, { label: "gate", head: "old", started_at: "2026-10-02T11", ok: true, clean: true }];
  assert.equal(evaluateReceipt(receipts, "abc").pass, true);
  assert.equal(evaluateReceipt(receipts, "new").pass, false);
  assert.equal(evaluateReceipt([{ ...receipts[0], ok: false }], "abc").pass, false);
  assert.equal(evaluateReceipt([{ ...receipts[0], clean: false }], "abc").pass, false);
});

test("the table prints a pass, a miss, a skip and a by-hand row", () => {
  const text = formatTable([{ band: "a", measured: "1", threshold: "2", pass: true }, { band: "b", measured: "3", threshold: "4", pass: false }, { band: "c", measured: "-", threshold: "-", pass: null }, { band: "d", measured: "5", threshold: "6", pass: null, byHand: true }]);
  assert.match(text, /d\s+5\s+6\s+by hand/);
  assert.match(text, /a\s+1\s+2\s+pass/);
  assert.match(text, /b\s+3\s+4\s+MISS/);
  assert.match(text, /c\s+-\s+-\s+skipped/);
});

// --- --after on a fixture log ----------------------------------------------------------

const line = (id, extra) => JSON.stringify({ table: "slice", outcome: "running", bites: 0, smashes: 0, stages: [], ...extra, run_id: id });
const fixture = [
  line("r1", { smashes: 1, stages: [{ events_joined: ["surge_run"], ticks_to_warden_engaged: 1000, attempts: 1 }] }),
  line("r1", { outcome: "lost", smashes: 6, bites: 8, stages: [{ events_joined: ["surge_run", "scrap_stampede", "surge_run"], ticks_to_warden_engaged: 6300, attempts: 2 }] }),
  line("r2", { outcome: "won", smashes: 2, stages: [{ events_joined: [], ticks_to_warden_engaged: 900, attempts: 1 }] }),
  JSON.stringify({ run_id: "old", table: "default", stages: [] }),
  "not json",
].join("\n");

test("readRunLog keeps the last line of each slice run and drops other tables", () => {
  const runs = readRunLog(fixture);
  assert.deepEqual(runs.map((r) => [r.run_id, r.outcome]), [["r1", "lost"], ["r2", "won"]]);
});

test("the sitting reader answers each question and reports one with no field as not measurable", () => {
  const verdicts = Object.fromEntries(evaluateSitting(readRunLog(fixture)).map((v) => [v.id, v]));
  assert.equal(verdicts.activities.verdict, "pass");
  assert.deepEqual(verdicts.activities.values, [2, 0]);
  assert.equal(verdicts.zone.verdict, "pass"); // 6300 ticks is 70 s
  assert.equal(verdicts.second_run.verdict, "pass");
  assert.equal(verdicts.smashes.verdict, "not measurable");
  assert.equal(verdicts.smashes.measurable, false);
  assert.match(verdicts.smashes.reason, /target/);
  const oneRun = evaluateSitting(readRunLog(line("only", { stages: [{ events_joined: ["surge_run"], ticks_to_warden_engaged: 90 }] })));
  const byId = Object.fromEntries(oneRun.map((v) => [v.id, v.verdict]));
  assert.deepEqual([byId.activities, byId.zone, byId.second_run], ["miss", "miss", "miss"]);
});

test("a custom question with a reason reports not measurable", () => {
  const verdicts = evaluateSitting([], [{ id: "x", ask: "ask", fields: [], read: () => null, reason: "no field for x" }]);
  assert.equal(verdicts[0].verdict, "not measurable");
  assert.equal(verdicts[0].reason, "no field for x");
});

test("by-hand rows never count as a pass or a miss", () => {
  assert.ok(BY_HAND.length >= 3);
  for (const row of BY_HAND) assert.deepEqual([row.pass, row.byHand], [null, true]);
});
