#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, lstatSync, readFileSync, realpathSync, symlinkSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function safeRealpath(target) {
  try {
    return realpathSync(target);
  } catch {
    return path.resolve(target);
  }
}

function sha256(filePath) {
  return createHash("sha256").update(readFileSync(filePath)).digest("hex");
}

function binName(name, platform) {
  return platform === "win32" ? `${name}.cmd` : name;
}

export function ensureNodeModules(worktreeRoot = root, opts = {}) {
  const { spawn = spawnSync, platform = process.platform, log = null } = opts;
  const worktree = path.resolve(worktreeRoot);
  const worktreeModules = path.join(worktree, "node_modules");

  try {
    lstatSync(worktreeModules);
    return { ok: true, linked: false, reason: "already_exists" };
  } catch (error) {
    if (error.code !== "ENOENT") {
      return { ok: false, linked: false, reason: error.message };
    }
  }

  const ran = spawn(
    "git",
    ["-C", worktree, "rev-parse", "--path-format=absolute", "--git-common-dir"],
    { encoding: "utf8" },
  );
  if (ran.error || ran.status !== 0 || !ran.stdout.trim()) {
    return { ok: false, linked: false, reason: "git_common_dir_failed" };
  }

  const primary = path.dirname(ran.stdout.trim());
  const worktreeReal = safeRealpath(worktree);
  const primaryReal = safeRealpath(primary);
  if (primaryReal === worktreeReal) {
    return { ok: false, linked: false, reason: "primary_checkout" };
  }

  const primaryModules = path.join(primaryReal, "node_modules");
  const oxfmtBin = path.join(primaryModules, ".bin", binName("oxfmt", platform));
  const oxlintBin = path.join(primaryModules, ".bin", binName("oxlint", platform));
  if (!existsSync(oxfmtBin) || !existsSync(oxlintBin)) {
    return { ok: false, linked: false, reason: "primary_bins_missing" };
  }

  const worktreeLock = path.join(worktree, "package-lock.json");
  const primaryLock = path.join(primaryReal, "package-lock.json");
  if (!existsSync(worktreeLock) || !existsSync(primaryLock)) {
    return { ok: false, linked: false, reason: "lockfile_missing" };
  }
  if (sha256(worktreeLock) !== sha256(primaryLock)) {
    return { ok: false, linked: false, reason: "lockfile_mismatch" };
  }

  symlinkSync(primaryModules, worktreeModules, platform === "win32" ? "junction" : "dir");
  if (log) log(`ensure-node-modules: linked ${worktreeModules} -> ${primaryModules}`);
  return { ok: true, linked: true, reason: "linked", target: primaryModules };
}

export function parseEnsureArgs(argv) {
  let worktree = root;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--worktree") {
      if (i + 1 >= argv.length || !argv[i + 1] || argv[i + 1].startsWith("-")) {
        throw new Error("--worktree requires a directory");
      }
      worktree = path.resolve(argv[++i]);
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  return { worktree };
}

function isMain() {
  if (!process.argv[1]) return false;
  try {
    return realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1]);
  } catch {
    return fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
  }
}

if (isMain()) {
  try {
    const { worktree } = parseEnsureArgs(process.argv.slice(2));
    const result = ensureNodeModules(worktree, { log: (msg) => console.log(msg) });
    if (!result.ok) {
      console.error(`ensure-node-modules: skipped (${result.reason})`);
      process.exitCode = 1;
    } else {
      if (!result.linked) {
        console.log(`ensure-node-modules: ${result.reason}`);
      }
      process.exitCode = 0;
    }
  } catch (error) {
    console.error(`ensure-node-modules: ${error.message}`);
    process.exitCode = 2;
  }
}
