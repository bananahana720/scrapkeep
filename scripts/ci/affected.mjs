#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { appendFileSync, readFileSync } from "node:fs";
import { isMain } from "../lib/cli.mjs";

export const KNOWN_FAILING_LEDGER = "project-guide/handoff/KNOWN-FAILING.tsv";
const WEB_PATTERN =
  /^(index\.html|orchard\.html|vite\.config\.js|package\.json|package-lock\.json|public\/|src\/|server\/|scripts\/check-build\.mjs|scripts\/verify\.mjs)/;
const GODOT_PATTERN = /^sketches\/core-loop\//;
const GODOT_SHARD_THRESHOLD = 8;
const GODOT_PARK_PATTERN = /^sketches\/core-loop\/(?:.*\/)?(?:parks?\/|park_[^/]*$)/;
const GODOT_HUB_PATTERN =
  /^sketches\/core-loop\/(?:src\/game\.gd|src\/movement\/(?:intent|tuning|augments)\.gd|src\/core\/(?:palette|class_def|event_kinds|game_events|run_state|ability_state|profile|park_defs|stage_defs|sim_clock)\.gd|src\/build\/parts\.gd|src\/combat\/(?:threat_grammar|warden|roster|weapons)\.gd|src\/world\/(?:terrain|director|world)\.gd|src\/presentation\/(?:sfx_bank|harmony|audio|hero_assets)\.gd|tests\/support\/t\.gd|tools\/bot_driver\.gd)$/;
const PACKAGE_PATTERN = /^package(?:-lock)?\.json$/;
const HANDOFF_DOC_PATTERN =
  /(?:\.md$|^project-guide\/handoff\/(?:STATE\.md|DECISIONS\.md|KNOWN-FAILING\.tsv|WEEKLY\.tsv|shared\/structure-sweep\/(?:pool|units)\.tsv))/;
const SKILL_PATTERN = /^\.(?:agents|claude)\/skills\//;
const AGENT_CONFIG_PATTERN = /^\.(?:agents|claude|codex)\//;
const DOCS_SCRIPT_PATTERN =
  /^scripts\/(?:check-docs|check-project|check-skills|check-agents\.mjs|brief-check|wave-state|known-failing|structure-sweep|gate\/weekly)/;
const NODE_PATTERN =
  /^(package\.json|package-lock\.json|scripts\/|tests\/|tools\/|src\/|server\/|project-guide\/handoff\/sitting-kit\/|\.github\/(?:workflows|actions)\/)/;
const WORKFLOW_PATTERN = /^(\.github\/(?:workflows|actions)\/|scripts\/ci\/)/;

export const isWebPath = (file) => WEB_PATTERN.test(file);
export const isGodotPath = (file) => GODOT_PATTERN.test(file);
export const isPackagePath = (file) => PACKAGE_PATTERN.test(file);
export const isHandoffDocPath = (file) => HANDOFF_DOC_PATTERN.test(file);
export const isSkillPath = (file) => SKILL_PATTERN.test(file);
export const isAgentConfigPath = (file) => AGENT_CONFIG_PATTERN.test(file);
export const isDocsPath = (file, exists = () => true) =>
  isHandoffDocPath(file) ||
  isAgentConfigPath(file) ||
  DOCS_SCRIPT_PATTERN.test(file) ||
  !exists(file);
export const isNodePath = (file) => NODE_PATTERN.test(file);
export const isWorkflowPath = (file) => WORKFLOW_PATTERN.test(file);

export function classifyAffected(changedFiles, { full = false, exists } = {}) {
  const files = [...new Set(changedFiles.filter(Boolean))];
  if (full || files.length === 0) {
    return {
      full: true,
      lint: true,
      docs: true,
      node: true,
      web: true,
      godot: true,
      godot_shards: 1,
      godot_matrix: "[1]",
      changedCount: files.length,
    };
  }
  const workflowTouched = files.some(isWorkflowPath);
  const web = workflowTouched || files.some(isWebPath);
  const godotFiles = files.filter(isGodotPath);
  const godot = godotFiles.length > 0;
  const godotWide =
    godot &&
    (godotFiles.length >= GODOT_SHARD_THRESHOLD ||
      godotFiles.some((f) => GODOT_PARK_PATTERN.test(f) || GODOT_HUB_PATTERN.test(f)));
  const godot_shards = godotWide ? 2 : 1;
  const godot_matrix = godot_shards > 1 ? "[1, 2]" : "[1]";
  const node = workflowTouched || godot || web || files.some(isNodePath);
  const docs = workflowTouched || files.some((file) => isDocsPath(file, exists));
  return {
    full: false,
    lint: true,
    docs,
    node,
    web,
    godot,
    godot_shards,
    godot_matrix,
    changedCount: files.length,
  };
}

export function diffFiles(baseRef, { cwd = process.cwd(), spawn = spawnSync } = {}) {
  const ran = spawn("git", ["diff", "--no-renames", "--name-only", `${baseRef}...HEAD`], {
    cwd,
    encoding: "utf8",
  });
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

export function treeFiles(ref, { cwd = process.cwd(), spawn = spawnSync, env = process.env } = {}) {
  if (typeof ref !== "string" || ref === "") throw new Error("treeFiles needs a commit");
  const ran = spawn("git", ["ls-tree", "-r", "-z", "--name-only", ref], {
    cwd,
    env,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  if (ran.error || ran.status !== 0) {
    throw new Error(
      `git ls-tree ${ref} failed: ${ran.error?.message || (ran.stderr || ran.stdout || "").trim()}`,
    );
  }
  const files = new Set(ran.stdout.split("\0").filter(Boolean));
  if (files.size === 0) throw new Error(`git ls-tree ${ref} lists no files`);
  return files;
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
    const head = full ? null : treeFiles("HEAD");
    const result = classifyAffected(files, {
      full,
      exists: head ? (file) => head.has(file) : undefined,
    });
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
