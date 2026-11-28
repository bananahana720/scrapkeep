import assert from "node:assert/strict";
import test from "node:test";

import { evaluateBatchOutput, judge, linuxLeakLines, linuxOnlyLeak } from "./godot-test-runner.mjs";

const TEST = "res://tests/x_test.gd";
const CLEAN = "[a] one -> PASS\nx_test: PASS (1 checks)\n";
const RID_LINE =
  "ERROR: 2 RID allocations of type 'N13RendererDummy15MaterialStorage11DummyShaderE' were leaked at exit.\n";
const IN_USE_LINE = "ERROR: 1 resources still in use at exit (run with --verbose for details).\n";

const captured = {
  clean: CLEAN,
  "the dummy renderer's leak line": CLEAN + RID_LINE,
  "the resources line": CLEAN + IN_USE_LINE,
  "both lines": CLEAN + RID_LINE + IN_USE_LINE + "   at: clear (core/io/resource.cpp:822)\n",
};

test("judge keeps the macOS verdict and flags only the resources line as a test the Linux CI fails", () => {
  const expected = {
    clean: { darwin: [true, false], linux: [true, false] },
    "the dummy renderer's leak line": { darwin: [true, false], linux: [false, false] },
    "the resources line": { darwin: [true, true], linux: [false, false] },
    "both lines": { darwin: [true, true], linux: [false, false] },
  };
  for (const [name, output] of Object.entries(captured)) {
    for (const platform of ["darwin", "linux"]) {
      const verdict = judge({ test: TEST, status: 0, output, platform });
      assert.deepEqual(
        [verdict.ok, verdict.linuxLeak],
        expected[name][platform],
        `${name} on ${platform}`,
      );
      assert.equal(linuxOnlyLeak(output, platform), expected[name][platform][1]);
    }
  }
  const linuxVerdict = judge({
    test: TEST,
    status: 0,
    output: captured["the resources line"],
    platform: "linux",
  });
  assert.equal(linuxVerdict.reason, "the test printed an error line");
});

test("a warm batch whose exit lines hold the resources line is flagged on macOS only", () => {
  const tests = ["tests/a_test.gd", "tests/b_test.gd"];
  const body = [
    "BATCH START tests/a_test.gd",
    "a_test: PASS (1 checks)",
    "BATCH END tests/a_test.gd exit=0 ms=10",
    "BATCH START tests/b_test.gd",
    "b_test: PASS (1 checks)",
    "BATCH END tests/b_test.gd exit=0 ms=10",
    "BATCH DONE 2 tests",
    "",
  ].join("\n");
  const leaked = evaluateBatchOutput(body + RID_LINE + IN_USE_LINE, tests, { platform: "darwin" });
  assert.deepEqual([leaked.tainted, leaked.linuxLeak], [false, true]);
  const quirk = evaluateBatchOutput(body + RID_LINE, tests, { platform: "darwin" });
  assert.deepEqual([quirk.tainted, quirk.linuxLeak], [false, false]);
  const onLinux = evaluateBatchOutput(body + IN_USE_LINE, tests, { platform: "linux" });
  assert.deepEqual([onLinux.tainted, onLinux.linuxLeak], [true, false]);
});

test("linuxLeakLines gives one line per leaking test or batch and one count line, and nothing when none leaked", () => {
  assert.deepEqual(linuxLeakLines([]), []);
  const lines = linuxLeakLines([["tests/x_test.gd"], ["tests/a_test.gd", "tests/b_test.gd"]]);
  assert.equal(lines.length, 3);
  assert.match(lines[0], /^WARN linux leak: tests\/x_test\.gd printed .*Linux CI fails the test/);
  assert.match(lines[1], /^WARN linux leak: a warm batch of tests\/a_test\.gd, tests\/b_test\.gd /);
  assert.equal(
    lines[2],
    "linux leaks: 1 test and 1 batch printed the exit leak line the Linux CI fails on (some clean tests print it on macOS only)",
  );
});

test("the leak check refuses input it cannot read instead of reporting no leak", () => {
  for (const bad of [undefined, null, 7, Buffer.from(IN_USE_LINE)])
    assert.throws(() => linuxOnlyLeak(bad, "darwin"), TypeError, String(bad));
  for (const bad of [undefined, null, "tests/x_test.gd"])
    assert.throws(() => linuxLeakLines(bad), TypeError, String(bad));
});
