// The commit a receipt may be stamped with, shared by the world 1 done read's receipt producers
// (scripts/world1-bands.rows.json): the checkout's head, and only when the checkout is that commit.
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

// Refuses uncommitted changes to tracked files, and untracked files under the game's src/ and assets/ (a rendered
// sound that is not committed would count as a cue's own sound for a head that lacks it). Gitignored files do not
// count.
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
