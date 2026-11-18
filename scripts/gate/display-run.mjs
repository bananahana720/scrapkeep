// Run a pixel-producing script with scratch saves, a machine slot and an exclusive drawn-run lock.
// On the Mac, --offscreen uses the native embedded Metal display and a 50 ms window watcher.
// The models-render gate also uses that display. Only the Gate runs the visible CLI reference.
// Linux library callers supply their own display (the PC uses headless gamescope).
import { spawn, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { watchDrawnRun } from "./window-watch.mjs";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
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
export function launch(command, argv, { env, cwd, timeoutMs, signal: cancellation }) {
  cancellation?.throwIfAborted();
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
    const cancel = () => killGroup(child);
    let interrupted;
    const onSignal = (signal) => {
      interrupted = signal === "SIGINT" ? 130 : 143;
      process.exitCode = interrupted;
      cancel();
    };
    cancellation?.addEventListener("abort", cancel, { once: true });
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
      cancellation?.removeEventListener("abort", cancel);
      resolve({ pid: child.pid, exit: interrupted ?? exit, signal, output, timedOut });
    };
    child.on("error", (error) => { output += String(error.message ?? error); finish(null, null); });
    // "close" once the pipes drain; "exit" plus half a second when a grandchild keeps them open past the kill.
    child.on("close", (exit, signal) => finish(exit, signal));
    child.on("exit", (exit, signal) => setTimeout(() => finish(exit, signal), 500));
  });
}

// Share the drawn lock across worktrees, while still participating in the ordinary machine-slot pool.
export async function acquireDrawnSlot({ directory = "/tmp/scrapkeep-drawn.slots", log = console.error,
  machine = acquireSlot, pollMs = 2000 } = {}) {
  const drawn = await acquireSlot({ directory, slots: 1, pollMs, log: msg => log("display-run waiting: " + msg) });
  try {
    const slot = await machine({ log });
    return { release() { try { slot.release(); } finally { drawn.release(); } } };
  } catch (error) {
    drawn.release();
    throw error;
  }
}

// Runs one Godot script with a window. Returns { exit, output, timedOut, home, supported }. exit is null when the run
// did not start or was killed.
export function runWindowed(options = {}) {
  // The models-render gate is the library caller that draws on the Mac. Its original
  // receipt predates helper markers and judges its own real and planted images.
  if ((options.platform ?? process.platform) === "darwin" && options.script === "res://tools/model_render_check.gd") {
    return macCapture(options, false);
  }
  return runScript(options);
}

async function runScript({
  script,
  args = [],
  engineArgs = [],
  extraEnv = {},
  cwd = root,
  env = process.env,
  binary = env.GODOT_BIN,
  timeoutMs = TIMEOUT_MS,
  platform = process.platform,
  acquire = acquireDrawnSlot,
  start = launch,
} = {}) {
  if (typeof script !== "string" || !script.startsWith("res://")) throw new Error(`display-run: script must be a res:// path, got ${script}`);
  const refused = engineArgs.filter((a) => REFUSED_ENGINE_ARGS.some((r) => a === r || a.startsWith(`${r}=`)));
  if (refused.length) throw new Error(`display-run: refusing engine flag(s) ${refused.join(", ")}`);
  const problem = displayProblem(platform, env);
  if (problem) return { exit: null, output: problem, timedOut: false, home: null, supported: false };
  if (!binary) return { exit: null, output: "GODOT_BIN is not set", timedOut: false, home: null, supported: true };
  const lease = await acquire({ log: console.error });
  let scratch;
  try {
    scratch = scratchEnv(cwd);
    const argv = [...engineArgs, "--path", path.join(cwd, SKETCH), "--script", script, "--", ...args];
    const run = await start(binary, argv, { env: { ...env, ...extraEnv, ...scratch.env }, cwd, timeoutMs });
    return { ...run, exit: run.timedOut ? null : run.exit, home: scratch.home, supported: true };
  } finally {
    lease.release();
    if (scratch && env.KEEP_DISPLAY_HOME !== "1") rmSync(scratch.home, { recursive: true, force: true });
  }
}

const PROBE = "res://tools/offscreen_probe.gd";

function editorVersion(command, options) {
  const r = spawnSync(command, ["--headless", "--version"], { ...options, timeout: 5000, encoding: "utf8" });
  return r.status === 0 ? r.stdout.trim() : "";
}

// Finite probe with a fixed script for the Gate's single notified reference. All other
// CLI runs start with --embedded: Godot draws to a CAMetalLayer with no editor attached.
export function runCapture(options = {}) {
  return macCapture(options, true);
}

async function macCapture({ script, args = [], reference = false, cwd = root, env = process.env,
  engineArgs = [], extraEnv = {},
  platform = process.platform, binary = env.GODOT_BIN, acquire, start = launch,
  observe = watchDrawnRun, version = editorVersion, timeoutMs = TIMEOUT_MS }, requireMarker) {
  if (platform !== "darwin") throw new Error("Mac capture requires macOS; the Linux PC uses gamescope through the Gate");
  if (reference && script !== PROBE) throw new Error("only the W1-131 probe may draw the Gate reference");
  return runScript({
    engineArgs, script, args: script === PROBE ? [...args, "--shots=yard"] : args, cwd, env, platform, binary, acquire, timeoutMs,
    extraEnv: { ...extraEnv, SCRAPKEEP_OFFSCREEN: reference ? "0" : "1" },
    start: async (command, argv, options) => {
      if (!/^4\.7\.2\.stable\.official\.ed1daf0bf/.test(version(command, options))) {
        throw new Error("offscreen: expected the pinned Godot 4.7.2 editor; no drawn run started");
      }
      const flags = ["--rendering-driver", "metal", "--debug", "--skip-breakpoints", "--ignore-error-breaks", "--resolution", "1920x1080", "--audio-driver", "Dummy"];
      // Embedded Godot publishes its layer through EngineDebugger. The local stdout debugger
      // provides that object with no editor, listener or network peer.
      if (!reference) flags.unshift("--embedded");
      const result = await observe(signal => start(command, [...flags, ...argv], { ...options, signal }));
      const w = result.watch;
      const recorded = reference ? w.targetOnScreen > 0 :
        w.onScreen === 0 && w.frontmostChanges === 0 && (!requireMarker || result.output.split(/\r?\n/).includes("OFFSCREEN_WINDOW " + result.pid + " embedded"));
      const pass = result.exit === 0 && !result.timedOut && w.missed === 0 && recorded;
      return { ...result, exit: pass ? 0 : (result.exit || 1) };
    },
  });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  try {
    const [mode, name, separator, ...args] = process.argv.slice(2);
    if (!["--offscreen", "--gate-reference"].includes(mode) || !name || separator !== "--") {
      throw new Error("usage: display-run.mjs --offscreen <script> -- <args>");
    }
    const script = name.startsWith("res://") ? name : "res://" + name;
    let probeFrame;
    if (script === PROBE) {
      const out = args[0]?.slice("--out=".length);
      if (args.length !== 1 || !args[0].startsWith("--out=") || !path.isAbsolute(out)) {
        throw new Error("the probe needs -- --out=<absolute directory>");
      }
      probeFrame = path.join(out, "yard.png");
      if (existsSync(probeFrame)) throw new Error("yard.png already exists; supply a fresh output directory");
    }
    const result = await runCapture({ script, args, reference: mode === "--gate-reference" });
    if (result.output) console.log(result.output.trimEnd());
    if (result.watch) console.log("WINDOW_WATCH " + JSON.stringify(result.watch));
    if (probeFrame && result.exit === 0) {
      const png = readFileSync(probeFrame);
      if (png.toString("hex", 0, 8) !== "89504e470d0a1a0a" || png.readUInt32BE(16) !== 1920 || png.readUInt32BE(20) !== 1080) {
        throw new Error("probe did not write a new 1920x1080 PNG");
      }
    }
    process.exitCode ||= result.exit ?? 1;
  } catch (error) {
    console.error(error.message);
    process.exitCode ||= 1;
  }
}
