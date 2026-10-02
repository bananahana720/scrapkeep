import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  buildReceipt,
  countChecks,
  globToRegExp,
  hasVerdictLine,
  matchesGlob,
  namedRunMustWait,
  noMatchMessage,
  parseArgs,
  receiptFileName,
  selectTests,
  splitFlags,
  validateRun,
  waitForMachine,
  isSolo,
  isSoloScript,
} from "./sketch-smoke.mjs";

test("a first-line marker opts a file into the solo phase", () => {
  assert.equal(isSolo("# smoke: solo\nextends SceneTree\n"), true);
  assert.equal(isSolo("#smoke:solo\nextends SceneTree\n"), true);
  assert.equal(isSolo("# smoke: solo - wall-time cap\r\nextends SceneTree\n"), true);
});

test("an unmarked file stays in the parallel batch", () => {
  assert.equal(isSolo("extends SceneTree\n# smoke: parallel\n"), false);
  assert.equal(isSolo("# smoke: soloist\nextends SceneTree\n"), false);
  assert.equal(isSolo(""), false);
});

test("the marker is read only from the first lines", () => {
  const body = "extends SceneTree\n".repeat(5);
  assert.equal(isSolo(body + "# smoke: solo\n"), false);
  assert.equal(isSolo('extends SceneTree\nvar s := "# smoke: solo"\n'), false);
  assert.equal(isSolo("extends SceneTree\n# smoke: solo\n"), true);
});

test("the runner reads the res:// script from the sketch directory", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "smoke-marker-"));
  try {
    mkdirSync(path.join(dir, "tests"));
    writeFileSync(path.join(dir, "tests", "a_test.gd"), "# smoke: solo\nextends SceneTree\n");
    writeFileSync(path.join(dir, "tests", "b_test.gd"), "extends SceneTree\n");
    assert.equal(isSoloScript(dir, "res://tests/a_test.gd"), true);
    assert.equal(isSoloScript(dir, "res://tests/b_test.gd"), false);
    assert.equal(isSoloScript(dir, "res://tests/missing.gd"), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a glob matches a base name with or without .gd and * as the only wildcard", () => {
  assert.equal(matchesGlob("tuning_*", "tuning_basic_test.gd"), true);
  assert.equal(matchesGlob("tuning_*", "enemy_tuning_test.gd"), false);
  assert.equal(matchesGlob("boss_flow_test.gd", "boss_flow_test.gd"), true);
  assert.equal(matchesGlob("boss_flow_test", "boss_flow_test.gd"), true);
  assert.equal(matchesGlob("boss_flow_test", "boss_flow_test_2.gd"), false);
  assert.equal(matchesGlob("a.b", "axb.gd"), false);
  assert.equal(globToRegExp("*").test("anything"), true);
});

test("selectTests keeps scripts that match any glob", () => {
  const scripts = ["res://tests/tuning_a.gd", "res://tests/tuning_b.gd", "res://tests/enemy_director_test.gd", "res://tests/other.gd"];
  assert.deepEqual(selectTests(scripts, ["tuning_*", "enemy_director_test"]), scripts.slice(0, 3));
  assert.deepEqual(selectTests(scripts, ["nope_*"]), []);
});

test("flags split on spaces, and --flags wins over SMOKE_FLAGS", () => {
  assert.deepEqual(splitFlags("--scrap=armor  --loop=drop"), ["--scrap=armor", "--loop=drop"]);
  assert.deepEqual(splitFlags(""), []);
  assert.deepEqual(splitFlags(undefined), []);
  assert.deepEqual(parseArgs(["--flags", "--a=1"], { SMOKE_FLAGS: "--b=2" }).flags, ["--a=1"]);
  assert.deepEqual(parseArgs([], { SMOKE_FLAGS: "--b=2 --c" }).flags, ["--b=2", "--c"]);
});

test("parseArgs reads tests, receipt label and the strict switch", () => {
  const named = parseArgs(["--sketch", "core-loop", "--test", "a_*", "--test", "b"]);
  assert.deepEqual(named.tests, ["a_*", "b"]);
  assert.equal(named.named, true);
  assert.equal(named.receipt, "named");
  assert.equal(parseArgs(["--sketch", "x"]).receipt, "smoke");
  assert.equal(parseArgs(["--receipt", "gate"]).receipt, "gate");
  assert.equal(parseArgs(["--strict-verdict"]).strict, true);
  assert.equal(parseArgs([]).strict, false);
});

test("a named run needs exactly one known sketch and at least one match", () => {
  const available = ["core-loop", "other"];
  assert.match(validateRun(parseArgs(["--test", "x"]), available), /exactly one --sketch/);
  assert.match(validateRun(parseArgs(["--test", "x", "--sketch", "core-loop", "--sketch", "other"]), available), /exactly one --sketch/);
  assert.match(validateRun(parseArgs(["--sketch", "nope"]), available), /no sketch named nope/);
  assert.equal(validateRun(parseArgs(["--sketch", "core-loop", "--test", "x"]), available), null);
  assert.equal(validateRun(parseArgs([]), available), null);
  assert.match(noMatchMessage("core-loop", ["zzz_*"]), /no test in core-loop matching zzz_\*/);
});

test("verdict lines and check counts are detected tolerantly", () => {
  assert.equal(hasVerdictLine("a -> PASS\nboss_flow_test: PASS\n"), true);
  assert.equal(hasVerdictLine("boss_flow_test: FAIL (2 checks)\r\n"), true);
  assert.equal(hasVerdictLine("a -> PASS\nall good\n"), false);
  assert.equal(hasVerdictLine("  indented: PASS\n"), false);
  assert.deepEqual(countChecks("a -> PASS\nb -> PASS\nc -> FAIL\nx: PASS\n"), { passes: 2, fails: 1 });
  assert.deepEqual(countChecks("x: PASS\n"), { passes: 0, fails: 0 });
});

test("a named run waits only while a live pid holds the lock", async () => {
  assert.equal(namedRunMustWait(() => 0), false);
  assert.equal(namedRunMustWait(() => 4242), true);
  const holders = [4242, 4242, 0];
  const sleeps = [];
  const waited = await waitForMachine({
    pollMs: 1,
    holderCheck: () => holders.shift() ?? 0,
    sleep: async (ms) => sleeps.push(ms),
  });
  assert.equal(sleeps.length, 1);
  assert.equal(typeof waited, "number");
  assert.equal(await waitForMachine({ holderCheck: () => 0, sleep: async () => assert.fail("slept") }), 0);
});

test("the receipt carries every field and its totals", () => {
  const results = [
    { label: "s import", ok: true, exit: 0, ms: 5, solo: false, passes: 0, fails: 0, verdict_line: null, skips: [] },
    { label: "s res://tests/a.gd", ok: true, exit: 0, ms: 9, solo: false, passes: 3, fails: 0, verdict_line: true, skips: ["SKIP x"] },
    { label: "s res://tests/b.gd", ok: false, exit: 1, ms: 7, solo: true, passes: 1, fails: 1, verdict_line: false, skips: [] },
  ];
  const receipt = buildReceipt({
    label: "named",
    argv: ["--test", "a"],
    root: "/r",
    git: { head: "h", tree: "t".repeat(40), clean: false, dirty_paths: ["x"] },
    godot: { binary: "/g", version: "4.7.2" },
    sketches: ["sketches/s"],
    flags: ["--scrap=armor"],
    width: 2,
    lockWaitMs: 0,
    startedAt: "2026-10-01T00:00:00.000Z",
    wallMs: 21,
    stems: { "sketches/s": 4 },
    results,
  });
  assert.equal(receipt.schema, "scrapkeep-smoke-receipt/1");
  assert.deepEqual(receipt.totals, { runs: 3, failed: 1, skipped: 1, missing_verdict: 1 });
  assert.equal(receipt.ok, false);
  for (const key of ["label", "argv", "root", "head", "tree", "clean", "dirty_paths", "godot", "sketches", "flags", "width", "lock_wait_ms", "started_at", "wall_ms", "stems", "results", "totals", "ok"]) {
    assert.ok(key in receipt, key);
  }
  assert.deepEqual(Object.keys(receipt.results[1]), ["label", "ok", "exit", "ms", "solo", "passes", "fails", "verdict_line", "skips"]);
  assert.equal(receiptFileName("named", receipt.tree, receipt.started_at), "named-tttttttttttt-2026-10-01T00-00-00-000Z.json");
});

test("without git the receipt's git fields are null", () => {
  const receipt = buildReceipt({ label: "x", argv: [], root: "/r", git: null, godot: { binary: "/g", version: null }, sketches: [], flags: [], width: 1, lockWaitMs: 0, startedAt: "t", wallMs: 0, stems: {}, results: [] });
  assert.equal(receipt.head, null);
  assert.equal(receipt.tree, null);
  assert.equal(receipt.clean, null);
  assert.equal(receipt.ok, true);
  assert.equal(receiptFileName("x", null, "2026-10-01T00:00:00.000Z"), "x-nogit-2026-10-01T00-00-00-000Z.json");
});
