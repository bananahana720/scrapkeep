import test from "node:test";
import assert from "node:assert/strict";
import {
  HIGH_LOAD_RATIO,
  HOOK_BUDGET_S,
  changedFilesForRange,
  evaluateHookOutcome,
  executeHookPlan,
  isHighLoad,
  parseHookArgs,
  parsePushStdin,
  planHookChecks,
  rangeBase,
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
    hasSkills: false,
    hasBriefs: false,
    hasKnownFailing: false,
    hasBaseline: false,
  });

  const jsOnly = planHookChecks(["scripts/ci/affected.mjs"], (f) => existing.has(f));
  assert.deepEqual(jsOnly, {
    jsFiles: ["scripts/ci/affected.mjs"],
    hasSketch: false,
    hasDocsOrPkg: false,
    hasSkills: false,
    hasBriefs: false,
    hasKnownFailing: false,
    hasBaseline: false,
  });

  const knownFailing = planHookChecks(["project-guide/handoff/KNOWN-FAILING.tsv"], (f) =>
    existing.has(f),
  );
  assert.deepEqual(knownFailing, {
    jsFiles: [],
    hasSketch: false,
    hasDocsOrPkg: true,
    hasSkills: false,
    hasBriefs: false,
    hasKnownFailing: true,
    hasBaseline: false,
  });

  assert.equal(
    planHookChecks(["scripts/structure-sweep.mjs"], (f) => existing.has(f)).hasDocsOrPkg,
    true,
  );

  const nearMissLedger = planHookChecks(["docs/KNOWN-FAILING.tsv"], (f) => existing.has(f));
  assert.deepEqual(nearMissLedger, {
    jsFiles: [],
    hasSketch: false,
    hasDocsOrPkg: false,
    hasSkills: false,
    hasBriefs: false,
    hasKnownFailing: false,
    hasBaseline: false,
  });

  assert.equal(planHookChecks(["scripts/sketch-lint.baseline.json"], () => true).hasBaseline, true);

  const skillsAndBriefs = planHookChecks(
    [
      ".agents/skills/scrapkeep-verify/SKILL.md",
      "sketches/core-loop/design-v3/sound/briefs/w1.json",
    ],
    (f) => existing.has(f),
  );
  assert.deepEqual(skillsAndBriefs, {
    jsFiles: [],
    hasSketch: true,
    hasDocsOrPkg: true,
    hasSkills: true,
    hasBriefs: true,
    hasKnownFailing: false,
    hasBaseline: false,
  });
});

test("parseHookArgs validates --base values", () => {
  assert.deepEqual(parseHookArgs([]), { base: null });
  assert.deepEqual(parseHookArgs(["--base", "origin/main"]), { base: "origin/main" });
  assert.throws(() => parseHookArgs(["--base"]), /--base requires/);
  assert.throws(() => parseHookArgs(["--base", ""]), /--base requires/);
  assert.throws(() => parseHookArgs(["--bogus"]), /unknown argument/);
});

test("isHighLoad checks max(loadStart, loadEnd) >= cpus * HIGH_LOAD_RATIO", () => {
  assert.equal(HIGH_LOAD_RATIO, 0.5);
  assert.equal(isHighLoad({ loadStart: 4, loadEnd: 1, cpus: 8 }), true);
  assert.equal(isHighLoad({ loadStart: 1, loadEnd: 4, cpus: 8 }), true);
  assert.equal(isHighLoad({ loadStart: 3.9, loadEnd: 3.9, cpus: 8 }), false);
  assert.equal(isHighLoad({ loadStart: 4, loadEnd: 4, cpus: 0 }), false);
});

test("evaluateHookOutcome waives OVER_BUDGET with PASS_UNDER_LOAD only when ok and isHighLoad", () => {
  const overNormal = evaluateHookOutcome({
    ok: true,
    elapsedS: HOOK_BUDGET_S + 1,
    loadStart: 1,
    loadEnd: 1,
    cpus: 8,
    ranLabels: ["oxfmt(1)"],
  });
  assert.equal(overNormal.exitCode, 1);
  assert.equal(overNormal.status, "OVER_BUDGET");
  assert.match(overNormal.message, /OVER_BUDGET/);

  const overHighLoad = evaluateHookOutcome({
    ok: true,
    elapsedS: HOOK_BUDGET_S + 1,
    loadStart: 1,
    loadEnd: 5,
    cpus: 8,
    ranLabels: ["oxfmt(1)"],
  });
  assert.equal(overHighLoad.exitCode, 0);
  assert.equal(overHighLoad.status, "PASS_UNDER_LOAD");
  assert.match(overHighLoad.message, /PASS_UNDER_LOAD/);

  const failedHighLoad = evaluateHookOutcome({
    ok: false,
    elapsedS: HOOK_BUDGET_S + 1,
    loadStart: 8,
    loadEnd: 8,
    cpus: 8,
    ranLabels: ["oxfmt(1)"],
  });
  assert.equal(failedHighLoad.exitCode, 1);
  assert.equal(failedHighLoad.status, "FAIL");
});

test("executeHookPlan runs all planned checks strictly with zero skipped checks and fails on missing bins", () => {
  const ran = [];
  const resAll = executeHookPlan(
    {
      jsFiles: ["scripts/a.mjs"],
      hasSketch: true,
      hasDocsOrPkg: true,
      hasSkills: true,
      hasBriefs: true,
      hasKnownFailing: true,
    },
    {
      cwd: "/repo",
      exists: () => true,
      ensureModules: () => ({ ok: true }),
      spawn: (cmd, args) => {
        ran.push([cmd, ...args]);
        return { status: ran.length === 1 ? 1 : 0 };
      },
    },
  );
  assert.equal(resAll.ok, false);
  assert.deepEqual(resAll.ranLabels, [
    "oxfmt(1)",
    "oxlint(1)",
    "sketch:lint",
    "check:project",
    "check:docs",
    "check:skills",
    "check:briefs",
    "known-failing",
  ]);
  assert.equal(ran.length, 8);

  const missingBins = executeHookPlan(
    {
      jsFiles: ["scripts/a.mjs"],
      hasSketch: true,
      hasDocsOrPkg: false,
      hasKnownFailing: false,
    },
    {
      cwd: "/repo",
      exists: () => false,
      ensureModules: () => ({ ok: false }),
      errLog: () => {},
      spawn: () => ({ status: 0 }),
    },
  );
  assert.equal(missingBins.ok, false);
  assert.deepEqual(missingBins.ranLabels, ["oxfmt/oxlint(missing)", "sketch:lint"]);
});

test("rangeBase is the remote tip for an update and the parent of the oldest unpushed commit for a new branch", () => {
  assert.equal(rangeBase({ localSha: "def456", remoteSha: "abc123" }), "abc123");
  let args = null;
  const base = rangeBase(
    { localSha: "ccc", remoteSha: null },
    {
      spawn: (_cmd, a) => {
        args = a;
        return { status: 0, stdout: "ccc\nbbb\naaa\n" };
      },
    },
  );
  assert.deepEqual(args, ["rev-list", "--first-parent", "ccc", "--not", "--remotes"]);
  assert.equal(base, "aaa^");
  assert.equal(
    rangeBase({ localSha: "ccc", remoteSha: null }, { spawn: () => ({ status: 0, stdout: "" }) }),
    "ccc",
  );
});

test("executeHookPlan fails a push whose lint baseline list grew and passes one that shrank", () => {
  const lists = {
    base: { L1: ["a.gd", "b.gd"], L15: { "c.gd": 2 } },
    grown: { L1: ["a.gd", "b.gd", "d.gd"], L15: { "c.gd": 2 } },
    shrunk: { L1: ["a.gd"], L15: { "c.gd": 2 } },
  };
  const plan = {
    jsFiles: [],
    hasSketch: false,
    hasDocsOrPkg: false,
    hasKnownFailing: false,
    hasBaseline: true,
  };
  const errors = [];
  const grown = executeHookPlan(plan, {
    ranges: [{ base: "base", head: "grown" }],
    readBaseline: (ref) => lists[ref],
    errLog: (line) => errors.push(line),
  });
  assert.equal(grown.ok, false);
  assert.deepEqual(grown.ranLabels, ["baseline"]);
  assert.match(errors.join("\n"), /L1 list grew from 2 to 3 entries \(new: d\.gd\)/);
  const shrunk = executeHookPlan(plan, {
    ranges: [{ base: "base", head: "shrunk" }],
    readBaseline: (ref) => lists[ref],
    errLog: () => assert.fail("no growth to report"),
  });
  assert.equal(shrunk.ok, true);
});
