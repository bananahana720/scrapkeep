#!/usr/bin/env node
// Checks JS/MJS formatting with oxfmt on changed files only (so every new/edited file is formatted
// without churning untouched legacy files).
// Usage: node scripts/ci/format-changed.mjs [--base <ref>] [--write] [--] [files...]

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const JS_FILE = /^(?:src|server|scripts|tests|tools)\/.*\.(?:js|mjs|cjs)$|^vite\.config\.js$/;

export function filterFormatTargets(files, exists = (file) => existsSync(path.join(root, file))) {
  return [
    ...new Set(files.map((f) => f.trim()).filter((f) => JS_FILE.test(f) && exists(f))),
  ].sort();
}

export function changedFilesSince(baseRef, { cwd = root, spawn = spawnSync } = {}) {
  const ran = spawn("git", ["diff", "--name-only", "--diff-filter=ACMR", `${baseRef}...HEAD`], {
    cwd,
    encoding: "utf8",
  });
  if (ran.status !== 0) {
    throw new Error(
      `git diff against ${baseRef} failed: ${(ran.stderr || ran.stdout || "").trim()}`,
    );
  }
  return ran.stdout
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function parseArgs(argv) {
  const opts = { base: null, write: false, files: [] };
  let rest = false;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (rest) {
      opts.files.push(arg);
    } else if (arg === "--") {
      rest = true;
    } else if (arg === "--base" && argv[i + 1]) {
      opts.base = argv[++i];
    } else if (arg === "--write") {
      opts.write = true;
    } else if (arg.startsWith("-")) {
      throw new Error(`unknown argument: ${arg}`);
    } else {
      opts.files.push(arg);
    }
  }
  return opts;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  try {
    const opts = parseArgs(process.argv.slice(2));
    const candidates =
      opts.files.length > 0 ? opts.files : opts.base ? changedFilesSince(opts.base) : [];
    const targets = filterFormatTargets(candidates);
    if (targets.length === 0) {
      console.log("format-changed: 0 JS/MJS files to check");
      process.exitCode = 0;
    } else {
      const bin = path.join(
        root,
        "node_modules",
        ".bin",
        process.platform === "win32" ? "oxfmt.cmd" : "oxfmt",
      );
      const args = [
        "-c",
        path.join(root, "scripts", "ci", "oxfmt.json"),
        ...(opts.write ? [] : ["--check"]),
        ...targets,
      ];
      const ran = spawnSync(bin, args, { cwd: root, stdio: "inherit" });
      if (ran.error) throw ran.error;
      process.exitCode = ran.status ?? 1;
    }
  } catch (error) {
    console.error(`format-changed: ${error.message}`);
    process.exitCode = 2;
  }
}
