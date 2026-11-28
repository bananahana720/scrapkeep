import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, renameSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { LIST_PATH } from "./dated-records.mjs";

const script = path.join(path.dirname(fileURLToPath(import.meta.url)), "dated-records.mjs");
const PAGE = "notes/record.md";
const ENTRIES = "# Record\n\n- one\n- two\n- three\n";

function git(cwd, ...args) {
  const ran = spawnSync("git", ["-c", "commit.gpgsign=false", ...args], {
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

function commit(dir, files) {
  for (const [file, text] of Object.entries(files)) {
    const full = path.join(dir, file);
    if (text === null) {
      rmSync(full);
    } else {
      mkdirSync(path.dirname(full), { recursive: true });
      writeFileSync(full, text);
    }
  }
  git(dir, "add", "-A");
  git(dir, "commit", "-q", "--allow-empty", "-m", "step");
  return git(dir, "rev-parse", "HEAD");
}

function list(frozen = [], log = []) {
  return JSON.stringify({ frozen, log });
}

function run(cwd, ...args) {
  const ran = spawnSync(process.execPath, [script, ...args], {
    cwd,
    encoding: "utf8",
    env: { ...process.env, GIT_TERMINAL_PROMPT: "0" },
  });
  return { code: ran.status, out: ran.stdout + ran.stderr };
}

function withRepo(fn) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "dated-records-"));
  try {
    git(dir, "init", "-q", "-b", "main");
    return fn(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function judge(rule, headFiles, baseText = ENTRIES) {
  return withRepo((dir) => {
    const lists = rule === "frozen" ? list([PAGE]) : list([], [PAGE]);
    const base = commit(dir, { [LIST_PATH]: lists, [PAGE]: baseText });
    commit(dir, headFiles);
    return run(dir, "--base", base);
  });
}

test("a frozen page that is changed, added to, deleted or renamed is a finding", () => {
  const changed = judge("frozen", { [PAGE]: ENTRIES.replace("- two", "- 2") });
  assert.equal(changed.code, 1, changed.out);
  assert.match(changed.out, /notes\/record\.md \(frozen\) line 4 of the base copy changed/);
  assert.match(changed.out, /\n {4}- two\n/);
  assert.match(changed.out, /keeps the names and paths it was written with/);
  assert.match(changed.out, /remove it from scripts\/ci\/dated-records\.json/);

  const added = judge("frozen", { [PAGE]: `${ENTRIES}- four\n` });
  assert.equal(added.code, 1, added.out);
  assert.match(added.out, /line 6 was added at the head:\n {4}- four/);

  const deleted = judge("frozen", { [PAGE]: null });
  assert.equal(deleted.code, 1, deleted.out);
  assert.match(deleted.out, /notes\/record\.md \(frozen\) is gone at the head/);

  const renamed = judge("frozen", { [PAGE]: null, "notes/moved.md": ENTRIES });
  assert.equal(renamed.code, 1, renamed.out);
  assert.match(renamed.out, /is gone at the head \(deleted or renamed\)/);

  const kept = judge("frozen", { "notes/other.md": "x\n" });
  assert.equal(kept.code, 0, kept.out);
  assert.match(kept.out, /PASS, 1 listed page/);
});

test("a log page keeps every base line in order and takes new lines anywhere", () => {
  const changed = judge("log", { [PAGE]: ENTRIES.replace("- two", "- 2") });
  assert.equal(changed.code, 1, changed.out);
  assert.match(changed.out, /\(log\) line 4 of the base copy changed or went missing:\n {4}- two/);

  const removed = judge("log", { [PAGE]: ENTRIES.replace("- one\n", "") });
  assert.equal(removed.code, 1, removed.out);
  assert.match(removed.out, /line 3 of the base copy changed or went missing:\n {4}- one/);

  const swapped = judge("log", { [PAGE]: "# Record\n\n- two\n- one\n- three\n" });
  assert.equal(swapped.code, 1, swapped.out);
  assert.match(swapped.out, /\(log\) line \d+ of the base copy changed or went missing/);

  const atEnd = judge("log", { [PAGE]: `${ENTRIES}- four\n- five\n` });
  assert.equal(atEnd.code, 0, atEnd.out);

  const inMiddle = judge("log", {
    [PAGE]: "# Record\n\n- one\n- one and a half\n\n- two\n- three\n",
  });
  assert.equal(inMiddle.code, 0, inMiddle.out);
});

test("removing one copy of a line that a log page holds twice is a finding", () => {
  const twice = "# Record\n\n- same\n- other\n- same\n";
  const result = judge("log", { [PAGE]: "# Record\n\n- same\n- other\n" }, twice);
  assert.equal(result.code, 1, result.out);
  assert.match(result.out, /line 5 of the base copy changed or went missing:\n {4}- same/);
});

test("a listed page that is new at the head passes", () => {
  withRepo((dir) => {
    const base = commit(dir, { [LIST_PATH]: list() });
    commit(dir, { [LIST_PATH]: list([PAGE]), [PAGE]: ENTRIES });
    const result = run(dir, "--base", base);
    assert.equal(result.code, 0, result.out);
  });
});

test("a page dropped from the list passes and is named", () => {
  withRepo((dir) => {
    const base = commit(dir, { [LIST_PATH]: list([PAGE]), [PAGE]: ENTRIES });
    commit(dir, { [LIST_PATH]: list(), [PAGE]: "rewritten\n" });
    const result = run(dir, "--base", base);
    assert.equal(result.code, 0, result.out);
    assert.match(
      result.out,
      /notes\/record\.md was dropped from the list and is no longer checked/,
    );
  });
});

test("--head points the check at any two commits and reads the list from the working tree", () => {
  withRepo((dir) => {
    const base = commit(dir, { [LIST_PATH]: list(), [PAGE]: ENTRIES });
    const head = commit(dir, { [PAGE]: "rewritten\n" });
    commit(dir, { [LIST_PATH]: list([PAGE]), [PAGE]: ENTRIES });
    const result = run(dir, "--base", base, "--head", head);
    assert.equal(result.code, 1, result.out);
    assert.match(result.out, /line 1 of the base copy changed or went missing:\n {4}# Record/);
  });
});

test("the check exits 2 when it cannot read its input", () => {
  withRepo((dir) => {
    const base = commit(dir, { [LIST_PATH]: list([PAGE]), [PAGE]: ENTRIES });

    const noBase = run(dir);
    assert.equal(noBase.code, 2, noBase.out);
    assert.match(noBase.out, /could not run: --base <ref> is missing/);

    const badRef = run(dir, "--base", "no-such-ref");
    assert.equal(badRef.code, 2, badRef.out);
    assert.match(badRef.out, /--base no-such-ref is not a commit git can resolve[\s\S]*Fetch it/);

    git(dir, "switch", "-q", "--orphan", "other");
    const unrelated = commit(dir, { [LIST_PATH]: list([PAGE]), [PAGE]: "unrelated\n" });
    git(dir, "switch", "-q", "main");
    const noMergeBase = run(dir, "--base", unrelated);
    assert.equal(noMergeBase.code, 2, noMergeBase.out);
    assert.match(noMergeBase.out, /git merge-base \S+ HEAD failed[\s\S]*Fetch the full history/);

    rmSync(path.join(dir, LIST_PATH));
    const missing = run(dir, "--base", base);
    assert.equal(missing.code, 2, missing.out);
    assert.match(missing.out, /could not read the list scripts\/ci\/dated-records\.json/);

    writeFileSync(path.join(dir, LIST_PATH), "{ frozen: ");
    const invalid = run(dir, "--base", base);
    assert.equal(invalid.code, 2, invalid.out);
    assert.match(invalid.out, /dated-records\.json is not valid JSON/);

    writeFileSync(path.join(dir, LIST_PATH), list([PAGE, "notes/typo.md"]));
    const typo = run(dir, "--base", base);
    assert.equal(typo.code, 2, typo.out);
    assert.match(typo.out, /names notes\/typo\.md, which matches no tracked file/);
  });
});

test("a page whose base content git cannot read exits 2, not a pass", () => {
  const top = mkdtempSync(path.join(os.tmpdir(), "dated-records-blobless-"));
  try {
    const source = path.join(top, "source");
    mkdirSync(source);
    git(source, "init", "-q", "-b", "main");
    git(source, "config", "uploadpack.allowFilter", "true");
    const base = commit(source, { [LIST_PATH]: list([], [PAGE]), [PAGE]: ENTRIES });
    commit(source, { [PAGE]: ENTRIES.replace("- two", "- 2") });

    const clone = path.join(top, "clone");
    git(top, "clone", "-q", "--filter=blob:none", "--no-checkout", `file://${source}`, clone);
    git(clone, "reset", "-q", "--hard", "HEAD");
    renameSync(source, path.join(top, "moved"));

    const result = run(clone, "--base", base);
    assert.equal(result.code, 2, result.out);
    assert.match(result.out, /could not read notes\/record\.md at \S+[\s\S]*does not pass a page/);
  } finally {
    rmSync(top, { recursive: true, force: true });
  }
});
