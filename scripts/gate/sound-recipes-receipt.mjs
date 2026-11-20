#!/usr/bin/env node
// The receipt for the world 1 done read's row "sound-own-recipes" (scripts/world1-bands.rows.json):
//   { head, pass, measured, plant_caught }
// It runs sketches/core-loop/tests/sound_own_recipes_test.gd itself, through the project's runner
// (scripts/sketch-smoke.mjs, so Godot's HOME is a scratch folder), on this checkout, and takes the head
// from `git rev-parse HEAD`. It refuses a checkout with uncommitted changes to tracked files, since the
// test would then judge code that no commit holds.
// The test prints one CUE line per cue the world 1 sound facts name, with whether it plays a sound of
// its own and what plays in its place; a PLANT line (one world 1 cue's recipe removed must be counted,
// the removed id must bake the fallback blip, three real recipes must not); and a SUMMARY line with the
// pinned cue count. The receipt passes only when no check failed, the CUE lines number the SUMMARY's
// count and that count is the pinned one, no cue lacks a sound of its own, and the plant was caught.
//
//   node scripts/gate/sound-recipes-receipt.mjs --out <file>
//   node scripts/gate/sound-recipes-receipt.mjs --log <test output>   (a test hook: prints, never passes)
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { cleanHead } from "./clean-head.mjs";

export { cleanHead };

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
export const TEST = "sound_own_recipes_test";
// The test prints five check lines; fewer means it stopped early.
export const MIN_CHECKS = 5;

const jsonLines = (text, tag) =>
  text
    .split("\n")
    .filter((l) => l.startsWith(`${tag} {`))
    .map((line) => {
      try {
        return JSON.parse(line.slice(tag.length + 1));
      } catch {
        return null;
      }
    })
    .filter(Boolean);

export function buildReceipt(text, head) {
  const lines = text.split("\n");
  const failed = lines.filter((l) => l.endsWith("-> FAIL"));
  const checks = failed.length + lines.filter((l) => l.endsWith("-> PASS")).length;
  const cues = jsonLines(text, "CUE");
  const plant = jsonLines(text, "PLANT")[0] ?? null;
  const summary = jsonLines(text, "SUMMARY")[0] ?? null;
  const short = cues.filter((c) => c.own !== true);
  const counted =
    Boolean(summary) && cues.length === summary.cues && summary.cues === summary.pinned;
  // The plant is caught when the removed recipe was counted as one more cue than the real run found.
  const caught = Boolean(
    plant &&
    plant.caught === true &&
    plant.fact &&
    plant.before === short.length &&
    plant.after === short.length + 1,
  );
  const pass =
    failed.length === 0 && checks >= MIN_CHECKS && counted && short.length === 0 && caught;
  let measured;
  if (cues.length === 0 || !summary) measured = "no CUE or SUMMARY lines: the test did not finish";
  else if (!counted)
    measured = `${cues.length} CUE lines, SUMMARY counted ${summary.cues}, pinned ${summary.pinned}: world 1 cues appeared or vanished`;
  else if (checks < MIN_CHECKS) measured = `only ${checks} check lines, the test stopped early`;
  else if (short.length)
    measured = `${short.length} of ${cues.length} world 1 cues play no sound of their own: ${short.map((c) => `${c.cue} -> ${c.plays}`).join(", ")}`;
  else if (failed.length) measured = `${failed.length} check(s) failed: ${failed[0].slice(0, 120)}`;
  else measured = `all ${cues.length} world 1 cues play a sound of their own`;
  if (cues.length && plant)
    measured += `; plant: ${plant.fact}'s recipe removed read ${plant.before} -> ${plant.after}`;
  return { head, pass, measured, plant_caught: caught };
}

// Runs the test through the project's runner and returns its log text.
export function runTest(cwd) {
  const logs = mkdtempSync(path.join(os.tmpdir(), "sound-recipes-"));
  const run = spawnSync(
    process.execPath,
    [path.join(cwd, "scripts/sketch-smoke.mjs"), "--sketch", "core-loop", "--test", TEST],
    {
      cwd,
      env: { ...process.env, SMOKE_LOG_DIR: logs },
      encoding: "utf8",
      maxBuffer: 1 << 26,
    },
  );
  try {
    return readFileSync(path.join(logs, `${TEST}.log`), "utf8");
  } catch {
    return `runner exit ${run.status}, no ${TEST}.log: ${String(run.stdout).slice(-200)}`;
  }
}

// The receipt for the checkout at cwd: takes the head from cleanHead and runs the test there. run is injectable so
// the refusal can be tested without Godot.
export function produce({ cwd = root, run = runTest } = {}) {
  const head = cleanHead(cwd);
  return buildReceipt(run(cwd), head);
}

function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) args[argv[i].replace(/^--/, "")] = argv[i + 1];
  if (args.log) {
    // A test hook: a log from anywhere judges no commit, so it never writes a passing receipt.
    const r = buildReceipt(readFileSync(args.log, "utf8"), "0000000");
    process.stdout.write(
      JSON.stringify(
        { ...r, pass: false, measured: `log only, not a receipt: ${r.measured}` },
        null,
        2,
      ) + "\n",
    );
    return 1;
  }
  let receipt;
  try {
    receipt = produce();
  } catch (e) {
    console.error(String(e.message ?? e));
    return 2;
  }
  const text = JSON.stringify(receipt, null, 2) + "\n";
  if (args.out) writeFileSync(args.out, text);
  else process.stdout.write(text);
  return receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url))
  process.exit(main(process.argv.slice(2)));
