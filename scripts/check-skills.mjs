import { access, lstat, readFile, readdir, realpath } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const limits =
  "Existence and shape checks only, not correctness: a rename that keeps the " +
  "old path alive as a stub is not caught, and a lesson whose evidence file " +
  "exists but no longer supports it is a review job, not this check's job. " +
  "CLI-verb and path checks read scripts/play.mjs and skill files statically " +
  "(regex over source text), not by executing or importing them. Gitignore " +
  "matching is a best-effort subset (directory and bare-name patterns, simple " +
  "'*' globs), not full gitignore semantics.";

// DESIGN.md section 4b item 8, applied to the whole directory tree (N7).
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
// The origin map lives here, and SKL- ids are scoped here, when the project
// skill exists on this checkout.
const LAB_SKILL_DIR = "scrapkeep-lab";

// N1: an allowlist (not a blocklist) of imperative openers a frontmatter
// description may start with, "Use" always included.
const FRONTMATTER_VERB_ALLOWLIST = new Set([
  "Use",
  "Plan",
  "Execute",
  "Verify",
  "Run",
  "Design",
  "Build",
  "Check",
  "Review",
  "Add",
  "Create",
  "Update",
  "Fix",
  "Write",
  "Read",
  "Implement",
  "Extend",
  "Gate",
  "Port",
  "Manage",
  "Test",
  "Debug",
  "Configure",
  "Set",
  "Generate",
  "Validate",
  "Analyze",
  "Diagnose",
  "Extract",
  "Parse",
  "Compare",
  "Cut",
  "Start",
  "Load",
  "Resolve",
  "Discuss",
  "Prepare",
  "Explain",
  "Keep",
  "Ask",
  "Find",
  "List",
  "Open",
  "Close",
  "Record",
  "Report",
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

// CRLF normalised at the point of read so every regex and line count downstream
// (including frontmatter parsing, N1) sees only "\n".
async function readNormalized(file) {
  return (await readFile(file, "utf8")).replace(/\r\n/g, "\n");
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
  for (let cursor = 0; cursor < index; cursor++) if (content[cursor] === "\n") line++;
  return line;
}

function skillDirOf(relativeFile) {
  const match = /^\.agents\/skills\/([^/]+)\//.exec(relativeFile);
  return match ? ".agents/skills/" + match[1] : null;
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
      content: await readNormalized(path.join(root, skillFile)),
    });
  }
  const referencesDir = path.join(dir, "references");
  if (await exists(referencesDir)) {
    const entries = await readdir(referencesDir, { withFileTypes: true });
    for (const entry of entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
      .sort((a, b) => a.name.localeCompare(b.name))) {
      const relative = ".agents/skills/" + name + "/references/" + entry.name;
      files.push({
        relative,
        content: await readNormalized(path.join(root, relative)),
      });
    }
  }
  return files;
}

// Every file under a directory, recursively, root-relative posix paths.
async function walkFiles(root, dir) {
  const results = [];
  const absolute = path.join(root, dir);
  if (!(await exists(absolute))) return results;
  for (const entry of await readdir(absolute, { withFileTypes: true })) {
    const relative = path.posix.join(dir, entry.name);
    if (entry.isDirectory()) results.push(...(await walkFiles(root, relative)));
    else if (entry.isFile()) results.push(relative);
  }
  return results;
}

// --- Check 1: frontmatter + Check 9: size -----------------------------------

// N1: single-quoted, double-quoted, bare, folded (>) and literal (|) YAML
// scalars. Good enough for a two-field (name, description) frontmatter block,
// not a YAML parser.
function parseFrontmatterFields(block) {
  const lines = block.split("\n");
  const fields = {};
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const kv = /^([A-Za-z_]+):[ \t]?(.*)$/.exec(line);
    if (!kv) continue;
    const key = kv[1];
    let value = kv[2];
    const blockScalar = /^([>|])[+-]?\s*$/.exec(value.trim());
    if (blockScalar) {
      const style = blockScalar[1];
      const baseIndent = (/^\s*/.exec(line) ?? [""])[0].length;
      const collected = [];
      let j = i + 1;
      while (j < lines.length) {
        const next = lines[j];
        if (next.trim() === "") {
          collected.push("");
          j++;
          continue;
        }
        const indent = (/^\s*/.exec(next) ?? [""])[0].length;
        if (indent <= baseIndent) break;
        collected.push(next.trim());
        j++;
      }
      value =
        style === "|"
          ? collected.join("\n").trim()
          : collected.join(" ").replace(/\s+/g, " ").trim();
      i = j - 1;
    } else {
      value = value.trim();
      if (
        (value.startsWith('"') && value.endsWith('"') && value.length >= 2) ||
        (value.startsWith("'") && value.endsWith("'") && value.length >= 2)
      )
        value = value.slice(1, -1);
    }
    fields[key] = value;
  }
  return fields;
}

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
  const fields = parseFrontmatterFields(match[1]);
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
  const description = fields.description;
  if (!description) {
    findings.fail("frontmatter", file.relative, 1, "missing description");
  } else {
    if (description.length > 1024)
      findings.fail(
        "frontmatter",
        file.relative,
        1,
        "description is " + description.length + " chars, over the 1024 limit",
      );
    const firstWord = /^[A-Za-z']+/.exec(description)?.[0] ?? "";
    if (!FRONTMATTER_VERB_ALLOWLIST.has(firstWord))
      findings.fail(
        "frontmatter",
        file.relative,
        1,
        'description does not start with "Use" or an allowlisted verb: ' +
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
    findings.fail("link", linkFile, 0, "resolves to " + resolved + ", expected " + expected);
}

// --- Check 3: paths ----------------------------------------------------------

const PATH_SUFFIX = /\.(mjs|gd|md|json)$/;
const PATH_PREFIX = /^[a-z0-9_.-]+\//;
const SCHEME = /^[a-z][a-z0-9+.-]*:/i;
const LINE_SUFFIX = /:\d+(-\d+)?$/;
const ANCHOR_SUFFIX = /#[^#]*$/; // N8

function looksLikePath(token) {
  return PATH_PREFIX.test(token) || PATH_SUFFIX.test(token);
}

// N3: a best-effort subset of gitignore matching: directory patterns
// ("dir/"), path patterns ("a/b"), bare names at any depth ("node_modules"),
// and a single-level '*' glob within a pattern. Negation ("!...") is not
// re-included; this only ever turns a failure into a softer warning.
function parseGitignore(content) {
  return content
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line !== "" && !line.startsWith("#") && !line.startsWith("!"));
}

function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function isGitignored(patterns, candidate) {
  const segments = candidate.split("/");
  for (const raw of patterns) {
    let pattern = raw.endsWith("/") ? raw.slice(0, -1) : raw;
    pattern = pattern.replace(/^\//, "");
    const hasSlash = pattern.includes("/");
    const toRegExp = (text) =>
      new RegExp("^" + text.split("*").map(escapeRegExp).join("[^/]*") + "$");
    if (hasSlash) {
      if (candidate === pattern || candidate.startsWith(pattern + "/")) return true;
      if (pattern.includes("*")) {
        const re = new RegExp("^" + pattern.split("*").map(escapeRegExp).join(".*") + "(/|$)");
        if (re.test(candidate)) return true;
      }
    } else if (pattern.includes("*")) {
      const re = toRegExp(pattern);
      if (segments.some((segment) => re.test(segment))) return true;
    } else if (segments.includes(pattern)) {
      return true;
    }
  }
  return false;
}

// B4: every whitespace-separated word in a backtick span is checked on its
// own, so a real path inside a longer command ("node scripts/x.mjs") is
// caught; only a word carrying "<", "*" or a URL scheme is skipped outright.
// B5/N8: a path that fails root-relative resolution is retried relative to
// the citing skill's own directory (covers a bare "SKILL.md" self-reference,
// or "references/x.md" cited from the skill's own SKILL.md), and an
// "#anchor" suffix is stripped alongside ":line".
async function checkPaths(findings, root, file, gitignorePatterns) {
  const lines = fenceBlankedLines(file.content);
  const skillDir = skillDirOf(file.relative);
  for (const [index, line] of lines.entries()) {
    for (const match of line.matchAll(/`([^`]+)`/g)) {
      const raw = match[1];
      for (const word of raw.split(/\s+/).filter(Boolean)) {
        if (word.includes("<")) continue;
        if (word.includes("*")) continue;
        if (SCHEME.test(word)) continue;
        const stripped = word.replace(ANCHOR_SUFFIX, "").replace(LINE_SUFFIX, "");
        if (stripped === "") continue;
        if (stripped.startsWith("/") || stripped.startsWith("~/")) continue;
        if (!looksLikePath(stripped)) continue;
        if (await exists(path.join(root, stripped))) continue;
        if (skillDir !== null && (await exists(path.join(root, skillDir, stripped)))) continue;
        if (isGitignored(gitignorePatterns, stripped)) {
          findings.warn(
            "paths",
            file.relative,
            index + 1,
            "path is under a gitignored directory, not checkable in a fresh " +
              "clone: " +
              stripped,
          );
          continue;
        }
        // Phase 2 cleanup: scrapkeep-verify-formal is frozen during Phase 1 and
        // still carries the retired docs/project/README.md boilerplate line.
        if (
          file.relative === ".agents/skills/scrapkeep-verify-formal/SKILL.md" &&
          stripped === "docs/project/README.md"
        ) {
          findings.warn(
            "paths",
            file.relative,
            index + 1,
            "retired heavy-lane path pending Phase 2 cleanup: " + stripped,
          );
          continue;
        }
        findings.fail("paths", file.relative, index + 1, "path does not exist: " + stripped);
      }
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
        findings.fail("npm", file.relative, line, 'npm test: no "test" script in package.json');
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

// --- Check 5: CLI verbs, read statically (B2, never imported: N4) -----------

function extractQuotedArray(source, varName) {
  const declaration = new RegExp(
    "(?:const|let|var)\\s+" + varName + "\\s*=\\s*\\[([\\s\\S]*?)\\]",
  ).exec(source);
  if (!declaration) return null;
  return [...declaration[1].matchAll(/["'`]([^"'`]+)["'`]/g)].map((m) => m[1]);
}

function extractObjectKeys(source, varName) {
  const declaration = new RegExp("(?:const|let|var)\\s+" + varName + "\\s*=\\s*\\{").exec(source);
  if (!declaration) return null;
  let depth = 1;
  let i = declaration.index + declaration[0].length;
  const bodyStart = i;
  while (i < source.length && depth > 0) {
    if (source[i] === "{") depth++;
    else if (source[i] === "}") depth--;
    i++;
  }
  const body = source.slice(bodyStart, i - 1);
  const keys = new Set();
  for (const m of body.matchAll(/(?:^|[{,\n])\s*(?:"([^"]+)"|'([^']+)'|([A-Za-z_$][\w$]*))\s*:/g))
    keys.add(m[1] ?? m[2] ?? m[3]);
  return [...keys];
}

// The `verb === "lab"` style literal comparisons inside labRoute, found
// generically rather than by hard-coding "lab", so a future case is picked
// up without editing this script.
function extractLiteralVerbCases(source) {
  return [...source.matchAll(/\bverb\s*===\s*["'`]([^"'`]+)["'`]/g)].map((m) => m[1]);
}

async function checkVerbsStatic(findings, root, allFiles) {
  const file = "scripts/play.mjs";
  const absolute = path.join(root, file);
  if (!(await exists(absolute))) return;
  const source = await readNormalized(absolute);

  const verbsArray = extractQuotedArray(source, "verbs");
  const labVerbKeys = extractObjectKeys(source, "LAB_VERBS");
  const labSubverbKeys = extractObjectKeys(source, "LAB_SUBVERBS");
  const literalCases = extractLiteralVerbCases(source);

  const haveTop = verbsArray !== null || labVerbKeys !== null || literalCases.length > 0;
  const haveSub = labSubverbKeys !== null;
  if (!haveTop && !haveSub) {
    findings.warn(
      "verbs",
      file,
      0,
      "could not statically find verbs, LAB_VERBS or LAB_SUBVERBS in " +
        "scripts/play.mjs; CLI verb citations are not validated",
    );
    return;
  }
  if (!haveTop)
    findings.warn(
      "verbs",
      file,
      0,
      "could not statically find the top-level verb list (verbs, LAB_VERBS) " +
        "in scripts/play.mjs; top-level scrapkeep <verb> citations are not " +
        "validated",
    );

  const topSet = new Set([...(verbsArray ?? []), ...(labVerbKeys ?? []), ...literalCases]);
  const subSet = new Set(labSubverbKeys ?? []);

  for (const skillFile of allFiles) {
    if (haveSub)
      for (const match of skillFile.content.matchAll(/\bscrapkeep\s+lab\s+([A-Za-z][\w|-]*)/g)) {
        const line = lineAt(skillFile.content, match.index);
        for (const sub of match[1].split("|"))
          if (!subSet.has(sub))
            findings.fail(
              "verbs",
              skillFile.relative,
              line,
              "scrapkeep lab " + sub + ": not a lab sub-verb in scripts/play.mjs (LAB_SUBVERBS)",
            );
      }
    if (haveTop)
      for (const match of skillFile.content.matchAll(/\bscrapkeep\s+([A-Za-z][\w|-]*)/g)) {
        const line = lineAt(skillFile.content, match.index);
        for (const verb of match[1].split("|"))
          if (!topSet.has(verb))
            findings.fail(
              "verbs",
              skillFile.relative,
              line,
              "scrapkeep " + verb + ": not a verb in scripts/play.mjs (verbs/LAB_VERBS)",
            );
      }
  }
}

// --- Check 6: lesson ledgers ---------------------------------------------------

const LESSON_STATUSES = new Set(["established", "provisional", "retracted"]);

// B3: a loose match on "- **id**" that fails the strict header shape is a
// named "malformed lesson header" finding rather than silently swallowed
// into the previous lesson's body.
function parseLessons(content) {
  const lines = content.split("\n");
  const start = lines.findIndex((line) => line.trim() === "## Lessons");
  if (start === -1) return { lessons: [], sectionFound: false, malformed: [] };
  let end = start + 1;
  while (end < lines.length && !/^##\s/.test(lines[end])) end++;
  const lessons = [];
  const malformed = [];
  let current = null;
  for (let index = start + 1; index < end; index++) {
    const line = lines[index];
    const loose = /^- \*\*([^*]+)\*\*/.exec(line);
    if (loose) {
      const header =
        /^- \*\*((?:RML|SKL|BLK|VGM|VBD|VWB|VFM|AGW|SVR)-\d+)\*\*\s*·\s*status:\s*(\S+)/.exec(line);
      if (header) {
        current = {
          id: header[1],
          status: header[2],
          evidence: "",
          overturned: "",
          line: index + 1,
        };
        lessons.push(current);
      } else {
        malformed.push({ line: index + 1, text: line.trim() });
        current = null;
      }
      continue;
    }
    if (!current) continue;
    const evidence = /^\s*Evidence:\s*(.*)$/.exec(line);
    if (evidence) current.evidence = evidence[1].trim();
    const overturned = /^\s*Overturned by:\s*(.*)$/.exec(line);
    if (overturned) current.overturned = overturned[1].trim();
  }
  return { lessons, sectionFound: true, malformed };
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

// B1: the newest Changelog row's date must not be earlier than any retracted
// lesson's Overturned-by date (parsed as the first \d{4}-\d{2}-\d{2} in that
// field). Returns null when the section is missing entirely.
function parseChangelogDates(content) {
  const lines = content.split("\n");
  const start = lines.findIndex((line) => line.trim() === "## Changelog");
  if (start === -1) return null;
  let end = start + 1;
  while (end < lines.length && !/^##\s/.test(lines[end])) end++;
  const dates = [];
  for (let index = start + 1; index < end; index++) {
    const row = lines[index];
    if (!row.startsWith("|") || /^\|\s*-{3}/.test(row)) continue;
    const cell = row.split("|")[1]?.trim() ?? "";
    if (/^\d{4}-\d{2}-\d{2}$/.test(cell)) dates.push(cell);
  }
  return dates;
}

function checkChangelog(findings, file, lessons) {
  const dates = parseChangelogDates(file.content);
  if (dates === null) {
    findings.fail("changelog", file.relative, 0, 'no "## Changelog" section');
    return;
  }
  const newest = dates.length ? dates.reduce((a, b) => (a > b ? a : b)) : null;
  for (const lesson of lessons) {
    if (lesson.status !== "retracted") continue;
    const match = /\d{4}-\d{2}-\d{2}/.exec(lesson.overturned);
    if (!match) continue;
    const overturnedDate = match[0];
    if (newest === null || overturnedDate > newest)
      findings.fail(
        "changelog",
        file.relative,
        lesson.line,
        lesson.id +
          ": Overturned by date " +
          overturnedDate +
          " is after the newest Changelog row (" +
          (newest ?? "none") +
          ")",
      );
  }
}

function checkLessonLedgers(findings, ledgerFiles, skillDirs) {
  const global = new Map(); // id -> {file, line}
  const allLessons = [];
  for (const file of ledgerFiles) {
    const { lessons, sectionFound, malformed } = parseLessons(file.content);
    if (!sectionFound) findings.fail("lessons", file.relative, 0, 'no "## Lessons" section');
    for (const bad of malformed)
      findings.fail(
        "lessons",
        file.relative,
        bad.line,
        "malformed lesson header: " + JSON.stringify(bad.text.slice(0, 80)),
      );
    checkChangelog(findings, file, lessons);
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

      // B3: RML- only inside the portable skill, SKL- only inside the lab skill.
      if (
        lesson.id.startsWith("RML-") &&
        !file.relative.startsWith(".agents/skills/" + PORTABLE_SKILL_DIR + "/")
      )
        findings.fail(
          "lessons",
          file.relative,
          lesson.line,
          lesson.id + ": RML- ids belong only in " + PORTABLE_SKILL_DIR,
        );
      if (
        lesson.id.startsWith("SKL-") &&
        !file.relative.startsWith(".agents/skills/" + LAB_SKILL_DIR + "/")
      )
        findings.fail(
          "lessons",
          file.relative,
          lesson.line,
          lesson.id + ": SKL- ids belong only in " + LAB_SKILL_DIR,
        );

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
        findings.fail("lessons", file.relative, lesson.line, lesson.id + ": Evidence is empty");
      if (lesson.status === "retracted" && (lesson.overturned === "" || lesson.overturned === "—"))
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
    const originMapFile = ".agents/skills/" + LAB_SKILL_DIR + "/references/lessons.md";
    const originMapFull = ledgerFiles.find((file) => file.relative === originMapFile);
    const originIds = originMapFull ? parseOriginMapIds(originMapFull.content) : null;
    for (const lesson of allLessons) {
      if (!lesson.id.startsWith("RML-")) continue;
      if (originIds === null) {
        findings.fail(
          "lessons",
          originMapFile,
          0,
          'no "## RML origin map" table in ' + originMapFile,
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

// B3: recognises multi-id citations like "(SKL-15, SKL-32)".
function checkLessonCitations(findings, file, lessonIds) {
  for (const match of file.content.matchAll(
    /\(((?:RML|SKL|BLK|VGM|VBD|VWB|VFM|AGW|SVR)-\d+(?:,\s*(?:RML|SKL|BLK|VGM|VBD|VWB|VFM|AGW|SVR)-\d+)*)\)/g,
  )) {
    const line = lineAt(file.content, match.index);
    for (const id of match[1].split(",").map((entry) => entry.trim()))
      if (!lessonIds.has(id))
        findings.fail(
          "lessons",
          file.relative,
          line,
          "cited lesson " + id + " is not in any ledger",
        );
  }
}

// --- Check 8: portability (N7: every file under the portable skill) --------

function checkPortability(findings, file) {
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

async function checkPortabilityFull(findings, root, skillDirs) {
  if (!skillDirs.includes(PORTABLE_SKILL_DIR)) return;
  const files = await walkFiles(root, ".agents/skills/" + PORTABLE_SKILL_DIR);
  for (const relative of files.sort()) {
    let content;
    try {
      content = await readNormalized(path.join(root, relative));
    } catch {
      continue; // unreadable/binary; existence-only scope, skip
    }
    checkPortability(findings, { relative, content });
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
      "could not read/parse package.json at " + options.root + ": " + (error?.message ?? error),
    );
    process.exitCode = 2;
    return;
  }

  const gitignorePatterns = (await exists(path.join(options.root, ".gitignore")))
    ? parseGitignore(await readNormalized(path.join(options.root, ".gitignore")))
    : [];

  const findings = new Findings();
  const skillDirs = await listSkillDirs(options.root);

  const allFilesBySkill = new Map();
  for (const skillName of skillDirs)
    allFilesBySkill.set(skillName, await loadSkillFiles(options.root, skillName));

  const allFiles = [...allFilesBySkill.values()].flat();
  const ledgerFiles = allFiles.filter((file) => file.relative.endsWith("/references/lessons.md"));

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
    await checkPaths(findings, options.root, file, gitignorePatterns);
    checkNpmScripts(findings, file, scripts);
  }
  await checkPortabilityFull(findings, options.root, skillDirs);

  const lessonIds = checkLessonLedgers(findings, ledgerFiles, skillDirs);
  for (const file of allFiles) checkLessonCitations(findings, file, lessonIds);

  await checkVerbsStatic(findings, options.root, allFiles);

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
