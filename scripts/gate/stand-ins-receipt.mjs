#!/usr/bin/env node
// The receipt for the world 1 done read's row "no-code-stand-ins" (scripts/world1-bands.rows.json):
//   { head, pass, measured, plant_caught }
// It runs sketches/core-loop/tests/prim_census_test.gd twice, alone, through the project's runner (solo-run.mjs), on
// this checkout, and takes the head from cleanHead (clean-head.mjs). The test plays one skipper bot through the dam,
// the flume and Brindle, lists every surface drawn from a Godot primitive mesh, judges the list against
// tools/prim_census_pin.tsv, and ends with one line:
//   SUMMARY {"surfaces": n, "pinned": <least surfaces>, "stand_ins": [...], "new": [...], "stale": [...], "plant": ""}
//   1. as it ships: the receipt passes only when the test passed, the census counted at least the pinned number of
//      surfaces, ran with no plant, and found no new primitive, no stale stand-in row and no stand-in except one on
//      WAITING (an item ruled to wait, with the line that parks it). The pin marking a surface "stand-in" does not
//      excuse it: the row is "no code-built stand-in left in world 1", so each one left fails the receipt and is named
//      with its file and the BACKLOG row that owes its model.
//   2. with PRIM_PLANT=dam_box, a test-only switch: the box the test's control hangs on the first activity it finds
//      is judged as a real surface, a new code-built box the pin does not cover. The test must fail and name it.
//      A plant switch left in the caller's environment reaches run 1, which then names the plant and fails.
//
//   node scripts/gate/stand-ins-receipt.mjs --out <file>
import { realpathSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { cleanHead, root } from "./clean-head.mjs";
import { runAlone } from "./solo-run.mjs";

export const TEST = "prim_census_test";
export const PINNED_SURFACES = 129;
export const PLANT_ENV = { PRIM_PLANT: "dam_box" };
export const PLANT_NAME = "PlantedStandIn";
// Stand-ins ruled to wait, matched on file and BACKLOG row. Each names the line that parks it.
export const WAITING = [
  {
    file: "stakes.gd",
    row: "W1-23",
    why: "the trade spots' bodies land after the sitting",
    cite: "project-guide/handoff/DECISIONS.md:117 (ruling ci: \"The words land before the sitting, the bodies after it.\"); BACKLOG.md W1-23",
  },
];
export const NOT_SEEN = "what is not judged: one seed, one pilot and one table, so a surface the run never builds is not seen, a second primitive under a key already pinned is not seen, and a model that does exist says nothing about how it looks";

const summaryOf = (text) => {
  const line = String(text ?? "").split("\n").find((l) => l.startsWith("SUMMARY {"));
  try { return line ? JSON.parse(line.slice("SUMMARY ".length)) : null; } catch { return null; }
};
const verdictLine = (text) => String(text ?? "").split("\n").find((l) => l.startsWith(`${TEST}: `)) ?? "";
const named = (r) => `${r.shape} in ${r.file} (${r.mesh}${r.row ? `, owed by ${r.row}` : ""})`;

// run and plant: { ok, log } of the shipped run and the planted run, ok from the runner.
export function buildReceipt(run, plant, head) {
  const s = summaryOf(run.log);
  const p = summaryOf(plant.log);
  const failed = String(run.log ?? "").split("\n").filter((l) => l.endsWith("-> FAIL"));
  const clean = Boolean(s) && s.plant === "";
  const counted = Boolean(s) && Number.isInteger(s.surfaces) && s.pinned === PINNED_SURFACES && s.surfaces >= PINNED_SURFACES;
  const waits = (r) => WAITING.find((w) => w.file === r.file && w.row === r.row);
  const held = (s?.stand_ins ?? []).filter(waits);
  const standIns = (s?.stand_ins ?? []).filter((r) => !waits(r));
  const fresh = s?.new ?? [];
  const stale = s?.stale ?? [];
  const caught = Boolean(p) && !plant.ok && p.plant === PLANT_ENV.PRIM_PLANT && verdictLine(plant.log).includes("FAIL")
    && (p.new ?? []).some((r) => String(r.shape).endsWith(`/${PLANT_NAME}`)) && !fresh.some((r) => String(r.shape).endsWith(`/${PLANT_NAME}`));
  const pass = run.ok && failed.length === 0 && clean && counted && standIns.length === 0 && fresh.length === 0 && stale.length === 0 && caught
    && verdictLine(run.log).startsWith(`${TEST}: PASS`);
  let measured;
  if (!s) measured = `no SUMMARY line, so nothing was counted: ${(failed[0] ?? verdictLine(run.log) ?? "").slice(0, 200) || "the test did not finish"}`;
  else if (!clean) measured = `the counting run ran planted (${s.plant}): a plant switch reached the run that counts`;
  else if (!counted) measured = `the census counted ${s.surfaces} primitive surfaces, pinned at least ${PINNED_SURFACES} (test pin ${s.pinned}): the run built less than it should`;
  else {
    const parts = [`${s.surfaces} primitive surfaces counted over one bot run through the dam, the flume and Brindle`];
    parts.push(standIns.length ? `${standIns.length} code-built stand-in(s) left: ${standIns.map(named).join("; ")}` : held.length ? "no code-built stand-in left but those ruled to wait" : "no code-built stand-in left");
    if (fresh.length) parts.push(`${fresh.length} new primitive(s) no pin row covers: ${fresh.map(named).join("; ")}`);
    if (stale.length) parts.push(`${stale.length} stale stand-in row(s): ${stale.map((r) => `pin line ${r.line} ${r.file}|${r.mesh}|${r.shape} (${r.row})`).join("; ")}`);
    if (held.length) parts.push(`waiting: ${held.map((r) => `${named(r)} (${waits(r).cite.split(" ")[0]})`).join("; ")}`);
    if (failed.length) parts.push(`${failed.length} check(s) failed: ${failed[0].slice(0, 160)}`);
    measured = parts.join("; ");
  }
  if (p) measured += `; plant: with the control box judged as real (PRIM_PLANT=dam_box) the test ${plant.ok ? "still passed" : caught ? "failed and named it new" : "failed but did not name the box"}`;
  else measured += "; plant: the planted run printed no SUMMARY";
  measured += `; ${NOT_SEEN}`;
  return { head, pass, measured, plant_caught: caught };
}

// The receipt for the checkout at cwd. run is injectable so the refusal can be tested without Godot.
export function produce({ cwd = root, run = runAlone } = {}) {
  const head = cleanHead(cwd);
  const main = run(cwd, TEST);
  const plant = run(cwd, TEST, PLANT_ENV);
  return buildReceipt(main, plant, head);
}

function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) args[argv[i].replace(/^--/, "")] = argv[i + 1];
  let receipt;
  try { receipt = produce(); } catch (e) { console.error(String(e.message ?? e)); return 2; }
  const text = JSON.stringify(receipt, null, 2) + "\n";
  if (args.out) writeFileSync(args.out, text);
  else process.stdout.write(text);
  return receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main(process.argv.slice(2)));
