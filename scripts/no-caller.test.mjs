import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { findMentions } from "./no-caller.mjs";

const cli = path.join(path.dirname(fileURLToPath(import.meta.url)), "no-caller.mjs");

function scratchRepo() {
  const dir = mkdtempSync(path.join(os.tmpdir(), "no-caller-"));
  const files = {
    "sketches/core-loop/tools/called.gd": "class_name CalledTool\nextends Node\n",
    "sketches/core-loop/tools/called.gd.uid": "uid://called\n",
    "sketches/core-loop/tools/runner.gd": "var t := CalledTool.new()\n",
    "sketches/core-loop/tools/dead.gd": "extends SceneTree\n",
    "sketches/core-loop/tools/dead.gd.uid": "uid://dead\n",
    "sketches/core-loop/tools/pair_a.gd": 'const B := preload("res://tools/pair_b.gd")\n',
    "sketches/core-loop/tools/pair_b.gd": "class_name PairB\nvar a := 'pair_a.gd'\n",
    "docs/notes.md": "Run `godot --script res://tools/called.gd` to see it.\n",
    "sketches/core-loop/tools/form.py": "WIDTH = 2\n",
    "sketches/core-loop/tools/gate.py": "import form as F\nreform = F.WIDTH\n",
    "sketches/core-loop/tools/by_uid.gd": "extends Node\n",
    "sketches/core-loop/tools/by_uid.gd.uid": "uid://b7byuid42\n",
    "sketches/core-loop/scenes/rig.tscn":
      '[ext_resource type="Script" uid="uid://b7byuid42" id="1"]\n',
  };
  for (const [rel, text] of Object.entries(files)) {
    mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    writeFileSync(path.join(dir, rel), text);
  }
  spawnSync("git", ["init", "-q"], { cwd: dir });
  spawnSync("git", ["add", "."], { cwd: dir });
  return dir;
}

const run = (dir, ...files) =>
  spawnSync(process.execPath, [cli, ...files], { cwd: dir, encoding: "utf8" });

test("a called file lists every mention by name, res:// path and class_name", () => {
  const dir = scratchRepo();
  try {
    const hits = findMentions(["sketches/core-loop/tools/called.gd"], dir).get(
      "sketches/core-loop/tools/called.gd",
    );
    assert.deepEqual(hits, [
      "docs/notes.md:1: Run `godot --script res://tools/called.gd` to see it.",
      "sketches/core-loop/tools/runner.gd:1: var t := CalledTool.new()",
    ]);
    const r = run(dir, "sketches/core-loop/tools/called.gd");
    assert.equal(r.status, 1);
    assert.match(r.stdout, /called\.gd: 2 mentions/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a dead file and two files that only call each other exit 0 together", () => {
  const dir = scratchRepo();
  try {
    const r = run(
      dir,
      "sketches/core-loop/tools/dead.gd",
      "sketches/core-loop/tools/pair_a.gd",
      "sketches/core-loop/tools/pair_b.gd",
    );
    assert.equal(r.status, 0, r.stdout);
    assert.match(r.stdout, /dead\.gd: 0 mentions/);
    const alone = run(dir, "sketches/core-loop/tools/pair_a.gd");
    assert.equal(alone.status, 1);
    assert.match(alone.stdout, /pair_b\.gd:2: var a/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a Python module is mentioned by its import name as a whole word", () => {
  const dir = scratchRepo();
  try {
    const hits = findMentions(["sketches/core-loop/tools/form.py"], dir).get(
      "sketches/core-loop/tools/form.py",
    );
    assert.deepEqual(hits, ["sketches/core-loop/tools/gate.py:1: import form as F"]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a path given from a subfolder resolves against the repository root", () => {
  const dir = scratchRepo();
  try {
    const r = run(path.join(dir, "sketches/core-loop"), "tools/dead.gd");
    assert.equal(r.status, 0, r.stdout);
    assert.match(r.stdout, /^sketches\/core-loop\/tools\/dead\.gd: 0 mentions/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a .gd file is mentioned by the uid in its .uid file", () => {
  const dir = scratchRepo();
  try {
    const hits = findMentions(["sketches/core-loop/tools/by_uid.gd"], dir).get(
      "sketches/core-loop/tools/by_uid.gd",
    );
    assert.deepEqual(hits, [
      'sketches/core-loop/scenes/rig.tscn:1: [ext_resource type="Script" uid="uid://b7byuid42" id="1"]',
    ]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a missing, wrong-prefix, untracked or directory path exits 2, names the path and searches nothing", () => {
  const dir = scratchRepo();
  try {
    writeFileSync(path.join(dir, "sketches/core-loop/tools/loose.gd"), "extends Node\n");
    const cases = {
      "sketches/core-loop/tools/missing.gd": /does not exist/,
      "tools/called.gd": /does not exist/,
      "sketches/core-loop/tools": /is a directory/,
      "sketches/core-loop/tools/loose.gd": /is not tracked by git/,
      "../outside.gd": /lies outside the repository/,
    };
    for (const [given, reason] of Object.entries(cases)) {
      const r = run(dir, given, "sketches/core-loop/tools/dead.gd");
      assert.equal(r.status, 2, given);
      assert.equal(r.stdout, "", given);
      assert.ok(r.stderr.startsWith(`${given}: `), r.stderr);
      assert.match(r.stderr, reason, given);
      assert.match(
        r.stderr,
        /pass a path to a tracked file, relative to where you run the command/,
      );
    }
    assert.throws(
      () => findMentions(["tools/called.gd"], dir),
      /tools\/called\.gd: does not exist/,
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a search that cannot run exits 2 and prints no result", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "no-caller-bare-"));
  try {
    writeFileSync(path.join(dir, "dead.gd"), "extends Node\n");
    const r = spawnSync(process.execPath, [cli, "dead.gd"], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, GIT_CEILING_DIRECTORIES: path.dirname(dir) },
    });
    assert.equal(r.status, 2);
    assert.equal(r.stdout, "");
    assert.match(r.stderr, /the search could not run, so nothing is known about callers/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a tracked file whose name starts with two dots is inside the repository", () => {
  const dir = scratchRepo();
  try {
    writeFileSync(path.join(dir, "..dots.gd"), "extends Node\n");
    spawnSync("git", ["add", "..dots.gd"], { cwd: dir });
    const r = run(dir, "..dots.gd");
    assert.equal(r.status, 0, r.stderr);
    assert.equal(r.stdout, "..dots.gd: 0 mentions\n");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
