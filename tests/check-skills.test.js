import test from "node:test";
import assert from "node:assert/strict";
import { cp, mkdir, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
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
// is applied. `broken` dangles a name; `notSymlink` writes a plain file
// instead; `wrongTarget` points a name at the OTHER skill's directory.
async function linkSkills(repoRoot, { broken = null, notSymlink = null, wrongTarget = null } = {}) {
  const linkDir = path.join(repoRoot, ".claude/skills");
  await mkdir(linkDir, { recursive: true });
  for (const name of skillNames) {
    const linkPath = path.join(linkDir, name);
    if (name === notSymlink) {
      await writeFile(linkPath, "not a symlink\n");
      continue;
    }
    const otherName = skillNames.find((candidate) => candidate !== name);
    let target;
    if (name === broken) target = path.join("..", "..", ".agents/skills", "does-not-exist");
    else if (name === wrongTarget) target = path.join("..", "..", ".agents/skills", otherName);
    else target = path.join("..", "..", ".agents/skills", name);
    await symlink(target, linkPath);
  }
}

async function runFixture(name, linkOptions = {}) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-skills-"));
  try {
    const repoRoot = path.join(temporary, "repo");
    await mkdir(repoRoot);
    await cp(path.join(fixtures, "base"), repoRoot, { recursive: true });
    if (name !== "base") await cp(path.join(fixtures, name), repoRoot, { recursive: true });
    await linkSkills(repoRoot, linkOptions);
    return await runAgainst(repoRoot);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}

async function runAgainst(repoRoot, extraArgs = []) {
  const child = spawnSync(
    process.execPath,
    [path.join(root, "scripts/check-skills.mjs"), "--root", repoRoot, "--json", ...extraArgs],
    { encoding: "utf8", timeout: 10000 },
  );
  assert.equal(child.error, undefined);
  let findings = null;
  try {
    findings = JSON.parse(child.stdout);
  } catch {
    // Some paths (bad flags, missing required input) intentionally print no
    // JSON at all; callers that expect findings assert non-null themselves.
  }
  return { status: child.status, stdout: child.stdout, stderr: child.stderr, findings };
}

function failures(findings, check) {
  return findings.filter(
    (finding) => finding.level === "failure" && (check === undefined || finding.check === check),
  );
}

function warnings(findings, check) {
  return findings.filter(
    (finding) => finding.level === "warning" && (check === undefined || finding.check === check),
  );
}

// A minimal from-scratch repo for the N10 cases that do not need the full
// two-skill base fixture: two required board files, one skill directory
// built from the given SKILL.md/lessons.md content.
async function buildMinimalRepo(
  temporary,
  { skillMd, lessonsMd, skillName = "reactive-model-loop" },
) {
  const repoRoot = path.join(temporary, "repo");
  await mkdir(path.join(repoRoot, ".agents/skills/" + skillName + "/references"), {
    recursive: true,
  });
  await writeFile(
    path.join(repoRoot, "package.json"),
    JSON.stringify({ scripts: { test: "node --test" } }),
  );
  await writeFile(
    path.join(repoRoot, "TRACKING.md"),
    "# Tracking\n\n## Append-only events\n\n| EV-0001 | 2026-09-25T00:00:00Z | writer | JL-01 | Fixture |\n",
  );
  await writeFile(
    path.join(repoRoot, "BACKLOG.md"),
    '# Backlog\n\n<a id="jl-01"></a>\n### JL-01: Demo\n',
  );
  await writeFile(path.join(repoRoot, ".agents/skills/" + skillName + "/SKILL.md"), skillMd);
  if (lessonsMd !== undefined)
    await writeFile(
      path.join(repoRoot, ".agents/skills/" + skillName + "/references/lessons.md"),
      lessonsMd,
    );
  return repoRoot;
}

const GOOD_LESSONS = `# Lesson ledger

## Lessons

- **RML-01** · status: provisional · since: 2026-09-25 · origin: one lab
  The model picks coarse intent; code owns execution.
  Evidence: one lab found this split held throughout.
  Overturned by: —

## Changelog

| Date | Change type | Ids touched | Evidence or commit | Reviewer |
| --- | --- | --- | --- | --- |
| 2026-09-25 | new lesson | RML-01 | fixture | pending |
`;

function goodSkillMd({ description = "Design and evaluate a fast model.", body = "" } = {}) {
  return `---
name: reactive-model-loop
description: "${description}"
---

# Run a fast model as a decider

Resolve this skill directory through symlinks.

## Procedure

1. Split coarse intent from deterministic execution. (RML-01)
${body}
## Host adapter

- Claude Code: use structured questions when available.
- Codex: use the host's own structured input tool.

## Lessons and updates

See [references/lessons.md](references/lessons.md).
`;
}

// --- Existing coverage (A1), updated for the base fixture's richer content --

test("a clean fixture passes with exit 0 and no failures", async () => {
  const { status, findings, stdout } = await runFixture("base");
  assert.equal(status, 0, stdout);
  assert.equal(failures(findings).length, 0, JSON.stringify(findings, null, 2));
});

test("the clean fixture also prints one line per finding and a count in the default mode, and no JSON", async () => {
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
    assert.throws(() => JSON.parse(child.stdout));
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test("a dead backtick path fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("dead-path");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "paths");
  assert.ok(
    hits.some((f) => f.message.includes("scripts/does-not-exist.mjs")),
    JSON.stringify(findings, null, 2),
  );
});

test("a dead npm script fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("dead-npm-script");
  assert.equal(status, 1, stdout);
  assert.ok(failures(findings, "npm").some((f) => f.message.includes("does-not-exist")));
});

test("a broken .claude/skills link fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("base", { broken: "scrapkeep-lab" });
  assert.equal(status, 1, stdout);
  assert.ok(failures(findings, "link").some((f) => f.file.includes("scrapkeep-lab")));
});

test("a forbidden token in the portable skill fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("forbidden-token");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "portability");
  assert.ok(hits.some((f) => f.message.includes("Godot")));
  assert.ok(hits.every((f) => f.file.includes("reactive-model-loop")));
});

test("a duplicate lesson id fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("duplicate-lesson");
  assert.equal(status, 1, stdout);
  assert.ok(
    failures(findings, "lessons").some(
      (f) => f.message.includes("duplicate") && f.message.includes("RML-01"),
    ),
  );
});

test("a retracted lesson without Overturned by fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("retracted-without-overturned");
  assert.equal(status, 1, stdout);
  assert.ok(
    failures(findings, "lessons").some(
      (f) => f.message.includes("Overturned by") && f.message.includes("RML-01"),
    ),
  );
});

test("an RML id missing from the origin map fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("rml-missing-from-map");
  assert.equal(status, 1, stdout);
  assert.ok(
    failures(findings, "lessons").some(
      (f) => f.message.includes("RML-02") && f.message.includes("origin map"),
    ),
  );
});

test("a SKILL.md body over 250 lines fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("body-over-250");
  assert.equal(status, 1, stdout);
  assert.ok(failures(findings, "size").length > 0);
});

test("a placeholder, glob, quoted-schema, URL and :line-suffixed token are not flagged", async () => {
  const { status, findings, stdout } = await runFixture("not-flagged");
  assert.equal(status, 0, stdout);
  assert.equal(failures(findings, "paths").length, 0, JSON.stringify(findings, null, 2));
});

test("an unreadable root exits 2", async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-skills-"));
  try {
    const { status } = await runAgainst(path.join(temporary, "does-not-exist"));
    assert.equal(status, 2);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test("an unknown flag exits 2", async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-skills-"));
  try {
    const repoRoot = path.join(temporary, "repo");
    await mkdir(repoRoot);
    await cp(path.join(fixtures, "base"), repoRoot, { recursive: true });
    await linkSkills(repoRoot);
    const { status, findings } = await runAgainst(repoRoot, ["--bogus"]);
    assert.equal(status, 2);
    assert.equal(findings, null);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

// --- A2 review items ---------------------------------------------------------

// B1
test("B1: a lesson ledger with no Changelog section fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("changelog-missing");
  assert.equal(status, 1, stdout);
  assert.ok(failures(findings, "changelog").some((f) => f.message.includes("Changelog")));
});

test("B1: a retracted lesson's Overturned-by date after the newest Changelog row fails", async () => {
  const { status, findings, stdout } = await runFixture("changelog-stale");
  assert.equal(status, 1, stdout);
  assert.ok(
    failures(findings, "changelog").some(
      (f) => f.message.includes("RML-01") && f.message.includes("2026-09-30"),
    ),
  );
});

// B2
test("B2: an invalid scrapkeep verb and lab sub-verb fail, read statically from play.mjs", async () => {
  const { status, findings, stdout } = await runFixture("bad-verb-citation");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "verbs");
  assert.ok(
    hits.some((f) => f.message.includes("frobnicate")),
    JSON.stringify(findings, null, 2),
  );
  assert.ok(hits.some((f) => f.message.includes("bogus") && f.message.includes("lab sub-verb")));
});

test("B2: valid scrapkeep verbs and lab sub-verbs (including pipe-separated) are not flagged", async () => {
  const { status, findings, stdout } = await runFixture("base");
  assert.equal(status, 0, stdout);
  assert.equal(failures(findings, "verbs").length, 0, JSON.stringify(findings, null, 2));
});

test("B2: a play.mjs with no statically findable verb lists warns every run, never fails", async () => {
  const { status, findings, stdout } = await runFixture("no-static-verbs");
  assert.equal(status, 0, stdout);
  assert.ok(warnings(findings, "verbs").length > 0, JSON.stringify(findings, null, 2));
});

// B3
test('B3: a missing "## Lessons" section fails with a named finding', async () => {
  const { status, findings, stdout } = await runFixture("missing-lessons-section");
  assert.equal(status, 1, stdout);
  assert.ok(failures(findings, "lessons").some((f) => f.message.includes("## Lessons")));
});

test("B3: a malformed lesson header fails with a named finding", async () => {
  const { status, findings, stdout } = await runFixture("malformed-lesson-header");
  assert.equal(status, 1, stdout);
  assert.ok(failures(findings, "lessons").some((f) => f.message.includes("malformed")));
});

test("B3: the verify and Antigravity skill lesson prefixes (VGM, VBD, VWB, AGW, SVR) are recognised", async () => {
  const { status, findings, stdout } = await runFixture("verify-prefixes");
  assert.equal(status, 0, stdout);
  assert.equal(failures(findings, "lessons").length, 0, stdout);
});

test("B3: AGW and SVR lesson headers and citations pass check-skills", async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-skills-"));
  try {
    const skillMd = goodSkillMd({
      description: "Run Antigravity workflows.",
      body: "2. Route Gemini tiers cleanly. (AGW-01)\n3. Inspect visuals directly. (SVR-01)\n",
    })
      .replace("name: reactive-model-loop", "name: scrapkeep-gemini-workflows")
      .replace("(RML-01)", "(AGW-01)");
    const lessonsMd = GOOD_LESSONS.replace("RML-01", "AGW-01")
      .replace("| RML-01 |", "| AGW-01 |")
      .replace(
        "## Changelog",
        "- **SVR-01** · status: provisional · since: 2026-11-25 · origin: visual review\n  Open rendered images directly.\n  Evidence: fixture.\n  Overturned by: —\n\n## Changelog",
      );
    const repoRoot = await buildMinimalRepo(temporary, {
      skillName: "scrapkeep-gemini-workflows",
      skillMd,
      lessonsMd,
    });
    const linkDir = path.join(repoRoot, ".claude/skills");
    await mkdir(linkDir, { recursive: true });
    await symlink(
      "../../.agents/skills/scrapkeep-gemini-workflows",
      path.join(linkDir, "scrapkeep-gemini-workflows"),
    );
    const { status, findings } = await runAgainst(repoRoot);
    assert.equal(status, 0, JSON.stringify(findings, null, 2));
    assert.equal(failures(findings, "lessons").length, 0);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test("B3: an RML- id inside the lab skill's ledger fails (prefix scope)", async () => {
  const { status, findings, stdout } = await runFixture("wrong-prefix-scope");
  assert.equal(status, 1, stdout);
  assert.ok(
    failures(findings, "lessons").some(
      (f) => f.message.includes("SKL-99") && f.message.includes("belong only in"),
    ),
  );
});

test("B3: a multi-id citation (SKL-01, SKL-99) is recognised and the missing id fails alone", async () => {
  const { status, findings, stdout } = await runFixture("multi-id-citation");
  assert.equal(status, 1, stdout);
  const hits = failures(findings, "lessons");
  assert.ok(hits.some((f) => f.message.includes("SKL-99")));
  assert.ok(!hits.some((f) => f.message.includes("cited lesson SKL-01")));
});

// B4
test("B4: a path-shaped word inside a multi-word command is now flagged", async () => {
  const { status, findings, stdout } = await runFixture("word-in-command");
  assert.equal(status, 1, stdout);
  assert.ok(
    failures(findings, "paths").some((f) => f.message.includes("scripts/does-not-exist.mjs")),
    JSON.stringify(findings, null, 2),
  );
});

// B5 / N8 (exercised through the base fixture's own additions)
test("B5: a bare SKILL.md self-reference resolves relative to the citing skill's directory", async () => {
  const { status, findings, stdout } = await runFixture("base");
  assert.equal(status, 0, stdout);
  assert.ok(
    !findings.some((f) => f.message.includes("path does not exist: SKILL.md")),
    JSON.stringify(findings, null, 2),
  );
});

test("N8: a BACKLOG.md#anchor citation strips the anchor before resolving", async () => {
  const { status, findings, stdout } = await runFixture("base");
  assert.equal(status, 0, stdout);
  assert.ok(
    !findings.some((f) => f.message.includes("BACKLOG.md#jl-01")),
    JSON.stringify(findings, null, 2),
  );
});

// N3
test("N3: a dead path under a gitignored directory warns instead of failing", async () => {
  const { status, findings, stdout } = await runFixture("gitignored-path");
  assert.equal(status, 0, stdout);
  assert.equal(failures(findings, "paths").length, 0, JSON.stringify(findings, null, 2));
  assert.ok(
    warnings(findings, "paths").some(
      (f) => f.message.includes("dist/bundle.js") && f.message.includes("gitignored"),
    ),
    JSON.stringify(findings, null, 2),
  );
});

// N1
test("N1: single-quoted description and CRLF line endings parse cleanly", async () => {
  const { status, findings, stdout } = await runFixture("frontmatter-yaml-styles");
  assert.equal(status, 0, stdout);
  assert.equal(failures(findings, "frontmatter").length, 0, JSON.stringify(findings, null, 2));
});

test("N1: a folded (>) YAML description parses without a frontmatter failure", async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-skills-"));
  try {
    const folded = goodSkillMd().replace(
      'description: "Design and evaluate a fast model."',
      "description: >\n  Design and evaluate a fast model that makes\n  reaction-based decisions.",
    );
    const repoRoot = await buildMinimalRepo(temporary, {
      skillMd: folded,
      lessonsMd: GOOD_LESSONS,
    });
    await linkSkills(repoRoot, {});
    const { status, findings } = await runAgainst(repoRoot);
    assert.equal(failures(findings, "frontmatter").length, 0, JSON.stringify(findings, null, 2));
    assert.equal(status, 0);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

// N7
test("N7: a forbidden token in a non-standard file under the portable skill is still caught", async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-skills-"));
  try {
    const repoRoot = path.join(temporary, "repo");
    await mkdir(repoRoot);
    await cp(path.join(fixtures, "base"), repoRoot, { recursive: true });
    await writeFile(
      path.join(repoRoot, ".agents/skills/reactive-model-loop/NOTES.md"),
      "A stray note that mentions Godot by name.\n",
    );
    await linkSkills(repoRoot, {});
    const { status, findings } = await runAgainst(repoRoot);
    assert.equal(status, 1);
    assert.ok(
      failures(findings, "portability").some((f) => f.file.includes("NOTES.md")),
      JSON.stringify(findings, null, 2),
    );
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

// N10: frontmatter failures
test("N10: a frontmatter name that does not match the directory fails", async () => {
  const { status, findings, stdout } = await runFixture("frontmatter-name-mismatch");
  assert.equal(status, 1, stdout);
  assert.ok(
    failures(findings, "frontmatter").some((f) =>
      f.message.includes("does not match directory name"),
    ),
  );
});

test("N10: a missing description fails", async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-skills-"));
  try {
    const skillMd = `---
name: reactive-model-loop
---

# Run a fast model as a decider

Resolve this skill directory through symlinks.

## Host adapter

- Claude Code: use structured questions when available.
- Codex: use the host's own structured input tool.
`;
    const repoRoot = await buildMinimalRepo(temporary, { skillMd, lessonsMd: GOOD_LESSONS });
    await linkSkills(repoRoot, {});
    const { status, findings } = await runAgainst(repoRoot);
    assert.equal(status, 1);
    assert.ok(
      failures(findings, "frontmatter").some((f) => f.message.includes("missing description")),
    );
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

// N10: >150 warning
test("N10: a SKILL.md body between 150 and 250 lines warns, does not fail", async () => {
  const { status, findings, stdout } = await runFixture("body-warning-150");
  assert.equal(status, 0, stdout);
  assert.equal(failures(findings, "size").length, 0);
  assert.ok(warnings(findings, "size").length > 0, JSON.stringify(findings, null, 2));
});

// N10: link failure modes
test("N10: a .claude/skills entry that is a regular file, not a symlink, fails", async () => {
  const { status, findings, stdout } = await runFixture("base", { notSymlink: "scrapkeep-lab" });
  assert.equal(status, 1, stdout);
  assert.ok(
    failures(findings, "link").some(
      (f) => f.file.includes("scrapkeep-lab") && f.message.includes("not a symlink"),
    ),
  );
});

test("N10: a .claude/skills symlink pointing at the wrong skill directory fails", async () => {
  const { status, findings, stdout } = await runFixture("base", { wrongTarget: "scrapkeep-lab" });
  assert.equal(status, 1, stdout);
  assert.ok(
    failures(findings, "link").some(
      (f) => f.file.includes("scrapkeep-lab") && f.message.includes("expected"),
    ),
  );
});

// N10: invalid status
test("N10: an invalid lesson status fails", async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-skills-"));
  try {
    const badLessons = GOOD_LESSONS.replace("status: provisional", "status: bogus");
    const repoRoot = await buildMinimalRepo(temporary, {
      skillMd: goodSkillMd(),
      lessonsMd: badLessons,
    });
    await linkSkills(repoRoot, {});
    const { status, findings } = await runAgainst(repoRoot);
    assert.equal(status, 1);
    assert.ok(failures(findings, "lessons").some((f) => f.message.includes("bogus")));
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

// N10: a citation to a lesson id that does not exist anywhere ("uncited")
test("N10: a SKILL.md citing a lesson id absent from every ledger fails", async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-skills-"));
  try {
    const skillMd = goodSkillMd({
      body: "2. A second rule citing a lesson that was never written. (RML-99)\n",
    });
    const repoRoot = await buildMinimalRepo(temporary, { skillMd, lessonsMd: GOOD_LESSONS });
    await linkSkills(repoRoot, {});
    const { status, findings } = await runAgainst(repoRoot);
    assert.equal(status, 1);
    assert.ok(
      failures(findings, "lessons").some(
        (f) => f.message.includes("RML-99") && f.message.includes("not in any ledger"),
      ),
    );
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test("--json prints a well-shaped findings array", async () => {
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
