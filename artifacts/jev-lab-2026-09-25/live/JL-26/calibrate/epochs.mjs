// A1 (stage-threat-rule 1: knocked foes dropped) vs A2 (stage-threat-rule 2: only dead
// or freed foes dropped), same seeds, same scenarios; descriptive.
//   node epochs.mjs <a1-runs-root> <a2-runs-root>
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
const load = (root) => {
  const out = new Map();
  for (const d of readdirSync(root).filter((x) => /^\d{8}T/.test(x))) {
    const r = JSON.parse(readFileSync(path.join(root, d, "run.json"), "utf8"));
    const mode = /\b(rigid|kinematic)\b/.exec(r.config.launcher)[1];
    out.set(`${r.config.scenario}\t${mode}\t${r.config.arm}`, r.config.trials.map((t) => t.scenario_result));
  }
  return out;
};
const a1 = load(process.argv[2]);
const a2 = load(process.argv[3]);
const mean = (xs) => xs.reduce((a, b) => a + b, 0) / xs.length;
const cell = (res) => {
  const n = res.length;
  return [
    `${res.filter((s) => s.result === "success").length}/${n}`,
    (res.filter((s) => s.end === "scrapped").length / n).toFixed(2),
    mean(res.map((s) => s.contact?.miniboss?.hits ?? 0)).toFixed(2),
    mean(res.map((s) => s.knocked)).toFixed(2),
    mean(res.map((s) => s.tick / 90)).toFixed(1),
  ];
};
console.log("# descriptive; A2 is the new epoch stage-threat-rule 2");
console.log(["scenario", "mode", "arm", "A1 success", "A2 success", "A1 scrapped", "A2 scrapped", "A1 miniboss hits", "A2 miniboss hits", "A1 foes knocked", "A2 foes knocked", "A1 mean end s", "A2 mean end s"].join("\t"));
for (const [k, r1] of [...a1].sort()) {
  const r2 = a2.get(k);
  if (!r2) continue;
  const c1 = cell(r1);
  const c2 = cell(r2);
  console.log([k, c1[0], c2[0], c1[1], c2[1], c1[2], c2[2], c1[3], c2[3], c1[4], c2[4]].join("\t"));
}
