#!/usr/bin/env node
// Runs Scrapkeep's Node test suite (reading the canonical list from package.json "test")
// with proper --test-shard=i/n placement before file arguments and optional deterministic
// --shuffle [--seed <n>] ordering to flush out cross-file state leaks.
// Usage: node scripts/ci/node-tests.mjs [--shard <i/n>] [--shuffle] [--seed <n>] [--dry-run]

import { spawnSync } from "node:child_process";
import { readdirSync, readFileSync, realpathSync } from "node:fs";
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

// Deterministic Fisher-Yates shuffle (mulberry32) so all shards with the same seed partition
// the exact same permuted list without overlap or dropped files.
export function shuffleFiles(files, seed) {
  let state = seed >>> 0;
  const next = () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const copy = [...files];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(next() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

export function buildNodeTestArgs(files, { shard = null, shuffle = false, seed = null } = {}) {
  const ordered = shuffle ? shuffleFiles(files, seed ?? 1) : [...files];
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
  args.push(...ordered);
  return args;
}

function parseArgs(argv) {
  const opts = { shard: null, shuffle: false, seed: null, dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--shard") {
      if (i + 1 >= argv.length) throw new Error("--shard requires a value");
      opts.shard = argv[++i];
    } else if (arg === "--shuffle") {
      opts.shuffle = true;
    } else if (arg === "--seed") {
      if (i + 1 >= argv.length) throw new Error("--seed requires a value");
      const n = Number(argv[++i]);
      if (!Number.isFinite(n)) throw new Error("--seed must be a number");
      opts.seed = Math.trunc(n) >>> 0;
    } else if (arg === "--dry-run") {
      opts.dryRun = true;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  return opts;
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
    const opts = parseArgs(process.argv.slice(2));
    const seed = opts.shuffle ? (opts.seed ?? (Date.now() & 0xffffffff) >>> 0) : null;
    const pkg = JSON.parse(readFileSync(path.join(root, "package.json"), "utf8"));
    const files = resolveTestFiles(pkg.scripts?.test ?? "", root);
    const args = buildNodeTestArgs(files, { shard: opts.shard, shuffle: opts.shuffle, seed });
    if (opts.shuffle) console.log(`node-tests: shuffled ${files.length} files with seed=${seed}`);
    if (opts.dryRun) {
      console.log(
        JSON.stringify({
          fileCount: files.length,
          shard: opts.shard,
          shuffle: opts.shuffle,
          seed,
          firstFiles: args.slice(opts.shard ? 2 : 1, opts.shard ? 5 : 4),
        }),
      );
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
