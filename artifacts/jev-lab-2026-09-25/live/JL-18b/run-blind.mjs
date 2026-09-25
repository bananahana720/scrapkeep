// JL-18b DoD 6: the blind corpus scored live under q2-neutral through
// score.mjs's scoreCorpora with the real decide(). Calls run one at a time,
// at most CAP in all, one retry per case; the ledger holds counts only.
import { writeFileSync } from "node:fs";
import path from "node:path";

import {
  decide,
  instrumentIdentity,
  loadQuestionSet,
} from "../../../../../tools/jev-player/decide.mjs";
import {
  loadBlind,
  loadDiagnostic,
  scoreCorpora,
} from "../../../../../tools/jev-player/score.mjs";

const CAP = 40;
const FIELDS = [
  "input_tokens",
  "output_tokens",
  "cache_read_input_tokens",
  "cache_creation_input_tokens",
];
const here = import.meta.dirname;
const questions = loadQuestionSet("q2-neutral");
const instrument = instrumentIdentity(questions);
const blind = loadBlind();
const diagnostic = loadDiagnostic();

const ledger = {
  questions_version: questions.version,
  instrument,
  cases: blind.length,
  cap: CAP,
  calls: 0,
  failed_calls: 0,
  retried_cases: 0,
  models: [],
  tokens: Object.fromEntries(FIELDS.map((field) => [field, null])),
  started_at: new Date().toISOString(),
  finished_at: null,
  failure: null,
};
let stopped = false;

async function ask(state, options, settings) {
  for (let attempt = 1; ; attempt += 1) {
    if (stopped) throw new Error("the run stopped after an earlier failure");
    if (ledger.calls >= CAP) {
      stopped = true;
      throw new Error(`the call cap of ${CAP} is reached`);
    }
    ledger.calls += 1;
    try {
      const decision = await decide(state, options, settings);
      if (!ledger.models.includes(decision.model ?? null))
        ledger.models.push(decision.model ?? null);
      for (const field of FIELDS) {
        const value = decision.usage?.[field];
        if (Number.isFinite(value))
          ledger.tokens[field] = (ledger.tokens[field] ?? 0) + value;
      }
      return decision;
    } catch (error) {
      ledger.failed_calls += 1;
      if (attempt >= 2) {
        stopped = true;
        throw error;
      }
      ledger.retried_cases += 1;
    }
  }
}

let queue = Promise.resolve();
const serial = (state, options, settings) => {
  const next = queue.then(() => ask(state, options, settings));
  queue = next.catch(() => {});
  return next;
};

let report = null;
try {
  report = await scoreCorpora({
    questions,
    instrument,
    decideFn: serial,
    authored: null,
    blind,
    diagnostic,
    reportFile: path.join(here, "corpus-score-q2-blind.json"),
    print: (line) => process.stdout.write(`${line}\n`),
    when: ledger.started_at,
  });
} catch (error) {
  ledger.failure = error.message;
}
await queue;
ledger.finished_at = new Date().toISOString();
writeFileSync(
  path.join(here, "ledger.json"),
  JSON.stringify(ledger, null, 2) + "\n",
);
process.stdout.write(
  `calls ${ledger.calls} (cap ${CAP}), failed ${ledger.failed_calls}, models ${ledger.models.join(", ")}\n`,
);
process.exitCode = report === null ? 5 : report.gate.exit;
