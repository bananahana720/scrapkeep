import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

import {
  MAPS,
  OPEN_HALVES,
  PINNED_LINES,
  POINTS,
  TESTS,
  VERIFIED_HALVES,
  WAITING,
  buildReceipt,
  mapLines,
  parseArgs,
  produce,
} from "./map-standard-receipt.mjs";
import { receiptRow } from "../world1-bands.mjs";

const HEAD = "3adc2fd0e8563b13c87f921b2ae85763467fec03";
const OTHER_HEAD = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const row = {
  id: "map-standard",
  plant: "every map test's planted fault must fail its line",
  producer: "x",
};

function logs({
  status = {},
  value = {},
  drop = [],
  plantPass = null,
  failCheck = null,
  extra = 0,
} = {}) {
  const out = {};
  const tests = Object.keys(TESTS);
  for (const t of tests) out[t] = [`[${t} a check] ok -> PASS`];
  let n = 0;
  const add = (t, map, measure) => {
    if (drop.includes(`${map} ${measure}`)) return;
    out[t].push(
      `MAPCHECK ${map} ${measure} ${value[`${map} ${measure}`] ?? "1.00"} pass>=0.50 ${status[`${map} ${measure}`] ?? "PASS"}`,
    );
    n += 1;
  };
  Object.values(POINTS).forEach((measures, i) =>
    MAPS.forEach((m) => add(tests[i % tests.length], m, measures[0])),
  );
  while (n < PINNED_LINES + extra) add("site_markers_test", MAPS[n % 2], "marker_sight");
  for (const t of tests) {
    out[t].push(`MAPCHECK park_dam report INFO detail`);
    for (let i = 0; i < TESTS[t]; i += 1)
      out[t].push(`PLANTED ${t}_${i} x 0.00 pass>=0.50 ${plantPass === t ? "PASS" : "FAIL"}`);
    if (failCheck === t) out[t].push(`[${t} broke] x -> FAIL`, `${t}: FAIL (1 of 2 checks)`);
    else out[t].push(`${t}: PASS (2 checks)`);
  }
  for (const t of tests) out[t] = out[t].join("\n");
  return out;
}

test("map standard: every point checked on both maps, every line passing and every plant caught passes", () => {
  const r = buildReceipt(logs(), HEAD);
  assert.equal(r.pass, true, r.measured);
  assert.equal(r.plant_caught, true);
  assert.match(
    r.measured,
    new RegExp(
      `^${PINNED_LINES} MAPCHECK lines \\(pinned ${PINNED_LINES}\\); lines per point dam/flume 1:1/1 `,
    ),
  );
  assert.deepEqual(receiptRow(row, r, HEAD), { measured: r.measured, pass: true });
});

test("map standard: an OWED line not ruled to wait is a miss, one on a waiting fixture is held with its citation", () => {
  const owed = buildReceipt(
    logs({ status: { "park_flume height_bands_populated": "OWED" } }),
    HEAD,
  );
  assert.equal(owed.pass, false);
  assert.match(owed.measured, /misses: park_flume height_bands_populated 1.00 pass>=0.50 OWED/);
  const yard = "park_flume yard_rim_median_m";
  assert.equal(WAITING.length, 0);
  const unparkedYard = buildReceipt(
    logs({ status: { [yard]: "OWED" }, value: { [yard]: "-0.41" } }),
    HEAD,
  );
  assert.equal(unparkedYard.pass, false);
  assert.match(unparkedYard.measured, /misses: park_flume yard_rim_median_m -0.41/);

  const waitingFixture = [
    {
      map: "park_flume",
      measure: "yard_rim_median_m",
      status: "OWED",
      value: "-0.41",
      why: "parked fixture",
      cite: "project-guide/handoff/ROADMAP.md:27 (parked fixture)",
    },
  ];
  const parked = buildReceipt(
    logs({ status: { [yard]: "OWED" }, value: { [yard]: "-0.41" } }),
    HEAD,
    { waiting: waitingFixture },
  );
  assert.equal(parked.pass, true, parked.measured);
  assert.match(
    parked.measured,
    /waiting: park_flume yard_rim_median_m -0.41 pass>=0.50 \(project-guide\/handoff\/ROADMAP.md:27/,
  );
  assert.match(
    buildReceipt(logs({ status: { [yard]: "OWED" }, value: { [yard]: "-0.90" } }), HEAD, {
      waiting: waitingFixture,
    }).measured,
    /misses: park_flume yard_rim_median_m -0.90/,
  );
  assert.equal(
    buildReceipt(logs({ status: { [yard]: "FAIL" }, value: { [yard]: "-0.41" } }), HEAD, {
      waiting: waitingFixture,
    }).pass,
    false,
  );
  assert.equal(
    buildReceipt(logs({ status: { "park_dam yard_rim_median_m": "OWED" } }), HEAD, {
      waiting: waitingFixture,
    }).pass,
    false,
  );
});

test("map standard: a point with no line on one map fails and is named", () => {
  const r = buildReceipt(logs({ drop: ["park_dam layout_sets"], extra: 1 }), HEAD);
  assert.equal(r.pass, false);
  assert.match(r.measured, /no check for point 4 on park_dam/);
});

test("map standard: a lost or added check moves the count off the pin and fails", () => {
  const more = buildReceipt(logs({ extra: 1 }), HEAD);
  assert.equal(more.pass, false);
  assert.match(more.measured, /off the pin/);
});

test("map standard: a plant that passed, or a missing PLANTED line, voids the receipt", () => {
  const r = buildReceipt(logs({ plantPass: "park_breath_test" }), HEAD);
  assert.equal(r.plant_caught, false);
  assert.equal(r.pass, false);
  assert.match(receiptRow(row, r, HEAD).measured, /^void, the planted fault was not shown caught/);
  const gone = logs();
  gone.park_variety_test = gone.park_variety_test
    .split("\n")
    .filter((l) => !l.startsWith("PLANTED"))
    .join("\n");
  assert.equal(buildReceipt(gone, HEAD).plant_caught, false);
});

test("map standard: a failed check, an unmapped measure and an empty run fail", () => {
  assert.equal(buildReceipt(logs({ failCheck: "park_rhythm_test" }), HEAD).pass, false);
  const odd = logs();
  odd.park_breath_test += "\nMAPCHECK park_dam brand_new_measure 1 pass>=1 PASS";
  assert.match(buildReceipt(odd, HEAD).measured, /unmapped measure park_dam brand_new_measure/);
  const empty = buildReceipt({}, HEAD);
  assert.equal(empty.pass, false);
  assert.match(empty.measured, /^no MAPCHECK lines/);
});

test("map standard: MAPCHECK parsing reads marker lines and skips report INFO", () => {
  const got = mapLines(
    "MAPCHECK park_dam marker_sight cage 0.9100 pass>=0.85 PASS (120 cells)\nMAPCHECK park_dam band_shares 0.1/0.2 report INFO\nMAPCHECK park_flume rhythm_switches 9.0 pass>=3 PASS",
  );
  assert.equal(got.length, 2);
  assert.deepEqual(
    [got[0].measure, got[0].value, got[0].line, got[0].status],
    ["marker_sight", "0.9100", "pass>=0.85", "PASS"],
  );
});

test("map standard: the producer refuses a dirty checkout and passes on a clean checkout", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "map-standard-git-"));
  try {
    const git = (...args) => spawnSync("git", args, { cwd: dir, encoding: "utf8" });
    git("init", "-q");
    git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "base");
    writeFileSync(path.join(dir, "tracked.txt"), "a");
    git("add", "tracked.txt");
    git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "-m", "file");
    writeFileSync(path.join(dir, "tracked.txt"), "b");
    let ran = false;
    assert.throws(
      () =>
        produce({
          cwd: dir,
          run: () => {
            ran = true;
            return logs();
          },
        }),
      /refusing: uncommitted changes/,
    );
    assert.equal(ran, false);
    git("checkout", "-q", "tracked.txt");
    const r = produce({ cwd: dir, run: () => logs() });
    assert.equal(r.head, git("rev-parse", "HEAD").stdout.trim());
    assert.equal(r.pass, true, r.measured);
    assert.equal(r.plant_caught, true);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("map standard: an injected unparked open half still fails and measured names what closes it", () => {
  assert.equal(OPEN_HALVES.length, 0);
  const sample = {
    point: 1,
    half: "1 picture (synthetic open half)",
    closes: "a blind read against a control",
  };
  const r = buildReceipt(logs(), HEAD, { halves: [sample] });
  assert.equal(r.pass, false);
  assert.match(r.measured, /open halves, no ruling parks them/);
  assert.ok(r.measured.includes(`${sample.half} (closes with ${sample.closes})`));
  const parked = buildReceipt(logs(), HEAD, { halves: [{ ...sample, parked: "a ruling" }] });
  assert.equal(parked.pass, true, parked.measured);
});

test("map standard: all four Wave 46B halves and point 5 tagged cover are closed with audit receipts", () => {
  assert.equal(PINNED_LINES, 42);
  assert.equal(TESTS.park_cover_tags_test, 3);
  assert.ok(POINTS[5].includes("hard_rows_shell_cast_share"));
  assert.equal(OPEN_HALVES.length, 0);
  assert.equal(WAITING.length, 0);
  assert.equal(VERIFIED_HALVES.length, 4);
  for (const label of ["1 picture", "5 picture", "8b silhouettes", "8c snags"]) {
    const entry = VERIFIED_HALVES.find((h) => h.half.startsWith(label));
    assert.ok(entry, `missing VERIFIED_HALVES entry for ${label}`);
    assert.match(entry.commit, /^[0-9a-f]{7,40}$/, label);
    assert.match(entry.cite, /map-audit\.md/, label);
    assert.ok(entry.check && entry.verdict, label);
  }
});

test("map standard: optional snagReceipt verifies 8c live when supplied and rejects stale, failed, or void receipts", () => {
  const good = { head: HEAD, pass: true, plant_caught: true, measured: "park_dam ride 0, seams 0" };
  const ok = buildReceipt(logs(), HEAD, { snagReceipt: good });
  assert.equal(ok.pass, true, ok.measured);
  assert.equal(ok.plant_caught, true);
  assert.match(ok.measured, /8c snag-sweep receipt verified/);

  const prefixOk = buildReceipt(logs(), HEAD, {
    snagReceipt: { ...good, head: HEAD.slice(0, 9) },
  });
  assert.equal(prefixOk.pass, true, prefixOk.measured);

  const stale = buildReceipt(logs(), HEAD, { snagReceipt: { ...good, head: OTHER_HEAD } });
  assert.equal(stale.pass, false);
  assert.match(stale.measured, /does not match/);

  const failed = buildReceipt(logs(), HEAD, {
    snagReceipt: { ...good, pass: false, measured: "park_dam: 1 static ride snag(s)" },
  });
  assert.equal(failed.pass, false);
  assert.match(failed.measured, /8c snag-sweep receipt failed/);

  const voidPlant = buildReceipt(logs(), HEAD, {
    snagReceipt: { ...good, plant_caught: false },
  });
  assert.equal(voidPlant.pass, false);
  assert.equal(voidPlant.plant_caught, false);
  assert.match(voidPlant.measured, /8c snag-sweep receipt plant was not shown caught/);

  const malformed = buildReceipt(logs(), HEAD, { snagReceipt: [] });
  assert.equal(malformed.pass, false);
  assert.match(malformed.measured, /not a JSON object/);

  const nullReceipt = buildReceipt(logs(), HEAD, { snagReceipt: null });
  assert.equal(nullReceipt.pass, false);
  assert.match(nullReceipt.measured, /not a JSON object/);

  for (const shortHead of ["3", HEAD.slice(0, 6)]) {
    const shortRes = buildReceipt(logs(), HEAD, { snagReceipt: { ...good, head: shortHead } });
    assert.equal(shortRes.pass, false, shortHead);
    assert.match(shortRes.measured, /names no valid commit head/);
  }

  const missingHead = buildReceipt(logs(), HEAD, {
    snagReceipt: { pass: true, plant_caught: true },
  });
  assert.equal(missingHead.pass, false);
  assert.match(missingHead.measured, /names no valid commit head/);

  const missingPlant = buildReceipt(logs(), HEAD, { snagReceipt: { head: HEAD, pass: true } });
  assert.equal(missingPlant.pass, false);
  assert.equal(missingPlant.plant_caught, false);

  const missingPass = buildReceipt(logs(), HEAD, {
    snagReceipt: { head: HEAD, plant_caught: true },
  });
  assert.equal(missingPass.pass, false);
  assert.match(missingPass.measured, /8c snag-sweep receipt failed/);

  const badCheckoutHead = buildReceipt(logs(), "bad", { snagReceipt: good });
  assert.equal(badCheckoutHead.pass, false);
  assert.match(badCheckoutHead.measured, /no valid checkout head to match/);
});

test("map standard: parseArgs accepts --out, --logs, and --snag-receipt in split or = form and rejects unknown flags", () => {
  assert.deepEqual(parseArgs(["--out", "/tmp/a.json", "--snag-receipt=/tmp/s.json"]), {
    out: "/tmp/a.json",
    logs: null,
    snagReceipt: "/tmp/s.json",
  });
  assert.deepEqual(parseArgs(["--logs=/tmp/logs", "--snag-receipt", "/tmp/s.json"]), {
    out: null,
    logs: "/tmp/logs",
    snagReceipt: "/tmp/s.json",
  });
  assert.throws(() => parseArgs(["--bogus", "1"]), /unknown argument: --bogus/);
  assert.throws(() => parseArgs(["--out"]), /--out requires a value/);
  assert.throws(() => parseArgs(["--snag-receipt"]), /--snag-receipt requires a value/);
  assert.throws(() => parseArgs(["--snag-receipt="]), /--snag-receipt requires a value/);
  assert.throws(() => parseArgs(["--out="]), /--out requires a value/);
  assert.throws(() => parseArgs(["--logs="]), /--logs requires a value/);
});
