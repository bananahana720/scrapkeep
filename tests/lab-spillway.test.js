// JL-27: the Jev Lab on Spillway Drop, Node side. The sketch runs through
// JL-26's `godot-launch.mjs --sketch`; its stage metrics are registered under
// metrics/index.mjs STAGES as "spillway-drop", measure() turns the scenario
// results the lab branch's runner prints into them, and a batch on that sketch
// records them in run.json. No Godot is started here: the batch case wraps
// fake-godot in a shell that prints a Spillway scenario line after it. The
// drift case holds the lab branch's copy of jev_io.gd to ball-lab's, byte for
// byte. The Godot side has its own tests under the lab worktree's
// sketches/spillway-drop.
import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { fakeGodot, runBatch } from "../scripts/lab/harness.mjs";
import { godotLaunch, stageFor } from "../scripts/lab/godot-launch.mjs";
import {
  METRICS,
  STAGES,
  getMetric,
  registryFor,
} from "../scripts/lab/metrics/index.mjs";
import spillway, { measure } from "../scripts/lab/metrics/spillway.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const LAB_BRANCH = "lab/spillway-drop";
const JEV_IO = "src/jev/jev_io.gd";

function git(cwd, ...args) {
  const result = spawnSync("git", args, { cwd, encoding: "buffer" });
  return {
    status: result.status,
    stdout: result.stdout,
    stderr: String(result.stderr),
  };
}

async function temporary(t) {
  const dir = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-spillway-"));
  t.after(() => rm(dir, { recursive: true, force: true }));
  return dir;
}

async function fakeSketch(dir, name) {
  const sketch = path.join(dir, name);
  await mkdir(sketch, { recursive: true });
  await writeFile(path.join(sketch, "project.godot"), "config_version=5\n");
  return sketch;
}

// --- the registry ---------------------------------------------------------------

test("Spillway's stage metrics sit under STAGES beside the plan's, with ids of their own", () => {
  assert.ok(Object.hasOwn(STAGES, "spillway-drop"));
  const stage = STAGES["spillway-drop"];
  assert.equal(stage.measure, measure);
  assert.deepEqual(
    stage.metrics.map((one) => one.id),
    spillway.map((one) => one.id),
  );
  for (const metric of spillway) {
    assert.match(metric.id, /^spillway_/);
    assert.equal(getMetric(metric.id).id, metric.id);
  }
  assert.equal(
    registryFor("spillway-drop").length,
    METRICS.length + spillway.length,
  );
});

test("stageFor gives a spillway-drop sketch its registry and measure", async (t) => {
  const sketch = await fakeSketch(await temporary(t), "spillway-drop");
  const stage = stageFor(sketch);
  assert.equal(stage.measure, measure);
  assert.equal(stage.registry.length, registryFor("spillway-drop").length);
  assert.match(godotLaunch({ sketch }).label, /sketch spillway-drop/);
});

// --- measure --------------------------------------------------------------------

function result(overrides) {
  return {
    id: "mid-climb",
    result: "timeout",
    snapshots: 10,
    multi: 8,
    offered: { push_objective: 10, hit_kicker: 6, ram_target: 4 },
    kept: { push_objective: 10, hit_kicker: 6, ram_target: 1 },
    route: "",
    dead_tick: -1,
    caught: false,
    threat_rule: "stage-threat-rule 2",
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

test("measure turns mid-climb results into choice, climb, route, death and gate metrics", () => {
  const run = recorder();
  measure(run, [
    result({ result: "success", route: "chute" }),
    result({ route: "bypass", dead_tick: 900, multi: 4 }),
    result({ route: "" }),
  ]);
  const { seen } = run;
  assert.equal(seen.spillway_choice_share.bucket, "kpi");
  assert.equal(seen.spillway_choice_share.value, 20 / 30);
  assert.equal(seen.spillway_choice_share.ci, null);
  assert.equal(seen.spillway_climb_success.value, 1 / 3);
  assert.equal(seen.spillway_climb_success.ci.length, 2);
  // Two trials reached the shelf, one by a chute.
  assert.equal(seen.spillway_chute_share.value, 0.5);
  assert.equal(seen.spillway_chute_share.n, 2);
  assert.equal(seen.spillway_deaths.bucket, "kri");
  assert.equal(seen.spillway_deaths.value, 1 / 3);
  // 60 offers, 51 kept: the gate removed 3 ram offers per trial.
  assert.equal(seen.spillway_gated_offer_share.value, 9 / 60);
  assert.equal(seen.spillway_hatch_success, undefined);
  assert.equal(seen.spillway_flood_caught, undefined);
});

test("measure turns flood-hatch results into hatch success and flood caught", () => {
  const run = recorder();
  measure(run, [
    result({ id: "flood-hatch", result: "success", caught: true }),
    result({ id: "flood-hatch", caught: false }),
  ]);
  assert.equal(run.seen.spillway_hatch_success.value, 0.5);
  assert.equal(run.seen.spillway_flood_caught.value, 0.5);
  assert.equal(run.seen.spillway_climb_success, undefined);
  assert.equal(run.seen.spillway_chute_share, undefined);
});

test("measure records nothing without a parsed result", () => {
  const run = recorder();
  measure(run, []);
  assert.deepEqual(run.seen, {});
});

// --- a batch --------------------------------------------------------------------

test("a batch on Spillway Drop records the stage metrics in run.json", async (t) => {
  const dir = await temporary(t);
  const repository = path.join(dir, "repository");
  await mkdir(path.join(repository, "src"), { recursive: true });
  const run = (...args) => assert.equal(git(repository, ...args).status, 0);
  run("init", "-q", "-b", "lab");
  await writeFile(path.join(repository, "src/tuning.txt"), "speed = 4\n");
  run("add", ".");
  run(
    "-c",
    "user.name=t",
    "-c",
    "user.email=t@t",
    "commit",
    "-q",
    "-m",
    "fixture",
  );
  const line = `jev_run: scenario ${JSON.stringify(result({ result: "success", route: "chute" }))}`;
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
  launch.label = "fake-godot sketch spillway-drop";
  const { record } = await runBatch({
    scenario: "downhill-run",
    arm: "random",
    trials: 2,
    launch,
    ...stageFor(await fakeSketch(dir, "spillway-drop")),
    runs: { root: path.join(dir, "runs"), repository, sources: ["src"] },
  });
  assert.equal(record.config.scenario_results.success, 2);
  const written = JSON.parse(
    await readFile(path.join(dir, "runs", record.id, "run.json"), "utf8"),
  );
  assert.equal(written.kpis.spillway_choice_share.value, 0.8);
  assert.equal(written.kpis.spillway_choice_share.n, 20);
  assert.equal(written.kpis.spillway_climb_success.value, 1);
  assert.equal(written.kpis.spillway_chute_share.value, 1);
  assert.equal(written.kris.spillway_deaths.value, 0);
  assert.equal(
    written.config.trials[0].scenario_result.threat_rule,
    "stage-threat-rule 2",
  );
});

// --- drift ----------------------------------------------------------------------

// JL-27 ported jev_io.gd to Spillway byte for byte; both halves of protocol v1
// must stay one file. The lab branch lives in this repository's refs, so the
// check reads it with git; it skips, saying so, where the branch is absent.
test("the lab branch's Spillway jev_io.gd is byte-identical to ball-lab's", (t) => {
  const ref = git(
    root,
    "rev-parse",
    "--verify",
    "--quiet",
    `${LAB_BRANCH}^{commit}`,
  );
  if (ref.status !== 0) {
    t.skip(`no ${LAB_BRANCH} branch in this repository`);
    return;
  }
  const copy = git(
    root,
    "show",
    `${LAB_BRANCH}:sketches/spillway-drop/${JEV_IO}`,
  );
  assert.equal(copy.status, 0, copy.stderr);
  const reference = git(root, "show", `HEAD:sketches/ball-lab/${JEV_IO}`);
  assert.equal(reference.status, 0, reference.stderr);
  assert.ok(
    Buffer.compare(copy.stdout, reference.stdout) === 0,
    `${LAB_BRANCH} sketches/spillway-drop/${JEV_IO} differs from ball-lab's`,
  );
});
