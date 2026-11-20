import test from "node:test";
import assert from "node:assert/strict";
import { filterFormatTargets } from "./format-changed.mjs";

test("filterFormatTargets keeps only existing JS/MJS files in supported roots", () => {
  const existing = new Set([
    "scripts/ci/check-budget.mjs",
    "src/game.js",
    "vite.config.js",
    "README.md",
    "sketches/core-loop/src/game.gd",
    "artifacts/local/tmp.js",
  ]);
  const res = filterFormatTargets(
    [
      "scripts/ci/check-budget.mjs",
      "scripts/ci/check-budget.mjs",
      "src/game.js",
      "vite.config.js",
      "README.md",
      "sketches/core-loop/src/game.gd",
      "artifacts/local/tmp.js",
      "scripts/deleted.mjs",
    ],
    (f) => existing.has(f),
  );
  assert.deepEqual(res, ["scripts/ci/check-budget.mjs", "src/game.js", "vite.config.js"]);
});
