import assert from "node:assert/strict";
import test from "node:test";
import { census, passes, ride, sites } from "./poi-census.mjs";

const park = (activity_rows) => ({
  map: "park_test",
  spawn: { at: [0, 0] },
  landmark: { at: [0, 1000] },
  activity_rows,
  park_rows: [{ id: "bend", at: [0, 500] }],
});
const line = { pilots: { sable: { waypoints: ["drop_in", "bend", "landmark"] } } };

test("an empty map has one site, the Warden, and one long gap", () => {
  const r = ride(park([]), line.pilots.sable.waypoints);
  assert.equal(r.sites, 1);
  assert.equal(r.gap_s, 50);
  assert.equal(passes(census(park([]), line)), false);
});

test("a site counts within reach of the line and not past it", () => {
  const p = park([
    { id: "near", activity: "cracked_cache", at: [55, 300] },
    { id: "far", activity: "enemy_camp", at: [90, 600] },
  ]);
  assert.equal(sites(p).length, 3);
  const r = ride(p, line.pilots.sable.waypoints);
  assert.equal(r.sites, 2);
  assert.equal(r.kinds, 2);
  assert.equal(r.gap_s, 35);
});

test("a site every 150 m passes", () => {
  const rows = [150, 300, 450, 600, 750, 900].map((y, i) => ({ id: `s${i}`, activity: "cracked_cache", at: [20, y] }));
  assert.equal(passes(census(park(rows), line)), true);
});

test("a pilot line that names a missing row is an error", () => {
  assert.throws(() => ride(park([]), ["drop_in", "nowhere"]), /nowhere/);
});
