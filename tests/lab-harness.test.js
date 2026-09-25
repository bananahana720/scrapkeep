// JL-11: the trial harness and its arms, run against fake-godot.mjs. No real
// Godot process and no Jev call: the jev arm is a stub that throws, so a trial
// that reaches it aborts instead of spending anything.
import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import {
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  rm,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  offeredOptions as decideOffered,
  INTENTS,
} from "../tools/jev-player/decide.mjs";
import {
  offeredOptions as protocolOffered,
  validateTrial,
  watchdogMs,
  WATCHDOG_FLOOR_MS,
} from "../tools/jev-player/protocol/protocol.mjs";
import { SCHEMA } from "../scripts/lab/record.mjs";
import { createArm, seededRandom } from "../scripts/lab/arms.mjs";
import {
  DEFAULTS,
  fakeGodot,
  runBatch,
  watchdogLimit,
} from "../scripts/lab/harness.mjs";
import { SCENARIOS } from "../scripts/lab/fake-godot.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

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

// A throwaway repository for provenance and a runs root outside it, so no
// case touches the real artifacts/local/runs or hashes the real tree.
async function fixture(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-harness-"));
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
  // Normal trials never come near this floor; only the stall case lowers it.
  return (options) => runBatch({ watchdogFloorMs: 10_000, runs, ...options });
}

async function readTrial(io) {
  const files = {};
  for (const name of await readdir(io)) {
    files[name] = await readFile(path.join(io, name), "utf8");
  }
  return files;
}

async function intentsOf(io) {
  const files = await readTrial(io);
  return Object.keys(files)
    .filter((name) => name.startsWith("intent-"))
    .sort()
    .map((name) => JSON.parse(files[name]));
}

// --- DoD 4: one fallback, owned by decide.mjs -------------------------------

test("protocol.mjs judges offered options with decide.mjs's own function", () => {
  assert.equal(protocolOffered, decideOffered);
  const gated = {
    state: { self: { speed_ms: 4, speed_tier: "walk", grounded: true } },
    options: [{ id: "hit_kicker", why: "ramp", requires_speed_ms: 26 }],
  };
  assert.deepEqual(decideOffered(gated), [
    { id: "push_objective", why: INTENTS.push_objective },
  ]);
});

// --- the watchdog ------------------------------------------------------------

test("the watchdog limit is max(floor, 20 x median step) and defaults to the 30 s floor", () => {
  assert.equal(DEFAULTS.watchdogFloorMs, WATCHDOG_FLOOR_MS);
  for (const steps of [
    [],
    [100, 200, 300],
    [1000, 4000, 2000],
    [3000, 1000, 2000, 4000, 5000],
  ]) {
    assert.equal(watchdogLimit(steps, WATCHDOG_FLOOR_MS), watchdogMs(steps));
  }
  assert.equal(watchdogLimit([], 500), 500);
  assert.equal(watchdogLimit([10, 20, 30], 100), 400);
  assert.equal(watchdogLimit([10, 20, 30, 40], 100), 400);
  assert.equal(watchdogLimit([1, 2, 3], 100), 100);
});

// --- arms --------------------------------------------------------------------

const options = (...ids) => ids.map((id) => ({ id, why: INTENTS[id] }));
const openState = {
  self: {
    speed_ms: 18,
    speed_tier: "fast",
    grounded: true,
    air_jump_available: true,
  },
  stage: { name: "t", time_s: 0, tier: 1 },
  threats: [{ kind: "dummy", distance_m: 9 }],
  objective: { kind: "pad", distance_m: 40 },
};

test("the random arm repeats its choices for a seed and records the seed", async () => {
  const offered = options(
    "push_objective",
    "stomp_target",
    "ram_target",
    "evade_hazard",
  );
  const play = async (seed) => {
    const arm = createArm("random", { seed });
    const picks = [];
    for (let seq = 0; seq < 24; seq += 1) {
      const choice = await arm.choose({ seq, state: openState, offered });
      assert.equal(choice.source, "seeded");
      assert.equal(choice.meta.seed, seed);
      assert.ok(offered.some((option) => option.id === choice.intent));
      picks.push(choice.intent);
    }
    return picks;
  };
  assert.deepEqual(await play(7), await play(7));
  assert.notDeepEqual(await play(7), await play(8));
  const a = seededRandom(3);
  const b = seededRandom(3);
  for (let i = 0; i < 5; i += 1) assert.equal(a(), b());
});

test("the scripted arm is a deterministic rule ladder over the offered options", async () => {
  const arm = createArm("scripted");
  const hazard = {
    ...openState,
    threats: [
      { kind: "pillar", distance_m: 6, on_current_line: true, closing: true },
    ],
  };
  const evade = await arm.choose({
    seq: 0,
    state: hazard,
    offered: options("push_objective", "evade_hazard"),
  });
  assert.equal(evade.intent, "evade_hazard");
  assert.equal(evade.source, "rule");
  assert.equal(typeof evade.meta.rule, "string");
  const ram = await arm.choose({
    seq: 1,
    state: openState,
    offered: options("push_objective", "ram_target", "stomp_target"),
  });
  assert.equal(ram.intent, "ram_target");
  const push = await arm.choose({
    seq: 2,
    state: openState,
    offered: options("push_objective", "sweep_scrap"),
  });
  assert.equal(push.intent, "sweep_scrap");
});

test("the jev arm is a stub that throws and never calls out", async () => {
  const arm = createArm("jev");
  assert.match(arm.forcedMeta().questions_sha, /^[0-9a-f]{64}$/);
  await assert.rejects(
    arm.choose({
      seq: 0,
      state: openState,
      offered: options("push_objective", "ram_target"),
    }),
    /JL-14/,
  );
  for (const file of [
    "scripts/lab/arms.mjs",
    "scripts/lab/harness.mjs",
    "scripts/lab/fake-godot.mjs",
  ]) {
    const text = await readFile(path.join(root, file), "utf8");
    assert.doesNotMatch(text, /\bfetch\s*\(|\bdecide\s*\(/, file);
  }
});

test("every plan section 3 scenario is scripted in the fake", () => {
  for (const name of [
    "downhill-run",
    "run-to-pad",
    "bench-climb",
    "kicker-gap",
    "dummy-knock",
    "pillar-weave",
    "soak",
  ]) {
    assert.ok(
      Array.isArray(SCENARIOS[name]) && SCENARIOS[name].length > 0,
      name,
    );
  }
});

// --- DoD 1: batches and records ---------------------------------------------

test("a seeded random batch writes one valid <io> per trial and one run record", async (t) => {
  const run = await fixture(t);
  const first = await run({
    scenario: "downhill-run",
    arm: "random",
    trials: 3,
    seed: 7,
  });
  const { record, trials } = first;
  assert.equal(record.schema, SCHEMA);
  assert.equal(record.config.scenario, "downhill-run");
  assert.equal(record.config.arm, "random");
  assert.equal(record.config.seed, 7);
  assert.equal(record.config.call_cap, DEFAULTS.callCap);
  assert.equal(record.config.trials.length, 3);
  assert.deepEqual(record.kris.trial_abort_rate.value, 0);
  assert.equal(record.kris.trial_abort_rate.n, 3);
  assert.equal(record.result, "pass");
  const onDisk = JSON.parse(
    await readFile(path.join(first.directory, "run.json"), "utf8"),
  );
  assert.deepEqual(onDisk.config.trials, record.config.trials);
  const dirs = new Set();
  for (const trial of trials) {
    assert.equal(trial.outcome, "complete");
    assert.deepEqual(trial.errors, []);
    const io = path.join(first.directory, trial.io);
    dirs.add(io);
    assert.deepEqual(validateTrial(await readTrial(io)), []);
    assert.equal(trial.snapshots, SCENARIOS["downhill-run"].length);
  }
  assert.equal(dirs.size, 3);

  const again = await run({
    scenario: "downhill-run",
    arm: "random",
    trials: 3,
    seed: 7,
  });
  for (let i = 0; i < 3; i += 1) {
    const before = await intentsOf(path.join(first.directory, trials[i].io));
    const after = await intentsOf(
      path.join(again.directory, again.trials[i].io),
    );
    assert.deepEqual(after, before);
    assert.equal(again.trials[i].seed, trials[i].seed);
  }
});

test("a scripted batch completes with rule-sourced intents", async (t) => {
  const run = await fixture(t);
  const { record, trials, directory } = await run({
    scenario: "pillar-weave",
    arm: "scripted",
    trials: 2,
  });
  assert.equal(record.result, "pass");
  for (const trial of trials) {
    assert.equal(trial.outcome, "complete");
    const intents = await intentsOf(path.join(directory, trial.io));
    assert.ok(intents.every((intent) => intent.arm === "scripted"));
    assert.ok(intents.some((intent) => intent.source === "rule"));
  }
});

// --- DoD 3: forced ------------------------------------------------------------

test("a single offered option is answered forced without calling the arm", async (t) => {
  const run = await fixture(t);
  // run-to-pad offers only push_objective; kicker-gap offers the kicker alone,
  // and below its speed the gate leaves only the push_objective fallback. The
  // jev stub would throw if asked.
  for (const scenario of ["run-to-pad", "kicker-gap"]) {
    const { trials, directory } = await run({
      scenario,
      arm: "jev",
      trials: 1,
    });
    const [trial] = trials;
    assert.equal(trial.outcome, "complete", scenario);
    assert.equal(trial.arm_calls, 0);
    assert.equal(trial.forced, trial.intents);
    const intents = await intentsOf(path.join(directory, trial.io));
    assert.ok(intents.length > 0);
    for (const intent of intents) {
      assert.equal(intent.source, "forced");
      assert.match(intent.meta.questions_sha, /^[0-9a-f]{64}$/);
    }
  }
});

test("the jev stub aborts a trial with arm_error once a real choice is needed", async (t) => {
  const run = await fixture(t);
  const { trials, directory, record } = await run({
    scenario: "pillar-weave",
    arm: "jev",
    trials: 1,
  });
  const [trial] = trials;
  assert.equal(trial.outcome, "aborted");
  assert.equal(trial.abort.reason, "arm_error");
  const files = await readTrial(path.join(directory, trial.io));
  assert.equal(JSON.parse(files["abort.json"]).reason, "arm_error");
  assert.equal(JSON.parse(files["done.json"]).reason, "aborted");
  assert.equal(record.kris.trial_abort_rate.value, 1);
});

// --- DoD 2: stall, crash, invalid --------------------------------------------

test("a stalled fake is killed by the watchdog and recorded as stall", async (t) => {
  const run = await fixture(t);
  const started = Date.now();
  const { trials, record } = await run({
    scenario: "downhill-run",
    arm: "scripted",
    launch: fakeGodot({ stallAt: 1 }),
    watchdogFloorMs: 3000,
  });
  const [trial] = trials;
  assert.equal(trial.outcome, "stall");
  assert.equal(trial.waiting_for, "state-000001.json");
  assert.equal(trial.exit.signal, "SIGKILL");
  assert.ok(trial.watchdog_ms >= 3000);
  assert.ok(Date.now() - started < 15_000);
  assert.equal(record.kris.trial_abort_rate.value, 1);
  assert.equal(record.result, "fail");
});

test("an exit with no done.json is a crash", async (t) => {
  const run = await fixture(t);
  const { trials, directory } = await run({
    scenario: "downhill-run",
    arm: "random",
    launch: fakeGodot({ crashAt: 2 }),
  });
  const [trial] = trials;
  assert.equal(trial.outcome, "crash");
  assert.notEqual(trial.exit.code, 0);
  assert.equal(existsSync(path.join(directory, trial.io, "done.json")), false);
  assert.equal(trial.events_tmp_only, true);
});

test("an invalid state from Godot writes abort arm_error and records invalid", async (t) => {
  const run = await fixture(t);
  const { trials, directory, record } = await run({
    scenario: "downhill-run",
    arm: "scripted",
    launch: fakeGodot({ invalidAt: 1 }),
  });
  const [trial] = trials;
  assert.equal(trial.outcome, "invalid");
  assert.equal(trial.abort.reason, "arm_error");
  assert.match(trial.abort.message, /state-000001\.json/);
  const files = await readTrial(path.join(directory, trial.io));
  assert.equal(JSON.parse(files["abort.json"]).reason, "arm_error");
  // The fake honours abort.json the way Godot must: done.json, reason aborted.
  assert.equal(JSON.parse(files["done.json"]).reason, "aborted");
  assert.equal(files["intent-000001.json"], undefined);
  assert.ok(
    trial.errors.some((error) => error.path.startsWith("state-000001.json:")),
  );
  assert.equal(record.result, "invalid");
});

test("an error.json from Godot is recorded by its code", async (t) => {
  const run = await fixture(t);
  const { trials } = await run({
    scenario: "downhill-run",
    arm: "scripted",
    launch: fakeGodot({ errorAt: 1 }),
  });
  assert.equal(trials[0].outcome, "error:internal");
  assert.equal(trials[0].exit.code, 1);
});

// --- DoD 5: the per-batch call cap -----------------------------------------------

test("the per-batch call cap stops the batch before the arm is called past it", async (t) => {
  const run = await fixture(t);
  assert.ok(Number.isInteger(DEFAULTS.callCap) && DEFAULTS.callCap > 0);
  const { trials, record } = await run({
    scenario: "pillar-weave",
    arm: "scripted",
    trials: 3,
    callCap: 2,
  });
  assert.equal(trials.length, 1);
  assert.equal(trials[0].outcome, "aborted");
  assert.equal(trials[0].arm_calls, 2);
  assert.equal(trials[0].abort.reason, "arm_error");
  assert.match(trials[0].abort.message, /call cap/);
  assert.equal(record.config.capped, true);
  assert.equal(record.config.arm_calls, 2);
  assert.ok(record.limits.some((line) => /call cap/.test(line)));
});

// Any process can stand in for Godot through `launch`. This one writes files
// that each pass their own validator but not validateTrial() as a whole: the
// done.json trace_hash is well formed and wrong.
test("a trial whose files fail validateTrial() as a whole is invalid", async (t) => {
  const run = await fixture(t);
  const script = `
    import { renameSync, writeFileSync } from "node:fs";
    import path from "node:path";
    const io = process.argv[1];
    const put = (name, value) => {
      const file = path.join(io, name);
      writeFileSync(file + ".tmp", typeof value === "string" ? value : JSON.stringify(value));
      renameSync(file + ".tmp", file);
    };
    put("hello.json", { protocol: "scrapkeep-jev/1", sketch: "stub", scenario: "downhill-run",
      seed: 0, physics_mode: "kinematic", godot: "stub", tick_hz: 90, snapshot_every: 90,
      hold_ticks: 26, intent_timeout_s: 30 });
    put("events.ndjson", "");
    put("done.json", { protocol: "scrapkeep-jev/1", reason: "complete", tick: 0, snapshots: 0,
      trace_hash: "0".repeat(64) });
  `;
  const launch = ({ io }) => ({
    command: process.execPath,
    args: ["--input-type=module", "-e", script, io],
  });
  const { trials, record } = await run({
    scenario: "downhill-run",
    arm: "scripted",
    launch,
  });
  assert.equal(record.config.launcher, "custom");
  assert.equal(trials[0].outcome, "invalid");
  assert.deepEqual(
    trials[0].errors.map((error) => error.path),
    ["done.json:trace_hash"],
  );
  assert.equal(record.result, "invalid");
});

test("the harness refuses an unknown arm, scenario shape or cap", async (t) => {
  const run = await fixture(t);
  await assert.rejects(run({ scenario: "downhill-run", arm: "oracle" }), /arm/);
  await assert.rejects(
    run({ scenario: "downhill-run", arm: "random", callCap: 0 }),
    /call cap/,
  );
  await assert.rejects(
    run({ scenario: "Downhill Run", arm: "random" }),
    /scenario/,
  );
});
