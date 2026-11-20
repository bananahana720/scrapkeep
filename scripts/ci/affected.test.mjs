import test from "node:test";
import assert from "node:assert/strict";
import { classifyAffected } from "./affected.mjs";

test("full mode enables every CI surface", () => {
  assert.deepEqual(classifyAffected([], { full: true }), {
    full: true,
    lint: true,
    docs: true,
    node: true,
    web: true,
    godot: true,
    changedCount: 0,
  });
});

test("docs-only change skips web build and godot tests", () => {
  const res = classifyAffected(["project-guide/handoff/STATE.md", "README.md"]);
  assert.equal(res.lint, true);
  assert.equal(res.docs, true);
  assert.equal(res.node, false);
  assert.equal(res.web, false);
  assert.equal(res.godot, false);
});

test("godot sketch change triggers godot and node tests without web build", () => {
  const res = classifyAffected(["sketches/core-loop/src/game.gd"]);
  assert.equal(res.godot, true);
  assert.equal(res.node, true);
  assert.equal(res.web, false);
  assert.equal(res.docs, false);
});

test("browser proof change triggers web build and node tests without godot", () => {
  const res = classifyAffected(["src/orchard/simulation.js"]);
  assert.equal(res.web, true);
  assert.equal(res.node, true);
  assert.equal(res.godot, false);
});

test("CI workflow edit validates lint, docs, node and web build", () => {
  const res = classifyAffected([".github/workflows/ci.yml"]);
  assert.equal(res.lint, true);
  assert.equal(res.docs, true);
  assert.equal(res.node, true);
  assert.equal(res.web, true);
  assert.equal(res.godot, false);
});
