import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { parseArgs } from "../sketch-fast.mjs";

const workflow = readFileSync(new URL("../../.github/workflows/ci.yml", import.meta.url), "utf8");

function jobBlock(name) {
  const start = workflow.indexOf(`\n  ${name}:\n`);
  assert.ok(start >= 0, `job ${name} exists`);
  const rest = workflow.slice(start + 1);
  const next = rest.slice(1).search(/\n {2}[a-z][a-z0-9-]*:\n/);
  return next < 0 ? rest : rest.slice(0, next + 1);
}

function validateGodotAffectedBudget(job, minBudgetS) {
  const errors = [];
  const timeoutMatch = job.match(/^\s*timeout-minutes:\s*(\d+)/m);
  const budgetMatch = job.match(/check-budget\.mjs\s+--label\s+godot-affected\s+--budget\s+(\d+)/);
  if (!timeoutMatch) errors.push("missing timeout-minutes on godot-affected");
  if (!budgetMatch) errors.push("missing check-budget.mjs --label godot-affected --budget");
  if (errors.length > 0) return errors;
  const timeoutS = Number(timeoutMatch[1]) * 60;
  const budgetS = Number(budgetMatch[1]);
  if (budgetS < minBudgetS) {
    errors.push(`godot-affected budget ${budgetS}s < sketch-fast default ${minBudgetS}s`);
  }
  if (timeoutS < budgetS + 180) {
    errors.push(
      `godot-affected timeout ${timeoutS}s < budget ${budgetS}s + 180s import/cache headroom`,
    );
  }
  return errors;
}

test("godot-affected skips stage promotion pull requests into main", () => {
  const job = jobBlock("godot-affected");
  assert.match(job, /github\.event\.pull_request\.base\.ref == 'main'/);
  assert.match(job, /startsWith\(github\.event\.pull_request\.head\.ref, 'stage\/'\)/);
  assert.match(
    job,
    /&& !\(github\.event_name == 'pull_request' && .*base\.ref == 'main' && .*startsWith/,
  );
});

test("godot-affected still runs on ordinary pull requests and pushes", () => {
  const job = jobBlock("godot-affected");
  assert.match(job, /needs\.changes\.outputs\.godot == 'true'/);
  assert.match(job, /github\.event_name == 'pull_request' \|\| github\.event_name == 'push'/);
});

test("godot-affected budget matches sketch-fast default and leaves 180s job timeout headroom", () => {
  const minBudgetS = parseArgs([]).budgetS;
  assert.equal(minBudgetS, 900);
  const job = jobBlock("godot-affected");
  assert.deepEqual(validateGodotAffectedBudget(job, minBudgetS), []);

  const past480 = job
    .replace(/timeout-minutes:\s*\d+/, "timeout-minutes: 10")
    .replace(/--label godot-affected --budget \d+/, "--label godot-affected --budget 480");
  const past480Errors = validateGodotAffectedBudget(past480, minBudgetS);
  assert.ok(past480Errors.some((msg) => /480s < sketch-fast default 900s/.test(msg)));
  assert.ok(past480Errors.some((msg) => /timeout 600s < budget 480s \+ 180s/.test(msg)));

  const past240 = job
    .replace(/timeout-minutes:\s*\d+/, "timeout-minutes: 10")
    .replace(/--label godot-affected --budget \d+/, "--label godot-affected --budget 240");
  const past240Errors = validateGodotAffectedBudget(past240, minBudgetS);
  assert.ok(past240Errors.some((msg) => /240s < sketch-fast default 900s/.test(msg)));

  const tightTimeout = job.replace(/timeout-minutes:\s*\d+/, "timeout-minutes: 15");
  const tightErrors = validateGodotAffectedBudget(tightTimeout, minBudgetS);
  assert.ok(tightErrors.some((msg) => /timeout 900s < budget 900s \+ 180s/.test(msg)));
});

test("ci-gate accepts a skipped godot-affected and the merge queue still runs godot-full", () => {
  const gate = workflow.slice(workflow.indexOf("Require all active jobs green"));
  assert.match(gate, /"godot-affected:\$GODOT_AFFECTED_RESULT"/);
  assert.match(gate, /\$res" != "success" && "\$res" != "skipped"/);
  assert.match(jobBlock("godot-full"), /github\.event_name == 'merge_group'/);
});
