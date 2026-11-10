#!/usr/bin/env node
// The play findings list: project-guide/handoff/PLAY-FINDINGS.tsv.
//
//   node scripts/redteam/findings.mjs --check        structure only
//   node scripts/redteam/findings.mjs --overdue      structure, and exit 1 when a row is past its review date
//   node scripts/redteam/findings.mjs --print        the list as a Markdown table, by owner
//
// A row is an open thing a player would feel: what they meet, where it was seen, who owns the fix
// and the date it is looked at again. The pull request that fixes one removes its row. A finding
// never holds a promotion (ruling cn): --overdue is a report for the owners, not a gate step.

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
for (const problem of problems) console.error(`${FINDINGS_FILE}:${problem.line} ${problem.message}`);
if (problems.length) process.exit(1);
if (mode === "--print") {
  console.log("| id | grade | what the player meets | owner | review |\n| --- | --- | --- | --- | --- |");
  for (const row of [...rows].sort((a, b) => a.owner.localeCompare(b.owner))) console.log(`| ${row.id} | ${row.grade} | ${row.meets.replaceAll("|", "/")} | ${row.owner} | ${row.review} |`);
  process.exit(0);
}
const late = mode === "--overdue" ? overdueFindings(rows, new Date().toISOString().slice(0, 10)) : [];
for (const row of late) console.error(`${row.id} is past its review date (${row.review}, ${row.owner}): ${row.meets}`);
console.log(`play findings: ${rows.length} open, ${late.length} past review`);
process.exit(late.length ? 1 : 0);
