import assert from "node:assert/strict";
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  BUDGET,
  FrametimeError,
  findOnPath,
  main,
  mangohudConfig,
  missingMangohudMessage,
  parseArgs,
  parseLog,
  resolveTarget,
  summarize,
} from "./frametime-check.mjs";

const SYSTEM =
  "os,cpu,gpu,ram,kernel,driver,cpuscheduler\nArch,Ryzen,RTX 4080,64,6.18,580,\n";
const HEADER = "fps,frametime,cpu_load,gpu_load,cpu_temp,gpu_temp,elapsed\n";
const csv = (frames) =>
  SYSTEM +
  HEADER +
  frames.map((ms) => `${1000 / ms},${ms},10,20,50,60,0`).join("\n") +
  "\n";

test("parseArgs keeps the alpha budget by default and passes arguments after -- to the game", () => {
  const args = parseArgs([]);
  assert.equal(args.p99, BUDGET.p99Ms);
  assert.equal(args.hitch, BUDGET.hitchMs);
  assert.equal(args.seconds, 300);
  assert.equal(args.warmup, 10);
  const custom = parseArgs([
    "--seconds=60",
    "--hud",
    "--",
    "--profile=sitting",
  ]);
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
  assert.throws(
    () => resolveTarget({ exe: null, dataHome, exports }),
    /npm run sketch:export/,
  );
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
  assert.throws(
    () => resolveTarget({ exe: "/no/such/build", dataHome, exports }),
    /no build at/,
  );
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
  assert.throws(
    () => mangohudConfig({ outDir: "/a,b", seconds: 1, warmup: 0 }),
    /comma/,
  );
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
    assert.equal(
      main([], { PATH: path.join(base, "empty"), XDG_DATA_HOME: base }, out),
      2,
    );
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
  const summary = JSON.parse(
    readFileSync(path.join(out, stampDir, "summary.json"), "utf8"),
  );
  assert.equal(summary.over_hitch, 1);
});
