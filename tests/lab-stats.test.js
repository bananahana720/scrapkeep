import test from "node:test";
import assert from "node:assert/strict";
import {
  mkdir,
  mkdtemp,
  readdir,
  readFile,
  rm,
  writeFile,
} from "node:fs/promises";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { STATUS, evaluate } from "../scripts/lab/metrics/status.mjs";
import { METRICS, getMetric } from "../scripts/lab/metrics/index.mjs";
import { SCHEMA } from "../scripts/lab/record.mjs";
import {
  MixedEpochError,
  aggregate,
  compareToPin,
  epochKey,
  epochOf,
  latestReading,
  loadModel,
  loadPins,
} from "../scripts/lab/model.mjs";
import { main as statsMain } from "../scripts/lab/stats-cli.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const statsScript = path.join(root, "scripts/lab/stats-cli.mjs");
const gateScript = path.join(root, "scripts/lab/gate.mjs");
const HOUR = 3_600_000;

const Q1 = "1".repeat(64);
const Q2 = "2".repeat(64);

function record(id, overrides = {}) {
  const finished = overrides.finished ?? new Date();
  const base = {
    schema: SCHEMA,
    id,
    type: "suite",
    label: "ball-lab",
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
      },
      versions: { node: process.version },
      instrument: null,
      jev: { model: null, calls: 0, cache_hits: 0 },
    },
    config: {},
    kpis: { suite_wall_s: { value: 10, n: 20, ci: null } },
    kris: {
      suite_pass: { value: 0, n: 20, ci: null },
      flake_rate: { value: 0, n: 40, ci: null },
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

function instrument(questions_sha, model = "jev-1") {
  return { instrument: { questions_sha, model }, jev: { model } };
}

async function fixture(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-stats-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const runs = path.join(temporary, "runs");
  const artifacts = path.join(temporary, "artifacts");
  await mkdir(runs, { recursive: true });
  const write = async (run, { index = true } = {}) => {
    await mkdir(path.join(runs, run.id), { recursive: true });
    await writeFile(
      path.join(runs, run.id, "run.json"),
      JSON.stringify(run, null, 2) + "\n",
    );
    if (index) {
      const line = {
        seq: run.seq,
        id: run.id,
        type: run.type,
        label: run.label,
        result: run.result,
      };
      await writeFile(
        path.join(runs, "index.ndjson"),
        JSON.stringify(line) + "\n",
        { flag: "a" },
      );
    }
    return run;
  };
  const pin = async (name, run, { day = "2026-09-25", pinnedAt } = {}) => {
    const directory = path.join(artifacts, `jev-lab-${day}`, "pins", name);
    await mkdir(directory, { recursive: true });
    await writeFile(path.join(directory, "run.json"), JSON.stringify(run));
    await writeFile(
      path.join(directory, "pin.json"),
      JSON.stringify({
        name,
        run_id: run.id,
        pinned_at: pinnedAt ?? `${day}T12:00:00.000Z`,
      }),
    );
    return directory;
  };
  const stats = (...args) => {
    const result = spawnSync(
      process.execPath,
      [statsScript, ...args, "--runs", runs, "--artifacts", artifacts],
      { encoding: "utf8" },
    );
    return { code: result.status, out: result.stdout, err: result.stderr };
  };
  const gate = (...args) => {
    const result = spawnSync(
      process.execPath,
      [gateScript, ...args, "--runs", runs, "--artifacts", artifacts],
      { encoding: "utf8" },
    );
    return { code: result.status, out: result.stdout, err: result.stderr };
  };
  return { temporary, runs, artifacts, write, pin, stats, gate };
}

test("epochOf reads the question sha and the model Jev answered as", () => {
  const plain = record("plain");
  assert.deepEqual(epochOf(plain), { questions_sha: null, model: null });
  const jev = record("jev", { provenance: instrument(Q1, "jev-1") });
  assert.deepEqual(epochOf(jev), { questions_sha: Q1, model: "jev-1" });
  const intended = record("intended", {
    provenance: { instrument: { questions_sha: Q1, model: "jev-2" } },
  });
  assert.equal(epochOf(intended).model, "jev-2");
  assert.notEqual(
    epochKey(epochOf(jev)),
    epochKey(epochOf(intended)),
    "a different model is a different epoch",
  );
});

test("loadModel keeps the latest record per type and label, by seq", async (t) => {
  const { runs, write } = await fixture(t);
  await write(record("r0", { seq: 0 }));
  await write(record("r1", { seq: 1, label: "all" }));
  await write(
    record("r2", {
      seq: 2,
      kpis: { suite_wall_s: { value: 12, n: 20, ci: null } },
    }),
  );
  const model = await loadModel({ root: runs });
  assert.deepEqual(
    model.records.map((one) => one.id),
    ["r0", "r1", "r2"],
  );
  assert.deepEqual([...model.latest.keys()].toSorted(), [
    "suite/all",
    "suite/ball-lab",
  ]);
  assert.equal(model.latest.get("suite/ball-lab").id, "r2");
  assert.deepEqual(model.problems, []);
  const reading = latestReading(model, "suite_wall_s");
  assert.equal(reading.record.id, "r2");
  assert.equal(reading.measure.value, 12);
  assert.equal(reading.series, "suite/ball-lab");
  assert.equal(latestReading(model, "lever_effect"), null);
});

test("trends are per metric and series, and break at every epoch boundary", async (t) => {
  const { runs, write } = await fixture(t);
  const wall = (value) => ({ suite_wall_s: { value, n: 20, ci: null } });
  await write(
    record("a", { seq: 0, kpis: wall(10), provenance: instrument(Q1) }),
  );
  await write(
    record("b", { seq: 1, kpis: wall(11), provenance: instrument(Q1) }),
  );
  await write(
    record("c", { seq: 2, kpis: wall(12), provenance: instrument(Q2) }),
  );
  await write(
    record("d", {
      seq: 3,
      kpis: wall(13),
      provenance: instrument(Q2, "jev-2"),
    }),
  );
  await write(
    record("e", { seq: 4, kpis: wall(14), provenance: instrument(Q1) }),
  );
  const model = await loadModel({ root: runs });
  const segments = model.trends.get("suite_wall_s").get("suite/ball-lab");
  assert.deepEqual(
    segments.map((segment) => segment.points.map((point) => point.value)),
    [[10, 11], [12], [13], [14]],
  );
  assert.deepEqual(
    model.epochs.map(({ questions_sha, model: name, runs: count }) => [
      questions_sha,
      name,
      count,
    ]),
    [
      [Q1, "jev-1", 3],
      [Q2, "jev-1", 1],
      [Q2, "jev-2", 1],
    ],
  );
  assert.equal(model.boundaries.length, 3, "a boundary at seq 2, 3 and 4");
  assert.deepEqual(
    model.boundaries.map((boundary) => boundary.seq),
    [2, 3, 4],
  );
});

test("aggregate pools one epoch and refuses mixed question shas or models", async (t) => {
  const { runs, write } = await fixture(t);
  const wall = (value) => ({ suite_wall_s: { value, n: 10, ci: null } });
  await write(
    record("a", { seq: 0, kpis: wall(10), provenance: instrument(Q1) }),
  );
  await write(
    record("b", { seq: 1, kpis: wall(20), provenance: instrument(Q1) }),
  );
  await write(
    record("c", { seq: 2, kpis: wall(30), provenance: instrument(Q2) }),
  );
  await write(
    record("d", {
      seq: 3,
      kpis: wall(40),
      provenance: instrument(Q1, "jev-2"),
    }),
  );
  const model = await loadModel({ root: runs });
  const [first, second, third, fourth] = model.trends
    .get("suite_wall_s")
    .get("suite/ball-lab");
  assert.deepEqual(aggregate(first.points), {
    value: 15,
    n: 20,
    epoch: epochKey({ questions_sha: Q1, model: "jev-1" }),
  });
  assert.throws(
    () => aggregate([...first.points, ...second.points]),
    (error) =>
      error instanceof MixedEpochError && /question/.test(error.message),
  );
  assert.throws(
    () => aggregate([...first.points, ...third.points]),
    (error) => error instanceof MixedEpochError && /model/.test(error.message),
  );
  assert.equal(fourth, undefined);
});

test("loadModel scans run directories when the index is missing and never writes", async (t) => {
  const { runs, write, temporary } = await fixture(t);
  await write(record("r0", { seq: 0 }), { index: false });
  await write(record("r1", { seq: 1 }), { index: false });
  const model = await loadModel({ root: runs });
  assert.deepEqual(
    model.records.map((one) => one.id),
    ["r0", "r1"],
  );
  assert.deepEqual((await readdir(runs)).toSorted(), ["r0", "r1"]);
  const empty = await loadModel({ root: path.join(temporary, "absent") });
  assert.deepEqual(empty.records, []);
  assert.deepEqual(empty.epochs, []);
});

test("an index line whose run.json is missing or unreadable is a problem, not a crash", async (t) => {
  const { runs, write } = await fixture(t);
  await write(record("good", { seq: 0 }));
  await writeFile(
    path.join(runs, "index.ndjson"),
    JSON.stringify({ seq: 1, id: "gone" }) + "\n",
    { flag: "a" },
  );
  await mkdir(path.join(runs, "broken"));
  await writeFile(path.join(runs, "broken", "run.json"), "{ not json");
  await writeFile(
    path.join(runs, "index.ndjson"),
    JSON.stringify({ seq: 2, id: "broken" }) + "\n",
    { flag: "a" },
  );
  const model = await loadModel({ root: runs });
  assert.deepEqual(
    model.records.map((one) => one.id),
    ["good"],
  );
  assert.equal(model.problems.length, 2);
  assert.match(model.problems.join("\n"), /gone/);
  assert.match(model.problems.join("\n"), /broken/);
});

test("a record whose instrument names one model while Jev answered as another is flagged", async (t) => {
  const { runs, write } = await fixture(t);
  await write(
    record("split", {
      provenance: {
        instrument: { questions_sha: Q1, model: "jev-1" },
        jev: { model: "jev-2" },
      },
    }),
  );
  const model = await loadModel({ root: runs });
  assert.match(model.problems.join("\n"), /split.*jev-1.*jev-2/);
});

test("compareToPin uses the newest pin of the same type and refuses another epoch", async (t) => {
  const { runs, artifacts, write, pin } = await fixture(t);
  await write(
    record("now", {
      seq: 0,
      kpis: { suite_wall_s: { value: 12, n: 20, ci: null } },
    }),
  );
  await pin(
    "old",
    record("p-old", { kpis: { suite_wall_s: { value: 9, n: 20, ci: null } } }),
    {
      day: "2026-09-20",
    },
  );
  await pin(
    "base",
    record("p-new", { kpis: { suite_wall_s: { value: 10, n: 20, ci: null } } }),
  );
  await pin("other-type", record("p-type", { type: "ball-lab" }), {
    day: "2026-09-26",
  });
  await pin(
    "q2",
    record("p-q2", { type: "program", provenance: instrument(Q2) }),
    { day: "2026-09-26" },
  );
  const model = await loadModel({ root: runs });
  const pins = await loadPins(artifacts);
  assert.deepEqual(
    pins.map((one) => one.name),
    ["other-type", "q2", "base", "old"],
  );
  const change = compareToPin(latestReading(model, "suite_wall_s"), pins);
  assert.equal(change.kind, "change");
  assert.equal(change.pin.name, "base");
  assert.equal(change.change, 2);
  assert.equal(
    compareToPin(latestReading(model, "lever_effect"), pins).kind,
    "none",
  );

  const epochRuns = path.join(path.dirname(runs), "epoch-runs");
  await mkdir(path.join(epochRuns, "jev-now"), { recursive: true });
  await writeFile(
    path.join(epochRuns, "jev-now", "run.json"),
    JSON.stringify(
      record("jev-now", { type: "program", provenance: instrument(Q1) }),
    ),
  );
  const epochModel = await loadModel({ root: epochRuns });
  const refused = compareToPin(latestReading(epochModel, "suite_wall_s"), pins);
  assert.equal(refused.kind, "epoch");
  assert.equal(refused.pin.name, "q2");
  assert.deepEqual(await loadPins(path.join(artifacts, "absent")), []);
});

test("stats prints one line per metric: glyph, value, n, change from the pin and the says line", async (t) => {
  const { write, pin, stats } = await fixture(t);
  await write(
    record("now", {
      seq: 0,
      kpis: { suite_wall_s: { value: 12.34567, n: 20, ci: null } },
    }),
  );
  await pin(
    "base",
    record("p", { kpis: { suite_wall_s: { value: 10, n: 20, ci: null } } }),
  );
  const result = stats("--layer", "stability");
  assert.equal(result.code, 0, result.out + result.err);
  const lines = result.out.split("\n");
  const stability = METRICS.filter((metric) => metric.layer === "stability");
  for (const metric of stability) {
    const hits = lines.filter((line) => line.includes(` ${metric.id} `));
    assert.equal(hits.length, 1, `${metric.id} has exactly one line`);
    assert.ok(hits[0].includes(metric.says), `${metric.id} says line`);
  }
  const wall = lines.find((line) => line.includes(" suite_wall_s "));
  const glyph = evaluate(getMetric("suite_wall_s"), {
    value: 12.34567,
    n: 20,
  }).glyph;
  assert.ok(
    wall.trimStart().startsWith(`${glyph} suite_wall_s 12.3457 n=20`),
    wall,
  );
  assert.match(wall, /change \+2\.3457 from pin base/);
  const pass = lines.find((line) => line.includes(" suite_pass "));
  assert.match(pass, /change 0 from pin base/);
  const abort = lines.find((line) => line.includes(" trial_abort_rate "));
  assert.match(abort, /no reading/);
  for (const metric of METRICS.filter((one) => one.layer !== "stability"))
    assert.ok(
      !result.out.includes(` ${metric.id} `),
      `${metric.id} filtered out`,
    );
  assert.match(result.out, /epoch 1 of 1: no instrument/);
});

test("stats with no layer prints every registry metric once", async (t) => {
  const { stats } = await fixture(t);
  const result = stats();
  assert.equal(result.code, 0, result.out + result.err);
  for (const metric of METRICS) {
    const hits = result.out
      .split("\n")
      .filter((line) => line.includes(` ${metric.id} `));
    assert.equal(hits.length, 1, metric.id);
  }
  assert.match(result.out, /no runs under/);
});

test("stats names a pin in another epoch instead of computing a change", async (t) => {
  const { write, pin, stats } = await fixture(t);
  await write(record("now", { provenance: instrument(Q2) }));
  await pin("base", record("p", { provenance: instrument(Q1) }));
  const result = stats("--layer", "stability");
  assert.equal(result.code, 0, result.out + result.err);
  const wall = result.out
    .split("\n")
    .find((line) => line.includes(" suite_wall_s "));
  assert.match(wall, /pin base is in another epoch, not compared/);
  assert.doesNotMatch(wall, /change [+-]?\d/);
});

test("stats refuses an unknown layer or argument with exit 2", async (t) => {
  const { stats } = await fixture(t);
  const layer = stats("--layer", "vibes");
  assert.equal(layer.code, 2);
  assert.match(layer.err, /unknown layer vibes/);
  assert.match(layer.err, /Usage/);
  assert.equal(stats("--bogus").code, 2);
  assert.equal(stats("extra").code, 2);
});

test("stats colours a line with its status's ANSI only on a terminal", async (t) => {
  const { runs, artifacts, write } = await fixture(t);
  await write(
    record("now", { kris: { engine_crash: { value: 1, n: 1, ci: null } } }),
  );
  const capture = (isTTY) => {
    const chunks = [];
    return {
      stream: { isTTY, write: (text) => chunks.push(text) },
      text: () => chunks.join(""),
    };
  };
  const args = [
    "--layer",
    "stability",
    "--runs",
    runs,
    "--artifacts",
    artifacts,
  ];
  const tty = capture(true);
  assert.equal(await statsMain(args, { out: tty.stream, err: tty.stream }), 0);
  const crash = evaluate(getMetric("engine_crash"), { value: 1, n: 1 });
  const line = tty
    .text()
    .split("\n")
    .find((one) => one.includes(" engine_crash "));
  assert.ok(line.includes(`${crash.ansi}${crash.glyph} engine_crash`), line);
  assert.ok(line.endsWith("\x1b[0m"), "reset at the end of the line");
  const plain = capture(false);
  await statsMain(args, { out: plain.stream, err: plain.stream });
  assert.ok(!plain.text().includes("\x1b["), "no escape codes off a terminal");
});

test("stats and model import status only from status.mjs and name no status word", async () => {
  const words = new RegExp(`\\b(${Object.keys(STATUS).join("|")})\\b`, "i");
  for (const file of ["scripts/lab/stats-cli.mjs", "scripts/lab/model.mjs"]) {
    const source = await readFile(path.join(root, file), "utf8");
    assert.equal(words.exec(source), null, file);
    assert.doesNotMatch(source, /#[0-9a-f]{6}\b/i, file);
    assert.doesNotMatch(
      source,
      /\\x1b\[38;/,
      `${file} builds no colour itself`,
    );
  }
});

// JL-12 review N1: the gate's compare line for a score or a share of time
// must say it treats the value as n trials, and a pin rate outside 0..1 must
// be reported rather than skipped.
test("the gate labels approximated rates and reports a pin rate outside 0..1", async (t) => {
  const { write, pin, gate } = await fixture(t);
  const rates = {
    kpis: {
      corpus_blind_weighted: { value: 0.95, n: 200, ci: null },
      first_pass_review: { value: 0.9, n: 100, ci: null },
    },
    kris: { dead_tier: { value: 0.2, n: 200, ci: null } },
  };
  await pin("base", record("p", { type: "ball-lab", ...rates }));
  await write(record("cand", { type: "ball-lab", ...rates }));
  const result = gate("cand", "--against", "base");
  assert.equal(result.code, 0, result.out + result.err);
  const line = (id) =>
    result.out.split("\n").find((one) => one.startsWith(`compare ${id} `));
  assert.match(line("corpus_blind_weighted"), /approximated as n trials/);
  assert.match(line("dead_tier"), /approximated as n trials/);
  assert.doesNotMatch(line("first_pass_review"), /approximated/);
  assert.doesNotMatch(line("flake_rate"), /approximated/);

  await pin(
    "scaled",
    record("p2", {
      type: "ball-lab",
      kpis: { first_pass_review: { value: 95, n: 100, ci: null } },
    }),
  );
  const scaled = gate("cand", "--against", "scaled");
  assert.equal(scaled.code, 3, scaled.out + scaled.err);
  assert.match(
    scaled.out,
    /compare first_pass_review: the pin's rate 95 is not a proportion in 0\.\.1, inconclusive/,
  );

  await write(
    record("cand-scaled", {
      type: "ball-lab",
      ...rates,
      kpis: {
        ...rates.kpis,
        first_pass_review: { value: 90, n: 100, ci: null },
      },
    }),
  );
  const candidate = gate("cand-scaled", "--against", "base");
  assert.equal(candidate.code, 3, candidate.out + candidate.err);
  assert.match(
    candidate.out,
    /compare first_pass_review: the candidate's rate 90 is not a proportion in 0\.\.1, inconclusive/,
  );
});
