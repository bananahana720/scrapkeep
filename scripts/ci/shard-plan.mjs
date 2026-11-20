#!/usr/bin/env node
// Duration-balanced shard planner for Scrapkeep's headless Godot test suite.
// Uses Longest-Processing-Time-first (LPT) bin packing from scripts/sketch-fast.timings.json
// instead of alphabetical slicing, so every shard finishes at roughly the same wall clock.
// Usage:
//   node scripts/ci/shard-plan.mjs --shards 4 [--json]
//   node scripts/ci/shard-plan.mjs --shard 1/4 [--shuffle] [--seed 42]

import { readFileSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { isBot, testScripts } from "../sketch-smoke.mjs";
import { shuffleFiles } from "./node-tests.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const DEFAULT_SKETCH = "sketches/core-loop";
const TIMINGS_FILE = path.join(root, "scripts", "sketch-fast.timings.json");
const FALLBACK_MS = 10_000;

export function packDurationShards(items, shardCount) {
  if (!Number.isInteger(shardCount) || shardCount < 1) {
    throw new Error(`shardCount must be a positive integer; got ${shardCount}`);
  }
  const shards = Array.from({ length: shardCount }, (_, index) => ({
    index: index + 1,
    totalMs: 0,
    tests: [],
  }));
  // Sort longest measured duration first, deterministic tie-break by test name.
  const sorted = [...items].sort((a, b) => b.ms - a.ms || a.name.localeCompare(b.name));
  for (const item of sorted) {
    let lightest = shards[0];
    for (let i = 1; i < shards.length; i++) {
      if (shards[i].totalMs < lightest.totalMs) lightest = shards[i];
    }
    lightest.tests.push(item.name);
    lightest.totalMs += item.ms;
  }
  return shards;
}

export function shardStats(shards) {
  const totals = shards.map((s) => s.totalMs);
  const sum = totals.reduce((a, b) => a + b, 0);
  const max = totals.length > 0 ? Math.max(...totals) : 0;
  const min = totals.length > 0 ? Math.min(...totals) : 0;
  const avg = shards.length > 0 ? sum / shards.length : 0;
  return {
    shardCount: shards.length,
    totalTests: shards.reduce((a, s) => a + s.tests.length, 0),
    totalMs: sum,
    minMs: min,
    maxMs: max,
    avgMs: Math.round(avg),
    imbalanceRatio: avg > 0 ? Number((max / avg).toFixed(3)) : 1,
  };
}

export function loadNonBotTests(
  sketchDir = path.join(root, DEFAULT_SKETCH),
  timingsPath = TIMINGS_FILE,
) {
  const rawTimings = JSON.parse(readFileSync(timingsPath, "utf8"));
  const timings = rawTimings.tests ?? rawTimings;
  const items = [];
  for (const script of testScripts(sketchDir)) {
    const rel = script.replace(/^res:\/\//, "");
    const source = readFileSync(path.join(sketchDir, rel), "utf8");
    if (isBot(source)) continue;
    const name = path.posix.basename(rel, ".gd");
    const entry = timings[rel];
    const ms =
      typeof entry === "number"
        ? entry
        : entry && typeof entry.ms === "number"
          ? entry.ms
          : FALLBACK_MS;
    items.push({ name, rel, ms });
  }
  return items;
}

function parseArgs(argv) {
  const opts = { shards: null, shard: null, shuffle: false, seed: null, json: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--shards") {
      if (i + 1 >= argv.length) throw new Error("--shards requires a value");
      opts.shards = Number(argv[++i]);
    } else if (arg === "--shard") {
      if (i + 1 >= argv.length) throw new Error("--shard requires a value");
      opts.shard = argv[++i];
    } else if (arg === "--shuffle") {
      opts.shuffle = true;
    } else if (arg === "--seed") {
      if (i + 1 >= argv.length) throw new Error("--seed requires a value");
      const n = Number(argv[++i]);
      if (!Number.isFinite(n)) throw new Error("--seed must be a number");
      opts.seed = Math.trunc(n) >>> 0;
    } else if (arg === "--json") {
      opts.json = true;
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
    const items = loadNonBotTests();
    if (opts.shard) {
      if (!/^\d+\/\d+$/.test(opts.shard)) {
        throw new Error(`--shard must be INDEX/TOTAL (for example 1/4); got "${opts.shard}"`);
      }
      const [index, total] = opts.shard.split("/").map(Number);
      if (index < 1 || total < 1 || index > total) {
        throw new Error(`--shard ${opts.shard} out of range`);
      }
      const shards = packDurationShards(items, total);
      let tests = shards[index - 1].tests;
      if (opts.shuffle) {
        tests = shuffleFiles(tests, opts.seed ?? 1);
      }
      console.log(tests.join(","));
    } else {
      const count = opts.shards ?? 4;
      const shards = packDurationShards(items, count);
      const summary = {
        ...shardStats(shards),
        shards: shards.map((s) => ({
          index: s.index,
          tests: s.tests.length,
          estimatedSeconds: Math.round(s.totalMs / 1000),
        })),
      };
      console.log(JSON.stringify(summary, null, 2));
    }
  } catch (error) {
    console.error(`shard-plan: ${error.message}`);
    process.exitCode = 2;
  }
}
