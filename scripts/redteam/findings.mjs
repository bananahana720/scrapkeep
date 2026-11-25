#!/usr/bin/env node

import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FINDINGS_FILE, overdueFindings, parseFindings } from "./lib.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const mode = process.argv[2] || "--check";
if (!["--check", "--overdue", "--print"].includes(mode)) {
  console.error("findings: use --check, --overdue or --print");
  process.exit(2);
}
const { rows, problems } = parseFindings(readFileSync(path.join(root, FINDINGS_FILE), "utf8"));
for (const problem of problems)
  console.error(`${FINDINGS_FILE}:${problem.line} ${problem.message}`);
if (problems.length) process.exit(1);
if (mode === "--print") {
  console.log(
    "| id | grade | what the player meets | owner | review |\n| --- | --- | --- | --- | --- |",
  );
  for (const row of [...rows].sort((a, b) => a.owner.localeCompare(b.owner)))
    console.log(
      `| ${row.id} | ${row.grade} | ${row.meets.replaceAll("|", "/")} | ${row.owner} | ${row.review} |`,
    );
  process.exit(0);
}
const late =
  mode === "--overdue" ? overdueFindings(rows, new Date().toISOString().slice(0, 10)) : [];
for (const row of late)
  console.error(`${row.id} is past its review date (${row.review}, ${row.owner}): ${row.meets}`);
console.log(`play findings: ${rows.length} open, ${late.length} past review`);
process.exit(late.length ? 1 : 0);
