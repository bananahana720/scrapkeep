import test from "node:test";
import assert from "node:assert/strict";
import {
  copyFile,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  rm,
  writeFile,
} from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

test("verification stops after a failing child and records the nonzero result", async () => {
  const temporary = await mkdtemp(
    path.join(os.tmpdir(), "scrapkeep-verify-test-"),
  );
  try {
    for (const directory of ["src", "server", "scripts", "tests"])
      await mkdir(path.join(temporary, directory));
    for (const file of [
      "package.json",
      "package-lock.json",
      "vite.config.js",
      "index.html",
      "orchard.html",
    ])
      await writeFile(path.join(temporary, file), "{}");
    await copyFile(
      path.join(root, "scripts/verify.mjs"),
      path.join(temporary, "scripts/verify.mjs"),
    );
    const failure = path.join(temporary, "failing-npm.mjs");
    await writeFile(
      failure,
      'process.stderr.write("controlled failure"); process.exit(23);',
    );
    const child = spawnSync(
      process.execPath,
      [path.join(temporary, "scripts/verify.mjs")],
      {
        env: { ...process.env, npm_execpath: failure },
        encoding: "utf8",
        timeout: 10000,
      },
    );
    assert.equal(child.error, undefined);
    assert.equal(child.status, 1);
    const report = JSON.parse(
      await readFile(
        path.join(temporary, "artifacts/local/verify/report.json"),
        "utf8",
      ),
    );
    assert.equal(report.result, "fail");
    assert.equal(report.stages.length, 1);
    assert.equal(report.stages[0].exitCode, 23);
    assert.equal(report.stages[0].name, "project");
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

for (const customOutput of [false, true]) {
  test(
    "lead browser startup failure closes resources with " +
      (customOutput ? "custom" : "default") +
      " output",
    async () => {
      const temporary = await mkdtemp(
        path.join(os.tmpdir(), "scrapkeep-browser-startup-test-"),
      );
      try {
        const storageRoot = path.join(temporary, "tmp");
        await mkdir(storageRoot);
        const env = {
          ...process.env,
          TMPDIR: storageRoot,
          CAPTURE_ENABLED: "true",
          CHROMIUM_PATH: path.join(temporary, "missing-browser"),
        };
        if (customOutput) env.ARTIFACT_DIR = path.join(temporary, "output");
        else delete env.ARTIFACT_DIR;
        const child = spawnSync(
          process.execPath,
          [path.join(root, "tests/lead-browser.mjs")],
          {
            cwd: root,
            env,
            encoding: "utf8",
            timeout: 10000,
          },
        );
        assert.equal(
          child.error,
          undefined,
          "startup must exit instead of leaving the server running",
        );
        assert.notEqual(child.status, 0);
        assert.doesNotMatch(child.stderr, /ReferenceError/);
        assert.match(
          child.stderr,
          /executable|doesn't exist|not exist/i,
          "failure must reach the controlled missing-browser launch",
        );
        const remains = await readdir(storageRoot);
        assert.deepEqual(
          remains.filter((name) => name.startsWith("scrapkeep-browser-leads-")),
          [],
        );
      } finally {
        // Only this test's owned sandbox, including any provider-created profiles.
        await rm(temporary, { recursive: true, force: true });
      }
    },
  );
}
