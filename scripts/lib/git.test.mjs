import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  statSync,
  utimesSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  DEFAULT_MAX_BUFFER,
  GIT_STOP_GRACE_MS,
  REPO_ROOT,
  cleanHead,
  git,
  gitAsync,
  gitOptional,
  gitState,
  nulSeparated,
} from "./git.mjs";
import { processLive } from "./proc.mjs";

function makeTempRepo() {
  const dir = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-git-lib-"));
  git(["init", "-q", "-b", "main"], { cwd: dir });
  git(["config", "user.email", "test@example.invalid"], { cwd: dir });
  git(["config", "user.name", "Test"], { cwd: dir });
  git(["config", "commit.gpgsign", "false"], { cwd: dir });
  mkdirSync(path.join(dir, "sketches/core-loop/src"), { recursive: true });
  writeFileSync(path.join(dir, "sketches/core-loop/src/a.gd"), "extends Node\n");
  git(["add", "."], { cwd: dir });
  git(["commit", "-q", "-m", "initial"], { cwd: dir });
  return dir;
}

test("git and gitOptional read the repository cwd is in, even when a git hook exported another one", () => {
  const dir = makeTempRepo();
  const before = process.env.GIT_DIR;
  process.env.GIT_DIR = path.join(REPO_ROOT, ".git");
  try {
    const cwd = path.join(dir, "sketches/core-loop");
    assert.equal(git(["ls-files", "--", "src"], { cwd }), "src/a.gd");
    assert.equal(gitOptional(["ls-files", "--", "src"], { cwd }), "src/a.gd");
    assert.equal(realpathSync(git(["rev-parse", "--show-toplevel"], { cwd })), realpathSync(dir));
    assert.equal(cleanHead(dir), git(["rev-parse", "HEAD"], { cwd: dir }));
  } finally {
    if (before === undefined) delete process.env.GIT_DIR;
    else process.env.GIT_DIR = before;
    rmSync(dir, { recursive: true, force: true });
  }
});

test("git and gitOptional use 64 MiB default maxBuffer, trim by default, and handle errors", () => {
  assert.equal(DEFAULT_MAX_BUFFER, 64 * 1024 * 1024);
  let seen = null;
  const out = git(["rev-parse", "HEAD"], {
    cwd: "/fake",
    spawn: (_cmd, args, opts) => {
      seen = { args, opts };
      return { status: 0, stdout: "abc123\n", stderr: "" };
    },
  });
  assert.equal(out, "abc123");
  assert.equal(seen.opts.maxBuffer, DEFAULT_MAX_BUFFER);
  assert.equal(seen.opts.cwd, "/fake");

  assert.equal(
    git(["status"], {
      trim: false,
      spawn: () => ({ status: 0, stdout: " M file.mjs\n", stderr: "" }),
    }),
    " M file.mjs\n",
  );
  assert.throws(
    () =>
      git(["bad-cmd"], {
        spawn: () => ({ status: 1, stdout: "", stderr: "unknown command" }),
      }),
    /git bad-cmd failed: unknown command/,
  );
  assert.equal(
    gitOptional(["bad-cmd"], {
      spawn: () => ({ status: 1, stdout: "", stderr: "fail" }),
    }),
    null,
  );
  assert.equal(
    gitOptional(["status"], {
      trim: false,
      spawn: () => ({ status: 0, stdout: " M file.mjs\n", stderr: "" }),
    }),
    " M file.mjs",
  );
});

test("git hands a failed call's exit status and output on the error, and both helpers pass a timeout through", () => {
  const failed = { status: 1, stdout: "partial\n", stderr: "no match\n" };
  assert.throws(
    () => git(["grep", "x"], { spawn: () => failed }),
    (error) => error.status === 1 && error.stdout === "partial\n" && error.stderr === "no match\n",
  );
  const seen = [];
  const spawn = (_cmd, _args, opts) => {
    seen.push(opts);
    return { status: 0, stdout: "ok\n", stderr: "" };
  };
  git(["status"], { spawn, timeout: 3000 });
  gitOptional(["status"], { spawn, timeout: 3000 });
  git(["status"], { spawn });
  assert.deepEqual(
    seen.map((opts) => opts.timeout),
    [3000, 3000, undefined],
  );
  assert.deepEqual(
    seen.map((opts) => opts.env.GIT_OPTIONAL_LOCKS),
    ["0", "0", undefined],
  );
  const spawnError = Object.assign(new Error("spawnSync git ETIMEDOUT"), { code: "ETIMEDOUT" });
  assert.throws(
    () => git(["status"], { spawn: () => ({ status: null, error: spawnError }) }),
    /ETIMEDOUT/,
  );
  assert.equal(
    gitOptional(["status"], { spawn: () => ({ status: null, error: spawnError }) }),
    null,
  );
});

test("a git call that passes its time limit stops a child that ignores the first stop signal, and the caller returns", () => {
  const standIn = 'trap "" TERM; echo $$; sleep 5 </dev/null >/dev/null 2>&1';
  const ran = [];
  const spawn = (_cmd, _args, opts) => {
    const result = spawnSync("/bin/sh", ["-c", standIn], opts);
    ran.push(result);
    return result;
  };
  assert.throws(() => git(["fetch"], { spawn, timeout: 500 }), /ETIMEDOUT/);
  assert.equal(gitOptional(["fetch"], { spawn, timeout: 500 }), null);
  assert.equal(ran.length, 2);
  for (const result of ran) {
    assert.equal(result.signal, "SIGKILL");
    const pid = Number(result.stdout.trim());
    assert.ok(
      Number.isInteger(pid) && pid > 0,
      `the stand-in printed no process id: ${result.stdout}`,
    );
    assert.equal(processLive(pid), false);
  }
});

test("a git status with a time limit leaves the index as it was, so a kill cannot leave its lock", () => {
  const dir = makeTempRepo();
  try {
    const index = path.join(dir, ".git/index");
    const stale = () => {
      const later = new Date(Date.now() + 60_000);
      utimesSync(path.join(dir, "sketches/core-loop/src/a.gd"), later, later);
      const before = new Date(Date.now() - 120_000);
      utimesSync(index, before, before);
      return statSync(index).mtimeMs;
    };
    let was = stale();
    assert.equal(gitOptional(["status", "--porcelain"], { cwd: dir, timeout: 10_000 }), "");
    assert.equal(statSync(index).mtimeMs, was, "a timed status wrote the index");
    was = stale();
    assert.equal(gitOptional(["status", "--porcelain"], { cwd: dir }), "");
    assert.notEqual(statSync(index).mtimeMs, was, "an untimed status refreshes the index");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

function fakeGit(body) {
  const bin = realpathSync(mkdtempSync(path.join(os.tmpdir(), "scrapkeep-fake-git-")));
  writeFileSync(path.join(bin, "git"), `#!/bin/sh\necho $$ > "${bin}/pid"\n${body}\n`, {
    mode: 0o755,
  });
  return bin;
}

async function withPath(bin, run) {
  const before = { PATH: process.env.PATH, GIT_DIR: process.env.GIT_DIR };
  process.env.PATH = bin;
  process.env.GIT_DIR = "/elsewhere";
  try {
    return await run();
  } finally {
    for (const [name, value] of Object.entries(before))
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    rmSync(bin, { recursive: true, force: true });
  }
}

test(
  "gitAsync returns what git printed in the repository cwd is in, and fails on a failed, missing or wrongly called git",
  { timeout: 60_000 },
  async () => {
    const bin = fakeGit(
      'if [ "$1" = fail ]; then echo "no such ref" >&2; exit 1; fi\necho "$* in $PWD with ${GIT_DIR-no GIT_DIR}"',
    );
    await withPath(bin, async () => {
      assert.equal(
        await gitAsync(["fetch", "-q"], { cwd: bin }),
        `fetch -q in ${bin} with no GIT_DIR`,
      );
      await assert.rejects(
        gitAsync(["fail"], { cwd: bin }),
        (error) =>
          error.status === 1 &&
          error.stderr === "no such ref\n" &&
          error.message === "git fail failed: no such ref",
      );
      rmSync(path.join(bin, "pid"));
      await assert.rejects(
        gitAsync(["status"], "/some/dir"),
        (error) =>
          error instanceof TypeError &&
          error.message ===
            "gitAsync(args, options): options must be an object such as { cwd }, got a string",
      );
      assert.equal(existsSync(path.join(bin, "pid")), false, "git was started");
      rmSync(path.join(bin, "git"));
      await assert.rejects(gitAsync(["status"], { cwd: bin }), { code: "ENOENT" });
    });
  },
);

test(
  "gitAsync stops a call that passes its limit with SIGTERM, and kills it after the grace only when it stays",
  { timeout: 60_000 },
  async () => {
    assert.equal(GIT_STOP_GRACE_MS, 5000);
    for (const [body, signal] of [
      ["exec /bin/sleep 30", "SIGTERM"],
      ['trap "" TERM\nexec /bin/sleep 30', "SIGKILL"],
    ]) {
      const bin = fakeGit(body);
      await withPath(bin, async () => {
        const started = Date.now();
        const error = await gitAsync(["fetch"], { cwd: bin, timeout: 300, graceMs: 1500 }).then(
          () => assert.fail("a call past its limit returned"),
          (error) => error,
        );
        const ms = Date.now() - started;
        assert.equal(error.signal, signal);
        assert.match(error.message, /^git fetch passed its 300 ms limit/);
        if (signal === "SIGTERM") assert.ok(ms < 1500, `the stop took ${ms} ms`);
        else assert.ok(ms >= 1800, `the kill came after ${ms} ms, before the grace ended`);
        const pid = Number(readFileSync(path.join(bin, "pid"), "utf8"));
        assert.ok(Number.isInteger(pid) && pid > 0, "the stand-in wrote no process id");
        assert.equal(processLive(pid), false);
      });
    }
  },
);

test("nulSeparated reads a -z answer as its paths, keeping spaces and line breaks, and refuses what is not text", () => {
  assert.deepEqual(nulSeparated(' a b\0café "q"\0\0line\nbreak\0'), [
    " a b",
    'café "q"',
    "line\nbreak",
  ]);
  assert.deepEqual(nulSeparated(""), []);
  for (const value of [undefined, null, Buffer.from("a\0")])
    assert.throws(() => nulSeparated(value), TypeError);
});

test("git and gitOptional refuse a second argument that is not an options object, before starting git", () => {
  const bin = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-fake-git-"));
  const marker = path.join(bin, "started");
  writeFileSync(path.join(bin, "git"), `#!/bin/sh\necho "$@" >> "${marker}"\n`, { mode: 0o755 });
  const before = process.env.PATH;
  process.env.PATH = bin;
  try {
    for (const [bad, kind] of [
      ["/some/dir", "a string"],
      [3, "a number"],
      [["/some/dir"], "an array"],
      [null, "null"],
      [new Map(), "a Map"],
      [() => {}, "a function"],
    ]) {
      for (const [name, call] of [
        ["git", git],
        ["gitOptional", gitOptional],
      ]) {
        assert.throws(
          () => call(["status"], bad),
          (error) =>
            error instanceof TypeError &&
            error.message ===
              `${name}(args, options): options must be an object such as { cwd }, got ${kind}`,
        );
      }
    }
    for (const [name, call] of [
      ["gitState", gitState],
      ["cleanHead", cleanHead],
    ]) {
      assert.throws(
        () => call({ cwd: "/some/dir" }),
        (error) =>
          error instanceof TypeError &&
          error.message ===
            `${name}(cwd, options): cwd must be a folder path string, got an object`,
      );
    }
    assert.equal(existsSync(marker), false, "git was started");
    git(["status"], Object.assign(Object.create(null), { cwd: bin }));
    assert.equal(readFileSync(marker, "utf8"), "status\n", "the fake git on PATH did not run");
  } finally {
    if (before === undefined) delete process.env.PATH;
    else process.env.PATH = before;
    rmSync(bin, { recursive: true, force: true });
  }
});

test("gitState and cleanHead report repository state and refuse dirty trees", () => {
  const dir = makeTempRepo();
  const nonRepo = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-nongit-"));
  try {
    assert.equal(gitState(nonRepo), null);
    const state = gitState(dir);
    assert.equal(realpathSync(state.root), realpathSync(dir));
    assert.equal(state.branch, "main");
    assert.equal(state.dirty, false);
    assert.match(state.head, /^[0-9a-f]{40}$/);
    assert.equal(cleanHead(dir), state.head);

    writeFileSync(path.join(dir, "sketches/core-loop/src/untracked.gd"), "extends Node\n");
    assert.throws(() => cleanHead(dir), /untracked files under the game's src or assets/);
    rmSync(path.join(dir, "sketches/core-loop/src/untracked.gd"));

    writeFileSync(path.join(dir, "sketches/core-loop/src/a.gd"), "extends Node\nvar x := 1\n");
    assert.equal(gitState(dir).dirty, true);
    assert.throws(() => cleanHead(dir), /uncommitted changes to tracked files/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
    rmSync(nonRepo, { recursive: true, force: true });
  }
});

const GIT_COMMAND = String.raw`(?:[^"'\`]*?(?:&&|\|\||[;|]|-l?c\s+['"]?))?\s*git\s`;
const STARTS_GIT = new RegExp(
  [
    String.raw`\b[\w$.]+\(\s*["'\`]git["'\`]\s*,`,
    String.raw`\bexec(?:Sync|Async)?\(\s*["'\`]` + GIT_COMMAND,
    String.raw`["'\`]-l?c["'\`]\s*,\s*["'\`]` + GIT_COMMAND,
  ].join("|"),
);

const STARTS_GIT_BY_HAND = {
  "scripts/lib/git.mjs": "the helper itself",
  "scripts/ci/affected.mjs":
    "the CI changes job checks out only scripts/ci and scripts/lib/cli.mjs, so scripts/lib/git.mjs is not on disk when it runs",
  "scripts/sketch-lint.test.mjs": "pull request 1332 holds this file",
};

function filesStartingGit(cwd) {
  const files = nulSeparated(git(["ls-files", "-z", "--", "*.mjs", "*.js"], { cwd, trim: false }));
  if (files.length === 0) throw new Error(`git ls-files lists no .mjs or .js file in ${cwd}`);
  return files.filter((file) => STARTS_GIT.test(readFileSync(path.join(cwd, file), "utf8"))).sort();
}

test("only the allowed files start git by hand; every other script starts it through scripts/lib/git.mjs", () => {
  assert.deepEqual(
    filesStartingGit(REPO_ROOT),
    Object.keys(STARTS_GIT_BY_HAND).sort(),
    "start git with git or gitOptional from scripts/lib/git.mjs, which drops the repository variables a git hook exports so the cwd decides the repository",
  );
});

test("the direct-git listing names a file that starts git by hand and fails on an empty listing or a folder outside git", () => {
  const dir = makeTempRepo();
  const empty = makeTempRepo();
  const outside = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-nongit-"));
  try {
    writeFileSync(path.join(dir, "a.mjs"), 'spawnSync(\n  "git",\n  ["status"],\n);\n');
    writeFileSync(path.join(dir, "b.js"), "execSync(`" + "git rev-parse HEAD`);\n");
    writeFileSync(
      path.join(dir, "c.mjs"),
      [
        'git(["status"]);',
        "throw new Error(`git status failed`);",
        'spawnSync("python3", ["-c", "import git"]);',
        'git(["-c", "user.name=t", "commit"]);',
        'spawnSync("sh", ["-c", "digit status"]);',
        "",
      ].join("\n"),
    );
    const cases = {
      "d.mjs": ["runCmd(", '"git", ["-C", root, "status"]);'],
      "e.mjs": ['spawnSync("sh", ["-c", "', 'git status"]);'],
      "f.mjs": ['spawn("bash", [\n  "-lc",\n  `cd ${dir} && ', "git fetch origin`,\n]);"],
      "g.js": ["execSync(\"bash -lc '", "git status'\");"],
      "h.mjs": ["execSync(`npm ci; ", "git log -1`);"],
    };
    for (const [file, parts] of Object.entries(cases))
      writeFileSync(path.join(dir, file), parts.join("") + "\n");
    const files = ["a.mjs", "b.js", "c.mjs", "d.mjs", "e.mjs", "f.mjs", "g.js", "h.mjs"];
    git(["add", ...files], { cwd: dir });
    assert.deepEqual(
      filesStartingGit(dir),
      files.filter((file) => file !== "c.mjs"),
    );
    assert.throws(() => filesStartingGit(empty), /lists no \.mjs or \.js file/);
    assert.throws(() => filesStartingGit(outside), /not a git repository/i);
  } finally {
    for (const d of [dir, empty, outside]) rmSync(d, { recursive: true, force: true });
  }
});
