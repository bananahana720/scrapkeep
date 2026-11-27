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

test("a valid fixture passes with a manifest and a limits line", async () => {
  const { status, report, stdout } = await runFixture("base");
  assert.equal(status, 0, stdout);
  assert.equal(report.result, "pass");
  assert.ok(Object.keys(report.manifest).includes("README.md"));
  for (const hash of Object.values(report.manifest)) assert.match(hash, /^[0-9a-f]{64}$/);
  assert.match(report.limits, /No build, runtime, browser or remote check/);
});

test("a heading with inline code slugs like GitHub", async () => {
  const { status, report, stdout } = await runFixture("inline-code-heading");
  assert.equal(status, 0, stdout);
  assert.equal(report.failures, 0);
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

const failing = [
  ["broken-anchor", "README.md:3", /broken anchor: BACKLOG\.md#hf-99/],
  ["broken-anchor", "README.md:3", /broken anchor: #missing-heading/],
  ["absolute-link", "README.md:3", /non-portable absolute link: \/home\//],
  ["link-escapes-repo", "README.md:3", /link escapes repository: \.\.\/outside\.md/],
  ["malformed-percent", "README.md:3", /malformed percent-encoding in link: BACKLOG\.md#hf%2/],
  ["malformed-percent", "README.md:3", /malformed percent-encoding in link: BACK%ZZLOG\.md/],
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

test("artifacts/local is pruned before traversal", async () => {
  const tmp = await mkdtemp(path.join(os.tmpdir(), "check-docs-prune-"));
  try {
    await cp(path.join(fixtures, "base"), tmp, { recursive: true });
    await mkdir(path.join(tmp, "artifacts/local/nested"), { recursive: true });
    await writeFile(
      path.join(tmp, "artifacts/local/nested/README.md"),
      "[broken](./does-not-exist.md)\n",
    );
    const ran = spawnSync(
      process.execPath,
      [
        path.join(root, "scripts/check-docs.mjs"),
        "--root",
        tmp,
        "--report",
        path.join(tmp, "report.json"),
      ],
      { encoding: "utf8" },
    );
    assert.equal(ran.status, 0, ran.stdout + ran.stderr);
  } finally {
    await rm(tmp, { recursive: true, force: true });
  }
});

async function runCustomRepo(files) {
  const tmp = await mkdtemp(path.join(os.tmpdir(), "check-docs-custom-"));
  try {
    await cp(path.join(fixtures, "base"), tmp, { recursive: true });
    for (const [rel, body] of Object.entries(files)) {
      const full = path.join(tmp, rel);
      await mkdir(path.dirname(full), { recursive: true });
      await writeFile(full, body);
    }
    const reportPath = path.join(tmp, "report.json");
    const ran = spawnSync(
      process.execPath,
      [path.join(root, "scripts/check-docs.mjs"), "--root", tmp, "--report", reportPath],
      { encoding: "utf8", timeout: 10000 },
    );
    assert.equal(ran.error, undefined);
    assert.notEqual(ran.status, 2, ran.stderr);
    return {
      status: ran.status,
      stdout: ran.stdout,
      report: JSON.parse(await readFile(reportPath, "utf8")),
    };
  } finally {
    await rm(tmp, { recursive: true, force: true });
  }
}

test("broken relative links inside sketches/core-loop/design-v3/ fail check-docs", async () => {
  const { status, stdout, report } = await runCustomRepo({
    "sketches/core-loop/design-v3/sample.md": "# Sample\n\nSee [missing](./missing-note.md).\n",
  });
  assert.equal(status, 1, stdout);
  const hit = report.findings.find(
    (entry) =>
      entry.level === "failure" &&
      entry.file === "sketches/core-loop/design-v3/sample.md" &&
      entry.line === 3 &&
      /missing link target: \.\/missing-note\.md; update to an existing repo-relative path/.test(
        entry.message,
      ),
  );
  assert.ok(hit, stdout);
});

test("absolute /home/andrew links inside project-guide/handoff/ fail with repo-relative fix hint", async () => {
  const { status, stdout, report } = await runCustomRepo({
    "project-guide/handoff/sample.md":
      "# Handoff\n\nSee [local](/home/andrew/projects/scrapkeep/README.md).\n",
  });
  assert.equal(status, 1, stdout);
  const hit = report.findings.find(
    (entry) =>
      entry.level === "failure" &&
      entry.file === "project-guide/handoff/sample.md" &&
      entry.line === 3 &&
      /non-portable absolute link: \/home\/andrew\/projects\/scrapkeep\/README\.md; replace with a repo-relative path from this file/.test(
        entry.message,
      ),
  );
  assert.ok(hit, stdout);
});

test("GitHub line-range anchors (#L10-L20) pass on existing markdown while #missing-heading still fails", async () => {
  const passRun = await runCustomRepo({
    "project-guide/handoff/sample.md": "# Handoff\n\nSee [lines](../../README.md#L10-L20).\n",
  });
  assert.equal(passRun.status, 0, passRun.stdout);
  const failRun = await runCustomRepo({
    "project-guide/handoff/sample.md": "# Handoff\n\nSee [bad](../../README.md#missing-heading).\n",
  });
  assert.equal(failRun.status, 1, failRun.stdout);
  const hit = failRun.report.findings.find(
    (entry) =>
      entry.level === "failure" &&
      entry.file === "project-guide/handoff/sample.md" &&
      /broken anchor: \.\.\/\.\.\/README\.md#missing-heading/.test(entry.message),
  );
  assert.ok(hit, failRun.stdout);
});
