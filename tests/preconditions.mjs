// What a test needs from the box it runs on. A test that cannot do its job
// here is skipped with the reason and what lifts it, so it shows in the
// "skipped" count instead of failing as if the code were broken. Cloud threads
// run as root, usually on a shallow clone; Andrew's PC and a full clone run by
// an ordinary user skip nothing here.
//
// The promotion run sets SCRAPKEEP_WHOLE_TESTS=1 (project-guide/handoff/GATE.md).
// There a limit is an error and not a skip, so "npm test passed" means every
// one of these tests ran.
import path from "node:path";
import { fileURLToPath } from "node:url";
import { gitOptional } from "../scripts/lib/git.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const whole = process.env.SCRAPKEEP_WHOLE_TESTS === "1";

function limit(applies, reason) {
  if (!applies) return false;
  if (whole)
    throw new Error(`SCRAPKEEP_WHOLE_TESTS=1 needs a box with no limits, and this one ${reason}`);
  return reason;
}

// Root ignores directory permissions, so a test that takes write permission
// away to force a failed write cannot force it.
export const asRoot = limit(
  process.getuid?.() === 0,
  "runs as root, which ignores the directory permissions this test removes; run as an ordinary user",
);

// A shallow clone lacks the old commits that playtest records and git
// snapshots name. With no git, or outside a repository, this is false and the
// tests run and fail with git's own message.
export const shallowClone = limit(
  gitOptional(["rev-parse", "--is-shallow-repository"], { cwd: root }) === "true",
  "is a shallow clone, which lacks the commits this test reads; run `git fetch --unshallow origin`",
);
