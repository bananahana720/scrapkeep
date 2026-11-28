import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  addedLines,
  defaultBase,
  parseFuncs,
  passThroughs,
  reachIns,
  report,
  sourceFiles,
  stringKeys,
  sweep,
  wideSignatures,
} from "./deep-sweep.mjs";
import { git } from "./lib/git.mjs";

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
  assert.deepEqual(
    funcs.map((f) => f.name),
    ["hit", "hit_twice", "_private_forward", "reorder", "wide"],
  );
  assert.deepEqual(
    funcs[0].params.map((p) => p.name),
    ["target", "amount"],
  );
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
  const hits = reachIns([
    [1, "\tvar x = boss._phase"],
    [2, "\tself._phase = 1"],
    [3, "\t# boss._phase"],
    [4, '\tw.get("_state")'],
    [5, "\tvar y = _local"],
  ]);
  assert.deepEqual(
    hits.map((h) => h.line),
    [1, 4],
  );
});

test("stringKeys collects snake_case literals", () => {
  assert.deepEqual(
    [...stringKeys([[1, 'd["run_seed"] = d.get("stage_index", 0) + "plain"']])].sort(),
    ["run_seed", "stage_index"],
  );
});

test("addedLines maps hunks to new line numbers", () => {
  const diff = "+++ b/a.gd\n@@ -3,0 +4,2 @@\n+one\n+two\n+++ b/b.gd\n@@ -1 +1 @@\n-old\n+new\n";
  const files = addedLines(diff);
  assert.deepEqual(files.get("a.gd"), [
    [4, "one"],
    [5, "two"],
  ]);
  assert.deepEqual(files.get("b.gd"), [[1, "new"]]);
});

test("sweep reports new wrappers, leaks and growth on added code only", () => {
  const file = "sketches/core-loop/src/x.gd";
  const src = {
    [file]: GD + '\nvar k = "run_seed"\n',
    "sketches/core-loop/src/y.gd": 'x["run_seed"]',
    "sketches/core-loop/src/z.gd": 'y["run_seed"]',
  };
  const diff = `+++ b/${file}\n@@ -0,0 +1,4 @@\n+extends Node\n+\n+func hit(target: Node, amount: float) -> void:\n+\treturn combat.hit(target, amount)\n@@ -0,0 +22,1 @@\n+var k = "run_seed"\n`;
  const findings = sweep({
    base: "b",
    head: "h",
    read: (f) => src[f] ?? "",
    diff,
    listSrc: () => Object.keys(src),
    linesAt: () => 0,
  });
  assert.deepEqual(findings.map((f) => f.rule).sort(), ["D1", "D4"]);
  const text = report({ base: "aaaaaaaaaa", head: "bbbbbbbbbb", findings });
  assert.match(text, /## D1 Pass-through wrappers \(1\)/);
  assert.match(text, /"run_seed" is spelled in 3 src files/);
});

test("sweep skips string keys that the event schema owns", () => {
  const file = "sketches/core-loop/src/x.gd";
  const src = {
    [file]: 'var k = "enemy_killed"\n',
    "sketches/core-loop/src/y.gd": '"enemy_killed"',
    "sketches/core-loop/src/z.gd": '"enemy_killed"',
    "sketches/core-loop/src/core/event_kinds.gd": 'const K := ["enemy_killed"]',
  };
  const diff = `+++ b/${file}\n@@ -0,0 +1,1 @@\n+var k = "enemy_killed"\n`;
  const findings = sweep({
    base: "b",
    head: "h",
    read: (f) => src[f] ?? "",
    diff,
    listSrc: () => Object.keys(src),
    linesAt: () => 0,
  });
  assert.deepEqual(findings, []);
});

test("reachIns follows a chain of owners and a member of another object held on self", () => {
  const hits = reachIns([
    [1, "\tgame.flow.warden._age = 0.0"],
    [2, "\tself.director._home_at(site)"],
    [3, "\tself._age = 1.0"],
    [4, "\tlocks._wave.clear()"],
    [5, "\tsuper._ready()"],
  ]);
  assert.deepEqual(
    hits.map((h) => [h.line, h.message]),
    [
      [1, "reaches into game.flow.warden._age"],
      [2, "reaches into director._home_at"],
      [4, "reaches into locks._wave"],
    ],
  );
});

test("sweep reads a tool script for reach-ins only", () => {
  const tool = "sketches/core-loop/tools/trial.gd";
  const diff = `+++ b/${tool}\n@@ -0,0 +1,2 @@\n+func run(a, b, c, d, e, f, g):\n+\tdirector._place_pack()\n`;
  const findings = sweep({
    base: "b".repeat(40),
    head: "h".repeat(40),
    read: () => "",
    diff,
    listSrc: () => [],
    linesAt: () => 0,
  });
  assert.deepEqual(
    findings.map((f) => [f.rule, f.path, f.line]),
    [["D2", tool, 2]],
  );
});

test("reachIns follows a chain that starts at the file's own private field", () => {
  const hits = reachIns([
    [1, "\t_game.flow._set_state(2)"],
    [2, "\tself._game = game"],
    [3, "\tvar a = _local"],
    [4, "\tself._game.flow._set_state(2)"],
  ]);
  assert.deepEqual(
    hits.map((h) => [h.line, h.message]),
    [
      [1, "reaches into _game.flow._set_state"],
      [4, "reaches into _game.flow._set_state"],
    ],
  );
});

test("defaultBase returns the first parent for a merge commit", () => {
  const calls = [];
  const run = (...args) => {
    calls.push(args);
    if (args[0] === "rev-list") return "head111 parent1 parent2\n";
    throw new Error(`unexpected git call: ${args.join(" ")}`);
  };
  assert.equal(defaultBase("head111", run), "parent1");
  assert.deepEqual(calls, [["rev-list", "--parents", "-n", "1", "head111"]]);
});

test("defaultBase returns the merge base with origin/main for a branch commit", () => {
  const calls = [];
  const run = (...args) => {
    calls.push(args);
    if (args[0] === "rev-list") return "head222 parent1\n";
    if (args[0] === "merge-base") return "base999\n";
    throw new Error(`unexpected git call: ${args.join(" ")}`);
  };
  assert.equal(defaultBase("head222", run), "base999");
  assert.deepEqual(calls, [
    ["rev-list", "--parents", "-n", "1", "head222"],
    ["merge-base", "head222", "origin/main"],
  ]);
});

test("defaultBase returns HEAD's parent when the merge base is HEAD itself", () => {
  const run = (...args) => {
    if (args[0] === "rev-list") return "head333 parent1\n";
    if (args[0] === "merge-base") return "head333\n";
    throw new Error(`unexpected git call: ${args.join(" ")}`);
  };
  assert.equal(defaultBase("head333", run), "parent1");
  assert.equal(defaultBase("HEAD", run), "parent1");
});

test("defaultBase falls back to HEAD's parent when origin/main is absent and throws on a root commit", () => {
  const missingOrigin = (...args) => {
    if (args[0] === "rev-list") return "head444 parent1\n";
    throw new Error("fatal: Not a valid object name origin/main");
  };
  assert.equal(defaultBase("head444", missingOrigin), "parent1");

  const rootCommit = (...args) => {
    if (args[0] === "rev-list") return "root000\n";
    return "root000\n";
  };
  assert.throws(() => defaultBase("root000", rootCommit), /has no parent/);
});

test("sourceFiles lists a script whose name holds a newline, a leading space and a quote as itself, and fails on an empty or unread tree", () => {
  const cwd = mkdtempSync(path.join(os.tmpdir(), "deep-sweep-src-"));
  const run = (...args) =>
    git(
      [
        "-c",
        "user.name=t",
        "-c",
        "user.email=t@example.invalid",
        "-c",
        "commit.gpgsign=false",
        ...args,
      ],
      { cwd },
    );
  try {
    run("init", "-q");
    writeFileSync(path.join(cwd, "README"), "x\n");
    run("add", "README");
    run("commit", "-q", "-m", "no sources");
    const empty = run("rev-parse", "HEAD");
    const odd = 'sketches/core-loop/src/ odd "name"\nline.gd';
    for (const file of [
      odd,
      "sketches/core-loop/src/core/plain.gd",
      "sketches/core-loop/src/notes.md",
    ]) {
      mkdirSync(path.dirname(path.join(cwd, file)), { recursive: true });
      writeFileSync(path.join(cwd, file), "extends Node\n");
    }
    run("add", "sketches");
    run("commit", "-q", "-m", "sources");
    assert.deepEqual(
      sourceFiles("HEAD", { cwd }).sort(),
      [odd, "sketches/core-loop/src/core/plain.gd"].sort(),
    );
    assert.throws(
      () => sourceFiles(empty, { cwd }),
      /lists no \.gd file under sketches\/core-loop\/src\//,
    );
    assert.throws(() => sourceFiles("no-such-ref", { cwd }), /git ls-tree .* failed/);
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});
