// Offline tests for decide(). fetch is replaced for every test in this file, so
// no request leaves the machine and no API key is read.
import { afterEach, beforeEach, test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  applyFloor,
  CONFIDENCE_FLOOR,
  decide,
  gateOptions,
  INTENTS,
} from "../decide.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const realFetch = globalThis.fetch;
let requests;
let answer;

beforeEach(() => {
  requests = [];
  answer = { choice: "push_objective", confidence: 0.9 };
  globalThis.fetch = async (url, init) => {
    requests.push({ url, body: JSON.parse(init.body) });
    return {
      ok: true,
      json: async () => ({
        model: "stub",
        usage: { input_tokens: 1 },
        answers: {
          intent: { ...answer, probabilities: {} },
          danger: { score: 0.5 },
          greedy: { noul: 0.5 },
        },
      }),
    };
  };
});

afterEach(() => {
  globalThis.fetch = realFetch;
});

const option = (id) => ({ id, why: INTENTS[id] });
const exit = option("start_exit");
const push = option("push_objective");

test("start_exit is dropped only when the state says the player is outside the ring", () => {
  const outside = { self: {}, objective: { inside_ring: false } };
  assert.deepEqual(gateOptions(outside, [exit, push]).dropped, ["start_exit"]);
  const inside = { self: {}, objective: { inside_ring: true } };
  assert.deepEqual(gateOptions(inside, [exit]).dropped, []);
  assert.deepEqual(gateOptions({ self: {} }, [exit]).dropped, []);
});

test("start_exit is offered when the objective omits inside_ring, even 18 m out", () => {
  const state = { self: {}, objective: { kind: "reach_exit", distance_m: 18 } };
  assert.deepEqual(gateOptions(state, [exit]).dropped, []);
});

test("a fully gated option set falls back to push_objective alone", async () => {
  const state = {
    self: { grounded: false, air_jump_available: false, speed_tier: "cruise" },
  };
  const result = await decide(
    state,
    [option("stomp_target"), option("ram_target")],
    { key: "offline" },
  );
  assert.equal(requests.length, 1);
  assert.deepEqual(requests[0].body.questions.intent.criteria, {
    push_objective: INTENTS.push_objective,
  });
  assert.deepEqual(result.gatedOut, ["stomp_target", "ram_target"]);
  assert.equal(result.intent, "push_objective");
});

test("below the confidence floor the player holds push_objective and keeps the raw choice", async () => {
  answer = { choice: "hit_kicker", confidence: 0.02 };
  const result = await decide({ self: {} }, [push, option("sweep_scrap")], {
    key: "offline",
  });
  assert.equal(result.intent, "push_objective");
  assert.equal(result.rawIntent, "hit_kicker");
  assert.equal(result.lowConfidence, true);
  assert.equal(result.confidence, 0.02);
});

test("at or above the floor the model's choice stands", () => {
  const at = applyFloor({ choice: "hit_kicker", confidence: CONFIDENCE_FLOOR });
  assert.deepEqual(at, {
    intent: "hit_kicker",
    lowConfidence: false,
    rawIntent: "hit_kicker",
  });
  const below = applyFloor({
    choice: "hit_kicker",
    confidence: CONFIDENCE_FLOOR - 0.001,
  });
  assert.equal(below.intent, "push_objective");
  assert.equal(below.lowConfidence, true);
});

test("the request body under q1 carries the snapshot wording", async () => {
  const options = Object.keys(INTENTS).map(option);
  const open = { self: { grounded: true, speed_tier: "fast", speed_ms: 30 } };
  const result = await decide(open, options, { key: "offline" });
  assert.deepEqual(result.gatedOut, []);
  const snapshot = readFileSync(
    path.join(here, "fixtures", "q1-built.json"),
    "utf8",
  );
  assert.equal(
    JSON.stringify(requests[0].body.questions, null, 2) + "\n",
    snapshot,
  );
  assert.deepEqual(Object.keys(requests[0].body), [
    "model",
    "state",
    "questions",
  ]);
});
