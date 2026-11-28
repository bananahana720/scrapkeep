import { spawnSync } from "node:child_process";
import { access, readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const VALID_MODELS = new Set(["flash_lite", "flash", "pro", "inherit"]);
const VALID_NATIVE_TOOLS = new Set([
  "read_file",
  "edit_file",
  "write_file",
  "run_command",
  "manage_task",
  "search_web",
]);
const VALID_TRIGGERS = new Set(["always_on", "model_decision", "glob", "manual"]);
const VALID_HOOK_EVENTS = new Set([
  "enabled",
  "SessionStart",
  "PreToolUse",
  "PostToolUse",
  "PreInvocation",
  "PostInvocation",
  "Stop",
]);
const ASTACK_PATTERN = /\bastack\b|\bA[- ]stack\b|\/home\/andrew\/\.config\/astack/i;
const RETIRED_SCRIPT_TOKENS = [
  {
    pattern: /\bastack\b/i,
    message: "retired 'astack' reference; use pstack / ~/.local/share/tlc",
  },
  {
    pattern: /\bgpt-6-astra\b/,
    message: "retired 'gpt-6-astra' model pin; use gpt-6.2-astra (AGENTS.md Rule 11)",
  },
  {
    pattern: /\bclaude-opus-4-6\b/,
    message: "retired 'claude-opus-4-6' model pin; use AGENTS.md Rule 11 models",
  },
];
const CORE_CODEX_AGENTS = [
  "scrapkeep-explorer",
  "scrapkeep-reviewer",
  "scrapkeep-reviewer-medium",
  "scrapkeep-verifier",
  "scrapkeep-writer",
  "scrapkeep-writer-low",
];
const RETIRED_AGENT_TOKENS = [
  {
    pattern: /\bFable 5\.1\b/,
    message: "retired 'Fable 5.1' model pin; use tier / AGENTS.md Rule 11 wording",
  },
  {
    pattern: /\bSonnet 5\b/,
    message: "retired 'Sonnet 5' model pin; use tier / AGENTS.md Rule 11 wording",
  },
  {
    pattern: /\bOpus 5\.5 medium\b/,
    message: "retired 'Opus 5.5 medium' model pin; use tier / AGENTS.md Rule 11 wording",
  },
  {
    pattern: /\bCLAUDE_EFFORT\b/,
    message: "retired 'CLAUDE_EFFORT' instruction; use runtime effort metadata wording",
  },
];
const HARDCODED_PY_MODEL_PIN = /\bmodel\s*=\s*["'](?:flash|flash_lite|pro)["']/;
const SCRIPT_EXTS = new Set([".mjs", ".js", ".sh", ".py"]);
const MAX_RULE_BYTES = 24_000;

function parseArguments(argv) {
  const options = { root: scriptRoot, json: false };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === "--root") {
      const value = argv[i + 1];
      if (value === undefined) throw new Error("--root needs a directory");
      options.root = path.resolve(value);
      i += 1;
    } else if (flag === "--json") {
      options.json = true;
    } else {
      throw new Error("Unknown argument: " + flag);
    }
  }
  return options;
}

async function exists(file) {
  try {
    await access(file);
    return true;
  } catch {
    return false;
  }
}

async function readNormalized(file) {
  return (await readFile(file, "utf8")).replace(/\r\n/g, "\n");
}

function unquote(value) {
  const v = value.trim();
  if (
    (v.startsWith('"') && v.endsWith('"') && v.length >= 2) ||
    (v.startsWith("'") && v.endsWith("'") && v.length >= 2)
  ) {
    return v.slice(1, -1);
  }
  return v;
}

function parseYamlFrontmatter(content) {
  const match = /^---\n([\s\S]*?)\n---\n/.exec(content);
  if (!match) return null;
  const rawBlock = match[1];
  const fields = {};
  const rawLines = {};
  const lines = rawBlock.split("\n");
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    const kv = /^([A-Za-z_][A-Za-z0-9_]*):[ \t]?(.*)$/.exec(line);
    if (!kv) continue;
    const key = kv[1];
    const rest = kv[2].trim();
    rawLines[key] = rest;
    if (rest === "" && i + 1 < lines.length && /^\s*-\s+/.test(lines[i + 1])) {
      const items = [];
      let j = i + 1;
      while (j < lines.length) {
        const item = /^\s*-\s+(.+)$/.exec(lines[j]);
        if (!item) break;
        items.push(unquote(item[1]));
        j += 1;
      }
      fields[key] = items;
      i = j - 1;
      continue;
    }
    if (rest.startsWith("[") && rest.endsWith("]")) {
      fields[key] = rest
        .slice(1, -1)
        .split(",")
        .map((s) => unquote(s))
        .filter(Boolean);
      continue;
    }
    fields[key] = unquote(rest);
  }
  return { fields, rawLines, body: content.slice(match[0].length) };
}

class Findings {
  constructor() {
    this.list = [];
  }
  fail(check, file, line, message) {
    this.list.push({ check, level: "failure", file, line, message });
  }
  warn(check, file, line, message) {
    this.list.push({ check, level: "warning", file, line, message });
  }
}

function scanLinesForTokens(findings, check, rel, content, rules) {
  const lines = content.split("\n");
  for (let i = 0; i < lines.length; i += 1) {
    for (const { pattern, message } of rules) {
      if (pattern.test(lines[i])) findings.fail(check, rel, i + 1, message);
    }
  }
}

async function checkAgentsDir(findings, root) {
  const agentsDir = path.join(root, ".agents/agents");
  const claudeDir = path.join(root, ".claude/agents");
  const codexDir = path.join(root, ".codex/agents");
  const agyNames = new Set();

  if (await exists(agentsDir)) {
    const entries = await readdir(agentsDir, { withFileTypes: true });
    for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
      if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
      const stem = entry.name.slice(0, -3);
      agyNames.add(stem);
      const rel = `.agents/agents/${entry.name}`;
      const content = await readNormalized(path.join(agentsDir, entry.name));
      scanLinesForTokens(findings, "agents", rel, content, RETIRED_AGENT_TOKENS);
      const fm = parseYamlFrontmatter(content);
      if (!fm) {
        findings.fail("agents", rel, 1, "missing YAML frontmatter");
        continue;
      }
      const { fields } = fm;
      if (fields.name !== stem) {
        findings.fail(
          "agents",
          rel,
          1,
          `frontmatter name ${JSON.stringify(fields.name ?? null)} does not match ${JSON.stringify(stem)}`,
        );
      }
      if (!fields.description || typeof fields.description !== "string") {
        findings.fail("agents", rel, 1, "missing description");
      }
      if (fields.subagent !== "true") {
        findings.fail("agents", rel, 1, "subagent must be true");
      }
      if (fields.mainAgent !== "false") {
        findings.fail("agents", rel, 1, "mainAgent must be false");
      }
      if (!VALID_MODELS.has(fields.model)) {
        findings.fail(
          "agents",
          rel,
          1,
          `model ${JSON.stringify(fields.model ?? null)} must be one of flash_lite, flash, pro, inherit`,
        );
      }
      const tools = Array.isArray(fields.tools) ? fields.tools : [];
      if (tools.length === 0) {
        findings.fail("agents", rel, 1, "tools list must be non-empty");
      } else {
        for (const t of tools) {
          if (!VALID_NATIVE_TOOLS.has(t)) {
            findings.fail("agents", rel, 1, `unknown native tool ${JSON.stringify(t)}`);
          }
        }
        if (/(explorer|reviewer)/.test(stem)) {
          for (const forbidden of ["edit_file", "write_file", "run_command"]) {
            if (tools.includes(forbidden)) {
              findings.fail(
                "agents",
                rel,
                1,
                `read-only agent ${stem} must not grant ${forbidden}`,
              );
            }
          }
        }
        if (/verifier/.test(stem)) {
          for (const forbidden of ["edit_file", "write_file"]) {
            if (tools.includes(forbidden)) {
              findings.fail("agents", rel, 1, `verifier ${stem} must not grant ${forbidden}`);
            }
          }
        }
      }
    }
  }

  if (await exists(claudeDir)) {
    const claudeNames = new Set();
    const entries = await readdir(claudeDir, { withFileTypes: true });
    for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
      if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
      const stem = entry.name.slice(0, -3);
      claudeNames.add(stem);
      const rel = `.claude/agents/${entry.name}`;
      const content = await readNormalized(path.join(claudeDir, entry.name));
      scanLinesForTokens(findings, "agents", rel, content, RETIRED_AGENT_TOKENS);
      if (!agyNames.has(stem)) {
        findings.fail(
          "agents",
          rel,
          0,
          `missing matching Antigravity subagent .agents/agents/${entry.name}`,
        );
      }
    }
    for (const stem of [...agyNames].sort()) {
      if (!claudeNames.has(stem)) {
        findings.fail(
          "agents",
          `.agents/agents/${stem}.md`,
          0,
          `missing matching Claude subagent .claude/agents/${stem}.md`,
        );
      }
    }
  }

  if (await exists(codexDir)) {
    const codexNames = new Set();
    const entries = await readdir(codexDir, { withFileTypes: true });
    for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
      if (!entry.isFile() || !entry.name.endsWith(".toml")) continue;
      const stem = entry.name.slice(0, -5);
      codexNames.add(stem);
      const rel = `.codex/agents/${entry.name}`;
      const content = await readNormalized(path.join(codexDir, entry.name));
      scanLinesForTokens(findings, "agents", rel, content, [
        ...RETIRED_AGENT_TOKENS,
        ...RETIRED_SCRIPT_TOKENS,
      ]);
    }
    for (const stem of CORE_CODEX_AGENTS) {
      if (!codexNames.has(stem)) {
        findings.fail(
          "agents",
          `.codex/agents/${stem}.toml`,
          0,
          `missing core Codex subagent .codex/agents/${stem}.toml`,
        );
      }
    }
  }
}

async function checkRulesDir(findings, root) {
  const rulesDir = path.join(root, ".agents/rules");
  if (!(await exists(rulesDir))) return;
  const entries = await readdir(rulesDir, { withFileTypes: true });
  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
    const rel = `.agents/rules/${entry.name}`;
    if (entry.isDirectory()) {
      findings.fail(
        "rules",
        rel,
        0,
        "nested subdirectory inside .agents/rules/ is silently ignored",
      );
      continue;
    }
    if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
    const raw = await readFile(path.join(rulesDir, entry.name));
    if (raw.byteLength > MAX_RULE_BYTES) {
      findings.fail(
        "rules",
        rel,
        0,
        `rule file exceeds ${MAX_RULE_BYTES} bytes (${raw.byteLength})`,
      );
    }
    const content = raw.toString("utf8").replace(/\r\n/g, "\n");
    const fm = parseYamlFrontmatter(content);
    if (!fm) {
      findings.fail("rules", rel, 1, "missing YAML frontmatter");
      continue;
    }
    const { fields, rawLines } = fm;
    if (!VALID_TRIGGERS.has(fields.trigger)) {
      findings.fail(
        "rules",
        rel,
        1,
        `trigger ${JSON.stringify(fields.trigger ?? null)} must be one of always_on, model_decision, glob, manual`,
      );
      continue;
    }
    if (fields.trigger === "glob") {
      const globVal = fields.globs ?? fields.glob ?? "";
      const rawGlob = rawLines.globs ?? rawLines.glob ?? "";
      if (!globVal) {
        findings.fail("rules", rel, 1, "trigger: glob requires non-empty globs");
      } else if (rawGlob.startsWith("*")) {
        findings.fail("rules", rel, 1, "glob pattern starting with * must be quoted in YAML");
      }
    }
    if (fields.trigger === "model_decision" && !fields.description) {
      findings.fail("rules", rel, 1, "trigger: model_decision requires non-empty description");
    }
  }
}

async function checkHooksFile(findings, root) {
  const hooksRel = ".agents/hooks.json";
  const hooksPath = path.join(root, hooksRel);
  if (!(await exists(hooksPath))) return;
  let parsed;
  try {
    parsed = JSON.parse(await readFile(hooksPath, "utf8"));
  } catch (err) {
    findings.fail("hooks", hooksRel, 1, `invalid JSON: ${err.message}`);
    return;
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    findings.fail("hooks", hooksRel, 1, "top-level hooks.json must be a JSON object");
    return;
  }
  for (const [hookName, spec] of Object.entries(parsed)) {
    if (!spec || typeof spec !== "object" || Array.isArray(spec)) {
      findings.fail("hooks", hooksRel, 1, `hook ${hookName} must be an object`);
      continue;
    }
    for (const [eventName, groups] of Object.entries(spec)) {
      if (!VALID_HOOK_EVENTS.has(eventName)) {
        findings.fail(
          "hooks",
          hooksRel,
          1,
          `hook ${hookName}: unknown event ${JSON.stringify(eventName)}`,
        );
        continue;
      }
      if (eventName === "enabled") continue;
      if (!Array.isArray(groups)) {
        findings.fail("hooks", hooksRel, 1, `hook ${hookName}.${eventName} must be an array`);
        continue;
      }
      for (const group of groups) {
        const handlers =
          eventName === "PreToolUse" || eventName === "PostToolUse" ? group?.hooks : [group];
        if (
          (eventName === "PreToolUse" || eventName === "PostToolUse") &&
          typeof group?.matcher !== "string"
        ) {
          findings.fail(
            "hooks",
            hooksRel,
            1,
            `hook ${hookName}.${eventName} entry missing string matcher`,
          );
        }
        if (!Array.isArray(handlers) || handlers.length === 0) {
          findings.fail(
            "hooks",
            hooksRel,
            1,
            `hook ${hookName}.${eventName} entry has no handlers`,
          );
          continue;
        }
        for (const handler of handlers) {
          if (typeof handler?.command !== "string" || !handler.command.trim()) {
            findings.fail(
              "hooks",
              hooksRel,
              1,
              `hook ${hookName}.${eventName} handler missing command`,
            );
            continue;
          }
          for (const m of handler.command.matchAll(/(?:^|\s)\.\/([^\s"'`]+)/g)) {
            const target = path.join(root, ".agents", m[1]);
            if (!(await exists(target))) {
              findings.fail(
                "hooks",
                hooksRel,
                1,
                `hook ${hookName}.${eventName} script does not exist: .agents/${m[1]}`,
              );
            }
          }
        }
      }
    }
  }
}

async function checkEntrypointsAndAstack(findings, root) {
  for (const entry of ["AGENTS.md", "GEMINI.md"]) {
    const abs = path.join(root, entry);
    if (!(await exists(abs))) continue;
    const raw = await readFile(abs);
    if (raw.byteLength > MAX_RULE_BYTES) {
      findings.fail(
        "entrypoints",
        entry,
        0,
        `${entry} exceeds ${MAX_RULE_BYTES} bytes (${raw.byteLength})`,
      );
    }
    if (entry === "GEMINI.md") {
      const lines = raw.toString("utf8").replace(/\r\n/g, "\n").split("\n").length;
      if (lines > 100) {
        findings.warn("entrypoints", entry, lines, `GEMINI.md is ${lines} lines (target <= 100)`);
      }
    }
  }

  const liveFiles = [
    "AGENTS.md",
    "CLAUDE.md",
    "GEMINI.md",
    ".agents/skills/README.md",
    "docs/project/AI-WORKFLOW.md",
    "project-guide/handoff/START-HERE.md",
  ];
  for (const dir of [".agents/rules", ".agents/agents"]) {
    const absDir = path.join(root, dir);
    if (await exists(absDir)) {
      for (const e of await readdir(absDir, { withFileTypes: true })) {
        if (e.isFile() && e.name.endsWith(".md")) liveFiles.push(`${dir}/${e.name}`);
      }
    }
  }
  const skillsDir = path.join(root, ".agents/skills");
  if (await exists(skillsDir)) {
    for (const e of await readdir(skillsDir, { withFileTypes: true })) {
      if (!e.isDirectory()) continue;
      liveFiles.push(`.agents/skills/${e.name}/SKILL.md`);
      const refDir = path.join(skillsDir, e.name, "references");
      if (await exists(refDir)) {
        for (const r of await readdir(refDir, { withFileTypes: true })) {
          if (r.isFile() && r.name.endsWith(".md") && r.name !== "lessons.md") {
            liveFiles.push(`.agents/skills/${e.name}/references/${r.name}`);
          }
        }
      }
    }
  }

  for (const rel of liveFiles.sort()) {
    const abs = path.join(root, rel);
    if (!(await exists(abs))) continue;
    const lines = (await readNormalized(abs)).split("\n");
    for (let i = 0; i < lines.length; i += 1) {
      if (ASTACK_PATTERN.test(lines[i])) {
        findings.fail(
          "astack",
          rel,
          i + 1,
          "dead astack reference in live configuration/skill/doc",
        );
      }
    }
  }
}

async function walkScriptFiles(root, dir, out = []) {
  const absDir = path.join(root, dir);
  if (!(await exists(absDir))) return out;
  for (const e of await readdir(absDir, { withFileTypes: true })) {
    const rel = `${dir}/${e.name}`;
    if (e.isDirectory()) {
      await walkScriptFiles(root, rel, out);
    } else if (e.isFile() && SCRIPT_EXTS.has(path.extname(e.name))) {
      if (rel.includes(".test.") || rel === "scripts/check-agents.mjs") continue;
      out.push(rel);
    }
  }
  return out;
}

async function walkLiveAgentsMarkdown(root, dir, out = []) {
  const absDir = path.join(root, dir);
  if (!(await exists(absDir))) return out;
  for (const e of await readdir(absDir, { withFileTypes: true })) {
    const rel = `${dir}/${e.name}`;
    if (e.isDirectory()) {
      await walkLiveAgentsMarkdown(root, rel, out);
    } else if (e.isFile() && e.name.endsWith(".md") && e.name !== "lessons.md") {
      out.push(rel);
    }
  }
  return out;
}

async function checkScriptTokens(findings, root) {
  const files = [];
  for (const dir of ["scripts", "tools"]) await walkScriptFiles(root, dir, files);
  await walkLiveAgentsMarkdown(root, ".agents", files);
  for (const rel of files.sort()) {
    const content = await readNormalized(path.join(root, rel));
    scanLinesForTokens(findings, "tokens", rel, content, RETIRED_SCRIPT_TOKENS);
  }
}

async function checkClaudeSettings(findings, root) {
  const rel = ".claude/settings.json";
  const abs = path.join(root, rel);
  if (!(await exists(abs))) return;
  let parsed;
  try {
    parsed = JSON.parse(await readNormalized(abs));
  } catch (err) {
    findings.fail("settings", rel, 0, `invalid JSON: ${err.message}`);
    return;
  }
  if (parsed?.enabledPlugins?.["pstack@cursor-plugins"] !== true) {
    findings.fail(
      "settings",
      rel,
      0,
      'missing enabledPlugins["pstack@cursor-plugins"]: true (ruling er)',
    );
  }
  if (!parsed?.extraKnownMarketplaces?.["cursor-plugins"]) {
    findings.fail(
      "settings",
      rel,
      0,
      'missing extraKnownMarketplaces["cursor-plugins"] marketplace registration (ruling er)',
    );
  }
}

async function checkPythonWorkflows(findings, root) {
  const skillsDir = path.join(root, ".agents/skills");
  if (!(await exists(skillsDir))) return;
  const pyFiles = [];
  for (const e of await readdir(skillsDir, { withFileTypes: true })) {
    if (!e.isDirectory()) continue;
    const sDir = path.join(skillsDir, e.name, "scripts");
    if (!(await exists(sDir))) continue;
    for (const f of await readdir(sDir, { withFileTypes: true })) {
      if (f.isFile() && f.name.endsWith(".py")) {
        pyFiles.push(`.agents/skills/${e.name}/scripts/${f.name}`);
      }
    }
  }
  if (pyFiles.length === 0) return;
  for (const rel of pyFiles.sort()) {
    const lines = (await readNormalized(path.join(root, rel))).split("\n");
    for (let i = 0; i < lines.length; i += 1) {
      if (/^\s*#/.test(lines[i])) continue;
      if (HARDCODED_PY_MODEL_PIN.test(lines[i])) {
        findings.fail(
          "workflows",
          rel,
          i + 1,
          'hardcoded model tier pin violates AGENTS.md Rule 11; use model=args.get(...) or "inherit"',
        );
      }
    }
  }
  const checkScript =
    "import ast, sys\nfor p in sys.argv[1:]:\n  src = open(p, encoding='utf8').read()\n  compile(src, p, 'exec', flags=ast.PyCF_ALLOW_TOP_LEVEL_AWAIT)\n  tree = compile(src, p, 'exec', flags=ast.PyCF_ALLOW_TOP_LEVEL_AWAIT | ast.PyCF_ONLY_AST)\n  defined = {n.name for n in ast.walk(tree) if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))}\n  if 'call_tool' not in defined:\n    for node in ast.walk(tree):\n      if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == 'call_tool':\n        sys.stderr.write(f'{p}:{node.lineno}: undefined call_tool() is not provided by Antigravity run_workflow; use subprocess.run\\n')\n        sys.exit(1)\n";
  const res = spawnSync(
    "python3",
    ["-c", checkScript, ...pyFiles.sort().map((rel) => path.join(root, rel))],
    { encoding: "utf8" },
  );
  if (res.error) {
    findings.warn(
      "workflows",
      ".agents/skills",
      0,
      `python3 unavailable; skipped workflow syntax check (${res.error.message})`,
    );
    return;
  }
  if (res.status !== 0) {
    findings.fail(
      "workflows",
      ".agents/skills",
      0,
      `workflow Python syntax failure: ${(res.stderr || res.stdout).trim()}`,
    );
  }
}

async function main() {
  let options;
  try {
    options = parseArguments(process.argv.slice(2));
  } catch (err) {
    console.error(err.message);
    process.exitCode = 2;
    return;
  }
  if (!(await exists(options.root))) {
    console.error("--root does not exist: " + options.root);
    process.exitCode = 2;
    return;
  }

  const findings = new Findings();
  await checkAgentsDir(findings, options.root);
  await checkRulesDir(findings, options.root);
  await checkHooksFile(findings, options.root);
  await checkEntrypointsAndAstack(findings, options.root);
  await checkScriptTokens(findings, options.root);
  await checkClaudeSettings(findings, options.root);
  await checkPythonWorkflows(findings, options.root);

  const failures = findings.list.filter((f) => f.level === "failure");
  if (options.json) {
    console.log(JSON.stringify(findings.list, null, 2));
  } else {
    for (const f of findings.list) {
      console.log(`${f.level.toUpperCase()} ${f.check} ${f.file}:${f.line} ${f.message}`);
    }
    console.log(
      `check:agents ${failures.length ? "fail" : "pass"}: ${findings.list.length} findings (${failures.length} failures, ${findings.list.length - failures.length} warnings).`,
    );
  }
  process.exitCode = failures.length ? 1 : 0;
}

try {
  await main();
} catch (err) {
  console.error("check:agents internal error: " + (err?.stack ?? err));
  process.exitCode = 2;
}
