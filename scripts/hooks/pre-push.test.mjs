import test from "node:test";
import assert from "node:assert/strict";
import { parsePushStdin, planHookChecks } from "./pre-push.mjs";

test("parsePushStdin skips branch deletions and keeps updates and new branches", () => {
  const input = [
    "refs/heads/feat aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/heads/feat bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "refs/heads/new cccccccccccccccccccccccccccccccccccccccc refs/heads/new 0000000000000000000000000000000000000000",
    "(delete) 0000000000000000000000000000000000000000 refs/heads/old dddddddddddddddddddddddddddddddddddddddd",
  ].join("\n");
  assert.deepEqual(parsePushStdin(input), [
    {
      localSha: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      remoteSha: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    },
    {
      localSha: "cccccccccccccccccccccccccccccccccccccccc",
      remoteSha: null,
    },
  ]);
});

test("planHookChecks selects only the checks matching changed paths", () => {
  const existing = new Set([
    "scripts/ci/affected.mjs",
    "sketches/core-loop/src/game.gd",
    "README.md",
  ]);
  const jsOnly = planHookChecks(["scripts/ci/affected.mjs"], (f) => existing.has(f));
  assert.deepEqual(jsOnly, {
    jsFiles: ["scripts/ci/affected.mjs"],
    hasSketch: false,
    hasDocsOrPkg: false,
  });

  const sketchOnly = planHookChecks(["sketches/core-loop/src/game.gd"], (f) => existing.has(f));
  assert.deepEqual(sketchOnly, {
    jsFiles: [],
    hasSketch: true,
    hasDocsOrPkg: false,
  });

  const docOnly = planHookChecks(["README.md"], (f) => existing.has(f));
  assert.deepEqual(docOnly, {
    jsFiles: [],
    hasSketch: false,
    hasDocsOrPkg: true,
  });
});
