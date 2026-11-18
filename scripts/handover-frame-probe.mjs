// W1-144a. Read artifacts without starting a game. Each mode is one independent diagnostic.
//   node scripts/handover-frame-probe.mjs native <watched two-pass handover log with DISPLAY_RUN_EXIT>
//   node scripts/handover-frame-probe.mjs frames <frame capture directory> <ordered engine log>
//   node scripts/handover-frame-probe.mjs shutdown <ordered Godot stdout+stderr from launch to exit>
// On the Mac only a qualified tool through display-run.mjs --offscreen may produce the
// frame capture. Read its frames.csv, frametime-compatible summary.json and ordered log.
// Use a matched warm scratch HOME, --self-play-watch=1 and --self-play-until=win.
// Use --self-play-beat=0.5 and finish the CSV during play so the next beat bounds its end.
// For a clean shutdown append "GODOT_EXIT <status>" after the child exits and both streams close.
// Capture shutdown at the engine process. A parent may buffer stdout and inherit stderr,
// and the user:// Godot log can close before the particle shader destructor reports its error.
// Exit 0 if the selected check passes, 1 for a measured miss, 2 for missing or unusable evidence.
import { readFileSync } from "node:fs";
import path from "node:path";
import { withoutTeardownNoise } from "./sketch-smoke.mjs";
import { ENGINE_LOG } from "./frametime-check.mjs";

function rideTimes(lines) {
  const events = ["stage 1 entered", "stage 1 exit taken", "stage 2 entered", "stage 2 exit taken", "boss arena entered", "run won"];
  const times = [];
  for (const line of lines) {
    const event = /^self-play: (stage [12] (?:entered|exit taken)|boss arena entered|run won) at ([\d.]+) s$/.exec(line);
    if (!event) continue;
    const seconds = Number(event[2]);
    if (event[1] !== events[times.length] || !Number.isFinite(seconds) || seconds < times.at(-1))
      throw new Error("out of order or repeated ride markers");
    times.push(seconds);
  }
  if (times.length !== events.length) throw new Error("ride must take both exits and win with watch enabled");
  return times;
}

function frameWindows(directory, log) {
  const read = (name) => readFileSync(path.join(directory, name), "utf8");
  const run = JSON.parse(read("summary.json"));
  if (run.cache !== "reused (--home)" || run.target !== "debug-editor")
    throw new Error("expected a debug-editor capture reusing the cold pass home");
  if (run.self_play?.exit !== 0 || run.self_play.stalled || run.self_play.stages.some((s) => s.retry))
    throw new Error("expected one successful ride without retries");
  const lines = run.self_play.lines;
  if (lines.some((line) => line.startsWith("self-play: film "))) throw new Error("film markers use simulation time");
  const [, , flume, , bowl] = rideTimes(lines);
  // The engine CSV has one millisecond value per draw. MangoHud can use other
  // units, so do not apply its median-based conversion to an engine stall.
  const [schema, device, column, ...samples] = read(ENGINE_LOG).trimEnd().split(/\r?\n/);
  if (schema !== "scrapkeep_frame_log,engine,driver,adapter,vsync" ||
      !/^scrapkeep_frame_log,[^,]+,metal,[^,]+,/i.test(device) || column !== "frametime")
    throw new Error("expected Mac Metal engine frames");
  const frames = samples.map(Number);
  if (!frames.length || frames.some((ms) => !Number.isFinite(ms) || ms <= 0))
    throw new Error("invalid drawn frame interval");
  const written = `SCRAPKEEP_FRAME_LOG ${frames.length} frames ${run.log}`;
  const raw = log.split(/\r?\n/);
  const marker = raw.indexOf(written);
  if (frames.length !== run.frames || marker < 0 ||
      raw.filter((line) => line.startsWith("self-play:")).join("\n") !== lines.join("\n"))
    throw new Error("expected the complete engine log from the same frame capture");

  // CSV zero is the draw preceding the first logged interval, not necessarily the
  // requested warmup. The last draw is no later than the first beat after the CSV write.
  const nextBeat = raw.slice(marker + 1).find((line) => /^self-play: beat [\d.]+ s /.test(line));
  if (!nextBeat) throw new Error("need a wall-clock beat after the CSV write");
  const stage = run.self_play.stages.find((entry) => entry.stage === 2);
  const warmupMs = (flume - stage.log_s) * 1000;
  const total = frames.reduce((sum, ms) => sum + ms, 0);
  // Self-play reads whole milliseconds, prints entry times to 0.01 s and beats
  // to 0.1 s. Allow 1 ms of clock granularity plus half the printed unit.
  const entrySlackMs = 6;
  const beatSlackMs = 51;
  const earliest = Math.max(0, warmupMs - frames[0] - entrySlackMs);
  const latest = Number(nextBeat.split(" ")[2]) * 1000 + beatSlackMs - total;
  if (!(earliest <= latest)) throw new Error("inconsistent CSV and ride clocks");

  const result = {};
  for (const [name, seconds] of [["dam_to_flume", flume], ["flume_to_bowl", bowl]]) {
    // Entry stamps are rounded to 0.01 s. Bound the maximum for every possible
    // clock alignment, using the union and intersection of the six-second windows.
    const first = seconds * 1000 - latest - entrySlackMs;
    const last = seconds * 1000 - earliest + entrySlackMs;
    if (first < 1000 || last + 5000 > total) throw new Error("incomplete window for " + name);
    let elapsed = 0;
    let lower = 0;
    let upper = 0;
    for (const ms of frames) {
      if (elapsed < last + 5000 && elapsed + ms > first - 1000) upper = Math.max(upper, ms);
      if (elapsed < first + 5000 && elapsed + ms > last - 1000) lower = Math.max(lower, ms);
      elapsed += ms;
    }
    result[name] = { lower, upper };
  }
  const bounds = Object.values(result);
  const pass = bounds.some(({lower}) => lower > 33.3) ? false :
    bounds.every(({upper}) => upper <= 33.3) ? true : null;
  return { max_frame_ms_bounds: result, pass };
}

// Unlike the archived engine CSV, this capture timestamps the stage signals and the
// ends of drawn frames with one monotonic microsecond clock. Grade only pass two.
function nativeCapture(file) {
  const lines = readFileSync(file, "utf8").trimEnd().split(/\r?\n/);
  if (!lines.some(line => /^Metal .*Apple/.test(line)) ||
      !lines.some(line => /^OFFSCREEN_WINDOW [1-9]\d* embedded$/.test(line)) ||
      lines.at(-1) !== "DISPLAY_RUN_EXIT 0" || !lines.at(-2)?.startsWith("WINDOW_WATCH "))
    throw new Error("need a complete watched Mac capture and successful launcher exit");
  const watch = JSON.parse(lines.at(-2).slice("WINDOW_WATCH ".length));
  if (watch.periodMs !== 50 || !(watch.samples >= 2) ||
      [watch.missed, watch.onScreen, watch.targetOnScreen, watch.frontmostChanges].some(n => n !== 0))
    throw new Error("invalid window watcher receipt");
  const rows = lines.filter(line => line.startsWith("W144_START ") || line.startsWith("W144_PASS "));
  if (rows.length !== 4 || rows[0] !== "W144_START 1" || rows[2] !== "W144_START 2" ||
      !rows[1].startsWith("W144_PASS ") || !rows[3].startsWith("W144_PASS "))
    throw new Error("need one cold ride followed by one warm ride");
  const passes = [1, 2].map(number => {
    const row = JSON.parse(rows[number * 2 - 1].slice("W144_PASS ".length));
    if (row.profiled !== false) throw new Error("need an uninstrumented capture for a budget verdict");
    if (row.pass_number !== number || typeof row.planted !== "boolean" || (number === 1 && row.planted))
      throw new Error("invalid pass identity");
    const maxima = {};
    const entryFrames = {};
    for (const name of ["dam_to_flume", "flume_to_bowl"]) {
      const { entry_us: entry, intervals_us: intervals } = row.seams[name];
      const left = entry - 1_000_000;
      const right = entry + 5_000_000;
      if (!Number.isSafeInteger(entry) || !intervals.length ||
          intervals[0][0] > left || intervals.at(-1)[1] < right)
        throw new Error("incomplete native window for " + name);
      let worst = 0;
      let previous = intervals[0][0];
      for (const [a, b] of intervals) {
        if (![a, b].every(Number.isSafeInteger) || a !== previous || b <= a || b <= left || a >= right)
          throw new Error("invalid or missing drawn interval at " + name);
        worst = Math.max(worst, b - a);
        if (a <= entry && entry < b) entryFrames[name] = (b - a) / 1000;
        previous = b;
      }
      maxima[name] = worst / 1000;
    }
    if (row.seams.dam_to_flume.entry_us >= row.seams.flume_to_bowl.entry_us)
      throw new Error("reversed handovers");
    return { pass_number: number, planted: row.planted, max_frame_ms: maxima, entry_frame_ms: entryFrames };
  });
  const afterWarmWin = lines.slice(lines.indexOf(rows[3]) + 1).join("\n");
  const controlledQuit = /^W144_RELEASE /m.test(afterWarmWin);
  const errors = withoutTeardownNoise(afterWarmWin, "darwin").split("\n").filter(line => /^(?:SCRIPT )?ERROR:/.test(line));
  const framePass = Object.values(passes[1].max_frame_ms).every(ms => ms <= 33.3);
  const shutdownPass = controlledQuit ? null : !errors.length;
  return { passes, frame_pass: framePass, shutdown_pass: shutdownPass, shutdown_error_lines: errors.length, errors,
    pass: framePass ? shutdownPass : false };
}

function shutdown(file) {
  const log = readFileSync(file, "utf8").replaceAll("\r\n", "\n");
  if (!/^Metal .*Apple/m.test(log)) throw new Error("expected a drawn Mac Metal run");
  rideTimes(log.split(/\r?\n/));
  const end = /^self-play: run won at [\d.]+ s$/m.exec(log);
  // The shared macOS rule skips dummy-renderer RIDs only. A live Metal RID is evidence.
  const errors = withoutTeardownNoise(log.slice(end.index), "darwin").split(/\r?\n/)
    .filter((line) => /^(?:SCRIPT )?ERROR:/.test(line));
  if (!errors.length && log.trimEnd().split(/\r?\n/).at(-1) !== "GODOT_EXIT 0")
    throw new Error("missing clean process exit recorded after both streams closed");
  return { shutdown_error_lines: errors.length, errors, pass: errors.length === 0 };
}

try {
  const [mode, input, engineLog, ...extra] = process.argv.slice(2);
  if (!input || extra.length || !["frames", "shutdown", "native"].includes(mode) || (mode === "frames") !== Boolean(engineLog))
    throw new Error("usage: handover-frame-probe.mjs frames <directory> <engine log> | shutdown <engine log> | native <watched log>");
  const result = mode === "frames" ? frameWindows(input, readFileSync(engineLog, "utf8")) : mode === "native" ? nativeCapture(input) : shutdown(input);
  console.log(JSON.stringify(result));
  process.exitCode = result.pass === null ? 2 : result.pass ? 0 : 1;
} catch (error) {
  console.error(error.message);
  process.exitCode = 2;
}
