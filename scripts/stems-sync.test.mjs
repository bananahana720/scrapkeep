import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { defaultSources, parseHashes, sync } from "./stems-sync.mjs";
import { git } from "./lib/git.mjs";

const sha = (text) => createHash("sha256").update(text).digest("hex");

function layout(listed, held) {
  const root = mkdtempSync(path.join(os.tmpdir(), "stems-sync-"));
  const to = path.join(root, "to");
  const src = path.join(root, "src");
  for (const dir of [to, src]) mkdirSync(path.join(dir, "pack"), { recursive: true });
  writeFileSync(
    path.join(to, "STEMS.sha256"),
    listed.map(([rel, text]) => `${sha(text)}  ${rel}`).join("\n") + "\n",
  );
  for (const [where, rel, text] of held)
    writeFileSync(path.join(where === "to" ? to : src, rel), text);
  return { root, to, src };
}

test("copies an absent stem whose source hashes as listed, leaves a present one alone", () => {
  const { root, to, src } = layout(
    [
      ["pack/a.ogg", "A"],
      ["pack/b.ogg", "B"],
    ],
    [
      ["to", "pack/a.ogg", "A"],
      ["src", "pack/b.ogg", "B"],
    ],
  );
  try {
    const r = sync(to, [src]);
    assert.deepEqual(
      [r.copied, r.present, r.mismatched, r.missing],
      [["pack/b.ogg"], ["pack/a.ogg"], [], []],
    );
    assert.equal(readFileSync(path.join(to, "pack/b.ogg"), "utf8"), "B");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("planted mismatch: a stale file in the target is named and never overwritten", () => {
  const { root, to, src } = layout(
    [["pack/a.ogg", "A"]],
    [
      ["to", "pack/a.ogg", "STALE"],
      ["src", "pack/a.ogg", "A"],
    ],
  );
  try {
    const r = sync(to, [src]);
    assert.equal(r.mismatched.length, 1);
    assert.equal(r.mismatched[0].file, "pack/a.ogg");
    assert.equal(readFileSync(path.join(to, "pack/a.ogg"), "utf8"), "STALE");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("planted mismatch: a source with the wrong hash is not copied", () => {
  const { root, to, src } = layout([["pack/a.ogg", "A"]], [["src", "pack/a.ogg", "STALE"]]);
  try {
    const r = sync(to, [src]);
    assert.equal(r.copied.length, 0);
    assert.equal(r.mismatched.length, 1);
    assert.equal(existsSync(path.join(to, "pack/a.ogg")), false);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a listed stem no source holds is reported missing; a second source can supply it", () => {
  const { root, to, src } = layout([["pack/a.ogg", "A"]], []);
  try {
    assert.deepEqual(sync(to, [src]).missing, ["pack/a.ogg"]);
    const second = path.join(root, "second");
    mkdirSync(path.join(second, "pack"), { recursive: true });
    writeFileSync(path.join(second, "pack/a.ogg"), "A");
    assert.deepEqual(sync(to, [src, second]).copied, ["pack/a.ogg"]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a target with no hash list is an error, never a pass", () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "stems-sync-"));
  try {
    assert.throws(() => sync(root, []), /no hash list/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("parseHashes reads sha256sum lines and skips the rest", () => {
  const m = parseHashes(`${sha("x")}  a/b.ogg\nnot a line\n`);
  assert.deepEqual([...m], [["a/b.ogg", sha("x")]]);
});

test("defaultSources checks the main checkout first, then w46/music_ace-v2 before older scratch copies and repage/music_ace last", () => {
  const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const common = git(["rev-parse", "--git-common-dir"], { cwd: repo });
  const mainMusic = path.resolve(
    repo,
    common,
    "..",
    "sketches",
    "core-loop",
    "assets",
    "music_ace",
  );
  const home = path.join(os.tmpdir(), "stems-sync-home");
  const sources = defaultSources(repo, home);
  assert.equal(sources[0], mainMusic);
  assert.equal(sources[1], path.join(home, "scratch", "w46", "music_ace-v2"));
  assert.equal(sources[2], path.join(home, "scratch", "w33", "music_ace-full"));
  assert.equal(sources.at(-1), path.join(home, "scratch", "repage", "music_ace"));
});
