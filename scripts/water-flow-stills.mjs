#!/usr/bin/env node
// Water flow stills on the real renderer (sketches/core-loop/tools/water_flow_stills.gd), through the one approved
// way to open a Godot window, scripts/gate/display-run.mjs: a machine slot, a scratch HOME under artifacts/local that is
// deleted after the run, and no --headless. One run at a time.
//   node scripts/water-flow-stills.mjs --out=<dir> [--shader=<file>] [--calm]
// --out and --shader are made absolute against this checkout; --out must lie outside the scratch home (it is deleted).
// SCRAPKEEP_WATER_FLOW_PLANT=freeze in the environment reaches the tool and must make it exit 1.
// Prints the tool's output and exits with its exit code (2 when the run did not start or was killed).
import path from "node:path";
import { realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { runWindowed } from "./gate/display-run.mjs";

export const SCRIPT = "res://tools/water_flow_stills.gd";
export const ENGINE_ARGS = ["--resolution", "1280x720", "--audio-driver", "Dummy"];

export function toolArgs(argv, cwd) {
  return argv.map((arg) => {
    const [flag, value] = arg.split(/=(.*)/s);
    if (flag === "--out" || flag === "--shader") return `${flag}=${path.resolve(cwd, value)}`;
    if (arg === "--calm") return arg;
    throw new Error(`water-flow-stills: unknown option ${arg}`);
  });
}

async function main(argv) {
  const cwd = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const args = toolArgs(argv, cwd);
  if (!args.some((a) => a.startsWith("--out=")))
    throw new Error("water-flow-stills: --out=<dir> is needed");
  const run = await runWindowed({ cwd, script: SCRIPT, args, engineArgs: ENGINE_ARGS });
  process.stdout.write(run.output);
  if (run.timedOut)
    console.error(
      "water-flow-stills: timed out; the process group was killed, check that no Godot window is left open",
    );
  if (!run.supported) console.error(`water-flow-stills: ${run.output}`);
  return run.exit ?? 2;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).then(
    (code) => process.exit(code),
    (e) => {
      console.error(String(e.message ?? e));
      process.exit(2);
    },
  );
}
