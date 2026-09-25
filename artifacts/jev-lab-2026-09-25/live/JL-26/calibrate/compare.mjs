// JL-26 arm comparison per scenario and mode, from one pass's run records.
//   node compare.mjs <runs-root>
// Scenario success per arm (Wilson) and random - scripted (Newcombe); descriptive. JL-28 owns the pre-registered comparison.
// Everything else is descriptive, chosen after the exploratory runs, and labelled so.
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { wilson, newcombe } from "../../../../../scripts/lab/stats.mjs";

const root = process.argv[2];
const records = readdirSync(root)
  .filter((d) => /^\d{8}T/.test(d))
  .map((d) => JSON.parse(readFileSync(path.join(root, d, "run.json"), "utf8")));
const modeOf = (r) => /\b(rigid|kinematic)\b/.exec(r.config.launcher)[1];
const key = (r) => `${r.config.scenario}\t${modeOf(r)}`;
const groups = new Map();
for (const r of records) {
  if (!groups.has(key(r))) groups.set(key(r), {});
  groups.get(key(r))[r.config.arm] = r;
}
const mean = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : NaN);
const median = (xs) => {
  if (!xs.length) return NaN;
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.floor((s.length - 1) / 2)];
};
const f = (x, d = 2) => (Number.isFinite(x) ? x.toFixed(d) : "-");

console.log("# scenario success and every column after the bar: descriptive, not a pre-registered comparison (JL-28 owns that)");
console.log(
  ["scenario", "mode", "arm", "n", "success", "wilson95", "scrapped", "limit", "|",
    "choice_share", "caches", "scrap", "ledge_visits", "stomp", "ram", "end_s_median",
    "tier_end_mean", "chaser_hits", "miniboss_hits", "lobber_hits", "cableway_hits", "gated_share"].join("\t"),
);
const diffs = [];
for (const [k, arms] of [...groups].sort()) {
  const counts = {};
  for (const arm of ["random", "scripted"]) {
    const r = arms[arm];
    if (!r) continue;
    const res = r.config.trials.map((t) => t.scenario_result).filter(Boolean);
    const n = res.length;
    const ok = res.filter((s) => s.result === "success").length;
    counts[arm] = { ok, n };
    const w = wilson(ok, n);
    const hits = (kind) => mean(res.map((s) => s.contact?.[kind]?.hits ?? 0));
    const sum = (t) => Object.values(t ?? {}).reduce((a, b) => a + b, 0);
    const offered = res.reduce((a, s) => a + sum(s.offered), 0);
    const kept = res.reduce((a, s) => a + sum(s.kept), 0);
    console.log(
      [k, arm, n, ok, `[${f(w.lower)}, ${f(w.upper)}]`,
        res.filter((s) => s.end === "scrapped").length,
        res.filter((s) => s.end === "limit").length, "|",
        f(res.reduce((a, s) => a + s.multi, 0) / res.reduce((a, s) => a + s.snapshots, 0), 3),
        f(mean(res.map((s) => s.caches_opened))),
        f(mean(res.map((s) => s.scrap_taken)), 1),
        f(mean(res.map((s) => s.mesa_visits.length))),
        f(mean(res.map((s) => s.knocks.stomp)), 1),
        f(mean(res.map((s) => s.knocks.ram)), 1),
        f(median(res.map((s) => s.tick / 90)), 1),
        f(mean(res.map((s) => s.stage_tier))),
        f(hits("chaser"), 1), f(hits("miniboss"), 1), f(hits("lobber"), 1),
        f(mean(res.map((s) => s.cableway_hits)), 2),
        f((offered - kept) / offered, 3)].join("\t"),
    );
  }
  if (counts.random && counts.scripted) {
    const d = newcombe(counts.random.ok, counts.random.n, counts.scripted.ok, counts.scripted.n);
    diffs.push(`${k}\trandom-scripted ${f(d.estimate)} [${f(d.lower)}, ${f(d.upper)}]`);
  }
}
console.log("\n# Newcombe 95% for success(random) - success(scripted)");
for (const line of diffs) console.log(line);
