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
// simulation's 90 Hz. A round trip measured 223 ms, so frame-level control is
// not on the table and is not wanted; the game keeps flying the last intent
// while the next decision is in flight.
import { readFileSync } from "node:fs";

const ENDPOINT = "https://api.typesafe.ai/v1/systemone";
const MODEL = "jev-latest";
// Tuned against the corpus, not guessed: every case the corpus labels confidently
// lands well above this, and the one flat distribution falls below it.
export const CONFIDENCE_FLOOR = 0.05;

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

export function buildQuestions(options) {
  const criteria = {};
  for (const option of options) {
    criteria[option.id] = option.why;
  }
  return {
    // One narrow judgement: given what is reachable right now, what next?
    intent: {
      type: "choice",
      // Mechanics only. An earlier version of this instruction said that scrubbing
      // speed "costs you" and that time spent is "never free", which is a valuation,
      // not a rule. A negative control caught it: with that wording the model
      // declined a cache priced at zero scrap, 0.18 against 0.81. The sweep built on
      // it was measuring the prompt. State what the game does and let the judgement
      // be the judgement.
      instructions:
        "You are playing a rolling scrap mech in a roguelite stage. The mechanics: you damage enemies only by landing on them from above, or by ramming while above the fast speed tier, so speed is what makes combat possible. A difficulty tier rises on a fixed timer and raises enemy health, spawn rate and cache prices. Caches cost scrap and grant permanent stacking buffs that last the rest of the run. Scrap has no use other than buying caches, so scrap still held at the end of the run bought nothing. Choose the single best intent to hold for the next second or two.",
      criteria,
    },
    // Asked in the same request, so it costs one round trip rather than two.
    danger: {
      type: "score",
      instructions:
        "How much immediate danger is the player in right now, given health and the listed threats?",
      criteria: [
        "Safe: free to optimise purely for speed and loot",
        "Pressured: threats must be accounted for in the next move",
        "Critical: about to take a hit that matters, or low enough that another hit ends the run",
      ],
    },
    // Separate from the intent so policy can veto greed without re-asking.
    greedy: {
      type: "noul",
      instructions:
        "Would taking more loot or another cache right now cost more, in rising difficulty and risk, than the value it adds to this run?",
    },
  };
}

export async function decide(state, options, { key = apiKey(), signal } = {}) {
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
      questions: buildQuestions(offered),
    }),
    signal,
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Jev ${response.status}: ${body.slice(0, 300)}`);
  }
  const data = await response.json();
  // A Choice confidence near zero means the distribution is flat: the model has
  // no opinion, and acting on the top of a coin flip makes the player jitter
  // between intents on consecutive ticks. The corpus has a live example
  // (kicker-has-speed, confidence 0.01), so below the floor the player holds the
  // one intent that is always executable instead of committing to a guess.
  const confident = data.answers.intent.confidence >= CONFIDENCE_FLOOR;
  return {
    gatedOut: dropped,
    intent: confident ? data.answers.intent.choice : "push_objective",
    lowConfidence: !confident,
    rawIntent: data.answers.intent.choice,
    confidence: data.answers.intent.confidence,
    probabilities: data.answers.intent.probabilities,
    danger: data.answers.danger.score,
    greedy: data.answers.greedy.noul,
    latencyMs: Date.now() - started,
    usage: data.usage,
    model: data.model,
  };
}
