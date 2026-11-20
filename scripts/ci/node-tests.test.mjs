import test from "node:test";
import assert from "node:assert/strict";
import { buildNodeTestArgs, resolveTestFiles } from "./node-tests.mjs";

test("buildNodeTestArgs places --test-shard before file arguments", () => {
  const args = buildNodeTestArgs(["a.test.js", "b.test.js"], { shard: "1/2" });
  assert.deepEqual(args, ["--test", "--test-shard=1/2", "a.test.js", "b.test.js"]);
});

test("buildNodeTestArgs rejects malformed or out-of-range shards", () => {
  assert.throws(() => buildNodeTestArgs(["a.test.js"], { shard: "bad" }), /INDEX\/TOTAL/);
  assert.throws(() => buildNodeTestArgs(["a.test.js"], { shard: "3/2" }), /out of range/);
  assert.throws(() => buildNodeTestArgs(["a.test.js"], { shard: "0/2" }), /out of range/);
});

test("resolveTestFiles expands package.json globs into sorted concrete paths", () => {
  const files = resolveTestFiles("node --test scripts/ci/*.test.mjs scripts/check-docs.mjs");
  assert.ok(files.includes("scripts/ci/affected.test.mjs"));
  assert.ok(files.includes("scripts/ci/check-budget.test.mjs"));
  assert.ok(files.includes("scripts/check-docs.mjs"));
});
