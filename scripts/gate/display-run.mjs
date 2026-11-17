// One Godot script run WITH a window, for a gate producer whose check reads rendered pixels (the world 1 done read's
// row "models-render", tools/model_render_check.gd). It is the one approved way for a gate producer to open a window.
// Godot is started elsewhere too, always headless: scripts/sketch-smoke.mjs for tests, and scripts/gate/pc.mjs, which
// launches Godot directly under its own scratch environment (stepEnv).
//
// It takes a machine slot with acquireSlot (scripts/sketch-smoke.mjs), so it waits while a frame reading holds the
// machine quiet and counts as a runner, then launches
//   $GODOT_BIN [engineArgs] --path sketches/core-loop --script res://<path> -- <args>
// with no --headless. The child's HOME, XDG_DATA_HOME, XDG_CONFIG_HOME and XDG_CACHE_HOME are always a new scratch
// folder under the repo's artifacts/local/display-run/, merged last over every other variable, on every platform (Godot
// on macOS ignores XDG_DATA_HOME, so HOME must move too; scripts/godot-home.mjs). A scratch folder that would resolve
// outside artifacts/local is refused, so the player's own saves are never read or written. The folder is removed after
// the run unless KEEP_DISPLAY_HOME=1.
// The child runs in its own process group. At the timeout, or when this node process gets SIGINT or SIGTERM during a
// run, the whole group is killed. The slot is always given back.
//
// macOS has a window server for a logged-in session, so a run there opens a window. On Linux a run needs DISPLAY or
// WAYLAND_DISPLAY; the PC's lane is gamescope headless (tools/tripo/README.md, "The render check"), not built here, so
// with no display this returns "not supported here" without starting Godot. Other platforms are not supported.
import { spawn } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync } from "node:fs";
import path from "node:path";

import { acquireSlot } from "../sketch-smoke.mjs";
import { root } from "./clean-head.mjs";

export const SKETCH = "sketches/core-loop";
export const TIMEOUT_MS = 600_000;
// Engine flags a caller may not pass: each would defeat the window or point Godot at another project.
export const REFUSED_ENGINE_ARGS = ["--headless", "--display-driver", "--rendering-driver", "--path"];

// Why a window cannot open here, or "" when it can.
export function displayProblem(platform = process.platform, env = process.env) {
  if (platform === "darwin") return "";
  if (platform === "linux") return env.DISPLAY || env.WAYLAND_DISPLAY ? "" : "not supported here: no DISPLAY or WAYLAND_DISPLAY (the PC lane is gamescope headless, not built in display-run.mjs)";
  return `not supported here: no display lane for ${platform}`;
}

// The scratch environment for one run: a new folder under <cwd>/artifacts/local/display-run, refused if it would
// resolve anywhere else. Every home variable points into it, whatever the platform.
export function scratchEnv(cwd) {
  const local = path.resolve(cwd, "artifacts/local");
  const homes = path.resolve(local, "display-run");
  mkdirSync(homes, { recursive: true });
  const home = path.resolve(mkdtempSync(path.join(homes, "home-")));
  if (!home.startsWith(homes + path.sep) || path.relative(local, home).startsWith("..")) {
    rmSync(home, { recursive: true, force: true });
    throw new Error(`display-run: the scratch home ${home} would be outside ${local}; refusing`);
  }
  return {
    home,
    env: { HOME: home, XDG_DATA_HOME: path.join(home, "data"), XDG_CONFIG_HOME: path.join(home, "config"), XDG_CACHE_HOME: path.join(home, "cache") },
  };
}

const killGroup = (child) => {
  try { process.kill(-child.pid, "SIGKILL"); } catch { try { child.kill("SIGKILL"); } catch { /* already gone */ } }
};

// Starts a process in its own group and resolves { exit, signal, output, timedOut }. At the timeout, or on SIGINT or
// SIGTERM to this process while it runs, the whole group is killed. A seam for the tests.
export function launch(command, argv, { env, cwd, timeoutMs }) {
  return new Promise((resolve) => {
    let output = "";
    let timedOut = false;
    let child;
    try {
      child = spawn(command, argv, { env, cwd, stdio: ["ignore", "pipe", "pipe"], detached: true });
    } catch (error) {
      resolve({ exit: null, signal: null, output: String(error.message ?? error), timedOut });
      return;
    }
    const onSignal = (signal) => {
      killGroup(child);
      process.exit(signal === "SIGINT" ? 130 : 143);
    };
    process.on("SIGINT", onSignal);
    process.on("SIGTERM", onSignal);
    child.stdout.on("data", (d) => { output += d; });
    child.stderr.on("data", (d) => { output += d; });
    const timer = setTimeout(() => { timedOut = true; killGroup(child); }, timeoutMs);
    let done = false;
    const finish = (exit, signal) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      process.off("SIGINT", onSignal);
      process.off("SIGTERM", onSignal);
      resolve({ exit, signal, output, timedOut });
    };
    child.on("error", (error) => { output += String(error.message ?? error); finish(null, null); });
    // "close" once the pipes drain; "exit" plus half a second when a grandchild keeps them open past the kill.
    child.on("close", (exit, signal) => finish(exit, signal));
    child.on("exit", (exit, signal) => setTimeout(() => finish(exit, signal), 500));
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
  if (typeof script !== "string" || !script.startsWith("res://")) throw new Error(`display-run: script must be a res:// path, got ${script}`);
  const refused = engineArgs.filter((a) => REFUSED_ENGINE_ARGS.some((r) => a === r || a.startsWith(`${r}=`)));
  if (refused.length) throw new Error(`display-run: refusing engine flag(s) ${refused.join(", ")}`);
  const problem = displayProblem(platform, env);
  if (problem) return { exit: null, output: problem, timedOut: false, home: null, supported: false };
  if (!binary) return { exit: null, output: "GODOT_BIN is not set", timedOut: false, home: null, supported: true };
  const scratch = scratchEnv(cwd);
  const lease = await acquire({ log: () => {} });
  try {
    const argv = [...engineArgs, "--path", path.join(cwd, SKETCH), "--script", script, "--", ...args];
    const run = await start(binary, argv, { env: { ...env, ...extraEnv, ...scratch.env }, cwd, timeoutMs });
    return { exit: run.timedOut ? null : run.exit, output: run.output, timedOut: run.timedOut, home: scratch.home, supported: true };
  } finally {
    lease.release();
    if (env.KEEP_DISPLAY_HOME !== "1") rmSync(scratch.home, { recursive: true, force: true });
  }
}
