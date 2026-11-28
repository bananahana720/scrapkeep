#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  KNOWN_FAILING_LEDGER,
  isGodotPath,
  isDocsPath,
  isPackagePath,
  isSkillPath,
} from "../ci/affected.mjs";
import { filterFormatTargets } from "../ci/format-changed.mjs";
import { datedRecordPaths } from "../dated-records.mjs";
import { ensureNodeModules } from "../ensure-node-modules.mjs";
import { isMain } from "../lib/cli.mjs";
import { REPO_ROOT } from "../lib/git.mjs";

const root = REPO_ROOT;
const ZERO_SHA = "0000000000000000000000000000000000000000";
export const HOOK_BUDGET_S = 9;
export const HIGH_LOAD_RATIO = 0.5;

export function isHighLoad({ loadStart, loadEnd, cpus }) {
  if (!Number.isFinite(cpus) || cpus <= 0) return false;
  const peak = Math.max(
    Number.isFinite(loadStart) ? loadStart : 0,
    Number.isFinite(loadEnd) ? loadEnd : 0,
  );
  return peak >= cpus * HIGH_LOAD_RATIO;
}

const BRIEFS_TRIGGER = /(?:^|\/)sound\/briefs\/|^scripts\/brief-check\.mjs$/;

export function parsePushStdin(text) {
  const ranges = [];
  for (const raw of (text || "").split("\n")) {
    const line = raw.trim();
    if (!line) continue;
    const [, localSha, , remoteSha] = line.split(/\s+/);
    if (!localSha || localSha === ZERO_SHA) continue;
    ranges.push({ localSha, remoteSha: remoteSha && remoteSha !== ZERO_SHA ? remoteSha : null });
  }
  return ranges;
}

export function changedFilesForRange(
  { localSha, remoteSha },
  { cwd = root, spawn = spawnSync } = {},
) {
  const args = remoteSha
    ? ["diff", "--no-renames", "--name-only", `${remoteSha}..${localSha}`]
    : [
        "log",
        "--no-renames",
        "--name-only",
        "--pretty=format:",
        "-m",
        "--first-parent",
        localSha,
        "--not",
        "--remotes",
      ];
  const ran = spawn("git", args, { cwd, encoding: "utf8" });
  if (ran.error || ran.status !== 0) {
    throw new Error(
      `git ${args[0]} failed: ${ran.error?.message || (ran.stderr || ran.stdout || "").trim()}`,
    );
  }
  return [
    ...new Set(
      ran.stdout
        .split("\n")
        .map((line) => line.trim())
        .filter(Boolean),
    ),
  ];
}

export function rangeBase({ localSha, remoteSha }, { cwd = root, spawn = spawnSync } = {}) {
  if (remoteSha) return remoteSha;
  const ran = spawn("git", ["rev-list", "--first-parent", localSha, "--not", "--remotes"], {
    cwd,
    encoding: "utf8",
  });
  if (ran.error || ran.status !== 0) {
    throw new Error(
      `git rev-list failed: ${ran.error?.message || (ran.stderr || ran.stdout || "").trim()}`,
    );
  }
  const oldest = ran.stdout.trim().split("\n").filter(Boolean).pop();
  return oldest ? `${oldest}^` : localSha;
}

export function planHookChecks(changedFiles, exists = (f) => existsSync(path.join(root, f))) {
  const jsFiles = filterFormatTargets(changedFiles, exists);
  const hasSketch = changedFiles.some(isGodotPath);
  const hasDocsOrPkg = changedFiles.some(
    (f) => isDocsPath(f) || isPackagePath(f) || isSkillPath(f),
  );
  const hasSkills = changedFiles.some((f) => isSkillPath(f) || f === "scripts/check-skills.mjs");
  const hasBriefs = changedFiles.some((f) => BRIEFS_TRIGGER.test(f));
  const hasKnownFailing = changedFiles.includes(KNOWN_FAILING_LEDGER);
  return { jsFiles, hasSketch, hasDocsOrPkg, hasSkills, hasBriefs, hasKnownFailing };
}

function runStep(label, cmd, args, { cwd = root, spawn = spawnSync } = {}) {
  const t0 = performance.now();
  const ran = spawn(cmd, args, { cwd, stdio: "inherit" });
  const ms = Math.round(performance.now() - t0);
  if (ran.error) {
    console.error(`pre-push[${label}]: failed to start ${cmd}: ${ran.error.message}`);
    return { ok: false, ms };
  }
  return { ok: ran.status === 0, ms };
}

function binPath(name, cwd = root) {
  return path.join(
    cwd,
    "node_modules",
    ".bin",
    process.platform === "win32" ? `${name}.cmd` : name,
  );
}

export function executeHookPlan(
  plan,
  {
    cwd = root,
    exists = existsSync,
    spawn = spawnSync,
    ensureModules = ensureNodeModules,
    errLog = console.error,
  } = {},
) {
  let ok = true;
  const ranLabels = [];

  if (plan.jsFiles.length > 0) {
    ensureModules(cwd);
    const oxfmt = binPath("oxfmt", cwd);
    const oxlint = binPath("oxlint", cwd);
    if (!exists(oxfmt) || !exists(oxlint)) {
      ok = false;
      ranLabels.push("oxfmt/oxlint(missing)");
      errLog("pre-push: node_modules/.bin/{oxfmt,oxlint} missing; run npm ci to enable JS checks");
    } else {
      ranLabels.push(`oxfmt(${plan.jsFiles.length})`);
      const r1 = runStep(
        "oxfmt",
        oxfmt,
        ["-c", path.join(cwd, "scripts/ci/oxfmt.json"), "--check", ...plan.jsFiles],
        { cwd, spawn },
      );
      if (!r1.ok) ok = false;

      ranLabels.push(`oxlint(${plan.jsFiles.length})`);
      const r2 = runStep(
        "oxlint",
        oxlint,
        ["-c", path.join(cwd, "scripts/ci/oxlint.json"), ...plan.jsFiles],
        { cwd, spawn },
      );
      if (!r2.ok) ok = false;
    }
  }
  if (plan.hasSketch) {
    ranLabels.push("sketch:lint");
    const r = runStep(
      "sketch:lint",
      process.execPath,
      [path.join(cwd, "scripts/sketch-lint.mjs"), "--sketch", "core-loop"],
      { cwd, spawn },
    );
    if (!r.ok) ok = false;
  }
  if (plan.hasDocsOrPkg) {
    ranLabels.push("check:project");
    const r1 = runStep(
      "check:project",
      process.execPath,
      [path.join(cwd, "scripts/check-project.mjs")],
      {
        cwd,
        spawn,
      },
    );
    if (!r1.ok) ok = false;

    ranLabels.push("check:docs");
    const r2 = runStep("check:docs", process.execPath, [path.join(cwd, "scripts/check-docs.mjs")], {
      cwd,
      spawn,
    });
    if (!r2.ok) ok = false;
  }
  if (plan.hasSkills) {
    ranLabels.push("check:skills");
    const r = runStep(
      "check:skills",
      process.execPath,
      [path.join(cwd, "scripts/check-skills.mjs")],
      { cwd, spawn },
    );
    if (!r.ok) ok = false;
  }
  if (plan.hasBriefs) {
    ranLabels.push("check:briefs");
    const r = runStep(
      "check:briefs",
      process.execPath,
      [path.join(cwd, "scripts/brief-check.mjs")],
      { cwd, spawn },
    );
    if (!r.ok) ok = false;
  }
  if (plan.hasKnownFailing) {
    ranLabels.push("known-failing");
    const r = runStep(
      "known-failing",
      process.execPath,
      ["--test", path.join(cwd, "scripts/known-failing.test.mjs")],
      { cwd, spawn },
    );
    if (!r.ok) ok = false;
  }

  return { ok, ranLabels };
}

export function runDatedRecords(
  files,
  ranges,
  { cwd = root, spawn = spawnSync, watched = datedRecordPaths(cwd) } = {},
) {
  if (watched && !files.some((f) => watched.has(f))) return { ok: true, ranLabels: [] };
  let ok = true;
  for (const { base, head } of ranges) {
    const r = runStep(
      "dated-records",
      process.execPath,
      [path.join(cwd, "scripts/dated-records.mjs"), "--base", base, "--head", head],
      { cwd, spawn },
    );
    if (!r.ok) ok = false;
  }
  return { ok, ranLabels: [`dated-records(${ranges.length})`] };
}

export function evaluateHookOutcome({
  ok,
  elapsedS,
  budgetS = HOOK_BUDGET_S,
  loadStart,
  loadEnd,
  cpus,
  ranLabels = [],
}) {
  const elapsedDisplay =
    elapsedS > budgetS && elapsedS.toFixed(2) === budgetS.toFixed(2)
      ? elapsedS.toFixed(3)
      : elapsedS.toFixed(2);
  const summary = ranLabels.length > 0 ? ranLabels.join(", ") : "no matching files";
  if (!ok) {
    return {
      exitCode: 1,
      status: "FAIL",
      message: `pre-push: FAIL in ${elapsedDisplay}s (${summary})`,
    };
  }
  if (elapsedS > budgetS) {
    if (isHighLoad({ loadStart, loadEnd, cpus })) {
      const peak = Math.max(
        Number.isFinite(loadStart) ? loadStart : 0,
        Number.isFinite(loadEnd) ? loadEnd : 0,
      );
      return {
        exitCode: 0,
        status: "PASS_UNDER_LOAD",
        message: `pre-push: PASS_UNDER_LOAD (${elapsedDisplay}s > ${budgetS}s; load=${peak.toFixed(2)}/${cpus}; ${summary})`,
      };
    }
    return {
      exitCode: 1,
      status: "OVER_BUDGET",
      message: `pre-push: OVER_BUDGET (${elapsedDisplay}s > ${budgetS}s; ${summary})`,
    };
  }
  return {
    exitCode: 0,
    status: "PASS",
    message: `pre-push: PASS in ${elapsedDisplay}s / ${budgetS}s (${summary})`,
  };
}

export function parseHookArgs(argv) {
  const opts = { base: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--base") {
      if (i + 1 >= argv.length || !argv[i + 1] || argv[i + 1].startsWith("-")) {
        throw new Error("--base requires a ref");
      }
      opts.base = argv[++i];
    } else {
      throw new Error(`unknown argument: ${argv[i]}`);
    }
  }
  return opts;
}

if (isMain(import.meta.url)) {
  const started = performance.now();
  const loadStart = os.loadavg()[0];
  const cpus = os.cpus().length;
  try {
    const opts = parseHookArgs(process.argv.slice(2));
    let files = [];
    let ranges = [];
    if (opts.base) {
      const ran = spawnSync("git", ["diff", "--no-renames", "--name-only", `${opts.base}...HEAD`], {
        cwd: root,
        encoding: "utf8",
      });
      if (ran.error || ran.status !== 0) {
        throw new Error(`git diff failed: ${ran.error?.message || (ran.stderr || "").trim()}`);
      }
      files = ran.stdout
        .split("\n")
        .map((l) => l.trim())
        .filter(Boolean);
    } else {
      const stdin = process.stdin.isTTY ? "" : readFileSync(0, "utf8");
      const pushed = parsePushStdin(stdin);
      files = [...new Set(pushed.flatMap((range) => changedFilesForRange(range)))];
      ranges = pushed.map((range) => ({ base: rangeBase(range), head: range.localSha }));
    }

    const dated = runDatedRecords(files, opts.base ? [{ base: opts.base, head: "HEAD" }] : ranges);
    const plan = planHookChecks(files);
    const { ok, ranLabels } = executeHookPlan(plan);
    const loadEnd = os.loadavg()[0];
    const elapsedS = (performance.now() - started) / 1000;
    const outcome = evaluateHookOutcome({
      ok: ok && dated.ok,
      elapsedS,
      budgetS: HOOK_BUDGET_S,
      loadStart,
      loadEnd,
      cpus,
      ranLabels: [...ranLabels, ...dated.ranLabels],
    });
    if (outcome.exitCode === 0) {
      console.log(outcome.message);
    } else {
      console.error(outcome.message);
    }
    process.exitCode = outcome.exitCode;
  } catch (error) {
    console.error(`pre-push: ${error.message}`);
    process.exitCode = 2;
  }
}
