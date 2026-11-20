import test from "node:test";
import assert from "node:assert/strict";
import { buildNodeTestArgs, resolveTestFiles, shuffleFiles } from "./node-tests.mjs";

test("buildNodeTestArgs places --test-shard before file arguments", () => {
  const args = buildNodeTestArgs(["a.test.js", "b.test.js"], { shard: "1/2" });
  assert.deepEqual(args, ["--test", "--test-shard=1/2", "a.test.js", "b.test.js"]);
});

test("buildNodeTestArgs rejects malformed or out-of-range shards", () => {
  assert.throws(() => buildNodeTestArgs(["a.test.js"], { shard: "bad" }), /INDEX\/TOTAL/);
  assert.throws(() => buildNodeTestArgs(["a.test.js"], { shard: "3/2" }), /out of range/);
  assert.throws(() => buildNodeTestArgs(["a.test.js"], { shard: "0/2" }), /out of range/);
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
