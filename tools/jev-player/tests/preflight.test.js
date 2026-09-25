// Offline tests for the preflight controls. Every test injects decideFn, so no
// request leaves the machine and no API key is read.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readdir, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import {
  gateOptions,
  instrumentIdentity,
  loadQuestionSet,
} from "../decide.mjs";
import {
  BLIND_NOT_RUN,
  EPOCH_SCHEMA,
  PREFLIGHT_EXIT,
  beforeJevBatch,
  blindResult,
  epochRecord,
  epochStatus,
  loadControls,
  readEpoch,
  runControls,
  writeEpochRecord,
} from "../preflight.mjs";

const questions = loadQuestionSet();
const controls = loadControls();
const instrument = instrumentIdentity(questions);
const q2 = loadQuestionSet("q2-neutral");
const c2 = loadControls("c2");

// A decideFn built from a policy: policy(state, options, questions) returns
// {choice, probabilities}. Every call is logged so a test can check what was
// asked and how often.
function stub(policy) {
  const calls = [];
  const decideFn = async (state, options, settings) => {
    calls.push({ state, options, settings });
    const { kept, dropped } = gateOptions(state, options);
    const { choice, probabilities } = policy(state, kept, settings.questions);
    return {
      gatedOut: dropped,
      intent: choice,
      lowConfidence: false,
      rawIntent: choice,
      confidence: probabilities[choice] ?? 0,
      probabilities,
      danger: 0.2,
      greedy: 0.3,
      latencyMs: 5,
      usage: {
        input_tokens: 100,
        output_tokens: 7,
        cache_read_input_tokens: 40,
        cache_creation_input_tokens: 3,
      },
      model: "jev-stub-1",
    };
  };
  return { decideFn, calls };
}

// Takes the first option in the order offered with probability p and splits
// the rest evenly.
const firstListed =
  (p = 0.7) =>
  (state, options) => {
    const rest = Number(((1 - p) / Math.max(options.length - 1, 1)).toFixed(4));
    const probabilities = Object.fromEntries(
      options.map((option, index) => [option.id, index === 0 ? p : rest]),
    );
    return { choice: options[0].id, probabilities };
  };

// A sensible player: takes caches, never rams at 8 HP.
const sensible = (state, options) => {
  const ids = options.map((option) => option.id);
  const favourite = ids.includes("take_cache") ? "take_cache" : "retreat_regen";
  const rest = 0.2 / (ids.length - 1);
  return {
    choice: favourite,
    probabilities: Object.fromEntries(
      ids.map((id) => [id, id === favourite ? 0.8 : rest]),
    ),
  };
};

const byId = (result, id) => result.controls.find((one) => one.id === id);

test("c1 holds the three plan controls with the plan's pass lines", () => {
  assert.equal(controls.version, "c1");
  assert.match(controls.sha, /^[0-9a-f]{64}$/);
  assert.deepEqual(
    controls.controls.map((one) => one.id),
    ["free-cache", "lethal-option", "wording-swap"],
  );
  const free = controls.controls[0];
  assert.equal(free.probe, "take_cache");
  assert.equal(free.min, 0.6);
  assert.equal(free.state.scrap.held, 0);
  assert.match(free.options[0].why, /costs 0 scrap and no stopping/);
  const lethal = controls.controls[1];
  assert.equal(lethal.probe, "ram_target");
  assert.equal(lethal.max, 0.2);
  assert.equal(lethal.state.self.hp, 8);
  assert.match(
    lethal.options.find((one) => one.id === "ram_target").why,
    /25 contact damage/,
  );
  // The ram must be executable, or the control measures the gate, not Jev.
  assert.deepEqual(gateOptions(lethal.state, lethal.options).dropped, []);
  assert.equal(typeof controls.neutral_intent, "string");
  assert.notEqual(controls.neutral_intent, questions.intent.instructions);
});

test("every control runs in both orders, eight live calls, and all pass for a sensible player", async () => {
  const { decideFn, calls } = stub(sensible);
  const result = await runControls({ questions, decideFn, controls });
  assert.equal(result.passed, true);
  assert.equal(calls.length, 8);
  assert.equal(result.calls, 8);
  for (const control of result.controls) {
    assert.equal(control.passed, true, `${control.id}: ${control.reason}`);
    const orders = new Set(control.runs.map((run) => run.order));
    assert.deepEqual([...orders].sort(), ["given", "reversed"]);
  }
  const free = byId(result, "free-cache");
  assert.deepEqual(
    free.runs.map((run) => run.p),
    [0.8, 0.8],
  );
  const given = calls[0].options.map((one) => one.id);
  const reversed = calls[1].options.map((one) => one.id);
  assert.deepEqual(reversed, given.toReversed());
  assert.deepEqual(result.instrument, instrument);
  assert.equal(result.controls_version, "c1");
  assert.equal(result.controls_sha, controls.sha);
});

test("a control fails when either order misses its line, so option position cannot carry it", async () => {
  // Always picks whichever option is listed first: passes free-cache in the
  // given order and fails it reversed.
  const { decideFn } = stub(firstListed(0.7));
  const result = await runControls({ questions, decideFn, controls });
  assert.equal(result.passed, false);
  const free = byId(result, "free-cache");
  assert.equal(free.passed, false);
  assert.deepEqual(
    free.runs.map((run) => [run.order, run.p]),
    [
      ["given", 0.7],
      ["reversed", 0.15],
    ],
  );
  assert.match(free.reason, /reversed/);
  const lethal = byId(result, "lethal-option");
  assert.equal(lethal.passed, false, "ram is listed first in the given order");
});

test("lethal-option fails when P(ram) exceeds 0.2", async () => {
  const { decideFn } = stub((state, options) => {
    const ids = options.map((one) => one.id);
    if (!ids.includes("ram_target")) return sensible(state, options);
    return {
      choice: "retreat_regen",
      probabilities: {
        ram_target: 0.25,
        retreat_regen: 0.6,
        push_objective: 0.15,
      },
    };
  });
  const result = await runControls({ questions, decideFn, controls });
  const lethal = byId(result, "lethal-option");
  assert.equal(lethal.passed, false);
  assert.deepEqual(
    lethal.runs.map((run) => run.p),
    [0.25, 0.25],
  );
  assert.equal(byId(result, "free-cache").passed, true);
  assert.equal(result.passed, false);
});

test("wording-swap asks under both wordings and fails when the choice moves", async () => {
  const { decideFn, calls } = stub((state, options, asked) => {
    const neutral = asked.intent.instructions === controls.neutral_intent;
    if (state.scrap?.held === 140 && !neutral)
      return {
        choice: "push_objective",
        probabilities: {
          push_objective: 0.7,
          take_cache: 0.2,
          sweep_scrap: 0.1,
        },
      };
    return sensible(state, options);
  });
  const result = await runControls({ questions, decideFn, controls });
  const swap = byId(result, "wording-swap");
  assert.equal(swap.passed, false);
  assert.equal(swap.runs.length, 4);
  assert.deepEqual(
    swap.runs.map((run) => [run.wording, run.order, run.choice]),
    [
      ["current", "given", "push_objective"],
      ["neutral", "given", "take_cache"],
      ["current", "reversed", "push_objective"],
      ["neutral", "reversed", "take_cache"],
    ],
  );
  const asked = calls.filter((call) => call.state.scrap?.held === 140);
  assert.equal(
    asked[0].settings.questions,
    questions,
    "current wording is the set itself",
  );
  const neutral = asked[1].settings.questions;
  assert.equal(neutral.intent.instructions, controls.neutral_intent);
  assert.deepEqual(neutral.danger, questions.danger);
  assert.deepEqual(neutral.greedy, questions.greedy);
  assert.equal(neutral.intent.type, questions.intent.type);
});

const lengthRatio = (options) => {
  const lengths = options.map((option) => option.why.length);
  return Math.max(...lengths) / Math.min(...lengths);
};

test("c2 keeps the plan's lines, adds the free-cache swap and a max-shift line, and length-matches options", () => {
  assert.equal(c2.version, "c2");
  assert.match(c2.sha, /^[0-9a-f]{64}$/);
  assert.deepEqual(
    c2.controls.map((one) => one.id),
    ["free-cache", "lethal-option", "wording-swap", "wording-swap-free"],
  );
  const [free, lethal, swap, swapFree] = c2.controls;
  assert.equal(free.kind, "min-probability");
  assert.equal(free.probe, "take_cache");
  assert.equal(free.min, 0.6);
  assert.ok(
    free.state.scrap.held > 0,
    "held > 0 so cost 0 cannot read as unaffordable",
  );
  assert.match(
    free.options.find((one) => one.id === "take_cache").why,
    /0 scrap/,
  );
  assert.equal(lethal.kind, "max-probability");
  assert.equal(lethal.probe, "ram_target");
  assert.equal(lethal.max, 0.2);
  assert.equal(lethal.state.self.hp, 8);
  assert.match(
    lethal.options.find((one) => one.id === "ram_target").why,
    /25 damage/,
  );
  assert.deepEqual(gateOptions(lethal.state, lethal.options).dropped, []);
  for (const same of [swap, swapFree]) {
    assert.equal(same.kind, "same-choice");
    assert.equal(typeof same.max_shift, "number");
    assert.ok(same.max_shift > 0 && same.max_shift < 1);
  }
  assert.deepEqual(swapFree.state, free.state);
  assert.deepEqual(swapFree.options, free.options);
  for (const control of c2.controls)
    assert.ok(
      lengthRatio(control.options) <= 1.25,
      `${control.id} options differ in length by ${lengthRatio(control.options).toFixed(2)}x`,
    );
  assert.equal(c2.neutral_intent, controls.neutral_intent);
});

test("c2's swap options carry every decision-bearing fact, so the arms differ only in framing", () => {
  for (const same of c2.controls.filter((one) => one.kind === "same-choice")) {
    const take = same.options.find((one) => one.id === "take_cache").why;
    const all = same.options.map((one) => one.why).join(" ");
    assert.match(take, /\d+ scrap/, `${same.id}: the cache's price`);
    assert.match(take, /\d+ s\b|no stop/, `${same.id}: the stopping time`);
    assert.match(take, /rest of the run/, `${same.id}: buff permanence`);
    assert.match(all, /spent only on caches/, `${same.id}: scrap's sole use`);
    assert.match(all, /tier/, `${same.id}: the tier clock`);
    assert.match(all, /clears the stage/, `${same.id}: what the exit does`);
  }
});

test("c2 asks twelve live calls and passes for a sensible player under q2", async () => {
  const { decideFn, calls } = stub(sensible);
  const result = await runControls({
    questions: q2,
    decideFn,
    controls: c2,
  });
  assert.equal(result.passed, true);
  assert.equal(calls.length, 12);
  assert.equal(result.controls_version, "c2");
  assert.equal(result.questions_version, "q2-neutral");
  for (const id of ["wording-swap", "wording-swap-free"]) {
    const swap = byId(result, id);
    assert.equal(swap.runs.length, 4);
    assert.deepEqual(swap.shift, {
      line: 0.15,
      max: 0,
      by_order: [
        { order: "given", option: "take_cache", delta: 0 },
        { order: "reversed", option: "take_cache", delta: 0 },
      ],
    });
  }
});

// Answers any cache state from a fixed table per wording and the rest sensibly.
function perWording(current, neutral) {
  return stub((state, options, asked) => {
    if (!options.some((one) => one.id === "take_cache"))
      return sensible(state, options);
    const table =
      asked.intent.instructions === c2.neutral_intent ? neutral : current;
    const probabilities = Object.fromEntries(
      options.map((one) => [one.id, table[one.id]]),
    );
    const choice = options
      .map((one) => one.id)
      .reduce((top, id) => (probabilities[id] > probabilities[top] ? id : top));
    return { choice, probabilities };
  });
}

test("under c2 a near-tie flip inside the max-shift line is not a wording effect", async () => {
  const { decideFn } = perWording(
    { take_cache: 0.45, push_objective: 0.4, sweep_scrap: 0.15 },
    { take_cache: 0.4, push_objective: 0.45, sweep_scrap: 0.15 },
  );
  const result = await runControls({ questions: q2, decideFn, controls: c2 });
  for (const id of ["wording-swap", "wording-swap-free"]) {
    const swap = byId(result, id);
    assert.equal(swap.passed, true, swap.reason);
    assert.equal(swap.shift.max, 0.05);
    assert.match(swap.reason, /within the max-shift line 0\.15/);
  }
});

test("under c2 a flip whose shift exceeds the line fails, naming the shift", async () => {
  const { decideFn } = perWording(
    { take_cache: 0.7, push_objective: 0.2, sweep_scrap: 0.1 },
    { take_cache: 0.25, push_objective: 0.65, sweep_scrap: 0.1 },
  );
  const result = await runControls({ questions: q2, decideFn, controls: c2 });
  const swap = byId(result, "wording-swap");
  assert.equal(swap.passed, false);
  assert.equal(swap.shift.max, 0.45);
  assert.match(
    swap.reason,
    /take_cache under the current wording, push_objective under the neutral one/,
  );
  assert.match(swap.reason, /moved 0\.45 > 0\.15/);
  assert.equal(result.passed, false);
});

test("under c2 the same choice passes and records a shift above the line", async () => {
  const { decideFn } = perWording(
    { take_cache: 0.9, push_objective: 0.05, sweep_scrap: 0.05 },
    { take_cache: 0.5, push_objective: 0.3, sweep_scrap: 0.2 },
  );
  const result = await runControls({ questions: q2, decideFn, controls: c2 });
  const swap = byId(result, "wording-swap-free");
  assert.equal(swap.passed, true, swap.reason);
  assert.equal(swap.shift.max, 0.4);
});

test("a flip with no measurable shift fails, and c1 without a line fails any flip", async () => {
  const { decideFn } = stub((state, options, asked) => {
    const neutral = asked.intent.instructions === c2.neutral_intent;
    const choice = neutral ? "push_objective" : "take_cache";
    return { choice, probabilities: {} };
  });
  const result = await runControls({ questions: q2, decideFn, controls: c2 });
  assert.equal(byId(result, "wording-swap").passed, false);
  assert.match(
    byId(result, "wording-swap").reason,
    /no shift could be measured/,
  );

  const { decideFn: nearTie } = perWording(
    { take_cache: 0.45, push_objective: 0.4, sweep_scrap: 0.15 },
    { take_cache: 0.4, push_objective: 0.45, sweep_scrap: 0.15 },
  );
  const old = await runControls({ questions, decideFn: nearTie, controls });
  const swap = byId(old, "wording-swap");
  assert.equal(swap.passed, false);
  assert.equal(swap.shift, undefined);
});

test("a probe the gate drops or the answer omits fails its control", async () => {
  const gated = structuredClone(controls);
  gated.controls[1].state.self.speed_tier = "cruise";
  const { decideFn } = stub(sensible);
  const result = await runControls({ questions, decideFn, controls: gated });
  const lethal = byId(result, "lethal-option");
  assert.equal(lethal.passed, false);
  assert.match(lethal.reason, /ram_target was not offered/);

  const { decideFn: silent } = stub((state, options) => ({
    choice: options[0].id,
    probabilities: {},
  }));
  const quiet = await runControls({ questions, decideFn: silent, controls });
  assert.equal(byId(quiet, "free-cache").passed, false);
  assert.match(byId(quiet, "free-cache").reason, /no probability/);
});

test("a call that throws fails its control and keeps the other answers", async () => {
  const { decideFn: answer, calls } = stub(sensible);
  const decideFn = async (state, options, settings) => {
    if (state.self.hp === 8 && options[0].id !== "ram_target")
      throw new Error("Jev 503: busy");
    return answer(state, options, settings);
  };
  const result = await runControls({ questions, decideFn, controls });
  const lethal = byId(result, "lethal-option");
  assert.equal(lethal.passed, false);
  assert.match(lethal.reason, /call failed in the reversed order: Jev 503/);
  assert.equal(lethal.runs[0].p, 0.1);
  assert.equal(byId(result, "free-cache").passed, true);
  assert.equal(result.calls, 8);
  assert.equal(calls.length, 7);
  const swapping = async (state, options, settings) => {
    if (settings.questions.intent.instructions === controls.neutral_intent)
      throw new Error("Jev 500: down");
    return answer(state, options, settings);
  };
  const swapped = await runControls({
    questions,
    decideFn: swapping,
    controls,
  });
  assert.match(byId(swapped, "wording-swap").reason, /neutral wording/);
  assert.equal(byId(swapped, "wording-swap").passed, false);
});

test("controls never read a cache: each run asks again and passes only questions", async () => {
  const { decideFn, calls } = stub(sensible);
  await runControls({ questions, decideFn, controls });
  await runControls({ questions, decideFn, controls });
  assert.equal(calls.length, 16);
  for (const call of calls)
    assert.deepEqual(Object.keys(call.settings), ["questions"]);
});

test("tokens are totalled per field and never merged, with the resolved models", async () => {
  const { decideFn } = stub(sensible);
  const result = await runControls({ questions, decideFn, controls });
  assert.deepEqual(result.tokens, {
    input_tokens: 800,
    output_tokens: 56,
    cache_read_input_tokens: 320,
    cache_creation_input_tokens: 24,
  });
  assert.deepEqual(result.resolved_models, ["jev-stub-1"]);
  // The live API reports input and output only; a field no call reported
  // stays null rather than reading as zero spend.
  const { decideFn: plain } = stub(sensible);
  const sparse = async (state, options, settings) => {
    const decision = await plain(state, options, settings);
    return { ...decision, usage: { input_tokens: 700, output_tokens: 80 } };
  };
  const live = await runControls({ questions, decideFn: sparse, controls });
  assert.deepEqual(live.tokens, {
    input_tokens: 5600,
    output_tokens: 640,
    cache_read_input_tokens: null,
    cache_creation_input_tokens: null,
  });
});

test("a failed control exits 6 before the batch starts", async () => {
  let started = 0;
  const start = async () => {
    started += 1;
    return "batch";
  };
  const { decideFn: bad } = stub(firstListed(0.7));
  const failed = await beforeJevBatch({
    questions,
    decideFn: bad,
    controls,
    start,
  });
  assert.equal(PREFLIGHT_EXIT, 6);
  assert.equal(failed.exit, 6);
  assert.equal(started, 0);
  assert.equal(failed.controls.passed, false);

  const { decideFn: good } = stub(sensible);
  const passed = await beforeJevBatch({
    questions,
    decideFn: good,
    controls,
    start,
  });
  assert.equal(passed.exit, 0);
  assert.equal(passed.started, "batch");
  assert.equal(started, 1);
});

test("runControls refuses to run without an injected decideFn", async () => {
  await assert.rejects(runControls({ questions, controls }), /decideFn/);
});

test("blindResult keeps only the aggregate of a score report", () => {
  const report = {
    instrument,
    blind: {
      gating: true,
      summary: {
        cases: 24,
        weighted: 0.91,
        plainPass: 22,
        severeMisses: ["secret-case-id"],
        modelMisses: ["another-id"],
      },
      results: [{ id: "secret-case-id" }],
    },
    gate: { exit: 1, reason: "Severe miss on the blind corpus." },
  };
  const result = blindResult(report, instrument);
  assert.deepEqual(result, {
    status: "fail",
    passed: false,
    exit: 1,
    reason: "Severe miss on the blind corpus.",
    cases: 24,
    weighted: 0.91,
    severe_misses: 1,
  });
  assert.doesNotMatch(JSON.stringify(result), /secret-case-id|another-id/);
  const passing = blindResult(
    {
      ...report,
      blind: {
        ...report.blind,
        summary: { ...report.blind.summary, severeMisses: [] },
      },
      gate: { exit: 0, reason: "Blind corpus passes." },
    },
    instrument,
  );
  assert.equal(passing.passed, true);
  assert.throws(
    () => blindResult(report, { ...instrument, model: "other" }),
    /instrument/,
  );
  assert.deepEqual(
    blindResult(
      {
        ...report,
        blind: null,
        gate: { exit: 3, reason: "No blind corpus, so nothing gates." },
      },
      instrument,
    ).passed,
    false,
  );
});

async function scratch(t) {
  const directory = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-epoch-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  return directory;
}

test("an epoch is valid only when its controls and its blind corpus both passed", async (t) => {
  const directory = await scratch(t);
  const { decideFn } = stub(sensible);
  const passed = await runControls({ questions, decideFn, controls });
  const pending = epochRecord({
    questions,
    controls: passed,
    blind: BLIND_NOT_RUN,
  });
  assert.equal(pending.schema, EPOCH_SCHEMA);
  assert.deepEqual(pending.instrument, instrument);
  assert.equal(pending.questions_version, "q1-original");
  assert.equal(pending.blind.status, "not-run");
  assert.equal(pending.valid, false);
  assert.equal(pending.controls.passed, true);
  assert.equal(pending.controls.results.length, 3);

  const file = await writeEpochRecord(pending, directory);
  assert.deepEqual(await readdir(directory), [path.basename(file)]);
  assert.deepEqual(JSON.parse(await readFile(file, "utf8")), pending);
  assert.deepEqual(await readEpoch(instrument, directory), pending);
  let status = await epochStatus(instrument, directory);
  assert.equal(status.valid, false);
  assert.match(status.reason, /blind corpus/);

  const blind = {
    status: "pass",
    passed: true,
    exit: 0,
    reason: "Blind corpus passes.",
    cases: 24,
    weighted: 0.93,
    severe_misses: 0,
  };
  await writeEpochRecord(
    epochRecord({ questions, controls: passed, blind }),
    directory,
  );
  assert.equal(
    (await readdir(directory)).length,
    1,
    "one record per instrument",
  );
  status = await epochStatus(instrument, directory);
  assert.deepEqual(status, {
    valid: true,
    reason: "controls and blind corpus passed",
  });

  const { decideFn: bad } = stub(firstListed(0.7));
  const failed = await runControls({ questions, decideFn: bad, controls });
  await writeEpochRecord(
    epochRecord({ questions, controls: failed, blind }),
    directory,
  );
  status = await epochStatus(instrument, directory);
  assert.equal(status.valid, false);
  assert.match(status.reason, /controls failed/);
});

test("an epoch record answers only for its exact instrument", async (t) => {
  const directory = await scratch(t);
  const { decideFn } = stub(sensible);
  const passed = await runControls({ questions, decideFn, controls });
  const blind = {
    status: "pass",
    passed: true,
    exit: 0,
    reason: "",
    cases: 24,
    weighted: 0.93,
    severe_misses: 0,
  };
  await writeEpochRecord(
    epochRecord({ questions, controls: passed, blind }),
    directory,
  );
  for (const other of [
    { ...instrument, model: "jev-next" },
    { ...instrument, confidence_floor: 0.1 },
    { ...instrument, gate_version: 2 },
    { ...instrument, questions_sha: "0".repeat(64) },
  ]) {
    assert.equal(await readEpoch(other, directory), null);
    const status = await epochStatus(other, directory);
    assert.equal(status.valid, false);
    assert.match(status.reason, /no epoch record/);
  }
  const reordered = Object.fromEntries(Object.entries(instrument).toReversed());
  assert.equal((await epochStatus(reordered, directory)).valid, true);
  assert.equal((await epochStatus(null, directory)).valid, false);
  assert.equal(
    (await epochStatus(instrument, path.join(directory, "absent"))).valid,
    false,
  );
});
