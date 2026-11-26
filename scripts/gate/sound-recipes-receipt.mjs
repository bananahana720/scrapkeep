#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { cleanHead } from "./clean-head.mjs";

export { cleanHead };

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
export const TEST = "sound_own_recipes_test";
export const MIN_CHECKS = 5;

const jsonLines = (text, tag) => text.split("\n").filter((l) => l.startsWith(`${tag} {`)).map((line) => {
  try { return JSON.parse(line.slice(tag.length + 1)); } catch { return null; }
}).filter(Boolean);

export function buildReceipt(text, head) {
  const lines = text.split("\n");
  const failed = lines.filter((l) => l.endsWith("-> FAIL"));
  const checks = failed.length + lines.filter((l) => l.endsWith("-> PASS")).length;
  const cues = jsonLines(text, "CUE");
  const plant = jsonLines(text, "PLANT")[0] ?? null;
  const summary = jsonLines(text, "SUMMARY")[0] ?? null;
  const short = cues.filter((c) => c.own !== true);
  const counted = Boolean(summary) && cues.length === summary.cues && summary.cues === summary.pinned;
  const caught = Boolean(plant && plant.caught === true && plant.fact && plant.before === short.length && plant.after === short.length + 1);
  const pass = failed.length === 0 && checks >= MIN_CHECKS && counted && short.length === 0 && caught;
  let measured;
  if (cues.length === 0 || !summary) measured = "no CUE or SUMMARY lines: the test did not finish";
  else if (!counted) measured = `${cues.length} CUE lines, SUMMARY counted ${summary.cues}, pinned ${summary.pinned}: world 1 cues appeared or vanished`;
  else if (checks < MIN_CHECKS) measured = `only ${checks} check lines, the test stopped early`;
  else if (short.length) measured = `${short.length} of ${cues.length} world 1 cues play no sound of their own: ${short.map((c) => `${c.cue} -> ${c.plays}`).join(", ")}`;
  else if (failed.length) measured = `${failed.length} check(s) failed: ${failed[0].slice(0, 120)}`;
  else measured = `all ${cues.length} world 1 cues play a sound of their own`;
  if (cues.length && plant) measured += `; plant: ${plant.fact}'s recipe removed read ${plant.before} -> ${plant.after}`;
  return { head, pass, measured, plant_caught: caught };
}

export function runTest(cwd) {
  const logs = mkdtempSync(path.join(os.tmpdir(), "sound-recipes-"));
  const run = spawnSync(process.execPath, [path.join(cwd, "scripts/sketch-smoke.mjs"), "--sketch", "core-loop", "--test", TEST], {
    cwd, env: { ...process.env, SMOKE_LOG_DIR: logs }, encoding: "utf8", maxBuffer: 1 << 26,
  });
  try { return readFileSync(path.join(logs, `${TEST}.log`), "utf8"); } catch { return `runner exit ${run.status}, no ${TEST}.log: ${String(run.stdout).slice(-200)}`; }
}

export function produce({ cwd = root, run = runTest } = {}) {
  const head = cleanHead(cwd);
  return buildReceipt(run(cwd), head);
}

function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) args[argv[i].replace(/^--/, "")] = argv[i + 1];
  if (args.log) {
    const r = buildReceipt(readFileSync(args.log, "utf8"), "0000000");
    process.stdout.write(JSON.stringify({ ...r, pass: false, measured: `log only, not a receipt: ${r.measured}` }, null, 2) + "\n");
    return 1;
  }
  let receipt;
  try { receipt = produce(); } catch (e) { console.error(String(e.message ?? e)); return 2; }
  const text = JSON.stringify(receipt, null, 2) + "\n";
  if (args.out) writeFileSync(args.out, text);
  else process.stdout.write(text);
  return receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main(process.argv.slice(2)));
