// Post hoc progress metrics (chosen after seeing the arms batches): pillar-weave
// trials that passed at least 2 of its 4 gates; bench-climb trials that knocked
// 3 or more distinct dummies, and that landed a ram.
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

import { newcombe, wilson } from "../../../../../scripts/lab/stats.mjs";

const root = process.argv[2];
const metrics = {
  "pillar-weave": { "gates>=2": (r) => r.gates >= 2 },
  "bench-climb": { "knocked>=3": (r) => r.knocked >= 3, "ram>=1": (r) => r.knocks.ram >= 1 },
};
const got = {};
for (const name of (await readdir(root)).sort()) {
  if (name === "index.ndjson") continue;
  const { config } = JSON.parse(await readFile(path.join(root, name, "run.json"), "utf8"));
  const mode = /rigid/.test(config.launcher) ? "rigid" : "kinematic";
  for (const [metric, test] of Object.entries(metrics[config.scenario] ?? {})) {
    const key = `${config.scenario} ${metric} ${mode}`;
    got[key] ??= {};
    got[key][config.arm] = { k: config.trials.filter((t) => test(t.scenario_result)).length, n: config.trials.length };
  }
}
const f = (x) => x.toFixed(2);
for (const [key, { scripted: s, random: r }] of Object.entries(got)) {
  const ws = wilson(s.k, s.n);
  const wr = wilson(r.k, r.n);
  const d = newcombe(r.k, r.n, s.k, s.n);
  console.log(`${key}\tscripted ${s.k}/${s.n} [${f(ws.lower)}, ${f(ws.upper)}]\trandom ${r.k}/${r.n} [${f(wr.lower)}, ${f(wr.upper)}]\trandom-scripted ${f(d.estimate)} [${f(d.lower)}, ${f(d.upper)}]`);
}
