#!/usr/bin/env node
// Turns the output of sketches/core-loop/tests/sound_own_recipes_test.gd into the receipt that
// scripts/world1-bands.mjs reads for the row "sound-own-recipes":
//   { head, pass, measured, plant_caught }
// The test takes the world 1 sound facts from sound_twins_test.gd's derivation, prints one CUE line per
// cue those facts name (a row's sound_next first, since Rows.heard plays the row's `sound` in its place
// while the bank has no recipe for it) with whether it has a recipe of its own, then a PLANT line: the
// same count with one world 1 fact's cue swapped for an id with no recipe. The receipt passes only when
// no check failed, every check line is there, enough cues were counted, no cue is on a stand-in, and the
// plant was counted.
//
//   node scripts/gate/sound-recipes-receipt.mjs --log <test output> --head <commit> [--out <file>]
//
// Produce the log with (Godot's HOME is a scratch folder under the runner):
//   SMOKE_LOG_DIR=<dir> node scripts/sketch-smoke.mjs --sketch core-loop --test sound_own_recipes_test
//   (the log is <dir>/sound_own_recipes_test.log)
import { readFileSync, realpathSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

// The test prints four check lines; fewer means it stopped early.
export const MIN_CHECKS = 4;
// The audit of 13 Nov named about 110 world 1 sounds; fewer than this many cues means the derivation broke.
export const MIN_CUES = 30;

const jsonLines = (text, tag) => text.split("\n").filter((l) => l.startsWith(`${tag} {`)).map((line) => {
  try { return JSON.parse(line.slice(tag.length + 1)); } catch { return null; }
}).filter(Boolean);

export function buildReceipt(text, head) {
  const lines = text.split("\n");
  const failed = lines.filter((l) => l.endsWith("-> FAIL"));
  const checks = failed.length + lines.filter((l) => l.endsWith("-> PASS")).length;
  const cues = jsonLines(text, "CUE");
  const plant = jsonLines(text, "PLANT")[0] ?? null;
  const standins = cues.filter((c) => c.own !== true);
  const unjudged = cues.filter((c) => c.own === true && String(c.how).startsWith("unjudged"));
  // The plant is caught when the swapped cue was counted as one more stand-in than the real run found.
  const caught = Boolean(plant && plant.caught === true && plant.fact && plant.before === standins.length && plant.after === standins.length + 1);
  const pass = failed.length === 0 && checks >= MIN_CHECKS && cues.length >= MIN_CUES && standins.length === 0 && caught;
  const tail = unjudged.length ? `; ${unjudged.length} resolve from the event's own context and are not judged (${unjudged.map((c) => c.cue).join(", ")})` : "";
  let measured;
  if (cues.length === 0) measured = "no CUE lines: the test did not finish";
  else if (cues.length < MIN_CUES) measured = `only ${cues.length} world 1 cues counted, the derivation broke`;
  else if (checks < MIN_CHECKS) measured = `only ${checks} check lines, the test stopped early`;
  else if (standins.length) measured = `${standins.length} of ${cues.length} world 1 cues play a stand-in: ${standins.map((c) => `${c.cue} (${c.how})`).join(", ")}${tail}`;
  else if (failed.length) measured = `${failed.length} check(s) failed: ${failed[0].slice(0, 120)}`;
  else measured = `0 of ${cues.length} world 1 cues play a stand-in${tail}`;
  if (cues.length && plant) measured += `; plant: ${plant.fact}'s cue removed read ${plant.before} -> ${plant.after}`;
  return { head, pass, measured, plant_caught: caught };
}

function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) args[argv[i].replace(/^--/, "")] = argv[i + 1];
  if (!args.log || !args.head) {
    console.error("usage: sound-recipes-receipt.mjs --log <test output> --head <commit> [--out <file>]");
    return 2;
  }
  const receipt = buildReceipt(readFileSync(args.log, "utf8"), args.head);
  const text = JSON.stringify(receipt, null, 2) + "\n";
  if (args.out) writeFileSync(args.out, text);
  else process.stdout.write(text);
  return receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main(process.argv.slice(2)));
