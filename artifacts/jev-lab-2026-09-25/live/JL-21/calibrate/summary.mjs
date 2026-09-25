// Summarises every batch under a runs root: per scenario, arm and mode, the
// share of snapshots offering two or more options, the scenario's own result,
// time to success, knocks and trace hashes. `--trials` prints each trial.
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

import { distribution, wilson } from "../../../../../scripts/lab/stats.mjs";

const [root, flag] = process.argv.slice(2);
const batches = [];
for (const name of (await readdir(root)).sort()) {
  if (name === "index.ndjson") continue;
  const record = JSON.parse(await readFile(path.join(root, name, "run.json"), "utf8"));
  batches.push({ name, record });
}

const fmt = (x) => (x === null || x === undefined ? "-" : Number.isInteger(x) ? String(x) : x.toFixed(2));
const interval = (k, n) => {
  const w = wilson(k, n);
  return `${k}/${n} [${w.lower.toFixed(2)}, ${w.upper.toFixed(2)}]`;
};

console.log(["scenario", "arm", "mode", "D", "k", "trials", "multi_option_snapshots", "success", "timeout", "running", "t_success_p50_s", "t_success_p90_s", "knocked_mean", "stomp", "ram", "hashes", "outcomes"].join("\t"));
for (const { name, record } of batches) {
  const { config } = record;
  const mode = /rigid/.test(config.launcher) ? "rigid" : "kinematic";
  const trials = config.trials;
  const snapshots = trials.reduce((s, t) => s + t.snapshots, 0);
  const multi = trials.reduce((s, t) => s + t.arm_calls, 0);
  const results = trials.map((t) => t.scenario_result);
  const success = results.filter((r) => r?.result === "success");
  const times = success.map((r) => r.success_tick / 90);
  const p = (q) => {
    const sorted = times.toSorted((a, b) => a - b);
    return sorted.length === 0 ? null : sorted[Math.max(0, Math.ceil(sorted.length * q) - 1)];
  };
  const knocked = results.map((r) => r?.knocked ?? 0);
  const stomp = results.reduce((s, r) => s + (r?.knocks?.stomp ?? 0), 0);
  const ram = results.reduce((s, r) => s + (r?.knocks?.ram ?? 0), 0);
  const outcomes = [...new Set(trials.map((t) => t.outcome))].join(",");
  console.log([
    config.scenario, config.arm, mode, config.snapshot_every, config.hold_ticks, trials.length,
    snapshots === 0 ? "-" : interval(multi, snapshots),
    interval(success.length, trials.length),
    results.filter((r) => r?.result === "timeout").length,
    results.filter((r) => r?.result === "running").length,
    fmt(p(0.5)), fmt(p(0.9)),
    fmt(knocked.reduce((a, b) => a + b, 0) / trials.length),
    stomp, ram,
    new Set(trials.map((t) => t.trace_hash)).size,
    outcomes,
  ].join("\t"));
  if (flag === "--trials") {
    for (const t of trials) {
      const r = t.scenario_result;
      console.log(`   trial ${t.trial} seed ${t.seed}: ${t.outcome} ${r?.result} tick ${r?.tick} success_tick ${r?.success_tick} knocked ${r?.knocked} knocks ${JSON.stringify(r?.knocks)} gates ${r?.gates} route ${r?.route} lip ${JSON.stringify(r?.lip)} snapshots ${t.snapshots} multi ${t.arm_calls} hash ${t.trace_hash?.slice(0, 12)}`);
    }
  }
}
void distribution;
