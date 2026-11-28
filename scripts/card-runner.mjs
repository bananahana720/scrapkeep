import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

import { FACTS_HEADING, parseWaveFacts } from "./wave-state.mjs";
import { isMain } from "./lib/cli.mjs";

export const BACKLOG_FILE = "BACKLOG.md";
export const STATE_FILE = "project-guide/handoff/STATE.md";

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

function proofOf(card) {
  return Object.entries(card)
    .filter(([key]) => key.startsWith("proof"))
    .map(([, value]) => value)
    .join(" ");
}

export function refusal(card) {
  const files = card.files ?? "";
  const proof = proofOf(card);
  const everything = Object.values(card).join(" ");
  if (/\b(built|done|fenced?|board-owned|owned|board thread's|waits on Andrew)\b/i.test(everything))
    return "built, done, fenced or owned elsewhere (see its row)";
  if (/PC lane run only/i.test(files))
    return "PC lane run: GPU timing or a rendered build, not a writer card";
  if (/\b(stills?|films?|strips?|capture)\b/i.test(proof))
    return "proof needs a film or PC capture; the Gate's PC session owns that";
  if (/sitting watch list|feel|taste pick/i.test(proof))
    return "proof is a feel or taste call for Andrew, not a check";
  if (/24-seed|band read/i.test(proof))
    return "proof is a band read; that belongs to the wave gate";
  if (/\b(after|waits on|with) (PR \d+|[A-Z][A-Z0-9]*-\d+)/i.test(everything))
    return "waits on another pull request or card";
  if (!/\btests?\b|_test\b|check:docs|docs checks?/i.test(proof))
    return "proof names no test the runner can check";
  if (!BUDGETS[card.size])
    return `size ${card.size || "unknown"} has no unattended budget (S and M only)`;
  return null;
}

function readWaveFacts(stateText) {
  let parsed = parseWaveFacts(stateText);
  if (!parsed.found) parsed = parseWaveFacts(`${FACTS_HEADING}\n\n${stateText}`);
  return parsed.facts ?? {};
}

export function openStage(stateText) {
  const facts = readWaveFacts(stateText);
  if (facts.flatMain) return "main";
  return facts.stage !== undefined ? `stage/alpha-w${facts.stage}` : null;
}

export function liveBoard(stateText) {
  const facts = readWaveFacts(stateText);
  return facts.board ?? null;
}

export function takenIds(text) {
  return new Set(
    (String(text).match(/\b[A-Za-z][A-Za-z0-9]*-[0-9]+[a-z]?\b/g) ?? []).map((id) =>
      id.toUpperCase(),
    ),
  );
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

export function planCard(card, { stage, board }) {
  const targetStage = stage ?? "main";
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
      {
        step: "free",
        run:
          board == null
            ? `skip unless no open pull request or branch names ${card.id}`
            : `skip unless no open pull request, branch or board #${board} claim names ${card.id}`,
      },
      {
        step: "base",
        run: `git fetch origin ${targetStage} && git worktree add -b ${branch} ${worktree} origin/${targetStage}`,
      },
      ...(board == null
        ? []
        : [
            {
              step: "claim",
              run: `post one CLAIM comment on board #${board}: ${card.id}, ${branch}, base origin/${targetStage}, files ${card.files}`,
            },
          ]),
      {
        step: "write",
        run:
          `cd ${worktree} && timeout -k 60 ${budget.minutes}m claude -p ${shellQuote(writerPrompt(card, targetStage))} ` +
          `--agent scrapkeep-writer --permission-mode auto --disallowedTools 'Bash(git push:*)' 'Bash(gh:*)' --max-budget-usd ${budget.usd} --output-format json`,
      },
      {
        step: "gate",
        run: `cd ${worktree} && npm run sketch:fast -- --base origin/${targetStage} --budget 600`,
      },
      {
        step: "review",
        run: `claude -p <card + diff> --agent scrapkeep-reviewer-medium --max-budget-usd ${REVIEW_USD}; the last line is VERDICT: PASS or FAIL`,
      },
      {
        step: "land if green",
        run:
          board == null
            ? `git -C ${worktree} push -u origin ${branch}; open a draft PR against ${targetStage}`
            : `git -C ${worktree} push -u origin ${branch}; open a draft PR against ${targetStage}; post READY on board #${board} with the receipt`,
      },
      {
        step: "stop if red",
        run: `keep ${branch} local, write the red and the budget spent to ${receipt}, take the next card`,
      },
    ],
  };
}

export function selectCards(cards, { ids, section }) {
  if (ids?.length)
    return ids.map((id) => cards.find((card) => card.id === id) ?? { id, missing: true });
  return section ? cards.filter((card) => card.section === section) : cards;
}

export function plan({ backlog, state, ids, section, limit, taken = new Set() }) {
  const stage = openStage(state);
  const board = liveBoard(state);
  let runnable = 0;
  const planned = selectCards(parseCards(backlog), { ids, section }).map((card) => {
    if (card.missing) return { id: card.id, skip: "no such card in BACKLOG.md" };
    const why = taken.has(card.id.toUpperCase())
      ? "already claimed or in a pull request"
      : refusal(card);
    if (why) return { id: card.id, skip: why };
    runnable += 1;
    return limit && runnable > limit
      ? { id: card.id, skip: `past --limit ${limit}` }
      : planCard(card, { stage, board });
  });
  return { stage, board, cards: planned };
}

export function render(result) {
  const stageLabel = result.stage ?? "main";
  const boardLabel = result.board == null ? "no live board" : `board #${result.board}`;
  const lines = [`Dry run on ${stageLabel} (${boardLabel}). Nothing was run.`, ""];
  for (const card of result.cards) {
    if (card.skip) {
      lines.push(`${card.id}: skipped, ${card.skip}`, "");
      continue;
    }
    lines.push(
      `${card.id}: ${card.budget.minutes} min, $${card.budget.usd} cap, branch ${card.branch}`,
    );
    for (const { step, run } of card.steps)
      lines.push(`  ${step}: ${run.split("\n")[0]}${run.includes("\n") ? " ...'" : ""}`);
    lines.push("");
  }
  return lines.join("\n");
}

function sh(command, args, { cwd, timeoutMinutes, input } = {}) {
  const wrapped = timeoutMinutes
    ? ["timeout", ["-k", "60", `${timeoutMinutes}m`, command, ...args]]
    : [command, args];
  const result = spawnSync(wrapped[0], wrapped[1], {
    cwd,
    input,
    encoding: "utf8",
    maxBuffer: 256 * 1024 * 1024,
  });
  return { status: result.status, stdout: result.stdout ?? "", stderr: result.stderr ?? "" };
}

export function claudeJson(stdout, capUsd) {
  try {
    const parsed = JSON.parse(stdout.trim().split("\n").pop());
    const cost = Number(parsed.total_cost_usd);
    return {
      cost: Number.isFinite(cost) ? cost : capUsd,
      text: String(parsed.result ?? ""),
      error: Boolean(parsed.is_error),
    };
  } catch {
    return { cost: capUsd, text: stdout.slice(-2000), error: true };
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
  const receipt = {
    id: card.id,
    branch: planned.branch,
    worktree,
    budget: planned.budget,
    started: new Date().toISOString(),
    cost: 0,
    steps: [],
  };
  const note = (step, ok, detail) =>
    receipt.steps.push({
      step,
      ok,
      detail: String(detail).slice(-1500),
      at: new Date().toISOString(),
    });
  const finish = (outcome) => {
    receipt.outcome = outcome;
    receipt.finished = new Date().toISOString();
    writeFileSync(
      path.join(receipts, `${card.id.toLowerCase()}.json`),
      `${JSON.stringify(receipt, null, 2)}\n`,
    );
    return receipt;
  };

  const fetched = sh("git", ["fetch", "-q", "origin", stage], { timeoutMinutes: 5 });
  if (fetched.status !== 0) {
    note("base", false, `fetch failed: ${fetched.stderr}`);
    return finish("stopped: could not fetch the stage");
  }
  const base = sh("git", [
    "worktree",
    "add",
    "-q",
    "-b",
    planned.branch,
    worktree,
    `origin/${stage}`,
  ]);
  note(
    "base",
    base.status === 0,
    base.stderr || sh("git", ["-C", worktree, "rev-parse", "HEAD"]).stdout.trim(),
  );
  if (base.status !== 0) return finish("stopped at base");
  const baseHead = sh("git", ["-C", worktree, "rev-parse", "HEAD"]).stdout.trim();

  const write = sh(
    "claude",
    [
      "-p",
      writerPrompt(card, stage),
      "--agent",
      "scrapkeep-writer",
      "--permission-mode",
      "auto",
      "--disallowedTools",
      "Bash(git push:*)",
      "Bash(gh:*)",
      "--max-budget-usd",
      String(planned.budget.usd),
      "--output-format",
      "json",
    ],
    { cwd: worktree, timeoutMinutes: planned.budget.minutes },
  );
  const writer = claudeJson(write.stdout, planned.budget.usd);
  receipt.cost += writer.cost;
  receipt.writer = writer.text;
  const head = sh("git", ["-C", worktree, "rev-parse", "HEAD"]).stdout.trim();
  const onBranch =
    sh("git", ["-C", worktree, "branch", "--show-current"]).stdout.trim() === planned.branch;
  note(
    "write",
    write.status === 0 && head !== baseHead,
    `exit ${write.status}, $${writer.cost.toFixed(2)}, head ${head}`,
  );
  if (!onBranch) return finish("writer left its branch; nothing pushed");
  if (head === baseHead)
    return finish(
      write.status === 124 ? "writer ran out of time with no commit" : "writer made no commit",
    );
  receipt.head = head;

  sh("npm", ["ci", "--silent"], { cwd: worktree, timeoutMinutes: 10 });
  const gate = sh(
    "npm",
    ["run", "sketch:fast", "--", "--base", `origin/${stage}`, "--budget", "600"],
    { cwd: worktree, timeoutMinutes: 40 },
  );
  const gateLine =
    (gate.stdout + gate.stderr)
      .split("\n")
      .filter((line) => /^sketch:fast (pass|fail)/.test(line))
      .pop() ?? `exit ${gate.status}`;
  note("gate", gate.status === 0, gateLine);
  if (gate.status !== 0) return finish("fast lane red; branch kept local");

  const diff = sh("git", ["-C", worktree, "diff", `origin/${stage}...HEAD`]).stdout;
  const review = sh(
    "claude",
    [
      "-p",
      reviewPrompt(card, diff),
      "--agent",
      "scrapkeep-reviewer-medium",
      "--max-budget-usd",
      String(REVIEW_USD),
      "--output-format",
      "json",
    ],
    { cwd: worktree, timeoutMinutes: 20 },
  );
  const reviewer = claudeJson(review.stdout, REVIEW_USD);
  receipt.cost += reviewer.cost;
  receipt.review = reviewer.text;
  const verdict = reviewer.error ? "NONE" : reviewVerdict(reviewer.text);
  note("review", verdict === "PASS", `${verdict}, $${reviewer.cost.toFixed(2)}`);
  if (verdict !== "PASS") return finish("review did not pass; branch kept local");

  const push = sh(
    "git",
    ["-C", worktree, "push", "-q", "-u", "origin", `HEAD:refs/heads/${planned.branch}`],
    { timeoutMinutes: 5 },
  );
  note("push", push.status === 0, push.stderr || planned.branch);
  return finish(
    push.status === 0 ? "pushed; caller opens the draft PR and posts READY" : "push failed",
  );
}

export function runQueue(
  result,
  cards,
  { cardsRoot = "../scrapkeep-cards", maxTotalUsd = 20 } = {},
) {
  const receipts = path.resolve("artifacts/local/card-runner");
  mkdirSync(receipts, { recursive: true });
  mkdirSync(cardsRoot, { recursive: true });
  let spent = 0;
  const done = [];
  for (const planned of result.cards) {
    if (planned.skip) continue;
    if (spent >= maxTotalUsd) {
      done.push({
        id: planned.id,
        outcome: `not started: $${spent.toFixed(2)} spent of the $${maxTotalUsd} cap`,
      });
      continue;
    }
    const receipt = runCard(
      cards.find((card) => card.id === planned.id),
      planned,
      { stage: result.stage, cardsRoot, receipts },
    );
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
  if (options.limit !== undefined && !(Number.isInteger(options.limit) && options.limit > 0))
    throw new Error("--limit takes a positive whole number");
  if (options.maxTotalUsd !== undefined && !(options.maxTotalUsd > 0))
    throw new Error("--max-total-usd takes a positive number");
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
  process.stdout.write(
    options.json ? `${JSON.stringify(result, null, 2)}\n` : `${render(result)}\n`,
  );
}

if (isMain(import.meta.url)) {
  try {
    main();
  } catch (error) {
    process.stderr.write(`card-runner: ${error.message}\n`);
    process.exit(2);
  }
}
