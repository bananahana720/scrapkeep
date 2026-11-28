import { createHash } from "node:crypto";
import { access, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

import { checkLedger } from "./known-failing.mjs";
import { checkWeekly } from "./gate/weekly.mjs";
import { checkWaveState } from "./wave-state.mjs";

const scriptRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const limits =
  "Structural documentation checks only. No build, runtime, browser or remote check is implied; link targets are checked for existence and anchors, not for content correctness.";

function parseArguments(argv) {
  const options = { root: scriptRoot, report: null };
  for (let index = 0; index < argv.length; index++) {
    const flag = argv[index];
    const value = argv[index + 1];
    if (flag === "--root" && value) options.root = path.resolve(value);
    else if (flag === "--report" && value) options.report = path.resolve(value);
    else throw new Error("Unknown argument: " + flag);
    index++;
  }
  options.report ??= path.join(options.root, "artifacts/local/check-docs/report.json");
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

async function walk(root, directory, keep, skipDir = () => false) {
  const files = [];
  const absolute = path.join(root, directory);
  if (!(await exists(absolute))) return files;
  for (const item of await readdir(absolute, { withFileTypes: true })) {
    const file = path.posix.join(directory, item.name);
    if (item.isDirectory()) {
      if (skipDir(file)) continue;
      files.push(...(await walk(root, file, keep, skipDir)));
    } else if (item.isFile() && keep(file)) {
      files.push(file);
    }
  }
  return files;
}

const PRUNE_EXACT_DIRS = new Set([
  "artifacts/local",
  "tests/fixtures",
  "sketches/core-loop/addons",
]);
const PRUNE_DIR_NAMES = new Set([
  ".git",
  "node_modules",
  ".godot",
  "dist",
  "build",
  ".venv",
  "__pycache__",
]);

function shouldSkipDir(dir) {
  return PRUNE_EXACT_DIRS.has(dir) || PRUNE_DIR_NAMES.has(path.posix.basename(dir));
}

async function markdownFiles(root) {
  const files = await walk(root, "", (file) => file.endsWith(".md"), shouldSkipDir);
  return files.sort();
}

function visibleLines(content, keepCodeText = false) {
  let fenced = false;
  return content.split("\n").map((line) => {
    if (/^\s*(```|~~~)/.test(line)) {
      fenced = !fenced;
      return "";
    }
    if (fenced) return "";
    return keepCodeText ? line.replace(/`/g, "") : line.replace(/`[^`]*`/g, "");
  });
}

function slugify(heading) {
  const text = heading
    .replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1")
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s_-]/gu, "")
    .replace(/\s/g, "-");
  return text;
}

function collectAnchors(lines) {
  const anchors = new Set();
  const seen = new Map();
  for (const line of lines) {
    const heading = /^#{1,6}\s+(.*?)\s*#*\s*$/.exec(line);
    if (heading) {
      const base = slugify(heading[1]);
      const count = seen.get(base) ?? 0;
      seen.set(base, count + 1);
      anchors.add(count === 0 ? base : base + "-" + count);
    }
    for (const match of line.matchAll(/<a\s+(?:name|id)="([^"]+)"/g)) anchors.add(match[1]);
  }
  return anchors;
}

class Documents {
  constructor(root) {
    this.root = root;
    this.cache = new Map();
    this.existsCache = new Map();
    this.findings = [];
  }

  async hasFile(relativePath) {
    if (!this.existsCache.has(relativePath)) {
      this.existsCache.set(relativePath, await exists(path.join(this.root, relativePath)));
    }
    return this.existsCache.get(relativePath);
  }

  async load(file) {
    if (!this.cache.has(file)) {
      const content = await readFile(path.join(this.root, file), "utf8");
      const lines = visibleLines(content);
      this.cache.set(file, {
        content,
        lines,
        anchors: collectAnchors(visibleLines(content, true)),
        sha256: createHash("sha256").update(content).digest("hex"),
      });
    }
    return this.cache.get(file);
  }

  fail(check, file, line, message) {
    this.findings.push({ check, level: "failure", file, line, message });
  }

  info(check, file, line, message) {
    this.findings.push({ check, level: "info", file, line, message });
  }
}

async function checkLinks(docs, file) {
  const { lines } = await docs.load(file);
  let checked = 0;
  for (const [index, line] of lines.entries()) {
    const number = index + 1;
    for (const match of line.matchAll(/!?\[[^\]]*\]\((<[^>]+>|[^)]+)\)/g)) {
      const target = match[1]
        .replace(/^<|>$/g, "")
        .replace(/\s+"[^"]*"$/, "")
        .trim();
      if (/^[a-z][a-z0-9+.-]*:/i.test(target)) continue;
      checked++;
      if (target.startsWith("/")) {
        docs.fail(
          "links",
          file,
          number,
          "non-portable absolute link: " +
            target +
            "; replace with a repo-relative path from this file",
        );
        continue;
      }
      const [rawPath, rawAnchor] = target.split("#");
      let anchor = "";
      let decodedPath = "";
      try {
        anchor = rawAnchor ? decodeURIComponent(rawAnchor) : "";
        decodedPath = rawPath ? decodeURIComponent(rawPath) : "";
      } catch {
        docs.fail("links", file, number, "malformed percent-encoding in link: " + target);
        continue;
      }
      let targetFile = file;
      if (decodedPath) {
        targetFile = path.posix.normalize(path.posix.join(path.posix.dirname(file), decodedPath));
        if (targetFile === ".." || targetFile.startsWith("../")) {
          docs.fail("links", file, number, "link escapes repository: " + target);
          continue;
        }
        if (!(await docs.hasFile(targetFile))) {
          docs.fail(
            "links",
            file,
            number,
            "missing link target: " + target + "; update to an existing repo-relative path",
          );
          continue;
        }
      }
      if (!anchor || !targetFile.endsWith(".md")) continue;
      if (/^L\d+(?:-L?\d+)?$/.test(anchor)) continue;
      const { anchors } = await docs.load(targetFile);
      if (!anchors.has(anchor))
        docs.fail(
          "links",
          file,
          number,
          "broken anchor: " + target + " (no heading or <a id> for #" + anchor + ")",
        );
    }
  }
  return checked;
}

async function checkSkillsStage(docs) {
  const script = path.join(scriptRoot, "scripts/check-skills.mjs");
  if (!(await exists(script))) return 0;
  if (!(await exists(path.join(docs.root, ".agents/skills")))) return 0;
  const timeoutMs = 30_000;
  const result = spawnSync(process.execPath, [script, "--root", docs.root, "--json"], {
    encoding: "utf8",
    timeout: timeoutMs,
  });
  if (result.error?.code === "ETIMEDOUT") {
    docs.fail(
      "skills",
      "scripts/check-skills.mjs",
      0,
      "did not finish within " + timeoutMs / 1000 + "s and was killed",
    );
    return 0;
  }
  if (result.status === null) {
    docs.fail(
      "skills",
      "scripts/check-skills.mjs",
      0,
      "did not finish: " + (result.error?.message ?? result.signal),
    );
    return 0;
  }
  let findings;
  try {
    findings = JSON.parse(result.stdout);
  } catch {
    docs.fail(
      "skills",
      "scripts/check-skills.mjs",
      0,
      "did not print a JSON findings array (exit " +
        result.status +
        "): " +
        (result.stderr || result.stdout).slice(0, 200),
    );
    return 0;
  }
  for (const finding of findings) {
    const message = "[" + finding.check + "] " + finding.message;
    if (finding.level === "failure") docs.fail("skills", finding.file, finding.line, message);
    else docs.info("skills", finding.file, finding.line, message);
  }
  return findings.length;
}

async function checkAgentsStage(docs) {
  const script = path.join(scriptRoot, "scripts/check-agents.mjs");
  if (!(await exists(script))) return 0;
  if (!(await exists(path.join(docs.root, ".agents")))) return 0;
  const timeoutMs = 30_000;
  const result = spawnSync(process.execPath, [script, "--root", docs.root, "--json"], {
    encoding: "utf8",
    timeout: timeoutMs,
  });
  if (result.status === null) {
    docs.fail(
      "agents",
      "scripts/check-agents.mjs",
      0,
      "did not finish: " + (result.error?.message ?? result.signal),
    );
    return 0;
  }
  let findings;
  try {
    findings = JSON.parse(result.stdout);
  } catch {
    docs.fail(
      "agents",
      "scripts/check-agents.mjs",
      0,
      "did not print a JSON findings array (exit " +
        result.status +
        "): " +
        (result.stderr || result.stdout).slice(0, 200),
    );
    return 0;
  }
  for (const finding of findings) {
    const message = "[" + finding.check + "] " + finding.message;
    if (finding.level === "failure") docs.fail("agents", finding.file, finding.line, message);
    else docs.info("agents", finding.file, finding.line, message);
  }
  return findings.length;
}

async function checkWaveStateStage(docs) {
  const findings = await checkWaveState(docs.root);
  for (const finding of findings) {
    if (finding.level === "failure")
      docs.fail("wave-state", finding.file, finding.line, finding.message);
    else docs.info("wave-state", finding.file, finding.line, finding.message);
  }
  return findings.filter((finding) => finding.level === "failure").length;
}

const RULINGS_FILE = "project-guide/handoff/DECISIONS.md";
async function checkRulingLetters(docs) {
  try {
    await access(path.join(docs.root, RULINGS_FILE));
  } catch {
    return;
  }
  const { lines } = await docs.load(RULINGS_FILE);
  const seen = new Map();
  let replaced = false;
  for (const [index, line] of lines.entries()) {
    if (line.startsWith("## ")) replaced = /^## Replaced rulings\b/.test(line);
    if (replaced) continue;
    const match = /^\| Ruling ([a-z]{1,2})[,:]/.exec(line);
    if (!match) continue;
    const [, letter] = match;
    if (seen.has(letter))
      docs.fail(
        "rulings",
        RULINGS_FILE,
        index + 1,
        `ruling ${letter} already names the row on line ${seen.get(letter)}; give this ruling the next free letter`,
      );
    else seen.set(letter, index + 1);
  }
}

async function checkLedgerStage(docs) {
  const findings = await checkLedger(docs.root, { requireChecks: true });
  for (const finding of findings) {
    if (finding.level === "failure")
      docs.fail("known-failing", finding.file, finding.line, finding.message);
    else docs.info("known-failing", finding.file, finding.line, finding.message);
  }
  for (const finding of checkWeekly(docs.root)) {
    findings.push(finding);
    docs.fail("weekly-list", finding.file, finding.line, finding.message);
  }
  return findings.filter((finding) => finding.level === "failure").length;
}

const ARCHITECTURE_FILE = "sketches/core-loop/ARCHITECTURE.md";
const CORE_LOOP_SRC_DIR = "sketches/core-loop/src";
const CONTEXT_FILE = "sketches/core-loop/src/core/context.gd";

async function checkArchitectureSync(docs) {
  if (!(await docs.hasFile(CONTEXT_FILE))) return 0;
  if (!(await docs.hasFile(ARCHITECTURE_FILE))) {
    docs.fail("architecture", ARCHITECTURE_FILE, 1, `missing ${ARCHITECTURE_FILE}`);
    return 1;
  }
  const { content } = await docs.load(ARCHITECTURE_FILE);
  let failures = 0;
  const entries = await readdir(path.join(docs.root, CORE_LOOP_SRC_DIR), { withFileTypes: true });
  const subdirs = entries
    .filter((item) => item.isDirectory() && !item.name.startsWith("."))
    .map((item) => item.name)
    .sort();
  for (const dir of subdirs) {
    if (!content.includes(`src/${dir}/`)) {
      docs.fail(
        "architecture",
        ARCHITECTURE_FILE,
        1,
        `missing src/${dir}/ directory in ${ARCHITECTURE_FILE}; document ${CORE_LOOP_SRC_DIR}/${dir}/`,
      );
      failures++;
    }
  }
  const contextText = await readFile(path.join(docs.root, CONTEXT_FILE), "utf8");
  for (const [index, line] of contextText.split("\n").entries()) {
    const match = /^var\s+([A-Za-z_][A-Za-z0-9_]*)\b/.exec(line);
    if (!match) continue;
    const field = match[1];
    if (!content.includes(`\`${field}\``)) {
      docs.fail(
        "architecture",
        ARCHITECTURE_FILE,
        1,
        `missing Context field \`${field}\` from ${CONTEXT_FILE}:${index + 1} in ${ARCHITECTURE_FILE}`,
      );
      failures++;
    }
  }
  return failures;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const docs = new Documents(options.root);
  const files = await markdownFiles(options.root);
  let links = 0;
  for (const file of files) links += await checkLinks(docs, file);
  const skillFindings = await checkSkillsStage(docs);
  const agentFindings = await checkAgentsStage(docs);
  const waveFindings = await checkWaveStateStage(docs);
  const ledgerFindings = await checkLedgerStage(docs);
  await checkRulingLetters(docs);
  const architectureFindings = await checkArchitectureSync(docs);
  const manifest = {};
  for (const file of [...docs.cache.keys()].sort()) manifest[file] = docs.cache.get(file).sha256;
  const failures = docs.findings.filter((finding) => finding.level === "failure");
  const report = {
    result: failures.length ? "fail" : "pass",
    root: options.root,
    checked: {
      files: files.length,
      links,
      skillFindings,
      agentFindings,
      waveFindings,
      ledgerFindings,
      architectureFindings,
    },
    failures: failures.length,
    findings: docs.findings,
    manifest,
    limits,
  };
  await mkdir(path.dirname(options.report), { recursive: true });
  await writeFile(options.report, JSON.stringify(report, null, 2) + "\n");
  for (const finding of docs.findings)
    console.log(
      finding.level.toUpperCase() +
        " " +
        finding.check +
        " " +
        finding.file +
        ":" +
        finding.line +
        " " +
        finding.message,
    );
  console.log(
    "check:docs " +
      report.result +
      ": " +
      files.length +
      " Markdown files, " +
      links +
      " local links, " +
      skillFindings +
      " skill findings, " +
      agentFindings +
      " agent findings, " +
      waveFindings +
      " wave-state findings, " +
      ledgerFindings +
      " known-failing findings, " +
      architectureFindings +
      " architecture findings, " +
      failures.length +
      " failures. Report: " +
      options.report,
  );
  console.log(limits);
  process.exitCode = failures.length ? 1 : 0;
}

try {
  await main();
} catch (error) {
  console.error("check:docs internal error: " + (error?.stack ?? error));
  process.exitCode = 2;
}
