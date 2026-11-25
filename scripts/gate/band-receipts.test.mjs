import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import {
  BOWL_COLUMNS,
  SEEDS,
  WORST_FLOOR,
  buildReceipt,
  buildReceipts,
  gradeBowlStopTax,
  gradeFairness,
  gradeNoviceDeaths,
  gradeStrongBuild,
  gradeWorstMinute,
  plantBowlStopTax,
  plantFairness,
  plantNoviceDeaths,
  plantStrongBuild,
  plantWorstMinute,
} from "./band-receipts.mjs";
import { COLUMNS } from "../challenge/lib.mjs";
import { med } from "../challenge/worst-window.mjs";
import { receiptRow } from "../world1-bands.mjs";

const HEAD = "3adc2fd0e8563b13c87f921b2ae85763467fec03";
const rows = JSON.parse(
  readFileSync(new URL("../world1-bands.rows.json", import.meta.url), "utf8"),
).rows;
const rowOf = (id) => rows.find((r) => r.id === id);
const script = fileURLToPath(new URL("./band-receipts.mjs", import.meta.url));

const kindOf = (cell) => (cell === "brindle" ? "boss" : cell === "w1clear" ? "clear" : "warden");
const run = (cell, column, seed, grade, row = {}) => ({
  id: `${cell}-${column}-${seed}`,
  cell,
  column,
  band: column,
  seed,
  kind: kindOf(cell),
  commit: HEAD,
  row: { resumed: true, ...row },
  grade,
});
const win = (fightS) => ({ result: "win", fightS });
const loss = { result: "loss", diedS: 50 };
const cap = { result: "timeout", reason: "fight_capped" };
const seeds = (n) => Array.from({ length: n }, (_, i) => i);

const fair = (over = {}) => ({
  hull: { telegraphed: 50, untelegraphed: 1, contact: 0, unknown: 0 },
  hit_sources: { warden: 30, chaser: 21 },
  killing_hit: null,
  slow_s: 30,
  fast_s: 60,
  slow_hull: 30,
  fast_hull: 10,
  first_hit: { s1: { contact: true, hit: true, first_hit_s: 5, opened_by_hit: false } },
  ...over,
});

const clearRow = ({ dam = 20, boss = 30 } = {}) => {
  const damNote =
    dam === "unrecorded"
      ? { stage: 1, warden_engaged_s: 40 }
      : dam === "unfought"
        ? { stage: 1, worst_60s_hull: 50, worst_60s_max_hp: 100 }
        : { stage: 1, warden_engaged_s: 40, worst_60s_hull: dam, worst_60s_max_hp: 100 };
  const bossNote =
    boss === "nohit"
      ? { entry_parts: 3, hits: 0 }
      : boss === "unrecorded"
        ? { entry_parts: 3 }
        : {
            entry_parts: 3,
            hits: 4,
            worst_60s_hull: boss,
            worst_60s_hp: boss,
            worst_60s_max_hp: 100,
            hit_sources: { brindle_slag: boss },
          };
  return {
    stages: [
      damNote,
      { stage: 2, warden_engaged_s: 50, worst_60s_hull: 10, worst_60s_max_hp: 100 },
    ],
    ...(boss === null ? {} : { boss: bossNote }),
  };
};

const band = ({
  n = 48,
  topParts = 8,
  topFight = 70,
  novice = (_cell, i) => [loss, loss, loss, cap][i % 4],
  fairness = () => fair(),
  clear = () => clearRow(),
} = {}) => ({
  runs: [
    ...seeds(n).map((i) =>
      run("brindle", "expertTop", i, win(topFight + (i % 3)), {
        boss: { entry_parts: topParts },
        fairness: fairness(),
      }),
    ),
    ...seeds(n).map((i) =>
      run("brindle", "expert", i, win(85 + (i % 3)), {
        boss: { entry_parts: 3 },
        fairness: fairness(),
      }),
    ),
    ...["w1", "w2", "w1clear"].flatMap((cell) =>
      seeds(n).map((i) =>
        run(cell, "novice", i, novice(cell, i), cell === "w1clear" ? {} : { fairness: fairness() }),
      ),
    ),
    ...["w1", "w2", "brindle"].flatMap((cell) =>
      seeds(n).map((i) => run(cell, "learner1", i, win(60), { fairness: fairness() })),
    ),
    ...["novice", "learner5"].flatMap((column) =>
      seeds(n).map((i) => run("brindle", column, i, loss, { fairness: fairness() })),
    ),
    ...["learner5", "expert"].flatMap((column) =>
      seeds(n).map((i) => run("w1clear", column, i, win(400), clear(column, i))),
    ),
  ],
});
const mapRuns = (read, f) => ({ ...read, runs: read.runs.map(f) });

test("a full band read that holds every line passes all five rows, and the done table accepts each receipt", () => {
  const receipts = buildReceipts(band(), HEAD);
  for (const [id, r] of Object.entries(receipts)) {
    assert.equal(r.pass, true, `${id}: ${r.measured}`);
    assert.equal(r.plant_caught, true, id);
    assert.deepEqual(receiptRow(rowOf(id), r, HEAD), { measured: r.measured, pass: true });
  }
  assert.match(
    receipts["strong-build-shows"].measured,
    /parts 8 top against 3 ordinary; fight 71 s top against 86 s ordinary \(brindle expertTop n=48, brindle expert n=48\)/,
  );
  assert.match(receipts["novice-deaths"].measured, /w1 36 of 48 \(75%, n=48\)/);
  assert.match(
    receipts["warden-fairness"].measured,
    /F1 holds in \d+ pools; F2 holds in \d+ pools; F3 holds in 3 pools; n 48 to 48/,
  );
  assert.match(
    receipts["brindle-worst-minute"].measured,
    /learner5 Brindle 30% \(n=48\) against 27% \(dam 20%, n=48; floor 27%\); expert Brindle 30% \(n=48\) against 20% \(dam 20%, n=48; floor 7%\)/,
  );
  assert.match(
    receipts["brindle-stop-tax"].measured,
    /Slag Bowl stop tax, line 2\.0: novice 6\.00, learner1 6\.00, learner5 6\.00, expert 6\.00, expertTop 6\.00 \(/,
  );
});

test("item 1: one run a column, or fewer seeds than the plan asks, is a miss with too few runs, never a pass", () => {
  const thin = buildReceipts(band({ n: 1 }), HEAD);
  for (const [id, r] of Object.entries(thin)) {
    assert.equal(r.pass, false, id);
    assert.match(r.measured, /too few runs/, id);
  }
  const r24 = band({ n: 24 });
  assert.equal(gradeFairness(r24, HEAD).pass, true);
  assert.match(gradeStrongBuild(r24, HEAD).measured, /too few runs: brindle expertTop n=24 of 48/);
  assert.match(gradeNoviceDeaths(r24, HEAD).measured, /too few runs: w1 novice n=24 of 48/);
  assert.equal(SEEDS.expert, 48);
});

test("a column cut short by --early-stop is too few runs, whatever the read's record says (ruling dg settles the win rate only)", () => {
  const short = mapRuns(band(), (r) => r);
  short.runs = short.runs.filter(
    (r) => !(r.cell === "w1" && r.column === "novice" && r.seed >= 30),
  );
  const recorded = {
    ...short,
    earlyStop: [{ cell: "w1", column: "novice", mark: true, planned: 48, ran: 30 }],
  };
  const g = gradeNoviceDeaths(recorded, HEAD);
  assert.equal(g.pass, false);
  assert.match(g.measured, /too few runs: w1 novice n=30 of 48/);
});

test("a tuned or tiered band read is refused by every row: the targets are for default difficulty", () => {
  for (const flag of ["--tune=mobs.interval_scale=2", "--run-tier=3"]) {
    const tuned = mapRuns(band(), (r) => ({ ...r, args: [flag, "--band=" + r.column] }));
    for (const grade of [
      gradeStrongBuild,
      gradeFairness,
      gradeNoviceDeaths,
      gradeWorstMinute,
      gradeBowlStopTax,
    ]) {
      const g = grade(tuned, HEAD);
      assert.equal(g.pass, false);
      assert.match(g.measured, /not default difficulty/);
    }
  }
  const plain = mapRuns(band(), (r) => ({
    ...r,
    args: ["--band=" + r.column, "--cell=" + r.cell],
  }));
  assert.equal(gradeNoviceDeaths(plain, HEAD).pass, true);
});

test("item 2: strong-build-shows misses when the top build is not faster, and the label swap plant makes both halves miss", () => {
  const slow = gradeStrongBuild(band({ topFight: 90 }), HEAD);
  assert.deepEqual([slow.pass, slow.checks.faster, slow.checks.parts], [false, false, true]);
  const swapped = gradeStrongBuild(plantStrongBuild(band()), HEAD);
  assert.deepEqual(
    [swapped.pass, swapped.checks.parts, swapped.checks.faster],
    [false, false, false],
  );
  const partsOnly = buildReceipt("strong-build-shows", band({ topFight: 90 }), HEAD);
  assert.equal(partsOnly.pass, false);
  assert.match(rowOf("strong-build-shows").plant, /labels swapped/);
});

test("item 3: novice-deaths is graded per cell, so a cell where every non-win is a time cap misses inside a good pool", () => {
  const read = band({ novice: (cell, i) => (cell === "w2" ? [win(40), cap][i % 2] : loss) });
  const g = gradeNoviceDeaths(read, HEAD);
  assert.equal(g.pass, false);
  assert.match(g.measured, /w2 0 of 24 \(0%, n=48\), .*; under the line: w2$/);
  const noLoss = gradeNoviceDeaths(
    band({ novice: (cell, i) => (cell === "w1clear" ? win(400) : [loss, loss, cap][i % 3]) }),
    HEAD,
  );
  assert.equal(noLoss.pass, true, noLoss.measured);
  assert.match(noLoss.measured, /w1clear no non-win \(n=48\)/);
  const planted = gradeNoviceDeaths(plantNoviceDeaths(band()), HEAD);
  assert.deepEqual([planted.pass, planted.checks.share], [false, false]);
});

test("item 4: a killing hit in the contact or unknown bucket is an F1 miss", () => {
  for (const bucket of ["contact", "unknown"]) {
    const read = mapRuns(band(), (r) =>
      r.cell === "w1" && r.column === "novice" && r.seed === 0
        ? { ...r, row: { ...r.row, fairness: fair({ killing_hit: { source: "chaser", bucket } }) } }
        : r,
    );
    const g = gradeFairness(read, HEAD);
    assert.deepEqual([g.pass, g.checks.F1], [false, false], bucket);
    assert.match(g.measured, /F1 misses in 1 of \d+ pools \(w1 novice/);
  }
});

test("item 5: a pool that measured no F1 or no F2 is a miss, not skipped", () => {
  const noF1 = mapRuns(band(), (r) =>
    r.cell === "w2" && r.column === "learner1"
      ? {
          ...r,
          row: {
            ...r.row,
            fairness: fair({ hull: { telegraphed: 0, untelegraphed: 0, contact: 0, unknown: 0 } }),
          },
        }
      : r,
  );
  const g1 = gradeFairness(noF1, HEAD);
  assert.deepEqual([g1.pass, g1.checks.F1], [false, false]);
  assert.match(g1.measured, /w2 learner1 not measured/);
  const noF2 = mapRuns(band(), (r) =>
    r.cell === "brindle" && r.column === "expert"
      ? { ...r, row: { ...r.row, fairness: fair({ fast_hull: 0 }) } }
      : r,
  );
  const g2 = gradeFairness(noF2, HEAD);
  assert.deepEqual([g2.pass, g2.checks.F2], [false, false]);
  assert.match(g2.measured, /brindle expert not measured \(no hull lost at cruise\)/);
  const quick = gradeFairness(
    band({
      fairness: () =>
        fair({
          first_hit: { s1: { contact: true, hit: true, first_hit_s: 1, opened_by_hit: false } },
        }),
    }),
    HEAD,
  );
  assert.deepEqual([quick.pass, quick.checks.F3], [false, false]);
  const hidden = gradeFairness(plantFairness(band()), HEAD);
  assert.deepEqual([hidden.pass, hidden.checks.F1marked], [false, false]);
  for (const id of ["strong-build-shows", "warden-fairness", "novice-deaths"])
    assert.match(rowOf(id).producer, /--library=<library dir>/);
});

test("a read whose F1 carries no mark anywhere cannot show its plant caught, so the done table voids it", () => {
  const unknown = band({
    fairness: () => fair({ hull: { telegraphed: 50, untelegraphed: 0, contact: 0, unknown: 20 } }),
  });
  const r = buildReceipt("warden-fairness", unknown, HEAD);
  assert.deepEqual([r.pass, r.plant_caught], [false, false]);
  assert.match(
    receiptRow(rowOf("warden-fairness"), r, HEAD).measured,
    /^void, the planted fault was not shown caught/,
  );
});

test("runs from another commit are not this head's read", () => {
  const stale = mapRuns(band(), (r) => ({
    ...r,
    commit: "ffffffffffffffffffffffffffffffffffffffff",
  }));
  for (const r of Object.values(buildReceipts(stale, HEAD))) {
    assert.equal(r.pass, false);
    assert.match(r.measured, /^band read ran on fffffffff, not 3adc2fd0e/);
  }
});

test("item 7: two shard folders that repeat a run count it once, and a short --head is refused", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "band-receipts-"));
  try {
    const read = band();
    const half = read.runs.filter(
      (r) => !(r.cell === "w1" && r.column === "novice" && r.seed >= 24),
    );
    for (const shard of ["a", "b"]) {
      mkdirSync(path.join(dir, shard));
      writeFileSync(
        path.join(dir, shard, "runs.ndjson"),
        half.map((r) => JSON.stringify(r)).join("\n") + "\n",
      );
    }
    const out = path.join(dir, "receipts");
    const p = spawnSync(
      process.execPath,
      [
        script,
        "--band",
        path.join(dir, "a"),
        "--band",
        path.join(dir, "b"),
        "--head",
        HEAD,
        "--out",
        out,
      ],
      { encoding: "utf8" },
    );
    assert.equal(p.status, 1);
    assert.match(
      JSON.parse(readFileSync(path.join(out, "novice-deaths.json"), "utf8")).measured,
      /too few runs: w1 novice n=24 of 48/,
    );
    const short = spawnSync(
      process.execPath,
      [script, "--band", path.join(dir, "a"), "--head", "3adc2f", "--out", out],
      { encoding: "utf8" },
    );
    assert.equal(short.status, 2);
    assert.match(short.stderr, /--head must be a commit of 7 to 40 hex characters/);
    assert.throws(() => buildReceipt("novice-deaths", read, "3adc"), /--head must be/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("the CLI reads a band read folder and writes one receipt per row", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "band-receipts-"));
  try {
    const read = band();
    writeFileSync(
      path.join(dir, "runs.ndjson"),
      read.runs.map((r) => JSON.stringify(r)).join("\n") + "\n",
    );
    execFileSync(
      process.execPath,
      [script, "--band", dir, "--head", HEAD, "--out", path.join(dir, "receipts")],
      { encoding: "utf8" },
    );
    for (const id of [
      "strong-build-shows",
      "warden-fairness",
      "novice-deaths",
      "brindle-worst-minute",
      "brindle-stop-tax",
    ]) {
      const r = JSON.parse(readFileSync(path.join(dir, "receipts", `${id}.json`), "utf8"));
      assert.deepEqual(
        [r.head, r.pass, r.plant_caught],
        [HEAD, true, true],
        `${id}: ${r.measured}`,
      );
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

const worst = (clear) => gradeWorstMinute(band({ clear }), HEAD);
const cols = (g) => [g.pass, g.checks.learner5, g.checks.expert];

test("brindle-worst-minute: the floor comes from the rows file, the W1-31 read's dam medians", () => {
  assert.deepEqual(WORST_FLOOR, { learner5: 0.27, expert: 0.07 });
  assert.deepEqual(rowOf("brindle-worst-minute").floor, WORST_FLOOR);
  assert.match(rowOf("brindle-worst-minute").basis, /comment 6935842041/);
  assert.match(rowOf("brindle-worst-minute").basis, /med in scripts\/challenge\/worst-window\.mjs/);
});

test("brindle-worst-minute: a Brindle that deals no damage misses in both columns, and the plant is that Brindle", () => {
  const silent = worst(() => clearRow({ boss: "nohit" }));
  assert.deepEqual(cols(silent), [false, false, false]);
  assert.match(silent.measured, /learner5 Brindle 0% \(no hit landed, n=48\) against 27%/);
  const planted = gradeWorstMinute(
    plantWorstMinute(band({ clear: () => clearRow({ dam: 0 }) })),
    HEAD,
  );
  assert.deepEqual(cols(planted), [false, false, false]);
  assert.match(
    planted.measured,
    /learner5 Brindle 0% \(no hit landed, n=48\) against 27% \(dam 0%, n=48; floor 27%\)/,
  );
  assert.equal(buildReceipt("brindle-worst-minute", band(), HEAD).plant_caught, true);
});

test("brindle-worst-minute: the bar is the larger of the dam's median and the floor, so both fights cannot sink together", () => {
  assert.equal(worst(() => clearRow()).pass, true);
  assert.deepEqual(cols(worst(() => clearRow({ dam: 1, boss: 2 }))), [false, false, false]);
  assert.equal(worst(() => clearRow({ dam: 30, boss: 30 })).pass, true);
  assert.deepEqual(cols(worst(() => clearRow({ dam: 40, boss: 30 }))), [false, false, false]);
  const at = worst((column) => clearRow({ dam: 0, boss: column === "learner5" ? 27 : 7 }));
  assert.equal(at.pass, true, at.measured);
  assert.deepEqual(
    cols(worst((column) => clearRow({ dam: 0, boss: column === "learner5" ? 26.9 : 7 }))),
    [false, false, true],
  );
  assert.deepEqual(
    cols(worst((column) => clearRow({ dam: 0, boss: column === "learner5" ? 27 : 6.9 }))),
    [false, true, false],
  );
  const w131 = worst((column) => clearRow({ dam: column === "learner5" ? 27 : 7, boss: 0 }));
  assert.deepEqual(cols(w131), [false, false, false]);
  assert.match(
    w131.measured,
    /learner5 Brindle 0% \(n=48\) against 27% \(dam 27%, n=48; floor 27%\); expert Brindle 0% \(n=48\) against 7%/,
  );
});

test("brindle-worst-minute: the median is the lower middle, so half the fights at 0 and half at 30 read 0% and miss", () => {
  const g = worst((_column, i) => clearRow({ dam: 0, boss: i % 2 ? 30 : 0 }));
  assert.deepEqual(cols(g), [false, false, false]);
  assert.match(g.measured, /learner5 Brindle 0% \(n=48\)/);
  assert.equal(med([0, 30]), 0);
});

test("brindle-worst-minute: too few runs, too few fights on either side, and a column whose runs were all excluded", () => {
  const thin = gradeWorstMinute(band({ n: 24 }), HEAD);
  assert.equal(thin.pass, false);
  assert.match(
    thin.measured,
    /too few runs: w1clear learner5 n=24 of 48, w1clear expert n=24 of 48/,
  );
  assert.equal(SEEDS.worstMinute, 48);
  assert.equal(SEEDS.worstMinuteFights, 24);
  const one = worst((_column, i) => clearRow({ boss: i === 0 ? 90 : null }));
  assert.deepEqual(cols(one), [false, false, false]);
  assert.match(one.measured, /learner5 too few Brindle fights: 1 of 24/);
  assert.match(
    worst((_c, i) => clearRow({ boss: i < 23 ? 90 : null })).measured,
    /too few Brindle fights: 23 of 24/,
  );
  assert.equal(worst((_c, i) => clearRow({ boss: i < 24 ? 90 : null })).pass, true);
  const unfought = worst((_c, i) => clearRow({ dam: i < 30 ? "unfought" : 20 }));
  assert.deepEqual(cols(unfought), [false, false, false]);
  assert.match(unfought.measured, /learner5 too few dam fights: 18 of 24/);
  const excluded = gradeWorstMinute(
    mapRuns(band(), (r) =>
      r.cell === "w1clear" && r.column === "expert" ? { ...r, grade: { result: "error" } } : r,
    ),
    HEAD,
  );
  assert.equal(excluded.pass, false);
  assert.match(excluded.measured, /too few runs: w1clear expert n=0 of 48/);
  const none = gradeWorstMinute({ runs: band().runs.filter((r) => r.cell !== "w1clear") }, HEAD);
  assert.match(none.measured, /too few runs: w1clear learner5 n=0 of 48/);
});

test("brindle-worst-minute: no data on either side is a miss, and a dam fight no hit landed in reads 0", () => {
  const oneClean = worst((_c, i) => clearRow({ dam: i === 0 ? "unrecorded" : 20, boss: 90 }));
  assert.deepEqual(cols(oneClean), [true, true, true]);
  assert.match(
    oneClean.measured,
    /learner5 Brindle 90% \(n=48\) against 27% \(dam 20%, n=48, 1 with no hit landed; floor 27%\)/,
  );
  const mostClean = worst((_c, i) => clearRow({ dam: i < 40 ? "unrecorded" : 60, boss: 26 }));
  assert.deepEqual(cols(mostClean), [false, false, true]);
  assert.match(
    mostClean.measured,
    /learner5 Brindle 26% \(n=48\) against 27% \(dam 0%, n=48, 40 with no hit landed; floor 27%\)/,
  );
  const damGap = worst(() => clearRow({ dam: "unrecorded", boss: 90 }));
  assert.deepEqual(cols(damGap), [false, false, false]);
  assert.match(
    damGap.measured,
    /learner5 dam no data \(worst_60s_hull not recorded on any of 48 fights\)/,
  );
  const smallHull = worst(() => ({
    ...clearRow(),
    boss: { entry_parts: 3, hits: 4, worst_60s_hull: 30, worst_60s_max_hp: 60 },
  }));
  assert.match(smallHull.measured, /learner5 Brindle 50% \(n=48\)/);
  const bossGap = worst(() => clearRow({ boss: "unrecorded" }));
  assert.deepEqual(cols(bossGap), [false, false, false]);
  assert.match(
    bossGap.measured,
    /learner5 Brindle no data \(no worst_60s_hull and no hit count of 0 on 48 of 48 fights\)/,
  );
  assert.match(
    worst(() => ({ ...clearRow(), boss: { entry_parts: 3, hits: 5 } })).measured,
    /Brindle no data/,
  );
  const oneBroken = worst((_c, i) =>
    i === 0 ? { ...clearRow(), boss: { entry_parts: 3, hits: 5 } } : clearRow({ boss: 90 }),
  );
  assert.deepEqual(cols(oneBroken), [false, false, false]);
  assert.match(
    oneBroken.measured,
    /learner5 Brindle no data \(no worst_60s_hull and no hit count of 0 on 1 of 48 fights\)/,
  );
  const cleanColumn = worst((c) => clearRow({ dam: c === "expert" ? "unrecorded" : 20, boss: 90 }));
  assert.deepEqual(cols(cleanColumn), [true, true, true]);
  assert.match(
    cleanColumn.measured,
    /expert Brindle 90% \(n=48\) against 7% \(dam 0%, n=48, 48 with no hit landed; floor 7%\)/,
  );
});

test("brindle-stop-tax: a stopped ball that loses the same as a cruising one misses, and that is the plant", () => {
  const same = gradeBowlStopTax(
    band({ fairness: () => fair({ slow_s: 30, fast_s: 30, slow_hull: 30, fast_hull: 30 }) }),
    HEAD,
  );
  assert.deepEqual([same.pass, same.checks.tax], [false, false]);
  assert.match(
    same.measured,
    /expert 1\.00.*; under the line: novice, learner1, learner5, expert, expertTop/,
  );
  const planted = gradeBowlStopTax(plantBowlStopTax(band()), HEAD);
  assert.deepEqual([planted.pass, planted.checks.tax], [false, false]);
  assert.match(
    planted.measured,
    /novice 1\.00, learner1 1\.00, learner5 1\.00, expert 1\.00, expertTop 1\.00/,
  );
  const uneven = mapRuns(band(), (r) =>
    r.cell === "brindle"
      ? {
          ...r,
          row: {
            ...r.row,
            fairness: fair({
              slow_s: 10 + (r.seed % 7) * 9,
              fast_s: 5 + (r.seed % 5) * 17,
              slow_hull: 40,
              fast_hull: 3 + (r.seed % 3) * 8,
            }),
          },
        }
      : r,
  );
  assert.match(
    gradeBowlStopTax(plantBowlStopTax(uneven), HEAD).measured,
    /novice 1\.00, learner1 1\.00, learner5 1\.00, expert 1\.00, expertTop 1\.00/,
  );
  assert.equal(buildReceipt("brindle-stop-tax", band(), HEAD).plant_caught, true);
});

test("brindle-stop-tax: every default column is a pool of its own, and one under the line misses while the rest pass", () => {
  assert.deepEqual(
    BOWL_COLUMNS,
    COLUMNS.map((c) => c.id),
  );
  assert.equal(gradeBowlStopTax(band(), HEAD).pass, true);
  assert.equal(
    gradeBowlStopTax(
      band({ fairness: () => fair({ slow_s: 30, fast_s: 30, slow_hull: 20, fast_hull: 10 }) }),
      HEAD,
    ).pass,
    true,
  );
  assert.equal(
    gradeBowlStopTax(
      band({ fairness: () => fair({ slow_s: 30, fast_s: 30, slow_hull: 19, fast_hull: 10 }) }),
      HEAD,
    ).pass,
    false,
  );
  const one = gradeBowlStopTax(
    mapRuns(band(), (r) =>
      r.cell === "brindle" && r.column === "learner5"
        ? {
            ...r,
            row: {
              ...r.row,
              fairness: fair({ slow_s: 30, fast_s: 30, slow_hull: 10, fast_hull: 10 }),
            },
          }
        : r,
    ),
    HEAD,
  );
  assert.deepEqual([one.pass, one.checks.tax], [false, false]);
  assert.match(one.measured, /learner5 1\.00, expert 6\.00, .*; under the line: learner5 \(/);
  assert.equal(
    gradeBowlStopTax(
      mapRuns(band(), (r) =>
        r.cell === "w1" ? { ...r, row: { ...r.row, fairness: fair({ slow_hull: 1 }) } } : r,
      ),
      HEAD,
    ).pass,
    true,
  );
});

test("brindle-stop-tax: a missing column, too few runs, too few fairness records and no stop tax are each a miss", () => {
  const lone = gradeBowlStopTax(
    { runs: band().runs.filter((r) => r.cell !== "brindle" || r.column === "expert") },
    HEAD,
  );
  assert.deepEqual([lone.pass, lone.checks.tax], [false, false]);
  assert.match(
    lone.measured,
    /too few runs: brindle novice n=0 of 24, brindle learner1 n=0 of 24, brindle learner5 n=0 of 24, brindle expertTop n=0 of 24/,
  );
  const thin = gradeBowlStopTax(band({ n: 23 }), HEAD);
  assert.match(thin.measured, /too few runs: brindle novice n=23 of 24/);
  assert.equal(SEEDS.fairness, 24);
  const excluded = gradeBowlStopTax(
    mapRuns(band(), (r) =>
      r.cell === "brindle" && r.column === "learner1" ? { ...r, grade: { result: "error" } } : r,
    ),
    HEAD,
  );
  assert.match(excluded.measured, /too few runs: brindle learner1 n=0 of 24/);
  const sparse = gradeBowlStopTax(
    mapRuns(band(), (r) =>
      r.cell === "brindle" && r.column === "expert" && r.seed > 0
        ? { ...r, row: { ...r.row, fairness: undefined } }
        : r,
    ),
    HEAD,
  );
  assert.deepEqual([sparse.pass, sparse.checks.tax], [false, false]);
  assert.match(sparse.measured, /too few runs with a fairness record: brindle expert 1 of 24/);
  const noFast = gradeBowlStopTax(band({ fairness: () => fair({ fast_hull: 0 }) }), HEAD);
  assert.deepEqual([noFast.pass, noFast.checks.tax], [false, false]);
  assert.match(noFast.measured, /expert no data \(no hull lost at cruise\)/);
});

test("warden-fairness: a pool with enough runs but too few fairness records is a miss", () => {
  const sparse = mapRuns(band(), (r) =>
    r.cell === "w2" && r.column === "learner1" && r.seed >= 23
      ? { ...r, row: { ...r.row, fairness: undefined } }
      : r,
  );
  const g = gradeFairness(sparse, HEAD);
  assert.equal(g.pass, false);
  assert.match(g.measured, /too few runs with a fairness record: w2 learner1 23 of 24/);
  const enoughRecords = mapRuns(band(), (r) =>
    r.cell === "w2" && r.column === "learner1" && r.seed >= 24
      ? { ...r, row: { ...r.row, fairness: undefined } }
      : r,
  );
  assert.equal(gradeFairness(enoughRecords, HEAD).pass, true);
});

test("the command line cannot stamp a Brindle pass: unknown flags change nothing and a miss exits 1", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "band-receipts-"));
  try {
    const read = band({ clear: () => clearRow({ boss: 0 }) });
    writeFileSync(
      path.join(dir, "runs.ndjson"),
      read.runs.map((r) => JSON.stringify(r)).join("\n") + "\n",
    );
    const out = path.join(dir, "receipts");
    const p = spawnSync(
      process.execPath,
      [
        script,
        "--band",
        dir,
        "--head",
        HEAD,
        "--out",
        out,
        "--pass",
        "brindle-worst-minute",
        "--early-stop",
        "1",
      ],
      { encoding: "utf8" },
    );
    assert.equal(p.status, 1);
    const r = JSON.parse(readFileSync(path.join(out, "brindle-worst-minute.json"), "utf8"));
    assert.deepEqual([r.pass, r.plant_caught], [false, true]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("each row's producer names this command", () => {
  for (const id of [
    "strong-build-shows",
    "warden-fairness",
    "novice-deaths",
    "brindle-worst-minute",
    "brindle-stop-tax",
  ])
    assert.match(
      rowOf(id).producer,
      /node scripts\/gate\/band-receipts\.mjs --band <band read folder> --head <commit> --out <dir>/,
    );
});

test("F2: a pool with no hull lost at cruise stays a miss, whatever the scrap at cruise reads", () => {
  const scrapOnly = () =>
    fair({ slow_s: 30, fast_s: 60, slow_hull: 20, fast_hull: 0, slow_scrap: 0, fast_scrap: 1 });
  const g = gradeFairness(band({ fairness: scrapOnly }), HEAD);
  assert.equal(g.checks.F2, false);
  const bowl = gradeBowlStopTax(band({ fairness: scrapOnly }), HEAD);
  assert.deepEqual([bowl.pass, bowl.checks.tax], [false, false]);
  assert.match(bowl.measured, /expert no data \(.*\), 40\.00 with scrap/);
});
