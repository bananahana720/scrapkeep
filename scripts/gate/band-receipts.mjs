#!/usr/bin/env node
// Turns a difficulty band read (scripts/challenge/run.mjs, its folder's runs.ndjson) into the receipts that
// scripts/world1-bands.mjs reads for three rows: strong-build-shows, warden-fairness and novice-deaths.
// Each receipt is { head, pass, measured, plant_caught }. Each row's plant is applied to a copy of the same runs and
// graded by the same function; plant_caught is true only when the planted copy misses on the check the plant targets.
// A receipt passes only when its own check passes and its plant was caught.
//
//   node scripts/gate/band-receipts.mjs --band <band read folder> --head <commit> --out <receipts folder>
//
// Produce the band read with:
//   npm run challenge:bands -- --library=<dir> --only=w1,w2,brindle --label=<name>
// It writes <out>/strong-build-shows.json, <out>/warden-fairness.json and <out>/novice-deaths.json.
import { mkdirSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { EXCLUDED, FAIRNESS, fairnessPool, gradeRun, median, parseNdjson } from "../challenge/lib.mjs";

// World 1's fight cells in the band table: the dam Warden, the flume Warden and Admiral Brindle.
export const W1_FIGHTS = ["w1", "w2", "brindle"];
// difficulty-plan.md, "Targets and fairness checks": "Novice non-wins that are deaths | >= 60%".
export const NOVICE_DEATH_SHARE = 0.6;

const gradeOf = (run) => run.grade ?? gradeRun(run.kind, run.row, run);
const counted = (run) => run.row != null && run.row.resumed !== false && !EXCLUDED.includes(gradeOf(run).result);
const sameHead = (commit, head) => typeof commit === "string" && commit.length >= 7 && (head.startsWith(commit) || commit.startsWith(head));
const pct = (x) => `${Math.round(x * 100)}%`;
const fmt = (x) => (Number.isFinite(x) ? (Math.round(x * 10) / 10).toString() : String(x));
const clone = (runs) => JSON.parse(JSON.stringify(runs));

// Runs of the named cells, or the reason the band read cannot judge this head.
function select(runs, head, cells) {
  const mine = runs.filter((r) => cells.includes(r.cell));
  const other = mine.find((r) => !sameHead(r.commit, head));
  if (other) return { error: `band read ran on ${String(other.commit ?? "no commit").slice(0, 9)}, not ${head.slice(0, 9)}` };
  return { runs: mine.filter(counted) };
}

// --- strong-build-shows: a strong build beats Brindle faster and with more parts than a plain one ----------------------

// Brindle's cell, the Expert with a top build (column expertTop) against the Expert with an ordinary build (expert).
// More parts: the median parts carried into the fight (boss.entry_parts, tools/bot_driver.gd) is higher for the top build.
// Faster: the median fight time of its wins (boss.defeated_s) is lower. The row names no margin, so any gap counts.
export function gradeStrongBuild(runs, head) {
  const sel = select(runs, head, ["brindle"]);
  if (sel.error) return { pass: false, measured: sel.error, checks: { parts: null, faster: null } };
  const col = (id) => sel.runs.filter((r) => r.column === id);
  const top = col("expertTop");
  const ord = col("expert");
  if (!top.length || !ord.length) return { pass: false, measured: `brindle needs both Expert columns; top ${top.length} runs, ordinary ${ord.length}`, checks: { parts: null, faster: null } };
  const parts = (rs) => median(rs.map((r) => r.row?.boss?.entry_parts).filter((x) => typeof x === "number"));
  const fight = (rs) => median(rs.map(gradeOf).filter((g) => g.result === "win").map((g) => g.fightS));
  const p = { top: parts(top), ord: parts(ord) };
  const t = { top: fight(top), ord: fight(ord) };
  const checks = {
    parts: p.top == null || p.ord == null ? null : p.top > p.ord,
    faster: t.top == null || t.ord == null ? null : t.top < t.ord,
  };
  const partsText = p.top == null || p.ord == null ? "parts not recorded (boss.entry_parts)" : `parts ${fmt(p.top)} top against ${fmt(p.ord)} ordinary`;
  const fightText = t.top == null || t.ord == null ? `no win to time (top ${top.length} runs, ordinary ${ord.length})` : `fight ${fmt(t.top)} s top against ${fmt(t.ord)} s ordinary`;
  return { pass: checks.parts === true && checks.faster === true, measured: `Brindle, Expert medians: ${partsText}; ${fightText}`, checks };
}

// The plant: the top build's parts stripped. Only the record can be stripped here, so the parts check must miss.
export function plantStrongBuild(runs) {
  return clone(runs).map((r) => (r.cell === "brindle" && r.column === "expertTop" && r.row?.boss ? { ...r, row: { ...r.row, boss: { ...r.row.boss, entry_parts: 0 } } } : r));
}

// --- warden-fairness: fairness lines F1 to F3 (difficulty-plan.md; lines in scripts/challenge/fairness.json) ------------

// One pool per world 1 fight cell and column, as the band table prints them (fairnessPool in scripts/challenge/lib.mjs).
// F1: telegraph share >= FAIRNESS.telegraphShare and every killing hit shown, in every pool that measured it; a pool whose
//     unknown hull is over the line carries no F1 mark and reads as a miss, since the hit sources are not all owned.
// F2: stop tax >= FAIRNESS.stopTax in every pool that measured it.
// F3: median first hit >= FAIRNESS.firstHitS s, in the Learner attempt 1 pools only (the plan's F3 row: "(Learner 1)").
// Each line needs at least one measured pool and each world 1 fight cell needs a fairness record.
export function gradeFairness(runs, head) {
  const sel = select(runs, head, W1_FIGHTS);
  if (sel.error) return { pass: false, measured: sel.error, checks: { F1: null, F1marked: null, F2: null, F3: null } };
  const groups = new Map();
  for (const r of sel.runs) {
    const key = `${r.cell} ${r.column ?? r.band}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(r);
  }
  const pools = [...groups.entries()].map(([key, rs]) => ({ key, column: rs[0].column ?? rs[0].band, cell: rs[0].cell, ...fairnessPool(rs) })).filter((p) => p.measured > 0);
  const missingCells = W1_FIGHTS.filter((c) => !pools.some((p) => p.cell === c));
  const f1 = pools.filter((p) => p.telegraphShare != null);
  const f1Bad = f1.filter((p) => !p.shareMarked || p.telegraphShare < FAIRNESS.telegraphShare - 1e-9 || (p.kills && p.killsShown !== p.kills));
  // F1 judged only where it carries a mark: what the plant must be seen to move.
  const f1Marked = f1.filter((p) => p.shareMarked);
  const f2 = pools.filter((p) => p.stopTax != null);
  const f2Bad = f2.filter((p) => p.stopTax < FAIRNESS.stopTax - 1e-9);
  const f3 = pools.filter((p) => p.column === "learner1" && p.firstHitS != null);
  const f3Bad = f3.filter((p) => p.firstHitS < FAIRNESS.firstHitS - 1e-9);
  const checks = {
    F1: f1.length ? f1Bad.length === 0 : null,
    F1marked: f1Marked.length ? f1Marked.every((p) => !f1Bad.includes(p)) : null,
    F2: f2.length ? f2Bad.length === 0 : null,
    F3: f3.length ? f3Bad.length === 0 : null,
  };
  const say = (name, all, bad, show) => (!all.length ? `${name} not measured` : bad.length ? `${name} misses in ${bad.length} of ${all.length} pools (${bad.slice(0, 3).map(show).join(", ")})` : `${name} holds in ${all.length} pools`);
  const parts = [
    say("F1", f1, f1Bad, (p) => `${p.key} ${!p.shareMarked ? "unknown hull " + pct(p.unknownShare) : pct(p.telegraphShare) + ", kills " + p.killsShown + "/" + p.kills}`),
    say("F2", f2, f2Bad, (p) => `${p.key} ${p.stopTax.toFixed(2)}`),
    say("F3", f3, f3Bad, (p) => `${p.key} ${fmt(p.firstHitS)} s`),
  ];
  if (missingCells.length) parts.push(`no fairness record for ${missingCells.join(", ")}`);
  const pass = missingCells.length === 0 && checks.F1 === true && checks.F2 === true && checks.F3 === true;
  return { pass, measured: parts.join("; "), checks };
}

// The plant: a Warden attack with its telegraph removed. In the Warden cells' runs, the hull of one source (the Warden's
// own, or the source that cost the most hull when the Warden landed nothing) moves from telegraphed to untelegraphed, as
// far as the run's telegraphed hull allows, and a killing hit from that source becomes untelegraphed. F1 must miss in a
// pool that carries its mark, so a read whose F1 is unmarked everywhere cannot count the plant as caught.
export function plantFairness(runs) {
  const out = clone(runs);
  const wardens = out.filter((r) => (r.cell === "w1" || r.cell === "w2") && r.row?.fairness);
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

// The Novice column of the world 1 fight cells, pooled. A death is a graded loss; a time cap is any timeout (fight cap,
// stall, tick guard). Errors and harness kills are left out, as the band table leaves them out.
export function gradeNoviceDeaths(runs, head) {
  const sel = select(runs, head, W1_FIGHTS);
  if (sel.error) return { pass: false, measured: sel.error, checks: { share: null } };
  const novice = sel.runs.filter((r) => r.column === "novice");
  const per = W1_FIGHTS.map((cell) => {
    const gs = novice.filter((r) => r.cell === cell).map(gradeOf);
    return { cell, deaths: gs.filter((g) => g.result === "loss").length, caps: gs.filter((g) => g.result === "timeout").length };
  });
  const deaths = per.reduce((a, c) => a + c.deaths, 0);
  const caps = per.reduce((a, c) => a + c.caps, 0);
  const cells = per.filter((c) => c.deaths + c.caps > 0).map((c) => `${c.cell} ${c.deaths}/${c.deaths + c.caps}`).join(", ");
  if (deaths + caps === 0) return { pass: false, measured: `no Novice non-win in ${W1_FIGHTS.join(", ")} (${novice.length} runs)`, checks: { share: null } };
  const share = deaths / (deaths + caps);
  const ok = share >= NOVICE_DEATH_SHARE - 1e-9;
  return { pass: ok, measured: `Novice non-wins that are deaths: ${deaths} of ${deaths + caps} (${pct(share)}, line ${pct(NOVICE_DEATH_SHARE)}); ${cells}`, checks: { share: ok } };
}

// The plant: a band where every loss is a time cap.
export function plantNoviceDeaths(runs) {
  return clone(runs).map((r) => {
    if (r.column !== "novice" || gradeOf(r).result !== "loss") return r;
    return { ...r, row: r.row ? { ...r.row, outcome: "fight_capped" } : r.row, grade: { ...gradeOf(r), result: "timeout", reason: "fight_capped", diedS: undefined } };
  });
}

// --- receipts -----------------------------------------------------------------------------------------------------

// Each row: its grader, its plant, and the check the plant must make miss.
export const ROWS = {
  "strong-build-shows": { grade: gradeStrongBuild, plant: plantStrongBuild, target: "parts" },
  "warden-fairness": { grade: gradeFairness, plant: plantFairness, target: "F1marked" },
  "novice-deaths": { grade: gradeNoviceDeaths, plant: plantNoviceDeaths, target: "share" },
};

export function buildReceipt(id, runs, head) {
  const { grade, plant, target } = ROWS[id];
  const real = grade(runs, head);
  const planted = grade(plant(runs), head);
  const caught = planted.checks[target] === false && planted.pass === false;
  const measured = caught ? real.measured : `${real.measured}; plant not caught (${planted.measured})`;
  return { head, pass: real.pass && caught, measured, plant_caught: caught };
}

export function buildReceipts(runs, head) {
  return Object.fromEntries(Object.keys(ROWS).map((id) => [id, buildReceipt(id, runs, head)]));
}

function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) args[argv[i].replace(/^--/, "")] = argv[i + 1];
  if (!args.band || !args.head || !args.out) {
    console.error("usage: band-receipts.mjs --band <band read folder> --head <commit> --out <receipts folder>");
    return 2;
  }
  const runs = parseNdjson(readFileSync(path.join(args.band, "runs.ndjson"), "utf8"));
  const receipts = buildReceipts(runs, args.head);
  mkdirSync(args.out, { recursive: true });
  for (const [id, receipt] of Object.entries(receipts)) {
    writeFileSync(path.join(args.out, `${id}.json`), JSON.stringify(receipt, null, 2) + "\n");
    console.log(`${id}: ${receipt.pass ? "pass" : "miss"}${receipt.plant_caught ? "" : " (plant not caught)"}: ${receipt.measured}`);
  }
  return Object.values(receipts).every((r) => r.pass) ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main(process.argv.slice(2)));
