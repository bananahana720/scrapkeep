// How each ledge visit arrived: by air (a landing event within 10 ticks of the visit,
// after a takeoff from the kicker's run) or rolling (no landing), with the peak planar
// speed in the 3 s before. Post hoc, descriptive.  node ledge.mjs <runs-root>
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
const root = process.argv[2];
const tally = {};
for (const d of readdirSync(root).filter((x) => /^\d{8}T/.test(x))) {
  const r = JSON.parse(readFileSync(path.join(root, d, "run.json"), "utf8"));
  const mode = /\b(rigid|kinematic)\b/.exec(r.config.launcher)[1];
  for (const t of r.config.trials) {
    const visits = t.scenario_result.mesa_visits;
    if (!visits.length) continue;
    const ev = readFileSync(path.join(root, d, t.io, "events.ndjson"), "utf8").trim().split("\n").map(JSON.parse);
    for (const v of visits) {
      const air = ev.some((e) => e.kind === "landing" && Math.abs(e.tick - v.tick) <= 10);
      const peak = Math.max(0, ...ev.filter((e) => e.kind === "trace" && e.tick <= v.tick && e.tick > v.tick - 270).map((e) => Math.hypot(e.vel[0], e.vel[2])));
      const lastIntent = ev.filter((e) => e.kind === "intent" && e.tick <= v.tick).at(-1)?.intent;
      const k = `${r.config.scenario} ${r.config.arm} ${mode}`;
      const row = (tally[k] ??= { visits: 0, air: 0, peaks: [], intents: {} });
      row.visits += 1;
      if (air) row.air += 1;
      row.peaks.push(peak.toFixed(1));
      row.intents[lastIntent] = (row.intents[lastIntent] ?? 0) + 1;
    }
  }
}
for (const [k, row] of Object.entries(tally).sort()) console.log(`${k}: ${row.visits} visits, ${row.air} arrived by air; peak speeds ${row.peaks.join(",")}; intent held ${JSON.stringify(row.intents)}`);
