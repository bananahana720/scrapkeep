import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const script = path.join(root, "scripts/check-drift.mjs");

function sha256(content) {
  return createHash("sha256").update(content).digest("hex");
}

// Fixtures are written under a temporary root rather than beside the admitted
// corpora, so no case depends on a section's current bytes. The one exception
// is the fallback case, which must cite a real file under docs/tech/sections
// to prove the second resolution root, so it hashes that file at run time.
const dependency = "# Dependency\n\nFixture bytes.\n";
const dependencyHash = sha256(dependency);
const altered = dependencyHash.replace(/^./, (first) =>
  first === "0" ? "1" : "0",
);
const technicalName = "HF-01-production-conventions.md";
const technicalHash = sha256(
  await readFile(path.join(root, "docs/tech/sections", technicalName)),
);

// The Sources bullet is line 5 of every fixture, which is what the DRIFT and
// UNBOUND line forms name after the citing file.
function section(title, ...bullets) {
  return [
    "# " + title,
    "",
    "## Sources",
    "",
    ...bullets.map((one) => "- " + one),
  ]
    .concat(["", "## Contract", "", "Fixture section.", ""])
    .join("\n");
}

const scenarios = [
  {
    name: "a product section that binds against its own directory",
    files: {
      "sections/PD-fixture.md": section(
        "PD-fixture",
        "[dependency](../deps/dependency.md), section bytes SHA256 `" +
          dependencyHash +
          "`.",
      ),
      "deps/dependency.md": dependency,
    },
    args: (temporary) => [
      "--product-sections",
      path.join(temporary, "sections"),
    ],
    status: 0,
    expect: [
      /check:drift product pass: 1 sections, 1 stated hashes, 0 mismatches, 0 unbound\./,
      /check:drift pass: 1 sections, 1 stated hashes, 0 mismatches, 0 unbound over 1 corpus: product/,
    ],
    refute: [/DRIFT/, /UNBOUND/],
  },
  {
    name: "a product section that binds through docs/tech/sections",
    files: {
      "sections/PD-fixture.md": section(
        "PD-fixture",
        "[HF-01](" +
          technicalName +
          "), section bytes SHA256 `" +
          technicalHash +
          "`.",
      ),
    },
    args: (temporary) => [
      "--product-sections",
      path.join(temporary, "sections"),
    ],
    status: 0,
    expect: [
      /check:drift product pass: 1 sections, 1 stated hashes, 0 mismatches, 0 unbound\./,
      /dependencies resolved from each citing file then docs\/tech\/sections/,
    ],
    refute: [/DRIFT/],
  },
  {
    name: "a dependency beside the citing section ahead of the fallback root",
    files: {
      "sections/PD-fixture.md": section(
        "PD-fixture",
        "[HF-01](" +
          technicalName +
          "), section bytes SHA256 `" +
          dependencyHash +
          "`.",
      ),
      ["sections/" + technicalName]: dependency,
    },
    args: (temporary) => [
      "--product-sections",
      path.join(temporary, "sections"),
    ],
    status: 0,
    expect: [
      /check:drift product pass: 2 sections, 1 stated hashes, 0 mismatches, 1 unbound\./,
      new RegExp("UNBOUND \\S*" + technicalName + " states no dependency hash"),
    ],
    refute: [/DRIFT/],
  },
  {
    name: "a product section whose stated hash mismatches",
    files: {
      "sections/PD-fixture.md": section(
        "PD-fixture",
        "[dependency](../deps/dependency.md), section bytes SHA256 `" +
          altered +
          "`.",
      ),
      "deps/dependency.md": dependency,
    },
    args: (temporary) => [
      "--product-sections",
      path.join(temporary, "sections"),
    ],
    status: 1,
    expect: [
      new RegExp(
        "^DRIFT \\S*PD-fixture\\.md:5 \\S*dependency\\.md stated " +
          altered +
          " actual " +
          dependencyHash +
          "$",
        "m",
      ),
      /check:drift product fail: 1 sections, 1 stated hashes, 1 mismatches, 0 unbound\./,
      /check:drift fail: /,
    ],
  },
  {
    name: "a product section whose link binds nowhere",
    files: {
      "sections/PD-fixture.md": section(
        "PD-fixture",
        "[absent](../deps/absent.md), section bytes SHA256 `" +
          dependencyHash +
          "`.",
      ),
    },
    args: (temporary) => [
      "--product-sections",
      path.join(temporary, "sections"),
    ],
    status: 1,
    expect: [
      new RegExp(
        "^DRIFT \\S*PD-fixture\\.md:5 \\S*absent\\.md stated " +
          dependencyHash +
          " actual missing$",
        "m",
      ),
      /check:drift product fail: 1 sections, 1 stated hashes, 1 mismatches, 0 unbound\./,
    ],
  },
  {
    name: "a product section that states no dependency hash",
    files: {
      "sections/PD-empty.md": section(
        "PD-empty",
        "[the technical section index](../../tech/sections/README.md) supplies the form; no bytes are stated.",
      ),
    },
    args: (temporary) => [
      "--product-sections",
      path.join(temporary, "sections"),
    ],
    status: 0,
    expect: [
      /UNBOUND \S*PD-empty\.md states no dependency hash in its Sources bullets/,
      /check:drift product pass: 1 sections, 0 stated hashes, 0 mismatches, 1 unbound\./,
    ],
    refute: [/DRIFT/],
  },
  {
    name: "a product index that states no dependency hash",
    files: {
      "sections/README.md": section(
        "Product sections",
        "[PD-fixture](PD-fixture.md), the one admitted section.",
      ),
      "sections/PD-fixture.md": section(
        "PD-fixture",
        "[dependency](../deps/dependency.md), section bytes SHA256 `" +
          dependencyHash +
          "`.",
      ),
      "deps/dependency.md": dependency,
    },
    args: (temporary) => [
      "--product-sections",
      path.join(temporary, "sections"),
    ],
    status: 0,
    expect: [
      /check:drift product pass: 2 sections, 1 stated hashes, 0 mismatches, 0 unbound\./,
    ],
    refute: [/UNBOUND/, /DRIFT/],
  },
  {
    name: "a stated hash with no preceding repository-path link",
    files: {
      "sections/PD-fixture.md": section(
        "PD-fixture",
        "A retained paper check, bytes SHA256 `" + dependencyHash + "`.",
      ),
    },
    args: (temporary) => [
      "--product-sections",
      path.join(temporary, "sections"),
    ],
    status: 0,
    expect: [
      new RegExp(
        "UNBOUND \\S*PD-fixture\\.md:5 stated " +
          dependencyHash +
          " has no preceding repository-path link on its bullet",
      ),
      /check:drift product pass: 1 sections, 1 stated hashes, 0 mismatches, 1 unbound\./,
    ],
  },
  {
    name: "a technical corpus mismatch, with a hashless technical file left unreported",
    files: {
      "sections/HF-fixture.md": section(
        "HF-fixture",
        "[dependency](../deps/dependency.md), section bytes SHA256 `" +
          altered +
          "`.",
      ),
      "sections/HF-index.md": section(
        "HF-index",
        "[BACKLOG](../../BACKLOG.md#hf-01) owns the card; no bytes are stated.",
      ),
      "deps/dependency.md": dependency,
    },
    args: (temporary) => ["--sections", path.join(temporary, "sections")],
    status: 1,
    expect: [
      new RegExp(
        "^DRIFT \\S*HF-fixture\\.md:5 \\S*dependency\\.md stated " +
          altered +
          " actual " +
          dependencyHash +
          "$",
        "m",
      ),
      /check:drift technical fail: 2 sections, 1 stated hashes, 1 mismatches, 0 unbound\./,
      /dependencies resolved from each citing file$/m,
    ],
    refute: [/UNBOUND/],
  },
  {
    name: "a product copy whose dependencies resolve from an explicit root",
    files: {
      "copy/PD-fixture.md": section(
        "PD-fixture",
        "[dependency](../deps/dependency.md), section bytes SHA256 `" +
          dependencyHash +
          "`.",
      ),
      "deps/dependency.md": dependency,
    },
    args: (temporary) => [
      "--product-sections",
      path.join(temporary, "copy"),
      "--resolve-from",
      path.join(temporary, "sections"),
    ],
    status: 0,
    expect: [
      /check:drift product pass: 1 sections, 1 stated hashes, 0 mismatches, 0 unbound\./,
      /dependencies resolved from \S+ then docs\/tech\/sections/,
    ],
    refute: [/DRIFT/],
  },
];

function run(args) {
  const child = spawnSync(process.execPath, [script, ...args], {
    encoding: "utf8",
    timeout: 30000,
  });
  assert.equal(child.error, undefined);
  return child;
}

for (const scenario of scenarios)
  test("check:drift reports " + scenario.name, async () => {
    const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-drift-"));
    try {
      for (const [file, content] of Object.entries(scenario.files)) {
        await mkdir(path.join(temporary, path.dirname(file)), {
          recursive: true,
        });
        await writeFile(path.join(temporary, file), content);
      }
      const child = run(scenario.args(temporary));
      const output = child.stdout + child.stderr;
      assert.equal(child.status, scenario.status, output);
      for (const pattern of scenario.expect) assert.match(output, pattern);
      for (const pattern of scenario.refute ?? [])
        assert.doesNotMatch(output, pattern);
      assert.match(output, /^Hash agreement only\./m);
    } finally {
      await rm(temporary, { recursive: true, force: true });
    }
  });

// The admitted run is asserted for the directories it scans and for the
// absence of an internal error, not for the repository's current drift state:
// a real mismatch is check:drift's own finding for a card, not a test failure.
test("check:drift scans both admitted section directories by default", () => {
  const child = run([]);
  assert.ok(
    child.status === 0 || child.status === 1,
    child.stdout + child.stderr,
  );
  assert.match(
    child.stdout,
    /^check:drift technical (pass|fail): .* Scanned docs\/tech\/sections, dependencies resolved from each citing file$/m,
  );
  assert.match(
    child.stdout,
    /^check:drift product (pass|fail): .* Scanned docs\/product\/sections, dependencies resolved from each citing file then docs\/tech\/sections$/m,
  );
  assert.match(child.stdout, /over 2 corpora: technical, product$/m);
});

test("check:drift rejects a malformed invocation with exit 2", () => {
  const child = run(["--sections"]);
  assert.equal(child.status, 2);
  assert.match(
    child.stderr,
    /check:drift internal error: Error: Unknown argument: --sections/,
  );
});
