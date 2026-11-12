// The card runner: one BACKLOG card at a time, unattended, inside a hard
// wall-clock and dollar budget per card. Proof of concept, dry run only.
//
//   node scripts/card-runner.mjs --cards W1-07,W1-08
//   node scripts/card-runner.mjs --section "World 1 now: ready to build" --limit 2
//   node scripts/card-runner.mjs --cards W1-07 --json
//
// It reads the card from BACKLOG.md (the one definition, ruling bz), decides
// whether an unattended run may take it, and prints the exact plan it would
// execute: a worktree on its own branch from the open stage, one headless
// `claude -p` writer capped by `timeout` and `--max-budget-usd`, then the
// runner's own fast lane, and a push plus draft pull request only when the
// lane is green. The runner never stacks: the Gate thread alone stacks onto
// the stage (ruling dh). There is no --run yet; executing the plan on the PC
// waits for Andrew's go-ahead.

import { readFileSync, realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";

export const BACKLOG_FILE = "BACKLOG.md";
export const STATE_FILE = "project-guide/handoff/STATE.md";

// Budget per card size. A card that needs more is not an unattended card.
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

export function writerPrompt(card, stage) {
  return [
    `Build Scrapkeep card ${card.id} from BACKLOG.md ("${card.section}") on this branch, which starts at origin/${stage}.`,
    `What the player gets: ${card["what the player gets"] ?? card.what ?? ""}`,
    `Files: ${card.files}`,
    `Proof: ${card.proof}`,
    `Source: ${card.source}`,
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
          `--max-budget-usd ${budget.usd} --permission-mode acceptEdits --output-format json > ${receipt}`,
      },
      { step: "gate", run: `cd ${worktree} && npm run sketch:fast -- --base origin/${stage} --budget 600` },
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

export function plan({ backlog, state, ids, section, limit }) {
  const stage = openStage(state);
  const board = liveBoard(state);
  const cards = selectCards(parseCards(backlog), { ids, section, limit });
  return {
    stage,
    board,
    cards: cards.map((card) => {
      if (card.missing) return { id: card.id, skip: "no such card in BACKLOG.md" };
      const why = refusal(card);
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

function parseArgs(argv) {
  const options = { json: false };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--cards") options.ids = argv[++index].split(",").map((id) => id.trim());
    else if (arg === "--section") options.section = argv[++index];
    else if (arg === "--limit") options.limit = Number(argv[++index]);
    else if (arg === "--json") options.json = true;
    else if (arg === "--run") throw new Error("--run is not built: executing cards on the PC waits for Andrew's go-ahead");
    else throw new Error(`unknown option ${arg}`);
  }
  if (!options.ids && !options.section) throw new Error("name --cards or --section");
  return options;
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const result = plan({
    backlog: readFileSync(BACKLOG_FILE, "utf8"),
    state: readFileSync(STATE_FILE, "utf8"),
    ...options,
  });
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
