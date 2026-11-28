#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ensureNodeModules } from "../ensure-node-modules.mjs";
import { isMain } from "../lib/cli.mjs";
import { git } from "../lib/git.mjs";

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
    "audits every model in sketches/core-loop/assets/registry.json, which the node-tests partial checkout leaves out of sketches/core-loop/assets/models/; scripts/sketch-fast.mjs runs it on a full checkout through NODE_PATH_RULES",
  "scripts/far-faults.test.mjs":
    "scans the park prop models under sketches/core-loop/assets/models/park/props/, which the node-tests partial checkout leaves out; scripts/sketch-fast.mjs runs it on a full checkout through NODE_PATH_RULES",
});

function scopeFiles(scope, files) {
  const prefix = `${scope.dir}/`;
  return files.filter(
    (file) =>
      file.startsWith(prefix) &&
      file.endsWith(scope.suffix) &&
      (scope.recursive || !file.slice(prefix.length).includes("/")),
  );
}

export function discoverTestFiles(
  baseDir = root,
  { scopes = TEST_SCOPES, excluded = EXCLUDED_TESTS, log = console.error } = {},
) {
  const list = (...args) =>
    git(["ls-files", "-z", ...args, "--", ...scopes.map((scope) => scope.dir)], {
      cwd: baseDir,
      trim: false,
    })
      .split("\0")
      .filter(Boolean);
  const tracked = list();
  if (tracked.length === 0) throw new Error(`git ls-files lists no tracked files in ${baseDir}`);
  const untracked = new Set(list("--others", "--exclude-standard"));
  const excludedSet = new Set(Object.keys(excluded));
  const found = [
    ...new Set(scopes.flatMap((scope) => scopeFiles(scope, [...tracked, ...untracked]))),
  ]
    .filter((file) => !excludedSet.has(file))
    .sort();
  for (const file of found) if (untracked.has(file)) log(`node-tests: running untracked ${file}`);
  return found;
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

export const DEFAULT_FILE_MS = 500;
export const DURATION_HINTS_MS = {
  "scripts/sketch-smoke.test.mjs": 5_700,
  "sketch-smoke.test.mjs": 5_700,
  "scripts/alpha-rc.test.mjs": 4_100,
  "alpha-rc.test.mjs": 4_100,
  "scripts/ci/selection-mutation.test.mjs": 2_100,
  "selection-mutation.test.mjs": 2_100,
  "scripts/sketch-lint.test.mjs": 2_000,
  "sketch-lint.test.mjs": 2_000,
  "scripts/gate/sound-receipts.test.mjs": 1_900,
  "sound-receipts.test.mjs": 1_900,
  "tests/check-docs.test.js": 1_700,
  "check-docs.test.js": 1_700,
  "tests/sprint-close.test.js": 1_500,
  "sprint-close.test.js": 1_500,
  "scripts/brief-check.test.mjs": 1_400,
  "brief-check.test.mjs": 1_400,
  "scripts/gate/look-receipts.test.mjs": 1_400,
  "look-receipts.test.mjs": 1_400,
  "scripts/gate/pc.test.mjs": 1_400,
  "pc.test.mjs": 1_400,
  "scripts/wave-state.test.mjs": 1_300,
  "wave-state.test.mjs": 1_300,
  "tests/check-agents.test.js": 1_300,
  "check-agents.test.js": 1_300,
  "scripts/play.resolve.test.mjs": 1_100,
  "play.resolve.test.mjs": 1_100,
  "tests/check-skills.test.js": 900,
  "check-skills.test.js": 900,
  "tests/check-scope.test.js": 700,
  "check-scope.test.js": 700,
  "tests/asset-inspect.test.js": 600,
  "asset-inspect.test.js": 600,
  "tests/antigravity-hooks.test.js": 600,
  "antigravity-hooks.test.js": 600,
};

export function estimateFileMs(file, hints = DURATION_HINTS_MS) {
  return hints[file] ?? hints[path.posix.basename(file)] ?? DEFAULT_FILE_MS;
}

export function partitionDurationShards(files, total, hints = DURATION_HINTS_MS) {
  const shards = Array.from({ length: total }, () => ({ totalMs: 0, files: [] }));
  const ranked = files
    .map((file, order) => ({ file, order, ms: estimateFileMs(file, hints) }))
    .sort((a, b) => b.ms - a.ms || a.order - b.order);
  for (const item of ranked) {
    let lightest = shards[0];
    for (let i = 1; i < shards.length; i++) {
      if (shards[i].totalMs < lightest.totalMs) lightest = shards[i];
    }
    lightest.files.push(item.file);
    lightest.totalMs += item.ms;
  }
  return shards;
}

export function selectShardFiles(
  files,
  { shard = null, shuffle = false, seed = null, hints = DURATION_HINTS_MS } = {},
) {
  if (shard && shuffle && seed === null) {
    throw new Error(
      "--shard with --shuffle requires an explicit --seed so all shards partition identically",
    );
  }
  if (!shard) {
    return shuffle ? shuffleFiles(files, seed ?? 1) : [...files];
  }
  const { index, total } = parseShardSpec(shard);
  const shardFiles = partitionDurationShards(files, total, hints)[index - 1].files;
  if (!shuffle) return shardFiles;
  const shardSeed = ((seed ?? 1) ^ Math.imul(index, 0x9e3779b1)) >>> 0;
  return shuffleFiles(shardFiles, shardSeed);
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
    } else if (arg.startsWith("--test-name-pattern")) {
      throw new Error(
        `${arg} is not passed on; run the files it names with node --test --test-name-pattern=<pattern> <file>...`,
      );
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  return opts;
}

if (isMain(import.meta.url)) {
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
