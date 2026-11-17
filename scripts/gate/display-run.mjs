// One Godot script run WITH a window, for a gate producer whose check reads rendered pixels (the world 1 done read's
// row "models-render", tools/model_render_check.gd). This is the one approved way for a gate producer to open a
// window; every other gate run goes through scripts/sketch-smoke.mjs, which is headless only.
//
// It takes a machine slot with acquireSlot (scripts/sketch-smoke.mjs), so it waits while a frame reading holds the
// machine quiet and counts as a runner, then launches
//   $GODOT_BIN [engineArgs] --path sketches/core-loop --script <res path> -- <args>
// with no --headless, under a scratch HOME / XDG_DATA_HOME in artifacts/local/display-run/ (scripts/godot-home.mjs:
// Godot on macOS ignores XDG_DATA_HOME, so HOME moves too). The player's own saves folder is never read or written.
// It kills the run at the timeout and always gives the slot back.
//
// macOS has a window server for a logged-in session, so a run there opens a window. On Linux a run needs DISPLAY or
// WAYLAND_DISPLAY; the PC's own lane is gamescope headless (tools/tripo/README.md, "The render check"), not built here,
// so with no display this returns "not supported here" without starting Godot. Other platforms are not supported.
import { spawn } from "node:child_process";
import { mkdirSync, mkdtempSync } from "node:fs";
import path from "node:path";

import { userDataEnv } from "../godot-home.mjs";
import { acquireSlot } from "../sketch-smoke.mjs";
import { root } from "./clean-head.mjs";

export const SKETCH = "sketches/core-loop";
export const TIMEOUT_MS = 600_000;

// Why a window cannot open here, or "" when it can.
export function displayProblem(platform = process.platform, env = process.env) {
  if (platform === "darwin") return "";
  if (platform === "linux") return env.DISPLAY || env.WAYLAND_DISPLAY ? "" : "not supported here: no DISPLAY or WAYLAND_DISPLAY (the PC lane is gamescope headless, not built in display-run.mjs)";
  return `not supported here: no display lane for ${platform}`;
}

// Starts a process and resolves { exit, signal, output, timedOut }. A seam for the tests.
export function launch(command, argv, { env, cwd, timeoutMs }) {
  return new Promise((resolve) => {
    let output = "";
    let timedOut = false;
    let child;
    try {
      child = spawn(command, argv, { env, cwd, stdio: ["ignore", "pipe", "pipe"] });
    } catch (error) {
      resolve({ exit: null, signal: null, output: String(error.message ?? error), timedOut });
      return;
    }
    child.stdout.on("data", (d) => { output += d; });
    child.stderr.on("data", (d) => { output += d; });
    const timer = setTimeout(() => { timedOut = true; child.kill("SIGKILL"); }, timeoutMs);
    child.on("error", (error) => { output += String(error.message ?? error); });
    child.on("close", (exit, signal) => { clearTimeout(timer); resolve({ exit, signal, output, timedOut }); });
  });
}

// Runs one Godot script with a window. Returns { exit, output, timedOut, home, supported }. exit is null when the run
// did not start or was killed.
export async function runWindowed({
  script,
  args = [],
  engineArgs = [],
  extraEnv = {},
  cwd = root,
  env = process.env,
  binary = env.GODOT_BIN,
  timeoutMs = TIMEOUT_MS,
  platform = process.platform,
  acquire = acquireSlot,
  start = launch,
} = {}) {
  const problem = displayProblem(platform, env);
  if (problem) return { exit: null, output: problem, timedOut: false, home: null, supported: false };
  if (!binary) return { exit: null, output: "GODOT_BIN is not set", timedOut: false, home: null, supported: true };
  const homes = path.join(cwd, "artifacts/local/display-run");
  mkdirSync(homes, { recursive: true });
  const home = mkdtempSync(path.join(homes, "home-"));
  const lease = await acquire({ log: () => {} });
  try {
    const argv = [...engineArgs, "--path", path.join(cwd, SKETCH), "--script", script, "--", ...args];
    if (argv.includes("--headless")) throw new Error("display-run: --headless defeats a windowed run");
    const run = await start(binary, argv, { env: { ...env, ...extraEnv, ...userDataEnv(home, platform) }, cwd, timeoutMs });
    return { exit: run.timedOut ? null : run.exit, output: run.output, timedOut: run.timedOut, home, supported: true };
  } finally {
    lease.release();
  }
}
