import { spawnSync } from "node:child_process";
import {
  accessSync,
  constants,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  realpathSync,
  statSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { userDataEnv } from "./godot-home.mjs";
import { holdQuietSync } from "./sketch-smoke.mjs";

// node scripts/frametime-check.mjs: plays the exported build under MangoHud, logs every frame and
// reports whether frame times stay inside the alpha budget (sketches/core-loop/BUG-BAR.md).
// It launches, in order: --exe=<path>, the installed AppImage (~/.local/share/scrapkeep/
// Scrapkeep.AppImage), or core-loop.x86_64 in the newest artifacts/local/core-loop-export/<run>/.
// Logging starts after --warmup seconds (default 10, past boot) and runs --seconds (default 300);
// play through, then quit after the log ends. Output: artifacts/local/frametime/<stamp>/ with
// MangoHud's CSV and summary.json. --log=<csv> skips the launch and reads an existing log.
// --p99=<ms> (default 16.7) and --hitch=<ms> (default 33) set the budget; --keep-vsync leaves the
// player's vsync on, --hud shows the overlay. Arguments after -- go to the game.
// --self-play launches the game with its bot (src/game.gd --self-play; the pack must carry tools/:
// npm run sketch:export -- --self-play) and any --self-play-<name>=<v> flag goes with it. The game's
// "self-play:" lines are kept in self-play.log and summary.json (stage entries as seconds since
// launch and in the MangoHud log's own time, with the worst frame from 1 s before to 5 s after
// each). Keep the log alive to its end: --self-play-min=<warmup + seconds + 10>. A self-play run is
// silent; --sound keeps its audio.
// A self-play game runs on its own XDG data and config under the run folder (xdg-data, xdg-config).
// A self-play game that exits non-zero (1 run ended early, 2 no tools/ in the pack, 3 stalled)
// fails the check with exit 1, or 2 for code 2.
// Exit 0 inside budget, 1 over it, 2 when nothing was measured. Never downloads anything.
// A reading that launches the game holds the machine quiet for as long as the game runs: it waits (up to 45 min, then
// exit 2) for sketch:smoke and sketch:fast runs on the shared slot pool to finish, and no runner on this machine
// takes a slot until the game exits (a new sketch:fast still runs its lint and node checks before it waits). A
// reading killed by a signal leaves a hold that dies with its process. It does not see a running gate, nightly run, red team, band read or export, so
// do not start a reading during one. Grading a log (--log=) takes no hold; FRAMETIME_NO_QUIET=1 skips it.
// --capture=engine|mangohud picks how frames are caught (captureMode). Without it: MangoHud when
// mangohud is on PATH, else the engine on macOS (no MangoHud there), else MangoHud's install note.
// The engine capture launches $GODOT_BIN --path sketches/core-loop (or --exe=<a packed build's
// binary>) windowed, with Godot's --disable-vsync unless --keep-vsync, and the game's own frame log
// (src/core/frame_log.gd, --frame-log=<csv>) on the same warmup and seconds; the CSV it writes is
// read as MangoHud's is. Each such run has scratch XDG data under the run folder, so its saves
// start empty; on macOS HOME moves there too, so the shader and pipeline caches also start empty
// and shader compiles fall in the log unless the warmup covers them. Without --exe the engine runs
// the project as a debug run, so that reading is not comparable with a packed build's. --hud has no engine overlay and is refused there.
// --home=<dir> (engine capture) reuses an earlier run's scratch HOME, a folder under artifacts/local/,
// so on macOS its shader and pipeline caches and its user:// carry over (engineHome).

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const exportRoot = path.join(root, "artifacts/local/core-loop-export");
const outRoot = path.join(root, "artifacts/local/frametime");
const projectDir = path.join(root, "sketches/core-loop");
export const EXECUTABLE = "core-loop.x86_64";
export const ENGINE_LOG = "frames.csv";
export const CAPTURES = ["engine", "mangohud"];
export const BUDGET = { p99Ms: 16.7, hitchMs: 33, severeMs: 50 };

export class FrametimeError extends Error {}

export function parseArgs(argv) {
  const args = {
    exe: null,
    log: null,
    seconds: 300,
    warmup: 10,
    p99: BUDGET.p99Ms,
    hitch: BUDGET.hitchMs,
    keepVsync: false,
    hud: false,
    sound: false,
    selfPlay: false,
    capture: null,
    home: null,
    selfPlayArgs: [],
    gameArgs: [],
  };
  const number = (arg, name) => {
    const value = Number(arg.slice(name.length + 3));
    if (!Number.isFinite(value) || value < 0)
      throw new FrametimeError(`--${name} needs a number: ${arg}`);
    return value;
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--") {
      args.gameArgs = argv.slice(i + 1);
      break;
    } else if (arg.startsWith("--exe=")) args.exe = arg.slice("--exe=".length);
    else if (arg.startsWith("--log=")) args.log = arg.slice("--log=".length);
    else if (arg.startsWith("--seconds="))
      args.seconds = number(arg, "seconds");
    else if (arg.startsWith("--warmup=")) args.warmup = number(arg, "warmup");
    else if (arg.startsWith("--p99=")) args.p99 = number(arg, "p99");
    else if (arg.startsWith("--hitch=")) args.hitch = number(arg, "hitch");
    else if (arg.startsWith("--home=")) args.home = arg.slice("--home=".length);
    else if (arg === "--keep-vsync") args.keepVsync = true;
    else if (arg === "--hud") args.hud = true;
    else if (arg === "--sound") args.sound = true;
    else if (arg === "--self-play") args.selfPlay = true;
    else if (arg.startsWith("--capture=")) {
      args.capture = arg.slice("--capture=".length);
      if (!CAPTURES.includes(args.capture))
        throw new FrametimeError(`--capture takes ${CAPTURES.join(" or ")}: ${arg}`);
    }
    else if (arg.startsWith("--self-play-script="))
      throw new FrametimeError("--self-play-script= is a test override of the game and is not forwarded");
    else if (/^--self-play-[a-z]+=/.test(arg)) args.selfPlayArgs.push(arg);
    else throw new FrametimeError("unknown argument: " + arg);
  }
  if (args.seconds === 0) throw new FrametimeError("--seconds must be above 0");
  if (args.selfPlayArgs.length > 0 && !args.selfPlay)
    throw new FrametimeError("--self-play-<name>=<v> flags need --self-play");
  return args;
}

// The game's argv: the plain list after -- by default (a person is playing, so sound stays on);
// with --self-play the run is silent unless --sound, so it never plays over a live session, and
// the flag and its options follow a leading -- so the game reads them as user args.
export function gameArgv(args) {
  if (!args.selfPlay) return args.gameArgs;
  const engine = args.sound ? [] : ["--audio-driver", "Dummy"];
  return [...engine, "--", "--self-play", ...args.selfPlayArgs, ...args.gameArgs];
}

export function selfPlayXdg(outDir) {
  const data = path.join(outDir, "xdg-data");
  const config = path.join(outDir, "xdg-config");
  mkdirSync(data, { recursive: true });
  mkdirSync(config, { recursive: true });
  return { XDG_DATA_HOME: data, XDG_CONFIG_HOME: config };
}

// The "self-play:" lines of a game's stdout, as stage entries (seconds since launch) plus the
// stall line if any. at is the MangoHud log's own time: launch seconds less the warmup.
export function parseSelfPlay(text, warmup = 0) {
  const lines = text.split(/\r?\n/).filter((line) => line.startsWith("self-play:"));
  const stages = [];
  let stalled = null;
  for (const line of lines) {
    const entered = line.match(/^self-play: stage (\d+) entered( \(retry\))? at ([\d.]+) s/);
    if (entered)
      stages.push({
        stage: Number(entered[1]),
        retry: Boolean(entered[2]),
        launch_s: Number(entered[3]),
        log_s: round(Number(entered[3]) - warmup),
      });
    const stall = line.match(/^self-play: stalled at stage (\d+) (\w+) at ([\d.]+) s pos (\S+)/);
    if (stall)
      stalled = { stage: Number(stall[1]), what: stall[2], launch_s: Number(stall[3]), pos: stall[4] };
  }
  return { lines, stages, stalled };
}

// The worst frame (ms) from before s before to after s after a stage entry, on the log's clock.
export function worstFrameNear(frames, logS, before = 1, after = 5) {
  let elapsed = 0;
  let worst = 0;
  for (const ms of frames) {
    const at = elapsed / 1000;
    if (at >= logS - before && at <= logS + after && ms > worst) worst = ms;
    elapsed += ms;
  }
  return round(worst);
}

export function findOnPath(name, envPath = process.env.PATH ?? "") {
  for (const dir of envPath.split(path.delimiter).filter(Boolean)) {
    const file = path.join(dir, name);
    try {
      accessSync(file, constants.X_OK);
      if (statSync(file).isFile()) return file;
    } catch {
      // not here
    }
  }
  return null;
}

// The one place the capture is chosen: --capture=, else MangoHud wherever it is installed, else
// the engine's own log on macOS, where MangoHud does not exist.
export function captureMode(args, platform = process.platform, envPath = process.env.PATH ?? "") {
  if (args.capture) return args.capture;
  if (findOnPath("mangohud", envPath)) return "mangohud";
  return platform === "darwin" ? "engine" : "mangohud";
}

// The engine capture's command: the editor binary on the project, or --exe=<packed build binary>;
// windowed, vsync off unless --keep-vsync, and the frame log's flags first among the user args.
export function engineLaunch(args, { outDir, godotBin, project = projectDir }) {
  const csv = path.join(outDir, ENGINE_LOG);
  const flags = [`--frame-log=${csv}`, `--frame-log-warmup=${args.warmup}`, `--frame-log-seconds=${args.seconds}`];
  const game = gameArgv(args);
  const split = game.indexOf("--");
  const user = split < 0 ? [...game, "--", ...flags] : [...game.slice(0, split + 1), ...flags, ...game.slice(split + 1)];
  const engine = [...(args.exe ? [] : ["--path", project]), "--windowed", ...(args.keepVsync ? [] : ["--disable-vsync"])];
  return { command: args.exe ? path.resolve(args.exe) : godotBin, argv: [...engine, ...user], csv };
}

export function missingMangohudMessage() {
  return [
    "MangoHud is not installed (no mangohud on PATH).",
    "MangoHud is a Linux overlay that shows and logs frame times for Vulkan and OpenGL games.",
    "Install it from the Arch extra repository, then run this again:",
    "",
    "  sudo pacman -S mangohud",
    "",
  ].join("\n");
}

function newestExportExe(directory) {
  if (!existsSync(directory)) return null;
  const found = readdirSync(directory)
    .map((name) => path.join(directory, name, EXECUTABLE))
    .filter((file) => existsSync(file))
    .sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
  return found[0] ?? null;
}

export function resolveTarget({ exe, dataHome, exports = exportRoot }) {
  if (exe) {
    if (!existsSync(exe)) throw new FrametimeError("no build at --exe=" + exe);
    return path.resolve(exe);
  }
  const appImage = path.join(dataHome, "scrapkeep", "Scrapkeep.AppImage");
  if (existsSync(appImage)) return appImage;
  const exported = newestExportExe(exports);
  if (exported) return exported;
  throw new FrametimeError(
    "no build found: no installed AppImage at " +
      appImage +
      " and no " +
      EXECUTABLE +
      " under " +
      exports +
      ". Run npm run sketch:export first, or pass --exe=<path>.",
  );
}

// MangoHud reads MANGOHUD_CONFIG as comma-separated key=value pairs, so a comma in the folder
// would split it. log_interval=0 logs every frame; vsync=1 means off (Vulkan only), matching
// perf_bench's vsync-off bench so the budget measures headroom, not the display's refresh.
export function mangohudConfig({ outDir, seconds, warmup, keepVsync, hud }) {
  if (outDir.includes(","))
    throw new FrametimeError(
      "the output folder cannot contain a comma: " + outDir,
    );
  const pairs = [
    "output_folder=" + outDir,
    "autostart_log=" + warmup,
    "log_duration=" + seconds,
    "log_interval=0",
  ];
  if (!keepVsync) pairs.push("vsync=1");
  if (!hud) pairs.push("no_display");
  return pairs.join(",");
}

// MangoHud's CSV opens with a system block (os,cpu,gpu,...), then a header row naming
// frametime, then one row per frame. Frame time is milliseconds in current MangoHud; a median
// above 1000 can only be microseconds, so that log is converted.
export function parseLog(text) {
  const lines = text.split(/\r?\n/);
  const headerAt = lines.findIndex((line) =>
    line.split(",").some((cell) => cell.trim().toLowerCase() === "frametime"),
  );
  if (headerAt < 0)
    throw new FrametimeError("no frametime column in the MangoHud log");
  const column = lines[headerAt]
    .split(",")
    .findIndex((cell) => cell.trim().toLowerCase() === "frametime");
  const frames = [];
  for (const line of lines.slice(headerAt + 1)) {
    const value = Number(line.split(",")[column]);
    if (line.trim() && Number.isFinite(value) && value > 0) frames.push(value);
  }
  if (frames.length === 0)
    throw new FrametimeError("the MangoHud log has no frames");
  const sorted = [...frames].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)] > 1000
    ? frames.map((v) => v / 1000)
    : frames;
}

function percentile(sorted, p) {
  return sorted[Math.min(sorted.length - 1, Math.ceil(p * sorted.length) - 1)];
}

const round = (value) => Math.round(value * 100) / 100;

// Each hitch carries its time from the start of the log, so it can be matched to what was on screen.
export function summarize(
  frames,
  {
    p99Ms = BUDGET.p99Ms,
    hitchMs = BUDGET.hitchMs,
    severeMs = BUDGET.severeMs,
  } = {},
) {
  const sorted = [...frames].sort((a, b) => a - b);
  const hitches = [];
  let elapsed = 0;
  for (const ms of frames) {
    if (ms > hitchMs)
      hitches.push({ at_s: round(elapsed / 1000), ms: round(ms) });
    elapsed += ms;
  }
  const p99 = percentile(sorted, 0.99);
  return {
    frames: frames.length,
    seconds: round(elapsed / 1000),
    p50_ms: round(percentile(sorted, 0.5)),
    p95_ms: round(percentile(sorted, 0.95)),
    p99_ms: round(p99),
    max_ms: round(sorted[sorted.length - 1]),
    over_hitch: hitches.length,
    over_severe: hitches.filter((h) => h.ms > severeMs).length,
    hitches,
    budget: { p99_ms: p99Ms, hitch_ms: hitchMs },
    p99_ok: p99 <= p99Ms,
    hitch_ok: hitches.length === 0,
    pass: p99 <= p99Ms && hitches.length === 0,
  };
}

// The engine's log opens with its own info row; any other log is MangoHud's.
export function logLabel(text) {
  return text.startsWith("scrapkeep_frame_log,") ? "Engine frame log" : "MangoHud log";
}

export function report(summary, source, label = "MangoHud log") {
  const ok = (flag) => (flag ? "ok  " : "OVER");
  const lines = [
    `${label}: ${source}`,
    `${summary.frames} frames over ${summary.seconds} s. p50 ${summary.p50_ms} ms, p95 ${summary.p95_ms} ms, max ${summary.max_ms} ms.`,
    `${ok(summary.p99_ok)} p99 frame time ${summary.p99_ms} ms (budget ${summary.budget.p99_ms} ms)`,
    `${ok(summary.hitch_ok)} frames over ${summary.budget.hitch_ms} ms: ${summary.over_hitch} (over 50 ms: ${summary.over_severe})`,
  ];
  for (const hitch of summary.hitches.slice(0, 20))
    lines.push(`       at ${hitch.at_s} s: ${hitch.ms} ms`);
  if (summary.hitches.length > 20)
    lines.push(
      `       and ${summary.hitches.length - 20} more in summary.json`,
    );
  lines.push(
    summary.pass
      ? "PASS: frame times stay inside the alpha budget."
      : "OVER BUDGET: see BUG-BAR.md to grade it.",
  );
  return lines.join("\n");
}

export function newestLog(directory) {
  if (!existsSync(directory)) return null;
  const found = readdirSync(directory)
    .filter((name) => name.endsWith(".csv") && !name.endsWith("_summary.csv"))
    .map((name) => path.join(directory, name))
    .sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
  return found[0] ?? null;
}

function stamp(date = new Date()) {
  return date
    .toISOString()
    .replace(/[:.]/g, "-")
    .replace(/-\d{3}Z$/, "Z");
}

// What a reading measured: a packed build or a debug run of the project, on warm or cold caches.
// With --home on macOS the caches are an earlier run's: "reused", not proven warm.
export function engineContext(args, platform = process.platform) {
  const cache = platform !== "darwin" ? "shared" : args.home ? "reused (--home)" : "cold";
  return { target: args.exe ? "packed" : "debug-editor", cache };
}

export function engineHome(args, outDir, localRoot = path.join(root, "artifacts/local")) {
  if (!args.home) return path.join(outDir, "home");
  if (!existsSync(args.home)) throw new FrametimeError("no folder at --home=" + args.home);
  const home = realpathSync(args.home);
  const rel = path.relative(existsSync(localRoot) ? realpathSync(localRoot) : path.resolve(localRoot), home);
  if (rel === "" || rel.startsWith("..") || path.isAbsolute(rel))
    throw new FrametimeError("--home must be a folder under artifacts/local/: " + args.home);
  return home;
}

function analyse(logFile, args, outDir, selfPlay = null, context = null) {
  const text = readFileSync(logFile, "utf8");
  const frames = parseLog(text);
  const summary = summarize(frames, {
    p99Ms: args.p99,
    hitchMs: args.hitch,
  });
  let extra = {};
  const notes = [];
  if (selfPlay) {
    const stages = selfPlay.stages.map((entry) => ({
      ...entry,
      worst_frame_ms: worstFrameNear(frames, entry.log_s),
    }));
    extra = {
      self_play: { exit: selfPlay.exit, stages, stalled: selfPlay.stalled, lines: selfPlay.lines },
    };
    for (const entry of stages)
      notes.push(
        `self-play: stage ${entry.stage}${entry.retry ? " (retry)" : ""} entered at ${entry.launch_s} s (log ${entry.log_s} s), worst frame ${entry.worst_frame_ms} ms from 1 s before to 5 s after`,
      );
    if (selfPlay.stalled)
      notes.push(
        `self-play: STALLED at stage ${selfPlay.stalled.stage} ${selfPlay.stalled.what} at ${selfPlay.stalled.launch_s} s pos ${selfPlay.stalled.pos}`,
      );
    notes.push(`self-play: game exit ${selfPlay.exit}`);
  }
  mkdirSync(outDir, { recursive: true });
  writeFileSync(
    path.join(outDir, "summary.json"),
    JSON.stringify({ log: logFile, ...summary, ...extra, ...(context ?? {}) }, null, 2) + "\n",
  );
  console.log(report(summary, logFile, logLabel(text)));
  if (context)
    console.log(
      `Measured: ${context.target === "packed" ? "a packed build" : "a debug run of the project (not the packed build)"}, ${context.cache} shader caches.`,
    );
  for (const note of notes) console.log(note);
  console.log("Summary: " + path.join(outDir, "summary.json"));
  if (selfPlay && selfPlay.exit !== 0) return selfPlay.exit === 2 ? 2 : 1;
  return summary.pass ? 0 : 1;
}

export function main(
  argv = process.argv.slice(2),
  env = process.env,
  out = outRoot,
  platform = process.platform,
  quiet = null,
) {
  const args = parseArgs(argv);
  const outDir = path.join(out, stamp());
  if (args.log) return analyse(path.resolve(args.log), args, outDir);
  if (captureMode(args, platform, env.PATH) === "engine") return engineCapture(args, env, outDir, platform, quiet);

  const mangohud = findOnPath("mangohud", env.PATH);
  if (!mangohud) {
    console.error(missingMangohudMessage());
    return 2;
  }
  const dataHome = env.XDG_DATA_HOME || path.join(os.homedir(), ".local/share");
  const target = resolveTarget({ exe: args.exe, dataHome });
  mkdirSync(outDir, { recursive: true });
  const config = mangohudConfig({ outDir, ...args });
  const minutes = Math.round(((args.warmup + args.seconds) / 60) * 10) / 10;
  console.log(`Launching ${target} under MangoHud.`);
  console.log(
    `Logging starts ${args.warmup} s after launch and runs ${args.seconds} s. Play normally for about ${minutes} min, then quit.`,
  );
  // A self-play game's stdout is read for its "self-play:" lines and echoed; otherwise it is inherited.
  // A self-play game saves into its own XDG data and config under the run folder, never the player's
  // (the cache stays shared, so shader compiles are not part of the measure).
  const launch = { env: { ...env, MANGOHUD_CONFIG: config, ...(args.selfPlay ? selfPlayXdg(outDir) : {}) } };
  const run = launchQuiet(quiet, () =>
    spawnSync(
      mangohud,
      [target, ...gameArgv(args)],
      args.selfPlay
        ? { ...launch, stdio: ["inherit", "pipe", "inherit"], maxBuffer: 256 * 1024 * 1024, encoding: "utf8" }
        : { ...launch, stdio: "inherit" },
    ),
  );
  return collect(
    run,
    args,
    outDir,
    `MangoHud wrote no log in ${outDir}. Quit before the log ended, or MangoHud did not attach. Run again and play past ${minutes} min.`,
  );
}

// After the game closes, either capture: keep the self-play lines, then grade the run folder's log.
function collect(run, args, outDir, noLogMessage, context = null) {
  if (run.error)
    throw new FrametimeError("could not launch: " + run.error.message);
  let selfPlay = null;
  if (args.selfPlay) {
    process.stdout.write(run.stdout ?? "");
    selfPlay = { ...parseSelfPlay(run.stdout ?? "", args.warmup), exit: run.status };
    writeFileSync(path.join(outDir, "self-play.log"), selfPlay.lines.join("\n") + "\n");
  }
  const logFile = newestLog(outDir);
  if (!logFile) {
    if (selfPlay) console.error(`self-play: game exit ${selfPlay.exit}${selfPlay.stalled ? ", stalled at stage " + selfPlay.stalled.stage : ""}`);
    console.error(noLogMessage);
    return 2;
  }
  return analyse(logFile, args, outDir, selfPlay, context);
}

function launchQuiet(quiet, launch) {
  if (!quiet) return launch();
  let held;
  try {
    held = quiet();
  } catch (error) {
    throw new FrametimeError(error.message);
  }
  try {
    return launch();
  } finally {
    held.release();
  }
}

function engineCapture(args, env, outDir, platform, quiet) {
  if (args.hud) throw new FrametimeError("--hud is MangoHud's overlay; the engine capture has none");
  const godotBin = env.GODOT_BIN;
  if (!args.exe && !(godotBin && existsSync(godotBin))) {
    console.error("The engine capture needs GODOT_BIN set to the Godot 4.7.2 editor binary, or --exe=<a packed build's binary>.");
    return 2;
  }
  if (args.exe && !existsSync(args.exe)) throw new FrametimeError("no build at --exe=" + args.exe);
  const home = engineHome(args, outDir);
  mkdirSync(outDir, { recursive: true });
  mkdirSync(home, { recursive: true });
  const { command, argv, csv } = engineLaunch(args, { outDir, godotBin });
  const minutes = Math.round(((args.warmup + args.seconds) / 60) * 10) / 10;
  console.log(`Launching ${command} with the engine's frame log.`);
  console.log(
    `Logging starts ${args.warmup} s after launch and runs ${args.seconds} s. Play normally for about ${minutes} min, then quit.`,
  );
  // The game's user:// lives under this HOME on macOS (scripts/godot-home.mjs), never the player's.
  const launch = { env: { ...env, ...userDataEnv(home, platform) } };
  const run = launchQuiet(quiet, () =>
    spawnSync(
      command,
      argv,
      args.selfPlay
        ? { ...launch, stdio: ["inherit", "pipe", "inherit"], maxBuffer: 256 * 1024 * 1024, encoding: "utf8" }
        : { ...launch, stdio: "inherit" },
    ),
  );
  return collect(
    run,
    args,
    outDir,
    `The game wrote no frame log at ${csv}. It closed before the log ended, or the build has no src/core/frame_log.gd. Run again and play past ${minutes} min.`,
    engineContext(args, platform),
  );
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    process.exitCode = main(
      undefined,
      undefined,
      undefined,
      undefined,
      process.env.FRAMETIME_NO_QUIET === "1" ? null : holdQuietSync,
    );
  } catch (error) {
    if (!(error instanceof FrametimeError)) throw error;
    console.error(error.message);
    process.exitCode = 2;
  }
}
