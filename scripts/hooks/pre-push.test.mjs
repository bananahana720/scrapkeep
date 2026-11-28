import test, { after } from "node:test";
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import {
  chmodSync,
  existsSync,
  lutimesSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  realpathSync,
  rmSync,
  statSync,
  symlinkSync,
  utimesSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { treeFiles } from "../ci/affected.mjs";
import { REPO_ROOT, git } from "../lib/git.mjs";
import {
  HIGH_LOAD_RATIO,
  HOOK_BUDGET_S,
  STALE_COPY_MS,
  changedFilesForRange,
  copyFolder,
  evaluateHookOutcome,
  executeHookPlan,
  isHighLoad,
  parseHookArgs,
  parsePushStdin,
  planHookChecks,
  pushedChanges,
  rangeBase,
  readPushedFiles,
  removeStaleCopies,
  workingTreeDrift,
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
        return { status: 0, stdout: "README.md\0scripts/ci/affected.mjs\0\0README.md\0\0" };
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
        return { status: 0, stdout: "docs/deleted.md\0" };
      },
    },
  );
  assert.deepEqual(updateArgs, ["diff", "--no-renames", "--name-only", "-z", "abc123..def456"]);
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

  const knownFailing = planHookChecks(["project-guide/handoff/KNOWN-FAILING.tsv"], () => true);
  assert.deepEqual(knownFailing, {
    jsFiles: [],
    hasSketch: false,
    hasDocsOrPkg: true,
    hasSkills: false,
    hasBriefs: false,
    hasKnownFailing: true,
    hasBaseline: false,
  });

  assert.equal(planHookChecks(["scripts/structure-sweep.mjs"], () => true).hasDocsOrPkg, true);

  const nearMissLedger = planHookChecks(["docs/KNOWN-FAILING.tsv"], () => true);
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
    () => true,
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
    [
      {
        jsFiles: ["scripts/a.mjs"],
        hasSketch: true,
        hasDocsOrPkg: true,
        hasSkills: true,
        hasBriefs: true,
        hasKnownFailing: true,
      },
    ],
    {
      cwd: "/repo",
      exists: () => true,
      ensureModules: () => ({ ok: true }),
      readPushed: (_head, files) => files.map(() => ""),
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
    [
      {
        jsFiles: ["scripts/a.mjs"],
        hasSketch: true,
        hasDocsOrPkg: false,
        hasKnownFailing: false,
      },
    ],
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
    swapped: { L1: ["a.gd", "other/e.gd"], L15: { "c.gd": 2 } },
    split: { L1: ["a.gd", "b_part.gd"], L15: { "c.gd": 2 } },
  };
  const renames = { swapped: new Map([["other/e.gd", "b.gd"]]) };
  const asked = [];
  const readRenames = (base, head) => {
    asked.push(`${base}..${head}`);
    return new Map();
  };
  const plan = {
    jsFiles: [],
    hasSketch: false,
    hasDocsOrPkg: false,
    hasKnownFailing: false,
    hasBaseline: true,
  };
  const errors = [];
  const grown = executeHookPlan([{ ...plan, base: "base", head: "grown" }], {
    readBaseline: (ref) => lists[ref],
    readRenames,
    errLog: (line) => errors.push(line),
  });
  assert.equal(grown.ok, false);
  assert.deepEqual(grown.ranLabels, ["baseline"]);
  assert.match(errors.join("\n"), /L1 list grew from 2 to 3 entries \(new: d\.gd\)/);
  const shrunk = executeHookPlan([{ ...plan, base: "base", head: "shrunk" }], {
    readBaseline: (ref) => lists[ref],
    readRenames,
    errLog: () => assert.fail("no growth to report"),
  });
  assert.equal(shrunk.ok, true);
  const swapErrors = [];
  const swapped = executeHookPlan([{ ...plan, base: "base", head: "swapped" }], {
    readBaseline: (ref) => lists[ref],
    readRenames,
    errLog: (line) => swapErrors.push(line),
  });
  assert.equal(swapped.ok, false);
  assert.match(
    swapErrors.join("\n"),
    /L1 list has 1 entry the base list lacks.*\(new: other\/e\.gd\).*\n {4}An offence that moved with a split file passes only when it stays inside one directory/,
  );
  const split = executeHookPlan([{ ...plan, base: "base", head: "split" }], {
    readBaseline: (ref) => lists[ref],
    readRenames,
    errLog: () => assert.fail("an offence that moved with a split file inside its directory"),
  });
  assert.equal(split.ok, true);
  assert.deepEqual(asked, ["base..grown", "base..shrunk", "base..swapped", "base..split"]);
  const moved = executeHookPlan([{ ...plan, base: "base", head: "swapped" }], {
    readBaseline: (ref) => lists[ref],
    readRenames: (base, head) => renames[head],
    errLog: () => assert.fail("a renamed file's entry is not growth"),
  });
  assert.equal(moved.ok, true);
});

const scratchDirs = [];
after(() => {
  for (const dir of scratchDirs) rmSync(dir, { recursive: true, force: true });
});

function pushRepo() {
  const dir = mkdtempSync(path.join(os.tmpdir(), "pre-push-push-"));
  scratchDirs.push(dir);
  const work = path.join(dir, "work");
  git(["init", "-q", "--bare", path.join(dir, "remote.git")], { cwd: dir });
  git(["init", "-q", work], { cwd: dir });
  const g = (...args) =>
    git(["-c", "user.name=t", "-c", "user.email=t@example.invalid", ...args], { cwd: work });
  const write = (file, text) => {
    mkdirSync(path.dirname(path.join(work, file)), { recursive: true });
    writeFileSync(path.join(work, file), text);
  };
  write("README.md", "[tool](tools/run.sh)\n");
  write("tools/run.sh", "echo\n");
  write("scripts/kept.mjs", "export const kept = 1;\n");
  for (const config of ["scripts/ci/oxfmt.json", "scripts/ci/oxlint.json"])
    write(config, readFileSync(path.join(REPO_ROOT, config), "utf8"));
  symlinkSync(path.join(REPO_ROOT, "node_modules"), path.join(work, "node_modules"));
  writeFileSync(path.join(work, ".git/info/exclude"), "node_modules\n");
  g("add", "README.md", "tools", "scripts");
  g("commit", "-qm", "base");
  g("remote", "add", "origin", path.join(dir, "remote.git"));
  g("push", "-q", "origin", "HEAD:refs/heads/main");
  const base = g("rev-parse", "HEAD");
  const commit = (message) => {
    g("commit", "-qam", message);
    return g("rev-parse", "HEAD");
  };
  return { work, g, write, base, commit };
}

const BADLY_FORMATTED = "export const   kept=1\n";
const quiet = (cmd, args, options) => spawnSync(cmd, args, { ...options, stdio: "pipe" });
const runPushed = (work, pushed, options = {}) =>
  executeHookPlan(pushed, {
    cwd: work,
    spawn: quiet,
    ensureModules: () => {},
    errLog: () => {},
    ...options,
  });

test("a push that deletes a file selects the docs check even when the file is back on disk", () => {
  const { work, g, write, base, commit } = pushRepo();
  g("rm", "-q", "tools/run.sh");
  const head = commit("delete the tool the readme links to");
  write("tools/run.sh", "echo\n");
  for (const remoteSha of [base, null]) {
    const [pushed] = pushedChanges([{ localSha: head, remoteSha }], { cwd: work });
    assert.deepEqual(pushed.files, ["tools/run.sh"]);
    assert.equal(pushed.hasDocsOrPkg, true, remoteSha ?? "new branch");
    assert.deepEqual(workingTreeDrift([pushed], { cwd: work }), ["tools/run.sh"]);
  }
});

test("a push that changes a page selects the docs check even when the page is changed back on disk", () => {
  const { work, write, base, commit } = pushRepo();
  write("README.md", "[tool](tools/run.sh) and more\n");
  const head = commit("edit the readme");
  write("README.md", "[tool](tools/run.sh)\n");
  const [pushed] = pushedChanges([{ localSha: head, remoteSha: base }], { cwd: work });
  assert.deepEqual(pushed.files, ["README.md"]);
  assert.equal(pushed.hasDocsOrPkg, true);
  assert.deepEqual(workingTreeDrift([pushed], { cwd: work }), ["README.md"]);
  const notes = [];
  const ran = runPushed(work, [pushed], {
    spawn: () => ({ status: 0 }),
    errLog: (line) => notes.push(line),
    drift: () => workingTreeDrift([pushed], { cwd: work }),
  });
  assert.deepEqual(ran.ranLabels, ["check:project", "check:docs"]);
  assert.deepEqual(notes, [
    "pre-push: check:project, check:docs read the files on disk, which differ from what this push holds in 1 file(s): README.md",
  ]);
});

test("the formatter and the linter read the pushed script, not the working tree", () => {
  const { work, g, write, base, commit } = pushRepo();
  write("scripts/kept.mjs", BADLY_FORMATTED);
  const bad = commit("push a badly formatted script");
  write("scripts/kept.mjs", "export const kept = 1;\n");
  const [badPush] = pushedChanges([{ localSha: bad, remoteSha: base }], { cwd: work });
  assert.deepEqual(badPush.jsFiles, ["scripts/kept.mjs"]);
  assert.equal(runPushed(work, [badPush]).ok, false, "fixed on disk, bad in the push");

  g("checkout", "-q", "scripts/kept.mjs");
  write("scripts/kept.mjs", "export const kept = 2;\n");
  const good = commit("push a well formatted script");
  write("scripts/kept.mjs", BADLY_FORMATTED);
  const [goodPush] = pushedChanges([{ localSha: good, remoteSha: bad }], { cwd: work });
  assert.equal(runPushed(work, [goodPush]).ok, true, "bad on disk, good in the push");

  rmSync(path.join(work, "scripts/kept.mjs"));
  const [gone] = pushedChanges([{ localSha: bad, remoteSha: base }], { cwd: work });
  assert.deepEqual(gone.jsFiles, ["scripts/kept.mjs"], "deleted on disk, held by the push");
  assert.equal(gone.hasDocsOrPkg, false);
  assert.equal(runPushed(work, [gone]).ok, false);

  g("checkout", "-q", "--detach", base);
  assert.equal(
    runPushed(work, pushedChanges([{ localSha: bad, remoteSha: base }], { cwd: work })).ok,
    false,
    "another commit checked out",
  );
});

test("a new branch lists the files of its commits that no remote holds, and several refs keep their own trees", () => {
  const { work, g, write, base, commit } = pushRepo();
  write("scripts/kept.mjs", BADLY_FORMATTED);
  const scriptHead = commit("script");
  g("checkout", "-q", "-b", "other", base);
  g("rm", "-q", "tools/run.sh");
  const deleteHead = commit("delete");
  const pushed = pushedChanges(
    parsePushStdin(
      [
        `refs/heads/script ${scriptHead} refs/heads/script ${"0".repeat(40)}`,
        `refs/heads/other ${deleteHead} refs/heads/other ${"0".repeat(40)}`,
      ].join("\n"),
    ),
    { cwd: work },
  );
  assert.deepEqual(
    pushed.map(({ base: from, head, files, jsFiles, hasDocsOrPkg }) => ({
      from,
      head,
      files,
      jsFiles,
      hasDocsOrPkg,
    })),
    [
      {
        from: `${scriptHead}^`,
        head: scriptHead,
        files: ["scripts/kept.mjs"],
        jsFiles: ["scripts/kept.mjs"],
        hasDocsOrPkg: false,
      },
      {
        from: `${deleteHead}^`,
        head: deleteHead,
        files: ["tools/run.sh"],
        jsFiles: [],
        hasDocsOrPkg: true,
      },
    ],
  );
  const ran = runPushed(work, pushed, { spawn: (cmd, args, options) => quiet(cmd, args, options) });
  assert.equal(ran.ok, false, "the script ref is read at its own head");
  assert.deepEqual(ran.ranLabels, ["oxfmt(1)", "oxlint(1)", "check:project", "check:docs"]);
});

test("the push reader fails when it cannot read the push", () => {
  assert.throws(() => parsePushStdin(null), /no push on standard input/);
  assert.deepEqual(parsePushStdin(""), [], "git sends nothing for a push that is up to date");
  assert.throws(
    () => parsePushStdin("refs/heads/a abc refs/heads/a def"),
    /cannot read the push line/,
  );
  assert.throws(
    () => parsePushStdin(`refs/heads/a ${"a".repeat(40)}`),
    /cannot read the push line/,
  );
  assert.throws(() => planHookChecks(["README.md"]), /needs the pushed tree's file test/);
  const { work, g, base } = pushRepo();
  assert.throws(() => treeFiles(undefined, { cwd: work }), /needs a commit/);
  assert.throws(
    () => pushedChanges([{ localSha: "f".repeat(40), remoteSha: base }], { cwd: work }),
    /git ls-tree f+ failed/,
  );
  g("commit", "-q", "--allow-empty", "-m", "empty");
  g("rm", "-q", "-r", ".");
  g("commit", "-q", "-m", "nothing left");
  const empty = g("rev-parse", "HEAD");
  assert.throws(
    () => pushedChanges([{ localSha: empty, remoteSha: base }], { cwd: work }),
    /git ls-tree [0-9a-f]+ lists no files/,
  );
  assert.throws(
    () =>
      runPushed(work, [
        { jsFiles: ["scripts/absent.mjs"], head: base, modes: treeFiles(base, { cwd: work }) },
      ]),
    /[0-9a-f]+:scripts\/absent\.mjs is not in the pushed tree/,
  );
  assert.throws(
    () =>
      workingTreeDrift([{ head: "f".repeat(40), files: [], exists: () => true }], { cwd: work }),
    /git diff/,
  );
});

test("readPushedFiles reads every pushed file with one git process and stops on a reply it cannot read", () => {
  const { work, g, write } = pushRepo();
  write("scripts/a.mjs", "export const a = 1;\n");
  write("scripts/b.mjs", "no newline at the end");
  chmodSync(path.join(work, "scripts/b.mjs"), 0o755);
  g("add", "scripts");
  g("commit", "-qm", "two scripts");
  const head = g("rev-parse", "HEAD");
  assert.match(head, /^[0-9a-f]{40}$/);
  let gits = 0;
  const counted = (cmd, args, options) => {
    gits += 1;
    return spawnSync(cmd, args, options);
  };
  const files = ["scripts/a.mjs", "scripts/b.mjs", "scripts/kept.mjs"];
  const modes = treeFiles(head, { cwd: work });
  assert.equal(modes.get("scripts/b.mjs"), "100755");
  assert.deepEqual(readPushedFiles(head, files, { modes, cwd: work, spawn: counted }).map(String), [
    "export const a = 1;\n",
    "no newline at the end",
    "export const kept = 1;\n",
  ]);
  assert.equal(gits, 1);
  assert.throws(
    () => readPushedFiles(head, files, { cwd: work }),
    /readPushedFiles needs the pushed tree's file modes/,
  );
  assert.throws(
    () => readPushedFiles(head, ["scripts"], { modes, cwd: work }),
    /[0-9a-f]+:scripts is not in the pushed tree/,
  );
  const unasked = () => assert.fail("git was asked");
  for (const file of ["scripts/a\nb.mjs", "scripts/a\rb.mjs"])
    assert.throws(
      () => readPushedFiles(head, [file], { modes: new Map([[file, "100644"]]), spawn: unasked }),
      /cannot ask git for "scripts\/a\\[nr]b\.mjs": the path holds a line break/,
    );
  assert.throws(
    () =>
      readPushedFiles(head, ["scripts/sub.mjs"], {
        modes: new Map([["scripts/sub.mjs", "160000"]]),
        spawn: unasked,
      }),
    /scripts\/sub\.mjs has mode 160000 \(a submodule\); the hook checks only regular files/,
  );
  const reply = (stdout) => () => ({
    status: 0,
    stdout: stdout === null ? null : Buffer.from(stdout),
    stderr: null,
  });
  const cases = [
    [null, /gave no output/],
    ["", /cannot show h:x: no reply/],
    ["h:x missing\n", /cannot show h:x: h:x missing/],
    ["abc tree 3\nabc\n", /cannot show h:x: abc tree 3/],
    ["abc blob 10\nshort\n", /cut h:x short/],
    ["abc blob 2\nhi\nextra", /gave more than was asked/],
  ];
  for (const [stdout, error] of cases)
    assert.throws(
      () =>
        readPushedFiles("h", ["x"], { modes: new Map([["x", "100644"]]), spawn: reply(stdout) }),
      error,
    );
});

test("a pushed link at a script path stops the hook, naming the path and its mode", () => {
  const { work, g, base } = pushRepo();
  symlinkSync("kept.mjs", path.join(work, "scripts/alias.mjs"));
  g("add", "scripts/alias.mjs");
  g("commit", "-qm", "a link where a script goes");
  const head = g("rev-parse", "HEAD");
  const pushed = pushedChanges([{ localSha: head, remoteSha: base }], { cwd: work });
  assert.deepEqual(pushed[0].jsFiles, ["scripts/alias.mjs"]);
  assert.throws(
    () => runPushed(work, pushed),
    new RegExp(
      `^Error: ${head}:scripts/alias\\.mjs has mode 120000 \\(a symbolic link\\); the hook checks only regular files`,
    ),
  );
});

test("a pushed script whose name git would quote is checked like any other, on a new branch and an update", () => {
  const { work, g, write, base } = pushRepo();
  const names = ['scripts/a b".mjs', "scripts/café.mjs"];
  const pushAs = (contents, message) => {
    names.forEach((name, i) => write(name, contents[i]));
    g("add", ...names);
    g("commit", "-qm", message);
    return g("rev-parse", "HEAD");
  };
  const good = "export const kept = 1;\n";
  const heads = [
    [pushAs([good, good], "both formatted"), true],
    [pushAs([BADLY_FORMATTED, good], "the quoted name is not formatted"), false],
    [pushAs([good, BADLY_FORMATTED], "the accented name is not formatted"), false],
  ];
  for (const [head, ok] of heads)
    for (const remoteSha of [base, null]) {
      const pushed = pushedChanges([{ localSha: head, remoteSha }], { cwd: work });
      assert.deepEqual(pushed[0].jsFiles, names);
      assert.equal(pushed[0].hasDocsOrPkg, false);
      const ran = runPushed(work, pushed);
      assert.equal(ran.ok, ok, `${head} from ${remoteSha}`);
      assert.deepEqual(ran.ranLabels, ["oxfmt(2)", "oxlint(2)"]);
    }
  write(names[1], "export const kept = 2;\n");
  const [pushed] = pushedChanges([{ localSha: heads[2][0], remoteSha: base }], { cwd: work });
  assert.deepEqual(workingTreeDrift([pushed], { cwd: work }), [names[1]]);
});

const HOOK = path.join(REPO_ROOT, "scripts/hooks/pre-push.mjs");
const OWN_FOLDER = `scrapkeep-pre-push-${process.getuid()}`;
const runHook = (tmp) =>
  spawnSync(process.execPath, [HOOK], {
    env: { ...process.env, TMPDIR: tmp },
    input: "",
    encoding: "utf8",
  });

test(
  "a hook stopped by SIGTERM in a child call leaves a copy that the next start removes, and nothing else",
  { timeout: 60_000 },
  async () => {
    const tmp = realpathSync(mkdtempSync(path.join(os.tmpdir(), "pre-push-stop-")));
    scratchDirs.push(tmp);
    const stopped = spawn(
      process.execPath,
      [
        "--input-type=module",
        "-e",
        [
          'import { spawnSync } from "node:child_process";',
          `import { executeHookPlan } from ${JSON.stringify(pathToFileURL(HOOK).href)};`,
          'executeHookPlan([{ jsFiles: ["scripts/a.mjs"], head: "HEAD", modes: new Map() }], {',
          "  exists: () => true,",
          "  ensureModules: () => {},",
          '  readPushed: (_head, files) => files.map(() => "export {};\\n"),',
          "  spawn: () =>",
          '    spawnSync("/bin/sh", ["-c", "echo in a child call; exec sleep 30"], {',
          '      stdio: ["ignore", "inherit", "inherit"],',
          "    }),",
          "});",
        ].join("\n"),
      ],
      {
        env: { ...process.env, TMPDIR: tmp },
        detached: true,
        stdio: ["ignore", "pipe", "inherit"],
      },
    );
    const exited = new Promise((resolve) =>
      stopped.once("exit", (_code, signal) => resolve(signal)),
    );
    const ready = await Promise.race([
      new Promise((resolve) => stopped.stdout.once("data", () => resolve(true))),
      exited.then(() => false),
    ]);
    assert.ok(ready, "the stand-in hook ended before it reached a child call");
    process.kill(stopped.pid, "SIGTERM");
    assert.equal(await exited, "SIGTERM");
    try {
      process.kill(-stopped.pid, "SIGKILL");
    } catch {}

    const folder = path.join(tmp, OWN_FOLDER);
    const [left, ...more] = readdirSync(folder);
    assert.deepEqual(more, []);
    assert.match(left, new RegExp(`^copy-${stopped.pid}-[A-Za-z0-9]{6}$`));
    assert.ok(existsSync(path.join(folder, left, "scripts/a.mjs")), "the stop skipped the cleanup");

    const outside = path.join(tmp, `copy-${stopped.pid}-aaaaaa`);
    const kept = {
      [`other-${stopped.pid}-bbbbbb`]: "dir",
      [`copy-${process.pid}-cccccc`]: "dir",
      [`copy-${stopped.pid}-dddddd`]: "fresh",
      [`copy-${stopped.pid}-eeeeee`]: "link",
      [`copy-${stopped.pid}-ffffff`]: "file",
      [`copy-${stopped.pid}-ggggggg`]: "dir",
      "copy-0-hhhhhh": "dir",
      "copy-1-iiiiii": "dir",
      "copy-012345-jjjjjj": "dir",
      "copy-2147483648-kkkkkk": "dir",
      "copy-4294967294-llllll": "dir",
      "copy-4294967295-mmmmmm": "dir",
      "copy-4294967296-nnnnnn": "dir",
    };
    mkdirSync(path.join(outside, "inner"), { recursive: true });
    for (const [name, kind] of Object.entries(kept)) {
      const at = path.join(folder, name);
      if (kind === "link") symlinkSync(outside, at);
      else if (kind === "file") writeFileSync(at, "");
      else mkdirSync(at);
    }
    const old = new Date(Date.now() - 2 * STALE_COPY_MS);
    for (const name of [left, ...Object.keys(kept)].filter((name) => kept[name] !== "fresh"))
      lutimesSync(path.join(folder, name), old, old);
    utimesSync(outside, old, old);

    const next = runHook(tmp);
    assert.equal(next.status, 0, next.stderr);
    assert.match(next.stdout, /^pre-push: PASS in /);
    assert.deepEqual(readdirSync(folder).sort(), Object.keys(kept).sort());
    assert.ok(existsSync(path.join(outside, "inner")), "a folder outside the hook's own is kept");
  },
);

test("the hook stops when the folder for its copies is not a plain folder of this user's that only this user can write", () => {
  for (const [make, wrong] of [
    [(at) => writeFileSync(at, ""), /is not a folder/],
    [(at) => symlinkSync(os.tmpdir(), at), /is not a folder/],
    [
      (at) => {
        mkdirSync(at);
        chmodSync(at, 0o777);
      },
      /can be written by other users \(mode 777\)/,
    ],
    [
      (at) => {
        mkdirSync(at);
        chmodSync(at, 0o720);
      },
      /can be written by other users \(mode 720\)/,
    ],
  ]) {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "pre-push-folder-"));
    scratchDirs.push(tmp);
    const folder = path.join(tmp, OWN_FOLDER);
    make(folder);
    const ran = runHook(tmp);
    assert.equal(ran.status, 2, ran.stdout);
    assert.ok(ran.stderr.startsWith(`pre-push: ${folder} `), ran.stderr);
    assert.match(ran.stderr, wrong);
  }
  const tmp = mkdtempSync(path.join(os.tmpdir(), "pre-push-folder-"));
  scratchDirs.push(tmp);
  const someoneElse = process.getuid() + 1;
  assert.throws(
    () => removeStaleCopies({ tmp, uid: someoneElse, errLog: assert.fail }),
    new RegExp(
      `scrapkeep-pre-push-${someoneElse} belongs to user ${process.getuid()}, not to this user \\(${someoneElse}\\)`,
    ),
  );
  assert.equal(copyFolder({ tmp }), path.join(tmp, OWN_FOLDER));
  assert.equal(statSync(path.join(tmp, OWN_FOLDER)).mode & 0o077, 0, "made for this user only");
});

test(
  "a stale copy that cannot be removed is named in one line and the push goes on",
  {
    skip: process.getuid() === 0 ? "root can remove a file in a folder it may not write" : false,
  },
  () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "pre-push-stuck-"));
    scratchDirs.push(tmp);
    const folder = copyFolder({ tmp });
    const dead = spawnSync(process.execPath, ["-e", ""]).pid;
    const stuck = path.join(folder, `copy-${dead}-aaaaaa`);
    mkdirSync(path.join(stuck, "locked"), { recursive: true });
    writeFileSync(path.join(stuck, "locked/kept.mjs"), "");
    chmodSync(path.join(stuck, "locked"), 0o500);
    try {
      const old = new Date(Date.now() - 2 * STALE_COPY_MS);
      utimesSync(stuck, old, old);
      const ran = runHook(tmp);
      assert.equal(ran.status, 0, ran.stderr);
      assert.match(ran.stdout, /^pre-push: PASS in /);
      const said = ran.stderr.split("\n").filter(Boolean);
      assert.equal(said.length, 1, ran.stderr);
      assert.ok(said[0].startsWith(`pre-push: left the stale copy ${stuck}: `), said[0]);
      assert.ok(existsSync(path.join(stuck, "locked/kept.mjs")));
    } finally {
      chmodSync(path.join(stuck, "locked"), 0o700);
    }
  },
);
