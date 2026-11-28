import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, test } from "node:test";
import { fileURLToPath } from "node:url";

import { defaultInspectProjectGodot, evaluateHook } from "../.agents/hooks/safety-gate.mjs";
import { git as runGit } from "../scripts/lib/git.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const hookScript = path.join(root, ".agents/hooks/safety-gate.mjs");
const CONCURRENCY = Math.max(2, Math.min(os.availableParallelism(), 8));

function runHookCli(payloadOrRaw, script = hookScript) {
  const input = typeof payloadOrRaw === "string" ? payloadOrRaw : JSON.stringify(payloadOrRaw);
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [script], { stdio: ["pipe", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (c) => (stdout += c));
    child.stderr.on("data", (c) => (stderr += c));
    child.on("error", reject);
    child.on("close", (status) => {
      try {
        assert.equal(status, 0, stderr);
        assert.match(stdout, /^[^\n]+\n$/, "the hook prints exactly one line");
        resolve(JSON.parse(stdout));
      } catch (err) {
        reject(err);
      }
    });
    child.stdin.end(input);
  });
}

describe("antigravity-hooks", { concurrency: CONCURRENCY }, () => {
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

  test("denies git commit (including relative git -C and chained git add && git commit) when McpBridge is in project.godot", async () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-hook-"));
    const sub = path.join(tmp, "repo");
    try {
      const git = (...args) =>
        runGit(["-c", "user.name=Test", "-c", "user.email=test@example.invalid", ...args], {
          cwd: sub,
          trim: false,
        });
      mkdirSync(path.join(sub, "sketches/core-loop"), { recursive: true });
      git("init", "-q");
      writeFileSync(
        path.join(sub, "sketches/core-loop/project.godot"),
        '[autoload]\nMcpBridge="*res://addons/mcp/bridge.gd"\n',
      );

      const pfCmds = [
        'git commit -m "pf-eq" --pathspec-from-file=paths.txt',
        'git commit -m "pf-sp" --pathspec-from-file paths.txt',
      ];
      const [chained, amCommit, pathspecCommit, ...pfCommits] = await Promise.all([
        runHookCli({
          toolCall: {
            name: "run_command",
            args: { CommandLine: 'git add -A && git commit -m "chained"' },
          },
          cwd: sub,
        }),
        runHookCli({
          toolCall: { name: "run_command", args: { CommandLine: 'git commit -am "combined"' } },
          cwd: sub,
        }),
        runHookCli({
          toolCall: {
            name: "run_command",
            args: { CommandLine: 'git commit -m "pathspec" -- sketches/core-loop/project.godot' },
          },
          cwd: sub,
        }),
        ...pfCmds.map((cmd) =>
          runHookCli({
            toolCall: { name: "run_command", args: { CommandLine: cmd } },
            cwd: sub,
          }),
        ),
      ]);
      assert.equal(chained.decision, "deny");
      assert.match(chained.reason, /McpBridge/);
      assert.equal(amCommit.decision, "deny");
      assert.match(amCommit.reason, /McpBridge/);
      assert.equal(pathspecCommit.decision, "deny");
      assert.match(pathspecCommit.reason, /McpBridge/);
      for (let i = 0; i < pfCmds.length; i++) {
        assert.equal(pfCommits[i].decision, "deny", `Expected deny for: ${pfCmds[i]}`);
        assert.match(pfCommits[i].reason, /McpBridge/);
      }

      git("add", "sketches/core-loop/project.godot");
      const [relCommit, subdirCommit] = await Promise.all([
        runHookCli({
          toolCall: { name: "run_command", args: { CommandLine: 'git -C repo commit -m "rel"' } },
          cwd: tmp,
        }),
        runHookCli({
          toolCall: { name: "run_command", args: { CommandLine: 'git commit -m "from-subdir"' } },
          cwd: path.join(sub, "sketches/core-loop"),
        }),
      ]);
      assert.equal(relCommit.decision, "deny");
      assert.match(relCommit.reason, /McpBridge/);
      assert.equal(subdirCommit.decision, "deny");
      assert.match(subdirCommit.reason, /McpBridge/);

      writeFileSync(
        path.join(sub, "sketches/core-loop/project.godot"),
        '[application]\nconfig/name="core-loop"\n',
      );
      git("add", "sketches/core-loop/project.godot");

      const allowed = await runHookCli({
        toolCall: { name: "run_command", args: { CommandLine: 'git -C repo commit -m "clean"' } },
        cwd: tmp,
      });
      assert.equal(allowed.decision, "allow");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  test("prompts (ask) on pushes to main, global-flag reset/branch, package mutations, gh repo/api, package.json edits, and bad stdin", async () => {
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

    const badJson = await runHookCli("{not valid json");
    assert.equal(badJson.decision, "ask");
  });

  test("allows safe commands and edits including npm ci, scratch Godot save paths under artifacts/local/, and feature-branch pushes", async () => {
    const safeCmds = [
      "npm ci",
      "npm run check:docs",
      "git push -u origin aifirstify_repo_gemini_workflows",
      "git -C repo status -sb",
      "cat artifacts/local/verify-game/run1/.local/share/godot/app_userdata/core-loop/profile.json",
      "XDG_DATA_HOME=/repo/artifacts/local/home ls /repo/artifacts/local/home/.local/share/godot/app_userdata/core-loop",
    ];
    const scratchPaths = [
      path.join(root, "GEMINI.md"),
      path.join(
        root,
        "artifacts/local/verify-game/run1/.local/share/godot/app_userdata/core-loop/profile.json",
      ),
      "artifacts/local/test-home/.local/share/godot/app_userdata/core-loop/settings.cfg",
    ];
    const [cmdResults, editResults] = await Promise.all([
      Promise.all(
        safeCmds.map((cmd) =>
          runHookCli({
            toolCall: { name: "run_command", args: { CommandLine: cmd } },
            cwd: root,
          }),
        ),
      ),
      Promise.all(
        scratchPaths.map((scratchPath) =>
          runHookCli({
            toolCall: { name: "edit_file", args: { Path: scratchPath } },
            cwd: root,
          }),
        ),
      ),
    ]);
    for (let i = 0; i < safeCmds.length; i++) {
      assert.equal(cmdResults[i].decision, "allow", `Expected allow for: ${safeCmds[i]}`);
    }
    for (let i = 0; i < scratchPaths.length; i++) {
      assert.equal(
        editResults[i].decision,
        "allow",
        `Expected allow for edit_file: ${scratchPaths[i]}`,
      );
    }

    for (const bypassCmd of [
      "cat artifacts/local/../../../home/andrew/.local/share/godot/app_userdata/core-loop/profile.json",
      "cp artifacts/local/run/.local/share/godot/app_userdata/core-loop/save.json ~/.local/share/godot/app_userdata/core-loop/save.json",
      "echo hi>~/.local/share/godot/app_userdata/core-loop/save.json",
      "rm -rf ~/.local/share/godot/app_userdata/core-loop/artifacts/local/x",
      "rm -rf ~/.local/share/godot/app_userdata/core-loop/{save.json,x/artifacts/local/y}",
      "rm -rf /home/andrew/.local/share/godot/app_userdata/core-loop/artifacts/local/x",
      "rm -rf /home/andrew/.local/share/godot/app_userdata/core-loop/artifacts/local/.local/share/godot/app_userdata/core-loop",
      "cat $HOME/artifacts/local/x/.local/share/godot/app_userdata/core-loop/save.json",
      "cat artifacts/local/*/.local/share/godot/app_userdata/core-loop/save.json",
      "cat artifacts/local/'..'/../../home/andrew/.local/share/godot/app_userdata/core-loop/save.json",
      'cat artifacts/local/".."/../../home/andrew/.local/share/godot/app_userdata/core-loop/save.json',
      "cat artifacts/local/..\\/..\\/home/andrew/.local/share/godot/app_userdata/core-loop/save.json",
    ]) {
      const res = evaluateHook({
        toolCall: { name: "run_command", args: { CommandLine: bypassCmd } },
        cwd: root,
      });
      assert.equal(res.decision, "deny", `Expected deny for live-save bypass: ${bypassCmd}`);
    }
  });

  test("defaultInspectProjectGodot fast-paths clean project.godot without spawning git and bounds git calls to 3000ms", () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-fastpath-"));
    try {
      mkdirSync(path.join(tmp, ".git"));
      mkdirSync(path.join(tmp, "sketches/core-loop/src"), { recursive: true });
      writeFileSync(
        path.join(tmp, "sketches/core-loop/project.godot"),
        '[application]\nconfig/name="core-loop"\n',
      );

      const calls = [];
      const spySpawn = (cmd, args, opts) => {
        calls.push({ cmd, args, opts });
        return { status: 0, stdout: "" };
      };

      assert.equal(
        defaultInspectProjectGodot(path.join(tmp, "sketches/core-loop/src"), {
          checkWorkingTree: false,
          spawn: spySpawn,
        }),
        false,
      );
      assert.equal(calls.length, 0);

      writeFileSync(
        path.join(tmp, "sketches/core-loop/project.godot"),
        '[autoload]\nMcpBridge="*res://addons/mcp/bridge.gd"\n',
      );
      assert.equal(
        defaultInspectProjectGodot(tmp, { checkWorkingTree: true, spawn: spySpawn }),
        true,
      );
      assert.equal(calls.length, 0);

      const spyStaged = (cmd, args, opts) => {
        calls.push({ cmd, args, opts });
        if (args.includes("diff")) {
          return { status: 0, stdout: "sketches/core-loop/project.godot\n" };
        }
        if (args.includes("show")) {
          return { status: 0, stdout: '[autoload]\nMcpBridge="x"\n' };
        }
        return { status: 0, stdout: "" };
      };
      assert.equal(
        defaultInspectProjectGodot(tmp, { checkWorkingTree: false, spawn: spyStaged }),
        true,
      );
      assert.equal(calls.length, 2);
      for (const call of calls) {
        assert.equal(call.opts.timeout, 3000);
      }

      const noGitCalls = [];
      assert.equal(
        defaultInspectProjectGodot(os.tmpdir(), {
          checkWorkingTree: false,
          spawn: (cmd, args, opts) => {
            noGitCalls.push(opts);
            return { status: 1, stdout: "" };
          },
        }),
        false,
      );
      assert.ok(noGitCalls.length >= 1);
      for (const opts of noGitCalls) {
        assert.equal(opts.timeout, 3000);
      }
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

test("denies macOS live Godot save paths across shell quoting, escapes, %20, casing, and file-write tools while allowing artifacts/local scratch paths", () => {
  for (const cmd of [
    'rm -rf "$HOME/Library/Application Support/godot/app_userdata/core-loop/save.json"',
    "rm -rf '/Users/andrew/Library/Application Support/Godot/app_userdata/core-loop/save.json'",
    "rm -rf ~/Library/Application\\ Support/godot/app_userdata/core-loop/save.json",
    'cat ~/Library/"Application Support"/Godot/app_userdata/core-loop/profile.json',
    "cat ~/Library/'Application Support'/godot/app_userdata/core-loop/profile.json",
    "open file:///Users/andrew/Library/Application%20Support/godot/app_userdata/core-loop/save.json",
    "cat /Users/andrew/Library/Application Support/godot/app_userdata/core-loop/save.json",
    'cat "artifacts/local/../../../Users/andrew/Library/Application Support/godot/app_userdata/core-loop/save.json"',
    'cat "$HOME/artifacts/local/x/Library/Application Support/godot/app_userdata/core-loop/save.json"',
    'cp "artifacts/local/run/Library/Application Support/godot/app_userdata/core-loop/a" "~/Library/Application Support/godot/app_userdata/core-loop/b"',
    'rm -rf "/Users/andrew/Library/Application Support/godot/app_userdata/core-loop/artifacts/local/x"',
    'rm -rf "/Users/andrew/Library/Application%20Support/godot/app_userdata/core-loop/artifacts/local/x"',
  ]) {
    const res = evaluateHook({
      toolCall: { name: "run_command", args: { CommandLine: cmd } },
      cwd: root,
    });
    assert.equal(res.decision, "deny", `Expected deny for macOS live save cmd: ${cmd}`);
  }

  for (const [toolName, key] of [
    ["edit_file", "Path"],
    ["write_file", "Path"],
    ["write_to_file", "TargetFile"],
    ["replace_file_content", "TargetFile"],
    ["multi_replace_file_content", "AbsolutePath"],
  ]) {
    for (const targetPath of [
      "/Users/andrew/Library/Application Support/godot/app_userdata/core-loop/settings.cfg",
      "/Users/andrew/Library/Application Support/Godot/app_userdata/core-loop/profile.json",
      "/Users/andrew/Library/Application%20Support/godot/app_userdata/core-loop/save.json",
      "/Users/andrew/Library/Application%20Support/godot/app_userdata/core-loop/artifacts/local/save.json",
    ]) {
      const res = evaluateHook({
        toolCall: { name: toolName, args: { [key]: targetPath } },
        cwd: root,
      });
      assert.equal(
        res.decision,
        "deny",
        `Expected deny for ${toolName} (${key}) on macOS live save: ${targetPath}`,
      );
    }
  }

  for (const cmd of [
    'cat "artifacts/local/verify-game/run1/Library/Application Support/Godot/app_userdata/core-loop/profile.json"',
    "cat artifacts/local/verify-game/run1/Library/Application\\ Support/godot/app_userdata/core-loop/profile.json",
    "cat artifacts/local/verify-game/run1/Library/Application%20Support/godot/app_userdata/core-loop/profile.json",
    'HOME=/repo/artifacts/local/home ls "/repo/artifacts/local/home/Library/Application Support/godot/app_userdata/core-loop"',
  ]) {
    const res = evaluateHook({
      toolCall: { name: "run_command", args: { CommandLine: cmd } },
      cwd: root,
    });
    assert.equal(res.decision, "allow", `Expected allow for macOS scratch save cmd: ${cmd}`);
  }

  for (const scratchPath of [
    path.join(
      root,
      "artifacts/local/verify-game/run1/Library/Application Support/Godot/app_userdata/core-loop/profile.json",
    ),
    "artifacts/local/test-home/Library/Application Support/godot/app_userdata/core-loop/settings.cfg",
    "artifacts/local/test-home/Library/Application%20Support/godot/app_userdata/core-loop/settings.cfg",
  ]) {
    const res = evaluateHook({
      toolCall: { name: "edit_file", args: { Path: scratchPath } },
      cwd: root,
    });
    assert.equal(
      res.decision,
      "allow",
      `Expected allow for macOS scratch file edit: ${scratchPath}`,
    );
  }
});

test("decodes every percent code in a live save path, never throws on a malformed code, and keeps scratch paths allowed unless they leave artifacts/local", async () => {
  const decide = (toolCall) => evaluateHook({ toolCall, cwd: root }).decision;
  const command = (cmd) => decide({ name: "run_command", args: { CommandLine: cmd } });
  const edit = (target) => decide({ name: "edit_file", args: { Path: target } });

  for (const cmd of [
    "open file:///Users/andrew/Library/Application%20Support/godot/app_userdata/core%2Dloop/profile.json",
    "open file:///Users/andrew/Library%2FApplication%20Support%2Fgodot%2Fapp_userdata%2Fcore-loop%2Fsave.json",
    "cat /home/andrew/%2Elocal/share/godot/app_userdata/core-loop/save.json",
    "cat /home/andrew/%2elocal%2fshare/godot/app_userdata/core-loop/save.json",
    "cat /home/andrew/.local/share/godot/app%5Fuserdata/core-loop/save.json",
    "cat '/Users/andrew/Library/Applic%61tion Support/godot/app_userdata/core-loop/save.json'",
  ]) {
    assert.equal(command(cmd), "deny", `Expected deny for an encoded live save path: ${cmd}`);
  }
  for (const target of [
    "/Users/andrew/Library/Application%20Support/godot/app_userdata/core%2Dloop/save.json",
    "/home/andrew/.local%2Fshare%2Fgodot%2Fapp_userdata%2Fcore-loop/profile.json",
  ]) {
    assert.equal(edit(target), "deny", `Expected deny for an encoded live save edit: ${target}`);
  }

  for (const cmd of [
    "cat /home/andrew/.local/share/godot/app_userdata/core-loop%32/save.json",
    "cat artifacts%2Flocal%2Fx/.local/share/godot/app_userdata/core-loop/save.json",
  ]) {
    assert.equal(command(cmd), "deny", `Expected the path as written to stay denied: ${cmd}`);
  }

  for (const cmd of [
    "cat /home/andrew/.local/share/godot/app_userdata/core%2Dloop/%zz/save.json",
    "cat /home/andrew/%/.local%2Fshare/godot/app_userdata/core-loop/save.json%",
  ]) {
    assert.equal(
      command(cmd),
      "deny",
      `Expected a malformed code to leave the rest decoded: ${cmd}`,
    );
  }
  for (const cmd of ["echo 100%zz done %", "echo %", "echo %2", "echo %%%", "echo %E9%C3%28"]) {
    assert.equal(command(cmd), "allow", `Expected allow without a throw: ${cmd}`);
  }
  assert.equal(
    (await runHookCli({ toolCall: { name: "run_command", args: { CommandLine: "echo %zz %" } } }))
      .decision,
    "allow",
  );

  for (const cmd of [
    "cat artifacts/local/%2E%2E/%2E%2E/home/andrew/.local/share/godot/app_userdata/core-loop/save.json",
    "cat artifacts/local/run/%2e%2e%2f%2e%2e%2f%2e%2e%2fhome/andrew/.local/share/godot/app_userdata/core-loop/save.json",
  ]) {
    assert.equal(
      command(cmd),
      "deny",
      `Expected deny for an encoded way out of artifacts/local: ${cmd}`,
    );
  }
  assert.equal(
    edit(
      "artifacts/local/x/%2E%2E/%2E%2E/%2E%2E/Users/andrew/Library/Application Support/godot/app_userdata/core-loop/save.json",
    ),
    "deny",
  );

  for (const cmd of [
    "cat artifacts/local/run/%zz/.local/share/godot/app_userdata/core-loop/profile.json",
    "cat artifacts/local/run1/Library/Application%20Support/godot/app_userdata/core%2Dloop/profile.json",
    "cat artifacts/local/x%24y/.local/share/godot/app_userdata/core-loop/save.json",
  ]) {
    assert.equal(command(cmd), "allow", `Expected allow for a scratch save path: ${cmd}`);
  }
  for (const target of [
    "artifacts/local/test-home/.local%2Fshare/godot/app_userdata/core-loop/settings.cfg",
    "artifacts/local/test-home/Library/Application%20Support/godot/app_userdata/core%2Dloop/%E9%C3%28.cfg",
  ]) {
    assert.equal(edit(target), "allow", `Expected allow for a scratch save edit: ${target}`);
  }

  assert.equal(
    command(
      "open file:///Users/andrew/Library/Application%2520Support/godot/app_userdata/core-loop/save.json",
    ),
    "allow",
    "a code encoded twice is decoded once, as a file:// reader does: it names a folder called Application%20Support",
  );
});

test("the hook prints an ask decision and exits 0 when a helper it loads is missing or throws, or when evaluating throws", async () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-hook-broken-"));
  const payload = { toolCall: { name: "run_command", args: { CommandLine: "ls" } }, cwd: dir };
  const scratchHook = (name, helperFiles) => {
    const top = path.join(dir, name);
    mkdirSync(path.join(top, ".agents/hooks"), { recursive: true });
    mkdirSync(path.join(top, "scripts/lib"), { recursive: true });
    copyFileSync(hookScript, path.join(top, ".agents/hooks/safety-gate.mjs"));
    for (const [rel, text] of Object.entries(helperFiles)) {
      const target = path.join(top, "scripts/lib", rel);
      if (text === null) copyFileSync(path.join(root, "scripts/lib", rel), target);
      else writeFileSync(target, text);
    }
    return path.join(top, ".agents/hooks/safety-gate.mjs");
  };
  try {
    const cases = [
      [scratchHook("missing", {}), /could not run \(Cannot find module .*cli\.mjs/],
      [
        scratchHook("git-throws", {
          "cli.mjs": null,
          "git.mjs": 'throw new Error("broken git helper");\n',
        }),
        /could not run \(broken git helper\)/,
      ],
      [
        scratchHook("cli-throws", {
          "cli.mjs": 'throw new Error("broken cli helper");\n',
          "git.mjs": null,
        }),
        /could not run \(broken cli helper\)/,
      ],
      [
        scratchHook("git-syntax", { "cli.mjs": null, "git.mjs": "export const = ;\n" }),
        /could not run \(.+\)/,
      ],
    ];
    for (const [script, reason] of cases) {
      const res = await runHookCli(payload, script);
      assert.equal(res.decision, "ask", script);
      assert.match(res.reason, reason, script);
      assert.match(res.reason, /confirm manually\.$/, script);
    }

    const unconvertible = { toString: null };
    assert.throws(
      () =>
        evaluateHook({
          toolCall: { name: "run_command", args: { CommandLine: unconvertible } },
          cwd: root,
        }),
      TypeError,
    );
    const thrown = await runHookCli({
      toolCall: { name: "run_command", args: { CommandLine: unconvertible } },
      cwd: root,
    });
    assert.equal(thrown.decision, "ask");
    assert.match(
      thrown.reason,
      /^PreToolUse safety hook could not run \(Cannot convert object to primitive value\); confirm manually\.$/,
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
