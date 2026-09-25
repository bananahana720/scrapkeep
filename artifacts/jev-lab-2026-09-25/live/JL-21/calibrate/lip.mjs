// Reads the lip-probe batches: per launch speed and mode, the speed at the lip
// and whether the ball reached the bench before the first intent applied.
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

const root = process.argv[2];
const rows = [];
for (const name of await readdir(root)) {
  if (name === "index.ndjson") continue;
  const record = JSON.parse(await readFile(path.join(root, name, "run.json"), "utf8"));
  const { config } = record;
  for (const trial of config.trials) {
    const result = trial.scenario_result;
    const mode = /rigid/.test(config.launcher) ? "rigid" : "kinematic";
    const first = result?.lip?.[0] ?? null;
    const cleared = result !== null && first !== null && result.bench_tick >= 0
      && result.bench_tick < config.hold_ticks && result.route === "kicker";
    rows.push({
      mode,
      launch: Number(config.scenario.split("@")[1]),
      lip_speed: first?.speed ?? null,
      lip_tick: first?.tick ?? null,
      bench_tick: result?.bench_tick ?? null,
      cleared,
      result: result?.result ?? null,
      hold: config.hold_ticks,
    });
  }
}
rows.sort((a, b) => a.mode.localeCompare(b.mode) || a.launch - b.launch);
console.log("mode\tlaunch_ms\tlip_speed_ms\tlip_tick\tbench_tick\tcleared_before_first_intent\tscenario");
for (const row of rows) {
  console.log([row.mode, row.launch, row.lip_speed, row.lip_tick, row.bench_tick, row.cleared, row.result].join("\t"));
}
for (const mode of ["kinematic", "rigid"]) {
  const mine = rows.filter((row) => row.mode === mode && row.lip_speed !== null);
  const cleared = mine.filter((row) => row.cleared).map((row) => row.lip_speed);
  const short = mine.filter((row) => !row.cleared).map((row) => row.lip_speed);
  console.log(`${mode}: slowest lip speed that cleared ${Math.min(...cleared)}, fastest that fell short ${Math.max(...short)}`);
}
