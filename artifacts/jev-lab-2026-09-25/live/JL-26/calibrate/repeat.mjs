// JL-26 repeat-pair equality: the same batch (scenario, arm, mode, seed 1, 20 trials)
// run twice at the same heads; trial i of one against trial i of the other.
//   node repeat.mjs <runs-root-a> <runs-root-b>
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";

const load = (root) => {
  const out = new Map();
  for (const d of readdirSync(root).filter((x) => /^\d{8}T/.test(x))) {
    const r = JSON.parse(readFileSync(path.join(root, d, "run.json"), "utf8"));
    const mode = /\b(rigid|kinematic)\b/.exec(r.config.launcher)[1];
    out.set(`${r.config.scenario} ${r.config.arm} ${mode}`, r);
  }
  return out;
};
const a = load(process.argv[2]);
const b = load(process.argv[3]);
const perMode = {};
console.log("batch\tequal_hash\tsame_end\tsame_success\tpairs\theads_a\theads_b");
for (const [key, ra] of [...a].sort()) {
  const rb = b.get(key);
  if (!rb) continue;
  const mode = key.split(" ")[2];
  const m = (perMode[mode] ??= { pairs: 0, equal: 0, sameEnd: 0, sameSuccess: 0 });
  let equal = 0;
  let sameEnd = 0;
  let sameSuccess = 0;
  let counted = 0;
  const n = Math.min(ra.config.trials.length, rb.config.trials.length);
  for (let i = 0; i < n; i += 1) {
    const ta = ra.config.trials[i];
    const tb = rb.config.trials[i];
    if (ta.seed !== tb.seed) throw new Error(`${key} trial ${i}: seeds differ`);
    if (ta.outcome !== "complete" || tb.outcome !== "complete") {
      m.skipped = (m.skipped ?? 0) + 1;
      console.log(`# ${key} trial ${i} skipped: ${ta.outcome} vs ${tb.outcome}`);
      continue;
    }
    counted += 1;
    if (ta.trace_hash === tb.trace_hash) equal += 1;
    if (ta.scenario_result.end === tb.scenario_result.end) sameEnd += 1;
    if ((ta.scenario_result.result === "success") === (tb.scenario_result.result === "success")) sameSuccess += 1;
  }
  m.pairs += counted;
  m.equal += equal;
  m.sameEnd += sameEnd;
  m.sameSuccess += sameSuccess;
  const heads = (r) => `${r.provenance.head.slice(0, 7)}${r.provenance.dirty ? "+dirty" : ""}/${r.provenance.versions.sketch_head.slice(0, 7)}${r.provenance.versions.sketch_dirty === "true" ? "+dirty" : ""}`;
  console.log([key, equal, sameEnd, sameSuccess, counted, heads(ra), heads(rb)].join("\t"));
  for (let i = 0; i < n; i += 1) {
    const ta = ra.config.trials[i];
    const tb = rb.config.trials[i];
    if (ta.outcome === "complete" && tb.outcome === "complete" && ta.trace_hash !== tb.trace_hash) {
      console.log(`#   differs: trial ${i} seed ${ta.seed} ${ta.scenario_result.end}@${ta.scenario_result.tick} vs ${tb.scenario_result.end}@${tb.scenario_result.tick}`);
    }
  }
}
console.log("\n# per mode: pairs with an identical trace_hash, the same end, the same success");
for (const [mode, m] of Object.entries(perMode)) {
  console.log(`${mode}\t${m.skipped ?? 0} pairs skipped (a trial did not complete)\t${m.equal}/${m.pairs} equal hash\t${m.sameEnd}/${m.pairs} same end\t${m.sameSuccess}/${m.pairs} same success`);
}
