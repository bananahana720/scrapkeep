import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

import { MAPS, OPEN_HALVES, PINNED_LINES, POINTS, TESTS, buildReceipt as judge, mapLines, produce } from "./map-standard-receipt.mjs";

// The receipt with no open halves, so each test judges the lines alone; the open halves have a test of their own.
const buildReceipt = (logs, head) => judge(logs, head, { halves: [] });
import { receiptRow } from "../world1-bands.mjs";

const HEAD = "3adc2fd0e8563b13c87f921b2ae85763467fec03";
const row = { id: "map-standard", plant: "every map test's planted fault must fail its line", producer: "x" };

// A full set of logs: every point checked on both maps, padded with extra point 10 lines up to the pin.
function logs({ status = {}, value = {}, drop = [], plantPass = null, failCheck = null, extra = 0 } = {}) {
  const out = {};
  const tests = Object.keys(TESTS);
  for (const t of tests) out[t] = [`[${t} a check] ok -> PASS`];
  let n = 0;
  const add = (t, map, measure) => {
    if (drop.includes(`${map} ${measure}`)) return;
    out[t].push(`MAPCHECK ${map} ${measure} ${value[`${map} ${measure}`] ?? "1.00"} pass>=0.50 ${status[`${map} ${measure}`] ?? "PASS"}`);
    n += 1;
  };
  Object.values(POINTS).forEach((measures, i) => MAPS.forEach((m) => add(tests[i % tests.length], m, measures[0])));
  while (n < PINNED_LINES + extra) add("site_markers_test", MAPS[n % 2], "marker_sight");
  for (const t of tests) {
    out[t].push(`MAPCHECK park_dam report INFO detail`);
    for (let i = 0; i < TESTS[t]; i += 1) out[t].push(`PLANTED ${t}_${i} x 0.00 pass>=0.50 ${plantPass === t ? "PASS" : "FAIL"}`);
    if (failCheck === t) out[t].push(`[${t} broke] x -> FAIL`, `${t}: FAIL (1 of 2 checks)`);
    else out[t].push(`${t}: PASS (2 checks)`);
  }
  for (const t of tests) out[t] = out[t].join("\n");
  return out;
}

test("map standard: every point checked on both maps, every line passing and every plant caught passes", () => {
  const r = buildReceipt(logs(), HEAD);
  assert.equal(r.pass, true, r.measured);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, new RegExp(`^${PINNED_LINES} MAPCHECK lines \\(pinned ${PINNED_LINES}\\); lines per point dam/flume 1:1/1 `));
  assert.deepEqual(receiptRow(row, r, HEAD), { measured: r.measured, pass: true });
});

test("map standard: an OWED line not ruled to wait is a miss, one on WAITING is held with its citation", () => {
  const owed = buildReceipt(logs({ status: { "park_flume height_bands_populated": "OWED" } }), HEAD);
  assert.equal(owed.pass, false);
  assert.match(owed.measured, /misses: park_flume height_bands_populated 1.00 pass>=0.50 OWED/);
  const yard = "park_flume yard_rim_median_m";
  const parked = buildReceipt(logs({ status: { [yard]: "OWED" }, value: { [yard]: "-0.41" } }), HEAD);
  assert.equal(parked.pass, true, parked.measured);
  assert.match(parked.measured, /waiting: park_flume yard_rim_median_m -0.41 pass>=0.50 \(project-guide\/handoff\/ROADMAP.md:27/);
  // The wait is pinned to its value and status: a worse bowl, or a FAIL in place of OWED, is a miss.
  assert.match(buildReceipt(logs({ status: { [yard]: "OWED" }, value: { [yard]: "-0.90" } }), HEAD).measured, /misses: park_flume yard_rim_median_m -0.90/);
  assert.equal(buildReceipt(logs({ status: { [yard]: "FAIL" }, value: { [yard]: "-0.41" } }), HEAD).pass, false);
  assert.equal(buildReceipt(logs({ status: { "park_dam yard_rim_median_m": "OWED" } }), HEAD).pass, false);
});

test("map standard: a point with no line on one map fails and is named", () => {
  const r = buildReceipt(logs({ drop: ["park_dam layout_sets"], extra: 1 }), HEAD);
  assert.equal(r.pass, false);
  assert.match(r.measured, /no check for point 4 on park_dam/);
});

test("map standard: a lost or added check moves the count off the pin and fails", () => {
  const more = buildReceipt(logs({ extra: 1 }), HEAD);
  assert.equal(more.pass, false);
  assert.match(more.measured, /off the pin/);
});

test("map standard: a plant that passed, or a missing PLANTED line, voids the receipt", () => {
  const r = buildReceipt(logs({ plantPass: "park_breath_test" }), HEAD);
  assert.equal(r.plant_caught, false);
  assert.equal(r.pass, false);
  assert.match(receiptRow(row, r, HEAD).measured, /^void, the planted fault was not shown caught/);
  const gone = logs();
  gone.park_variety_test = gone.park_variety_test.split("\n").filter((l) => !l.startsWith("PLANTED")).join("\n");
  assert.equal(buildReceipt(gone, HEAD).plant_caught, false);
});

test("map standard: a failed check, an unmapped measure and an empty run fail", () => {
  assert.equal(buildReceipt(logs({ failCheck: "park_rhythm_test" }), HEAD).pass, false);
  const odd = logs();
  odd.park_breath_test += "\nMAPCHECK park_dam brand_new_measure 1 pass>=1 PASS";
  assert.match(buildReceipt(odd, HEAD).measured, /unmapped measure park_dam brand_new_measure/);
  const empty = buildReceipt({}, HEAD);
  assert.equal(empty.pass, false);
  assert.match(empty.measured, /^no MAPCHECK lines/);
});

test("map standard: MAPCHECK parsing reads marker lines and skips report INFO", () => {
  const got = mapLines("MAPCHECK park_dam marker_sight cage 0.9100 pass>=0.85 PASS (120 cells)\nMAPCHECK park_dam band_shares 0.1/0.2 report INFO\nMAPCHECK park_flume rhythm_switches 9.0 pass>=3 PASS");
  assert.equal(got.length, 2);
  assert.deepEqual([got[0].measure, got[0].value, got[0].line, got[0].status], ["marker_sight", "0.9100", "pass>=0.85", "PASS"]);
});

test("map standard: the producer refuses a dirty checkout and never runs the tests there", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "map-standard-git-"));
  const git = (...args) => spawnSync("git", args, { cwd: dir, encoding: "utf8" });
  git("init", "-q");
  git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "base");
  writeFileSync(path.join(dir, "tracked.txt"), "a");
  git("add", "tracked.txt");
  git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "-m", "file");
  writeFileSync(path.join(dir, "tracked.txt"), "b");
  let ran = false;
  assert.throws(() => produce({ cwd: dir, run: () => { ran = true; return logs(); } }), /refusing: uncommitted changes/);
  assert.equal(ran, false);
  git("checkout", "-q", "tracked.txt");
  const r = produce({ cwd: dir, run: () => logs() });
  assert.equal(r.head, git("rev-parse", "HEAD").stdout.trim());
  assert.equal(r.pass, false, "the open halves keep a clean run from passing");
  assert.match(r.measured, /open halves/);
});

test("map standard: an open half no ruling parks is a miss and measured names it with what closes it", () => {
  const r = judge(logs(), HEAD);
  assert.equal(r.pass, false);
  for (const h of OPEN_HALVES) assert.ok(r.measured.includes(`${h.half} (closes with ${h.closes})`), h.half);
  const parked = judge(logs(), HEAD, { halves: [{ ...OPEN_HALVES[0], parked: "a ruling" }] });
  assert.equal(parked.pass, true, parked.measured);
});
