import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { diffTokenStreams, lexGd, lexJsLike } from "./token-diff.mjs";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const scriptPath = path.join(repoRoot, "scripts", "token-diff.mjs");

function git(cwd, ...args) {
  const ran = spawnSync("git", args, {
    cwd,
    encoding: "utf8",
    env: {
      ...process.env,
      GIT_AUTHOR_NAME: "Test",
      GIT_AUTHOR_EMAIL: "test@example.invalid",
      GIT_COMMITTER_NAME: "Test",
      GIT_COMMITTER_EMAIL: "test@example.invalid",
    },
  });
  assert.equal(ran.status, 0, ran.stderr);
  return ran.stdout.trim();
}

test("lexGd strips comments, keeps # smoke: (lines 1-5) and # lint: pragmas, and emits INDENT/DEDENT/NEWLINE", () => {
  const a = [
    "# smoke: solo  timeout=60s",
    "# regular header comment",
    "func f(x):",
    "\t# body comment",
    '\tvar s := r"raw" + &\'name\' + ^"Node/Path" + """multi',
    "line\"\"\" + '''single''' # lint:   route seed",
    "\treturn x",
    "",
  ].join("\n");

  const b = [
    "# smoke: solo timeout=60s",
    "func f(x):",
    '\tvar s := r"raw" + &\'name\' + ^"Node/Path" + """multi',
    "line\"\"\" + '''single''' # lint: route seed",
    "\treturn x # trailing comment",
  ].join("\n");

  assert.equal(diffTokenStreams(lexGd(a), lexGd(b)).changed, false);

  const smokeBeyond5 = [
    "var a = 1",
    "var b = 2",
    "var c = 3",
    "var d = 4",
    "var e = 5",
    "# smoke: solo",
  ].join("\n");
  const smokeRemovedBeyond5 = [
    "var a = 1",
    "var b = 2",
    "var c = 3",
    "var d = 4",
    "var e = 5",
  ].join("\n");
  assert.equal(diffTokenStreams(lexGd(smokeBeyond5), lexGd(smokeRemovedBeyond5)).changed, false);

  const missingPragma = b.replace("# lint: route seed", "");
  assert.equal(diffTokenStreams(lexGd(b), lexGd(missingPragma)).changed, true);

  const badIndent = b.replace("\treturn x", "return x");
  const indentDiff = diffTokenStreams(lexGd(b), lexGd(badIndent));
  assert.equal(indentDiff.changed, true);
});

test("lexJsLike handles templates, regex vs division, and strips // and /* */ except // lint:", () => {
  const a = [
    "// top comment",
    "/* block",
    "   comment */",
    "const x = `hello ${/* inner */ a / 2} world`;",
    "const re = /foo\\/bar[0-9]/gi;",
    "if (ok) /baz/.test(s); // lint:   keep this",
    "const div = (a + b) / 2;",
  ].join("\n");

  const b = [
    "const x = `hello ${a / 2} world`;",
    "const re = /foo\\/bar[0-9]/gi;",
    "if (ok) /baz/.test(s); // lint: keep this",
    "const div = (a + b) / 2;",
  ].join("\n");

  assert.equal(diffTokenStreams(lexJsLike(a), lexJsLike(b)).changed, false);

  const changedTemplate = b.replace("a / 2", "a / 3");
  const diff = diffTokenStreams(lexJsLike(b), lexJsLike(changedTemplate));
  assert.equal(diff.changed, true);
  assert.equal(diff.baseLine, 1);
  assert.equal(diff.headLine, 1);

  const removedLint = b.replace("// lint: keep this", "");
  assert.equal(diffTokenStreams(lexJsLike(b), lexJsLike(removedLint)).changed, true);

  const shaderA =
    "shader_type spatial;\n// comment\nvoid fragment() { ALBEDO = vec3(1.0) / 2.0; }\n";
  const shaderB = "shader_type spatial;\nvoid fragment() { ALBEDO = vec3(1.0) / 2.0; }\n";
  assert.equal(
    diffTokenStreams(
      lexJsLike(shaderA, { allowRegex: false }),
      lexJsLike(shaderB, { allowRegex: false }),
    ).changed,
    false,
  );
});

test("token-diff CLI exits 0 on comment-only edits, 1 with file:baseLine:headLine on code edits, and 2 on error", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "token-diff-cli-"));
  try {
    mkdirSync(path.join(tmp, "src"), { recursive: true });
    git(tmp, "init", "-q");
    writeFileSync(path.join(tmp, "src", "a.mjs"), "// header\nexport const v = 1;\n");
    writeFileSync(path.join(tmp, "src", "b.gd"), "# comment\nfunc run():\n\treturn 2\n");
    git(tmp, "add", ".");
    git(tmp, "commit", "-q", "-m", "base");

    writeFileSync(path.join(tmp, "src", "a.mjs"), "export const v = 1;\n");
    writeFileSync(path.join(tmp, "src", "b.gd"), "func run():\n\treturn 2\n");

    const clean = spawnSync(process.execPath, [scriptPath, "--root", tmp], { encoding: "utf8" });
    assert.equal(clean.status, 0, clean.stderr);

    writeFileSync(path.join(tmp, "src", "a.mjs"), "export const v = 2;\n");
    const dirty = spawnSync(process.execPath, [scriptPath, "--root", tmp], { encoding: "utf8" });
    assert.equal(dirty.status, 1);
    assert.match(dirty.stdout, /^src\/a\.mjs:2:1 /m);

    git(tmp, "add", "src/b.gd");
    const stagedClean = spawnSync(process.execPath, [scriptPath, "--root", tmp, "--staged"], {
      encoding: "utf8",
    });
    assert.equal(stagedClean.status, 0, stagedClean.stderr);

    git(tmp, "add", "src/a.mjs");
    const stagedDirty = spawnSync(process.execPath, [scriptPath, "--root", tmp, "--staged"], {
      encoding: "utf8",
    });
    assert.equal(stagedDirty.status, 1);
    assert.match(stagedDirty.stdout, /^src\/a\.mjs:2:1 /m);

    const errRun = spawnSync(process.execPath, [scriptPath, "--root", tmp, "nonexistent-ref"], {
      encoding: "utf8",
    });
    assert.equal(errRun.status, 2);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
