import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, cpSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";

const scripts = path.dirname(fileURLToPath(import.meta.url));
const scratch = mkdtempSync(path.join(tmpdir(), "play-resolve-"));
const main = path.join(scratch, "main");
const stub = path.join(scratch, "godot-stub");
writeFileSync(stub, "#!/bin/sh\nexit 0\n");
chmodSync(stub, 0o755);

after(() => rmSync(scratch, { recursive: true, force: true }));

function sketches(tree, names) {
  for (const name of names) {
    mkdirSync(path.join(tree, "sketches", name), { recursive: true });
    writeFileSync(path.join(tree, "sketches", name, "project.godot"), "");
  }
}

function git(cwd, ...args) {
  const result = spawnSync(
    "git",
    ["-c", "user.name=t", "-c", "user.email=t@example.com", "-C", cwd, ...args],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
}

mkdirSync(main, { recursive: true });
git(main, "init", "-q", "-b", "trunk");
sketches(main, ["sandbox", "core-loop", "arena-bench"]);
cpSync(scripts, path.join(main, "scripts"), { recursive: true });
git(main, "add", "-A");
git(main, "commit", "-q", "-m", "fixture");
const v3 = path.join(scratch, "core-loop-v3");
const plan = path.join(scratch, "plan-abc");
git(main, "worktree", "add", "-q", "-b", "v3", v3);
git(main, "worktree", "add", "-q", "-b", "plan", plan);
const job = path.join(scratch, "job-0123abcd");
git(main, "worktree", "add", "-q", "-b", "job", job);
for (const tree of [v3, plan, job]) {
  sketches(tree, ["core-loop", "sandbox", "arena-bench"]);
}

function opened(cwd, name) {
  const result = spawnSync(process.execPath, [path.join(main, "scripts", "play.mjs"), name], {
    cwd,
    encoding: "utf8",
    env: { ...process.env, GODOT_BIN: stub },
  });
  const line = result.stdout.split("\n").find((one) => one.includes("▶"));
  return { result, line: line ?? "" };
}

test("core-loop from outside any worktree opens the main checkout's", () => {
  const { result, line } = opened(scratch, "core-loop");
  assert.equal(result.status, 0, result.stderr);
  assert.ok(line.includes(path.join(main, "sketches", "core-loop")), line);
});

test("core-loop typed inside a worktree opens that worktree's", () => {
  const { result, line } = opened(plan, "core-loop");
  assert.equal(result.status, 0, result.stderr);
  assert.ok(line.includes(path.join(plan, "sketches", "core-loop")), line);
});

test("a worktree's bare name opens its core-loop sketch", () => {
  const { result, line } = opened(scratch, "plan-abc");
  assert.equal(result.status, 0, result.stderr);
  assert.ok(line.includes(path.join(plan, "sketches", "core-loop")), line);
});

test("a worktree named like core-loop-v3 opens that worktree's core-loop", () => {
  const { result, line } = opened(scratch, "core-loop-v3");
  assert.equal(result.status, 0, result.stderr);
  assert.ok(line.includes(path.join(v3, "sketches", "core-loop")), line);
});

test("an exact tree/sketch id opens exactly that sketch", () => {
  const { result, line } = opened(scratch, "plan-abc/arena-bench");
  assert.equal(result.status, 0, result.stderr);
  assert.ok(line.includes(path.join(plan, "sketches", "arena-bench")), line);
});

test("a name that matches nothing fails with a list", () => {
  const { result } = opened(scratch, "no-such-sketch");
  assert.equal(result.status, 2);
  assert.match(result.stderr, /No sketch matches "no-such-sketch"/);
  assert.match(result.stderr, /plan-abc/);
});

test("<worktree>/core-loop opens that worktree's core-loop, as at the base", () => {
  const { result, line } = opened(scratch, "plan-abc/core-loop");
  assert.equal(result.status, 0, result.stderr);
  assert.ok(line.includes(path.join(plan, "sketches", "core-loop")), line);
});

test("<main checkout>/core-loop opens the main checkout's core-loop", () => {
  const { result, line } = opened(plan, "main/core-loop");
  assert.equal(result.status, 0, result.stderr);
  assert.ok(line.includes(path.join(main, "sketches", "core-loop")), line);
});

test("job-<hex>/core-loop opens that job's core-loop", () => {
  const { result, line } = opened(scratch, "job-0123abcd/core-loop");
  assert.equal(result.status, 0, result.stderr);
  assert.ok(line.includes(path.join(job, "sketches", "core-loop")), line);
});

test("an ambiguous name suggests the nearest copy first", () => {
  const inside = opened(plan, "arena");
  assert.equal(inside.result.status, 2);
  assert.match(inside.result.stderr, /Most likely: scrapkeep plan-abc\/arena-bench/);
  const outside = opened(scratch, "arena");
  assert.equal(outside.result.status, 2);
  assert.match(outside.result.stderr, /Most likely: scrapkeep main\/arena-bench/);
});
