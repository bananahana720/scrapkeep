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

import {
  buildQuestions,
  decide,
  instrumentIdentity,
  INTENTS,
  loadQuestionSet,
  offeredOptions,
} from "./decide.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..");
const WEIGHT = { severe: 5, moderate: 2, minor: 1 };
const BLIND_MIN_CASES = 20;
const GATE_WEIGHTED_MIN = 0.8;
export const REPORT_FILE = path.join(
  root,
  "artifacts",
  "local",
  "jev-player",
  "corpus-score.json",
);

// The blind cases a text-only picker with game priors cannot answer, chosen by
// the coordinator. The subscore over them is reported as counts only; the ids
// never reach the output.
export const DIAGNOSTIC_FILE = path.join(
  root,
  "artifacts",
  "jev-lab-2026-09-25",
  "blind-diagnostic.json",
);

export const USAGE = `usage: node tools/jev-player/score.mjs [--dry-run | --help]
  (no flag)   score both corpora against live Jev, one call per case, and
              write ${path.relative(root, REPORT_FILE)}
  --dry-run   load and validate the corpora and the question set; no call
  --help, -h  print this and exit`;

// Arguments are read before anything else, so no flag can fall through to
// scoring and spend calls.
export function parseArgs(argv) {
  const options = { help: false, dryRun: false };
  for (const word of argv) {
    if (word === "--help" || word === "-h") {
      options.help = true;
    } else if (word === "--dry-run") {
      options.dryRun = true;
    } else {
      throw new Error(`unknown argument ${word}`);
    }
  }
  return options;
}

// Faults name the case by index and field only, never by id or value, so a
// dry run over the blind corpus prints nothing a labeller could learn from.
export function validateCases(cases, label) {
  const faults = [];
  const fault = (at, message) =>
    faults.push({ path: `${label}${at}`, message });
  if (!Array.isArray(cases)) {
    fault("", "must be a list of cases");
    return faults;
  }
  const seen = new Set();
  cases.forEach((testCase, index) => {
    const at = `[${index}]`;
    if (testCase === null || typeof testCase !== "object") {
      fault(at, "must be an object");
      return;
    }
    const { id, block, severity, accept, state, options } = testCase;
    if (typeof id !== "string" || id === "") {
      fault(`${at}.id`, "must be a non-empty string");
    } else if (seen.has(id)) {
      fault(`${at}.id`, "repeats an earlier case's id");
    } else {
      seen.add(id);
    }
    if (typeof block !== "string" || block === "") {
      fault(`${at}.block`, "must be a non-empty string");
    }
    if (!Object.hasOwn(WEIGHT, severity)) {
      fault(
        `${at}.severity`,
        `must be one of ${Object.keys(WEIGHT).join(", ")}`,
      );
    }
    if (
      !Array.isArray(accept) ||
      accept.length === 0 ||
      !accept.every((intent) => Object.hasOwn(INTENTS, intent))
    ) {
      fault(`${at}.accept`, "must be a non-empty list of known intents");
    }
    if (
      state === null ||
      typeof state !== "object" ||
      state.self === null ||
      typeof state.self !== "object"
    ) {
      fault(`${at}.state`, "must be an object with a self block");
      return;
    }
    if (!Array.isArray(options) || options.length === 0) {
      fault(`${at}.options`, "must be a non-empty list");
      return;
    }
    options.forEach((option, n) => {
      if (!Object.hasOwn(INTENTS, option?.id)) {
        fault(`${at}.options[${n}].id`, "must be a known intent");
      }
      if (typeof option?.why !== "string" || option.why === "") {
        fault(`${at}.options[${n}].why`, "must be a non-empty string");
      }
    });
  });
  return faults;
}

// The question set must carry all three questions, and every case must build
// a request from it exactly as a live run would, short of sending it.
function validateQuestions(questions, cases) {
  const faults = [];
  for (const name of ["intent", "danger", "greedy"]) {
    if (questions[name] === null || typeof questions[name] !== "object") {
      faults.push({ path: `questions.${name}`, message: "is missing" });
    }
  }
  if (faults.length > 0) return faults;
  cases.forEach(([label, list]) =>
    list.forEach((testCase, index) => {
      try {
        buildQuestions(offeredOptions(testCase), questions);
      } catch {
        faults.push({
          path: `${label}[${index}]`,
          message: "cannot build a request from the question set",
        });
      }
    }),
  );
  return faults;
}

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

export function loadDiagnostic(file = DIAGNOSTIC_FILE) {
  if (!existsSync(file)) {
    return null;
  }
  const ids = JSON.parse(readFileSync(file, "utf8")).case_ids;
  if (
    !Array.isArray(ids) ||
    !ids.every((id) => typeof id === "string" && id !== "") ||
    new Set(ids).size !== ids.length
  ) {
    throw new Error(
      `${path.relative(root, file)}: case_ids must be a list of distinct non-empty strings`,
    );
  }
  return ids;
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
    model: decision.model,
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

// The blind score over the listed cases alone, as numbers: `cases` is how many
// listed ids were scored, `listed` how many the file names.
export function subscore(records, ids) {
  const listed = new Set(ids);
  const picked = records.filter((record) => listed.has(record.id));
  let earned = 0;
  let possible = 0;
  for (const record of picked) {
    possible += WEIGHT[record.severity];
    if (record.passed) {
      earned += WEIGHT[record.severity];
    }
  }
  return {
    cases: picked.length,
    listed: listed.size,
    earned,
    possible,
    weighted: possible === 0 ? null : earned / possible,
    plainPass: picked.filter((record) => record.passed).length,
    severeMissCount: picked.filter(
      (record) => !record.passed && record.severity === "severe",
    ).length,
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

// The blind summary without a case id: each id list becomes its count. Block
// names are corpus sections, not cases, so the per-block counts stay.
export function aggregateSummary(summary) {
  const { severeMisses, modelMisses, floorMisses, floorRescues, ...rest } =
    summary;
  return {
    ...rest,
    severeMissCount: severeMisses.length,
    modelMissCount: modelMisses.length,
    floorMissCount: floorMisses.length,
    floorRescueCount: floorRescues.length,
  };
}

// The authored section keeps every scored case. The blind section keeps
// aggregates only (plan section 1: blind results reach a question-set author
// as numbers), so neither the report file nor the console ever holds a blind
// case id. The gate is judged on the full blind summary before it is reduced.
export function buildReport({
  authored,
  blind,
  instrument,
  when,
  diagnostic = null,
}) {
  const blindSummary = blind === null ? null : summarize(blind);
  return {
    when,
    instrument,
    authored: {
      gating: false,
      summary: summarize(authored),
      results: authored,
    },
    blind:
      blind === null
        ? null
        : {
            gating: true,
            summary: aggregateSummary(blindSummary),
            diagnostic:
              diagnostic === null ? null : subscore(blind, diagnostic),
          },
    gate: gateVerdict(blindSummary),
  };
}

function printSection(name, section, print = console.log) {
  const label = section.gating ? "gating" : "not gating";
  print(`\n${name} corpus (${label})`);
  for (const r of section.results ?? []) {
    const mark = r.passed ? "PASS" : "FAIL";
    const raw = r.lowConfidence ? ` raw=${r.rawIntent}` : "";
    print(
      `${mark} ${r.id.padEnd(30)} got=${r.got.padEnd(16)} conf=${r.confidence.toFixed(2)} ${r.outcome}${raw}`,
    );
    if (r.gatedOut.length > 0) {
      print(`     gated out in code: ${r.gatedOut.join(", ")}`);
    }
    if (!r.passed) {
      print(`     expected one of: ${r.expected.join(", ")}`);
    }
  }
  const s = section.summary;
  const count = (list, total) => total ?? list.length;
  print(
    `Severity-weighted ${s.earned}/${s.possible} (${(s.weighted * 100).toFixed(1)}%), plain ${s.plainPass}/${s.cases}`,
  );
  print(
    `Severe misses ${count(s.severeMisses, s.severeMissCount)}; model misses ${count(s.modelMisses, s.modelMissCount)}; floor misses ${count(s.floorMisses, s.floorMissCount)}; floor rescues ${count(s.floorRescues, s.floorRescueCount)}`,
  );
  print(
    `By block: ${Object.entries(s.byBlock)
      .map(([block, tally]) => `${block} ${tally.pass}/${tally.total}`)
      .join(", ")}`,
  );
  print(
    `Latency median ${s.latencyMedianMs} ms, max ${s.latencyMaxMs} ms; mean ${s.meanInputTokens} input tokens`,
  );
  const d = section.diagnostic;
  if (d !== undefined && d !== null) {
    const percent =
      d.weighted === null ? "n/a" : `${(d.weighted * 100).toFixed(1)}%`;
    print(
      `State-diagnostic subscore weighted ${d.earned}/${d.possible} (${percent}), plain ${d.plainPass}/${d.cases}; severe misses ${d.severeMissCount}; ${d.cases} of ${d.listed} listed cases scored`,
    );
  }
}

async function scoreAll(cases, questions, decideFn) {
  return Promise.all(
    cases.map(async (testCase) =>
      scoreCase(
        testCase,
        await decideFn(testCase.state, testCase.options, { questions }),
      ),
    ),
  );
}

// The live path behind the CLI, with the decider, corpora, report file and
// printer injectable so a test can run it offline. The diagnostic list loads
// before any call, so a malformed list costs nothing.
export async function scoreCorpora({
  questions,
  instrument,
  decideFn = decide,
  authored = loadAuthored(),
  blind = loadBlind(),
  diagnostic = blind === null ? null : loadDiagnostic(),
  reportFile = REPORT_FILE,
  print = console.log,
  when = new Date().toISOString(),
}) {
  const report = buildReport({
    when,
    instrument,
    authored: await scoreAll(authored, questions, decideFn),
    blind: blind === null ? null : await scoreAll(blind, questions, decideFn),
    diagnostic,
  });
  printSection("Authored", report.authored, print);
  if (report.blind === null) {
    print("\nBlind corpus: absent.");
  } else {
    printSection("Blind", report.blind, print);
  }
  print(`\nGate: ${report.gate.reason} (exit ${report.gate.exit})`);
  mkdirSync(path.dirname(reportFile), { recursive: true });
  writeFileSync(reportFile, JSON.stringify(report, null, 2));
  print(`Report: ${reportFile}`);
  print(
    "Corpus agreement only. It says nothing about whether the game is fun.",
  );
  return report;
}

function dryRun(questions) {
  const authored = loadAuthored();
  const blind = loadBlind();
  const corpora = [["authored", authored]];
  if (blind !== null) corpora.push(["blind", blind]);
  const faults = corpora.flatMap(([label, cases]) =>
    validateCases(cases, label),
  );
  if (faults.length === 0)
    faults.push(...validateQuestions(questions, corpora));
  const count = (label) =>
    faults.filter((fault) => fault.path.startsWith(label)).length;
  console.log(
    `Authored corpus: ${authored.length} cases, ${count("authored")} faults`,
  );
  console.log(
    blind === null
      ? "Blind corpus: absent."
      : `Blind corpus: ${blind.length} cases, ${count("blind")} faults`,
  );
  let diagnostic = null;
  try {
    diagnostic = loadDiagnostic();
  } catch (error) {
    faults.push({ path: "diagnostic", message: error.message });
  }
  if (diagnostic === null) {
    console.log("State-diagnostic subscore: no case list.");
  } else {
    const scored = new Set((blind ?? []).map((testCase) => testCase.id));
    const found = diagnostic.filter((id) => scored.has(id)).length;
    console.log(
      `State-diagnostic subscore: ${diagnostic.length} cases listed, ${found} in the blind corpus`,
    );
    if (found < diagnostic.length) {
      faults.push({
        path: "diagnostic",
        message: `${diagnostic.length - found} listed cases are not in the blind corpus`,
      });
    }
  }
  for (const fault of faults) console.log(`  ${fault.path} ${fault.message}`);
  console.log("Dry run: no Jev call was made and no report was written.");
  return faults.length === 0 ? 0 : 1;
}

async function main(argv) {
  let options;
  try {
    options = parseArgs(argv);
  } catch (error) {
    console.error(error.message);
    console.error(USAGE);
    process.exit(2);
  }
  if (options.help) {
    console.log(USAGE);
    process.exit(0);
  }
  const questions = loadQuestionSet();
  const instrument = instrumentIdentity(questions);
  console.log(
    `Question set ${questions.version} (${questions.status}), sha ${instrument.questions_sha.slice(0, 12)}`,
  );
  if (options.dryRun) {
    process.exit(dryRun(questions));
  }
  const report = await scoreCorpora({ questions, instrument });
  process.exit(report.gate.exit);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2));
}
