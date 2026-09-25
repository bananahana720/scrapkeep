// Offline tests for the precondition gate. No API key, no network: these run
// in the ordinary `npm test` sweep and guard the rule that the model is never
// offered an action the engine cannot execute.
import { test } from "node:test";
import assert from "node:assert/strict";

import { gateOptions, INTENTS } from "../decide.mjs";

const stomp = { id: "stomp_target", why: INTENTS.stomp_target };
const ram = { id: "ram_target", why: INTENTS.ram_target };
const kicker = {
  id: "hit_kicker",
  why: INTENTS.hit_kicker,
  requires_speed_ms: 26,
};
const push = { id: "push_objective", why: INTENTS.push_objective };

test("a spent air jump while airborne removes the stomp", () => {
  const state = { self: { grounded: false, air_jump_available: false } };
  const { kept, dropped } = gateOptions(state, [stomp, push]);
  assert.deepEqual(dropped, ["stomp_target"]);
  assert.deepEqual(
    kept.map((o) => o.id),
    ["push_objective"],
  );
});

test("an available air jump keeps the stomp while airborne", () => {
  const state = { self: { grounded: false, air_jump_available: true } };
  const { dropped } = gateOptions(state, [stomp, push]);
  assert.deepEqual(dropped, []);
});

test("grounded keeps the stomp regardless of the air jump", () => {
  const state = { self: { grounded: true, air_jump_available: false } };
  const { dropped } = gateOptions(state, [stomp, push]);
  assert.deepEqual(dropped, []);
});

test("ramming needs the fast tier or better", () => {
  const slow = { self: { speed_tier: "cruise" } };
  assert.deepEqual(gateOptions(slow, [ram, push]).dropped, ["ram_target"]);
  for (const tier of ["fast", "blazing"]) {
    assert.deepEqual(
      gateOptions({ self: { speed_tier: tier } }, [ram]).dropped,
      [],
    );
  }
});

test("the kicker needs its stated approach speed", () => {
  assert.deepEqual(gateOptions({ self: { speed_ms: 9 } }, [kicker]).dropped, [
    "hit_kicker",
  ]);
  assert.deepEqual(
    gateOptions({ self: { speed_ms: 26 } }, [kicker]).dropped,
    [],
  );
  assert.deepEqual(
    gateOptions({ self: { speed_ms: 28.1 } }, [kicker]).dropped,
    [],
  );
});

test("an option with no rule always survives", () => {
  const { kept } = gateOptions({ self: {} }, [
    push,
    { id: "sweep_scrap", why: "x" },
  ]);
  assert.equal(kept.length, 2);
});
