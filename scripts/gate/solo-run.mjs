import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";

import { parseSmokeLog, soloEnvironment } from "./shard.mjs";

export function runAlone(cwd, test, extraEnv = {}) {
  const out = mkdtempSync(path.join(os.tmpdir(), `solo-${test}-`));
  const env = { ...soloEnvironment(process.env, out, "logs"), ...extraEnv };
  const run = spawnSync(process.execPath, [path.join(cwd, "scripts/sketch-smoke.mjs"), "--sketch", "core-loop", "--test", test], {
    cwd, env, encoding: "utf8", maxBuffer: 1 << 26,
  });
  const line = parseSmokeLog(String(run.stdout)).find((r) => r.test === test);
  let log;
  try { log = readFileSync(path.join(out, "logs", `${test}.log`), "utf8"); } catch { log = `runner exit ${run.status}, no ${test}.log: ${String(run.stdout).slice(-200)}`; }
  return { ok: Boolean(line?.ok), exit: line?.exit ?? `runner ${run.status}`, seconds: line?.seconds ?? 0, log };
}
