// The wave facts in project-guide/handoff/STATE.md, checked against git.
//
// STATE.md carries one small "Wave facts" table: the last promotion, the open
// stage, the live board, the red team persona and the receipts to compare
// against. It is the only page that names the live board. Every other
// first-read page points at it, so one line moves when a wave turns over.
//
//   node scripts/wave-state.mjs --check
//   node scripts/wave-state.mjs --print
//   node scripts/wave-state.mjs --write --board 640 --compare gate/w33-1a2b3c4d/
//
// --check is also a stage of `npm run check:docs`. It fails when the table has
// fallen behind the newest promotion commit reachable from HEAD, or when a
// pointer page hard-codes a board number. --write is the Gate's first commit
// on a new stage.

import { readFile, writeFile } from "node:fs/promises";
import { realpathSync } from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

export const STATE_FILE = "project-guide/handoff/STATE.md";
export const FACTS_HEADING = "## Wave facts";
// Pages a new session reads before the board. None of them may name a board
// number: they say "STATE.md names it".
export const POINTER_FILES = [
  "AGENTS.md",
  "CLAUDE.md",
  "ORCHESTRATOR.md",
  "project-guide/handoff/START-HERE.md",
  "project-guide/handoff/README.md",
  "project-guide/handoff/ROADMAP.md",
  "project-guide/handoff/THREADS.md",
];
// scripts/redteam/lib.mjs owns the personas; this is the order the gate
// rotates them in, one per promotion.
export const RED_TEAM_ROTATION = [
  "greedy",
  "line-rider",
  "speedrunner",
  "first-timer",
  "cautious",
];

const PROMOTION_SUBJECT =
  /^Promote alpha wave (\d+) \(stage\/alpha-w\d+ ([0-9a-f]{7,40})\) to main \(#(\d+)\)/;
const BOARD_MENTIONS = [
  /\bboard(?: issue)?,? \(?#\d+/i,
  /#\d+ for wave \d+/i,
  /\bwatches on #\d+/i,
];

export function parsePromotionSubject(subject) {
  const match = PROMOTION_SUBJECT.exec(subject);
  if (!match) return null;
  return { wave: Number(match[1]), stageSha: match[2], pr: Number(match[3]) };
}

// `lines` are "<full hash>\t<subject>", newest first, as
// `git log --format=%H%x09%s` prints them.
export function lastPromotion(lines) {
  for (const line of lines) {
    const tab = line.indexOf("\t");
    if (tab < 0) continue;
    const promotion = parsePromotionSubject(line.slice(tab + 1));
    if (promotion) return { ...promotion, sha: line.slice(0, tab) };
  }
  return null;
}

function tableCells(line) {
  return line
    .trim()
    .replace(/^\|/, "")
    .replace(/\|$/, "")
    .split("|")
    .map((cell) => cell.trim());
}

// Returns { found, start, end, facts, problems }. `start` and `end` are the
// zero-based line span of the heading and its table, so --write can replace it.
export function parseWaveFacts(text) {
  const lines = text.split("\n");
  const start = lines.findIndex((line) => line.trim() === FACTS_HEADING);
  if (start < 0) return { found: false, facts: null, problems: [] };
  const rows = new Map();
  let end = start + 1;
  let inTable = false;
  for (; end < lines.length; end += 1) {
    const line = lines[end];
    if (line.trim().startsWith("|")) {
      inTable = true;
      const cells = tableCells(line);
      if (cells.length >= 2) rows.set(cells[0].toLowerCase(), cells[1]);
    } else if (inTable || line.startsWith("#")) break;
  }
  const problems = [];
  const facts = {};
  const need = (name) => {
    const value = rows.get(name);
    if (value === undefined) problems.push('the table has no "' + name + '" row');
    return value ?? "";
  };
  const promotion =
    /^wave (\d+), main ([0-9a-f]{7,40}), #(\d+)$/.exec(need("last promotion"));
  if (promotion) {
    facts.wave = Number(promotion[1]);
    facts.mainSha = promotion[2];
    facts.pr = Number(promotion[3]);
  } else if (rows.has("last promotion"))
    problems.push(
      '"Last promotion" must read "wave <N>, main <sha>, #<PR>", not "' +
        rows.get("last promotion") +
        '"',
    );
  const stage = /^stage\/alpha-w(\d+)$/.exec(need("open stage"));
  if (stage) facts.stage = Number(stage[1]);
  else if (rows.has("open stage"))
    problems.push('"Open stage" must read "stage/alpha-w<N>"');
  const board = /^#(\d+)$/.exec(need("live board"));
  if (board) facts.board = Number(board[1]);
  else if (rows.has("live board"))
    problems.push('"Live board" must be one issue number, such as "#633"');
  facts.redTeam = need("red team");
  if (rows.has("red team") && !RED_TEAM_ROTATION.includes(facts.redTeam))
    problems.push(
      '"Red team" must be one of ' + RED_TEAM_ROTATION.join(", "),
    );
  facts.compare = need("compare against");
  if (rows.has("compare against") && !facts.compare)
    problems.push('"Compare against" is empty');
  return { found: true, start, end, facts, problems };
}

const sameSha = (a, b) => a.startsWith(b) || b.startsWith(a);
const fixCommand =
  "node scripts/wave-state.mjs --write --board <new board issue> --compare <receipts folder>";

// `promotion` is lastPromotion()'s result, or null when history holds none.
// `headIsPromotion`: HEAD is that promotion commit itself, which is true of
// main after every promotion and of a new stage before its first commit. The
// promoted tree cannot name its own merge commit, so one wave behind passes
// there. `isAncestor(sha)` answers whether a commit is reachable from HEAD.
export function compareWithGit(facts, promotion, options = {}) {
  const problems = [];
  if (facts.wave === undefined) return problems;
  if (facts.stage !== undefined && facts.stage !== facts.wave + 1)
    problems.push(
      "Open stage is stage/alpha-w" +
        facts.stage +
        " but the last promotion is wave " +
        facts.wave +
        "; the open stage is always one wave ahead",
    );
  if (!promotion) return problems;
  const behind =
    "the Wave facts table says wave " +
    facts.wave +
    " but history holds the wave " +
    promotion.wave +
    " promotion (" +
    promotion.sha.slice(0, 8) +
    ", #" +
    promotion.pr +
    "). Run: " +
    fixCommand;
  if (facts.wave < promotion.wave) {
    const oneBehindAtPromotion =
      options.headIsPromotion && facts.wave === promotion.wave - 1;
    if (!oneBehindAtPromotion) problems.push(behind);
    return problems;
  }
  if (facts.wave === promotion.wave) {
    if (!sameSha(promotion.sha, facts.mainSha))
      problems.push(
        "Last promotion names main " +
          facts.mainSha +
          " but the wave " +
          promotion.wave +
          " promotion commit is " +
          promotion.sha.slice(0, 8),
      );
    if (facts.pr !== promotion.pr)
      problems.push(
        "Last promotion names #" +
          facts.pr +
          " but the wave " +
          promotion.wave +
          " promotion was #" +
          promotion.pr,
      );
    return problems;
  }
  // The table is ahead of the newest "Promote alpha wave" subject: a promotion
  // merged under another subject. Accept it only if its commit is in history.
  if (options.isAncestor && !options.isAncestor(facts.mainSha))
    problems.push(
      "Last promotion names main " +
        facts.mainSha +
        " for wave " +
        facts.wave +
        ", which is not a commit in this history",
    );
  return problems;
}

// Lines of a pointer page that hard-code a board. `board` is the live board
// number; any mention of it counts, and so does any "board #N" wording.
export function hardCodedBoards(text, board) {
  const hits = [];
  const live = board === undefined ? null : new RegExp("#" + board + "(?!\\d)");
  let fenced = false;
  for (const [index, line] of text.split("\n").entries()) {
    if (/^\s*(```|~~~)/.test(line)) {
      fenced = !fenced;
      continue;
    }
    if (fenced) continue;
    if (live?.test(line) || BOARD_MENTIONS.some((pattern) => pattern.test(line)))
      hits.push({ line: index + 1, text: line.trim() });
  }
  return hits;
}

export function nextRedTeam(current) {
  const index = RED_TEAM_ROTATION.indexOf(current);
  return RED_TEAM_ROTATION[(index + 1) % RED_TEAM_ROTATION.length];
}

export function renderWaveFacts(facts) {
  return [
    FACTS_HEADING,
    "",
    "| Fact | Value |",
    "| --- | --- |",
    "| Last promotion | wave " +
      facts.wave +
      ", main " +
      facts.mainSha.slice(0, 8) +
      ", #" +
      facts.pr +
      " |",
    "| Open stage | stage/alpha-w" + facts.stage + " |",
    "| Live board | #" + facts.board + " |",
    "| Red team | " + facts.redTeam + " |",
    "| Compare against | " + facts.compare + " |",
  ].join("\n");
}

export function replaceWaveFacts(text, facts) {
  const parsed = parseWaveFacts(text);
  if (!parsed.found)
    throw new Error(STATE_FILE + ' has no "' + FACTS_HEADING + '" section');
  const lines = text.split("\n");
  lines.splice(
    parsed.start,
    parsed.end - parsed.start,
    ...renderWaveFacts(facts).split("\n"),
  );
  return lines.join("\n");
}

function git(root, args) {
  const result = spawnSync("git", ["-C", root, ...args], { encoding: "utf8" });
  return result.status === 0 ? result.stdout.trim() : null;
}

// Null when `root` is not the top of a git checkout (a test fixture, an
// exported tree): the caller then reports the facts as unverified.
export function readGit(root) {
  const top = git(root, ["rev-parse", "--show-toplevel"]);
  if (top === null) return null;
  try {
    if (realpathSync(top) !== realpathSync(root)) return null;
  } catch {
    return null;
  }
  const head = git(root, ["rev-parse", "HEAD"]);
  const log = git(root, [
    "log",
    "--extended-regexp",
    "--grep=^Promote alpha wave [0-9]+ ",
    "-n",
    "5",
    "--format=%H%x09%s",
    "HEAD",
  ]);
  if (head === null || log === null) return null;
  const promotion = lastPromotion(log.split("\n"));
  return {
    head,
    promotion,
    headIsPromotion: promotion !== null && promotion.sha === head,
    isAncestor: (sha) =>
      spawnSync("git", ["-C", root, "merge-base", "--is-ancestor", sha, "HEAD"])
        .status === 0,
  };
}

// The whole check. Returns findings as { level, file, line, message }.
export async function checkWaveState(root) {
  const findings = [];
  const add = (level, file, line, message) =>
    findings.push({ level, file, line, message });
  let text;
  try {
    text = await readFile(path.join(root, STATE_FILE), "utf8");
  } catch {
    return findings; // no handoff folder under this root: nothing to check
  }
  const parsed = parseWaveFacts(text);
  if (!parsed.found) {
    add(
      "failure",
      STATE_FILE,
      0,
      'has no "' + FACTS_HEADING + '" table; the table is the one place that names the live board',
    );
    return findings;
  }
  const line = parsed.start + 1;
  for (const problem of parsed.problems) add("failure", STATE_FILE, line, problem);
  const repo = readGit(root);
  if (!repo)
    add("info", STATE_FILE, line, "not a git checkout, so the wave facts were not compared with history");
  else if (!repo.promotion)
    add("info", STATE_FILE, line, "no promotion commit is reachable from HEAD (shallow clone?), so the wave facts were not compared with history");
  for (const problem of compareWithGit(parsed.facts, repo?.promotion ?? null, repo ?? {}))
    add("failure", STATE_FILE, line, problem);

  const outside = text.split("\n");
  outside.splice(parsed.start, parsed.end - parsed.start);
  for (const hit of hardCodedBoards(outside.join("\n"), parsed.facts.board))
    add(
      "failure",
      STATE_FILE,
      0,
      'names a board outside the Wave facts table ("' + hit.text.slice(0, 80) + '"); say "the wave board" instead',
    );
  for (const file of POINTER_FILES) {
    let page;
    try {
      page = await readFile(path.join(root, file), "utf8");
    } catch {
      continue;
    }
    for (const hit of hardCodedBoards(page, parsed.facts.board))
      add(
        "failure",
        file,
        hit.line,
        "hard-codes a board number; point at the Wave facts table in " + STATE_FILE + " instead",
      );
  }
  return findings;
}

function parseArguments(argv) {
  const options = { mode: null, root: process.cwd() };
  const value = (index, flag) => {
    if (argv[index + 1] === undefined) throw new Error(flag + " needs a value");
    return argv[index + 1];
  };
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    if (flag === "--check" || flag === "--print" || flag === "--write")
      options.mode = flag.slice(2);
    else if (flag === "--root") options.root = path.resolve(value(index++, flag));
    else if (flag === "--board") options.board = value(index++, flag);
    else if (flag === "--red-team") options.redTeam = value(index++, flag);
    else if (flag === "--compare") options.compare = value(index++, flag);
    else throw new Error("unknown argument " + flag);
  }
  if (!options.mode) throw new Error("say one of --check, --print or --write");
  return options;
}

async function write(options) {
  const file = path.join(options.root, STATE_FILE);
  const text = await readFile(file, "utf8");
  const parsed = parseWaveFacts(text);
  if (!parsed.found) throw new Error(STATE_FILE + " has no Wave facts table");
  const repo = readGit(options.root);
  if (!repo?.promotion)
    throw new Error("no promotion commit is reachable from HEAD; fetch more history first");
  const old = parsed.facts;
  const advanced = old.wave !== repo.promotion.wave;
  const board = /^#?(\d+)$/.exec(options.board ?? "");
  if (advanced && !board) throw new Error("a new wave needs --board <issue number>");
  if (advanced && !options.compare)
    throw new Error("a new wave needs --compare <receipts folder of the promoted gate>");
  if (options.redTeam && !RED_TEAM_ROTATION.includes(options.redTeam))
    throw new Error("--red-team must be one of " + RED_TEAM_ROTATION.join(", "));
  const facts = {
    wave: repo.promotion.wave,
    mainSha: repo.promotion.sha,
    pr: repo.promotion.pr,
    stage: repo.promotion.wave + 1,
    board: board ? Number(board[1]) : old.board,
    redTeam: options.redTeam ?? (advanced ? nextRedTeam(old.redTeam) : old.redTeam),
    compare: options.compare ?? old.compare,
  };
  await writeFile(file, replaceWaveFacts(text, facts));
  console.log(renderWaveFacts(facts));
  console.log("\nWrote " + STATE_FILE + ". The prose under the table is still yours to update.");
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.mode === "write") return write(options);
  if (options.mode === "print") {
    const text = await readFile(path.join(options.root, STATE_FILE), "utf8");
    const parsed = parseWaveFacts(text);
    if (!parsed.found || parsed.problems.length)
      throw new Error(["the Wave facts table does not parse", ...parsed.problems].join("; "));
    console.log(JSON.stringify(parsed.facts, null, 2));
    return;
  }
  const findings = await checkWaveState(options.root);
  for (const finding of findings)
    console.log(
      finding.level.toUpperCase() + " wave-state " + finding.file + ":" + finding.line + " " + finding.message,
    );
  const failures = findings.filter((finding) => finding.level === "failure");
  console.log("wave-state " + (failures.length ? "fail" : "pass") + ": " + failures.length + " failures.");
  process.exitCode = failures.length ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    await main();
  } catch (error) {
    console.error("wave-state: " + (error?.message ?? error));
    process.exitCode = 2;
  }
}
