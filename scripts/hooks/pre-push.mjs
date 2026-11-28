#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  KNOWN_FAILING_LEDGER,
  isGodotPath,
  isDocsPath,
  isPackagePath,
  isSkillPath,
  treeFiles,
} from "../ci/affected.mjs";
import { filterFormatTargets } from "../ci/format-changed.mjs";
import { ensureNodeModules } from "../ensure-node-modules.mjs";
import { isMain } from "../lib/cli.mjs";
import { REPO_ROOT, cwdDecidesRepository, git } from "../lib/git.mjs";
import { BASELINE_PATH, baselineGrowth, formatFinding, readBaselineAt } from "../sketch-lint.mjs";

const root = REPO_ROOT;
const SHA = /^(?:[0-9a-f]{40}|[0-9a-f]{64})$/;
const ZERO_SHA = /^0+$/;
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
  if (typeof text !== "string")
    throw new Error("no push on standard input: pipe in git's ref lines, or pass --base <ref>");
  const ranges = [];
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (!line) continue;
    const fields = line.split(/\s+/);
    const [, localSha, , remoteSha] = fields;
    if (fields.length !== 4 || !SHA.test(localSha) || !SHA.test(remoteSha))
      throw new Error(`cannot read the push line "${line}"`);
    if (ZERO_SHA.test(localSha)) continue;
    ranges.push({ localSha, remoteSha: ZERO_SHA.test(remoteSha) ? null : remoteSha });
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
  return [
    ...new Set(
      git(args, { cwd, spawn })
        .split("\n")
        .map((line) => line.trim())
        .filter(Boolean),
    ),
  ];
}

export function rangeBase({ localSha, remoteSha }, { cwd = root, spawn = spawnSync } = {}) {
  if (remoteSha) return remoteSha;
  const oldest = git(["rev-list", "--first-parent", localSha, "--not", "--remotes"], {
    cwd,
    spawn,
  })
    .split("\n")
    .filter(Boolean)
    .pop();
  return oldest ? `${oldest}^` : localSha;
}

export function pushedChanges(ranges, { cwd = root, spawn = spawnSync } = {}) {
  return ranges.map((range) => {
    const tree = treeFiles(range.localSha, { cwd, spawn, env: cwdDecidesRepository() });
    const files = changedFilesForRange(range, { cwd, spawn });
    const exists = (file) => tree.has(file);
    return {
      ...planHookChecks(files, exists),
      base: rangeBase(range, { cwd, spawn }),
      head: range.localSha,
      files,
      exists,
    };
  });
}

export function workingTreeDrift(pushed, { cwd = root, spawn = spawnSync } = {}) {
  const differs = new Set();
  for (const { head, files, exists } of pushed) {
    const tracked = git(["diff", "--no-renames", "--name-only", head], { cwd, spawn }).split("\n");
    const restored = files.filter((file) => !exists(file) && existsSync(path.join(cwd, file)));
    for (const file of [...tracked, ...restored]) if (file) differs.add(file);
  }
  return [...differs].sort();
}

export function planHookChecks(changedFiles, exists) {
  if (typeof exists !== "function")
    throw new Error("planHookChecks needs the pushed tree's file test");
  const jsFiles = filterFormatTargets(changedFiles, exists);
  const hasSketch = changedFiles.some(isGodotPath);
  const hasDocsOrPkg = changedFiles.some(
    (f) => isDocsPath(f, exists) || isPackagePath(f) || isSkillPath(f),
  );
  const hasSkills = changedFiles.some((f) => isSkillPath(f) || f === "scripts/check-skills.mjs");
  const hasBriefs = changedFiles.some((f) => BRIEFS_TRIGGER.test(f));
  const hasKnownFailing = changedFiles.includes(KNOWN_FAILING_LEDGER);
  const hasBaseline = changedFiles.includes(BASELINE_PATH);
  return { jsFiles, hasSketch, hasDocsOrPkg, hasSkills, hasBriefs, hasKnownFailing, hasBaseline };
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
  plans,
  {
    cwd = root,
    exists = existsSync,
    spawn = spawnSync,
    ensureModules = ensureNodeModules,
    errLog = console.error,
    readPushed = (head, file) => git(["show", `${head}:${file}`], { cwd, spawn, trim: false }),
    readBaseline = (ref) => readBaselineAt(ref, { cwd }),
    drift = () => [],
  } = {},
) {
  let ok = true;
  const ranLabels = [];
  const any = (key) => plans.some((plan) => plan[key]);
  const scripted = plans.filter((plan) => plan.jsFiles.length > 0);

  if (scripted.length > 0) {
    ensureModules(cwd);
    const oxfmt = binPath("oxfmt", cwd);
    const oxlint = binPath("oxlint", cwd);
    const count = scripted.reduce((sum, plan) => sum + plan.jsFiles.length, 0);
    if (!exists(oxfmt) || !exists(oxlint)) {
      ok = false;
      ranLabels.push("oxfmt/oxlint(missing)");
      errLog("pre-push: node_modules/.bin/{oxfmt,oxlint} missing; run npm ci to enable JS checks");
    } else {
      ranLabels.push(`oxfmt(${count})`, `oxlint(${count})`);
      for (const plan of scripted) {
        const copy = mkdtempSync(path.join(os.tmpdir(), "pre-push-"));
        try {
          for (const file of plan.jsFiles) {
            mkdirSync(path.dirname(path.join(copy, file)), { recursive: true });
            writeFileSync(path.join(copy, file), readPushed(plan.head, file));
          }
          const steps = [
            ["oxfmt", oxfmt, ["-c", path.join(cwd, "scripts/ci/oxfmt.json"), "--check"]],
            ["oxlint", oxlint, ["-c", path.join(cwd, "scripts/ci/oxlint.json")]],
          ];
          for (const [label, bin, args] of steps)
            if (!runStep(label, bin, [...args, ...plan.jsFiles], { cwd: copy, spawn }).ok)
              ok = false;
        } finally {
          rmSync(copy, { recursive: true, force: true });
        }
      }
    }
  }
  const onDisk = [];
  const step = (label, ...argv) => {
    ranLabels.push(label);
    onDisk.push(label);
    if (!runStep(label, process.execPath, argv, { cwd, spawn }).ok) ok = false;
  };
  const script = (file) => path.join(cwd, "scripts", file);
  if (any("hasSketch")) step("sketch:lint", script("sketch-lint.mjs"), "--sketch", "core-loop");
  if (any("hasDocsOrPkg")) {
    step("check:project", script("check-project.mjs"));
    step("check:docs", script("check-docs.mjs"));
  }
  if (any("hasSkills")) step("check:skills", script("check-skills.mjs"));
  if (any("hasBriefs")) step("check:briefs", script("brief-check.mjs"));
  if (any("hasBaseline")) {
    ranLabels.push("baseline");
    for (const { base, head } of plans.filter((plan) => plan.hasBaseline)) {
      const grew = baselineGrowth(readBaseline(base), readBaseline(head));
      for (const item of grew) errLog(formatFinding(item));
      if (grew.length > 0) ok = false;
    }
  }
  if (any("hasKnownFailing")) step("known-failing", "--test", script("known-failing.test.mjs"));
  if (onDisk.length > 0) {
    const differs = drift();
    if (differs.length > 0)
      errLog(
        `pre-push: ${onDisk.join(", ")} read the files on disk, which differ from what this push holds in ${differs.length} file(s): ${differs.slice(0, 8).join(", ")}${differs.length > 8 ? ", ..." : ""}`,
      );
  }

  return { ok, ranLabels };
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
    const ranges = opts.base
      ? [
          {
            localSha: git(["rev-parse", "HEAD"]),
            remoteSha: git(["merge-base", opts.base, "HEAD"]),
          },
        ]
      : parsePushStdin(process.stdin.isTTY ? null : readFileSync(0, "utf8"));
    const pushed = pushedChanges(ranges);
    const { ok, ranLabels } = executeHookPlan(pushed, { drift: () => workingTreeDrift(pushed) });
    const loadEnd = os.loadavg()[0];
    const elapsedS = (performance.now() - started) / 1000;
    const outcome = evaluateHookOutcome({
      ok,
      elapsedS,
      budgetS: HOOK_BUDGET_S,
      loadStart,
      loadEnd,
      cpus,
      ranLabels,
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
