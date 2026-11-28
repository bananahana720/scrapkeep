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

function kind(value) {
  if (value === null) return "null";
  if (Array.isArray(value)) return "an array";
  if (typeof value === "object") {
    const name = value.constructor?.name;
    return !name || name === "Object" ? "an object" : `a ${name}`;
  }
  return `a ${typeof value}`;
}

function checked(name, options) {
  if (options === undefined) return {};
  const proto = typeof options === "object" && options !== null && Object.getPrototypeOf(options);
  if (proto !== Object.prototype && proto !== null)
    throw new TypeError(
      `${name}(args, options): options must be an object such as { cwd }, got ${kind(options)}`,
    );
  return options;
}

function checkedCwd(name, cwd) {
  if (typeof cwd !== "string")
    throw new TypeError(
      `${name}(cwd, options): cwd must be a folder path string, got ${kind(cwd)}`,
    );
}

function start(args, { cwd = REPO_ROOT, maxBuffer = DEFAULT_MAX_BUFFER, spawn, stdio, timeout }) {
  return spawn("git", args, {
    cwd,
    env: cwdDecidesRepository(),
    encoding: "utf8",
    maxBuffer,
    ...(stdio ? { stdio } : {}),
    ...(timeout ? { timeout } : {}),
  });
}

export function git(args, options) {
  const { trim = true, spawn = spawnSync, ...rest } = checked("git", options);
  const ran = start(args, { spawn, ...rest });
  if (ran.error) throw ran.error;
  if (ran.status !== 0) {
    throw Object.assign(
      new Error(`git ${args.join(" ")} failed: ${(ran.stderr || ran.stdout || "").trim()}`),
      { status: ran.status, stdout: ran.stdout ?? "", stderr: ran.stderr ?? "" },
    );
  }
  const stdout = ran.stdout ?? "";
  return trim ? stdout.trim() : stdout;
}

export function gitOptional(args, options) {
  const { trim = true, spawn = spawnSync, ...rest } = checked("gitOptional", options);
  const ran = start(args, { spawn, ...rest });
  if (ran.error || ran.status !== 0) return null;
  const stdout = ran.stdout ?? "";
  return trim ? stdout.trim() : stdout.replace(/\r?\n$/, "");
}

export function gitState(cwd = REPO_ROOT, { spawn = spawnSync } = {}) {
  checkedCwd("gitState", cwd);
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
  checkedCwd("cleanHead", cwd);
  const tracked = git(["status", "--porcelain", "--untracked-files=no"], {
    cwd,
    trim: false,
    spawn,
  });
  if (tracked.trim())
    throw new Error(
      `refusing: uncommitted changes to tracked files, the check would judge no commit:\n${tracked}`,
    );
  const loose = git(
    [
      "status",
      "--porcelain",
      "--untracked-files=all",
      "--",
      "sketches/core-loop/src",
      "sketches/core-loop/assets",
    ],
    { cwd, trim: false, spawn },
  );
  if (loose.trim())
    throw new Error(
      `refusing: untracked files under the game's src or assets, the check would judge no commit:\n${loose}`,
    );
  return git(["rev-parse", "HEAD"], { cwd, spawn });
}
