import { createHash } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";

const repositoryRoot = path.resolve(import.meta.dirname, "..");
const technicalSections = path.join(repositoryRoot, "docs/tech/sections");
const productSections = path.join(repositoryRoot, "docs/product/sections");
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

// Both corpora state hashes in the same Sources-bullet form and report the
// same DRIFT line form. They differ in resolution and in what an empty section
// means. A technical section cites files relative to itself only. A product
// section cites the technical sections it depends on, so a link that does not
// exist beside it is resolved from docs/tech/sections next, and a product
// section that states no dependency hash at all is reported unbound instead of
// passing silently -- an admitted product section is required to state the
// bytes it depends on, and the Handoff-6 closure had to re-point those hashes
// by hand because nothing scanned them. The technical corpus keeps exactly the
// assertions it made before this check was widened.
const technicalCorpus = {
  label: "technical",
  root: technicalSections,
  fallbacks: [],
  requireCitations: false,
};
const productCorpus = {
  label: "product",
  root: productSections,
  fallbacks: [technicalSections],
  requireCitations: true,
};

// A directory index is the coordinator's, is not an admitted section and
// states no dependency hashes by design, so it is still scanned for any hash
// it does state but is never reported unbound for stating none.
const indexName = "README.md";

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

// `--sections` keeps its meaning, the technical corpus over an explicit root,
// so an existing copy run is unchanged; `--product-sections` is its product
// equivalent. Naming either root scans that corpus alone; naming neither scans
// both admitted corpora.
function parseArguments(argv) {
  let technical = null;
  let product = null;
  let resolveFrom = null;
  for (let index = 0; index < argv.length; index++) {
    const flag = argv[index];
    const value = argv[index + 1];
    if (flag === "--sections" && value) technical = path.resolve(value);
    else if (flag === "--product-sections" && value)
      product = path.resolve(value);
    else if (flag === "--resolve-from" && value)
      resolveFrom = path.resolve(value);
    else throw new Error("Unknown argument: " + flag);
    index++;
  }
  const corpora = [];
  if (technical) corpora.push({ ...technicalCorpus, root: technical });
  if (product) corpora.push({ ...productCorpus, root: product });
  if (!corpora.length) corpora.push(technicalCorpus, productCorpus);
  return { corpora, resolveFrom };
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

// The first root that holds the linked file is the one the hash is compared
// against, so a fallback root can never mask a dependency that exists beside
// the citing section. A link no root resolves is reported against the citing
// section's own resolution with an actual of `missing`, exactly as a technical
// section's unresolvable link is.
async function bind(roots, link) {
  const candidates = roots.map((root) => path.resolve(root, link));
  for (const candidate of candidates) {
    const actual = await digest(candidate);
    if (actual !== null) return { file: candidate, actual };
  }
  return { file: candidates[0], actual: null };
}

async function checkSection(corpus, options, sectionFile, findings) {
  const relativeSection = display(sectionFile);
  const roots = [
    options.resolveFrom ?? path.dirname(sectionFile),
    ...corpus.fallbacks,
  ];
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
      const { file, actual } = await bind(roots, link);
      if (actual === hash.toLowerCase()) continue;
      findings.push({
        level: "mismatch",
        text:
          "DRIFT " +
          relativeSection +
          ":" +
          bullet.line +
          " " +
          display(file) +
          " stated " +
          hash.toLowerCase() +
          " actual " +
          (actual ?? "missing"),
      });
    }
  }
  if (
    corpus.requireCitations &&
    citations === 0 &&
    path.basename(sectionFile) !== indexName
  )
    findings.push({
      level: "unbound",
      text:
        "UNBOUND " +
        relativeSection +
        " states no dependency hash in its Sources bullets",
    });
  return citations;
}

async function checkCorpus(corpus, options) {
  const entries = await readdir(corpus.root, { withFileTypes: true });
  const sections = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
    .map((entry) => path.join(corpus.root, entry.name))
    .sort();
  const findings = [];
  let citations = 0;
  for (const section of sections)
    citations += await checkSection(corpus, options, section, findings);
  const mismatches = findings.filter(
    (finding) => finding.level === "mismatch",
  ).length;
  return {
    corpus,
    findings,
    sections: sections.length,
    citations,
    mismatches,
    unbound: findings.length - mismatches,
  };
}

function counts(totals) {
  return (
    totals.sections +
    " sections, " +
    totals.citations +
    " stated hashes, " +
    totals.mismatches +
    " mismatches, " +
    totals.unbound +
    " unbound"
  );
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const results = [];
  for (const corpus of options.corpora)
    results.push(await checkCorpus(corpus, options));
  const totals = { sections: 0, citations: 0, mismatches: 0, unbound: 0 };
  for (const result of results)
    for (const key of Object.keys(totals)) totals[key] += result[key];
  for (const result of results)
    for (const finding of result.findings) console.log(finding.text);
  for (const result of results)
    console.log(
      "check:drift " +
        result.corpus.label +
        " " +
        (result.mismatches ? "fail" : "pass") +
        ": " +
        counts(result) +
        ". Scanned " +
        display(result.corpus.root) +
        ", dependencies resolved from " +
        (options.resolveFrom
          ? display(options.resolveFrom)
          : "each citing file") +
        (result.corpus.fallbacks.length
          ? " then " + result.corpus.fallbacks.map(display).join(" then ")
          : ""),
    );
  console.log(
    "check:drift " +
      (totals.mismatches ? "fail" : "pass") +
      ": " +
      counts(totals) +
      " over " +
      results.length +
      (results.length === 1 ? " corpus: " : " corpora: ") +
      results.map((result) => result.corpus.label).join(", "),
  );
  console.log(limits);
  process.exitCode = totals.mismatches ? 1 : 0;
}

try {
  await main();
} catch (error) {
  console.error("check:drift internal error: " + (error?.stack ?? error));
  process.exitCode = 2;
}
