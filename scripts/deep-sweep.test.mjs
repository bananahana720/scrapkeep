import assert from "node:assert/strict";
import test from "node:test";
import { addedLines, parseFuncs, passThroughs, reachIns, report, stringKeys, sweep, wideSignatures } from "./deep-sweep.mjs";

const GD = `extends Node

func hit(target: Node, amount: float) -> void:
	return combat.hit(target, amount)

func hit_twice(target, amount):
	combat.hit(target, amount)
	combat.hit(target, amount)

func _private_forward(a):
	return other.go(a)

func reorder(a, b):
	return other.go(b, a)

func wide(a, b, c: bool, d: bool, e := false, f = 1):
	pass
`;

test("parseFuncs reads names, params and bodies", () => {
  const funcs = parseFuncs(GD);
  assert.deepEqual(funcs.map((f) => f.name), ["hit", "hit_twice", "_private_forward", "reorder", "wide"]);
  assert.deepEqual(funcs[0].params.map((p) => p.name), ["target", "amount"]);
  assert.equal(funcs[1].body.length, 2);
});

test("passThroughs flags only a public one-line forward with the same args in order", () => {
  const hits = passThroughs(parseFuncs(GD));
  assert.equal(hits.length, 1);
  assert.match(hits[0].message, /^hit\(\) only forwards to combat\.hit/);
});

test("wideSignatures flags six params or three bools", () => {
  const hits = wideSignatures(parseFuncs(GD));
  assert.equal(hits.length, 1);
  assert.match(hits[0].message, /wide\(\) takes 6 params \(3 bool\)/);
});

test("reachIns flags another object's underscore member, not self or comments", () => {
  const hits = reachIns([[1, "\tvar x = boss._phase"], [2, "\tself._phase = 1"], [3, "\t# boss._phase"], [4, '\tw.get("_state")'], [5, "\tvar y = _local"]]);
  assert.deepEqual(hits.map((h) => h.line), [1, 4]);
});

test("stringKeys collects snake_case literals", () => {
  assert.deepEqual([...stringKeys([[1, 'd["run_seed"] = d.get("stage_index", 0) + "plain"']])].sort(), ["run_seed", "stage_index"]);
});

test("addedLines maps hunks to new line numbers", () => {
  const diff = "+++ b/a.gd\n@@ -3,0 +4,2 @@\n+one\n+two\n+++ b/b.gd\n@@ -1 +1 @@\n-old\n+new\n";
  const files = addedLines(diff);
  assert.deepEqual(files.get("a.gd"), [[4, "one"], [5, "two"]]);
  assert.deepEqual(files.get("b.gd"), [[1, "new"]]);
});

test("sweep reports new wrappers, leaks and growth on added code only", () => {
  const file = "sketches/core-loop/src/x.gd";
  const src = { [file]: GD + '\nvar k = "run_seed"\n', "sketches/core-loop/src/y.gd": 'x["run_seed"]', "sketches/core-loop/src/z.gd": 'y["run_seed"]' };
  const diff = `+++ b/${file}\n@@ -0,0 +1,4 @@\n+extends Node\n+\n+func hit(target: Node, amount: float) -> void:\n+\treturn combat.hit(target, amount)\n@@ -0,0 +22,1 @@\n+var k = "run_seed"\n`;
  const findings = sweep({ base: "b", head: "h", read: (f) => src[f] ?? "", diff, listSrc: () => Object.keys(src), linesAt: () => 0 });
  assert.deepEqual(findings.map((f) => f.rule).sort(), ["D1", "D4"]);
  const text = report({ base: "aaaaaaaaaa", head: "bbbbbbbbbb", findings });
  assert.match(text, /## D1 Pass-through wrappers \(1\)/);
  assert.match(text, /"run_seed" is spelled in 3 src files/);
});
