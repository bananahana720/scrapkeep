import test from "node:test";
import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const cases = JSON.parse(
  await readFile(
    path.join(root, "tests/fixtures/check-scope/cases.json"),
    "utf8",
  ),
);

function git(cwd, ...args) {
  const child = spawnSync("git", args, {
    cwd,
    encoding: "utf8",
    env: {
      ...process.env,
      GIT_AUTHOR_NAME: "fixture",
      GIT_AUTHOR_EMAIL: "fixture@example.invalid",
      GIT_COMMITTER_NAME: "fixture",
      GIT_COMMITTER_EMAIL: "fixture@example.invalid",
    },
  });
  assert.equal(child.status, 0, child.stderr);
  return child.stdout.trim();
}

for (const scenario of cases)
  test("check:scope classifies " + scenario.name, async () => {
    const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-scope-"));
    try {
      git(temporary, "init", "-q");
      git(
        temporary,
        "-c",
        "commit.gpgsign=false",
        "commit",
        "-q",
        "--allow-empty",
        "-m",
        "base",
      );
      const base = git(temporary, "rev-parse", "HEAD");
      for (const file of scenario.paths) {
        await mkdir(path.join(temporary, path.dirname(file)), {
          recursive: true,
        });
        await writeFile(path.join(temporary, file), "x\n");
      }
      git(temporary, "add", "-A");
      git(
        temporary,
        "-c",
        "commit.gpgsign=false",
        "commit",
        "-q",
        "--allow-empty",
        "-m",
        "candidate",
      );
      const candidate = git(temporary, "rev-parse", "HEAD");
      const child = spawnSync(
        process.execPath,
        [
          path.join(root, "scripts/check-scope.mjs"),
          "--root",
          temporary,
          base,
          candidate,
          ...(scenario.noBuild ? ["--no-build"] : []),
        ],
        { encoding: "utf8", timeout: 10000 },
      );
      assert.equal(child.error, undefined);
      assert.equal(child.status, scenario.status, child.stdout + child.stderr);
      assert.match(
        child.stdout,
        new RegExp("^scope: " + scenario.scope + " ", "m"),
      );
      for (const command of scenario.commands)
        assert.ok(
          child.stdout.includes(command),
          "expected command " + command + "\n" + child.stdout,
        );
      for (const file of scenario.paths) assert.ok(child.stdout.includes(file));
      if (scenario.status === 1)
        assert.match(child.stdout, /refused: --no-build was given/);
      if (scenario.paths.length === 0)
        assert.match(child.stdout, /none \(no changed paths\)/);
    } finally {
      await rm(temporary, { recursive: true, force: true });
    }
  });

test("check:scope rejects a malformed invocation with exit 2", () => {
  const child = spawnSync(
    process.execPath,
    [path.join(root, "scripts/check-scope.mjs"), "only-one"],
    { encoding: "utf8", timeout: 10000 },
  );
  assert.equal(child.status, 2);
  assert.match(child.stderr, /Usage/);
});
