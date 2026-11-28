#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { isMain } from "../lib/cli.mjs";
import { git, nulSeparated } from "../lib/git.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const JS_FILE = /^(?:src|server|scripts|tests|tools)\/.*\.(?:js|mjs|cjs)$|^vite\.config\.js$/s;

export function filterFormatTargets(files, exists = (file) => existsSync(path.join(root, file))) {
  return [...new Set(files.filter((f) => JS_FILE.test(f) && exists(f)))].sort();
}

export function changedFilesSince(baseRef, { cwd = root, spawn = spawnSync } = {}) {
  return nulSeparated(
    git(["diff", "--no-renames", "--name-only", "-z", "--diff-filter=ACM", `${baseRef}...HEAD`], {
      cwd,
      spawn,
      trim: false,
    }),
  );
}

export function parseFormatArgs(argv) {
  const opts = { base: null, write: false, files: [] };
  let rest = false;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (rest) {
      opts.files.push(arg);
    } else if (arg === "--") {
      rest = true;
    } else if (arg === "--base") {
      if (i + 1 >= argv.length || !argv[i + 1] || argv[i + 1].startsWith("-")) {
        throw new Error("--base requires a ref");
      }
      opts.base = argv[++i];
    } else if (arg === "--write") {
      opts.write = true;
    } else if (arg.startsWith("-")) {
      throw new Error(`unknown argument: ${arg}`);
    } else {
      opts.files.push(arg);
    }
  }
  if (!opts.base && opts.files.length === 0) {
    throw new Error("pass --base <ref> or explicit file paths");
  }
  return opts;
}

if (isMain(import.meta.url)) {
  try {
    const opts = parseFormatArgs(process.argv.slice(2));
    const candidates = opts.files.length > 0 ? opts.files : changedFilesSince(opts.base);
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
