import assert from "node:assert/strict";
import { test } from "node:test";

import { BUDGETS, liveBoard, openStage, parseCards, plan, refusal, reviewPrompt, reviewVerdict, takenIds } from "./card-runner.mjs";

const BACKLOG = `# Backlog

### World 1 now: ready to build

| ID | What the player gets | Files | Size | Proof | Source |
| --- | --- | --- | --- | --- | --- |
| W1-01 | Scale on | \`tuning.gd\` | S | tuning test | ruling dd. Built 12 Nov on branch \`x\` |
| W1-07 | Pop-ups wait | toast queue | S | prologue test | PF-19 |
| W1-14 | Camera | camera rig | M | PC film of Brindle; feel goes on the sitting watch list | PF-06 |
| W1-19 | Quit under swipe | PC lane run only | S | one rendered quit | SA-F |
| W1-30 | Big | many | L | bands | x |
| W1-65 | Lessons | lock_rows.gd | S | 24-seed w1 band read; lock ring tests. After PR 845 | y |

### Elsewhere

| ID | What the player gets | Files | Size | Proof | Source |
| --- | --- | --- | --- | --- | --- |
| SC-01 | Flag | a.gd | M | hash | y |
`;

const STATE = `| Open stage | stage/alpha-w39 |\n| Live board | #848 |\n`;

test("parses card rows under their section with header keys", () => {
  const cards = parseCards(BACKLOG);
  assert.deepEqual(cards.map((card) => card.id), ["W1-01", "W1-07", "W1-14", "W1-19", "W1-30", "W1-65", "SC-01"]);
  assert.equal(cards[1].section, "World 1 now: ready to build");
  assert.equal(cards[1]["what the player gets"], "Pop-ups wait");
  assert.equal(cards[6].section, "Elsewhere");
});

test("refuses built, PC-only, feel-proof and oversize cards", () => {
  const byId = Object.fromEntries(parseCards(BACKLOG).map((card) => [card.id, card]));
  assert.match(refusal(byId["W1-01"]), /already built/);
  assert.equal(refusal(byId["W1-07"]), null);
  assert.match(refusal(byId["W1-14"]), /PC still or film/);
  assert.match(refusal(byId["W1-19"]), /PC lane run/);
  assert.match(refusal(byId["W1-30"]), /no unattended budget/);
  assert.match(refusal(byId["W1-65"]), /24-seed band read/);
});

test("reads the open stage and board from STATE.md", () => {
  assert.equal(openStage(STATE), "stage/alpha-w39");
  assert.equal(liveBoard(STATE), 848);
});

test("plans a capped writer, the fast lane, and a push only when green", () => {
  const result = plan({ backlog: BACKLOG, state: STATE, ids: ["W1-07", "NOPE-1"] });
  const [card, missing] = result.cards;
  assert.equal(missing.skip, "no such card in BACKLOG.md");
  assert.deepEqual(card.budget, BUDGETS.S);
  const steps = Object.fromEntries(card.steps.map(({ step, run }) => [step, run]));
  assert.match(steps.base, /git worktree add -b card\/w1-07 .* origin\/stage\/alpha-w39/);
  assert.match(steps.write, /timeout -k 60 30m claude -p /);
  assert.match(steps.write, /--max-budget-usd 4 /);
  assert.match(steps.gate, /sketch:fast -- --base origin\/stage\/alpha-w39 --budget 600/);
  assert.match(steps["land if green"], /draft PR/);
  assert.doesNotMatch(JSON.stringify(card), /stack/i);
});

test("section selection keeps order and honours the limit", () => {
  const result = plan({ backlog: BACKLOG, state: STATE, section: "World 1 now: ready to build", limit: 2 });
  assert.deepEqual(result.cards.map((card) => card.id), ["W1-01", "W1-07"]);
});

test("cards named in pull requests or board comments are skipped", () => {
  const taken = takenIds("CLAIM W1-07 (#858) on branch x; PR 851 built W1-08");
  assert.deepEqual([...taken].sort(), ["W1-07", "W1-08"]);
  const result = plan({ backlog: BACKLOG, state: STATE, ids: ["W1-07"], taken });
  assert.equal(result.cards[0].skip, "already claimed or in a pull request");
});

test("the review must end on a PASS line to land", () => {
  assert.equal(reviewVerdict("fine\nVERDICT: PASS"), "PASS");
  assert.equal(reviewVerdict("VERDICT: PASS\nbut one more thing"), "NONE");
  assert.equal(reviewVerdict("blocking: x.gd:3\nVERDICT: FAIL\n"), "FAIL");
  const card = parseCards(BACKLOG).find((row) => row.id === "W1-07");
  assert.match(reviewPrompt(card, "diff --git a b"), /Files: toast queue[\s\S]*diff --git a b$/);
});
