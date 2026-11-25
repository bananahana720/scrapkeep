#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { chmodSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

if (/^(true|1)$/i.test(process.env.CI || "")) {
  process.exit(0);
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const check = spawnSync("git", ["rev-parse", "--git-dir"], { cwd: root, encoding: "utf8" });
if (check.status !== 0) {
  process.exit(0);
}

const hookFile = path.join(root, "scripts", "hooks", "pre-push");
if (existsSync(hookFile)) {
  try {
    chmodSync(hookFile, 0o755);
  } catch {}
}

const set = spawnSync("git", ["config", "core.hooksPath", "scripts/hooks"], {
  cwd: root,
  encoding: "utf8",
});
if (set.status !== 0) {
  console.error(`hooks:install failed: ${(set.stderr || set.stdout || "").trim()}`);
  process.exit(1);
}
console.log("hooks:install active (core.hooksPath = scripts/hooks)");
