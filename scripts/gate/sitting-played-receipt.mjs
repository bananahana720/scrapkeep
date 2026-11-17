#!/usr/bin/env node
// Turns the output of sketches/core-loop/tests/sitting_played_run_test.gd into the receipt that
// scripts/world1-bands.mjs reads for the row "sitting-launch-played":
//   { head, pass, measured, plant_caught }
// The test plays the sitting launch (--profile=sitting-earned) with the self-play bot to the win at
// Brindle, prints a RECEIPT line (which of the six loops fired) and then plays the same run twice more, each with
// one loop switched off, and prints a CONTROL line for each. The receipt passes only when no check failed, every
// check line is there, all six loops fired, and each control run read its loop as not fired while the
// full run read it as fired, for two different loops. plant_caught is the last part: a run that cannot show a loop missing
// decides nothing.
//
//   node scripts/gate/sitting-played-receipt.mjs --log <test output> --head <commit> [--out <file>]
//
// Produce the log with:
//   Godot --headless --path sketches/core-loop --script res://tests/sitting_played_run_test.gd > <log>
import { readFileSync, realpathSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

export const LOOPS = ["heat", "overtime", "called_shot", "marked_hull", "moss_scale", "carry_core"];
// Fewer check lines than this means the test stopped early; the test prints well over this many.
export const MIN_CHECKS = 20;

const jsonLines = (text, tag) => text.split("\n").filter((l) => l.startsWith(`${tag} {`)).map((line) => {
  try { return JSON.parse(line.slice(tag.length + 1)); } catch { return null; }
});
const jsonAfter = (text, tag) => jsonLines(text, tag)[0] ?? null;
// The planted controls: each switches one loop off in its own run, and two different loops are needed.
export const MIN_CONTROLS = 2;

export function buildReceipt(text, head) {
  const lines = text.split("\n");
  const failed = lines.filter((l) => l.endsWith("-> FAIL"));
  const passed = lines.filter((l) => l.endsWith("-> PASS"));
  const run = jsonAfter(text, "RECEIPT");
  const controls = jsonLines(text, "CONTROL");
  const fired = run?.fired ?? {};
  const missing = LOOPS.filter((l) => fired[l] !== true);
  const offs = controls.map((c) => c?.off);
  const caughtOne = (control) => Boolean(run && control && LOOPS.includes(control.off) && fired[control.off] === true && control.fired?.[control.off] === false
    && LOOPS.filter((l) => l !== control.off).every((l) => control.fired?.[l] === fired[l]));
  const caught = controls.length >= MIN_CONTROLS && new Set(offs).size === controls.length && controls.every(caughtOne);
  const checks = passed.length + failed.length;
  const pass = Boolean(run) && failed.length === 0 && checks >= MIN_CHECKS && missing.length === 0 && caught;
  let measured;
  if (!run) measured = "no RECEIPT line: the played run did not finish";
  else if (failed.length) measured = `${failed.length} check(s) failed: ${failed[0].slice(0, 120)}`;
  else if (checks < MIN_CHECKS) measured = `only ${checks} check lines, the test stopped early`;
  else if (missing.length) measured = `${LOOPS.length - missing.length} of ${LOOPS.length} loops fired; not fired: ${missing.join(", ")} (${run.seconds} s)`;
  else measured = `${LOOPS.length} of ${LOOPS.length} loops fired in a played run to Brindle (${run.seconds} s); with ${offs.join(" off, and with ")} off each read as not fired`;
  return { head, pass, measured, plant_caught: caught };
}

function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) args[argv[i].replace(/^--/, "")] = argv[i + 1];
  if (!args.log || !args.head) {
    console.error("usage: sitting-played-receipt.mjs --log <test output> --head <commit> [--out <file>]");
    return 2;
  }
  const receipt = buildReceipt(readFileSync(args.log, "utf8"), args.head);
  const text = JSON.stringify(receipt, null, 2) + "\n";
  if (args.out) writeFileSync(args.out, text);
  else process.stdout.write(text);
  return receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main(process.argv.slice(2)));
