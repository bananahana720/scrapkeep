import test from "node:test";
import assert from "node:assert/strict";
import { cp, mkdir, mkdtemp, readFile, rm, symlink } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const fixtures = path.join(root, "tests/fixtures/check-skills");
const skillNames = ["reactive-model-loop", "scrapkeep-lab"];

// `.claude/skills/<name>` symlinks are never committed to the fixture tree
// (fs.cp can rewrite a relative symlink's target when it copies one), so the
// harness creates them itself, in the copied destination, after the overlay
// is applied. `broken` names a skill whose link should dangle instead.
async function linkSkills(repoRoot, { broken = null } = {}) {
  const linkDir = path.join(repoRoot, ".claude/skills");
  await mkdir(linkDir, { recursive: true });
  for (const name of skillNames) {
    const target =
      name === broken
        ? path.join("..", "..", ".agents/skills", "does-not-exist")
        : path.join("..", "..", ".agents/skills", name);
    await symlink(target, path.join(linkDir, name));
  }
}

async function runFixture(name, { broken = null } = {}) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-skills-"));
  try {
    const repoRoot = path.join(temporary, "repo");
    await mkdir(repoRoot);
    await cp(path.join(fixtures, "base"), repoRoot, { recursive: true });
    if (name !== "base")
      await cp(path.join(fixtures, name), repoRoot, { recursive: true });
    await linkSkills(repoRoot, { broken });
    const child = spawnSync(
      process.execPath,
      [path.join(root, "scripts/check-skills.mjs"), "--root", repoRoot, "--json"],
      { encoding: "utf8", timeout: 10000 },
    );
    assert.equal(child.error, undefined);
    assert.notEqual(child.status, 2, child.stderr);
    let findings;
    try {
      findings = JSON.parse(child.stdout);
    } catch {
      throw new Error(
        "check-skills.mjs --json did not print a JSON array:\n" +
          child.stdout +
          "\n" +
          child.stderr,
      );
    }
    return { status: child.status, stdout: child.stdout, stderr: child.stderr, findings };
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}

function failures(findings, check) {
  return findings.filter(
    (finding) => finding.level === "failure" && (check === undefined || finding.check === check),
  );
}

test("a clean fixture passes with exit 0 and no failures", async () => {
  const { status, findings, stdout } = await runFixture("base");
  assert.equal(status, 0, stdout);
  assert.equal(failures(findings).length, 0, JSON.stringify(findings, null, 2));
});

test("the clean fixture also prints one line per finding and a count in the default mode", async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-skills-"));
  try {
    const repoRoot = path.join(temporary, "repo");
    await mkdir(repoRoot);
    await cp(path.join(fixtures, "base"), repoRoot, { recursive: true });
    await linkSkills(repoRoot);
    const child = spawnSync(
      process.execPath,
      [path.join(root, "scripts/check-skills.mjs"), "--root", repoRoot],
      { encoding: "utf8", timeout: 10000 },
    );
    assert.equal(child.status, 0, child.stdout + child.stderr);
    assert.match(child.stdout, /check:skills pass:/);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test("a dead backtick path fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("dead-path");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "paths");
  assert.ok(hits.length > 0, JSON.stringify(findings, null, 2));
  assert.ok(hits.some((f) => f.message.includes("scripts/does-not-exist.mjs")));
});

test("a dead npm script fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("dead-npm-script");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "npm");
  assert.ok(hits.length > 0, JSON.stringify(findings, null, 2));
  assert.ok(hits.some((f) => f.message.includes("does-not-exist")));
});

test("a dead EV id fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("dead-ev-id");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "ids");
  assert.ok(hits.length > 0, JSON.stringify(findings, null, 2));
  assert.ok(hits.some((f) => f.message.includes("EV-9999")));
});

test("a dead BACKLOG card anchor fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("dead-card-anchor");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "ids");
  assert.ok(hits.length > 0, JSON.stringify(findings, null, 2));
  assert.ok(hits.some((f) => f.message.includes("JL-99")));
});

test("a broken .claude/skills link fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("base", { broken: "scrapkeep-lab" });
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "link");
  assert.ok(hits.length > 0, JSON.stringify(findings, null, 2));
  assert.ok(hits.some((f) => f.file.includes("scrapkeep-lab")));
});

test("a forbidden token in the portable skill fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("forbidden-token");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "portability");
  assert.ok(hits.length > 0, JSON.stringify(findings, null, 2));
  assert.ok(hits.some((f) => f.message.includes("Godot")));
  assert.ok(hits.every((f) => f.file.includes("reactive-model-loop")));
});

test("a duplicate lesson id fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("duplicate-lesson");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "lessons");
  assert.ok(hits.length > 0, JSON.stringify(findings, null, 2));
  assert.ok(hits.some((f) => f.message.includes("duplicate") && f.message.includes("RML-01")));
});

test("a retracted lesson without Overturned by fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("retracted-without-overturned");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "lessons");
  assert.ok(hits.length > 0, JSON.stringify(findings, null, 2));
  assert.ok(
    hits.some((f) => f.message.includes("Overturned by") && f.message.includes("RML-01")),
  );
});

test("an RML id missing from the origin map fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("rml-missing-from-map");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "lessons");
  assert.ok(hits.length > 0, JSON.stringify(findings, null, 2));
  assert.ok(hits.some((f) => f.message.includes("RML-02") && f.message.includes("origin map")));
});

test("a SKILL.md body over 250 lines fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("body-over-250");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "size");
  assert.ok(hits.length > 0, JSON.stringify(findings, null, 2));
});

test("a placeholder, glob, quoted-schema, URL and :line-suffixed token are not flagged", async () => {
  const { status, findings, stdout } = await runFixture("not-flagged");
  assert.equal(status, 0, stdout);
  const hits = failures(findings, "paths");
  assert.equal(hits.length, 0, JSON.stringify(findings, null, 2));
});

test("--json prints a findings array and the default mode does not", async () => {
  const { findings } = await runFixture("dead-path");
  assert.ok(Array.isArray(findings));
  for (const finding of findings) {
    assert.ok("check" in finding);
    assert.ok("level" in finding);
    assert.ok("file" in finding);
    assert.ok("line" in finding);
    assert.ok("message" in finding);
  }
});

test("an unreadable root exits 2", async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-skills-"));
  try {
    const child = spawnSync(
      process.execPath,
      [
        path.join(root, "scripts/check-skills.mjs"),
        "--root",
        path.join(temporary, "does-not-exist"),
      ],
      { encoding: "utf8", timeout: 10000 },
    );
    assert.equal(child.status, 2, child.stdout + child.stderr);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});
