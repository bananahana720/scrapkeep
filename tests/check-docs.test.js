import test from "node:test";
import assert from "node:assert/strict";
import { cp, mkdtemp, readFile, rm } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const fixtures = path.join(root, "tests/fixtures/check-docs");

async function runFixture(name) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-docs-"));
  try {
    await cp(path.join(fixtures, "base"), temporary, { recursive: true });
    if (name !== "base")
      await cp(path.join(fixtures, name), temporary, { recursive: true });
    const report = path.join(temporary, "report.json");
    const child = spawnSync(
      process.execPath,
      [
        path.join(root, "scripts/check-docs.mjs"),
        "--root",
        temporary,
        "--report",
        report,
      ],
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
    "README.md",
    "TRACKING.md",
  ]);
  for (const hash of Object.values(report.manifest))
    assert.match(hash, /^[0-9a-f]{64}$/);
  assert.equal(report.interimRows.length, 1);
  assert.match(report.interimRows[0].row, /^PS-01/);
  assert.match(report.limits, /No build, runtime, browser or remote check/);
});

const failing = [
  ["broken-anchor", "README.md:3", /broken anchor: BACKLOG\.md#hf-99/],
  ["broken-anchor", "README.md:3", /broken anchor: #missing-heading/],
  ["absolute-link", "README.md:3", /non-portable absolute link: \/home\//],
  [
    "card-missing-boundary",
    "BACKLOG.md:5",
    /HF-01: missing field \*\*Boundary:\*\*/,
  ],
  ["card-size-l", "BACKLOG.md:7", /HF-01: non-assignable card, Size L/],
  ["duplicate-event", "TRACKING.md:21", /duplicate event EV-0001/],
  ["blank-line-events", "TRACKING.md:21", /blank line inside the events table/],
  [
    "missing-section-heading",
    "docs/tech/sections/HF-01-fixture.md:0",
    /missing required heading: Procedure performed/,
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
    assert.match(
      stdout,
      new RegExp("FAILURE \\w+ " + location.replace(".", "\\.")),
    );
  });

test("the duplicate event also breaks the Last event reference for its row", async () => {
  const { report } = await runFixture("duplicate-event");
  assert.ok(
    report.findings.some((finding) =>
      /Last event EV-0002 is not in the events table/.test(finding.message),
    ),
  );
});
