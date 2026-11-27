#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { readdirSync, readFileSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ensureNodeModules } from "../ensure-node-modules.mjs";

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
  "scripts/gate/sound-receipts.test.mjs": 15_000,
  "sound-receipts.test.mjs": 15_000,
  "tests/sprint-close.test.js": 10_400,
  "sprint-close.test.js": 10_400,
  "scripts/alpha-rc.test.mjs": 8_300,
  "alpha-rc.test.mjs": 8_300,
  "scripts/sketch-smoke.test.mjs": 5_700,
  "sketch-smoke.test.mjs": 5_700,
  "tests/check-skills.test.js": 4_300,
  "check-skills.test.js": 4_300,
  "scripts/audio-gate.test.mjs": 3_500,
  "audio-gate.test.mjs": 3_500,
  "tests/check-scope.test.js": 3_100,
  "check-scope.test.js": 3_100,
  "tests/asset-inspect.test.js": 3_000,
  "asset-inspect.test.js": 3_000,
  "scripts/ci/selection-mutation.test.mjs": 2_100,
  "selection-mutation.test.mjs": 2_100,
  "scripts/sketch-lint.test.mjs": 2_000,
  "sketch-lint.test.mjs": 2_000,
  "tests/antigravity-hooks.test.js": 1_900,
  "antigravity-hooks.test.js": 1_900,
  "scripts/play.resolve.test.mjs": 1_700,
  "play.resolve.test.mjs": 1_700,
  "tests/check-docs.test.js": 1_700,
  "check-docs.test.js": 1_700,
  "scripts/gate/look-receipts.test.mjs": 1_500,
  "look-receipts.test.mjs": 1_500,
  "scripts/brief-check.test.mjs": 1_400,
  "brief-check.test.mjs": 1_400,
  "scripts/gate/pc.test.mjs": 1_400,
  "pc.test.mjs": 1_400,
  "scripts/wave-state.test.mjs": 1_300,
  "wave-state.test.mjs": 1_300,
  "tests/check-agents.test.js": 1_300,
  "check-agents.test.js": 1_300,
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
    const pkg = JSON.parse(readFileSync(path.join(root, "package.json"), "utf8"));
    const files = resolveTestFiles(pkg.scripts?.test ?? "", root);
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
