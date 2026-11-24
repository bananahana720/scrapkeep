import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { classifyAffected } from "./affected.mjs";

const affectedScript = path.join(path.dirname(fileURLToPath(import.meta.url)), "affected.mjs");

test("full mode and empty changed-file list fail safe to full suite", () => {
  assert.deepEqual(classifyAffected([], { full: true }), {
    full: true,
    lint: true,
    docs: true,
    node: true,
    web: true,
    godot: true,
    changedCount: 0,
  });
  assert.equal(classifyAffected([]).full, true);
});

test("docs-only change skips web build and godot tests", () => {
  const res = classifyAffected(["project-guide/handoff/STATE.md", "README.md"]);
  assert.equal(res.lint, true);
  assert.equal(res.docs, true);
  assert.equal(res.node, false);
  assert.equal(res.web, false);
  assert.equal(res.godot, false);
});

test("godot sketch change triggers godot and node tests without web build", () => {
  const res = classifyAffected(["sketches/core-loop/src/game.gd"]);
  assert.equal(res.godot, true);
  assert.equal(res.node, true);
  assert.equal(res.web, false);
  assert.equal(res.docs, false);
});

test("sitting-kit and weekly.mjs trigger node and docs surfaces", () => {
  assert.equal(classifyAffected(["project-guide/handoff/sitting-kit/serve.mjs"]).node, true);
  assert.equal(classifyAffected(["scripts/gate/weekly.mjs"]).docs, true);
});

test("browser proof change triggers web build and node tests without godot", () => {
  const res = classifyAffected(["src/orchard/simulation.js"]);
  assert.equal(res.web, true);
  assert.equal(res.node, true);
  assert.equal(res.godot, false);
});

test("CLI --stdin writes github-output and rejects unknown arguments", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "affected-test-"));
  const out = path.join(tmp, "out.txt");
  try {
    const ran = spawnSync(process.execPath, [affectedScript, "--stdin", "--github-output", out], {
      input: "sketches/core-loop/src/game.gd\nREADME.md\n",
      encoding: "utf8",
    });
    assert.equal(ran.status, 0, ran.stderr);
    const parsed = JSON.parse(ran.stdout.trim());
    assert.equal(parsed.godot, true);
    assert.equal(parsed.docs, true);
    assert.equal(parsed.web, false);
    assert.match(readFileSync(out, "utf8"), /godot=true/);

    const bad = spawnSync(process.execPath, [affectedScript, "--bogus"], { encoding: "utf8" });
    assert.equal(bad.status, 2);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
