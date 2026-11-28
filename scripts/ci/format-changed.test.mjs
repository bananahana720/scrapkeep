import test from "node:test";
import assert from "node:assert/strict";
import { changedFilesSince, filterFormatTargets, parseFormatArgs } from "./format-changed.mjs";

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

test("changedFilesSince uses --no-renames and surfaces spawn errors", () => {
  let seenArgs = null;
  const files = changedFilesSince("origin/main", {
    spawn: (_cmd, args) => {
      seenArgs = args;
      return { status: 0, stdout: 'scripts/a.mjs\0 scripts/café "b".mjs\0' };
    },
  });
  assert.ok(seenArgs.includes("--no-renames"));
  assert.ok(seenArgs.includes("-z"));
  assert.deepEqual(files, ["scripts/a.mjs", ' scripts/café "b".mjs']);

  assert.throws(
    () =>
      changedFilesSince("origin/main", {
        spawn: () => ({ status: null, error: new Error("ENOENT") }),
      }),
    /ENOENT/,
  );
});

test("parseFormatArgs validates --base and requires input", () => {
  assert.throws(() => parseFormatArgs([]), /pass --base/);
  assert.throws(() => parseFormatArgs(["--base"]), /--base requires/);
  assert.throws(() => parseFormatArgs(["--base", "--write"]), /--base requires/);
  assert.deepEqual(parseFormatArgs(["--base", "origin/main", "--write"]), {
    base: "origin/main",
    write: true,
    files: [],
  });
});
