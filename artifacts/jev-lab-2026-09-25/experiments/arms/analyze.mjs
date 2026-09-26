// JL-28 analysis: reads batch records, pairs trials by trial seed, and
// computes what PREREGISTRATION.md fixes. Self-contained so its sha256 pins
// every statistic it computes.
//
//   node analyze.mjs --self-test
//   node analyze.mjs --prior [--out dir]          prior records (seed 1)
//   node analyze.mjs --manifest batches.ndjson --head <sha> [--out dir]
import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, writeFileSync, mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

const here = path.dirname(fileURLToPath(import.meta.url));
export const REPO = path.resolve(here, "../../../..");
export const DESIGN = path.join(here, "design.json");
const Z = 1.959963984540054;

export function loadDesign(file = DESIGN) {
  return JSON.parse(readFileSync(file, "utf8"));
}

export function wilson(k, n) {
  if (n === 0) return [0, 1];
  const p = k / n;
  const z2 = Z * Z;
  const centre = (p + z2 / (2 * n)) / (1 + z2 / n);
  const half = (Z * Math.sqrt((p * (1 - p)) / n + z2 / (4 * n * n))) / (1 + z2 / n);
  return [Math.max(0, centre - half), Math.min(1, centre + half)];
}

// Newcombe (1998a) method 10: hybrid score interval for p1 - p2, independent.
export function newcombeUnpaired(k1, n1, k2, n2) {
  const p1 = k1 / n1;
  const p2 = k2 / n2;
  const [l1, u1] = wilson(k1, n1);
  const [l2, u2] = wilson(k2, n2);
  const d = p1 - p2;
  return {
    diff: d,
    lower: d - Math.sqrt((p1 - l1) ** 2 + (u2 - p2) ** 2),
    upper: d + Math.sqrt((u1 - p1) ** 2 + (p2 - l2) ** 2),
  };
}

// Newcombe (1998b, Stat Med 17:2635, p. 2640) method 10: score interval for
// p1 - p2 on paired data, phi's numerator max(ad - bc - n/2, 0) when ad > bc.
// a both succeed, b only arm 1, c only arm 2, d neither.
export function newcombePaired(a, b, c, d) {
  const n = a + b + c + d;
  const p1 = (a + b) / n;
  const p2 = (a + c) / n;
  const [l1, u1] = wilson(a + b, n);
  const [l2, u2] = wilson(a + c, n);
  const margins = (a + b) * (c + d) * (a + c) * (b + d);
  const cross = a * d - b * c;
  const numerator = cross > 0 ? Math.max(cross - n / 2, 0) : cross;
  const phi = margins === 0 ? 0 : numerator / Math.sqrt(margins);
  const diff = p1 - p2;
  const lowerTerm = (p1 - l1) ** 2 - 2 * phi * (p1 - l1) * (u2 - p2) + (u2 - p2) ** 2;
  const upperTerm = (u1 - p1) ** 2 - 2 * phi * (u1 - p1) * (p2 - l2) + (p2 - l2) ** 2;
  return {
    diff,
    lower: Math.max(-1, diff - Math.sqrt(Math.max(0, lowerTerm))),
    upper: Math.min(1, diff + Math.sqrt(Math.max(0, upperTerm))),
  };
}

function logChoose(n, k) {
  let s = 0;
  for (let i = 1; i <= k; i += 1) s += Math.log(n - k + i) - Math.log(i);
  return s;
}

// P(X >= k) for X ~ Binomial(n, 1/2).
export function binomUpperHalf(k, n) {
  if (k <= 0) return 1;
  if (k > n) return 0;
  let total = 0;
  for (let i = k; i <= n; i += 1) total += Math.exp(logChoose(n, i) - n * Math.LN2);
  return Math.min(1, total);
}

// Exact McNemar on the discordant pairs. `favoured` is the count in the
// pre-registered direction, `other` the count against it.
export function mcnemar(favoured, other) {
  const m = favoured + other;
  if (m === 0) return { one_sided: 1, two_sided: 1 };
  const upper = binomUpperHalf(favoured, m);
  const lower = binomUpperHalf(other, m);
  return { one_sided: upper, two_sided: Math.min(1, 2 * Math.min(upper, lower)) };
}

// Holm step-down. Returns adjusted p values in input order.
export function holm(ps) {
  const k = ps.length;
  const order = ps.map((p, i) => [p, i]).sort((x, y) => x[0] - y[0] || x[1] - y[1]);
  const adjusted = new Array(k);
  let running = 0;
  order.forEach(([p, i], j) => {
    running = Math.max(running, Math.min(1, (k - j) * p));
    adjusted[i] = running;
  });
  return adjusted;
}

function binomPmf(n, k, p) {
  if (p <= 0) return k === 0 ? 1 : 0;
  if (p >= 1) return k === n ? 1 : 0;
  return Math.exp(logChoose(n, k) + k * Math.log(p) + (n - k) * Math.log(1 - p));
}

// Chance that the one-sided exact McNemar rejects at `alpha` with n pairs,
// when a pair is discordant in the favoured direction with probability pf
// and against it with probability po. Planning only.
export function pairedPower(pf, po, n, alpha) {
  const pd = pf + po;
  if (pd === 0) return 0;
  const share = pf / pd;
  let power = 0;
  for (let m = 1; m <= n; m += 1) {
    const pm = binomPmf(n, m, pd);
    if (pm < 1e-15) continue;
    for (let f = 0; f <= m; f += 1) {
      if (binomUpperHalf(f, m) <= alpha) power += pm * binomPmf(m, f, share);
    }
  }
  return power;
}

const quantile = (sorted, q) =>
  sorted.length === 0 ? null : sorted[Math.min(sorted.length - 1, Math.ceil(q * sorted.length) - 1)];

const modeOf = (config) => (/\brigid\b/.test(config.launcher) ? "rigid" : "kinematic");
const sketchOf = (config) => {
  const match = /\bsketch (\S+)/.exec(config.launcher);
  return match === null ? "ball-lab" : match[1];
};

export function readRecord(runDir) {
  return JSON.parse(readFileSync(path.join(runDir, "run.json"), "utf8"));
}

// Events-derived measures for one trial; null when the trial directory is gone.
export function trialEvents(runDir, entry) {
  const file = path.join(runDir, entry.io ?? "", "events.ndjson");
  if (entry.io === null || !existsSync(file)) return null;
  const counts = { stuck: 0, anomalies: {}, tiers: {} };
  for (const line of readFileSync(file, "utf8").split("\n")) {
    if (line === "") continue;
    const event = JSON.parse(line);
    if (event.kind === "stuck_begin") counts.stuck += 1;
    if (event.kind === "anomaly") counts.anomalies[event.what] = (counts.anomalies[event.what] ?? 0) + 1;
    if (event.kind === "trace") counts.tiers[event.tier] = (counts.tiers[event.tier] ?? 0) + 1;
  }
  return counts;
}

const TIERS = ["walk", "cruise", "fast", "blazing"];

// Exploratory measures for one arm of one cell. None of these is a test.
export function exploratory(runDir, trials, tickHz = 90) {
  const results = trials.map((t) => t.scenario_result);
  const n = trials.length;
  const successTicks = results
    .filter((r) => r.result === "success" && r.success_tick >= 0)
    .map((r) => r.success_tick / tickHz)
    .sort((x, y) => x - y);
  const mean = (values) => (values.length === 0 ? null : values.reduce((s, v) => s + v, 0) / values.length);
  const events = trials.map((t) => trialEvents(runDir, t));
  const withEvents = events.filter((e) => e !== null);
  const tierTotals = Object.fromEntries(TIERS.map((t) => [t, 0]));
  for (const e of withEvents) for (const [tier, c] of Object.entries(e.tiers)) tierTotals[tier] = (tierTotals[tier] ?? 0) + c;
  const traced = Object.values(tierTotals).reduce((s, v) => s + v, 0);
  let dead = null;
  if (traced > 0) {
    const [tier, count] = Object.entries(tierTotals).sort((x, y) => x[1] - y[1])[0];
    dead = { tier, share: count / traced, shares: Object.fromEntries(Object.entries(tierTotals).map(([t, c]) => [t, c / traced])) };
  }
  const anomalyKinds = {};
  for (const e of withEvents) for (const [what, c] of Object.entries(e.anomalies)) anomalyKinds[what] = (anomalyKinds[what] ?? 0) + c;
  return {
    time_to_success_s: { n: successTicks.length, p50: quantile(successTicks, 0.5), p90: quantile(successTicks, 0.9) },
    deaths: results.filter((r) => r.end === "scrapped" || (typeof r.dead_tick === "number" && r.dead_tick >= 0)).length,
    anomalies_per_trial: mean(results.map((r) => r.anomalies ?? 0)),
    trials_with_anomaly: results.filter((r) => (r.anomalies ?? 0) > 0).length,
    anomaly_kinds: withEvents.length === 0 ? null : anomalyKinds,
    stuck_per_trial: withEvents.length === 0 ? null : mean(withEvents.map((e) => e.stuck)),
    trials_with_stuck: withEvents.length === 0 ? null : withEvents.filter((e) => e.stuck > 0).length,
    dead_tier: dead,
    events_trials: withEvents.length,
    knocks_stomp_per_trial: mean(results.map((r) => r.knocks?.stomp ?? 0)),
    knocks_ram_per_trial: mean(results.map((r) => r.knocks?.ram ?? 0)),
    gates_mean: results.some((r) => typeof r.gates === "number") ? mean(results.map((r) => r.gates ?? 0)) : null,
    n,
  };
}

// Batch-level validity against the plan. Returns a list of problems.
export function batchProblems(record, { cell, arm, design, head, live }) {
  const problems = [];
  const c = record.config;
  const sketch = design.sketches[cell.sketch];
  if (c.scenario !== cell.scenario) problems.push(`scenario ${c.scenario}`);
  if (c.arm !== arm) problems.push(`arm ${c.arm}`);
  if (modeOf(c) !== cell.mode) problems.push(`mode ${modeOf(c)}`);
  if (sketchOf(c) !== cell.sketch) problems.push(`sketch ${sketchOf(c)}`);
  if (record.provenance.dirty !== false) problems.push("dirty");
  if (record.provenance.sources?.matched !== true) problems.push("sources changed during the batch");
  if ((record.provenance.jev?.calls ?? 0) !== 0 || record.provenance.instrument !== null) problems.push("jev calls or instrument present");
  if (sketch.repository !== "self") {
    const v = record.provenance.versions ?? {};
    if (v.sketch_head !== sketch.head) problems.push(`sketch_head ${v.sketch_head}`);
    if (v.sketch_dirty !== "false") problems.push(`sketch_dirty ${v.sketch_dirty}`);
  }
  if (live) {
    if (record.provenance.head !== head) problems.push(`head ${record.provenance.head}`);
    if (c.seed !== design.batch_seed) problems.push(`batch seed ${c.seed}`);
    if (c.trials.length !== cell.n) problems.push(`${c.trials.length} of ${cell.n} trials`);
    c.trials.forEach((t, i) => {
      if (t.seed !== design.batch_seed * design.trial_seed_stride + i) problems.push(`trial ${i} seed ${t.seed}`);
    });
  }
  return problems;
}

function trialOk(entry, cell, design) {
  const r = entry.scenario_result;
  if (entry.outcome !== "complete" || r === null || !["success", "timeout"].includes(r.result)) return false;
  const want = design.sketches[cell.sketch].trial_epoch;
  if (want !== undefined && r.epoch !== want) return false;
  return true;
}

const share = (trials) => {
  const snapshots = trials.reduce((s, t) => s + t.snapshots, 0);
  const calls = trials.reduce((s, t) => s + t.arm_calls, 0);
  return { value: snapshots === 0 ? 0 : calls / snapshots, arm_calls: calls, snapshots };
};

// One cell: pairs, primary statistic, validity and exploratory measures.
export function analyseCell(cell, batches, design, options) {
  const out = { id: cell.id, sketch: cell.sketch, scenario: cell.scenario, mode: cell.mode, class: cell.class, direction: cell.direction ?? null, status: "ok", problems: [] };
  for (const arm of design.arms) {
    const batch = batches[arm];
    if (batch === undefined) {
      out.status = "blocked";
      out.problems.push(`${arm}: no record`);
      continue;
    }
    if (batch.exit !== undefined && batch.exit !== 0) {
      out.status = "blocked";
      out.problems.push(`${arm}: launcher exit ${batch.exit}`);
    }
    const problems = batchProblems(batch.record, { cell, arm, design, head: options.head, live: options.live });
    if (problems.length > 0) {
      out.status = "blocked";
      out.problems.push(...problems.map((p) => `${arm}: ${p}`));
    }
  }
  if (out.status === "blocked" && design.arms.some((arm) => batches[arm] === undefined)) return out;
  const [first, second] = design.arms.map((arm) => batches[arm].record.config.trials);
  const bySeed = (trials) => new Map(trials.map((t) => [t.seed, t]));
  const seeds = [...bySeed(first).keys()].filter((s) => bySeed(second).has(s)).sort((x, y) => x - y);
  const paired = seeds.length === first.length && seeds.length === second.length;
  const kept = { [design.arms[0]]: [], [design.arms[1]]: [] };
  let excluded = 0;
  for (const seed of seeds) {
    const x = bySeed(first).get(seed);
    const y = bySeed(second).get(seed);
    if (trialOk(x, cell, design) && trialOk(y, cell, design)) {
      kept[design.arms[0]].push(x);
      kept[design.arms[1]].push(y);
    } else {
      excluded += 1;
    }
  }
  out.pairs = kept[design.arms[0]].length;
  out.pairs_excluded = excluded;
  out.paired_by_seed = paired;
  if (excluded > design.max_excluded_pair_share * seeds.length) {
    out.status = "blocked";
    out.problems.push(`${excluded} of ${seeds.length} pairs excluded`);
  }
  const win = (t) => t.scenario_result.result === "success";
  const [S, R] = ["scripted", "random"].map((arm) => kept[arm]);
  let a = 0, bR = 0, cS = 0, d = 0;
  S.forEach((s, i) => {
    const r = R[i];
    if (win(r) && win(s)) a += 1;
    else if (win(r)) bR += 1;
    else if (win(s)) cS += 1;
    else d += 1;
  });
  const n = out.pairs;
  out.success = {
    random: { k: a + bR, n, wilson: wilson(a + bR, n) },
    scripted: { k: a + cS, n, wilson: wilson(a + cS, n) },
  };
  out.table = { both: a, random_only: bR, scripted_only: cS, neither: d };
  out.random_minus_scripted = {
    paired: n > 0 ? newcombePaired(a, bR, cS, d) : null,
    unpaired: n > 0 ? newcombeUnpaired(a + bR, n, a + cS, n) : null,
  };
  const [favoured, other] = cell.direction === "scripted>random" ? [cS, bR] : [bR, cS];
  out.mcnemar = paired ? mcnemar(favoured, other) : null;
  out.multi_share = { scripted: share(S), random: share(R) };
  out.multi_share_valid = out.multi_share.scripted.value >= design.multi_share_min && out.multi_share.random.value >= design.multi_share_min;
  if (!paired) out.problems.push("trials do not pair by seed; unpaired Newcombe over the shared seeds only");
  if (!out.multi_share_valid && out.status === "ok") out.status = "invalid";
  out.exploratory = {
    scripted: exploratory(batches.scripted.dir, S),
    random: exploratory(batches.random.dir, R),
  };
  return out;
}

export function decide(cells, design) {
  const confirmatory = cells.filter((c) => c.class === "confirmatory");
  const ps = confirmatory.map((c) => (c.status === "ok" && c.mcnemar !== null ? c.mcnemar.one_sided : 1));
  const adjusted = holm(ps);
  confirmatory.forEach((c, i) => {
    c.holm_p = adjusted[i];
    if (c.status === "blocked") c.verdict = "BLOCKED";
    else if (c.status === "invalid") c.verdict = "INVALID (multi-option share below the line)";
    else if (c.mcnemar === null) c.verdict = "BLOCKED (not paired)";
    else c.verdict = adjusted[i] <= design.alpha ? "SUPPORTED" : "NOT SUPPORTED";
    const d = c.random_minus_scripted?.paired?.diff;
    const wrong = d !== undefined && (c.direction === "random>scripted" ? d < 0 : d > 0);
    c.reversal_flag = Boolean(wrong && c.mcnemar !== null && c.mcnemar.two_sided < design.alpha);
  });
  const blocked = cells.filter((c) => c.status === "blocked" || (c.class === "confirmatory" && c.mcnemar === null)).length;
  return { run_blocked: blocked * 3 >= cells.length, blocked_cells: blocked };
}

// A precondition that failed after the run blocks every cell of its sketch
// (sketch null: every cell).
export function applyAfter(cells, after) {
  if (after === null) return ["provenance-after.json missing: the runner did not finish"];
  const failed = (after.preconditions ?? []).filter((p) => !p.ok);
  for (const p of failed) {
    for (const c of cells) {
      if (p.sketch !== null && p.sketch !== c.sketch) continue;
      c.status = "blocked";
      c.problems.push(`after the run: ${p.name} (${p.detail})`);
    }
  }
  return failed.map((p) => `after the run: ${p.name}`);
}

// Records from directories of run folders, grouped by sketch, scenario, mode, arm.
export function collect(dirs) {
  const groups = new Map();
  for (const dir of dirs) {
    for (const name of readdirSync(dir)) {
      const runDir = path.join(dir, name);
      if (!existsSync(path.join(runDir, "run.json"))) continue;
      const record = readRecord(runDir);
      const c = record.config;
      const key = `${sketchOf(c)}|${c.scenario}|${modeOf(c)}|${c.arm}`;
      if (groups.has(key)) throw new Error(`two records for ${key}: ${groups.get(key).dir} and ${runDir}`);
      groups.set(key, { dir: runDir, record });
    }
  }
  return groups;
}

export function analyse(design, groups, options) {
  const cells = design.cells.map((cell) => {
    const batches = {};
    for (const arm of design.arms) {
      const g = groups.get(`${cell.sketch}|${cell.scenario}|${cell.mode}|${arm}`);
      if (g !== undefined) batches[arm] = g;
    }
    return analyseCell(cell, batches, design, options);
  });
  const after = options.live ? applyAfter(cells, options.after ?? null) : [];
  const summary = decide(cells, design);
  if (options.live && (options.after ?? null) === null) summary.run_blocked = true;
  summary.after = after;
  return { cells, summary };
}

const f2 = (x) => (x === null || x === undefined ? "-" : x.toFixed(2));
const f3 = (x) => (x === null || x === undefined ? "-" : x < 0.001 ? x.toExponential(1) : x.toFixed(3));
const ci = (i) => (i === null ? "-" : `${f2(i.diff)} [${f2(i.lower)}, ${f2(i.upper)}]`);

export function render(result, { title, planning = null }) {
  const lines = [`# ${title}`, "", "Automated; not a feel verdict.", ""];
  lines.push("## Primary metric: the scenario's own success predicate", "");
  lines.push("| Cell | Class | Direction | Status | Scripted | Random | Pairs (both/R only/S only/neither) | R − S paired Newcombe | R − S unpaired | McNemar one-sided | two-sided | Holm | Verdict | Multi share S / R |");
  lines.push("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |");
  for (const c of result.cells) {
    if (c.success === undefined) {
      lines.push(`| ${c.id} | ${c.class} | ${c.direction ?? "-"} | ${c.status}: ${c.problems.join("; ")} | - | - | - | - | - | - | - | - | ${c.verdict ?? "-"} | - |`);
      continue;
    }
    const t = c.table;
    const tested = c.class === "confirmatory";
    lines.push(
      `| ${c.id} | ${c.class} | ${c.direction ?? "-"} | ${c.status}${c.problems.length ? ` (${c.problems.join("; ")})` : ""} | ${c.success.scripted.k}/${c.success.scripted.n} | ${c.success.random.k}/${c.success.random.n} | ${t.both}/${t.random_only}/${t.scripted_only}/${t.neither} | ${ci(c.random_minus_scripted.paired)} | ${ci(c.random_minus_scripted.unpaired)} | ${tested && c.mcnemar ? f3(c.mcnemar.one_sided) : "-"} | ${c.mcnemar ? f3(c.mcnemar.two_sided) : "-"}${tested ? "" : " (exploratory)"} | ${tested ? f3(c.holm_p) : "-"} | ${tested ? c.verdict + (c.reversal_flag ? "; reversal flag" : "") : "not tested"} | ${f2(c.multi_share.scripted.value)} / ${f2(c.multi_share.random.value)} |`,
    );
  }
  lines.push("", `Blocked cells (unpaired confirmatory included): ${result.summary.blocked_cells}. Run blocked: ${result.summary.run_blocked}.${result.summary.after.length ? ` ${result.summary.after.join("; ")}.` : ""}`, "");
  if (planning !== null) {
    lines.push("## Planning: power at the planned n from the prior discordance (unverified-computed)", "");
    lines.push("| Cell | Direction | Planned n | Prior favoured / against pairs of 20 | Power at α/5 | Power at α |", "| --- | --- | --- | --- | --- | --- |");
    for (const p of planning) lines.push(`| ${p.id} | ${p.direction} | ${p.n} | ${p.favoured}/${p.other} | ${f2(p.power_bonferroni)} | ${f2(p.power_alpha)} |`);
    lines.push("");
  }
  lines.push("## Exploratory measures (not pre-registered as tests)", "");
  lines.push("| Cell | Arm | Time to success p50 / p90 s (n) | Deaths | Stuck per trial (trials with stuck) | Dead tier (share) | Anomalies per trial (trials) | Stomp / ram knocks per trial | Gates mean |");
  lines.push("| --- | --- | --- | --- | --- | --- | --- | --- | --- |");
  for (const c of result.cells) {
    if (c.exploratory === undefined) continue;
    for (const arm of ["scripted", "random"]) {
      const e = c.exploratory[arm];
      const tts = e.time_to_success_s;
      lines.push(
        `| ${c.id} | ${arm} | ${f2(tts.p50)} / ${f2(tts.p90)} (${tts.n}) | ${e.deaths}/${e.n} | ${e.stuck_per_trial === null ? "no events" : `${f2(e.stuck_per_trial)} (${e.trials_with_stuck})`} | ${e.dead_tier === null ? "no events" : `${e.dead_tier.tier} ${f3(e.dead_tier.share)}`} | ${f2(e.anomalies_per_trial)} (${e.trials_with_anomaly}) | ${f2(e.knocks_stomp_per_trial)} / ${f2(e.knocks_ram_per_trial)} | ${f2(e.gates_mean)} |`,
      );
    }
  }
  lines.push("");
  return lines.join("\n");
}

export function planning(result, design) {
  const k = design.cells.filter((c) => c.class === "confirmatory").length;
  return result.cells
    .filter((c) => c.class === "confirmatory" && c.table !== undefined)
    .map((c) => {
      const cell = design.cells.find((x) => x.id === c.id);
      const [favoured, other] = c.direction === "scripted>random" ? [c.table.scripted_only, c.table.random_only] : [c.table.random_only, c.table.scripted_only];
      const pf = favoured / c.pairs;
      const po = other / c.pairs;
      return {
        id: c.id,
        direction: c.direction,
        n: cell.n,
        favoured,
        other,
        power_bonferroni: pairedPower(pf, po, cell.n, design.alpha / k),
        power_alpha: pairedPower(pf, po, cell.n, design.alpha),
      };
    });
}

function close(actual, expected, tolerance, label, failures) {
  if (Math.abs(actual - expected) > tolerance) failures.push(`${label}: ${actual} vs ${expected}`);
}

export function selfTest() {
  const failures = [];
  const w = wilson(3, 20);
  close(w[0], 0.0524, 0.0005, "wilson 3/20 lower (JL-21 review)", failures);
  close(w[1], 0.3604, 0.0005, "wilson 3/20 upper", failures);
  const u1 = newcombeUnpaired(11, 20, 1, 20);
  close(u1.lower, 0.221, 0.0015, "newcombe 11/20 vs 1/20 lower (JL-21b review)", failures);
  close(u1.upper, 0.696, 0.0015, "newcombe 11/20 vs 1/20 upper", failures);
  const u2 = newcombeUnpaired(17, 20, 9, 20);
  close(u2.lower, 0.104, 0.0015, "newcombe 17/20 vs 9/20 lower (JL-21b review)", failures);
  close(u2.upper, 0.616, 0.0015, "newcombe 17/20 vs 9/20 upper", failures);
  const u3 = newcombeUnpaired(14, 20, 0, 20);
  close(u3.lower, 0.43, 0.005, "newcombe 14/20 vs 0/20 lower (JL-21 review)", failures);
  close(u3.upper, 0.85, 0.005, "newcombe 14/20 vs 0/20 upper", failures);
  const u4 = newcombeUnpaired(8, 20, 12, 20);
  close(u4.lower, -0.46, 0.005, "newcombe 8/20 vs 12/20 lower (JL-26 33-a2-compare)", failures);
  close(u4.upper, 0.10, 0.005, "newcombe 8/20 vs 12/20 upper", failures);
  const p0 = newcombePaired(5, 3, 3, 9);
  const i0 = newcombeUnpaired(8, 20, 8, 20);
  close(p0.diff, 0, 1e-12, "paired zero difference", failures);
  close(p0.upper, -p0.lower, 1e-12, "paired interval symmetric at zero difference", failures);
  if (!(p0.upper - p0.lower < i0.upper - i0.lower)) failures.push("positive correlation narrows the paired interval");
  const ind = newcombePaired(4, 4, 6, 6);
  const indU = newcombeUnpaired(8, 20, 10, 20);
  close(ind.lower, indU.lower, 1e-12, "phi 0 reduces paired to unpaired (lower)", failures);
  close(ind.upper, indU.upper, 1e-12, "phi 0 reduces paired to unpaired (upper)", failures);
  const m10 = newcombePaired(1, 10, 0, 9);
  close(m10.lower, u1.lower, 1e-12, "method 10 (1,10,0,9): ad - bc = 9 <= n/2 gives phi 0, paired equals unpaired (lower)", failures);
  close(m10.upper, u1.upper, 1e-12, "method 10 (1,10,0,9): paired equals unpaired (upper)", failures);
  const cells = [
    { class: "confirmatory", status: "ok", mcnemar: null, sketch: "ball-lab", problems: [] },
    { class: "floor", status: "invalid", mcnemar: { one_sided: 1, two_sided: 1 }, sketch: "cable-bench", problems: [] },
    { class: "floor", status: "ok", mcnemar: { one_sided: 1, two_sided: 1 }, sketch: "cable-bench", problems: [] },
  ];
  const counted = decide(cells, { alpha: 0.05 }).blocked_cells;
  if (counted !== 1) failures.push(`run-block count includes not-paired confirmatory cells and excludes INVALID cells: ${counted} vs 1`);
  applyAfter(cells, { preconditions: [{ name: "cable-bench head", ok: false, detail: "x", sketch: "cable-bench" }] });
  if (cells[2].status !== "blocked" || cells[0].status !== "ok") failures.push("a failed after-run precondition blocks only its sketch's cells");
  close(binomUpperHalf(8, 8), 1 / 256, 1e-15, "P(X>=8|8)", failures);
  close(binomUpperHalf(9, 10), 11 / 1024, 1e-15, "P(X>=9|10)", failures);
  close(binomUpperHalf(0, 5), 1, 0, "P(X>=0)", failures);
  const m = mcnemar(7, 1);
  close(m.one_sided, 9 / 256, 1e-15, "mcnemar 7 vs 1 one-sided", failures);
  close(m.two_sided, 18 / 256, 1e-15, "mcnemar 7 vs 1 two-sided", failures);
  const h = holm([0.01, 0.04, 0.03]);
  close(h[0], 0.03, 1e-12, "holm first", failures);
  close(h[1], 0.06, 1e-12, "holm second", failures);
  close(h[2], 0.06, 1e-12, "holm third", failures);
  close(pairedPower(0, 0.5, 20, 0.05), 0, 1e-12, "power is 0 when every discordant pair goes the other way", failures);
  close(pairedPower(0.5, 0, 20, 0.05), 1 - binomPmf(20, 0, 0.5) - binomPmf(20, 1, 0.5) - binomPmf(20, 2, 0.5) - binomPmf(20, 3, 0.5) - binomPmf(20, 4, 0.5), 1e-12, "power with all discordance favoured needs m >= 5", failures);
  return failures;
}

export const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");

function main(argv) {
  const { values } = parseArgs({
    args: argv,
    options: {
      "self-test": { type: "boolean", default: false },
      prior: { type: "boolean", default: false },
      manifest: { type: "string" },
      head: { type: "string" },
      out: { type: "string" },
    },
  });
  if (values["self-test"]) {
    const failures = selfTest();
    for (const f of failures) console.log(`FAIL ${f}`);
    console.log(failures.length === 0 ? "self-test: all checks pass" : `self-test: ${failures.length} failures`);
    return failures.length === 0 ? 0 : 1;
  }
  const design = loadDesign();
  let result;
  let title;
  let plan = null;
  if (values.prior) {
    const dirs = design.prior_sources.map((p) => path.resolve(REPO, p));
    const missing = dirs.filter((d) => !existsSync(d));
    if (missing.length > 0) {
      console.error(`prior sources missing: ${missing.join(", ")}`);
      return 2;
    }
    result = analyse(design, collect(dirs), { live: false });
    plan = planning(result, design);
    title = "JL-28 analysis dry run on prior records (seed 1, trials 1000 to 1019); planning only, not a result";
  } else if (values.manifest !== undefined && values.head !== undefined) {
    const groups = new Map();
    const manifest = path.resolve(values.manifest);
    for (const line of readFileSync(manifest, "utf8").split("\n")) {
      if (line === "") continue;
      const b = JSON.parse(line);
      const cell = design.cells.find((c) => c.id === b.cell);
      if (b.run_dir === null) continue;
      const dir = path.resolve(path.dirname(manifest), b.run_dir);
      groups.set(`${cell.sketch}|${cell.scenario}|${cell.mode}|${b.arm}`, { dir, record: readRecord(dir), exit: b.exit });
    }
    const afterFile = path.join(path.dirname(manifest), "provenance-after.json");
    const after = existsSync(afterFile) ? JSON.parse(readFileSync(afterFile, "utf8")) : null;
    result = analyse(design, groups, { live: true, head: values.head, after });
    title = "JL-28 results as they fell (batch seed 2)";
  } else {
    console.error("usage: analyze.mjs --self-test | --prior [--out dir] | --manifest file --head sha [--out dir]");
    return 2;
  }
  const text = render(result, { title, planning: plan });
  console.log(text);
  if (values.out !== undefined) {
    mkdirSync(values.out, { recursive: true });
    writeFileSync(path.join(values.out, "results.json"), JSON.stringify({ ...result, planning: plan }, null, 2) + "\n");
    writeFileSync(path.join(values.out, "results.md"), text + "\n");
  }
  return 0;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
