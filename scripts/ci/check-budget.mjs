#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { appendFileSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export function parseBudgetArgs(argv) {
  let label = null;
  let budgetS = null;
  const sep = argv.indexOf("--");
  if (sep < 0) {
    throw new Error("usage: check-budget.mjs --label <name> --budget <seconds> -- <cmd> [args...]");
  }
  const head = argv.slice(0, sep);
  const command = argv.slice(sep + 1);
  if (command.length === 0) throw new Error("missing command after --");
  for (let i = 0; i < head.length; i++) {
    const arg = head[i];
    if (arg === "--label") {
      if (i + 1 >= head.length) throw new Error("--label requires a value");
      label = head[++i];
    } else if (arg === "--budget") {
      if (i + 1 >= head.length) throw new Error("--budget requires a value");
      budgetS = Number(head[++i]);
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!label) throw new Error("--label is required");
  if (!Number.isFinite(budgetS) || budgetS <= 0) {
    throw new Error("--budget must be a positive number of seconds");
  }
  return { label, budgetS, command };
}

export function evaluateBudget({ label, budgetS, elapsedMs, exitCode, signal }) {
  const exactS = elapsedMs / 1000;
  const childOk = exitCode === 0 && !signal;
  const overBudget = exactS > budgetS;
  const status = !childOk ? "FAIL" : overBudget ? "OVER_BUDGET" : "PASS";
  const ok = childOk && !overBudget;
  const elapsedDisplay =
    overBudget && exactS.toFixed(2) === budgetS.toFixed(2) ? exactS.toFixed(3) : exactS.toFixed(2);
  return {
    label,
    budgetS,
    elapsedS: Number(exactS.toFixed(3)),
    elapsedDisplay,
    exitCode: exitCode ?? 1,
    signal: signal ?? null,
    overBudget,
    status,
    ok,
  };
}

export function formatSummaryRow(result) {
  const icon = result.ok ? "PASS" : result.status;
  return `| ${result.label} | ${result.elapsedDisplay}s | ${result.budgetS}s | ${icon} |\n`;
}

export function runWithBudget(
  argv,
  {
    spawn = spawnSync,
    now = () => performance.now(),
    summaryPath = process.env.GITHUB_STEP_SUMMARY,
    log = console.log,
    errLog = console.error,
  } = {},
) {
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
  log(`budget[${result.label}]: ${result.elapsedDisplay}s / ${result.budgetS}s (${result.status})`);
  if (summaryPath) {
    try {
      appendFileSync(summaryPath, formatSummaryRow(result));
    } catch {}
  }
  if (!result.ok) {
    if (result.overBudget && result.exitCode === 0 && !result.signal) {
      errLog(
        `budget[${result.label}]: exceeded budget (${result.elapsedDisplay}s > ${result.budgetS}s)`,
      );
      return { exit: 1, result };
    }
    return { exit: result.exitCode || 1, result };
  }
  return { exit: 0, result };
}

function isMain() {
  if (!process.argv[1]) return false;
  try {
    return realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1]);
  } catch {
    return fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
  }
}

if (isMain()) {
  try {
    const { exit } = runWithBudget(process.argv.slice(2));
    process.exitCode = exit;
  } catch (error) {
    console.error(`check-budget: ${error.message}`);
    process.exitCode = 2;
  }
}
