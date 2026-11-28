#!/usr/bin/env node
import { mkdirSync, mkdtempSync } from "node:fs";
import path from "node:path";

import { runWindowed } from "./display-run.mjs";
import { cleanHead, parseReceiptArgs, root, runReceiptCli } from "./receipt-cli.mjs";
import { isMain } from "../lib/cli.mjs";

export const TOOL = "tools/model_render_check.gd";
export const ENGINE_ARGS = ["--resolution", "800x600", "--audio-driver", "Dummy"];
export const PINNED_KINDS = 6;
export const KINDS = ["chaser", "lobber", "swatter", "hooker", "netcaster", "boom_tender"];
export const PLANT_ENV = { RENDER_PLANT: "dark_models" };
export const NOT_SEEN =
  "not judged: pilots, item parts, the camp pet and props have no render check; only a model darker than its authored one is caught, so a brighter, white or recoloured model passes; most of an enemy's material is replaced in code, so a missing or wrong material in the model file cannot be seen; shape, fit, floating parts and how a model looks to a person still need the PC look";
export const NO_DISPLAY =
  "not run: the shoot needs a graphics display and display-run.mjs found none";

const summaryOf = (text) => {
  const line = String(text ?? "")
    .split("\n")
    .find((l) => l.startsWith("SUMMARY {"));
  try {
    return line ? JSON.parse(line.slice("SUMMARY ".length)) : null;
  } catch {
    return null;
  }
};
const kindLines = (text) =>
  String(text ?? "")
    .split("\n")
    .filter((l) => /^(PASS|FAIL) \w+: /.test(l));

export function buildReceipt(real, plant, head) {
  const s = summaryOf(real.log);
  const p = summaryOf(plant.log);
  const lines = kindLines(real.log);
  const missing = s && Array.isArray(s.missing) ? s.missing : ["(no missing list)"];
  const counted =
    Boolean(s) &&
    s.judged === PINNED_KINDS &&
    s.pinned === PINNED_KINDS &&
    lines.length === PINNED_KINDS;
  const clean = Boolean(s) && s.plant === "";
  const failed = s && Array.isArray(s.failed) ? s.failed : [];
  const plantFailed = p && Array.isArray(p.failed) ? p.failed : [];
  const plantMissed = KINDS.filter((k) => !plantFailed.includes(k));
  const caught = Boolean(s && p) && p.plant === PLANT_ENV.RENDER_PLANT && plantMissed.length === 0;
  const pass = counted && clean && missing.length === 0 && failed.length === 0 && caught;
  let measured;
  if (!s) {
    const first =
      String(real.log ?? "")
        .split("\n")
        .find((l) => l.trim()) ?? "";
    measured = `no SUMMARY line, so no model was judged: ${first.slice(0, 200)}`;
  } else if (!clean)
    measured = `the real shoot ran planted (${s.plant}): a plant switch reached the run that counts`;
  else if (missing.length)
    measured = `${missing.length} kind(s) had no generated model loaded, so nothing was judged for them: ${missing.join(", ")}`;
  else if (!counted)
    measured = `${s.judged} kinds judged with ${lines.length} verdict lines, pinned ${PINNED_KINDS} (the check pins ${s.pinned}): a kind was not shot in both`;
  else if (failed.length)
    measured = `${failed.length} of ${s.judged} generated enemy models render darker than their authored ones: ${failed.join(", ")}`;
  else
    measured = `no generated enemy model renders darker than its authored one: all ${s.judged} kinds send at least 0.80 of the authored brightness with at most 0.15 more near-black pixels, in two views each, over the parts drawn from the model file`;
  if (s) {
    if (!p) measured += "; plant: the planted compare printed no SUMMARY";
    else if (p.plant !== PLANT_ENV.RENDER_PLANT)
      measured += `; plant: the planted shoot's stats do not show the plant (${p.plant || "none"}), so it proves nothing`;
    else
      measured += `; plant: with every kind's model parts painted near-black (RENDER_PLANT=dark_models) the compare ${caught ? `failed all ${KINDS.length} kinds` : `missed ${plantMissed.join(", ")}`}`;
  }
  measured += `; ${NOT_SEEN}`;
  return { head, pass, measured, plant_caught: caught };
}

const stepFailed = (name, r) =>
  `${name} ${r.timedOut ? "timed out" : `exit ${r.exit}`}: ${String(r.output).trim().split("\n").slice(-4).join(" | ")}`;

export async function runShoots(cwd, { window = runWindowed } = {}) {
  mkdirSync(path.join(cwd, "artifacts/local"), { recursive: true });
  const dir = mkdtempSync(path.join(cwd, "artifacts/local/model-render-"));
  const at = (name) => path.join(dir, name);
  const step = (args, extraEnv = {}) =>
    window({ cwd, script: `res://${TOOL}`, args, engineArgs: ENGINE_ARGS, extraEnv });
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
  const plant =
    planted.exit === 0
      ? await step([
          `--compare=${at("authored")},${at("tripo-planted")}`,
          `--out=${at("sheets-planted")}`,
        ])
      : { output: stepFailed("planted shoot", planted) };
  return { real: { log: real.output }, plant: { log: plant.output }, dir };
}

export async function produce({ cwd = root, run = runShoots } = {}) {
  const head = cleanHead(cwd);
  const { real, plant } = await run(cwd);
  return buildReceipt(real, plant, head);
}

function main(argv) {
  return runReceiptCli(async () => {
    const args = parseReceiptArgs(argv);
    return { receipt: await produce(), out: args.out };
  });
}

if (isMain(import.meta.url)) main(process.argv.slice(2)).then((code) => process.exit(code));
