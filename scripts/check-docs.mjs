import { createHash } from "node:crypto";
import { access, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

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

function tableRows(lines, sectionHeading) {
  const start = lines.findIndex((line) => line.trim() === sectionHeading);
  if (start < 0) return null;
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
  return { start, end, rows };
}

async function checkTracking(docs) {
  const file = "TRACKING.md";
  if (!(await exists(path.join(docs.root, file)))) {
    docs.fail("tracking", file, 0, "required board file missing");
    return { events: 0, interim: [] };
  }
  const { lines } = await docs.load(file);
  const events = tableRows(lines, "## Append-only events");
  const sequence = new Set();
  if (!events)
    docs.fail("tracking", file, 0, "missing section ## Append-only events");
  else {
    const rows = events.rows.filter((row) =>
      /^EV-\d{4}$/.test(row.cells[0] ?? ""),
    );
    let previous = 0;
    for (const row of rows) {
      const id = row.cells[0];
      const value = Number(id.slice(3));
      if (sequence.has(id))
        docs.fail("tracking", file, row.line, "duplicate event " + id);
      else if (value !== previous + 1)
        docs.fail(
          "tracking",
          file,
          row.line,
          "event sequence break: " +
            id +
            " follows EV-" +
            String(previous).padStart(4, "0"),
        );
      sequence.add(id);
      previous = Math.max(previous, value);
    }
    if (rows.length) {
      const first = rows[0].line - 1;
      const last = rows[rows.length - 1].line - 1;
      for (let index = first; index <= last; index++)
        if (lines[index].trim() === "")
          docs.fail(
            "tracking",
            file,
            index + 1,
            "blank line inside the events table",
          );
        else if (!lines[index].startsWith("|"))
          docs.fail(
            "tracking",
            file,
            index + 1,
            "non-table line inside the events table",
          );
    }
  }
  const interim = [];
  const backlogAnchors = (await exists(path.join(docs.root, "BACKLOG.md")))
    ? (await docs.load("BACKLOG.md")).anchors
    : new Set();
  for (const heading of ["## Task state index", "## Question state index"]) {
    const table = tableRows(lines, heading);
    if (!table) {
      docs.fail("tracking", file, 0, "missing section " + heading);
      continue;
    }
    for (const row of table.rows) {
      const head = row.cells[0] ?? "";
      if (/^(Task ID|Question)$/.test(head)) continue;
      const link = /^\[([^\]]+)\]\(BACKLOG\.md#([^)]+)\)/.exec(head);
      if (!link) interim.push({ line: row.line, row: head });
      else if (!backlogAnchors.has(link[2]))
        docs.fail(
          "tracking",
          file,
          row.line,
          head + ": BACKLOG.md#" + link[2] + " has no anchor",
        );
      const lastEvent = row.cells[row.cells.length - 1] ?? "";
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
    }
  }
  for (const row of interim)
    docs.info(
      "tracking",
      file,
      row.line,
      "interim row without a BACKLOG link: " + row.row,
    );
  return { events: sequence.size, interim };
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
      sections,
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
