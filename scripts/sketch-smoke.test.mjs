import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { isSolo, isSoloScript } from "./sketch-smoke.mjs";

test("a first-line marker opts a file into the solo phase", () => {
  assert.equal(isSolo("# smoke: solo\nextends SceneTree\n"), true);
  assert.equal(isSolo("#smoke:solo\nextends SceneTree\n"), true);
  assert.equal(isSolo("# smoke: solo - wall-time cap\r\nextends SceneTree\n"), true);
});

test("an unmarked file stays in the parallel batch", () => {
  assert.equal(isSolo("extends SceneTree\n# smoke: parallel\n"), false);
  assert.equal(isSolo("# smoke: soloist\nextends SceneTree\n"), false);
  assert.equal(isSolo(""), false);
});

test("the marker is read only from the first lines", () => {
  const body = "extends SceneTree\n".repeat(5);
  assert.equal(isSolo(body + "# smoke: solo\n"), false);
  assert.equal(isSolo('extends SceneTree\nvar s := "# smoke: solo"\n'), false);
  assert.equal(isSolo("extends SceneTree\n# smoke: solo\n"), true);
});

test("the runner reads the res:// script from the sketch directory", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "smoke-marker-"));
  try {
    mkdirSync(path.join(dir, "tests"));
    writeFileSync(path.join(dir, "tests", "a_test.gd"), "# smoke: solo\nextends SceneTree\n");
    writeFileSync(path.join(dir, "tests", "b_test.gd"), "extends SceneTree\n");
    assert.equal(isSoloScript(dir, "res://tests/a_test.gd"), true);
    assert.equal(isSoloScript(dir, "res://tests/b_test.gd"), false);
    assert.equal(isSoloScript(dir, "res://tests/missing.gd"), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
