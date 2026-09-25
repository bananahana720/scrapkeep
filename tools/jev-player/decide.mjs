// The decision layer of the Jev player.
//
// Jev never sees pixels and never invents an action. Code computes which
// actions are actually available from the current simulation state, and Jev
// chooses among them. That keeps every decision executable by construction:
// the model cannot pick a cache that is out of reach or a stomp with no
// target, because the option was never offered.
//
// The split that makes this work at all: Jev picks an *intent* that holds for
// a second or more, and deterministic steering code executes it at the
// simulation's 90 Hz. The last retained corpus run had a median round trip of
// 294 ms, so frame-level control is not on the table and is not wanted; the
// game keeps flying the last intent while the next decision is in flight.
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ENDPOINT = "https://api.typesafe.ai/v1/systemone";
const MODEL = "jev-latest";
// Provisional. It rests on one case (kicker-has-speed, confidence 0.02 in the
// retained run); the next lowest confidence was 0.25. Calibration from live
// intent churn is JL-21.
export const CONFIDENCE_FLOOR = 0.05;
// Bump when PRECONDITION or the all-gated fallback changes what Jev is offered.
export const GATE_VERSION = 1;

export const QUESTIONS_DIR = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "questions",
);
export const DEFAULT_QUESTION_SET = "q1-original";

// Published question files are immutable: new wording is a new file with a new
// pin in INDEX.json. A file whose bytes no longer match its pin refuses to
// load, so every result names the exact wording that produced it.
export function loadQuestionSet(
  version = DEFAULT_QUESTION_SET,
  dir = QUESTIONS_DIR,
) {
  const index = JSON.parse(readFileSync(path.join(dir, "INDEX.json"), "utf8"));
  const entry = index[version];
  if (entry === undefined) {
    throw new Error(`Question set ${version} is not pinned in INDEX.json.`);
  }
  const bytes = readFileSync(path.join(dir, entry.file));
  const sha = createHash("sha256").update(bytes).digest("hex");
  if (sha !== entry.sha256) {
    throw new Error(
      `${entry.file} sha256 ${sha} does not match its pin ${entry.sha256}.`,
    );
  }
  return { ...JSON.parse(bytes), sha };
}

export function instrumentIdentity(questions = loadQuestionSet()) {
  return {
    questions_sha: questions.sha,
    model: MODEL,
    confidence_floor: CONFIDENCE_FLOOR,
    gate_version: GATE_VERSION,
  };
}

export function apiKey() {
  if (process.env.TYPESAFE_API_KEY) {
    return process.env.TYPESAFE_API_KEY;
  }
  const file = "/home/andrew/.config/typesafe/.env";
  try {
    const found = readFileSync(file, "utf8").match(/TYPESAFE_API_KEY=(.+)/);
    if (found !== null) {
      return found[1].trim();
    } else {
      return null;
    }
  } catch {
    return null;
  }
}

// Every intent the steering layer knows how to execute. An option is offered
// only when the state says it is reachable, so this table is the whole
// vocabulary shared between the model and the game.
export const INTENTS = {
  push_objective:
    "Drive the fastest available line toward the current objective",
  sweep_scrap: "Detour onto the nearest scrap line and collect it",
  take_cache: "Open the cache within reach and spend the scrap",
  hit_kicker: "Commit to the kicker ramp to reach a high bench at speed",
  stomp_target: "Jump and land on a reachable enemy from above",
  ram_target: "Ram an enemy while above the fast speed tier",
  evade_hazard: "Break off the current line to clear an incoming hazard",
  retreat_regen: "Back off from all contact and let health regenerate",
  start_exit: "Begin the exit charge and hold the ring",
};

// Hard preconditions live in code, never in the prompt. The corpus caught this:
// offered a stomp while airborne with the air jump spent over a 22 m drop, the
// model took it, because nothing in the state made the action impossible rather
// than merely unwise. An action the engine cannot execute must never reach the
// question at all. These are physics, not judgement; judgement is what Jev is
// for, and it only gets to choose among the survivors.
export const PRECONDITION = {
  stomp_target: (state) =>
    state.self.grounded === true || state.self.air_jump_available === true,
  ram_target: (state) =>
    state.self.speed_tier === "fast" || state.self.speed_tier === "blazing",
  hit_kicker: (state, option) =>
    option.requires_speed_ms === undefined ||
    state.self.speed_ms >= option.requires_speed_ms,
  start_exit: (state) =>
    state.objective === undefined || state.objective.inside_ring !== false,
};

export function gateOptions(state, options) {
  const kept = [];
  const dropped = [];
  for (const option of options) {
    const rule = PRECONDITION[option.id];
    if (rule === undefined || rule(state, option) === true) {
      kept.push(option);
    } else {
      dropped.push(option.id);
    }
  }
  return { kept, dropped };
}

// The wording and its rationale live in questions/<version>.json. Only the
// intent's criteria come from the offered options.
export function buildQuestions(options, questions = loadQuestionSet()) {
  const criteria = {};
  for (const option of options) {
    criteria[option.id] = option.why;
  }
  return {
    intent: { ...questions.intent, criteria },
    danger: { ...questions.danger },
    greedy: { ...questions.greedy },
  };
}

// A Choice confidence near zero means a flat distribution. Acting on the top of
// it makes the player jitter between intents on consecutive ticks, so below the
// floor the player holds the one intent that is always executable. The raw
// choice is kept so a scorer can tell a floor-induced miss from a model miss.
export function applyFloor(answer, floor = CONFIDENCE_FLOOR) {
  const confident = answer.confidence >= floor;
  return {
    intent: confident ? answer.choice : "push_objective",
    lowConfidence: !confident,
    rawIntent: answer.choice,
  };
}

export async function decide(
  state,
  options,
  { key = apiKey(), signal, questions = loadQuestionSet() } = {},
) {
  if (key === null) {
    throw new Error("No TypeSafe API key; set TYPESAFE_API_KEY.");
  }
  if (options.length === 0) {
    throw new Error("decide() needs at least one available option.");
  }
  const { kept, dropped } = gateOptions(state, options);
  // push_objective is always executable, so a fully gated set still has a move.
  const offered =
    kept.length > 0
      ? kept
      : [{ id: "push_objective", why: INTENTS.push_objective }];
  const started = Date.now();
  const response = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      state,
      questions: buildQuestions(offered, questions),
    }),
    signal,
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Jev ${response.status}: ${body.slice(0, 300)}`);
  }
  const data = await response.json();
  const { intent, lowConfidence, rawIntent } = applyFloor(data.answers.intent);
  return {
    gatedOut: dropped,
    intent,
    lowConfidence,
    rawIntent,
    confidence: data.answers.intent.confidence,
    probabilities: data.answers.intent.probabilities,
    // Recorded for analysis only; no decision reads danger or greedy.
    danger: data.answers.danger.score,
    greedy: data.answers.greedy.noul,
    latencyMs: Date.now() - started,
    usage: data.usage,
    model: data.model,
  };
}
