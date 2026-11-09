import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

import { validateVerdicts } from "../scripts/lab/verdicts.mjs";
import { shallowClone } from "./preconditions.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const REAL_FILE = path.join(root, "docs/playtests/verdicts.ndjson");
const REAL_LOG = path.join(root, "docs/playtests/PLAYTEST-LOG.md");
const CLI = path.join(root, "scripts/lab/verdicts.mjs");

const ENTRY_1 = {
  build_sha: "aef51fe22fdeae634e6eb5330ad3ec0a9a3eb6cb",
  anchor: "docs/playtests/PLAYTEST-LOG.md#1-orchard-increment-01-first-human-play",
  quote:
    '"the implementation was off and not very good, wasnt very inspiring. it was a static room like level - looking for more of a exploring, more open world to play a rougelite in"',
};

// The whole quoted span of line 43's Verdict bullet, first opening quote
// through the final closing quote before the trailing period, including
// the "Also:" joiner and the inner quote marks — the coordinator's
// resolution of JL-07-A1's escalation.
const ENTRY_2 = {
  build_sha: "dc94b2c42b58b1a48944573d22f44a0e0413f196",
  anchor: "docs/playtests/PLAYTEST-LOG.md#2-ball-lab-first-human-play",
  quote:
    '"DUDE this feels so amazing and fun in the movement and traversal. wow im really happy with this - its already so fun to move and explore around. I would want augments or abilities that can class or item or whatever driven to make it even more fun like a grapple hook or maneuverability in the air or other things. well done." Also: "rigid body felt best, and I didn\'t do any fine tuning, I was already lost in the game having a blast"',
};

// A real commit that neither entry's section names (in backticks), for the
// "sha not credited to this entry" case.
const UNNAMED_COMMIT = "e9b977a99bb3f10d65275e06a333c01e50d3bf97";

// A working copy of the real log, so a case can point validateVerdicts at a
// temp file without ever touching the real PLAYTEST-LOG.md.
async function fixtureLog(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-verdicts-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const log = path.join(temporary, "PLAYTEST-LOG.md");
  await writeFile(log, await readFile(REAL_LOG, "utf8"));
  return { temporary, log };
}

async function fixtureFile(temporary, record) {
  const file = path.join(temporary, "verdicts.ndjson");
  const line = typeof record === "string" ? record : JSON.stringify(record);
  await writeFile(file, `${line}\n`);
  return file;
}

test("the real verdicts file validates against the real log", { skip: shallowClone }, async () => {
  const { ok, problems } = validateVerdicts({ file: REAL_FILE, log: REAL_LOG, git: root });
  assert.deepEqual(problems, []);
  assert.equal(ok, true);
});

// Counts PLAYTEST-LOG's numbered "## N." entry headings and checks the real
// verdicts file carries exactly one line per number, so a future entry
// cannot be silently skipped the way JL-07-A1 nearly skipped entry 2.
test("the real file has exactly one line per PLAYTEST-LOG entry", async () => {
  const logText = await readFile(REAL_LOG, "utf8");
  const headingEntries = [...logText.matchAll(/^##\s+(\d+)\./gm)]
    .map((match) => Number(match[1]))
    .sort((a, b) => a - b);

  const ndjsonText = await readFile(REAL_FILE, "utf8");
  const lines = ndjsonText.split(/\r?\n/).filter((line) => line.trim().length > 0);
  const fileEntries = lines.map((line) => JSON.parse(line).entry).sort((a, b) => a - b);

  assert.ok(headingEntries.length > 0, "expected at least one numbered entry heading in the log");
  assert.deepEqual(fileEntries, headingEntries);
});

test("a tampered quote fails validation", async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const file = await fixtureFile(temporary, {
    entry: 1,
    ...ENTRY_1,
    quote: '"the implementation was actually pretty great, loved every minute"',
    tags: [],
  });
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.equal(ok, false);
  assert.ok(problems.some((problem) => problem.includes("verbatim")));
});

test("entry 1's quote placed on entry 2's line fails validation", async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const file = await fixtureFile(temporary, {
    entry: 2,
    ...ENTRY_2,
    quote: ENTRY_1.quote,
    tags: [],
  });
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.equal(ok, false);
  assert.ok(
    problems.some((problem) => problem.includes("verbatim") && problem.includes("entry 2")),
    problems.join("\n"),
  );
});

test("a fake commit sha fails validation", async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const file = await fixtureFile(temporary, {
    entry: 1,
    ...ENTRY_1,
    build_sha: "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
    tags: [],
  });
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.equal(ok, false);
  assert.ok(problems.some((problem) => problem.includes("not a commit")));
});

test("a real commit the entry does not name fails validation", { skip: shallowClone }, async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const file = await fixtureFile(temporary, {
    entry: 1,
    ...ENTRY_1,
    build_sha: UNNAMED_COMMIT,
    tags: [],
  });
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.equal(ok, false);
  assert.ok(
    problems.some((problem) => problem.includes("not named") && problem.includes("entry 1")),
    problems.join("\n"),
  );
});

test("a bad anchor fails validation", async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const file = await fixtureFile(temporary, {
    entry: 1,
    ...ENTRY_1,
    anchor: "docs/playtests/PLAYTEST-LOG.md#no-such-heading-here",
    tags: [],
  });
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.equal(ok, false);
  assert.ok(problems.some((problem) => problem.includes("does not equal")));
});

// A real heading slug, just not the entry's own — the "Waiting for play"
// section exists in the log, but it is not entry 1's heading.
test("a valid slug from another section fails validation", async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const file = await fixtureFile(temporary, {
    entry: 1,
    ...ENTRY_1,
    anchor: "docs/playtests/PLAYTEST-LOG.md#waiting-for-play",
    tags: [],
  });
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.equal(ok, false);
  assert.ok(problems.some((problem) => problem.includes("does not equal")));
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
  const file = await fixtureFile(temporary, {
    entry: 1,
    ...ENTRY_1,
    tags: "none",
  });
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.equal(ok, false);
  assert.ok(problems.some((problem) => problem.includes('"tags"')));
});

test("a valid line for entry 2's heading and build resolves independently of entry 1", { skip: shallowClone }, async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const file = await fixtureFile(temporary, { entry: 2, ...ENTRY_2, tags: [] });
  const { ok, problems } = validateVerdicts({ file, log, git: root });
  assert.deepEqual(problems, []);
  assert.equal(ok, true);
});

test("the CLI exits 0 for the real file", { skip: shallowClone }, async () => {
  const real = spawnSync(process.execPath, [CLI], { cwd: root, encoding: "utf8" });
  assert.equal(real.status, 0);
  assert.equal(real.stderr, "");
});

test("the CLI exits 0 for a valid --file/--log pair pointing at temp copies", { skip: shallowClone }, async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const file = await fixtureFile(temporary, { entry: 1, ...ENTRY_1, tags: [] });
  const result = spawnSync(process.execPath, [CLI, "--file", file, "--log", log], {
    cwd: root,
    encoding: "utf8",
  });
  assert.equal(result.status, 0);
});

test("the CLI exits 1 and prints a problem for an invalid file", async (t) => {
  const { temporary, log } = await fixtureLog(t);
  const file = await fixtureFile(temporary, {
    entry: 1,
    ...ENTRY_1,
    quote: "not the real quote at all",
    tags: [],
  });
  const invalid = spawnSync(process.execPath, [CLI, "--file", file, "--log", log], {
    cwd: root,
    encoding: "utf8",
  });
  assert.equal(invalid.status, 1);
  assert.match(invalid.stderr, /verbatim/);
});
