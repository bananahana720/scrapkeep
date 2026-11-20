#!/usr/bin/env node
// Enforces a wall-clock budget on a CI check or job step.
// Usage: node scripts/ci/check-budget.mjs --label <name> --budget <seconds> -- <cmd> [args...]
// Exits with the child's exit code if the child fails; exits 1 if the child passes but exceeds
// the budget (so CI fails fast instead of silently slowing down).

import { spawnSync } from "node:child_process";
import { appendFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export function parseBudgetArgs(argv) {
  let label = null;
  let budgetS = null;
  let sep = argv.indexOf("--");
  if (sep < 0) throw new Error("usage: check-budget.mjs --label <name> --budget <seconds> -- <cmd> [args...]");
  const head = argv.slice(0, sep);
  const command = argv.slice(sep + 1);
  if (command.length === 0) throw new Error("missing command after --");
  for (let i = 0; i < head.length; i++) {
    const arg = head[i];
    if (arg === "--label" && head[i + 1]) label = head[++i];
    else if (arg === "--budget" && head[i + 1]) budgetS = Number(head[++i]);
    else throw new Error(`unknown argument: ${arg}`);
  }
  if (!label) throw new Error("--label is required");
  if (!Number.isFinite(budgetS) || budgetS <= 0) throw new Error("--budget must be a positive number of seconds");
  return { label, budgetS, command };
}

export function evaluateBudget({ label, budgetS, elapsedMs, exitCode, signal }) {
  const elapsedS = elapsedMs / 1000;
  const childOk = exitCode === 0 && !signal;
  const overBudget = elapsedS > budgetS;
  const status = !childOk ? "FAIL" : overBudget ? "OVER_BUDGET" : "PASS";
  const ok = childOk && !overBudget;
  return {
    label,
    budgetS,
    elapsedS: Number(elapsedS.toFixed(2)),
    exitCode: exitCode ?? 1,
    signal: signal ?? null,
    overBudget,
    status,
    ok,
  };
}

export function formatSummaryRow(result) {
  const icon = result.ok ? "PASS" : result.status;
  return `| ${result.label} | ${result.elapsedS.toFixed(2)}s | ${result.budgetS}s | ${icon} |\n`;
}

export function runWithBudget(argv, { spawn = spawnSync, now = () => performance.now(), summaryPath = process.env.GITHUB_STEP_SUMMARY, log = console.log, errLog = console.error } = {}) {
  const { label, budgetS, command } = parseBudgetArgs(argv);
  const started = now();
  const child = spawn(command[0], command.slice(1), { stdio: "inherit" });
  const elapsedMs = Math.max(0, now() - started);
  if (child.error) {
    errLog(`budget[${label}]: failed to spawn ${command[0]}: ${child.error.message}`);
    return { exit: 2, result: null };
  }
  const result = evaluateBudget({
    label,
    budgetS,
    elapsedMs,
    exitCode: child.status,
    signal: child.signal,
  });
  log(`budget[${result.label}]: ${result.elapsedS.toFixed(2)}s / ${result.budgetS}s (${result.status})`);
  if (summaryPath) {
    try {
      appendFileSync(summaryPath, formatSummaryRow(result));
    } catch {
      // Do not mask command verdict if summary path is unwritable.
    }
  }
  if (!result.ok) {
    if (result.overBudget && result.exitCode === 0) {
      errLog(`budget[${result.label}]: exceeded budget (${result.elapsedS.toFixed(2)}s > ${result.budgetS}s)`);
      return { exit: 1, result };
    }
    return { exit: result.exitCode || 1, result };
  }
  return { exit: 0, result };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  try {
    const { exit } = runWithBudget(process.argv.slice(2));
    process.exitCode = exit;
  } catch (error) {
    console.error(`check-budget: ${error.message}`);
    process.exitCode = 2;
  }
}
