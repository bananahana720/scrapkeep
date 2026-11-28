#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { appendFileSync, readFileSync } from "node:fs";
import { isMain } from "../lib/cli.mjs";

export const KNOWN_FAILING_LEDGER = "project-guide/handoff/KNOWN-FAILING.tsv";
const WEB_PATTERN =
  /^(index\.html|orchard\.html|vite\.config\.js|package\.json|package-lock\.json|public\/|src\/|server\/|scripts\/check-build\.mjs|scripts\/verify\.mjs)/;
const GODOT_PATTERN = /^sketches\/core-loop\//;
const PACKAGE_PATTERN = /^package(?:-lock)?\.json$/;
const HANDOFF_DOC_PATTERN =
  /(?:\.md$|^project-guide\/handoff\/(?:STATE\.md|DECISIONS\.md|KNOWN-FAILING\.tsv|WEEKLY\.tsv))/;
const SKILL_PATTERN = /^\.(?:agents|claude)\/skills\//;
const AGENT_CONFIG_PATTERN = /^\.(?:agents|claude|codex)\//;
const DOCS_SCRIPT_PATTERN =
  /^scripts\/(?:check-docs|check-project|check-skills|check-agents\.mjs|brief-check|wave-state|known-failing|gate\/weekly)/;
const NODE_PATTERN =
  /^(package\.json|package-lock\.json|scripts\/|tests\/|tools\/|src\/|server\/|project-guide\/handoff\/sitting-kit\/|\.github\/(?:workflows|actions)\/)/;
const WORKFLOW_PATTERN = /^(\.github\/(?:workflows|actions)\/|scripts\/ci\/)/;

export const isWebPath = (file) => WEB_PATTERN.test(file);
export const isGodotPath = (file) => GODOT_PATTERN.test(file);
export const isPackagePath = (file) => PACKAGE_PATTERN.test(file);
export const isHandoffDocPath = (file) => HANDOFF_DOC_PATTERN.test(file);
export const isSkillPath = (file) => SKILL_PATTERN.test(file);
export const isAgentConfigPath = (file) => AGENT_CONFIG_PATTERN.test(file);
export const isDocsPath = (file) =>
  isHandoffDocPath(file) || isAgentConfigPath(file) || DOCS_SCRIPT_PATTERN.test(file);
export const isNodePath = (file) => NODE_PATTERN.test(file);
export const isWorkflowPath = (file) => WORKFLOW_PATTERN.test(file);

export function classifyAffected(changedFiles, { full = false } = {}) {
  const files = changedFiles.filter(Boolean);
  if (full || files.length === 0) {
    return {
      full: true,
      lint: true,
      docs: true,
      node: true,
      web: true,
      godot: true,
      changedCount: files.length,
    };
  }
  const workflowTouched = files.some(isWorkflowPath);
  const web = workflowTouched || files.some(isWebPath);
  const godot = files.some(isGodotPath);
  const node = workflowTouched || godot || web || files.some(isNodePath);
  const docs = workflowTouched || files.some(isDocsPath);
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
    if (arg === "--base") {
      if (i + 1 >= argv.length) throw new Error("--base requires a value");
      opts.base = argv[++i];
    } else if (arg === "--full") {
      opts.full = true;
    } else if (arg === "--stdin") {
      opts.stdin = true;
    } else if (arg === "--github-output") {
      if (i + 1 >= argv.length) throw new Error("--github-output requires a value");
      opts.githubOutput = argv[++i];
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  return opts;
}

if (isMain(import.meta.url)) {
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
