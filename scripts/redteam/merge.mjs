#!/usr/bin/env node
// node scripts/redteam/merge.mjs --out=<dir> <findings.json>...
// Joins passes that ran in separate sandboxes (a sweep split with --block) into one page. A finding
// seen in several passes becomes one line with all their runs, at the worst severity any gave it.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { SEVERITIES, carryList, rank, renderMarkdown } from "./lib.mjs";

const args = process.argv.slice(2);
const out = args.find((a) => a.startsWith("--out="))?.slice(6);
const inputs = args.filter((a) => !a.startsWith("--"));
if (!out || inputs.length === 0) {
  console.error("redteam merge: usage: --out=<dir> <findings.json>...");
  process.exit(1);
}
const passes = inputs.map((f) => JSON.parse(readFileSync(f, "utf8")));
const byKey = new Map();
for (const pass of passes) {
  for (const f of pass.findings) {
    // Passes before the fuzz budget fix logged a fuzz timeout as a game finding; it was the harness.
    if (f.key === "fuzz:stall_or_crash_in_fuzz" && /timeout/.test(pass.extras.fuzzSummary ?? "")) continue;
    const have = byKey.get(f.key);
    if (!have) byKey.set(f.key, { ...f, runs: [...f.runs] });
    else {
      have.runs.push(...f.runs);
      if (SEVERITIES.indexOf(f.severity) < SEVERITIES.indexOf(have.severity)) have.severity = f.severity;
    }
  }
}
const findings = rank([...byKey.values()]);
const results = passes.flatMap((p) => p.runs).map((r) => ({
  job: r, exit: r.exit, timedOut: r.outcome === "timeout", piles: r.piles ?? [], perf: r.hitches ?? { p99: null },
  row: ["crash", "timeout"].includes(r.outcome) ? null : { outcome: r.outcome, stage_reached: r.stage, game_seconds: r.game_seconds ?? 0, stages: [{ hits: r.hits ?? 0 }] },
}));
const first = passes[0];
const minutes = passes.reduce((n, p) => n + p.minutes, 0);
const extras = { ...first.extras, fuzzSummary: passes.map((p) => p.extras.fuzzSummary).filter(Boolean).join("; ") };
mkdirSync(out, { recursive: true });
const page = renderMarkdown({ wave: `${first.wave} (${passes.length} passes merged)`, commit: first.commit, started: first.started.slice(0, 16) + "Z", minutes, results, findings, extras });
writeFileSync(path.join(out, "findings.md"), page);
writeFileSync(path.join(out, "findings.json"), JSON.stringify({ wave: first.wave, commit: first.commit, started: first.started, minutes, merged: inputs, runs: passes.flatMap((p) => p.runs), extras, findings, carry: carryList(findings) }, null, 2));
console.log(page.split("\n").slice(0, 6).join("\n"));
