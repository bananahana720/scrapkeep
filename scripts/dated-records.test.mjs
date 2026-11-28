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

function judgeFiles(rule, baseFiles, headFiles, step = () => {}) {
  return withRepo((dir) => {
    const lists = rule === "frozen" ? list([PAGE]) : list([], [PAGE]);
    const base = commit(dir, { [LIST_PATH]: lists, ...baseFiles });
    commit(dir, headFiles);
    step(dir);
    return run(dir, "--base", base);
  });
}

test("a frozen page whose final newline is added or removed is a finding", () => {
  for (const [before, after] of [
    ["a\nb\n", "a\nb"],
    ["a\nb", "a\nb\n"],
    ["", "\n"],
  ]) {
    const result = judgeFiles("frozen", { [PAGE]: before }, { [PAGE]: after });
    assert.equal(result.code, 1, `${JSON.stringify([before, after])}: ${result.out}`);
    assert.match(result.out, /newline at the end of the file added or removed/);
    assert.match(result.out, /make the end of the file exactly as it is at the base/);
  }
});

test("a frozen page whose file mode changes is a finding; a log page may change mode", () => {
  const chmod = (dir) => {
    git(dir, "update-index", "--chmod=+x", PAGE);
    git(dir, "commit", "-q", "-m", "mode");
  };
  const frozen = judgeFiles("frozen", { [PAGE]: ENTRIES }, {}, chmod);
  assert.equal(frozen.code, 1, frozen.out);
  assert.match(frozen.out, /changed its file mode from 100644 to 100755; set it back to 100644/);

  const log = judgeFiles("log", { [PAGE]: ENTRIES }, {}, chmod);
  assert.equal(log.code, 0, log.out);
});

test("more frozen changes: a removed line, a line-ending change, a rename with an edit", () => {
  const removed = judge("frozen", { [PAGE]: ENTRIES.replace("- two\n", "") });
  assert.equal(removed.code, 1, removed.out);
  assert.match(removed.out, /line 4 of the base copy changed or went missing:\n {4}- two/);

  const crlf = judge("frozen", { [PAGE]: ENTRIES.replaceAll("\n", "\r\n") });
  assert.equal(crlf.code, 1, crlf.out);
  assert.match(crlf.out, /\(frozen\) line 1 of the base copy changed or went missing/);

  const renamed = judge("frozen", { [PAGE]: null, "notes/moved.md": `${ENTRIES}- four\n` });
  assert.equal(renamed.code, 1, renamed.out);
  assert.match(renamed.out, /\(frozen\) is gone at the head \(deleted or renamed\)/);
});

test("a log page that is deleted or renamed is a finding", () => {
  const deleted = judge("log", { [PAGE]: null });
  assert.equal(deleted.code, 1, deleted.out);
  assert.match(deleted.out, /\(log\) is gone at the head \(deleted or renamed\)/);

  const renamed = judge("log", { [PAGE]: null, "notes/moved.md": ENTRIES });
  assert.equal(renamed.code, 1, renamed.out);
  assert.match(renamed.out, /\(log\) is gone at the head \(deleted or renamed\)/);
});

test("a log line edited while a copy of the old line is added elsewhere is a finding", () => {
  const above = judge("log", { [PAGE]: "# Record\n\n- two\n- one\n- 2\n- three\n" });
  assert.equal(above.code, 1, above.out);
  assert.match(above.out, /\(log\) line 4 of the base copy changed or went missing:\n {4}- two/);

  const below = judge("log", { [PAGE]: "# Record\n\n- one\n- 2\n- three\n- two\n" });
  assert.equal(below.code, 1, below.out);
  assert.match(below.out, /\(log\) line \d of the base copy changed or went missing/);
});

test("an empty list passes, says no page is listed, and still names dropped pages", () => {
  withRepo((dir) => {
    const base = commit(dir, { [LIST_PATH]: list([PAGE]), [PAGE]: ENTRIES });
    commit(dir, { [LIST_PATH]: list() });
    const result = run(dir, "--base", base);
    assert.equal(result.code, 0, result.out);
    assert.match(
      result.out,
      /notes\/record\.md was dropped from the list and is no longer checked/,
    );
    assert.match(result.out, /PASS, no page is listed in scripts\/ci\/dated-records\.json/);
  });
});

test("--base with no value and every bad list shape exit 2", () => {
  withRepo((dir) => {
    const base = commit(dir, { [LIST_PATH]: list([PAGE]), [PAGE]: ENTRIES });

    for (const args of [["--base"], ["--base="]]) {
      const result = run(dir, ...args);
      assert.equal(result.code, 2, `${args}: ${result.out}`);
      assert.match(result.out, /could not run: bad arguments: --base requires a value/);
    }

    const shapes = [
      [JSON.stringify({ log: [] }), /needs "frozen" as an array of repo-relative paths/],
      [JSON.stringify({ frozen: [] }), /needs "log" as an array of repo-relative paths/],
      [JSON.stringify({ frozen: PAGE, log: [] }), /needs "frozen" as an array/],
      [JSON.stringify({ frozen: [3], log: [] }), /needs "frozen" as an array/],
      [JSON.stringify({ frozen: [""], log: [] }), /needs "frozen" as an array/],
      [list([PAGE], [PAGE]), /lists notes\/record\.md twice/],
      [JSON.stringify([PAGE]), /needs a JSON object with "frozen" and "log" arrays/],
      ["null", /needs a JSON object with "frozen" and "log" arrays/],
    ];
    for (const [text, message] of shapes) {
      writeFileSync(path.join(dir, LIST_PATH), text);
      const result = run(dir, "--base", base);
      assert.equal(result.code, 2, `${text}: ${result.out}`);
      assert.match(result.out, message);
    }
  });
});

test("the check exits 2, never 0, when git is not on the path", () => {
  withRepo((dir) => {
    const base = commit(dir, { [LIST_PATH]: list([PAGE]), [PAGE]: ENTRIES });
    const empty = mkdtempSync(path.join(os.tmpdir(), "dated-records-nogit-"));
    try {
      const ran = spawnSync(process.execPath, [script, "--base", base], {
        cwd: dir,
        encoding: "utf8",
        env: { ...process.env, PATH: empty },
      });
      assert.equal(ran.status, 2, ran.stdout + ran.stderr);
      assert.match(ran.stderr, /could not run: not inside a git checkout/);
    } finally {
      rmSync(empty, { recursive: true, force: true });
    }
  });
});

test("content git gives that does not match its blob id exits 2", () => {
  withRepo((dir) => {
    const base = commit(dir, { [LIST_PATH]: list([], [PAGE]), [PAGE]: ENTRIES });
    commit(dir, { [PAGE]: `${ENTRIES}- four\n` });
    const realGit = spawnSync("sh", ["-c", "command -v git"], { encoding: "utf8" }).stdout.trim();
    const bin = mkdtempSync(path.join(os.tmpdir(), "dated-records-fakegit-"));
    try {
      writeFileSync(
        path.join(bin, "git"),
        `#!/bin/sh\nif [ "$1" = "cat-file" ]; then exit 0; fi\nexec "${realGit}" "$@"\n`,
        { mode: 0o755 },
      );
      const ran = spawnSync(process.execPath, [script, "--base", base], {
        cwd: dir,
        encoding: "utf8",
        env: { ...process.env, PATH: `${bin}:${process.env.PATH}` },
      });
      assert.equal(ran.status, 2, ran.stdout + ran.stderr);
      assert.match(ran.stderr, /does not match its blob id/);
    } finally {
      rmSync(bin, { recursive: true, force: true });
    }
  });
});

test("a page whose head content git cannot read exits 2", () => {
  const top = mkdtempSync(path.join(os.tmpdir(), "dated-records-blobless-head-"));
  try {
    const source = path.join(top, "source");
    mkdirSync(source);
    git(source, "init", "-q", "-b", "main");
    git(source, "config", "uploadpack.allowFilter", "true");
    const base = commit(source, { [LIST_PATH]: list([PAGE]), [PAGE]: ENTRIES });
    const head = commit(source, { [PAGE]: ENTRIES.replace("- two", "- 2") });
    commit(source, { [PAGE]: ENTRIES });

    const clone = path.join(top, "clone");
    git(top, "clone", "-q", "--filter=blob:none", "--no-checkout", `file://${source}`, clone);
    git(clone, "reset", "-q", "--hard", "HEAD");
    renameSync(source, path.join(top, "moved"));

    const result = run(clone, "--base", base, "--head", head);
    assert.equal(result.code, 2, result.out);
    assert.ok(result.out.includes(`could not read notes/record.md at ${head}`), result.out);
    assert.match(result.out, /does not pass a page/);
  } finally {
    rmSync(top, { recursive: true, force: true });
  }
});
