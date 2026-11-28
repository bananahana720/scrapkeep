import assert from "node:assert/strict";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { DEFAULT_MAX_BUFFER, REPO_ROOT, cleanHead, git, gitOptional, gitState } from "./git.mjs";

function makeTempRepo() {
  const dir = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-git-lib-"));
  git(["init", "-q", "-b", "main"], { cwd: dir });
  git(["config", "user.email", "test@example.invalid"], { cwd: dir });
  git(["config", "user.name", "Test"], { cwd: dir });
  git(["config", "commit.gpgsign", "false"], { cwd: dir });
  mkdirSync(path.join(dir, "sketches/core-loop/src"), { recursive: true });
  writeFileSync(path.join(dir, "sketches/core-loop/src/a.gd"), "extends Node\n");
  git(["add", "."], { cwd: dir });
  git(["commit", "-q", "-m", "initial"], { cwd: dir });
  return dir;
}

test("git and gitOptional read the repository cwd is in, even when a git hook exported another one", () => {
  const dir = makeTempRepo();
  const before = process.env.GIT_DIR;
  process.env.GIT_DIR = path.join(REPO_ROOT, ".git");
  try {
    const cwd = path.join(dir, "sketches/core-loop");
    assert.equal(git(["ls-files", "--", "src"], { cwd }), "src/a.gd");
    assert.equal(gitOptional(["ls-files", "--", "src"], { cwd }), "src/a.gd");
    assert.equal(realpathSync(git(["rev-parse", "--show-toplevel"], { cwd })), realpathSync(dir));
    assert.equal(cleanHead(dir), git(["rev-parse", "HEAD"], { cwd: dir }));
  } finally {
    if (before === undefined) delete process.env.GIT_DIR;
    else process.env.GIT_DIR = before;
    rmSync(dir, { recursive: true, force: true });
  }
});

test("git and gitOptional use 64 MiB default maxBuffer, trim by default, and handle errors", () => {
  assert.equal(DEFAULT_MAX_BUFFER, 64 * 1024 * 1024);
  let seen = null;
  const out = git(["rev-parse", "HEAD"], {
    cwd: "/fake",
    spawn: (_cmd, args, opts) => {
      seen = { args, opts };
      return { status: 0, stdout: "abc123\n", stderr: "" };
    },
  });
  assert.equal(out, "abc123");
  assert.equal(seen.opts.maxBuffer, DEFAULT_MAX_BUFFER);
  assert.equal(seen.opts.cwd, "/fake");

  assert.equal(
    git(["status"], {
      trim: false,
      spawn: () => ({ status: 0, stdout: " M file.mjs\n", stderr: "" }),
    }),
    " M file.mjs\n",
  );
  assert.throws(
    () =>
      git(["bad-cmd"], {
        spawn: () => ({ status: 1, stdout: "", stderr: "unknown command" }),
      }),
    /git bad-cmd failed: unknown command/,
  );
  assert.equal(
    gitOptional(["bad-cmd"], {
      spawn: () => ({ status: 1, stdout: "", stderr: "fail" }),
    }),
    null,
  );
  assert.equal(
    gitOptional(["status"], {
      trim: false,
      spawn: () => ({ status: 0, stdout: " M file.mjs\n", stderr: "" }),
    }),
    " M file.mjs",
  );
});

test("git hands a failed call's exit status and output on the error, and both helpers pass a timeout through", () => {
  const failed = { status: 1, stdout: "partial\n", stderr: "no match\n" };
  assert.throws(
    () => git(["grep", "x"], { spawn: () => failed }),
    (error) => error.status === 1 && error.stdout === "partial\n" && error.stderr === "no match\n",
  );
  const seen = [];
  const spawn = (_cmd, _args, opts) => {
    seen.push(opts);
    return { status: 0, stdout: "ok\n", stderr: "" };
  };
  git(["status"], { spawn, timeout: 3000 });
  gitOptional(["status"], { spawn, timeout: 3000 });
  git(["status"], { spawn });
  assert.deepEqual(
    seen.map((opts) => opts.timeout),
    [3000, 3000, undefined],
  );
  const spawnError = Object.assign(new Error("spawnSync git ETIMEDOUT"), { code: "ETIMEDOUT" });
  assert.throws(
    () => git(["status"], { spawn: () => ({ status: null, error: spawnError }) }),
    /ETIMEDOUT/,
  );
  assert.equal(
    gitOptional(["status"], { spawn: () => ({ status: null, error: spawnError }) }),
    null,
  );
});

test("git and gitOptional refuse a second argument that is not an options object, before starting git", () => {
  const bin = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-fake-git-"));
  const marker = path.join(bin, "started");
  writeFileSync(path.join(bin, "git"), `#!/bin/sh\necho "$@" >> "${marker}"\n`, { mode: 0o755 });
  const before = process.env.PATH;
  process.env.PATH = bin;
  try {
    for (const [bad, kind] of [
      ["/some/dir", "a string"],
      [3, "a number"],
      [["/some/dir"], "an array"],
      [null, "null"],
      [new Map(), "a Map"],
      [() => {}, "a function"],
    ]) {
      for (const [name, call] of [
        ["git", git],
        ["gitOptional", gitOptional],
      ]) {
        assert.throws(
          () => call(["status"], bad),
          (error) =>
            error instanceof TypeError &&
            error.message ===
              `${name}(args, options): options must be an object such as { cwd }, got ${kind}`,
        );
      }
    }
    for (const [name, call] of [
      ["gitState", gitState],
      ["cleanHead", cleanHead],
    ]) {
      assert.throws(
        () => call({ cwd: "/some/dir" }),
        (error) =>
          error instanceof TypeError &&
          error.message ===
            `${name}(cwd, options): cwd must be a folder path string, got an object`,
      );
    }
    assert.equal(existsSync(marker), false, "git was started");
    git(["status"], Object.assign(Object.create(null), { cwd: bin }));
    assert.equal(readFileSync(marker, "utf8"), "status\n", "the fake git on PATH did not run");
  } finally {
    if (before === undefined) delete process.env.PATH;
    else process.env.PATH = before;
    rmSync(bin, { recursive: true, force: true });
  }
});

test("gitState and cleanHead report repository state and refuse dirty trees", () => {
  const dir = makeTempRepo();
  const nonRepo = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-nongit-"));
  try {
    assert.equal(gitState(nonRepo), null);
    const state = gitState(dir);
    assert.equal(realpathSync(state.root), realpathSync(dir));
    assert.equal(state.branch, "main");
    assert.equal(state.dirty, false);
    assert.match(state.head, /^[0-9a-f]{40}$/);
    assert.equal(cleanHead(dir), state.head);

    writeFileSync(path.join(dir, "sketches/core-loop/src/untracked.gd"), "extends Node\n");
    assert.throws(() => cleanHead(dir), /untracked files under the game's src or assets/);
    rmSync(path.join(dir, "sketches/core-loop/src/untracked.gd"));

    writeFileSync(path.join(dir, "sketches/core-loop/src/a.gd"), "extends Node\nvar x := 1\n");
    assert.equal(gitState(dir).dirty, true);
    assert.throws(() => cleanHead(dir), /uncommitted changes to tracked files/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
    rmSync(nonRepo, { recursive: true, force: true });
  }
});

const GIT_COMMAND = String.raw`(?:[^"'\`]*?(?:&&|\|\||[;|]|-l?c\s+['"]?))?\s*git\s`;
const STARTS_GIT = new RegExp(
  [
    String.raw`\b[\w$.]+\(\s*["'\`]git["'\`]\s*,`,
    String.raw`\bexec(?:Sync|Async)?\(\s*["'\`]` + GIT_COMMAND,
    String.raw`["'\`]-l?c["'\`]\s*,\s*["'\`]` + GIT_COMMAND,
  ].join("|"),
);

const STARTS_GIT_BY_HAND = {
  "scripts/lib/git.mjs": "the helper itself",
  "scripts/ci/affected.mjs":
    "the CI changes job checks out only scripts/ci and scripts/lib/cli.mjs, so scripts/lib/git.mjs is not on disk when it runs",
  "scripts/sketch-lint.test.mjs": "pull request 1332 holds this file",
};

function filesStartingGit(cwd) {
  const files = git(["ls-files", "-z", "--", "*.mjs", "*.js"], { cwd, trim: false })
    .split("\0")
    .filter(Boolean);
  if (files.length === 0) throw new Error(`git ls-files lists no .mjs or .js file in ${cwd}`);
  return files.filter((file) => STARTS_GIT.test(readFileSync(path.join(cwd, file), "utf8"))).sort();
}

test("only the allowed files start git by hand; every other script starts it through scripts/lib/git.mjs", () => {
  assert.deepEqual(
    filesStartingGit(REPO_ROOT),
    Object.keys(STARTS_GIT_BY_HAND).sort(),
    "start git with git or gitOptional from scripts/lib/git.mjs, which drops the repository variables a git hook exports so the cwd decides the repository",
  );
});

test("the direct-git listing names a file that starts git by hand and fails on an empty listing or a folder outside git", () => {
  const dir = makeTempRepo();
  const empty = makeTempRepo();
  const outside = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-nongit-"));
  try {
    writeFileSync(path.join(dir, "a.mjs"), 'spawnSync(\n  "git",\n  ["status"],\n);\n');
    writeFileSync(path.join(dir, "b.js"), "execSync(`" + "git rev-parse HEAD`);\n");
    writeFileSync(
      path.join(dir, "c.mjs"),
      [
        'git(["status"]);',
        "throw new Error(`git status failed`);",
        'spawnSync("python3", ["-c", "import git"]);',
        'git(["-c", "user.name=t", "commit"]);',
        'spawnSync("sh", ["-c", "digit status"]);',
        "",
      ].join("\n"),
    );
    const cases = {
      "d.mjs": ["runCmd(", '"git", ["-C", root, "status"]);'],
      "e.mjs": ['spawnSync("sh", ["-c", "', 'git status"]);'],
      "f.mjs": ['spawn("bash", [\n  "-lc",\n  `cd ${dir} && ', "git fetch origin`,\n]);"],
      "g.js": ["execSync(\"bash -lc '", "git status'\");"],
      "h.mjs": ["execSync(`npm ci; ", "git log -1`);"],
    };
    for (const [file, parts] of Object.entries(cases))
      writeFileSync(path.join(dir, file), parts.join("") + "\n");
    const files = ["a.mjs", "b.js", "c.mjs", "d.mjs", "e.mjs", "f.mjs", "g.js", "h.mjs"];
    git(["add", ...files], { cwd: dir });
    assert.deepEqual(
      filesStartingGit(dir),
      files.filter((file) => file !== "c.mjs"),
    );
    assert.throws(() => filesStartingGit(empty), /lists no \.mjs or \.js file/);
    assert.throws(() => filesStartingGit(outside), /not a git repository/i);
  } finally {
    for (const d of [dir, empty, outside]) rmSync(d, { recursive: true, force: true });
  }
});
