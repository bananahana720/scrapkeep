import path from "node:path";

import { isMain } from "../lib/cli.mjs";
import { REPO_ROOT, git as runGit, nulSeparated } from "../lib/git.mjs";
import { buildIndex, isTopLevelTest, referrers } from "../sketch-fast.mjs";
import { gateLists } from "./shard.mjs";

const root = REPO_ROOT;
const SKETCH = "sketches/core-loop";

export function sortChanges(paths, sketch = SKETCH) {
  const game = [];
  const tests = [];
  const other = [];
  for (const file of paths) {
    if (!file.startsWith(sketch + "/")) other.push(file);
    else {
      const rel = file.slice(sketch.length + 1);
      if (rel.startsWith("tests/")) tests.push(rel);
      else if (/\.md$/.test(rel)) other.push(file);
      else game.push(file);
    }
  }
  return { game, tests, other };
}

export function testsToRerun(index, changedTestFiles) {
  const why = new Map();
  const queue = changedTestFiles.map((rel) => ({ rel, from: null }));
  const visited = new Set();
  while (queue.length > 0) {
    const { rel, from } = queue.shift();
    if (visited.has(rel)) continue;
    visited.add(rel);
    if (isTopLevelTest(rel) && index.files.has(rel) && !why.has(rel))
      why.set(rel, from === null ? "changed" : `reaches ${from}`);
    for (const next of referrers(index, rel)) {
      if (next.startsWith("tests/")) queue.push({ rel: next, from: from ?? rel });
    }
  }
  return why;
}

export function place(name, lists) {
  const bot = lists.bots.indexOf(name);
  if (bot >= 0) return `bot list ${bot + 1}`;
  const test = lists.tests.indexOf(name);
  if (test >= 0) return `non-bot list ${test + 1}`;
  if (lists.weekly?.tests.includes(name) || lists.weekly?.bots.includes(name))
    return "weekly list, not in this promotion";
  return "not in a gate list";
}

function git(...args) {
  return runGit(args, { cwd: root });
}

function main() {
  const [from, to = "HEAD"] = process.argv.slice(2);
  if (!from)
    throw new Error("usage: node scripts/gate/carry.mjs <head the rows were read on> [<new head>]");
  if (git("rev-parse", to) !== git("rev-parse", "HEAD"))
    throw new Error(`check out ${to} first; the test files are read from the working tree`);
  const changed = nulSeparated(
    runGit(["diff", "--name-only", "-z", from, to], { cwd: root, trim: false }),
  );
  const { game, tests, other } = sortChanges(changed);
  console.log(
    `${git("rev-parse", "--short=8", from)} to ${git("rev-parse", "--short=8", to)}: ${changed.length} files changed.`,
  );
  if (game.length > 0) {
    console.log(
      `NOTHING CARRIES: ${game.length} game files changed (${game.slice(0, 5).join(", ")}${game.length > 5 ? ", ..." : ""}). Run every shard again, or name the shards a reviewer agrees cannot be reached.`,
    );
    return 1;
  }
  const sketchDir = path.join(root, SKETCH);
  const rerun = testsToRerun(buildIndex(sketchDir), tests);
  const lists = gateLists(sketchDir);
  if (rerun.size === 0) console.log("No test file changed. Every row carries.");
  else {
    console.log(`Run these ${rerun.size} tests again on the new head; every other row carries:`);
    for (const [rel, reason] of [...rerun].sort()) {
      const name = path.posix.basename(rel, ".gd");
      console.log(`  ${name} (${place(name, lists)}): ${reason}`);
    }
  }
  if (other.length > 0)
    console.log(
      `Also changed outside the game and its tests (judge by hand; a runner change under scripts/ can move any row): ${other.join(", ")}`,
    );
  return 0;
}

if (isMain(import.meta.url)) {
  try {
    process.exitCode = main();
  } catch (error) {
    console.error("gate carry: " + (error?.message ?? error));
    process.exitCode = 2;
  }
}
