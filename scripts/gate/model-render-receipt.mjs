#!/usr/bin/env node
// The receipt for the world 1 done read's row "models-render" (scripts/world1-bands.rows.json):
//   { head, pass, measured, plant_caught }
// What it measures: no generated (Tripo) enemy model renders darker than its authored one, for the 6 enemy kinds that
// have one, in two views. sketches/core-loop/tools/model_render_check.gd shoots each kind in the real game, measures
// only the parts drawn from the model file (code-built nets, masts and lamps are masked out), and its compare needs at
// least 0.80 of the authored brightness with at most 0.15 more near-black pixels. The compare ends with one line:
//   SUMMARY {"judged": n, "pinned": 6, "failed": [kind...], "missing": [kind...], "plant": ""}
// The receipt passes only when the real compare printed one verdict line per pinned kind, judged all 6, found no kind
// missing its generated model and none too dark, ran with no plant, and the planted compare (RENDER_PLANT=dark_models:
// every kind's model parts painted near-black as it is shot, the fault of the rejected dark hooker body) shows the
// plant in its stats and failed every one of the 6 kinds. A plant switch left in the caller's environment reaches the
// real shoot (the authored shoot refuses it), so the receipt fails.
// The head comes from cleanHead (clean-head.mjs).
//
// A shoot needs a graphics display, so every run goes through display-run.mjs (a machine slot, a window, a scratch
// HOME): the authored shoot, the --models=tripo-all shoot, the compare, then the planted tripo-all shoot and its
// compare. Shoots and sheets land in a new folder under artifacts/local/. Where display-run.mjs has no display (Linux
// without one; the PC's gamescope lane is not built), the receipt fails with that reason.
//
//   node scripts/gate/model-render-receipt.mjs --out <file>
import { mkdirSync, mkdtempSync, realpathSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { cleanHead, root } from "./clean-head.mjs";
import { runWindowed } from "./display-run.mjs";

export const TOOL = "tools/model_render_check.gd";
export const ENGINE_ARGS = ["--resolution", "800x600", "--audio-driver", "Dummy"];
export const PINNED_KINDS = 6;
export const KINDS = ["chaser", "lobber", "swatter", "hooker", "netcaster", "boom_tender"];
export const PLANT_ENV = { RENDER_PLANT: "dark_models" };
export const NOT_SEEN = "not judged: pilots, item parts, the camp pet and props have no render check; only a model darker than its authored one is caught, so a brighter, white or recoloured model passes; most of an enemy's material is replaced in code, so a missing or wrong material in the model file cannot be seen; shape, fit, floating parts and how a model looks to a person still need the PC look";
export const NO_DISPLAY = "not run: the shoot needs a graphics display and display-run.mjs found none";

const summaryOf = (text) => {
  const line = String(text ?? "").split("\n").find((l) => l.startsWith("SUMMARY {"));
  try { return line ? JSON.parse(line.slice("SUMMARY ".length)) : null; } catch { return null; }
};
const kindLines = (text) => String(text ?? "").split("\n").filter((l) => /^(PASS|FAIL) \w+: /.test(l));

// real and plant: { log } of the real compare and the planted compare.
export function buildReceipt(real, plant, head) {
  const s = summaryOf(real.log);
  const p = summaryOf(plant.log);
  const lines = kindLines(real.log);
  const missing = s && Array.isArray(s.missing) ? s.missing : ["(no missing list)"];
  const counted = Boolean(s) && s.judged === PINNED_KINDS && s.pinned === PINNED_KINDS && lines.length === PINNED_KINDS;
  const clean = Boolean(s) && s.plant === "";
  const failed = s && Array.isArray(s.failed) ? s.failed : [];
  const plantFailed = p && Array.isArray(p.failed) ? p.failed : [];
  const plantMissed = KINDS.filter((k) => !plantFailed.includes(k));
  const caught = Boolean(s && p) && p.plant === PLANT_ENV.RENDER_PLANT && plantMissed.length === 0;
  const pass = counted && clean && missing.length === 0 && failed.length === 0 && caught;
  let measured;
  if (!s) {
    const first = String(real.log ?? "").split("\n").find((l) => l.trim()) ?? "";
    measured = `no SUMMARY line, so no model was judged: ${first.slice(0, 200)}`;
  } else if (!clean) measured = `the real shoot ran planted (${s.plant}): a plant switch reached the run that counts`;
  else if (missing.length) measured = `${missing.length} kind(s) had no generated model loaded, so nothing was judged for them: ${missing.join(", ")}`;
  else if (!counted) measured = `${s.judged} kinds judged with ${lines.length} verdict lines, pinned ${PINNED_KINDS} (the check pins ${s.pinned}): a kind was not shot in both`;
  else if (failed.length) measured = `${failed.length} of ${s.judged} generated enemy models render darker than their authored ones: ${failed.join(", ")}`;
  else measured = `no generated enemy model renders darker than its authored one: all ${s.judged} kinds send at least 0.80 of the authored brightness with at most 0.15 more near-black pixels, in two views each, over the parts drawn from the model file`;
  if (s) {
    if (!p) measured += "; plant: the planted compare printed no SUMMARY";
    else if (p.plant !== PLANT_ENV.RENDER_PLANT) measured += `; plant: the planted shoot's stats do not show the plant (${p.plant || "none"}), so it proves nothing`;
    else measured += `; plant: with every kind's model parts painted near-black (RENDER_PLANT=dark_models) the compare ${caught ? `failed all ${KINDS.length} kinds` : `missed ${plantMissed.join(", ")}`}`;
  }
  measured += `; ${NOT_SEEN}`;
  return { head, pass, measured, plant_caught: caught };
}

// A failed step's log: what ran, its exit, and the output's last lines (no SUMMARY in it, so the receipt misses).
const stepFailed = (name, r) => `${name} ${r.timedOut ? "timed out" : `exit ${r.exit}`}: ${String(r.output).trim().split("\n").slice(-4).join(" | ")}`;

// The real shoot and compare, then the planted ones, each through display-run.mjs. window is injectable for the tests.
export async function runShoots(cwd, { window = runWindowed } = {}) {
  mkdirSync(path.join(cwd, "artifacts/local"), { recursive: true });
  const dir = mkdtempSync(path.join(cwd, "artifacts/local/model-render-"));
  const at = (name) => path.join(dir, name);
  const step = (args, extraEnv = {}) => window({ cwd, script: `res://${TOOL}`, args, engineArgs: ENGINE_ARGS, extraEnv });
  const shots = [
    ["authored shoot", [`--out=${at("authored")}`]],
    ["tripo-all shoot", [`--out=${at("tripo")}`, "--models=tripo-all"]],
  ];
  for (const [name, args] of shots) {
    const r = await step(args);
    if (r.exit !== 0) {
      const log = r.supported === false ? `${NO_DISPLAY}: ${r.output}` : stepFailed(name, r);
      return { real: { log }, plant: { log: "not run: the real shoot failed" } };
    }
  }
  const real = await step([`--compare=${at("authored")},${at("tripo")}`, `--out=${at("sheets")}`]);
  const planted = await step([`--out=${at("tripo-planted")}`, "--models=tripo-all"], PLANT_ENV);
  const plant = planted.exit === 0
    ? await step([`--compare=${at("authored")},${at("tripo-planted")}`, `--out=${at("sheets-planted")}`])
    : { output: stepFailed("planted shoot", planted) };
  return { real: { log: real.output }, plant: { log: plant.output }, dir };
}

// The receipt for the checkout at cwd. run is injectable so the refusal can be tested without Godot.
export async function produce({ cwd = root, run = runShoots } = {}) {
  const head = cleanHead(cwd);
  const { real, plant } = await run(cwd);
  return buildReceipt(real, plant, head);
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

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) main(process.argv.slice(2)).then((code) => process.exit(code));
