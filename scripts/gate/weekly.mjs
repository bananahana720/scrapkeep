// The weekly list: tests a promotion does not run (ruling ca). They run when a
// change touches their files (the fast lane) and in a weekly sweep. One row per
// test in project-guide/handoff/WEEKLY.tsv, beside the known-failing ledger
// (sketch-lint allows no list file under tests/). This module imports nothing
// from the gate, so the ledger and the shard runner can both read it.

import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

export const WEEKLY_FILE = "project-guide/handoff/WEEKLY.tsv";
export const WEEKLY_HEADER = ["test", "group", "reason", "returns-when"];

export function parseWeekly(text) {
  const lines = (text || "").split("\n").map((line) => line.replace(/\r$/, ""));
  const problems = [];
  const rows = [];
  if (lines[0] !== WEEKLY_HEADER.join("\t")) return { rows, problems: [`line 1: the header must be: ${WEEKLY_HEADER.join(" TAB ")}`] };
  const seen = new Set();
  lines.slice(1).forEach((line, index) => {
    if (line.trim() === "") return;
    const cells = line.split("\t").map((cell) => cell.trim());
    if (cells.length !== WEEKLY_HEADER.length || cells.some((cell) => cell === "")) problems.push(`line ${index + 2}: a row needs ${WEEKLY_HEADER.join(", ")}, with no cell empty`);
    else if (!/^[a-z0-9_]+$/.test(cells[0])) problems.push(`line ${index + 2}: "${cells[0]}" must be the test's base name, with no folder and no .gd`);
    else if (seen.has(cells[0])) problems.push(`line ${index + 2}: ${cells[0]} is listed twice`);
    else {
      seen.add(cells[0]);
      rows.push({ test: cells[0], group: cells[1], reason: cells[2], returnsWhen: cells[3] });
    }
  });
  return { rows, problems };
}

// The names on the list under `root`, or an empty set when there is no file.
// Throws when the file does not parse: a broken list never reads as "skip nothing".
export function weeklyNames(root, file = path.join(root, WEEKLY_FILE)) {
  if (!existsSync(file)) return new Set();
  const { rows, problems } = parseWeekly(readFileSync(file, "utf8"));
  if (problems.length > 0) throw new Error(`${WEEKLY_FILE} does not parse: ${problems.join("; ")}`);
  return new Set(rows.map((row) => row.test));
}
