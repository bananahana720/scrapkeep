import assert from "node:assert/strict";
import {
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import {
  ROWS,
  brokeRule,
  buildReceipt,
  cfgRules,
  coveredFiles,
  findJar,
  parseTlc,
  syncCommit,
  timedOut,
} from "./model-receipts.mjs";
import { receiptRow } from "../world1-bands.mjs";

const HEAD = "3adc2fd0e8563b13c87f921b2ae85763467fec03";
const SKILL = new URL("../../.agents/skills/scrapkeep-verify-formal/", import.meta.url);
const cfg = (name) => cfgRules(readFileSync(new URL(`models/${name}`, SKILL), "utf8"));

const fixture = (name) =>
  readFileSync(new URL(`fixtures/tlc/${name}.out`, import.meta.url), "utf8");
const out = {
  clean: parseTlc(fixture("today-store")),
  vanish: parseTlc(fixture("broken-vanish")),
  endguard: parseTlc(fixture("broken-endguard")),
  rewardsClean: parseTlc(fixture("rewards-today-one")),
  rewardsTwo: parseTlc(fixture("rewards-today-two-once")),
  ledger: parseTlc(fixture("rewards-broken-ledger")),
  midsave: parseTlc(fixture("rewards-broken-midsave")),
  hazardClean: parseTlc(fixture("hazard-today")),
  hitAnywhere: parseTlc(fixture("hazard-broken-hitanywhere")),
};

test("a finished clean run is clean, with the final state counts", () => {
  assert.deepEqual(out.clean, {
    outcome: "clean",
    rules: [],
    temporal: false,
    deadlock: false,
    generated: 4137,
    distinct: 1444,
    error: null,
  });
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
  const dead = parseTlc(
    "Error: Deadlock reached.\n10 states generated, 5 distinct states found, 2 states left on queue.",
  );
  assert.equal(dead.outcome, "violated");
  assert.equal(dead.deadlock, true);
});

test("a TLC that refused its options, a run cut short and no output are errors, never clean", () => {
  const bad = parseTlc(fixture("bad-option"));
  assert.equal(bad.outcome, "error");
  assert.match(bad.error, /unrecognized option/);
  const clean = fixture("today-store");
  assert.equal(
    parseTlc(clean.slice(0, clean.indexOf("Model checking completed"))).outcome,
    "error",
  );
  assert.equal(parseTlc("").outcome, "error");
});

test("a plant counts as caught only on the rule it names", () => {
  assert.equal(brokeRule(out.vanish, cfg("broken-vanish.cfg"), "WardenGoneOpens"), true);
  assert.equal(brokeRule(out.endguard, cfg("broken-endguard.cfg"), "EndsOnce"), true);
  assert.equal(brokeRule(out.ledger, cfg("rewards-broken-ledger.cfg"), "AtMostOnce"), true);
  assert.equal(brokeRule(out.midsave, cfg("rewards-broken-midsave.cfg"), "NeverLost"), true);
  assert.equal(
    brokeRule(out.hitAnywhere, cfg("hazard-broken-hitanywhere.cfg"), "BallOnlyWhereTold"),
    true,
  );
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
  for (const row of Object.values(ROWS))
    assert.match(
      syncCommit(readFileSync(new URL(row.coverage, SKILL), "utf8")),
      /^[0-9a-f]{7,40}$/,
    );
  assert.equal(
    syncCommit("text\n\n`bbd157f44` (branch w43/x; before it, `3adc2fd0e`)\n"),
    "bbd157f44",
  );
  assert.equal(syncCommit("Sync commit: 04a7311c4\n"), "04a7311c4");
  assert.equal(syncCommit("no commit here"), null);
});

const flow = ROWS["run-always-ends"];
const plantsOf = (vanish, endguard) => [
  { ...flow.plants[0], rules: cfg(flow.plants[0].cfg), parsed: vanish },
  { ...flow.plants[1], rules: cfg(flow.plants[1].cfg), parsed: endguard },
];
const synced = { sync: "bbd157f44", files: [] };
const row = {
  id: "run-always-ends",
  plant: "the model without the vanished-Warden fallback must show a run that never ends",
  producer: "x",
};
const receipt = (real, plants, drift = synced) =>
  buildReceipt({ head: HEAD, real: [{ ...flow.real[0], parsed: real }], plants, drift });

test("the code's config clean and both plants caught: a passing receipt the done table accepts", () => {
  const r = receipt(out.clean, plantsOf(out.vanish, out.endguard));
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.equal(
    r.measured,
    "today-store: no break in 1,444 distinct states; plants: broken-vanish broke WardenGoneOpens in 1,444 states; broken-endguard broke EndsOnce in 72 states",
  );
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
  const r = receipt(out.clean, plantsOf(out.vanish, out.endguard), {
    sync: "bbd157f44",
    files: ["sketches/core-loop/src/core/flow.gd"],
  });
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, true);
  assert.match(
    r.measured,
    /^model not synced: sketches\/core-loop\/src\/core\/flow\.gd changed since bbd157f44; /,
  );
  assert.equal(
    receipt(out.clean, plantsOf(out.vanish, out.endguard), { sync: null, files: [] }).pass,
    false,
  );
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
  assert.deepEqual(
    coveredFiles(
      "`sketches/core-loop/src/core/flow.gd:12` and sketches/core-loop/src/build/build.gd, again `sketches/core-loop/src/core/flow.gd`",
    ),
    ["sketches/core-loop/src/build/build.gd", "sketches/core-loop/src/core/flow.gd"],
  );
  const page = (row) => coveredFiles(readFileSync(new URL(ROWS[row].coverage, SKILL), "utf8"));
  for (const f of [
    "core/flow.gd",
    "core/run_state.gd",
    "build/build.gd",
    "game.gd",
    "presentation/launch_take.gd",
    "ui/pause_menu.gd",
    "ui/screens.gd",
  ]) {
    assert.ok(page("run-always-ends").includes(`sketches/core-loop/src/${f}`), f);
  }
  for (const f of [
    "core/flow.gd",
    "core/run_state.gd",
    "game.gd",
    "core/profile.gd",
    "core/safe_store.gd",
    "core/run_store.gd",
    "core/progress.gd",
  ]) {
    assert.ok(page("rewards-banked-once").includes(`sketches/core-loop/src/${f}`), f);
  }
});

test("the rewards receipt checks the old-key route and two games, fails on a break in either, and names what it cannot see", () => {
  const rw = ROWS["rewards-banked-once"];
  assert.deepEqual(
    rw.real.map((r) => r.cfg),
    ["rewards-today-one.cfg", "rewards-today-two-once.cfg", "rewards-today-two-lost.cfg"],
  );
  assert.equal(cfg("rewards-today-one.cfg").invariants.includes("NeverLost"), true);
  assert.equal(cfg("rewards-today-two-lost.cfg").invariants.includes("NeverLost"), true);
  assert.equal(cfg("rewards-today-two-once.cfg").invariants.includes("AtMostOnce"), true);
  assert.deepEqual(
    rw.plants.map((p) => [p.cfg, p.rule]),
    [
      ["rewards-broken-ledger.cfg", "AtMostOnce"],
      ["rewards-broken-midsave.cfg", "NeverLost"],
      ["rewards-broken-legacyrun.cfg", "NeverLost"],
      ["rewards-broken-stale.cfg", "AtMostOnce"],
      ["rewards-broken-nolock.cfg", "AtMostOnce"],
    ],
  );
  const caughtBy = { AtMostOnce: out.ledger, NeverLost: out.midsave };
  const plants = rw.plants.map((p) => ({ ...p, rules: cfg(p.cfg), parsed: caughtBy[p.rule] }));
  const real = (second) => [
    { ...rw.real[0], parsed: out.rewardsClean },
    { ...rw.real[1], parsed: second },
    { ...rw.real[2], parsed: { ...out.rewardsTwo, distinct: rw.real[2].minStates } },
  ];
  const r = buildReceipt({
    head: HEAD,
    real: real(out.ledger),
    plants,
    drift: synced,
    gaps: rw.gaps,
  });
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, true);
  assert.match(
    r.measured,
    /two games on one profile paying once \(finding R-2\), rewards-today-two-once: broke AtMostOnce/,
  );
  const held = buildReceipt({
    head: HEAD,
    real: real(out.rewardsTwo),
    plants,
    drift: synced,
    gaps: rw.gaps,
  });
  assert.equal(held.pass, true);
  assert.match(held.measured, /older build's run file \(W1-117\), rewards-today-one: no break/);
  assert.match(
    held.measured,
    /finding R-2\), rewards-today-two-once: no break in 8,009,266 distinct states/,
  );
  assert.match(held.measured, /not checked: the profile's save lock is taken as perfect/);
  assert.doesNotMatch(
    held.measured,
    /not modelled \(the model holds the old and new reward keys as one flag\)/,
  );
  assert.match(held.measured, /finding R-1\) stays unpaid: .* card W1-121/);
});

test("a code config with fewer distinct states than its pin is a miss, and every code config carries a pin", () => {
  for (const row of Object.values(ROWS))
    for (const r of row.real) assert.ok(Number.isInteger(r.minStates) && r.minStates > 0, r.cfg);
  const rw = ROWS["rewards-banked-once"];
  const plants = rw.plants.map((p) => ({
    ...p,
    rules: cfg(p.cfg),
    parsed: p.rule === "AtMostOnce" ? out.ledger : out.midsave,
  }));
  const real = (one) => [
    { ...rw.real[0], parsed: one },
    { ...rw.real[1], parsed: out.rewardsTwo },
    { ...rw.real[2], parsed: { ...out.rewardsTwo, distinct: rw.real[2].minStates } },
  ];
  assert.equal(
    buildReceipt({ head: HEAD, real: real(out.rewardsClean), plants, drift: synced, gaps: rw.gaps })
      .pass,
    true,
  );
  const shrunk = buildReceipt({
    head: HEAD,
    real: real({ ...out.rewardsClean, distinct: rw.real[0].minStates - 1 }),
    plants,
    drift: synced,
    gaps: rw.gaps,
  });
  assert.equal(shrunk.pass, false);
  assert.match(
    shrunk.measured,
    /rewards-today-one: no break in 98,318 distinct states \(fewer than the 98,319 pinned\)/,
  );
  assert.equal(out.clean.distinct, ROWS["run-always-ends"].real[0].minStates);
  assert.equal(out.rewardsClean.distinct, rw.real[0].minStates);
  assert.equal(out.rewardsTwo.distinct, rw.real[1].minStates);
  assert.equal(out.hazardClean.outcome, "clean");
  assert.equal(out.hazardClean.distinct, ROWS["hazards-hit-everyone"].real[0].minStates);
});

test("the flood row's pins and plants match captured TLC output", () => {
  const fl = ROWS["flood-never-held"];
  for (const r of fl.real) {
    const parsed = parseTlc(fixture(r.cfg.replace(".cfg", "")));
    assert.equal(parsed.outcome, "clean", r.cfg);
    assert.equal(parsed.distinct, r.minStates, r.cfg);
  }
  for (const p of fl.plants)
    assert.equal(
      brokeRule(parseTlc(fixture(p.cfg.replace(".cfg", ""))), cfg(p.cfg), p.rule),
      true,
      `${p.cfg} breaks ${p.rule}`,
    );
});

test("the destructibles row's pin and plants match captured TLC output, and its page covers the code it models", () => {
  const ds = ROWS["destructibles-safe"];
  for (const r of ds.real) {
    const parsed = parseTlc(fixture(r.cfg.replace(".cfg", "")));
    assert.equal(parsed.outcome, "clean", r.cfg);
    assert.equal(parsed.distinct, r.minStates, r.cfg);
  }
  assert.deepEqual(ds.plants.map((p) => p.rule).sort(), [
    "NoColliderAfterShatter",
    "NoLineOnRubble",
    "NoLineOnRubble",
    "NoLineOnRubble",
    "PaysOnce",
    "PaysOnce",
    "RetryNoFarm",
    "RetryNoFarm",
    "TierCapNeverStacks",
  ]);
  for (const p of ds.plants)
    assert.equal(
      brokeRule(parseTlc(fixture(p.cfg.replace(".cfg", ""))), cfg(p.cfg), p.rule),
      true,
      `${p.cfg} breaks ${p.rule}`,
    );
  const covered = coveredFiles(readFileSync(new URL(ds.coverage, SKILL), "utf8"));
  for (const f of [
    "world/destructibles.gd",
    "world/world.gd",
    "movement/player_ball.gd",
    "core/flow.gd",
    "core/run_state.gd",
    "build/build.gd",
    "build/scrap_field.gd",
  ])
    assert.ok(covered.includes(`sketches/core-loop/src/${f}`), f);
});

test("the flood row checks the step past the live time and no longer names PF-2 as a gap", () => {
  const fl = ROWS["flood-never-held"];
  assert.ok(
    fl.plants.some((p) => p.cfg === "flood-broken-endstop.cfg" && p.rule === "FullWaterNeverHeld"),
  );
  assert.ok(
    fl.plants.some((p) => p.cfg === "flood-broken-endstop-hold.cfg" && p.rule === "HoldEnds"),
  );
  assert.ok(cfg("flood-today-longfill.cfg").properties.includes("HoldEnds"));
  assert.ok(fl.gaps.every((g) => !/PF-2/.test(g)));
});

function checkRow(id, { rules, files }) {
  const row = ROWS[id];
  for (const r of row.real) {
    const parsed = parseTlc(fixture(r.cfg.replace(".cfg", "")));
    assert.equal(parsed.outcome, "clean", r.cfg);
    assert.equal(parsed.distinct, r.minStates, r.cfg);
  }
  assert.deepEqual([...new Set(row.plants.map((p) => p.rule))].sort(), rules);
  const plants = row.plants.map((p) => ({
    ...p,
    rules: cfg(p.cfg),
    parsed: parseTlc(fixture(p.cfg.replace(".cfg", ""))),
  }));
  for (const p of plants)
    assert.equal(brokeRule(p.parsed, p.rules, p.rule), true, `${p.cfg} breaks ${p.rule}`);
  const real = row.real.map((r) => ({
    ...r,
    parsed: parseTlc(fixture(r.cfg.replace(".cfg", ""))),
  }));
  const held = buildReceipt({ head: HEAD, real, plants, drift: synced, gaps: row.gaps });
  assert.equal(held.pass, true);
  const broken = buildReceipt({
    head: HEAD,
    real: [{ ...real[0], parsed: plants[0].parsed }, ...real.slice(1)],
    plants,
    drift: synced,
    gaps: row.gaps,
  });
  assert.equal(broken.pass, false);
  const covered = coveredFiles(readFileSync(new URL(row.coverage, SKILL), "utf8"));
  for (const f of files) assert.ok(covered.includes(`sketches/core-loop/src/${f}`), f);
  return { row, held };
}

test("the yard lock row runs the full played game and the storeless flow now that P7 closed YL-1 and YL-2", () => {
  const { row, held } = checkRow("yard-lock-safe", {
    rules: [
      "LockAlwaysOpens",
      "NoLockInWardenFight",
      "OvertimeOnlyAfterWin",
      "StartCardOnce",
      "WallOnlyWhileLocked",
      "YardPaysOnce",
    ],
    files: [
      "world/stage_locks.gd",
      "world/overtime.gd",
      "world/lock_rows.gd",
      "core/flow.gd",
      "core/beacon.gd",
      "game.gd",
      "world/world.gd",
      "movement/player_ball.gd",
      "movement/rigid_ball.gd",
      "combat/weapons.gd",
    ],
  });
  assert.deepEqual(
    row.real.map((r) => r.cfg),
    ["yardlock-today.cfg", "yardlock-today-nostore.cfg"],
  );
  for (const r of row.real)
    assert.ok(cfg(r.cfg).properties.includes("LockAlwaysOpens"), `${r.cfg} checks LockAlwaysOpens`);
  assert.ok(cfg("yardlock-today-nostore.cfg").invariants.includes("NoLockInWardenFight"));
  assert.ok(row.plants.some((p) => p.cfg === "yardlock-broken-lockedyields.cfg"));
  assert.ok(row.plants.some((p) => p.cfg === "yardlock-broken-deadspends.cfg"));
  assert.ok(row.gaps.every((g) => !/YL-1|YL-2/.test(g)));
  assert.equal(parseTlc(fixture("yardlock-today-ranged")).outcome, "clean");
  assert.match(held.measured, /yardlock-today: no break in 146,341 distinct states/);
  assert.match(held.measured, /yardlock-broken-lockedyields broke NoLockInWardenFight/);
  assert.match(held.measured, /yardlock-broken-maxs broke LockAlwaysOpens/);
});

test("the earned save row runs the two-refusal and sustained-refusal tables now that P9 closed ES-2 and ES-3", () => {
  const { row, held } = checkRow("earned-save-safe", {
    rules: ["SaveOnce"],
    files: ["core/flow.gd", "core/run_state.gd", "core/run_store.gd", "core/safe_store.gd"],
  });
  assert.deepEqual(
    row.real.map((r) => r.cfg),
    [
      "earnedsave-today.cfg",
      "earnedsave-today-inprocess.cfg",
      "earnedsave-today-clearfail.cfg",
      "earnedsave-today-sustained.cfg",
    ],
  );
  assert.ok(row.plants.some((p) => p.cfg === "earnedsave-broken-spendowed.cfg"));
  assert.ok(row.plants.some((p) => p.cfg === "earnedsave-broken-clearflush.cfg"));
  assert.ok(row.plants.some((p) => p.cfg === "earnedsave-broken-newrunflush.cfg"));
  assert.ok(row.gaps.every((g) => !/ES-2|ES-3/.test(g)));
  assert.ok(row.gaps.some((g) => /crash/.test(g)) && row.gaps.some((g) => /allfail/.test(g)));
  assert.match(
    fixture("earnedsave-broken-clearflush"),
    /last = "ClearRefused"[\s\S]*last = "Quit"/,
  );
  assert.match(fixture("earnedsave-broken-newrunflush"), /last = "NewRunOwed"/);
  assert.doesNotMatch(fixture("earnedsave-broken-newrunflush"), /last = "Quit"/);
  assert.match(held.measured, /earnedsave-today: no break in 3,014 distinct states/);
  assert.match(held.measured, /earnedsave-today-inprocess: no break in 3,361 distinct states/);
  assert.match(held.measured, /earnedsave-today-clearfail: no break in 6,407 distinct states/);
  assert.match(held.measured, /earnedsave-today-sustained: no break in 11,102 distinct states/);
  assert.match(held.measured, /earnedsave-broken-clearflush broke SaveOnce/);
  assert.match(held.measured, /earnedsave-broken-newrunflush broke SaveOnce/);
});

test("the deferred effects row holds on the code and every plant breaks its rule", () => {
  const { row, held } = checkRow("deferred-effects-safe", {
    rules: ["NoEchoAcrossAttempt", "ProcDepthOne", "ShotBitsCap"],
    files: [
      "combat/combat.gd",
      "combat/bolts.gd",
      "combat/effects.gd",
      "core/flow.gd",
      "build/shot_bits.gd",
    ],
  });
  assert.equal(row.plants.length, 24);
  assert.match(held.measured, /deferred-today: no break in 9,955,877 distinct states/);
  assert.match(held.measured, /deferred-broken-ungated broke NoEchoAcrossAttempt/);
  assert.match(held.measured, /deferred-broken-nestproc broke ProcDepthOne/);
});

test("the sound arbiter row's pin and plants match captured TLC output, and its page covers the code it models", () => {
  const sa = ROWS["sound-arbiter-safe"];
  for (const r of sa.real) {
    const parsed = parseTlc(fixture(r.cfg.replace(".cfg", "")));
    assert.equal(parsed.outcome, "clean", r.cfg);
    assert.equal(parsed.distinct, r.minStates, r.cfg);
  }
  assert.deepEqual(sa.plants.map((p) => p.rule).sort(), [
    "BossMusicInArena",
    "DeathClearsUltFlight",
    "DeckObeysArbiter",
    "NoStaleShot",
    "NoStaleTrim",
    "OneMelodyNoClash",
    "UltimateRestoresChampion",
    "WardenOwnsFightMusic",
  ]);
  for (const p of sa.plants)
    assert.equal(
      brokeRule(parseTlc(fixture(p.cfg.replace(".cfg", ""))), cfg(p.cfg), p.rule),
      true,
      `${p.cfg} breaks ${p.rule}`,
    );
  const covered = coveredFiles(readFileSync(new URL(sa.coverage, SKILL), "utf8"));
  for (const f of [
    "presentation/music_arbiter.gd",
    "presentation/melody_lease.gd",
    "presentation/deck_moves.gd",
    "presentation/audio.gd",
    "presentation/ace_sequencer.gd",
  ])
    assert.ok(covered.includes(`sketches/core-loop/src/${f}`), f);
});

test("the weapon cadence row covers all six pilots, pins 12,415 states, and wires all 16 plants", () => {
  const wc = ROWS["weapon-cadence-safe"];
  assert.deepEqual(
    wc.real.map((r) => [r.cfg, r.minStates]),
    [["weaponcadence-today.cfg", 12415]],
  );
  assert.equal(wc.plants.length, 16);
  assert.deepEqual([...new Set(wc.plants.map((p) => p.rule))].sort(), [
    "BoundedReadyAfterInterrupt",
    "NoShotOutsidePlay",
    "OneVolleyPerPress",
    "RefundNeverExceedsSpend",
    "RestAfterBoundary",
    "WindowPaysAtMostOnce",
  ]);
  for (const name of [
    "weaponcadence-broken-double-snap.cfg",
    "weaponcadence-broken-detline-double.cfg",
    "weaponcadence-broken-snap-hold-lock.cfg",
    "weaponcadence-broken-beats-hold-repeat.cfg",
    "weaponcadence-broken-beats-skip.cfg",
    "weaponcadence-broken-lock-stuck.cfg",
  ])
    assert.ok(
      wc.plants.some((p) => p.cfg === name),
      name,
    );
  assert.ok(wc.gaps.every((g) => !/phase E2 modes/.test(g)));
  const covered = coveredFiles(readFileSync(new URL(wc.coverage, SKILL), "utf8"));
  assert.deepEqual(covered, [
    "sketches/core-loop/src/combat/combat.gd",
    "sketches/core-loop/src/combat/weapon_driver.gd",
  ]);
});

test("findJar resolves XDG_DATA_HOME/tlc/tla2tools-1.7.4.jar instead of retired astack path", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-tlc-"));
  const prevXdg = process.env.XDG_DATA_HOME;
  const prevTla = process.env.TLA2TOOLS;
  try {
    delete process.env.TLA2TOOLS;
    process.env.XDG_DATA_HOME = tmp;
    const expected = path.join(tmp, "tlc/tla2tools-1.7.4.jar");
    mkdirSync(path.dirname(expected), { recursive: true });
    writeFileSync(expected, "");
    assert.equal(findJar(), expected);
    const retired = path.join(tmp, "astack/tlc/tla2tools-1.7.4.jar");
    rmSync(expected);
    mkdirSync(path.dirname(retired), { recursive: true });
    writeFileSync(retired, "");
    assert.equal(findJar(), null);
  } finally {
    if (prevXdg === undefined) delete process.env.XDG_DATA_HOME;
    else process.env.XDG_DATA_HOME = prevXdg;
    if (prevTla === undefined) delete process.env.TLA2TOOLS;
    else process.env.TLA2TOOLS = prevTla;
    rmSync(tmp, { recursive: true, force: true });
  }
});

function plantCompletenessGaps(modelsDir, rows) {
  const disk = new Set(
    readdirSync(modelsDir).filter((name) => name.includes("-broken-") && name.endsWith(".cfg")),
  );
  const registered = new Set(
    Object.values(rows)
      .flatMap((r) => r.plants.map((p) => p.cfg))
      .filter((name) => name.includes("-broken-")),
  );
  return {
    unregistered: [...disk].filter((name) => !registered.has(name)).sort(),
    missingOnDisk: [...registered].filter((name) => !disk.has(name)).sort(),
  };
}

test("every *-broken-*.cfg plant on disk matches ROWS.plants (zero unregistered, zero missing)", () => {
  const modelsDir = fileURLToPath(new URL("models/", SKILL));
  const live = plantCompletenessGaps(modelsDir, ROWS);
  assert.deepEqual(
    live.unregistered,
    [],
    `unregistered broken plant cfgs missing from scripts/gate/model-receipts.mjs: ${live.unregistered.join(", ")}`,
  );
  assert.deepEqual(
    live.missingOnDisk,
    [],
    `scripts/gate/model-receipts.mjs references missing broken cfgs: ${live.missingOnDisk.join(", ")}`,
  );

  // Proof the completeness check fails on the real past omission (deferred-broken-nestproc.cfg).
  const omitted = structuredClone(ROWS);
  omitted["deferred-effects-safe"].plants = omitted["deferred-effects-safe"].plants.filter(
    (p) => p.cfg !== "deferred-broken-nestproc.cfg",
  );
  assert.deepEqual(plantCompletenessGaps(modelsDir, omitted).unregistered, [
    "deferred-broken-nestproc.cfg",
  ]);
});

const SPEC_GENERATORS = {
  "DeferredEffects.tla": "make-deferred-configs.sh",
  "RunFlow.tla": "make-configs.sh",
  "ParkFlood.tla": "make-flood-configs.sh",
  "HazardCycle.tla": "make-hazard-configs.sh",
  "SoundArbiter.tla": "make-sound-configs.sh",
};

test("every .tla spec has an executable make-*-configs.sh generator", () => {
  const modelsDir = fileURLToPath(new URL("models/", SKILL));
  const specs = readdirSync(modelsDir)
    .filter((name) => name.endsWith(".tla"))
    .sort();
  assert.ok(specs.length >= 11, specs.join(", "));
  for (const spec of specs) {
    const stem = spec.slice(0, -4).toLowerCase();
    const generator = SPEC_GENERATORS[spec] ?? `make-${stem}-configs.sh`;
    const full = path.join(modelsDir, generator);
    const mode = statSync(full).mode;
    assert.ok((mode & 0o111) !== 0, `${generator} must exist and be executable for ${spec}`);
  }
});
