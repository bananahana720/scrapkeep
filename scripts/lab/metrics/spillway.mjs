// Spillway Drop's stage metrics (JL-27), measured on the lab branch
// lab/spillway-drop through `godot-launch.mjs --sketch`. The definitions have the
// registry's shape and ids of their own, but they are not merged into
// index.mjs's METRICS: that registry is pinned to the plan's table by
// tests/lab-metrics.test.js, and adding a stage layer there is the
// coordinator's call. harness.mjs does not record them in run.json either;
// summarizeBatch() reads a retained batch directory and spillwayMeasures()
// turns it into {value, n, ci} per metric, the shape run.kpi()/kri() take.
//
// Scenarios (sketches/spillway-drop/src/jev/scenarios.gd on lab/spillway-drop):
// mid-climb (basin to mid shelf: a chute or the bypass ramp) and flood-hatch
// (ride the flood out in the basin or climb out, then reach the open hatch).
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

import { offeredOptions } from "../../../tools/jev-player/protocol/protocol.mjs";
import { wilson } from "../stats.mjs";

const metric = (id, kind, says, minN = 20) => ({
  id,
  layer: "mechanics",
  kind,
  sentinel: false,
  thresholds: null,
  min_n: minN,
  says,
});

export default [
  metric(
    "spillway_choice_share",
    "kpi",
    "Share of Spillway Drop snapshots that offer the arm two or more options after the precondition gate; below 0.5 the scenario mostly forces the answer.",
  ),
  metric(
    "spillway_climb_success",
    "kpi",
    "Share of mid-climb trials that reach the mid-shelf objective alive within the limit.",
  ),
  metric(
    "spillway_chute_share",
    "kpi",
    "Share of basin-to-mid climbs carried by a chute rather than the bypass ramp: the stage's route question.",
  ),
  metric(
    "spillway_hatch_success",
    "kpi",
    "Share of flood-hatch trials that reach the open maintenance hatch alive within the limit.",
  ),
  metric(
    "spillway_flood_caught",
    "kri",
    "Share of flood-hatch trials in which the ball sat at least half submerged while the basin was flooded.",
  ),
  metric(
    "spillway_deaths",
    "kri",
    "Share of Spillway Drop trials in which the ball's HP reached zero.",
  ),
];

const count = (map, key) => {
  map[key] = (map[key] ?? 0) + 1;
};

async function jsonFiles(directory, prefix) {
  let names;
  try {
    names = await readdir(directory);
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
  const out = [];
  for (const name of names
    .filter((one) => one.startsWith(prefix) && one.endsWith(".json"))
    .sort()) {
    out.push(JSON.parse(await readFile(path.join(directory, name), "utf8")));
  }
  return out;
}

// One retained batch: run.json plus trials/NNN/{hello,state-*,intent-*}.json.
export async function summarizeBatch(directory) {
  const record = JSON.parse(
    await readFile(path.join(directory, "run.json"), "utf8"),
  );
  const { config } = record;
  const summary = {
    id: record.id,
    scenario: config.scenario,
    arm: config.arm,
    mode: null,
    trials: config.trials.length,
    judged: 0,
    success: 0,
    deaths: 0,
    caught: 0,
    routes: { chute: 0, bypass: 0, other: 0, none: 0 },
    choice: { states: 0, multi: 0, share: null },
    offered: {},
    gated: {},
    intents: {},
    sources: {},
    hashes: [],
  };
  for (const entry of config.trials) {
    summary.hashes.push(entry.trace_hash ?? null);
    const result = entry.scenario_result;
    if (result !== null && result !== undefined) {
      summary.judged += 1;
      if (result.result === "success") summary.success += 1;
      if ((result.dead_tick ?? -1) >= 0) summary.deaths += 1;
      if (result.caught === true) summary.caught += 1;
      if (result.route === "chute" || result.route === "bypass") {
        summary.routes[result.route] += 1;
      } else if (typeof result.route === "string" && result.route !== "") {
        summary.routes.other += 1;
      } else {
        summary.routes.none += 1;
      }
    }
    const io = path.join(
      directory,
      "trials",
      String(entry.trial).padStart(3, "0"),
    );
    const [hello] = await jsonFiles(io, "hello");
    if (summary.mode === null && hello?.physics_mode) {
      summary.mode = hello.physics_mode;
    }
    for (const state of await jsonFiles(io, "state-")) {
      const offered = offeredOptions(state.jev).map((option) => option.id);
      summary.choice.states += 1;
      if (offered.length >= 2) summary.choice.multi += 1;
      for (const id of offered) count(summary.offered, id);
      for (const option of state.jev.options) {
        if (!offered.includes(option.id)) count(summary.gated, option.id);
      }
    }
    for (const intent of await jsonFiles(io, "intent-")) {
      count(summary.intents, intent.intent);
      count(summary.sources, intent.source);
    }
  }
  if (summary.mode === null) {
    summary.mode =
      /\b(kinematic|rigid)\b/.exec(config.launcher ?? "")?.[1] ?? null;
  }
  if (summary.choice.states > 0) {
    summary.choice.share = summary.choice.multi / summary.choice.states;
  }
  return summary;
}

const share = (k, n) => {
  if (n === 0) return { value: null, n: 0, ci: null };
  const interval = wilson(k, n);
  return { value: k / n, n, ci: [interval.lower, interval.upper] };
};

// {metric id: {value, n, ci}} for the metrics this batch's scenario measures.
export function spillwayMeasures(summary) {
  const out = {
    // Snapshots within a trial are not independent draws: no interval.
    spillway_choice_share: {
      value: summary.choice.share,
      n: summary.choice.states,
      ci: null,
    },
    spillway_deaths: share(summary.deaths, summary.judged),
  };
  if (summary.scenario === "mid-climb") {
    const climbs =
      summary.routes.chute + summary.routes.bypass + summary.routes.other;
    out.spillway_climb_success = share(summary.success, summary.judged);
    out.spillway_chute_share = share(summary.routes.chute, climbs);
  }
  if (summary.scenario === "flood-hatch") {
    out.spillway_hatch_success = share(summary.success, summary.judged);
    out.spillway_flood_caught = share(summary.caught, summary.judged);
  }
  return out;
}
