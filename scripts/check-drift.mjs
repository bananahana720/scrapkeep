import { createHash } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";

const repositoryRoot = path.resolve(import.meta.dirname, "..");
const defaultSections = path.join(repositoryRoot, "docs/tech/sections");
const limits =
  "Hash agreement only. A match proves the dependency's bytes are the ones the citing section recorded; it proves nothing about whether the citation, the line numbers or the claim built on them is still correct, and a mismatch is a finding for a card and a reviewer, not a defect this check judges.";

// A Sources bullet states a dependency hash in the three forms the admitted
// sections use -- `section bytes SHA256 <hex>`, `<CSV>` or `report bytes
// SHA256 <hex>`, and a bare `SHA256 <hex>` -- so the hash itself is matched
// and the wording before it is not.
const hashPattern = /SHA256\s+`([0-9a-fA-F]{64})`/g;
const linkPattern = /\[(?:[^\]]*)\]\(([^)]+)\)/g;
const tokenPattern = new RegExp(
  hashPattern.source + "|" + linkPattern.source,
  "g",
);

// BACKLOG.md and TRACKING.md anchors are record citations: a bullet writes
// `[HF-07b](HF-07b-commit-boundaries.md) revision 1 from
// [HF-07b](../../../BACKLOG.md#hf-07b) (...), section bytes SHA256 <hex>`,
// where the nearest preceding link names the card and the hash belongs to the
// section link before it. A register file changes on every card edit, so no
// section states its bytes; excluding its anchored form is what makes
// "nearest preceding link" bind to the file the hash was taken from.
const registerAnchors = new Set(["BACKLOG.md", "TRACKING.md"]);

function citablePath(target) {
  const withoutFragment = target.split("#")[0].trim();
  if (!withoutFragment) return null;
  if (/^[a-z][a-z0-9+.-]*:/i.test(withoutFragment)) return null;
  if (withoutFragment.startsWith("//")) return null;
  if (
    target.includes("#") &&
    registerAnchors.has(path.posix.basename(withoutFragment))
  )
    return null;
  return withoutFragment;
}

// An explicit root may sit outside the repository, so a path that escapes it
// is reported absolute rather than as a ladder of `..` segments.
function display(file) {
  const relative = path.relative(repositoryRoot, file);
  return relative.startsWith("..") ? file : relative;
}

function parseArguments(argv) {
  const options = { sections: defaultSections, resolveFrom: null };
  for (let index = 0; index < argv.length; index++) {
    const flag = argv[index];
    const value = argv[index + 1];
    if (flag === "--sections" && value) options.sections = path.resolve(value);
    else if (flag === "--resolve-from" && value)
      options.resolveFrom = path.resolve(value);
    else throw new Error("Unknown argument: " + flag);
    index++;
  }
  return options;
}

// Fenced blocks are blanked rather than removed so findings keep their line
// numbers, matching scripts/check-docs.mjs.
function visibleLines(content) {
  let fenced = false;
  return content.split("\n").map((line) => {
    if (/^\s*(```|~~~)/.test(line)) {
      fenced = !fenced;
      return "";
    }
    return fenced ? "" : line;
  });
}

// One bullet may wrap over following lines, so a bullet keeps its own first
// line number and absorbs continuation lines until the next bullet, blank line
// or heading.
function sourcesBullets(lines) {
  const bullets = [];
  let inSources = false;
  let current = null;
  for (const [index, line] of lines.entries()) {
    if (/^##\s/.test(line)) {
      current = null;
      inSources = /^##\s+Sources\s*$/.test(line);
      continue;
    }
    if (!inSources) continue;
    if (/^\s*[-*]\s+/.test(line)) {
      current = { line: index + 1, text: line };
      bullets.push(current);
    } else if (current && line.trim() && !/^#{1,6}\s/.test(line))
      current.text += " " + line.trim();
    else current = null;
  }
  return bullets;
}

const digests = new Map();
async function digest(file) {
  if (!digests.has(file))
    digests.set(
      file,
      readFile(file)
        .then((bytes) => createHash("sha256").update(bytes).digest("hex"))
        .catch(() => null),
    );
  return digests.get(file);
}

async function checkSection(options, sectionFile, findings) {
  const relativeSection = display(sectionFile);
  const resolveFrom = options.resolveFrom ?? path.dirname(sectionFile);
  const lines = visibleLines(await readFile(sectionFile, "utf8"));
  let citations = 0;
  for (const bullet of sourcesBullets(lines)) {
    let link = null;
    for (const token of bullet.text.matchAll(tokenPattern)) {
      const [, hash, target] = token;
      if (target !== undefined) {
        link = citablePath(target) ?? link;
        continue;
      }
      citations++;
      if (!link) {
        findings.push({
          level: "unbound",
          text:
            "UNBOUND " +
            relativeSection +
            ":" +
            bullet.line +
            " stated " +
            hash.toLowerCase() +
            " has no preceding repository-path link on its bullet",
        });
        continue;
      }
      const dependency = path.resolve(resolveFrom, link);
      const actual = await digest(dependency);
      if (actual === hash.toLowerCase()) continue;
      findings.push({
        level: "mismatch",
        text:
          "DRIFT " +
          relativeSection +
          ":" +
          bullet.line +
          " " +
          display(dependency) +
          " stated " +
          hash.toLowerCase() +
          " actual " +
          (actual ?? "missing"),
      });
    }
  }
  return citations;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const entries = await readdir(options.sections, { withFileTypes: true });
  const sections = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
    .map((entry) => path.join(options.sections, entry.name))
    .sort();
  const findings = [];
  let citations = 0;
  for (const section of sections)
    citations += await checkSection(options, section, findings);
  const mismatches = findings.filter((finding) => finding.level === "mismatch");
  const unbound = findings.length - mismatches.length;
  for (const finding of findings) console.log(finding.text);
  console.log(
    "check:drift " +
      (mismatches.length ? "fail" : "pass") +
      ": " +
      sections.length +
      " sections, " +
      citations +
      " stated hashes, " +
      mismatches.length +
      " mismatches, " +
      unbound +
      " unbound. Scanned " +
      display(options.sections) +
      ", dependencies resolved from " +
      (options.resolveFrom ? display(options.resolveFrom) : "each citing file"),
  );
  console.log(limits);
  process.exitCode = mismatches.length ? 1 : 0;
}

try {
  await main();
} catch (error) {
  console.error("check:drift internal error: " + (error?.stack ?? error));
  process.exitCode = 2;
}
