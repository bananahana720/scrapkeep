#!/usr/bin/env node

import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { isBot, testScripts } from "../lib/godot-test-runner.mjs";
import { shuffleFiles } from "./node-tests.mjs";
import { isMain } from "../lib/cli.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const DEFAULT_SKETCH = "sketches/core-loop";
const TIMINGS_FILE = path.join(root, "scripts", "sketch-fast.timings.json");
const FALLBACK_MS = 10_000;

function compareCodePoint(a, b) {
  return a < b ? -1 : a > b ? 1 : 0;
}

export function packDurationShards(items, shardCount) {
  if (!Number.isInteger(shardCount) || shardCount < 1) {
    throw new Error(`shardCount must be a positive integer; got ${shardCount}`);
  }
  const shards = Array.from({ length: shardCount }, (_, index) => ({
    index: index + 1,
    totalMs: 0,
    tests: [],
  }));
  const sorted = [...items].sort((a, b) => b.ms - a.ms || compareCodePoint(a.name, b.name));
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
    const rawMs = typeof entry === "number" ? entry : entry?.ms;
    const ms = Number.isFinite(rawMs) && rawMs >= 0 ? rawMs : FALLBACK_MS;
    items.push({ name, rel, ms });
  }
  return items;
}

function parseArgs(argv) {
  const opts = { shards: null, shard: null, shuffle: false, seed: null };
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
      const raw = argv[++i];
      if (raw.trim() === "" || !Number.isFinite(Number(raw))) {
        throw new Error(`--seed must be a finite number; got "${raw}"`);
      }
      opts.seed = Math.trunc(Number(raw)) >>> 0;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  return opts;
}

if (isMain(import.meta.url)) {
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
        const seed = opts.seed ?? (Date.now() & 0xffffffff) >>> 0;
        tests = shuffleFiles(tests, seed);
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
