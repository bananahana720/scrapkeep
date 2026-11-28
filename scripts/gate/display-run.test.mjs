import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test, { after } from "node:test";

import { acquireDrawnSlot, launch, measureFrame, runCapture, runWindowed } from "./display-run.mjs";
import { watchDrawnRun, windowCounts } from "./window-watch.mjs";

const script = "res://tools/offscreen_probe.gd";
const version = () => "4.7.2.stable.official.ed1daf0bf";
const lease = async () => ({ release() {} });
const sample = (at, front = 4, visible = [], godot = [], missed = 0) => ({
  at,
  front,
  visible,
  godot,
  missed,
});
const clean = [sample(0), sample(50), sample(100)];
const GUARD = { timeout: 30_000 };
function capture(cwd, samples = clean) {
  const tools = path.join(cwd, "sketches/core-loop/tools");
  mkdirSync(tools, { recursive: true });
  for (const file of ["offscreen_probe.gd", "dam_look_capture.gd", "offscreen_window.gd"]) {
    copyFileSync(
      new URL("../../sketches/core-loop/tools/" + file, import.meta.url),
      path.join(tools, file),
    );
  }
  return {
    script,
    cwd,
    platform: "darwin",
    env: {},
    binary: "/test/godot",
    version,
    acquire: lease,
    start: async () => ({
      exit: 0,
      pid: 12,
      output: "OFFSCREEN_WINDOW 12 embedded\n",
      timedOut: false,
    }),
    observe: async (run) => ({ ...(await run()), watch: windowCounts(samples, 12) }),
  };
}
const scratchDirs = [];
after(() => {
  for (const dir of scratchDirs) rmSync(dir, { recursive: true, force: true });
});
function scratch() {
  const dir = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-capture-test-"));
  scratchDirs.push(dir);
  return dir;
}

test("the probe uses embedded Metal before the project is loaded, with a scratch home", async () => {
  const opts = capture(scratch());
  let saved;
  const r = await runCapture({
    ...opts,
    start: async (bin, argv, context) => {
      saved = { argv, env: context.env };
      return opts.start();
    },
  });
  assert.equal(r.exit, 0);
  assert.deepEqual(saved.argv.slice(0, 10), [
    "--embedded",
    "--rendering-driver",
    "metal",
    "--debug",
    "--skip-breakpoints",
    "--ignore-error-breaks",
    "--resolution",
    "1920x1080",
    "--audio-driver",
    "Dummy",
  ]);
  assert.equal(saved.env.SCRAPKEEP_OFFSCREEN, "1");
  assert.ok(saved.env.HOME.startsWith(path.join(opts.cwd, "artifacts/local/display-run/home-")));
});

test("the watcher rejects focus changes, visible children, missing periods and missing helper", async () => {
  const cwd = scratch();
  for (const plant of [
    sample(50, 12),
    sample(50, 4, [], [99]),
    sample(102, 4, [], [], 1),
    sample(50, 4, [12]),
  ]) {
    assert.equal((await runCapture(capture(cwd, [sample(0), plant]))).exit, 1);
  }
  const otherApps = [sample(0, 4), sample(50, 7), sample(100, 4)];
  assert.equal((await runCapture(capture(cwd, otherApps))).exit, 0);
  assert.equal(
    windowCounts([...otherApps, sample(150, 12), sample(200, 12), sample(250, 4)], 12)
      .frontmostChanges,
    1,
  );
  const opts = capture(cwd);
  assert.equal(
    (await runCapture({ ...opts, start: async () => ({ ...(await opts.start()), output: "" }) }))
      .exit,
    1,
  );
  assert.throws(() => windowCounts([sample(0)], 12), /lacks/);
});

test("the Gate reference needs a visible sample for its own process and the pinned executable", async () => {
  const cwd = scratch();
  const plant = capture(cwd, [sample(0), sample(50, 12, [12], [12])]);
  const r = await runCapture({
    ...plant,
    reference: true,
    start: async (bin, argv, options) => {
      assert.ok(!argv.includes("--embedded"));
      assert.equal(options.env.SCRAPKEEP_OFFSCREEN, "0");
      return plant.start();
    },
  });
  assert.equal(r.exit, 0);
  assert.equal(r.watch.targetOnScreen, 1);
  assert.equal(r.watch.frontmostChanges, 1);
  const unrelated = capture(cwd, [sample(0), sample(50, 9, [99], [99])]);
  assert.equal((await runCapture({ ...unrelated, reference: true })).exit, 1);
  await assert.rejects(
    runCapture({ ...plant, version: () => "4.5", start: assert.fail }),
    /pinned/,
  );
  await assert.rejects(
    runCapture({ ...plant, reference: true, script: "res://other.gd", start: assert.fail }),
    /only the W1-131 probe/,
  );
});

test(
  "two drawn runs wait for one lock across worktrees and have disjoint start/end times",
  GUARD,
  async () => {
    const directory = scratch();
    const notices = [];
    const events = [];
    let contend;
    const contended = new Promise((resolve) => (contend = resolve));
    const acquire = () =>
      acquireDrawnSlot({
        directory,
        machine: lease,
        pollMs: 8,
        log: (msg) => {
          notices.push(msg);
          if (msg.includes("waiting for a machine slot")) contend();
        },
      });
    async function draw() {
      const opts = capture(scratch());
      const result = await runCapture({
        ...opts,
        acquire,
        start: async () => {
          events.push("start");
          if (events.length === 1) await contended;
          else contend();
          events.push("end");
          return opts.start();
        },
      });
      assert.equal(result.exit, 0);
    }
    await Promise.all([draw(), draw()]);
    assert.deepEqual(events, ["start", "end", "start", "end"]);
    assert.ok(notices.some((msg) => msg.includes("waiting for a machine slot")));
  },
);

test(
  "losing the sampler aborts a still-running group before releasing the drawn slot",
  GUARD,
  async (t) => {
    const row = JSON.stringify(sample(Date.now()));
    const runPid = path.join(scratch(), "run.pid");
    let samplerChild;
    let samplerPid;
    t.after(() => {
      if (samplerChild && samplerChild.exitCode === null && samplerChild.signalCode === null)
        samplerChild.kill("SIGKILL");
      if (!existsSync(runPid)) return;
      try {
        process.kill(-Number(readFileSync(runPid, "utf8")), "SIGKILL");
      } catch (error) {
        if (error.code !== "ESRCH") throw error;
      }
    });
    const sampler = () => {
      const child = spawn(
        process.execPath,
        [
          "-e",
          "const row=process.argv[1];console.log(row);setInterval(()=>console.log(row),50)",
          row,
        ],
        { stdio: ["ignore", "pipe", "pipe"] },
      );
      samplerChild = child;
      samplerPid = child.pid;
      return child;
    };
    let result;
    await assert.rejects(
      watchDrawnRun(async (signal) => {
        const running =
          'require("fs").writeFileSync(process.argv[2],String(process.pid));process.kill(Number(process.argv[1]));setInterval(()=>{},1000)';
        result = await launch(process.execPath, ["-e", running, String(samplerPid), runPid], {
          cwd: scratch(),
          env: {},
          timeoutMs: 45_000,
          signal,
        });
        return result;
      }, sampler),
      /watcher stopped/,
    );
    assert.equal(result.timedOut, false);
    assert.equal(result.signal, "SIGKILL");
  },
);

test("Mac library captures keep the producer resolution and plant while forcing the embedded backend", async () => {
  const opts = capture(scratch());
  const result = await runWindowed({
    ...opts,
    reference: true,
    engineArgs: ["--resolution", "800x600"],
    extraEnv: { RENDER_PLANT: "dark_models" },
    start: async (bin, argv, { env }) => {
      assert.equal(argv[0], "--embedded");
      assert.equal(argv[argv.lastIndexOf("--resolution") + 1], "800x600");
      assert.equal(env.RENDER_PLANT, "dark_models");
      return { exit: 0, pid: 12, output: "SUMMARY", timedOut: false };
    },
  });
  assert.equal(result.exit, 0);
  assert.equal(result.output, "SUMMARY");
});

test("model receipts see a valid planted comparison but cannot consume an unwatched verdict", async () => {
  const summary = 'SUMMARY {"judged":6,"plant":"dark_models"}';
  for (const [rows, expected] of [
    [clean, true],
    [[sample(0), sample(50, 4, [12])], false],
  ]) {
    const result = await runWindowed({
      ...capture(scratch(), rows),
      start: async () => ({ exit: 1, pid: 12, output: summary, timedOut: false }),
    });
    assert.equal(result.exit, 1);
    assert.equal(result.output.includes(summary), expected);
  }
});

test("both Mac entry points refuse unknown and changed tools before taking a lock or starting Godot", async () => {
  const opts = capture(scratch());
  const unused = {
    acquire: assert.fail,
    version: assert.fail,
    observe: assert.fail,
    start: assert.fail,
  };
  for (const entry of [runWindowed, runCapture]) {
    for (const tool of [
      "res://tools/model_render_check.gd",
      "res://tools/look_harness.gd",
      "res://new.gd",
    ]) {
      const r = await entry({ ...opts, ...unused, script: tool });
      assert.equal(r.supported, false);
      assert.match(r.output, /refused before launch/);
    }
    await assert.rejects(
      entry({ ...opts, ...unused, engineArgs: ["--script", "res://other.gd"] }),
      /refusing engine flag/,
    );
  }
  writeFileSync(
    path.join(opts.cwd, "sketches/core-loop/tools/dam_look_capture.gd"),
    "modified inherited capture",
  );
  assert.equal((await runWindowed({ ...opts, ...unused })).supported, false);
  assert.equal((await runCapture({ ...opts, ...unused })).supported, false);
});

test("a queued Mac draw rechecks its files before the version query and again before the draw", async () => {
  for (const wait of ["slot", "sample"]) {
    const opts = capture(scratch());
    const changeHelper = () =>
      writeFileSync(path.join(opts.cwd, "sketches/core-loop/tools/offscreen_window.gd"), "changed");
    let released = false;
    const result = await runWindowed({
      ...opts,
      acquire: async () => {
        if (wait === "slot") changeHelper();
        return {
          release() {
            released = true;
          },
        };
      },
      version: wait === "slot" ? assert.fail : version,
      observe: async (draw) => {
        assert.equal(wait, "sample");
        changeHelper();
        return draw();
      },
      start: assert.fail,
    });
    assert.equal(result.supported, false);
    assert.match(result.output, /refused before launch/);
    assert.equal(released, true);
  }
});

test("headless measurement and the editor version probe use only their scratch homes", async () => {
  const opts = capture(scratch());
  const file = path.join(opts.cwd, "yard.png");
  const ref = path.join(opts.cwd, "gate.png");
  const result = await measureFrame(file, ref, {
    ...opts,
    env: { HOME: "/original" },
    start: async (_binary, argv, { env }) => {
      assert.deepEqual(argv, [
        "--headless",
        "--path",
        path.join(opts.cwd, "sketches/core-loop"),
        "--script",
        script,
        "--",
        "--measure=" + file,
        "--reference=" + ref,
      ]);
      assert.ok(env.HOME.startsWith(path.join(opts.cwd, "artifacts/local/display-run/home-")));
      assert.equal(env.XDG_DATA_HOME, path.join(env.HOME, "data"));
      return { exit: 0, output: "measured", timedOut: false };
    },
  });
  assert.equal(result.exit, 0);
  assert.equal(existsSync(result.home), false);
  let versionHome;
  const control = await runCapture({
    ...opts,
    reference: true,
    version: (_command, { env }) => {
      versionHome = env.HOME;
      assert.ok(existsSync(versionHome));
      return version();
    },
    start: async (_bin, _argv, { env }) => {
      assert.equal(env.HOME, versionHome);
      assert.equal(env.XDG_CACHE_HOME, path.join(versionHome, "cache"));
      return opts.start();
    },
  });
  assert.equal(control.home, versionHome);
  assert.equal(existsSync(versionHome), false);
});
