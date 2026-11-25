#!/usr/bin/env node
import { mkdirSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  COLUMNS,
  EXCLUDED,
  FAIRNESS,
  fairnessPool,
  f1ShareUnder,
  f2TaxUnder,
  gradeRun,
  median,
  parseNdjson,
} from "../challenge/lib.mjs";
import { fightMaxHp, fightNotes, med } from "../challenge/worst-window.mjs";

export const W1_FIGHTS = ["w1", "w2", "brindle"];
export const NOVICE_DEATH_SHARE = 0.6;
export const SEEDS = {
  expert: 48,
  fairness: 24,
  novice: { w1: 48, w2: 24, w1clear: 24 },
  worstMinute: 48,
  worstMinuteFights: 24,
};
export const NOVICE_CELLS = ["w1", "w2", "w1clear"];

const gradeOf = (run) => run.grade ?? gradeRun(run.kind, run.row, run);
const counted = (run) =>
  run.row != null && run.row.resumed !== false && !EXCLUDED.includes(gradeOf(run).result);
export const COMMIT = /^[0-9a-f]{7,40}$/;
const sameHead = (commit, head) =>
  typeof commit === "string" &&
  commit.length >= 7 &&
  (head.startsWith(commit) || commit.startsWith(head));
const pct = (x) => `${Math.round(x * 100)}%`;
const fmt = (x) => (Number.isFinite(x) ? (Math.round(x * 10) / 10).toString() : String(x));
const clone = (x) => JSON.parse(JSON.stringify(x));

export function dedupeRuns(runs) {
  const m = new Map();
  for (const r of runs) m.set(`${r.cell}\u0000${r.column ?? r.band}\u0000${r.seed}`, r);
  return [...m.values()];
}

function select(read, head, cells) {
  const all = dedupeRuns(read.runs).filter((r) => cells.includes(r.cell));
  const other = all.find((r) => !sameHead(r.commit, head));
  if (other)
    return {
      error: `band read ran on ${String(other.commit ?? "no commit").slice(0, 9)}, not ${head.slice(0, 9)}`,
    };
  const tuned = all.find((r) => (r.args ?? []).some((a) => /^--(tune|run-tier)\b/.test(String(a))));
  if (tuned)
    return {
      error: `band read is not default difficulty: ${tuned.cell} ${tuned.column} ran with ${tuned.args.filter((a) => /^--(tune|run-tier)\b/.test(String(a))).join(" ")}`,
    };
  return { all, runs: all.filter(counted) };
}

export function enough(sel, cell, column, need) {
  const n = sel.runs.filter((r) => r.cell === cell && r.column === column).length;
  return {
    ok: n >= need,
    n,
    text: n >= need ? `${cell} ${column} n=${n}` : `${cell} ${column} n=${n} of ${need}`,
  };
}

const tooFew = (counts) =>
  `too few runs: ${counts
    .filter((c) => !c.ok)
    .map((c) => c.text)
    .join(", ")}`;

function thinMeasured(pools) {
  const thin = pools.filter((p) => p.measured < SEEDS.fairness);
  return thin.length
    ? `too few runs with a fairness record: ${thin.map((p) => `${p.key} ${p.measured} of ${SEEDS.fairness}`).join(", ")}`
    : null;
}

export function gradeStrongBuild(read, head) {
  const none = { parts: null, faster: null };
  const sel = select(read, head, ["brindle"]);
  if (sel.error) return { pass: false, measured: sel.error, checks: none };
  const counts = ["expertTop", "expert"].map((c) => enough(sel, "brindle", c, SEEDS.expert));
  if (counts.some((c) => !c.ok))
    return { pass: false, measured: `Brindle, Expert: ${tooFew(counts)}`, checks: none };
  const col = (id) => sel.runs.filter((r) => r.column === id);
  const top = col("expertTop");
  const ord = col("expert");
  const parts = (rs) =>
    median(rs.map((r) => r.row?.boss?.entry_parts).filter((x) => typeof x === "number"));
  const fight = (rs) =>
    median(
      rs
        .map(gradeOf)
        .filter((g) => g.result === "win")
        .map((g) => g.fightS),
    );
  const p = { top: parts(top), ord: parts(ord) };
  const t = { top: fight(top), ord: fight(ord) };
  const checks = {
    parts: p.top == null || p.ord == null ? null : p.top > p.ord,
    faster: t.top == null || t.ord == null ? null : t.top < t.ord,
  };
  const partsText =
    p.top == null || p.ord == null
      ? "parts not recorded (boss.entry_parts)"
      : `parts ${fmt(p.top)} top against ${fmt(p.ord)} ordinary`;
  const fightText =
    t.top == null || t.ord == null
      ? "no win to time"
      : `fight ${fmt(t.top)} s top against ${fmt(t.ord)} s ordinary`;
  return {
    pass: checks.parts === true && checks.faster === true,
    measured: `Brindle, Expert medians: ${partsText}; ${fightText} (${counts.map((c) => c.text).join(", ")})`,
    checks,
  };
}

export function plantStrongBuild(read) {
  const swap = { expertTop: "expert", expert: "expertTop" };
  return {
    ...clone(read),
    runs: clone(read.runs).map((r) =>
      r.cell === "brindle" && swap[r.column]
        ? { ...r, column: swap[r.column], build: r.build === "top" ? "ordinary" : "top" }
        : r,
    ),
  };
}

export function gradeFairness(read, head) {
  const none = { F1: null, F1marked: null, F2: null, F3: null };
  const sel = select(read, head, W1_FIGHTS);
  if (sel.error) return { pass: false, measured: sel.error, checks: none };
  const keys = [...new Set(sel.all.map((r) => `${r.cell}\u0000${r.column}`))].map((k) =>
    k.split("\u0000"),
  );
  const counts = keys.map(([cell, column]) => enough(sel, cell, column, SEEDS.fairness));
  const noLearner = W1_FIGHTS.filter(
    (c) => !keys.some(([cell, column]) => cell === c && column === "learner1"),
  );
  if (noLearner.length)
    return {
      pass: false,
      measured: `no Learner attempt 1 runs for ${noLearner.join(", ")}`,
      checks: none,
    };
  if (counts.some((c) => !c.ok)) return { pass: false, measured: tooFew(counts), checks: none };
  const pools = keys.map(([cell, column]) => ({
    key: `${cell} ${column}`,
    cell,
    column,
    ...fairnessPool(sel.runs.filter((r) => r.cell === cell && r.column === column)),
  }));
  const unmeasured = thinMeasured(pools);
  if (unmeasured) return { pass: false, measured: unmeasured, checks: none };
  const f1Fails = (p) =>
    p.telegraphShare == null ||
    !p.shareMarked ||
    f1ShareUnder(p) ||
    p.killsShown !== p.kills ||
    p.killsOther > 0;
  const f1Bad = pools.filter(f1Fails);
  const f1Marked = pools.filter((p) => p.shareMarked);
  const f2Bad = pools.filter((p) => p.stopTax == null || f2TaxUnder(p));
  const f3 = pools.filter((p) => p.column === "learner1");
  const f3Bad = f3.filter((p) => p.firstHitS == null || p.firstHitS < FAIRNESS.firstHitS - 1e-9);
  const checks = {
    F1: f1Bad.length === 0,
    F1marked: f1Marked.length ? f1Marked.every((p) => !f1Bad.includes(p)) : null,
    F2: f2Bad.length === 0,
    F3: f3Bad.length === 0,
  };
  const f1Why = (p) => {
    if (p.telegraphShare == null) return "not measured";
    if (!p.shareMarked)
      return `unknown ${pct(p.unknownShare)} of hull${p.pooledUnknownShare != null && p.pooledUnknownShare > FAIRNESS.unknownMaxShare ? `, ${pct(p.pooledUnknownShare)} of hull and scrap` : ""}`;
    const line = FAIRNESS.telegraphShare - 1e-9;
    const missed = [
      p.telegraphShare < line ? `hull ${pct(p.telegraphShare)}` : "",
      p.pooledShare != null && p.pooledShare < line ? `hull and scrap ${pct(p.pooledShare)}` : "",
    ].filter(Boolean);
    return `${missed.length ? `${missed.join(", ")} under the line` : pct(p.telegraphShare)}, kills shown ${p.killsShown}/${p.kills + p.killsOther}`;
  };
  const f2Why = (p) => {
    if (p.stopTax == null && p.pooledStopTax == null) return `not measured (${p.stopTaxNote})`;
    const line = FAIRNESS.stopTax - 1e-9;
    const missed = [
      p.stopTax != null && p.stopTax < line ? `hull ${p.stopTax.toFixed(2)}` : "",
      p.pooledStopTax != null && p.pooledStopTax < line
        ? `hull and scrap ${p.pooledStopTax.toFixed(2)}`
        : "",
    ].filter(Boolean);
    return missed.length
      ? `${missed.join(", ")} under the line`
      : (p.stopTax ?? p.pooledStopTax).toFixed(2);
  };
  const say = (name, all, bad, show) =>
    bad.length
      ? `${name} misses in ${bad.length} of ${all.length} pools (${bad.slice(0, 3).map(show).join(", ")})`
      : `${name} holds in ${all.length} pools`;
  const parts = [
    say("F1", pools, f1Bad, (p) => `${p.key} ${f1Why(p)}`),
    say("F2", pools, f2Bad, (p) => `${p.key} ${f2Why(p)}`),
    say(
      "F3",
      f3,
      f3Bad,
      (p) => `${p.key} ${p.firstHitS == null ? "not measured" : fmt(p.firstHitS) + " s"}`,
    ),
    `n ${Math.min(...counts.map((c) => c.n))} to ${Math.max(...counts.map((c) => c.n))} a pool over ${pools.length} pools`,
  ];
  return { pass: checks.F1 && checks.F2 && checks.F3, measured: parts.join("; "), checks };
}

export function plantFairness(read) {
  const out = clone(read);
  const wardens = out.runs.filter((r) => (r.cell === "w1" || r.cell === "w2") && r.row?.fairness);
  const bySource = {};
  for (const r of wardens)
    for (const [s, h] of Object.entries(r.row.fairness.hit_sources ?? {}))
      bySource[s] = (bySource[s] ?? 0) + (h ?? 0);
  const source =
    bySource.warden > 0
      ? "warden"
      : (Object.entries(bySource).sort((a, b) => b[1] - a[1])[0]?.[0] ?? "warden");
  for (const r of wardens) {
    const f = r.row.fairness;
    const hull = f.hull ?? {};
    const moved = Math.min(f.hit_sources?.[source] ?? 0, hull.telegraphed ?? 0);
    f.hull = {
      ...hull,
      telegraphed: (hull.telegraphed ?? 0) - moved,
      untelegraphed: (hull.untelegraphed ?? 0) + moved,
    };
    if (f.killing_hit?.source === source)
      f.killing_hit = { ...f.killing_hit, bucket: "untelegraphed" };
  }
  return out;
}

export function gradeNoviceDeaths(read, head) {
  const sel = select(read, head, NOVICE_CELLS);
  if (sel.error) return { pass: false, measured: sel.error, checks: { share: null } };
  const counts = NOVICE_CELLS.map((cell) => enough(sel, cell, "novice", SEEDS.novice[cell]));
  if (counts.some((c) => !c.ok))
    return { pass: false, measured: `Novice: ${tooFew(counts)}`, checks: { share: null } };
  const per = NOVICE_CELLS.map((cell, i) => {
    const gs = sel.runs.filter((r) => r.cell === cell && r.column === "novice").map(gradeOf);
    const deaths = gs.filter((g) => g.result === "loss").length;
    const caps = gs.filter((g) => g.result === "timeout").length;
    const share = deaths + caps ? deaths / (deaths + caps) : null;
    return {
      cell,
      n: counts[i].n,
      deaths,
      caps,
      share,
      ok: share == null || share >= NOVICE_DEATH_SHARE - 1e-9,
    };
  });
  const graded = per.filter((c) => c.share != null);
  const text = per
    .map((c) =>
      c.share == null
        ? `${c.cell} no non-win (n=${c.n})`
        : `${c.cell} ${c.deaths} of ${c.deaths + c.caps} (${pct(c.share)}, n=${c.n})`,
    )
    .join(", ");
  if (!graded.length)
    return {
      pass: false,
      measured: `Novice non-wins that are deaths: no cell has a non-win; ${text}`,
      checks: { share: null },
    };
  const ok = per.every((c) => c.ok);
  const bad = per.filter((c) => !c.ok).map((c) => c.cell);
  return {
    pass: ok,
    measured: `Novice non-wins that are deaths, per cell, line ${pct(NOVICE_DEATH_SHARE)}: ${text}${bad.length ? `; under the line: ${bad.join(", ")}` : ""}`,
    checks: { share: ok },
  };
}

export function plantNoviceDeaths(read) {
  return {
    ...clone(read),
    runs: clone(read.runs).map((r) => {
      if (r.column !== "novice" || gradeOf(r).result !== "loss") return r;
      return {
        ...r,
        row: r.row ? { ...r.row, outcome: "fight_capped" } : r.row,
        grade: { ...gradeOf(r), result: "timeout", reason: "fight_capped", diedS: undefined },
      };
    }),
  };
}

export const WORST_COLUMNS = ["learner5", "expert"];
const ROWS_FILE = JSON.parse(
  readFileSync(new URL("../world1-bands.rows.json", import.meta.url), "utf8"),
);
export const WORST_FLOOR = ROWS_FILE.rows.find((r) => r.id === "brindle-worst-minute")?.floor ?? {};

function worstSide(pairs, clean, records = false) {
  const vals = [];
  let unread = 0;
  let noHit = 0;
  for (const { note, row } of pairs) {
    if (typeof note.worst_60s_hull === "number")
      vals.push(note.worst_60s_hull / fightMaxHp(note, row).maxHp);
    else if (clean === "hits" ? note.hits === 0 : records === true) (vals.push(0), noHit++);
    else unread++;
  }
  return { n: pairs.length, unread, noHit, median: unread ? null : med(vals) };
}

export function gradeWorstMinute(read, head) {
  const none = Object.fromEntries(WORST_COLUMNS.map((c) => [c, null]));
  const sel = select(read, head, ["w1clear"]);
  if (sel.error) return { pass: false, measured: sel.error, checks: none };
  const counts = WORST_COLUMNS.map((c) => enough(sel, "w1clear", c, SEEDS.worstMinute));
  if (counts.some((c) => !c.ok))
    return {
      pass: false,
      measured: `Brindle against the dam, whole clear: ${tooFew(counts)}`,
      checks: none,
    };
  const checks = {};
  const damRecorded = sel.runs.some(
    (r) =>
      WORST_COLUMNS.includes(r.column) && typeof fightNotes(r.row).dam?.worst_60s_hull === "number",
  );
  const texts = WORST_COLUMNS.map((column) => {
    const fought = (key) =>
      sel.runs
        .filter((r) => r.column === column)
        .map((r) => ({ note: fightNotes(r.row)[key], row: r.row }))
        .filter((p) => p.note);
    const dam = worstSide(fought("dam"), "recorded", damRecorded);
    const boss = worstSide(fought("brindle"), "hits");
    const floor = WORST_FLOOR[column];
    const need = SEEDS.worstMinuteFights;
    const gap =
      dam.n < need
        ? `too few dam fights: ${dam.n} of ${need}`
        : boss.n < need
          ? `too few Brindle fights: ${boss.n} of ${need}`
          : dam.unread
            ? `dam no data (worst_60s_hull not recorded on any of ${dam.n} fights)`
            : boss.unread
              ? `Brindle no data (no worst_60s_hull and no hit count of 0 on ${boss.unread} of ${boss.n} fights)`
              : typeof floor !== "number"
                ? "no data (no floor for this column in the rows file)"
                : dam.median == null || boss.median == null
                  ? "no data (no median)"
                  : null;
    if (gap) {
      checks[column] = false;
      return `${column} ${gap}`;
    }
    const bar = Math.max(dam.median, floor);
    checks[column] = boss.median >= bar - 1e-9;
    const hits =
      boss.noHit === boss.n
        ? `no hit landed, n=${boss.n}`
        : boss.noHit
          ? `n=${boss.n}, ${boss.noHit} with no hit landed`
          : `n=${boss.n}`;
    return `${column} Brindle ${pct(boss.median)} (${hits}) against ${pct(bar)} (dam ${pct(dam.median)}, n=${dam.n}${dam.noHit ? `, ${dam.noHit} with no hit landed` : ""}; floor ${pct(floor)})`;
  });
  return {
    pass: WORST_COLUMNS.every((c) => checks[c] === true),
    measured: `median worst-minute hull lost, share of max hull: ${texts.join("; ")} (${counts.map((c) => c.text).join(", ")})`,
    checks,
  };
}

export function plantWorstMinute(read) {
  return {
    ...clone(read),
    runs: clone(read.runs).map((r) => {
      if (r.cell !== "w1clear" || !r.row?.boss) return r;
      const { hit_sources, worst_60s_hull, worst_60s_hp, worst_60s_max_hp, ...boss } = r.row.boss;
      return { ...r, row: { ...r.row, boss: { ...boss, hits: 0 } } };
    }),
  };
}

export const BOWL_COLUMNS = COLUMNS.map((c) => c.id);
export function gradeBowlStopTax(read, head) {
  const sel = select(read, head, ["brindle"]);
  if (sel.error) return { pass: false, measured: sel.error, checks: { tax: null } };
  const columns = BOWL_COLUMNS;
  const counts = columns.map((c) => enough(sel, "brindle", c, SEEDS.fairness));
  if (counts.some((c) => !c.ok))
    return {
      pass: false,
      measured: `Slag Bowl stop tax: ${tooFew(counts)}`,
      checks: { tax: false },
    };
  const pools = columns.map((column) => ({
    column,
    key: `brindle ${column}`,
    ...fairnessPool(sel.runs.filter((r) => r.column === column)),
  }));
  const unmeasured = thinMeasured(pools);
  if (unmeasured)
    return { pass: false, measured: `Slag Bowl stop tax: ${unmeasured}`, checks: { tax: false } };
  const bad = pools.filter((p) => p.stopTax == null || f2TaxUnder(p));
  const show = (p) =>
    `${p.column} ${p.stopTax == null ? `no data (${p.stopTaxNote})${p.pooledStopTax == null ? "" : `, ${p.pooledStopTax.toFixed(2)} with scrap`}` : f2TaxUnder(p) && p.pooledStopTax != null && (p.stopTax == null || p.pooledStopTax < p.stopTax) ? `${p.pooledStopTax.toFixed(2)} with scrap` : (p.stopTax ?? p.pooledStopTax).toFixed(2)}`;
  const text = `Slag Bowl stop tax, line ${FAIRNESS.stopTax.toFixed(1)}: ${pools.map(show).join(", ")}${bad.length ? `; under the line: ${bad.map((p) => p.column).join(", ")}` : ""} (${counts.map((c) => c.text).join(", ")})`;
  return { pass: bad.length === 0, measured: text, checks: { tax: bad.length === 0 } };
}

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

export const ROWS = {
  "strong-build-shows": {
    grade: gradeStrongBuild,
    plant: plantStrongBuild,
    targets: ["parts", "faster"],
  },
  "warden-fairness": { grade: gradeFairness, plant: plantFairness, targets: ["F1marked"] },
  "novice-deaths": { grade: gradeNoviceDeaths, plant: plantNoviceDeaths, targets: ["share"] },
  "brindle-worst-minute": {
    grade: gradeWorstMinute,
    plant: plantWorstMinute,
    targets: WORST_COLUMNS,
  },
  "brindle-stop-tax": { grade: gradeBowlStopTax, plant: plantBowlStopTax, targets: ["tax"] },
};

export function buildReceipt(id, read, head) {
  if (typeof head !== "string" || !COMMIT.test(head))
    throw new Error(
      `--head must be a commit of 7 to 40 hex characters, not ${JSON.stringify(head)}`,
    );
  const { grade, plant, targets } = ROWS[id];
  const real = grade(read, head);
  const planted = grade(plant(read), head);
  const caught = planted.pass === false && targets.every((t) => planted.checks[t] === false);
  const measured = caught
    ? real.measured
    : `${real.measured}; plant not caught (${planted.measured})`;
  return { head, pass: real.pass && caught, measured, plant_caught: caught };
}

export function buildReceipts(read, head) {
  return Object.fromEntries(Object.keys(ROWS).map((id) => [id, buildReceipt(id, read, head)]));
}

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
    console.error(
      "usage: band-receipts.mjs --band <band read folder> [--band <folder> ...] --head <commit> --out <receipts folder>",
    );
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
    console.log(
      `${id}: ${receipt.pass ? "pass" : "miss"}${receipt.plant_caught ? "" : " (plant not caught)"}: ${receipt.measured}`,
    );
  }
  return Object.values(receipts).every((r) => r.pass) ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url))
  process.exit(main(process.argv.slice(2)));
