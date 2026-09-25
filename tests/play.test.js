import test from "node:test";
import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

import {
  aggregateOutcomes,
  buildTestMeasures,
  findOnPath,
  flakeRate,
  jobLimit,
  labRoute,
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
import { wilson } from "../scripts/lab/stats.mjs";

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

test("slugLabel makes a record.mjs-safe slug from arbitrary text", () => {
  assert.equal(slugLabel("ball-lab"), "ball-lab");
  assert.equal(slugLabel("Cable Bench!!"), "cable-bench");
  assert.equal(
    slugLabel("spillway-drop/spillway-drop"),
    "spillway-drop-spillway-drop",
  );
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

test("flakeRate counts a check disagreeing with itself, not just fail-then-pass order", () => {
  const agree = new Map([
    ["a", ["pass", "pass", "pass"]],
    ["b", ["fail", "fail"]],
  ]);
  const agreeCi = wilson(0, 2);
  assert.deepEqual(flakeRate(agree), {
    value: 0,
    n: 2,
    ci: [agreeCi.lower, agreeCi.upper],
  });

  const disagree = new Map([
    ["a", ["pass", "pass"]],
    ["b", ["pass", "fail"]],
    ["c", ["fail", "pass", "pass"]],
  ]);
  const disagreeCi = wilson(2, 3);
  assert.deepEqual(flakeRate(disagree), {
    value: 2 / 3,
    n: 3,
    ci: [disagreeCi.lower, disagreeCi.upper],
  });

  assert.deepEqual(flakeRate(new Map()), { value: null, n: 0, ci: null });
});

test("buildTestMeasures reports suite_wall_s, suite_pass, engine_crash and skips flake_rate for a single run", () => {
  const repeatResults = [
    [
      { label: "a import", ok: true, crashed: false },
      { label: "a boot", ok: true, crashed: false },
    ],
  ];
  const { measures, checks, flake, totalSeconds } = buildTestMeasures({
    repeatResults,
    repeatSeconds: [12.5],
    repeatOks: [true],
  });
  assert.equal(totalSeconds, 12.5);
  assert.deepEqual(measures.suite_wall_s, { value: 12.5, n: 1, ci: null });
  assert.deepEqual(measures.suite_pass, { value: 0, n: 1, ci: null });
  assert.deepEqual(measures.engine_crash, { value: 0, n: 2, ci: null });
  assert.equal(flake, null);
  assert.deepEqual(checks, [
    { label: "a import", outcomes: ["pass"] },
    { label: "a boot", outcomes: ["pass"] },
  ]);
});

test("buildTestMeasures reports flake_rate and counts crashes across repeats", () => {
  const repeatResults = [
    [
      { label: "a import", ok: true, crashed: false },
      { label: "a boot", ok: true, crashed: true },
    ],
    [
      { label: "a import", ok: true, crashed: false },
      { label: "a boot", ok: false, crashed: false },
    ],
  ];
  const { measures, flake } = buildTestMeasures({
    repeatResults,
    repeatSeconds: [10, 14],
    repeatOks: [true, false],
  });
  const flakeCi = wilson(1, 2);
  assert.deepEqual(measures.suite_wall_s, { value: 12, n: 2, ci: null });
  assert.deepEqual(measures.suite_pass, { value: 1, n: 2, ci: null });
  assert.deepEqual(measures.engine_crash, { value: 1, n: 4, ci: null });
  assert.deepEqual(flake, {
    value: 0.5,
    n: 2,
    ci: [flakeCi.lower, flakeCi.upper],
  });
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

  // A later PATH entry still resolves after an earlier one comes up empty.
  const empty = path.join(temporary, "empty-dir");
  await mkdir(empty);
  assert.equal(
    findOnPath("claude-open", {
      PATH: `${empty}${path.delimiter}${temporary}`,
    }),
    executable,
  );

  // A file that exists but is not executable does not count as found.
  const inert = path.join(temporary, "not-executable");
  await writeFile(inert, "not a script\n");
  assert.equal(findOnPath("not-executable", { PATH: temporary }), null);
});

test("shotOutputPath defaults under artifacts/local/shots/, never /tmp (audit A8)", () => {
  const entry = { sketch: "ball-lab" };
  const noArg = shotOutputPath(root, entry, undefined);
  assert.equal(noArg.shotsDir, path.join(root, "artifacts", "local", "shots"));
  assert.equal(noArg.out, path.join(noArg.shotsDir, "ball-lab-spawn.png"));
  assert.ok(!noArg.out.startsWith("/tmp"));

  const named = shotOutputPath(root, entry, "custom.png");
  assert.equal(named.out, path.join(named.shotsDir, "custom.png"));

  const absolute = shotOutputPath(
    root,
    entry,
    "/home/andrew/shots/explicit.png",
  );
  assert.equal(absolute.out, "/home/andrew/shots/explicit.png");
});

test("shotOutputPath refuses an explicit output path under /tmp (N6)", () => {
  const entry = { sketch: "ball-lab" };
  assert.throws(
    () => shotOutputPath(root, entry, "/tmp/explicit.png"),
    /\/tmp/,
  );
  assert.throws(() => shotOutputPath(root, entry, "/tmp"), /\/tmp/);
  assert.throws(
    () => shotOutputPath(root, entry, "/tmp/nested/dir/explicit.png"),
    /\/tmp/,
  );
});

test("shotOutputPath resolves the path before refusing /tmp, so .. and //tmp cannot slip in (NB3)", () => {
  const entry = { sketch: "ball-lab" };
  const climbs = "../".repeat(root.split("/").length + 4);
  for (const hostile of [
    `${climbs}tmp/x.png`,
    "//tmp/x.png",
    "/tmp/../tmp/x.png",
    "/home/../tmp/x.png",
  ]) {
    assert.throws(
      () => shotOutputPath(root, entry, hostile),
      /may not be under/,
      hostile,
    );
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
  const entry = { sketch: "ball-lab" };
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
  const hung = spawnSync(
    process.execPath,
    ["-e", "setTimeout(() => {}, 30000)"],
    { ...shotSpawnOptions({ timeoutMs: 300 }), stdio: "ignore" },
  );
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

test("labRoute sends stats, gate and lab sub-verbs to their scripts", () => {
  const lab = path.join(root, "scripts", "lab");
  const exists = () => true;
  assert.deepEqual(labRoute(["stats", "--layer", "program"], { exists }), {
    script: path.join(lab, "stats-cli.mjs"),
    args: ["--layer", "program"],
  });
  assert.deepEqual(labRoute(["gate", "r1", "--against", "base"], { exists }), {
    script: path.join(lab, "gate.mjs"),
    args: ["r1", "--against", "base"],
  });
  assert.deepEqual(
    labRoute(["lab", "run", "downhill-run", "--arm", "scripted", "-n", "20"], {
      exists,
    }),
    {
      script: path.join(lab, "harness.mjs"),
      args: ["downhill-run", "--arm", "scripted", "-n", "20"],
    },
  );
  assert.deepEqual(labRoute(["lab", "program", "--since", "x"], { exists }), {
    script: path.join(lab, "program.mjs"),
    args: ["--since", "x"],
  });
  assert.equal(
    labRoute(["lab", "verdicts"], { exists }).script,
    path.join(lab, "verdicts.mjs"),
  );
  for (const words of [["lab"], ["lab", "bogus"]]) {
    const routed = labRoute(words, { exists });
    assert.equal(routed.exit, 2, words.join(" "));
    assert.match(routed.error, /lab run\|program\|verdicts/);
  }
  const unbuilt = labRoute(["lab", "run", "x"], {
    exists: (file) => !file.endsWith("harness.mjs"),
  });
  assert.equal(unbuilt.exit, 2);
  assert.match(unbuilt.error, /harness\.mjs is not built yet/);
  for (const words of [[], ["play", "x"], ["test"], ["mobility"], ["--all"]])
    assert.equal(labRoute(words, { exists }), null, words.join(" "));
});

test("play.mjs routes lab verbs before it looks for Godot", async (t) => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-route-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const env = { ...process.env, GODOT_BIN: path.join(temporary, "no-godot") };
  const run = (...args) =>
    spawnSync(
      process.execPath,
      [path.join(root, "scripts/play.mjs"), ...args],
      {
        encoding: "utf8",
        env,
      },
    );
  const stats = run(
    "stats",
    "--layer",
    "human",
    "--runs",
    path.join(temporary, "runs"),
    "--artifacts",
    path.join(temporary, "artifacts"),
  );
  assert.equal(stats.status, 0, stats.stdout + stats.stderr);
  assert.match(stats.stdout, / agent_agreement /);
  assert.match(stats.stdout, / unplayed_green /);
  const gate = run("gate");
  assert.equal(gate.status, 2, gate.stdout + gate.stderr);
  assert.match(gate.stderr, /scripts\/lab\/gate\.mjs --pin/);
  const lab = run("lab");
  assert.equal(lab.status, 2);
  assert.doesNotMatch(lab.stderr, /Godot binary not found/);
  const sketch = run("list");
  assert.equal(sketch.status, 2, "a sketch verb still needs Godot");
  assert.match(sketch.stderr, /Godot binary not found/);
});

test("resolve still prefers an exact id, then a primary among prefix or substring hits", () => {
  const entries = [
    { id: "ball-lab", sketch: "ball-lab", primary: true },
    { id: "mobility-kit/ball-lab", sketch: "ball-lab", primary: false },
    { id: "spillway-drop", sketch: "spillway-drop", primary: true },
  ];
  assert.equal(resolve(entries, "ball-lab").entry.id, "ball-lab");
  assert.equal(resolve(entries, "spill").entry.id, "spillway-drop");
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

test("waitForShot times out when the file never appears, e.g. claude-open dispatched and returned early", async () => {
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

// B1: createRun() has to run before the suite loop, or its start-of-run
// source digest already includes whatever the suite changed, and JL-01's
// mid-run source-change guard can never fire. A fake runOnce() that edits a
// tracked file on its first call stands in for the suite without Godot.
function git(repository, ...args) {
  const result = spawnSync(
    "git",
    [
      "-c",
      "user.name=Lab Test",
      "-c",
      "user.email=lab@example.invalid",
      "-c",
      "commit.gpgsign=false",
      ...args,
    ],
    { cwd: repository, encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}

async function repoFixture(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-play-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const repository = path.join(temporary, "repository");
  const runsRoot = path.join(temporary, "runs");
  await mkdir(path.join(repository, "src"), { recursive: true });
  git(repository, "init", "-q", "-b", "lab");
  await writeFile(path.join(repository, "src/a.txt"), "before\n");
  git(repository, "add", ".");
  git(repository, "commit", "-q", "-m", "fixture");
  return { repository, runsRoot };
}

test("runTestSuite calls createRun before the loop, so a source edit during the run is caught (B1)", async (t) => {
  const { repository, runsRoot } = await repoFixture(t);
  const before = Date.now();

  let calls = 0;
  let editedAt = null;
  const runOnce = async () => {
    calls += 1;
    if (calls === 1) {
      // The "suite work": if createRun() ran after this instead of before,
      // its start digest would already include this edit and the mismatch
      // could never be detected.
      await writeFile(path.join(repository, "src/a.txt"), "during\n");
      editedAt = Date.now();
    }
    return {
      ok: true,
      results: [{ label: "check", ok: true, crashed: false }],
    };
  };

  const { record, overallOk, totalSeconds } = await runTestSuite({
    targets: [],
    limit: 1,
    repeats: 1,
    label: "fixture",
    runOnce,
    createRunOptions: {
      repository,
      root: runsRoot,
      sources: ["src"],
    },
  });
  const after = Date.now();

  assert.equal(overallOk, true);
  assert.equal(typeof totalSeconds, "number");
  // started_at falls inside the call window and, decisively, no later than
  // the edit the "suite work" made after createRun() had already run.
  assert.ok(Date.parse(record.started_at) >= before);
  assert.ok(Date.parse(record.started_at) <= after);
  assert.ok(Date.parse(record.started_at) <= editedAt);
  assert.equal(record.result, "inconclusive");
  assert.equal(record.provenance.sources.matched, false);
  assert.deepEqual(record.provenance.sources.changed, ["src/a.txt"]);
});

test("runTestSuite writes suite_wall_s/suite_pass/engine_crash and per-check outcomes in config (DoD 1)", async (t) => {
  const { repository, runsRoot } = await repoFixture(t);
  const runOnce = async () => ({
    ok: true,
    results: [
      { label: "fixture import", ok: true, crashed: false },
      { label: "fixture boot", ok: true, crashed: false },
    ],
  });

  const { record } = await runTestSuite({
    targets: [],
    limit: 1,
    repeats: 2,
    label: "fixture",
    runOnce,
    createRunOptions: {
      repository,
      root: runsRoot,
      sources: ["src"],
      config: { target: "fixture", jobs: 1, repeat: 2 },
    },
  });

  assert.equal(record.result, "pass");
  assert.equal(record.kris.suite_pass.value, 0);
  assert.equal(record.kris.suite_pass.n, 2);
  assert.equal(record.kris.engine_crash.value, 0);
  assert.equal(record.kris.engine_crash.n, 4);
  assert.equal(record.kpis.suite_wall_s.n, 2);
  assert.equal(record.kris.flake_rate.value, 0);
  assert.deepEqual(record.config.repeat_seconds.length, 2);
  assert.deepEqual(record.config.checks.map((c) => c.label).sort(), [
    "fixture boot",
    "fixture import",
  ]);
});
