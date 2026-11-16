// JL-26: the Jev Lab on Cable Bench. The launcher runs a sketch at a given
// path, the stage's metrics are registered beside the plan's registry under the
// same rules, and a batch on that sketch records them from the scenario lines
// its Godot runner prints. No Godot is started here: the batch case wraps
// fake-godot in a shell that prints a Cable Bench scenario line after it.
import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { fakeGodot, runBatch } from "../scripts/lab/harness.mjs";
import { SKETCH, godotLaunch, stageFor } from "../scripts/lab/godot-launch.mjs";
import {
  METRICS,
  STAGES,
  getMetric,
  mergeLayers,
  registryFor,
} from "../scripts/lab/metrics/index.mjs";
import cableBench, { measure } from "../scripts/lab/metrics/cable-bench.mjs";

// Its own identity, as the other lab tests do: the gate runs node with a scratch XDG_CONFIG_HOME,
// which hides the machine's.
function git(cwd, ...args) {
  const result = spawnSync(
    "git",
    ["-c", "user.name=Lab Test", "-c", "user.email=lab@example.invalid", "-c", "commit.gpgsign=false", ...args],
    { cwd, encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}

async function temporary(t) {
  const dir = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-cable-"));
  t.after(() => rm(dir, { recursive: true, force: true }));
  return dir;
}

async function fakeSketch(dir, name) {
  const sketch = path.join(dir, name);
  await mkdir(sketch, { recursive: true });
  await writeFile(path.join(sketch, "project.godot"), "config_version=5\n");
  return sketch;
}

// --- the launcher ---------------------------------------------------------------

test("godotLaunch runs the sketch at a given path and names it in the label", async (t) => {
  const sketch = await fakeSketch(await temporary(t), "cable-bench");
  const launch = godotLaunch({ mode: "rigid", sketch });
  const { args } = launch({
    io: "/tmp/io",
    scenario: "bench-one",
    seed: 1000,
    trial: 0,
    snapshotEvery: 90,
    holdTicks: 26,
  });
  const engine = args.slice(0, args.indexOf("--"));
  assert.equal(engine[engine.indexOf("--path") + 1], sketch);
  assert.match(launch.label, /sketch cable-bench/);
  assert.deepEqual(launch.sketch, { name: "cable-bench", path: sketch });
});

test("godotLaunch keeps ball-lab as the default sketch, with the label it had", () => {
  const launch = godotLaunch({ mode: "kinematic" });
  const { args } = launch({
    io: "/tmp/io",
    scenario: "downhill-run",
    seed: 1,
    trial: 0,
    snapshotEvery: 90,
    holdTicks: 26,
  });
  assert.equal(args[args.indexOf("--path") + 1], SKETCH);
  assert.doesNotMatch(launch.label, /sketch/);
  assert.equal(launch.sketch.name, "ball-lab");
});

test("godotLaunch refuses a sketch path with no project.godot", async (t) => {
  const dir = await temporary(t);
  assert.throws(
    () => godotLaunch({ sketch: path.join(dir, "nothing-here") }),
    /project\.godot/,
  );
});

// --- the registry -----------------------------------------------------------------

test("Cable Bench's stage metrics follow the registry rules and sit beside the plan's", () => {
  assert.ok(Object.hasOwn(STAGES, "cable-bench"));
  const stage = STAGES["cable-bench"];
  assert.equal(stage.metrics.length, cableBench.length);
  assert.deepEqual(mergeLayers(cableBench), stage.metrics);
  const plan = new Set(METRICS.map((metric) => metric.id));
  for (const metric of stage.metrics) {
    assert.ok(!plan.has(metric.id), `${metric.id} is not a plan id`);
    assert.equal(getMetric(metric.id), metric);
    assert.ok(Object.isFrozen(metric), `${metric.id} is frozen`);
  }
  const ids = new Set(stage.metrics.map((metric) => metric.id));
  for (const id of [
    "choice_share",
    "stage_success_rate",
    "caches_per_trial",
    "scrapped_rate",
    "gated_offer_share",
  ]) {
    assert.ok(ids.has(id), `${id} is registered`);
  }
  assert.equal(registryFor("ball-lab"), METRICS);
  assert.equal(registryFor("constructor"), METRICS);
  const merged = registryFor("cable-bench");
  assert.equal(merged.length, METRICS.length + stage.metrics.length);
  assert.equal(typeof stage.measure, "function");
});

test("stageFor gives a Cable Bench sketch its registry and measure, and ball-lab none", async (t) => {
  const sketch = await fakeSketch(await temporary(t), "cable-bench");
  const stage = stageFor(sketch);
  assert.equal(stage.registry.length, registryFor("cable-bench").length);
  assert.equal(stage.measure, measure);
  assert.deepEqual(stageFor(SKETCH), {});
});

// --- measure --------------------------------------------------------------------

function result(overrides) {
  return {
    id: "bench-one",
    result: "timeout",
    end: "limit",
    snapshots: 10,
    multi: 6,
    offered: { push_objective: 10, ram_target: 4, stomp_target: 3 },
    kept: { push_objective: 10, stomp_target: 3 },
    caches_opened: 0,
    scrap_taken: 10,
    charge_tick: -1,
    cableway_hits: 0,
    mesa_visits: [],
    ...overrides,
  };
}

function recorder() {
  const seen = {};
  return {
    seen,
    kpi: (id, value) => (seen[id] = { bucket: "kpi", ...value }),
    kri: (id, value) => (seen[id] = { bucket: "kri", ...value }),
  };
}

test("measure turns Cable Bench scenario results into the stage metrics", () => {
  const run = recorder();
  measure(run, [
    result({
      result: "success",
      end: "success",
      caches_opened: 2,
      scrap_taken: 40,
      charge_tick: 90 * 50,
      cableway_hits: 1,
      mesa_visits: [{ tick: 900, mesa: 0 }],
    }),
    result({ end: "scrapped", multi: 2, snapshots: 10 }),
  ]);
  const { seen } = run;
  assert.equal(seen.choice_share.bucket, "kpi");
  assert.equal(seen.choice_share.value, 8 / 20);
  assert.equal(seen.choice_share.n, 20);
  assert.equal(seen.stage_success_rate.value, 0.5);
  assert.equal(seen.stage_success_rate.n, 2);
  assert.equal(seen.stage_success_rate.ci.length, 2);
  assert.equal(seen.caches_per_trial.value, 1);
  assert.equal(seen.scrap_per_trial.value, 25);
  assert.equal(seen.scrapped_rate.bucket, "kri");
  assert.equal(seen.scrapped_rate.value, 0.5);
  // 34 offers, 26 kept: the gate removed the 8 ram offers.
  assert.equal(seen.gated_offer_share.value, 8 / 34);
  assert.equal(seen.gated_offer_share.n, 34);
  assert.equal(seen.cableway_hits_per_trial.value, 0.5);
  assert.equal(seen.ledge_visits_per_trial.value, 0.5);
  // Charge started at 50 s, which is tier 2; one trial started it.
  assert.equal(seen.tier_at_charge.value, 2);
  assert.equal(seen.tier_at_charge.n, 1);
});

test("measure leaves out tier_at_charge when no trial started the charge", () => {
  const run = recorder();
  measure(run, [result({})]);
  assert.equal(run.seen.tier_at_charge, undefined);
  assert.equal(run.seen.choice_share.value, 0.6);
});

// --- a batch --------------------------------------------------------------------

test("a batch on Cable Bench records the stage metrics from its scenario lines", async (t) => {
  const dir = await temporary(t);
  const repository = path.join(dir, "repository");
  await mkdir(path.join(repository, "src"), { recursive: true });
  git(repository, "init", "-q", "-b", "lab");
  await writeFile(path.join(repository, "src/tuning.txt"), "speed = 4\n");
  git(repository, "add", ".");
  git(repository, "commit", "-q", "-m", "fixture");
  const line = `jev_run: scenario ${JSON.stringify(result({ result: "success", end: "success", caches_opened: 1 }))}`;
  const fake = fakeGodot();
  const launch = (request) => {
    const { command, args } = fake(request);
    return {
      command: "/bin/sh",
      args: [
        "-c",
        'if "$0" "$@"; then code=0; else code=$?; fi; printf "%s\\n" "$SCENARIO_LINE"; exit $code',
        command,
        ...args,
      ],
      env: { SCENARIO_LINE: line },
    };
  };
  launch.label = "fake-godot sketch cable-bench";
  const { record } = await runBatch({
    scenario: "downhill-run",
    arm: "random",
    trials: 2,
    launch,
    ...stageFor(await fakeSketch(dir, "cable-bench")),
    runs: { root: path.join(dir, "runs"), repository, sources: ["src"] },
  });
  assert.equal(record.config.scenario_results.success, 2);
  assert.equal(record.kpis.choice_share.value, 0.6);
  assert.equal(record.kpis.stage_success_rate.value, 1);
  assert.equal(record.kpis.caches_per_trial.value, 1);
  assert.equal(record.kris.scrapped_rate.value, 0);
  const written = JSON.parse(
    await readFile(path.join(dir, "runs", record.id, "run.json"), "utf8"),
  );
  assert.equal(written.kpis.choice_share.n, 20);
});
