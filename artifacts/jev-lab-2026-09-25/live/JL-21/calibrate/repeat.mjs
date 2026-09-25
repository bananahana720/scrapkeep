// Determinism across repeated batches: for every (scenario, arm, mode, D, k,
// trial) present under both roots, whether trace_hash matches.
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

async function load(root) {
  const out = new Map();
  for (const name of (await readdir(root)).sort()) {
    if (name === "index.ndjson") continue;
    const { config } = JSON.parse(await readFile(path.join(root, name, "run.json"), "utf8"));
    const mode = /rigid/.test(config.launcher) ? "rigid" : "kinematic";
    for (const trial of config.trials) {
      const key = [config.scenario, config.arm, mode, config.snapshot_every, config.hold_ticks, config.seed, trial.trial].join("|");
      out.set(key, { hash: trial.trace_hash, seed: trial.seed, outcome: trial.outcome });
    }
  }
  return out;
}

const [first, second] = await Promise.all(process.argv.slice(2, 4).map(load));
const tally = new Map();
for (const [key, a] of first) {
  const b = second.get(key);
  if (b === undefined) continue;
  const group = key.split("|").slice(0, 5).join(" ");
  const entry = tally.get(group) ?? { pairs: 0, equal: 0, seeds: new Set(), differ: [] };
  entry.pairs += 1;
  entry.seeds.add(a.seed);
  if (a.hash !== null && a.hash === b.hash) entry.equal += 1;
  else entry.differ.push(`${a.seed}:${a.hash?.slice(0, 8)}/${b.hash?.slice(0, 8)}`);
  tally.set(group, entry);
}
console.log("scenario arm mode D k\tpairs\tidentical\tseeds\tdiffering");
for (const [group, entry] of [...tally].sort()) {
  console.log(`${group}\t${entry.pairs}\t${entry.equal}\t${entry.seeds.size}\t${entry.differ.join(" ") || "-"}`);
}
