// Recomputes the check-set summary per universe from the retained score.json; no calls.
import { readFileSync } from "node:fs";
import { scoreCases } from "../../../../../scripts/lab/test-order.mjs";
const [scoreFile, casesFile] = process.argv.slice(2);
const report = JSON.parse(readFileSync(scoreFile, "utf8"));
const set = Object.values(report.sets)[0];
const cases = JSON.parse(readFileSync(casesFile, "utf8")).cases;
for (const universe of ["all", "godot", "node"]) {
  const subset = cases.filter((c) => universe === "all" || c.universe === universe);
  const s = scoreCases(subset, set.results);
  console.log(`${universe}: n=${s.cases} mean rank jev ${s.mean_rank.jev} current ${s.mean_rank.current} static ${s.mean_rank.static}; first_fail_s jobs1 ${JSON.stringify(s.mean_first_fail_s.jobs1)} jobs2 ${JSON.stringify(s.mean_first_fail_s.jobs2)}; vs current ${JSON.stringify(s.jev_vs_current)} vs static ${JSON.stringify(s.jev_vs_static)}; control ${s.control.passed} ${s.control.cases}; gap ${JSON.stringify(s.order_gap)}`);
}
for (const row of scoreCases(cases, set.results).rows) {
  console.log(`${row.id}: rank jev ${row.rank.jev} current ${row.rank.current} static ${row.rank.static}; jobs1 s jev ${row.seconds.jobs1.jev} current ${row.seconds.jobs1.current} static ${row.seconds.jobs1.static}`);
}
console.log(`models ${set.models} usage ${JSON.stringify(set.usage_totals)} cache_hits ${set.cache_hits} calls ${report.calls} questions_sha ${report.questions_sha} set sha256 ${set.sha256}`);
