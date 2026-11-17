// JL-17: the real Godot runner (sketches/ball-lab/src/jev/jev_run.gd), its
// launcher (scripts/lab/godot-launch.mjs) and the harness seam they share.
//
// The seam cases need no Godot: D, k and env reach the launch, the record
// stores D and k, the harness kills a stalled launch's whole process group, and
// SIGINT or SIGTERM to the harness writes abort{interrupted}. The bridge cases
// start real headless Godot and skip, saying so, when the pinned binary is
// missing. They answer every snapshot with the scripted arm after a random
// delay and check that each intent applies at exactly state.tick + k and that
// trace_hash does not depend on the delays, in each physics mode. A rigid-mode
// divergence is reported as stochastic, not failed.
//
// JL-21 adds the scenario's own result on stdout and in the record, the
// `@<speed>` scenario ids, --time-limit-s, no state on the end tick, and the
// widened determinism evidence: dummy-knock with choices and contact, and a
// negative control where k or one answer changes the hash.
import test from "node:test";
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import {
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  realpath,
  rm,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  fileName,
  offeredOptions,
  PROTOCOL,
  TIMING,
  validateTrial,
  writeAtomic,
} from "../tools/jev-player/protocol/protocol.mjs";
import { binary as smokeBinary } from "../scripts/sketch-smoke.mjs";
import { createArm, seededRandom } from "../scripts/lab/arms.mjs";
import { fakeGodot, runBatch } from "../scripts/lab/harness.mjs";
import {
  GODOT_BINARY,
  RUNNER,
  SKETCH,
  godotLaunch,
} from "../scripts/lab/godot-launch.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const fixtures = path.join(root, "tools/jev-player/protocol/fixtures");
const noGodot = existsSync(GODOT_BINARY)
  ? false
  : `the Godot binary is missing at ${GODOT_BINARY}; set GODOT_BIN to run the bridge cases`;
const MODES = ["kinematic", "rigid"];
// Five snapshots of downhill-run (none at the end tick); enough intents to see every delay pattern.
const BRIDGE_TICKS = 5 * TIMING.snapshot_every;

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

// A throwaway repository for provenance and a runs root outside it, as in
// tests/lab-harness.test.js.
async function fixture(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-bridge-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const repository = path.join(temporary, "repository");
  await mkdir(path.join(repository, "src"), { recursive: true });
  git(repository, "init", "-q", "-b", "lab");
  await writeFile(path.join(repository, "src/tuning.txt"), "speed = 4\n");
  git(repository, "add", ".");
  git(repository, "commit", "-q", "-m", "fixture");
  const runs = {
    root: path.join(temporary, "runs"),
    repository,
    sources: ["src"],
  };
  return { temporary, runs };
}

const alive = (pid) => {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
};

async function until(check, ms, what) {
  const started = Date.now();
  while (!(await check())) {
    if (Date.now() - started > ms) assert.fail(`timed out waiting for ${what}`);
    await sleep(20);
  }
}

async function findFile(directory, name) {
  if (!existsSync(directory)) return null;
  const entries = await readdir(directory, { recursive: true });
  const hit = entries.find((entry) => path.basename(entry) === name);
  return hit === undefined ? null : path.join(directory, hit);
}

// --- the harness seam -------------------------------------------------------

test("the launch receives D and k, and the batch record stores them", async (t) => {
  const { runs } = await fixture(t);
  const seen = [];
  const fake = fakeGodot();
  const launch = (request) => {
    seen.push(request);
    return fake(request);
  };
  launch.label = "probe";
  const { record, trials } = await runBatch({
    scenario: "downhill-run",
    arm: "scripted",
    runs,
    launch,
  });
  assert.equal(trials[0].outcome, "complete");
  assert.equal(seen[0].snapshotEvery, TIMING.snapshot_every);
  assert.equal(seen[0].holdTicks, TIMING.hold_ticks);
  assert.equal(record.config.snapshot_every, TIMING.snapshot_every);
  assert.equal(record.config.hold_ticks, TIMING.hold_ticks);
});

test("a hello whose schedule differs from the requested D and k is invalid", async (t) => {
  const { runs } = await fixture(t);
  const { trials } = await runBatch({
    scenario: "downhill-run",
    arm: "scripted",
    runs,
    snapshotEvery: 45,
    holdTicks: 26,
  });
  assert.equal(trials[0].outcome, "invalid");
  assert.match(trials[0].abort.message, /snapshot_every/);
});

test("the harness refuses a schedule where k is not below D", async (t) => {
  const { runs } = await fixture(t);
  for (const [snapshotEvery, holdTicks] of [
    [90, 90],
    [0, 0],
    [90, -1],
    [45.5, 0],
  ]) {
    await assert.rejects(
      runBatch({
        scenario: "downhill-run",
        arm: "scripted",
        runs,
        snapshotEvery,
        holdTicks,
      }),
      /snapshotEvery|holdTicks/,
    );
  }
});

test("env and cwd from the launch reach the spawned process", async (t) => {
  const { temporary, runs } = await fixture(t);
  const probe = path.join(temporary, "probe.json");
  const launch = () => ({
    command: process.execPath,
    args: [
      "-e",
      `require("node:fs").writeFileSync(${JSON.stringify(probe)}, JSON.stringify({ env: process.env.JL17_PROBE, cwd: process.cwd(), path: process.env.PATH }))`,
    ],
    env: { JL17_PROBE: "carried" },
    cwd: temporary,
  });
  const { trials } = await runBatch({
    scenario: "downhill-run",
    arm: "scripted",
    runs,
    launch,
  });
  assert.equal(trials[0].outcome, "crash");
  const seen = JSON.parse(await readFile(probe, "utf8"));
  assert.equal(seen.env, "carried");
  // process.cwd() is the resolved path; macOS keeps its temp folder behind /var -> /private/var.
  assert.equal(seen.cwd, await realpath(temporary));
  assert.equal(
    seen.path,
    process.env.PATH,
    "the launch env adds to the harness env",
  );
});

// jev_run.gd prints the scenario's own judgement as one stdout line, because
// done.json is closed; the harness keeps it per trial and sums it per batch.
test("the scenario's own result from stdout reaches the trial entry and the batch record", async (t) => {
  const { runs } = await fixture(t);
  const fake = fakeGodot();
  const lines = [
    {
      id: "dummy-knock",
      result: "success",
      success_tick: 700,
      limit_ticks: 5400,
      tick: 700,
      knocks: { stomp: 1, ram: 2 },
      knocked: 3,
      lip: [],
    },
    {
      id: "dummy-knock",
      result: "timeout",
      success_tick: -1,
      limit_ticks: 5400,
      tick: 5401,
      knocks: { stomp: 0, ram: 1 },
      knocked: 1,
      lip: [],
    },
  ];
  const launch = (request) => {
    const { command, args } = fake(request);
    const line = `jev_run: scenario ${JSON.stringify(lines[request.trial])}`;
    return {
      command: process.execPath,
      args: [
        "-e",
        `console.log("Godot Engine banner");
         const run = require("node:child_process").spawnSync(${JSON.stringify(command)}, ${JSON.stringify(args)}, { stdio: "inherit" });
         console.log(${JSON.stringify(line)});
         console.log("jev_run: dummy-knock kinematic seed 0: complete at tick 700");
         process.exit(run.status ?? 1);`,
      ],
    };
  };
  launch.label = "fake-godot with a scenario line";
  const { record, trials } = await runBatch({
    scenario: "downhill-run",
    arm: "scripted",
    trials: 2,
    runs,
    launch,
  });
  assert.deepEqual(
    trials.map((entry) => entry.outcome),
    ["complete", "complete"],
  );
  assert.deepEqual(trials[0].scenario_result, lines[0]);
  assert.deepEqual(trials[1].scenario_result, lines[1]);
  assert.deepEqual(record.config.scenario_results, {
    success: 1,
    timeout: 1,
    running: 0,
    unreported: 0,
  });
  assert.deepEqual(record.kris.unreachable_scenarios, {
    value: 0,
    n: 1,
    ci: null,
  });
  assert.deepEqual(record.kpis.stomp_ram_split, {
    value: 0.25,
    n: 4,
    ci: null,
  });
});

test("a parameterised scenario such as kicker-gap@21 runs under a slug label", async (t) => {
  const { runs } = await fixture(t);
  const seen = [];
  const launch = (request) => {
    seen.push(request.scenario);
    return { command: process.execPath, args: ["-e", ""] };
  };
  const { record } = await runBatch({
    scenario: "kicker-gap@21.5",
    arm: "scripted",
    runs,
    launch,
  });
  assert.deepEqual(seen, ["kicker-gap@21.5"]);
  assert.equal(record.config.scenario, "kicker-gap@21.5");
  assert.match(record.id, /-kicker-gap-at-21p5-scripted-/);
  for (const scenario of ["kicker-gap@", "kicker-gap@fast", "@21", "a@1@2"]) {
    await assert.rejects(
      runBatch({ scenario, arm: "scripted", runs }),
      /is not a slug/,
      scenario,
    );
  }
});

test("a launch that prints no scenario line leaves the result unreported", async (t) => {
  const { runs } = await fixture(t);
  const { record, trials } = await runBatch({
    scenario: "downhill-run",
    arm: "scripted",
    runs,
  });
  assert.equal(trials[0].scenario_result, null);
  assert.deepEqual(record.config.scenario_results, {
    success: 0,
    timeout: 0,
    running: 0,
    unreported: 1,
  });
  assert.equal(record.kris.unreachable_scenarios, undefined);
  assert.equal(record.kpis.stomp_ram_split, undefined);
});

test("a stalled launch's whole process group is killed, not only its direct child", async (t) => {
  const { temporary, runs } = await fixture(t);
  const pidFile = path.join(temporary, "grandchild.pid");
  const hang = `require("node:fs").writeFileSync(${JSON.stringify(pidFile)}, String(process.pid)); setInterval(() => {}, 1000);`;
  // A wrapper shell that starts the real process and waits, as a Godot
  // launched through a script would.
  const launch = () => ({
    command: "/bin/sh",
    args: ["-c", `"${process.execPath}" -e '${hang}' & wait`],
  });
  const { trials } = await runBatch({
    scenario: "downhill-run",
    arm: "scripted",
    runs,
    launch,
    watchdogFloorMs: 1500,
  });
  assert.equal(trials[0].outcome, "stall");
  const pid = Number(await readFile(pidFile, "utf8"));
  t.after(() => {
    if (alive(pid)) process.kill(pid, "SIGKILL");
  });
  await until(() => !alive(pid), 2000, "the grandchild to die");
});

// A Godot stand-in that writes hello and state-000000, then waits for
// abort.json, and finishes as protocol v1 says: events.ndjson, then done.json
// {reason: aborted}.
const ABORTABLE = `
  import { existsSync, readFileSync, renameSync, writeFileSync } from "node:fs";
  import { createHash } from "node:crypto";
  import path from "node:path";
  const [io, fixtures] = process.argv.slice(1);
  const put = (name, text) => {
    writeFileSync(path.join(io, name + ".tmp"), text);
    renameSync(path.join(io, name + ".tmp"), path.join(io, name));
  };
  const hello = JSON.parse(readFileSync(path.join(fixtures, "hello.json"), "utf8"));
  put("hello.json", JSON.stringify({ ...hello, scenario: "downhill-run" }));
  put("state-000000.json", readFileSync(path.join(fixtures, "state-000000.json"), "utf8"));
  const timer = setInterval(() => {
    if (!existsSync(path.join(io, "abort.json"))) return;
    clearInterval(timer);
    put("events.ndjson", "");
    put("done.json", JSON.stringify({ protocol: "scrapkeep-jev/1", reason: "aborted", tick: 0,
      snapshots: 1, trace_hash: createHash("sha256").update("").digest("hex") }));
  }, 10);
`;

for (const signal of ["SIGTERM", "SIGINT"]) {
  test(`${signal} to the harness writes abort{interrupted}, ends the batch and keeps its record`, async (t) => {
    const { runs } = await fixture(t);
    const harness = pathToFileURL(path.join(root, "scripts/lab/harness.mjs"));
    const driver = `
      import { runBatch } from ${JSON.stringify(harness.href)};
      const launch = ({ io }) => ({
        command: process.execPath,
        args: ["--input-type=module", "-e", ${JSON.stringify(ABORTABLE)}, io,
          ${JSON.stringify(path.join(fixtures, "trial-aborted"))}],
      });
      const batch = await runBatch({ scenario: "downhill-run", arm: "scripted", trials: 3,
        runs: ${JSON.stringify(runs)}, launch, watchdogFloorMs: 20000 });
      process.stdout.write(JSON.stringify({ result: batch.record.result, trials: batch.trials,
        limits: batch.record.limits }));
    `;
    const child = spawn(
      process.execPath,
      ["--input-type=module", "-e", driver],
      {
        stdio: ["ignore", "pipe", "pipe"],
      },
    );
    t.after(() => {
      if (child.exitCode === null) child.kill("SIGKILL");
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => (stdout += chunk));
    child.stderr.on("data", (chunk) => (stderr += chunk));
    const exited = new Promise((resolve) =>
      child.on("exit", (code, killedBy) => resolve({ code, killedBy })),
    );
    let intent = null;
    await until(
      async () =>
        (intent = await findFile(runs.root, fileName("intent", 0))) !== null,
      10_000,
      "the harness to answer state-000000",
    );
    child.kill(signal);
    const ended = await exited;
    assert.deepEqual(
      ended,
      { code: 0, killedBy: null },
      `the harness outlives the signal to finish its record; stderr: ${stderr}`,
    );
    const io = path.dirname(intent);
    const abort = JSON.parse(
      await readFile(path.join(io, "abort.json"), "utf8"),
    );
    assert.deepEqual(
      { protocol: abort.protocol, reason: abort.reason },
      { protocol: PROTOCOL, reason: "interrupted" },
    );
    assert.match(abort.message, new RegExp(signal));
    const batch = JSON.parse(stdout);
    assert.equal(batch.trials.length, 1, "no trial starts after the signal");
    assert.equal(batch.trials[0].outcome, "aborted");
    assert.equal(batch.trials[0].abort.cause, "interrupted");
    assert.equal(batch.result, "inconclusive");
    assert.ok(batch.limits.some((line) => line.includes(signal)));
  });
}

// --- the launcher -------------------------------------------------------------

test("godotLaunch runs jev_run.gd headless at 90 fixed fps with the scenario, seed, D, k and output directory", () => {
  const launch = godotLaunch({ mode: "rigid", maxTicks: 180 });
  const { command, args, env } = launch({
    io: "/tmp/io",
    scenario: "downhill-run",
    seed: 1002,
    trial: 2,
    snapshotEvery: 45,
    holdTicks: 0,
  });
  assert.equal(command, GODOT_BINARY);
  const split = args.indexOf("--");
  const engine = args.slice(0, split);
  const user = args.slice(split + 1);
  assert.ok(engine.includes("--headless"));
  assert.equal(engine[engine.indexOf("--fixed-fps") + 1], "90");
  assert.equal(engine[engine.indexOf("--path") + 1], SKETCH);
  assert.equal(engine[engine.indexOf("--script") + 1], RUNNER);
  assert.equal(RUNNER, "res://src/jev/jev_run.gd");
  assert.deepEqual(user, [
    "--io=/tmp/io",
    "--scenario=downhill-run",
    "--seed=1002",
    "--mode=rigid",
    "--snapshot-every=45",
    "--hold-ticks=0",
    "--max-ticks=180",
  ]);
  assert.equal(typeof env, "object");
  assert.match(launch.label, /godot/);
  assert.match(launch.label, /rigid/);
  assert.throws(() => godotLaunch({ mode: "floaty" }), /mode/);
});

// --- real Godot ------------------------------------------------------------------

// Plays the Node side of one trial against a real Godot process: the scripted
// arm answers each snapshot after delays(seq) ms. `answer` overrides the intent
// file for a seq, `silent` stops answering from that seq on.
async function drive(
  t,
  {
    mode,
    seed = 7,
    scenario = "downhill-run",
    holdTicks = TIMING.hold_ticks,
    armName = "scripted",
    delays = () => 0,
    answer,
    silent,
    intentTimeoutS,
    maxTicks = BRIDGE_TICKS,
    io,
  },
) {
  await mkdir(io, { recursive: true });
  const launch = godotLaunch({ mode, maxTicks, intentTimeoutS });
  const { command, args, env } = launch({
    io,
    scenario,
    seed,
    trial: 0,
    snapshotEvery: TIMING.snapshot_every,
    holdTicks,
  });
  const child = spawn(command, args, {
    env: { ...process.env, ...env },
    detached: true,
    stdio: ["ignore", "pipe", "pipe"],
  });
  t.after(() => {
    try {
      process.kill(-child.pid, "SIGKILL");
    } catch {
      // Already gone.
    }
  });
  let stdout = "";
  child.stdout.on("data", (chunk) => (stdout += chunk));
  child.stderr.on("data", (chunk) => (stdout += chunk));
  let code = null;
  const exited = new Promise((resolve) =>
    child.on("exit", (exitCode) => {
      code = exitCode;
      resolve();
    }),
  );
  const arm = createArm(armName, { seed });
  let multi = 0;
  const started = Date.now();
  for (let seq = 0; ; seq += 1) {
    const name = fileName("state", seq);
    let present = [];
    while (
      !(present = await readdir(io)).some((file) =>
        [name, "done.json", "error.json"].includes(file),
      )
    ) {
      if (code !== null) break;
      if (Date.now() - started > 90_000) assert.fail(`no ${name} in 90 s`);
      await sleep(2);
    }
    if (!present.includes(name)) break;
    if (silent !== undefined && seq >= silent) break;
    const state = JSON.parse(await readFile(path.join(io, name), "utf8"));
    const offered = offeredOptions(state.jev);
    if (offered.length > 1) multi += 1;
    const choice =
      offered.length === 1
        ? { intent: offered[0].id, source: "forced", meta: arm.forcedMeta() }
        : await arm.choose({
            seq,
            state: state.jev.state,
            offered,
            jev: state.jev,
          });
    const intent = {
      protocol: PROTOCOL,
      seq,
      intent: choice.intent,
      arm: armName,
      source: choice.source,
      meta: choice.meta,
      ...(answer?.(seq, offered, choice) ?? {}),
    };
    await sleep(delays(seq));
    await writeAtomic(path.join(io, fileName("intent", seq)), intent);
  }
  await exited;
  const files = {};
  for (const name of await readdir(io)) {
    if (!name.endsWith(".tmp"))
      files[name] = await readFile(path.join(io, name), "utf8");
  }
  return { code, files, stdout, multi };
}

const events = (files) =>
  files["events.ndjson"]
    .split("\n")
    .filter((line) => line !== "")
    .map((line) => JSON.parse(line));

// One delay per seq from a seeded stream: none, short, and long enough that
// Godot must block at t + k for every intent.
const PATTERNS = {
  none: () => () => 0,
  short: (seed) => {
    const next = seededRandom(seed);
    return () => Math.floor(next() * 40);
  },
  long: (seed) => {
    const next = seededRandom(seed);
    return () => 120 + Math.floor(next() * 200);
  },
};

for (const mode of MODES) {
  test(
    `bridge, ${mode}: every intent applies at state.tick + k and trace_hash ignores responder delays`,
    { skip: noGodot, timeout: 240_000 },
    async (t) => {
      const { temporary } = await fixture(t);
      const runs = {};
      for (const [name, pattern] of Object.entries(PATTERNS)) {
        const io = path.join(temporary, mode, name);
        const result = await drive(t, {
          mode,
          io,
          delays: pattern(17 + name.length),
        });
        const trace = JSON.parse(result.files["done.json"]);
        assert.equal(result.code, 0, result.stdout);
        assert.deepEqual(validateTrial(result.files), [], `${mode}/${name}`);
        assert.equal(trace.reason, "complete");
        const hello = JSON.parse(result.files["hello.json"]);
        assert.equal(hello.physics_mode, mode);
        assert.deepEqual(
          [
            hello.tick_hz,
            hello.snapshot_every,
            hello.hold_ticks,
            hello.intent_timeout_s,
          ],
          [
            TIMING.tick_hz,
            TIMING.snapshot_every,
            TIMING.hold_ticks,
            TIMING.intent_timeout_s,
          ],
        );
        const applied = events(result.files).filter(
          (event) => event.kind === "intent",
        );
        assert.ok(applied.length >= 1, `${mode}/${name} applied no intent`);
        for (const event of applied) {
          assert.equal(
            event.tick,
            event.seq * TIMING.snapshot_every + TIMING.hold_ticks,
            `${mode}/${name} intent ${event.seq}`,
          );
        }
        const summary =
          /blocked (\d+) of (\d+) intents; (\d+) frames, (\d+) ticks/.exec(
            result.stdout,
          );
        assert.ok(summary, `jev_run prints its summary: ${result.stdout}`);
        const [blocked, intents, frames, ticks] = summary.slice(1).map(Number);
        assert.equal(intents, applied.length);
        assert.equal(
          frames,
          ticks,
          "one process frame per physics tick (--fixed-fps 90)",
        );
        if (name === "long")
          assert.equal(
            blocked,
            intents,
            `${mode}/long blocks for every intent`,
          );
        runs[name] = {
          hash: trace.trace_hash,
          blocked,
          intents,
          tick: trace.tick,
        };
      }
      t.diagnostic(`${mode}: ${JSON.stringify(runs)}`);
      const hashes = new Set(Object.values(runs).map((run) => run.hash));
      if (mode === "rigid" && hashes.size > 1) {
        t.diagnostic(
          `rigid: STOCHASTIC, ${hashes.size} distinct trace_hash values over ${Object.keys(runs).length} delay patterns`,
        );
        return;
      }
      assert.equal(
        hashes.size,
        1,
        `${mode} trace_hash differs across delay patterns`,
      );
    },
  );
}

// JL-21 (JL-17 review, N5): the same property on a contact scenario whose
// snapshots offer real choices, so intent timing could matter; the three
// delay patterns are also three repeated runs of identical inputs. Rigid mode
// makes contact too, but the game does not credit a rigid stomp (the known
// limit in jev_agent_test.gd), so only kinematic must show knock events.
const CONTACT = {
  scenario: "dummy-knock",
  maxTicks: 10 * TIMING.snapshot_every,
};
const traceHash = (result) => JSON.parse(result.files["done.json"]).trace_hash;

for (const mode of MODES) {
  test(
    `bridge, ${mode}: dummy-knock, with choices and knocks, keeps one trace_hash across responder delays`,
    { skip: noGodot, timeout: 240_000 },
    async (t) => {
      const { temporary } = await fixture(t);
      const runs = {};
      for (const [name, pattern] of Object.entries(PATTERNS)) {
        const result = await drive(t, {
          mode,
          ...CONTACT,
          io: path.join(temporary, mode, name),
          delays: pattern(31 + name.length),
        });
        assert.equal(result.code, 0, result.stdout);
        assert.deepEqual(validateTrial(result.files), [], `${mode}/${name}`);
        const done = JSON.parse(result.files["done.json"]);
        runs[name] = {
          hash: done.trace_hash,
          snapshots: done.snapshots,
          multi: result.multi,
          knocks: events(result.files).filter((e) => e.kind === "knock")
            .length,
        };
      }
      t.diagnostic(`${mode}: ${JSON.stringify(runs)}`);
      for (const [name, run] of Object.entries(runs)) {
        if (mode === "kinematic")
          assert.ok(run.knocks >= 1, `${mode}/${name} made contact`);
        assert.ok(
          run.multi * 2 > run.snapshots,
          `${mode}/${name}: most snapshots offer two or more options`,
        );
      }
      const hashes = new Set(Object.values(runs).map((run) => run.hash));
      if (mode === "rigid" && hashes.size > 1) {
        t.diagnostic(
          `rigid: STOCHASTIC, ${hashes.size} distinct trace_hash values over ${Object.keys(runs).length} runs`,
        );
        return;
      }
      assert.equal(hashes.size, 1, `${mode} trace_hash differs across delays`);
    },
  );
}

// The negative control: hash equality above is only evidence if the hash
// moves when the inputs do. A later k, or one different answer, must change it,
// and the changed answer must leave every event before it applies untouched.
test(
  "bridge, kinematic: trace_hash changes when k or one answer changes",
  { skip: noGodot, timeout: 120_000 },
  async (t) => {
    const { temporary } = await fixture(t);
    const base = await drive(t, {
      mode: "kinematic",
      ...CONTACT,
      io: path.join(temporary, "base"),
    });
    const laterK = await drive(t, {
      mode: "kinematic",
      ...CONTACT,
      holdTicks: 54,
      io: path.join(temporary, "k54"),
    });
    let changed = null;
    const otherAnswer = await drive(t, {
      mode: "kinematic",
      ...CONTACT,
      io: path.join(temporary, "answer"),
      answer: (seq, offered, choice) => {
        if (changed !== null || seq < 3 || offered.length < 2) return undefined;
        changed = seq;
        return { intent: offered.find((one) => one.id !== choice.intent).id };
      },
    });
    for (const result of [base, laterK, otherAnswer]) {
      assert.equal(result.code, 0, result.stdout);
      assert.deepEqual(validateTrial(result.files), []);
    }
    assert.notEqual(changed, null, "some snapshot offered a choice");
    assert.notEqual(traceHash(laterK), traceHash(base), "k 54 vs 26");
    assert.notEqual(traceHash(otherAnswer), traceHash(base), "one answer");
    const applies = changed * TIMING.snapshot_every + TIMING.hold_ticks;
    const before = (result) =>
      events(result.files).filter((event) => event.tick < applies);
    assert.deepEqual(before(otherAnswer), before(base));
    t.diagnostic(
      `base ${traceHash(base)}, k54 ${traceHash(laterK)}, answer changed at seq ${changed} ${traceHash(otherAnswer)}`,
    );
  },
);

// JL-21b (JL-21 review, F1): a dummy knocked in this trial is no longer a
// threat. sim.knocked and sim.threat_ids name the dummies (lab indices), so a
// knocked dummy that was a threat must be absent from every later state.
test(
  "bridge, kinematic: a knocked dummy leaves the threats of every later state",
  { skip: noGodot, timeout: 120_000 },
  async (t) => {
    const { temporary } = await fixture(t);
    const result = await drive(t, {
      mode: "kinematic",
      ...CONTACT,
      io: path.join(temporary, "knocked"),
    });
    assert.equal(result.code, 0, result.stdout);
    assert.deepEqual(validateTrial(result.files), []);
    const states = Object.keys(result.files)
      .filter((name) => /^state-\d+\.json$/.test(name))
      .sort()
      .map((name) => JSON.parse(result.files[name]));
    const wasThreat = new Set();
    const leftAfterThreat = new Set();
    let everKnocked = [];
    for (const state of states) {
      const { threat_ids: ids, knocked } = state.sim;
      assert.ok(Array.isArray(ids) && Array.isArray(knocked), `seq ${state.seq} sim`);
      assert.equal(ids.length, state.jev.state.threats.length, `seq ${state.seq}`);
      for (const dummy of everKnocked) {
        assert.ok(knocked.includes(dummy), `seq ${state.seq}: dummy ${dummy} stays knocked`);
      }
      for (const dummy of knocked) {
        assert.ok(!ids.includes(dummy), `seq ${state.seq}: knocked dummy ${dummy} is still a threat`);
        if (wasThreat.has(dummy)) leftAfterThreat.add(dummy);
      }
      for (const dummy of ids) wasThreat.add(dummy);
      everKnocked = knocked;
    }
    assert.ok(
      leftAfterThreat.size >= 1,
      `some dummy was a threat, was knocked, and left the threats (knocked ${JSON.stringify(everKnocked)} over ${states.length} states)`,
    );
    t.diagnostic(
      `knocked ${JSON.stringify(everKnocked)}; left the threats after being one: ${JSON.stringify([...leftAfterThreat])}`,
    );
  },
);

test(
  "bridge: the harness drives real Godot through godotLaunch to the same trace",
  { skip: noGodot, timeout: 120_000 },
  async (t) => {
    const { temporary, runs } = await fixture(t);
    const { record, trials } = await runBatch({
      scenario: "downhill-run",
      arm: "scripted",
      seed: 0,
      runs,
      launch: godotLaunch({ mode: "kinematic", maxTicks: BRIDGE_TICKS }),
    });
    assert.equal(trials[0].outcome, "complete", JSON.stringify(trials[0]));
    assert.deepEqual(trials[0].errors, []);
    assert.match(record.config.launcher, /godot/);
    // The trial ends at tick 450, a multiple of D: no state is written there
    // (JL-17 review, N1), and max-ticks leaves the scenario running.
    const done = JSON.parse(
      await readFile(path.join(runs.root, record.id, trials[0].io, "done.json"), "utf8"),
    );
    assert.equal(done.tick, BRIDGE_TICKS);
    assert.equal(trials[0].snapshots, BRIDGE_TICKS / TIMING.snapshot_every);
    assert.equal(done.snapshots, trials[0].snapshots);
    assert.equal(trials[0].scenario_result?.id, "downhill-run");
    assert.equal(trials[0].scenario_result?.result, "running");
    assert.equal(trials[0].scenario_result?.tick, BRIDGE_TICKS);
    assert.deepEqual(record.config.scenario_results, {
      success: 0,
      timeout: 0,
      running: 1,
      unreported: 0,
    });
    const direct = await drive(t, {
      mode: "kinematic",
      seed: 0,
      io: path.join(temporary, "direct"),
    });
    assert.equal(
      JSON.parse(direct.files["done.json"]).trace_hash,
      trials[0].trace_hash,
    );
  },
);

// JL-21's limit calibration probes past a scenario's limit when the scripted
// p90 is censored there; --time-limit-s replaces the limit for that trial.
test(
  "bridge: --time-limit-s replaces the scenario's limit and the result line reports it",
  { skip: noGodot, timeout: 60_000 },
  async (t) => {
    const { runs } = await fixture(t);
    const base = godotLaunch({ mode: "kinematic" });
    const launch = (request) => {
      const spec = base(request);
      return { ...spec, args: [...spec.args, "--time-limit-s=2"] };
    };
    launch.label = `${base.label} time-limit 2 s`;
    const { trials } = await runBatch({
      scenario: "downhill-run",
      arm: "scripted",
      seed: 0,
      runs,
      launch,
    });
    assert.equal(trials[0].outcome, "complete", JSON.stringify(trials[0]));
    assert.deepEqual(trials[0].errors, []);
    const result = trials[0].scenario_result;
    assert.equal(result.limit_ticks, 2 * TIMING.tick_hz);
    assert.equal(result.result, "timeout");
    assert.equal(result.tick, 2 * TIMING.tick_hz + 1);
  },
);

// JL-21b: run-to-pad's limit is per physics mode (scenarios.gd MODE_LIMITS_S),
// chosen when jev_run.gd places the ball; --time-limit-s always wins, even one
// equal to the initial limit (JL-21b-A2).
test(
  "bridge: the runner takes the scenario's limit for its physics mode, and an override still wins",
  { skip: noGodot, timeout: 60_000 },
  async (t) => {
    const { runs } = await fixture(t);
    const limitTicks = async (mode, override) => {
      const base = godotLaunch({ mode, maxTicks: TIMING.snapshot_every });
      const launch = (request) => {
        const spec = base(request);
        const extra = override === undefined ? [] : [`--time-limit-s=${override}`];
        return { ...spec, args: [...spec.args, ...extra] };
      };
      launch.label = base.label;
      const { trials } = await runBatch({ scenario: "run-to-pad", arm: "scripted", seed: 0, runs, launch });
      assert.equal(trials[0].outcome, "complete", JSON.stringify(trials[0]));
      return trials[0].scenario_result.limit_ticks;
    };
    assert.equal(await limitTicks("kinematic"), 61 * TIMING.tick_hz);
    assert.equal(await limitTicks("rigid"), 45 * TIMING.tick_hz);
    assert.equal(await limitTicks("kinematic", 135), 135 * TIMING.tick_hz);
    assert.equal(await limitTicks("kinematic", 45), 45 * TIMING.tick_hz);
  },
);

test(
  "bridge: no intent within the timeout is error intent_timeout at the blocking tick, exit 5",
  { skip: noGodot, timeout: 60_000 },
  async (t) => {
    const { temporary } = await fixture(t);
    const result = await drive(t, {
      mode: "kinematic",
      io: path.join(temporary, "timeout"),
      silent: 1,
      intentTimeoutS: 1,
    });
    assert.equal(result.code, 5, result.stdout);
    const error = JSON.parse(result.files["error.json"]);
    assert.equal(error.code, "intent_timeout");
    assert.equal(error.seq, 1);
    assert.equal(error.tick, TIMING.snapshot_every + TIMING.hold_ticks);
    assert.deepEqual(validateTrial(result.files), []);
  },
);

test(
  "bridge: an intent that is not offered is error intent_invalid, exit 4",
  { skip: noGodot, timeout: 60_000 },
  async (t) => {
    const { temporary } = await fixture(t);
    const result = await drive(t, {
      mode: "kinematic",
      io: path.join(temporary, "invalid"),
      answer: (seq) =>
        seq === 1 ? { intent: "take_cache", source: "rule" } : {},
    });
    assert.equal(result.code, 4, result.stdout);
    const error = JSON.parse(result.files["error.json"]);
    assert.equal(error.code, "intent_invalid");
    assert.equal(error.seq, 1);
  },
);

test(
  "bridge: abort.json while Godot blocks ends the trial as done{aborted}, exit 0",
  { skip: noGodot, timeout: 60_000 },
  async (t) => {
    const { temporary } = await fixture(t);
    const io = path.join(temporary, "abort");
    const pending = drive(t, { mode: "kinematic", io, silent: 1 });
    await until(
      () => existsSync(path.join(io, fileName("state", 1))),
      30_000,
      "state-000001",
    );
    await writeAtomic(path.join(io, "abort.json"), {
      protocol: PROTOCOL,
      reason: "interrupted",
    });
    const result = await pending;
    assert.equal(result.code, 0, result.stdout);
    assert.equal(JSON.parse(result.files["done.json"]).reason, "aborted");
    assert.deepEqual(validateTrial(result.files), []);
  },
);

test(
  "bridge: an unknown scenario is error internal, exit 1",
  { skip: noGodot, timeout: 60_000 },
  async (t) => {
    const { temporary } = await fixture(t);
    const io = path.join(temporary, "unknown");
    await mkdir(io, { recursive: true });
    const { command, args } = godotLaunch()({
      io,
      scenario: "no-such-scenario",
      seed: 0,
      trial: 0,
      snapshotEvery: TIMING.snapshot_every,
      holdTicks: TIMING.hold_ticks,
    });
    const result = spawnSync(command, args, {
      encoding: "utf8",
      timeout: 30_000,
    });
    assert.equal(result.status, 1, result.stdout + result.stderr);
    const error = JSON.parse(
      await readFile(path.join(io, "error.json"), "utf8"),
    );
    assert.deepEqual(
      [error.code, error.seq, error.tick],
      ["internal", null, 0],
    );
    assert.match(error.message, /no-such-scenario/);
  },
);

test(
  "the godot-launch CLI exits 2 on a harness usage error, before any Godot process",
  { skip: noGodot },
  () => {
    const result = spawnSync(
      process.execPath,
      [
        path.join(root, "scripts/lab/godot-launch.mjs"),
        "downhill-run",
        "--hold-ticks",
        "90",
      ],
      { encoding: "utf8", timeout: 30_000 },
    );
    assert.equal(result.status, 2, result.stdout + result.stderr);
    assert.match(result.stderr, /holdTicks \(k\)/);
    assert.doesNotMatch(result.stderr, /at .*harness\.mjs/);
  },
);

test("godot-launch.mjs runs the Godot binary sketch-smoke pins", () => {
  assert.equal(GODOT_BINARY, smokeBinary);
});
