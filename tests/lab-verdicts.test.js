import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

import { validateVerdicts } from "../scripts/lab/verdicts.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const REAL_FILE = path.join(root, "docs/playtests/verdicts.ndjson");
const REAL_LOG = path.join(root, "docs/playtests/PLAYTEST-LOG.md");

// A working copy of the real log, so a case can point validateVerdicts at a
// temp file without ever touching the real PLAYTEST-LOG.md.
async function fixtureLog(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-verdicts-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const log = path.join(temporary, "PLAYTEST-LOG.md");
  await writeFile(log, await readFile(REAL_LOG, "utf8"));
  return { temporary, log };
}

async function fixtureFile(temporary, line) {
  const file = path.join(temporary, "verdicts.ndjson");
  await writeFile(file, `${line}\n`);
  return file;
}

test("the real verdicts file validates against the real log", async () => {
  const { ok, problems } = validateVerdicts({ file: REAL_FILE, log: REAL_LOG, git: root });
  assert.deepEqual(problems, []);
  assert.equal(ok, true);
});

test("a tampered quote fails validation", async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const tampered = JSON.stringify({
    entry: 1,
    build_sha: "aef51fe22fdeae634e6eb5330ad3ec0a9a3eb6cb",
    anchor: "docs/playtests/PLAYTEST-LOG.md#1-orchard-increment-01-first-human-play",
    quote: "the implementation was actually pretty great, loved every minute",
    tags: [],
  });
  const file = await fixtureFile(temporary, tampered);
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.equal(ok, false);
  assert.ok(problems.some((problem) => problem.includes("verbatim")));
});

test("a fake commit sha fails validation", async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const fake = JSON.stringify({
    entry: 1,
    build_sha: "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
    anchor: "docs/playtests/PLAYTEST-LOG.md#1-orchard-increment-01-first-human-play",
    quote:
      "the implementation was off and not very good, wasnt very inspiring. it was a static room like level - looking for more of a exploring, more open world to play a rougelite in",
    tags: [],
  });
  const file = await fixtureFile(temporary, fake);
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.equal(ok, false);
  assert.ok(problems.some((problem) => problem.includes("not a commit")));
});

test("a bad anchor fails validation", async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const badAnchor = JSON.stringify({
    entry: 1,
    build_sha: "aef51fe22fdeae634e6eb5330ad3ec0a9a3eb6cb",
    anchor: "docs/playtests/PLAYTEST-LOG.md#no-such-heading-here",
    quote:
      "the implementation was off and not very good, wasnt very inspiring. it was a static room like level - looking for more of a exploring, more open world to play a rougelite in",
    tags: [],
  });
  const file = await fixtureFile(temporary, badAnchor);
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.equal(ok, false);
  assert.ok(problems.some((problem) => problem.includes("does not resolve")));
});

test("a malformed line fails validation", async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const file = await fixtureFile(temporary, "{not json");
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.equal(ok, false);
  assert.ok(problems.some((problem) => problem.includes("not valid JSON")));
});

test("tags must be an array", async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const badTags = JSON.stringify({
    entry: 1,
    build_sha: "aef51fe22fdeae634e6eb5330ad3ec0a9a3eb6cb",
    anchor: "docs/playtests/PLAYTEST-LOG.md#1-orchard-increment-01-first-human-play",
    quote:
      "the implementation was off and not very good, wasnt very inspiring. it was a static room like level - looking for more of a exploring, more open world to play a rougelite in",
    tags: "none",
  });
  const file = await fixtureFile(temporary, badTags);
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.equal(ok, false);
  assert.ok(problems.some((problem) => problem.includes('"tags"')));
});

test("a valid line for entry 2's heading and build resolves independently of entry 1", async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const line = JSON.stringify({
    entry: 2,
    build_sha: "dc94b2c42b58b1a48944573d22f44a0e0413f196",
    anchor: "docs/playtests/PLAYTEST-LOG.md#2-ball-lab-first-human-play",
    quote:
      "rigid body felt best, and I didn't do any fine tuning, I was already lost in the game having a blast",
    tags: [],
  });
  const file = await fixtureFile(temporary, line);
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.deepEqual(problems, []);
  assert.equal(ok, true);
});

test("the CLI exits 0 for the real file", async () => {
  const { spawnSync } = await import("node:child_process");
  const real = spawnSync(process.execPath, [path.join(root, "scripts/lab/verdicts.mjs")], {
    cwd: root,
    encoding: "utf8",
  });
  assert.equal(real.status, 0);
  assert.equal(real.stderr, "");
});

test("the CLI exits 1 and prints a problem for an invalid file", async (t) => {
  // The CLI has no arguments, so this swaps the real deliverable's bytes for
  // an invalid line, runs the CLI, then restores the original bytes no
  // matter how the test ends.
  const original = await readFile(REAL_FILE, "utf8");
  t.after(async () => {
    await writeFile(REAL_FILE, original);
  });
  await writeFile(
    REAL_FILE,
    `${JSON.stringify({
      entry: 1,
      build_sha: "aef51fe22fdeae634e6eb5330ad3ec0a9a3eb6cb",
      anchor: "docs/playtests/PLAYTEST-LOG.md#1-orchard-increment-01-first-human-play",
      quote: "not the real quote at all",
      tags: [],
    })}\n`,
  );
  const { spawnSync } = await import("node:child_process");
  const invalid = spawnSync(process.execPath, [path.join(root, "scripts/lab/verdicts.mjs")], {
    cwd: root,
    encoding: "utf8",
  });
  assert.equal(invalid.status, 1);
  assert.match(invalid.stderr, /verbatim/);
});
