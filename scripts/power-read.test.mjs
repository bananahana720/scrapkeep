import assert from "node:assert/strict";
import test from "node:test";
import { PowerReadError, TARGETS, command, netArea, parseArgs, parseRow, renderPage, summarize } from "./power-read.mjs";

const row = (pilot, depth, over = {}) => ({
  pilot, depth, rendered: true, area_peak: 0.2, noise_peak: 0.05, knock_m: 8, sound_layers: 3,
  sounds: ["core_slam", "womp", "hit_thwack"], heft: 1, parts: [], picks: [], damage: 20, fx_spawned: 7, ...over,
});

test("parseArgs reads pilots, jobs and render mode", () => {
  const args = parseArgs(["--pilots=tally,tarn", "--jobs=3", "--native", "--gate"]);
  assert.deepEqual(args.pilots, ["tally", "tarn"]);
  assert.equal(args.jobs, 3);
  assert.equal(args.render, "native");
  assert.equal(args.gate, true);
  assert.throws(() => parseArgs(["--pilots=nobody"]), PowerReadError);
  assert.throws(() => parseArgs(["--jobs=0"]), PowerReadError);
});

test("command renders under xvfb by default and headless without pixels", () => {
  const xvfb = command({ binary: "/g", pilot: "tally", depth: 4, out: "/o", render: "xvfb" });
  assert.equal(xvfb.cmd, "xvfb-run");
  assert.ok(xvfb.argv.includes("opengl3"));
  const none = command({ binary: "/g", pilot: "tally", depth: 4, out: "/o", render: "none" });
  assert.equal(none.cmd, "/g");
  assert.deepEqual(none.argv.slice(-5), ["--", "--pilot=tally", "--depth=4", "--out=/o", "--render=0"]);
  assert.ok(none.argv.includes("--headless"));
});

test("parseRow takes the tool's last row line", () => {
  assert.deepEqual(parseRow('noise\npower_read row: {"a":1}\nmore'), { a: 1 });
  assert.equal(parseRow("SCRIPT ERROR: x"), null);
});

test("summarize compares grown with first fight against the targets", () => {
  const rows = [
    row("tally", 0),
    row("tally", 4, { area_peak: 0.5, knock_m: 16, sound_layers: 4 }),
    row("tarn", 0),
    row("tarn", 4, { area_peak: 0.25, noise_peak: 0.1 }),
  ];
  const s = summarize(rows);
  const tally = s.pilots.find((p) => p.id === "tally");
  assert.equal(netArea(rows[0]), 0.15000000000000002);
  assert.ok(Math.abs(tally.ratios.area - 0.45 / 0.15) < 1e-9);
  assert.deepEqual(tally.meets, { area: true, knock: true, layers: false });
  const tarn = s.pilots.find((p) => p.id === "tarn");
  assert.equal(tarn.ratios.knock, 1);
  assert.deepEqual(tarn.meets, { area: false, knock: false, layers: false });
  assert.deepEqual(s.totals.area, { met: 1, measured: 2 });
  assert.deepEqual(s.targets, TARGETS);
});

test("an unrendered or failed run is not counted as a pass", () => {
  const s = summarize([
    row("tally", 0, { rendered: false }),
    row("tally", 4, { rendered: false, knock_m: 20 }),
    row("kest", 0),
    { pilot: "demolitions_caster", depth: 4, error: "no row" },
  ]);
  const tally = s.pilots.find((p) => p.id === "tally");
  assert.equal(tally.ratios.area, null);
  assert.equal(tally.meets.area, null);
  assert.deepEqual(s.totals.area, { met: 0, measured: 0 });
  assert.deepEqual(s.totals.knock, { met: 1, measured: 1 });
});

test("renderPage names every pilot and escapes text", () => {
  const s = summarize([row("tally", 0), row("tally", 4, { sounds: ["<b>"] })]);
  const html = renderPage(s, { stamp: "now", version: "abc" });
  assert.match(html, /<title>Power Read<\/title>/);
  assert.match(html, /Tally/);
  assert.match(html, /&lt;b&gt;/);
  assert.doesNotMatch(html, /<b>"/);
});
