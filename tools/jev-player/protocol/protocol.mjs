// Protocol v1: the file lockstep between one Godot trial and the Node harness.
// PROTOCOL.md is the prose contract; this module is its executable half. Each
// validator returns a list of {path, message}; an empty list means valid.
// Paths are language-neutral so the Godot side (JL-09) can report the same ones.
import { createHash } from "node:crypto";
import { open, rename, rm } from "node:fs/promises";

import { gateOptions, INTENTS } from "../decide.mjs";

export const PROTOCOL = "scrapkeep-jev/1";

// Plan section 2, "Timing". hello.json echoes these, so a trial run with a
// different schedule says so in its own record.
export const TIMING = {
  tick_hz: 90,
  snapshot_every: 90,
  hold_ticks: 26,
  intent_timeout_s: 30,
};

// Which sources each arm may report. `forced` is shared: one offered option
// means no arm chooses anything.
export const ARMS = {
  random: ["seeded", "forced"],
  scripted: ["rule", "forced"],
  jev: ["live", "cache", "forced"],
};

// Godot's exit code for each error.json code. A clean finish exits 0.
export const ERROR_EXIT = { internal: 1, intent_invalid: 4, intent_timeout: 5 };
export const ABORT_REASONS = ["interrupted", "arm_error", "replay_miss"];
export const DONE_REASONS = ["complete", "aborted"];
export const SPEED_TIERS = ["walk", "cruise", "fast", "blazing"];
export const ANOMALIES = ["nan", "tunnel", "out_of_bounds", "overspeed"];

const SHA = /^[0-9a-f]{64}$/;
const FILE = /^(state|intent)-(\d{6})\.json$/;

export function fileName(type, seq) {
  return `${type}-${String(seq).padStart(6, "0")}.json`;
}

// --- small checkers --------------------------------------------------------

const isObject = (value) =>
  value !== null && typeof value === "object" && !Array.isArray(value);
const onGrid = (value, step) =>
  Number.isFinite(value) &&
  Math.abs(value / step - Math.round(value / step)) < 1e-9;

// A field kind is a function (value) -> message | null.
const kinds = {
  string: (v) =>
    typeof v === "string" && v !== "" ? null : "must be a non-empty string",
  boolean: (v) => (typeof v === "boolean" ? null : "must be a boolean"),
  int: (v) =>
    Number.isInteger(v) && v >= 0 ? null : "must be a whole number >= 0",
  anyInt: (v) => (Number.isInteger(v) ? null : "must be a whole number"),
  // Corpus quantisation: tenths for speeds and countdowns, whole numbers for
  // distances, damage, time, tiers and scrap. Off-grid values would split the
  // verdict cache over noise.
  tenth: (v) =>
    onGrid(v, 0.1) && v >= 0 ? null : "must be >= 0 in steps of 0.1",
  number: (v) => (Number.isFinite(v) ? null : "must be a finite number"),
  sha: (v) =>
    typeof v === "string" && SHA.test(v)
      ? null
      : "must be 64 lowercase hex characters",
  vec3: (v) =>
    Array.isArray(v) && v.length === 3 && v.every(Number.isFinite)
      ? null
      : "must be three finite numbers",
  protocol: (v) => (v === PROTOCOL ? null : `must be "${PROTOCOL}"`),
  tier: (v) =>
    SPEED_TIERS.includes(v) ? null : `must be one of ${SPEED_TIERS.join(", ")}`,
  intentId: (v) =>
    Object.hasOwn(INTENTS, v) ? null : "must be an intent id from decide.mjs",
  heldIntent: (v) =>
    v === null || Object.hasOwn(INTENTS, v)
      ? null
      : "must be null or an intent id from decide.mjs",
};
const oneOf = (list) => (v) =>
  list.includes(v) ? null : `must be one of ${list.join(", ")}`;

// Checks `value` against a closed shape. `required` and `optional` map field
// names to kinds; any other key is an error, because every byte of the jev
// block feeds the verdict-cache key and every event line feeds trace_hash.
function shape(errors, at, value, required, optional = {}) {
  if (!isObject(value)) {
    errors.push({ path: at || "(root)", message: "must be an object" });
    return false;
  }
  const join = (key) => (at === "" ? key : `${at}.${key}`);
  for (const key of Object.keys(required)) {
    if (!Object.hasOwn(value, key)) {
      errors.push({ path: join(key), message: "is required" });
    }
  }
  for (const [key, field] of Object.entries(value)) {
    const known = Object.hasOwn(required, key) || Object.hasOwn(optional, key);
    const kind = Object.hasOwn(required, key) ? required[key] : optional[key];
    if (!known) {
      errors.push({ path: join(key), message: "is not a protocol v1 field" });
    } else if (typeof kind === "function") {
      const message = kind(field);
      if (message !== null) errors.push({ path: join(key), message });
    }
  }
  return true;
}

function list(errors, at, value, { min = 0, max = Infinity } = {}) {
  if (!Array.isArray(value)) {
    errors.push({ path: at, message: "must be an array" });
    return false;
  }
  if (value.length < min || value.length > max) {
    const bound = max === Infinity ? `at least ${min}` : `${min} to ${max}`;
    errors.push({ path: at, message: `must hold ${bound} entries` });
    return false;
  }
  return true;
}

// --- the jev block: the corpus state and option schema ---------------------

const SELF = {
  required: {
    speed_ms: kinds.tenth,
    speed_tier: kinds.tier,
    grounded: kinds.boolean,
  },
  optional: {
    hp: kinds.int,
    air_jump_available: kinds.boolean,
    location: kinds.string,
    over: kinds.string,
  },
};
const STAGE = {
  required: { name: kinds.string, time_s: kinds.int, tier: kinds.int },
};
const THREAT = {
  required: { kind: kinds.string },
  optional: {
    distance_m: kinds.int,
    damage: kinds.int,
    closing: kinds.boolean,
    impact_in_s: kinds.tenth,
    arc_lands_in_s: kinds.tenth,
    water_rises_in_s: kinds.tenth,
    on_current_line: kinds.boolean,
    targets_current_position: kinds.boolean,
    telegraphing: kinds.boolean,
    below: kinds.boolean,
    effect: kinds.string,
    lands_on: kinds.string,
  },
};
const OBJECTIVE = {
  required: { kind: kinds.string, distance_m: kinds.int },
  optional: { inside_ring: kinds.boolean, charge_started: kinds.boolean },
};
const OPTION = {
  required: { id: kinds.intentId, why: kinds.string },
  optional: { requires_speed_ms: kinds.tenth },
};
// Ball-lab synthesises the nearest three enemies within 60 m; the corpus never
// needs more. A longer list would be a protocol change, not a longer prompt.
const MAX_THREATS = 3;

function checkJev(errors, jev) {
  if (!shape(errors, "jev", jev, { state: null, options: null })) return;
  const { state, options } = jev;
  if (
    shape(
      errors,
      "jev.state",
      state,
      { self: null, stage: null, threats: null, objective: null },
      { scrap: null, buffs: null },
    )
  ) {
    shape(errors, "jev.state.self", state.self, SELF.required, SELF.optional);
    shape(errors, "jev.state.stage", state.stage, STAGE.required);
    if (
      list(errors, "jev.state.threats", state.threats, { max: MAX_THREATS })
    ) {
      state.threats.forEach((threat, i) =>
        shape(
          errors,
          `jev.state.threats[${i}]`,
          threat,
          THREAT.required,
          THREAT.optional,
        ),
      );
    }
    shape(
      errors,
      "jev.state.objective",
      state.objective,
      OBJECTIVE.required,
      OBJECTIVE.optional,
    );
    if (Object.hasOwn(state, "scrap")) {
      shape(errors, "jev.state.scrap", state.scrap, { held: kinds.int });
    }
    if (
      Object.hasOwn(state, "buffs") &&
      list(errors, "jev.state.buffs", state.buffs)
    ) {
      state.buffs.forEach((buff, i) => {
        const message = kinds.string(buff);
        if (message !== null)
          errors.push({ path: `jev.state.buffs[${i}]`, message });
      });
    }
  }
  if (list(errors, "jev.options", options, { min: 1 })) {
    const seen = new Set();
    options.forEach((option, i) => {
      shape(
        errors,
        `jev.options[${i}]`,
        option,
        OPTION.required,
        OPTION.optional,
      );
      if (seen.has(option?.id)) {
        errors.push({
          path: `jev.options[${i}].id`,
          message: "is offered twice",
        });
      }
      seen.add(option?.id);
    });
  }
}

// The options an arm may choose from: decide.mjs's precondition gate, with the
// same fallback when everything is gated out. `forced` is judged on this list.
export function offeredOptions(jev) {
  const { kept } = gateOptions(jev.state, jev.options);
  return kept.length > 0
    ? kept
    : [{ id: "push_objective", why: INTENTS.push_objective }];
}

// --- one validator per message type ----------------------------------------

export function validateHello(message) {
  const errors = [];
  const ok = shape(errors, "", message, {
    protocol: kinds.protocol,
    sketch: kinds.string,
    scenario: kinds.string,
    seed: kinds.anyInt,
    physics_mode: kinds.string,
    godot: kinds.string,
    tick_hz: kinds.int,
    snapshot_every: kinds.int,
    hold_ticks: kinds.int,
    intent_timeout_s: kinds.int,
  });
  if (ok && errors.length === 0) {
    for (const key of ["tick_hz", "snapshot_every", "intent_timeout_s"]) {
      if (message[key] === 0)
        errors.push({ path: key, message: "must be > 0" });
    }
    if (message.hold_ticks >= message.snapshot_every) {
      errors.push({
        path: "hold_ticks",
        message:
          "must be below snapshot_every, or the next snapshot lands before the intent applies",
      });
    }
  }
  return errors;
}

export function validateState(message) {
  const errors = [];
  const ok = shape(errors, "", message, {
    protocol: kinds.protocol,
    seq: kinds.int,
    tick: kinds.int,
    held: kinds.heldIntent,
    jev: null,
    sim: null,
  });
  if (!ok) return errors;
  if (Object.hasOwn(message, "jev")) checkJev(errors, message.jev);
  if (Object.hasOwn(message, "sim")) {
    // sim is Godot's own record of the moment: never shown to Jev, never in the
    // cache key, so extra keys are allowed as long as there is no wall clock.
    if (isObject(message.sim)) {
      for (const key of ["pos", "vel"]) {
        const text = kinds.vec3(message.sim[key]);
        if (text !== null) errors.push({ path: `sim.${key}`, message: text });
      }
    } else {
      errors.push({ path: "sim", message: "must be an object" });
    }
  }
  return errors;
}

// `context.state`, when given, is the state-NNNNNN.json this intent answers.
// Without it only the message itself is checked.
export function validateIntent(message, context = {}) {
  const errors = [];
  const ok = shape(errors, "", message, {
    protocol: kinds.protocol,
    seq: kinds.int,
    intent: kinds.intentId,
    arm: oneOf(Object.keys(ARMS)),
    source: kinds.string,
    meta: null,
  });
  if (!ok) return errors;
  const sources = ARMS[message.arm];
  if (sources !== undefined && !sources.includes(message.source)) {
    errors.push({
      path: "source",
      message: `must be one of ${sources.join(", ")} for the ${message.arm} arm`,
    });
  }
  if (!isObject(message.meta)) {
    errors.push({ path: "meta", message: "must be an object" });
  } else if (message.arm === "jev") {
    // The instrument epoch: every jev decision names the exact wording asked.
    const text = kinds.sha(message.meta.questions_sha);
    if (text !== null) {
      errors.push({
        path: "meta.questions_sha",
        message: `is required for the jev arm and ${text}`,
      });
    }
  }
  const { state } = context;
  if (state !== undefined && state?.jev !== undefined) {
    if (message.seq !== state.seq) {
      errors.push({
        path: "seq",
        message: `must match the state's seq ${state.seq}`,
      });
    }
    const offered = offeredOptions(state.jev).map((option) => option.id);
    // Below the confidence floor decide.mjs holds push_objective, offered or not.
    const floor = message.arm === "jev" && message.source !== "forced";
    if (
      !offered.includes(message.intent) &&
      !(floor && message.intent === "push_objective")
    ) {
      errors.push({
        path: "intent",
        message: `must be one of the offered options ${offered.join(", ")}`,
      });
    }
    if (offered.length === 1 && message.source !== "forced") {
      errors.push({
        path: "source",
        message: "must be forced when a single option is offered",
      });
    } else if (offered.length > 1 && message.source === "forced") {
      errors.push({
        path: "source",
        message: `cannot be forced with ${offered.length} options offered`,
      });
    }
  }
  return errors;
}

export function validateError(message) {
  const errors = [];
  shape(errors, "", message, {
    protocol: kinds.protocol,
    code: oneOf(Object.keys(ERROR_EXIT)),
    seq: (v) => (v === null ? null : kinds.int(v)),
    tick: kinds.int,
    message: kinds.string,
  });
  return errors;
}

export function validateAbort(message) {
  const errors = [];
  shape(
    errors,
    "",
    message,
    { protocol: kinds.protocol, reason: oneOf(ABORT_REASONS) },
    { message: kinds.string },
  );
  return errors;
}

export function validateDone(message) {
  const errors = [];
  shape(errors, "", message, {
    protocol: kinds.protocol,
    reason: oneOf(DONE_REASONS),
    tick: kinds.int,
    snapshots: kinds.int,
    trace_hash: kinds.sha,
  });
  return errors;
}

// Each kind's fields beyond {tick, kind}. Closed, so no wall-clock value can
// slip into the bytes trace_hash covers.
const EVENTS = {
  trace: {
    pos: kinds.vec3,
    vel: kinds.vec3,
    tier: kinds.tier,
    grounded: kinds.boolean,
  },
  intent: { seq: kinds.int, intent: kinds.intentId },
  tier: { from: kinds.tier, to: kinds.tier },
  takeoff: {},
  landing: {},
  knock: { strength: kinds.number },
  stuck_begin: {},
  stuck_end: {},
  anomaly: { what: oneOf(ANOMALIES) },
};
export const EVENT_KINDS = Object.keys(EVENTS);

export function validateEvents(text) {
  const errors = [];
  if (typeof text !== "string") {
    return [{ path: "events", message: "must be NDJSON text" }];
  }
  if (text === "") return errors;
  if (!text.endsWith("\n")) {
    errors.push({ path: "events", message: "must end with a newline" });
  }
  let last = -1;
  text
    .replace(/\n$/, "")
    .split("\n")
    .forEach((line, i) => {
      const at = `events[${i}]`;
      let event;
      try {
        event = JSON.parse(line);
      } catch {
        errors.push({ path: at, message: "is not one JSON value" });
        return;
      }
      const fields = EVENTS[event?.kind];
      if (fields === undefined) {
        errors.push({
          path: `${at}.kind`,
          message: `must be one of ${EVENT_KINDS.join(", ")}`,
        });
        return;
      }
      shape(errors, at, event, { tick: kinds.int, kind: null, ...fields });
      if (Number.isInteger(event.tick)) {
        if (event.tick < last) {
          errors.push({
            path: `${at}.tick`,
            message: `goes back from ${last}`,
          });
        }
        last = Math.max(last, event.tick);
      }
    });
  return errors;
}

export const validators = {
  hello: validateHello,
  state: validateState,
  intent: validateIntent,
  error: validateError,
  abort: validateAbort,
  done: validateDone,
  events: validateEvents,
};

// --- a whole <io> directory ------------------------------------------------

export function traceHash(eventsText) {
  return createHash("sha256").update(eventsText, "utf8").digest("hex");
}

// `files` maps each file name in one <io> directory to its text. Checks every
// message, then the rules that span files: contiguous snapshots on the tick
// schedule, each intent applied exactly hold_ticks after its snapshot, the held
// intent carried into the next snapshot, and done's trace_hash.
export function validateTrial(files) {
  const errors = [];
  const add = (file, list) =>
    list.forEach((error) =>
      errors.push({ path: `${file}:${error.path}`, message: error.message }),
    );
  const parse = (file) => {
    try {
      return JSON.parse(files[file]);
    } catch {
      errors.push({ path: `${file}:(root)`, message: "is not JSON" });
      return undefined;
    }
  };
  const has = (file) => Object.hasOwn(files, file);
  const states = [];
  const intents = [];
  for (const file of Object.keys(files).sort()) {
    if (file.endsWith(".tmp")) continue; // a writer's unfinished file
    const numbered = FILE.exec(file);
    if (numbered !== null) {
      (numbered[1] === "state" ? states : intents)[Number(numbered[2])] = file;
    } else if (
      ![
        "hello.json",
        "error.json",
        "abort.json",
        "done.json",
        "events.ndjson",
      ].includes(file)
    ) {
      errors.push({ path: file, message: "is not a protocol v1 file" });
    }
  }
  if (!has("hello.json")) {
    errors.push({ path: "hello.json", message: "is required" });
    return errors;
  }
  const hello = parse("hello.json");
  add("hello.json", validateHello(hello));
  if (errors.length > 0) return errors;
  const { snapshot_every: every, hold_ticks: hold } = hello;

  const parsedStates = [];
  for (let seq = 0; seq < states.length; seq += 1) {
    const file = fileName("state", seq);
    if (states[seq] === undefined) {
      errors.push({
        path: file,
        message: "is missing; snapshots must be contiguous from 0",
      });
      continue;
    }
    const state = parse(file);
    parsedStates[seq] = state;
    add(file, validateState(state));
    if (state?.seq !== seq)
      errors.push({ path: `${file}:seq`, message: `must be ${seq}` });
    if (state?.tick !== seq * every) {
      errors.push({
        path: `${file}:tick`,
        message: `must be ${seq * every} (seq x snapshot_every)`,
      });
    }
  }
  const parsedIntents = [];
  intents.forEach((file, seq) => {
    const intent = parse(file);
    parsedIntents[seq] = intent;
    if (parsedStates[seq] === undefined) {
      errors.push({
        path: file,
        message: "answers a snapshot that does not exist",
      });
      add(file, validateIntent(intent));
    } else {
      add(file, validateIntent(intent, { state: parsedStates[seq] }));
    }
  });
  parsedStates.forEach((state, seq) => {
    const expected =
      seq === 0 ? null : (parsedIntents[seq - 1]?.intent ?? null);
    if (state !== undefined && state.held !== expected) {
      errors.push({
        path: `${fileName("state", seq)}:held`,
        message: `must be ${JSON.stringify(expected)}, the intent in force at this tick`,
      });
    }
  });

  if (has("error.json") && has("done.json")) {
    errors.push({ path: "done.json", message: "cannot sit beside error.json" });
  }
  let events = [];
  if (has("events.ndjson")) {
    add("events.ndjson", validateEvents(files["events.ndjson"]));
    events = files["events.ndjson"]
      .split("\n")
      .filter((line) => line !== "")
      .map((line) => {
        try {
          return JSON.parse(line);
        } catch {
          return {};
        }
      });
  } else if (has("done.json") || has("error.json")) {
    errors.push({
      path: "events.ndjson",
      message: "must be renamed into place before done.json or error.json",
    });
  }
  events.forEach((event, i) => {
    if (event.kind !== "intent") return;
    const state = parsedStates[event.seq];
    if (parsedIntents[event.seq]?.intent !== event.intent) {
      errors.push({
        path: `events.ndjson:events[${i}].intent`,
        message: "must match the intent file it applies",
      });
    }
    if (state !== undefined && event.tick !== state.tick + hold) {
      errors.push({
        path: `events.ndjson:events[${i}].tick`,
        message: `must be ${state.tick + hold}, hold_ticks after snapshot ${event.seq}`,
      });
    }
  });

  if (has("done.json")) {
    const done = parse("done.json");
    add("done.json", validateDone(done));
    if (done?.snapshots !== parsedStates.length) {
      errors.push({
        path: "done.json:snapshots",
        message: `must be ${parsedStates.length}`,
      });
    }
    if (done?.reason === "aborted" && !has("abort.json")) {
      errors.push({
        path: "done.json:reason",
        message: "aborted needs an abort.json",
      });
    }
    if (
      has("events.ndjson") &&
      done?.trace_hash !== traceHash(files["events.ndjson"])
    ) {
      errors.push({
        path: "done.json:trace_hash",
        message: "must be the sha256 of events.ndjson",
      });
    }
    const applied = new Set(
      events.filter((e) => e.kind === "intent").map((e) => e.seq),
    );
    parsedIntents.forEach((intent, seq) => {
      const due = parsedStates[seq]?.tick + hold;
      if (intent !== undefined && due <= done?.tick && !applied.has(seq)) {
        errors.push({
          path: `${fileName("intent", seq)}`,
          message: `has no intent event at tick ${due}`,
        });
      }
    });
  }
  if (has("error.json")) {
    const error = parse("error.json");
    add("error.json", validateError(error));
    if (error?.code === "intent_timeout") {
      const state = parsedStates[error.seq];
      if (state === undefined) {
        errors.push({
          path: "error.json:seq",
          message: "must name an existing snapshot",
        });
      } else if (error.tick !== state.tick + hold) {
        errors.push({
          path: "error.json:tick",
          message: `must be ${state.tick + hold}, where Godot blocked`,
        });
      }
    }
  }
  if (has("abort.json")) add("abort.json", validateAbort(parse("abort.json")));
  return errors;
}

// --- writing, the cache key and the watchdog -------------------------------

// Every protocol file is written to `<file>.tmp` beside it, flushed, then
// renamed, so a reader never sees half a message. Objects become one line of
// JSON plus a newline; strings are written as given.
export async function writeAtomic(file, data) {
  const text = typeof data === "string" ? data : JSON.stringify(data) + "\n";
  const temporary = `${file}.tmp`;
  let handle;
  try {
    handle = await open(temporary, "w");
    await handle.writeFile(text, "utf8");
    await handle.sync();
    await handle.close();
    handle = undefined;
    await rename(temporary, file);
  } catch (error) {
    await handle?.close().catch(() => {});
    await rm(temporary, { force: true });
    throw error;
  }
  return file;
}

// Sorted keys at every depth, no whitespace. Arrays keep their order: option
// order is part of what Jev was shown.
export function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (isObject(value)) {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

// Plan section 2, "Arms": sha256({protocol, questions_sha, model,
// confidence_floor, gate_version, state, options}). `instrument` is
// decide.mjs's instrumentIdentity(); `jev` is the state file's jev block with
// the options as Godot offered them, before the gate (gate_version covers it).
export function verdictKey(instrument, jev) {
  const key = {
    protocol: PROTOCOL,
    questions_sha: instrument.questions_sha,
    model: instrument.model,
    confidence_floor: instrument.confidence_floor,
    gate_version: instrument.gate_version,
    state: jev.state,
    options: jev.options,
  };
  for (const [field, value] of Object.entries(key)) {
    if (value === undefined) throw new Error(`verdict key needs ${field}`);
  }
  return createHash("sha256").update(canonicalJson(key)).digest("hex");
}

// Node's stall limit: max(30 s, 20 x the nearest-rank median step), where a
// step is the wall time from Node renaming intent-N into place to the next
// Godot file appearing.
export const WATCHDOG_FLOOR_MS = 30_000;

export function watchdogMs(stepsMs) {
  if (stepsMs.length === 0) return WATCHDOG_FLOOR_MS;
  const sorted = [...stepsMs].sort((a, b) => a - b);
  const median = sorted[Math.ceil(sorted.length / 2) - 1];
  return Math.max(WATCHDOG_FLOOR_MS, 20 * median);
}
