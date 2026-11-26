import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

export function cleanHead(cwd = root) {
  const git = (...args) => spawnSync("git", args, { cwd, encoding: "utf8" });
  const tracked = git("status", "--porcelain", "--untracked-files=no");
  if (tracked.status !== 0) throw new Error(`git status failed: ${tracked.stderr}`);
  if (tracked.stdout.trim()) throw new Error(`refusing: uncommitted changes to tracked files, the check would judge no commit:\n${tracked.stdout}`);
  const loose = git("status", "--porcelain", "--untracked-files=all", "--", "sketches/core-loop/src", "sketches/core-loop/assets");
  if (loose.status !== 0) throw new Error(`git status failed: ${loose.stderr}`);
  if (loose.stdout.trim()) throw new Error(`refusing: untracked files under the game's src or assets, the check would judge no commit:\n${loose.stdout}`);
  return git("rev-parse", "HEAD").stdout.trim();
}
