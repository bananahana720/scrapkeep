// Run a pixel-producing script with scratch saves, a machine slot and an exclusive drawn-run lock.
// On the Mac, --offscreen uses the native embedded Metal display and a 50 ms window watcher.
// Mac callers need a watched qualification for each tool. All drawn Mac runs must use the embedded display.
// Linux library callers supply their own display (the PC uses headless gamescope).
import { createHash } from "node:crypto";
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
      resolve({ pid: child.pid, exit: interrupted ?? exit, interrupted, signal, output, timedOut });
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
  if ((options.platform ?? process.platform) === "darwin") {
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
  headless = false,
} = {}) {
  if (typeof script !== "string" || !script.startsWith("res://")) throw new Error(`display-run: script must be a res:// path, got ${script}`);
  const refused = engineArgs.filter((a) => REFUSED_ENGINE_ARGS.some((r) => a === r || a.startsWith(`${r}=`)));
  if (refused.length) throw new Error(`display-run: refusing engine flag(s) ${refused.join(", ")}`);
  const problem = !headless && displayProblem(platform, env);
  if (problem) return { exit: null, output: problem, timedOut: false, home: null, supported: false };
  if (!binary) return { exit: null, output: "GODOT_BIN is not set", timedOut: false, home: null, supported: true };
  const lease = await acquire({ log: console.error });
  let scratch;
  let interrupted;
  try {
    scratch = scratchEnv(cwd);
    const argv = [...(headless ? ["--headless"] : []), ...engineArgs, "--path", path.join(cwd, SKETCH), "--script", script, "--", ...args];
    const run = await start(binary, argv, { env: { ...env, ...extraEnv, ...scratch.env }, cwd, timeoutMs });
    interrupted = run.interrupted;
    return { ...run, exit: run.timedOut ? null : run.exit, home: scratch.home, supported: true };
  } finally {
    lease.release();
    if (scratch && env.KEEP_DISPLAY_HOME !== "1") rmSync(scratch.home, { recursive: true, force: true });
    if (interrupted) process.exit(interrupted);
  }
}

const PROBE = "res://tools/offscreen_probe.gd";

// Each admitted tool version has a kept Mac watcher receipt. During the owning subtask,
// the candidate registration and its watched trial stay on that subtask's isolated branch.
// Keep the receipt before admitting the registration to the stage. A helper marker alone
// does not qualify a tool. The probe inherits the dam capture, so pin both scripts.
const watchedTools = new Map([
  ["res://tools/look_harness.gd", {
    "tools/look_harness.gd": "b9125ab224f8798c57ce7c238b4d1012652c6d18b9cd57ab353a81f67a242595",
    "tools/look_subjects.gd": "4df4ff493cd8259f498e43901ef573e4423637da8a8952cdd656b21016e49bad",
    "tools/offscreen_window.gd": "c9da9cb92150ed33095b65a3c2f0dce419b6c2c4736990743226a8f9efd83f4d",
    "tests/workshop/push.gd": "f233cec8d830d14f3aeaaff0931b8a649763bfb30a107036a6a1533fd17d2cce",
  }],
  [PROBE, {
    // proof/W1-131 at 2c2dfa665, artifacts/proof/W1-131a/capture.json
    "tools/offscreen_probe.gd": "156464df4c44b25ba4f903f6786557bdff94a71b89f033744c0021f5d734819b",
    "tools/dam_look_capture.gd": "157820aa32157a3dfb1374f852acdc8c0659d87b02307c1ed58377ad7a59c6b4",
    "tools/offscreen_window.gd": "c9da9cb92150ed33095b65a3c2f0dce419b6c2c4736990743226a8f9efd83f4d",
  }],
]);

function hasWatchedVersion(script, cwd) {
  const files = watchedTools.get(script);
  if (!files) return false;
  return Object.entries(files).every(([file, hash]) => {
    const source = path.join(cwd, SKETCH, file);
    return existsSync(source) && createHash("sha256").update(readFileSync(source)).digest("hex") === hash;
  });
}

// Whitelist engine options used by capture callers. An injected --script or project
// selector would run a different entry point after qualification.
function checkCaptureEngineArgs(argv) {
  for (let i = 0; i < argv.length; i += 2) {
    const [key, value] = argv.slice(i, i + 2);
    if (key === "--resolution" && /^\d+x\d+$/.test(value)) continue;
    if (key === "--audio-driver" && value === "Dummy") continue;
    throw new Error("display-run: refusing engine flag " + key);
  }
}

export async function measureFrame(file, reference, { cwd = root, env = process.env,
  binary = env.GODOT_BIN, acquire = acquireSlot, start = launch } = {}) {
  if (!path.isAbsolute(file) || (reference !== undefined && !path.isAbsolute(reference))) {
    throw new Error("--measure requires absolute PNG paths");
  }
  const args = ["--measure=" + file];
  if (reference !== undefined) args.push("--reference=" + reference);
  return runScript({ script: PROBE, args, cwd, env, binary, acquire, start, headless: true });
}

function editorVersion(command, options) {
  const r = spawnSync(command, ["--headless", "--version"], { ...options, timeout: 5000, encoding: "utf8" });
  return r.status === 0 ? r.stdout.trim() : "";
}

// Draw to a Metal layer without an editor or ordinary Mac window.
export function runCapture(options = {}) {
  return macCapture(options, true);
}

async function macCapture({ script, args = [], reference = false, cwd = root, env = process.env,
  engineArgs = [], extraEnv = {},
  platform = process.platform, binary = env.GODOT_BIN, acquire, start = launch,
  observe = watchDrawnRun, version = editorVersion, timeoutMs = TIMEOUT_MS }, requireMarker) {
  if (platform !== "darwin") throw new Error("Mac capture requires macOS; the Linux PC uses gamescope through the Gate");
  if (reference) throw new Error("Mac capture requires --offscreen; the visible reference has already been taken");
  checkCaptureEngineArgs(engineArgs);
  const refusal = new Error("Mac capture refused before launch: no watched qualification for this script version: " + script);
  const refused = { exit: null, supported: false, timedOut: false, home: null, output: refusal.message };
  if (!hasWatchedVersion(script, cwd)) return refused;
  // Both the machine slot and the first watcher sample may take time. Recheck the
  // files after each wait, immediately before the corresponding Godot invocation.
  const verifyBeforeSpawn = () => {
    if (!hasWatchedVersion(script, cwd)) throw refusal;
  };
  return runScript({
    engineArgs, script, args: script === PROBE ? [...args, "--shots=yard"] : args, cwd, env, platform, binary, acquire, timeoutMs,
    extraEnv: { ...extraEnv, SCRAPKEEP_OFFSCREEN: "1" },
    start: async (command, argv, options) => {
      verifyBeforeSpawn();
      if (!/^4\.7\.2\.stable\.official\.ed1daf0bf/.test(version(command, options))) {
        throw new Error("offscreen: expected the pinned Godot 4.7.2 editor; no drawn run started");
      }
      const flags = ["--embedded", "--rendering-driver", "metal", "--debug", "--skip-breakpoints", "--ignore-error-breaks", "--resolution", "1920x1080", "--audio-driver", "Dummy"];
      // Embedded Godot publishes its layer through EngineDebugger. The local stdout debugger
      // provides that object with no editor, listener or network peer.
      const result = await observe(signal => {
        verifyBeforeSpawn();
        return start(command, [...flags, ...argv], { ...options, signal });
      });
      const w = result.watch;
      const recorded = w.onScreen === 0 && w.frontmostChanges === 0 && (!requireMarker || result.output.split(/\r?\n/).includes("OFFSCREEN_WINDOW " + result.pid + " embedded"));
      if (result.timedOut || w.missed !== 0 || !recorded) {
        // The models-render producer reads SUMMARY even when its planted compare exits 1.
        // A run with invalid display evidence cannot supply that producer with a verdict.
        const message = "display-run: invalid capture; see window counts and helper acknowledgement";
        const output = requireMarker ? result.output + "\n" + message : message;
        return { ...result, output, exit: result.exit || 1 };
      }
      return result;
    },
  }).catch(error => {
    if (error === refusal) return refused;
    throw error;
  });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  try {
    const [mode, name, separator, ...args] = process.argv.slice(2);
    if (mode === "--measure") {
      if (!name || (separator === undefined ? args.length !== 0 : separator !== "--reference" || args.length !== 1)) {
        throw new Error("usage: display-run.mjs --measure <absolute PNG> [--reference <absolute PNG>]");
      }
      const result = await measureFrame(name, args[0]);
      console.log(result.output.trimEnd());
      process.exitCode ||= result.exit ?? 1;
    } else {
      if (mode !== "--offscreen" || !name || separator !== "--") {
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
      const result = await runCapture({ script, args });
      if (result.output) console.log(result.output.trimEnd());
      if (result.watch) console.log("WINDOW_WATCH " + JSON.stringify(result.watch));
      if (probeFrame && result.exit === 0) {
        const png = readFileSync(probeFrame);
        if (png.toString("hex", 0, 8) !== "89504e470d0a1a0a" || png.readUInt32BE(16) !== 1920 || png.readUInt32BE(20) !== 1080) {
          throw new Error("probe did not write a new 1920x1080 PNG");
        }
      }
      process.exitCode ||= result.exit ?? 1;
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode ||= 1;
  }
}
