// Per-trial and per-batch summary of Cable Bench batch records (JL-26).
//   node summary.mjs <run-dir>... [--trials]
import { readFileSync } from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const showTrials = args.includes("--trials");
const dirs = args.filter((a) => !a.startsWith("--"));

const add = (into, table) => {
  for (const [k, v] of Object.entries(table ?? {})) into[k] = (into[k] ?? 0) + v;
};
const fmt = (x) => (typeof x === "number" ? Number(x.toFixed(3)) : x);

for (const dir of dirs) {
  const r = JSON.parse(readFileSync(path.join(dir, "run.json"), "utf8"));
  const c = r.config;
  const mode = /\b(rigid|kinematic)\b/.exec(c.launcher)?.[1];
  const offered = {};
  const kept = {};
  const chosen = {};
  const ends = {};
  let multi = 0;
  let snaps = 0;
  for (const t of c.trials) {
    const s = t.scenario_result;
    if (s === null) continue;
    add(offered, s.offered);
    add(kept, s.kept);
    add(chosen, s.chosen);
    ends[s.end] = (ends[s.end] ?? 0) + 1;
    multi += s.multi;
    snaps += s.snapshots;
    if (showTrials) {
      console.log(
        `  ${t.trial} seed ${t.seed} ${t.outcome} ${s.end} tick ${s.tick} multi ${s.multi}/${s.snapshots} caches ${s.caches_opened} scrap ${s.scrap_taken} hp ${fmt(s.hp)} tier ${s.stage_tier} knocks ${s.knocks.stomp}/${s.knocks.ram} mesa ${s.mesa_visits.length} cw ${s.cableway_hits} charge ${s.charge_tick} chosen ${JSON.stringify(s.chosen)} hash ${t.trace_hash?.slice(0, 8)}`,
      );
    }
  }
  console.log(
    `${path.basename(dir)} | ${c.scenario} ${c.arm} ${mode} n=${c.trials.length} head ${r.provenance.head.slice(0, 7)} dirty ${r.provenance.dirty} sketch ${r.provenance.versions.sketch_head?.slice(0, 7)} dirty ${r.provenance.versions.sketch_dirty} | ends ${JSON.stringify(ends)} | multi ${multi}/${snaps} = ${fmt(multi / snaps)}`,
  );
  console.log(
    `  kpis ${JSON.stringify(Object.fromEntries(Object.entries(r.kpis).map(([k, v]) => [k, fmt(v.value)])))}`,
  );
  console.log(
    `  kris ${JSON.stringify(Object.fromEntries(Object.entries(r.kris).map(([k, v]) => [k, fmt(v.value)])))}`,
  );
  console.log(`  offered ${JSON.stringify(offered)}`);
  console.log(`  kept    ${JSON.stringify(kept)}`);
  console.log(`  chosen  ${JSON.stringify(chosen)}`);
}
