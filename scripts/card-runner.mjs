// The card runner: one BACKLOG card at a time, unattended, inside a hard
// wall-clock and dollar budget per card.
//
//   node scripts/card-runner.mjs --cards W1-77,SG-04             dry run: print the plan
//   node scripts/card-runner.mjs --section "World 1 now: ready to build" --limit 2
//   node scripts/card-runner.mjs --cards W1-77 --taken taken.txt  skip ids named in that text
//   node scripts/card-runner.mjs --cards W1-77,SG-04 --run        build them
//
// It reads each card from BACKLOG.md (the one definition, ruling bz) and
// decides whether an unattended run may take it. --taken names a file of
// text (open pull requests, board comments) whose card ids are already
// claimed. With --run, per card: a worktree on its own branch from the open
// stage, one headless writer (`claude -p --agent scrapkeep-writer`) under
// `timeout` and `--max-budget-usd`, the fast lane, one independent review
// (`--agent scrapkeep-reviewer-medium`), and a push only when the lane is
// green and the review passes. The claim, the draft pull request and the
// READY comment are left to the caller, which owns the board. The runner
// never stacks: the Gate thread alone stacks onto the stage (ruling dh).
// `--max-budget-usd` is checked between turns, so a writer can overshoot it;
// the runner stops the queue once the spend recorded passes --max-total-usd.

import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const BACKLOG_FILE = "BACKLOG.md";
export const STATE_FILE = "project-guide/handoff/STATE.md";

// Budget per card size. A card that needs more is not an unattended card.
export const REVIEW_USD = 2;
export const BUDGETS = {
  S: { minutes: 30, usd: 4 },
  M: { minutes: 60, usd: 10 },
};

const ROW_ID = /^[A-Z][A-Z0-9]*-[0-9]+[a-z]?$/;

function cells(line) {
  return line
    .replace(/^\s*\|/, "")
    .replace(/\|\s*$/, "")
    .split(/(?<!\\)\|/)
    .map((cell) => cell.trim());
}

// Every card table in BACKLOG.md: rows whose first cell is a card id, under
// the nearest ### heading, keyed by the table's own header names.
export function parseCards(text) {
  const cards = [];
  let section = "";
  let header = null;
  for (const line of text.split("\n")) {
    if (line.startsWith("### ")) {
      section = line.slice(4).trim();
      header = null;
      continue;
    }
    if (!line.trim().startsWith("|")) {
      header = null;
      continue;
    }
    const row = cells(line);
    if (row.every((cell) => /^:?-+:?$/.test(cell))) continue;
    if (!header) {
      header = row.map((name) => name.toLowerCase());
      continue;
    }
    if (!ROW_ID.test(row[0])) continue;
    const card = { id: row[0], section };
    header.forEach((name, index) => {
      if (index > 0) card[name] = row[index] ?? "";
    });
    cards.push(card);
  }
  return cards;
}

// Why an unattended run may not take this card, or null when it may.
export function refusal(card) {
  const files = card.files ?? "";
  const source = card.source ?? "";
  if (/\bBuilt\b/.test(source)) return "already built on a branch (see its Source)";
  if (/PC lane run only/i.test(files)) return "PC lane run: GPU timing or a rendered build, not a writer card";
  if (/\bPC (still|film)\b/i.test(card.proof ?? "")) return "proof needs a PC still or film; the Gate's PC session owns that";
  if (/sitting watch list|feel/i.test(card.proof ?? "")) return "proof is a feel call for Andrew, not a check";
  if (!BUDGETS[card.size]) return `size ${card.size || "unknown"} has no unattended budget (S and M only)`;
  if (/24-seed|band read/i.test(card.proof ?? "") && !/unchanged/i.test(card.proof ?? "")) return "proof is a 24-seed band read; that belongs to the wave gate";
  if (/\bAfter PR \d+/i.test(card.proof ?? "")) return "waits on another pull request";
  if (/^owned/i.test(card.section) || /owned by another thread/i.test(card.section)) return "owned by another thread";
  return null;
}

export function openStage(stateText) {
  const match = stateText.match(/\|\s*Open stage\s*\|\s*(stage\/alpha-w\d+)\s*\|/);
  return match ? match[1] : null;
}

export function liveBoard(stateText) {
  const match = stateText.match(/\|\s*Live board\s*\|\s*#(\d+)\s*\|/);
  return match ? Number(match[1]) : null;
}

// Card ids named anywhere in this text: pull request titles and bodies, board
// comments. A named card is claimed or built, so the runner leaves it alone.
export function takenIds(text) {
  return new Set(String(text).match(/\b[A-Z][A-Z0-9]*-[0-9]+[a-z]?\b/g) ?? []);
}

function cardLines(card) {
  return Object.entries(card)
    .filter(([key]) => !["id", "section"].includes(key))
    .map(([key, value]) => `${key[0].toUpperCase()}${key.slice(1)}: ${value}`);
}

export function writerPrompt(card, stage) {
  return [
    `Build Scrapkeep card ${card.id} from BACKLOG.md ("${card.section}") on this branch, which starts at origin/${stage}.`,
    ...cardLines(card),
    "Read AGENTS.md and the card's sources first. Touch only the named files and their tests.",
    "Record each taste call as a one-line assumption in the commit message.",
    "Run the focused tests the Proof names. Commit on this branch. Do not push, open a pull request or edit any other branch.",
    "Finish with a short receipt: what changed, the tests you ran and their result.",
  ].join("\n");
}

function shellQuote(text) {
  return `'${String(text).replace(/'/g, `'\\''`)}'`;
}

// The exact steps one card would take. Nothing here runs.
export function planCard(card, { stage, board }) {
  const budget = BUDGETS[card.size];
  const slug = card.id.toLowerCase();
  const branch = `card/${slug}`;
  const worktree = `../scrapkeep-cards/${slug}`;
  const receipt = `artifacts/local/card-runner/${slug}.json`;
  return {
    id: card.id,
    branch,
    worktree,
    budget,
    steps: [
      { step: "free", run: `skip unless no open pull request, branch or board #${board} claim names ${card.id}` },
      { step: "base", run: `git fetch origin ${stage} && git worktree add -b ${branch} ${worktree} origin/${stage}` },
      { step: "claim", run: `post one CLAIM comment on board #${board}: ${card.id}, ${branch}, base origin/${stage}, files ${card.files}` },
      {
        step: "write",
        run:
          `cd ${worktree} && timeout -k 60 ${budget.minutes}m claude -p ${shellQuote(writerPrompt(card, stage))} ` +
          `--agent scrapkeep-writer --permission-mode auto --disallowedTools 'Bash(git push:*)' --max-budget-usd ${budget.usd} --output-format json`,
      },
      { step: "gate", run: `cd ${worktree} && npm run sketch:fast -- --base origin/${stage} --budget 600` },
      { step: "review", run: `claude -p <card + diff> --agent scrapkeep-reviewer-medium --max-budget-usd ${REVIEW_USD}; the last line is VERDICT: PASS or FAIL` },
      { step: "land if green", run: `git -C ${worktree} push -u origin ${branch}; open a draft PR against ${stage}; post READY on board #${board} with the receipt` },
      { step: "stop if red", run: `keep ${branch} local, write the red and the budget spent to ${receipt}, take the next card` },
    ],
  };
}

export function selectCards(cards, { ids, section, limit }) {
  let chosen = cards;
  if (ids?.length) chosen = ids.map((id) => cards.find((card) => card.id === id) ?? { id, missing: true });
  else if (section) chosen = cards.filter((card) => card.section === section);
  return limit ? chosen.slice(0, limit) : chosen;
}

export function plan({ backlog, state, ids, section, limit, taken = new Set() }) {
  const stage = openStage(state);
  const board = liveBoard(state);
  const cards = selectCards(parseCards(backlog), { ids, section, limit });
  return {
    stage,
    board,
    cards: cards.map((card) => {
      if (card.missing) return { id: card.id, skip: "no such card in BACKLOG.md" };
      const why = taken.has(card.id) ? "already claimed or in a pull request" : refusal(card);
      return why ? { id: card.id, skip: why } : planCard(card, { stage, board });
    }),
  };
}

export function render(result) {
  const lines = [`Dry run on ${result.stage} (board #${result.board}). Nothing was run.`, ""];
  for (const card of result.cards) {
    if (card.skip) {
      lines.push(`${card.id}: skipped, ${card.skip}`, "");
      continue;
    }
    lines.push(`${card.id}: ${card.budget.minutes} min, $${card.budget.usd} cap, branch ${card.branch}`);
    for (const { step, run } of card.steps) lines.push(`  ${step}: ${run.split("\n")[0]}${run.includes("\n") ? " ...'" : ""}`);
    lines.push("");
  }
  return lines.join("\n");
}

// ---- Live mode -------------------------------------------------------------

function sh(command, args, { cwd, timeoutMinutes, input } = {}) {
  const wrapped = timeoutMinutes ? ["timeout", ["-k", "60", `${timeoutMinutes}m`, command, ...args]] : [command, args];
  const result = spawnSync(wrapped[0], wrapped[1], { cwd, input, encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });
  return { status: result.status, stdout: result.stdout ?? "", stderr: result.stderr ?? "" };
}

function claudeJson(stdout) {
  try {
    const parsed = JSON.parse(stdout.trim().split("\n").pop());
    return { cost: Number(parsed.total_cost_usd) || 0, text: String(parsed.result ?? ""), error: Boolean(parsed.is_error) };
  } catch {
    return { cost: 0, text: stdout.slice(-2000), error: true };
  }
}

export function reviewVerdict(text) {
  const match = String(text).match(/VERDICT:\s*(PASS|FAIL)\s*$/i);
  return match ? match[1].toUpperCase() : "NONE";
}

export function reviewPrompt(card, diff) {
  return [
    `Review this diff for Scrapkeep card ${card.id} against the card. You cannot run anything; judge from the card and the diff.`,
    ...cardLines(card),
    "Check: it does what the card says and nothing else, the named files only, a test that would fail without the change, no player-facing words that break ruling cx, deep modules with small interfaces.",
    "List any blocking finding with its file and line. End with exactly one line: VERDICT: PASS or VERDICT: FAIL.",
    "",
    diff.length > 120000 ? `${diff.slice(0, 120000)}\n[diff cut at 120000 characters]` : diff,
  ].join("\n");
}

function runCard(card, planned, { stage, cardsRoot, receipts }) {
  const worktree = path.resolve(cardsRoot, card.id.toLowerCase());
  const receipt = { id: card.id, branch: planned.branch, worktree, budget: planned.budget, started: new Date().toISOString(), cost: 0, steps: [] };
  const note = (step, ok, detail) => receipt.steps.push({ step, ok, detail: String(detail).slice(-1500), at: new Date().toISOString() });
  const finish = (outcome) => {
    receipt.outcome = outcome;
    receipt.finished = new Date().toISOString();
    writeFileSync(path.join(receipts, `${card.id.toLowerCase()}.json`), `${JSON.stringify(receipt, null, 2)}\n`);
    return receipt;
  };

  sh("git", ["fetch", "-q", "origin", stage]);
  const base = sh("git", ["worktree", "add", "-q", "-b", planned.branch, worktree, `origin/${stage}`]);
  note("base", base.status === 0, base.stderr || sh("git", ["-C", worktree, "rev-parse", "HEAD"]).stdout.trim());
  if (base.status !== 0) return finish("stopped at base");
  const baseHead = sh("git", ["-C", worktree, "rev-parse", "HEAD"]).stdout.trim();

  const write = sh("claude", ["-p", writerPrompt(card, stage), "--agent", "scrapkeep-writer", "--permission-mode", "auto",
    "--disallowedTools", "Bash(git push:*)", "--max-budget-usd", String(planned.budget.usd), "--output-format", "json"],
  { cwd: worktree, timeoutMinutes: planned.budget.minutes });
  const writer = claudeJson(write.stdout);
  receipt.cost += writer.cost;
  receipt.writer = writer.text.slice(-3000);
  const head = sh("git", ["-C", worktree, "rev-parse", "HEAD"]).stdout.trim();
  note("write", write.status === 0 && head !== baseHead, `exit ${write.status}, $${writer.cost.toFixed(2)}, head ${head}`);
  if (head === baseHead) return finish(write.status === 124 ? "writer ran out of time with no commit" : "writer made no commit");
  receipt.head = head;

  sh("npm", ["ci", "--silent"], { cwd: worktree, timeoutMinutes: 10 });
  const gate = sh("npm", ["run", "sketch:fast", "--", "--base", `origin/${stage}`, "--budget", "600"], { cwd: worktree, timeoutMinutes: 40 });
  const gateLine = (gate.stdout + gate.stderr).split("\n").filter((line) => /^sketch:fast (pass|fail)/.test(line)).pop() ?? `exit ${gate.status}`;
  note("gate", gate.status === 0, gateLine);
  if (gate.status !== 0) return finish("fast lane red; branch kept local");

  const diff = sh("git", ["-C", worktree, "diff", `origin/${stage}...HEAD`]).stdout;
  const review = sh("claude", ["-p", reviewPrompt(card, diff), "--agent", "scrapkeep-reviewer-medium", "--max-budget-usd", String(REVIEW_USD), "--output-format", "json"],
    { cwd: worktree, timeoutMinutes: 20 });
  const reviewer = claudeJson(review.stdout);
  receipt.cost += reviewer.cost;
  receipt.review = reviewer.text.slice(-3000);
  const verdict = reviewVerdict(reviewer.text);
  note("review", verdict === "PASS", `${verdict}, $${reviewer.cost.toFixed(2)}`);
  if (verdict !== "PASS") return finish("review did not pass; branch kept local");

  const push = sh("git", ["-C", worktree, "push", "-q", "-u", "origin", planned.branch]);
  note("push", push.status === 0, push.stderr || planned.branch);
  return finish(push.status === 0 ? "pushed; caller opens the draft PR and posts READY" : "push failed");
}

export function runQueue(result, cards, { cardsRoot = "../scrapkeep-cards", maxTotalUsd = 20 } = {}) {
  const receipts = path.resolve("artifacts/local/card-runner");
  mkdirSync(receipts, { recursive: true });
  mkdirSync(cardsRoot, { recursive: true });
  let spent = 0;
  const done = [];
  for (const planned of result.cards) {
    if (planned.skip) continue;
    if (spent >= maxTotalUsd) {
      done.push({ id: planned.id, outcome: `not started: $${spent.toFixed(2)} spent of the $${maxTotalUsd} cap` });
      continue;
    }
    const receipt = runCard(cards.find((card) => card.id === planned.id), planned, { stage: result.stage, cardsRoot, receipts });
    spent += receipt.cost;
    done.push(receipt);
    process.stdout.write(`${receipt.id}: ${receipt.outcome} ($${receipt.cost.toFixed(2)})\n`);
  }
  return { spent, done };
}

function parseArgs(argv) {
  const options = { json: false };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--cards") options.ids = argv[++index].split(",").map((id) => id.trim());
    else if (arg === "--section") options.section = argv[++index];
    else if (arg === "--limit") options.limit = Number(argv[++index]);
    else if (arg === "--json") options.json = true;
    else if (arg === "--run") options.run = true;
    else if (arg === "--taken") options.taken = takenIds(readFileSync(argv[++index], "utf8"));
    else if (arg === "--max-total-usd") options.maxTotalUsd = Number(argv[++index]);
    else if (arg === "--cards-root") options.cardsRoot = argv[++index];
    else throw new Error(`unknown option ${arg}`);
  }
  if (!options.ids && !options.section) throw new Error("name --cards or --section");
  return options;
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const backlog = readFileSync(BACKLOG_FILE, "utf8");
  const result = plan({ backlog, state: readFileSync(STATE_FILE, "utf8"), ...options });
  if (options.run) {
    process.stdout.write(`${render(result).replace("Nothing was run.", "Running.")}\n`);
    const { spent } = runQueue(result, parseCards(backlog), options);
    process.stdout.write(`spent $${spent.toFixed(2)}; receipts in artifacts/local/card-runner/\n`);
    return;
  }
  process.stdout.write(options.json ? `${JSON.stringify(result, null, 2)}\n` : `${render(result)}\n`);
}

if (process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url))) {
  try {
    main();
  } catch (error) {
    process.stderr.write(`card-runner: ${error.message}\n`);
    process.exit(2);
  }
}
