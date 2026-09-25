import { access, lstat, readFile, readdir, realpath } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const scriptRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

const limits =
  "Existence and shape checks only, not correctness: a rename that keeps the " +
  "old path alive as a stub is not caught, and a lesson whose evidence file " +
  "exists but no longer supports it is a review job, not this check's job.";

// DESIGN.md section 4b item 8, applied only under this directory.
const PORTABLE_SKILL_DIR = "reactive-model-loop";
const FORBIDDEN_PORTABLE_TOKENS = [
  "scrapkeep",
  "Scrapkeep",
  "Godot",
  "Jolt",
  "ball-lab",
  "cable-bench",
  "spillway",
  "EV-",
  "JL-",
  "Q-E",
  "Q-P",
  "artifacts/",
  "tools/",
  "scripts/",
  "npm run",
  "Andrew",
];
// The origin map lives here, when the project skill exists on this checkout.
const LAB_SKILL_DIR = "scrapkeep-lab";

const FRONTMATTER_DESCRIPTION_BLOCKLIST = new Set([
  "The",
  "A",
  "An",
  "This",
  "That",
  "It",
  "Its",
  "Skill",
  "Description",
]);

function parseArguments(argv) {
  const options = { root: scriptRoot, json: false };
  for (let index = 0; index < argv.length; index++) {
    const flag = argv[index];
    if (flag === "--root") {
      const value = argv[index + 1];
      if (value === undefined) throw new Error("--root needs a directory");
      options.root = path.resolve(value);
      index++;
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

// Fenced lines are blanked to "" so a code sample is never scanned for a
// repo-shaped path, matching scripts/check-docs.mjs's convention. Backticks
// are kept (unlike check-docs' visibleLines) because this check tokenizes on
// backtick spans itself.
function fenceBlankedLines(content) {
  let fenced = false;
  return content.split("\n").map((line) => {
    if (/^\s*(```|~~~)/.test(line)) {
      fenced = !fenced;
      return "";
    }
    return fenced ? "" : line;
  });
}

function lineAt(content, index) {
  let line = 1;
  for (let cursor = 0; cursor < index; cursor++)
    if (content[cursor] === "\n") line++;
  return line;
}

// --- Skill discovery -------------------------------------------------------

async function listSkillDirs(root) {
  const skillsRoot = path.join(root, ".agents/skills");
  if (!(await exists(skillsRoot))) return [];
  const entries = await readdir(skillsRoot, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

async function loadSkillFiles(root, name) {
  const dir = path.join(root, ".agents/skills", name);
  const files = [];
  const skillFile = ".agents/skills/" + name + "/SKILL.md";
  if (await exists(path.join(root, skillFile))) {
    files.push({
      relative: skillFile,
      content: await readFile(path.join(root, skillFile), "utf8"),
    });
  }
  const referencesDir = path.join(dir, "references");
  if (await exists(referencesDir)) {
    const entries = await readdir(referencesDir, { withFileTypes: true });
    for (const entry of entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
      .sort((a, b) => a.name.localeCompare(b.name))) {
      const relative =
        ".agents/skills/" + name + "/references/" + entry.name;
      files.push({
        relative,
        content: await readFile(path.join(root, relative), "utf8"),
      });
    }
  }
  return files;
}

// --- Check 1: frontmatter + Check 9: size -----------------------------------

function checkFrontmatterAndSize(findings, skillName, file) {
  const match = /^---\n([\s\S]*?)\n---\n/.exec(file.content);
  if (!match) {
    findings.fail(
      "frontmatter",
      file.relative,
      1,
      "no frontmatter block (--- ... ---) at the top of the file",
    );
    return;
  }
  const fields = {};
  for (const line of match[1].split("\n")) {
    const kv = /^([A-Za-z_]+):\s*(.*)$/.exec(line);
    if (kv) fields[kv[1]] = kv[2].trim();
  }
  if (fields.name !== skillName)
    findings.fail(
      "frontmatter",
      file.relative,
      1,
      "frontmatter name " +
        JSON.stringify(fields.name ?? null) +
        " does not match directory name " +
        JSON.stringify(skillName),
    );
  const rawDescription = fields.description;
  if (!rawDescription) {
    findings.fail("frontmatter", file.relative, 1, "missing description");
  } else {
    const description = rawDescription.replace(/^"|"$/g, "");
    if (description.length > 1024)
      findings.fail(
        "frontmatter",
        file.relative,
        1,
        "description is " + description.length + " chars, over the 1024 limit",
      );
    const firstWord = /^[A-Za-z']+/.exec(description)?.[0] ?? "";
    const looksLikeVerb =
      /^[A-Z][a-z']*$/.test(firstWord) &&
      !FRONTMATTER_DESCRIPTION_BLOCKLIST.has(firstWord);
    if (!looksLikeVerb)
      findings.fail(
        "frontmatter",
        file.relative,
        1,
        "description does not start with a verb or \"Use\": " +
          JSON.stringify(description.slice(0, 40)),
      );
  }

  const body = file.content.slice(match[0].length);
  const bodyLines = body.split("\n");
  if (bodyLines[bodyLines.length - 1] === "") bodyLines.pop();
  const count = bodyLines.length;
  if (count > 250)
    findings.fail(
      "size",
      file.relative,
      count,
      "SKILL.md body is " + count + " lines, over the 250-line failure limit",
    );
  else if (count > 150)
    findings.warn(
      "size",
      file.relative,
      count,
      "SKILL.md body is " + count + " lines, over the 150-line warning limit",
    );
}

// --- Check 2: .claude/skills link -------------------------------------------

async function checkLink(findings, root, skillName) {
  const linkFile = ".claude/skills/" + skillName;
  const linkPath = path.join(root, linkFile);
  const targetDir = ".agents/skills/" + skillName;
  let stat;
  try {
    stat = await lstat(linkPath);
  } catch {
    findings.fail("link", linkFile, 0, "missing: no .claude/skills/" + skillName);
    return;
  }
  if (!stat.isSymbolicLink()) {
    findings.fail("link", linkFile, 0, "exists but is not a symlink");
    return;
  }
  let resolved;
  try {
    resolved = await realpath(linkPath);
  } catch {
    findings.fail("link", linkFile, 0, "symlink target does not exist (dangling)");
    return;
  }
  let expected;
  try {
    expected = await realpath(path.join(root, targetDir));
  } catch {
    findings.fail(
      "link",
      linkFile,
      0,
      "resolves, but " + targetDir + " does not exist to compare against",
    );
    return;
  }
  if (resolved !== expected)
    findings.fail(
      "link",
      linkFile,
      0,
      "resolves to " + resolved + ", expected " + expected,
    );
}

// --- Check 3: paths ----------------------------------------------------------

const PATH_SUFFIX = /\.(mjs|gd|md|json)$/;
const PATH_PREFIX = /^[a-z0-9_.-]+\//;
const SCHEME = /^[a-z][a-z0-9+.-]*:/i;
const LINE_SUFFIX = /:\d+(-\d+)?$/;

function looksLikePath(token) {
  return PATH_PREFIX.test(token) || PATH_SUFFIX.test(token);
}

async function checkPaths(findings, root, file) {
  const lines = fenceBlankedLines(file.content);
  for (const [index, line] of lines.entries()) {
    for (const match of line.matchAll(/`([^`]+)`/g)) {
      const raw = match[1];
      if (/\s/.test(raw)) continue; // a command or sentence, not a bare path
      if (raw.includes("<")) continue; // placeholder token
      if (raw.includes("*")) continue; // glob token
      if (raw.startsWith('"') && raw.endsWith('"') && raw.length >= 2) continue; // quoted schema string
      if (SCHEME.test(raw)) continue; // URL or other scheme
      const stripped = raw.replace(LINE_SUFFIX, "");
      if (stripped.startsWith("/") || stripped.startsWith("~/")) continue; // outside repo
      if (!looksLikePath(stripped)) continue;
      if (!(await exists(path.join(root, stripped))))
        findings.fail(
          "paths",
          file.relative,
          index + 1,
          "path does not exist: " + stripped,
        );
    }
  }
}

// --- Check 4: npm scripts -----------------------------------------------------

async function loadPackageScripts(root) {
  const file = path.join(root, "package.json");
  const raw = await readFile(file, "utf8");
  const parsed = JSON.parse(raw);
  return parsed.scripts ?? {};
}

function checkNpmScripts(findings, file, scripts) {
  for (const match of file.content.matchAll(/npm (run [\w:-]+|test\b)/g)) {
    const line = lineAt(file.content, match.index);
    if (match[1] === "test") {
      if (!Object.hasOwn(scripts, "test"))
        findings.fail("npm", file.relative, line, "npm test: no \"test\" script in package.json");
      continue;
    }
    const name = match[1].slice("run ".length);
    if (!Object.hasOwn(scripts, name))
      findings.fail(
        "npm",
        file.relative,
        line,
        "npm run " + name + ": no matching script in package.json",
      );
  }
}

// --- Check 5: CLI verbs --------------------------------------------------------

async function checkVerbs(findings, root) {
  const file = "scripts/play.mjs";
  const absolute = path.join(root, file);
  if (!(await exists(absolute))) return;
  let module_;
  try {
    module_ = await import(pathToFileURL(absolute).href);
  } catch (error) {
    findings.warn(
      "verbs",
      file,
      0,
      "could not import scripts/play.mjs for verb validation: " +
        (error?.message ?? String(error)),
    );
    return;
  }
  const exported = ["verbs", "LAB_VERBS", "LAB_SUBVERBS"].filter((name) =>
    Object.hasOwn(module_, name),
  );
  if (exported.length === 0) {
    const raw = await readFile(absolute, "utf8");
    const usageStrings = [...raw.matchAll(/Usage:[^\n]*/g)].map((m) => m[0]);
    findings.warn(
      "verbs",
      file,
      0,
      "verb list not exported (verbs, LAB_VERBS, LAB_SUBVERBS); CLI verbs " +
        "cited in skills are not validated against it" +
        (usageStrings.length
          ? "; grepped usage strings: " + usageStrings.join(" | ")
          : ""),
    );
  }
}

// --- Check 6: EV / JL / Q ids --------------------------------------------------

async function loadTrackingEventIds(root) {
  const file = path.join(root, "TRACKING.md");
  if (!(await exists(file))) return null;
  const content = await readFile(file, "utf8");
  return new Set([...content.matchAll(/^\| (EV-\d{4}) \|/gm)].map((m) => m[1]));
}

async function loadBacklogAnchors(root) {
  const file = path.join(root, "BACKLOG.md");
  if (!(await exists(file))) return null;
  const content = await readFile(file, "utf8");
  return new Set(
    [...content.matchAll(/<a\s+(?:id|name)="([^"]+)"/g)].map((m) =>
      m[1].toLowerCase(),
    ),
  );
}

function checkIds(findings, file, eventIds, backlogAnchors) {
  if (eventIds !== null)
    for (const match of file.content.matchAll(/\bEV-\d{4}\b/g)) {
      const id = match[0];
      if (!eventIds.has(id))
        findings.fail(
          "ids",
          file.relative,
          lineAt(file.content, match.index),
          id + " is not a TRACKING.md event row",
        );
    }
  if (backlogAnchors !== null) {
    for (const match of file.content.matchAll(/\bJL-\d+[a-z]?\b/g)) {
      const id = match[0];
      if (!backlogAnchors.has(id.toLowerCase()))
        findings.fail(
          "ids",
          file.relative,
          lineAt(file.content, match.index),
          id + " has no <a id> anchor in BACKLOG.md",
        );
    }
    for (const match of file.content.matchAll(/\bQ-[EP]\d{2}\b/g)) {
      const id = match[0];
      if (!backlogAnchors.has(id.toLowerCase()))
        findings.fail(
          "ids",
          file.relative,
          lineAt(file.content, match.index),
          id + " has no <a id> anchor in BACKLOG.md",
        );
    }
  }
}

// --- Check 7: lesson ledgers ---------------------------------------------------

const LESSON_STATUSES = new Set(["established", "provisional", "retracted"]);

function parseLessons(content) {
  const lines = content.split("\n");
  const start = lines.findIndex((line) => line.trim() === "## Lessons");
  if (start === -1) return [];
  let end = start + 1;
  while (end < lines.length && !/^##\s/.test(lines[end])) end++;
  const lessons = [];
  let current = null;
  for (let index = start + 1; index < end; index++) {
    const line = lines[index];
    const header = /^- \*\*((?:RML|SKL)-\d+)\*\*\s*(?:·|\|)\s*status:\s*(\S+)/.exec(
      line,
    );
    if (header) {
      current = {
        id: header[1],
        status: header[2],
        evidence: "",
        overturned: "",
        line: index + 1,
      };
      lessons.push(current);
      continue;
    }
    if (!current) continue;
    const evidence = /^\s*Evidence:\s*(.*)$/.exec(line);
    if (evidence) current.evidence = evidence[1].trim();
    const overturned = /^\s*Overturned by:\s*(.*)$/.exec(line);
    if (overturned) current.overturned = overturned[1].trim();
  }
  return lessons;
}

function parseOriginMapIds(content) {
  const lines = content.split("\n");
  const start = lines.findIndex((line) => line.trim() === "## RML origin map");
  if (start === -1) return null;
  let end = start + 1;
  while (end < lines.length && !/^##\s/.test(lines[end])) end++;
  const ids = new Set();
  for (let index = start + 1; index < end; index++) {
    const match = /^\|\s*(RML-\d+)\s*\|/.exec(lines[index]);
    if (match) ids.add(match[1]);
  }
  return ids;
}

function checkLessonLedgers(findings, ledgerFiles, skillDirs, root) {
  const global = new Map(); // id -> {file, line}
  const allLessons = [];
  for (const file of ledgerFiles) {
    const lessons = parseLessons(file.content);
    for (const lesson of lessons) {
      allLessons.push({ ...lesson, file: file.relative });
      const previous = global.get(lesson.id);
      if (previous)
        findings.fail(
          "lessons",
          file.relative,
          lesson.line,
          "duplicate lesson id " +
            lesson.id +
            " (first seen at " +
            previous.file +
            ":" +
            previous.line +
            ")",
        );
      else global.set(lesson.id, { file: file.relative, line: lesson.line });

      if (!LESSON_STATUSES.has(lesson.status))
        findings.fail(
          "lessons",
          file.relative,
          lesson.line,
          lesson.id +
            ": status " +
            JSON.stringify(lesson.status) +
            " is not one of established, provisional, retracted",
        );
      if (lesson.evidence === "" || lesson.evidence === "—")
        findings.fail(
          "lessons",
          file.relative,
          lesson.line,
          lesson.id + ": Evidence is empty",
        );
      if (
        lesson.status === "retracted" &&
        (lesson.overturned === "" || lesson.overturned === "—")
      )
        findings.fail(
          "lessons",
          file.relative,
          lesson.line,
          lesson.id + ": status is retracted but Overturned by is empty",
        );
    }
  }

  // Every RML id must appear in the scrapkeep-lab origin map, when that skill
  // exists on this checkout (DESIGN.md 4b item 6/7 + the card's override).
  if (skillDirs.includes(LAB_SKILL_DIR)) {
    const originMapFile =
      ".agents/skills/" + LAB_SKILL_DIR + "/references/lessons.md";
    const originMapFull = ledgerFiles.find(
      (file) => file.relative === originMapFile,
    );
    const originIds = originMapFull
      ? parseOriginMapIds(originMapFull.content)
      : null;
    for (const lesson of allLessons) {
      if (!lesson.id.startsWith("RML-")) continue;
      if (originIds === null) {
        findings.fail(
          "lessons",
          originMapFile,
          0,
          "no \"## RML origin map\" table in " + originMapFile,
        );
        break;
      }
      if (!originIds.has(lesson.id))
        findings.fail(
          "lessons",
          lesson.file,
          lesson.line,
          lesson.id + " is missing from the scrapkeep-lab origin map",
        );
    }
  }

  return global;
}

function checkLessonCitations(findings, file, lessonIds) {
  for (const match of file.content.matchAll(/\((RML|SKL)-\d+\)/g)) {
    const id = match[0].slice(1, -1);
    if (!lessonIds.has(id))
      findings.fail(
        "lessons",
        file.relative,
        lineAt(file.content, match.index),
        "cited lesson " + id + " is not in any ledger",
      );
  }
}

// --- Check 8: portability ------------------------------------------------------

function checkPortability(findings, file) {
  if (!file.relative.startsWith(".agents/skills/" + PORTABLE_SKILL_DIR + "/"))
    return;
  for (const token of FORBIDDEN_PORTABLE_TOKENS) {
    let cursor = 0;
    while (true) {
      const index = file.content.indexOf(token, cursor);
      if (index === -1) break;
      findings.fail(
        "portability",
        file.relative,
        lineAt(file.content, index),
        "forbidden token " + JSON.stringify(token) + " in the portable skill",
      );
      cursor = index + token.length;
    }
  }
}

// --- Main ------------------------------------------------------------------

async function main() {
  let options;
  try {
    options = parseArguments(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 2;
    return;
  }
  if (!(await exists(options.root))) {
    console.error("--root does not exist: " + options.root);
    process.exitCode = 2;
    return;
  }
  let scripts;
  try {
    scripts = await loadPackageScripts(options.root);
  } catch (error) {
    console.error(
      "could not read/parse package.json at " +
        options.root +
        ": " +
        (error?.message ?? error),
    );
    process.exitCode = 2;
    return;
  }

  const findings = new Findings();
  const skillDirs = await listSkillDirs(options.root);
  const eventIds = await loadTrackingEventIds(options.root);
  const backlogAnchors = await loadBacklogAnchors(options.root);
  if (eventIds === null)
    findings.fail("ids", "TRACKING.md", 0, "TRACKING.md is missing; EV ids cannot be checked");
  if (backlogAnchors === null)
    findings.fail("ids", "BACKLOG.md", 0, "BACKLOG.md is missing; card ids cannot be checked");

  const allFilesBySkill = new Map();
  for (const skillName of skillDirs)
    allFilesBySkill.set(skillName, await loadSkillFiles(options.root, skillName));

  const allFiles = [...allFilesBySkill.values()].flat();
  const ledgerFiles = allFiles.filter((file) =>
    file.relative.endsWith("/references/lessons.md"),
  );

  for (const skillName of skillDirs) {
    const files = allFilesBySkill.get(skillName);
    const skillFile = files.find(
      (file) => file.relative === ".agents/skills/" + skillName + "/SKILL.md",
    );
    if (!skillFile) {
      findings.fail(
        "frontmatter",
        ".agents/skills/" + skillName + "/SKILL.md",
        0,
        "missing SKILL.md",
      );
      continue;
    }
    checkFrontmatterAndSize(findings, skillName, skillFile);
    await checkLink(findings, options.root, skillName);
  }

  for (const file of allFiles) {
    await checkPaths(findings, options.root, file);
    checkNpmScripts(findings, file, scripts);
    checkIds(findings, file, eventIds, backlogAnchors);
    checkPortability(findings, file);
  }

  const lessonIds = checkLessonLedgers(findings, ledgerFiles, skillDirs, options.root);
  for (const file of allFiles) checkLessonCitations(findings, file, lessonIds);

  await checkVerbs(findings, options.root);

  const failures = findings.list.filter((finding) => finding.level === "failure");
  if (options.json) {
    console.log(JSON.stringify(findings.list, null, 2));
  } else {
    for (const finding of findings.list)
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
      "check:skills " +
        (failures.length ? "fail" : "pass") +
        ": " +
        skillDirs.length +
        " skills, " +
        findings.list.length +
        " findings (" +
        failures.length +
        " failures, " +
        (findings.list.length - failures.length) +
        " warnings).",
    );
    console.log(limits);
  }
  process.exitCode = failures.length ? 1 : 0;
}

try {
  await main();
} catch (error) {
  console.error("check:skills internal error: " + (error?.stack ?? error));
  process.exitCode = 2;
}
