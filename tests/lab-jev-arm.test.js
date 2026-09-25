// JL-14: the verdict cache, the jev arm and replay. Every decideFn here is an
// injected stub and every cache lives under mkdtemp, so nothing leaves the
// machine and nothing touches artifacts/local.
import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
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

import {
  instrumentIdentity,
  loadQuestionSet,
  offeredOptions,
  INTENTS,
} from "../tools/jev-player/decide.mjs";
import { verdictKey } from "../tools/jev-player/protocol/protocol.mjs";
import { createArm } from "../scripts/lab/arms.mjs";
import { runBatch } from "../scripts/lab/harness.mjs";
import {
  openVerdictCache,
  VERDICT_CACHE_ROOT,
} from "../scripts/lab/verdict-cache.mjs";

const USAGE = {
  input_tokens: 700,
  output_tokens: 11,
  cache_read_input_tokens: 5,
  cache_creation_input_tokens: 2,
};
const MODEL = "jev-stub-resolved";

// Answers evade_hazard when offered, otherwise the first offered option.
function stubDecide(overrides = {}) {
  const calls = [];
  const decideFn = async (state, options, settings = {}) => {
    calls.push({ state, options, settings });
    if (overrides.throws !== undefined) throw new Error(overrides.throws);
    const offered = offeredOptions({ state, options });
    const pick =
      overrides.intent ??
      (offered.find((option) => option.id === "evade_hazard") ?? offered[0]).id;
    return {
      gatedOut: [],
      intent: pick,
      lowConfidence: false,
      rawIntent: pick,
      confidence: 0.8,
      probabilities: {},
      danger: 0.1,
      greedy: 0.2,
      latencyMs: 3,
      usage: { ...USAGE },
      model: MODEL,
    };
  };
  decideFn.calls = calls;
  return decideFn;
}

const noCall = () => stubDecide({ throws: "a test reached decideFn" });

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
}

async function fixture(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-jev-arm-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const repository = path.join(temporary, "repository");
  await mkdir(path.join(repository, "src"), { recursive: true });
  git(repository, "init", "-q", "-b", "lab");
  await writeFile(path.join(repository, "src/tuning.txt"), "speed = 4\n");
  git(repository, "add", ".");
  git(repository, "commit", "-q", "-m", "fixture");
  const cache = path.join(temporary, "cache");
  const runs = {
    root: path.join(temporary, "runs"),
    repository,
    sources: ["src"],
  };
  const run = (options) =>
    runBatch({
      arm: "jev",
      watchdogFloorMs: 10_000,
      verdictCache: cache,
      runs,
      ...options,
    });
  return { run, cache, temporary };
}

async function trialFiles(directory, trial) {
  const io = path.join(directory, trial.io);
  const files = {};
  for (const name of await readdir(io)) {
    files[name] = await readFile(path.join(io, name), "utf8");
  }
  return files;
}

const jevBlock = {
  state: {
    self: { speed_ms: 12, speed_tier: "cruise", grounded: true },
    stage: { name: "t", time_s: 0, tier: 1 },
    threats: [{ kind: "pillar", distance_m: 15, on_current_line: true }],
    objective: { kind: "pad", distance_m: 90 },
  },
  options: ["push_objective", "evade_hazard"].map((id) => ({
    id,
    why: INTENTS[id],
  })),
};

async function tempCache(t) {
  const directory = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-cache-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  return openVerdictCache(directory);
}

// --- the verdict cache --------------------------------------------------------

test("the verdict cache stores one file per key and reads it back", async (t) => {
  const cache = await tempCache(t);
  const key = verdictKey(instrumentIdentity(), jevBlock);
  assert.equal(await cache.get(key), null);
  await cache.put(key, { verdict: { intent: "evade_hazard" } });
  const entry = await cache.get(key);
  assert.equal(entry.key, key);
  assert.equal(entry.verdict.intent, "evade_hazard");
  assert.deepEqual(await readdir(cache.directory), [`${key}.json`]);
  assert.equal(
    VERDICT_CACHE_ROOT,
    path.resolve(import.meta.dirname, "../artifacts/local/jev-cache"),
  );
});

test("the verdict cache refuses a malformed key and an entry filed under another key", async (t) => {
  const cache = await tempCache(t);
  await assert.rejects(cache.get("../escape"), /key/);
  const key = "a".repeat(64);
  await writeFile(
    path.join(cache.directory, `${key}.json`),
    JSON.stringify({ key: "b".repeat(64), verdict: {} }),
  );
  await assert.rejects(cache.get(key), /key/);
});

// --- the arm on its own -------------------------------------------------------

test("the jev arm calls decideFn once, caches under verdictKey and answers the repeat from the cache", async (t) => {
  const cache = await tempCache(t);
  const questions = loadQuestionSet();
  const instrument = instrumentIdentity(questions);
  const decideFn = stubDecide();
  const arm = createArm("jev", { instrument, questions, decideFn, cache });
  const offered = offeredOptions(jevBlock);
  const live = await arm.choose({
    seq: 0,
    state: jevBlock.state,
    offered,
    jev: jevBlock,
  });
  assert.equal(decideFn.calls.length, 1);
  assert.equal(decideFn.calls[0].settings.questions, questions);
  assert.equal(live.intent, "evade_hazard");
  assert.equal(live.source, "live");
  assert.equal(live.meta.questions_sha, instrument.questions_sha);
  assert.equal(live.meta.model, MODEL);
  assert.deepEqual(live.jev, { model: MODEL, usage: USAGE, cached: false });
  const key = verdictKey(instrument, jevBlock);
  assert.equal(live.meta.verdict_key, key);
  assert.equal((await cache.get(key)).verdict.intent, "evade_hazard");

  const again = await arm.choose({
    seq: 1,
    state: jevBlock.state,
    offered,
    jev: jevBlock,
  });
  assert.equal(decideFn.calls.length, 1, "the repeat made no call");
  assert.equal(again.source, "cache");
  assert.equal(again.intent, "evade_hazard");
  assert.deepEqual(again.jev, { model: MODEL, cached: true });
});

test("a replaying jev arm never calls decideFn and treats a miss as a replay_miss abort", async (t) => {
  const cache = await tempCache(t);
  const decideFn = noCall();
  const arm = createArm("jev", { decideFn, cache, replay: true });
  const error = await arm
    .choose({
      seq: 0,
      state: jevBlock.state,
      offered: offeredOptions(jevBlock),
      jev: jevBlock,
    })
    .then(
      () => null,
      (thrown) => thrown,
    );
  assert.ok(error instanceof Error);
  assert.deepEqual(error.abort, {
    reason: "replay_miss",
    cause: "replay_miss",
  });
  assert.equal(decideFn.calls.length, 0);
});

test("a failed Jev call is an api_error abort and caches nothing", async (t) => {
  const cache = await tempCache(t);
  const arm = createArm("jev", {
    decideFn: stubDecide({ throws: "Jev 503: busy" }),
    cache,
  });
  const error = await arm
    .choose({
      seq: 0,
      state: jevBlock.state,
      offered: offeredOptions(jevBlock),
      jev: jevBlock,
    })
    .then(
      () => null,
      (thrown) => thrown,
    );
  assert.deepEqual(error.abort, { reason: "arm_error", cause: "api_error" });
  assert.match(error.message, /503/);
  assert.deepEqual(await readdir(cache.directory), []);
});

test("the jev arm refuses questions whose sha is not the instrument's", () => {
  const questions = loadQuestionSet();
  assert.throws(
    () =>
      createArm("jev", {
        questions,
        instrument: {
          ...instrumentIdentity(questions),
          questions_sha: "0".repeat(64),
        },
        decideFn: noCall(),
      }),
    /questions_sha/,
  );
});

// --- through the harness ------------------------------------------------------

test("a jev batch calls once per non-forced snapshot and records model and the four token fields apart", async (t) => {
  const { run, cache } = await fixture(t);
  const decideFn = stubDecide();
  // downhill-run: snapshots 0 and 1 are gated to one option (forced); 2 and 3
  // need a choice.
  const { record, trials, directory } = await run({
    scenario: "downhill-run",
    trials: 2,
    decideFn,
  });
  assert.equal(record.result, "pass");
  assert.equal(
    decideFn.calls.length,
    2,
    "trial 1 repeats trial 0's states from the cache",
  );
  for (const trial of trials) {
    assert.equal(trial.outcome, "complete");
    assert.equal(trial.forced, 2);
    assert.equal(trial.arm_calls, 2);
    assert.match(trial.trace_hash, /^[0-9a-f]{64}$/);
  }
  const jev = record.provenance.jev;
  assert.equal(jev.model, MODEL);
  assert.equal(jev.calls, 2);
  assert.equal(jev.cache_hits, 2);
  assert.equal(jev.input_tokens, 2 * USAGE.input_tokens);
  assert.equal(jev.output_tokens, 2 * USAGE.output_tokens);
  assert.equal(jev.cache_read_input_tokens, 2 * USAGE.cache_read_input_tokens);
  assert.equal(
    jev.cache_creation_input_tokens,
    2 * USAGE.cache_creation_input_tokens,
  );
  assert.equal(record.config.replay, false);
  assert.equal(record.config.verdict_cache, cache);
  assert.deepEqual(record.kris.api_error_rate.value, 0);
  assert.equal(record.kris.api_error_rate.n, 2);

  const files = await trialFiles(directory, trials[0]);
  const instrument = instrumentIdentity();
  const keys = [];
  for (const seq of [2, 3]) {
    const name = String(seq).padStart(6, "0");
    const state = JSON.parse(files[`state-${name}.json`]);
    const intent = JSON.parse(files[`intent-${name}.json`]);
    assert.equal(intent.source, "live");
    assert.equal(intent.meta.verdict_key, verdictKey(instrument, state.jev));
    keys.push(`${intent.meta.verdict_key}.json`);
  }
  assert.deepEqual((await readdir(cache)).sort(), keys.sort());
  const second = await trialFiles(directory, trials[1]);
  assert.equal(JSON.parse(second["intent-000002.json"]).source, "cache");
});

test("--replay reproduces a batch from the cache with zero calls and the same trace_hash", async (t) => {
  const { run } = await fixture(t);
  const first = await run({ scenario: "pillar-weave", decideFn: stubDecide() });
  assert.equal(first.record.result, "pass");
  assert.equal(first.record.provenance.jev.calls, 4);

  const decideFn = noCall();
  const replay = await run({
    scenario: "pillar-weave",
    decideFn,
    replay: true,
  });
  assert.equal(decideFn.calls.length, 0);
  assert.equal(replay.record.result, "pass");
  assert.equal(replay.record.config.replay, true);
  assert.equal(replay.record.provenance.jev.calls, 0);
  assert.equal(replay.record.provenance.jev.cache_hits, 4);
  assert.equal(replay.record.provenance.jev.model, MODEL);
  assert.equal(replay.trials[0].trace_hash, first.trials[0].trace_hash);
  assert.ok(replay.record.limits.some((line) => /[Rr]eplay/.test(line)));
});

test("a replay cache miss aborts with replay_miss, makes no call and fails the batch", async (t) => {
  const { run } = await fixture(t);
  const decideFn = noCall();
  const { record, trials, directory } = await run({
    scenario: "pillar-weave",
    decideFn,
    replay: true,
  });
  assert.equal(decideFn.calls.length, 0);
  const [trial] = trials;
  assert.equal(trial.outcome, "aborted");
  assert.equal(trial.abort.reason, "replay_miss");
  assert.equal(trial.abort.cause, "replay_miss");
  const files = await trialFiles(directory, trial);
  assert.deepEqual(Object.keys(JSON.parse(files["abort.json"])).sort(), [
    "message",
    "protocol",
    "reason",
  ]);
  assert.equal(JSON.parse(files["abort.json"]).reason, "replay_miss");
  assert.equal(record.result, "fail");
});

test("an API failure aborts with cause api_error and leaves the batch inconclusive, not failed", async (t) => {
  const { run } = await fixture(t);
  const { record, trials, directory } = await run({
    scenario: "pillar-weave",
    trials: 2,
    decideFn: stubDecide({ throws: "Jev 500: upstream" }),
  });
  for (const trial of trials) {
    assert.equal(trial.outcome, "aborted");
    assert.equal(trial.abort.reason, "arm_error");
    assert.equal(trial.abort.cause, "api_error");
  }
  const files = await trialFiles(directory, trials[0]);
  assert.equal(JSON.parse(files["abort.json"]).reason, "arm_error");
  assert.equal(record.result, "inconclusive");
  assert.equal(record.kris.api_error_rate.value, 1);
  assert.equal(record.kris.api_error_rate.n, 2);
  assert.ok(record.limits.some((line) => /API error/.test(line)));
});

test("an answer outside the offered options is intent_invalid and fails the batch", async (t) => {
  const { run } = await fixture(t);
  const { record, trials } = await run({
    scenario: "pillar-weave",
    decideFn: stubDecide({ intent: "stomp_target" }),
  });
  assert.equal(trials[0].abort.cause, "intent_invalid");
  assert.equal(trials[0].abort.reason, "arm_error");
  assert.equal(record.result, "fail");
});

test("a corrupt cache entry is an arm_throw abort", async (t) => {
  const { run, cache } = await fixture(t);
  await run({ scenario: "pillar-weave", decideFn: stubDecide() });
  for (const name of await readdir(cache)) {
    await writeFile(path.join(cache, name), "{not json");
  }
  const { record, trials } = await run({
    scenario: "pillar-weave",
    decideFn: noCall(),
  });
  assert.equal(trials[0].abort.cause, "arm_throw");
  assert.equal(record.result, "fail");
});

test("the jev arm respects the per-batch call cap", async (t) => {
  const { run } = await fixture(t);
  const decideFn = stubDecide();
  const { record, trials } = await run({
    scenario: "pillar-weave",
    trials: 3,
    callCap: 2,
    decideFn,
  });
  assert.equal(decideFn.calls.length, 2);
  assert.equal(trials.length, 1);
  assert.equal(trials[0].abort.cause, "call_cap");
  assert.equal(record.config.capped, true);
  assert.equal(record.result, "inconclusive");
});

test("replay needs the jev arm", async (t) => {
  const { run } = await fixture(t);
  await assert.rejects(
    run({ scenario: "pillar-weave", arm: "scripted", replay: true }),
    /replay/,
  );
});
