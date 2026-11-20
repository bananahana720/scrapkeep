import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { classifyAffected } from "./affected.mjs";
import { ALWAYS, buildIndex, canaries, selectTests } from "../sketch-fast.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const sketchDir = path.join(root, "sketches", "core-loop");

test("selection mutation proof: hidden indirect changes are never dropped by CI selector", () => {
  // Changes tucked into non-obvious paths still trigger their verifying surface.
  assert.equal(classifyAffected(["native/project.godot"]).node, true);
  assert.equal(classifyAffected(["docs/playtests/verdicts.ndjson"]).node, true);
  assert.equal(classifyAffected(["scripts/gate/weekly.mjs"]).docs, true);
  assert.equal(classifyAffected(["src/orchard/simulation.js"]).web, true);
  assert.equal(classifyAffected(["src/orchard/simulation.js"]).node, true);
  assert.equal(classifyAffected(["sketches/core-loop/src/core/palette.gd"]).godot, true);
});

test("selection mutation proof: GDScript change reaches ALWAYS pins, direct tests and whole-game canaries", () => {
  const index = buildIndex(sketchDir);
  // Pick a real non-test source file in the sketch and confirm selection never returns empty.
  const selection = selectTests(index, ["src/core/palette.gd"]);
  for (const pin of ALWAYS) {
    assert.ok(selection.picked.has(pin), `expected ALWAYS pin ${pin} to be selected`);
  }
  assert.ok(
    selection.picked.size > ALWAYS.length,
    `expected direct/transitive tests for src/core/palette.gd, got ${selection.picked.size}`,
  );
  // Even a synthetic unreferenced .gd file still triggers ALWAYS pins + whole-game canaries.
  const hidden = selectTests(index, ["src/unreferenced_hidden_module.gd"]);
  assert.ok(hidden.unmapped.includes("src/unreferenced_hidden_module.gd"));
  for (const pin of ALWAYS) {
    assert.ok(hidden.picked.has(pin), `expected ALWAYS pin ${pin} on unmapped file`);
  }
  const fakeTimings = Object.fromEntries(index.tests.map((t, i) => [t, (i + 1) * 100]));
  assert.ok(canaries(index, fakeTimings).length >= 1, "expected whole-game canaries to exist");
});
