import test from "node:test";
import assert from "node:assert/strict";
import { evaluateBudget, formatSummaryRow, parseBudgetArgs, runWithBudget } from "./check-budget.mjs";

test("parseBudgetArgs parses label, budget and command", () => {
  const parsed = parseBudgetArgs(["--label", "lint", "--budget", "5", "--", "npm", "run", "sketch:lint"]);
  assert.deepEqual(parsed, { label: "lint", budgetS: 5, command: ["npm", "run", "sketch:lint"] });
});

test("parseBudgetArgs rejects missing separator, label, budget or command", () => {
  assert.throws(() => parseBudgetArgs(["--label", "x", "--budget", "5"]), /usage:/);
  assert.throws(() => parseBudgetArgs(["--budget", "5", "--", "true"]), /--label/);
  assert.throws(() => parseBudgetArgs(["--label", "x", "--budget", "0", "--", "true"]), /positive/);
  assert.throws(() => parseBudgetArgs(["--label", "x", "--budget", "5", "--"]), /missing command/);
});

test("evaluateBudget passes within budget and fails over budget", () => {
  const pass = evaluateBudget({ label: "lint", budgetS: 5, elapsedMs: 1234, exitCode: 0, signal: null });
  assert.equal(pass.ok, true);
  assert.equal(pass.status, "PASS");
  assert.equal(pass.elapsedS, 1.23);

  const slow = evaluateBudget({ label: "lint", budgetS: 5, elapsedMs: 5500, exitCode: 0, signal: null });
  assert.equal(slow.ok, false);
  assert.equal(slow.overBudget, true);
  assert.equal(slow.status, "OVER_BUDGET");

  const failed = evaluateBudget({ label: "lint", budgetS: 5, elapsedMs: 200, exitCode: 1, signal: null });
  assert.equal(failed.ok, false);
  assert.equal(failed.status, "FAIL");
});

test("runWithBudget fails when child exceeds budget and preserves child exit code on failure", () => {
  const ticks = [1000, 7500];
  let i = 0;
  const slow = runWithBudget(["--label", "lint", "--budget", "5", "--", "echo", "hi"], {
    spawn: () => ({ status: 0, signal: null }),
    now: () => ticks[i++],
    summaryPath: "",
    log: () => {},
    errLog: () => {},
  });
  assert.equal(slow.exit, 1);
  assert.equal(slow.result.status, "OVER_BUDGET");

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
  assert.equal(fail.result.status, "FAIL");
  assert.match(formatSummaryRow(fail.result), /\| lint \| 0\.10s \| 5s \| FAIL \|/);
});
