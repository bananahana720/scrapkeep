import assert from "node:assert/strict";
import { test } from "node:test";

import {
  BUDGETS,
  claudeJson,
  failureText,
  liveBoard,
  openStage,
  parseCards,
  plan,
  refusal,
  render,
  reviewPrompt,
  reviewVerdict,
  takenIds,
} from "./card-runner.mjs";

test("a failed git step keeps the error's message when stderr is empty, blank or a buffer", () => {
  assert.equal(
    failureText({ stderr: Buffer.alloc(0), message: "git fetch failed" }),
    "git fetch failed",
  );
  assert.equal(failureText({ stderr: "", message: "git fetch failed" }), "git fetch failed");
  assert.equal(failureText({ stderr: "\n", message: "git fetch failed" }), "git fetch failed");
  assert.equal(failureText({ message: "spawn git ENOENT" }), "spawn git ENOENT");
  assert.equal(failureText({ stderr: "fatal: no remote\n", message: "m" }), "fatal: no remote");
  assert.equal(
    failureText({ stderr: Buffer.from("fatal: in a buffer\n"), message: "m" }),
    "fatal: in a buffer",
  );
});

const BACKLOG = `# Backlog

### World 1 now: ready to build

| ID | What the player gets | Files | Size | Proof | Source |
| --- | --- | --- | --- | --- | --- |
| W1-01 | Scale on | \`tuning.gd\` | S | tuning test | ruling dd. Built 12 Nov on branch \`x\` |
| W1-07 | Pop-ups wait | toast queue | S | prologue test | PF-19 |
| W1-14 | Camera | camera rig | M | PC film of Brindle; feel goes on the sitting watch list | PF-06 |
| W1-19 | Quit under swipe | PC lane run only | S | one rendered quit | SA-F |
| W1-30 | Big | many | L | a pin test | x |
| W1-65 | Lessons | lock_rows.gd | S | 24-seed w1 band read; lock ring tests. After PR 845 | y |
| W1-13 | Cone | material | S | PC stills against the washout | PF-07 |
| W1-62 | Break pays | gates.gd | S | gate test; band read unchanged for the Novice | z |
| FX-05 | Path | fx.gd | S | fx test | Build after W1-05 lands |
| FX-09 | Boss | boss.gd (board-owned) | S | test | not built here |

### Elsewhere

| ID | What it does | Files | Size | Proof that world 1 is unchanged | Notes |
| --- | --- | --- | --- | --- | --- |
| SC-01 | Flag | a.gd | M | the same hash; schema test | y |
| SC-04 | Label | b.tsv | S | check:docs | done with this section |
| SC-05 | Notch | c.gd | S | a still of the notch | |
| SC-06 | Hook | d.gd | S | a probe | |
| SC-02 | Move | b.gd | S | a film still of the dam | Built 12 Nov |
| SC-03 | Move | c.gd | S | a film still of the dam | |
`;

const STATE = `| Open stage | stage/alpha-w39 |\n| Live board | #848 |\n`;

test("parses card rows under their section with header keys", () => {
  const cards = parseCards(BACKLOG);
  assert.deepEqual(
    cards.map((card) => card.id),
    [
      "W1-01",
      "W1-07",
      "W1-14",
      "W1-19",
      "W1-30",
      "W1-65",
      "W1-13",
      "W1-62",
      "FX-05",
      "FX-09",
      "SC-01",
      "SC-04",
      "SC-05",
      "SC-06",
      "SC-02",
      "SC-03",
    ],
  );
  assert.equal(cards[1].section, "World 1 now: ready to build");
  assert.equal(cards[1]["what the player gets"], "Pop-ups wait");
  assert.equal(cards[10].section, "Elsewhere");
});

test("refuses built, PC-only, feel-proof and oversize cards", () => {
  const byId = Object.fromEntries(parseCards(BACKLOG).map((card) => [card.id, card]));
  assert.match(refusal(byId["W1-01"]), /built/);
  assert.equal(refusal(byId["W1-07"]), null);
  assert.match(refusal(byId["W1-14"]), /film or PC capture/);
  assert.match(refusal(byId["W1-19"]), /PC lane run/);
  assert.match(refusal(byId["W1-30"]), /no unattended budget/);
  assert.match(refusal(byId["W1-65"]), /band read/);
  assert.match(refusal(byId["W1-13"]), /film or PC capture/);
  assert.match(refusal(byId["W1-62"]), /band read/);
  assert.match(refusal(byId["FX-05"]), /waits on another/);
  assert.match(refusal(byId["FX-09"]), /owned/);
  assert.match(refusal(byId["SC-02"]), /built/);
  assert.match(refusal(byId["SC-03"]), /film/);
  assert.equal(refusal(byId["SC-01"]), null);
  assert.match(refusal(byId["SC-04"]), /done/);
  assert.match(refusal(byId["SC-05"]), /film or PC capture/);
  assert.match(refusal(byId["SC-06"]), /names no test/);
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

test("the limit counts runnable cards, after the skips", () => {
  const result = plan({
    backlog: BACKLOG,
    state: STATE,
    section: "World 1 now: ready to build",
    limit: 1,
  });
  const runnable = result.cards.filter((card) => !card.skip).map((card) => card.id);
  assert.deepEqual(runnable, ["W1-07"]);
});

test("a run cut off with no JSON is charged its whole cap", () => {
  assert.equal(claudeJson("", 4).cost, 4);
  assert.equal(claudeJson('{"total_cost_usd":0.42,"result":"ok"}', 4).cost, 0.42);
});

test("cards named in pull requests or board comments are skipped", () => {
  const taken = takenIds("CLAIM W1-07 (#858); PR 851 built branch card/w1-08 and W1-12a");
  assert.ok(taken.has("W1-07") && taken.has("W1-08") && taken.has("W1-12A"));
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

test("flat main with no live board returns stage main, board null, and emits zero null references", () => {
  const flatState = "| Open stage | main |\n| Live board | none |\n";
  assert.equal(openStage(flatState), "main");
  assert.equal(liveBoard(flatState), null);
  const result = plan({ backlog: BACKLOG, state: flatState, ids: ["W1-07"] });
  assert.equal(result.stage, "main");
  assert.equal(result.board, null);
  const serialized = JSON.stringify(result.cards[0]);
  assert.doesNotMatch(serialized, /\bnull\b/);
  assert.match(serialized, /origin\/main/);
  assert.doesNotMatch(render(result), /#null|board null/);
});
