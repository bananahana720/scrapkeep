// What a test needs from the box it runs on. A test that cannot do its job
// here is skipped with the reason and what lifts it, so it shows in the
// "skipped" count instead of failing as if the code were broken. Cloud threads
// run as root on a shallow clone; Andrew's PC and a full clone run by an
// ordinary user skip nothing here.
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

// Root ignores directory permissions, so a test that takes write permission
// away to force a failed write cannot force it.
export const asRoot =
  process.getuid?.() === 0 &&
  "runs as root, which ignores the directory permissions this test removes; run as an ordinary user";

// A shallow clone lacks the old commits that playtest records and git
// snapshots name.
export const shallowClone =
  spawnSync("git", ["rev-parse", "--is-shallow-repository"], { cwd: root, encoding: "utf8" }).stdout.trim() === "true" &&
  "this clone is shallow and the test reads commits it lacks; run `git fetch --unshallow origin`";
