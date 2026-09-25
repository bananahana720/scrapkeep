// Spillway Drop's stage metrics (JL-27). Like Cable Bench's (JL-26) they sit
// outside the plan's table: metrics/index.mjs registers them under STAGES as
// "spillway-drop", so a batch on that sketch (godot-launch.mjs --sketch)
// records against METRICS plus these, and harness.mjs calls measure() with
// the scenario results that the lab branch's
// sketches/spillway-drop/src/jev/jev_run.gd prints.
//
// Scenarios: mid-climb (basin to mid shelf, by a chute or the bypass ramp)
// and flood-hatch (ride the flood out in the basin or climb out, then reach
// the open hatch). A batch runs one scenario, so each metric is recorded only
// when its scenario's results are there. Snapshots and offers within a trial
// are not independent draws, so their shares carry no interval; trial-level
// rates carry Wilson's.
import { wilson } from "../stats.mjs";

const metric = (id, kind, says) => ({
  id,
  layer: "mechanics",
  kind,
  sentinel: false,
  thresholds: null,
  min_n: 20,
  says,
});

export default [
  metric(
    "spillway_choice_share",
    "kpi",
    "Share of Spillway Drop snapshots that offer two or more options after the precondition gate; below one half, the arms mostly answer forced.",
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
  metric(
    "spillway_gated_offer_share",
    "kri",
    "Share of offered options the precondition gate removed before an arm saw them (mostly ram_target below the fast tier).",
  ),
];

const sum = (values) => values.reduce((total, value) => total + value, 0);
const counts = (table) => sum(Object.values(table ?? {}));

export function measure(run, results) {
  if (results.length === 0) return;
  const rate = (id, bucket, hits, n) => {
    if (n === 0) return;
    const interval = wilson(hits, n);
    run[bucket](id, {
      value: hits / n,
      n,
      ci: [interval.lower, interval.upper],
    });
  };
  const snapshots = sum(results.map((one) => one.snapshots ?? 0));
  if (snapshots > 0) {
    run.kpi("spillway_choice_share", {
      value: sum(results.map((one) => one.multi ?? 0)) / snapshots,
      n: snapshots,
      ci: null,
    });
  }
  rate(
    "spillway_deaths",
    "kri",
    results.filter((one) => (one.dead_tick ?? -1) >= 0).length,
    results.length,
  );
  const offered = sum(results.map((one) => counts(one.offered)));
  if (offered > 0) {
    run.kri("spillway_gated_offer_share", {
      value: (offered - sum(results.map((one) => counts(one.kept)))) / offered,
      n: offered,
      ci: null,
    });
  }
  const climbs = results.filter((one) => one.id === "mid-climb");
  if (climbs.length > 0) {
    rate(
      "spillway_climb_success",
      "kpi",
      climbs.filter((one) => one.result === "success").length,
      climbs.length,
    );
    const routed = climbs.filter(
      (one) => typeof one.route === "string" && one.route !== "",
    );
    rate(
      "spillway_chute_share",
      "kpi",
      routed.filter((one) => one.route === "chute").length,
      routed.length,
    );
  }
  const floods = results.filter((one) => one.id === "flood-hatch");
  if (floods.length > 0) {
    rate(
      "spillway_hatch_success",
      "kpi",
      floods.filter((one) => one.result === "success").length,
      floods.length,
    );
    rate(
      "spillway_flood_caught",
      "kri",
      floods.filter((one) => one.caught === true).length,
      floods.length,
    );
  }
}
