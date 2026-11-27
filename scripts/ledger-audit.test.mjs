import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import {
  auditFormalSync,
  formatLedgerAudit,
  parseKnownFailingTsv,
  REPO_ROOT,
  runLedgerAudit,
} from "./ledger-audit.mjs";

describe("parseKnownFailingTsv", () => {
  it("classifies red, flake, and overdue rows against the supplied date", () => {
    const tsv = [
      "test\tkind\tcause\towner\tadded\treview\tcheck",
      "alpha_test\tred\tbroken\ttesting\t2026-11-01\t2026-11-20\tc1",
      "beta_test\tflake\tload\tcoord\t2026-11-05\t2026-12-01\t-",
      "gamma_test\tflake\tload\tcoord\t2026-11-05\t2026-11-25\t-",
    ].join("\n");
    const parsed = parseKnownFailingTsv(tsv, { today: "2026-11-26" });
    assert.equal(parsed.total, 3);
    assert.deepEqual(
      parsed.reds.map((r) => r.test),
      ["alpha_test"],
    );
    assert.deepEqual(
      parsed.flakes.map((r) => r.test),
      ["beta_test", "gamma_test"],
    );
    assert.deepEqual(
      parsed.overdue.map((r) => r.test),
      ["alpha_test", "gamma_test"],
    );
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
          const sync = args[args.indexOf("--name-only") + 1];
          if (sync === "1111111111") {
            return { status: 0, stdout: "sketches/core-loop/src/combat/bolts.gd\n", stderr: "" };
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
});

describe("runLedgerAudit", () => {
  it("runs quickly (<2000ms) on the live repository and produces structured output", () => {
    const report = runLedgerAudit({ repoRoot: REPO_ROOT, today: "2026-11-26" });
    assert.ok(report.ms < 2000, `expected ledger-audit < 2000ms, got ${report.ms}ms`);
    assert.ok(report.formal.total >= 10);
    assert.equal(typeof report.known_failing.red_count, "number");
    assert.equal(typeof report.placeholders.finding_count, "number");
    const formatted = formatLedgerAudit(report);
    assert.match(formatted, /KNOWN-FAILING\.tsv:/);
    assert.match(formatted, /placeholder-gate:/);
    assert.match(formatted, /formal-models:/);
  });
});
