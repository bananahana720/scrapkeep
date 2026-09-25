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
