// The ball-lab sketch validates against its own copy of the protocol v1
// fixtures, because Godot reads only inside its project. The copy must stay
// byte-identical to tools/jev-player/protocol/fixtures/, the canonical set.
import test from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const canonical = path.join(root, "tools/jev-player/protocol/fixtures");
const copy = path.join(root, "sketches/ball-lab/src/jev/fixtures");

function readTree(directory, prefix = "") {
  const files = new Map();
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const relative = path.posix.join(prefix, entry.name);
    if (entry.isDirectory()) {
      for (const [name, bytes] of readTree(path.join(directory, entry.name), relative)) {
        files.set(name, bytes);
      }
    } else {
      files.set(relative, readFileSync(path.join(directory, entry.name)));
    }
  }
  return files;
}

export function treeDifferences(expected, actual) {
  const differences = [];
  for (const [name, bytes] of expected) {
    if (!actual.has(name)) differences.push(`missing ${name}`);
    else if (!bytes.equals(actual.get(name))) differences.push(`differs ${name}`);
  }
  for (const name of actual.keys()) {
    if (!expected.has(name)) differences.push(`extra ${name}`);
  }
  return differences.sort();
}

test("the sketch's fixture copy matches the canonical fixtures byte for byte", () => {
  const expected = readTree(canonical);
  assert.ok(expected.has("INDEX.json"), "canonical fixtures hold INDEX.json");
  assert.deepEqual(treeDifferences(expected, readTree(copy)), []);
});

// jev_io.gd ports decide.mjs's precondition gate by hand, so both files pin the
// gate's version and PROTOCOL.md states it. A gate change bumps all three.
test("jev_io.gd and PROTOCOL.md pin decide.mjs's GATE_VERSION", () => {
  const constant = (file, pattern) => {
    const found = readFileSync(path.join(root, file), "utf8").match(pattern);
    assert.ok(found, `${file} states GATE_VERSION`);
    return Number(found[1]);
  };
  const node = constant(
    "tools/jev-player/decide.mjs",
    /^export const GATE_VERSION = (\d+);$/m,
  );
  const godot = constant(
    "sketches/ball-lab/src/jev/jev_io.gd",
    /^const GATE_VERSION := (\d+)$/m,
  );
  const prose = constant(
    "tools/jev-player/protocol/PROTOCOL.md",
    /`GATE_VERSION` is (\d+)/,
  );
  assert.equal(godot, node, "jev_io.gd GATE_VERSION");
  assert.equal(prose, node, "PROTOCOL.md GATE_VERSION");
});

test("a missing, extra or changed file is a difference", () => {
  const bytes = (text) => Buffer.from(text, "utf8");
  const expected = new Map([
    ["INDEX.json", bytes("{}\n")],
    ["valid/a.json", bytes("{\"n\":1}\n")],
    ["valid/b.json", bytes("{}\n")],
  ]);
  const actual = new Map([
    ["INDEX.json", bytes("{}\n")],
    ["valid/a.json", bytes("{\"n\":1}\r\n")],
    ["valid/c.json", bytes("{}\n")],
  ]);
  assert.deepEqual(treeDifferences(expected, actual), [
    "differs valid/a.json",
    "extra valid/c.json",
    "missing valid/b.json",
  ]);
});
