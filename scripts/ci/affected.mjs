#!/usr/bin/env node
// Classifies a git diff into affected CI surfaces so PR feedback runs only what the diff can reach,
// while full-suite triggers (merge_group, push to main/stage/*, workflow_dispatch full) run everything.
// Usage: node scripts/ci/affected.mjs [--base <ref>] [--full] [--github-output <path>]

import { spawnSync } from "node:child_process";
import { appendFileSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const WEB_PATTERN =
  /^(index\.html|orchard\.html|vite\.config\.js|package\.json|package-lock\.json|public\/|src\/|server\/|scripts\/check-build\.mjs|scripts\/verify\.mjs)/;
const GODOT_PATTERN =
  /^(sketches\/core-loop\/|scripts\/sketch-(?:fast|smoke|lint)|scripts\/import-stamp\.mjs|scripts\/godot-home\.mjs|scripts\/known-failing\.mjs|scripts\/placeholder-gate\.mjs|project-guide\/handoff\/KNOWN-FAILING\.tsv)/;
const NODE_PATTERN =
  /^(package\.json|package-lock\.json|scripts\/|tests\/|tools\/|src\/|server\/|project-guide\/handoff\/sitting-kit\/|\.github\/workflows\/)/;
const DOCS_PATTERN =
  /(\.md$|^project-guide\/handoff\/(?:STATE\.md|DECISIONS\.md|KNOWN-FAILING\.tsv|WEEKLY\.tsv)|^\.agents\/skills\/|^\.claude\/skills\/|^scripts\/(?:check-docs|check-project|check-skills|brief-check|wave-state|known-failing))/;
const WORKFLOW_PATTERN = /^(\.github\/workflows\/|scripts\/ci\/)/;

export function classifyAffected(changedFiles, { full = false } = {}) {
  if (full) {
    return {
      full: true,
      lint: true,
      docs: true,
      node: true,
      web: true,
      godot: true,
      changedCount: changedFiles.length,
    };
  }
  const files = changedFiles.filter(Boolean);
  const workflowTouched = files.some((f) => WORKFLOW_PATTERN.test(f));
  const web = workflowTouched || files.some((f) => WEB_PATTERN.test(f));
  const godot = files.some((f) => GODOT_PATTERN.test(f));
  const node = workflowTouched || godot || web || files.some((f) => NODE_PATTERN.test(f));
  const docs = workflowTouched || files.some((f) => DOCS_PATTERN.test(f));
  return {
    full: false,
    lint: true,
    docs,
    node,
    web,
    godot,
    changedCount: files.length,
  };
}

export function diffFiles(baseRef, { cwd = process.cwd(), spawn = spawnSync } = {}) {
  const ran = spawn("git", ["diff", "--name-only", `${baseRef}...HEAD`], { cwd, encoding: "utf8" });
  if (ran.status !== 0) {
    throw new Error(
      `git diff against ${baseRef} failed: ${(ran.stderr || ran.stdout || "").trim()}`,
    );
  }
  return ran.stdout
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function parseArgs(argv) {
  const opts = {
    base: null,
    full: false,
    stdin: false,
    githubOutput: process.env.GITHUB_OUTPUT || null,
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--base" && argv[i + 1]) opts.base = argv[++i];
    else if (arg === "--full") opts.full = true;
    else if (arg === "--stdin") opts.stdin = true;
    else if (arg === "--github-output" && argv[i + 1]) opts.githubOutput = argv[++i];
    else throw new Error(`unknown argument: ${arg}`);
  }
  return opts;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  try {
    const opts = parseArgs(process.argv.slice(2));
    let files = [];
    let full = opts.full;
    if (!full) {
      if (opts.stdin) {
        files = readFileSync(0, "utf8")
          .split("\n")
          .map((line) => line.trim())
          .filter(Boolean);
      } else if (opts.base) {
        files = diffFiles(opts.base);
      } else {
        full = true;
      }
    }
    const result = classifyAffected(files, { full });
    console.log(JSON.stringify(result));
    if (opts.githubOutput) {
      const lines =
        Object.entries(result)
          .map(([k, v]) => `${k}=${v}`)
          .join("\n") + "\n";
      appendFileSync(opts.githubOutput, lines);
    }
  } catch (error) {
    console.error(`affected: ${error.message}`);
    process.exitCode = 2;
  }
}
