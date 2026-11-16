import { createHash } from "node:crypto";
import { access, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

import { checkLedger } from "./known-failing.mjs";
import { checkWeekly } from "./gate/weekly.mjs";
import { checkWaveState } from "./wave-state.mjs";

const scriptRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const limits =
  "Structural documentation checks only. No build, runtime, browser or remote check is implied; link targets are checked for existence and anchors, not for content correctness.";
const cardFields = [
  "Card revision",
  "Owner",
  "Size",
  "Lane",
  "Source and inputs",
  "Dependencies",
  "Blocking questions",
  "Files touched",
  "Definition of done",
  "Verification and evidence",
  "Boundary",
];
const sectionHeadings = [
  "Sources",
  "Contract",
  "Scenarios",
  "Unresolved questions",
  "Re-verification triggers",
  "Procedure performed",
  "Evidence limits",
];
// TRACKING.md § Task record schema owns this vocabulary (the `state` row); the
// question index has its own four states and is deliberately not checked here.
const taskStates = [
  "queued",
  "blocked",
  "ready",
  "in_progress",
  "review",
  "changes_requested",
  "done",
  "parked",
  "cancelled",
];
// TRACKING.md § Event schema and write discipline allows a batch event to name
// an explicit ID list, so a program-level event names records as authorization
// scope rather than as changed records and cannot make an index row stale:
// EV-0077 (sprint closure) and EV-0078 (authorization/coordination) name all
// fourteen foundation cards while their rows correctly still point at each
// card's own last change (EV-0075, EV-0072, EV-0029). Every other event that
// names a record can make that record's row stale.
const programEvent = /authorization|coordination|closure/i;
// Record IDs as a cell writes them: HF-01, HF-03a, S0-09, PS-05a, Q-E01.
const recordIdPattern = /[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+[a-z]?/g;
const recordIds = (cell) => [...new Set(cell.match(recordIdPattern) ?? [])];

// Event archives -- the declaration the coordinator authors against.
//
// An event may move out of TRACKING.md into a tracked archive without breaking
// the index rows that cite it, but a moved event must be *declared*, never
// guessed from a path or a file name. A Markdown file declares itself an event
// archive with a level-2 heading whose text is exactly `Event archive`:
//
//     ## Event archive
//
// The declaration is the only thing that makes a file an event archive; its
// path and name are free. The coordinator's chosen location,
// docs/project/tracking/EVENTS-0001-0057.md, is therefore recognised, but so is
// any other name in documentation scope. The event rows are the table rows under
// that heading (up to the next `##` heading) with the same
// `Sequence | UTC timestamp | Actor / kind | Affected records | Change and
// evidence` columns as TRACKING.md § Append-only events, so the split moves rows
// verbatim. A file may carry more than one `## Event archive` section.
//
// A heading that only resembles the declaration (`# Event archive`,
// `## Event Archive`, `## Event archives`, `## Event archive: EV-0001..EV-0057`)
// is a failure rather than a silent no-op, so a mistyped archive cannot quietly
// stop resolving ids. Documenting the heading inside a fenced code block stays
// safe: fenced lines are blanked before scanning.
//
// Checked sources are the live board plus every declared archive in the
// documentation scope this checker already walks (top-level *.md, adr/**,
// docs/**, artifacts/*/README.md, excluding artifacts/local/). TRACKING.md is
// never also read as an archive, and scratch or worktree copies are out of
// scope, so a copy of an archive cannot make a real id look duplicated.
const eventArchiveHeading = "## Event archive";
const eventArchiveHeadingLike = /^#{1,6}\s+Events?\s+archives?\b/i;
const isEventId = (cell) => /^EV-\d{4}$/.test(cell ?? "");

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
  options.report ??= path.join(
    options.root,
    "artifacts/local/check-docs/report.json",
  );
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

async function walk(root, directory, keep) {
  const files = [];
  const absolute = path.join(root, directory);
  if (!(await exists(absolute))) return files;
  for (const item of await readdir(absolute, { withFileTypes: true })) {
    const file = path.posix.join(directory, item.name);
    if (item.isDirectory()) files.push(...(await walk(root, file, keep)));
    else if (item.isFile() && keep(file)) files.push(file);
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
      (file) =>
        path.posix.basename(file) === "README.md" &&
        !file.startsWith("artifacts/local/"),
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
    for (const match of line.matchAll(/<a\s+(?:name|id)="([^"]+)"/g))
      anchors.add(match[1]);
  }
  return anchors;
}

class Documents {
  constructor(root) {
    this.root = root;
    this.cache = new Map();
    this.findings = [];
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
          "non-portable absolute link: " + target,
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
        docs.fail(
          "links",
          file,
          number,
          "malformed percent-encoding in link: " + target,
        );
        continue;
      }
      let targetFile = file;
      if (decodedPath) {
        targetFile = path.posix.normalize(
          path.posix.join(path.posix.dirname(file), decodedPath),
        );
        if (targetFile === ".." || targetFile.startsWith("../")) {
          docs.fail(
            "links",
            file,
            number,
            "link escapes repository: " + target,
          );
          continue;
        }
        if (!(await exists(path.join(docs.root, targetFile)))) {
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
          "broken anchor: " +
            target +
            " (no heading or <a id> for #" +
            anchor +
            ")",
        );
    }
  }
  return checked;
}

function precedingAnchor(lines, index) {
  for (let cursor = index - 1; cursor >= 0; cursor--) {
    if (lines[cursor].trim() === "") continue;
    return /^<a\s+id="([^"]+)"><\/a>\s*$/.exec(lines[cursor])?.[1] ?? null;
  }
  return null;
}

async function checkBacklog(docs) {
  const file = "BACKLOG.md";
  if (!(await exists(path.join(docs.root, file)))) {
    docs.fail("backlog", file, 0, "required board file missing");
    return 0;
  }
  const { lines, anchors } = await docs.load(file);
  let cards = 0;
  for (const [index, line] of lines.entries()) {
    const heading = /^###\s+([A-Z][A-Z0-9]*-[A-Z0-9]+[a-z]?):\s/.exec(line);
    if (!heading) continue;
    const id = heading[1];
    const number = index + 1;
    const anchor = precedingAnchor(lines, index);
    if (anchor !== id.toLowerCase())
      docs.fail(
        "backlog",
        file,
        number,
        id +
          ": preceding <a id> is " +
          JSON.stringify(anchor) +
          ", expected " +
          id.toLowerCase(),
      );
    if (id.startsWith("Q-")) continue;
    cards++;
    let end = index + 1;
    while (end < lines.length && !/^(##\s|###\s)/.test(lines[end])) end++;
    const body = lines.slice(index + 1, end);
    for (const field of cardFields)
      if (!body.some((entry) => entry.includes("**" + field + ":**")))
        docs.fail(
          "backlog",
          file,
          number,
          id + ": missing field **" + field + ":**",
        );
    for (const [offset, entry] of body.entries()) {
      const size = /\*\*Size:\*\*\s*([A-Z]+)/.exec(entry);
      if (size && !["S", "M"].includes(size[1]))
        docs.fail(
          "backlog",
          file,
          number + offset + 1,
          id + ": non-assignable card, Size " + size[1] + " (S or M required)",
        );
      if (
        !/\*\*(Dependencies|Blocking questions|Registered non-blocking questions):\*\*/.test(
          entry,
        )
      )
        continue;
      for (const link of entry.matchAll(/\[([^\]]+)\]\(#([^)]+)\)/g)) {
        if (!anchors.has(link[2]))
          docs.fail(
            "backlog",
            file,
            number + offset + 1,
            id + ": dependency or question link #" + link[2] + " has no anchor",
          );
        else if (link[1].toLowerCase() !== link[2])
          docs.fail(
            "backlog",
            file,
            number + offset + 1,
            id + ": link text " + link[1] + " does not name anchor #" + link[2],
          );
      }
    }
  }
  return cards;
}

// Every section whose heading text is exactly the given one, so an archive that
// repeats the declaration is read whole instead of dropping the later rows.
function tableSections(lines, sectionHeading) {
  const sections = [];
  for (let start = 0; start < lines.length; start++) {
    if (lines[start].trim() !== sectionHeading) continue;
    let end = start + 1;
    while (end < lines.length && !/^##\s/.test(lines[end])) end++;
    const rows = [];
    for (let index = start + 1; index < end; index++) {
      const line = lines[index];
      if (!line.startsWith("|") || /^\|\s*-{3}/.test(line)) continue;
      const cells = line
        .split("|")
        .slice(1, -1)
        .map((cell) => cell.trim());
      rows.push({ line: index + 1, cells });
    }
    sections.push({ start, end, rows });
  }
  return sections;
}

function tableRows(lines, sectionHeading) {
  const section = tableSections(lines, sectionHeading)[0];
  return section
    ? { start: section.start, end: section.end, rows: section.rows }
    : null;
}

// Every declared event archive in documentation scope, as an event source:
// { file, lines, sections, rows } with rows already limited to EV-NNNN ids.
async function eventArchives(docs) {
  const archives = [];
  for (const file of await markdownFiles(docs.root)) {
    if (file === "TRACKING.md") continue;
    const { lines } = await docs.load(file);
    const declared = [];
    for (const [index, line] of lines.entries())
      if (eventArchiveHeadingLike.test(line.trim())) declared.push(index + 1);
    if (!declared.length) continue;
    const exact = [];
    for (const line of declared)
      if (lines[line - 1].trim() === eventArchiveHeading) exact.push(line);
      else
        docs.fail(
          "tracking",
          file,
          line,
          "malformed event archive heading: " +
            JSON.stringify(lines[line - 1].trim()) +
            " (an event archive declares itself with a level-2 heading that is exactly " +
            JSON.stringify(eventArchiveHeading) +
            ")",
        );
    if (!exact.length) continue;
    const sections = tableSections(lines, eventArchiveHeading);
    const rows = sections
      .flatMap((section) => section.rows)
      .filter((row) => isEventId(row.cells[0]));
    if (!rows.length) {
      docs.fail(
        "tracking",
        file,
        exact[0],
        "declared event archive holds no EV-NNNN event rows",
      );
      continue;
    }
    archives.push({ file, lines, sections, rows });
  }
  return archives;
}

async function checkTracking(docs) {
  const file = "TRACKING.md";
  if (!(await exists(path.join(docs.root, file)))) {
    docs.fail("tracking", file, 0, "required board file missing");
    return { events: 0, interim: [], states: 0, archives: 0 };
  }
  const { lines } = await docs.load(file);
  const events = tableRows(lines, "## Append-only events");
  if (!events)
    docs.fail("tracking", file, 0, "missing section ## Append-only events");
  // Event sources: the live board, then every archive that declares itself an
  // event archive. The board keeps the shape the AR-01 rules were written
  // against; archives contribute ids, sequence positions and named records.
  const archives = await eventArchives(docs);
  const sources = [
    {
      file,
      lines,
      sections: events ? [events] : [],
      rows: (events?.rows ?? []).filter((row) => isEventId(row.cells[0])),
    },
    ...archives,
  ];
  const lowest = (source) =>
    Math.min(...source.rows.map((row) => Number(row.cells[0].slice(3))));
  // The id space is checked over the ordered union of sources: each source keeps
  // its own file order, and the sources themselves are ordered by their lowest
  // event id, so an archived EV-0001..EV-0057 prefix precedes the board's
  // EV-0058.. continuation. With no archive this is exactly the single-table
  // ascending, gap-free sequence the board has always been checked against, and
  // an id that appears twice in or across sources is still a failure.
  const ordered = sources
    .filter((source) => source.rows.length)
    .sort((left, right) => {
      const byEvent = lowest(left) - lowest(right);
      if (byEvent) return byEvent;
      if (left.file === right.file) return 0;
      if (left.file === file) return -1;
      if (right.file === file) return 1;
      return left.file.localeCompare(right.file);
    });
  const sequence = new Set();
  const firstSeen = new Map();
  let previous = 0;
  for (const source of ordered)
    for (const row of source.rows) {
      const id = row.cells[0];
      const value = Number(id.slice(3));
      if (sequence.has(id)) {
        const first = firstSeen.get(id);
        docs.fail(
          "tracking",
          source.file,
          row.line,
          "duplicate event " +
            id +
            " (first seen in " +
            first.file +
            ":" +
            first.line +
            ")",
        );
      } else if (value !== previous + 1)
        docs.fail(
          "tracking",
          source.file,
          row.line,
          "event sequence break: " +
            id +
            " follows EV-" +
            String(previous).padStart(4, "0"),
        );
      sequence.add(id);
      if (!firstSeen.has(id))
        firstSeen.set(id, { file: source.file, line: row.line });
      previous = Math.max(previous, value);
    }
  // The events table stays one unbroken table in every source, archive included.
  for (const source of sources)
    for (const section of source.sections) {
      const rows = section.rows.filter((row) => isEventId(row.cells[0]));
      if (!rows.length) continue;
      const first = rows[0].line - 1;
      const last = rows[rows.length - 1].line - 1;
      for (let index = first; index <= last; index++)
        if (source.lines[index].trim() === "")
          docs.fail(
            "tracking",
            source.file,
            index + 1,
            "blank line inside the events table",
          );
        else if (!source.lines[index].startsWith("|"))
          docs.fail(
            "tracking",
            source.file,
            index + 1,
            "non-table line inside the events table",
          );
    }
  // Which records each change-carrying event names, so an index row can be
  // compared against events that arrived after its own Last event. Archived
  // events take part here too, which is what keeps the stale-row rule alive once
  // the events it compares have moved out of the board, and still lets a later
  // board event make a row that points into an archive stale.
  const namedEvents = new Map();
  for (const source of sources) {
    const header = source.sections[0]?.rows[0]?.cells ?? [];
    const affectedIndex = header.indexOf("Affected records");
    const kindIndex = header.indexOf("Actor / kind");
    for (const row of source.rows) {
      if (programEvent.test(row.cells[kindIndex >= 0 ? kindIndex : 2] ?? ""))
        continue;
      const event = { id: row.cells[0], sequence: Number(row.cells[0].slice(3)) };
      for (const id of recordIds(row.cells[affectedIndex >= 0 ? affectedIndex : 3] ?? ""))
        namedEvents.set(id, [...(namedEvents.get(id) ?? []), event]);
    }
  }
  const interim = [];
  let states = 0;
  const backlogAnchors = (await exists(path.join(docs.root, "BACKLOG.md")))
    ? (await docs.load("BACKLOG.md")).anchors
    : new Set();
  for (const heading of ["## Task state index", "## Question state index"]) {
    const table = tableRows(lines, heading);
    if (!table) {
      docs.fail("tracking", file, 0, "missing section " + heading);
      continue;
    }
    const header = table.rows[0]?.cells ?? [];
    const lastEventIndex = header.indexOf("Last event");
    const stateIndex = header.indexOf("State");
    const taskIndex = heading === "## Task state index";
    if (taskIndex && stateIndex < 0)
      docs.fail("tracking", file, table.start + 1, "task index has no State column");
    for (const row of table.rows) {
      const head = row.cells[0] ?? "";
      if (/^(Task ID|Question)$/.test(head)) continue;
      const link = /^\[([^\]]+)\]\(BACKLOG\.md#([^)]+)\)/.exec(head);
      // The row names its record through the link text, or through the first
      // token of an interim row ("PS-06 (S0-01, S0-04)" is PS-06).
      const record = (link ? link[1] : head.split(/[\s(]/)[0]).trim();
      if (!link) interim.push({ line: row.line, row: head });
      else if (!backlogAnchors.has(link[2]))
        docs.fail(
          "tracking",
          file,
          row.line,
          head + ": BACKLOG.md#" + link[2] + " has no anchor",
        );
      if (taskIndex && stateIndex >= 0) {
        states++;
        const state = row.cells[stateIndex] ?? "";
        if (!taskStates.includes(state))
          docs.fail(
            "tracking",
            file,
            row.line,
            head +
              ": state " +
              JSON.stringify(state) +
              " is not in the state vocabulary (" +
              taskStates.join(", ") +
              ")",
          );
      }
      const lastEvent =
        lastEventIndex >= 0
          ? (row.cells[lastEventIndex] ?? "")
          : (row.cells[row.cells.length - 1] ?? "");
      if (!/^EV-\d{4}$/.test(lastEvent))
        docs.fail(
          "tracking",
          file,
          row.line,
          head +
            ": Last event is not an EV-NNNN id: " +
            JSON.stringify(lastEvent),
        );
      else if (!sequence.has(lastEvent))
        docs.fail(
          "tracking",
          file,
          row.line,
          head + ": Last event " + lastEvent + " is not in the events table",
        );
      else {
        const value = Number(lastEvent.slice(3));
        const later = (namedEvents.get(record) ?? [])
          .filter((event) => event.sequence > value)
          .sort((left, right) => right.sequence - left.sequence);
        if (later.length)
          docs.fail(
            "tracking",
            file,
            row.line,
            head +
              ": Last event " +
              lastEvent +
              " predates " +
              later[0].id +
              ", which also names " +
              record,
          );
      }
    }
  }
  for (const row of interim)
    docs.info(
      "tracking",
      file,
      row.line,
      "interim row without a BACKLOG link: " + row.row,
    );
  return { events: sequence.size, interim, states, archives: archives.length };
}

async function checkSections(docs) {
  const files = await walk(docs.root, "docs/tech/sections", (file) =>
    file.endsWith(".md"),
  );
  for (const file of files) {
    const { lines } = await docs.load(file);
    const present = new Set(
      lines
        .map((line) =>
          /^#{1,6}\s+(.*?)\s*#*\s*$/.exec(line)?.[1].trim().toLowerCase(),
        )
        .filter(Boolean),
    );
    for (const heading of sectionHeadings)
      if (!present.has(heading.toLowerCase()))
        docs.fail("sections", file, 0, "missing required heading: " + heading);
  }
  return files.length;
}

async function checkClosureContract(docs) {
  const contracts = {
    "ORCHESTRATOR.md": ["Sprint closure", "Specification contradictions"],
    "docs/project/prompts/sprint-close.md": ["Close the selected sprint"],
    "docs/project/sprint-0/amendment-request.md": ["Request identity and context", "Conflicting clauses and observation", "Classification and proposed change", "Decision record", "Admission and propagation receipt", "Closure disposition"],
    "docs/project/sprint-0/closure-receipt.md": ["Receipt schema", "Mandatory gates", "Run the checker", "Evidence limits"],
  };
  for (const [file, headings] of Object.entries(contracts)) {
    if (!(await exists(path.join(docs.root, file)))) {
      docs.fail("closure", file, 0, "required closure contract missing");
      continue;
    }
    const { anchors } = await docs.load(file);
    for (const heading of headings)
      if (!anchors.has(slugify(heading)))
        docs.fail("closure", file, 0, "missing required closure heading: " + heading);
  }
  for (const [file, target] of [
    ["ORCHESTRATOR.md", "docs/project/prompts/sprint-close.md"],
    ["ORCHESTRATOR.md", "docs/project/sprint-0/amendment-request.md"],
    ["docs/project/prompts/sprint-close.md", "../../../ORCHESTRATOR.md#sprint-closure"],
  ]) {
    if (!(await exists(path.join(docs.root, file)))) continue;
    const { lines } = await docs.load(file);
    const linked = lines.some((line) => [...line.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)].some((match) => match[1] === target));
    if (!linked) docs.fail("closure", file, 0, "missing required closure link: " + target);
  }
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
  const result = spawnSync(
    process.execPath,
    [script, "--root", docs.root, "--json"],
    { encoding: "utf8", timeout: timeoutMs },
  );
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
    if (finding.level === "failure")
      docs.fail("skills", finding.file, finding.line, message);
    else docs.info("skills", finding.file, finding.line, message);
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
  const cards = await checkBacklog(docs);
  const tracking = await checkTracking(docs);
  const sections = await checkSections(docs);
  await checkClosureContract(docs);
  const skillFindings = await checkSkillsStage(docs);
  const waveFindings = await checkWaveStateStage(docs);
  const ledgerFindings = await checkLedgerStage(docs);
  await checkRulingLetters(docs);
  const manifest = {};
  for (const file of [...docs.cache.keys()].sort())
    manifest[file] = docs.cache.get(file).sha256;
  const failures = docs.findings.filter(
    (finding) => finding.level === "failure",
  );
  const report = {
    result: failures.length ? "fail" : "pass",
    root: options.root,
    checked: {
      files: files.length,
      links,
      cards,
      events: tracking.events,
      archives: tracking.archives,
      states: tracking.states,
      sections,
      skillFindings,
      waveFindings,
      ledgerFindings,
    },
    failures: failures.length,
    findings: docs.findings,
    interimRows: tracking.interim,
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
      cards +
      " cards, " +
      tracking.events +
      " events, " +
      sections +
      " sections, " +
      tracking.interim.length +
      " interim rows, " +
      skillFindings +
      " skill findings, " +
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
