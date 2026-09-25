import test from "node:test";
import assert from "node:assert/strict";
import {
  appendFile,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  rm,
  writeFile,
} from "node:fs/promises";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { STATUS } from "../scripts/lab/metrics/status.mjs";
import { METRICS } from "../scripts/lab/metrics/index.mjs";
import { SCHEMA, createRun } from "../scripts/lab/record.mjs";
import { sourceName } from "../scripts/lab/gate.mjs";
import {
  instrumentIdentity,
  loadQuestionSet,
} from "../tools/jev-player/decide.mjs";
import {
  BLIND_NOT_RUN,
  epochRecord,
  loadControls,
  writeEpochRecord,
} from "../tools/jev-player/preflight.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const gateScript = path.join(root, "scripts/lab/gate.mjs");
const HOUR = 3_600_000;
const DAY = 24 * HOUR;

// A clean, passing scrapkeep-run/1 record. first_pass_review and flake_rate
// are compared as rates against a pin; engine_crash is a sentinel.
function record(id, overrides = {}) {
  const finished = overrides.finished ?? new Date();
  const base = {
    schema: SCHEMA,
    id,
    type: "ball-lab",
    label: "smoke",
    result: "pass",
    seq: 0,
    started_at: new Date(finished.getTime() - HOUR).toISOString(),
    finished_at: finished.toISOString(),
    provenance: {
      head: "a".repeat(40),
      branch: "lab",
      dirty: false,
      sources: {
        paths: ["src"],
        start: "d".repeat(64),
        end: "d".repeat(64),
        matched: true,
        changed: [],
        files: {},
      },
      versions: { node: process.version },
      instrument: null,
      jev: { model: null, calls: 0, cache_hits: 0 },
    },
    config: {},
    kpis: { first_pass_review: { value: 0.95, n: 1000, ci: null } },
    kris: {
      engine_crash: { value: 0, n: 1, ci: null },
      flake_rate: { value: 0.005, n: 2000, ci: null },
    },
    findings: [],
    limits: [],
  };
  const {
    finished: _,
    provenance = {},
    kpis = {},
    kris = {},
    ...rest
  } = overrides;
  return {
    ...base,
    ...rest,
    provenance: { ...base.provenance, ...provenance },
    kpis: { ...base.kpis, ...kpis },
    kris: { ...base.kris, ...kris },
  };
}

async function fixture(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-gate-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const runs = path.join(temporary, "runs");
  const artifacts = path.join(temporary, "artifacts");
  const epochs = path.join(temporary, "epochs");
  await mkdir(runs, { recursive: true });
  const write = async (run) => {
    await mkdir(path.join(runs, run.id), { recursive: true });
    await writeFile(
      path.join(runs, run.id, "run.json"),
      JSON.stringify(run, null, 2) + "\n",
    );
    return run.id;
  };
  const gate = (...args) => {
    const result = spawnSync(
      process.execPath,
      [
        gateScript,
        ...args,
        "--runs",
        runs,
        "--artifacts",
        artifacts,
        "--epochs",
        epochs,
      ],
      { encoding: "utf8" },
    );
    return {
      code: result.status,
      out: result.stdout,
      err: result.stderr,
    };
  };
  // Pins a clean baseline under the name "base" and returns its record.
  const pinBase = async (overrides = {}) => {
    const base = record("base-run", overrides);
    await write(base);
    const pinned = gate("--pin", base.id, "--as", "base");
    assert.equal(pinned.code, 0, pinned.out + pinned.err);
    return base;
  };
  return { temporary, runs, artifacts, epochs, write, gate, pinBase };
}

async function pinDirectories(artifacts) {
  const days = await readdir(artifacts).catch(() => []);
  return days.filter((day) => /^jev-lab-\d{4}-\d{2}-\d{2}$/.test(day));
}

test("usage errors exit 2", async (t) => {
  const { gate, write, pinBase } = await fixture(t);
  const id = await write(record("candidate"));
  assert.equal(gate().code, 2, "no arguments");
  assert.equal(gate("--bogus").code, 2, "unknown option");
  assert.equal(gate(id).code, 2, "a candidate without --against");
  assert.equal(gate("--pin", id).code, 2, "--pin without --as");
  assert.equal(gate("--pin", id, "--as", "../escape").code, 2, "bad name");
  assert.equal(gate("--pin", "no-such-run", "--as", "x").code, 2);
  assert.equal(gate(id, "--against", "no-such-pin").code, 2);
  assert.equal(gate("no-such-run", "--against", "no-such-pin").code, 2);
  await pinBase();
  assert.equal(gate(id, "--against", "base").code, 0);
  const taken = gate("--pin", id, "--as", "base");
  assert.equal(taken.code, 2, "a pin name is never overwritten");
  assert.match(taken.err, /already/);
  const other = await write(record("program-run", { type: "program" }));
  assert.equal(gate(other, "--against", "base").code, 2, "type mismatch");
});

test("--pin copies the run to jev-lab-<date>/pins/<name>/", async (t) => {
  const { artifacts, runs, write, gate } = await fixture(t);
  const run = record("pinnable");
  await write(run);
  await writeFile(path.join(runs, run.id, "verdicts.ndjson"), "{}\n");
  const result = gate("--pin", run.id, "--as", "andrew-anchor");
  assert.equal(result.code, 0, result.out + result.err);
  const days = await pinDirectories(artifacts);
  assert.deepEqual(days, [`jev-lab-${new Date().toISOString().slice(0, 10)}`]);
  const pin = path.join(artifacts, days[0], "pins/andrew-anchor");
  assert.deepEqual(JSON.parse(await readFile(path.join(pin, "run.json"))), run);
  assert.equal(
    await readFile(path.join(pin, "verdicts.ndjson"), "utf8"),
    "{}\n",
  );
  const meta = JSON.parse(await readFile(path.join(pin, "pin.json")));
  assert.equal(meta.name, "andrew-anchor");
  assert.equal(meta.run_id, run.id);
});

test("--pin refuses a run that does not pass on its own", async (t) => {
  const { artifacts, write, gate } = await fixture(t);
  const cases = [
    [record("dirty", { provenance: { dirty: true } }), 3],
    [record("invalid", { result: "invalid" }), 4],
    [
      record("crashed", {
        kris: { engine_crash: { value: 1, n: 1, ci: null } },
      }),
      1,
    ],
    [record("thin", { kris: { flake_rate: { value: 0, n: 3, ci: null } } }), 3],
  ];
  for (const [run, code] of cases) {
    await write(run);
    const result = gate("--pin", run.id, "--as", run.id);
    assert.equal(result.code, code, `${run.id}: ${result.out}${result.err}`);
    assert.match(result.err, /refus/);
  }
  assert.deepEqual(await pinDirectories(artifacts), []);
});

test("exit 0 when nothing regresses and untiered KRIs are ignored", async (t) => {
  const { write, gate, pinBase } = await fixture(t);
  await pinBase();
  const id = await write(
    record("candidate", {
      kris: {
        api_error_rate: { value: 0.9, n: 40, ci: null },
        escaped_defects: { value: 12, n: 1, ci: null },
        low_conf_rate: { value: 0, n: 0, ci: null },
      },
      kpis: { tokens_per_decision: { value: 900, n: 2, ci: null } },
    }),
  );
  const result = gate(id, "--against", "base");
  assert.equal(result.code, 0, result.out + result.err);
  assert.match(
    result.out,
    new RegExp(`${STATUS.untiered.glyph} .*api_error_rate`),
  );
  assert.match(result.out, /first_pass_review/);
});

test("exit 1 for a red KRI", async (t) => {
  const { write, gate, pinBase } = await fixture(t);
  await pinBase();
  const id = await write(
    record("candidate", {
      kris: { engine_crash: { value: 1, n: 1, ci: null } },
    }),
  );
  assert.equal(gate(id, "--against", "base").code, 1);
});

test("exit 1 for a conclusive regression beyond the 0.10 tolerance", async (t) => {
  const { write, gate, pinBase } = await fixture(t);
  await pinBase();
  const id = await write(
    record("candidate", {
      kpis: { first_pass_review: { value: 0.75, n: 1000, ci: null } },
    }),
  );
  const result = gate(id, "--against", "base");
  assert.equal(result.code, 1, result.out + result.err);
  assert.match(result.out, /first_pass_review.*regress/);
});

test("exit 3 when a difference interval straddles the tolerance", async (t) => {
  const { write, gate, pinBase } = await fixture(t);
  await pinBase();
  const id = await write(
    record("candidate", {
      kpis: { first_pass_review: { value: 0.85, n: 20, ci: null } },
    }),
  );
  const result = gate(id, "--against", "base");
  assert.equal(result.code, 3, result.out + result.err);
  assert.match(result.out, /first_pass_review.*inconclusive/);
});

test("exit 3 against a pin older than the evidence_age_d fail limit", async (t) => {
  const { write, gate, pinBase } = await fixture(t);
  await pinBase({ finished: new Date(Date.now() - 10 * DAY) });
  const fresh = await write(record("fresh"));
  assert.equal(gate(fresh, "--against", "base").code, 3, "stale pin");
});

test("exit 3 for too few samples, a dirty tree, a source mismatch, an unproven epoch or a missing rate", async (t) => {
  const { write, gate, pinBase } = await fixture(t);
  await pinBase();
  const cases = {
    thin: { kris: { flake_rate: { value: 0, n: 5, ci: null } } },
    dirty: { provenance: { dirty: true } },
    mismatch: { result: "inconclusive" },
    lever: { kpis: { lever_effect: { value: 0.4, n: 200, ci: null } } },
  };
  for (const [name, overrides] of Object.entries(cases)) {
    const id = await write(record(name, overrides));
    const result = gate(id, "--against", "base");
    assert.equal(result.code, 3, `${name}: ${result.out}${result.err}`);
  }
  const missing = record("missing");
  delete missing.kris.flake_rate;
  await write(missing);
  assert.equal(gate(missing.id, "--against", "base").code, 3, "missing rate");
});

test("exit 4 when the instrument or the record is invalid", async (t) => {
  const { write, gate, pinBase } = await fixture(t);
  await pinBase();
  const cases = {
    invalid: { result: "invalid" },
    schema: { schema: "scrapkeep-run/0" },
    unknown: { kris: { not_a_metric: { value: 0, n: 1, ci: null } } },
    malformed: { kris: { flake_rate: { value: "0.1", n: 20, ci: null } } },
    epoch: { provenance: { instrument: { question_set: "v2" } } },
    both: {
      result: "invalid",
      kris: { engine_crash: { value: 1, n: 1, ci: null } },
    },
  };
  for (const [name, overrides] of Object.entries(cases)) {
    const id = await write(record(name, overrides));
    const result = gate(id, "--against", "base");
    assert.equal(result.code, 4, `${name}: ${result.out}${result.err}`);
  }
});

test("a red KRI outranks an inconclusive one", async (t) => {
  const { write, gate, pinBase } = await fixture(t);
  await pinBase();
  const id = await write(
    record("candidate", {
      provenance: { dirty: true },
      kris: { engine_crash: { value: 1, n: 1, ci: null } },
    }),
  );
  assert.equal(gate(id, "--against", "base").code, 1);
});

function git(repository, ...args) {
  const result = spawnSync(
    "git",
    [
      "-c",
      "user.name=Lab Test",
      "-c",
      "user.email=lab@example.invalid",
      "-c",
      "commit.gpgsign=false",
      ...args,
    ],
    { cwd: repository, encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
}

test("a source mismatch keeps invalid and records the reported result", async (t) => {
  const { temporary, runs, gate, pinBase } = await fixture(t);
  const repository = path.join(temporary, "repository");
  await mkdir(path.join(repository, "src"), { recursive: true });
  git(repository, "init", "-q", "-b", "lab");
  await writeFile(path.join(repository, "src/tuning.txt"), "speed = 4\n");
  git(repository, "add", ".");
  git(repository, "commit", "-q", "-m", "fixture");
  const finish = async (label, result) => {
    const run = await createRun({
      type: "ball-lab",
      label,
      registry: METRICS,
      root: runs,
      repository,
      sources: ["src"],
    });
    await appendFile(path.join(repository, "src/tuning.txt"), `${label}\n`);
    return run.finish({ result });
  };
  const invalid = await finish("invalid", "invalid");
  assert.equal(invalid.result, "invalid");
  assert.equal(invalid.provenance.sources.matched, false);
  assert.equal(invalid.provenance.sources.reported_result, "invalid");
  const passed = await finish("passed", "pass");
  assert.equal(passed.result, "inconclusive");
  assert.equal(passed.provenance.sources.reported_result, "pass");
  await pinBase();
  assert.equal(gate(invalid.id, "--against", "base").code, 4);
  assert.equal(gate(passed.id, "--against", "base").code, 3);
});

test("gate.mjs names no status and reads STATUS only through evaluate", async () => {
  const source = await readFile(gateScript, "utf8");
  const words = new RegExp(`\\b(${Object.keys(STATUS).join("|")})\\b`, "i");
  assert.equal(words.exec(source), null);
  assert.doesNotMatch(source, /\bSTATUS\b/);
});

// The q1 instrument, and an epoch record for it built by preflight.mjs from a
// controls result and a blind result.
const questions = loadQuestionSet();
const instrument = instrumentIdentity(questions);
const BLIND_PASSED = {
  status: "pass",
  passed: true,
  exit: 0,
  reason: "Blind corpus passes.",
  cases: 24,
  weighted: 0.93,
  severe_misses: 0,
};

async function writeEpoch(
  epochs,
  { controls = true, blind = BLIND_PASSED } = {},
) {
  const result = {
    instrument,
    controls_version: "c1",
    controls_sha: "c".repeat(64),
    passed: controls,
    controls: loadControls().controls.map((control) => ({
      id: control.id,
      passed: controls,
      reason: "",
      runs: [],
    })),
  };
  return writeEpochRecord(
    epochRecord({ questions, controls: result, blind }),
    epochs,
  );
}

const withInstrument = (id, overrides = {}) =>
  record(id, {
    ...overrides,
    provenance: { instrument, ...overrides.provenance },
  });

test("--pin refuses a run with an instrument until its epoch passed controls and the blind corpus", async (t) => {
  const { artifacts, epochs, write, gate } = await fixture(t);
  const run = withInstrument("jev-run");
  await write(run);
  const attempt = () => gate("--pin", run.id, "--as", "jev-base");

  const none = attempt();
  assert.equal(none.code, 4, none.out + none.err);
  assert.match(none.out, /no epoch record/);
  assert.match(none.err, /refus/);

  await writeEpoch(epochs, { blind: BLIND_NOT_RUN });
  const pending = attempt();
  assert.equal(pending.code, 4, pending.out + pending.err);
  assert.match(pending.out, /blind corpus/);

  await writeEpoch(epochs, { controls: false });
  const failed = attempt();
  assert.equal(failed.code, 4, failed.out + failed.err);
  assert.match(failed.out, /controls failed/);
  assert.deepEqual(await pinDirectories(artifacts), []);

  const other = withInstrument("other-model", {
    provenance: { instrument: { ...instrument, model: "jev-next" } },
  });
  await write(other);
  await writeEpoch(epochs);
  const mismatched = gate("--pin", other.id, "--as", "other");
  assert.equal(mismatched.code, 4, "an epoch answers only for its instrument");

  const valid = attempt();
  assert.equal(valid.code, 0, valid.out + valid.err);
  assert.equal((await pinDirectories(artifacts)).length, 1);
});

test("lever_effect is judged once the candidate's epoch is valid, and held otherwise", async (t) => {
  const { epochs, write, gate, pinBase } = await fixture(t);
  await writeEpoch(epochs);
  await pinBase({ provenance: { instrument } });
  const lever = { kpis: { lever_effect: { value: 0.4, n: 200, ci: null } } };
  const judged = await write(withInstrument("judged", lever));
  const passed = gate(judged, "--against", "base");
  assert.equal(passed.code, 0, passed.out + passed.err);
  assert.match(
    passed.out,
    new RegExp(`${STATUS.untiered.glyph} ${STATUS.untiered.word} lever_effect`),
  );

  await writeEpoch(epochs, { blind: BLIND_NOT_RUN });
  const held = gate(judged, "--against", "base");
  assert.equal(held.code, 3, held.out + held.err);
  assert.match(
    held.out,
    new RegExp(
      `${STATUS.insufficient.glyph} ${STATUS.insufficient.word} lever_effect`,
    ),
  );
});

// --- JL-25: carried notes (EV-0504, EV-0511) and revision 2 (EV-0546) -------

test("the andrew-anchor pin never goes stale; any other name does", async (t) => {
  const { write, gate } = await fixture(t);
  const old = record("old-run", { finished: new Date(Date.now() - 30 * DAY) });
  await write(old);
  for (const name of ["andrew-anchor", "old-baseline"]) {
    const pinned = gate("--pin", old.id, "--as", name);
    assert.equal(pinned.code, 0, pinned.out + pinned.err);
  }
  const id = await write(record("candidate"));
  const anchored = gate(id, "--against", "andrew-anchor");
  assert.equal(anchored.code, 0, anchored.out + anchored.err);
  assert.match(anchored.out, /andrew-anchor.*never goes stale/);
  assert.doesNotMatch(anchored.out, /stale:/);
  const other = gate(id, "--against", "old-baseline");
  assert.equal(other.code, 3, other.out + other.err);
  assert.match(other.out, /pin old-baseline is stale/);
});

test("a pin copy leaves out sources.json, run-owner.json and per-trial directories", async (t) => {
  const { artifacts, runs, write, gate } = await fixture(t);
  const run = record("with-extras");
  await write(run);
  const directory = path.join(runs, run.id);
  await writeFile(path.join(directory, "sources.json"), "{}\n");
  await writeFile(path.join(directory, "run-owner.json"), "{}\n");
  await mkdir(path.join(directory, "trials/000"), { recursive: true });
  await writeFile(path.join(directory, "trials/000/done.json"), "{}\n");
  await writeFile(path.join(directory, "verdicts.ndjson"), "{}\n");
  const result = gate("--pin", run.id, "--as", "slim");
  assert.equal(result.code, 0, result.out + result.err);
  const [day] = await pinDirectories(artifacts);
  const pin = path.join(artifacts, day, "pins/slim");
  assert.deepEqual((await readdir(pin)).sort(), [
    "pin.json",
    "run.json",
    "verdicts.ndjson",
  ]);
  const meta = JSON.parse(await readFile(path.join(pin, "pin.json")));
  assert.equal(meta.source, run.id, "a run outside the repository goes by id");
  assert.deepEqual(meta.omitted.sort(), [
    "run-owner.json",
    "sources.json",
    "trials",
  ]);
});

test("an uncaught error exits 4, not Node's default 1", async (t) => {
  const { runs, gate, pinBase } = await fixture(t);
  await pinBase();
  // run.json as a directory: readFile throws EISDIR, which no branch expects.
  await mkdir(path.join(runs, "broken/run.json"), { recursive: true });
  const result = gate("broken", "--against", "base");
  assert.equal(result.code, 4, result.out + result.err);
  assert.match(result.err, /EISDIR/);
});

test("margin_vs_scripted is shown without a tier and not gated until JL-28", async (t) => {
  const { write, gate, pinBase } = await fixture(t);
  await pinBase();
  const id = await write(
    record("candidate", {
      kpis: { margin_vs_scripted: { value: -0.9, n: 40, ci: null } },
    }),
  );
  const result = gate(id, "--against", "base");
  assert.equal(result.code, 0, result.out + result.err);
  assert.match(
    result.out,
    new RegExp(
      `${STATUS.untiered.glyph} ${STATUS.untiered.word} margin_vs_scripted .*not gated until JL-28`,
    ),
  );
});

// A scripted batch as harness.mjs records it, with one trace hash per trial.
function batch(id, options = {}) {
  const {
    mode = "kinematic",
    scenario = "dummy-knock",
    seed = 1,
    trials = 20,
    success = 14,
    hash = (trial) => `${trial}`.padStart(64, "0"),
    ...overrides
  } = options;
  const run = record(id, {
    type: "batch",
    label: `${scenario}-scripted`,
    config: {
      scenario,
      arm: "scripted",
      seed,
      trial_seed_stride: 1000,
      snapshot_every: 90,
      hold_ticks: 26,
      launcher: `godot-headless godot ${mode}`,
      trials: Array.from({ length: trials }, (_, trial) => ({
        trial,
        outcome: "complete",
        trace_hash: hash(trial),
      })),
      scenario_results: { success, timeout: trials - success, unreported: 0 },
    },
    kris: {
      trial_abort_rate: { value: 0, n: trials, ci: null },
      unreachable_scenarios: { value: success === 0 ? 1 : 0, n: 1, ci: null },
    },
    ...overrides,
  });
  delete run.kpis.first_pass_review;
  delete run.kris.flake_rate;
  return run;
}

async function pinBatch(write, gate, run, name) {
  await write(run);
  const pinned = gate("--pin", run.id, "--as", name);
  assert.equal(pinned.code, 0, pinned.out + pinned.err);
}

test("a kinematic batch must reproduce every shared trial's trace hash", async (t) => {
  const { write, gate } = await fixture(t);
  await pinBatch(write, gate, batch("pin-run"), "kinematic");
  const same = await write(batch("same"));
  const passed = gate(same, "--against", "kinematic");
  assert.equal(passed.code, 0, passed.out + passed.err);
  assert.match(passed.out, /replay_repro .*20 of 20 trials reproduce/);

  const drifted = await write(
    batch("drifted", {
      hash: (trial) => (trial === 3 ? "f" : `${trial}`).padStart(64, "0"),
    }),
  );
  const failed = gate(drifted, "--against", "kinematic");
  assert.equal(failed.code, 1, failed.out + failed.err);
  assert.match(failed.out, /19 of 20 trials reproduce; trials 3 diverge/);

  const reseeded = await write(batch("reseeded", { seed: 2 }));
  const unshared = gate(reseeded, "--against", "kinematic");
  assert.equal(unshared.code, 3, unshared.out + unshared.err);
  assert.match(unshared.out, /no trial seed is shared/);
});

test("a rigid batch is not held to trace equality and needs n >= 20 on each side", async (t) => {
  const { write, gate } = await fixture(t);
  await pinBatch(write, gate, batch("pin-run", { mode: "rigid" }), "rigid");
  const flipped = await write(
    batch("flipped", {
      mode: "rigid",
      hash: (trial) => (trial === 3 ? "f" : `${trial}`).padStart(64, "0"),
    }),
  );
  const passed = gate(flipped, "--against", "rigid");
  assert.equal(passed.code, 0, passed.out + passed.err);
  assert.match(passed.out, /trace equality not gated: rigid physics/);
  assert.match(
    passed.out,
    /n ≥ 20 on each side \(20 and 20 trials\); no rate compared until JL-28; nondeterminism floor 0.05 applies to the unreachable check/,
  );
  assert.doesNotMatch(passed.out, /distributions over/);

  const thin = await write(
    batch("thin", { mode: "rigid", trials: 10, success: 7 }),
  );
  const few = gate(thin, "--against", "rigid");
  assert.equal(few.code, 3, few.out + few.err);
  assert.match(
    few.out,
    /at least 20 trials on each side; the candidate has 10/,
  );
});

test("batches differing in scenario, arm, D, k or physics mode are not compared", async (t) => {
  const { write, gate } = await fixture(t);
  await pinBatch(write, gate, batch("pin-run"), "kinematic");
  const cases = {
    scenario: batch("other-scenario", { scenario: "run-to-pad" }),
    mode: batch("other-mode", { mode: "rigid" }),
  };
  const armed = batch("other-arm");
  armed.config.arm = "random";
  cases.arm = armed;
  const held = batch("other-k");
  held.config.hold_ticks = 0;
  cases.k = held;
  for (const [name, run] of Object.entries(cases)) {
    await write(run);
    const result = gate(run.id, "--against", "kinematic");
    assert.equal(result.code, 2, `${name}: ${result.out}${result.err}`);
    assert.match(result.err, /cannot be gated/);
  }
});

test("a scenario the pin reached and the candidate never reached is a regression, within the rigid floor inconclusive, and bench-climb is exempt", async (t) => {
  const { write, gate } = await fixture(t);
  const rigid = { mode: "rigid" };
  await pinBatch(write, gate, batch("pin-run", rigid), "reached");
  const lost = await write(batch("lost", { ...rigid, success: 0 }));
  const regressed = gate(lost, "--against", "reached");
  assert.equal(regressed.code, 1, regressed.out + regressed.err);
  assert.match(
    regressed.out,
    /reached dummy-knock in 14 of 20 trials and the candidate in none; regressed/,
  );

  await pinBatch(
    write,
    gate,
    batch("rare-run", { ...rigid, success: 1 }),
    "rare",
  );
  const floor = gate(lost, "--against", "rare");
  assert.equal(floor.code, 3, floor.out + floor.err);
  assert.match(floor.out, /within the rigid floor of 1/);

  const bench = { ...rigid, scenario: "bench-climb" };
  await pinBatch(
    write,
    gate,
    batch("bench-pin", { ...bench, success: 3 }),
    "bench",
  );
  const none = await write(batch("bench-none", { ...bench, success: 0 }));
  const exempt = gate(none, "--against", "bench");
  assert.equal(exempt.code, 0, exempt.out + exempt.err);
  assert.match(exempt.out, /unreachable_scenarios not counted for bench-climb/);
});

// --- JL-25 review F3 and F7: pin.json subject and source ----------------------

test("pin.json names its source run repository-relative, never by machine path", () => {
  const inside = path.join(root, "artifacts/local/runs/20260925T000000Z-x");
  assert.equal(
    sourceName(inside, "20260925T000000Z-x"),
    "artifacts/local/runs/20260925T000000Z-x",
  );
  assert.equal(sourceName(path.join(os.tmpdir(), "runs/r1"), "r1"), "r1");
});

test("--pin --subject-commit/--subject-path records the tree the run measured", async (t) => {
  const { artifacts, write, gate } = await fixture(t);
  const run = record("exported-tree");
  await write(run);
  const git = (...args) =>
    spawnSync("git", args, { cwd: root, encoding: "utf8" }).stdout.trim();
  const commit = git("rev-parse", "HEAD");
  const result = gate(
    "--pin",
    run.id,
    "--as",
    "exported",
    "--subject-commit",
    "HEAD",
    "--subject-path",
    "scripts/lab",
  );
  assert.equal(result.code, 0, result.out + result.err);
  const [day] = await pinDirectories(artifacts);
  const meta = JSON.parse(
    await readFile(path.join(artifacts, day, "pins/exported/pin.json")),
  );
  assert.deepEqual(meta.subject, {
    commit,
    path: "scripts/lab",
    tree_oid: git("rev-parse", `${commit}:scripts/lab`),
    method: "git archive export",
  });

  const plain = gate("--pin", run.id, "--as", "plain");
  assert.equal(plain.code, 0, plain.out + plain.err);
  const bare = JSON.parse(
    await readFile(path.join(artifacts, day, "pins/plain/pin.json")),
  );
  assert.equal(bare.subject, undefined);

  const refused = {
    "commit without path": ["--subject-commit", "HEAD"],
    "path without commit": ["--subject-path", "scripts/lab"],
    "unknown commit": [
      "--subject-commit",
      "0".repeat(40),
      "--subject-path",
      "scripts/lab",
    ],
    "path not in the commit": [
      "--subject-commit",
      "HEAD",
      "--subject-path",
      "no/such/dir",
    ],
  };
  for (const [name, flags] of Object.entries(refused)) {
    const attempt = gate("--pin", run.id, "--as", `x-${name.length}`, ...flags);
    assert.equal(attempt.code, 2, `${name}: ${attempt.out}${attempt.err}`);
  }
  const gating = gate(
    run.id,
    "--against",
    "plain",
    "--subject-commit",
    "HEAD",
    "--subject-path",
    "scripts/lab",
  );
  assert.equal(gating.code, 2, "subject flags need --pin");
});
