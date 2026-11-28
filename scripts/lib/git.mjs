import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
export const DEFAULT_MAX_BUFFER = 64 * 1024 * 1024;
const REPOSITORY_VARIABLES = [
  "GIT_DIR",
  "GIT_WORK_TREE",
  "GIT_COMMON_DIR",
  "GIT_INDEX_FILE",
  "GIT_PREFIX",
];

export function cwdDecidesRepository(env = process.env) {
  const out = { ...env };
  for (const name of REPOSITORY_VARIABLES) delete out[name];
  return out;
}

export function git(
  args,
  { cwd = REPO_ROOT, maxBuffer = DEFAULT_MAX_BUFFER, trim = true, spawn = spawnSync, stdio } = {},
) {
  const ran = spawn("git", args, {
    cwd,
    env: cwdDecidesRepository(),
    encoding: "utf8",
    maxBuffer,
    ...(stdio ? { stdio } : {}),
  });
  if (ran.error) throw ran.error;
  if (ran.status !== 0) {
    throw new Error(`git ${args.join(" ")} failed: ${(ran.stderr || ran.stdout || "").trim()}`);
  }
  const stdout = ran.stdout ?? "";
  return trim ? stdout.trim() : stdout;
}

export function gitOptional(
  args,
  { cwd = REPO_ROOT, maxBuffer = DEFAULT_MAX_BUFFER, trim = true, spawn = spawnSync, stdio } = {},
) {
  const ran = spawn("git", args, {
    cwd,
    env: cwdDecidesRepository(),
    encoding: "utf8",
    maxBuffer,
    ...(stdio ? { stdio } : {}),
  });
  if (ran.error || ran.status !== 0) return null;
  const stdout = ran.stdout ?? "";
  return trim ? stdout.trim() : stdout.replace(/\r?\n$/, "");
}

export function gitState(cwd = REPO_ROOT, { spawn = spawnSync } = {}) {
  const top = gitOptional(["rev-parse", "--show-toplevel"], { cwd, spawn });
  if (top === null) return null;
  const head = gitOptional(["rev-parse", "HEAD"], { cwd, spawn });
  const branch = gitOptional(["rev-parse", "--abbrev-ref", "HEAD"], { cwd, spawn });
  const status = gitOptional(["status", "--porcelain", "--untracked-files=no"], {
    cwd,
    trim: false,
    spawn,
  });
  return {
    root: top,
    head,
    branch,
    dirty: Boolean(status && status.trim()),
  };
}

export function cleanHead(cwd = REPO_ROOT, { spawn = spawnSync } = {}) {
  const tracked = spawn("git", ["status", "--porcelain", "--untracked-files=no"], {
    cwd,
    env: cwdDecidesRepository(),
    encoding: "utf8",
    maxBuffer: DEFAULT_MAX_BUFFER,
  });
  if (tracked.error) throw tracked.error;
  if (tracked.status !== 0) throw new Error(`git status failed: ${tracked.stderr}`);
  if (tracked.stdout.trim())
    throw new Error(
      `refusing: uncommitted changes to tracked files, the check would judge no commit:\n${tracked.stdout}`,
    );
  const loose = spawn(
    "git",
    [
      "status",
      "--porcelain",
      "--untracked-files=all",
      "--",
      "sketches/core-loop/src",
      "sketches/core-loop/assets",
    ],
    { cwd, env: cwdDecidesRepository(), encoding: "utf8", maxBuffer: DEFAULT_MAX_BUFFER },
  );
  if (loose.error) throw loose.error;
  if (loose.status !== 0) throw new Error(`git status failed: ${loose.stderr}`);
  if (loose.stdout.trim())
    throw new Error(
      `refusing: untracked files under the game's src or assets, the check would judge no commit:\n${loose.stdout}`,
    );
  return git(["rev-parse", "HEAD"], { cwd, spawn });
}
