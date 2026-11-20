import test from "node:test";
import assert from "node:assert/strict";
import { loadNonBotTests, packDurationShards, shardStats } from "./shard-plan.mjs";

test("packDurationShards balances skewed durations far better than alphabetical slicing", () => {
  const skewed = [
    { name: "a_heavy_1", ms: 90_000 },
    { name: "a_heavy_2", ms: 85_000 },
    { name: "a_heavy_3", ms: 80_000 },
    { name: "b_light_1", ms: 5_000 },
    { name: "b_light_2", ms: 5_000 },
    { name: "b_light_3", ms: 5_000 },
  ];
  const shards = packDurationShards(skewed, 3);
  const stats = shardStats(shards);
  assert.equal(stats.totalTests, 6);
  assert.ok(stats.imbalanceRatio <= 1.1, `expected balanced shards, got ${stats.imbalanceRatio}`);
  const all = shards.flatMap((s) => s.tests).sort();
  assert.deepEqual(all, skewed.map((x) => x.name).sort());
});

test("packDurationShards partitions real Scrapkeep non-bot Godot tests with near-1.0 balance", () => {
  const items = loadNonBotTests();
  assert.ok(items.length > 500, `expected >500 non-bot tests, got ${items.length}`);
  const shards = packDurationShards(items, 4);
  const stats = shardStats(shards);
  assert.equal(stats.totalTests, items.length);
  assert.ok(
    stats.imbalanceRatio <= 1.05,
    `expected <= 1.05 imbalance across 4 shards, got ${stats.imbalanceRatio}`,
  );
});
