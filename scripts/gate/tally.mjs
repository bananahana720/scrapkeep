// Checks a gate plan's tally before the Gate writes CLEAN.
//
//   node scripts/gate/tally.mjs --plan /mnt/project-files/gate/w33-<head>-gate-plan.md
//
// The wave 30 promotion was called CLEAN with an empty tally row. This reads
// every "| Shard | Verdict |" table in the plan and refuses unless: each
// expected shard has a row, no verdict is empty, each names its receipt, the
// test windows cover the whole non-bot list, the newest row for each shard is
// not red, and no known-failing row is past its review date. When a head moves
// and a shard is read again, add a new row; the newest row for a name wins.

import { readFileSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { checkLedger } from "../known-failing.mjs";
import { gateLists } from "./shard.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const BOT_BLOCK = 5;

// Rows of every table whose header is "| Shard | Verdict |", in file order.
export function tallyRows(text) {
  const rows = [];
  let inTable = false;
  text.split("\n").forEach((line, index) => {
    const cells = line.trim().startsWith("|") ? line.trim().replace(/^\||\|$/g, "").split(/(?<!\\)\|/).map((cell) => cell.trim()) : null;
    if (!cells) {
      inTable = false;
      return;
    }
    if (cells.length === 2 && /^shard$/i.test(cells[0]) && /^verdict$/i.test(cells[1])) {
      inTable = true;
      return;
    }
    if (!inTable || cells.every((cell) => /^:?-+:?$/.test(cell))) return;
    rows.push({ shard: cells[0], verdict: cells.slice(1).join(" | "), line: index + 1 });
  });
  return rows;
}

export function expectedShards(botCount) {
  const names = [];
  for (let block = 1; block <= Math.ceil(botCount / BOT_BLOCK); block++) names.push(`bots ${block}`);
  return [...names, "bands A", "bands B", "bands C", "red team"];
}

const isRed = (verdict) => /^(?:NEW )?(?:RED|FAIL)\b/.test(verdict.replace(/^\*+/, ""));
const hasReceipt = (verdict) => /\breceipt\b|\blogs?\b/i.test(verdict);

export function checkTally(rows, { testCount, botCount }) {
  const problems = [];
  const latest = new Map();
  for (const row of rows) latest.set(row.shard.toLowerCase(), row);
  for (const row of rows) {
    if (row.verdict === "") problems.push(`line ${row.line}: "${row.shard}" has an empty verdict`);
  }
  for (const row of latest.values()) {
    if (row.verdict === "") continue;
    if (!hasReceipt(row.verdict)) problems.push(`line ${row.line}: "${row.shard}" names no receipt`);
    if (isRed(row.verdict)) problems.push(`line ${row.line}: "${row.shard}" is red in its newest row; fix it or carry it on the ledger, then add a new row`);
  }
  for (const name of expectedShards(botCount)) {
    if (![...latest.keys()].some((key) => key === name.toLowerCase() || key.startsWith(name.toLowerCase() + " "))) problems.push(`no row for "${name}"`);
  }
  const windows = [...latest.values()]
    .map((row) => /^tests (\d+)-(\d+)$/i.exec(row.shard))
    .filter(Boolean)
    .map((match) => [Number(match[1]), Number(match[2])])
    .sort((a, b) => a[0] - b[0]);
  let next = 1;
  for (const [first, last] of windows) {
    if (first > next) problems.push(`non-bot tests ${next} to ${first - 1} have no row`);
    next = Math.max(next, last + 1);
  }
  if (next <= testCount) problems.push(windows.length === 0 ? 'no "tests FIRST-LAST" row' : `non-bot tests ${next} to ${testCount} have no row`);
  return problems;
}

async function main() {
  const argv = process.argv.slice(2);
  const planAt = argv.indexOf("--plan");
  if (planAt < 0 || !argv[planAt + 1]) throw new Error("usage: node scripts/gate/tally.mjs --plan <gate plan.md>");
  const lists = gateLists(path.join(root, "sketches", "core-loop"));
  const rows = tallyRows(readFileSync(argv[planAt + 1], "utf8"));
  const problems = checkTally(rows, { testCount: lists.tests.length, botCount: lists.bots.length });
  const ledger = (await checkLedger(root, { promotion: true })).filter((finding) => finding.level === "failure");
  for (const finding of ledger) problems.push(`ledger line ${finding.line}: ${finding.message}`);
  for (const problem of problems) console.log("PROBLEM " + problem);
  console.log(`gate tally: ${rows.length} rows, ${lists.tests.length} non-bot tests, ${lists.bots.length} bot tests. ${problems.length === 0 ? "Every row is filled; CLEAN may be written" : `Not clean: ${problems.length} problem${problems.length === 1 ? "" : "s"}`}.`);
  return problems.length === 0 ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    process.exitCode = await main();
  } catch (error) {
    console.error("gate tally: " + (error?.message ?? error));
    process.exitCode = 2;
  }
}
