import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  MISSING_VERDICT,
  binary,
  buildReceipt,
  countChecks,
  emitReceipt,
  gateFlagsError,
  globToRegExp,
  hasVerdictLine,
  judge,
  matchesGlob,
  namedRunMustWait,
  noMatchMessage,
  parseArgs,
  parseQuarantine,
  quarantinedNames,
  quarantineVerdict,
  runPasses,
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
  assert.deepEqual(splitFlags("--scrap=armor  --music=ace"), ["--scrap=armor", "--music=ace"]);
  assert.deepEqual(splitFlags(""), []);
  assert.deepEqual(splitFlags(undefined), []);
  assert.deepEqual(parseArgs(["--flags", "--scrap=armor"], { SMOKE_FLAGS: "--music=ace" }).flags, ["--scrap=armor"]);
  assert.deepEqual(parseArgs([], { SMOKE_FLAGS: "--music=ace --c" }).flags, ["--music=ace", "--c"]);
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
  assert.deepEqual(receipt.totals, { runs: 3, failed: 1, skipped: 1, missing_verdict: 1, quarantined_red: [], quarantine_stale: [] });
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

const result = (label, ok, extra = {}) => ({ label, ok, exit: ok ? 0 : 1, ms: 1, solo: false, passes: 0, fails: 0, verdict_line: true, skips: [], ...extra });
const testLabel = (name) => `sketches/core-loop res://tests/${name}.gd`;

test("the quarantine file parses into entries and names", () => {
  const text = "test\towner\treason\tadded\tdeadline\na_test\tO1\twhy\t2026-10-01\twave 3\r\n\nb_test\tB0\tbecause\t2026-10-01\twave 3\n";
  assert.deepEqual(parseQuarantine(text)[0], { test: "a_test", owner: "O1", reason: "why", added: "2026-10-01", deadline: "wave 3" });
  assert.deepEqual([...quarantinedNames(text)], ["a_test", "b_test"]);
  assert.deepEqual(parseQuarantine(""), []);
});

test("a red quarantined test does not fail the run, a green one is stale, any other failure fails", () => {
  const red = [result("sketches/core-loop import", true), result(testLabel("a_test"), false, { quarantined: true }), result(testLabel("c_test"), true)];
  assert.equal(runPasses(red), true);
  assert.deepEqual(quarantineVerdict(red).quarantined_red, ["a_test"]);
  assert.deepEqual(quarantineVerdict(red).quarantine_stale, []);
  const green = [result(testLabel("a_test"), true, { quarantined: true })];
  assert.equal(runPasses(green), true);
  assert.deepEqual(quarantineVerdict(green).quarantine_stale, ["a_test"]);
  assert.equal(runPasses([...red, result(testLabel("d_test"), false)]), false);
});

test("the receipt lists quarantine outcomes and never counts them as failed", () => {
  const receipt = buildReceipt({
    label: "named", argv: [], root: "/r", git: null, godot: { binary: "/g", version: null }, sketches: [], flags: [], width: 1, lockWaitMs: 0, startedAt: "t", wallMs: 0, stems: {},
    results: [result(testLabel("a_test"), false, { quarantined: true }), result(testLabel("b_test"), true, { quarantined: true }), result(testLabel("c_test"), true)],
  });
  assert.equal(receipt.totals.failed, 0);
  assert.deepEqual(receipt.totals.quarantined_red, ["a_test"]);
  assert.deepEqual(receipt.totals.quarantine_stale, ["b_test"]);
  assert.equal(receipt.results[0].quarantined, true);
  assert.equal("quarantined" in receipt.results[2], false);
  assert.equal(receipt.ok, true);
});

test("a gate run refuses launch flags from --flags or the environment", () => {
  assert.match(gateFlagsError(parseArgs(["--receipt", "gate", "--flags", "--scrap=armor"])), /refuses launch flags/);
  assert.match(gateFlagsError(parseArgs(["--receipt", "gate"], { SMOKE_FLAGS: "--music=ace" })), /SMOKE_FLAGS/);
  assert.equal(gateFlagsError(parseArgs(["--receipt", "gate"], {})), null);
  assert.equal(gateFlagsError(parseArgs(["--flags", "--scrap=armor"])), null);
});

test("a receipt that cannot be written is exit 3 and one clear line", () => {
  const lines = [];
  const code = emitReceipt({ label: "x" }, () => { throw new Error("ENOSPC: no space left"); }, (line) => lines.push(line));
  assert.equal(code, 3);
  assert.equal(lines.length, 1);
  assert.match(lines[0], /could not write the receipt under .*receipts: ENOSPC/);
  const ok = [];
  assert.equal(emitReceipt({ label: "x" }, () => "/p/x.json", (line) => ok.push(line)), null);
  assert.deepEqual(ok, ["receipt /p/x.json"]);
});

test("every export the runner had before the quarantine unit still exists", async () => {
  const module = await import("./sketch-smoke.mjs");
  for (const name of ["binary", "sketchDirectories", "testScripts", "isSolo", "isSoloScript", "jobCount", "skipLines", "hasVerdictLine", "countChecks", "globToRegExp", "matchesGlob", "selectTests", "splitFlags", "parseArgs", "validateRun", "noMatchMessage", "acquireMachine", "namedRunMustWait", "waitForMachine", "receiptFileName", "buildReceipt"]) {
    assert.ok(name in module, name);
  }
});

test("a test that exits 0 with no verdict line fails and says why", () => {
  const ended = judge({ test: true, status: 0, output: "[a] x -> PASS\n[b] y -> PASS\n" });
  assert.equal(ended.ok, false);
  assert.equal(ended.missing, true);
  assert.equal(ended.reason, MISSING_VERDICT);
  assert.equal(MISSING_VERDICT, "no verdict line: the test ended early");
  const done = judge({ test: true, status: 0, output: "[a] x -> PASS\nsuite_test: PASS (1 checks)\n" });
  assert.equal(done.ok, true);
  assert.equal(done.missing, false);
  const skipped = judge({ test: true, status: 0, output: "[ace] stems missing -> SKIP\n" });
  assert.equal(skipped.ok, true);
  assert.equal(skipped.missing, false);
  assert.equal(skipped.skips.length, 1);
  assert.equal(judge({ test: false, status: 0, output: "booted\n" }).ok, true);
  assert.equal(judge({ test: true, status: 1, output: "suite_test: FAIL (1 of 2 checks)\n" }).ok, false);
  assert.equal(done.reason, null);
  assert.equal(skipped.reason, null);
});

test("a nonzero exit and a kill give their own reason, not the missing-verdict one", () => {
  const crashed = judge({ test: true, status: 1, output: "[a] x -> PASS\n" });
  assert.equal(crashed.ok, false);
  assert.equal(crashed.reason, "the test exited with code 1");
  assert.notEqual(crashed.reason, MISSING_VERDICT);
  const killed = judge({ test: true, status: null, output: "[a] x -> PASS\n" });
  assert.equal(killed.ok, false);
  assert.equal(killed.reason, "the test was killed at the time limit or by a signal");
  const failed = judge({ test: true, status: 0, output: "suite_test: FAIL (1 of 2 checks)\n" });
  assert.equal(failed.reason, "the test printed a FAIL verdict");
});

test("a skip line exempts a test only when no check ran", () => {
  const mixed = judge({ test: true, status: 0, output: "[a] x -> PASS\n[b] stems missing -> SKIP\n" });
  assert.equal(mixed.ok, false);
  assert.equal(mixed.missing, true);
  assert.equal(mixed.reason, MISSING_VERDICT);
  const withVerdict = judge({ test: true, status: 0, output: "[a] x -> PASS\n[b] stems missing -> SKIP\nsuite_test: PASS (1 checks)\n" });
  assert.equal(withVerdict.ok, true);
});

test("a FAIL verdict fails the test whatever the exit code and wherever the line sits", () => {
  const early = judge({ test: true, status: 0, output: "suite_test: FAIL (1 of 2 checks)\ntrailing line\n" });
  assert.equal(early.ok, false);
  assert.equal(early.missing, false);
  assert.equal(early.reason, "the test printed a FAIL verdict");
  const both = judge({ test: true, status: 0, output: "suite_test: PASS (2 checks)\nsuite_test: FAIL (1 of 2 checks)\n" });
  assert.equal(both.ok, false);
});

test("a skipped test is not counted as missing a verdict in the receipt", () => {
  const rows = [
    { label: "s res://tests/a.gd", ok: true, exit: 0, ms: 1, passes: 0, fails: 0, verdict_line: false, skips: ["SKIP stems"] },
    { label: "s res://tests/b.gd", ok: false, exit: 0, ms: 1, passes: 2, fails: 0, verdict_line: false, skips: [] },
  ];
  const receipt = buildReceipt({ label: "x", argv: [], root: "/r", git: null, godot: { binary: "/g", version: null }, sketches: [], flags: [], width: 1, lockWaitMs: 0, startedAt: "t", wallMs: 0, stems: {}, results: rows });
  assert.equal(receipt.totals.missing_verdict, 1);
  assert.equal(receipt.totals.skipped, 1);
});

test("the receipt counts a skip line with checks and no verdict as missing, as judge does", () => {
  const rows = [
    { label: "s res://tests/a.gd", ok: true, exit: 0, ms: 1, passes: 0, fails: 0, verdict_line: false, skips: ["SKIP stems"] },
    { label: "s res://tests/c.gd", ok: false, exit: 0, ms: 1, passes: 1, fails: 0, verdict_line: false, skips: ["SKIP stems"] },
  ];
  const receipt = buildReceipt({ label: "x", argv: [], root: "/r", git: null, godot: { binary: "/g", version: null }, sketches: [], flags: [], width: 1, lockWaitMs: 0, startedAt: "t", wallMs: 0, stems: {}, results: rows });
  assert.equal(receipt.totals.missing_verdict, 1);
  assert.equal(receipt.totals.skipped, 2);
});

test("an error line under a PASS verdict fails with its own reason", () => {
  const errored = judge({ test: true, status: 0, output: "SCRIPT ERROR: bad call\nsuite_test: PASS (2 checks)\n" });
  assert.equal(errored.ok, false);
  assert.equal(errored.reason, "the test printed an error line");
});

test("a script error inside an awaited part of a test cannot pass", { skip: !existsSync(binary) }, () => {
  const project = mkdtempSync(path.join(os.tmpdir(), "verdict-fixture-"));
  try {
    writeFileSync(path.join(project, "project.godot"), 'config_version=5\n[application]\nconfig/name="fixture"\n');
    writeFileSync(
      path.join(project, "hazard.gd"),
      [
        "extends SceneTree",
        "func _initialize() -> void:",
        "\t_run.call_deferred()",
        "func _part() -> void:",
        '\tprint("[one] first -> PASS")',
        "\tawait process_frame",
        "\tvar empty: Dictionary = {}",
        '\tvar broken = empty["absent"].call()',
        '\tprint("[two] second -> PASS")',
        "func _run() -> void:",
        "\tawait _part()",
        "\tquit(0)",
        "",
      ].join("\n"),
    );
    const run = spawnSync(binary, ["--headless", "--path", project, "--script", "hazard.gd"], {
      encoding: "utf8",
      timeout: 60_000,
      env: { ...process.env, XDG_DATA_HOME: path.join(project, "data") },
    });
    const output = (run.stdout || "") + (run.stderr || "");
    assert.equal(run.status, 0);
    assert.match(output, /^SCRIPT ERROR/m);
    assert.match(output, /\[one\] first -> PASS/);
    assert.doesNotMatch(output, /\[two\]/);
    assert.equal(hasVerdictLine(output), false);
    const judged = judge({ test: true, status: run.status, output });
    assert.equal(judged.ok, false);
    assert.equal(judged.missing, true);
    const withoutErrorLines = output.split("\n").filter((line) => !/^SCRIPT ERROR/.test(line)).join("\n");
    const quiet = judge({ test: true, status: 0, output: withoutErrorLines });
    assert.equal(quiet.ok, false);
    assert.equal(quiet.missing, true);
  } finally {
    rmSync(project, { recursive: true, force: true });
  }
});
