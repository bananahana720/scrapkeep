import assert from "node:assert/strict";
import test from "node:test";
import { createHash } from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {
  executionFailures,
  exportFailures,
  godotEnvironment,
  run,
  templateCheck,
} from "../scripts/native-smoke.mjs";

const passMarker = /^SCRAPKEEP_INTEGRATION STAGE PASS$/m;
const execute = (source, options) =>
  run(process.execPath, ["-e", source], options);

test("accepts an actual process with the required marker and expected exit", () => {
  const result = execute('console.log("SCRAPKEEP_INTEGRATION STAGE PASS")');
  assert.deepEqual(
    executionFailures(result, { requiredMarker: passMarker }),
    [],
  );
});

test("rejects a successful process without its success marker", () => {
  const result = execute('console.log("booted")');
  assert.match(
    executionFailures(result, { requiredMarker: passMarker }).join(" "),
    /required marker absent/,
  );
});

test("rejects timeout even when the child printed success first", () => {
  const result = execute(
    'console.log("SCRAPKEEP_INTEGRATION STAGE PASS"); setInterval(() => {}, 1000)',
    { timeout: 200 },
  );
  assert.equal(result.error.code, "ETIMEDOUT");
  assert.match(
    executionFailures(result, { requiredMarker: passMarker }).join(" "),
    /ETIMEDOUT/,
  );
});

test("rejects script errors despite a success marker and zero exit", () => {
  const result = execute(
    'console.log("SCRAPKEEP_INTEGRATION STAGE PASS"); console.error("SCRIPT ERROR: bad type")',
  );
  assert.match(
    executionFailures(result, { requiredMarker: passMarker }).join(" "),
    /engine script error/,
  );
});

test("requires the injected fault exit code and marker together", () => {
  const requiredMarker = /^SCRAPKEEP_INTEGRATION STAGE FAIL$/m;
  const caught = execute(
    'console.log("SCRAPKEEP_INTEGRATION STAGE FAIL"); process.exitCode = 1',
  );
  assert.deepEqual(
    executionFailures(caught, { expectedCode: 1, requiredMarker }),
    [],
  );
  const ignored = execute('console.log("SCRAPKEEP_INTEGRATION STAGE FAIL")');
  assert.match(
    executionFailures(ignored, { expectedCode: 1, requiredMarker }).join(" "),
    /expected exit 1/,
  );
});

test("failed export cannot pass because an output file exists", () => {
  const result = execute("process.exitCode = 1");
  assert.match(
    exportFailures(result, { size: 100, sha256: "a".repeat(64) }).join(" "),
    /expected exit 0/,
  );
});

test("export refuses missing, empty and unhashed files", () => {
  const result = execute("");
  for (const artifact of [
    null,
    { size: 0, sha256: "a".repeat(64) },
    { size: 100, sha256: "" },
  ]) {
    assert.match(
      exportFailures(result, artifact).join(" "),
      /missing, empty or unhashed/,
    );
  }
});

test("export error text cannot pass on zero exit", () => {
  const result = execute('console.error("ERROR: export failed")');
  assert.match(
    exportFailures(result, { size: 100, sha256: "a".repeat(64) }).join(" "),
    /engine export\/import error/,
  );
});

test("missing executable is a failed execution with a retained command", () => {
  const result = run("/nonexistent/scrapkeep-smoke-binary", []);
  assert.equal(result.error.code, "ENOENT");
  assert.deepEqual(result.command, ["/nonexistent/scrapkeep-smoke-binary"]);
  assert.match(executionFailures(result).join(" "), /ENOENT/);
});

test("rejects a replaced consumed template even when the file remains nonempty", async (t) => {
  const directory = await mkdtemp(
    path.join(os.tmpdir(), "scrapkeep-template-test-"),
  );
  t.after(() => rm(directory, { recursive: true, force: true }));
  const file = path.join(directory, "version.txt");
  const inspect = async () => {
    const bytes = await readFile(file);
    return templateCheck("version.txt", {
      size: bytes.length,
      sha256: createHash("sha256").update(bytes).digest("hex"),
    });
  };
  await writeFile(file, "4.7.2.stable\n");
  assert.equal((await inspect()).status, "pass");
  await writeFile(file, "4.7.2.stable\nappended replacement marker\n");
  const replacement = await inspect();
  assert.equal(replacement.status, "fail");
  assert.notEqual(replacement.actualSha256, replacement.expectedSha256);
});

test("child process writes settings into its run instead of inherited user config", async (t) => {
  const directory = await mkdtemp(
    path.join(os.tmpdir(), "scrapkeep-config-test-"),
  );
  t.after(() => rm(directory, { recursive: true, force: true }));
  const inheritedConfig = path.join(directory, "owner-config");
  const inherited = {
    ...process.env,
    XDG_CONFIG_HOME: inheritedConfig,
    XDG_DATA_HOME: "/owner-data",
    XDG_CACHE_HOME: "/owner-cache",
  };
  const runDirectory = path.join(directory, "run");
  const env = godotEnvironment(runDirectory, inherited);
  const child = execute(
    'const fs = require("node:fs"); fs.mkdirSync(process.env.XDG_CONFIG_HOME, {recursive:true}); fs.writeFileSync(process.env.XDG_CONFIG_HOME + "/settings", "isolated");',
    { env },
  );
  assert.deepEqual(executionFailures(child), []);
  assert.equal(
    await readFile(path.join(runDirectory, "config/settings"), "utf8"),
    "isolated",
  );
  await assert.rejects(readFile(path.join(inheritedConfig, "settings")), {
    code: "ENOENT",
  });
  assert.equal(env.XDG_DATA_HOME, path.join(runDirectory, "user-data"));
  assert.equal(env.XDG_CACHE_HOME, path.join(runDirectory, "cache"));
  assert.equal(inherited.XDG_CONFIG_HOME, inheritedConfig);
});
