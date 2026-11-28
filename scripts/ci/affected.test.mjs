import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { planHookChecks } from "../hooks/pre-push.mjs";
import { cwdDecidesRepository, git } from "../lib/git.mjs";
import { classifyAffected, treeFiles } from "./affected.mjs";

const affectedScript = path.join(path.dirname(fileURLToPath(import.meta.url)), "affected.mjs");

test("full mode and empty changed-file list fail safe to full suite", () => {
  assert.deepEqual(classifyAffected([], { full: true }), {
    full: true,
    lint: true,
    docs: true,
    node: true,
    web: true,
    godot: true,
    godot_shards: 1,
    godot_matrix: "[1]",
    changedCount: 0,
  });
  assert.equal(classifyAffected([]).full, true);
  assert.equal(classifyAffected([]).godot_shards, 1);
  assert.equal(classifyAffected([]).godot_matrix, "[1]");
});

test("docs-only change skips web build and godot tests", () => {
  const res = classifyAffected(["project-guide/handoff/STATE.md", "README.md"]);
  assert.equal(res.lint, true);
  assert.equal(res.docs, true);
  assert.equal(res.node, false);
  assert.equal(res.web, false);
  assert.equal(res.godot, false);
  assert.equal(res.godot_shards, 1);
  assert.equal(res.godot_matrix, "[1]");
});

test("a change to the structure sweep's data files or its checker runs the docs check", () => {
  for (const file of [
    "project-guide/handoff/shared/structure-sweep/pool.tsv",
    "project-guide/handoff/shared/structure-sweep/units.tsv",
    "scripts/structure-sweep.mjs",
  ])
    assert.equal(classifyAffected([file]).docs, true, file);
});

test("godot sketch change triggers godot and node tests without web build", () => {
  const small = classifyAffected(["sketches/core-loop/src/ui/badge.gd"]);
  assert.equal(small.godot, true);
  assert.equal(small.node, true);
  assert.equal(small.web, false);
  assert.equal(small.docs, false);
  assert.equal(small.godot_shards, 1);
  assert.equal(small.godot_matrix, "[1]");

  const hub = classifyAffected(["sketches/core-loop/src/game.gd"]);
  assert.equal(hub.godot, true);
  assert.equal(hub.godot_shards, 2);
  assert.equal(hub.godot_matrix, "[1, 2]");

  const park = classifyAffected(["sketches/core-loop/assets/park/park_dam/lines.json"]);
  assert.equal(park.godot, true);
  assert.equal(park.godot_shards, 2);
  assert.equal(park.godot_matrix, "[1, 2]");

  const sevenFiles = Array.from({ length: 7 }, (_, i) => `sketches/core-loop/src/ui/item_${i}.gd`);
  assert.equal(classifyAffected(sevenFiles).godot_shards, 1);
  assert.equal(classifyAffected(sevenFiles).godot_matrix, "[1]");

  const eightFiles = Array.from({ length: 8 }, (_, i) => `sketches/core-loop/src/ui/item_${i}.gd`);
  assert.equal(classifyAffected(eightFiles).godot_shards, 2);
  assert.equal(classifyAffected(eightFiles).godot_matrix, "[1, 2]");
});

test("sitting-kit and weekly.mjs trigger node and docs surfaces", () => {
  assert.equal(classifyAffected(["project-guide/handoff/sitting-kit/serve.mjs"]).node, true);
  assert.equal(classifyAffected(["scripts/gate/weekly.mjs"]).docs, true);
});

test("agent configs, hooks, codex definitions, and check-agents.mjs trigger docs surface", () => {
  for (const file of [
    ".agents/hooks.json",
    ".agents/hooks/safety-gate.mjs",
    ".claude/settings.json",
    ".codex/agents/scrapkeep-writer.toml",
    "scripts/check-agents.mjs",
  ]) {
    const res = classifyAffected([file]);
    assert.equal(res.docs, true, `Expected docs=true for ${file}`);
    assert.equal(res.lint, true, `Expected lint=true for ${file}`);
    assert.equal(res.godot, false, `Expected godot=false for ${file}`);
    assert.equal(res.web, false, `Expected web=false for ${file}`);
  }
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
    assert.match(readFileSync(out, "utf8"), /godot_shards=2/);
    assert.match(readFileSync(out, "utf8"), /godot_matrix=\[1, 2\]/);

    const bad = spawnSync(process.execPath, [affectedScript, "--bogus"], { encoding: "utf8" });
    assert.equal(bad.status, 2);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test("a changed path gone from the tree selects the docs check, in CI and in the pre-push hook", () => {
  for (const file of ["scripts/linked.mjs", "sketches/core-loop/tools/linked.gd"]) {
    assert.equal(classifyAffected([file], { exists: () => false }).docs, true, file);
    assert.equal(planHookChecks([file], () => false).hasDocsOrPkg, true, file);
    assert.equal(classifyAffected([file], { exists: () => true }).docs, false, file);
    assert.equal(planHookChecks([file], () => true).hasDocsOrPkg, false, file);
  }
});

function selector(cwd, input) {
  return spawnSync(process.execPath, [affectedScript, "--stdin"], {
    cwd,
    env: cwdDecidesRepository(),
    input,
    encoding: "utf8",
  });
}

test("CLI --stdin selects the docs check when a change deletes a script a page links to", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "affected-deleted-"));
  try {
    git(["init", "-q"], { cwd: tmp });
    mkdirSync(path.join(tmp, "scripts"));
    writeFileSync(path.join(tmp, "README.md"), "[tool](scripts/linked.mjs)\n");
    writeFileSync(path.join(tmp, "scripts/linked.mjs"), "\n");
    writeFileSync(path.join(tmp, "scripts/kept.mjs"), "\n");
    const commit = ["-c", "user.name=t", "-c", "user.email=t@example.invalid", "commit", "-qm"];
    git(["add", "."], { cwd: tmp });
    git([...commit, "one"], { cwd: tmp });
    git(["rm", "-q", "scripts/linked.mjs"], { cwd: tmp });
    git([...commit, "two"], { cwd: tmp });
    const deleted = selector(tmp, "scripts/linked.mjs\n");
    assert.equal(deleted.status, 0, deleted.stderr);
    assert.equal(JSON.parse(deleted.stdout).docs, true);
    const edited = selector(tmp, "scripts/kept.mjs\n");
    assert.equal(edited.status, 0, edited.stderr);
    assert.equal(JSON.parse(edited.stdout).docs, false);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test("CLI --stdin fails when git cannot list the head tree or it lists nothing", () => {
  const plain = mkdtempSync(path.join(os.tmpdir(), "affected-plain-"));
  const empty = mkdtempSync(path.join(os.tmpdir(), "affected-empty-"));
  try {
    const notRepo = selector(plain, "scripts/kept.mjs\n");
    assert.equal(notRepo.status, 2);
    assert.match(notRepo.stderr, /git ls-tree HEAD failed/);
    git(["init", "-q"], { cwd: empty });
    const unborn = selector(empty, "scripts/kept.mjs\n");
    assert.equal(unborn.status, 2);
    assert.match(unborn.stderr, /git ls-tree HEAD failed/);
    git(
      [
        "-c",
        "user.name=t",
        "-c",
        "user.email=t@example.invalid",
        "commit",
        "-q",
        "--allow-empty",
        "-m",
        "none",
      ],
      { cwd: empty },
    );
    const bare = selector(empty, "scripts/kept.mjs\n");
    assert.equal(bare.status, 2);
    assert.match(bare.stderr, /git ls-tree HEAD lists no files/);
  } finally {
    rmSync(plain, { recursive: true, force: true });
    rmSync(empty, { recursive: true, force: true });
  }
});

test("treeFiles reads each listed path with its mode and refuses an entry it cannot read", () => {
  const oid = "a".repeat(40);
  const listing =
    (...entries) =>
    () => ({ status: 0, stdout: entries.join("\0") + "\0" });
  const files = treeFiles("HEAD", {
    spawn: listing(`100644 blob ${oid}\tREADME.md`, `120000 blob ${oid}\tscripts/a b\nc.mjs`),
  });
  assert.deepEqual(
    [...files],
    [
      ["README.md", "100644"],
      ["scripts/a b\nc.mjs", "120000"],
    ],
  );
  for (const entry of [
    `100644 blob ${oid}\t`,
    "100644\tREADME.md",
    `100644 ${oid}\tREADME.md`,
    `10064 blob ${oid}\tREADME.md`,
    `100644 blob ${oid} README.md`,
    `100644 blob ${oid.slice(1)}\tREADME.md`,
  ])
    assert.throws(
      () => treeFiles("HEAD", { spawn: listing(entry) }),
      /git ls-tree HEAD gave an entry it cannot read/,
      JSON.stringify(entry),
    );
});
