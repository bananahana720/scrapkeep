import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

import {
  PINNED_ORDERS,
  buildReceipt as contactReceipt,
  produce as contactProduce,
} from "./contact-orders-receipt.mjs";
import {
  NAMES,
  RUNS,
  buildReceipt as feelReceipt,
  carriedRows,
  produce as feelProduce,
} from "./core-feel-receipt.mjs";
import { receiptRow } from "../world1-bands.mjs";
import { git as runGit } from "../lib/git.mjs";

const HEAD = "3adc2fd0e8563b13c87f921b2ae85763467fec03";

function repoWith(files) {
  const repo = mkdtempSync(path.join(os.tmpdir(), "feel-receipts-git-"));
  const git = (...args) =>
    runGit(["-c", "user.name=t", "-c", "user.email=t@t", ...args], { cwd: repo });
  git("init", "-q");
  for (const [file, text] of Object.entries(files)) {
    mkdirSync(path.dirname(path.join(repo, file)), { recursive: true });
    writeFileSync(path.join(repo, file), text);
  }
  git("add", ".");
  git("commit", "-q", "-m", "one");
  return { repo, head: git("rev-parse", "HEAD") };
}

const SETS = [
  ["heavy+heavy", 2],
  ["heavy+kill+pickup", 6],
  ["heavy+heavy+stomp", 6],
  ["heavy+heavy+kill+hit", 24],
  ["stomp+kill+soft+hazard", 24],
];
const same = (mode, set, ran, differ = 0, detail = "") =>
  `[same state ${mode}: ${set}] ${ran} orders ran, ${differ} differ from the first${detail} -> ${differ ? "FAIL" : "ok"}`;
const contactLog = ({ parted = null, orders = PINNED_ORDERS, drop = 0, known = "ok" } = {}) => {
  const rows = SETS.map(([set, n]) =>
    parted && parted.set === set
      ? same("block", set, n, 1, `; first differing order [2, 0, 1], fields: ["run.hp: 60 vs 65"]`)
      : same("block", set, n),
  ).slice(drop);
  const failed = rows.some((r) => r.endsWith("FAIL")) || known !== "ok";
  return [
    "[determinism: same order twice, state keys compared] 400 keys, 3 noisy -> ok",
    ...rows,
    `[orders ran] ${orders} orders of ${PINNED_ORDERS} expected -> ${orders === PINNED_ORDERS ? "ok" : "FAIL"}`,
    "[planted control fails the comparison] 3 of 8 unsorted orders differ -> ok",
    `[known dependence seen: pickup then hazard] differs in run.hp -> ${known}`,
    `SUMMARY ${JSON.stringify({ orders, pinned: PINNED_ORDERS, sets: 5, differ: parted ? 1 : 0 })}`,
    `contact_orders_all_test: ${failed || orders !== PINNED_ORDERS ? "FAIL (1)" : "PASS"}`,
  ].join("\n");
};
const plantRun = ({ fails = true } = {}) => ({
  ok: !fails,
  log: [
    same(
      "planted no sort",
      "heavy+heavy",
      2,
      fails ? 1 : 0,
      fails ? '; first differing order [1, 0], fields: ["ball.velocity"]' : "",
    ),
    `PLANT ${JSON.stringify({ switch: "CONTACT_PLANT=nosort", sets: 2, orders_differ: fails ? 3 : 0 })}`,
    `contact_orders_all_test: ${fails ? "FAIL (2)" : "PASS"}`,
  ].join("\n"),
});

test("contact orders: every order ends in one state and the plant failed, so the receipt passes and says what is not claimed", () => {
  const r = contactReceipt({ ok: true, log: contactLog() }, plantRun(), HEAD);
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.match(
    r.measured,
    /^all 62 arrival orders of 5 contact sets \(up to four same-tick contacts, each order a fresh game\) end in one state; what is faked: the physics server, for one tick, .*a hit lands its damage but not its knock; not claimed: a pickup with any damage in the same tick/,
  );
  assert.match(
    r.measured,
    /a design call waiting on Andrew; plant: with the contact sort bypassed \(CONTACT_PLANT=nosort\) 3 orders parted and the test failed$/,
  );
  assert.deepEqual(receiptRow({ id: "same-seed-same-run", plant: "x", producer: "x" }, r, HEAD), {
    measured: r.measured,
    pass: true,
  });
});

test("contact orders: an order dependence fails the receipt and names the set and the field", () => {
  const r = contactReceipt(
    { ok: false, log: contactLog({ parted: { set: "heavy+heavy+kill+hit" } }) },
    plantRun(),
    HEAD,
  );
  assert.equal(r.pass, false);
  assert.match(
    r.measured,
    /^order dependence: heavy\+heavy\+kill\+hit parts in 1 of 24 orders; first differing order \[2, 0, 1\], fields: \["run.hp: 60 vs 65"\]/,
  );
});

test("contact orders: too few orders, or a set check missing, is a miss", () => {
  assert.equal(
    contactReceipt({ ok: true, log: contactLog({ orders: 60 }) }, plantRun(), HEAD).pass,
    false,
  );
  const r = contactReceipt({ ok: true, log: contactLog({ drop: 1 }) }, plantRun(), HEAD);
  assert.equal(r.pass, false);
  assert.match(r.measured, /too few orders were tried to judge/);
  assert.match(
    contactReceipt({ ok: false, log: "crashed" }, plantRun(), HEAD).measured,
    /^no SUMMARY or same-state lines/,
  );
});

test("contact orders: a plant that did not fail voids a pass, and a lost known dependence fails it", () => {
  const r = contactReceipt({ ok: true, log: contactLog() }, plantRun({ fails: false }), HEAD);
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, false);
  assert.match(r.measured, /0 orders parted and the test still passed$/);
  assert.equal(
    contactReceipt({ ok: true, log: contactLog() }, { ok: false, log: "no plant" }, HEAD)
      .plant_caught,
    false,
  );
  assert.equal(
    contactReceipt({ ok: true, log: contactLog({ known: "FAIL" }) }, plantRun(), HEAD).pass,
    false,
  );
});

test("contact orders: the producer takes the head from git, runs the plant with its switch, and refuses a dirty checkout", () => {
  const { repo, head } = repoWith({ "a.txt": "one" });
  const calls = [];
  const run = (cwd, name, env = {}) => {
    calls.push([name, env]);
    return env.CONTACT_PLANT ? plantRun() : { ok: true, log: contactLog() };
  };
  const r = contactProduce({ cwd: repo, run });
  assert.equal(r.head, head);
  assert.equal(r.pass, true);
  assert.deepEqual(calls, [
    ["contact_orders_all_test", {}],
    ["contact_orders_all_test", { CONTACT_PLANT: "nosort" }],
  ]);
  writeFileSync(path.join(repo, "a.txt"), "two");
  assert.throws(() => contactProduce({ cwd: repo, run }), /refusing: uncommitted changes/);
  assert.equal(calls.length, 2, "a dirty checkout never runs the test");
});

const LEDGER = "test\tkind\tcause\towner\tadded\treview\tcheck\n";
const ledgerRow = (name, kind) =>
  `${name}\t${kind}\tfails under load\tlane\t2026-11-09\t2026-11-23\t${kind === "red" ? "x" : "-"}\n`;
const allRuns = (fail = []) =>
  NAMES.flatMap((name) =>
    Array.from({ length: RUNS }, (_, i) => ({
      test: name,
      run: i + 1,
      ok: !fail.includes(`${name}#${i + 1}`),
      exit: 0,
      seconds: 20,
      load: 2.1,
    })),
  );
const feelPlant = (fails = true) => ({
  ok: !fails,
  log: `[slowed ticks] 0.06 s ... slow [0, 0, 0] ticks -> ${fails ? "FAIL" : "PASS"}\nPLANT {"switch":"FEEL_PLANT=zero_stop","slowed":[0,0,0]}\nhit_stop_ticks_test: ${fails ? "FAIL (1)" : "PASS"}`,
});
const feel = (over = {}) =>
  feelReceipt({
    runs: allRuns(),
    carried: [],
    plant: feelPlant(),
    head: HEAD,
    threads: 18,
    maxLoad: 4.5,
    ...over,
  });

test("core feel: 18 of 18 alone, none of the six carried and the plant failed, so the receipt passes", () => {
  const r = feel();
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.match(
    r.measured,
    /^18 of 18 runs passed alone \(hit_stop_ticks_test, .*harpoon_canon_test; 3 runs each, 1-minute load at most 2.1 on 18 threads, quiet limit 4.5\); KNOWN-FAILING.tsv carries none of the six; plant: hit_stop_ticks_test with FEEL_PLANT=zero_stop failed \[slowed ticks\]$/,
  );
});

test("core feel: one red run, a carried flake row, or too few runs fails the receipt", () => {
  const red = feel({ runs: allRuns(["juice_budget_test#2"]) });
  assert.equal(red.pass, false);
  assert.match(red.measured, /^17 of 18 .*; failed: juice_budget_test run 2 \(exit 0\)/);
  const carried = feel({
    carried: carriedRows(
      LEDGER + ledgerRow("juice_budget_test", "flake") + ledgerRow("other_test", "flake"),
    ),
  });
  assert.equal(carried.pass, false);
  assert.match(
    carried.measured,
    /KNOWN-FAILING.tsv still carries juice_budget_test \(flake\), so the receipt fails; quiet solo passes do not clear a row, which comes off only after two full gates in a row/,
  );
  const short = feel({ runs: allRuns().slice(0, 17) });
  assert.equal(short.pass, false);
  assert.match(short.measured, /only 17 of 18 runs were made: too little data, a miss/);
});

test("core feel: a plant that passed voids the receipt", () => {
  const r = feel({ plant: feelPlant(false) });
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, false);
  assert.match(r.measured, /was not seen to fail$/);
});

test("core feel: the producer refuses a loaded machine before any run, and runs each test alone three times plus the plant", async () => {
  const { repo, head } = repoWith({
    "project-guide/handoff/KNOWN-FAILING.tsv": LEDGER + ledgerRow("hit_stop_ticks_test", "flake"),
  });
  const calls = [];
  const run = (cwd, name, env = {}) => {
    calls.push([name, env]);
    return env.FEEL_PLANT ? feelPlant() : { ok: true, exit: 0, seconds: 1, log: "" };
  };
  await assert.rejects(
    feelProduce({ cwd: repo, run, threads: 8, load: () => 2.5 }),
    /refusing: the 1-minute load 2.5 is above 2/,
  );
  assert.equal(calls.length, 0);
  const loads = [1, 1, 3, 1];
  let slept = 0;
  const r = await feelProduce({
    cwd: repo,
    run,
    threads: 8,
    load: () => (loads.length ? loads.shift() : 1),
    sleep: async () => {
      slept += 1;
    },
  });
  assert.equal(r.head, head);
  assert.equal(slept, 1, "a loaded moment between runs is waited out");
  assert.equal(calls.length, 19);
  assert.deepEqual(calls.at(-1), ["hit_stop_ticks_test", { FEEL_PLANT: "zero_stop" }]);
  assert.equal(r.pass, false, "the carried flake row fails it");
  assert.match(
    r.measured,
    /^18 of 18 .*; KNOWN-FAILING.tsv still carries hit_stop_ticks_test \(flake\)/,
  );
});
