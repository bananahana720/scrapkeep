#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync, readdirSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ensureNodeModules } from "../ensure-node-modules.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

export const TEST_SCOPES = Object.freeze([
  Object.freeze({ dir: "tests", suffix: ".test.js", recursive: false }),
  Object.freeze({ dir: "scripts", suffix: ".test.mjs", recursive: true }),
  Object.freeze({
    dir: "project-guide/handoff/sitting-kit",
    suffix: ".test.mjs",
    recursive: false,
  }),
]);

export const EXCLUDED_TESTS = Object.freeze({
  "scripts/budget-audit.test.mjs":
    "fails on base: asserts pilot_patch_anim has 0 bones and 0 clips, while the committed GLB has 25 bones and 8 clips",
});

function walkScope(baseDir, relDir, suffix, recursive, out) {
  const absDir = path.join(baseDir, relDir);
  if (!existsSync(absDir)) return;
  const entries = readdirSync(absDir, { withFileTypes: true }).sort((a, b) =>
    a.name < b.name ? -1 : a.name > b.name ? 1 : 0,
  );
  for (const entry of entries) {
    if (entry.name.startsWith(".") || entry.name === "node_modules") continue;
    const relPath = path.posix.join(relDir, entry.name);
    if (entry.isDirectory()) {
      if (recursive) walkScope(baseDir, relPath, suffix, true, out);
    } else if (entry.isFile() && entry.name.endsWith(suffix)) {
      out.push(relPath);
    }
  }
}

export function discoverTestFiles(
  baseDir = root,
  { scopes = TEST_SCOPES, excluded = EXCLUDED_TESTS } = {},
) {
  const found = [];
  for (const scope of scopes) {
    walkScope(baseDir, scope.dir, scope.suffix, scope.recursive, found);
  }
  const excludedSet = new Set(Object.keys(excluded));
  return [...new Set(found)].filter((file) => !excludedSet.has(file)).sort();
}

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

export function parseShardSpec(shard) {
  if (!/^\d+\/\d+$/.test(shard)) {
    throw new Error(`--shard must be INDEX/TOTAL (for example 1/2); got "${shard}"`);
  }
  const [index, total] = shard.split("/").map(Number);
  if (index < 1 || total < 1 || index > total) {
    throw new Error(`--shard ${shard} out of range`);
  }
  return { index, total };
}

export function selectShardFiles(files, { shard = null, shuffle = false, seed = null } = {}) {
  if (shard && shuffle && seed === null) {
    throw new Error(
      "--shard with --shuffle requires an explicit --seed so all shards partition identically",
    );
  }
  const ordered = shuffle ? shuffleFiles(files, seed ?? 1) : [...files];
  if (!shard) return ordered;
  const { index, total } = parseShardSpec(shard);
  return ordered.filter((_, idx) => idx % total === index - 1);
}

export function buildNodeTestArgs(files, { shard = null, shuffle = false, seed = null } = {}) {
  const selected = selectShardFiles(files, { shard, shuffle, seed });
  return ["--test", ...selected];
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
      const raw = argv[++i];
      if (raw.trim() === "" || !Number.isFinite(Number(raw))) {
        throw new Error(`--seed must be a finite number; got "${raw}"`);
      }
      opts.seed = Math.trunc(Number(raw)) >>> 0;
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
    if (opts.shard && opts.shuffle && opts.seed === null) {
      throw new Error("--shard with --shuffle requires an explicit --seed");
    }
    const seed = opts.shuffle ? (opts.seed ?? (Date.now() & 0xffffffff) >>> 0) : null;
    const files = discoverTestFiles(root);
    if (files.length === 0) {
      throw new Error("no Node test files discovered");
    }
    const args = buildNodeTestArgs(files, { shard: opts.shard, shuffle: opts.shuffle, seed });
    const selectedCount = args.length - 1;
    if (opts.shuffle) {
      console.log(
        `node-tests: selected ${selectedCount}/${files.length} files shuffled with seed=${seed}`,
      );
    }
    if (opts.dryRun) {
      console.log(
        JSON.stringify({
          totalFiles: files.length,
          selectedFiles: selectedCount,
          shard: opts.shard,
          shuffle: opts.shuffle,
          seed,
          firstFiles: args.slice(1, 5),
        }),
      );
      process.exitCode = 0;
    } else {
      ensureNodeModules(root);
      const ran = spawnSync(process.execPath, args, { cwd: root, stdio: "inherit" });
      if (ran.error) throw ran.error;
      process.exitCode = ran.status ?? 1;
    }
  } catch (error) {
    console.error(`node-tests: ${error.message}`);
    process.exitCode = 2;
  }
}
