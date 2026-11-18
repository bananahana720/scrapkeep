import assert from "node:assert/strict";
import { mkdtempSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import test from "node:test";

import { acquireDrawnSlot, runCapture } from "./display-run.mjs";
import { windowCounts } from "./window-watch.mjs";

const script = "res://tools/offscreen_probe.gd";
const version = () => "4.7.2.stable.official.ed1daf0bf";
const lease = async () => ({ release() {} });
const sample = (at, front = 4, visible = [], godot = [], missed = 0) => ({ at, front, visible, godot, missed });
const clean = [sample(0), sample(50), sample(100)];
function capture(cwd, samples = clean) {
  return { script, cwd, platform: "darwin", env: {}, binary: "/test/godot", version, acquire: lease,
    start: async () => ({ exit: 0, pid: 12, output: "OFFSCREEN_WINDOW 12 embedded\n", timedOut: false }),
    observe: async run => ({ ...await run(), watch: windowCounts(samples, 12) }),
  };
}
function scratch() { return mkdtempSync(path.join(os.tmpdir(), "scrapkeep-capture-test-")); }

test("the probe uses embedded Metal before the project is loaded, with a scratch home", async () => {
  const opts = capture(scratch());
  let saved;
  const r = await runCapture({ ...opts, start: async (bin, argv, context) => {
    saved = { argv, env: context.env };
    return opts.start();
  } });
  assert.equal(r.exit, 0);
  assert.deepEqual(saved.argv.slice(0, 7), ["--embedded", "--rendering-driver", "metal", "--resolution", "1920x1080", "--audio-driver", "Dummy"]);
  assert.equal(saved.env.SCRAPKEEP_OFFSCREEN, "1");
  assert.ok(saved.env.HOME.startsWith(path.join(opts.cwd, "artifacts/local/display-run/home-")));
});

test("the watcher rejects focus changes, visible children, missing periods and missing helper", async () => {
  const cwd = scratch();
  for (const plant of [sample(50, 7), sample(50, 4, [], [99]), sample(102, 4, [], [], 1), sample(50, 4, [12])]) {
    assert.equal((await runCapture(capture(cwd, [sample(0), plant]))).exit, 1);
  }
  const opts = capture(cwd);
  assert.equal((await runCapture({ ...opts, start: async () => ({ ...await opts.start(), output: "" }) })).exit, 1);
  assert.throws(() => windowCounts([sample(0)], 12), /lacks/);
});

test("the Gate reference needs a visible sample for its own process and the pinned executable", async () => {
  const cwd = scratch();
  const plant = capture(cwd, [sample(0), sample(50, 12, [12], [12])]);
  const r = await runCapture({ ...plant, reference: true, start: async (bin, argv, options) => {
    assert.ok(!argv.includes("--embedded"));
    assert.equal(options.env.SCRAPKEEP_OFFSCREEN, "0");
    return plant.start();
  } });
  assert.equal(r.exit, 0);
  assert.equal(r.watch.targetOnScreen, 1);
  const unrelated = capture(cwd, [sample(0), sample(50, 9, [99], [99])]);
  assert.equal((await runCapture({ ...unrelated, reference: true })).exit, 1);
  await assert.rejects(runCapture({ ...plant, version: () => "4.5", start: assert.fail }), /pinned/);
  await assert.rejects(runCapture({ ...plant, reference: true, script: "res://other.gd", start: assert.fail }), /only the W1-131 probe/);
});

test("two drawn runs wait for one lock across worktrees and have disjoint start/end times", async () => {
  const directory = scratch();
  const notices = [];
  const acquire = () => acquireDrawnSlot({ directory, machine: lease, pollMs: 8, log: msg => notices.push(msg) });
  const intervals = [];
  async function draw() {
    const opts = capture(scratch());
    const result = await runCapture({ ...opts, acquire, start: async () => {
      const from = performance.now();
      await sleep(40);
      intervals.push([from, performance.now()]);
      return opts.start();
    } });
    assert.equal(result.exit, 0);
  }
  await Promise.all([draw(), draw()]);
  assert.ok(notices.some(msg => msg.includes("waiting")));
  assert.ok(intervals[0][1] <= intervals[1][0]);
});
