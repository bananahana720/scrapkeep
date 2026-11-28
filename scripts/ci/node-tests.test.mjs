import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  buildNodeTestArgs,
  discoverTestFiles,
  estimateFileMs,
  EXCLUDED_TESTS,
  partitionDurationShards,
  selectShardFiles,
  shuffleFiles,
} from "./node-tests.mjs";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

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
  const allFiles = discoverTestFiles(repoRoot);
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
    "scripts/sketch-smoke.test.mjs",
    "scripts/alpha-rc.test.mjs",
    "scripts/ci/selection-mutation.test.mjs",
    "scripts/sketch-lint.test.mjs",
    "a.test.mjs",
    "b.test.mjs",
  ];
  assert.ok(estimateFileMs("scripts/sketch-smoke.test.mjs") > estimateFileMs("a.test.mjs"));
  const h1 = selectShardFiles(heavy, { shard: "1/2" });
  const h2 = selectShardFiles(heavy, { shard: "2/2" });
  assert.equal(h1.length + h2.length, heavy.length);
  assert.deepEqual([...h1, ...h2].sort(), [...heavy].sort());
  assert.notEqual(
    h1.includes("scripts/sketch-smoke.test.mjs"),
    h1.includes("scripts/alpha-rc.test.mjs"),
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

test("discoverTestFiles scans the three scopes, skips nested tests/ and excluded entries", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-node-tests-"));
  try {
    for (const rel of [
      "tests/alpha.test.js",
      "tests/helper.js",
      "tests/legacy/leads.test.js",
      "scripts/top.test.mjs",
      "scripts/nested/deep.test.mjs",
      "scripts/nested/skip-me.test.mjs",
      "scripts/nested/not-a-test.mjs",
      "project-guide/handoff/sitting-kit/serve.test.mjs",
      "project-guide/handoff/sitting-kit/sub/ignored.test.mjs",
    ]) {
      const full = path.join(tmp, rel);
      mkdirSync(path.dirname(full), { recursive: true });
      writeFileSync(full, "\n", "utf8");
    }
    const files = discoverTestFiles(tmp, {
      excluded: { "scripts/nested/skip-me.test.mjs": "fixture exclusion reason" },
    });
    assert.deepEqual(files, [
      "project-guide/handoff/sitting-kit/serve.test.mjs",
      "scripts/nested/deep.test.mjs",
      "scripts/top.test.mjs",
      "tests/alpha.test.js",
    ]);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test("every tracked *.test.mjs and tests/*.test.js is either discovered or listed in EXCLUDED_TESTS with a reason", () => {
  const tracked = spawnSync("git", ["ls-files", "--", "*.test.mjs", "tests/*.test.js"], {
    cwd: repoRoot,
    encoding: "utf8",
  });
  assert.equal(tracked.status, 0, tracked.stderr);
  const trackedScriptTests = tracked.stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((file) => file.endsWith(".test.mjs") || /^tests\/[^/]+\.test\.js$/.test(file))
    .sort();
  assert.ok(trackedScriptTests.length > 0);

  const discovered = discoverTestFiles(repoRoot);
  const discoveredSet = new Set(discovered);
  const excludedEntries = Object.entries(EXCLUDED_TESTS);
  const excludedSet = new Set(Object.keys(EXCLUDED_TESTS));
  const trackedSet = new Set(trackedScriptTests);

  for (const [file, reason] of excludedEntries) {
    assert.equal(typeof reason, "string", `${file} exclusion reason must be a string`);
    assert.ok(reason.trim().length > 0, `${file} exclusion reason must be non-empty`);
    assert.ok(trackedSet.has(file), `${file} in EXCLUDED_TESTS is not a tracked test`);
    assert.ok(!discoveredSet.has(file), `${file} in EXCLUDED_TESTS must not also be discovered`);
  }

  const unaccounted = trackedScriptTests.filter(
    (file) => !discoveredSet.has(file) && !excludedSet.has(file),
  );
  assert.deepEqual(unaccounted, []);

  assert.ok(discoveredSet.has("tests/game.test.js"));
  assert.ok(discoveredSet.has("scripts/ci/node-tests.test.mjs"));
  assert.ok(discoveredSet.has("scripts/godot-home.test.mjs"));
  assert.ok(discoveredSet.has("project-guide/handoff/sitting-kit/serve.test.mjs"));
  assert.ok(!discoveredSet.has("tests/legacy/leads.test.js"));

  const pkg = JSON.parse(readFileSync(path.join(repoRoot, "package.json"), "utf8"));
  assert.equal(pkg.scripts?.test, "node scripts/ci/node-tests.mjs");
});
