// Offline tests for score.mjs. Scoring runs on canned decisions here; nothing
// calls Jev.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import path from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

import {
  buildReport,
  gateVerdict,
  loadAuthored,
  loadBlind,
  parseArgs,
  REPORT_FILE,
  scoreCase,
  summarize,
  validateCases,
} from "../score.mjs";

const scorePath = fileURLToPath(new URL("../score.mjs", import.meta.url));

// The CLI runs with fetch replaced by one that exits 99, so a flag that leaks
// into scoring fails loudly instead of spending a call.
const noNetwork = `data:text/javascript,${encodeURIComponent(
  'globalThis.fetch = () => { process.stderr.write("network call\\n"); process.exit(99); };',
)}`;
function cli(...args) {
  return spawnSync(
    process.execPath,
    ["--import", noNetwork, scorePath, ...args],
    {
      encoding: "utf8",
      env: { ...process.env, TYPESAFE_API_KEY: "test-key-never-sent" },
    },
  );
}
const reportStamp = () =>
  existsSync(REPORT_FILE) ? statSync(REPORT_FILE).mtimeMs : null;

const kicker = {
  id: "kicker",
  block: "traversal",
  severity: "moderate",
  accept: ["hit_kicker"],
  note: "",
};
const decision = (overrides) => ({
  intent: "hit_kicker",
  rawIntent: "hit_kicker",
  lowConfidence: false,
  confidence: 0.9,
  danger: 0.1,
  greedy: 0.6,
  latencyMs: 250,
  gatedOut: [],
  usage: { input_tokens: 700 },
  ...overrides,
});
const floored = {
  intent: "push_objective",
  lowConfidence: true,
  confidence: 0.02,
};

test("the authored corpus loads its cases and adversarial block, and nothing else", () => {
  const authored = loadAuthored();
  assert.equal(authored.length, 16);
  assert.equal(authored.filter((c) => c.block === "adversarial").length, 4);
});

test("a missing blind corpus loads as null rather than borrowing authored cases", () => {
  assert.equal(
    loadBlind(path.join(tmpdir(), "no-such-corpus-blind.json")),
    null,
  );
});

test("every scored case records rawIntent and lowConfidence", () => {
  const record = scoreCase(kicker, decision({}));
  assert.equal(record.rawIntent, "hit_kicker");
  assert.equal(record.lowConfidence, false);
  assert.equal(record.outcome, "pass");
});

test("a miss the floor caused is told apart from a model miss", () => {
  const floorMiss = scoreCase(
    kicker,
    decision({ ...floored, rawIntent: "hit_kicker" }),
  );
  assert.equal(floorMiss.passed, false);
  assert.equal(floorMiss.outcome, "floor-miss");

  const modelMiss = scoreCase(
    kicker,
    decision({ intent: "sweep_scrap", rawIntent: "sweep_scrap" }),
  );
  assert.equal(modelMiss.outcome, "model-miss");

  const lowAndWrong = scoreCase(
    kicker,
    decision({ ...floored, rawIntent: "sweep_scrap" }),
  );
  assert.equal(lowAndWrong.outcome, "model-miss");

  const rescued = scoreCase(
    { ...kicker, accept: ["push_objective"] },
    decision({ ...floored, rawIntent: "hit_kicker" }),
  );
  assert.equal(rescued.passed, true);
  assert.equal(rescued.outcome, "floor-rescue");
});

test("the summary counts floor misses and model misses separately", () => {
  const records = [
    scoreCase(kicker, decision({})),
    scoreCase(kicker, decision({ ...floored, rawIntent: "hit_kicker" })),
    scoreCase(
      { ...kicker, id: "k2", severity: "severe" },
      decision({ intent: "sweep_scrap", rawIntent: "sweep_scrap" }),
    ),
  ];
  const summary = summarize(records);
  assert.deepEqual(summary.floorMisses, ["kicker"]);
  assert.deepEqual(summary.modelMisses, ["k2"]);
  assert.deepEqual(summary.severeMisses, ["k2"]);
  assert.equal(summary.earned, 2);
  assert.equal(summary.possible, 9);
  assert.equal(summary.cases, 3);
});

const passing = (n) =>
  Array.from({ length: n }, (_, i) =>
    scoreCase({ ...kicker, id: `b${i}` }, decision({})),
  );

test("only the blind score gates, and without one the gate is inconclusive", () => {
  assert.equal(gateVerdict(null).exit, 3);
  assert.equal(gateVerdict(summarize(passing(19))).exit, 3);
  assert.equal(gateVerdict(summarize(passing(20))).exit, 0);
  const severe = [
    ...passing(19),
    scoreCase(
      { ...kicker, id: "s", severity: "severe" },
      decision({ intent: "sweep_scrap", rawIntent: "sweep_scrap" }),
    ),
  ];
  assert.equal(gateVerdict(summarize(severe)).exit, 1);
});

test("the report keeps authored and blind apart and marks only blind as gating", () => {
  const authored = [
    scoreCase(
      kicker,
      decision({ intent: "sweep_scrap", rawIntent: "sweep_scrap" }),
    ),
  ];
  const blind = passing(20);
  const report = buildReport({
    authored,
    blind,
    instrument: { questions_sha: "x" },
  });
  assert.equal(report.authored.gating, false);
  assert.equal(report.blind.gating, true);
  assert.equal(report.authored.results.length, 1);
  assert.equal(report.blind.results.length, 20);
  assert.equal(report.gate.exit, 0);
  assert.equal(report.earned, undefined);
  assert.deepEqual(report.instrument, { questions_sha: "x" });

  const noBlind = buildReport({ authored, blind: null, instrument: {} });
  assert.equal(noBlind.blind, null);
  assert.equal(noBlind.gate.exit, 3);
});

// --- EV-0493: arguments first, --help, --dry-run, decision.model ---------------

test("each score record carries the model Jev resolved", () => {
  const record = scoreCase(kicker, decision({ model: "jev-resolved-7" }));
  assert.equal(record.model, "jev-resolved-7");
});

test("parseArgs reads --help and --dry-run and refuses anything else", () => {
  assert.deepEqual(parseArgs([]), { help: false, dryRun: false });
  assert.deepEqual(parseArgs(["--help"]), { help: true, dryRun: false });
  assert.deepEqual(parseArgs(["-h"]), { help: true, dryRun: false });
  assert.deepEqual(parseArgs(["--dry-run"]), { help: false, dryRun: true });
  assert.throws(() => parseArgs(["--live"]), /--live/);
  assert.throws(() => parseArgs(["corpus.json"]), /corpus\.json/);
});

test("--help prints usage and exits 0 without a call or a report", () => {
  const before = reportStamp();
  const result = cli("--help");
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /usage/i);
  assert.match(result.stdout, /--dry-run/);
  assert.doesNotMatch(result.stderr, /network call/);
  assert.equal(reportStamp(), before);
});

test("an unknown argument exits 2 with usage before anything runs", () => {
  const before = reportStamp();
  const result = cli("--score-everything");
  assert.equal(result.status, 2);
  assert.match(result.stderr, /usage/i);
  assert.equal(reportStamp(), before);
});

test("--dry-run validates the corpora and question set, makes no call and prints no blind case", () => {
  const before = reportStamp();
  const result = cli("--dry-run");
  assert.equal(result.status, 0, result.stderr);
  assert.doesNotMatch(result.stderr, /network call/);
  assert.match(result.stdout, /Authored corpus: 16 cases, 0 faults/);
  assert.match(result.stdout, /no Jev call/i);
  assert.equal(reportStamp(), before);
  const blind = loadBlind();
  if (blind !== null) {
    assert.match(
      result.stdout,
      new RegExp(`Blind corpus: ${blind.length} cases, 0 faults`),
    );
    const leaked = blind.filter(
      (testCase) =>
        result.stdout.includes(testCase.id) ||
        result.stderr.includes(testCase.id),
    ).length;
    assert.equal(leaked, 0, "the dry run printed blind case ids");
  }
});

test("validateCases names each fault by index and field, never by value", () => {
  const good = loadAuthored();
  assert.deepEqual(validateCases(good, "authored"), []);
  const bad = [
    { ...good[0], severity: "catastrophic" },
    { ...good[1], accept: [] },
    { ...good[2], options: [{ id: "teleport", why: "x" }] },
    { ...good[3], id: good[0].id },
    { ...good[4], state: null },
  ];
  const faults = validateCases(bad, "blind");
  assert.deepEqual(
    faults.map((fault) => fault.path),
    [
      "blind[0].severity",
      "blind[1].accept",
      "blind[2].options[0].id",
      "blind[3].id",
      "blind[4].state",
    ],
  );
  for (const fault of faults) {
    assert.doesNotMatch(fault.message, /catastrophic|teleport/);
    assert.ok(!fault.message.includes(good[0].id));
  }
});
