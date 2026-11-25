import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  checkImportStamp,
  hasValidUidCache,
  importSketch,
  isCleanImportPass,
  writeImportStamp,
} from "./import-stamp.mjs";

function repo() {
  const dir = mkdtempSync(path.join(os.tmpdir(), "import-stamp-"));
  const git = (...args) =>
    execFileSync("git", ["-C", dir, "-c", "user.name=t", "-c", "user.email=t@t", ...args], {
      stdio: "ignore",
    });
  mkdirSync(path.join(dir, "sk"), { recursive: true });
  writeFileSync(path.join(dir, "sk", "a.gd"), "1\n");
  writeFileSync(path.join(dir, ".gitignore"), ".godot/\n");
  git("init", "-q");
  git("add", ".");
  git("commit", "-qm", "one");
  const commit = (file, text) => {
    mkdirSync(path.dirname(path.join(dir, file)), { recursive: true });
    writeFileSync(path.join(dir, file), text);
    git("add", ".");
    git("commit", "-qm", file);
  };
  return { dir, commit };
}

test("a .godot never imported, or imported with no stamp, is refused", () => {
  const { dir } = repo();
  assert.equal(checkImportStamp(dir, "sk").ok, false);
  mkdirSync(path.join(dir, "sk", ".godot"));
  assert.match(checkImportStamp(dir, "sk").reason, /no import stamp/);
  rmSync(dir, { recursive: true });
});

test("the stamp holds across commits outside the sketch and breaks on a sketch change", () => {
  const { dir, commit } = repo();
  writeImportStamp(dir, "sk");
  assert.equal(checkImportStamp(dir, "sk").ok, true);
  commit("docs/x.md", "doc\n");
  assert.equal(checkImportStamp(dir, "sk").ok, true);
  commit("sk/b.gd", "2\n");
  const result = checkImportStamp(dir, "sk");
  assert.equal(result.ok, false);
  assert.match(result.reason, /imported at commit/);
  writeImportStamp(dir, "sk");
  assert.equal(checkImportStamp(dir, "sk").ok, true);
  rmSync(dir, { recursive: true });
});

test("uncommitted sketch edits refuse, at the import or after it", () => {
  const { dir, commit } = repo();
  try {
    writeImportStamp(dir, "sk");
    writeFileSync(path.join(dir, "sk", "a.gd"), "edited\n");
    assert.match(checkImportStamp(dir, "sk").reason, /uncommitted edits/);
    writeImportStamp(dir, "sk");
    commit("sk/a.gd", "edited\n");
    assert.match(checkImportStamp(dir, "sk").reason, /imported with uncommitted/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("untracked Godot project and asset files invalidate the stamp while temp output files do not", () => {
  const { dir } = repo();
  try {
    writeImportStamp(dir, "sk");
    assert.equal(checkImportStamp(dir, "sk").ok, true);
    writeFileSync(path.join(dir, "sk", "run.log"), "ok\n");
    writeFileSync(path.join(dir, "sk", "bots.ndjson"), "{}\n");
    writeFileSync(path.join(dir, "sk", "notes.txt"), "note\n");
    assert.equal(checkImportStamp(dir, "sk").ok, true);
    for (const file of [
      "new_script.gd",
      "scene.tscn",
      "mat.tres",
      "mesh.glb",
      "tex.png",
      "sfx.ogg",
      "hit.wav",
      "font.ttf",
      "disp.otf",
      "fx.gdshader",
      "data.json",
      "cache.bin",
      "tex.png.import",
      "project.godot",
    ]) {
      const full = path.join(dir, "sk", file);
      writeFileSync(full, "x\n");
      const res = checkImportStamp(dir, "sk");
      assert.equal(res.ok, false, `untracked ${file} must invalidate stamp`);
      assert.match(res.reason, /uncommitted edits/);
      rmSync(full);
    }
    assert.equal(checkImportStamp(dir, "sk").ok, true);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("Godot binary identity mismatch invalidates the stamp while legacy stamps stay compatible", () => {
  const { dir } = repo();
  try {
    writeImportStamp(dir, "sk", { godot: "Godot_v4.7.2:100" });
    assert.equal(checkImportStamp(dir, "sk", { godot: "Godot_v4.7.2:100" }).ok, true);
    const diff = checkImportStamp(dir, "sk", { godot: "Godot_v4.7.3:200" });
    assert.equal(diff.ok, false);
    assert.match(diff.reason, /imported with Godot Godot_v4\.7\.2:100/);
    writeImportStamp(dir, "sk", { godot: null });
    assert.equal(checkImportStamp(dir, "sk", { godot: "Godot_v4.7.2:100" }).ok, true);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("importSketch skips pass 2 when pass 1 is clean with a valid uid_cache.bin", () => {
  const { dir } = repo();
  try {
    mkdirSync(path.join(dir, "sk", ".godot"), { recursive: true });
    writeFileSync(path.join(dir, "sk", ".godot", "uid_cache.bin"), "uid-data");
    assert.equal(hasValidUidCache(dir, "sk"), true);
    const calls = [];
    const result = importSketch(dir, "sk", {
      runPass: (_root, _sketch, pass) => {
        calls.push(pass);
        return { status: 0, signal: null, stdout: "Godot Engine v4.7.2\n", stderr: "" };
      },
    });
    assert.deepEqual(calls, [1]);
    assert.deepEqual(result, { passes: 1, skippedSecond: true });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("importSketch runs pass 2 when --double is requested or pass 1 has errors, warnings, or missing uid cache", () => {
  const { dir } = repo();
  try {
    mkdirSync(path.join(dir, "sk", ".godot"), { recursive: true });
    const uidCalls = [];
    const rMissing = importSketch(dir, "sk", {
      runPass: (_root, _sketch, pass) => {
        uidCalls.push(pass);
        if (pass === 2) writeFileSync(path.join(dir, "sk", ".godot", "uid_cache.bin"), "ok");
        return { status: 0, signal: null, stdout: "", stderr: "" };
      },
    });
    assert.deepEqual(uidCalls, [1, 2]);
    assert.deepEqual(rMissing, { passes: 2, skippedSecond: false });

    const doubleCalls = [];
    const rDouble = importSketch(dir, "sk", {
      doublePass: true,
      runPass: (_root, _sketch, pass) => {
        doubleCalls.push(pass);
        return { status: 0, signal: null, stdout: "", stderr: "" };
      },
    });
    assert.deepEqual(doubleCalls, [1, 2]);
    assert.deepEqual(rDouble, { passes: 2, skippedSecond: false });

    for (const bad of [
      { status: 0, stdout: "SCRIPT ERROR: could not preload\n", stderr: "" },
      { status: 0, stdout: "", stderr: "WARNING: Failed to import font.ttf\n" },
      { status: null, signal: "SIGSEGV", stdout: "", stderr: "" },
    ]) {
      const fallbackCalls = [];
      const res = importSketch(dir, "sk", {
        runPass: (_root, _sketch, pass) => {
          fallbackCalls.push(pass);
          return pass === 1 ? bad : { status: 0, signal: null, stdout: "", stderr: "" };
        },
      });
      assert.deepEqual(fallbackCalls, [1, 2]);
      assert.equal(res.passes, 2);
    }

    assert.throws(
      () =>
        importSketch(dir, "sk", {
          runPass: () => ({ status: 0, signal: null, stdout: "SCRIPT ERROR: bad\n", stderr: "" }),
        }),
      /second import was not clean/,
    );
    assert.equal(isCleanImportPass({ status: 0, output: "ok", uidCacheValid: false }), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
