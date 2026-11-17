import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import { SEEDS, buildReceipt, buildReceipts, gradeFairness, gradeNoviceDeaths, gradeStrongBuild, plantFairness, plantNoviceDeaths, plantStrongBuild } from "./band-receipts.mjs";
import { receiptRow } from "../world1-bands.mjs";

const HEAD = "3adc2fd0e8563b13c87f921b2ae85763467fec03";
const rows = JSON.parse(readFileSync(new URL("../world1-bands.rows.json", import.meta.url), "utf8")).rows;
const rowOf = (id) => rows.find((r) => r.id === id);
const script = fileURLToPath(new URL("./band-receipts.mjs", import.meta.url));

// One runs.ndjson line, as scripts/challenge/run.mjs writes it: the job fields, the commit, the bot row and the grade.
const kindOf = (cell) => (cell === "brindle" ? "boss" : cell === "w1clear" ? "clear" : "warden");
const run = (cell, column, seed, grade, row = {}) => ({ id: `${cell}-${column}-${seed}`, cell, column, band: column, seed, kind: kindOf(cell), commit: HEAD, row: { resumed: true, ...row }, grade });
const win = (fightS) => ({ result: "win", fightS });
const loss = { result: "loss", diedS: 50 };
const cap = { result: "timeout", reason: "fight_capped" };
const seeds = (n) => Array.from({ length: n }, (_, i) => i);

const fair = (over = {}) => ({
  hull: { telegraphed: 50, untelegraphed: 1, contact: 0, unknown: 0 },
  hit_sources: { warden: 30, chaser: 21 },
  killing_hit: null,
  slow_s: 30, fast_s: 60, slow_hull: 30, fast_hull: 10,
  first_hit: { s1: { contact: true, hit: true, first_hit_s: 5, opened_by_hit: false } },
  ...over,
});

// A full read: 48 seeds in every column, so every pool has what the plan asks. novice(cell, i) gives the Novice grade.
const band = ({ n = 48, topParts = 8, topFight = 70, novice = (_cell, i) => [loss, loss, loss, cap][i % 4], fairness = () => fair() } = {}) => ({
  earlyStop: [],
  runs: [
    ...seeds(n).map((i) => run("brindle", "expertTop", i, win(topFight + (i % 3)), { boss: { entry_parts: topParts }, fairness: fairness() })),
    ...seeds(n).map((i) => run("brindle", "expert", i, win(85 + (i % 3)), { boss: { entry_parts: 3 }, fairness: fairness() })),
    ...["w1", "w2", "w1clear"].flatMap((cell) => seeds(n).map((i) => run(cell, "novice", i, novice(cell, i), cell === "w1clear" ? {} : { fairness: fairness() }))),
    ...["w1", "w2", "brindle"].flatMap((cell) => seeds(n).map((i) => run(cell, "learner1", i, win(60), { fairness: fairness() }))),
  ],
});
const mapRuns = (read, f) => ({ ...read, runs: read.runs.map(f) });

test("a full band read that holds every line passes all three rows, and the done table accepts each receipt", () => {
  const receipts = buildReceipts(band(), HEAD);
  for (const [id, r] of Object.entries(receipts)) {
    assert.equal(r.pass, true, `${id}: ${r.measured}`);
    assert.equal(r.plant_caught, true, id);
    assert.deepEqual(receiptRow(rowOf(id), r, HEAD), { measured: r.measured, pass: true });
  }
  assert.match(receipts["strong-build-shows"].measured, /parts 8 top against 3 ordinary; fight 71 s top against 86 s ordinary \(brindle expertTop n=48, brindle expert n=48\)/);
  assert.match(receipts["novice-deaths"].measured, /w1 36 of 48 \(75%, n=48\)/);
  assert.match(receipts["warden-fairness"].measured, /F1 holds in \d+ pools; F2 holds in \d+ pools; F3 holds in 3 pools; n 48 to 48/);
});

test("item 1: one run a column, or fewer seeds than the plan asks, is a miss with too few runs, never a pass", () => {
  const thin = buildReceipts(band({ n: 1 }), HEAD);
  for (const [id, r] of Object.entries(thin)) {
    assert.equal(r.pass, false, id);
    assert.match(r.measured, /too few runs/, id);
  }
  // 24 seeds is the fairness pool's count (plan lines 59 to 61) but short of the Expert's and the dam Novice's 48.
  const r24 = band({ n: 24 });
  assert.equal(gradeFairness(r24, HEAD).pass, true);
  assert.match(gradeStrongBuild(r24, HEAD).measured, /too few runs: brindle expertTop n=24 of 48/);
  assert.match(gradeNoviceDeaths(r24, HEAD).measured, /too few runs: w1 novice n=24 of 48/);
  assert.equal(SEEDS.expert, 48);
});

test("item 1: a column cut short by --early-stop counts only when the read's record says it stopped and how many ran", () => {
  const short = mapRuns(band(), (r) => r);
  short.runs = short.runs.filter((r) => !(r.cell === "w1" && r.column === "novice" && r.seed >= 30));
  assert.match(gradeNoviceDeaths(short, HEAD).measured, /too few runs: w1 novice n=30 of 48/);
  const recorded = { ...short, earlyStop: [{ cell: "w1", column: "novice", mark: true, planned: 48, ran: 30 }] };
  const g = gradeNoviceDeaths(recorded, HEAD);
  assert.equal(g.pass, true, g.measured);
  assert.match(g.measured, /w1 \d+ of \d+ \(\d+%, n=30\)/);
  // A record that claims more runs than the folder holds, or a plan smaller than the plan's count, does not count.
  assert.equal(gradeNoviceDeaths({ ...short, earlyStop: [{ cell: "w1", column: "novice", mark: true, planned: 48, ran: 40 }] }, HEAD).pass, false);
  assert.equal(gradeNoviceDeaths({ ...short, earlyStop: [{ cell: "w1", column: "novice", mark: true, planned: 30, ran: 30 }] }, HEAD).pass, false);
});

test("item 2: strong-build-shows misses when the top build is not faster, and the label swap plant makes both halves miss", () => {
  const slow = gradeStrongBuild(band({ topFight: 90 }), HEAD);
  assert.deepEqual([slow.pass, slow.checks.faster, slow.checks.parts], [false, false, true]);
  const swapped = gradeStrongBuild(plantStrongBuild(band()), HEAD);
  assert.deepEqual([swapped.pass, swapped.checks.parts, swapped.checks.faster], [false, false, false]);
  // A plant that left the fight time alone would not be caught: same parts gap, swapped fight times only.
  const partsOnly = buildReceipt("strong-build-shows", band({ topFight: 90 }), HEAD);
  assert.equal(partsOnly.pass, false);
  assert.match(rowOf("strong-build-shows").plant, /labels swapped/);
});

test("item 3: novice-deaths is graded per cell, so a cell where every non-win is a time cap misses inside a good pool", () => {
  const read = band({ novice: (cell, i) => (cell === "w2" ? [win(40), cap][i % 2] : loss) });
  const g = gradeNoviceDeaths(read, HEAD);
  assert.equal(g.pass, false);
  assert.match(g.measured, /w2 0 of 24 \(0%, n=48\), .*; under the line: w2$/);
  const noLoss = gradeNoviceDeaths(band({ novice: (cell, i) => (cell === "w1clear" ? win(400) : [loss, loss, cap][i % 3]) }), HEAD);
  assert.equal(noLoss.pass, true, noLoss.measured);
  assert.match(noLoss.measured, /w1clear no non-win \(n=48\)/);
  const planted = gradeNoviceDeaths(plantNoviceDeaths(band()), HEAD);
  assert.deepEqual([planted.pass, planted.checks.share], [false, false]);
});

test("item 4: a killing hit in the contact or unknown bucket is an F1 miss", () => {
  for (const bucket of ["contact", "unknown"]) {
    const read = mapRuns(band(), (r) => (r.cell === "w1" && r.column === "novice" && r.seed === 0 ? { ...r, row: { ...r.row, fairness: fair({ killing_hit: { source: "chaser", bucket } }) } } : r));
    const g = gradeFairness(read, HEAD);
    assert.deepEqual([g.pass, g.checks.F1], [false, false], bucket);
    assert.match(g.measured, /F1 misses in 1 of \d+ pools \(w1 novice/);
  }
});

test("item 5: a pool that measured no F1 or no F2 is a miss, not skipped", () => {
  const noF1 = mapRuns(band(), (r) => (r.cell === "w2" && r.column === "learner1" ? { ...r, row: { ...r.row, fairness: fair({ hull: { telegraphed: 0, untelegraphed: 0, contact: 0, unknown: 0 } }) } } : r));
  const g1 = gradeFairness(noF1, HEAD);
  assert.deepEqual([g1.pass, g1.checks.F1], [false, false]);
  assert.match(g1.measured, /w2 learner1 not measured/);
  const noF2 = mapRuns(band(), (r) => (r.cell === "brindle" && r.column === "expert" ? { ...r, row: { ...r.row, fairness: fair({ fast_hull: 0 }) } } : r));
  const g2 = gradeFairness(noF2, HEAD);
  assert.deepEqual([g2.pass, g2.checks.F2], [false, false]);
  assert.match(g2.measured, /brindle expert not measured \(no hull lost at cruise\)/);
  const quick = gradeFairness(band({ fairness: () => fair({ first_hit: { s1: { contact: true, hit: true, first_hit_s: 1, opened_by_hit: false } } }) }), HEAD);
  assert.deepEqual([quick.pass, quick.checks.F3], [false, false]);
  const hidden = gradeFairness(plantFairness(band()), HEAD);
  assert.deepEqual([hidden.pass, hidden.checks.F1marked], [false, false]);
  for (const id of ["strong-build-shows", "warden-fairness", "novice-deaths"]) assert.match(rowOf(id).producer, /--library=<library dir>/);
});

test("a read whose F1 carries no mark anywhere cannot show its plant caught, so the done table voids it", () => {
  const unknown = band({ fairness: () => fair({ hull: { telegraphed: 50, untelegraphed: 0, contact: 0, unknown: 20 } }) });
  const r = buildReceipt("warden-fairness", unknown, HEAD);
  assert.deepEqual([r.pass, r.plant_caught], [false, false]);
  assert.match(receiptRow(rowOf("warden-fairness"), r, HEAD).measured, /^void, the planted fault was not shown caught/);
});

test("runs from another commit are not this head's read", () => {
  const stale = mapRuns(band(), (r) => ({ ...r, commit: "ffffffffffffffffffffffffffffffffffffffff" }));
  for (const r of Object.values(buildReceipts(stale, HEAD))) {
    assert.equal(r.pass, false);
    assert.match(r.measured, /^band read ran on fffffffff, not 3adc2fd0e/);
  }
});

test("item 7: two shard folders that repeat a run count it once, and a short --head is refused", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "band-receipts-"));
  try {
    // 24 Novice seeds of w1, written to two shards that each carry all of them: still 24, short of the 48 needed.
    const read = band();
    const half = read.runs.filter((r) => !(r.cell === "w1" && r.column === "novice" && r.seed >= 24));
    for (const shard of ["a", "b"]) {
      mkdirSync(path.join(dir, shard));
      writeFileSync(path.join(dir, shard, "runs.ndjson"), half.map((r) => JSON.stringify(r)).join("\n") + "\n");
    }
    const out = path.join(dir, "receipts");
    const p = spawnSync(process.execPath, [script, "--band", path.join(dir, "a"), "--band", path.join(dir, "b"), "--head", HEAD, "--out", out], { encoding: "utf8" });
    assert.equal(p.status, 1);
    assert.match(JSON.parse(readFileSync(path.join(out, "novice-deaths.json"), "utf8")).measured, /too few runs: w1 novice n=24 of 48/);
    const short = spawnSync(process.execPath, [script, "--band", path.join(dir, "a"), "--head", "3adc2f", "--out", out], { encoding: "utf8" });
    assert.equal(short.status, 2);
    assert.match(short.stderr, /--head must be a commit of 7 to 40 hex characters/);
    assert.throws(() => buildReceipt("novice-deaths", read, "3adc"), /--head must be/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("the CLI reads a band read folder and its early-stop record and writes one receipt per row", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "band-receipts-"));
  try {
    const read = band();
    read.runs = read.runs.filter((r) => !(r.cell === "w2" && r.column === "novice" && r.seed >= 20));
    writeFileSync(path.join(dir, "runs.ndjson"), read.runs.map((r) => JSON.stringify(r)).join("\n") + "\n");
    writeFileSync(path.join(dir, "table.json"), JSON.stringify({ early_stop: [{ cell: "w2", column: "novice", mark: true, planned: 48, ran: 20 }] }));
    execFileSync(process.execPath, [script, "--band", dir, "--head", HEAD, "--out", path.join(dir, "receipts")], { encoding: "utf8" });
    for (const id of ["strong-build-shows", "warden-fairness", "novice-deaths"]) {
      const r = JSON.parse(readFileSync(path.join(dir, "receipts", `${id}.json`), "utf8"));
      assert.deepEqual([r.head, r.pass, r.plant_caught], [HEAD, true, true], `${id}: ${r.measured}`);
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("each row's producer names this command", () => {
  for (const id of ["strong-build-shows", "warden-fairness", "novice-deaths"]) assert.match(rowOf(id).producer, /node scripts\/gate\/band-receipts\.mjs --band <band read folder> --head <commit> --out <dir>/);
});
