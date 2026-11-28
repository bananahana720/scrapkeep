import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { walkAsync, walkSync } from "./walk.mjs";

function makeFixtureTree() {
  const dir = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-walk-"));
  mkdirSync(path.join(dir, "a/nested"), { recursive: true });
  mkdirSync(path.join(dir, ".godot/cache"), { recursive: true });
  mkdirSync(path.join(dir, "b"), { recursive: true });
  writeFileSync(path.join(dir, "top.md"), "# top\n");
  writeFileSync(path.join(dir, "a/one.gd"), "extends Node\n");
  writeFileSync(path.join(dir, "a/nested/two.gd"), "extends Node\n");
  writeFileSync(path.join(dir, ".godot/cache/ignored.gd"), "ignored\n");
  writeFileSync(path.join(dir, "b/three.txt"), "three\n");
  return dir;
}

test("walkSync and walkAsync return POSIX paths, support prune/filter/includeDirs/sort, and tolerate missing roots", async () => {
  const dir = makeFixtureTree();
  try {
    const prune = (entry) => entry.name === ".godot";
    const syncFiles = walkSync(dir, { prune, sort: true });
    const asyncFiles = await walkAsync(dir, { prune, sort: true });
    assert.deepEqual(
      syncFiles.map((e) => e.rel),
      ["a/nested/two.gd", "a/one.gd", "b/three.txt", "top.md"],
    );
    assert.deepEqual(
      asyncFiles.map((e) => e.rel),
      syncFiles.map((e) => e.rel),
    );
    assert.ok(syncFiles.every((e) => path.isAbsolute(e.full) && !e.rel.includes("\\")));

    const withDirs = walkSync(dir, { prune, includeDirs: true, sort: true });
    assert.deepEqual(
      withDirs.map((e) => `${e.dir ? "d" : "f"}:${e.rel}`),
      ["d:a", "d:a/nested", "f:a/nested/two.gd", "f:a/one.gd", "d:b", "f:b/three.txt", "f:top.md"],
    );

    const onlyGd = await walkAsync(dir, {
      prune,
      sort: true,
      filesOnly: true,
      filter: (e) => e.name.endsWith(".gd"),
    });
    assert.deepEqual(
      onlyGd.map((e) => e.rel),
      ["a/nested/two.gd", "a/one.gd"],
    );

    const missing = path.join(dir, "does-not-exist");
    assert.deepEqual(walkSync(missing), []);
    assert.deepEqual(await walkAsync(missing), []);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
