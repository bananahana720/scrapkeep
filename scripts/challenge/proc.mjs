import { scratchGodotEnv } from "../godot-home.mjs";
import { pool, runProcess as runChild } from "../lib/proc.mjs";

export { pool };

export async function runProcess(godot, cwd, args, { env, timeout, logFile }) {
  const res = await runChild(godot, args, {
    cwd,
    env: { ...process.env, ...env },
    timeoutMs: timeout,
    logFile,
  });
  return {
    exit: res.exit ?? (res.signal ? 128 : 1),
    signal: res.signal,
    timedOut: res.timedOut,
    text: res.output,
    wallS: res.ms / 1000,
  };
}

export function stateEnv(dir, platform = process.platform) {
  return scratchGodotEnv(dir, { create: true, platform });
}
