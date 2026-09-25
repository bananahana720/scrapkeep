// Time limits from scripted batches: new = max(initial, 2 x scripted p90).
// p90 is nearest rank over every trial's time to success, a timeout counting
// as infinite, so more than 10% timeouts leaves p90 censored at the limit and
// the rule cannot set a limit from the data. Both modes pool per scenario.
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

const root = process.argv[2];
const byScenario = new Map();
for (const name of (await readdir(root)).sort()) {
  if (name === "index.ndjson") continue;
  const { config } = JSON.parse(await readFile(path.join(root, name, "run.json"), "utf8"));
  if (config.arm !== "scripted") continue;
  const mode = /rigid/.test(config.launcher) ? "rigid" : "kinematic";
  const list = byScenario.get(config.scenario) ?? [];
  for (const trial of config.trials) {
    const r = trial.scenario_result;
    list.push({ mode, limit_s: r.limit_ticks / 90, s: r.result === "success" ? r.success_tick / 90 : Infinity });
  }
  byScenario.set(config.scenario, list);
}
const rank = (values, q) => {
  const sorted = values.toSorted((a, b) => a - b);
  return sorted[Math.max(0, Math.ceil(sorted.length * q) - 1)];
};
console.log("scenario\tmode\tn\tsuccesses\tp50_s\tp90_s\tinitial_s\tnew_s");
for (const [scenario, list] of byScenario) {
  const initial = list[0].limit_s;
  let worst = 0;
  for (const mode of ["kinematic", "rigid"]) {
    const mine = list.filter((one) => one.mode === mode);
    const times = mine.map((one) => one.s);
    const p90 = rank(times, 0.9);
    worst = Math.max(worst, p90);
    console.log([scenario, mode, mine.length, times.filter(Number.isFinite).length, rank(times, 0.5).toFixed(2), Number.isFinite(p90) ? p90.toFixed(2) : "censored", initial, ""].join("\t"));
  }
  const proposed = Number.isFinite(worst) ? Math.max(initial, Math.ceil(2 * worst)) : null;
  console.log([scenario, "both", list.length, "", "", Number.isFinite(worst) ? worst.toFixed(2) : "censored", initial, proposed ?? `${initial} (kept: p90 censored)`].join("\t"));
}
