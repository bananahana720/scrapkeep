#!/usr/bin/env node
// PD-01 paper check. Asserts the structural claims of the production art
// acceptance brief that no repository command covers: check:drift scans only
// docs/tech/sections, and check:docs enforces required headings only there too.
//
// Usage: node paper-check.mjs --root <repository-root> --out <directory>
//        [--section <path relative to root>]
// Exit 0 all assertions pass, 1 an assertion failed, 2 internal error.

import { createHash } from "node:crypto";
import { readFile, mkdir, writeFile, access } from "node:fs/promises";
import path from "node:path";

const DEFAULT_SECTION = "docs/product/sections/PD-01-art-acceptance.md";
const CARD_QUESTIONS = [
  "Q-P01", "Q-P02", "Q-P03", "Q-P04", "Q-P05", "Q-P06", "Q-P07",
  "Q-P22", "Q-P26", "Q-P27", "Q-P29", "Q-P33", "Q-P34",
];
const ROW_ID = /\b(AC|PE|VW|PF|CC|RL)-\d{2}\b/g;

function parseArgs(argv) {
  const args = { root: null, out: null, section: DEFAULT_SECTION };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === "--root") args.root = argv[++i];
    else if (flag === "--out") args.out = argv[++i];
    else if (flag === "--section") args.section = argv[++i];
    else throw new Error("unknown argument: " + flag);
  }
  if (!args.root) throw new Error("--root <repository-root> is required");
  if (!args.out) throw new Error("--out <directory> is required");
  args.root = path.resolve(args.root);
  args.out = path.resolve(args.out);
  return args;
}

function slugify(heading) {
  return heading
    .replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1")
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s_-]/gu, "")
    .replace(/\s/g, "-");
}

function collectAnchors(content) {
  const anchors = new Set();
  const seen = new Map();
  for (const raw of content.split("\n")) {
    const line = raw.replace(/`/g, "");
    const heading = /^#{1,6}\s+(.*?)\s*#*\s*$/.exec(line);
    if (heading) {
      const base = slugify(heading[1]);
      const count = seen.get(base) ?? 0;
      seen.set(base, count + 1);
      anchors.add(count === 0 ? base : base + "-" + count);
    }
    for (const match of line.matchAll(/<a\s+(?:name|id)="([^"]+)"/g))
      anchors.add(match[1]);
  }
  return anchors;
}

function tableRows(text, prefix) {
  const rows = [];
  for (const line of text.split("\n")) {
    if (!line.startsWith("| " + prefix) && !line.startsWith("| [" + prefix)) continue;
    const cells = line.split("|").slice(1, -1).map((cell) => cell.trim());
    if (cells.length < 3) continue;
    rows.push({ cells, line });
  }
  return rows;
}

// Sentence split is deliberately crude: it over-segments on abbreviations,
// which can only add candidate sentences to the redraw scan, never hide one.
function sentences(text) {
  return text
    .replace(/\n+/g, " ")
    .split(/(?<=[.!?])\s+/)
    .map((s) => s.trim())
    .filter(Boolean);
}

async function exists(file) {
  try {
    await access(file);
    return true;
  } catch {
    return false;
  }
}

async function runAssertions(root, sectionPath, text) {
  const failures = [];
  const counts = {};
  const sectionDir = path.dirname(path.join(root, sectionPath));
  const fail = (code, detail) => failures.push({ code, detail });

  // A1: every AD identifier in BIBLE section 7 has at least one acceptance row.
  const bible = await readFile(path.join(root, "BIBLE.md"), "utf8");
  const start = bible.indexOf("\n## 7. Art Direction");
  const end = bible.indexOf("\n## 8.", start + 1);
  if (start < 0 || end < 0) fail("A1-source", "BIBLE section 7 boundaries not found");
  const sectionSeven = bible.slice(start, end);
  const adIds = [...sectionSeven.matchAll(/^### (AD-\d{2})\./gm)].map((m) => m[1]);
  counts.ad_identifiers_in_bible = adIds.length;

  const acRows = tableRows(text, "AC-");
  counts.acceptance_rows = acRows.length;
  const covered = new Map();
  for (const row of acRows) {
    const [id, rule, observable, failsWhen, source] = row.cells;
    for (const m of rule.matchAll(/AD-\d{2}/g)) {
      if (!covered.has(m[0])) covered.set(m[0], []);
      covered.get(m[0]).push(id);
    }
    if (observable.length < 25) fail("A1-observable", id + ": observable check cell is not a check");
    if (!failsWhen || failsWhen.length < 10) fail("A1-observable", id + ": no failure condition");
    // A2: every acceptance row traces to an approved line or a named cohesion limitation.
    if (!/BIBLE lines? \d+|COHESION lines? \d+/.test(source))
      fail("A2-source", id + ": source cell cites no BIBLE section 7 line or cohesion limitation");
  }
  for (const ad of adIds)
    if (!covered.has(ad)) fail("A1-coverage", ad + ": no acceptance row maps this rule");
  counts.ad_identifiers_covered = adIds.filter((ad) => covered.has(ad)).length;

  // A3: every required-evidence row names property, evidence form and a non-proof.
  const peRows = tableRows(text, "PE-");
  counts.evidence_rows = peRows.length;
  for (const row of peRows) {
    const [id, property, form, notProved, gate] = row.cells;
    if (!property || property.length < 10) fail("A3-property", id + ": no named property");
    if (!form || form.length < 20) fail("A3-form", id + ": no evidence form");
    if (!notProved || notProved.length < 20) fail("A3-limit", id + ": no fact the evidence does not prove");
    if (!/Q-[EP]\d{2}|TH-\d{2}|COHESION line/.test(gate)) fail("A3-gate", id + ": no gate or source");
  }

  // A4: every card question appears, gates a defined row, and states no value.
  const definedRows = new Set();
  for (const prefix of ["AC-", "PE-", "VW-", "PF-", "CC-", "RL-"])
    for (const row of tableRows(text, prefix)) definedRows.add(row.cells[0]);
  counts.defined_rows = definedRows.size;

  const qRows = tableRows(text, "Q-P");
  counts.question_rows = qRows.length;
  const seenQuestions = new Set();
  for (const row of qRows) {
    const [question, owns, gates, value] = row.cells;
    const id = /Q-P\d{2}/.exec(question)?.[0];
    if (!id) continue;
    seenQuestions.add(id);
    if (!owns || owns.length < 20) fail("A4-owns", id + ": does not state what it owns");
    const gated = [...gates.matchAll(ROW_ID)].map((m) => m[0]);
    if (gated.length === 0) fail("A4-gates", id + ": names no row it gates");
    for (const rowId of gated)
      if (!definedRows.has(rowId)) fail("A4-gates", id + ": gates undefined row " + rowId);
    if (value !== "none") fail("A4-value", id + ": states a value (" + value + ") instead of none");
  }
  for (const q of CARD_QUESTIONS)
    if (!seenQuestions.has(q)) fail("A4-missing", q + ": card question absent from the register table");

  // A4b: every row ID referenced anywhere in the section is defined.
  for (const m of text.matchAll(ROW_ID))
    if (!definedRows.has(m[0])) fail("A4-undefined", "referenced row " + m[0] + " is not defined");

  // A5: every local link resolves, and every .md anchor exists.
  const links = [...text.matchAll(/!?\[[^\]]*\]\(([^)\s]+)\)/g)].map((m) => m[1]);
  counts.local_links = 0;
  for (const target of links) {
    if (/^(https?:|mailto:)/.test(target)) continue;
    if (target.startsWith("#")) continue;
    counts.local_links += 1;
    const [file, anchor] = target.split("#");
    const resolved = path.resolve(sectionDir, file);
    if (!(await exists(resolved))) {
      fail("A5-link", "missing link target: " + target);
      continue;
    }
    if (anchor && resolved.endsWith(".md")) {
      const anchors = collectAnchors(await readFile(resolved, "utf8"));
      if (!anchors.has(decodeURIComponent(anchor)))
        fail("A5-anchor", "broken anchor: " + target);
    }
  }

  // A6: every stated hash matches the file of the nearest preceding link on its line.
  counts.stated_hashes = 0;
  for (const line of text.split("\n")) {
    const hashes = [...line.matchAll(/`([0-9a-f]{64})`/g)];
    if (hashes.length === 0) continue;
    const linkPositions = [...line.matchAll(/!?\[[^\]]*\]\(([^)\s]+)\)/g)];
    for (const hashMatch of hashes) {
      counts.stated_hashes += 1;
      let owner = null;
      for (const link of linkPositions) if (link.index < hashMatch.index) owner = link;
      if (!owner) {
        fail("A6-owner", "stated hash with no preceding file link: " + hashMatch[1]);
        continue;
      }
      const file = owner[1].split("#")[0];
      const resolved = path.resolve(sectionDir, file);
      if (!(await exists(resolved))) {
        fail("A6-owner", "stated hash names missing file: " + file);
        continue;
      }
      const actual = createHash("sha256").update(await readFile(resolved)).digest("hex");
      if (actual !== hashMatch[1])
        fail("A6-hash", file + ": stated " + hashMatch[1] + " actual " + actual);
    }
  }

  // A7: no sentence requests further concept work.
  const redraw = /\b(redraw|redrawn|redrawing|regenerate|regenerated|regenerating|re-?render(?:ed|ing)?|reissue|new concept image|another concept image|additional concept image|art generation|image generation)\b/i;
  const negation = /\b(no|not|never|cannot|nor|without|neither)\b/i;
  counts.redraw_candidate_sentences = 0;
  for (const sentence of sentences(text)) {
    if (!redraw.test(sentence)) continue;
    counts.redraw_candidate_sentences += 1;
    if (!negation.test(sentence)) fail("A7-redraw", "sentence requests concept work: " + sentence);
  }

  return { failures, counts };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const sectionFile = path.join(args.root, args.section);
  const text = await readFile(sectionFile, "utf8");

  const primary = await runAssertions(args.root, args.section, text);

  // Negative controls. Each mutates a copy of the section and must fail with the
  // named code; a control that passes means the assertion is not actually wired.
  const controls = [
    {
      id: "NC-1",
      expect: "A1-coverage",
      why: "an uncovered AD identifier must be caught",
      mutate: (t) => t.replace("| AC-10 | AD-01, AD-07, AD-11 |", "| AC-10 | AD-01, AD-11 |"),
    },
    {
      id: "NC-2",
      expect: "A3-limit",
      why: "an evidence row with no stated non-proof must be caught",
      mutate: (t) =>
        t.replace(
          /(\| PE-01 \| [^|]*\| [^|]*\| )[^|]*(\|)/,
          "$1 $2",
        ),
    },
    {
      id: "NC-3",
      expect: "A4-value",
      why: "a question row that states a value must be caught",
      mutate: (t) =>
        t.replace(
          "| PE-08 | none |",
          "| PE-08 | 60 mm single-piece figure |",
        ),
    },
    {
      id: "NC-4",
      expect: "A6-hash",
      why: "a stated hash that no longer matches must be caught",
      mutate: (t) =>
        t.replace(
          "98e19c20d6b0247af5b8b573bf6b5e3c1bdcfb2958dba11def8f834f8d9d01e3",
          "0000000000000000000000000000000000000000000000000000000000000000",
        ),
    },
    {
      id: "NC-5",
      expect: "A7-redraw",
      why: "an imperative request for further concept work must be caught",
      mutate: (t) => t + "\n\nThe technical artist must redraw M01 at production fidelity.\n",
    },
    {
      id: "NC-6",
      expect: "A5-link",
      why: "an unresolvable local link must be caught",
      mutate: (t) => t.replace("../../bible/images/M04-v2.png", "../../bible/images/M04-v9.png"),
    },
  ];

  const controlResults = [];
  for (const control of controls) {
    const mutated = control.mutate(text);
    if (mutated === text) {
      controlResults.push({ ...control, mutate: undefined, status: "ERROR", detail: "mutation did not change the section" });
      continue;
    }
    const result = await runAssertions(args.root, args.section, mutated);
    const caught = result.failures.some((f) => f.code === control.expect);
    controlResults.push({
      id: control.id,
      expect: control.expect,
      why: control.why,
      status: caught ? "PASS" : "FAIL",
      failures: result.failures.map((f) => f.code),
    });
  }

  const controlsOk = controlResults.every((c) => c.status === "PASS");
  const ok = primary.failures.length === 0 && controlsOk;

  const report = {
    tool: "PD-01 paper check",
    root: args.root,
    section: args.section,
    section_sha256: createHash("sha256").update(await readFile(sectionFile)).digest("hex"),
    generated: new Date().toISOString(),
    counts: primary.counts,
    failures: primary.failures,
    negative_controls: controlResults,
    result: ok ? "PASS" : "FAIL",
    limits:
      "Structural assertions only. Hash pairing uses the nearest preceding link on the same line. The redraw scan is lexical and clears a matching sentence that carries a negation. Nothing here inspects image pixels, runs a build, an engine or a browser, or establishes any production property.",
  };

  await mkdir(args.out, { recursive: true });
  await writeFile(path.join(args.out, "paper-check.json"), JSON.stringify(report, null, 2) + "\n");

  for (const [key, value] of Object.entries(primary.counts)) console.log(key + ": " + value);
  for (const failure of primary.failures) console.log("FAIL " + failure.code + " " + failure.detail);
  for (const c of controlResults) console.log("control " + c.id + " expect " + c.expect + ": " + c.status);
  console.log("result: " + report.result);
  process.exit(ok ? 0 : 1);
}

main().catch((error) => {
  console.error("internal error: " + error.message);
  process.exit(2);
});
