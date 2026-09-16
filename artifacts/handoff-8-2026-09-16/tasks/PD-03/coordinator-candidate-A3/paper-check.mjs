#!/usr/bin/env node
// PD-03 paper check. Asserts the sound and feel event brief against its card,
// its citations and its walk gates. Documentation-only: it runs no build,
// browser, engine or audio and establishes nothing about sound.
//
// Usage: node paper-check.mjs --root <repository-root> --out <directory>

import { createHash } from "node:crypto";
import { readFile, readdir, mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

const DOC = "docs/product/sections/PD-03-sound-feel-events.md";
const HEADINGS = [
  "Sources",
  "Contract",
  "Scenarios",
  "Unresolved questions",
  "Re-verification triggers",
  "Procedure performed",
  "Evidence limits",
];
const FAMILIES = [
  "attraction",
  "fabrication",
  "rolling",
  "jump",
  "rebound",
  "weapon",
  "device",
  "ultimate",
  "enemy warning",
  "UI",
  "revival",
  "defeat",
  "discovery",
];
const LABELS = ["proposal", "browser proof", "accepted invariant"];
const QUESTIONS = ["Q-P13", "Q-P17", "Q-P20", "Q-P28", "Q-P31", "Q-P32"];
const SCENARIOS = ["starting kit", "dense ordinary fight", "exceptional build"];
const PLAYBACK = ["quiet playback", "sound disabled"];
const EXPECTED_COUNTS = { SE: 22, BP: 7, SI: 14, UD: 14, SP: 14, AU: 6, FT: 2, WK: 5 };
const SECTION_8 = [741, 808];
const SECTION_6 = [469, 615];

const DANGER = /\b(danger\w*|threat\w*|warning\w*|telegraph\w*|damage\w*|attack\w*|lethal|defeat\w*)\b/i;
const MUSIC = /\b(beats?|downbeats?|bars?|bar lines?|phrases?|quantiz\w*|tempo|musical? (timing|clock|grid|boundar\w*))\b/i;
// A prohibition such as "never waits for a beat" names music timing in order
// to forbid it; only the negated span is removed, so any other music word in
// the same row still fails.
const NEGATED_MUSIC = /\b(never|not|no)\b[^.;|]{0,60}?\b(beats?|downbeats?|bars?|phrases?|quantiz\w*|tempo|music\w*)\b/gi;

const FORBIDDEN = [
  ["asset count", /(?<![-§]\s?)(?<![\w-])(\d+|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|dozens?|hundreds?)\s+(sounds?|sound files?|assets?|recordings?|samples?|stems?|tracks?|variations?|voice lines?|barks?)\b/i],
  ["capture scope", /\brecordings?\b|\brecording (session|scope|batch|plan|list)\b|\bstudio\b|\bfoley session\b/i],
  ["loudness value", /-?\d+(\.\d+)?\s*(dB|dBFS|LUFS|decibels?|%|percent)\b/i],
  ["loudness value", /\b(LUFS|dBFS|decibels?)\b/i],
  ["loudness value", /\b(volume|gain|level|loudness) (of|at|=)\s*-?\d/i],
  ["audition outcome", /\b(audition\w*|listening|listeners?|sessions?)\b[^|]*\b(passed|failed|confirmed|showed|found|judged|scored|rated)\b/i],
];

function args(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1)
    if (argv[i].startsWith("--")) out[argv[i].slice(2)] = argv[i + 1];
  return out;
}

function cells(line) {
  const trimmed = line.trim();
  if (!trimmed.startsWith("|") || !trimmed.endsWith("|")) return null;
  return trimmed.slice(1, -1).split("|").map((cell) => cell.trim());
}

function parse(text) {
  const lines = text.split("\n");
  const headings = [];
  const tables = [];
  let h2 = null;
  let h3 = null;
  for (let i = 0; i < lines.length; i += 1) {
    const two = /^##\s+(.*)$/.exec(lines[i]);
    const three = /^###\s+(.*)$/.exec(lines[i]);
    if (two && !three) {
      h2 = two[1].trim();
      h3 = null;
      headings.push(h2);
      continue;
    }
    if (three) {
      h3 = three[1].trim();
      continue;
    }
    const header = cells(lines[i]);
    const separator = i + 1 < lines.length ? cells(lines[i + 1]) : null;
    if (header && separator && separator.every((c) => /^:?-+:?$/.test(c))) {
      const rows = [];
      let j = i + 2;
      for (; j < lines.length; j += 1) {
        const row = cells(lines[j]);
        if (!row) break;
        const record = { line: j + 1 };
        header.forEach((name, k) => (record[name] = row[k] ?? ""));
        record._cells = row;
        rows.push(record);
      }
      tables.push({ header, rows, h2, h3, line: i + 1 });
      i = j - 1;
    }
  }
  return { lines, headings, tables };
}

function find(tables, predicate) {
  return tables.filter((t) => predicate(t.header, t));
}

function rowText(row) {
  return row._cells.join(" | ");
}

function expandIds(text) {
  const ids = new Set();
  for (const m of text.matchAll(/\b([A-Z]{2})-(\d{2})\s+to\s+\1-(\d{2})\b/g)) {
    for (let n = Number(m[2]); n <= Number(m[3]); n += 1)
      ids.add(`${m[1]}-${String(n).padStart(2, "0")}`);
  }
  for (const m of text.matchAll(/\b([A-Z]{2}-\d{2})\b/g)) ids.add(m[1]);
  return ids;
}

function words(text) {
  return new Set(text.toLowerCase().match(/[a-z]+/g) ?? []);
}

function jaccard(a, b) {
  const x = words(a);
  const y = words(b);
  const inter = [...x].filter((w) => y.has(w)).length;
  return inter / (x.size + y.size - inter || 1);
}

function bibleLines(text) {
  const found = [];
  for (const m of text.matchAll(/\bBIBLE lines? (\d+(?:(?:, | to )\d+)*)/g)) {
    const parts = m[1].split(", ");
    for (const part of parts) {
      const range = /^(\d+) to (\d+)$/.exec(part);
      if (range) found.push(Number(range[1]), Number(range[2]));
      else found.push(Number(part));
    }
  }
  return found;
}

async function sha(file) {
  try {
    return createHash("sha256").update(await readFile(file)).digest("hex");
  } catch {
    return null;
  }
}

async function sectionFiles(root) {
  const map = new Map();
  for (const dir of ["docs/tech/sections", "docs/product/sections"]) {
    for (const name of await readdir(path.join(root, dir))) {
      if (!name.endsWith(".md")) continue;
      const id = /^((?:TH|HF|PD)-\d{2}[ab]?)-/.exec(name);
      if (id) map.set(id[1], path.join(root, dir, name));
    }
  }
  return map;
}

async function check(text, root) {
  const failures = [];
  const fail = (tag, message) => failures.push({ tag, message });
  const counts = {};
  const { lines, headings, tables } = parse(text);
  const docDir = path.join(root, path.dirname(DOC));
  const bible = (await readFile(path.join(root, "BIBLE.md"), "utf8")).split("\n");
  const files = await sectionFiles(root);
  const fileLines = new Map();
  const linesOf = async (file) => {
    if (!fileLines.has(file)) fileLines.set(file, (await readFile(file, "utf8")).split("\n"));
    return fileLines.get(file);
  };

  if (JSON.stringify(headings) !== JSON.stringify(HEADINGS))
    fail("headings", `level-2 headings are ${JSON.stringify(headings)}`);
  counts.headings = headings.length;

  // Sources hashes bind to the nearest preceding repository link on the bullet.
  let hashes = 0;
  let inSources = false;
  let bullet = null;
  const bullets = [];
  for (const line of lines) {
    if (/^##\s/.test(line)) {
      inSources = /^##\s+Sources\s*$/.test(line);
      bullet = null;
      continue;
    }
    if (!inSources) continue;
    if (/^\s*-\s+/.test(line)) bullets.push((bullet = { text: line }));
    else if (bullet && line.trim()) bullet.text += " " + line.trim();
    else bullet = null;
  }
  for (const b of bullets) {
    let link = null;
    for (const token of b.text.matchAll(/SHA256\s+`([0-9a-f]{64})`|\[[^\]]*\]\(([^)]+)\)/g)) {
      if (token[2] !== undefined) {
        const target = token[2];
        const bare = target.split("#")[0];
        const register = target.includes("#") && ["BACKLOG.md", "TRACKING.md"].includes(path.basename(bare));
        if (bare && !register && !/^[a-z]+:/i.test(bare)) link = bare;
        continue;
      }
      hashes += 1;
      if (!link) {
        fail("hash", `stated ${token[1]} has no preceding link`);
        continue;
      }
      let actual = await sha(path.resolve(docDir, link));
      if (actual === null) actual = await sha(path.resolve(root, "docs/tech/sections", link));
      if (actual !== token[1]) fail("hash", `${link} stated ${token[1]} actual ${actual}`);
    }
    // "ID at line N" inside a bullet that links one section resolves against that section.
    const sectionLink = [...b.text.matchAll(/\]\(([^)#]+\.md)\)/g)]
      .map((m) => /((?:TH|HF|PD)-\d{2}[ab]?)-/.exec(path.basename(m[1])))
      .find(Boolean);
    if (sectionLink && files.has(sectionLink[1])) {
      const target = await linesOf(files.get(sectionLink[1]));
      for (const m of b.text.matchAll(/\b([A-Z][A-Z0-9]*(?:[-.][A-Z0-9]+)+) at line (\d+)/g)) {
        counts.sourceRuleCitations = (counts.sourceRuleCitations ?? 0) + 1;
        if (!(target[Number(m[2]) - 1] ?? "").includes(m[1]))
          fail("citation", `${sectionLink[1]} ${m[1]} not at line ${m[2]}`);
      }
    }
  }
  counts.statedHashes = hashes;

  // Tables by role.
  const eventTable = find(tables, (h) => h.includes("Family") && h.includes("Trigger meaning"))[0];
  const labelled = find(tables, (h) => h.includes("Label"));
  const bpTable = find(tables, (h) => h.includes("Entry") && h.includes("Label"))[0];
  const siTable = find(tables, (h) => h.includes("Invariant") && h.includes("Label"))[0];
  const udTable = find(tables, (h) => h.includes("Unselected detail"))[0];
  const spTable = find(tables, (h) => h.includes("Parameter") && h.includes("Value"))[0];
  const auTable = find(tables, (h) => h[0] === "Cell" && h.includes("Method"))[0];
  const ftTable = find(tables, (h) => h[0] === "ID" && h.includes("Method") && h.includes("Evidence needed"))[0];
  const qTable = find(tables, (h, t) => t.h2 === "Unresolved questions" && h[0] === "Question")[0];
  const walks = find(tables, (h, t) => t.h2 === "Scenarios" && /^WK-\d/.test(t.h3 ?? "") && h[0] === "Step");

  const sizes = {
    SE: eventTable?.rows.length ?? 0,
    BP: bpTable?.rows.length ?? 0,
    SI: siTable?.rows.length ?? 0,
    UD: udTable?.rows.length ?? 0,
    SP: spTable?.rows.length ?? 0,
    AU: auTable?.rows.length ?? 0,
    FT: ftTable?.rows.length ?? 0,
    WK: walks.length,
  };
  counts.rows = sizes;
  for (const [key, expected] of Object.entries(EXPECTED_COUNTS))
    if (sizes[key] !== expected) fail("counts", `${key} has ${sizes[key]} rows, prose states ${expected}`);

  const defined = new Set();
  for (const t of tables) for (const r of t.rows) if (/^[A-Z]{2}-\d{2}$/.test(r._cells[0])) defined.add(r._cells[0]);
  for (const w of walks) defined.add(w.h3.split(":")[0]);
  counts.definedRowIds = defined.size;

  // Families.
  const events = eventTable?.rows ?? [];
  for (const family of FAMILIES) {
    const rows = events.filter((r) => r.Family.toLowerCase() === family.toLowerCase());
    const good = rows.filter((r) => {
      const lines8 = bibleLines(r["Bible page"]).filter((n) => n >= SECTION_8[0] && n <= SECTION_8[1]);
      const lines6 = bibleLines(r["Bible page"]).filter((n) => n >= SECTION_6[0] && n <= SECTION_6[1]);
      const cited = bibleLines(r["Bible page"]).every((n) => (bible[n - 1] ?? "").trim().length > 0);
      return r["Proposed physical source"].length > 10 && r["Trigger meaning"].length > 10 && lines8.length && lines6.length && cited;
    });
    if (!good.length) fail("family", `no complete event row for family "${family}"`);
  }
  counts.familiesCovered = FAMILIES.length;

  // Labels.
  let labelledRows = 0;
  for (const t of labelled)
    for (const r of t.rows) {
      labelledRows += 1;
      if (!LABELS.includes(r.Label)) fail("label", `${r._cells[0]} label "${r.Label}"`);
    }
  for (const r of events) if (r.Label !== "proposal") fail("label", `${r.ID} event row not labelled proposal`);
  for (const r of bpTable?.rows ?? []) if (r.Label !== "browser proof") fail("label", `${r.ID} not labelled browser proof`);
  for (const r of siTable?.rows ?? []) if (r.Label !== "accepted invariant") fail("label", `${r.ID} not labelled accepted invariant`);
  counts.labelledRows = labelledRows;

  // Distinct meanings.
  const pair = (a, b, tag) => {
    const x = events.find((r) => r.Family === a);
    const y = events.find((r) => r.Family === b);
    if (!x || !y) return fail(tag, `missing ${a} or ${b} row`);
    if (x["Trigger meaning"] === y["Trigger meaning"] || jaccard(x["Trigger meaning"], y["Trigger meaning"]) >= 0.6)
      fail(tag, `${x.ID} and ${y.ID} meanings are not distinct`);
    if (x["Proposed physical source"] === y["Proposed physical source"])
      fail(tag, `${x.ID} and ${y.ID} sources are identical`);
    if (x["Committed moment"] === y["Committed moment"])
      fail(tag, `${x.ID} and ${y.ID} name the same moment`);
  };
  pair("collection", "fabrication", "distinct");
  pair("revival", "companion rescue", "distinct");

  // Danger rows never depend on music timing.
  let dangerRows = 0;
  const dangerCandidates = [
    ...events.filter((r) => r.Family === "enemy warning"),
    ...labelled.flatMap((t) => t.rows).filter((r) => DANGER.test(rowText(r))),
  ];
  for (const r of new Set(dangerCandidates)) {
    dangerRows += 1;
    const residue = rowText(r).replace(NEGATED_MUSIC, "");
    if (MUSIC.test(residue)) fail("music", `${r._cells[0]} depends on music timing: "${MUSIC.exec(residue)[0]}"`);
  }
  for (const r of events.filter((r) => r.Family === "enemy warning"))
    if (!/C-TICK/.test(r["Committed moment"]) || !/F-PROCESS/.test(r["Committed moment"]))
      fail("music", `${r.ID} does not sound from a published tick`);
  counts.dangerRowsChecked = dangerRows;

  // Audition matrix and fatigue.
  for (const s of SCENARIOS)
    for (const p of PLAYBACK) {
      const cell = (auTable?.rows ?? []).find((r) => r.Scenario === s && r.Playback === p);
      if (!cell) fail("matrix", `no cell for ${s} at ${p}`);
      else if (cell.Method.length < 30 || cell["Evidence needed"].length < 30)
        fail("matrix", `${cell.Cell} lacks a method or evidence`);
    }
  if (!(ftTable?.rows ?? []).some((r) => r.Method.length > 30 && r["Evidence needed"].length > 30))
    fail("matrix", "no fatigue method with evidence");
  for (const r of auTable?.rows ?? [])
    for (const id of expandIds(r["Rows exercised"])) if (!defined.has(id)) fail("matrix", `${r.Cell} exercises undefined ${id}`);
  counts.auditionCells = auTable?.rows.length ?? 0;

  // Questions.
  const gated = new Map();
  for (const q of QUESTIONS) {
    const row = (qTable?.rows ?? []).find((r) => r.Question.includes(`[${q}]`));
    if (!row) {
      fail("question", `${q} missing from Unresolved questions`);
      continue;
    }
    const ids = expandIds(row["Rows it gates"]);
    if (!ids.size) fail("question", `${q} gates no rows`);
    for (const id of ids) if (!defined.has(id)) fail("question", `${q} gates undefined ${id}`);
    if (row["Value stated here"] !== "none") fail("question", `${q} states a value`);
    gated.set(q, ids);
  }
  for (const t of [eventTable, udTable, spTable].filter(Boolean))
    for (const r of t.rows) {
      const id = r._cells[0];
      for (const q of QUESTIONS) {
        const inGate = new RegExp(`\\b${q}\\b`).test(r.Gate ?? "");
        const listed = gated.get(q)?.has(id) ?? false;
        if (inGate !== listed) fail("question", `${id} gate and ${q}'s gated rows disagree`);
      }
      if (!/Q-[PE]\d{2}|line \d+/.test(r.Gate ?? "")) fail("question", `${id} has no question or source line`);
    }
  for (const r of spTable?.rows ?? []) if (r.Value !== "unset") fail("forbidden", `${r.ID} states a value`);
  counts.questionsListed = gated.size;

  // Forbidden statements in any table row.
  let scanned = 0;
  for (const t of tables.filter((t) => t.h2 !== "Sources"))
    for (const r of t.rows) {
      scanned += 1;
      for (const [tag, pattern] of FORBIDDEN)
        if (pattern.test(rowText(r))) fail("forbidden", `${r._cells[0]} states a ${tag}: "${pattern.exec(rowText(r))[0]}"`);
    }
  counts.rowsScannedForForbidden = scanned;

  // Section citations by row ID and line.
  let citations = 0;
  for (const m of text.matchAll(/\b((?:TH|HF|PD)-\d{2}[ab]?)\s+(?:([A-Z][A-Z0-9]*(?:[-.][A-Z0-9]+)*)\s+)?lines?\s+(\d+)(?:\s+to\s+(\d+))?/g)) {
    const [, section, id, first, last] = m;
    const file = files.get(section);
    citations += 1;
    if (!file) {
      fail("citation", `${section} has no section file`);
      continue;
    }
    const target = await linesOf(file);
    for (const n of [first, last].filter(Boolean).map(Number))
      if (n < 1 || n > target.length || !target[n - 1].trim()) fail("citation", `${section} line ${n} is out of range or blank`);
    if (id && !(target[Number(first) - 1] ?? "").includes(id)) fail("citation", `${section} ${id} not at line ${first}`);
  }
  for (const n of bibleLines(text)) {
    citations += 1;
    if (!(bible[n - 1] ?? "").trim()) fail("citation", `BIBLE line ${n} is out of range or blank`);
  }
  counts.lineCitations = citations;

  // Durable field paths exist in the HF-07a CSV.
  const csv = (await readFile(path.join(root, "docs/tech/sections/HF-07a-save-envelope.csv"), "utf8"))
    .split("\n")
    .slice(1)
    .map((l) => l.split(",")[0])
    .filter(Boolean);
  let fields = 0;
  for (const m of text.matchAll(/`((?:run|profile|preferences)\.[\w.[\]]+)`/g)) {
    fields += 1;
    if (!csv.includes(m[1])) fail("field", `${m[1]} is not an HF-07a CSV field`);
  }
  counts.fieldPaths = fields;

  // Walk step order against each walk's gate.
  const walk = (id) => walks.find((w) => w.h3.startsWith(id))?.rows ?? [];
  const at = (rows, column, pattern) => rows.findIndex((r) => pattern.test(r[column] ?? ""));
  const order = (id, indices, message) => {
    if (indices.some((i) => i < 0) || indices.some((v, k) => k && v <= indices[k - 1])) fail("walk", `${id}: ${message}`);
  };
  for (const w of walks)
    for (const [k, r] of w.rows.entries())
      if (/\bSE-\d{2}\b/.test(r["Cue or event"]) && !/sound disabled/i.test(r["Cue or event"])) {
        if (!/F-PROCESS/.test(r.Moment)) fail("walk", `${w.h3.split(":")[0]} step ${r.Step} cue outside F-PROCESS`);
        if (!w.rows.slice(0, k).some((p) => /P6|acknowledge|O4|install_effective_build/.test(p.Moment)))
          fail("walk", `${w.h3.split(":")[0]} step ${r.Step} cue before any published or acknowledged fact`);
      }
  {
    const rows = walk("WK-1");
    const warn = at(rows, "Cue or event", /\bSE-11\b/);
    order("WK-1", [warn, at(rows, "Moment", /phrase boundary/i)], "the warning must precede the phrase boundary");
    if (warn < 1 || !/P6/.test(rows[warn - 1].Moment)) fail("walk", "WK-1: SE-11 must follow the P6 publish directly");
    const exec = at(rows, "Cue or event", /\bSE-12\b/);
    if (exec < 1 || !/P6/.test(rows[exec - 1].Moment)) fail("walk", "WK-1: SE-12 must follow the P6 publish directly");
    if (rows.some((r) => /\bSE-1[123]\b/.test(r["Cue or event"]) && /phrase|beat|bar/i.test(r.Moment)))
      fail("walk", "WK-1: a warning cue sits on a music boundary");
  }
  {
    const rows = walk("WK-2");
    order(
      "WK-2",
      [
        at(rows, "Cue or event", /\bSE-02\b/),
        at(rows, "Moment", /acknowledge/),
        at(rows, "Moment", /install_effective_build/),
        at(rows, "Cue or event", /\bSE-03\b/),
      ],
      "collection, acknowledge, install, fabrication must be in that order",
    );
  }
  {
    const rows = walk("WK-3");
    const a = rows.filter((r) => r.Branch === "A");
    const b = rows.filter((r) => r.Branch === "B");
    if (a.some((r) => /Transition [CD]/.test(r.Moment))) fail("walk", "WK-3: the rescue branch runs a lifecycle transition");
    if (at(a, "Cue or event", /\bSE-20\b/) < 0 || at(a, "Cue or event", /\bSE-18\b/) >= 0) fail("walk", "WK-3: branch A must carry SE-20 and not SE-18");
    if (at(b, "Cue or event", /\bSE-20\b/) >= 0) fail("walk", "WK-3: branch B carries the rescue cue");
    order(
      "WK-3",
      [at(b, "Cue or event", /\bSE-17\b/), at(b, "Moment", /Transition C acknowledge/), at(b, "Moment", /\bO4\b/), at(b, "Cue or event", /\bSE-18\b/)],
      "onset, Transition C acknowledge, O4, revival cue must be in that order",
    );
  }
  {
    const rows = walk("WK-4");
    order(
      "WK-4",
      [at(rows, "Cue or event", /\bSE-17\b/), at(rows, "Moment", /Transition D acknowledge/), at(rows, "Cue or event", /\bSE-19\b/)],
      "onset, Transition D acknowledge, terminal cue must be in that order",
    );
  }
  {
    const rows = walk("WK-5");
    const visible = rows.findIndex((r) => /telegraph/i.test(r["Cue or event"]) && /F-PROCESS/.test(r.Moment));
    order("WK-5", [visible, at(rows, "Cue or event", /\bEN-3\b/)], "the visible telegraph must precede the execution");
  }
  counts.walksChecked = walks.length;

  // Closure repair A2: integrated read R1 findings B3, A4, A5 and A20.
  {
    let closure = 0;
    const need = (tag, ok, message) => {
      closure += 1;
      if (!ok) fail(tag, message);
    };
    const byId = (id) => events.find((r) => r.ID === id);
    const rule = "A cue sounds from that published value and never earlier.";
    const ruleAt = lines.findIndex((l) => l.includes(rule));
    const after = ruleAt < 0 ? "" : lines.slice(ruleAt + 1, lines.findIndex((l, k) => k > ruleAt && l.startsWith("| ID |"))).join(" ");
    need("closure-B3", ruleAt >= 0, "the published-value rule is missing");
    for (const phrase of ["**UI-only input exception.**", "TRACKING EV-0453", "limited to UI feedback", "only departure", "covers SE-14 and no other row", "attacks, damage, pickups, danger, revival and defeat, still waits for its published value", "TH-17"])
      need("closure-B3", after.includes(phrase), `the exception beside the published-value rule lacks "${phrase}"`);
    const se14 = byId("SE-14");
    need("closure-B3", !!se14 && /UI-only input exception/.test(se14["Committed moment"]) && /EV-0453/.test(se14["Committed moment"]) && /TH-17/.test(se14["Committed moment"]), "SE-14 does not cite the UI-only input exception and TH-17");
    for (const r of events.filter((r) => r.ID !== "SE-14")) {
      const moment = r["Committed moment"];
      need("closure-B3", !/UI-only input exception|input moment|^F-INPUT/.test(rowText(r)), `${r.ID} claims the UI-only input exception`);
      need("closure-B3", /C-TICK|F-PROCESS|acknowledged|Transition [A-DS]|^As SE-\d{2}\b/.test(moment), `${r.ID} names no published or acknowledged moment`);
    }
    const si04 = (siTable?.rows ?? []).find((r) => r.ID === "SI-04");
    need("closure-B3", !!si04 && si04.Invariant.includes("Every gameplay cue consumes a published value") && si04.Invariant.includes("UI-only input exception") && !/^A cue consumes a published value/.test(si04.Invariant), "SI-04 does not separate gameplay cues from the UI-only input exception");

    const se11 = byId("SE-11");
    const se12 = byId("SE-12");
    need("closure-A4", !!se11 && se11["Trigger meaning"].startsWith("Windup commitment: the machine has declared a threat.") && se11["Committed moment"].includes("C-TICK P2 commits the windup under EN-2; P6 publishes it; F-PROCESS presents it") && se11["Trigger meaning"].includes("abandonable-preparation cue remains unselected"), "SE-11 is not the EN-2 windup commitment");
    need("closure-A4", !!se12 && se12["Trigger meaning"].startsWith("Execution: the declared attack resolves inside its committed geometry."), "SE-12 is not the EN-3 execution");
    need("closure-A4", !events.some((r) => /^(Preparation:|Commitment and release)/.test(r["Trigger meaning"])), "an enemy row still merges preparation, commitment or execution");

    const se22 = byId("SE-22");
    need("closure-A5", !!se22 && se22["Committed moment"].includes("Non-settlement knowledge commits at the next eligible Transition A, C, D or S; knowledge produced by settlement commits in that settlement's own transaction,") && se22["Committed moment"].includes("Cue playback acknowledges neither"), "SE-22 does not separate settlement knowledge");

    const bp04 = (bpTable?.rows ?? []).find((r) => r.ID === "BP-04");
    need("closure-A20", !!bp04 && bp04["What it plays"].includes("The baseline also plays a synthesized class-selection note at `src/main.js:116`; this is browser-proof evidence, not a selected production cue."), "BP-04 omits the class-selection note");
    const seamStart = lines.findIndex((l) => l.startsWith("### Seams stated and not decided"));
    const seams = seamStart < 0 ? "" : lines.slice(seamStart, lines.findIndex((l, k) => k > seamStart && /^##/.test(l))).join(" ");
    need("closure-A20", seams.includes("SC-01 supplies kit identity for SE-08; SC-04 supplies enemy/attack references for SE-11–SE-13; SC-08 supplies narrative/discovery references for SE-21, SE-22 and UD-07."), "the seams omit SC-01, SC-04 or SC-08");
    need("closure-stale", seams.includes("admitted at the Handoff-8 closure target; this section's original attempt did not necessarily inspect those admitted bytes"), "the seams lack the admission wording");
    need("closure-stale", !/written concurrently|are not admitted/.test(seams), "the seams still call Handoff-8 siblings unadmitted");
    counts.closureAssertions = closure;
  }

  // Closure repair A3: review R2 BF-1, N1, N2 and N4.
  {
    let closure = 0;
    const need = (tag, ok, message) => {
      closure += 1;
      if (!ok) fail(tag, message);
    };
    const exceptionLine = lines.find((l) => l.startsWith("**UI-only input exception.**")) ?? "";
    const se14 = events.find((r) => r.ID === "SE-14");
    const si04 = (siTable?.rows ?? []).find((r) => r.ID === "SI-04");
    const places = [
      ["the exception paragraph", exceptionLine],
      ["SE-14's committed moment", se14?.["Committed moment"] ?? ""],
      ["SI-04's invariant", si04?.Invariant ?? ""],
    ];
    const RULES = [
      ["RI-14", /TH-16 RI-14 line 181\b/],
      ["RV-5", /TH-16 RV-5 line 55\b/],
      ["Seam 4", /TH-16 line 304\b[^.;]{0,12}Seam 4|Seam 4[^.;]{0,12}TH-16 line 304\b/],
      ["AM-H8-006", /\bAM-H8-006\b/],
    ];
    const GATE = /until AM-H8-006 is admitted by a TH-16 revision, SE-14 sounds from its published value\b[^.]*like every other cue, and TH-17 may not realize input-moment playback\./;
    for (const [where, body] of places) {
      need("closure-BF1-rules", body.length > 0, `${where} is missing`);
      for (const [name, pattern] of RULES)
        need("closure-BF1-rules", pattern.test(body), `${where} does not name ${name}`);
      need("closure-BF1-gate", GATE.test(body), `${where} does not state the AM-H8-006 gate`);
    }
    need("closure-BF1-gate", /departs from/.test(exceptionLine) && /departs from/.test(se14?.["Committed moment"] ?? "") && /departs from/.test(si04?.Invariant ?? ""), "a place names the TH-16 rules without calling them a departure");

    const clauses = (si04?.["Carried by"] ?? "").split(/;\s*/).filter(Boolean);
    const seam = clauses.filter((c) => /TH-16 line 304\b/.test(c));
    const exception = clauses.filter((c) => /EV-0453/.test(c));
    need("closure-BF1-carrier", seam.length === 1 && /for gameplay cues$/.test(seam[0]) && !/exception|EV-0453|AM-H8-006/.test(seam[0]), "SI-04 does not keep TH-16 line 304 for gameplay cues only");
    need("closure-BF1-carrier", exception.length === 1 && /\bAM-H8-006\b/.test(exception[0]) && /UI-only input exception$/.test(exception[0]), "SI-04 does not carry the exception by EV-0453 and AM-H8-006");
    need("closure-BF1-carrier", !clauses.some((c) => /exception|EV-0453|AM-H8-006/.test(c) && /\b304\b/.test(c)), "SI-04 carries the exception by TH-16 line 304");

    for (const old of ["each enemy's preparation, commitment and recovery", "whose preparations SE-11 to SE-13 voice"])
      need("closure-N1", !text.includes(old), `old A4 wording survives: "${old}"`);
    const au01 = (auTable?.rows ?? []).find((r) => r.Cell === "AU-01");
    need("closure-N1", !!au01 && au01.Method.includes("each enemy's windup commitment, execution and recovery"), "AU-01 does not use SE-11 to SE-13's wording");
    need("closure-N1", text.includes("whose windup commitments, executions and recoveries SE-11 to SE-13 voice"), "the Q-P25 entry does not use SE-11 to SE-13's wording");

    const se22 = events.find((r) => r.ID === "SE-22");
    need("closure-N2", !!se22 && se22["Committed moment"].includes("knowledge produced by settlement commits in that settlement's own transaction, Transition B or the Transition A it rides (TH-09 LU-01 line 176)"), "SE-22 omits the Transition A a settlement rides");

    const th17 = lines.find((l) => l.startsWith("- **TH-17**")) ?? "";
    need("closure-N4", /Once AM-H8-006 is admitted by a TH-16 revision, TH-17 also owns the UI click plumbing/.test(th17) && th17.includes("TH-17 may not realize input-moment playback"), "the TH-17 seam omits the gated UI click plumbing");

    const trigStart = lines.findIndex((l) => /^##\s+Re-verification triggers/.test(l));
    const triggers = trigStart < 0 ? [] : lines.slice(trigStart + 1, lines.findIndex((l, k) => k > trigStart && /^##\s/.test(l)));
    need("closure-trigger", triggers.some((l) => l.startsWith("- AM-H8-006 is admitted, or any TH-16 revision changes") && /TH-16 RI-14 line 181/.test(l) && /TH-16 RV-5 line 55/.test(l) && /TH-16 line 304 \(Seam 4\)/.test(l) && /stays gated/.test(l)), "no re-verification trigger for the AM-H8-006 gate");
    counts.closureAssertionsA3 = closure;
  }

  return { failures, counts };
}

const MUTATIONS = [
  ["NC-01 drop the discovery family", "family", (t) => t.replaceAll("| discovery |", "| discovery-ish |")],
  ["NC-02 double label on a cue row", "label", (t) => t.replace("| proposal |", "| proposal; browser proof |")],
  [
    "NC-03 fabrication meaning copies collection",
    "distinct",
    (t) => {
      const lines = t.split("\n");
      const se02 = lines.findIndex((l) => l.startsWith("| SE-02 |"));
      const se03 = lines.findIndex((l) => l.startsWith("| SE-03 |"));
      const a = lines[se02].split("|");
      const b = lines[se03].split("|");
      b[3] = a[3];
      lines[se03] = b.join("|");
      return lines.join("\n");
    },
  ],
  [
    "NC-04 an enemy warning waits for the next bar",
    "music",
    (t) => t.replace("the declared attack resolves inside its committed geometry.", "the declared attack resolves, and the cue sounds on the next bar line of the combat arrangement."),
  ],
  ["NC-05 remove the exceptional build sound-disabled cell", "matrix", (t) => t.split("\n").filter((l) => !l.startsWith("| AU-06 |")).join("\n")],
  ["NC-06 state an asset count", "forbidden", (t) => t.replace("| UD-06 | Source method |", "| UD-06 | Source method, with 12 recordings per region |")],
  ["NC-07 remove Q-P28 from Unresolved questions", "question", (t) => t.split("\n").filter((l) => !l.startsWith("| [Q-P28]")).join("\n")],
  ["NC-08 corrupt a stated hash", "hash", (t) => t.replace("98e19c20d6b0247af5b8b573bf6b5e3c1bdcfb2958dba11def8f834f8d9d01e3", "0".repeat(64))],
  [
    "NC-09 revival cue before Transition C acknowledge",
    "walk",
    (t) => t.replace("| 6 | B | HF-07b Transition C acknowledge |", "| 6 | B | F-PROCESS after HF-04a O4 | SE-18 sounds early. | SI-07 |\n| 6b | B | HF-07b Transition C acknowledge |"),
  ],
  ["NC-10 state a loudness value", "forbidden", (t) => t.replace("| SP-09 | Quiet playback level,", "| SP-09 | Quiet playback level at -18 LUFS,")],
  ["NC-11 cite a rule ID at the wrong line", "citation", (t) => t.replace("TH-03 EN-2 line 40", "TH-03 EN-2 line 41")],
  [
    "NC-12 rescue meaning copies revival",
    "distinct",
    (t) => {
      const lines = t.split("\n");
      const se18 = lines.findIndex((l) => l.startsWith("| SE-18 |"));
      const se20 = lines.findIndex((l) => l.startsWith("| SE-20 |"));
      const a = lines[se18].split("|");
      const b = lines[se20].split("|");
      b[3] = a[3];
      lines[se20] = b.join("|");
      return lines.join("\n");
    },
  ],
  ["NC-13 B3: remove the UI-only input exception", "closure-B3", (t) => t.replace(/\n\n\*\*UI-only input exception\.\*\*[^\n]*/, "")],
  ["NC-14 B3: SE-14 sounds at F-INPUT without the exception", "closure-B3", (t) => t.replace("at the input moment under the UI-only input exception (TRACKING EV-0453), which departs from TH-16 RI-14 line 181, TH-16 RV-5 line 55 and TH-16 line 304 (Seam 4); TH-17 owns the cue plumbing.", "F-INPUT.")],
  ["NC-15 B3: a gameplay cue claims the input exception", "closure-B3", (t) => t.replace("| C-TICK P4 commits, P5 applies and P6 publishes; F-PROCESS `present_committed_result` from the same descriptor", "| At the input moment, under the UI-only input exception; the attack cue plays before P6")],
  ["NC-16 B3: SI-04 restores the unqualified published-value claim", "closure-B3", (t) => t.replace("| SI-04 | A cue decides nothing:", "| SI-04 | A cue consumes a published value and decides nothing:").replace("Every gameplay cue consumes a published value. ", "")],
  ["NC-17 A4: SE-11 reverts to preparation", "closure-A4", (t) => t.replace("Windup commitment: the machine has declared a threat.", "Preparation: a machine is readying a threat.")],
  ["NC-18 A5: SE-22 drops settlement knowledge", "closure-A5", (t) => t.replace(" knowledge produced by settlement commits in that settlement's own transaction, Transition B or the Transition A it rides (TH-09 LU-01 line 176).", "")],
  ["NC-19 A20: BP-04 drops the class-selection note", "closure-A20", (t) => t.replace(" The baseline also plays a synthesized class-selection note at `src/main.js:116`; this is browser-proof evidence, not a selected production cue.", "")],
  ["NC-20 stale: seams call siblings unadmitted", "closure-stale", (t) => t.replace("were admitted at the Handoff-8 closure target; this section's original attempt did not necessarily inspect those admitted bytes, and no byte of any is cited here.", "are written concurrently in this sprint and are not admitted; no byte of any is cited.")],
  ["NC-21 BF-1: the exception paragraph drops RV-5", "closure-BF1-rules", (t) => onLine(t, "**UI-only input exception.**", (l) => l.replace("TH-16 RV-5 line 55 derives", "TH-16 derives"))],
  ["NC-22 BF-1: SE-14 drops AM-H8-006", "closure-BF1-rules", (t) => onLine(t, "| SE-14 |", (l) => l.replaceAll("AM-H8-006", "the amendment"))],
  ["NC-23 BF-1: SI-04 drops RI-14 and Seam 4", "closure-BF1-rules", (t) => onLine(t, "| SI-04 |", (l) => l.replace("TH-16 RI-14 line 181, TH-16 RV-5 line 55 and TH-16 line 304 (Seam 4)", "TH-16 RV-5 line 55"))],
  ["NC-24 gate: the exception paragraph drops the gate", "closure-BF1-gate", (t) => onLine(t, "**UI-only input exception.**", (l) => l.replace(/\*\*Gate:\*\* until [^.]*\. /, ""))],
  ["NC-25 gate: SE-14 lets TH-17 realize input-moment playback", "closure-BF1-gate", (t) => onLine(t, "| SE-14 |", (l) => l.replace("TH-17 may not realize input-moment playback", "TH-17 may realize input-moment playback"))],
  ["NC-26 gate: SI-04 opens the exception without admission", "closure-BF1-gate", (t) => onLine(t, "| SI-04 |", (l) => l.replace("until AM-H8-006 is admitted by a TH-16 revision, SE-14 sounds from its published value", "SE-14 sounds at the input moment"))],
  ["NC-27 carrier: SI-04 reverts to unscoped TH-16 line 304 without EV-0453", "closure-BF1-carrier", (t) => onLine(t, "| SI-04 |", (l) => l.replace("TH-16 line 304 (Seam 4) for gameplay cues; TRACKING EV-0453 and AM-H8-006 for the UI-only input exception;", "TH-16 line 304;"))],
  ["NC-28 carrier: SI-04 carries the exception by TH-16 line 304", "closure-BF1-carrier", (t) => onLine(t, "| SI-04 |", (l) => l.replace("TRACKING EV-0453 and AM-H8-006 for the UI-only input exception", "TH-16 line 304, TRACKING EV-0453 and AM-H8-006 for the UI-only input exception"))],
  ["NC-29 N1: AU-01 restores preparation, commitment and recovery", "closure-N1", (t) => t.replace("each enemy's windup commitment, execution and recovery", "each enemy's preparation, commitment and recovery")],
  ["NC-30 N1: the Q-P25 entry restores preparations", "closure-N1", (t) => t.replace("whose windup commitments, executions and recoveries SE-11 to SE-13 voice", "whose preparations SE-11 to SE-13 voice")],
  ["NC-31 N2: SE-22 narrows settlement knowledge to Transition B", "closure-N2", (t) => t.replace("in that settlement's own transaction, Transition B or the Transition A it rides (TH-09 LU-01 line 176)", "with Transition B")],
  ["NC-32 N4: the TH-17 seam drops the UI click plumbing", "closure-N4", (t) => onLine(t, "- **TH-17**", (l) => l.replace(/ Once AM-H8-006 is admitted[^\n]*$/, ""))],
  ["NC-33 trigger: the AM-H8-006 gate trigger is removed", "closure-trigger", (t) => t.split("\n").filter((l) => !l.startsWith("- AM-H8-006 is admitted")).join("\n")],
];

function onLine(text, prefix, change) {
  return text
    .split("\n")
    .map((l) => (l.startsWith(prefix) ? change(l) : l))
    .join("\n");
}

async function main() {
  const { root, out } = args(process.argv.slice(2));
  if (!root || !out) {
    console.error("Usage: node paper-check.mjs --root <repository-root> --out <directory>");
    process.exit(2);
  }
  const repo = path.resolve(root);
  const outDir = path.resolve(out);
  await mkdir(outDir, { recursive: true });
  const text = await readFile(path.join(repo, DOC), "utf8");
  const positive = await check(text, repo);
  const controls = [];
  for (const [name, tag, mutate] of MUTATIONS) {
    const mutated = mutate(text);
    const result = await check(mutated, repo);
    const baseline = new Set(positive.failures.map((f) => f.message));
    const tagged = result.failures.filter((f) => f.tag === tag && !baseline.has(f.message));
    controls.push({ name, expectedTag: tag, changed: mutated !== text, failed: tagged.length > 0, failures: tagged.map((f) => f.message) });
  }
  const controlsOk = controls.every((c) => c.changed && c.failed);
  const result = {
    document: DOC,
    documentSha256: createHash("sha256").update(text).digest("hex"),
    positive: { pass: positive.failures.length === 0, failures: positive.failures, counts: positive.counts },
    negativeControls: controls,
    negativeControlsFailedAsRequired: controls.filter((c) => c.changed && c.failed).length,
    negativeControlsTotal: controls.length,
    pass: positive.failures.length === 0 && controlsOk,
    limits: "Paper check of document structure, citations, labels and walk order at one base. It establishes nothing about sound, mix, timing or feel.",
  };
  await writeFile(path.join(outDir, "paper-check.json"), JSON.stringify(result, null, 2) + "\n");
  console.log(`PD-03 paper check positive: ${positive.failures.length === 0 ? "pass" : "FAIL"} (${positive.failures.length} failures)`);
  for (const f of positive.failures) console.log(`  FAIL [${f.tag}] ${f.message}`);
  console.log(`counts: ${JSON.stringify(positive.counts)}`);
  for (const c of controls) console.log(`${c.name}: ${c.changed && c.failed ? "failed as required" : "DID NOT FAIL"} [${c.expectedTag}] ${c.failures[0] ?? ""}`);
  console.log(`negative controls failing as required: ${result.negativeControlsFailedAsRequired}/${result.negativeControlsTotal}`);
  console.log(`result: ${result.pass ? "pass" : "FAIL"}`);
  process.exit(result.pass ? 0 : 1);
}

main().catch((error) => {
  console.error(error);
  process.exit(2);
});
