// A batch through godot-launch.mjs's godotLaunch with the scenario's time
// limit replaced (jev_run.gd --time-limit-s), named in the launcher label.
//   node probe.mjs <scenario> <arm> <mode> <limit_s> <trials> <seed> <root>
import path from "node:path";

import { godotLaunch } from "../../../../../scripts/lab/godot-launch.mjs";
import { runBatch } from "../../../../../scripts/lab/harness.mjs";

const [scenario, arm, mode, limit, trials, seed, root] = process.argv.slice(2);
const base = godotLaunch({ mode });
const launch = (request) => {
  const spec = base(request);
  return { ...spec, args: [...spec.args, `--time-limit-s=${limit}`] };
};
launch.label = `${base.label} time-limit ${limit} s`;
const { record, trials: done } = await runBatch({
  scenario,
  arm,
  trials: Number(trials),
  seed: Number(seed),
  callCap: 20000,
  launch,
  runs: { root: path.resolve(root) },
});
const results = done.map((entry) => entry.scenario_result?.result ?? "unreported");
console.log(`${scenario} ${arm} ${mode} limit ${limit} s: ${record.result}; ${JSON.stringify(record.config.scenario_results)}; outcomes ${[...new Set(done.map((e) => e.outcome))]}; ${results.length} trials; ${record.id}`);
process.exitCode = record.result === "pass" ? 0 : 3;
