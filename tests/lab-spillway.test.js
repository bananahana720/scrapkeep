// JL-27: the Jev Lab on Spillway Drop, Node side. The launcher can point the
// runner at a sketch outside this checkout (the lab worktree) and stamps that
// sketch's repository into the record; the stage metrics in
// scripts/lab/metrics/spillway.mjs have the registry's shape, do not collide with
// the plan registry, and are computed from a retained batch directory. The
// Godot side has its own tests under the lab worktree's sketches/spillway-drop.
import test from "node:test";
import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  godotLaunch,
  SKETCH,
  sketchProvenance,
} from "../scripts/lab/godot-launch.mjs";
import { METRICS, mergeLayers } from "../scripts/lab/metrics/index.mjs";
import spillway, {
  spillwayMeasures,
  summarizeBatch,
} from "../scripts/lab/metrics/spillway.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

test("godotLaunch takes another sketch directory and keeps ball-lab as the default", () => {
  const request = {
    io: "/tmp/io",
    scenario: "mid-climb",
    seed: 1000,
    trial: 0,
    snapshotEvery: 90,
    holdTicks: 26,
  };
  const other = "/elsewhere/sketches/spillway-drop";
  const { args } = godotLaunch({ sketch: other })(request);
  assert.equal(args[args.indexOf("--path") + 1], other);
  assert.match(godotLaunch({ sketch: other }).label, /spillway-drop/);
  const plain = godotLaunch()(request);
  assert.equal(plain.args[plain.args.indexOf("--path") + 1], SKETCH);
  assert.doesNotMatch(godotLaunch().label, /ball-lab/);
});

test("sketchProvenance stamps the sketch's repository head, branch and dirty flag", () => {
  const stamp = sketchProvenance(path.join(root, "sketches/ball-lab"));
  assert.match(stamp.head, /^[0-9a-f]{40}$/);
  assert.equal(typeof stamp.dirty, "boolean");
  assert.equal(stamp.path, path.join(root, "sketches/ball-lab"));
  assert.ok("branch" in stamp);
});

test("the spillway stage metrics have the registry shape and no plan id", () => {
  assert.ok(spillway.length >= 5);
  const merged = mergeLayers(METRICS, spillway);
  assert.equal(merged.length, METRICS.length + spillway.length);
  for (const metric of spillway) assert.match(metric.id, /^spillway_/);
});

// A batch directory as the harness retains it: run.json with each trial's
// scenario_result, and the state files the arm saw.
async function fakeBatch(directory, scenario, trials) {
  await mkdir(directory, { recursive: true });
  const entries = [];
  for (const [i, trial] of trials.entries()) {
    const io = path.join(directory, "trials", String(i).padStart(3, "0"));
    await mkdir(io, { recursive: true });
    for (const [seq, options] of trial.states.entries()) {
      const state = {
        protocol: "scrapkeep-jev/1",
        seq,
        tick: seq * 90,
        held: null,
        jev: {
          state: {
            self: { speed_ms: 5, speed_tier: "walk", grounded: true },
            stage: { name: "spillway-drop", time_s: seq, tier: 1 },
            threats: [],
            objective: { kind: "reach_shelf", distance_m: 90 },
          },
          options: options.map((id) => ({ id, why: "test" })),
        },
        sim: { pos: [0, 0, 0], vel: [0, 0, 0] },
      };
      await writeFile(
        path.join(io, `state-${String(seq).padStart(6, "0")}.json`),
        JSON.stringify(state),
      );
    }
    entries.push({
      trial: i,
      outcome: "complete",
      trace_hash: `h${i}`,
      scenario_result: trial.result,
    });
  }
  await writeFile(
    path.join(directory, "run.json"),
    JSON.stringify({
      id: path.basename(directory),
      config: {
        scenario,
        arm: "random",
        launcher: "godot-headless x kinematic",
        trials: entries,
      },
    }),
  );
}

test("summarizeBatch counts choice snapshots after the gate, routes, deaths and the flood", async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), "jl27-"));
  try {
    const climb = path.join(dir, "climb");
    await fakeBatch(climb, "mid-climb", [
      {
        // ram_target is gated out at walk tier, so the second state is forced.
        states: [
          ["push_objective", "hit_kicker"],
          ["push_objective", "ram_target"],
        ],
        result: { result: "success", route: "chute", dead_tick: -1 },
      },
      {
        states: [["push_objective", "hit_kicker", "sweep_scrap"]],
        result: { result: "success", route: "bypass", dead_tick: -1 },
      },
      {
        states: [["push_objective"]],
        result: { result: "timeout", route: "", dead_tick: 400 },
      },
    ]);
    const summary = await summarizeBatch(climb);
    assert.equal(summary.scenario, "mid-climb");
    assert.equal(summary.mode, "kinematic");
    assert.deepEqual(summary.choice, { states: 4, multi: 2, share: 0.5 });
    assert.deepEqual(summary.routes, {
      chute: 1,
      bypass: 1,
      other: 0,
      none: 1,
    });
    assert.equal(summary.success, 2);
    assert.equal(summary.deaths, 1);
    const measures = spillwayMeasures(summary);
    assert.equal(measures.spillway_choice_share.value, 0.5);
    assert.equal(measures.spillway_chute_share.value, 0.5);
    assert.equal(measures.spillway_chute_share.n, 2);
    assert.equal(measures.spillway_climb_success.value, 2 / 3);
    assert.equal(measures.spillway_deaths.value, 1 / 3);
    assert.equal(measures.spillway_flood_caught, undefined);
    // Snapshots within a trial are not independent draws, so the choice share
    // carries no interval; the trial-level shares carry Wilson's.
    assert.equal(measures.spillway_choice_share.ci, null);
    for (const [id, measure] of Object.entries(measures)) {
      assert.ok(
        spillway.some((metric) => metric.id === id),
        id,
      );
      if (id !== "spillway_choice_share") assert.equal(measure.ci.length, 2);
    }

    const flood = path.join(dir, "flood");
    await fakeBatch(flood, "flood-hatch", [
      {
        states: [["push_objective", "evade_hazard"]],
        result: { result: "success", caught: true, dead_tick: -1 },
      },
      {
        states: [["push_objective", "evade_hazard"]],
        result: { result: "timeout", caught: false, dead_tick: -1 },
      },
    ]);
    const floodMeasures = spillwayMeasures(await summarizeBatch(flood));
    assert.equal(floodMeasures.spillway_flood_caught.value, 0.5);
    assert.equal(floodMeasures.spillway_hatch_success.value, 0.5);
    assert.equal(floodMeasures.spillway_chute_share, undefined);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});
