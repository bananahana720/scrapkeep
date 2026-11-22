import test from "node:test";
import assert from "node:assert/strict";
import {
  changedFilesForRange,
  parseHookArgs,
  parsePushStdin,
  planHookChecks,
} from "./pre-push.mjs";

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

test("changedFilesForRange walks all unpushed commits on new branches and preserves deletions", () => {
  let newBranchArgs = null;
  const newFiles = changedFilesForRange(
    { localSha: "abc123", remoteSha: null },
    {
      spawn: (_cmd, args) => {
        newBranchArgs = args;
        return { status: 0, stdout: "README.md\nscripts/ci/affected.mjs\nREADME.md\n" };
      },
    },
  );
  assert.equal(newBranchArgs[0], "log");
  assert.ok(newBranchArgs.includes("--not"));
  assert.ok(newBranchArgs.includes("--remotes"));
  assert.ok(!newBranchArgs.includes("--diff-filter=ACM"));
  assert.deepEqual(newFiles, ["README.md", "scripts/ci/affected.mjs"]);

  let updateArgs = null;
  changedFilesForRange(
    { localSha: "def456", remoteSha: "abc123" },
    {
      spawn: (_cmd, args) => {
        updateArgs = args;
        return { status: 0, stdout: "docs/deleted.md\n" };
      },
    },
  );
  assert.deepEqual(updateArgs, ["diff", "--no-renames", "--name-only", "abc123..def456"]);
});

test("planHookChecks selects only matching checks and keeps doc/sketch deletions active", () => {
  const existing = new Set(["scripts/ci/affected.mjs"]);
  const deletedDocAndJs = planHookChecks(
    ["docs/deleted.md", "sketches/core-loop/src/removed.gd", "scripts/ci/deleted.mjs"],
    (f) => existing.has(f),
  );
  assert.deepEqual(deletedDocAndJs, {
    jsFiles: [],
    hasSketch: true,
    hasDocsOrPkg: true,
    hasKnownFailing: false,
  });

  const jsOnly = planHookChecks(["scripts/ci/affected.mjs"], (f) => existing.has(f));
  assert.deepEqual(jsOnly, {
    jsFiles: ["scripts/ci/affected.mjs"],
    hasSketch: false,
    hasDocsOrPkg: false,
    hasKnownFailing: false,
  });

  const knownFailing = planHookChecks(["project-guide/handoff/KNOWN-FAILING.tsv"], (f) =>
    existing.has(f),
  );
  assert.deepEqual(knownFailing, {
    jsFiles: [],
    hasSketch: false,
    hasDocsOrPkg: true,
    hasKnownFailing: true,
  });
});

test("parseHookArgs validates --base values", () => {
  assert.deepEqual(parseHookArgs([]), { base: null });
  assert.deepEqual(parseHookArgs(["--base", "origin/main"]), { base: "origin/main" });
  assert.throws(() => parseHookArgs(["--base"]), /--base requires/);
  assert.throws(() => parseHookArgs(["--base", ""]), /--base requires/);
  assert.throws(() => parseHookArgs(["--bogus"]), /unknown argument/);
});
