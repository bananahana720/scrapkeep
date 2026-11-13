import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { COLUMNS, LEDGER, PRINCIPLES, checkLedger, checkPrinciples, ingest, parseLedger, readResults, report } from "./ui-audit.mjs";

const all = { test: () => true, capture: () => true, lint: () => true };
const none = { test: () => false, capture: () => false, lint: () => false };
const good = { id: "P1", name: "n", rule: "r", source: "s", standing: "established", checks: [{ kind: "test", ref: "a_test.gd" }], gap: "" };
const row = (over) => ({ id: "UF-1", principle: "P1", class: "small-text", where: "w", finding: "f", evidence: "e", state: "open", guard: "", added: "2026-11-13", ...over });

test("the repo's principles and ledger pass", () => {
  const principles = JSON.parse(readFileSync(PRINCIPLES, "utf8")).principles;
  assert.deepEqual(checkPrinciples(principles), []);
  assert.deepEqual(checkLedger(parseLedger(readFileSync(LEDGER, "utf8")), principles), []);
});

test("a principle fails on a missing check file, a bad standing, a reused id and no check with no gap", () => {
  assert.deepEqual(checkPrinciples([good], all), []);
  assert.match(checkPrinciples([good], none)[0], /does not exist/);
  assert.match(checkPrinciples([{ ...good, standing: "likely" }], all)[0], /standing/);
  assert.match(checkPrinciples([good, good], all)[0], /used twice/);
  assert.match(checkPrinciples([{ ...good, checks: [{ kind: "capture", ref: "x.gd" }] }], all)[0], /no automatic check and no gap/);
  assert.deepEqual(checkPrinciples([{ ...good, checks: [], gap: "needs a PC capture" }], all), []);
});

test("the lesson rule: a class found twice with no guard fails, and one guard clears it", () => {
  assert.deepEqual(checkLedger([row({})], [good], all), []);
  const twice = [row({}), row({ id: "UF-2", state: "fixed" })];
  assert.match(checkLedger(twice, [good], all)[0], /lesson owed: "small-text" has been found 2 times \(UF-1, UF-2\)/);
  assert.deepEqual(checkLedger([twice[0], { ...twice[1], guard: "a_test.gd" }], [good], all), []);
  assert.match(checkLedger([row({ guard: "gone_test.gd" })], [good], none)[0], /guard "gone_test.gd" does not exist/);
});

test("names that only look like a check do not pass, and a guard's ledger ids must exist", () => {
  const principles = JSON.parse(readFileSync(PRINCIPLES, "utf8")).principles;
  const bad = (check) => checkPrinciples([{ ...good, checks: [check] }]);
  assert.match(bad({ kind: "lint", ref: "constructor" })[0], /does not exist/);
  assert.match(bad({ kind: "test", ref: "support" })[0], /does not exist/);
  assert.match(bad({ kind: "test", ref: "QUARANTINE.tsv" })[0], /does not exist/);
  assert.deepEqual(bad({ kind: "test", ref: "ui_tokens_test.gd" }), []);
  const reads = { ...all, read: () => "waits on UF-1 and UF-77" };
  assert.deepEqual(checkLedger([row({ guard: "a_test.gd" })], principles, reads), ["a_test.gd names UF-77, which is not a ledger row"]);
});

test("a ledger row fails on an unknown principle, state or a reused id", () => {
  assert.match(checkLedger([row({ principle: "P9" })], [good], all)[0], /not in the list/);
  assert.match(checkLedger([row({ state: "done" })], [good], all)[0], /state/);
  assert.match(checkLedger([row({}), row({ class: "other" })], [good], all)[0], /used twice/);
  assert.throws(() => parseLedger("id\tprinciple\n"), /header/);
  assert.throws(() => parseLedger(`${COLUMNS.join("\t")}\nUF-1\tP1\n`), /cells/);
});

test("ingest turns ui_capture audit lines into candidates by principle", () => {
  const out = ingest([["1280x720-title.audit.txt", "small Button Quit 30x30\nunnamed Button @Button@4\noff-edge Label Wide x 0 to 1300 of 1280\nui_capture: note\n"]]);
  assert.deepEqual(out.map((c) => [c.principle, c.class, c.where]), [["P7", "small-target", "1280x720-title"], ["P6", "unnamed-control", "1280x720-title"], ["P4", "off-edge", "1280x720-title"]]);
});

test("results are read from the smoke receipt by test name, and a red test marks its principle", () => {
  const results = readResults({ results: [{ label: "core-loop res://tests/a_test.gd", ok: false }, { label: "core-loop res://tests/b_test.gd", ok: true }, { label: "core-loop res://tests/c_test.gd", ok: false, quarantined: true }, { label: "import" }] });
  assert.deepEqual([...results], [["a_test.gd", "fail"], ["b_test.gd", "pass"], ["c_test.gd", "quarantined red"]]);
  const lines = report([{ ...good, gap: "g" }, { ...good, id: "P2", checks: [{ kind: "test", ref: "c_test.gd" }] }], [row({})], results);
  assert.deepEqual([lines[0].held, lines[0].red, lines[0].open], ["partly", ["a_test.gd"], ["UF-1"]]);
  assert.deepEqual([lines[1].held, lines[1].red, lines[1].quarantined], ["held", [], ["c_test.gd"]]);
});
