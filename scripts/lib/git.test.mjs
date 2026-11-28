import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
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
