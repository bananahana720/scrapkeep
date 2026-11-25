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
export const REFUSED_ENGINE_ARGS = [
  "--headless",
  "--display-driver",
  "--rendering-driver",
  "--path",
];

export function displayProblem(platform = process.platform, env = process.env) {
  if (platform === "darwin") return "";
  if (platform === "linux")
    return env.DISPLAY || env.WAYLAND_DISPLAY
      ? ""
      : "not supported here: no DISPLAY or WAYLAND_DISPLAY (the PC lane is gamescope headless, not built in display-run.mjs)";
  return `not supported here: no display lane for ${platform}`;
}

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
    env: {
      HOME: home,
      XDG_DATA_HOME: path.join(home, "data"),
      XDG_CONFIG_HOME: path.join(home, "config"),
      XDG_CACHE_HOME: path.join(home, "cache"),
    },
  };
}

const killGroup = (child) => {
  try {
    process.kill(-child.pid, "SIGKILL");
  } catch {
    try {
      child.kill("SIGKILL");
    } catch {}
  }
};

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
    child.stdout.on("data", (d) => {
      output += d;
    });
    child.stderr.on("data", (d) => {
      output += d;
    });
    const timer = setTimeout(() => {
      timedOut = true;
      killGroup(child);
    }, timeoutMs);
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
    child.on("error", (error) => {
      output += String(error.message ?? error);
      finish(null, null);
    });
    child.on("close", (exit, signal) => finish(exit, signal));
    child.on("exit", (exit, signal) => setTimeout(() => finish(exit, signal), 500));
  });
}

export async function acquireDrawnSlot({
  directory = "/tmp/scrapkeep-drawn.slots",
  log = console.error,
  machine = acquireSlot,
  pollMs = 2000,
} = {}) {
  const drawn = await acquireSlot({
    directory,
    slots: 1,
    pollMs,
    log: (msg) => log("display-run waiting: " + msg),
  });
  try {
    const slot = await machine({ log });
    return {
      release() {
        try {
          slot.release();
        } finally {
          drawn.release();
        }
      },
    };
  } catch (error) {
    drawn.release();
    throw error;
  }
}

export function runWindowed(options = {}) {
  if ((options.platform ?? process.platform) === "darwin") {
    return macCapture({ ...options, reference: false }, false);
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
  if (typeof script !== "string" || !script.startsWith("res://"))
    throw new Error(`display-run: script must be a res:// path, got ${script}`);
  const refused = engineArgs.filter((a) =>
    REFUSED_ENGINE_ARGS.some((r) => a === r || a.startsWith(`${r}=`)),
  );
  if (refused.length) throw new Error(`display-run: refusing engine flag(s) ${refused.join(", ")}`);
  const problem = !headless && displayProblem(platform, env);
  if (problem)
    return { exit: null, output: problem, timedOut: false, home: null, supported: false };
  if (!binary)
    return {
      exit: null,
      output: "GODOT_BIN is not set",
      timedOut: false,
      home: null,
      supported: true,
    };
  const lease = await acquire({ log: console.error });
  let scratch;
  let interrupted;
  try {
    scratch = scratchEnv(cwd);
    const argv = [
      ...(headless ? ["--headless"] : []),
      ...engineArgs,
      "--path",
      path.join(cwd, SKETCH),
      "--script",
      script,
      "--",
      ...args,
    ];
    const run = await start(binary, argv, {
      env: { ...env, ...extraEnv, ...scratch.env },
      cwd,
      timeoutMs,
    });
    interrupted = run.interrupted;
    return { ...run, exit: run.timedOut ? null : run.exit, home: scratch.home, supported: true };
  } finally {
    lease.release();
    if (scratch && env.KEEP_DISPLAY_HOME !== "1")
      rmSync(scratch.home, { recursive: true, force: true });
    if (interrupted) process.exit(interrupted);
  }
}

const PROBE = "res://tools/offscreen_probe.gd";

const watchedTools = new Map([
  [
    "res://tools/water_flow_stills.gd",
    {
      "tools/water_flow_stills.gd":
        "ff44fb28395b723f5b76599d55326bba172b55a52c9498ab316bf33d06ce121c",
      "tools/offscreen_window.gd":
        "c9da9cb92150ed33095b65a3c2f0dce419b6c2c4736990743226a8f9efd83f4d",
    },
  ],
  [
    PROBE,
    {
      "tools/offscreen_probe.gd":
        "156464df4c44b25ba4f903f6786557bdff94a71b89f033744c0021f5d734819b",
      "tools/dam_look_capture.gd":
        "7573ff8e14d4d770c580c2c023bacf348968b2756a287001b082552cc6640f13",
      "tools/offscreen_window.gd":
        "c9da9cb92150ed33095b65a3c2f0dce419b6c2c4736990743226a8f9efd83f4d",
    },
  ],
]);

function hasWatchedVersion(script, cwd) {
  const files = watchedTools.get(script);
  if (!files) return false;
  return Object.entries(files).every(([file, hash]) => {
    const source = path.join(cwd, SKETCH, file);
    return (
      existsSync(source) && createHash("sha256").update(readFileSync(source)).digest("hex") === hash
    );
  });
}

function checkCaptureEngineArgs(argv) {
  for (let i = 0; i < argv.length; i += 2) {
    const [key, value] = argv.slice(i, i + 2);
    if (key === "--resolution" && /^\d+x\d+$/.test(value)) continue;
    if (key === "--audio-driver" && value === "Dummy") continue;
    throw new Error("display-run: refusing engine flag " + key);
  }
}

export async function measureFrame(
  file,
  reference,
  {
    cwd = root,
    env = process.env,
    binary = env.GODOT_BIN,
    acquire = acquireSlot,
    start = launch,
  } = {},
) {
  if (!path.isAbsolute(file) || (reference !== undefined && !path.isAbsolute(reference))) {
    throw new Error("--measure requires absolute PNG paths");
  }
  const args = ["--measure=" + file];
  if (reference !== undefined) args.push("--reference=" + reference);
  return runScript({ script: PROBE, args, cwd, env, binary, acquire, start, headless: true });
}

function editorVersion(command, options) {
  const r = spawnSync(command, ["--headless", "--version"], {
    ...options,
    timeout: 5000,
    encoding: "utf8",
  });
  return r.status === 0 ? r.stdout.trim() : "";
}

export function runCapture(options = {}) {
  return macCapture(options, true);
}

async function macCapture(
  {
    script,
    args = [],
    reference = false,
    cwd = root,
    env = process.env,
    engineArgs = [],
    extraEnv = {},
    platform = process.platform,
    binary = env.GODOT_BIN,
    acquire,
    start = launch,
    observe = watchDrawnRun,
    version = editorVersion,
    timeoutMs = TIMEOUT_MS,
  },
  requireMarker,
) {
  if (platform !== "darwin")
    throw new Error("Mac capture requires macOS; the Linux PC uses gamescope through the Gate");
  if (reference && script !== PROBE)
    throw new Error("only the W1-131 probe may draw the Gate reference");
  checkCaptureEngineArgs(engineArgs);
  const refusal = new Error(
    "Mac capture refused before launch: no watched qualification for this script version: " +
      script,
  );
  const refused = {
    exit: null,
    supported: false,
    timedOut: false,
    home: null,
    output: refusal.message,
  };
  if (!hasWatchedVersion(script, cwd)) return refused;
  const verifyBeforeSpawn = () => {
    if (!hasWatchedVersion(script, cwd)) throw refusal;
  };
  return runScript({
    engineArgs,
    script,
    args: script === PROBE ? [...args, "--shots=yard"] : args,
    cwd,
    env,
    platform,
    binary,
    acquire,
    timeoutMs,
    extraEnv: { ...extraEnv, SCRAPKEEP_OFFSCREEN: reference ? "0" : "1" },
    start: async (command, argv, options) => {
      verifyBeforeSpawn();
      if (!/^4\.7\.2\.stable\.official\.ed1daf0bf/.test(version(command, options))) {
        throw new Error("offscreen: expected the pinned Godot 4.7.2 editor; no drawn run started");
      }
      const flags = [
        "--rendering-driver",
        "metal",
        "--debug",
        "--skip-breakpoints",
        "--ignore-error-breaks",
        "--resolution",
        "1920x1080",
        "--audio-driver",
        "Dummy",
      ];
      if (!reference) flags.unshift("--embedded");
      const result = await observe((signal) => {
        verifyBeforeSpawn();
        return start(command, [...flags, ...argv], { ...options, signal });
      });
      const w = result.watch;
      const recorded = reference
        ? w.targetOnScreen > 0
        : w.onScreen === 0 &&
          w.frontmostChanges === 0 &&
          (!requireMarker ||
            result.output.split(/\r?\n/).includes("OFFSCREEN_WINDOW " + result.pid + " embedded"));
      if (result.timedOut || w.missed !== 0 || !recorded) {
        const message =
          "display-run: invalid capture; see window counts and helper acknowledgement";
        const output = requireMarker ? result.output + "\n" + message : message;
        return { ...result, output, exit: result.exit || 1 };
      }
      return result;
    },
  }).catch((error) => {
    if (error === refusal) return refused;
    throw error;
  });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  try {
    const [mode, name, separator, ...args] = process.argv.slice(2);
    if (mode === "--measure") {
      if (
        !name ||
        (separator === undefined
          ? args.length !== 0
          : separator !== "--reference" || args.length !== 1)
      ) {
        throw new Error(
          "usage: display-run.mjs --measure <absolute PNG> [--reference <absolute PNG>]",
        );
      }
      const result = await measureFrame(name, args[0]);
      console.log(result.output.trimEnd());
      process.exitCode ||= result.exit ?? 1;
    } else {
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
        if (existsSync(probeFrame))
          throw new Error("yard.png already exists; supply a fresh output directory");
      }
      const result = await runCapture({ script, args, reference: mode === "--gate-reference" });
      if (result.output) console.log(result.output.trimEnd());
      if (result.watch) console.log("WINDOW_WATCH " + JSON.stringify(result.watch));
      if (probeFrame && result.exit === 0) {
        const png = readFileSync(probeFrame);
        if (
          png.toString("hex", 0, 8) !== "89504e470d0a1a0a" ||
          png.readUInt32BE(16) !== 1920 ||
          png.readUInt32BE(20) !== 1080
        ) {
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
