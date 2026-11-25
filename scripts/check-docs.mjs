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

async function markdownFiles(root) {
  const files = [];
  for (const item of await readdir(root, { withFileTypes: true }))
    if (item.isFile() && item.name.endsWith(".md")) files.push(item.name);
  files.push(...(await walk(root, "adr", (file) => file.endsWith(".md"))));
  files.push(...(await walk(root, "docs", (file) => file.endsWith(".md"))));
  files.push(
    ...(await walk(
      root,
      "artifacts",
      (file) => path.posix.basename(file) === "README.md",
      (dir) => dir === "artifacts/local",
    )),
  );
  return files.sort();
}

// Fenced blocks are blanked rather than removed so findings keep their line numbers.
// Link scanning drops whole code spans; anchor collection keeps their text and
// drops only the backticks, matching how GitHub slugs a heading with inline code.
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
        docs.fail("links", file, number, "non-portable absolute link: " + target);
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
          docs.fail("links", file, number, "missing link target: " + target);
          continue;
        }
      }
      if (!anchor || !targetFile.endsWith(".md")) continue;
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

// scripts/check-skills.mjs, run as a stage against the same audited root so
// `npm run check:docs` covers skill staleness too. Its own findings keep
// their sub-check name in the message; the "skills" check groups them here.
async function checkSkillsStage(docs) {
  const script = path.join(scriptRoot, "scripts/check-skills.mjs");
  // Skip on a checkout with no .agents/skills tree at all (a docs-only
  // fixture, or a worktree that has not built any skills yet): the stage has
  // nothing to check, and package.json is not otherwise required here.
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

// The wave facts in STATE.md are checked against git history, so a promotion
// that nobody recorded fails the next docs check instead of misleading a
// fresh thread. scripts/wave-state.mjs owns the rules and the repair command.
async function checkWaveStateStage(docs) {
  const findings = await checkWaveState(docs.root);
  for (const finding of findings) {
    if (finding.level === "failure")
      docs.fail("wave-state", finding.file, finding.line, finding.message);
    else docs.info("wave-state", finding.file, finding.line, finding.message);
  }
  return findings.filter((finding) => finding.level === "failure").length;
}

// Several threads hand out ruling letters at the same time. Two rows that open
// with one letter mean two rulings answer to one name, so the later row fails.
// Only rows written "| Ruling xx," or "| Ruling xx:" carry a letter to check.
// The "Replaced rulings" section is skipped: its rows open with the old ruling,
// which may still have a row of its own above.
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

// The known-failing ledger is checked for shape here. A row past its review
// date is only a note in this check; it fails at the promotion gate
// (scripts/known-failing.mjs --promotion).
async function checkLedgerStage(docs) {
  const findings = await checkLedger(docs.root, { requireChecks: true });
  for (const finding of findings) {
    if (finding.level === "failure")
      docs.fail("known-failing", finding.file, finding.line, finding.message);
    else docs.info("known-failing", finding.file, finding.line, finding.message);
  }
  // The weekly list (ruling ca) sits beside the ledger and is checked with it.
  for (const finding of checkWeekly(docs.root)) {
    findings.push(finding);
    docs.fail("weekly-list", finding.file, finding.line, finding.message);
  }
  return findings.filter((finding) => finding.level === "failure").length;
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
