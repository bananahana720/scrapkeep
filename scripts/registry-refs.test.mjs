import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { brokenRefs, codeRef, main } from "./registry-refs.mjs";

const cli = path.join(path.dirname(fileURLToPath(import.meta.url)), "registry-refs.mjs");

const SOURCES = {
  "src/combat/crew.gd":
    'extends Node\n\nstatic func _parts() -> Array:\n\treturn []\n\n@warning_ignore("unused") static func _bare() -> void:\n\tpass\n\nfunc dress(x) -> void:\n\tpass\n',
  "tools/blender/crew.py": "import bpy\n\ndef build(scene):\n    return scene\n",
  "tools/tripo/README.md": "how\n",
};

function scratch(fragments, sources = SOURCES) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "registry-refs-"));
  for (const [rel, text] of Object.entries(sources)) {
    mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    writeFileSync(path.join(dir, rel), text);
  }
  mkdirSync(path.join(dir, "assets/registry.d"), { recursive: true });
  for (const [name, doc] of Object.entries(fragments))
    writeFileSync(
      path.join(dir, "assets/registry.d", name),
      typeof doc === "string" ? doc : JSON.stringify(doc),
    );
  return dir;
}

const row = (id, loader, provenance = { recipe: "tools/blender/crew.py" }) => ({
  id,
  path: `res://assets/models/${id}.glb`,
  ships: true,
  loader,
  provenance,
});

const quiet = () => {
  const out = [];
  const err = [];
  return { out, err, io: { log: (l) => out.push(l), error: (l) => err.push(l) } };
};

test("codeRef reads a leading path, a res:// path and a path:function, and leaves free text", () => {
  assert.deepEqual(codeRef("src/a.gd:_parts (the cast)"), {
    token: "src/a.gd:_parts",
    file: "src/a.gd",
    name: "_parts",
  });
  assert.deepEqual(codeRef("res://src/a.gd"), {
    token: "res://src/a.gd",
    file: "src/a.gd",
    name: null,
  });
  assert.deepEqual(codeRef("contraptions.gd _skin_views"), {
    token: "contraptions.gd",
    file: "contraptions.gd",
    name: null,
  });
  assert.deepEqual(codeRef("src/a.gd, src/b.gd"), {
    token: "src/a.gd",
    file: "src/a.gd",
    name: null,
  });
  for (const free of [
    "none (route proof; foot origin)",
    "park_recipes",
    "W47-GRAPPLE-CODE rig",
    "",
    undefined,
    3,
  ])
    assert.equal(codeRef(free), null, String(free));
});

test("a registry whose loaders and generators all name code that exists passes", () => {
  const dir = scratch({
    "a.json": {
      assets: [
        row("a", "src/combat/crew.gd:_parts"),
        row("b", "src/combat/crew.gd:_bare (annotated)"),
        row("c", "res://src/combat/crew.gd:dress", { recipe: "tools/tripo/README.md" }),
        row("d", "none (route proof)", { recipe: "tools/blender/crew.py:build" }),
        { ...row("e", "src/combat/crew.gd"), recipe: "tools/blender/crew.py" },
        row("f", "src/combat/crew.gd", { helper: "tools/blender/crew.py build()", note: "x" }),
      ],
    },
  });
  try {
    const { counts, findings } = brokenRefs(dir);
    assert.deepEqual(findings, []);
    assert.deepEqual(counts, { rows: 6, loaders: 5, generators: 7 });
    const { out, io } = quiet();
    assert.equal(main(["--project", dir], io), 0);
    assert.match(out.at(-1), /^registry refs: PASS, 6 rows, 5 path loaders, 7 path generators$/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("each wrong loader or generator is a finding and the command exits 1", () => {
  const dir = scratch({
    "a.json": {
      assets: [
        row("gone", "src/combat/gone.gd:_parts"),
        row("typo", "scr/combat/crew.gd (a folder typed wrong)"),
        row("bare", "crew.gd _parts"),
        row("nofunc", "src/combat/crew.gd:_missing"),
        row("line", "src/combat/crew.gd:440"),
        row("folder", "src/combat"),
        row("escape", "../outside.gd"),
        row("mdfunc", "src/combat/crew.gd", { recipe: "tools/tripo/README.md:how" }),
        row("pydef", "src/combat/crew.gd", { recipe: "tools/blender/crew.py:shape" }),
        row("gen", "src/combat/crew.gd", { recipe: "tools/blender/old.py" }),
        row("helper", "src/combat/crew.gd", { helper: "tools/blender/polish.py (bevel)" }),
        { ...row("top", "src/combat/crew.gd"), recipe: "tools/blender/old.py" },
      ],
    },
  });
  try {
    const { findings } = brokenRefs(dir);
    assert.deepEqual(findings, [
      "a.json gone: loader src/combat/gone.gd:_parts names a file that does not exist",
      "a.json typo: loader scr/combat/crew.gd names a file that does not exist",
      "a.json bare: loader crew.gd names a file that does not exist",
      "a.json nofunc: loader src/combat/crew.gd:_missing names _missing, which the file does not define",
      'a.json line: loader src/combat/crew.gd:440 names ":440", which is not a function name',
      "a.json folder: loader src/combat names a folder, not a file",
      "a.json escape: loader ../outside.gd lies outside the project",
      "a.json mdfunc: provenance.recipe tools/tripo/README.md:how names a function in a .md file",
      "a.json pydef: provenance.recipe tools/blender/crew.py:shape names shape, which the file does not define",
      "a.json gen: provenance.recipe tools/blender/old.py names a file that does not exist",
      "a.json helper: provenance.helper tools/blender/polish.py names a file that does not exist",
      "a.json top: recipe tools/blender/old.py names a file that does not exist",
    ]);
    const { out, io } = quiet();
    assert.equal(main(["--project", dir], io), 1);
    assert.match(out.at(-1), /^registry refs: FAIL \(12\)/);
    const r = spawnSync(process.execPath, [cli, "--project", dir], { encoding: "utf8" });
    assert.equal(r.status, 1, r.stderr);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a registry that cannot be read or holds nothing to check fails with exit 2", () => {
  const cases = {
    "no folder": [null, /ENOENT/],
    "no fragment": [{}, /holds no \.json file/],
    "no row": [{ "a.json": { assets: [] } }, /holds no asset row/],
    "not a fragment": [
      { "a.json": { rows: [] } },
      /a\.json: expected an object with an assets array/,
    ],
    "bad json": [{ "a.json": "{" }, /JSON/],
    "row not an object": [{ "a.json": { assets: [3] } }, /an asset row is not an object/],
    "no path loader": [
      { "a.json": { assets: [row("a", "none (route proof)")] } },
      /no row in assets\/registry\.d names a loader by path/,
    ],
    "no path generator": [
      { "a.json": { assets: [row("a", "src/combat/crew.gd", { recipe: "authored" })] } },
      /no row in assets\/registry\.d names a generator by path/,
    ],
  };
  for (const [label, [fragments, reason]] of Object.entries(cases)) {
    const dir = scratch(fragments ?? {});
    try {
      if (fragments === null) rmSync(path.join(dir, "assets/registry.d"), { recursive: true });
      assert.throws(() => brokenRefs(dir), reason, label);
      const { out, err, io } = quiet();
      assert.equal(main(["--project", dir], io), 2, label);
      assert.deepEqual(out, [], label);
      assert.match(err[0], /the registry could not be read, so nothing is checked/, label);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }
});

test("an unknown argument exits 2 and checks nothing", () => {
  const { out, err, io } = quiet();
  assert.equal(main(["--projct", "x"], io), 2);
  assert.equal(main(["--project"], io), 2);
  assert.deepEqual(out, []);
  assert.match(err[0], /^usage: node scripts\/registry-refs\.mjs/);
});

test("every row of the game's registry names a loader and a generator that exist", () => {
  const { out, err, io } = quiet();
  const code = main([], io);
  assert.deepEqual(err, []);
  assert.equal(code, 0, out.join("\n"));
  assert.match(out.at(-1), /^registry refs: PASS, [1-9]\d* rows, [1-9]\d* path loaders/);
});
