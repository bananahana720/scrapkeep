// Offline tests for score.mjs. Scoring runs on canned decisions here; nothing
// calls Jev.
import { test } from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { tmpdir } from "node:os";

import {
  buildReport,
  gateVerdict,
  loadAuthored,
  loadBlind,
  scoreCase,
  summarize,
} from "../score.mjs";

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
