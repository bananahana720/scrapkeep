import test from "node:test";
import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

import {
  aggregateOutcomes,
  findOnPath,
  jobLimit,
  pickPrimary,
  testEntry,
  repeatCount,
  resolve,
  runTestSuite,
  SHOT_TIMEOUT_MS,
  shotLaunchFailure,
  shotOutputPath,
  shotSpawnOptions,
  slugLabel,
  waitForShot,
  waitUntil,
} from "../scripts/play.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

test("jobLimit reads --jobs= and falls back to a core-based default", () => {
  assert.equal(jobLimit(["test", "--jobs=3"]), 3);
  assert.equal(jobLimit(["test", "--jobs=0"]), 1);
  assert.equal(jobLimit(["test", "--jobs=not-a-number"]), 1);
  const fallback = jobLimit(["test"]);
  assert.ok(fallback >= 2 && fallback <= 8);
});

test("repeatCount reads --repeat= and defaults to a single run", () => {
  assert.equal(repeatCount(["test"]), 1);
  assert.equal(repeatCount(["test", "--repeat=20"]), 20);
  assert.equal(repeatCount(["test", "--repeat=0"]), 1);
  assert.equal(repeatCount(["test", "--repeat=nope"]), 1);
});

test("slugLabel makes a safe slug from arbitrary text", () => {
  assert.equal(slugLabel("core-loop"), "core-loop");
  assert.equal(slugLabel("Core Loop!!"), "core-loop");
  assert.equal(slugLabel("alpha/core-loop"), "alpha-core-loop");
  assert.equal(slugLabel(""), "run");
  assert.equal(slugLabel("---"), "run");
});

test("aggregateOutcomes rows one check by label, tolerating a shorter repeat", () => {
  const repeatResults = [
    [
      { label: "a import", ok: true },
      { label: "a boot", ok: true },
    ],
    [{ label: "a import", ok: false }],
    [
      { label: "a import", ok: true },
      { label: "a boot", ok: false },
    ],
  ];
  const byLabel = aggregateOutcomes(repeatResults);
  assert.deepEqual(byLabel.get("a import"), ["pass", "fail", "pass"]);
  assert.deepEqual(byLabel.get("a boot"), ["pass", "fail"]);
});

test("findOnPath resolves an executable from an injected PATH and returns null when absent", async (t) => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-path-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const executable = path.join(temporary, "claude-open");
  await writeFile(executable, "#!/bin/sh\nexit 0\n");
  await chmod(executable, 0o755);

  assert.equal(findOnPath("claude-open", { PATH: temporary }), executable);
  assert.equal(findOnPath("claude-open", { PATH: "/does/not/exist" }), null);
  assert.equal(findOnPath("claude-open", {}), null);

  const empty = path.join(temporary, "empty-dir");
  await mkdir(empty);
  assert.equal(
    findOnPath("claude-open", {
      PATH: `${empty}${path.delimiter}${temporary}`,
    }),
    executable,
  );

  const inert = path.join(temporary, "not-executable");
  await writeFile(inert, "not a script\n");
  assert.equal(findOnPath("not-executable", { PATH: temporary }), null);
});

test("shotOutputPath defaults under artifacts/local/shots/, never /tmp (audit A8)", () => {
  const entry = { sketch: "core-loop" };
  const noArg = shotOutputPath(root, entry, undefined);
  assert.equal(noArg.shotsDir, path.join(root, "artifacts", "local", "shots"));
  assert.equal(noArg.out, path.join(noArg.shotsDir, "core-loop-spawn.png"));
  assert.ok(!noArg.out.startsWith("/tmp"));

  const named = shotOutputPath(root, entry, "custom.png");
  assert.equal(named.out, path.join(named.shotsDir, "custom.png"));

  const absolute = shotOutputPath(root, entry, "/home/andrew/shots/explicit.png");
  assert.equal(absolute.out, "/home/andrew/shots/explicit.png");
});

test("shotOutputPath refuses an explicit output path under /tmp (N6)", () => {
  const entry = { sketch: "core-loop" };
  assert.throws(() => shotOutputPath(root, entry, "/tmp/explicit.png"), /\/tmp/);
  assert.throws(() => shotOutputPath(root, entry, "/tmp"), /\/tmp/);
  assert.throws(() => shotOutputPath(root, entry, "/tmp/nested/dir/explicit.png"), /\/tmp/);
});

test("shotOutputPath resolves the path before refusing /tmp, so .. and //tmp cannot slip in (NB3)", () => {
  const entry = { sketch: "core-loop" };
  const climbs = "../".repeat(root.split("/").length + 4);
  for (const hostile of [
    `${climbs}tmp/x.png`,
    "//tmp/x.png",
    "/tmp/../tmp/x.png",
    "/home/../tmp/x.png",
  ]) {
    assert.throws(() => shotOutputPath(root, entry, hostile), /may not be under/, hostile);
  }
  assert.throws(
    () =>
      shotOutputPath(root, entry, "/scratch/tmpdir/x.png", {
        tmpRoots: ["/tmp", "/scratch/tmpdir"],
      }),
    /scratch\/tmpdir/,
    "os.tmpdir() is refused as well as /tmp",
  );
  assert.equal(
    shotOutputPath(root, entry, "/tmpfoo/x.png").out,
    "/tmpfoo/x.png",
    "a sibling that merely starts with tmp is allowed",
  );
  const nested = shotOutputPath(root, entry, "a/../b.png");
  assert.equal(nested.out, path.join(nested.shotsDir, "b.png"));
});

test("shotOutputPath refuses os.tmpdir() by default", () => {
  const entry = { sketch: "core-loop" };
  assert.throws(
    () => shotOutputPath(root, entry, path.join(os.tmpdir(), "shot.png")),
    /may not be under/,
  );
});

test("the shot spawn carries a process timeout, and a hung child is killed (NB1)", () => {
  const options = shotSpawnOptions();
  assert.equal(options.timeout, SHOT_TIMEOUT_MS);
  assert.ok(Number.isFinite(SHOT_TIMEOUT_MS) && SHOT_TIMEOUT_MS > 0);
  assert.equal(options.killSignal, "SIGKILL");
  assert.equal(options.stdio, "inherit");

  const started = Date.now();
  const hung = spawnSync(process.execPath, ["-e", "setTimeout(() => {}, 30000)"], {
    ...shotSpawnOptions({ timeoutMs: 300 }),
    stdio: "ignore",
  });
  assert.ok(Date.now() - started < 10_000, "killed well before it would exit");
  const failure = shotLaunchFailure(hung, 300);
  assert.equal(failure.code, 1);
  assert.match(failure.message, /did not exit within 0\.3 s/);

  assert.equal(shotLaunchFailure({ status: 0, signal: null }), null);
  assert.deepEqual(shotLaunchFailure({ status: 5, signal: null }), {
    code: 5,
    message: "the shot process exited with status 5",
  });
  const missing = shotLaunchFailure({
    status: null,
    signal: null,
    error: Object.assign(new Error("spawn nope ENOENT"), { code: "ENOENT" }),
  });
  assert.equal(missing.code, 1);
  assert.match(missing.message, /could not start: spawn nope ENOENT/);
});

test("a worktree's primary sketch is the one its name contains, longest first, else core-loop", () => {
  const sketches = ["arena", "core-loop", "sandbox-v2"].map((name) =>
    path.join("/wt", "sketches", name),
  );
  assert.equal(path.basename(pickPrimary(sketches, "sandbox-v2-exp")), "sandbox-v2");
  assert.equal(path.basename(pickPrimary(sketches, "arena")), "arena");
  assert.equal(path.basename(pickPrimary(sketches, "other-branch")), "core-loop");
  assert.equal(
    path.basename(pickPrimary([path.join("/wt", "sketches", "arena")], "other-branch")),
    "arena",
  );
});

test("resolve still prefers an exact id, then a primary among prefix or substring hits", () => {
  const entries = [
    { id: "core-loop", sketch: "core-loop", primary: true },
    { id: "wt/core-loop", sketch: "core-loop", primary: false },
    { id: "arena", sketch: "arena", primary: true },
  ];
  assert.equal(resolve(entries, "core-loop").entry.id, "core-loop");
  assert.equal(resolve(entries, "aren").entry.id, "arena");
  assert.deepEqual(resolve(entries, "nope"), { ambiguous: [] });
});

test("waitUntil resolves true as soon as check() reports done, without waiting out the timeout", async () => {
  let calls = 0;
  let clock = 0;
  const ok = await waitUntil(
    () => {
      calls += 1;
      return calls >= 3;
    },
    {
      timeoutMs: 10_000,
      intervalMs: 5,
      now: () => (clock += 1),
      sleep: async () => {},
    },
  );
  assert.equal(ok, true);
  assert.equal(calls, 3);
});

test("waitUntil returns false once the deadline passes and check() never succeeds", async () => {
  let calls = 0;
  let clock = 0;
  const ok = await waitUntil(
    () => {
      calls += 1;
      return false;
    },
    {
      timeoutMs: 10,
      intervalMs: 5,
      now: () => (clock += 4),
      sleep: async () => {},
    },
  );
  assert.equal(ok, false);
  assert.ok(calls >= 1);
});

test("waitForShot polls an injected exists() check rather than trusting an exit code (B2)", async () => {
  let checks = 0;
  let clock = 0;
  const ok = await waitForShot("/fake/out.png", {
    exists: () => {
      checks += 1;
      return checks >= 2;
    },
    timeoutMs: 10_000,
    intervalMs: 5,
    now: () => (clock += 1),
    sleep: async () => {},
  });
  assert.equal(ok, true);
  assert.equal(checks, 2);
});

test("waitForShot times out when the file never appears", async () => {
  let clock = 0;
  const ok = await waitForShot("/fake/out.png", {
    exists: () => false,
    timeoutMs: 10,
    intervalMs: 5,
    now: () => (clock += 4),
    sleep: async () => {},
  });
  assert.equal(ok, false);
});

test("runTestSuite aggregates per-check outcomes across repeats", async () => {
  const runOnce = async () => ({
    ok: true,
    results: [
      { label: "fixture import", ok: true, crashed: false },
      { label: "fixture boot", ok: true, crashed: false },
    ],
  });

  const { overallOk, checks, repeatSeconds } = await runTestSuite({
    targets: [],
    limit: 1,
    repeats: 2,
    runOnce,
  });

  assert.equal(overallOk, true);
  assert.equal(repeatSeconds.length, 2);
  assert.deepEqual(checks.map((c) => c.label).sort(), ["fixture boot", "fixture import"]);
});

async function fakeSketch() {
  const dir = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-play-stream-"));
  await mkdir(path.join(dir, "tests"), { recursive: true });
  await writeFile(path.join(dir, "tests", "a_test.gd"), "extends SceneTree\n");
  await writeFile(path.join(dir, "tests", "b_test.gd"), "extends SceneTree\n");
  return {
    entry: { id: "fake", directory: dir },
    done: () => rm(dir, { recursive: true, force: true }),
  };
}

function scriptedRun(plan, events) {
  return (label) =>
    new Promise((resolveRun) => {
      const { ms, ok } = plan[label.replace(/^fake /, "")];
      events.push(`start ${label}`);
      setTimeout(() => {
        events.push(`end ${label}`);
        resolveRun({ label, ok, status: ok ? 0 : 1, crashed: false, output: "" });
      }, ms);
    });
}

test("the test verb still reports every check in list order after the pool", async () => {
  const sketch = await fakeSketch();
  try {
    const events = [];
    const plan = {
      import: { ms: 1, ok: true },
      boot: { ms: 60, ok: true },
      "a_test.gd": { ms: 5, ok: false },
      "b_test.gd": { ms: 20, ok: true },
    };
    const reported = [];
    const logged = [];
    const result = await testEntry(sketch.entry, 3, {
      run: scriptedRun(plan, events),
      report: (r) => {
        reported.push(`${r.label} ${events.includes("end fake boot")}`);
        return r.ok;
      },
      log: (line) => logged.push(line),
    });
    assert.deepEqual(reported, [
      "fake import false",
      "fake boot true",
      "fake a_test.gd true",
      "fake b_test.gd true",
    ]);
    assert.deepEqual(logged, []);
    assert.equal(result.ok, false);
    assert.equal(result.first_fail_s, undefined);
  } finally {
    await sketch.done();
  }
});

test("watch streams each check as it finishes and prints one RED line at the first failure", async () => {
  const sketch = await fakeSketch();
  try {
    const events = [];
    const plan = {
      import: { ms: 1, ok: true },
      boot: { ms: 80, ok: true },
      "a_test.gd": { ms: 10, ok: false },
      "b_test.gd": { ms: 30, ok: false },
    };
    const reported = [];
    const logged = [];
    const started = Date.now();
    const result = await testEntry(sketch.entry, 3, {
      stream: true,
      started,
      run: scriptedRun(plan, events),
      report: (r) => {
        reported.push(`${r.label} ${events.includes("end fake boot")}`);
        return r.ok;
      },
      log: (line) => logged.push({ line, bootDone: events.includes("end fake boot") }),
    });
    assert.deepEqual(reported, [
      "fake import false",
      "fake a_test.gd false",
      "fake b_test.gd false",
      "fake boot true",
    ]);
    assert.equal(logged.length, 1, "one RED line, at the first failure only");
    assert.match(logged[0].line, /RED.* fake a_test\.gd after \d+\.\d s/);
    assert.equal(logged[0].bootDone, false, "printed while other checks still run");
    assert.ok(events.includes("end fake boot"), "no check is killed early");
    assert.equal(result.results.length, 4);
    assert.ok(result.first_fail_s >= 0 && result.first_fail_s < 1);
  } finally {
    await sketch.done();
  }
});

test("a throwing reporter cannot stop the pool; every check still runs and returns", async () => {
  const sketch = await fakeSketch();
  try {
    const events = [];
    const plan = {
      import: { ms: 1, ok: true },
      boot: { ms: 30, ok: true },
      "a_test.gd": { ms: 5, ok: false },
      "b_test.gd": { ms: 10, ok: true },
    };
    const result = await testEntry(sketch.entry, 3, {
      stream: true,
      run: scriptedRun(plan, events),
      report: (r) => {
        if (r.label !== "fake import") throw new Error("reporter broke");
        return r.ok;
      },
      log: () => {
        throw new Error("log broke");
      },
    });
    assert.equal(result.results.length, 4);
    assert.deepEqual(events.filter((e) => e.startsWith("end")).length, 4, "no child left running");
  } finally {
    await sketch.done();
  }
});
