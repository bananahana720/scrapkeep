// W1-144a. Read artifacts without starting a game. Each mode is one independent diagnostic.
//   node scripts/handover-frame-probe.mjs frames <frametime-check run directory>
//   node scripts/handover-frame-probe.mjs shutdown <ordered Godot stdout+stderr from launch to exit>
// For frames use --capture=engine, a warmed scratch HOME, --self-play-watch=1 and --self-play-until=win.
// Capture shutdown at the engine process. frametime-check buffers stdout and inherits stderr,
// and the user:// Godot log can close before the particle shader destructor reports its error.
// Exit 0 if the selected check passes, 1 for a measured miss, 2 for missing or unusable evidence.
import { readFileSync } from "node:fs";
import path from "node:path";
import { withoutTeardownNoise } from "./sketch-smoke.mjs";
import { parseLog } from "./frametime-check.mjs";

function frameWindows(directory) {
  const read = (name) => readFileSync(path.join(directory, name), "utf8");
  const run = JSON.parse(read("summary.json"));
  if (run.cache !== "reused (--home)" || run.target !== "debug-editor")
    throw new Error("expected a warm debug-editor capture");
  if (run.self_play?.exit !== 0 || run.self_play.stalled)
    throw new Error("self-play failed to finish cleanly");
  const csv = read("frames.csv");
  if (!/^scrapkeep_frame_log,[^\n]+,metal,[^\n]+,/im.test(csv))
    throw new Error("expected Mac Metal engine frames");
  const frames = parseLog(csv);
  if (frames.length !== run.frames) throw new Error("frame count differs from summary.json");
  const stages = run.self_play.stages;
  const flume = stages.find((entry) => entry.stage === 2 && !entry.retry);
  const bowl = run.self_play.lines.find((line) => line.startsWith("self-play: boss arena entered at "));
  const bowlMatch = bowl?.match(/^self-play: boss arena entered at ([\d.]+) s$/);
  if (!flume || !bowlMatch || !stages.some((entry) => entry.stage === 1) ||
      stages.some((entry) => entry.retry) || Number(bowlMatch[1]) <= flume.launch_s)
    throw new Error("expected one uninterrupted dam, flume and Slag Bowl ride with watch enabled");
  const warmup = flume.launch_s - flume.log_s;
  const durationMs = frames.reduce((sum, ms) => sum + ms, 0);
  const result = {};
  for (const [name, seconds] of [["dam_to_flume", flume.log_s], ["flume_to_bowl", Number(bowlMatch[1]) - warmup]]) {
    // Same one second before and five seconds after entry as frametime-check. Include a
    // frame straddling either boundary and compare the original millisecond precision.
    const start = (seconds - 1) * 1000;
    const end = (seconds + 5) * 1000;
    if (!Number.isFinite(seconds) || start < 0 || end > durationMs)
      throw new Error("incomplete frame window for " + name);
    let elapsed = 0;
    let maximum = 0;
    for (const ms of frames) {
      if (elapsed < end && elapsed + ms > start) maximum = Math.max(maximum, ms);
      elapsed += ms;
    }
    result[name] = maximum;
  }
  return { max_frame_ms: result, pass: Object.values(result).every((ms) => ms <= 33.3) };
}

function shutdown(file) {
  const log = readFileSync(file, "utf8");
  if (!/^Metal .*Apple/m.test(log)) throw new Error("expected a drawn Mac Metal run");
  const end = /^self-play: run won at [\d.]+ s$/m.exec(log);
  if (!end || !/^self-play: boss arena entered at [\d.]+ s$/m.test(log.slice(0, end.index)))
    throw new Error("missing boss entry or victory before shutdown");
  // The shared macOS rule skips dummy-renderer RIDs only. A live Metal RID is evidence.
  const errors = withoutTeardownNoise(log.slice(end.index), "darwin").split(/\r?\n/)
    .filter((line) => /^(?:SCRIPT )?ERROR:/.test(line));
  return { shutdown_error_lines: errors.length, errors, pass: errors.length === 0 };
}

try {
  const [mode, input, ...extra] = process.argv.slice(2);
  if (!input || extra.length || !["frames", "shutdown"].includes(mode))
    throw new Error("usage: handover-frame-probe.mjs frames <directory> | shutdown <complete engine log>");
  const result = mode === "frames" ? frameWindows(input) : shutdown(input);
  console.log(JSON.stringify(result));
  process.exitCode = result.pass ? 0 : 1;
} catch (error) {
  console.error(error.message);
  process.exitCode = 2;
}
