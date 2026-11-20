import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ALWAYS, buildIndex, canaries, plan, selectTests } from "../sketch-fast.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const sketchDir = path.join(root, "sketches", "core-loop");
const realTimings = JSON.parse(
  readFileSync(path.join(root, "scripts", "sketch-fast.timings.json"), "utf8"),
).tests;

test("selection mutation proof: GDScript change reaches ALWAYS pins, direct tests and real canaries", () => {
  const index = buildIndex(sketchDir);
  const selection = selectTests(index, ["src/core/palette.gd"]);
  for (const pin of ALWAYS) {
    assert.ok(selection.picked.has(pin), `expected ALWAYS pin ${pin} to be selected`);
  }
  assert.ok(
    selection.picked.size > ALWAYS.length,
    `expected direct/transitive tests for src/core/palette.gd, got ${selection.picked.size}`,
  );

  // Unreferenced/hidden .gd file still triggers ALWAYS pins + real whole-game canaries.
  const hidden = selectTests(index, ["src/unreferenced_hidden_module.gd"]);
  assert.ok(hidden.unmapped.includes("src/unreferenced_hidden_module.gd"));
  for (const pin of ALWAYS) {
    assert.ok(hidden.picked.has(pin), `expected ALWAYS pin ${pin} on unmapped file`);
  }
  const realCanaries = canaries(index, realTimings);
  assert.ok(realCanaries.length >= 1, "expected real production canaries to be non-empty");

  // Even under the tight 120s PR CI budget, tier-0 ALWAYS pins are never deferred.
  const planned = plan({
    picked: selection.picked,
    timings: realTimings,
    budgetMs: 120_000,
    width: 4,
  });
  const ranTests = new Set([...planned.parallel, ...planned.solo].map((r) => r.test));
  for (const pin of ALWAYS) {
    assert.ok(ranTests.has(pin), `expected ALWAYS pin ${pin} to stay inside 120s PR budget`);
  }
});

test("selection mutation proof: park data change triggers map-standard PATH_RULES", () => {
  const index = buildIndex(sketchDir);
  const parkSel = selectTests(index, ["src/world/parks/dam.gd"]);
  assert.ok(parkSel.picked.has("tests/park_fight_bowl_test.gd"));
  assert.ok(parkSel.picked.has("tests/park_rhythm_test.gd"));
});
