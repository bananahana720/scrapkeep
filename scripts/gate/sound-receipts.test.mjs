import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

import { MIN_CUES, buildReceipt as recipesReceipt } from "./sound-recipes-receipt.mjs";
import { PLANT_RATE, buildReceipt as levelsReceipt, measure, runPlants, tone } from "./sound-levels-receipt.mjs";
import { hasFfmpeg } from "../audio-gate.mjs";
import { receiptRow } from "../world1-bands.mjs";

const HEAD = "3adc2fd0e8563b13c87f921b2ae85763467fec03";
const ffmpeg = hasFfmpeg();

// --- sound-own-recipes ----------------------------------------------------------------------

const recipesRow = { id: "sound-own-recipes", plant: "a cue with its recipe removed must be counted", producer: "x" };
const cue = (name, own = true, how = own ? "recipe" : "fallback blip") => `CUE ${JSON.stringify({ cue: name, own, how, facts: 1, fact: `ROWS:${name}` })}`;
const recipesLog = ({ n = 40, standins = [], unjudged = [], plant = true, fail = 0, checks = 5 } = {}) => {
  const before = standins.length;
  return [
    ...Array.from({ length: checks }, (_, i) => `[check ${i}] detail -> ${i < fail ? "FAIL" : "PASS"}`),
    ...Array.from({ length: n }, (_, i) => cue(`cue_${i}`)),
    ...standins.map((c) => cue(c, false)),
    ...unjudged.map((c) => cue(c, true, "unjudged: resolves from the event's own context")),
    ...(plant ? [`PLANT ${JSON.stringify({ fact: "ROWS:cue_0", cue: "plant_recipe_removed", before, after: before + 1, caught: true })}`] : []),
  ].join("\n");
};

test("recipes: every world 1 cue has its own recipe and the plant was counted, so the done table passes it", () => {
  const r = recipesReceipt(recipesLog(), HEAD);
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /^0 of 40 world 1 cues play a stand-in; plant: ROWS:cue_0's cue removed read 0 -> 1/);
  assert.deepEqual(receiptRow(recipesRow, r, HEAD), { measured: r.measured, pass: true });
});

test("recipes: a cue on the fallback blip fails the receipt and is named", () => {
  const r = recipesReceipt(recipesLog({ standins: ["drop_thud", "guard_creak"] }), HEAD);
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /^2 of 42 world 1 cues play a stand-in: drop_thud \(fallback blip\), guard_creak \(fallback blip\)/);
});

test("recipes: no PLANT line, or a plant that did not raise the count by one, voids the receipt", () => {
  const none = recipesReceipt(recipesLog({ plant: false }), HEAD);
  assert.equal(none.plant_caught, false);
  assert.match(receiptRow(recipesRow, none, HEAD).measured, /^void, the planted fault was not shown caught/);
  const flat = recipesLog().replace(/"after":1/, '"after":0');
  assert.equal(recipesReceipt(flat, HEAD).plant_caught, false);
});

test("recipes: unjudged cues are named but do not fail; a short count, a failed check and an empty log fail", () => {
  const u = recipesReceipt(recipesLog({ unjudged: ["hold_by_kind"] }), HEAD);
  assert.equal(u.pass, true);
  assert.match(u.measured, /1 resolve from the event's own context and are not judged \(hold_by_kind\)/);
  assert.match(recipesReceipt(recipesLog({ n: MIN_CUES - 5 }), HEAD).measured, /derivation broke/);
  assert.equal(recipesReceipt(recipesLog({ fail: 1 }), HEAD).pass, false);
  assert.equal(recipesReceipt(recipesLog({ checks: 2 }), HEAD).pass, false);
  assert.equal(recipesReceipt("", HEAD).pass, false);
  assert.match(recipesReceipt("", HEAD).measured, /^no CUE lines/);
});

// --- sound-levels ---------------------------------------------------------------------------

const levelsRow = { id: "sound-levels", plant: "a stem 6 LU too loud must fail", producer: "x" };
const caught = { caught: true, what: "plants caught" };
const row = (name, lufs = -16, truePeak = -2, seam = true) => ({ name, seconds: 60, lufs, truePeak, ...(seam ? { seamWrap: 0.001, seamP999: 0.01 } : {}) });

test("levels: no stems on this machine is no data, never a pass", () => {
  const r = levelsReceipt({ head: HEAD, clips: 256, present: 0, plant: caught });
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /^no data: 0 of 256 music clips have their stems on this machine/);
  assert.equal(levelsReceipt({ head: HEAD, clips: 3, present: 3, ffmpeg: false, plant: null }).measured.startsWith("no data: ffmpeg not found"), true);
  assert.match(levelsReceipt({ head: HEAD, clips: 0, present: 0, plant: caught }).measured, /^no data: no assets\/music_ace manifest/);
});

test("levels: every clip measured inside the limits, plant caught: passes in the done table", () => {
  const r = levelsReceipt({ head: HEAD, clips: 2, present: 2, rows: [row("a/x"), row("b/y", -15.8, -1.4)], found: [], plant: caught });
  assert.equal(r.pass, true);
  assert.match(r.measured, /^2 of 2 music clips measured: -16 to -15.8 LUFS, true peak at most -1.4 dBTP, 2 loop seams; all inside the limits/);
  assert.deepEqual(receiptRow(levelsRow, r, HEAD), { measured: r.measured, pass: true });
});

test("levels: a finding, a missing clip or an uncaught plant does not pass", () => {
  const loud = levelsReceipt({ head: HEAD, clips: 1, present: 1, rows: [row("a/x", -10)], found: [{ kind: "loudness", where: "a/x", what: "-10 LUFS" }], plant: caught });
  assert.equal(loud.pass, false);
  assert.match(loud.measured, /1 over the limits .*loudness a\/x -10 LUFS/);
  const partial = levelsReceipt({ head: HEAD, clips: 2, present: 1, rows: [row("a/x")], found: [], plant: caught });
  assert.equal(partial.pass, false);
  assert.match(partial.measured, /1 clip\(s\) not measured/);
  const blind = levelsReceipt({ head: HEAD, clips: 1, present: 1, rows: [row("a/x")], found: [], plant: { caught: false, what: "plants not caught: loudness" } });
  assert.equal(blind.plant_caught, false);
  assert.match(receiptRow(levelsRow, blind, HEAD).measured, /^void/);
});

test("levels: the plants run through audio-gate's own judge, and a judge that sees nothing is not caught", { skip: !ffmpeg && "ffmpeg not installed" }, () => {
  const real = runPlants();
  assert.equal(real.caught, true, real.what);
  const blind = runPlants({ judgeFn: (name) => ({ row: { name }, found: [] }) });
  assert.equal(blind.caught, false);
  assert.match(blind.what, /loudness, peak, seam/);
});

// A WAV of a float stereo buffer, 16-bit, so ffmpeg reads it as a stem.
function wav(file, samples, rate) {
  const data = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i++) data.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767))), i * 2);
  const head = Buffer.alloc(44);
  head.write("RIFF", 0); head.writeUInt32LE(36 + data.length, 4); head.write("WAVEfmt ", 8);
  head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20); head.writeUInt16LE(2, 22); head.writeUInt32LE(rate, 24);
  head.writeUInt32LE(rate * 4, 28); head.writeUInt16LE(4, 32); head.writeUInt16LE(16, 34); head.write("data", 36); head.writeUInt32LE(data.length, 40);
  writeFileSync(file, Buffer.concat([head, data]));
}

test("levels: a fixture pack measured end to end; a stem 6 LU too loud fails it", { skip: !ffmpeg && "ffmpeg not installed" }, () => {
  const project = mkdtempSync(path.join(os.tmpdir(), "sound-levels-"));
  const pack = path.join(project, "assets/music_ace/fixture");
  mkdirSync(pack, { recursive: true });
  // amp 0.25 cosine at 240 Hz meters near -12.9 LUFS; level_db brings the mix to the target.
  const stem = tone(12, PLANT_RATE, 240, 0.25);
  wav(path.join(pack, "a.wav"), stem, PLANT_RATE);
  const manifest = (level) => ({ theme: "fixture", level_db: level, clips: { main: { rate: PLANT_RATE, files: { full: "a.wav" }, loop: true } } });
  writeFileSync(path.join(pack, "manifest.json"), JSON.stringify(manifest(-3.1)));
  const ok = measure(project);
  assert.match(ok.measured, /^1 of 1 music clips measured/);
  assert.equal(ok.pass, true, ok.measured);
  writeFileSync(path.join(pack, "manifest.json"), JSON.stringify(manifest(-3.1 + 6)));
  const loud = measure(project);
  assert.equal(loud.pass, false);
  assert.match(loud.measured, /loudness fixture\/main/);
});
