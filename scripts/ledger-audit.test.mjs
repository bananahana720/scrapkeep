import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import { LEDGER_FILE } from "./known-failing.mjs";
import { auditFormalSync, formatLedgerAudit, REPO_ROOT, runLedgerAudit } from "./ledger-audit.mjs";

const HEADER = "test\tkind\tcause\towner\tadded\treview\tcheck";
const ALPHA = "alpha_test\tred\tbroken\ttesting\t2026-11-01\t2026-11-20\tc1";

function auditLedger(text) {
  const root = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-ledger-audit-"));
  try {
    if (text !== null) {
      mkdirSync(path.join(root, path.dirname(LEDGER_FILE)), { recursive: true });
      writeFileSync(path.join(root, LEDGER_FILE), text);
    }
    return runLedgerAudit({
      repoRoot: root,
      today: "2026-11-26",
      spawn: () => assert.fail("no formal model is found, so no git runs"),
    });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

describe("the audit's read of KNOWN-FAILING.tsv", () => {
  it("classifies red, flake, and overdue rows against the supplied date", () => {
    const { known_failing: ledger } = auditLedger(
      [
        HEADER,
        ALPHA,
        "beta_test\tflake\tload\tcoord\t2026-11-05\t2026-12-01\t-",
        "gamma_test\tflake\tload\tcoord\t2026-11-05\t2026-11-25\t-",
      ].join("\n"),
    );
    assert.equal(ledger.total, 3);
    assert.deepEqual(ledger.problems, []);
    assert.deepEqual(
      ledger.reds.map((r) => r.test),
      ["alpha_test"],
    );
    assert.equal(ledger.flake_count, 2);
    assert.deepEqual(
      ledger.overdue.map((r) => r.test),
      ["alpha_test", "gamma_test"],
    );
  });

  it("reads the ledger through parseLedger, so a ledger the owner refuses is never clean", () => {
    for (const [why, text, said] of [
      ["no ledger", null, /^line 0: project-guide\/handoff\/KNOWN-FAILING\.tsv was not found$/],
      ["an empty ledger", "", /^line 1: the header must be/],
      ["a blank first line", `\n${HEADER}\n${ALPHA}\n`, /^line 1: the header must be/],
      ["a wrong header", `test\towner\treason\n${ALPHA}\n`, /^line 1: the header must be/],
      ["a short row", `${HEADER}\nalpha_test\tred\tbroken\n`, /^line 2: a row needs/],
      ["a long row", `${HEADER}\n${ALPHA}\textra\n`, /^line 2: a row needs/],
      [
        "an empty cell",
        `${HEADER}\nalpha_test\tred\t\ttesting\t2026-11-01\t2026-11-20\tc1\n`,
        /^line 2: a row needs/,
      ],
      ["an unknown kind", `${HEADER}\n${ALPHA.replace("\tred\t", "\tcloud\t")}\n`, /kind "cloud"/],
      ["a duplicate", `${HEADER}\n${ALPHA}\n${ALPHA}\n`, /already has a row on line 2/],
    ]) {
      const report = auditLedger(text);
      assert.equal(report.ok, false, why);
      assert.ok(report.known_failing.problem_count > 0, why);
      const lines = formatLedgerAudit(report).split("\n");
      assert.match(lines[1], /problems=[1-9]/, why);
      assert.match(lines[2].replace(/^ {4}problem: /, ""), said, why);
    }
    const padded = auditLedger(
      `${HEADER}\n alpha_test \tred \tbroken\ttesting\t2026-11-01\t 2026-11-20\tc1\n`,
    );
    assert.deepEqual(padded.known_failing.problems, []);
    assert.deepEqual(padded.known_failing.reds, [
      { test: "alpha_test", owner: "testing", review: "2026-11-20" },
    ]);
  });
});

describe("auditFormalSync", () => {
  it("detects synced models, drifted covered files, and missing coverage sync commits", () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-formal-audit-"));
    try {
      const refs = path.join(tmp, ".agents", "skills", "scrapkeep-verify-formal", "references");
      mkdirSync(refs, { recursive: true });
      writeFileSync(
        path.join(refs, "synced.md"),
        "Covers `sketches/core-loop/src/core/flow.gd`.\nSynced at `abcdef1234`.\n",
        "utf8",
      );
      writeFileSync(
        path.join(refs, "drifted.md"),
        "Covers `sketches/core-loop/src/combat/bolts.gd`.\nSynced at `1111111111`.\n",
        "utf8",
      );
      writeFileSync(
        path.join(refs, "nosync.md"),
        "Covers `sketches/core-loop/src/core/progress.gd`.\nNo commit hash here.\n",
        "utf8",
      );

      const mockRows = {
        m_synced: { spec: "A.tla", coverage: "references/synced.md" },
        m_drifted: { spec: "B.tla", coverage: "references/drifted.md" },
        m_nosync: { spec: "C.tla", coverage: "references/nosync.md" },
      };

      const res = auditFormalSync(tmp, {
        rows: mockRows,
        spawn: (_cmd, args) => {
          assert.ok(args.includes("-z"), args.join(" "));
          const sync = args[args.indexOf("--name-only") + 1];
          if (sync === "1111111111") {
            return { status: 0, stdout: "sketches/core-loop/src/combat/bolts.gd\0", stderr: "" };
          }
          return { status: 0, stdout: "", stderr: "" };
        },
      });
      assert.equal(res.total, 3);
      assert.equal(res.synced, 1);
      assert.deepEqual(
        res.drifted.map((m) => m.id),
        ["m_drifted"],
      );
      assert.deepEqual(res.drifted[0].changed_files, ["sketches/core-loop/src/combat/bolts.gd"]);
      assert.deepEqual(
        res.missing_sync.map((m) => m.id),
        ["m_nosync"],
      );
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("reads a changed path whose name holds a newline, a leading space and a quote as itself", () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-formal-odd-"));
    try {
      const refs = path.join(tmp, ".agents", "skills", "scrapkeep-verify-formal", "references");
      mkdirSync(refs, { recursive: true });
      writeFileSync(
        path.join(refs, "drifted.md"),
        "Covers `sketches/core-loop/src/combat/bolts.gd`.\nSynced at `1111111111`.\n",
        "utf8",
      );
      const odd = 'sketches/core-loop/src/combat/bolts.gd/ odd "name"\nline.gd';
      const res = auditFormalSync(tmp, {
        rows: { m_drifted: { spec: "B.tla", coverage: "references/drifted.md" } },
        spawn: (_cmd, args) => ({
          status: 0,
          stdout: args.includes("-z")
            ? `${odd}\0`
            : `"${odd.replace("\n", "\\n").replaceAll('"', '\\"')}"\n`,
          stderr: "",
        }),
      });
      assert.deepEqual(res.drifted[0].changed_files, [odd]);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("keeps git's failure message when git fails with only blank error output", () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-formal-blank-"));
    try {
      const refs = path.join(tmp, ".agents", "skills", "scrapkeep-verify-formal", "references");
      mkdirSync(refs, { recursive: true });
      writeFileSync(
        path.join(refs, "drifted.md"),
        "Covers `sketches/core-loop/src/combat/bolts.gd`.\nSynced at `1111111111`.\n",
        "utf8",
      );
      const res = auditFormalSync(tmp, {
        rows: { m_drifted: { spec: "B.tla", coverage: "references/drifted.md" } },
        spawn: () => ({ status: 128, stdout: "", stderr: " \n" }),
      });
      assert.equal(res.drifted[0].status, "git_error");
      assert.match(res.drifted[0].error, /^git -C .* diff -z --name-only 1111111111 .* failed:/);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe("runLedgerAudit", () => {
  it("starts at most one git process per formal model on the live repository and produces structured output", () => {
    const started = [];
    const spawn = (command, args, options) => {
      started.push([command, ...args].join(" "));
      return spawnSync(command, args, options);
    };
    const report = runLedgerAudit({ repoRoot: REPO_ROOT, today: "2026-11-26", spawn });
    assert.ok(started.length > 0 && started.length <= report.formal.total, started.join("\n"));
    assert.ok(
      started.every((line) => line.startsWith("git -C ")),
      started.join("\n"),
    );
    assert.ok(report.formal.total >= 10);
    assert.equal(typeof report.known_failing.red_count, "number");
    assert.deepEqual(report.known_failing.problems, [], "the checked-in ledger parses");
    assert.ok(report.known_failing.total > 0, "the checked-in ledger has rows");
    assert.equal(typeof report.placeholders.finding_count, "number");
    const formatted = formatLedgerAudit(report);
    assert.match(formatted, /KNOWN-FAILING\.tsv:/);
    assert.match(formatted, /placeholder-gate:/);
    assert.match(formatted, /formal-models:/);
  });
});
