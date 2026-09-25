// Offline tests for the JL-18c experiment runner. No test reaches the network:
// decide() runs against a replaced fetch and runPlan() against stub senders.
import { afterEach, test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { decide, gateOptions, loadQuestionSet } from "../decide.mjs";
import { loadControls } from "../preflight.mjs";
import {
  analyse,
  buildPlan,
  EXPERIMENT_DIR,
  loadExperiment,
  lockMismatches,
  PREREGISTRATION,
  renderReport,
  runPlan,
} from "../experiments/jl18c/run.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const runner = path.join(EXPERIMENT_DIR, "run.mjs");
const experiment = loadExperiment();
const q2 = loadQuestionSet("q2-neutral");
const plan = buildPlan(experiment, q2);
const realFetch = globalThis.fetch;

afterEach(() => {
  globalThis.fetch = realFetch;
});

const cellOf = (id) => experiment.design.cells.find((cell) => cell.id === id);
const callsOf = (id) => plan.filter((call) => call.cell === id);

test("the plan renders all six designs and its call count equals the budget", () => {
  assert.equal(experiment.design.budget, 216);
  assert.equal(plan.length, experiment.design.budget);
  assert.deepEqual(
    [...new Set(plan.map((call) => call.design))].toSorted(),
    ["a", "b", "c", "d", "e", "f"],
  );
  const expected = {
    choice3: 18,
    choice2: 6,
    comprehension: 6,
    preference: 18,
    "intent-only3": 18,
  };
  for (const cell of experiment.design.cells) {
    const width = (
      cell.options ?? experiment.states.states[cell.state].options
    ).length;
    const key =
      cell.call === "comprehension" || cell.call === "preference"
        ? cell.call
        : `${cell.call}${width}`;
    assert.equal(callsOf(cell.id).length, expected[key], cell.id);
  }
});

test("threshold cells run every permutation of their options, three repeats each", () => {
  for (const id of ["a-free-cache", "a-lethal", "d-free-heal", "e-free-cache"]) {
    const orders = callsOf(id).map((call) => call.order.join(">"));
    assert.equal(new Set(orders).size, 6, id);
    for (const order of new Set(orders)) {
      assert.equal(orders.filter((seen) => seen === order).length, 3, id);
    }
  }
  const two = callsOf("c-no-objective-two").map((call) => call.order.join(">"));
  assert.deepEqual([...new Set(two)].toSorted(), [
    "roll_on>take_cache",
    "take_cache>roll_on",
  ]);
});

test("repeats are the outer loop, so each cell is spread across the run", () => {
  const first = callsOf("a-free-cache").map((call) => call.index);
  assert.ok(first.at(-1) - first[0] > plan.length / 2);
  assert.deepEqual(
    plan.map((call) => call.index),
    plan.map((_, index) => index),
  );
});

test("choice bodies are byte-identical to what decide() sends", async () => {
  const sent = [];
  globalThis.fetch = async (url, init) => {
    sent.push(init.body);
    return {
      ok: true,
      json: async () => ({
        model: "stub",
        usage: {},
        answers: {
          intent: { choice: "push_objective", confidence: 1, probabilities: {} },
          danger: { score: 0 },
          greedy: { noul: 0 },
        },
      }),
    };
  };
  const choices = plan.filter((call) => call.call === "choice");
  for (const call of choices) {
    const { state, options } = experiment.states.states[call.state];
    const ordered = call.order.map((id) =>
      options.find((option) => option.id === id),
    );
    await decide(state, ordered, { key: "offline", questions: q2 });
    assert.equal(sent.at(-1), JSON.stringify(call.body), call.cell);
  }
  assert.equal(sent.length, choices.length);
});

test("intent-only bodies are the choice body without danger and greedy", () => {
  const onlyIntent = callsOf("f-free-cache");
  for (const call of onlyIntent) {
    const twin = callsOf("a-free-cache").find(
      (other) =>
        other.repeat === call.repeat &&
        other.order.join() === call.order.join(),
    );
    assert.deepEqual(Object.keys(call.body.questions), ["intent"]);
    assert.deepEqual(call.body.questions.intent, twin.body.questions.intent);
    assert.deepEqual(call.body.state, twin.body.state);
  }
});

test("free-cache and lethal-option are c2's states and options verbatim", () => {
  const c2 = loadControls("c2");
  for (const id of ["free-cache", "lethal-option"]) {
    const control = c2.controls.find((entry) => entry.id === id);
    assert.deepEqual(experiment.states.states[id].state, control.state);
    assert.deepEqual(experiment.states.states[id].options, control.options);
  }
});

test("no option in any state is removed by the option gate", () => {
  for (const [id, { state, options }] of Object.entries(
    experiment.states.states,
  )) {
    assert.deepEqual(gateOptions(state, options).dropped, [], id);
  }
});

test("the new states are length-matched within 1.25x", () => {
  for (const id of ["free-cache-no-objective", "free-heal", "free-cache-named-buff"]) {
    const lengths = experiment.states.states[id].options.map(
      (option) => option.why.length,
    );
    assert.ok(Math.max(...lengths) / Math.min(...lengths) <= 1.25, id);
  }
});

test("the no-objective cells never name the objective, the exit or the charge outside the pinned rules", () => {
  const { state, options } =
    experiment.states.states["free-cache-no-objective"];
  assert.equal(state.objective, undefined);
  assert.doesNotMatch(JSON.stringify(state), /exit|charge|objective/i);
  const rollOn = options.find((option) => option.id === "roll_on");
  assert.doesNotMatch(rollOn.why, /exit|charge|objective/i);
  for (const cell of ["c-no-objective", "c-no-objective-two"]) {
    for (const call of callsOf(cell)) {
      assert.doesNotMatch(JSON.stringify(call.body), /objective/i, cell);
    }
  }
});

test("the preference preamble is the pinned q2 rules text", () => {
  const { preamble } = experiment.questions.preference;
  assert.ok(q2.intent.instructions.startsWith(`${preamble} `));
});

test("preference bodies ask one noul per option, in the permutation's order", () => {
  for (const call of plan.filter((entry) => entry.call === "preference")) {
    assert.deepEqual(Object.keys(call.body.questions), call.order);
    const { options } = experiment.states.states[call.state];
    for (const id of call.order) {
      const question = call.body.questions[id];
      assert.equal(question.type, "noul");
      assert.ok(
        question.instructions.includes(
          `"${options.find((option) => option.id === id).why}"`,
        ),
      );
      assert.ok(question.instructions.endsWith("Is this the action to take now?"));
    }
  }
});

test("comprehension bodies carry no choice and run every item forward and reversed", () => {
  const { comprehension } = experiment.questions;
  for (const cell of experiment.design.cells.filter(
    (entry) => entry.call === "comprehension",
  )) {
    const items = comprehension.items[cell.state];
    const ids = experiment.states.states[cell.state].options.map((o) => o.id);
    for (const item of items) {
      assert.ok(ids.includes(item.option), `${cell.id} ${item.option}`);
      assert.ok(Object.hasOwn(comprehension.questions, item.question));
      assert.ok(["stated", "implied"].includes(item.basis));
    }
    const calls = callsOf(cell.id);
    const keys = items.map((item) => `${item.option}__${item.question}`);
    const seen = calls.map((call) => Object.keys(call.body.questions).join());
    assert.equal(seen.filter((k) => k === keys.join()).length, 3);
    assert.equal(seen.filter((k) => k === keys.toReversed().join()).length, 3);
    for (const call of calls) {
      assert.equal(call.body.questions.intent, undefined);
      for (const question of Object.values(call.body.questions)) {
        assert.equal(question.type, "noul");
        assert.doesNotMatch(question.instructions, /The rules:/);
      }
    }
  }
});

// Answers from a function of the request alone, so a stub decider can model
// position effects without knowing which cell asked.
function stubSender({ choice, noul, fail = () => false }) {
  let count = 0;
  return async (body) => {
    count += 1;
    if (fail(count)) throw new Error("stub outage");
    if (body.questions.intent !== undefined) {
      const ids = Object.keys(body.questions.intent.criteria);
      return {
        answers: { intent: { probabilities: choice(ids, body) } },
        usage: { input_tokens: 700, output_tokens: 80 },
        model: "jev-stub",
      };
    }
    const keys = Object.keys(body.questions);
    return {
      answers: Object.fromEntries(
        keys.map((key, position) => [key, { noul: noul(key, position, keys) }]),
      ),
      usage: { input_tokens: 900, output_tokens: 60 },
      model: "jev-stub",
    };
  };
}

const PROBES = new Set(["take_cache", "take_repair"]);
const truth = (key) => {
  for (const cell of Object.values(experiment.questions.comprehension.items)) {
    for (const item of cell) {
      if (key === `${item.option}__${item.question}`) return item.expected;
    }
  }
  return undefined;
};

function spread(ids, pick, share) {
  const rest = (1 - share) / (ids.length - 1);
  return Object.fromEntries(ids.map((id) => [id, id === pick ? share : rest]));
}

const idealChoice = (ids) => {
  if (ids.includes("ram_target")) return spread(ids, "retreat_regen", 0.9);
  return spread(ids, ids.find((id) => PROBES.has(id)), 0.9);
};

const idealNoul = (key) => {
  const known = truth(key);
  if (known !== undefined) return known ? 0.95 : 0.05;
  if (PROBES.has(key) || key === "retreat_regen") return 0.9;
  return 0.1;
};

test("an ideal stub decider yields a full table and a candidate verdict", async () => {
  const streamed = [];
  const results = await runPlan(
    plan,
    stubSender({ choice: idealChoice, noul: idealNoul }),
    experiment.design.budget,
    async (result) => streamed.push(result.index),
  );
  assert.equal(results.length, 216);
  assert.deepEqual(streamed, results.map((result) => result.index));
  const analysis = analyse(experiment, results);
  assert.deepEqual(
    Object.keys(analysis.cells).toSorted(),
    experiment.design.cells.map((cell) => cell.id).toSorted(),
  );
  assert.equal(analysis.verdict.verdict, "candidate");
  assert.deepEqual(analysis.verdict.candidates, ["choice", "preference"]);
  assert.equal(analysis.calls, 216);
  assert.equal(analysis.failed, 0);
  assert.deepEqual(analysis.models, ["jev-stub"]);
  const freeCache = analysis.cells["a-free-cache"];
  assert.equal(freeCache.orders.length, 6);
  assert.equal(freeCache.positions.length, 3);
  for (const field of ["mean", "min", "max", "sd", "n"]) {
    assert.ok(Number.isFinite(freeCache.positions[0][field]), field);
  }
  assert.equal(analysis.cells["b-free-cache"].read, true);
  const report = renderReport(analysis);
  for (const cell of experiment.design.cells) {
    assert.match(report, new RegExp(`^\\S+ ${cell.id} `, "m"));
  }
  assert.match(report, /^verdict candidate/m);
});

// JL-18's pattern: the free cache gains mass in later positions and never
// reaches 0.6; the ram is refused; the cache reads correctly; the preference
// nouls rate taking and pushing alike.
const lastPositionBoost = (ids) => {
  if (ids.includes("ram_target")) return spread(ids, "retreat_regen", 0.9);
  const probe = ids.find((id) => PROBES.has(id));
  const share = [0.38, 0.45, 0.52][ids.indexOf(probe)];
  const rival = ids.find((id) => id !== probe && id !== "sweep_scrap");
  const rest = ids.length === 2 ? 0 : 0.07;
  return Object.fromEntries(
    ids.map((id) => [
      id,
      id === probe ? share : id === rival ? 1 - share - rest : rest,
    ]),
  );
};

test("a JL-18-shaped stub parks, flags position and names preference, not reading", async () => {
  const results = await runPlan(
    plan,
    stubSender({
      choice: lastPositionBoost,
      noul: (key) =>
        truth(key) !== undefined
          ? idealNoul(key)
          : key === "ram_target"
            ? 0.05
            : 0.6,
    }),
    experiment.design.budget,
  );
  const analysis = analyse(experiment, results);
  assert.equal(analysis.verdict.verdict, "park");
  assert.deepEqual(analysis.verdict.candidates, []);
  assert.equal(analysis.cells["a-free-cache"].passed, false);
  assert.equal(analysis.cells["a-lethal"].passed, true);
  assert.equal(analysis.cells["e-free-cache"].passed, false);
  assert.ok(analysis.explanations.position.includes("a-free-cache"));
  assert.deepEqual(analysis.explanations.reading.stated_wrong, []);
  assert.equal(analysis.explanations.preference, true);
  assert.equal(analysis.cells["a-free-cache"].mean, 0.45);
});

test("a wrong answer on a stated item localises to reading", async () => {
  const misread = (key) =>
    key === "take_cache__spends_scrap" ? 0.9 : idealNoul(key);
  const results = await runPlan(
    plan,
    stubSender({ choice: lastPositionBoost, noul: misread }),
    experiment.design.budget,
  );
  const analysis = analyse(experiment, results);
  assert.equal(analysis.cells["b-free-cache"].read, false);
  assert.ok(
    analysis.explanations.reading.stated_wrong.some(
      (wrong) => wrong.cell === "b-free-cache" && wrong.item === "take_cache__spends_scrap",
    ),
  );
  assert.equal(analysis.explanations.preference, false);
});

test("ten failed calls block the verdict, and a failed call is kept, not retried", async () => {
  const results = await runPlan(
    plan,
    stubSender({
      choice: idealChoice,
      noul: idealNoul,
      fail: (count) => count <= 10,
    }),
    experiment.design.budget,
  );
  assert.equal(results.length, 216);
  assert.equal(results.filter((result) => result.error !== null).length, 10);
  const analysis = analyse(experiment, results);
  assert.equal(analysis.failed, 10);
  assert.equal(analysis.verdict.verdict, "blocked");
});

test("runPlan refuses a plan whose length is not the budget", async () => {
  let called = 0;
  await assert.rejects(
    runPlan(plan.slice(1), async () => {
      called += 1;
    }, experiment.design.budget),
    /budget/,
  );
  assert.equal(called, 0);
});

test("the pre-registration pins the sha256 of every input and the runner", () => {
  const text = readFileSync(PREREGISTRATION, "utf8");
  assert.deepEqual(lockMismatches(text), []);
  assert.deepEqual(lockMismatches("no hashes here").length, 4);
});

test("--dry-run prints every body and the call count without a key or a call", () => {
  const env = { ...process.env, TYPESAFE_API_KEY: "" };
  const run = spawnSync(process.execPath, [runner, "--dry-run"], {
    encoding: "utf8",
    env,
  });
  assert.equal(run.status, 0, run.stderr);
  const headers = run.stdout.match(/^# call \d+\/216 /gm) ?? [];
  assert.equal(headers.length, 216);
  assert.match(run.stdout, /^216 calls \(budget 216\); no call made$/m);
  const bare = spawnSync(process.execPath, [runner], { encoding: "utf8", env });
  assert.notEqual(bare.status, 0);
});
