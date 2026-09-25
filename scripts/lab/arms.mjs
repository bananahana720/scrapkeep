// The three arms of plan section 2: `random` (seeded) is the floor, `scripted`
// (a rule ladder) is the baseline, and `jev` is the candidate. Each arm answers
// one snapshot at a time with {intent, source, meta}. The harness never calls
// an arm when a single option is offered; it answers that snapshot `forced`
// with the arm's forcedMeta().
import { instrumentIdentity } from "../../tools/jev-player/decide.mjs";
import { ARMS } from "../../tools/jev-player/protocol/protocol.mjs";

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

// JL-14 builds the real arm (verdict cache, replay, live calls). Until then any
// snapshot that needs a choice throws, the harness aborts the trial with
// arm_error, and nothing leaves the machine. Forced answers still need the
// instrument epoch, which comes from the pinned local question files.
function jevStub({ instrument = instrumentIdentity() }) {
  return {
    name: "jev",
    forcedMeta: () => ({ questions_sha: instrument.questions_sha }),
    async choose() {
      throw new Error("the jev arm is a stub until JL-14 builds it");
    },
  };
}

const FACTORIES = { random: randomArm, scripted: scriptedArm, jev: jevStub };

export function createArm(name, options = {}) {
  const factory = FACTORIES[name];
  if (factory === undefined) {
    throw new Error(`unknown arm "${name}"; one of ${ARM_NAMES.join(", ")}`);
  }
  return factory(options);
}
