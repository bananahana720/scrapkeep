import assert from "node:assert/strict";
import test from "node:test";
import {
  executionFailures,
  exportFailures,
  run,
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
