#!/usr/bin/env node
// The receipt for the world 1 done read's row "core-feel-tests" (scripts/world1-bands.rows.json):
//   { head, pass, measured, plant_caught }
// The row's basis is the six core feel flakes KNOWN-FAILING.tsv carries, rows that fail only under load. They are
// the flake rows on hit-stop, the juice budget and how the ball takes a shove or a slam (TESTS below). None of them
// checks launch speed; world_launch_test does, and this row does not claim it. On this checkout (head from
// git; cleanHead refuses a dirty checkout) it runs each test alone through the project's runner (SMOKE_SLOTS=1), three
// times, each run on a quiet machine: it refuses to start when the 1-minute load is above a quarter of the threads
// (shard.mjs QUIET_FACTOR, the gate's retime rule), and between runs waits for quiet as retime does.
// The receipt passes only with 18 passes in 18 runs, no flake or red row for any of the six in KNOWN-FAILING.tsv, and
// the plant caught: hit_stop_ticks_test with FEEL_PLANT=zero_stop (a test-only switch asking for a hit-stop of zero
// ticks) must fail its [slowed ticks] check, so a runner that reports everything green is caught. Fewer runs than 18
// is a miss, never a pass. The quiet runs do not take a row off the ledger: a row comes off only after the test
// passes two full gates in a row, or with a fix for its load fault (project-guide/handoff/GATE.md, KNOWN-FAILING).
//
//   node scripts/gate/core-feel-receipt.mjs --out <file>
import { readFileSync, realpathSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { LEDGER_FILE, parseLedger } from "../known-failing.mjs";
import { cleanHead, root } from "./clean-head.mjs";
import { QUIET_FACTOR, QUIET_POLLS, QUIET_POLL_MS } from "./shard.mjs";
import { runAlone } from "./solo-run.mjs";

// The six, with what each holds of the row's label.
export const TESTS = [
  ["hit_stop_ticks_test", "hit-stop: a stop slows exactly its ticks and hands the time scale back"],
  ["presentation_hitstop_test", "hit-stop: damage bands, the 60 ms cap, spacing and budget"],
  ["presentation_juice_test", "hit-stop: the real freeze on Engine.time_scale, camera hooks and squash"],
  ["juice_budget_test", "juice budget: shake capped per frame, hit-stop only on the attacker's strike"],
  ["kite_dive_stack_test", "the ball in the hand: a diving drone never shoves the ball into a jump of speed"],
  ["harpoon_canon_test", "the ball in the hand: the harpoon's slam, winch and rewind on real physics"],
];
export const NAMES = TESTS.map(([name]) => name);
export const RUNS = 3;
export const PLANT = { test: "hit_stop_ticks_test", env: { FEEL_PLANT: "zero_stop" }, check: "[slowed ticks]" };

// runs: [{ test, run, ok, exit, seconds, load }]; carried: ledger rows for the six; plant: { ok, log }.
export function buildReceipt({ runs, carried, plant, head, threads, maxLoad }) {
  const want = NAMES.length * RUNS;
  const passed = runs.filter((r) => r.ok && NAMES.includes(r.test));
  const counted = runs.length === want && NAMES.every((name) => runs.filter((r) => r.test === name).length === RUNS);
  const plantRow = plant.log.split("\n").find((l) => l.startsWith("PLANT {"));
  const caught = !plant.ok && Boolean(plantRow) && plant.log.split("\n").some((l) => l.startsWith(PLANT.check) && l.endsWith("-> FAIL"));
  const pass = counted && passed.length === want && carried.length === 0 && caught;
  const peak = runs.length ? Math.max(...runs.map((r) => r.load)) : 0;
  let measured = `${passed.length} of ${want} runs passed alone (${NAMES.join(", ")}; ${RUNS} runs each, 1-minute load at most ${peak} on ${threads} threads, quiet limit ${maxLoad})`;
  if (!counted) measured += `; only ${runs.length} of ${want} runs were made: too little data, a miss`;
  const red = runs.filter((r) => !r.ok);
  if (red.length) measured += `; failed: ${red.map((r) => `${r.test} run ${r.run} (exit ${r.exit})`).join(", ")}`;
  measured += carried.length ? `; KNOWN-FAILING.tsv still carries ${carried.map((r) => `${r.test} (${r.kind})`).join(", ")}, so the receipt fails; quiet solo passes do not clear a row, which comes off only after two full gates in a row pass the test or a fix for its load fault lands (GATE.md)` : "; KNOWN-FAILING.tsv carries none of the six";
  measured += `; plant: ${PLANT.test} with FEEL_PLANT=zero_stop ${caught ? `failed ${PLANT.check}` : "was not seen to fail"}`;
  return { head, pass, measured, plant_caught: caught };
}

export function carriedRows(ledgerText) {
  return parseLedger(ledgerText).rows.filter((row) => NAMES.includes(row.test) && ["flake", "red"].includes(row.kind));
}

// The receipt for the checkout at cwd. run, load and sleep are injectable so the refusals can be tested without Godot.
export async function produce({ cwd = root, run = runAlone, load = () => Math.round(os.loadavg()[0] * 10) / 10, sleep = (ms) => new Promise((r) => setTimeout(r, ms)), threads = os.availableParallelism() } = {}) {
  const head = cleanHead(cwd);
  const maxLoad = threads * QUIET_FACTOR;
  const first = load();
  if (first > maxLoad) throw new Error(`refusing: the 1-minute load ${first} is above ${maxLoad} (a quarter of ${threads} threads); the core feel tests are judged on a quiet machine`);
  const quiet = async () => {
    for (let polls = 0; ; polls++) {
      const now = load();
      if (now <= maxLoad) return now;
      if (polls >= QUIET_POLLS) throw new Error(`refusing: the load stayed above ${maxLoad} for ${(QUIET_POLLS * QUIET_POLL_MS) / 60_000} minutes`);
      await sleep(QUIET_POLL_MS);
    }
  };
  const runs = [];
  for (const name of NAMES) {
    for (let index = 1; index <= RUNS; index++) {
      const at = await quiet();
      const result = run(cwd, name);
      runs.push({ test: name, run: index, ok: result.ok, exit: result.exit, seconds: result.seconds, load: at });
    }
  }
  await quiet();
  const plant = run(cwd, PLANT.test, PLANT.env);
  const carried = carriedRows(readFileSync(path.join(cwd, LEDGER_FILE), "utf8"));
  return buildReceipt({ runs, carried, plant, head, threads, maxLoad });
}

async function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) args[argv[i].replace(/^--/, "")] = argv[i + 1];
  let receipt;
  try { receipt = await produce(); } catch (e) { console.error(String(e.message ?? e)); return 2; }
  const text = JSON.stringify(receipt, null, 2) + "\n";
  if (args.out) writeFileSync(args.out, text);
  else process.stdout.write(text);
  return receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) process.exitCode = await main(process.argv.slice(2));
