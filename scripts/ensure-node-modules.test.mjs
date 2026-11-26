import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readlinkSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { ensureNodeModules, parseEnsureArgs } from "./ensure-node-modules.mjs";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const scriptPath = path.join(repoRoot, "scripts", "ensure-node-modules.mjs");

function git(cwd, ...args) {
  const ran = spawnSync("git", args, {
    cwd,
    encoding: "utf8",
    env: {
      ...process.env,
      GIT_AUTHOR_NAME: "Test",
      GIT_AUTHOR_EMAIL: "test@example.invalid",
      GIT_COMMITTER_NAME: "Test",
      GIT_COMMITTER_EMAIL: "test@example.invalid",
    },
  });
  assert.equal(ran.status, 0, ran.stderr);
  return ran.stdout.trim();
}

function makeFakePrimary(primaryDir, lockContent = '{"lockfileVersion":3}\n') {
  mkdirSync(path.join(primaryDir, "node_modules", ".bin"), { recursive: true });
  writeFileSync(path.join(primaryDir, "node_modules", ".bin", "oxfmt"), "#!/bin/sh\n");
  writeFileSync(path.join(primaryDir, "node_modules", ".bin", "oxlint"), "#!/bin/sh\n");
  writeFileSync(path.join(primaryDir, "package-lock.json"), lockContent);
}

test("parseEnsureArgs parses --worktree and rejects unknown flags", () => {
  assert.equal(parseEnsureArgs(["--worktree", "/tmp/wt"]).worktree, path.resolve("/tmp/wt"));
  assert.throws(() => parseEnsureArgs(["--worktree"]), /--worktree requires/);
  assert.throws(() => parseEnsureArgs(["--bogus"]), /unknown argument/);
});

test("ensureNodeModules symlinks node_modules in a git worktree when lockfiles and bins match", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "ensure-nm-"));
  try {
    const primary = path.join(tmp, "primary");
    const wt = path.join(tmp, "wt");
    mkdirSync(primary, { recursive: true });
    git(primary, "init", "-q");
    makeFakePrimary(primary);
    git(primary, "add", "package-lock.json");
    git(primary, "commit", "-q", "-m", "init");
    git(primary, "worktree", "add", "-q", "-b", "wt-branch", wt, "HEAD");

    const res = ensureNodeModules(wt);
    assert.equal(res.ok, true);
    assert.equal(res.linked, true);
    assert.equal(res.reason, "linked");
    assert.equal(lstatSync(path.join(wt, "node_modules")).isSymbolicLink(), true);
    assert.equal(
      realpathSync(readlinkSync(path.join(wt, "node_modules"))),
      realpathSync(path.join(primary, "node_modules")),
    );

    const second = ensureNodeModules(wt);
    assert.equal(second.ok, true);
    assert.equal(second.linked, false);
    assert.equal(second.reason, "already_exists");
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test("ensureNodeModules skips on primary checkout, missing bins, or lockfile mismatch", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "ensure-nm-skip-"));
  try {
    const primary = path.join(tmp, "primary");
    const wt = path.join(tmp, "wt");
    mkdirSync(primary, { recursive: true });
    git(primary, "init", "-q");
    writeFileSync(path.join(primary, "package-lock.json"), '{"v":1}\n');
    git(primary, "add", "package-lock.json");
    git(primary, "commit", "-q", "-m", "init");
    git(primary, "worktree", "add", "-q", "-b", "wt-branch", wt, "HEAD");

    const primaryRes = ensureNodeModules(primary);
    assert.equal(primaryRes.ok, false);
    assert.equal(primaryRes.reason, "primary_checkout");

    const noBins = ensureNodeModules(wt);
    assert.equal(noBins.ok, false);
    assert.equal(noBins.reason, "primary_bins_missing");

    makeFakePrimary(primary, '{"v":1}\n');
    writeFileSync(path.join(wt, "package-lock.json"), '{"v":2}\n');
    const mismatch = ensureNodeModules(wt);
    assert.equal(mismatch.ok, false);
    assert.equal(mismatch.reason, "lockfile_mismatch");
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test("ensure-node-modules CLI exits 0 on link and 1 on mismatch", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "ensure-nm-cli-"));
  try {
    const primary = path.join(tmp, "primary");
    const wt = path.join(tmp, "wt");
    mkdirSync(primary, { recursive: true });
    git(primary, "init", "-q");
    makeFakePrimary(primary);
    git(primary, "add", "package-lock.json");
    git(primary, "commit", "-q", "-m", "init");
    git(primary, "worktree", "add", "-q", "-b", "wt-cli", wt, "HEAD");

    const okRun = spawnSync(process.execPath, [scriptPath, "--worktree", wt], { encoding: "utf8" });
    assert.equal(okRun.status, 0, okRun.stderr);
    assert.match(okRun.stdout, /linked/);

    const badArg = spawnSync(process.execPath, [scriptPath, "--bad"], { encoding: "utf8" });
    assert.equal(badArg.status, 2);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
