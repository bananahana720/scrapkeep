import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { ROWS, brokeRule, buildReceipt, cfgRules, parseTlc, syncCommit } from "./model-receipts.mjs";
import { receiptRow } from "../world1-bands.mjs";

const HEAD = "3adc2fd0e8563b13c87f921b2ae85763467fec03";
const SKILL = new URL("../../.agents/skills/scrapkeep-verify-formal/", import.meta.url);
const cfg = (name) => cfgRules(readFileSync(new URL(`models/${name}`, SKILL), "utf8"));

// The shape of plain TLC output (no -tool flag). Written by hand from TLC's message formats, not captured from a run.
const CLEAN = `TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)
Running breadth-first search Model-Checking with fp 12 and seed 1 with 4 workers on 12 cores
Parsing file /tmp/model-receipt-x/Rewards.tla
Semantic processing of module Rewards
Starting... (2026-11-17 10:00:00)
Computing initial states...
Finished computing initial states: 1 distinct state generated at 2026-11-17 10:00:00.
Model checking completed. No error has been found.
  Estimates of the probability that TLC did not check all reachable states
  because two distinct states had the same fingerprint:
  calculated (optimistic):  val = 1.2E-10
210,544 states generated, 48,537 distinct states found, 0 states left on queue.
The depth of the complete state graph search is 41.
Finished in 03s at (2026-11-17 10:00:03)`;

const INVARIANT = `TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)
Computing initial states...
Finished computing initial states: 1 distinct state generated at 2026-11-17 10:00:00.
Error: Invariant AtMostOnce is violated.
Error: The behavior up to this point is:
State 1: <Initial predicate>
/\\ landed = 0
State 2: <Launch line 120, col 3 to line 130, col 40 of module Rewards>
/\\ landed = 2
1204 states generated, 611 distinct states found, 83 states left on queue.
The depth of the complete state graph search is 9.
Finished in 01s at (2026-11-17 10:00:01)`;

const TEMPORAL = `TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)
Implied-temporal checking--satisfiability problem has 1 branches.
Finished computing initial states: 1 distinct state generated at 2026-11-17 10:00:00.
Checking temporal properties for the complete state space with 3120 total distinct states at (2026-11-17 10:00:01)
Error: Temporal properties were violated.
Error: The following behavior constitutes a counter-example:
State 1: <Initial predicate>
Back to state 4: <WardenVanished line 183, col 1 to line 190, col 20 of module RunFlow>
9876 states generated, 3,120 distinct states found, 0 states left on queue.
Finished in 02s at (2026-11-17 10:00:02)`;

const PARSE = `TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)
***Parse Error***
Encountered "==" at line 40, column 9 in module RunFlow
Fatal errors while parsing TLA+ spec in file RunFlow`;

const STOPPED = `TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)
Computing initial states...
Progress(12) at 2026-11-17 10:00:00: 50,000 states generated, 20,000 distinct states found, 9,000 states left on queue.`;

const parsed = { clean: parseTlc(CLEAN), inv: parseTlc(INVARIANT), temporal: parseTlc(TEMPORAL) };

test("a finished clean run is clean, with the final state counts", () => {
  assert.deepEqual(parsed.clean, { outcome: "clean", rules: [], temporal: false, deadlock: false, generated: 210544, distinct: 48537, error: null });
});

test("a violated invariant is named, a temporal break is flagged, a deadlock is a break", () => {
  assert.equal(parsed.inv.outcome, "violated");
  assert.deepEqual(parsed.inv.rules, ["AtMostOnce"]);
  assert.equal(parsed.inv.distinct, 611);
  assert.equal(parsed.temporal.outcome, "violated");
  assert.equal(parsed.temporal.temporal, true);
  assert.equal(parsed.temporal.distinct, 3120);
  const dead = parseTlc("Error: Deadlock reached.\n10 states generated, 5 distinct states found, 2 states left on queue.");
  assert.equal(dead.outcome, "violated");
  assert.equal(dead.deadlock, true);
});

test("a parse error, a run cut short and no output are errors, never clean", () => {
  assert.equal(parseTlc(PARSE).outcome, "error");
  assert.match(parseTlc(PARSE).error, /Parse Error/);
  assert.equal(parseTlc(STOPPED).outcome, "error");
  assert.equal(parseTlc("").outcome, "error");
  assert.equal(parseTlc(`${CLEAN}\nError: TLC threw an unexpected exception.`).outcome, "error");
});

test("a plant counts as caught only on the rule it names", () => {
  assert.equal(brokeRule(parsed.inv, cfg("rewards-broken-ledger.cfg"), "AtMostOnce"), true);
  assert.equal(brokeRule(parsed.inv, cfg("rewards-broken-midsave.cfg"), "NeverLost"), false);
  assert.equal(brokeRule(parsed.temporal, cfg("broken-vanish.cfg"), "WardenGoneOpens"), true);
  assert.equal(brokeRule(parsed.temporal, cfg("broken-endguard.cfg"), "EndsOnce"), false);
  assert.equal(brokeRule(parsed.clean, cfg("broken-vanish.cfg"), "WardenGoneOpens"), false);
});

test("every config the producer runs exists and checks the rule it is read for", () => {
  for (const row of Object.values(ROWS)) {
    assert.ok(cfg(row.real).invariants.length > 0, row.real);
    for (const p of row.plants) {
      const r = cfg(p.cfg);
      assert.ok([...r.invariants, ...r.properties].includes(p.rule), `${p.cfg} checks ${p.rule}`);
    }
  }
});

test("each model's coverage page names a sync commit", () => {
  for (const row of Object.values(ROWS)) assert.match(syncCommit(readFileSync(new URL(row.coverage, SKILL), "utf8")), /^[0-9a-f]{7,40}$/);
  assert.equal(syncCommit("text\n\n`bbd157f44` (branch w43/x; before it, `3adc2fd0e`)\n"), "bbd157f44");
  assert.equal(syncCommit("Sync commit: 04a7311c4\n"), "04a7311c4");
  assert.equal(syncCommit("no commit here"), null);
});

const rewards = ROWS["rewards-banked-once"];
const plantsOf = (ledger, midsave) => [
  { ...rewards.plants[0], rules: cfg(rewards.plants[0].cfg), parsed: ledger },
  { ...rewards.plants[1], rules: cfg(rewards.plants[1].cfg), parsed: midsave },
];
const neverLost = parseTlc(INVARIANT.replace("AtMostOnce", "NeverLost"));
const synced = { sync: "04a7311c4", files: [] };
const row = { id: "rewards-banked-once", plant: "the settle ledger removed from the model must show a reward banked twice", producer: "x" };

test("the code's config clean and both plants caught: a passing receipt the done table accepts", () => {
  const r = buildReceipt({ head: HEAD, real: { cfg: rewards.real, parsed: parsed.clean }, plants: plantsOf(parsed.inv, neverLost), drift: synced });
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.equal(r.measured, "rewards-today-one: no break in 48,537 distinct states; plants: rewards-broken-ledger broke AtMostOnce in 611 states; rewards-broken-midsave broke NeverLost in 611 states");
  assert.deepEqual(receiptRow(row, r, HEAD), { measured: r.measured, pass: true });
});

test("a break on the code's config fails the receipt and names the rule", () => {
  const r = buildReceipt({ head: HEAD, real: { cfg: rewards.real, parsed: neverLost }, plants: plantsOf(parsed.inv, neverLost), drift: synced });
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /^rewards-today-one: broke NeverLost/);
});

test("a plant that shows no break is not caught, so the done table voids the receipt", () => {
  const r = buildReceipt({ head: HEAD, real: { cfg: rewards.real, parsed: parsed.clean }, plants: plantsOf(parsed.inv, parsed.clean), drift: synced });
  assert.equal(r.plant_caught, false);
  assert.equal(r.pass, false);
  assert.match(r.measured, /rewards-broken-midsave did not break NeverLost \(no break\)/);
  assert.match(receiptRow(row, r, HEAD).measured, /^void, the planted fault was not shown caught/);
});

test("a covered file changed since the sync commit fails the receipt until the model is synced", () => {
  const r = buildReceipt({ head: HEAD, real: { cfg: rewards.real, parsed: parsed.clean }, plants: plantsOf(parsed.inv, neverLost),
    drift: { sync: "04a7311c4", files: ["sketches/core-loop/src/core/progress.gd"] } });
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /^model not synced: sketches\/core-loop\/src\/core\/progress\.gd changed since 04a7311c4; /);
  assert.equal(buildReceipt({ head: HEAD, real: { cfg: rewards.real, parsed: parsed.clean }, plants: plantsOf(parsed.inv, neverLost), drift: { sync: null, files: [] } }).pass, false);
});

test("a receipt for another head is stale", () => {
  const r = buildReceipt({ head: HEAD, real: { cfg: rewards.real, parsed: parsed.clean }, plants: plantsOf(parsed.inv, neverLost), drift: synced });
  assert.equal(receiptRow(row, r, "ffffffffffffffffffff").noData, true);
});
