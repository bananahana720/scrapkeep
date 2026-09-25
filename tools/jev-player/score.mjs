// Scores the decision layer against labeled corpora. A miss is weighted by what
// it costs in a run: losing the run is not the same as losing tempo, so a flat
// accuracy number would hide the only failures that matter.
//
// The authored corpus (corpus.json) was written by the prompt's author, so it is
// reported but never gates. Only the blind corpus (corpus-blind.json, JL-04)
// gates, and the two are never merged.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { decide, instrumentIdentity, loadQuestionSet } from "./decide.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..");
const WEIGHT = { severe: 5, moderate: 2, minor: 1 };
const BLIND_MIN_CASES = 20;
const GATE_WEIGHTED_MIN = 0.8;

export function loadAuthored(file = path.join(here, "corpus.json")) {
  const data = JSON.parse(readFileSync(file, "utf8"));
  return [...data.cases, ...data.adversarial];
}

export function loadBlind(file = path.join(here, "corpus-blind.json")) {
  if (!existsSync(file)) {
    return null;
  }
  return JSON.parse(readFileSync(file, "utf8")).cases;
}

// outcome separates what the model chose from what the confidence floor did to
// it: a floor-miss is a raw choice the labels accept that the floor replaced,
// and a floor-rescue is a pass only because the floor replaced a wrong choice.
export function scoreCase(testCase, decision) {
  const passed = testCase.accept.includes(decision.intent);
  const rawPassed = testCase.accept.includes(decision.rawIntent);
  let outcome;
  if (passed) {
    outcome = decision.lowConfidence && !rawPassed ? "floor-rescue" : "pass";
  } else {
    outcome = decision.lowConfidence && rawPassed ? "floor-miss" : "model-miss";
  }
  return {
    id: testCase.id,
    block: testCase.block,
    severity: testCase.severity,
    expected: testCase.accept,
    got: decision.intent,
    rawIntent: decision.rawIntent,
    lowConfidence: decision.lowConfidence,
    passed,
    outcome,
    confidence: decision.confidence,
    danger: decision.danger,
    greedy: decision.greedy,
    latencyMs: decision.latencyMs,
    gatedOut: decision.gatedOut,
    inputTokens: decision.usage.input_tokens,
    note: testCase.note,
  };
}

export function summarize(records) {
  let earned = 0;
  let possible = 0;
  const byBlock = {};
  for (const record of records) {
    const weight = WEIGHT[record.severity];
    possible += weight;
    if (record.passed) {
      earned += weight;
    }
    const block = byBlock[record.block] || { pass: 0, total: 0 };
    block.total += 1;
    if (record.passed) {
      block.pass += 1;
    }
    byBlock[record.block] = block;
  }
  const ids = (outcome) =>
    records.filter((r) => r.outcome === outcome).map((r) => r.id);
  const latencies = records.map((r) => r.latencyMs).sort((a, b) => a - b);
  const tokens = records.reduce((sum, r) => sum + r.inputTokens, 0);
  return {
    cases: records.length,
    earned,
    possible,
    weighted: possible === 0 ? 0 : earned / possible,
    plainPass: records.filter((r) => r.passed).length,
    severeMisses: records
      .filter((r) => !r.passed && r.severity === "severe")
      .map((r) => r.id),
    modelMisses: ids("model-miss"),
    floorMisses: ids("floor-miss"),
    floorRescues: ids("floor-rescue"),
    lowConfidence: records.filter((r) => r.lowConfidence).length,
    byBlock,
    latencyMedianMs: latencies[Math.floor(latencies.length / 2)],
    latencyMaxMs: latencies[latencies.length - 1],
    meanInputTokens: Math.round(tokens / Math.max(records.length, 1)),
  };
}

// Exit codes follow the lab gate: 0 pass, 1 fail, 3 inconclusive.
export function gateVerdict(blindSummary) {
  if (blindSummary === null) {
    return { exit: 3, reason: "No blind corpus, so nothing gates." };
  }
  if (blindSummary.cases < BLIND_MIN_CASES) {
    return {
      exit: 3,
      reason: `Blind corpus has ${blindSummary.cases} cases; the gate needs ${BLIND_MIN_CASES}.`,
    };
  }
  if (blindSummary.severeMisses.length > 0) {
    return { exit: 1, reason: "Severe miss on the blind corpus." };
  }
  if (blindSummary.weighted < GATE_WEIGHTED_MIN) {
    return { exit: 1, reason: "Blind weighted score below 0.8." };
  }
  return { exit: 0, reason: "Blind corpus passes." };
}

export function buildReport({ authored, blind, instrument, when }) {
  const section = (records, gating) => ({
    gating,
    summary: summarize(records),
    results: records,
  });
  const blindSection = blind === null ? null : section(blind, true);
  return {
    when,
    instrument,
    authored: section(authored, false),
    blind: blindSection,
    gate: gateVerdict(blindSection === null ? null : blindSection.summary),
  };
}

function printSection(name, section) {
  const label = section.gating ? "gating" : "not gating";
  console.log(`\n${name} corpus (${label})`);
  for (const r of section.results) {
    const mark = r.passed ? "PASS" : "FAIL";
    const raw = r.lowConfidence ? ` raw=${r.rawIntent}` : "";
    console.log(
      `${mark} ${r.id.padEnd(30)} got=${r.got.padEnd(16)} conf=${r.confidence.toFixed(2)} ${r.outcome}${raw}`,
    );
    if (r.gatedOut.length > 0) {
      console.log(`     gated out in code: ${r.gatedOut.join(", ")}`);
    }
    if (!r.passed) {
      console.log(`     expected one of: ${r.expected.join(", ")}`);
    }
  }
  const s = section.summary;
  console.log(
    `Severity-weighted ${s.earned}/${s.possible} (${(s.weighted * 100).toFixed(1)}%), plain ${s.plainPass}/${s.cases}`,
  );
  console.log(
    `Severe misses ${s.severeMisses.length}; model misses ${s.modelMisses.length}; floor misses ${s.floorMisses.length}; floor rescues ${s.floorRescues.length}`,
  );
  console.log(
    `Latency median ${s.latencyMedianMs} ms, max ${s.latencyMaxMs} ms; mean ${s.meanInputTokens} input tokens`,
  );
}

async function scoreAll(cases, questions) {
  return Promise.all(
    cases.map(async (testCase) =>
      scoreCase(
        testCase,
        await decide(testCase.state, testCase.options, { questions }),
      ),
    ),
  );
}

async function main() {
  const questions = loadQuestionSet();
  const instrument = instrumentIdentity(questions);
  console.log(
    `Question set ${questions.version} (${questions.status}), sha ${instrument.questions_sha.slice(0, 12)}`,
  );
  const blindCases = loadBlind();
  const report = buildReport({
    when: new Date().toISOString(),
    instrument,
    authored: await scoreAll(loadAuthored(), questions),
    blind: blindCases === null ? null : await scoreAll(blindCases, questions),
  });

  printSection("Authored", report.authored);
  if (report.blind === null) {
    console.log("\nBlind corpus: absent.");
  } else {
    printSection("Blind", report.blind);
  }
  console.log(`\nGate: ${report.gate.reason} (exit ${report.gate.exit})`);

  const out = path.join(root, "artifacts", "local", "jev-player");
  mkdirSync(out, { recursive: true });
  const file = path.join(out, "corpus-score.json");
  writeFileSync(file, JSON.stringify(report, null, 2));
  console.log(`Report: ${file}`);
  console.log(
    "Corpus agreement only. It says nothing about whether the game is fun.",
  );
  process.exit(report.gate.exit);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
