import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import {
  checkPreset,
  covered,
  filterList,
  rawLiterals,
  resolveLiterals,
  uncoveredFiles,
} from "./export-include-check.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sketch = path.join(root, "sketches/core-loop");
const presetText = readFileSync(path.join(sketch, "export_presets.cfg"), "utf8");

test("rawLiterals finds raw data names and skips resource names", () => {
  const source =
    'a("res://assets/park/%s/graph.bin")\nb(dir + "/ground.bin")\nc("x.glb")\nd("runs.ndjson")';
  assert.deepEqual(
    rawLiterals(source).map((item) => item.text),
    ["res://assets/park/%s/graph.bin", "/ground.bin", "runs.ndjson"],
  );
});

test("resolveLiterals maps %s paths and tails, skips user writes, reports a missing res:// file", () => {
  const files = ["assets/park/a/graph.bin", "assets/park/a/ground.bin", "assets/x.glb"];
  const found = resolveLiterals(
    [
      { text: "res://assets/park/%s/graph.bin", res: "assets/park/%s/graph.bin" },
      { text: "/ground.bin", res: null },
      { text: "runs.ndjson", res: null },
      { text: "res://nope/%s.bin", res: "nope/%s.bin" },
    ],
    files,
  );
  assert.deepEqual(found.files, ["assets/park/a/graph.bin", "assets/park/a/ground.bin"]);
  assert.deepEqual(found.unresolved, ["res://nope/%s.bin"]);
});

test("a pattern covers a file by Godot glob and an exclude beats nothing here", () => {
  assert.equal(covered("assets/park/a/graph.bin", ["assets/park/*/graph.bin"]), true);
  assert.equal(covered("assets/park/a/graph.bin", ["assets/park/*/ground.bin"]), false);
  assert.deepEqual(filterList('"a/*.bin, res://b/*"'), ["a/*.bin", "b/*"]);
  assert.deepEqual(
    uncoveredFiles({ files: ["tests/x.bin"], include: [], exclude: ["tests/*"] }),
    [],
  );
});

for (const name of ["Linux x64", "Linux x64 proof", "macOS"]) {
  test(`every raw file the game opens is in the "${name}" include filter`, () => {
    const { problems, files } = checkPreset({ sketch, presetText, presetName: name });
    assert.ok(files.length >= 30, "the scan found " + files.length + " raw files");
    assert.deepEqual(problems, []);
  });
}

test("dropping the ground.bin pattern fails the check", () => {
  const broken = presetText.replaceAll("assets/park/*/ground.bin, ", "");
  assert.notEqual(broken, presetText);
  const { problems } = checkPreset({ sketch, presetText: broken, presetName: "Linux x64" });
  assert.ok(problems.length > 0);
  assert.ok(problems.every((line) => line.includes("/ground.bin ")));
});

test("dropping the surface.bin pattern fails the check for every park's surface", () => {
  const broken = presetText.replaceAll("assets/park/*/surface.bin, ", "");
  assert.notEqual(broken, presetText);
  const { problems } = checkPreset({ sketch, presetText: broken, presetName: "Linux x64" });
  assert.ok(problems.length >= 6);
  assert.ok(problems.every((line) => line.includes("/surface.bin ")));
});

test("an empty include filter fails for every park file", () => {
  const broken = presetText.replace(/^include_filter=.*$/gm, 'include_filter=""');
  const { problems } = checkPreset({ sketch, presetText: broken, presetName: "Linux x64" });
  assert.ok(problems.length >= 30);
});

test("a missing project folder fails the check and names the folder", () => {
  const missing = path.join(root, "artifacts/local/no-such-sketch");
  assert.deepEqual(checkPreset({ sketch: missing, presetText, presetName: "Linux x64" }), {
    problems: [`project folder ${missing} not found`],
    files: [],
  });
});
