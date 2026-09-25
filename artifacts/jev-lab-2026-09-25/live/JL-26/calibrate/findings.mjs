// JL-26 gameplay-finding evidence from one pass's trial files (post hoc, descriptive).
//   node findings.mjs <runs-root>
// 1. Knock vs contact: share of knock events (events.ndjson) with a foe contact hit on the
//    ball (scenario_result.hit_log) within 3 ticks.
// 2. Climb speed: mean planar speed on road 0 (|x+130| < 18, 109 < z < 146) per mode.
// 3. Ram gate: ram_target offers the gate kept, and all offers the gate removed, by id.
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";

const root = process.argv[2];
const dirs = readdirSync(root).filter((d) => /^\d{8}T/.test(d));
const byMode = {};
const gate = {};
for (const d of dirs) {
  const r = JSON.parse(readFileSync(path.join(root, d, "run.json"), "utf8"));
  const mode = /\b(rigid|kinematic)\b/.exec(r.config.launcher)[1];
  const m = (byMode[mode] ??= { knocks: 0, withHit: 0, stomp: [0, 0], ram: [0, 0], road: [], trials: 0 });
  for (const t of r.config.trials) {
    const s = t.scenario_result;
    m.trials += 1;
    const events = readFileSync(path.join(root, d, t.io, "events.ndjson"), "utf8")
      .trim().split("\n").filter(Boolean).map(JSON.parse);
    const hits = (s.hit_log ?? []).map((h) => h.tick);
    for (const e of events) {
      if (e.kind === "knock") {
        const hit = hits.some((h) => Math.abs(h - e.tick) <= 3);
        m.knocks += 1;
        if (hit) m.withHit += 1;
        const kind = e.strength === 0.6 ? "stomp" : "ram";
        m[kind][0] += 1;
        if (hit) m[kind][1] += 1;
      }
      if (r.config.scenario === "stage-run" && e.kind === "trace" && Math.abs(e.pos[0] + 130) < 18 && e.pos[2] > 109 && e.pos[2] < 146) {
        m.road.push(Math.hypot(e.vel[0], e.vel[2]));
      }
    }
    for (const [id, n] of Object.entries(s.offered)) {
      const g = (gate[`${mode} ${id}`] ??= { offered: 0, kept: 0 });
      g.offered += n;
      g.kept += s.kept[id] ?? 0;
    }
  }
}
for (const [mode, m] of Object.entries(byMode)) {
  const road = m.road;
  const mean = road.reduce((a, b) => a + b, 0) / road.length;
  const sorted = [...road].sort((a, b) => a - b);
  console.log(
    `${mode}: ${m.trials} trials; knocks ${m.knocks}, with a contact hit within 3 ticks ${m.withHit} (${(m.withHit / m.knocks).toFixed(2)}); stomp ${m.stomp[1]}/${m.stomp[0]}, ram ${m.ram[1]}/${m.ram[0]}`,
  );
  console.log(
    `${mode}: stage-run road-0 planar speed over ${road.length} trace samples: mean ${mean.toFixed(1)} m/s, median ${sorted[Math.floor(sorted.length / 2)].toFixed(1)}, share under 7 m/s (chaser speed) ${(road.filter((v) => v < 7).length / road.length).toFixed(2)}`,
  );
}
console.log("offers kept by the gate (mode id: kept/offered):");
for (const [k, g] of Object.entries(gate).sort()) {
  if (g.kept !== g.offered) console.log(`  ${k}: ${g.kept}/${g.offered} (${(g.kept / g.offered).toFixed(3)})`);
}
