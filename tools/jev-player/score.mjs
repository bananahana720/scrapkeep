// Scores the decision layer against the labeled corpus before it is allowed to
// drive anything. A miss is weighted by what it costs in a run: losing the run
// is not the same as losing tempo, so a flat accuracy number would hide the
// only failures that matter.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { decide } from "./decide.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..");
const WEIGHT = { severe: 5, moderate: 2, minor: 1 };

export function loadCorpus(file = path.join(here, "corpus.json")) {
  const data = JSON.parse(readFileSync(file, "utf8"));
  return [...data.cases, ...data.adversarial];
}

async function scoreCase(testCase) {
  const result = await decide(testCase.state, testCase.options);
  const passed = testCase.accept.includes(result.intent);
  return {
    id: testCase.id,
    block: testCase.block,
    severity: testCase.severity,
    expected: testCase.accept,
    got: result.intent,
    passed,
    confidence: result.confidence,
    danger: result.danger,
    greedy: result.greedy,
    latencyMs: result.latencyMs,
    gatedOut: result.gatedOut,
    inputTokens: result.usage.input_tokens,
    note: testCase.note,
  };
}

async function main() {
  const corpus = loadCorpus();
  console.log(`Scoring ${corpus.length} decision points against Jev.\n`);
  // The cases are independent, so they go out together rather than in a queue.
  const results = await Promise.all(corpus.map(scoreCase));

  let earned = 0;
  let possible = 0;
  const byBlock = new Map();
  for (const result of results) {
    const weight = WEIGHT[result.severity];
    possible += weight;
    if (result.passed) {
      earned += weight;
    }
    const block = byBlock.get(result.block) || { pass: 0, total: 0 };
    block.total += 1;
    if (result.passed) {
      block.pass += 1;
    }
    byBlock.set(result.block, block);

    const mark = result.passed ? "PASS" : "FAIL";
    const line = `${mark} ${result.id.padEnd(30)} got=${result.got.padEnd(16)} conf=${result.confidence.toFixed(2)} danger=${result.danger.toFixed(2)} greed=${result.greedy.toFixed(2)}`;
    console.log(line);
    if (result.gatedOut.length > 0) {
      console.log(`     gated out in code: ${result.gatedOut.join(", ")}`);
    }
    if (!result.passed) {
      console.log(`     expected one of: ${result.expected.join(", ")}`);
      console.log(`     ${result.note}`);
    }
  }

  const severeMisses = results.filter(
    (r) => !r.passed && r.severity === "severe",
  );
  const latencies = results.map((r) => r.latencyMs).sort((a, b) => a - b);
  const tokens = results.reduce((sum, r) => sum + r.inputTokens, 0);

  console.log("\nBy block:");
  for (const [block, stat] of byBlock) {
    console.log(`  ${block.padEnd(14)} ${stat.pass}/${stat.total}`);
  }
  console.log(
    `\nSeverity-weighted score: ${earned}/${possible} (${((earned / possible) * 100).toFixed(1)}%)`,
  );
  console.log(
    `Plain accuracy: ${results.filter((r) => r.passed).length}/${results.length}`,
  );
  console.log(`Severe misses: ${severeMisses.length}`);
  console.log(
    `Latency median ${latencies[Math.floor(latencies.length / 2)]} ms, max ${latencies[latencies.length - 1]} ms`,
  );
  console.log(
    `Input tokens total ${tokens}, mean ${Math.round(tokens / results.length)} per decision`,
  );

  const out = path.join(root, "artifacts", "local", "jev-player");
  mkdirSync(out, { recursive: true });
  const report = path.join(out, "corpus-score.json");
  writeFileSync(
    report,
    JSON.stringify(
      { when: new Date().toISOString(), earned, possible, results },
      null,
      2,
    ),
  );
  console.log(`\nReport: ${report}`);
  console.log(
    "Corpus agreement only. It says the decider picks defensible intents on these states; it says nothing about whether the game is fun.",
  );
  // A severe miss means the player can lose a run to a decision the corpus
  // already labelled, so it gates regardless of the weighted total.
  process.exit(severeMisses.length === 0 && earned / possible >= 0.8 ? 0 : 1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
