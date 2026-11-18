import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("./handover-frame-probe.mjs", import.meta.url));
const events = [
  "self-play: stage 1 entered at 2.00 s",
  "self-play: stage 1 exit taken at 11.99 s",
  "self-play: stage 2 entered at 12.00 s",
  "self-play: stage 2 exit taken at 23.99 s",
  "self-play: boss arena entered at 24.00 s",
];
function scratch(t) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "handover-frame-test-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return dir;
}

function probe(...args) {
  const result = spawnSync(process.execPath, [cli, ...args], { encoding: "utf8" });
  assert.ifError(result.error);
  return result;
}

test("a planted 50 ms frame fails only the crossing in which it occurs", (t) => {
  const dir = scratch(t);
  const csv = path.join(dir, "frames.csv");
  const log = path.join(dir, "engine.log");
  const lines = [...events, "self-play: beat 35.1 s stage 2 boss", "self-play: run won at 49.00 s"];
  const count = 2500;
  writeFileSync(log, [...events, `SCRAPKEEP_FRAME_LOG ${count} frames ${csv}`, ...lines.slice(events.length)].join("\n"));
  writeFileSync(path.join(dir, "summary.json"), JSON.stringify({
    cache: "reused (--home)", target: "debug-editor", frames: count, log: csv,
    self_play: { exit: 0, stages: [{ stage: 2, log_s: 2 }], lines },
  }));

  // Logging begins at 10 s. Flume entry is 2 s into the CSV, bowl entry is 14 s in.
  for (const [spike, flume, bowl] of [[-1, 10, 10], [200, 50, 10], [1400, 10, 50]]) {
    const samples = Array(count).fill(10);
    if (spike >= 0) samples[spike] = 50;
    writeFileSync(csv, ["scrapkeep_frame_log,engine,driver,adapter,vsync",
      "scrapkeep_frame_log,4.7.2,metal,Apple M5 Max,0", "frametime", ...samples].join("\n"));
    const result = probe("frames", dir, log);
    const pass = spike < 0;
    assert.equal(result.status, pass ? 0 : 1, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), {
      max_frame_ms_bounds: {
        dam_to_flume: { lower: flume, upper: flume },
        flume_to_bowl: { lower: bowl, upper: bowl },
      }, pass,
    });
  }
});

test("shutdown requires a drained clean exit and distinguishes a renderer error from truncation", (t) => {
  const log = path.join(scratch(t), "engine.log");
  const ride = ["Metal 4 - Apple M5 Max", ...events, "self-play: run won at 49.00 s"];
  for (const newline of ["\n", "\r\n"]) {
    writeFileSync(log, [...ride, ""].join(newline));
    const truncated = probe("shutdown", log);
    assert.equal(truncated.status, 2);
    assert.match(truncated.stderr, /missing clean process exit/);

    writeFileSync(log, [...ride, "GODOT_EXIT 0", ""].join(newline));
    const clean = probe("shutdown", log);
    assert.equal(clean.status, 0, clean.stderr);
    assert.equal(JSON.parse(clean.stdout).shutdown_error_lines, 0);

    writeFileSync(log, [...ride, "ERROR: shader was never freed", "GODOT_EXIT 0", ""].join(newline));
    const fault = probe("shutdown", log);
    assert.equal(fault.status, 1, fault.stderr);
    assert.deepEqual(JSON.parse(fault.stdout).errors, ["ERROR: shader was never freed"]);
  }
});

test("the watched capture grades the warm drawn intervals and rejects a gap or invalid watcher", t => {
  const file = path.join(scratch(t), "watched.log");
  const watch = { periodMs: 50, samples: 800, missed: 0, onScreen: 0, targetOnScreen: 0, frontmostChanges: 0 };
  function seam(entry, plant) {
    const intervals = [];
    for (let a = entry - 1_000_000; a < entry + 5_000_000;) {
      const b = a + (a === entry && plant ? 50_000 : 10_000);
      intervals.push([a, b]);
      a = b;
    }
    return { entry_us: entry, intervals_us: intervals };
  }
  const pass = (number, plant) => ({ pass_number: number, planted: number === 2 && plant, seams: {
    dam_to_flume: seam(number * 30_000_000, plant),
    flume_to_bowl: seam(number * 30_000_000 + 10_000_000, false),
  } });
  function run(warm, error = "", watcher = watch) {
    writeFileSync(file, ["Metal 4 - Apple M5 Max", "OFFSCREEN_WINDOW 42 embedded",
      "W144_START 1", "W144_PASS " + JSON.stringify(pass(1, true)),
      "W144_START 2", "W144_PASS " + JSON.stringify(warm), error,
      "WINDOW_WATCH " + JSON.stringify(watcher), "DISPLAY_RUN_EXIT 0"].join("\n"));
    return probe("native", file);
  }
  assert.equal(run(pass(2, false)).status, 0);
  const planted = run(pass(2, true));
  assert.equal(planted.status, 1);
  assert.deepEqual(JSON.parse(planted.stdout).passes[1].max_frame_ms, { dam_to_flume: 50, flume_to_bowl: 10 });
  assert.equal(run(pass(2, false), "ERROR: shader still in use").status, 1);
  assert.equal(run(pass(2, false), "", { ...watch, missed: 1 }).status, 2);
  const missing = pass(2, false);
  missing.seams.flume_to_bowl.intervals_us.splice(60, 1);
  assert.equal(run(missing).status, 2);
});
