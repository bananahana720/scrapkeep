import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { checkImportStamp, writeImportStamp } from "./import-stamp.mjs";

function repo() {
  const dir = mkdtempSync(path.join(os.tmpdir(), "import-stamp-"));
  const git = (...args) => execFileSync("git", ["-C", dir, "-c", "user.name=t", "-c", "user.email=t@t", ...args], { stdio: "ignore" });
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
