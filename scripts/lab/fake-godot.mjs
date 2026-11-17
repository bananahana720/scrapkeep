// A stand-in for one Godot trial (JL-11). It plays the Godot side of protocol
// v1 (tools/jev-player/protocol/PROTOCOL.md) from a scripted state sequence:
// hello, one state per snapshot, block for the matching intent, apply it
// hold_ticks later, then done.json with the trace hash. It simulates nothing;
// the snapshots are fixed, so a harness bug cannot hide behind physics.
//
// Switches for the harness's failure paths, each naming a snapshot seq:
//   --stall-at N    stop writing before state-N and hang (the Node watchdog)
//   --crash-at N    exit 3 before state-N with no done.json or error.json
//   --invalid-at N  write a state-N that fails validateState()
//   --error-at N    write error.json {code: internal} at state-N and exit 1
// abort.json is always honoured, at every snapshot and while blocking.
//
//   node scripts/lab/fake-godot.mjs --io <dir> --scenario <name> [--seed N]
import { appendFile, readFile, rename, writeFile } from "node:fs/promises";
import { existsSync, realpathSync } from "node:fs";
import path from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { fileURLToPath } from "node:url";

import { INTENTS } from "../../tools/jev-player/decide.mjs";
import {
  ERROR_EXIT,
  fileName,
  PROTOCOL,
  TIMING,
  traceHash,
  validateIntent,
  writeAtomic,
} from "../../tools/jev-player/protocol/protocol.mjs";

const tierOf = (speed) =>
  speed < 8 ? "walk" : speed < 16 ? "cruise" : speed < 24 ? "fast" : "blazing";
const self = (speed_ms, extra = {}) => ({
  speed_ms,
  speed_tier: tierOf(speed_ms),
  grounded: true,
  air_jump_available: true,
  ...extra,
});
const kicker = (requires_speed_ms) => ({ id: "hit_kicker", requires_speed_ms });
const snap = (selfBlock, objective, options, threats = []) => ({
  self: selfBlock,
  threats,
  objective,
  options,
});
const pad = (distance_m) => ({ kind: "pad", distance_m });
const dummy = (distance_m) => ({ kind: "dummy", distance_m, closing: false });
const pillar = (distance_m, onLine) => ({
  kind: "pillar",
  distance_m,
  on_current_line: onLine,
  closing: onLine,
});

// Plan section 3's ball-lab scenario names, each a short scripted sequence. The
// mix is deliberate: some snapshots offer one option (forced), some are gated
// down to the push_objective fallback, the rest need an arm's choice.
const base = {
  "downhill-run": [
    snap(self(4), pad(120), ["push_objective", kicker(20)]),
    snap(self(12.5), pad(96), ["push_objective", kicker(20)]),
    snap(
      self(21),
      pad(70),
      ["push_objective", kicker(20), "evade_hazard"],
      [{ kind: "boulder", distance_m: 14, impact_in_s: 1.2, closing: true }],
    ),
    snap(self(27.5), pad(38), ["push_objective", kicker(20)]),
  ],
  "run-to-pad": [
    snap(self(3), pad(40), ["push_objective"]),
    snap(self(9.5), pad(28), ["push_objective"]),
    snap(self(14), pad(9), ["push_objective"]),
  ],
  "bench-climb": [
    snap(self(8), { kind: "bench", distance_m: 60 }, [
      "push_objective",
      kicker(26),
    ]),
    snap(self(18), { kind: "bench", distance_m: 41 }, [
      "push_objective",
      kicker(26),
    ]),
    snap(self(27), { kind: "bench", distance_m: 22 }, [
      "push_objective",
      kicker(26),
    ]),
  ],
  "kicker-gap": [
    snap(self(14), { kind: "gap", distance_m: 50 }, [kicker(20)]),
    snap(self(22), { kind: "gap", distance_m: 30 }, [kicker(20)]),
    snap(self(28), { kind: "gap", distance_m: 11 }, [kicker(20)]),
  ],
  "dummy-knock": [
    snap(
      self(10),
      pad(80),
      ["push_objective", "stomp_target", "ram_target"],
      [dummy(18)],
    ),
    snap(
      self(18),
      pad(64),
      ["push_objective", "stomp_target", "ram_target"],
      [dummy(9)],
    ),
    snap(
      self(22, { grounded: false, air_jump_available: false }),
      pad(50),
      ["push_objective", "stomp_target", "ram_target"],
      [dummy(6)],
    ),
  ],
  "pillar-weave": [
    snap(
      self(12),
      pad(90),
      ["push_objective", "evade_hazard"],
      [pillar(15, true)],
    ),
    snap(
      self(14),
      pad(72),
      ["push_objective", "evade_hazard"],
      [pillar(22, false)],
    ),
    snap(
      self(15),
      pad(55),
      ["push_objective", "evade_hazard"],
      [pillar(8, true)],
    ),
    snap(
      self(16.5),
      pad(37),
      ["push_objective", "evade_hazard"],
      [pillar(30, false)],
    ),
  ],
};
// soak: 120 snapshots, one a second, cycling through the others' shapes.
const cycle = Object.values(base).flat();
export const SCENARIOS = {
  ...base,
  soak: Array.from({ length: 120 }, (_, i) => cycle[i % cycle.length]),
};

function jevBlock(spec, scenario, tick) {
  return {
    state: {
      self: spec.self,
      stage: {
        name: scenario,
        time_s: Math.floor(tick / TIMING.tick_hz),
        tier: 1,
      },
      threats: spec.threats,
      objective: spec.objective,
    },
    options: spec.options.map((option) => {
      const { id, ...rest } =
        typeof option === "string" ? { id: option } : option;
      return { id, why: INTENTS[id], ...rest };
    }),
  };
}

const round = (value) => Number(value.toFixed(2));
const traceLine = (tick) => ({
  tick,
  kind: "trace",
  pos: [0, 0.5, round(-tick * 0.2)],
  vel: [0, 0, -18],
  tier: "walk",
  grounded: true,
});

export async function play({
  io,
  scenario,
  seed = 0,
  stallAt = null,
  crashAt = null,
  invalidAt = null,
  errorAt = null,
  pollMs = 5,
}) {
  const snapshots = SCENARIOS[scenario];
  if (snapshots === undefined) {
    throw new Error(`fake-godot has no scenario "${scenario}"`);
  }
  const { tick_hz, snapshot_every: every, hold_ticks: hold } = TIMING;
  const eventsTmp = path.join(io, "events.ndjson.tmp");
  const at = (name) => path.join(io, name);
  await writeFile(eventsTmp, "");
  let nextTrace = 0;
  let written = 0;
  let held = null;
  const emit = (line) => appendFile(eventsTmp, JSON.stringify(line) + "\n");
  // Trace lines strictly before `tick`, so an intent applied at `tick` is
  // written before that tick's trace line.
  const traceUntil = async (tick) => {
    while (nextTrace < tick) {
      await emit(traceLine(nextTrace));
      nextTrace += tick_hz / 10;
    }
  };
  const closeEvents = async (tick) => {
    await traceUntil(tick + 1);
    await rename(eventsTmp, at("events.ndjson"));
    return readFile(at("events.ndjson"), "utf8");
  };
  const finish = async (reason, tick) => {
    const text = await closeEvents(tick);
    await writeAtomic(at("done.json"), {
      protocol: PROTOCOL,
      reason,
      tick,
      snapshots: written,
      trace_hash: traceHash(text),
    });
    return 0;
  };
  const fail = async (code, seq, tick, message) => {
    await closeEvents(tick);
    await writeAtomic(at("error.json"), {
      protocol: PROTOCOL,
      code,
      seq,
      tick,
      message,
    });
    return ERROR_EXIT[code];
  };

  await writeAtomic(at("hello.json"), {
    protocol: PROTOCOL,
    sketch: "fake-godot",
    scenario,
    seed,
    physics_mode: "kinematic",
    godot: "fake",
    ...TIMING,
  });

  for (let seq = 0; seq < snapshots.length; seq += 1) {
    const tick = seq * every;
    if (existsSync(at("abort.json"))) return finish("aborted", tick);
    if (stallAt === seq) {
      setInterval(() => {}, 60_000);
      return new Promise(() => {});
    }
    if (crashAt === seq) return 3;
    if (errorAt === seq) {
      return fail("internal", seq, tick, "fake-godot was told to fail here");
    }
    const state = {
      protocol: PROTOCOL,
      seq,
      tick,
      held,
      jev: jevBlock(snapshots[seq], scenario, tick),
      sim: { pos: [0, 0.5, round(-tick * 0.2)], vel: [0, 0, -18] },
    };
    if (invalidAt === seq) state.jev.state.self.speed_ms = 17.53;
    await writeAtomic(at(fileName("state", seq)), state);
    written += 1;

    // Keep flying the held intent for hold_ticks, then block for intent-seq.
    const due = tick + hold;
    const intentFile = at(fileName("intent", seq));
    const deadline = Date.now() + TIMING.intent_timeout_s * 1000;
    let text = null;
    while (text === null) {
      if (existsSync(at("abort.json"))) return finish("aborted", due);
      if (existsSync(intentFile)) {
        text = await readFile(intentFile, "utf8");
      } else if (Date.now() > deadline) {
        return fail(
          "intent_timeout",
          seq,
          due,
          `no ${fileName("intent", seq)}`,
        );
      } else {
        await sleep(pollMs);
      }
    }
    let intent;
    let errors;
    try {
      intent = JSON.parse(text);
      errors = validateIntent(intent, { state });
    } catch {
      errors = [{ path: "(root)", message: "is not JSON" }];
    }
    if (errors.length > 0) {
      const first = errors[0];
      return fail("intent_invalid", seq, due, `${first.path} ${first.message}`);
    }
    await traceUntil(due);
    await emit({ tick: due, kind: "intent", seq, intent: intent.intent });
    held = intent.intent;
  }
  return finish("complete", (snapshots.length - 1) * every + hold);
}

function parseArgs(argv) {
  const options = {};
  const numbers = {
    "--seed": "seed",
    "--stall-at": "stallAt",
    "--crash-at": "crashAt",
    "--invalid-at": "invalidAt",
    "--error-at": "errorAt",
    "--poll-ms": "pollMs",
  };
  for (let i = 0; i < argv.length; i += 2) {
    const [flag, value] = [argv[i], argv[i + 1]];
    if (flag === "--io") {
      options.io = value;
    } else if (flag === "--scenario") {
      options.scenario = value;
    } else if (
      Object.hasOwn(numbers, flag) &&
      Number.isInteger(Number(value))
    ) {
      options[numbers[flag]] = Number(value);
    } else {
      throw new Error(
        `fake-godot: unknown or malformed argument ${flag} ${value}`,
      );
    }
  }
  if (options.io === undefined || options.scenario === undefined) {
    throw new Error("fake-godot needs --io <dir> and --scenario <name>");
  }
  return options;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const code = await play(parseArgs(process.argv.slice(2)));
    process.exit(code);
  } catch (error) {
    console.error(error.message);
    process.exit(2);
  }
}
