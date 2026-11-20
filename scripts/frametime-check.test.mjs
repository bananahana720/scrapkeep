import assert from "node:assert/strict";
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  realpathSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  BUDGET,
  ENGINE_LOG,
  FrametimeError,
  captureMode,
  engineLaunch,
  findOnPath,
  gameArgv,
  logLabel,
  main,
  mangohudConfig,
  missingMangohudMessage,
  parseArgs,
  parseLog,
  parseSelfPlay,
  report,
  resolveTarget,
  summarize,
  worstFrameNear,
} from "./frametime-check.mjs";

const SYSTEM = "os,cpu,gpu,ram,kernel,driver,cpuscheduler\nArch,Ryzen,RTX 4080,64,6.18,580,\n";
const HEADER = "fps,frametime,cpu_load,gpu_load,cpu_temp,gpu_temp,elapsed\n";
const csv = (frames) =>
  SYSTEM + HEADER + frames.map((ms) => `${1000 / ms},${ms},10,20,50,60,0`).join("\n") + "\n";

test("parseArgs keeps the alpha budget by default and passes arguments after -- to the game", () => {
  const args = parseArgs([]);
  assert.equal(args.p99, BUDGET.p99Ms);
  assert.equal(args.hitch, BUDGET.hitchMs);
  assert.equal(args.seconds, 300);
  assert.equal(args.warmup, 10);
  const custom = parseArgs(["--seconds=60", "--hud", "--", "--profile=sitting"]);
  assert.equal(custom.seconds, 60);
  assert.equal(custom.hud, true);
  assert.deepEqual(custom.gameArgs, ["--profile=sitting"]);
  assert.throws(() => parseArgs(["--nope"]), FrametimeError);
  assert.throws(() => parseArgs(["--p99=fast"]), /needs a number/);
  assert.throws(() => parseArgs(["--seconds=0"]), /above 0/);
});

test("the missing-MangoHud message names the Arch install and downloads nothing", () => {
  assert.match(missingMangohudMessage(), /sudo pacman -S mangohud/);
});

test("findOnPath finds only executable files", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "ft-path-"));
  writeFileSync(path.join(dir, "mangohud"), "#!/bin/sh\n");
  assert.equal(findOnPath("mangohud", dir), null);
  chmodSync(path.join(dir, "mangohud"), 0o755);
  assert.equal(findOnPath("mangohud", dir), path.join(dir, "mangohud"));
});

test("resolveTarget prefers --exe, then the installed AppImage, then the newest export", () => {
  const dataHome = mkdtempSync(path.join(os.tmpdir(), "ft-data-"));
  const exports = mkdtempSync(path.join(os.tmpdir(), "ft-export-"));
  assert.throws(() => resolveTarget({ exe: null, dataHome, exports }), /npm run sketch:export/);
  mkdirSync(path.join(exports, "abc1234"));
  writeFileSync(path.join(exports, "abc1234", "core-loop.x86_64"), "");
  assert.equal(
    resolveTarget({ exe: null, dataHome, exports }),
    path.join(exports, "abc1234", "core-loop.x86_64"),
  );
  mkdirSync(path.join(dataHome, "scrapkeep"));
  writeFileSync(path.join(dataHome, "scrapkeep", "Scrapkeep.AppImage"), "");
  assert.equal(
    resolveTarget({ exe: null, dataHome, exports }),
    path.join(dataHome, "scrapkeep", "Scrapkeep.AppImage"),
  );
  assert.throws(() => resolveTarget({ exe: "/no/such/build", dataHome, exports }), /no build at/);
});

test("mangohudConfig logs every frame after the warm-up, vsync off and no overlay by default", () => {
  const config = mangohudConfig({
    outDir: "/o",
    seconds: 300,
    warmup: 10,
    keepVsync: false,
    hud: false,
  });
  assert.equal(
    config,
    "output_folder=/o,autostart_log=10,log_duration=300,log_interval=0,vsync=1,no_display",
  );
  assert.equal(
    mangohudConfig({
      outDir: "/o",
      seconds: 5,
      warmup: 0,
      keepVsync: true,
      hud: true,
    }).includes("vsync"),
    false,
  );
  assert.throws(() => mangohudConfig({ outDir: "/a,b", seconds: 1, warmup: 0 }), /comma/);
});

test("parseLog reads the frametime column below the system block, converting microseconds", () => {
  assert.deepEqual(parseLog(csv([8, 9, 40])), [8, 9, 40]);
  const micro = SYSTEM + HEADER + "125,8000,1,1,1,1,0\n111,9000,1,1,1,1,0\n";
  assert.deepEqual(parseLog(micro), [8, 9]);
  assert.throws(() => parseLog("a,b\n1,2\n"), /no frametime column/);
  assert.throws(() => parseLog(SYSTEM + HEADER), /no frames/);
});

test("summarize passes a steady run and times each hitch from the start of the log", () => {
  const steady = summarize(Array(1000).fill(8));
  assert.equal(steady.pass, true);
  assert.equal(steady.p99_ms, 8);
  const frames = Array(1000).fill(10);
  frames[500] = 60;
  const hitched = summarize(frames);
  assert.equal(hitched.p99_ok, true);
  assert.equal(hitched.hitch_ok, false);
  assert.equal(hitched.pass, false);
  assert.deepEqual(hitched.hitches, [{ at_s: 5, ms: 60 }]);
  assert.equal(hitched.over_severe, 1);
  const slow = summarize([...Array(900).fill(10), ...Array(100).fill(20)]);
  assert.equal(slow.p99_ms, 20);
  assert.equal(slow.p99_ok, false);
});

test("main runs the build under a stand-in mangohud and grades its log", () => {
  const base = mkdtempSync(path.join(os.tmpdir(), "ft-main-"));
  const bin = path.join(base, "bin");
  mkdirSync(bin);
  const game = path.join(base, "core-loop.x86_64");
  writeFileSync(game, "");
  // The stand-in writes a log where MANGOHUD_CONFIG's output_folder points, as MangoHud does.
  const fake = path.join(bin, "mangohud");
  const rows = Array.from({ length: 200 }, () => "125,8,1,1,1,1,0").join("\\n");
  writeFileSync(
    fake,
    `#!/bin/sh\nout=$(printf '%s' "$MANGOHUD_CONFIG" | tr ',' '\\n' | sed -n 's/^output_folder=//p')\n` +
      `printf '${SYSTEM.replace(/\n/g, "\\n")}${HEADER.replace(/\n/g, "\\n")}${rows}\\n' > "$out/core-loop_2026.csv"\n`,
  );
  chmodSync(fake, 0o755);
  const out = path.join(base, "out");
  const log = console.log;
  console.log = () => {};
  try {
    assert.equal(
      main(
        [`--exe=${game}`, "--seconds=1"],
        {
          PATH: [bin, "/usr/bin", "/bin"].join(path.delimiter),
          XDG_DATA_HOME: base,
        },
        out,
      ),
      0,
    );
    assert.equal(main([], { PATH: path.join(base, "empty"), XDG_DATA_HOME: base }, out), 2);
  } finally {
    console.log = log;
  }
});

test("main --log grades an existing log without launching anything", () => {
  const base = mkdtempSync(path.join(os.tmpdir(), "ft-log-"));
  const file = path.join(base, "run.csv");
  writeFileSync(file, csv([...Array(500).fill(8), 45]));
  const out = path.join(base, "out");
  const log = console.log;
  const lines = [];
  console.log = (line) => lines.push(line);
  try {
    assert.equal(main([`--log=${file}`], { PATH: "" }, out), 1);
  } finally {
    console.log = log;
  }
  assert.match(lines.join("\n"), /OVER BUDGET/);
  const [stampDir] = readdirSync(out);
  const summary = JSON.parse(readFileSync(path.join(out, stampDir, "summary.json"), "utf8"));
  assert.equal(summary.over_hitch, 1);
});

test("--self-play passes the flag and its options to the game; the default launch is unchanged", () => {
  const plain = parseArgs(["--", "--profile=sitting"]);
  assert.equal(plain.selfPlay, false);
  assert.deepEqual(gameArgv(plain), ["--profile=sitting"]);
  assert.deepEqual(gameArgv(parseArgs([])), []);
  const self = parseArgs([
    "--self-play",
    "--self-play-from=6",
    "--self-play-seed=2506",
    "--seconds=60",
  ]);
  assert.equal(self.selfPlay, true);
  assert.equal(self.seconds, 60);
  assert.deepEqual(gameArgv(self), [
    "--audio-driver",
    "Dummy",
    "--",
    "--self-play",
    "--self-play-from=6",
    "--self-play-seed=2506",
  ]);
  assert.equal(gameArgv(parseArgs(["--self-play", "--sound"]))[0], "--");
  assert.throws(() => parseArgs(["--self-play-from=6"]), /need --self-play/);
  assert.throws(() => parseArgs(["--self-play", "--self-play-script=res://x.gd"]), /not forwarded/);
});

test("parseSelfPlay reads stage entries on the launch and log clocks, and the stall", () => {
  const text = [
    "boot noise",
    "self-play: stage 1 entered at 12.50 s",
    "self-play: stage 2 entered at 140.25 s",
    "self-play: stage 2 entered (retry) at 150.00 s",
    "self-play: stalled at stage 6 exit at 400.00 s pos 1.0,2.0,-3.5",
  ].join("\n");
  const parsed = parseSelfPlay(text, 10);
  assert.equal(parsed.lines.length, 4);
  assert.deepEqual(
    parsed.stages.map((s) => [s.stage, s.retry, s.launch_s, s.log_s]),
    [
      [1, false, 12.5, 2.5],
      [2, false, 140.25, 130.25],
      [2, true, 150, 140],
    ],
  );
  assert.deepEqual(parsed.stalled, { stage: 6, what: "exit", launch_s: 400, pos: "1.0,2.0,-3.5" });
  assert.equal(parseSelfPlay("nothing", 10).stalled, null);
});

test("worstFrameNear reads the window around a stage entry", () => {
  const frames = Array(1000).fill(10);
  frames[300] = 70;
  frames[900] = 90;
  assert.equal(worstFrameNear(frames, 3), 70);
  assert.equal(worstFrameNear(frames, 9, 1, 0.5), 90);
  assert.equal(worstFrameNear(frames, 6, 0.5, 0.5), 10);
});

function selfPlayRun(exitCode, stdoutLines) {
  const base = mkdtempSync(path.join(os.tmpdir(), "ft-self-"));
  const bin = path.join(base, "bin");
  mkdirSync(bin);
  const game = path.join(base, "core-loop.x86_64");
  writeFileSync(game, "");
  const fake = path.join(bin, "mangohud");
  const rows = Array.from({ length: 200 }, () => "125,8,1,1,1,1,0").join("\\n");
  writeFileSync(
    fake,
    `#!/bin/sh\nout=$(printf '%s' "$MANGOHUD_CONFIG" | tr ',' '\\n' | sed -n 's/^output_folder=//p')\n` +
      `printf '%s\\n' "$@" > "$out/args.txt"\n` +
      `printf '%s\\n%s\\n' "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" > "$out/xdg.txt"\n` +
      `printf '${SYSTEM.replace(/\n/g, "\\n")}${HEADER.replace(/\n/g, "\\n")}${rows}\\n' > "$out/core-loop_2026.csv"\n` +
      stdoutLines.map((line) => `echo '${line}'\n`).join("") +
      `exit ${exitCode}\n`,
  );
  chmodSync(fake, 0o755);
  const out = path.join(base, "out");
  const write = process.stdout.write.bind(process.stdout);
  const log = console.log;
  const lines = [];
  console.log = (line) => lines.push(line);
  process.stdout.write = () => true;
  let code;
  const held = [];
  try {
    code = main(
      [
        `--exe=${game}`,
        "--seconds=1",
        "--self-play",
        "--self-play-from=6",
        "--self-play-stall=100",
      ],
      { PATH: [bin, "/usr/bin", "/bin"].join(path.delimiter), XDG_DATA_HOME: base },
      out,
      undefined,
      () => {
        held.push("taken");
        return { release: () => held.push("released") };
      },
    );
  } finally {
    console.log = log;
    process.stdout.write = write;
  }
  const [stampDir] = readdirSync(out);
  const dir = path.join(out, stampDir);
  // The MangoHud launch takes the quiet hold once and gives it back.
  assert.deepEqual(held, ["taken", "released"]);
  return {
    code,
    lines,
    dir,
    summary: JSON.parse(readFileSync(path.join(dir, "summary.json"), "utf8")),
  };
}

test("main --self-play launches the game with the flag and records the self-play lines", () => {
  const run = selfPlayRun(0, [
    "self-play: stage 6 entered at 10.50 s",
    "self-play: done at 40.00 s",
  ]);
  assert.equal(run.code, 0);
  assert.deepEqual(
    readFileSync(path.join(run.dir, "args.txt"), "utf8").trim().split("\n").slice(1),
    ["--audio-driver", "Dummy", "--", "--self-play", "--self-play-from=6", "--self-play-stall=100"],
  );
  const [data, config] = readFileSync(path.join(run.dir, "xdg.txt"), "utf8").trim().split("\n");
  assert.equal(data, path.join(run.dir, "xdg-data"));
  assert.equal(config, path.join(run.dir, "xdg-config"));
  assert.equal(
    readFileSync(path.join(run.dir, "self-play.log"), "utf8").trim().split("\n").length,
    2,
  );
  assert.equal(run.summary.self_play.exit, 0);
  assert.equal(run.summary.self_play.stages[0].stage, 6);
  assert.equal(run.summary.self_play.stages[0].log_s, 0.5);
  assert.equal(run.summary.self_play.stages[0].worst_frame_ms, 8);
  assert.match(run.lines.join("\n"), /self-play: stage 6 entered at 10.5 s \(log 0.5 s\)/);
});

test("main --self-play fails the check when the game stalls (3) or lacks tools/ (2)", () => {
  const stalled = selfPlayRun(3, ["self-play: stalled at stage 6 exit at 90.00 s pos 1.0,2.0,3.0"]);
  assert.equal(stalled.code, 1);
  assert.deepEqual(stalled.summary.self_play.stalled, {
    stage: 6,
    what: "exit",
    launch_s: 90,
    pos: "1.0,2.0,3.0",
  });
  assert.match(stalled.lines.join("\n"), /STALLED at stage 6 exit/);
  assert.equal(selfPlayRun(2, []).code, 2);
});

// The engine capture (macOS): src/core/frame_log.gd's CSV, read by the same parser.
const ENGINE_CSV = (frames) =>
  "scrapkeep_frame_log,engine,driver,adapter,vsync\nscrapkeep_frame_log,4.7.2.stable,metal,Apple M2 Ultra,0\nframetime\n" +
  frames.map((ms) => ms.toFixed(3)).join("\n") +
  "\n";

test("--capture picks engine or mangohud; without it MangoHud wins where installed, else the engine on macOS", () => {
  assert.equal(parseArgs([]).capture, null);
  assert.equal(parseArgs(["--capture=engine"]).capture, "engine");
  assert.throws(() => parseArgs(["--capture=vulkan"]), /--capture takes engine or mangohud/);
  const base = mkdtempSync(path.join(os.tmpdir(), "ft-mode-"));
  const fake = path.join(base, "mangohud");
  writeFileSync(fake, "#!/bin/sh\n");
  chmodSync(fake, 0o755);
  assert.equal(captureMode(parseArgs([]), "darwin", ""), "engine");
  assert.equal(captureMode(parseArgs([]), "linux", ""), "mangohud");
  assert.equal(captureMode(parseArgs([]), "darwin", base), "mangohud");
  assert.equal(captureMode(parseArgs(["--capture=engine"]), "linux", base), "engine");
  assert.equal(captureMode(parseArgs(["--capture=mangohud"]), "darwin", ""), "mangohud");
});

test("engineLaunch runs the editor on the project windowed, vsync off, with the frame log on the same warmup and seconds", () => {
  const outDir = "/runs/x";
  const self = engineLaunch(
    parseArgs(["--self-play", "--self-play-min=50", "--warmup=10", "--seconds=30"]),
    { outDir, godotBin: "/G/Godot", project: "/p" },
  );
  assert.equal(self.command, "/G/Godot");
  assert.equal(self.csv, path.join(outDir, ENGINE_LOG));
  assert.deepEqual(self.argv, [
    "--path",
    "/p",
    "--windowed",
    "--disable-vsync",
    "--audio-driver",
    "Dummy",
    "--",
    `--frame-log=${self.csv}`,
    "--frame-log-warmup=10",
    "--frame-log-seconds=30",
    "--self-play",
    "--self-play-min=50",
  ]);
  const plain = engineLaunch(parseArgs(["--keep-vsync", "--", "--profile=sitting"]), {
    outDir,
    godotBin: "/G/Godot",
    project: "/p",
  });
  assert.deepEqual(plain.argv, [
    "--path",
    "/p",
    "--windowed",
    "--profile=sitting",
    "--",
    `--frame-log=${plain.csv}`,
    "--frame-log-warmup=10",
    "--frame-log-seconds=300",
  ]);
  const packed = engineLaunch(parseArgs(["--exe=/b/Scrapkeep"]), {
    outDir,
    godotBin: "/G/Godot",
    project: "/p",
  });
  assert.equal(packed.command, "/b/Scrapkeep");
  assert.equal(packed.argv.includes("--path"), false);
});

test("the engine frame log reads through the MangoHud parser, and its label says which it is", () => {
  const text = ENGINE_CSV([8, 8.5, 9, 61]);
  assert.deepEqual(parseLog(text), [8, 8.5, 9, 61]);
  assert.equal(logLabel(text), "Engine frame log");
  assert.equal(logLabel(csv([8])), "MangoHud log");
  assert.match(report(summarize([8]), "x.csv", logLabel(text)), /^Engine frame log: x.csv/);
});

test("main on macOS launches the engine capture under a scratch HOME and grades the game's own log", () => {
  const base = mkdtempSync(path.join(os.tmpdir(), "ft-engine-"));
  // A stand-in editor: writes the CSV where --frame-log= points, and the HOME it was given.
  const fake = path.join(base, "Godot");
  const rows = Array.from({ length: 200 }, () => "8.000").join("\\n");
  writeFileSync(
    fake,
    `#!/bin/sh\nfor a in "$@"; do case "$a" in --frame-log=*) log="\${a#--frame-log=}";; esac; done\n` +
      `printf '%s\\n' "$@" > "$(dirname "$log")/args.txt"\nprintf '%s\\n' "$HOME" > "$(dirname "$log")/home.txt"\n` +
      `printf 'scrapkeep_frame_log,engine\\nscrapkeep_frame_log,4.7.2\\nframetime\\n${rows}\\n' > "$log"\n` +
      `echo 'self-play: stage 1 entered at 12.00 s'\n`,
  );
  chmodSync(fake, 0o755);
  const out = path.join(base, "out");
  const write = process.stdout.write.bind(process.stdout);
  const log = console.log;
  const error = console.error;
  const lines = [];
  console.log = (line) => lines.push(line);
  console.error = (line) => lines.push(line);
  process.stdout.write = () => true;
  let code;
  let missing;
  let reused;
  const held = [];
  // --home lives elsewhere, so the run folder must still be made for the frame log and self-play.log.
  const localRoot = path.resolve(import.meta.dirname, "../artifacts/local");
  mkdirSync(localRoot, { recursive: true });
  const keptHome = mkdtempSync(path.join(localRoot, "frametime-test-home-"));
  const outReused = path.join(base, "out3");
  try {
    // The launch takes the quiet hold once and gives it back; a run that never launches does not take it.
    const quiet = () => {
      held.push("taken");
      return { release: () => held.push("released") };
    };
    code = main(
      ["--self-play", "--seconds=1"],
      { PATH: "/usr/bin:/bin", GODOT_BIN: fake },
      out,
      "darwin",
      quiet,
    );
    missing = main([], { PATH: "/usr/bin:/bin" }, path.join(base, "out2"), "darwin", () =>
      assert.fail("no launch, no hold"),
    );
    assert.throws(
      () =>
        main(
          ["--self-play", "--seconds=1"],
          { PATH: "/usr/bin:/bin", GODOT_BIN: fake },
          path.join(base, "out4"),
          "darwin",
          () => {
            throw new Error("no frame reading taken");
          },
        ),
      (thrown) => thrown instanceof FrametimeError && /no frame reading taken/.test(thrown.message),
    );
    reused = main(
      ["--self-play", "--seconds=1", "--home=" + keptHome],
      { PATH: "/usr/bin:/bin", GODOT_BIN: fake },
      outReused,
      "darwin",
    );
  } finally {
    console.log = log;
    console.error = error;
    process.stdout.write = write;
  }
  assert.equal(code, 0);
  assert.deepEqual(held, ["taken", "released"]);
  assert.equal(missing, 2);
  assert.match(lines.join("\n"), /GODOT_BIN/);
  const [stampDir] = readdirSync(out);
  const dir = path.join(out, stampDir);
  const args = readFileSync(path.join(dir, "args.txt"), "utf8").trim().split("\n");
  assert.deepEqual(args.slice(0, 4), [
    "--path",
    path.resolve(import.meta.dirname, "../sketches/core-loop"),
    "--windowed",
    "--disable-vsync",
  ]);
  assert.ok(args.includes("--self-play"));
  assert.equal(readFileSync(path.join(dir, "home.txt"), "utf8").trim(), path.join(dir, "home"));
  assert.match(lines.join("\n"), /Engine frame log: .*frames\.csv/);
  const summary = JSON.parse(readFileSync(path.join(dir, "summary.json"), "utf8"));
  assert.equal(summary.frames, 200);
  assert.equal(summary.self_play.stages[0].log_s, 2);
  assert.equal(reused, 0);
  const reusedDir = path.join(outReused, readdirSync(outReused)[0]);
  assert.equal(readFileSync(path.join(reusedDir, "home.txt"), "utf8").trim(), keptHome);
  assert.equal(
    JSON.parse(readFileSync(path.join(reusedDir, "summary.json"), "utf8")).cache,
    "reused (--home)",
  );
  rmSync(keptHome, { recursive: true });
});

test("an engine reading says whether it measured a packed build and on what caches", async () => {
  const { engineContext } = await import("./frametime-check.mjs");
  assert.deepEqual(engineContext({ exe: null }, "darwin"), {
    target: "debug-editor",
    cache: "cold",
  });
  assert.deepEqual(engineContext({ exe: "/b/game" }, "linux"), {
    target: "packed",
    cache: "shared",
  });
  assert.deepEqual(engineContext({ exe: "/b/game", home: "/h" }, "darwin"), {
    target: "packed",
    cache: "reused (--home)",
  });
});

test("--home reuses an existing scratch HOME under artifacts/local and refuses any other folder", async () => {
  const { engineHome, parseArgs } = await import("./frametime-check.mjs");
  assert.equal(parseArgs(["--home=/l/run/home"]).home, "/l/run/home");
  assert.equal(parseArgs([]).home, null);
  const base = realpathSync(mkdtempSync(path.join(os.tmpdir(), "home-")));
  const local = path.join(base, "local");
  const kept = path.join(local, "frametime/a/home");
  const outside = path.join(base, "outside");
  mkdirSync(kept, { recursive: true });
  mkdirSync(outside);
  assert.equal(engineHome({ home: null }, "/out", local), "/out/home");
  assert.equal(engineHome({ home: kept }, "/out", local), kept);
  for (const bad of [outside, local, path.join(local, "../outside")])
    assert.throws(() => engineHome({ home: bad }, "/out", local), /under artifacts\/local/);
  assert.throws(
    () => engineHome({ home: path.join(local, "missing") }, "/out", local),
    /no folder/,
  );
  // A link inside artifacts/local that points out of it is refused; one that stays inside is not.
  symlinkSync(outside, path.join(local, "escape"));
  assert.throws(
    () => engineHome({ home: path.join(local, "escape") }, "/out", local),
    /under artifacts\/local/,
  );
  symlinkSync(kept, path.join(local, "inside"));
  assert.equal(engineHome({ home: path.join(local, "inside") }, "/out", local), kept);
  rmSync(base, { recursive: true });
});
