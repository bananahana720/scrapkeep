#!/usr/bin/env node
// Fast (<9s) local pre-push hook: formats/lints changed JS/MJS files with oxfmt + oxlint,
// runs sketch-lint on Godot changes, and runs check:project / check:docs on doc/package changes.
// Enforces a hard 9s budget so local feedback stays snappy.
// Usage:
//   git push (invoked via scripts/hooks/pre-push with push refs on stdin)
//   node scripts/hooks/pre-push.mjs --base <ref>

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { filterFormatTargets } from "../ci/format-changed.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const ZERO_SHA = "0000000000000000000000000000000000000000";
export const HOOK_BUDGET_S = 9;

const DOCS_OR_PKG =
  /(?:\.md$|^package(?:-lock)?\.json$|^project-guide\/handoff\/(?:STATE\.md|DECISIONS\.md|KNOWN-FAILING\.tsv|WEEKLY\.tsv)|^\.agents\/skills\/|^\.claude\/skills\/)/;

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
  // Include deletions (no --diff-filter=ACM drop) so deleting a .md or sketch file still triggers
  // check:docs / sketch:lint; filterFormatTargets filters out deleted JS files via exists().
  // For new branches (remoteSha === null), walk all commits not yet on any remote (and handle merges).
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

export function planHookChecks(changedFiles, exists = (f) => existsSync(path.join(root, f))) {
  const jsFiles = filterFormatTargets(changedFiles, exists);
  const hasSketch = changedFiles.some((f) => f.startsWith("sketches/core-loop/"));
  const hasDocsOrPkg = changedFiles.some((f) => DOCS_OR_PKG.test(f));
  return { jsFiles, hasSketch, hasDocsOrPkg };
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

function binPath(name) {
  return path.join(
    root,
    "node_modules",
    ".bin",
    process.platform === "win32" ? `${name}.cmd` : name,
  );
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

function isMain() {
  if (!process.argv[1]) return false;
  try {
    return realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1]);
  } catch {
    return fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
  }
}

if (isMain()) {
  const started = performance.now();
  try {
    const opts = parseHookArgs(process.argv.slice(2));
    let files = [];
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
      const ranges = parsePushStdin(stdin);
      files = [...new Set(ranges.flatMap((range) => changedFilesForRange(range)))];
    }

    const plan = planHookChecks(files);
    let ok = true;
    const ranLabels = [];

    if (plan.jsFiles.length > 0) {
      const oxfmt = binPath("oxfmt");
      const oxlint = binPath("oxlint");
      if (!existsSync(oxfmt) || !existsSync(oxlint)) {
        ranLabels.push("js-lint/format skipped (missing node_modules; run npm ci)");
        console.warn(
          "pre-push: node_modules/.bin/{oxfmt,oxlint} missing; run npm ci to enable JS checks",
        );
      } else {
        ranLabels.push(`oxfmt(${plan.jsFiles.length})`);
        const r1 = runStep("oxfmt", oxfmt, [
          "-c",
          path.join(root, "scripts/ci/oxfmt.json"),
          "--check",
          ...plan.jsFiles,
        ]);
        if (!r1.ok) ok = false;
        if (ok) {
          ranLabels.push(`oxlint(${plan.jsFiles.length})`);
          const r2 = runStep("oxlint", oxlint, [
            "-c",
            path.join(root, "scripts/ci/oxlint.json"),
            ...plan.jsFiles,
          ]);
          if (!r2.ok) ok = false;
        }
      }
    }
    if (ok && plan.hasSketch) {
      ranLabels.push("sketch:lint");
      const r = runStep("sketch:lint", process.execPath, [
        path.join(root, "scripts/sketch-lint.mjs"),
        "--sketch",
        "core-loop",
      ]);
      if (!r.ok) ok = false;
    }
    if (ok && plan.hasDocsOrPkg) {
      ranLabels.push("check:project");
      const r1 = runStep("check:project", process.execPath, [
        path.join(root, "scripts/check-project.mjs"),
      ]);
      if (!r1.ok) ok = false;
      if (ok) {
        ranLabels.push("check:docs");
        const r2 = runStep("check:docs", process.execPath, [
          path.join(root, "scripts/check-docs.mjs"),
        ]);
        if (!r2.ok) ok = false;
      }
    }

    const elapsedS = (performance.now() - started) / 1000;
    const elapsedDisplay =
      elapsedS > HOOK_BUDGET_S && elapsedS.toFixed(2) === HOOK_BUDGET_S.toFixed(2)
        ? elapsedS.toFixed(3)
        : elapsedS.toFixed(2);
    const summary = ranLabels.length > 0 ? ranLabels.join(", ") : "no matching files";
    if (!ok) {
      console.error(`pre-push: FAIL in ${elapsedDisplay}s (${summary})`);
      process.exitCode = 1;
    } else if (elapsedS > HOOK_BUDGET_S) {
      console.error(`pre-push: OVER_BUDGET (${elapsedDisplay}s > ${HOOK_BUDGET_S}s; ${summary})`);
      process.exitCode = 1;
    } else {
      console.log(`pre-push: PASS in ${elapsedDisplay}s / ${HOOK_BUDGET_S}s (${summary})`);
      process.exitCode = 0;
    }
  } catch (error) {
    console.error(`pre-push: ${error.message}`);
    process.exitCode = 2;
  }
}
