#!/usr/bin/env node
// PD-02 paper check. Asserts the interface-states section against its card,
// its citations and its own accidental-cast rule. Documentation-only: it runs
// no build, browser or engine and establishes no interface behaviour.
//
// Usage: node paper-check.mjs --root <repository-root> --out <directory>

import { createHash } from "node:crypto";
import { readFile, readdir, mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

const DOC = "docs/product/sections/PD-02-interface-states.md";
const VIEWS = ["VW-1", "VW-2", "VW-3", "VW-4", "VW-5", "VW-6"];
const STATES = [
  ["IS-01", "locked slot"],
  ["IS-02", "unavailable upgrade"],
  ["IS-03", "acquired item"],
  ["IS-04", "equipped item"],
  ["IS-05", "eligible swap"],
  ["IS-06", "special respec"],
  ["IS-07", "two-world offer"],
  ["IS-08", "available revival"],
  ["IS-09", "spent revival"],
  ["IS-10", "terminal"],
];
const CARD_QUESTIONS = [
  "Q-P11", "Q-P12", "Q-P14", "Q-P15", "Q-P16",
  "Q-P18", "Q-P19", "Q-P30", "Q-P32",
];
const INPUT_CLASSES = ["navigation", "ui-request", "control", "gameplay", "display"];
const HISTORICAL_MARKERS = ["LIGHTNING-VERIFICATION", "lightning-playtest", "lightning prototype"];

function args(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1)
    if (argv[i].startsWith("--")) out[argv[i].slice(2)] = argv[i + 1];
  return out;
}

function cells(line) {
  const trimmed = line.trim();
  if (!trimmed.startsWith("|")) return null;
  return trimmed.slice(1, -1).split("|").map((cell) => cell.trim());
}

function tableAfter(lines, headerPredicate) {
  const start = lines.findIndex((line) => {
    const row = cells(line);
    return row && headerPredicate(row);
  });
  if (start === -1) return null;
  const rows = [];
  for (let i = start + 2; i < lines.length; i += 1) {
    const row = cells(lines[i]);
    if (!row) break;
    rows.push(row);
  }
  return { header: cells(lines[start]), rows };
}

function slug(text) {
  return text
    .toLowerCase()
    .replace(/`/g, "")
    .replace(/[^\w\- ]+/g, "")
    .trim()
    .replace(/\s+/g, "-");
}

async function anchorsOf(file) {
  const text = await readFile(file, "utf8");
  const found = new Set();
  for (const line of text.split("\n")) {
    const heading = /^#{1,6}\s+(.*?)\s*#*\s*$/.exec(line);
    if (heading) found.add(slug(heading[1]));
    for (const tag of line.matchAll(/<a\s+id="([^"]+)"><\/a>/g)) found.add(tag[1]);
  }
  return found;
}

async function sectionFiles(root) {
  const dir = path.join(root, "docs/tech/sections");
  const map = new Map();
  for (const name of await readdir(dir)) {
    const id = /^((?:HF|TH)-\d{2}[ab]?)-/.exec(name);
    if (id && name.endsWith(".md")) map.set(id[1], path.join(dir, name));
  }
  return map;
}

async function runChecks(root, text, label) {
  const failures = [];
  const counts = {};
  const lines = text.split("\n");
  const fail = (message) => failures.push(label + ": " + message);

  // 1. Views: entry, exit, focus and pause for every view the card names.
  const views = tableAfter(lines, (row) => row[0] === "ID" && row[1] === "View");
  if (!views) fail("no views table");
  else {
    const byId = new Map(views.rows.map((row) => [row[0], row]));
    const wanted = ["Entry", "Exit", "Focus requirement", "Pause requirement"];
    for (const column of wanted)
      if (!views.header.includes(column)) fail("views table has no " + column + " column");
    for (const id of VIEWS) {
      const row = byId.get(id);
      if (!row) { fail("view " + id + " has no row"); continue; }
      for (const column of wanted) {
        const cell = row[views.header.indexOf(column)] ?? "";
        if (cell.length < 20) fail("view " + id + " has an empty or trivial " + column);
      }
    }
    counts.views = VIEWS.filter((id) => byId.has(id)).length;
  }

  // 2. States: a specification row for every state the card names.
  const states = tableAfter(lines, (row) => row[0] === "ID" && row[1] === "State");
  if (!states) fail("no interface states table");
  else {
    const byId = new Map(states.rows.map((row) => [row[0], row]));
    for (const [id, phrase] of STATES) {
      const row = byId.get(id);
      if (!row) { fail("state " + id + " has no specification row"); continue; }
      if (!row[1].toLowerCase().includes(phrase))
        fail("state " + id + " does not name the card's state: " + phrase);
      for (const index of [2, 3, 4, 5, 6])
        if ((row[index] ?? "").length < 20)
          fail("state " + id + " has an empty cell in column " + (index + 1));
    }
    counts.states = STATES.filter(([id]) => byId.has(id)).length;
  }

  // 3. Scenarios: one per view and per state, each naming feedback and refusals.
  const scenarios = [];
  for (let i = 0; i < lines.length; i += 1) {
    const heading = /^####\s+(RS-[A-Z0-9]+):\s+(.*?)\s+\((VW-\d|IS-\d{2})\)\s*$/.exec(lines[i]);
    if (!heading) continue;
    let end = lines.length;
    for (let j = i + 1; j < lines.length; j += 1)
      if (/^#{1,4}\s/.test(lines[j])) { end = j; break; }
    scenarios.push({ id: heading[1], subject: heading[3], body: lines.slice(i, end) });
  }
  counts.scenarios = scenarios.length;
  const subjects = new Set(scenarios.map((s) => s.subject));
  for (const id of [...VIEWS, ...STATES.map(([s]) => s)])
    if (!subjects.has(id)) fail("no review scenario for " + id);

  let steps = 0;
  let navigationSteps = 0;
  let gameplaySteps = 0;
  for (const scenario of scenarios) {
    const joined = scenario.body.join("\n");
    for (const field of ["Visible feedback", "Unavailable actions", "Questions exposed"]) {
      const match = new RegExp("\\*\\*" + field + ":\\*\\*\\s*(.+)").exec(joined);
      if (!match || match[1].trim().length < 15)
        fail("scenario " + scenario.id + " does not name its " + field.toLowerCase());
    }
    let rows = 0;
    for (const line of scenario.body) {
      const row = cells(line);
      if (!row || !/^\d+$/.test(row[0])) continue;
      rows += 1;
      steps += 1;
      const inputClass = (row[1] ?? "").replace(/`/g, "").trim();
      if (!INPUT_CLASSES.includes(inputClass))
        fail("scenario " + scenario.id + " step " + row[0] + " has unknown input class: " + inputClass);
      if (inputClass === "navigation") navigationSteps += 1;
      if (inputClass === "gameplay") gameplaySteps += 1;
      const routed = (row[2] ?? "") + " " + (row[3] ?? "");
      if (inputClass !== "gameplay" && routed.includes("submit_action"))
        fail("scenario " + scenario.id + " step " + row[0] + " reaches submit_action from a " + inputClass + " step");
    }
    if (rows < 3) fail("scenario " + scenario.id + " has fewer than three steps");
  }
  counts.steps = steps;
  counts.navigationSteps = navigationSteps;
  counts.gameplaySteps = gameplaySteps;
  if (navigationSteps === 0) fail("no navigation step exists, so the cast rule is untested");
  if (gameplaySteps === 0) fail("no gameplay step exists, so submit_action is never exercised");

  // 4. Citations: every rule ID must exist at the cited line of the named section.
  const files = await sectionFiles(root);
  const cache = new Map();
  const loadSection = async (id) => {
    if (!cache.has(id)) {
      const file = files.get(id);
      if (!file) return null;
      cache.set(id, (await readFile(file, "utf8")).split("\n"));
    }
    return cache.get(id);
  };
  let citations = 0;
  const idCite = /\b((?:HF|TH)-\d{2}[ab]?)\s+([A-Z][A-Za-z0-9]*(?:-[A-Za-z0-9]+)*)\s+line\s+(\d+)\b/g;
  for (const match of text.matchAll(idCite)) {
    citations += 1;
    const body = await loadSection(match[1]);
    if (!body) { fail("citation names an unknown section: " + match[0]); continue; }
    const line = body[Number(match[3]) - 1];
    if (line === undefined) { fail("citation past end of file: " + match[0]); continue; }
    if (!line.includes(match[2])) fail("citation does not resolve: " + match[0]);
  }
  const bareCite = /\b((?:HF|TH)-\d{2}[ab]?)\s+line\s+(\d+)\b/g;
  for (const match of text.matchAll(bareCite)) {
    citations += 1;
    const body = await loadSection(match[1]);
    if (!body) { fail("citation names an unknown section: " + match[0]); continue; }
    if (body[Number(match[2]) - 1] === undefined) fail("citation past end of file: " + match[0]);
  }
  counts.citations = citations;

  // 5. Questions: exposed at the states that need them, never answered.
  for (const question of CARD_QUESTIONS) {
    const exposed = scenarios.some((s) =>
      new RegExp("\\*\\*Questions exposed:\\*\\*[^\\n]*" + question + "\\b").test(s.body.join("\n")),
    );
    if (!exposed) fail(question + " is exposed by no review scenario");
    if (!text.includes("[" + question + "](")) fail(question + " is never linked to the register");
  }
  counts.questions = CARD_QUESTIONS.length;

  const params = tableAfter(lines, (row) => row[0] === "ID" && row[1] === "Parameter");
  if (!params) fail("no unresolved parameters table");
  else {
    for (const row of params.rows) {
      if (row[2] !== "unset") fail("parameter " + row[0] + " states a value: " + row[2]);
      if (!/Q-P\d+|line \d+|FP-\d+/.test(row[3] ?? ""))
        fail("parameter " + row[0] + " has no question ID and no source line");
    }
    counts.parameters = params.rows.length;
  }

  // 6. Historical labelling of prototype evidence.
  let historical = 0;
  for (const [index, line] of lines.entries())
    if (HISTORICAL_MARKERS.some((marker) => line.includes(marker))) {
      historical += 1;
      if (!/historical/i.test(line))
        fail("prototype evidence at line " + (index + 1) + " is not labelled historical");
    }
  counts.historicalReferences = historical;
  if (historical === 0) fail("no prototype evidence reference found, so the label is untested");

  // 7. Local links resolve, with their anchors.
  let links = 0;
  const docDir = path.dirname(path.join(root, DOC));
  for (const match of text.matchAll(/\[[^\]]*\]\(([^)\s]+)\)/g)) {
    const target = match[1];
    if (/^[a-z][a-z0-9+.-]*:/i.test(target)) continue;
    links += 1;
    const [rawPath, anchor] = target.split("#");
    const file = rawPath ? path.resolve(docDir, rawPath) : path.join(root, DOC);
    try {
      await readFile(file);
    } catch {
      fail("link target missing: " + target);
      continue;
    }
    if (anchor && file.endsWith(".md")) {
      const found = await anchorsOf(file);
      if (!found.has(anchor)) fail("link anchor missing: " + target);
    }
  }
  counts.links = links;

  // 8. Every stated hash matches a file named on its line.
  let hashes = 0;
  for (const [index, line] of lines.entries()) {
    const digests = [...line.matchAll(/\b([0-9a-f]{64})\b/g)].map((m) => m[1]);
    if (digests.length === 0) continue;
    const candidates = [
      ...[...line.matchAll(/\]\(([^)\s#]+)/g)].map((m) => m[1]),
      ...[...line.matchAll(/`([^`]+\.(?:md|csv|json))`/g)].map((m) => m[1]),
    ];
    for (const digest of digests) {
      hashes += 1;
      let matched = false;
      for (const candidate of candidates) {
        try {
          const bytes = await readFile(path.resolve(docDir, candidate));
          if (createHash("sha256").update(bytes).digest("hex") === digest) matched = true;
        } catch { /* a non-file candidate on the line */ }
      }
      if (!matched) fail("stated hash at line " + (index + 1) + " matches no file named on that line");
    }
  }
  counts.hashes = hashes;

  return { failures, counts };
}

const options = args(process.argv.slice(2));
if (!options.root || !options.out) {
  console.error("usage: node paper-check.mjs --root <repository-root> --out <directory>");
  process.exit(2);
}
const root = path.resolve(options.root);
const out = path.resolve(options.out);
const text = await readFile(path.join(root, DOC), "utf8");

const main = await runChecks(root, text, "check");

// Negative controls: each mutation must be caught.
const controls = [
  {
    name: "NC1 navigation step routes submit_action",
    text: text.replace("| gameplay | `submit_action`", "| navigation | `submit_action`"),
    expect: /submit_action from a navigation step/,
  },
  {
    name: "NC2 a stated hash is wrong",
    text: text.replace(/\b([0-9a-f]{63})[0-9a-f]\b/, (m, head) => head + "0"),
    expect: /stated hash at line/,
  },
  {
    name: "NC3 a question-gated parameter states a value",
    text: text.replace(
      "| IP-09 | The bound of the reduced-motion setting | unset |",
      "| IP-09 | The bound of the reduced-motion setting | 0.5 |",
    ),
    expect: /parameter IP-09 states a value/,
  },
];

const controlResults = [];
for (const control of controls) {
  if (control.text === text) {
    controlResults.push({ name: control.name, mutated: false, caught: false });
    continue;
  }
  const result = await runChecks(root, control.text, control.name);
  const caught = result.failures.some((message) => control.expect.test(message));
  controlResults.push({ name: control.name, mutated: true, caught, failures: result.failures.length });
}

const controlsPassed = controlResults.every((r) => r.mutated && r.caught);
const ok = main.failures.length === 0 && controlsPassed;
const report = {
  document: DOC,
  root,
  counts: main.counts,
  failures: main.failures,
  negativeControls: controlResults,
  result: ok ? "pass" : "fail",
};
await mkdir(out, { recursive: true });
await writeFile(path.join(out, "paper-check.json"), JSON.stringify(report, null, 2) + "\n");
for (const [key, value] of Object.entries(main.counts)) console.log(key + ": " + value);
for (const message of main.failures) console.log("FAIL " + message);
for (const control of controlResults)
  console.log(
    (control.mutated && control.caught ? "control caught: " : "CONTROL NOT CAUGHT: ") + control.name,
  );
console.log("result: " + report.result);
process.exit(ok ? 0 : 1);
