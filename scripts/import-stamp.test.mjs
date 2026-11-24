import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { checkImportStamp, writeImportStamp } from "./import-stamp.mjs";

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
    // Non-asset temp/output files leave the stamp valid.
    writeFileSync(path.join(dir, "sk", "run.log"), "ok\n");
    writeFileSync(path.join(dir, "sk", "bots.ndjson"), "{}\n");
    writeFileSync(path.join(dir, "sk", "notes.txt"), "note\n");
    assert.equal(checkImportStamp(dir, "sk").ok, true);
    // Untracked Godot scripts/assets invalidate the stamp.
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
    // Legacy stamp with no godot field still validates cleanly.
    writeImportStamp(dir, "sk", { godot: null });
    assert.equal(checkImportStamp(dir, "sk", { godot: "Godot_v4.7.2:100" }).ok, true);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
