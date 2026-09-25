// Offline tests for protocol v1, the file lockstep between a Godot trial and
// the Node harness. Nothing here spawns Godot or calls Jev: the fixtures are the
// contract both sides share, and JL-09 copies them into the sketch unchanged.
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  cpSync,
  existsSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  instrumentIdentity,
  loadQuestionSet,
  QUESTIONS_DIR,
} from "../decide.mjs";
import {
  ARMS,
  canonicalJson,
  ERROR_EXIT,
  fileName,
  offeredOptions,
  PROTOCOL,
  TIMING,
  traceHash,
  validateIntent,
  validateState,
  validateTrial,
  validators,
  verdictKey,
  watchdogMs,
  writeAtomic,
} from "../protocol/protocol.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const fixtures = path.join(here, "../protocol/fixtures");
const index = JSON.parse(
  readFileSync(path.join(fixtures, "INDEX.json"), "utf8"),
);
const TYPES = ["hello", "state", "intent", "error", "abort", "done", "events"];
const read = (file) => readFileSync(path.join(fixtures, file), "utf8");
const load = (file) => JSON.parse(read(file));
const sha = loadQuestionSet().sha;

function listFiles(directory, prefix = "") {
  const files = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const relative = prefix === "" ? entry.name : `${prefix}/${entry.name}`;
    if (entry.isDirectory()) {
      files.push(...listFiles(path.join(directory, entry.name), relative));
    } else {
      files.push(relative);
    }
  }
  return files;
}

function check(entry) {
  const text = read(entry.file);
  if (entry.type === "events") {
    return validators.events(text);
  } else if (entry.context !== undefined) {
    return validators[entry.type](JSON.parse(text), {
      state: load(entry.context),
    });
  } else {
    return validators[entry.type](JSON.parse(text));
  }
}

test("the validators accept every valid fixture and reject every invalid one at exactly the named path", () => {
  for (const entry of index.fixtures) {
    const errors = check(entry);
    if (entry.valid) {
      assert.deepEqual(errors, [], `${entry.file} should be valid`);
    } else {
      assert.deepEqual(
        errors.map((error) => error.path),
        [entry.path],
        `${entry.file} should fail with exactly one error at ${entry.path}; got ${JSON.stringify(errors)}`,
      );
    }
  }
});

test("every message type has at least one valid and one invalid fixture", () => {
  for (const type of TYPES) {
    const mine = index.fixtures.filter((entry) => entry.type === type);
    assert.ok(
      mine.some((entry) => entry.valid),
      `no valid ${type} fixture`,
    );
    assert.ok(
      mine.some((entry) => !entry.valid),
      `no invalid ${type} fixture`,
    );
  }
  assert.deepEqual(Object.keys(validators).sort(), [...TYPES].sort());
});

test("every fixture file is listed in INDEX.json and is plain JSON or NDJSON", () => {
  const listed = new Set(index.fixtures.map((entry) => entry.file));
  for (const file of listFiles(fixtures)) {
    if (file === "INDEX.json") continue;
    assert.ok(listed.has(file), `${file} is not listed in INDEX.json`);
    const text = read(file);
    assert.ok(!text.includes("\r"), `${file} uses CR line endings`);
    assert.ok(text.endsWith("\n"), `${file} lacks a final newline`);
    if (file.endsWith(".ndjson")) {
      for (const line of text.slice(0, -1).split("\n")) JSON.parse(line);
    } else {
      assert.ok(file.endsWith(".json"), `${file} is neither JSON nor NDJSON`);
      JSON.parse(text);
    }
  }
  for (const entry of index.fixtures) {
    assert.ok(existsSync(path.join(fixtures, entry.file)), entry.file);
  }
});

test("each trial directory is judged as a whole, including the tick schedule", () => {
  assert.ok(index.trials.some((trial) => trial.valid));
  assert.ok(index.trials.some((trial) => !trial.valid));
  for (const trial of index.trials) {
    const directory = path.join(fixtures, trial.dir);
    const files = {};
    for (const name of readdirSync(directory)) {
      files[name] = readFileSync(path.join(directory, name), "utf8");
    }
    const errors = validateTrial(files);
    if (trial.valid) {
      assert.deepEqual(errors, [], `${trial.dir} should be valid`);
    } else {
      assert.deepEqual(
        errors.map((error) => error.path),
        [trial.path],
        `${trial.dir} should fail with exactly one error at ${trial.path}; got ${JSON.stringify(errors)}`,
      );
    }
  }
});

test("the complete trial applies each intent exactly hold_ticks after its snapshot", () => {
  const events = read("trial-complete/events.ndjson")
    .trimEnd()
    .split("\n")
    .map((line) => JSON.parse(line))
    .filter((event) => event.kind === "intent");
  const hello = load("trial-complete/hello.json");
  assert.equal(events.length, 2);
  for (const event of events) {
    const state = load(`trial-complete/${fileName("state", event.seq)}`);
    assert.equal(event.tick, state.tick + hello.hold_ticks);
  }
  assert.equal(
    load("trial-complete/done.json").trace_hash,
    traceHash(read("trial-complete/events.ndjson")),
  );
});

test("a jev-arm intent without meta.questions_sha is invalid", () => {
  const state = load("trial-complete/state-000000.json");
  const intent = {
    protocol: PROTOCOL,
    seq: 0,
    intent: "push_objective",
    arm: "jev",
    source: "live",
    meta: { questions_sha: sha },
  };
  assert.deepEqual(validateIntent(intent, { state }), []);
  for (const meta of [{}, { questions_sha: "" }, { questions_sha: "abc" }]) {
    const errors = validateIntent({ ...intent, meta }, { state });
    assert.ok(errors.some((error) => error.path === "meta.questions_sha"));
  }
  // The other arms make no model call, so they carry no question set.
  assert.deepEqual(
    validateIntent(
      { ...intent, arm: "random", source: "seeded", meta: {} },
      { state },
    ),
    [],
  );
});

test("the jev fixtures carry a question-set sha that is pinned in INDEX.json", () => {
  const pinned = Object.values(
    JSON.parse(readFileSync(path.join(QUESTIONS_DIR, "INDEX.json"), "utf8")),
  ).map((entry) => entry.sha256);
  for (const entry of index.fixtures) {
    if (entry.type !== "intent" || !entry.valid) continue;
    const intent = load(entry.file);
    if (intent.arm === "jev") {
      assert.ok(pinned.includes(intent.meta.questions_sha), entry.file);
    }
  }
  assert.equal(instrumentIdentity().questions_sha, sha);
});

test("every authored corpus case is a valid jev block, so the state is pre-quantised to the corpus schema", () => {
  const corpus = JSON.parse(
    readFileSync(path.join(here, "../corpus.json"), "utf8"),
  );
  const template = load("trial-complete/state-000000.json");
  for (const one of [...corpus.cases, ...corpus.adversarial]) {
    const state = {
      ...template,
      jev: { state: one.state, options: one.options },
    };
    assert.deepEqual(validateState(state), [], one.id);
  }
});

test("a state value off the corpus quantisation grid is rejected", () => {
  const state = load("trial-complete/state-000001.json");
  const off = structuredClone(state);
  off.jev.state.self.speed_ms = 17.54;
  assert.ok(
    validateState(off).some(
      (error) => error.path === "jev.state.self.speed_ms",
    ),
  );
  const whole = structuredClone(state);
  whole.jev.state.threats[0].distance_m = 9.5;
  assert.ok(
    validateState(whole).some(
      (error) => error.path === "jev.state.threats[0].distance_m",
    ),
  );
});

test("a single offered option, counted after the precondition gate, must be forced for every arm", () => {
  const state = load("trial-complete/state-000001.json");
  assert.deepEqual(
    offeredOptions(state.jev).map((option) => option.id),
    ["ram_target"],
  );
  for (const [arm, sources] of Object.entries(ARMS)) {
    const base = {
      protocol: PROTOCOL,
      seq: state.seq,
      intent: "ram_target",
      arm,
      meta: arm === "jev" ? { questions_sha: sha } : {},
    };
    assert.deepEqual(
      validateIntent({ ...base, source: "forced" }, { state }),
      [],
    );
    for (const source of sources.filter((one) => one !== "forced")) {
      assert.ok(
        validateIntent({ ...base, source }, { state }).some(
          (error) => error.path === "source",
        ),
        `${arm}/${source} on a single option`,
      );
    }
  }
});

test("a fully gated option list offers push_objective alone, as decide.mjs does", () => {
  const state = load("trial-complete/state-000001.json");
  const gated = structuredClone(state);
  gated.jev.options = [
    { id: "hit_kicker", why: "Kicker ramp", requires_speed_ms: 26 },
  ];
  assert.deepEqual(
    offeredOptions(gated.jev).map((option) => option.id),
    ["push_objective"],
  );
});

test("only the jev arm may fall back to push_objective when it was not offered", () => {
  const state = load("valid/state-evade.json");
  const floor = load("valid/intent-floor.json");
  assert.deepEqual(validateIntent(floor, { state }), []);
  const random = { ...floor, arm: "random", source: "seeded", meta: {} };
  assert.ok(
    validateIntent(random, { state }).some((error) => error.path === "intent"),
  );
});

test("the timing constants match plan section 2 and the watchdog floor is 30 s", () => {
  assert.equal(PROTOCOL, "scrapkeep-jev/1");
  assert.deepEqual(TIMING, {
    tick_hz: 90,
    snapshot_every: 90,
    hold_ticks: 26,
    intent_timeout_s: 30,
  });
  assert.equal(ERROR_EXIT.intent_timeout, 5);
  assert.equal(watchdogMs([]), 30_000);
  assert.equal(watchdogMs([100, 200, 300]), 30_000);
  assert.equal(watchdogMs([1000, 4000, 2000]), 40_000);
  // The median is nearest-rank, like every other p50 in the lab.
  assert.equal(watchdogMs([1000, 2000, 3000, 4000]), 40_000);
  assert.equal(watchdogMs([3000, 1000, 2000, 4000, 5000]), 60_000);
  assert.equal(fileName("state", 7), "state-000007.json");
  assert.equal(fileName("intent", 123456), "intent-123456.json");
});

test("writeAtomic writes through a sibling .tmp file and leaves only the final file", async () => {
  const directory = mkdtempSync(path.join(tmpdir(), "jev-protocol-"));
  const file = path.join(directory, "intent-000000.json");
  writeFileSync(file, "old\n");
  const before = statSync(file).ino;
  const message = { protocol: PROTOCOL, seq: 0 };
  await writeAtomic(file, message);
  assert.equal(readFileSync(file, "utf8"), JSON.stringify(message) + "\n");
  // A rename swaps in a new inode; an in-place write would keep the old one,
  // and a reader could see it half-written.
  assert.notEqual(statSync(file).ino, before);
  assert.deepEqual(readdirSync(directory), ["intent-000000.json"]);
  await writeAtomic(file, "raw\n");
  assert.equal(readFileSync(file, "utf8"), "raw\n");
  await assert.rejects(
    writeAtomic(path.join(directory, "missing", "abort.json"), message),
  );
  assert.deepEqual(readdirSync(directory), ["intent-000000.json"]);
  assert.ok(statSync(file).isFile());
});

test("the verdict-cache key is sha256 of canonical JSON over protocol, instrument, state and options", () => {
  assert.equal(
    canonicalJson({ b: [2, { d: 1, c: null }], a: "x" }),
    '{"a":"x","b":[2,{"c":null,"d":1}]}',
  );
  const instrument = {
    questions_sha: "a".repeat(64),
    model: "jev-latest",
    confidence_floor: 0.05,
    gate_version: 1,
  };
  const jev = {
    state: { self: { speed_ms: 3, grounded: true } },
    options: [{ why: "go", id: "push_objective" }],
  };
  const expected =
    '{"confidence_floor":0.05,"gate_version":1,"model":"jev-latest",' +
    '"options":[{"id":"push_objective","why":"go"}],' +
    `"protocol":"scrapkeep-jev/1","questions_sha":"${"a".repeat(64)}",` +
    '"state":{"self":{"grounded":true,"speed_ms":3}}}';
  assert.equal(
    verdictKey(instrument, jev),
    createHash("sha256").update(expected).digest("hex"),
  );
  const other = { ...instrument, questions_sha: "b".repeat(64) };
  assert.notEqual(verdictKey(other, jev), verdictKey(instrument, jev));
  assert.throws(() => verdictKey({ ...instrument, model: undefined }, jev));
});

test("a state file whose content is JSON null is reported, never thrown on", (t) => {
  const directory = mkdtempSync(path.join(tmpdir(), "jev-null-state-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  for (const [trial, seq] of [
    ["trial-complete", 0],
    ["trial-complete", 1],
    ["trial-timeout", 0],
  ]) {
    const copy = path.join(directory, `${trial}-${seq}`);
    cpSync(path.join(fixtures, trial), copy, { recursive: true });
    writeFileSync(path.join(copy, fileName("state", seq)), "null\n");
    const files = {};
    for (const name of readdirSync(copy)) {
      files[name] = readFileSync(path.join(copy, name), "utf8");
    }
    let errors;
    assert.doesNotThrow(
      () => {
        errors = validateTrial(files);
      },
      `${trial} with ${fileName("state", seq)} null`,
    );
    assert.ok(
      errors.some((error) => error.path.startsWith(fileName("state", seq))),
      `${trial}: ${JSON.stringify(errors)}`,
    );
  }
});
