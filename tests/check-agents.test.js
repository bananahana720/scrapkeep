import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const script = path.join(root, "scripts/check-agents.mjs");

async function buildCleanRepo(tmp) {
  const repo = path.join(tmp, "repo");
  await mkdir(path.join(repo, ".agents/agents"), { recursive: true });
  await mkdir(path.join(repo, ".agents/rules"), { recursive: true });
  await mkdir(path.join(repo, ".agents/hooks"), { recursive: true });
  await mkdir(path.join(repo, ".agents/skills/demo/scripts"), { recursive: true });
  await mkdir(path.join(repo, ".claude/agents"), { recursive: true });

  await writeFile(path.join(repo, "AGENTS.md"), "# Agents\n");
  await writeFile(path.join(repo, "GEMINI.md"), "# Gemini\n");

  const explorerBody = `---\nname: demo-explorer\ndescription: Read-only lookup.\nsubagent: true\nmainAgent: false\nmodel: flash\ntools:\n  - read_file\n---\n\nInspect read-only.\n`;
  await writeFile(path.join(repo, ".agents/agents/demo-explorer.md"), explorerBody);
  await writeFile(path.join(repo, ".claude/agents/demo-explorer.md"), explorerBody);

  await writeFile(
    path.join(repo, ".agents/rules/gd.md"),
    `---\ntrigger: glob\nglobs: "**/*.gd"\ndescription: "GDScript rules."\n---\n\nKeep modules deep.\n`,
  );
  await writeFile(path.join(repo, ".agents/hooks/gate.mjs"), "console.log('{}');\n");
  await writeFile(
    path.join(repo, ".agents/hooks.json"),
    JSON.stringify({
      gate: {
        PreToolUse: [
          {
            matcher: "run_command",
            hooks: [{ type: "command", command: "node ./hooks/gate.mjs" }],
          },
        ],
      },
    }),
  );
  await writeFile(
    path.join(repo, ".agents/skills/demo/SKILL.md"),
    "---\nname: demo\ndescription: Run demo.\n---\n\n1. Run.\n",
  );
  await writeFile(
    path.join(repo, ".agents/skills/demo/scripts/flow.py"),
    "res = await agent('hi', schema={'type': 'string'})\n",
  );
  return repo;
}

function runCheck(repo) {
  const res = spawnSync(process.execPath, [script, "--root", repo, "--json"], {
    encoding: "utf8",
    timeout: 10000,
  });
  assert.equal(res.error, undefined);
  return { status: res.status, findings: JSON.parse(res.stdout), stderr: res.stderr };
}

test("clean Antigravity repo fixture passes check-agents with 0 findings", async () => {
  const tmp = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-agents-"));
  try {
    const repo = await buildCleanRepo(tmp);
    const { status, findings } = runCheck(repo);
    assert.equal(status, 0, JSON.stringify(findings));
    assert.equal(findings.length, 0);
  } finally {
    await rm(tmp, { recursive: true, force: true });
  }
});

test("catches unquoted glob *, nested rule dirs, and invalid trigger", async () => {
  const tmp = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-agents-"));
  try {
    const repo = await buildCleanRepo(tmp);
    await writeFile(
      path.join(repo, ".agents/rules/gd.md"),
      `---\ntrigger: glob\nglobs: **/*.gd\n---\n`,
    );
    await mkdir(path.join(repo, ".agents/rules/nested"), { recursive: true });
    await writeFile(
      path.join(repo, ".agents/rules/bad-trigger.md"),
      `---\ntrigger: alwaysOn\n---\n`,
    );
    const { status, findings } = runCheck(repo);
    assert.equal(status, 1);
    assert.ok(findings.some((f) => f.check === "rules" && f.message.includes("quoted")));
    assert.ok(findings.some((f) => f.check === "rules" && f.message.includes("nested")));
    assert.ok(findings.some((f) => f.check === "rules" && f.message.includes("trigger")));
  } finally {
    await rm(tmp, { recursive: true, force: true });
  }
});

test("catches invalid native tool names, read-only posture violations, and claude/agents parity drift", async () => {
  const tmp = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-agents-"));
  try {
    const repo = await buildCleanRepo(tmp);
    await writeFile(
      path.join(repo, ".agents/agents/demo-explorer.md"),
      `---\nname: demo-explorer\ndescription: Bad.\nsubagent: true\nmainAgent: false\nmodel: flash\ntools:\n  - read_file\n  - edit_file\n  - Bash\n---\n`,
    );
    await writeFile(
      path.join(repo, ".claude/agents/extra-agent.md"),
      "---\nname: extra-agent\n---\n",
    );
    await writeFile(
      path.join(repo, ".agents/agents/extra-agy.md"),
      `---\nname: extra-agy\ndescription: Extra.\nsubagent: true\nmainAgent: false\nmodel: flash\ntools:\n  - read_file\n---\n`,
    );
    const { status, findings } = runCheck(repo);
    assert.equal(status, 1);
    assert.ok(
      findings.some((f) => f.check === "agents" && f.message.includes("unknown native tool")),
    );
    assert.ok(
      findings.some((f) => f.check === "agents" && f.message.includes("must not grant edit_file")),
    );
    assert.ok(findings.some((f) => f.check === "agents" && f.message.includes("extra-agent.md")));
    assert.ok(findings.some((f) => f.check === "agents" && f.message.includes("extra-agy.md")));
  } finally {
    await rm(tmp, { recursive: true, force: true });
  }
});

test("catches missing hook script, dead astack/A-stack references (including references/), ignores lessons.md provenance, and catches invalid Python workflow syntax", async () => {
  const tmp = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-agents-"));
  try {
    const repo = await buildCleanRepo(tmp);
    await writeFile(
      path.join(repo, ".agents/hooks.json"),
      JSON.stringify({
        gate: {
          PreToolUse: [
            { matcher: "run_command", hooks: [{ command: "node ./hooks/missing.mjs" }] },
          ],
        },
      }),
    );
    await writeFile(path.join(repo, "GEMINI.md"), "# Gemini\nUse astack here.\n");
    await mkdir(path.join(repo, ".agents/skills/demo/references"), { recursive: true });
    await writeFile(
      path.join(repo, ".agents/skills/demo/references/notes.md"),
      "Do not mention A-stack.\n",
    );
    await writeFile(
      path.join(repo, ".agents/skills/demo/references/lessons.md"),
      "Historical origin: A stack.\n",
    );
    await writeFile(path.join(repo, ".agents/skills/demo/scripts/flow.py"), "def broken(:\n");
    const { status, findings } = runCheck(repo);
    assert.equal(status, 1);
    assert.ok(findings.some((f) => f.check === "hooks" && f.message.includes("missing.mjs")));
    assert.ok(findings.some((f) => f.check === "astack" && f.file === "GEMINI.md"));
    assert.ok(
      findings.some(
        (f) => f.check === "astack" && f.file === ".agents/skills/demo/references/notes.md",
      ),
    );
    assert.ok(!findings.some((f) => f.file === ".agents/skills/demo/references/lessons.md"));
    assert.ok(findings.some((f) => f.check === "workflows"));
  } finally {
    await rm(tmp, { recursive: true, force: true });
  }
});

test("catches undefined call_tool() in Antigravity Python workflows", async () => {
  const tmp = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-agents-"));
  try {
    const repo = await buildCleanRepo(tmp);
    await writeFile(
      path.join(repo, ".agents/skills/demo/scripts/bad_call.py"),
      "res = await call_tool('run_command', {'CommandLine': 'echo hi'})\n",
    );
    const { status, findings } = runCheck(repo);
    assert.equal(status, 1);
    assert.ok(findings.some((f) => f.check === "workflows" && f.message.includes("call_tool")));
  } finally {
    await rm(tmp, { recursive: true, force: true });
  }
});
