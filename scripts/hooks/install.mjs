#!/usr/bin/env node

import { chmodSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ensureNodeModules } from "../ensure-node-modules.mjs";
import { git, gitOptional } from "../lib/git.mjs";

if (/^(true|1)$/i.test(process.env.CI || "")) {
  process.exit(0);
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
if (gitOptional(["rev-parse", "--git-dir"], { cwd: root }) === null) {
  process.exit(0);
}

ensureNodeModules(root, { log: (msg) => console.log(msg) });

const hookFile = path.join(root, "scripts", "hooks", "pre-push");
if (existsSync(hookFile)) {
  try {
    chmodSync(hookFile, 0o755);
  } catch {}
}

try {
  git(["config", "core.hooksPath", "scripts/hooks"], { cwd: root });
} catch (error) {
  console.error(`hooks:install failed: ${(error.stderr || error.stdout || error.message).trim()}`);
  process.exit(1);
}
console.log("hooks:install active (core.hooksPath = scripts/hooks)");
