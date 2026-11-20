// Checks a gate plan's tally before the Gate writes CLEAN.
//
//   node scripts/gate/tally.mjs --plan /mnt/project-files/gate/w33-<head>-gate-plan.md
//
// The wave 30 promotion was called CLEAN with an empty tally row. This reads
// every "| Shard | Verdict |" table in the plan and refuses unless: each
// expected shard has a row, no verdict is empty, each names its receipt, the
// test windows cover the whole non-bot list, the newest row for each shard
// opens with PASS (CLEAR for the red team), the plan gates the checked-out head, no known-failing row is past its review date,
// and, while tests sit on the weekly list, a "weekly sweep" row dates a sweep no older than a week. When a head moves
// and a shard is read again, add a new row; the newest row for a name wins.
//
//   node scripts/gate/tally.mjs --wave --plan <plan>
//
// The wave gate (ruling cy, 11 November 2026) tests where a wave changed the game and leaves the wide sweeps to the
// release gate at the end of a sprint. With --wave the plan still needs every non-bot test window, and in place of
// the bot blocks, the three band sweeps and the red team it needs one "scoped" row: the bot and band tests the
// wave's changes reach, by name. A release shard may still have a row; it may open with DEFERRED and name the
// receipt of its last full read. Without --wave nothing is deferred: that is the release gate.
//
// Both scopes also read the plan's "| Check | Verdict |" table and refuse unless its newest "node tests" row
// passed with 0 fails and names its receipt (checkNodeRow).

import { spawnSync } from "node:child_process";
import { readFileSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { checkLedger } from "../known-failing.mjs";
import { WEEKLY_FILE, gateLists } from "./shard.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const BOT_BLOCK = 5;

// Rows of every table whose header is "| Shard | Verdict |" (or "| Check | Verdict |" with that
// first word), in file order.
export function tallyRows(text, first = "shard") {
  const rows = [];
  let inTable = false;
  text.split("\n").forEach((line, index) => {
    const cells = line.trim().startsWith("|")
      ? line
          .trim()
          .replace(/^\||\|$/g, "")
          .split(/(?<!\\)\|/)
          .map((cell) => cell.trim())
      : null;
    if (!cells) {
      inTable = false;
      return;
    }
    if (
      cells.length === 2 &&
      cells[0].toLowerCase() === first.toLowerCase() &&
      /^verdict$/i.test(cells[1])
    ) {
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
  for (let block = 1; block <= Math.ceil(botCount / BOT_BLOCK); block++)
    names.push(`bots ${block}`);
  return [...names, "bands A", "bands B", "bands C", "red team"];
}

// A verdict passes only when it says so first: PASS, or CLEAR for the red team. Any other
// opening word (RED, FAIL, "red:", "1 new red", a sentence) is not a pass, so a red shard
// worded another way cannot slip under CLEAN.
export const isPass = (verdict) =>
  /^(?:PASS|CLEAR)\b/.test(
    verdict
      .replace(/^[\s*_]+/, "")
      .replace(/^verdict:\s*/i, "")
      .replace(/^[\s*_]+/, ""),
  );
const hasReceipt = (verdict) => /\breceipts?\b|\blogs?\b/i.test(verdict);

export const SCOPED_SHARD = "scoped";
// A release shard the wave gate does not read says so first, and names where it was last read in full.
export const isDeferred = (verdict) => /^DEFERRED\b/.test(verdict.replace(/^[\s*_]+/, ""));
const isReleaseShard = (shard, botCount) =>
  expectedShards(botCount).some(
    (name) =>
      shard.toLowerCase() === name.toLowerCase() ||
      shard.toLowerCase().startsWith(name.toLowerCase() + " "),
  );

// "w33-1a2b3c4d-gate-plan.md" names the head the plan gates.
export function planHead(file) {
  return /(?:^|[/-])w\d+-([0-9a-f]{7,40})-gate-plan\.md$/.exec(file)?.[1] ?? null;
}

export const WEEKLY_SHARD = "weekly sweep";
export const WEEKLY_MAX_DAYS = 7;

// The weekly list's hold (ruling ca): a test the promotion does not run must still have run lately. While
// the list names any test, the plan carries a "weekly sweep" row whose verdict gives the day the sweep ran
// (YYYY-MM-DD, the first date in it). checkTally's own checks make that row open with PASS and name its
// receipt; this one refuses a missing row, a row with no day, and a sweep more than WEEKLY_MAX_DAYS old.
export function checkWeeklySweep(rows, { weeklyCount = 0, today = new Date() } = {}) {
  if (weeklyCount === 0) return [];
  const sweep = `node scripts/gate/shard.mjs run --weekly --tests 1-N, then --weekly --bots 1-N`;
  const row = [...rows]
    .reverse()
    .find((candidate) => candidate.shard.toLowerCase() === WEEKLY_SHARD);
  if (!row)
    return [
      `no row for "${WEEKLY_SHARD}": ${weeklyCount} tests are on the weekly list and a promotion needs their last sweep (${sweep}; verdict "PASS YYYY-MM-DD ..." with its receipts)`,
    ];
  if (row.verdict === "") return [];
  const match = /\b(\d{4})-(\d{2})-(\d{2})\b/.exec(row.verdict);
  const ran = match ? Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])) : NaN;
  if (!match || new Date(ran).toISOString().slice(0, 10) !== match[0])
    return [
      `line ${row.line}: "${row.shard}" gives no day the sweep ran; write it as YYYY-MM-DD in the verdict`,
    ];
  const age = Math.round(
    (Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()) - ran) / 86_400_000,
  );
  if (age < 0)
    return [`line ${row.line}: "${row.shard}" is dated ${match[0]}, which is after today`];
  if (age > WEEKLY_MAX_DAYS)
    return [
      `line ${row.line}: the weekly sweep last ran on ${match[0]}, ${age} days ago; a promotion needs one within ${WEEKLY_MAX_DAYS} days (${sweep}), then a new row`,
    ];
  return [];
}

export const NODE_CHECK = "node tests";

// The plan's Gate-side table carries the node suite's result for the gated head (scripts/gate/pc.mjs
// writes it from node/summary.txt). A release tally once read CLEAN beside a red node step because
// only the shard tables were read, so the newest "node tests" row must open with PASS, give
// "N tests, 0 fail" with N above zero, and name its receipt.
export function checkNodeRow(text) {
  const row = tallyRows(text, "check")
    .reverse()
    .find((candidate) => candidate.shard.toLowerCase() === NODE_CHECK);
  if (!row)
    return [
      `no "${NODE_CHECK}" row in a "| Check | Verdict |" table; run the node suite on the gated head and record "PASS. N tests, 0 fail. Receipt node/summary.txt"`,
    ];
  const problems = [];
  const counts = [...row.verdict.matchAll(/\b(\d+) tests, (\d+) fail\b/g)];
  if (!isPass(row.verdict))
    problems.push(`line ${row.line}: "${row.shard}" does not open with PASS in its newest row`);
  if (
    counts.length === 0 ||
    counts.some(([, tests, fail]) => Number(tests) === 0 || Number(fail) !== 0)
  )
    problems.push(
      `line ${row.line}: "${row.shard}" does not read "N tests, 0 fail" with N above zero`,
    );
  if (!hasReceipt(row.verdict)) problems.push(`line ${row.line}: "${row.shard}" names no receipt`);
  return problems;
}

export function checkTally(
  rows,
  {
    testCount,
    botCount,
    planHead: gated = null,
    head = null,
    weeklyCount = 0,
    today = new Date(),
    scope = "release",
  },
) {
  const wave = scope === "wave";
  const problems = [];
  if (gated && head && !head.startsWith(gated) && !gated.startsWith(head))
    problems.push(
      `the plan gates ${gated} and this checkout is at ${head.slice(0, 8)}; the test and bot lists are counted here, so check out the gated head first`,
    );
  const latest = new Map();
  for (const row of rows) latest.set(row.shard.toLowerCase(), row);
  for (const row of rows) {
    if (row.verdict === "") problems.push(`line ${row.line}: "${row.shard}" has an empty verdict`);
  }
  for (const row of latest.values()) {
    if (row.verdict === "") continue;
    if (!hasReceipt(row.verdict))
      problems.push(`line ${row.line}: "${row.shard}" names no receipt`);
    if (wave && isDeferred(row.verdict) && isReleaseShard(row.shard, botCount)) continue;
    if (!isPass(row.verdict))
      problems.push(
        `line ${row.line}: "${row.shard}" does not open with PASS (CLEAR for the red team) in its newest row; fix the red or carry it on the ledger, then add a new row`,
      );
  }
  for (const name of wave ? [SCOPED_SHARD] : expectedShards(botCount)) {
    if (
      ![...latest.keys()].some(
        (key) => key === name.toLowerCase() || key.startsWith(name.toLowerCase() + " "),
      )
    )
      problems.push(`no row for "${name}"`);
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
  if (next <= testCount)
    problems.push(
      windows.length === 0
        ? 'no "tests FIRST-LAST" row'
        : `non-bot tests ${next} to ${testCount} have no row`,
    );
  problems.push(...checkWeeklySweep(rows, { weeklyCount, today }));
  return problems;
}

async function main() {
  const argv = process.argv.slice(2);
  const planAt = argv.indexOf("--plan");
  if (planAt < 0 || !argv[planAt + 1])
    throw new Error("usage: node scripts/gate/tally.mjs [--wave] --plan <gate plan.md>");
  const lists = gateLists(path.join(root, "sketches", "core-loop"));
  const text = readFileSync(argv[planAt + 1], "utf8");
  const rows = tallyRows(text);
  const gated = planHead(argv[planAt + 1]);
  const head =
    spawnSync("git", ["-C", root, "rev-parse", "HEAD"], { encoding: "utf8" }).stdout.trim() || null;
  if (!gated)
    console.log(
      "NOTE the plan's file name is not w<N>-<head>-gate-plan.md, so the head it gates was not checked against this checkout",
    );
  const weekly = lists.weekly.tests.length + lists.weekly.bots.length;
  const scope = argv.includes("--wave") ? "wave" : "release";
  const problems = checkTally(rows, {
    testCount: lists.tests.length,
    botCount: lists.bots.length,
    planHead: gated,
    head,
    weeklyCount: weekly,
    scope,
  });
  problems.push(...checkNodeRow(text));
  console.log(
    scope === "wave"
      ? `wave gate (ruling cy): every non-bot test and the "${SCOPED_SHARD}" row; bot blocks, bands and the red team wait for the release gate`
      : "release gate: every shard, nothing deferred",
  );
  const notRun = new Set([...lists.weekly.tests, ...lists.weekly.bots]);
  const ledger = (await checkLedger(root, { promotion: true, notRun, requireChecks: true })).filter(
    (finding) => finding.level === "failure",
  );
  for (const finding of ledger) problems.push(`ledger line ${finding.line}: ${finding.message}`);
  for (const problem of problems) console.log("PROBLEM " + problem);
  if (weekly > 0)
    console.log(
      `weekly: ${weekly} tests not run this promotion (${WEEKLY_FILE}, ruling ca); they run on a change to their files and in the weekly sweep, which the "${WEEKLY_SHARD}" row dates`,
    );
  console.log(
    `gate tally: ${rows.length} rows, ${lists.tests.length} non-bot tests, ${lists.bots.length} bot tests. ${problems.length === 0 ? "Every row is filled; CLEAN may be written" : `Not clean: ${problems.length} problem${problems.length === 1 ? "" : "s"}`}.`,
  );
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
