import assert from "node:assert/strict";
import test from "node:test";
import { flumeOpening } from "./flume-opening.mjs";
import { fightMaxHp, worstWindows } from "./worst-window.mjs";

// Two runs of one column: run A carries the new worst_60s_max_hp field; run B is an older record without it.
const rows = [
  {
    column: "head",
    row: {
      max_hp: 200,
      stages: [
        { stage: 1, warden_engaged_s: 30, max_hp: 120, worst_60s_hull: 60, worst_60s_hp: 72, worst_60s_max_hp: 150 },
        { stage: 2, warden_engaged_s: 80, max_hp: 160, worst_60s_hull: 40, worst_60s_hp: 40,
          first_hit_s: 12, hp_lost: 90, hp_lost_45s: 30, hits: 9 },
      ],
      boss: { worst_60s_hull: 50, worst_60s_hp: 50, worst_60s_max_hp: 200 },
    },
  },
  {
    column: "head",
    row: {
      max_hp: 240,
      stages: [
        { stage: 1, warden_engaged_s: 40, max_hp: 120, worst_60s_hull: 30, worst_60s_hp: 30 },
        { stage: 2, warden_engaged_s: null, max_hp: 140, hp_lost: 20, exit_s: 300, hits: 2 },
      ],
      boss: { worst_60s_hull: 120, worst_60s_hp: 120 },
    },
  },
  { column: "head", row: null },
];

test("fightMaxHp prefers the window's max hull, then stage entry, then run end", () => {
  assert.deepEqual(fightMaxHp({ worst_60s_max_hp: 150, max_hp: 120 }, { max_hp: 200 }), { maxHp: 150, from: "window" });
  assert.deepEqual(fightMaxHp({ max_hp: 120 }, { max_hp: 200 }), { maxHp: 120, from: "entry" });
  assert.deepEqual(fightMaxHp({}, { max_hp: 200 }), { maxHp: 200, from: "run_end" });
  assert.deepEqual(fightMaxHp({}, {}), { maxHp: 120, from: "run_end" });
});

test("worstWindows divides each fight by the max hull at that fight, not at the end of the run", () => {
  const { head } = worstWindows(rows);
  assert.deepEqual(head.dam, [
    { hull: 60 / 150, hp: 72 / 150, from: "window" },
    { hull: 30 / 120, hp: 30 / 120, from: "entry" },
  ]);
  // Run B never engaged the flume Warden, so only run A's flume counts.
  assert.deepEqual(head.flume, [{ hull: 40 / 160, hp: 40 / 160, from: "entry" }]);
  assert.deepEqual(head.brindle, [
    { hull: 50 / 200, hp: 50 / 200, from: "window" },
    { hull: 120 / 240, hp: 120 / 240, from: "run_end" },
  ]);
});

test("flumeOpening subtracts only the fight's first 45 s and falls back to exit time with no hit", () => {
  const { head } = flumeOpening(rows);
  assert.equal(head.n, 2);
  assert.deepEqual(head.firstHit, [12, 300]);
  assert.equal(head.noHit, 1);
  assert.deepEqual(head.dmgOutside, [60, 20]);
  assert.deepEqual(head.maxHp, [160, 140]);
  assert.deepEqual(head.hits, [9, 2]);
});
