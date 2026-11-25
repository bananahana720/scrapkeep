import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import { evaluateHook } from "../.agents/hooks/safety-gate.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const hookScript = path.join(root, ".agents/hooks/safety-gate.mjs");

function runHookCli(payloadOrRaw) {
  const input = typeof payloadOrRaw === "string" ? payloadOrRaw : JSON.stringify(payloadOrRaw);
  const child = spawnSync(process.execPath, [hookScript], { input, encoding: "utf8" });
  assert.equal(child.status, 0, child.stderr);
  return JSON.parse(child.stdout);
}

test("denies force pushes (including with git -C / global flags), npm publish, gh repo delete, and live Godot save access", () => {
  for (const cmd of [
    "git push --force origin feat",
    "git -C some-dir push --force origin feat",
    "git --no-pager push -f origin feat",
    "git push -fu origin feat",
    "git push origin +main",
    "npm publish",
    "gh repo delete owner/repo",
    "rm -rf ~/.local/share/godot/app_userdata/core-loop/save.json",
  ]) {
    const res = evaluateHook({
      toolCall: { name: "run_command", args: { CommandLine: cmd } },
      cwd: root,
    });
    assert.equal(res.decision, "deny", `Expected deny for: ${cmd}`);
  }

  for (const [toolName, key] of [
    ["edit_file", "Path"],
    ["write_file", "Path"],
    ["write_to_file", "TargetFile"],
    ["replace_file_content", "TargetFile"],
    ["multi_replace_file_content", "AbsolutePath"],
  ]) {
    const res = evaluateHook({
      toolCall: {
        name: toolName,
        args: { [key]: "/home/andrew/.local/share/godot/app_userdata/core-loop/settings.cfg" },
      },
      cwd: root,
    });
    assert.equal(res.decision, "deny", `Expected deny for ${toolName} (${key}) on live save`);
  }
});

test("denies git commit (including relative git -C and chained git add && git commit) when McpBridge is in project.godot", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-hook-"));
  const sub = path.join(tmp, "repo");
  try {
    const git = (...args) => {
      const r = spawnSync("git", args, {
        cwd: sub,
        encoding: "utf8",
        env: {
          ...process.env,
          GIT_AUTHOR_NAME: "Test",
          GIT_AUTHOR_EMAIL: "test@example.invalid",
          GIT_COMMITTER_NAME: "Test",
          GIT_COMMITTER_EMAIL: "test@example.invalid",
        },
      });
      assert.equal(r.status, 0, r.stderr);
      return r.stdout;
    };
    mkdirSync(path.join(sub, "sketches/core-loop"), { recursive: true });
    git("init", "-q");
    writeFileSync(
      path.join(sub, "sketches/core-loop/project.godot"),
      '[autoload]\nMcpBridge="*res://addons/mcp/bridge.gd"\n',
    );

    // Chained `git add -A && git commit` catches McpBridge in working tree before staging.
    const chained = runHookCli({
      toolCall: {
        name: "run_command",
        args: { CommandLine: 'git add -A && git commit -m "chained"' },
      },
      cwd: sub,
    });
    assert.equal(chained.decision, "deny");
    assert.match(chained.reason, /McpBridge/);

    // Combined `-am` stages modified tracked files like project.godot without `git add`.
    const amCommit = runHookCli({
      toolCall: { name: "run_command", args: { CommandLine: 'git commit -am "combined"' } },
      cwd: sub,
    });
    assert.equal(amCommit.decision, "deny");
    assert.match(amCommit.reason, /McpBridge/);

    // Explicit pathspec `git commit project.godot` or `--pathspec-from-file` reads working tree without `-a`.
    const pathspecCommit = runHookCli({
      toolCall: {
        name: "run_command",
        args: { CommandLine: 'git commit -m "pathspec" -- sketches/core-loop/project.godot' },
      },
      cwd: sub,
    });
    assert.equal(pathspecCommit.decision, "deny");
    assert.match(pathspecCommit.reason, /McpBridge/);

    for (const cmd of [
      'git commit -m "pf-eq" --pathspec-from-file=paths.txt',
      'git commit -m "pf-sp" --pathspec-from-file paths.txt',
    ]) {
      const pfCommit = runHookCli({
        toolCall: { name: "run_command", args: { CommandLine: cmd } },
        cwd: sub,
      });
      assert.equal(pfCommit.decision, "deny", `Expected deny for: ${cmd}`);
      assert.match(pfCommit.reason, /McpBridge/);
    }

    // Relative `git -C repo commit` AND subdirectory cwd (`sketches/core-loop`) catch staged McpBridge.
    git("add", "sketches/core-loop/project.godot");
    const relCommit = runHookCli({
      toolCall: { name: "run_command", args: { CommandLine: 'git -C repo commit -m "rel"' } },
      cwd: tmp,
    });
    assert.equal(relCommit.decision, "deny");
    assert.match(relCommit.reason, /McpBridge/);

    const subdirCommit = runHookCli({
      toolCall: { name: "run_command", args: { CommandLine: 'git commit -m "from-subdir"' } },
      cwd: path.join(sub, "sketches/core-loop"),
    });
    assert.equal(subdirCommit.decision, "deny");
    assert.match(subdirCommit.reason, /McpBridge/);

    writeFileSync(
      path.join(sub, "sketches/core-loop/project.godot"),
      '[application]\nconfig/name="core-loop"\n',
    );
    git("add", "sketches/core-loop/project.godot");

    const allowed = runHookCli({
      toolCall: { name: "run_command", args: { CommandLine: 'git -C repo commit -m "clean"' } },
      cwd: tmp,
    });
    assert.equal(allowed.decision, "allow");
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test("prompts (ask) on pushes to main, global-flag reset/branch, package mutations, gh repo/api, package.json edits, and bad stdin", () => {
  for (const cmd of [
    "git push",
    "git push origin main",
    "git -C repo push -u origin main",
    "git push origin HEAD:main",
    "npm install foo",
    "npm i bar",
    "npm uninstall baz",
    "gh api repos/owner/repo",
    "gh repo view owner/repo",
    "git -C repo reset --hard HEAD~1",
    "git push origin --delete feat",
    "git push origin -ud feat",
    "git push origin :feat",
    "git -c core.autocrlf=false branch -D old-branch",
    "git branch -f moved-branch HEAD~1",
    "git branch -d --force old-branch",
    "git branch -M renamed-branch",
    "git branch -C copied-branch",
    "git branch -vM renamed-branch",
  ]) {
    const res = evaluateHook({
      toolCall: { name: "run_command", args: { CommandLine: cmd } },
      cwd: root,
    });
    assert.equal(res.decision, "ask", `Expected ask for: ${cmd}`);
  }

  for (const [toolName, key] of [
    ["edit_file", "Path"],
    ["replace_file_content", "TargetFile"],
  ]) {
    const pkgEdit = evaluateHook({
      toolCall: { name: toolName, args: { [key]: "/repo/sketches/core-loop/package.json" } },
      cwd: root,
    });
    assert.equal(pkgEdit.decision, "ask");
  }

  const badJson = runHookCli("{not valid json");
  assert.equal(badJson.decision, "ask");
});

test("allows safe commands and edits including npm ci and feature-branch pushes", () => {
  for (const cmd of [
    "npm ci",
    "npm run check:docs",
    "git push -u origin aifirstify_repo_gemini_workflows",
    "git -C repo status -sb",
  ]) {
    const res = runHookCli({
      toolCall: { name: "run_command", args: { CommandLine: cmd } },
      cwd: root,
    });
    assert.equal(res.decision, "allow", `Expected allow for: ${cmd}`);
  }

  const safeEdit = runHookCli({
    toolCall: { name: "edit_file", args: { Path: path.join(root, "GEMINI.md") } },
    cwd: root,
  });
  assert.equal(safeEdit.decision, "allow");
});
