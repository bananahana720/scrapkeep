import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  buildNodeTestArgs,
  estimateFileMs,
  partitionDurationShards,
  resolveTestFiles,
  selectShardFiles,
  shuffleFiles,
} from "./node-tests.mjs";

test("selectShardFiles partitions files cleanly across shards with and without shuffle", () => {
  const input = [
    "a.test.js",
    "b.test.js",
    "c.test.js",
    "d.test.js",
    "e.test.js",
    "f.test.js",
    "g.test.js",
    "h.test.js",
  ];
  const s1 = selectShardFiles(input, { shard: "1/2", shuffle: true, seed: 42 });
  const s2 = selectShardFiles(input, { shard: "2/2", shuffle: true, seed: 42 });
  assert.equal(s1.length + s2.length, input.length);
  assert.equal(new Set([...s1, ...s2]).size, input.length);
  assert.deepEqual([...s1, ...s2].sort(), input);

  const s1Again = selectShardFiles(input, { shard: "1/2", shuffle: true, seed: 42 });
  assert.deepEqual(s1, s1Again);

  const s1Alt = selectShardFiles(input, { shard: "1/2", shuffle: true, seed: 99 });
  assert.notDeepEqual(s1, s1Alt);
  assert.deepEqual([...s1Alt].sort(), [...s1].sort());

  const args = buildNodeTestArgs(input.slice(0, 6), { shard: "1/2" });
  assert.deepEqual(args, ["--test", "a.test.js", "c.test.js", "e.test.js"]);
});

test("selectShardFiles balances known-heavy tests via LPT and preserves disjoint full union", () => {
  const pkg = JSON.parse(readFileSync(new URL("../../package.json", import.meta.url), "utf8"));
  const allFiles = resolveTestFiles(pkg.scripts.test);
  const s1 = selectShardFiles(allFiles, { shard: "1/2", shuffle: true, seed: 12345 });
  const s2 = selectShardFiles(allFiles, { shard: "2/2", shuffle: true, seed: 12345 });

  assert.equal(s1.length + s2.length, allFiles.length);
  const set1 = new Set(s1);
  for (const f of s2) assert.ok(!set1.has(f), `duplicate file across shards: ${f}`);
  assert.deepEqual([...s1, ...s2].sort(), [...allFiles].sort());

  const shards = partitionDurationShards(allFiles, 2);
  const ratio =
    Math.max(shards[0].totalMs, shards[1].totalMs) / Math.min(shards[0].totalMs, shards[1].totalMs);
  assert.ok(
    ratio <= 1.05,
    `expected balanced shard estimate ratio <= 1.05, got ${ratio.toFixed(3)}`,
  );

  // Synthetic heavy-pair check: top two heavy tests must land on different shards.
  const heavy = [
    "scripts/gate/sound-receipts.test.mjs",
    "scripts/audio-gate.test.mjs",
    "scripts/ci/selection-mutation.test.mjs",
    "scripts/sketch-lint.test.mjs",
    "a.test.mjs",
    "b.test.mjs",
  ];
  assert.ok(estimateFileMs("scripts/gate/sound-receipts.test.mjs") > estimateFileMs("a.test.mjs"));
  const h1 = selectShardFiles(heavy, { shard: "1/2" });
  const h2 = selectShardFiles(heavy, { shard: "2/2" });
  assert.equal(h1.length + h2.length, heavy.length);
  assert.deepEqual([...h1, ...h2].sort(), [...heavy].sort());
  assert.notEqual(
    h1.includes("scripts/gate/sound-receipts.test.mjs"),
    h1.includes("scripts/audio-gate.test.mjs"),
    "top two heavy files should split across shards",
  );
});

test("buildNodeTestArgs rejects malformed shards and unseeded shuffled shards", () => {
  assert.throws(() => buildNodeTestArgs(["a.test.js"], { shard: "bad" }), /INDEX\/TOTAL/);
  assert.throws(() => buildNodeTestArgs(["a.test.js"], { shard: "3/2" }), /out of range/);
  assert.throws(() => buildNodeTestArgs(["a.test.js"], { shard: "0/2" }), /out of range/);
  assert.throws(
    () => buildNodeTestArgs(["a.test.js"], { shard: "1/2", shuffle: true, seed: null }),
    /requires an explicit --seed/,
  );
});

test("shuffleFiles is deterministic per seed and preserves exact file set", () => {
  const input = ["a.js", "b.js", "c.js", "d.js", "e.js", "f.js"];
  const s1 = shuffleFiles(input, 42);
  const s2 = shuffleFiles(input, 42);
  const s3 = shuffleFiles(input, 99);
  assert.deepEqual(s1, s2);
  assert.notDeepEqual(s1, s3);
  assert.deepEqual([...s1].sort(), input);
});

test("resolveTestFiles expands package.json globs into sorted concrete paths", () => {
  const files = resolveTestFiles("node --test scripts/ci/*.test.mjs scripts/check-docs.mjs");
  assert.ok(files.includes("scripts/ci/affected.test.mjs"));
  assert.ok(files.includes("scripts/ci/check-budget.test.mjs"));
  assert.ok(files.includes("scripts/check-docs.mjs"));
});
