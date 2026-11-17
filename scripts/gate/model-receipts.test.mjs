import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { ROWS, brokeRule, buildReceipt, cfgRules, coveredFiles, parseTlc, syncCommit, timedOut } from "./model-receipts.mjs";
import { receiptRow } from "../world1-bands.mjs";

const HEAD = "3adc2fd0e8563b13c87f921b2ae85763467fec03";
const SKILL = new URL("../../.agents/skills/scrapkeep-verify-formal/", import.meta.url);
const cfg = (name) => cfgRules(readFileSync(new URL(`models/${name}`, SKILL), "utf8"));

// Real TLC 2.19 output (tla2tools 1.7.4), trimmed by dropping the variable values under each State line and the temp
// folder paths. Captured on the Mac Studio on 17 November 2026 from the configs each file is named for; the rewards-*
// files from the W1-117 model (old and new reward keys apart, the save lock), with TLC's Progress lines dropped too.
const fixture = (name) => readFileSync(new URL(`fixtures/tlc/${name}.out`, import.meta.url), "utf8");
const out = {
  clean: parseTlc(fixture("today-store")),
  vanish: parseTlc(fixture("broken-vanish")),
  endguard: parseTlc(fixture("broken-endguard")),
  rewardsClean: parseTlc(fixture("rewards-today-one")),
  rewardsTwo: parseTlc(fixture("rewards-today-two-once")),
  ledger: parseTlc(fixture("rewards-broken-ledger")),
  midsave: parseTlc(fixture("rewards-broken-midsave")),
};

test("a finished clean run is clean, with the final state counts", () => {
  assert.deepEqual(out.clean, { outcome: "clean", rules: [], temporal: false, deadlock: false, generated: 4137, distinct: 1444, error: null });
  assert.equal(out.rewardsClean.outcome, "clean");
  assert.ok(out.rewardsClean.distinct > 0);
});

test("a violated invariant is named and a temporal break is flagged", () => {
  assert.equal(out.endguard.outcome, "violated");
  assert.deepEqual(out.endguard.rules, ["EndsOnce"]);
  assert.equal(out.endguard.distinct, 72);
  assert.equal(out.vanish.outcome, "violated");
  assert.equal(out.vanish.temporal, true);
  assert.deepEqual(out.vanish.rules, []);
  assert.equal(out.vanish.distinct, 1444);
  assert.deepEqual(out.ledger.rules, ["AtMostOnce"]);
  assert.deepEqual(out.midsave.rules, ["NeverLost"]);
  const dead = parseTlc("Error: Deadlock reached.\n10 states generated, 5 distinct states found, 2 states left on queue.");
  assert.equal(dead.outcome, "violated");
  assert.equal(dead.deadlock, true);
});

test("a TLC that refused its options, a run cut short and no output are errors, never clean", () => {
  const bad = parseTlc(fixture("bad-option"));
  assert.equal(bad.outcome, "error");
  assert.match(bad.error, /unrecognized option/);
  const clean = fixture("today-store");
  assert.equal(parseTlc(clean.slice(0, clean.indexOf("Model checking completed"))).outcome, "error");
  assert.equal(parseTlc("").outcome, "error");
});

test("a plant counts as caught only on the rule it names", () => {
  assert.equal(brokeRule(out.vanish, cfg("broken-vanish.cfg"), "WardenGoneOpens"), true);
  assert.equal(brokeRule(out.endguard, cfg("broken-endguard.cfg"), "EndsOnce"), true);
  assert.equal(brokeRule(out.ledger, cfg("rewards-broken-ledger.cfg"), "AtMostOnce"), true);
  assert.equal(brokeRule(out.midsave, cfg("rewards-broken-midsave.cfg"), "NeverLost"), true);
  assert.equal(brokeRule(out.ledger, cfg("rewards-broken-midsave.cfg"), "NeverLost"), false);
  assert.equal(brokeRule(out.vanish, cfg("broken-endguard.cfg"), "EndsOnce"), false);
  assert.equal(brokeRule(out.clean, cfg("broken-vanish.cfg"), "WardenGoneOpens"), false);
});

test("every config the producer runs exists and checks the rule it is read for", () => {
  for (const row of Object.values(ROWS)) {
    for (const r of row.real) assert.ok(cfg(r.cfg).invariants.length > 0, r.cfg);
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

const flow = ROWS["run-always-ends"];
const plantsOf = (vanish, endguard) => [
  { ...flow.plants[0], rules: cfg(flow.plants[0].cfg), parsed: vanish },
  { ...flow.plants[1], rules: cfg(flow.plants[1].cfg), parsed: endguard },
];
const synced = { sync: "bbd157f44", files: [] };
const row = { id: "run-always-ends", plant: "the model without the vanished-Warden fallback must show a run that never ends", producer: "x" };
const receipt = (real, plants, drift = synced) => buildReceipt({ head: HEAD, real: [{ ...flow.real[0], parsed: real }], plants, drift });

test("the code's config clean and both plants caught: a passing receipt the done table accepts", () => {
  const r = receipt(out.clean, plantsOf(out.vanish, out.endguard));
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.equal(r.measured, "today-store: no break in 1,444 distinct states; plants: broken-vanish broke WardenGoneOpens in 1,444 states; broken-endguard broke EndsOnce in 72 states");
  assert.deepEqual(receiptRow(row, r, HEAD), { measured: r.measured, pass: true });
});

test("a break on the code's config fails the receipt and names the rule", () => {
  const r = receipt(out.endguard, plantsOf(out.vanish, out.endguard));
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /^today-store: broke EndsOnce/);
});

test("a plant that shows no break, or breaks another rule, is not caught, so the done table voids the receipt", () => {
  const r = receipt(out.clean, plantsOf(out.vanish, out.clean));
  assert.equal(r.plant_caught, false);
  assert.equal(r.pass, false);
  assert.match(r.measured, /broken-endguard did not break EndsOnce \(no break\)/);
  assert.match(receiptRow(row, r, HEAD).measured, /^void, the planted fault was not shown caught/);
  assert.equal(receipt(out.clean, plantsOf(out.endguard, out.endguard)).plant_caught, false);
});

test("a covered file changed since the sync commit fails the receipt until the model is synced", () => {
  const r = receipt(out.clean, plantsOf(out.vanish, out.endguard), { sync: "bbd157f44", files: ["sketches/core-loop/src/core/flow.gd"] });
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /^model not synced: sketches\/core-loop\/src\/core\/flow\.gd changed since bbd157f44; /);
  assert.equal(receipt(out.clean, plantsOf(out.vanish, out.endguard), { sync: null, files: [] }).pass, false);
});

test("a receipt for another head is stale", () => {
  const r = receipt(out.clean, plantsOf(out.vanish, out.endguard));
  assert.equal(receiptRow(row, r, "ffffffffffffffffffff").noData, true);
});

test("a run stopped by the timeout is a miss that says it did not finish", () => {
  const r = receipt(timedOut(30), plantsOf(out.vanish, out.endguard));
  assert.equal(r.pass, false);
  assert.match(r.measured, /^today-store: stopped: did not finish in 30 min/);
  assert.equal(receipt(out.clean, plantsOf(timedOut(30), out.endguard)).plant_caught, false);
});

test("the covered files are every source file the coverage page cites", () => {
  assert.deepEqual(coveredFiles("`sketches/core-loop/src/core/flow.gd:12` and sketches/core-loop/src/build/build.gd, again `sketches/core-loop/src/core/flow.gd`"),
    ["sketches/core-loop/src/build/build.gd", "sketches/core-loop/src/core/flow.gd"]);
  const page = (row) => coveredFiles(readFileSync(new URL(ROWS[row].coverage, SKILL), "utf8"));
  for (const f of ["core/flow.gd", "core/run_state.gd", "build/build.gd", "game.gd", "presentation/launch_take.gd", "ui/pause_menu.gd", "ui/screens.gd"]) {
    assert.ok(page("run-always-ends").includes(`sketches/core-loop/src/${f}`), f);
  }
  for (const f of ["core/flow.gd", "core/run_state.gd", "game.gd", "core/profile.gd", "core/safe_store.gd", "core/run_store.gd", "core/progress.gd"]) {
    assert.ok(page("rewards-banked-once").includes(`sketches/core-loop/src/${f}`), f);
  }
});

test("the rewards receipt checks the old-key route and two games, fails on a break in either, and names what it cannot see", () => {
  const rw = ROWS["rewards-banked-once"];
  assert.deepEqual(rw.real.map((r) => r.cfg), ["rewards-today-one.cfg", "rewards-today-two-once.cfg", "rewards-today-two-lost.cfg"]);
  assert.equal(cfg("rewards-today-one.cfg").invariants.includes("NeverLost"), true);
  assert.equal(cfg("rewards-today-two-lost.cfg").invariants.includes("NeverLost"), true);
  assert.equal(cfg("rewards-today-two-once.cfg").invariants.includes("AtMostOnce"), true);
  assert.deepEqual(rw.plants.map((p) => [p.cfg, p.rule]), [
    ["rewards-broken-ledger.cfg", "AtMostOnce"],
    ["rewards-broken-midsave.cfg", "NeverLost"],
    ["rewards-broken-legacyrun.cfg", "NeverLost"],
    ["rewards-broken-stale.cfg", "AtMostOnce"],
    ["rewards-broken-nolock.cfg", "AtMostOnce"],
  ]);
  const caughtBy = { AtMostOnce: out.ledger, NeverLost: out.midsave };
  const plants = rw.plants.map((p) => ({ ...p, rules: cfg(p.cfg), parsed: caughtBy[p.rule] }));
  const real = (second) => [
    { ...rw.real[0], parsed: out.rewardsClean },
    { ...rw.real[1], parsed: second },
    { ...rw.real[2], parsed: out.rewardsClean },
  ];
  const r = buildReceipt({ head: HEAD, real: real(out.ledger), plants, drift: synced, gaps: rw.gaps });
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /two games on one profile paying once \(finding R-2\), rewards-today-two-once: broke AtMostOnce/);
  const held = buildReceipt({ head: HEAD, real: real(out.rewardsTwo), plants, drift: synced, gaps: rw.gaps });
  assert.equal(held.pass, true);
  assert.match(held.measured, /older build's run file \(W1-117\), rewards-today-one: no break/);
  assert.match(held.measured, /finding R-2\), rewards-today-two-once: no break in 8,009,266 distinct states/);
  assert.match(held.measured, /not checked: the profile's save lock is taken as perfect/);
  assert.doesNotMatch(held.measured, /not modelled \(the model holds the old and new reward keys as one flag\)/);
});
