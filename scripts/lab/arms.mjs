// The three arms of plan section 2: `random` (seeded) is the floor, `scripted`
// (a rule ladder) is the baseline, and `jev` is the candidate. Each arm answers
// one snapshot at a time with {intent, source, meta}; `choose` receives the
// state file's whole jev block as `jev` beside the gated `offered` list. The
// harness never calls an arm when a single option is offered; it answers that
// snapshot `forced` with the arm's forcedMeta().
import {
  decide,
  instrumentIdentity,
  loadQuestionSet,
} from "../../tools/jev-player/decide.mjs";
import { ARMS, verdictKey } from "../../tools/jev-player/protocol/protocol.mjs";
import { openVerdictCache } from "./verdict-cache.mjs";

export const ARM_NAMES = Object.keys(ARMS);

// mulberry32: small, fast and the same sequence for the same seed on every
// platform, which is all the floor arm needs.
export function seededRandom(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function randomArm({ seed }) {
  if (!Number.isInteger(seed)) {
    throw new Error(`the random arm needs a whole-number seed, got ${seed}`);
  }
  const next = seededRandom(seed);
  return {
    name: "random",
    forcedMeta: () => ({ seed }),
    async choose({ offered }) {
      const pick = offered[Math.floor(next() * offered.length)];
      return { intent: pick.id, source: "seeded", meta: { seed } };
    },
  };
}

const nearest = (state) =>
  Math.min(
    ...state.threats.map((threat) => threat.distance_m ?? Infinity),
    Infinity,
  );

// First matching rung wins, and only among the offered options, so the ladder
// never names an intent the gate removed. The order is the baseline's whole
// policy: clear a hazard, finish, attack in reach, take the kicker at speed,
// then economy, then drive on.
const LADDER = [
  {
    rule: "hazard-imminent",
    intent: "evade_hazard",
    when: (state) =>
      state.threats.some(
        (threat) =>
          (threat.impact_in_s ?? Infinity) <= 1.5 ||
          threat.targets_current_position === true ||
          (threat.on_current_line === true && threat.closing === true),
      ),
  },
  { rule: "exit-open", intent: "start_exit", when: () => true },
  { rule: "ram-in-reach", intent: "ram_target", when: (s) => nearest(s) <= 20 },
  {
    rule: "stomp-in-reach",
    intent: "stomp_target",
    when: (s) => nearest(s) <= 12,
  },
  { rule: "kicker-at-speed", intent: "hit_kicker", when: () => true },
  { rule: "cache-in-reach", intent: "take_cache", when: () => true },
  { rule: "scrap-nearby", intent: "sweep_scrap", when: () => true },
  {
    rule: "low-health",
    intent: "retreat_regen",
    when: (s) => (s.self.hp ?? Infinity) <= 1,
  },
  { rule: "drive-on", intent: "push_objective", when: () => true },
];

function scriptedArm() {
  return {
    name: "scripted",
    forcedMeta: () => ({}),
    async choose({ state, offered }) {
      const ids = new Set(offered.map((option) => option.id));
      for (const rung of LADDER) {
        if (ids.has(rung.intent) && rung.when(state)) {
          return {
            intent: rung.intent,
            source: "rule",
            meta: { rule: rung.rule },
          };
        }
      }
      return {
        intent: offered[0].id,
        source: "rule",
        meta: { rule: "first-offered" },
      };
    },
  };
}

// An arm failure that tells the harness how to abort: `reason` is the
// protocol's abort.json reason and `cause` the run record's finer label.
function armFailure(message, cause, reason = "arm_error") {
  return Object.assign(new Error(message), { abort: { reason, cause } });
}

// The candidate. Each snapshot's verdict is looked up under verdictKey() first;
// a miss calls decideFn once and caches the answer. With `replay` a miss is a
// replay_miss abort and decideFn is never called, so a replay makes no network
// call by construction. `jev` on the answer tells the harness what to add to
// the record's Jev ledger: the resolved model, and the raw usage for a live
// call only.
function jevArm({
  questions = loadQuestionSet(),
  instrument = instrumentIdentity(questions),
  decideFn = decide,
  cache = openVerdictCache(),
  replay = false,
}) {
  if (instrument.questions_sha !== questions.sha) {
    throw new Error(
      `the instrument's questions_sha does not match question set ${questions.version}`,
    );
  }
  const meta = (key, verdict) => ({
    questions_sha: instrument.questions_sha,
    verdict_key: key,
    model: verdict.model ?? null,
    confidence: verdict.confidence,
    low_confidence: verdict.lowConfidence,
    raw_intent: verdict.rawIntent,
  });
  return {
    name: "jev",
    forcedMeta: () => ({ questions_sha: instrument.questions_sha }),
    async choose({ jev }) {
      const key = verdictKey(instrument, jev);
      const hit = await cache.get(key);
      if (hit !== null) {
        return {
          intent: hit.verdict.intent,
          source: "cache",
          meta: meta(key, hit.verdict),
          jev: { model: hit.verdict.model ?? null, cached: true },
        };
      }
      if (replay) {
        throw armFailure(
          `replay has no cached verdict ${key} in ${cache.directory}`,
          "replay_miss",
          "replay_miss",
        );
      }
      let verdict;
      try {
        verdict = await decideFn(jev.state, jev.options, { questions });
      } catch (error) {
        throw armFailure(`Jev call failed: ${error.message}`, "api_error");
      }
      await cache.put(key, { instrument, verdict });
      return {
        intent: verdict.intent,
        source: "live",
        meta: meta(key, verdict),
        jev: {
          model: verdict.model ?? null,
          usage: verdict.usage ?? {},
          cached: false,
        },
      };
    },
  };
}

const FACTORIES = { random: randomArm, scripted: scriptedArm, jev: jevArm };

export function createArm(name, options = {}) {
  const factory = FACTORIES[name];
  if (factory === undefined) {
    throw new Error(`unknown arm "${name}"; one of ${ARM_NAMES.join(", ")}`);
  }
  return factory(options);
}
