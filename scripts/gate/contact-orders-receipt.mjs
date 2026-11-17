#!/usr/bin/env node
// The receipt for the world 1 done read's row "same-seed-same-run" (scripts/world1-bands.rows.json):
//   { head, pass, measured, plant_caught }
// It runs sketches/core-loop/tests/contact_orders_all_test.gd twice, alone, through the project's runner, on this
// checkout, and takes the head from git (cleanHead refuses a dirty checkout):
//   1. as it ships: every arrival order of five contact sets of up to four same-tick contacts, each order on a fresh
//      game from one seed, in two delivery modes (block: every touch at the first touch's place; interleaved: each
//      touch's body_entered at its own place, so a hit, pickup or hazard lands between two touches). The count of
//      orders is pinned here and in the test. A set whose orders end in different states fails the receipt, named.
//   2. with CONTACT_PLANT=nosort, a test-only switch that bypasses the game's contact sort on the checks that carry
//      the claim: the test must fail them. A pass whose plant was not seen to fail is void.
// Not claimed: a pickup and a hazard in the same tick end in a state that depends on which lands first.
//
//   node scripts/gate/contact-orders-receipt.mjs --out <file>
import { realpathSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { cleanHead, root } from "./clean-head.mjs";
import { runAlone } from "./solo-run.mjs";

export const TEST = "contact_orders_all_test";
export const PINNED_ORDERS = 124;
export const PINNED_SETS = 5;
export const MODES = ["block", "interleaved"];
export const PLANT_ENV = { CONTACT_PLANT: "nosort" };
export const EXCLUDED = "not claimed: a pickup and a hazard in the same tick end in a state that depends on which lands first (the scrap absorbs part of the damage); whether a same-tick pickup always lands first is a design call waiting on Andrew";

const jsonLine = (text, tag) => {
  const line = text.split("\n").find((l) => l.startsWith(`${tag} {`));
  try { return line ? JSON.parse(line.slice(tag.length + 1)) : null; } catch { return null; }
};
const verdictLine = (text) => text.split("\n").find((l) => l.startsWith(`${TEST}: `)) ?? "";
const SAME = /^\[same state (\S+(?: \S+)*?): ([^\]]+)\] (\d+) orders ran, (\d+) differ from the first(.*) -> (ok|FAIL)$/;
const sameRows = (text) => text.split("\n").map((l) => l.match(SAME)).filter(Boolean)
  .map((m) => ({ mode: m[1], set: m[2], ran: Number(m[3]), differ: Number(m[4]), detail: m[5].replace(/^; /, ""), ok: m[6] === "ok" }));

// run and plant: { ok, log } of the shipped run and the planted run, ok from the runner.
export function buildReceipt(run, plant, head) {
  const main = run.log;
  const lines = main.split("\n");
  const failed = lines.filter((l) => l.endsWith("-> FAIL"));
  const rows = sameRows(main).filter((r) => MODES.includes(r.mode));
  const summary = jsonLine(main, "SUMMARY");
  const known = lines.find((l) => l.startsWith("[known dependence seen: pickup then hazard]")) ?? "";
  const counted = Boolean(summary) && summary.orders === PINNED_ORDERS && summary.pinned === PINNED_ORDERS
    && rows.length === PINNED_SETS * MODES.length && rows.reduce((n, r) => n + r.ran, 0) === PINNED_ORDERS;
  const plantRows = sameRows(plant.log).filter((r) => r.mode === "planted no sort");
  const plantLine = jsonLine(plant.log, "PLANT");
  const caught = !plant.ok && Boolean(plantLine) && plantRows.some((r) => !r.ok && r.differ > 0) && verdictLine(plant.log).includes("FAIL");
  const parted = rows.filter((r) => !r.ok);
  const pass = run.ok && failed.length === 0 && counted && known.endsWith("-> ok") && verdictLine(main).endsWith("PASS") && caught;
  let measured;
  if (!summary || rows.length === 0) measured = "no SUMMARY or same-state lines: the test did not finish";
  else if (!counted) measured = `${summary.orders} orders ran in ${rows.length} set-and-mode checks, pinned ${PINNED_ORDERS} in ${PINNED_SETS * MODES.length}: too few orders were tried to judge`;
  else if (parted.length) measured = `order dependence: ${parted.map((r) => `${r.set} (${r.mode}) parts in ${r.differ} of ${r.ran} orders; ${r.detail.slice(0, 240)}`).join(" | ")}`;
  else if (failed.length) measured = `${failed.length} check(s) failed: ${failed[0].slice(0, 160)}`;
  else measured = `all ${summary.orders} arrival orders of ${PINNED_SETS} contact sets (up to four same-tick contacts, each order a fresh game from one seed) end in one state, with touches delivered as a block and interleaved with hits, pickups and hazards`;
  measured += `; ${EXCLUDED}`;
  if (plantLine) measured += `; plant: with the contact sort bypassed (CONTACT_PLANT=nosort) ${plantLine.orders_differ} orders parted and the test ${plant.ok ? "still passed" : "failed"}`;
  else measured += "; plant: the planted run printed no PLANT line";
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
