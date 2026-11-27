import { spawn } from "node:child_process";
import { writeFileSync } from "node:fs";
import { scratchGodotEnv } from "../godot-home.mjs";

export function runProcess(godot, cwd, args, { env, timeout, logFile }) {
  return new Promise((resolve) => {
    const t0 = Date.now();
    const child = spawn(godot, args, { cwd, env: { ...process.env, ...env } });
    let text = "";
    let timedOut = false;
    child.stdout.on("data", (d) => (text += d));
    child.stderr.on("data", (d) => (text += d));
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, timeout);
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      if (logFile) writeFileSync(logFile, text);
      resolve({
        exit: code ?? (signal ? 128 : 1),
        signal,
        timedOut,
        text,
        wallS: (Date.now() - t0) / 1000,
      });
    });
  });
}

export async function pool(tasks, slots) {
  const results = new Array(tasks.length);
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(slots, tasks.length) }, async () => {
      while (next < tasks.length) {
        const i = next++;
        results[i] = await tasks[i]();
      }
    }),
  );
  return results;
}

export function stateEnv(dir, platform = process.platform) {
  return scratchGodotEnv(dir, { create: true, platform });
}
