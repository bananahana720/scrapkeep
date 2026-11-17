import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import { buildReceipt, buildReceipts, gradeFairness, gradeNoviceDeaths, gradeStrongBuild, plantFairness, plantNoviceDeaths, plantStrongBuild } from "./band-receipts.mjs";
import { receiptRow } from "../world1-bands.mjs";

const HEAD = "3adc2fd0e8563b13c87f921b2ae85763467fec03";
const rows = JSON.parse(readFileSync(new URL("../world1-bands.rows.json", import.meta.url), "utf8")).rows;
const rowOf = (id) => rows.find((r) => r.id === id);

// One runs.ndjson line, as scripts/challenge/run.mjs writes it: the job fields, the commit, the bot row and the grade.
const run = (cell, column, grade, row = {}, commit = HEAD) => ({ cell, column, band: column, kind: cell === "brindle" ? "boss" : "warden", commit, row: { resumed: true, ...row }, grade });
const win = (fightS) => ({ result: "win", fightS });
const loss = { result: "loss", diedS: 50 };
const cap = { result: "timeout", reason: "fight_capped" };

const fair = (over = {}) => ({
  hull: { telegraphed: 50, untelegraphed: 1, contact: 0, unknown: 0 },
  hit_sources: { warden: 30, chaser: 21 },
  killing_hit: null,
  slow_s: 30, fast_s: 60, slow_hull: 30, fast_hull: 10,
  first_hit: { s1: { contact: true, hit: true, first_hit_s: 5, opened_by_hit: false } },
  ...over,
});
const boss = (parts, fightS) => run("brindle", parts > 4 ? "expertTop" : "expert", win(fightS), { boss: { entry_parts: parts, defeated_s: fightS } });

const band = ({ topParts = 8, topFight = 70, novice = [loss, loss, loss, cap], fairness = fair } = {}) => [
  boss(topParts, topFight), { ...boss(topParts, topFight), column: "expertTop" }, { ...boss(topParts, topFight + 4), column: "expertTop" },
  boss(3, 85), boss(3, 82), boss(2, 88),
  ...novice.map((g, i) => run(["w1", "w2", "brindle"][i % 3], "novice", g, { fairness: fairness() })),
  ...["w1", "w2", "brindle"].flatMap((cell) => ["learner1", "learner5"].map((col) => run(cell, col, win(60), { fairness: fairness() }))),
];

test("a band read that holds every line passes all three rows, and the done table accepts each receipt", () => {
  const receipts = buildReceipts(band(), HEAD);
  for (const [id, r] of Object.entries(receipts)) {
    assert.equal(r.pass, true, `${id}: ${r.measured}`);
    assert.equal(r.plant_caught, true, id);
    assert.deepEqual(receiptRow(rowOf(id), r, HEAD), { measured: r.measured, pass: true });
  }
  assert.match(receipts["strong-build-shows"].measured, /parts 8 top against 3 ordinary; fight 70 s top against 85 s ordinary/);
  assert.match(receipts["novice-deaths"].measured, /3 of 4 \(75%, line 60%\)/);
  assert.match(receipts["warden-fairness"].measured, /F1 holds in \d+ pools; F2 holds/);
});

test("strong-build-shows misses when the top build is not faster, and when its parts are stripped (the plant)", () => {
  const slow = gradeStrongBuild(band({ topFight: 90 }), HEAD);
  assert.deepEqual([slow.pass, slow.checks.faster, slow.checks.parts], [false, false, true]);
  const stripped = gradeStrongBuild(plantStrongBuild(band()), HEAD);
  assert.deepEqual([stripped.pass, stripped.checks.parts], [false, false]);
  assert.match(gradeStrongBuild(band().filter((r) => r.column !== "expertTop"), HEAD).measured, /needs both Expert columns/);
});

test("novice-deaths reads deaths over non-wins against 60%, and the all-caps plant misses", () => {
  const low = gradeNoviceDeaths(band({ novice: [loss, cap, cap, loss, cap] }), HEAD);
  assert.equal(low.pass, false);
  assert.match(low.measured, /2 of 5 \(40%/);
  const planted = gradeNoviceDeaths(plantNoviceDeaths(band()), HEAD);
  assert.deepEqual([planted.pass, planted.checks.share], [false, false]);
  assert.match(gradeNoviceDeaths(band({ novice: [win(40)] }), HEAD).measured, /no Novice non-win/);
});

test("warden-fairness grades F1 to F3 with fairness.json's lines and F3 on Learner attempt 1 only", () => {
  const taxFree = gradeFairness(band({ fairness: () => fair({ slow_hull: 5, fast_hull: 10 }) }), HEAD);
  assert.deepEqual([taxFree.pass, taxFree.checks.F2], [false, false]);
  const quick = gradeFairness(band({ fairness: () => fair({ first_hit: { s1: { contact: true, hit: true, first_hit_s: 1, opened_by_hit: false } } }) }), HEAD);
  assert.deepEqual([quick.pass, quick.checks.F3], [false, false]);
  // A fast first hit for Learner attempt 5 alone is not an F3 miss.
  const laterQuick = band().map((r) => (r.column === "learner5" && r.row.fairness ? { ...r, row: { ...r.row, fairness: fair({ first_hit: { s1: { contact: true, hit: true, first_hit_s: 1, opened_by_hit: false } } }) } } : r));
  assert.equal(gradeFairness(laterQuick, HEAD).checks.F3, true);
  const hidden = gradeFairness(plantFairness(band()), HEAD);
  assert.deepEqual([hidden.pass, hidden.checks.F1marked], [false, false]);
  const killed = band().map((r) => (r.cell === "w1" && r.column === "novice" ? { ...r, row: { ...r.row, fairness: fair({ killing_hit: { source: "warden", bucket: "untelegraphed" } }) } } : r));
  assert.equal(gradeFairness(killed, HEAD).checks.F1, false);
  assert.match(gradeFairness(band().filter((r) => r.cell !== "w2"), HEAD).measured, /no fairness record for w2/);
});

test("a read whose F1 carries no mark anywhere cannot show its plant caught, so the done table voids it", () => {
  const unknown = band({ fairness: () => fair({ hull: { telegraphed: 50, untelegraphed: 0, contact: 0, unknown: 20 } }) });
  const r = buildReceipt("warden-fairness", unknown, HEAD);
  assert.deepEqual([r.pass, r.plant_caught], [false, false]);
  assert.match(receiptRow(rowOf("warden-fairness"), r, HEAD).measured, /^void, the planted fault was not shown caught/);
});

test("runs from another commit are not this head's read", () => {
  const stale = band().map((r) => ({ ...r, commit: "ffffffffffffffffffffffffffffffffffffffff" }));
  for (const r of Object.values(buildReceipts(stale, HEAD))) {
    assert.equal(r.pass, false);
    assert.match(r.measured, /^band read ran on fffffffff, not 3adc2fd0e/);
  }
});

test("the CLI reads a band read folder and writes one receipt per row", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "band-receipts-"));
  try {
    writeFileSync(path.join(dir, "runs.ndjson"), band().map((r) => JSON.stringify(r)).join("\n") + "\n");
    const script = fileURLToPath(new URL("./band-receipts.mjs", import.meta.url));
    execFileSync(process.execPath, [script, "--band", dir, "--head", HEAD, "--out", path.join(dir, "receipts")], { encoding: "utf8" });
    for (const id of ["strong-build-shows", "warden-fairness", "novice-deaths"]) {
      const r = JSON.parse(readFileSync(path.join(dir, "receipts", `${id}.json`), "utf8"));
      assert.deepEqual([r.head, r.pass, r.plant_caught], [HEAD, true, true]);
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("each row's producer names this command", () => {
  for (const id of ["strong-build-shows", "warden-fairness", "novice-deaths"]) assert.match(rowOf(id).producer, /node scripts\/gate\/band-receipts\.mjs --band <band read folder> --head <commit> --out <dir>/);
});
