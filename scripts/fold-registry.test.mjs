import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const script = fileURLToPath(new URL("../sketches/core-loop/tools/fold_registry.py", import.meta.url));
const row = (id) => ({ id, path: `res://assets/models/${id}.glb`, class: "chunk", ships: true });

function fixture(t) {
  const root = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-fold-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  mkdirSync(path.join(root, "assets/models"), { recursive: true });
  mkdirSync(path.join(root, "assets/registry.d"));
  const registry = path.join(root, "assets/registry.json");
  writeFileSync(registry, JSON.stringify({ assets: [row("base")], note: "preserved" }, null, 1) + "\n");
  const fragment = (name, assets) => writeFileSync(path.join(root, "assets/registry.d", name), JSON.stringify({ assets }));
  const model = (id) => writeFileSync(path.join(root, "assets/models", `${id}.glb`), "fixture");
  const run = () => spawnSync("python3", [script, "--root", root], { encoding: "utf8" });
  return { root, registry, fragment, model, run };
}

test("folds all fragments in path order, preserves metadata, and is byte-idempotent", (t) => {
  const f = fixture(t);
  f.fragment("z.json", [row("a")]);
  f.fragment("a.json", [row("z")]);
  f.model("a");
  f.model("z");
  assert.equal(f.run().status, 0);
  const first = readFileSync(f.registry, "utf8");
  assert.deepEqual(JSON.parse(first).assets.map((r) => r.id), ["a", "base", "z"]);
  assert.equal(JSON.parse(first).note, "preserved");
  assert.equal(f.run().status, 0);
  assert.equal(readFileSync(f.registry, "utf8"), first);
  console.log("fold idempotence: PASS (two runs, no diff)");
});

test("rejects duplicate IDs across fragments and against the base without changing output", (t) => {
  const f = fixture(t);
  f.model("new");
  f.model("other");
  f.fragment("a.json", [row("new")]);
  f.fragment("b.json", [{ ...row("other"), id: "new" }]);
  const before = readFileSync(f.registry, "utf8");
  const duplicate = f.run();
  assert.equal(duplicate.status, 1);
  assert.match(duplicate.stderr, /duplicate id: new/);
  assert.equal(readFileSync(f.registry, "utf8"), before);
  console.log(duplicate.stderr.trim());
  rmSync(path.join(f.root, "assets/registry.d/b.json"));
  f.fragment("a.json", [row("base")]);
  assert.match(f.run().stderr, /duplicate id: base/);
});

test("path is the legacy ID and duplicate paths also fail with distinct explicit IDs", (t) => {
  const f = fixture(t);
  const legacy = { ...row("new") };
  delete legacy.id;
  f.model("new");
  f.fragment("a.json", [legacy]);
  assert.equal(f.run().status, 0);
  f.fragment("b.json", [legacy]);
  assert.match(f.run().stderr, /duplicate id: res:\/\/assets\/models\/new.glb/);
  f.fragment("b.json", [{ ...legacy, id: "different" }]);
  assert.match(f.run().stderr, /duplicate path:/);
});

test("rejects missing GLBs, invalid documents, and paths outside assets before writing", (t) => {
  const f = fixture(t);
  const before = readFileSync(f.registry, "utf8");
  f.fragment("a.json", [row("missing")]);
  assert.match(f.run().stderr, /GLB does not exist:/);
  assert.equal(readFileSync(f.registry, "utf8"), before);
  f.fragment("a.json", [{ ...row("escape"), path: "res://assets/../../escape.glb" }]);
  assert.match(f.run().stderr, /escapes assets/);
  writeFileSync(path.join(f.root, "assets/registry.d/a.json"), "{}");
  assert.match(f.run().stderr, /expected an object with an assets array/);
  assert.equal(readFileSync(f.registry, "utf8"), before);
});

test("updated and removed fragments replace prior generated rows", (t) => {
  const f = fixture(t);
  f.model("new");
  f.fragment("a.json", [row("new")]);
  assert.equal(f.run().status, 0);
  f.fragment("a.json", [{ ...row("new"), ships: false }]);
  assert.equal(f.run().status, 0);
  assert.equal(JSON.parse(readFileSync(f.registry)).assets.find((r) => r.id === "new").ships, false);
  rmSync(path.join(f.root, "assets/registry.d/a.json"));
  assert.equal(f.run().status, 0);
  assert.deepEqual(JSON.parse(readFileSync(f.registry)).assets, [row("base")]);
});
