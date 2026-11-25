import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

export const WEEKLY_FILE = "project-guide/handoff/WEEKLY.tsv";
export const WEEKLY_HEADER = ["test", "group", "reason", "returns-when"];

export function parseWeekly(text) {
  const lines = (text || "").split("\n").map((line) => line.replace(/\r$/, ""));
  const problems = [];
  const rows = [];
  if (lines[0] !== WEEKLY_HEADER.join("\t"))
    return { rows, problems: [`line 1: the header must be: ${WEEKLY_HEADER.join(" TAB ")}`] };
  const seen = new Set();
  lines.slice(1).forEach((line, index) => {
    if (line.trim() === "") return;
    const cells = line.split("\t").map((cell) => cell.trim());
    if (cells.length !== WEEKLY_HEADER.length || cells.some((cell) => cell === ""))
      problems.push(
        `line ${index + 2}: a row needs ${WEEKLY_HEADER.join(", ")}, with no cell empty`,
      );
    else if (!/^[a-z0-9_]+$/.test(cells[0]))
      problems.push(
        `line ${index + 2}: "${cells[0]}" must be the test's base name, with no folder and no .gd`,
      );
    else if (seen.has(cells[0])) problems.push(`line ${index + 2}: ${cells[0]} is listed twice`);
    else {
      seen.add(cells[0]);
      rows.push({
        test: cells[0],
        group: cells[1],
        reason: cells[2],
        returnsWhen: cells[3],
        line: index + 2,
      });
    }
  });
  return { rows, problems };
}

export function weeklyNames(root, file = path.join(root, WEEKLY_FILE)) {
  if (!existsSync(file)) return new Set();
  const { rows, problems } = parseWeekly(readFileSync(file, "utf8"));
  if (problems.length > 0) throw new Error(`${WEEKLY_FILE} does not parse: ${problems.join("; ")}`);
  return new Set(rows.map((row) => row.test));
}

export function checkWeekly(root, testsDirectory = "sketches/core-loop/tests") {
  const file = path.join(root, WEEKLY_FILE);
  if (!existsSync(file)) return [];
  const { rows, problems } = parseWeekly(readFileSync(file, "utf8"));
  const findings = problems.map((problem) => {
    const [, line, message] = /^line (\d+): (.*)$/s.exec(problem);
    return { level: "failure", file: WEEKLY_FILE, line: Number(line), message };
  });
  const tests = path.join(root, testsDirectory);
  if (!existsSync(tests)) return findings;
  for (const row of rows) {
    if (!existsSync(path.join(tests, row.test + ".gd"))) {
      findings.push({
        level: "failure",
        file: WEEKLY_FILE,
        line: row.line,
        message: `${row.test} has no file ${testsDirectory}/${row.test}.gd; remove the row or fix the name`,
      });
    }
  }
  return findings;
}
