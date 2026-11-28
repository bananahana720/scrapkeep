#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { coveredFiles, ROWS as MODEL_ROWS, syncCommit } from "./gate/model-receipts.mjs";
import { isMain } from "./lib/cli.mjs";
import { primStandIns, scan as scanPlaceholders } from "./placeholder-gate.mjs";
import { git, nulSeparated } from "./lib/git.mjs";

export const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const KNOWN_FAILING_REL = path.join("project-guide", "handoff", "KNOWN-FAILING.tsv");
const FORMAL_SKILL_REL = path.join(".agents", "skills", "scrapkeep-verify-formal");

export function parseKnownFailingTsv(text, { today = new Date().toISOString().slice(0, 10) } = {}) {
  const lines = String(text)
    .split(/\r?\n/)
    .map((line) => line.trimEnd())
    .filter((line) => line.trim() !== "");
  if (lines.length === 0) {
    return { total: 0, reds: [], flakes: [], overdue: [], rows: [] };
  }
  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const cells = lines[i].split("\t");
    if (cells.length < 7) continue;
    const [test, kind, cause, owner, added, review, check] = cells;
    const isOverdue = /^\d{4}-\d{2}-\d{2}$/.test(review) && review < today;
    rows.push({ test, kind, cause, owner, added, review, check, overdue: isOverdue });
  }
  return {
    total: rows.length,
    reds: rows.filter((r) => r.kind === "red"),
    flakes: rows.filter((r) => r.kind === "flake"),
    overdue: rows.filter((r) => r.overdue),
    rows,
  };
}

export function auditFormalSync(
  repoRoot = REPO_ROOT,
  { spawn = spawnSync, rows = MODEL_ROWS } = {},
) {
  const models = [];
  const drifted = [];
  const missingSync = [];
  for (const [id, row] of Object.entries(rows)) {
    const coveragePath = path.join(repoRoot, FORMAL_SKILL_REL, row.coverage);
    if (!existsSync(coveragePath)) {
      const entry = {
        id,
        spec: row.spec,
        coverage: row.coverage,
        sync: null,
        covered_count: 0,
        changed_files: [],
        status: "missing_coverage",
      };
      models.push(entry);
      missingSync.push(entry);
      continue;
    }
    const text = readFileSync(coveragePath, "utf8");
    const sync = syncCommit(text);
    const files = coveredFiles(text);
    if (!sync) {
      const entry = {
        id,
        spec: row.spec,
        coverage: row.coverage,
        sync: null,
        covered_count: files.length,
        changed_files: [],
        status: "missing_sync",
      };
      models.push(entry);
      missingSync.push(entry);
      continue;
    }
    let changed = [];
    if (files.length > 0) {
      try {
        changed = nulSeparated(
          git(["-C", repoRoot, "diff", "-z", "--name-only", sync, "--", ...files], {
            spawn,
            trim: false,
          }),
        );
      } catch (error) {
        const entry = {
          id,
          spec: row.spec,
          coverage: row.coverage,
          sync,
          covered_count: files.length,
          changed_files: [],
          status: "git_error",
          error: String(error?.stderr ?? "").trim() || String(error?.message ?? error),
        };
        models.push(entry);
        drifted.push(entry);
        continue;
      }
    }
    const status = changed.length > 0 ? "drifted" : "synced";
    const entry = {
      id,
      spec: row.spec,
      coverage: row.coverage,
      sync,
      covered_count: files.length,
      changed_files: changed,
      status,
    };
    models.push(entry);
    if (status === "drifted") drifted.push(entry);
  }
  return {
    total: models.length,
    synced: models.filter((m) => m.status === "synced").length,
    drifted,
    missing_sync: missingSync,
    models,
  };
}

export function runLedgerAudit({
  repoRoot = REPO_ROOT,
  sketchRel = path.join("sketches", "core-loop"),
  today = new Date().toISOString().slice(0, 10),
  spawn = spawnSync,
} = {}) {
  const started = Date.now();
  const knownFailingPath = path.join(repoRoot, KNOWN_FAILING_REL);
  const knownFailing = existsSync(knownFailingPath)
    ? parseKnownFailingTsv(readFileSync(knownFailingPath, "utf8"), { today })
    : { total: 0, reds: [], flakes: [], overdue: [], rows: [] };

  const sketchDir = path.join(repoRoot, sketchRel);
  const placeholderFindings = existsSync(sketchDir) ? scanPlaceholders(sketchDir) : [];
  const byKind = {};
  for (const item of placeholderFindings) {
    byKind[item.kind] = (byKind[item.kind] ?? 0) + (item.count ?? 1);
  }
  const standIns = existsSync(sketchDir) ? primStandIns(sketchDir) : {};
  const standInTotal = Object.values(standIns).reduce((sum, n) => sum + n, 0);

  const formal = auditFormalSync(repoRoot, { spawn });
  const ms = Date.now() - started;

  const clean =
    knownFailing.reds.length === 0 &&
    knownFailing.overdue.length === 0 &&
    placeholderFindings.length === 0 &&
    formal.drifted.length === 0 &&
    formal.missing_sync.length === 0;

  return {
    ok: clean,
    today,
    ms,
    known_failing: {
      path: KNOWN_FAILING_REL,
      total: knownFailing.total,
      red_count: knownFailing.reds.length,
      flake_count: knownFailing.flakes.length,
      overdue_count: knownFailing.overdue.length,
      reds: knownFailing.reds.map((r) => ({ test: r.test, owner: r.owner, review: r.review })),
      overdue: knownFailing.overdue.map((r) => ({
        test: r.test,
        kind: r.kind,
        owner: r.owner,
        review: r.review,
      })),
    },
    placeholders: {
      finding_count: placeholderFindings.length,
      total_items: placeholderFindings.reduce((sum, f) => sum + (f.count ?? 1), 0),
      by_kind: byKind,
      stand_in_pins: standIns,
      stand_in_total: standInTotal,
    },
    formal: {
      total: formal.total,
      synced: formal.synced,
      drifted_count: formal.drifted.length,
      missing_sync_count: formal.missing_sync.length,
      drifted: formal.drifted.map((m) => ({
        id: m.id,
        sync: m.sync,
        changed_files: m.changed_files,
      })),
      missing_sync: formal.missing_sync.map((m) => ({ id: m.id, status: m.status })),
    },
  };
}

export function formatLedgerAudit(report) {
  const lines = [
    `ledger-audit ${report.ok ? "CLEAN" : "ATTENTION"} (${report.ms}ms, as of ${report.today})`,
    `  KNOWN-FAILING.tsv: total=${report.known_failing.total} red=${report.known_failing.red_count} flake=${report.known_failing.flake_count} overdue=${report.known_failing.overdue_count}`,
  ];
  for (const r of report.known_failing.reds) {
    lines.push(`    red: ${r.test} (owner=${r.owner}, review=${r.review})`);
  }
  for (const r of report.known_failing.overdue) {
    lines.push(`    overdue: ${r.test} [${r.kind}] (review=${r.review})`);
  }
  lines.push(
    `  placeholder-gate: findings=${report.placeholders.finding_count} items=${report.placeholders.total_items} stand_in_pins=${report.placeholders.stand_in_total}`,
  );
  lines.push(
    `  formal-models: synced=${report.formal.synced}/${report.formal.total} drifted=${report.formal.drifted_count} missing_sync=${report.formal.missing_sync_count}`,
  );
  for (const m of report.formal.drifted) {
    lines.push(`    drifted: ${m.id} since ${m.sync} (${m.changed_files.join(", ")})`);
  }
  return lines.join("\n");
}

if (isMain(import.meta.url)) {
  const argv = process.argv.slice(2);
  const json = argv.includes("--json");
  const strict = argv.includes("--strict");
  const report = runLedgerAudit();
  if (json) console.log(JSON.stringify(report, null, 2));
  else console.log(formatLedgerAudit(report));
  process.exitCode = strict && !report.ok ? 1 : 0;
}
