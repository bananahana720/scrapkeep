#!/usr/bin/env node
// Turns a difficulty band read (scripts/challenge/run.mjs: its folder's runs.ndjson) into the receipts that scripts/world1-bands.mjs reads for five rows: strong-build-shows, warden-fairness,
// novice-deaths, brindle-worst-minute and brindle-stop-tax. Each receipt is { head, pass, measured, plant_caught }. Each row's plant is applied to a copy of the same
// read and graded by the same function; plant_caught is true only when the planted copy misses on every check the plant
// targets. A receipt passes only when its own checks pass and its plant was caught.
//
//   node scripts/gate/band-receipts.mjs --band <band read folder> [--band <shard folder> ...] --head <commit> --out <dir>
//
// Produce the band read with:
//   npm run challenge:bands -- --library=<library dir> --only=w1,w2,brindle,w1clear --seeds=48 --label=<name>
// It writes <out>/<row id>.json for each of the five rows.
import { mkdirSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { EXCLUDED, FAIRNESS, fairnessPool, gradeRun, median, parseNdjson } from "../challenge/lib.mjs";
import { worstWindows } from "../challenge/worst-window.mjs";

// World 1's fight cells in the band table: the dam Warden, the flume Warden and Admiral Brindle.
export const W1_FIGHTS = ["w1", "w2", "brindle"];
// difficulty-plan.md, "Targets and fairness checks": "Novice non-wins that are deaths | >= 60%" (line 57).
export const NOVICE_DEATH_SHARE = 0.6;
// Seeds a pool needs, from the same table (project-guide/handoff/shared/world1/difficulty-plan.md):
export const SEEDS = {
  expert: 48, // line 54, "Expert on each fight cell"; the Expert fight time reads the same runs (line 58)
  fairness: 24, // lines 59 to 61, F1 to F3
  novice: { w1: 48, w2: 24, w1clear: 24 }, // lines 51, 52 and 56; the death share reads the same runs (line 57)
  worstMinute: 48, // whole clear, Learner attempt 5 and Expert: lines 53 (dam Learner attempt 5) and 55 (whole clear Expert)
};
// The Novice cells the plan names (lines 51, 52, 56). It names no Novice row for Brindle, so Brindle is not graded here.
export const NOVICE_CELLS = ["w1", "w2", "w1clear"];

const gradeOf = (run) => run.grade ?? gradeRun(run.kind, run.row, run);
const counted = (run) => run.row != null && run.row.resumed !== false && !EXCLUDED.includes(gradeOf(run).result);
export const COMMIT = /^[0-9a-f]{7,40}$/;
const sameHead = (commit, head) => typeof commit === "string" && commit.length >= 7 && (head.startsWith(commit) || commit.startsWith(head));
const pct = (x) => `${Math.round(x * 100)}%`;
const fmt = (x) => (Number.isFinite(x) ? (Math.round(x * 10) / 10).toString() : String(x));
const clone = (x) => JSON.parse(JSON.stringify(x));

// A run is counted once: shard folders that repeat it are keyed by cell, column and seed, the last one winning.
export function dedupeRuns(runs) {
  const m = new Map();
  for (const r of runs) m.set(`${r.cell}\u0000${r.column ?? r.band}\u0000${r.seed}`, r);
  return [...m.values()];
}

// Runs of the named cells, or the reason the band read cannot judge this head.
function select(read, head, cells) {
  const all = dedupeRuns(read.runs).filter((r) => cells.includes(r.cell));
  const other = all.find((r) => !sameHead(r.commit, head));
  if (other) return { error: `band read ran on ${String(other.commit ?? "no commit").slice(0, 9)}, not ${head.slice(0, 9)}` };
  // The plan's targets are for default difficulty (difficulty-plan.md line 49): a tuned or tiered run is another game.
  const tuned = all.find((r) => (r.args ?? []).some((a) => /^--(tune|run-tier)\b/.test(String(a))));
  if (tuned) return { error: `band read is not default difficulty: ${tuned.cell} ${tuned.column} ran with ${tuned.args.filter((a) => /^--(tune|run-tier)\b/.test(String(a))).join(" ")}` };
  return { all, runs: all.filter(counted) };
}

// Whether one pool (cell and column) has the seeds it needs. A column cut short by --early-stop is too few: ruling dg
// settles only that column's win-rate mark, and the death share, the fight time and the fairness lines are not settled
// when it stops. The producer command does not pass --early-stop.
export function enough(sel, cell, column, need) {
  const n = sel.runs.filter((r) => r.cell === cell && r.column === column).length;
  return { ok: n >= need, n, text: n >= need ? `${cell} ${column} n=${n}` : `${cell} ${column} n=${n} of ${need}` };
}

const tooFew = (counts) => `too few runs: ${counts.filter((c) => !c.ok).map((c) => c.text).join(", ")}`;

// --- strong-build-shows: a strong build beats Brindle faster and with more parts than a plain one ----------------------

// Brindle's cell, the Expert with a top build (column expertTop) against the Expert with an ordinary build (expert).
// More parts: the median parts carried into the fight (boss.entry_parts, tools/bot_driver.gd) is higher for the top build.
// Faster: the median fight time of its wins (the graded fightS) is lower. The row names no margin, so any gap counts.
// Both columns need the Expert's 48 seeds; the top column plays the same seeds as the ordinary one.
export function gradeStrongBuild(read, head) {
  const none = { parts: null, faster: null };
  const sel = select(read, head, ["brindle"]);
  if (sel.error) return { pass: false, measured: sel.error, checks: none };
  const counts = ["expertTop", "expert"].map((c) => enough(sel, "brindle", c, SEEDS.expert));
  if (counts.some((c) => !c.ok)) return { pass: false, measured: `Brindle, Expert: ${tooFew(counts)}`, checks: none };
  const col = (id) => sel.runs.filter((r) => r.column === id);
  const top = col("expertTop");
  const ord = col("expert");
  const parts = (rs) => median(rs.map((r) => r.row?.boss?.entry_parts).filter((x) => typeof x === "number"));
  const fight = (rs) => median(rs.map(gradeOf).filter((g) => g.result === "win").map((g) => g.fightS));
  const p = { top: parts(top), ord: parts(ord) };
  const t = { top: fight(top), ord: fight(ord) };
  const checks = {
    parts: p.top == null || p.ord == null ? null : p.top > p.ord,
    faster: t.top == null || t.ord == null ? null : t.top < t.ord,
  };
  const partsText = p.top == null || p.ord == null ? "parts not recorded (boss.entry_parts)" : `parts ${fmt(p.top)} top against ${fmt(p.ord)} ordinary`;
  const fightText = t.top == null || t.ord == null ? "no win to time" : `fight ${fmt(t.top)} s top against ${fmt(t.ord)} s ordinary`;
  return { pass: checks.parts === true && checks.faster === true, measured: `Brindle, Expert medians: ${partsText}; ${fightText} (${counts.map((c) => c.text).join(", ")})`, checks };
}

// The plant: the top and ordinary labels swapped, so the plain build is read as the strong one. Each run keeps its own
// grade and record, so the parts and the fight time the grader reads both change sides, and both checks must miss.
export function plantStrongBuild(read) {
  const swap = { expertTop: "expert", expert: "expertTop" };
  return { ...clone(read), runs: clone(read.runs).map((r) => (r.cell === "brindle" && swap[r.column] ? { ...r, column: swap[r.column], build: r.build === "top" ? "ordinary" : "top" } : r)) };
}

// --- warden-fairness: fairness lines F1 to F3 (difficulty-plan.md; lines in scripts/challenge/fairness.json) ------------

// One pool per world 1 fight cell and column (fairnessPool in scripts/challenge/lib.mjs), each needing the plan's 24 seeds.
// F1: telegraph share >= FAIRNESS.telegraphShare and every killing hit telegraphed, in every pool. A killing hit whose
//     bucket is contact or unknown is a miss here (the row says every killing hit is telegraphed), and so is a pool whose
//     unknown hull is over the line (F1 carries no mark there) or that measured no F1 at all.
// F2: stop tax >= FAIRNESS.stopTax in every pool; a pool with no stop tax is a miss.
// F3: median first hit >= FAIRNESS.firstHitS s in every Learner attempt 1 pool (the plan's F3 row: "(Learner 1)").
// Each world 1 fight cell needs a Learner attempt 1 pool.
export function gradeFairness(read, head) {
  const none = { F1: null, F1marked: null, F2: null, F3: null };
  const sel = select(read, head, W1_FIGHTS);
  if (sel.error) return { pass: false, measured: sel.error, checks: none };
  const keys = [...new Set(sel.all.map((r) => `${r.cell}\u0000${r.column}`))].map((k) => k.split("\u0000"));
  const counts = keys.map(([cell, column]) => enough(sel, cell, column, SEEDS.fairness));
  const noLearner = W1_FIGHTS.filter((c) => !keys.some(([cell, column]) => cell === c && column === "learner1"));
  if (noLearner.length) return { pass: false, measured: `no Learner attempt 1 runs for ${noLearner.join(", ")}`, checks: none };
  if (counts.some((c) => !c.ok)) return { pass: false, measured: tooFew(counts), checks: none };
  const pools = keys.map(([cell, column]) => ({ key: `${cell} ${column}`, cell, column, ...fairnessPool(sel.runs.filter((r) => r.cell === cell && r.column === column)) }));
  const f1Fails = (p) => p.telegraphShare == null || !p.shareMarked || p.telegraphShare < FAIRNESS.telegraphShare - 1e-9 || p.killsShown !== p.kills || p.killsOther > 0;
  const f1Bad = pools.filter(f1Fails);
  // F1 judged only where it carries a mark: what the plant must be seen to move.
  const f1Marked = pools.filter((p) => p.shareMarked);
  const f2Bad = pools.filter((p) => p.stopTax == null || p.stopTax < FAIRNESS.stopTax - 1e-9);
  const f3 = pools.filter((p) => p.column === "learner1");
  const f3Bad = f3.filter((p) => p.firstHitS == null || p.firstHitS < FAIRNESS.firstHitS - 1e-9);
  const checks = {
    F1: f1Bad.length === 0,
    F1marked: f1Marked.length ? f1Marked.every((p) => !f1Bad.includes(p)) : null,
    F2: f2Bad.length === 0,
    F3: f3Bad.length === 0,
  };
  const f1Why = (p) => (p.telegraphShare == null ? "not measured" : !p.shareMarked ? `unknown hull ${pct(p.unknownShare)}` : `${pct(p.telegraphShare)}, kills shown ${p.killsShown}/${p.kills + p.killsOther}`);
  const say = (name, all, bad, show) => (bad.length ? `${name} misses in ${bad.length} of ${all.length} pools (${bad.slice(0, 3).map(show).join(", ")})` : `${name} holds in ${all.length} pools`);
  const parts = [
    say("F1", pools, f1Bad, (p) => `${p.key} ${f1Why(p)}`),
    say("F2", pools, f2Bad, (p) => `${p.key} ${p.stopTax == null ? `not measured (${p.stopTaxNote})` : p.stopTax.toFixed(2)}`),
    say("F3", f3, f3Bad, (p) => `${p.key} ${p.firstHitS == null ? "not measured" : fmt(p.firstHitS) + " s"}`),
    `n ${Math.min(...counts.map((c) => c.n))} to ${Math.max(...counts.map((c) => c.n))} a pool over ${pools.length} pools`,
  ];
  return { pass: checks.F1 && checks.F2 && checks.F3, measured: parts.join("; "), checks };
}

// The plant: a Warden attack with its telegraph removed. In the Warden cells' runs, the hull of one source (the Warden's
// own, or the source that cost the most hull when the Warden landed nothing) moves from telegraphed to untelegraphed, as
// far as the run's telegraphed hull allows, and a killing hit from that source becomes untelegraphed. F1 must miss in a
// pool that carries its mark, so a read whose F1 is unmarked everywhere cannot count the plant as caught.
export function plantFairness(read) {
  const out = clone(read);
  const wardens = out.runs.filter((r) => (r.cell === "w1" || r.cell === "w2") && r.row?.fairness);
  const bySource = {};
  for (const r of wardens) for (const [s, h] of Object.entries(r.row.fairness.hit_sources ?? {})) bySource[s] = (bySource[s] ?? 0) + (h ?? 0);
  const source = bySource.warden > 0 ? "warden" : Object.entries(bySource).sort((a, b) => b[1] - a[1])[0]?.[0] ?? "warden";
  for (const r of wardens) {
    const f = r.row.fairness;
    const hull = f.hull ?? {};
    const moved = Math.min(f.hit_sources?.[source] ?? 0, hull.telegraphed ?? 0);
    f.hull = { ...hull, telegraphed: (hull.telegraphed ?? 0) - moved, untelegraphed: (hull.untelegraphed ?? 0) + moved };
    if (f.killing_hit?.source === source) f.killing_hit = { ...f.killing_hit, bucket: "untelegraphed" };
  }
  return out;
}

// --- novice-deaths: at least 60% of Novice non-wins are deaths, not time caps ------------------------------------------

// Graded per cell, never pooled: every Novice cell the plan names with a non-win must reach the line on its own. A death is
// a graded loss; a time cap is any timeout (fight cap, stall, tick guard). Errors and harness kills are left out, as the
// band table leaves them out. A cell with no non-win is reported and does not fail.
export function gradeNoviceDeaths(read, head) {
  const sel = select(read, head, NOVICE_CELLS);
  if (sel.error) return { pass: false, measured: sel.error, checks: { share: null } };
  const counts = NOVICE_CELLS.map((cell) => enough(sel, cell, "novice", SEEDS.novice[cell]));
  if (counts.some((c) => !c.ok)) return { pass: false, measured: `Novice: ${tooFew(counts)}`, checks: { share: null } };
  const per = NOVICE_CELLS.map((cell, i) => {
    const gs = sel.runs.filter((r) => r.cell === cell && r.column === "novice").map(gradeOf);
    const deaths = gs.filter((g) => g.result === "loss").length;
    const caps = gs.filter((g) => g.result === "timeout").length;
    const share = deaths + caps ? deaths / (deaths + caps) : null;
    return { cell, n: counts[i].n, deaths, caps, share, ok: share == null || share >= NOVICE_DEATH_SHARE - 1e-9 };
  });
  const graded = per.filter((c) => c.share != null);
  const text = per.map((c) => (c.share == null ? `${c.cell} no non-win (n=${c.n})` : `${c.cell} ${c.deaths} of ${c.deaths + c.caps} (${pct(c.share)}, n=${c.n})`)).join(", ");
  if (!graded.length) return { pass: false, measured: `Novice non-wins that are deaths: no cell has a non-win; ${text}`, checks: { share: null } };
  const ok = per.every((c) => c.ok);
  const bad = per.filter((c) => !c.ok).map((c) => c.cell);
  return { pass: ok, measured: `Novice non-wins that are deaths, per cell, line ${pct(NOVICE_DEATH_SHARE)}: ${text}${bad.length ? `; under the line: ${bad.join(", ")}` : ""}`, checks: { share: ok } };
}

// The plant: a band where every loss is a time cap.
export function plantNoviceDeaths(read) {
  return { ...clone(read), runs: clone(read.runs).map((r) => {
    if (r.column !== "novice" || gradeOf(r).result !== "loss") return r;
    return { ...r, row: r.row ? { ...r.row, outcome: "fight_capped" } : r.row, grade: { ...gradeOf(r), result: "timeout", reason: "fight_capped", diedS: undefined } };
  }) };
}

// --- brindle-worst-minute: Brindle's worst minute costs at least the dam Warden's (BACKLOG MG-11) ----------------------

// The whole-clear cell (w1clear) plays the dam, the flume and Brindle in one run, so both fights are read off the same
// runs. Per column, the median share of max hull lost in the fight's worst 60 s (worst_60s_hull, tools/bot_driver.gd,
// W1-31; read by worstWindows in scripts/challenge/worst-window.mjs) at Brindle must be above zero and at least the dam's.
// A fight no run reached, or one whose notes never carry worst_60s_hull (a record from before the field, or a Brindle
// that landed no hit in any run), is no data and a miss: worstWindows reads a missing field as 0, which would let an
// unrecorded fight look calm.
export const WORST_COLUMNS = ["learner5", "expert"];
export function gradeWorstMinute(read, head) {
  const none = Object.fromEntries(WORST_COLUMNS.map((c) => [c, null]));
  const sel = select(read, head, ["w1clear"]);
  if (sel.error) return { pass: false, measured: sel.error, checks: none };
  const counts = WORST_COLUMNS.map((c) => enough(sel, "w1clear", c, SEEDS.worstMinute));
  if (counts.some((c) => !c.ok)) return { pass: false, measured: `Brindle against the dam, whole clear: ${tooFew(counts)}`, checks: none };
  const checks = {};
  const texts = WORST_COLUMNS.map((column) => {
    const runs = sel.runs.filter((r) => r.column === column);
    const fights = worstWindows(runs)[column] ?? { dam: [], brindle: [] };
    const damNotes = runs.map((r) => (r.row.stages ?? []).find((s) => s.stage === 1)).filter((n) => n?.warden_engaged_s != null);
    const bossNotes = runs.map((r) => r.row.boss).filter((n) => n != null);
    const recorded = (notes) => notes.some((n) => typeof n.worst_60s_hull === "number");
    const side = (name, list, notes) => (!list.length ? `${name} no data (no run reached it)` : !recorded(notes) ? `${name} no data (worst_60s_hull not recorded)` : null);
    const gap = side("dam", fights.dam, damNotes) ?? side("Brindle", fights.brindle, bossNotes);
    if (gap) {
      checks[column] = false;
      return `${column} ${gap}`;
    }
    const dam = median(fights.dam.map((x) => x.hull));
    const boss = median(fights.brindle.map((x) => x.hull));
    checks[column] = boss > 0 && boss >= dam - 1e-9;
    return `${column} Brindle ${pct(boss)} (n=${fights.brindle.length}) against dam ${pct(dam)} (n=${fights.dam.length})`;
  });
  return { pass: WORST_COLUMNS.every((c) => checks[c] === true), measured: `median worst-minute hull lost, share of max hull: ${texts.join("; ")} (${counts.map((c) => c.text).join(", ")})`, checks };
}

// The plant: Brindle deals no damage. Every whole-clear boss note keeps its fields but reads 0 hull and 0 hits in its
// worst minute, so every column must miss.
export function plantWorstMinute(read) {
  return { ...clone(read), runs: clone(read.runs).map((r) => {
    if (r.cell !== "w1clear" || !r.row?.boss) return r;
    const { hit_sources, ...boss } = r.row.boss;
    return { ...r, row: { ...r.row, boss: { ...boss, worst_60s_hull: 0, worst_60s_hp: 0 } } };
  }) };
}

// --- brindle-stop-tax: in the Slag Bowl a stopped ball pays at least double (F2, BACKLOG MG-11) -------------------------

// F2 from warden-fairness (fairnessPool's stop tax against FAIRNESS.stopTax), read on the Brindle cell alone: one pool per
// column, each needing the fairness count of seeds. A pool with no stop tax is a miss, and so is a read with no Brindle run.
export function gradeBowlStopTax(read, head) {
  const sel = select(read, head, ["brindle"]);
  if (sel.error) return { pass: false, measured: sel.error, checks: { tax: null } };
  const columns = [...new Set(sel.all.map((r) => r.column))];
  if (!columns.length) return { pass: false, measured: "Slag Bowl stop tax: no data (no Brindle runs)", checks: { tax: false } };
  const counts = columns.map((c) => enough(sel, "brindle", c, SEEDS.fairness));
  if (counts.some((c) => !c.ok)) return { pass: false, measured: `Slag Bowl stop tax: ${tooFew(counts)}`, checks: { tax: null } };
  const pools = columns.map((column) => ({ column, ...fairnessPool(sel.runs.filter((r) => r.column === column)) }));
  const bad = pools.filter((p) => p.stopTax == null || p.stopTax < FAIRNESS.stopTax - 1e-9);
  const show = (p) => `${p.column} ${p.stopTax == null ? `no data (${p.stopTaxNote})` : p.stopTax.toFixed(2)}`;
  const text = `Slag Bowl stop tax, line ${FAIRNESS.stopTax.toFixed(1)}: ${pools.map(show).join(", ")}${bad.length ? `; under the line: ${bad.map((p) => p.column).join(", ")}` : ""} (${counts.map((c) => c.text).join(", ")})`;
  return { pass: bad.length === 0, measured: text, checks: { tax: bad.length === 0 } };
}

// The plant: a stopped ball loses hull at the same rate as a cruising one. In each Brindle column, every run's hull lost
// below cruise is set to its time below cruise times the column's pooled cruise rate, so the pooled stop tax is 1.
export function plantBowlStopTax(read) {
  const out = clone(read);
  const runs = out.runs.filter((r) => r.cell === "brindle" && r.row?.fairness);
  for (const column of new Set(runs.map((r) => r.column))) {
    const col = runs.filter((r) => r.column === column);
    const fastS = col.reduce((a, r) => a + (r.row.fairness.fast_s ?? 0), 0);
    const fastH = col.reduce((a, r) => a + (r.row.fairness.fast_hull ?? 0), 0);
    const rate = fastS > 0 ? fastH / fastS : 0;
    for (const r of col) r.row.fairness.slow_hull = rate * (r.row.fairness.slow_s ?? 0);
  }
  return out;
}

// --- receipts -----------------------------------------------------------------------------------------------------

// Each row: its grader, its plant, and the checks the plant must make miss.
export const ROWS = {
  "strong-build-shows": { grade: gradeStrongBuild, plant: plantStrongBuild, targets: ["parts", "faster"] },
  "warden-fairness": { grade: gradeFairness, plant: plantFairness, targets: ["F1marked"] },
  "novice-deaths": { grade: gradeNoviceDeaths, plant: plantNoviceDeaths, targets: ["share"] },
  "brindle-worst-minute": { grade: gradeWorstMinute, plant: plantWorstMinute, targets: WORST_COLUMNS },
  "brindle-stop-tax": { grade: gradeBowlStopTax, plant: plantBowlStopTax, targets: ["tax"] },
};

// read: { runs: runs.ndjson rows }.
export function buildReceipt(id, read, head) {
  if (typeof head !== "string" || !COMMIT.test(head)) throw new Error(`--head must be a commit of 7 to 40 hex characters, not ${JSON.stringify(head)}`);
  const { grade, plant, targets } = ROWS[id];
  const real = grade(read, head);
  const planted = grade(plant(read), head);
  const caught = planted.pass === false && targets.every((t) => planted.checks[t] === false);
  const measured = caught ? real.measured : `${real.measured}; plant not caught (${planted.measured})`;
  return { head, pass: real.pass && caught, measured, plant_caught: caught };
}

export function buildReceipts(read, head) {
  return Object.fromEntries(Object.keys(ROWS).map((id) => [id, buildReceipt(id, read, head)]));
}

// One or more band read folders (shards may repeat a run; it is counted once).
export function loadRead(dirs) {
  const runs = dirs.flatMap((d) => parseNdjson(readFileSync(path.join(d, "runs.ndjson"), "utf8")));
  return { runs };
}

function main(argv) {
  const args = { band: [] };
  for (let i = 0; i < argv.length; i += 2) {
    const k = argv[i].replace(/^--/, "");
    if (k === "band") args.band.push(argv[i + 1]);
    else args[k] = argv[i + 1];
  }
  if (!args.band.length || !args.head || !args.out) {
    console.error("usage: band-receipts.mjs --band <band read folder> [--band <folder> ...] --head <commit> --out <receipts folder>");
    return 2;
  }
  if (!COMMIT.test(args.head)) {
    console.error(`--head must be a commit of 7 to 40 hex characters, not ${args.head}`);
    return 2;
  }
  const receipts = buildReceipts(loadRead(args.band), args.head);
  mkdirSync(args.out, { recursive: true });
  for (const [id, receipt] of Object.entries(receipts)) {
    writeFileSync(path.join(args.out, `${id}.json`), JSON.stringify(receipt, null, 2) + "\n");
    console.log(`${id}: ${receipt.pass ? "pass" : "miss"}${receipt.plant_caught ? "" : " (plant not caught)"}: ${receipt.measured}`);
  }
  return Object.values(receipts).every((r) => r.pass) ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main(process.argv.slice(2)));
