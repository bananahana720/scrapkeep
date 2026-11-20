import test from "node:test";
import assert from "node:assert/strict";
import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const fixtures = path.join(root, "tests/fixtures/check-docs");

// The fixture root sits one level below the temporary directory so a link
// that climbs out of the root can point at a file that really exists.
async function runFixture(name, remove = null) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-docs-"));
  try {
    const docsRoot = path.join(temporary, "repo");
    await mkdir(docsRoot);
    await writeFile(path.join(temporary, "outside.md"), "# Outside\n");
    await cp(path.join(fixtures, "base"), docsRoot, { recursive: true });
    if (name !== "base") await cp(path.join(fixtures, name), docsRoot, { recursive: true });
    if (remove) await rm(path.join(docsRoot, remove));
    const report = path.join(temporary, "report.json");
    const child = spawnSync(
      process.execPath,
      [path.join(root, "scripts/check-docs.mjs"), "--root", docsRoot, "--report", report],
      { encoding: "utf8", timeout: 10000 },
    );
    assert.equal(child.error, undefined);
    assert.notEqual(child.status, 2, child.stderr);
    return {
      status: child.status,
      stdout: child.stdout,
      report: JSON.parse(await readFile(report, "utf8")),
    };
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}

test("a valid fixture passes with a manifest, interim rows and a limits line", async () => {
  const { status, report, stdout } = await runFixture("base");
  assert.equal(status, 0, stdout);
  assert.equal(report.result, "pass");
  assert.deepEqual(Object.keys(report.manifest).sort(), [
    "BACKLOG.md",
    "ORCHESTRATOR.md",
    "README.md",
    "TRACKING.md",
    "docs/project/prompts/sprint-close.md",
    "docs/project/sprint-0/amendment-request.md",
    "docs/project/sprint-0/closure-receipt.md",
  ]);
  for (const hash of Object.values(report.manifest)) assert.match(hash, /^[0-9a-f]{64}$/);
  assert.equal(report.interimRows.length, 1);
  assert.match(report.interimRows[0].row, /^PS-01/);
  assert.match(report.limits, /No build, runtime, browser or remote check/);
});

test("card IDs with a digit in the prefix are counted", async () => {
  const { status, report, stdout } = await runFixture("card-s0");
  assert.equal(status, 0, stdout);
  assert.equal(report.checked.cards, 3);
});

test("a heading with inline code slugs like GitHub", async () => {
  const { status, report, stdout } = await runFixture("inline-code-heading");
  assert.equal(status, 0, stdout);
  assert.equal(report.failures, 0);
});

test("events outside the EV-NNNN form are not sequenced", async () => {
  const { report } = await runFixture("event-gap");
  assert.equal(report.checked.events, 2);
});

test("every board state passes and a program-level event does not make rows stale", async () => {
  const { status, report, stdout } = await runFixture("state-vocabulary");
  assert.equal(status, 0, stdout);
  assert.equal(report.failures, 0);
  assert.equal(report.checked.states, 9);
});

test("a row pointing at the last event that names its record is current", async () => {
  const { status, report, stdout } = await runFixture("last-event-current");
  assert.equal(status, 0, stdout);
  assert.equal(report.failures, 0);
});

test("an event archived out of the board still resolves for the row that cites it", async () => {
  const { status, report, stdout } = await runFixture("archive-resolves");
  assert.equal(status, 0, stdout);
  assert.equal(report.failures, 0);
  assert.equal(report.checked.events, 3);
  assert.equal(report.checked.archives, 1);
});

test("the stale rule compares a row that points into an archive against board events", async () => {
  const { status, stdout, report } = await runFixture("archive-row-stale-later");
  assert.equal(status, 1, stdout);
  assert.equal(report.failures, 1, stdout);
  const [finding] = report.findings.filter((entry) => entry.level === "failure");
  assert.equal(finding.file, "TRACKING.md");
  assert.equal(finding.line, 7);
  assert.match(finding.message, /Last event EV-0001 predates EV-0002, which also names HF-01$/);
});

test("two rulings that take the same letter fail on the later row", async () => {
  const { status, stdout, report } = await runFixture("ruling-letter-twice");
  assert.equal(status, 1, stdout);
  const failures = report.findings.filter((entry) => entry.level === "failure");
  // The row in the "Replaced rulings" table that opens with ca is not a clash;
  // the row after that section is.
  assert.equal(failures.length, 2, stdout);
  for (const failure of failures) {
    assert.equal(failure.check, "rulings");
    assert.equal(failure.file, "project-guide/handoff/DECISIONS.md");
  }
  assert.deepEqual(
    failures.map((failure) => failure.line),
    [7, 17],
  );
  assert.match(
    failures[0].message,
    /^ruling cb already names the row on line 6; give this ruling the next free letter$/,
  );
  assert.match(failures[1].message, /^ruling ca already names the row on line 5;/);
});

test("the historical IN_REVIEW token fails the state vocabulary rule", async () => {
  const { status, stdout, report } = await runFixture("state-in-review");
  assert.equal(status, 1, stdout);
  assert.equal(report.failures, 1, stdout);
  const [finding] = report.findings.filter((entry) => entry.level === "failure");
  assert.equal(finding.check, "tracking");
  assert.equal(finding.file, "TRACKING.md");
  assert.equal(finding.line, 7);
  assert.match(
    finding.message,
    /^\[HF-01\]\(BACKLOG\.md#hf-01\): state "IN_REVIEW" is not in the state vocabulary \(queued, blocked, ready, in_progress, review, changes_requested, done, parked, cancelled\)$/,
  );
  assert.match(stdout, /FAILURE tracking TRACKING\.md:7 /);
  assert.match(stdout, /check:docs fail: .* 1 failures\./);
});

test("a row whose Last event predates a later event naming it fails alone", async () => {
  const { status, stdout, report } = await runFixture("last-event-predates");
  assert.equal(status, 1, stdout);
  assert.equal(report.failures, 1, stdout);
  const [finding] = report.findings.filter((entry) => entry.level === "failure");
  assert.equal(finding.line, 7);
  assert.match(finding.message, /Last event EV-0001 predates EV-0002, which also names HF-01$/);
});

const failing = [
  ["closure-link", "ORCHESTRATOR.md:0", /missing required closure link/],
  [
    "closure-heading",
    "docs/project/sprint-0/amendment-request.md:0",
    /missing required closure heading: Admission and propagation receipt/,
  ],
  ["broken-anchor", "README.md:3", /broken anchor: BACKLOG\.md#hf-99/],
  ["broken-anchor", "README.md:3", /broken anchor: #missing-heading/],
  ["absolute-link", "README.md:3", /non-portable absolute link: \/home\//],
  ["card-missing-boundary", "BACKLOG.md:5", /HF-01: missing field \*\*Boundary:\*\*/],
  ["card-size-l", "BACKLOG.md:7", /HF-01: non-assignable card, Size L/],
  ["duplicate-event", "TRACKING.md:21", /duplicate event EV-0001/],
  ["event-gap", "TRACKING.md:21", /event sequence break: EV-0003 follows EV-0001/],
  ["link-escapes-repo", "README.md:3", /link escapes repository: \.\.\/outside\.md/],
  ["malformed-percent", "README.md:3", /malformed percent-encoding in link: BACKLOG\.md#hf%2/],
  ["malformed-percent", "README.md:3", /malformed percent-encoding in link: BACK%ZZLOG\.md/],
  ["blank-line-events", "TRACKING.md:21", /blank line inside the events table/],
  ["last-event-unresolvable", "TRACKING.md:7", /Last event is not an EV-NNNN id: "not-yet"/],
  ["last-event-unresolvable", "TRACKING.md:8", /Last event EV-0099 is not in the events table/],
  [
    "missing-section-heading",
    "docs/tech/sections/HF-01-fixture.md:0",
    /missing required heading: Procedure performed/,
  ],
  [
    "archive-missing-id",
    "TRACKING.md:8",
    /PS-01 \(interim\): Last event EV-0099 is not in the events table/,
  ],
  [
    "archive-duplicate-id",
    "TRACKING.md:20",
    /duplicate event EV-0002 \(first seen in docs\/project\/tracking\/EVENTS-0001-0002\.md:8\)/,
  ],
  [
    "archive-stale-later",
    "TRACKING.md:7",
    /Last event EV-0001 predates EV-0002, which also names HF-01/,
  ],
  [
    "archive-row-stale-later",
    "TRACKING.md:7",
    /Last event EV-0001 predates EV-0002, which also names HF-01/,
  ],
  [
    "archive-heading-malformed",
    "docs/project/tracking/EVENTS-0001-0002.md:1",
    /malformed event archive heading: "# Event archive" \(an event archive declares itself with a level-2 heading that is exactly "## Event archive"\)/,
  ],
  [
    "archive-heading-malformed",
    "docs/project/tracking/EVENTS-0001-0002.md:6",
    /malformed event archive heading: "## Event archives" \(an event archive declares itself with a level-2 heading that is exactly "## Event archive"\)/,
  ],
];

for (const [name, location, message] of failing)
  test("fixture " + name + " fails at " + location, async () => {
    const { status, stdout, report } = await runFixture(name);
    assert.equal(status, 1, stdout);
    const [file, line] = location.split(":");
    const hit = report.findings.find(
      (finding) =>
        finding.level === "failure" &&
        finding.file === file &&
        finding.line === Number(line) &&
        message.test(finding.message),
    );
    assert.ok(hit, "expected " + message + " at " + location + "\n" + stdout);
    assert.match(stdout, new RegExp("FAILURE \\w+ " + location.replace(".", "\\.")));
  });

test("the duplicate event also breaks the Last event reference for its row", async () => {
  const { report } = await runFixture("duplicate-event");
  assert.ok(
    report.findings.some((finding) =>
      /Last event EV-0002 is not in the events table/.test(finding.message),
    ),
  );
});

test("missing sprint-close prompt fails the closure contract", async () => {
  const { status, report } = await runFixture("base", "docs/project/prompts/sprint-close.md");
  assert.equal(status, 1);
  assert.ok(
    report.findings.some(
      (finding) =>
        finding.check === "closure" && /required closure contract missing/.test(finding.message),
    ),
  );
});

test("artifacts/local is pruned before traversal", async () => {
  const { mkdir, writeFile } = await import("node:fs/promises");
  const { mkdtempSync, rmSync, cpSync } = await import("node:fs");
  const os = await import("node:os");
  const pathMod = await import("node:path");
  const tmp = mkdtempSync(pathMod.join(os.tmpdir(), "check-docs-prune-"));
  try {
    cpSync(pathMod.join(process.cwd(), "tests/fixtures/check-docs/base"), tmp, { recursive: true });
    await mkdir(pathMod.join(tmp, "artifacts/local/nested"), { recursive: true });
    await writeFile(
      pathMod.join(tmp, "artifacts/local/nested/README.md"),
      "[broken](./does-not-exist.md)\n",
    );
    const { spawnSync } = await import("node:child_process");
    const ran = spawnSync(
      process.execPath,
      ["scripts/check-docs.mjs", "--root", tmp, "--report", pathMod.join(tmp, "report.json")],
      { encoding: "utf8" },
    );
    assert.equal(ran.status, 0, ran.stdout + ran.stderr);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
