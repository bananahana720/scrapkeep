import assert from "node:assert/strict";
import { test } from "node:test";

import { LOOPS, buildReceipt } from "./sitting-played-receipt.mjs";
import { receiptRow } from "../world1-bands.mjs";

const HEAD = "3adc2fd0e8563b13c87f921b2ae85763467fec03";
const allOn = Object.fromEntries(LOOPS.map((l) => [l, true]));
const checks = (n, fail = 0) => Array.from({ length: n }, (_, i) => `[check ${i}] detail -> ${i < fail ? "FAIL" : "PASS"}`);
const log = ({ fired = allOn, control = { off: "heat", fired: { ...allOn, heat: false } }, n = 25, fail = 0, run = true } = {}) => [
  ...checks(n, fail),
  ...(run ? [`RECEIPT ${JSON.stringify({ seconds: 300, loops: {}, fired })}`] : []),
  ...(control ? [`CONTROL ${JSON.stringify({ seconds: 290, ...control })}`] : []),
].join("\n");
const row = { id: "sitting-launch-played", plant: "one loop switched off must read as a miss", producer: "x" };

test("six loops fired and the control caught: a passing receipt that the done table accepts", () => {
  const r = buildReceipt(log(), HEAD);
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /^6 of 6 loops fired/);
  assert.deepEqual(receiptRow(row, r, HEAD), { measured: r.measured, pass: true });
});

test("a loop that never fired fails the receipt and names it", () => {
  const r = buildReceipt(log({ fired: { ...allOn, carry_core: false, moss_scale: false }, control: { off: "heat", fired: { ...allOn, heat: false, carry_core: false, moss_scale: false } } }), HEAD);
  assert.equal(r.pass, false);
  assert.match(r.measured, /4 of 6 loops fired; not fired: moss_scale, carry_core/);
  assert.equal(receiptRow(row, r, HEAD).pass, false);
});

test("a control that still shows the loop fired means the plant was not caught, so the done table voids the receipt", () => {
  const r = buildReceipt(log({ control: { off: "heat", fired: allOn } }), HEAD);
  assert.equal(r.plant_caught, false);
  assert.equal(r.pass, false);
  assert.match(receiptRow(row, r, HEAD).measured, /^void, the planted fault was not shown caught/);
});

test("a control that also changed a second loop is not a clean catch", () => {
  const r = buildReceipt(log({ control: { off: "heat", fired: { ...allOn, heat: false, overtime: false } } }), HEAD);
  assert.equal(r.plant_caught, false);
});

test("a failed check, a missing run line and a stopped-early test each fail", () => {
  assert.equal(buildReceipt(log({ fail: 1 }), HEAD).pass, false);
  assert.match(buildReceipt(log({ run: false }), HEAD).measured, /^no RECEIPT line/);
  const early = buildReceipt(log({ n: 3 }), HEAD);
  assert.equal(early.pass, false);
  assert.match(early.measured, /only 3 check lines/);
  assert.equal(buildReceipt("", HEAD).pass, false);
});

test("a receipt for another head is stale", () => {
  const r = buildReceipt(log(), HEAD);
  assert.equal(receiptRow(row, r, "ffffffffffffffffffff").noData, true);
});
