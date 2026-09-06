import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const bundled = join(
  homedir(),
  ".cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3",
);
const python =
  process.env.CODEX_PLAYER_PYTHON ||
  (existsSync(bundled) ? bundled : "python3");
const entry = fileURLToPath(
  new URL("../tools/agent-player/run.py", import.meta.url),
);
const child = spawn(python, [entry, ...process.argv.slice(2)], {
  stdio: "inherit",
  detached: true,
});
let stopping = false;
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () => {
    if (stopping) return;
    stopping = true;
    child.kill(signal);
  });
child.on("error", (error) => {
  console.error(error.message);
  process.exitCode = 1;
});
child.on("exit", (code, signal) => {
  process.exitCode = code ?? (signal ? 130 : 1);
});
