#!/usr/bin/env node
// The receipt for the world 1 done read's row "models-render" (scripts/world1-bands.rows.json):
//   { head, pass, measured, plant_caught }
// It judges sketches/core-loop/tools/model_render_check.gd: each generated (Tripo) enemy model, shot in the real game
// beside the authored one, must send at least 0.80 of the authored brightness with at most 0.15 more near-black pixels,
// in both views. The check's compare step ends with one line:
//   SUMMARY {"judged": n, "pinned": 6, "failed": [kind...], "plant": ""}
// The receipt passes only when the real compare judged every one of the PINNED_KINDS kinds, failed none, ran with no
// plant, and the planted compare (RENDER_PLANT=dark_hooker: the hooker painted near-black in the generated shoot, the
// fault of the rejected dark hooker body) failed the hooker, which the real compare passed. A plant switch left in the
// caller's environment reaches the real shoot, which then names the plant, so the receipt fails.
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
export const PLANT_ENV = { RENDER_PLANT: "dark_hooker" };
export const PLANT_KIND = "hooker";
export const NOT_SEEN = "what the numbers cannot say: rendered brightness against the authored model is all that is measured, so shape, fit, floating parts and how a model looks to a person still need the PC look; props are not judged";
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
  const counted = Boolean(s) && s.judged === PINNED_KINDS && s.pinned === PINNED_KINDS && lines.length === PINNED_KINDS;
  const clean = Boolean(s) && s.plant === "";
  const failed = s && Array.isArray(s.failed) ? s.failed : [];
  const caught = Boolean(s && p) && p.plant === PLANT_ENV.RENDER_PLANT && Array.isArray(p.failed)
    && p.failed.includes(PLANT_KIND) && !failed.includes(PLANT_KIND);
  const pass = counted && clean && failed.length === 0 && caught;
  let measured;
  if (!s) {
    const first = String(real.log ?? "").split("\n").find((l) => l.trim()) ?? "";
    measured = `no SUMMARY line, so no model was judged: ${first.slice(0, 200)}`;
  } else if (!clean) measured = `the real shoot ran planted (${s.plant}): a plant switch reached the run that counts`;
  else if (!counted) measured = `${s.judged} kinds judged with ${lines.length} verdict lines, pinned ${PINNED_KINDS}: a kind was not shot in both`;
  else if (failed.length) measured = `${failed.length} of ${s.judged} generated enemy models render too dark beside the authored ones: ${failed.join(", ")}`;
  else measured = `all ${s.judged} generated enemy models render at least 0.80 of the authored brightness with at most 0.15 more near-black pixels, in two views each`;
  if (s) {
    if (!p) measured += "; plant: the planted compare printed no SUMMARY";
    else measured += `; plant: with the hooker painted near-black (RENDER_PLANT=dark_hooker) the compare ${caught ? "failed the hooker" : `failed ${p.failed?.join(", ") || "nothing"}, not the hooker alone`}`;
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
