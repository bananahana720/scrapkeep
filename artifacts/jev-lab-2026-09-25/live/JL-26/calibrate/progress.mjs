// Per trial: first tick on each bench level (by z), death position, mean speed on road 0.
//   node progress.mjs <run-dir>...
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
const CLIFF_Z = [112, 46, -20, -86, -140];
const level = (z) => CLIFF_Z.filter((c) => z < c).length;
for (const dir of process.argv.slice(2)) {
  const r = JSON.parse(readFileSync(path.join(dir, "run.json"), "utf8"));
  const mode = /\b(rigid|kinematic)\b/.exec(r.config.launcher)?.[1];
  for (const t of r.config.trials) {
    const ev = readFileSync(path.join(dir, t.io, "events.ndjson"), "utf8").trim().split("\n").map(JSON.parse);
    const traces = ev.filter((e) => e.kind === "trace");
    const first = {};
    const road = [];
    for (const e of traces) {
      const L = level(e.pos[2]);
      if (!(L in first)) first[L] = e.tick;
      if (Math.abs(e.pos[0] + 130) < 18 && e.pos[2] < 146 && e.pos[2] > 109) road.push(Math.hypot(e.vel[0], e.vel[2]));
    }
    const last = traces.at(-1);
    const mean = road.length ? (road.reduce((a, b) => a + b, 0) / road.length).toFixed(1) : "-";
    console.log(`${r.config.scenario} ${r.config.arm} ${mode} t${t.trial} ${t.scenario_result.end} first-tick-per-level ${JSON.stringify(first)} road0 mean speed ${mean} (${road.length} samples) last ${last.pos.map((v) => v.toFixed(0)).join(",")}`);
  }
}
