// Scripted vs random per scenario, mode, D and k: the share of snapshots with
// two or more offered options, and the scenario's own success rate with its
// Wilson interval per arm and the Newcombe interval for random minus scripted.
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

import { newcombe, wilson } from "../../../../../scripts/lab/stats.mjs";

const roots = process.argv.slice(2);
const groups = new Map();
for (const root of roots) {
  for (const name of (await readdir(root)).sort()) {
    if (name === "index.ndjson") continue;
    const record = JSON.parse(await readFile(path.join(root, name, "run.json"), "utf8"));
    const { config } = record;
    const mode = /rigid/.test(config.launcher) ? "rigid" : "kinematic";
    const key = [config.scenario, mode, config.snapshot_every, config.hold_ticks].join("|");
    const group = groups.get(key) ?? {};
    group[config.arm] = { record, config };
    groups.set(key, group);
  }
}
const f = (x) => x.toFixed(2);
const share = (config) => {
  const snapshots = config.trials.reduce((s, t) => s + t.snapshots, 0);
  const multi = config.trials.reduce((s, t) => s + t.arm_calls, 0);
  return { multi, snapshots };
};
const wins = (config) => config.trials.filter((t) => t.scenario_result?.result === "success").length;
console.log(["scenario", "mode", "D", "k", "multi_scripted", "multi_random", "success_scripted [wilson]", "success_random [wilson]", "random_minus_scripted [newcombe]", "separated", "results_scripted", "results_random", "record_results"].join("\t"));
for (const [key, group] of [...groups].sort()) {
  const { scripted, random } = group;
  if (scripted === undefined || random === undefined) continue;
  const [scenario, mode, D, k] = key.split("|");
  const s = scripted.config;
  const r = random.config;
  const ns = s.trials.length;
  const nr = r.trials.length;
  const ws = wilson(wins(s), ns);
  const wr = wilson(wins(r), nr);
  const d = newcombe(wins(r), nr, wins(s), ns);
  const ms = share(s);
  const mr = share(r);
  console.log([
    scenario, mode, D, k,
    `${ms.multi}/${ms.snapshots} (${f(ms.multi / ms.snapshots)})`,
    `${mr.multi}/${mr.snapshots} (${f(mr.multi / mr.snapshots)})`,
    `${wins(s)}/${ns} [${f(ws.lower)}, ${f(ws.upper)}]`,
    `${wins(r)}/${nr} [${f(wr.lower)}, ${f(wr.upper)}]`,
    `${f(d.estimate)} [${f(d.lower)}, ${f(d.upper)}]`,
    d.lower > 0 || d.upper < 0 ? "yes" : "no",
    JSON.stringify(s.scenario_results),
    JSON.stringify(r.scenario_results),
    `${scripted.record.result}/${random.record.result}`,
  ].join("\t"));
}
