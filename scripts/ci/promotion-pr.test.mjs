import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const workflow = readFileSync(new URL("../../.github/workflows/ci.yml", import.meta.url), "utf8");

function jobBlock(name) {
  const start = workflow.indexOf(`\n  ${name}:\n`);
  assert.ok(start >= 0, `job ${name} exists`);
  const rest = workflow.slice(start + 1);
  const next = rest.slice(1).search(/\n {2}[a-z][a-z0-9-]*:\n/);
  return next < 0 ? rest : rest.slice(0, next + 1);
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

test("ci-gate accepts a skipped godot-affected and the merge queue still runs godot-full", () => {
  const gate = workflow.slice(workflow.indexOf("Require all active jobs green"));
  assert.match(gate, /"godot-affected:\$GODOT_AFFECTED_RESULT"/);
  assert.match(gate, /\$res" != "success" && "\$res" != "skipped"/);
  assert.match(jobBlock("godot-full"), /github\.event_name == 'merge_group'/);
});
