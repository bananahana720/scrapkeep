#!/usr/bin/env node
// Runs Scrapkeep's Node test suite (reading the canonical list from package.json "test")
// with proper --test-shard=i/n placement before file arguments.
// Usage: node scripts/ci/node-tests.mjs [--shard <i/n>] [--dry-run]

import { spawnSync } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

function expandToken(token, baseDir = root) {
  if (!token.includes("*")) return [token];
  const dir = path.dirname(token);
  const pattern = path.basename(token);
  const regex = new RegExp(
    "^" + pattern.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*") + "$",
  );
  return readdirSync(path.join(baseDir, dir))
    .filter((name) => regex.test(name))
    .sort()
    .map((name) => path.posix.join(dir, name));
}

export function resolveTestFiles(testScript, baseDir = root) {
  const prefix = "node --test ";
  if (!testScript.startsWith(prefix)) {
    throw new Error(`expected package.json "test" script to start with "${prefix}"`);
  }
  const tokens = testScript.slice(prefix.length).trim().split(/\s+/).filter(Boolean);
  return [...new Set(tokens.flatMap((token) => expandToken(token, baseDir)))];
}

export function buildNodeTestArgs(files, { shard = null } = {}) {
  const args = ["--test"];
  if (shard) {
    if (!/^\d+\/\d+$/.test(shard)) {
      throw new Error(`--shard must be INDEX/TOTAL (for example 1/2); got "${shard}"`);
    }
    const [index, total] = shard.split("/").map(Number);
    if (index < 1 || total < 1 || index > total) {
      throw new Error(`--shard ${shard} out of range`);
    }
    args.push(`--test-shard=${shard}`);
  }
  args.push(...files);
  return args;
}

function parseArgs(argv) {
  const opts = { shard: null, dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--shard" && argv[i + 1]) opts.shard = argv[++i];
    else if (arg === "--dry-run") opts.dryRun = true;
    else throw new Error(`unknown argument: ${arg}`);
  }
  return opts;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  try {
    const opts = parseArgs(process.argv.slice(2));
    const pkg = JSON.parse(readFileSync(path.join(root, "package.json"), "utf8"));
    const files = resolveTestFiles(pkg.scripts?.test ?? "", root);
    const args = buildNodeTestArgs(files, { shard: opts.shard });
    if (opts.dryRun) {
      console.log(JSON.stringify({ fileCount: files.length, shard: opts.shard, args: args.slice(0, 5) }));
      process.exitCode = 0;
    } else {
      const ran = spawnSync(process.execPath, args, { cwd: root, stdio: "inherit" });
      if (ran.error) throw ran.error;
      process.exitCode = ran.status ?? 1;
    }
  } catch (error) {
    console.error(`node-tests: ${error.message}`);
    process.exitCode = 2;
  }
}
