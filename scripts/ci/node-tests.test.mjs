import test from "node:test";
import assert from "node:assert/strict";
import {
  buildNodeTestArgs,
  resolveTestFiles,
  selectShardFiles,
  shuffleFiles,
} from "./node-tests.mjs";

test("selectShardFiles partitions files cleanly across shards with and without shuffle", () => {
  const input = ["a.test.js", "b.test.js", "c.test.js", "d.test.js", "e.test.js", "f.test.js"];
  const s1 = selectShardFiles(input, { shard: "1/2", shuffle: true, seed: 42 });
  const s2 = selectShardFiles(input, { shard: "2/2", shuffle: true, seed: 42 });
  assert.equal(s1.length + s2.length, input.length);
  assert.deepEqual([...s1, ...s2].sort(), input);

  const s1Alt = selectShardFiles(input, { shard: "1/2", shuffle: true, seed: 99 });
  assert.notDeepEqual(s1, s1Alt);

  const args = buildNodeTestArgs(input, { shard: "1/2" });
  assert.deepEqual(args, ["--test", "a.test.js", "c.test.js", "e.test.js"]);
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
