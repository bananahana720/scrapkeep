import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
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

test("walkSync and walkAsync sort by code unit (B < _ < a) and follow symlinked directories only when followSymlinks is set", async () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-walk-order-"));
  const target = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-walk-target-"));
  try {
    writeFileSync(path.join(dir, "a"), "a\n");
    writeFileSync(path.join(dir, "B"), "B\n");
    writeFileSync(path.join(dir, "_"), "_\n");
    writeFileSync(path.join(target, "inner.log"), "ok\n");
    symlinkSync(target, path.join(dir, "log"));

    const noFollowSync = walkSync(dir, { sort: true });
    const noFollowAsync = await walkAsync(dir, { sort: true });
    assert.deepEqual(
      noFollowSync.map((e) => e.rel),
      ["B", "_", "a", "log"],
    );
    assert.deepEqual(
      noFollowAsync.map((e) => e.rel),
      ["B", "_", "a", "log"],
    );

    const followSync = walkSync(dir, { sort: true, followSymlinks: true });
    const followAsync = await walkAsync(dir, { sort: true, followSymlinks: true });
    assert.deepEqual(
      followSync.map((e) => e.rel),
      ["B", "_", "a", "log/inner.log"],
    );
    assert.deepEqual(
      followAsync.map((e) => e.rel),
      ["B", "_", "a", "log/inner.log"],
    );
    assert.ok(followSync.every((e) => !e.dir));

    symlinkSync(dir, path.join(target, "loop"));
    assert.deepEqual(
      walkSync(dir, { sort: true, followSymlinks: true }).map((e) => e.rel),
      ["B", "_", "a", "log/inner.log"],
    );
    assert.deepEqual(
      (await walkAsync(dir, { sort: true, followSymlinks: true })).map((e) => e.rel),
      ["B", "_", "a", "log/inner.log"],
    );

    mkdirSync(path.join(dir, "sub"));
    writeFileSync(path.join(dir, "sub/deep.log"), "ok\n");
    symlinkSync(path.join(dir, "sub"), path.join(dir, "sub/again"));
    assert.deepEqual(
      walkSync(dir, { sort: true, followSymlinks: true }).map((e) => e.rel),
      ["B", "_", "a", "log/inner.log", "sub/deep.log"],
    );
    assert.deepEqual(
      (await walkAsync(dir, { sort: true, followSymlinks: true })).map((e) => e.rel),
      ["B", "_", "a", "log/inner.log", "sub/deep.log"],
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
    rmSync(target, { recursive: true, force: true });
  }
});
