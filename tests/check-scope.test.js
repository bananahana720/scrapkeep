import test, { describe } from "node:test";
import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { execFile } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { git as runGit } from "../scripts/lib/git.mjs";

const execFileAsync = promisify(execFile);
const CONCURRENCY = Math.max(2, Math.min(os.availableParallelism(), 8));

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const cases = JSON.parse(
  await readFile(path.join(root, "tests/fixtures/check-scope/cases.json"), "utf8"),
);

const basePackage = {
  name: "fixture",
  private: true,
  scripts: { test: "node --test tests/*.test.js" },
  dependencies: { three: "^0.180.0" },
};

function packageJson(overrides) {
  return JSON.stringify({ ...basePackage, ...overrides }, null, 2) + "\n";
}

// The shared fixture file states paths only. These scenarios also need file
// content at both revisions, because the tooling-no-build class reads
// package.json to tell a scripts entry from a dependency change.
const contentCases = [
  {
    name: "tooling-no-build for scripts, tests, package.json scripts and docs",
    baseFiles: { "package.json": packageJson() },
    paths: [
      "scripts/check-scope.mjs",
      "tests/check-scope.test.js",
      "package.json",
      "CONTRIBUTING.md",
    ],
    contents: {
      "package.json": packageJson({
        scripts: {
          test: "node --test tests/*.test.js",
          "check:docs": "node scripts/check-docs.mjs",
        },
      }),
    },
    scope: "tooling-no-build",
    commands: ["npm test", "npm run check:docs", "npm run check:project"],
    noBuild: true,
    status: 0,
  },
  {
    name: "a package.json dependency edit as build-requiring tooling",
    baseFiles: { "package.json": packageJson() },
    paths: ["package.json"],
    contents: {
      "package.json": packageJson({ dependencies: { three: "^0.181.0" } }),
    },
    scope: "tooling",
    commands: ["npm run verify"],
    noBuild: true,
    status: 1,
  },
  {
    name: "the lockfile beside tooling paths as build-requiring",
    paths: ["package-lock.json", "scripts/check-scope.mjs"],
    scope: "mixed",
    commands: ["npm run verify"],
    noBuild: true,
    status: 1,
  },
  {
    name: "game and server sources beside tooling paths as build-requiring",
    paths: ["src/orchard/scene.js", "server/index.js", "vite.config.js", "scripts/check-scope.mjs"],
    scope: "mixed",
    commands: ["npm run verify"],
    noBuild: true,
    status: 1,
  },
  {
    name: "a path whose name holds a newline, a leading space and a quote as itself",
    paths: ['docs/ odd "name"\nline.md'],
    scope: "documentation-only",
    commands: ["npm run check:docs", "npm run check:project"],
    noBuild: true,
    status: 0,
    count: 1,
  },
  {
    name: "documentation-only",
    paths: ["docs/design/loops.md", "README.md"],
    scope: "documentation-only",
    commands: ["npm run check:docs", "npm run check:project"],
    noBuild: true,
    status: 0,
  },
  {
    name: "tooling-no-build alongside configuration and docs",
    paths: [
      "GEMINI.md",
      ".agents/hooks.json",
      "scripts/check-scope.mjs",
      "tests/antigravity-hooks.test.js",
      "tests/fixtures/check-scope/cases.json",
    ],
    scope: "tooling-no-build",
    commands: [
      "npm test",
      "npm run check:docs",
      "npm run check:project",
      "scenario review of the changed instructions or configuration against ORCHESTRATOR.md and AGENTS.md",
    ],
    noBuild: true,
    status: 0,
  },
];

async function git(cwd, ...args) {
  return runGit(["-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid", ...args], {
    cwd,
  });
}

async function commit(cwd, message) {
  await git(cwd, "add", "-A");
  await git(cwd, "-c", "commit.gpgsign=false", "commit", "-q", "--allow-empty", "-m", message);
  return git(cwd, "rev-parse", "HEAD");
}

async function write(cwd, file, content) {
  await mkdir(path.join(cwd, path.dirname(file)), { recursive: true });
  await writeFile(path.join(cwd, file), content);
}

async function runScope(args) {
  try {
    const { stdout, stderr } = await execFileAsync(
      process.execPath,
      [path.join(root, "scripts/check-scope.mjs"), ...args],
      { encoding: "utf8", timeout: 10000 },
    );
    return { status: 0, stdout, stderr };
  } catch (error) {
    assert.equal(error.signal, null, error.message);
    return { status: error.code, stdout: error.stdout ?? "", stderr: error.stderr ?? "" };
  }
}

describe("check-scope", { concurrency: CONCURRENCY }, () => {
  for (const scenario of [...cases, ...contentCases])
    test("check:scope classifies " + scenario.name, async () => {
      const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-scope-"));
      try {
        await git(temporary, "init", "-q");
        for (const [file, content] of Object.entries(scenario.baseFiles ?? {}))
          await write(temporary, file, content);
        const base = await commit(temporary, "base");
        for (const file of scenario.paths)
          await write(temporary, file, scenario.contents?.[file] ?? "x\n");
        const candidate = await commit(temporary, "candidate");
        const child = await runScope([
          "--root",
          temporary,
          base,
          candidate,
          ...(scenario.noBuild ? ["--no-build"] : []),
        ]);
        assert.equal(child.status, scenario.status, child.stdout + child.stderr);
        assert.match(child.stdout, new RegExp("^scope: " + scenario.scope + " ", "m"));
        for (const command of scenario.commands)
          assert.ok(
            child.stdout.includes(command),
            "expected command " + command + "\n" + child.stdout,
          );
        for (const file of scenario.paths) assert.ok(child.stdout.includes(file));
        if (scenario.count !== undefined)
          assert.match(child.stdout, new RegExp(`\\(${scenario.count} changed paths\\)`));
        if (scenario.status === 1) assert.match(child.stdout, /refused: --no-build was given/);
        if (scenario.paths.length === 0) assert.match(child.stdout, /none \(no changed paths\)/);
      } finally {
        await rm(temporary, { recursive: true, force: true });
      }
    });

  test("check:scope rejects a malformed invocation with exit 2", async () => {
    const child = await runScope(["only-one"]);
    assert.equal(child.status, 2);
    assert.match(child.stderr, /Usage/);
  });
});
