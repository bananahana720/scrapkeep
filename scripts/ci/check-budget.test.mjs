import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  evaluateBudget,
  formatSummaryRow,
  parseBudgetArgs,
  runWithBudget,
} from "./check-budget.mjs";

test("parseBudgetArgs parses label, budget and command", () => {
  const parsed = parseBudgetArgs([
    "--label",
    "lint",
    "--budget",
    "5",
    "--",
    "npm",
    "run",
    "sketch:lint",
  ]);
  assert.deepEqual(parsed, { label: "lint", budgetS: 5, command: ["npm", "run", "sketch:lint"] });
});

test("parseBudgetArgs rejects missing separator, empty/missing values or command", () => {
  assert.throws(() => parseBudgetArgs(["--label", "x", "--budget", "5"]), /usage:/);
  assert.throws(() => parseBudgetArgs(["--budget", "5", "--", "true"]), /--label/);
  assert.throws(() => parseBudgetArgs(["--label", "", "--budget", "5", "--", "true"]), /--label/);
  assert.throws(() => parseBudgetArgs(["--label", "x", "--budget", "0", "--", "true"]), /positive/);
  assert.throws(() => parseBudgetArgs(["--label", "x", "--budget", "5", "--"]), /missing command/);
});

test("evaluateBudget handles pass, over-budget millisecond boundary, signal and failure", () => {
  const pass = evaluateBudget({
    label: "lint",
    budgetS: 5,
    elapsedMs: 1234,
    exitCode: 0,
    signal: null,
  });
  assert.equal(pass.ok, true);
  assert.equal(pass.status, "PASS");
  assert.equal(pass.elapsedDisplay, "1.23");

  const boundary = evaluateBudget({
    label: "lint",
    budgetS: 5,
    elapsedMs: 5001,
    exitCode: 0,
    signal: null,
  });
  assert.equal(boundary.ok, false);
  assert.equal(boundary.overBudget, true);
  assert.equal(boundary.elapsedDisplay, "5.001");

  const killed = evaluateBudget({
    label: "lint",
    budgetS: 5,
    elapsedMs: 200,
    exitCode: null,
    signal: "SIGTERM",
  });
  assert.equal(killed.ok, false);
  assert.equal(killed.status, "FAIL");
  assert.equal(killed.signal, "SIGTERM");
});

test("runWithBudget handles over-budget, child exit code, spawn error and summary output", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "budget-test-"));
  const summary = path.join(tmp, "summary.md");
  try {
    const ticks = [1000, 7500];
    let i = 0;
    const slow = runWithBudget(["--label", "lint", "--budget", "5", "--", "echo", "hi"], {
      spawn: () => ({ status: 0, signal: null }),
      now: () => ticks[i++],
      summaryPath: summary,
      log: () => {},
      errLog: () => {},
    });
    assert.equal(slow.exit, 1);
    assert.equal(slow.result.status, "OVER_BUDGET");
    assert.match(readFileSync(summary, "utf8"), /\| lint \| 6\.50s \| 5s \| OVER_BUDGET \|/);

    const failTicks = [1000, 1100];
    let j = 0;
    const fail = runWithBudget(["--label", "lint", "--budget", "5", "--", "false"], {
      spawn: () => ({ status: 3, signal: null }),
      now: () => failTicks[j++],
      summaryPath: "",
      log: () => {},
      errLog: () => {},
    });
    assert.equal(fail.exit, 3);
    assert.match(formatSummaryRow(fail.result), /\| lint \| 0\.10s \| 5s \| FAIL \|/);

    const quiet = [];
    runWithBudget(["--label", "lint", "--budget", "5", "--", "false"], {
      spawn: () => ({ status: 3, signal: null }),
      now: (() => {
        const at = [0, 100];
        return () => at.shift();
      })(),
      summaryPath: "",
      log: () => {},
      errLog: (line) => quiet.push(line),
    });
    assert.deepEqual(quiet, [], "a red run inside its budget says nothing of the budget");

    const err = runWithBudget(["--label", "lint", "--budget", "5", "--", "missing-bin"], {
      spawn: () => ({ status: null, signal: null, error: new Error("ENOENT") }),
      now: () => 0,
      summaryPath: "",
      log: () => {},
      errLog: () => {},
    });
    assert.equal(err.exit, 2);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test("a red child that also ran past its budget is reported as both, and keeps its own exit code", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "budget-both-"));
  const summary = path.join(tmp, "summary.md");
  try {
    for (const [child, exit] of [
      [{ status: 1, signal: null }, 1],
      [{ status: 3, signal: null }, 3],
      [{ status: null, signal: "SIGKILL" }, 1],
    ]) {
      const said = [];
      const warned = [];
      const ticks = [0, 950_000];
      const ran = runWithBudget(
        ["--label", "godot-affected", "--budget", "900", "--", "node", "scripts/sketch-fast.mjs"],
        {
          spawn: () => child,
          now: () => ticks.shift(),
          summaryPath: summary,
          log: (line) => said.push(line),
          errLog: (line) => warned.push(line),
        },
      );
      assert.equal(ran.exit, exit, JSON.stringify(child));
      assert.deepEqual(
        [ran.result.status, ran.result.overBudget, ran.result.ok],
        ["FAIL+OVER_BUDGET", true, false],
      );
      assert.deepEqual(said, ["budget[godot-affected]: 950.00s / 900s (FAIL+OVER_BUDGET)"]);
      assert.deepEqual(warned, ["budget[godot-affected]: exceeded budget (950.00s > 900s)"]);
    }
    assert.match(
      readFileSync(summary, "utf8"),
      /^\| godot-affected \| 950\.00s \| 900s \| FAIL\+OVER_BUDGET \|$/m,
    );
    const green = evaluateBudget({
      label: "x",
      budgetS: 900,
      elapsedMs: 950_000,
      exitCode: 0,
      signal: null,
    });
    assert.equal(green.status, "OVER_BUDGET", "a green child over its budget is over budget only");
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
