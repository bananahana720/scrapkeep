import assert from "node:assert/strict";
import { test } from "node:test";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  STATE_FILE,
  checkWaveState,
  compareWithGit,
  hardCodedBoards,
  lastPromotion,
  nextRedTeam,
  parsePromotionSubject,
  parseWaveFacts,
  renderWaveFacts,
  replaceWaveFacts,
} from "./wave-state.mjs";
import { git as runGit } from "./lib/git.mjs";

const script = fileURLToPath(new URL("./wave-state.mjs", import.meta.url));
const facts = {
  wave: 32,
  mainSha: "8180ec6c",
  pr: 632,
  stage: 33,
  board: 633,
  redTeam: "cautious",
  compare: "gate/w32-58a6de62/",
};
const state = (table = renderWaveFacts(facts)) =>
  "# Wave state\n\nIntro line.\n\n" + table + "\n\n## Owed\n\n- a thing\n";
const promotion32 = {
  wave: 32,
  stageSha: "8f12596a",
  pr: 632,
  sha: "8180ec6c0000000000000000000000000000abcd",
};

test("a promotion subject yields its wave, stage head and PR", () => {
  assert.deepEqual(
    parsePromotionSubject("Promote alpha wave 32 (stage/alpha-w32 8f12596a) to main (#632)"),
    { wave: 32, stageSha: "8f12596a", pr: 632 },
  );
  assert.equal(parsePromotionSubject("Merge pull request #614 from x/y"), null);
});

test("the newest promotion in a log wins and other subjects are skipped", () => {
  const found = lastPromotion([
    "aaaa\tPages build centred bold labels",
    "bbbb\tPromote alpha wave 32 (stage/alpha-w32 8f12596a) to main (#632)",
    "cccc\tPromote alpha wave 31 (stage/alpha-w31 80af241e) to main (#626)",
  ]);
  assert.equal(found.wave, 32);
  assert.equal(found.sha, "bbbb");
  assert.equal(lastPromotion(["aaaa\tno promotion here"]), null);
});

test("the rendered table parses back to the same facts", () => {
  const parsed = parseWaveFacts(state());
  assert.equal(parsed.found, true);
  assert.deepEqual(parsed.problems, []);
  assert.deepEqual(parsed.facts, facts);
});

test("a page with no Wave facts heading is reported as not found", () => {
  assert.equal(parseWaveFacts("# Wave state\n\nNothing here.\n").found, false);
});

test("a missing row and a malformed value are each named", () => {
  const broken = renderWaveFacts(facts)
    .replace("| Live board | #633 |\n", "")
    .replace("stage/alpha-w33", "the w33 stage");
  const { problems } = parseWaveFacts(state(broken));
  assert.equal(problems.length, 2);
  assert.match(problems.join("\n"), /no "live board" row/);
  assert.match(problems.join("\n"), /"Open stage" must read/);
});

test("facts that match the newest promotion pass", () => {
  assert.deepEqual(compareWithGit(facts, promotion32), []);
});

test("facts one wave behind fail and name the command that fixes them", () => {
  const promotion33 = { ...promotion32, wave: 33, pr: 640 };
  const problems = compareWithGit(facts, promotion33, { headIsPromotion: false });
  assert.equal(problems.length, 1);
  assert.match(problems[0], /says wave 32 but history holds the wave 33/);
  assert.match(problems[0], /wave-state\.mjs --write/);
});

test("one wave behind passes while HEAD is the promotion commit itself", () => {
  const promotion33 = { ...promotion32, wave: 33, pr: 640 };
  assert.deepEqual(compareWithGit(facts, promotion33, { headIsPromotion: true }), []);
  const promotion34 = { ...promotion32, wave: 34, pr: 650 };
  assert.equal(compareWithGit(facts, promotion34, { headIsPromotion: true }).length, 1);
});

test("a wrong main sha or PR for the right wave fails", () => {
  const problems = compareWithGit({ ...facts, mainSha: "deadbeef", pr: 600 }, promotion32);
  assert.equal(problems.length, 2);
});

test("the open stage must be one wave ahead of the last promotion", () => {
  const problems = compareWithGit({ ...facts, stage: 32 }, promotion32);
  assert.match(problems[0], /always one wave ahead/);
});

test("facts ahead of the newest standard subject need their commit in history", () => {
  const ahead = { ...facts, wave: 33, stage: 34, mainSha: "0123abcd" };
  assert.deepEqual(compareWithGit(ahead, promotion32, { isAncestor: () => true }), []);
  assert.equal(compareWithGit(ahead, promotion32, { isAncestor: () => false }).length, 1);
});

test("with no promotion in history only the table's own shape is checked", () => {
  assert.deepEqual(compareWithGit(facts, null), []);
});

test("board numbers in pointer pages are found, other issue numbers are not", () => {
  const page = [
    "The live board is the wave's board issue (#627 for wave 32).",
    "Queued on board #627.",
    "Watches on #627 and the owed reds.",
    "Every fix shipped in wave 29 (#600, #601).",
    "Read #633 first.",
    "```",
    "board #1",
    "```",
  ].join("\n");
  assert.deepEqual(
    hardCodedBoards(page, 633).map((hit) => hit.line),
    [1, 2, 3, 5],
  );
});

test("the red team rotates in the gate's order and wraps", () => {
  assert.equal(nextRedTeam("first-timer"), "cautious");
  assert.equal(nextRedTeam("cautious"), "greedy");
});

test("replacing the table leaves the rest of the page alone", () => {
  const next = replaceWaveFacts(state(), { ...facts, wave: 33, stage: 34, board: 640 });
  assert.match(next, /\| Live board \| #640 \|/);
  assert.match(next, /^# Wave state\n\nIntro line\.\n\n## Wave facts/);
  assert.match(next, /\n\n## Owed\n\n- a thing\n$/);
});

function repo() {
  const root = mkdtempSync(path.join(os.tmpdir(), "wave-state-"));
  const git = (...args) => runGit(args, { cwd: root });
  git("init", "-q", "-b", "main");
  git("config", "user.email", "test@example.invalid");
  git("config", "user.name", "Test");
  git("config", "commit.gpgsign", "false");
  mkdirSync(path.join(root, path.dirname(STATE_FILE)), { recursive: true });
  const commit = (subject) => {
    git("add", "-A");
    git("commit", "-q", "--allow-empty", "-m", subject);
    return git("rev-parse", "HEAD");
  };
  return { root, git, commit };
}

test("the check passes on a checkout whose table matches its history", async () => {
  const { root, commit } = repo();
  try {
    writeFileSync(path.join(root, STATE_FILE), state());
    const sha = commit("Promote alpha wave 32 (stage/alpha-w32 8f12596a) to main (#632)");
    writeFileSync(path.join(root, STATE_FILE), state(renderWaveFacts({ ...facts, mainSha: sha })));
    commit("First commit on the new stage");
    const findings = await checkWaveState(root);
    assert.deepEqual(
      findings.filter((finding) => finding.level === "failure"),
      [],
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("the check fails once a newer promotion lands, then --write repairs it", async () => {
  const { root, commit } = repo();
  try {
    writeFileSync(path.join(root, STATE_FILE), state());
    const sha32 = commit("Promote alpha wave 32 (stage/alpha-w32 8f12596a) to main (#632)");
    writeFileSync(
      path.join(root, STATE_FILE),
      state(renderWaveFacts({ ...facts, mainSha: sha32 })),
    );
    commit("A stacked pull request");
    const sha33 = commit("Promote alpha wave 33 (stage/alpha-w33 0a0a0a0a) to main (#640)");
    assert.deepEqual(
      (await checkWaveState(root)).filter((finding) => finding.level === "failure"),
      [],
      "the promotion commit itself may be one wave behind",
    );
    commit("First pull request on wave 34");
    const stale = (await checkWaveState(root)).filter((finding) => finding.level === "failure");
    assert.equal(stale.length, 1);
    assert.match(stale[0].message, /history holds the wave 33 promotion/);

    const refused = spawnSync(process.execPath, [script, "--write", "--root", root], {
      encoding: "utf8",
    });
    assert.equal(refused.status, 2);
    assert.match(refused.stderr, /needs --board/);
    const wrote = spawnSync(
      process.execPath,
      [script, "--write", "--root", root, "--board", "641", "--compare", "gate/w33-0a0a0a0a/"],
      { encoding: "utf8" },
    );
    assert.equal(wrote.status, 0, wrote.stderr);
    const parsed = parseWaveFacts(readFileSync(path.join(root, STATE_FILE), "utf8"));
    assert.deepEqual(parsed.facts, {
      wave: 33,
      mainSha: sha33.slice(0, 8),
      pr: 640,
      stage: 34,
      board: 641,
      redTeam: "greedy",
      compare: "gate/w33-0a0a0a0a/",
    });
    assert.deepEqual(
      (await checkWaveState(root)).filter((finding) => finding.level === "failure"),
      [],
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a pointer page that names the live board fails the check", async () => {
  const { root, commit } = repo();
  try {
    writeFileSync(path.join(root, STATE_FILE), state() + "\nPlay issues on board #633.\n");
    writeFileSync(path.join(root, "AGENTS.md"), "Read the board (#633) first.\n");
    commit("Docs");
    const failures = (await checkWaveState(root)).filter((finding) => finding.level === "failure");
    assert.deepEqual(failures.map((finding) => finding.file).sort(), ["AGENTS.md", STATE_FILE]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a root with no handoff folder has nothing to check", async () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "wave-state-"));
  try {
    assert.deepEqual(await checkWaveState(root), []);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("flat main mode parses, renders, and validates direct promotions with no live board", async () => {
  const flatFacts = {
    wave: 50,
    mainSha: "fc9680f8",
    direct: true,
    flatMain: true,
    redTeam: "cautious",
    compare: "w50-pre-alpha-fc9680f8",
  };
  const rendered = renderWaveFacts(flatFacts);
  assert.match(rendered, /\| Last promotion \| wave 50, main fc9680f8, direct \|/);
  assert.match(rendered, /\| Open stage \| main \|/);
  assert.match(rendered, /\| Live board \| none \|/);

  const parsed = parseWaveFacts(state(rendered));
  assert.equal(parsed.found, true);
  assert.deepEqual(parsed.problems, []);
  assert.deepEqual(parsed.facts, flatFacts);
  assert.equal(parsed.facts.pr, undefined);
  assert.equal(parsed.facts.board, undefined);

  assert.deepEqual(compareWithGit(flatFacts, promotion32, { isAncestor: () => true }), []);
  assert.equal(compareWithGit(flatFacts, promotion32, { isAncestor: () => false }).length, 1);
  assert.deepEqual(
    compareWithGit({ ...flatFacts, wave: 32 }, promotion32, { isAncestor: () => true }),
    [],
  );

  const { root, commit } = repo();
  try {
    writeFileSync(path.join(root, STATE_FILE), state());
    commit("Promote alpha wave 46 (stage/alpha-w46 8f12596a) to main (#1279)");
    const directSha = commit("Flatten waves 47-50 onto main");
    writeFileSync(
      path.join(root, STATE_FILE),
      state(renderWaveFacts({ ...flatFacts, mainSha: directSha.slice(0, 8) })),
    );
    commit("Record flat main baseline");
    const findings = await checkWaveState(root);
    assert.deepEqual(
      findings.filter((finding) => finding.level === "failure"),
      [],
    );

    writeFileSync(path.join(root, "AGENTS.md"), "Queued on board #1280.\n");
    const boardHits = (await checkWaveState(root)).filter((finding) => finding.level === "failure");
    assert.deepEqual(
      boardHits.map((finding) => finding.file),
      ["AGENTS.md"],
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("--write supports --flat-main --direct --wave <N> --board none", async () => {
  const { root, commit } = repo();
  try {
    writeFileSync(path.join(root, STATE_FILE), state());
    const directSha = commit("Flat alpha wave 52 commit");
    const wrote = spawnSync(
      process.execPath,
      [
        script,
        "--write",
        "--root",
        root,
        "--flat-main",
        "--direct",
        "--wave",
        "52",
        "--board",
        "none",
        "--compare",
        "gate/w52-flat/",
      ],
      { encoding: "utf8" },
    );
    assert.equal(wrote.status, 0, wrote.stderr);
    const parsed = parseWaveFacts(readFileSync(path.join(root, STATE_FILE), "utf8"));
    assert.equal(parsed.found, true);
    assert.deepEqual(parsed.problems, []);
    assert.deepEqual(parsed.facts, {
      wave: 52,
      mainSha: directSha.slice(0, 8),
      direct: true,
      flatMain: true,
      redTeam: "greedy",
      compare: "gate/w52-flat/",
    });
    commit("Record flat-main wave 52 facts");
    const findings = await checkWaveState(root);
    assert.deepEqual(
      findings.filter((finding) => finding.level === "failure"),
      [],
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("--write preserves flatMain, direct, and wave across --compare and --wave updates with historical promotions", () => {
  const { root, commit } = repo();
  try {
    writeFileSync(path.join(root, STATE_FILE), state());
    commit("Promote alpha wave 46 (stage/alpha-w46 8f12596a) to main (#1279)");
    commit("Flat alpha wave 52 baseline");
    const first = spawnSync(
      process.execPath,
      [
        script,
        "--write",
        "--root",
        root,
        "--flat-main",
        "--direct",
        "--wave",
        "52",
        "--board",
        "none",
        "--compare",
        "gate/w52-a/",
      ],
      { encoding: "utf8" },
    );
    assert.equal(first.status, 0, first.stderr);

    const head2 = commit("Second flat-main commit");
    const refreshCompare = spawnSync(
      process.execPath,
      [script, "--write", "--root", root, "--compare", "gate/w52-b/"],
      { encoding: "utf8" },
    );
    assert.equal(refreshCompare.status, 0, refreshCompare.stderr);
    let parsed = parseWaveFacts(readFileSync(path.join(root, STATE_FILE), "utf8"));
    assert.deepEqual(parsed.facts, {
      wave: 52,
      mainSha: head2.slice(0, 8),
      direct: true,
      flatMain: true,
      redTeam: "greedy",
      compare: "gate/w52-b/",
    });

    const bumpWave = spawnSync(
      process.execPath,
      [script, "--write", "--root", root, "--wave", "53", "--compare", "gate/w53-a/"],
      { encoding: "utf8" },
    );
    assert.equal(bumpWave.status, 0, bumpWave.stderr);
    parsed = parseWaveFacts(readFileSync(path.join(root, STATE_FILE), "utf8"));
    assert.deepEqual(parsed.facts, {
      wave: 53,
      mainSha: head2.slice(0, 8),
      direct: true,
      flatMain: true,
      redTeam: "line-rider",
      compare: "gate/w53-a/",
    });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
