// Cable Bench's stage metrics (JL-26). They are not in the plan's table, so
// index.mjs keeps them out of METRICS and registers them under STAGES: a batch
// on the cable-bench sketch records against METRICS plus these. measure()
// turns the scenario results that sketches/cable-bench/src/jev/jev_run.gd
// prints into their values. None has plan thresholds yet.
import { wilson } from "../stats.mjs";

export default [
  {
    id: "choice_share",
    layer: "mechanics",
    kind: "kpi",
    sentinel: false,
    thresholds: null,
    min_n: 20,
    says: "Share of snapshots offering two or more options after the precondition gate; below one half, the arms mostly answer forced.",
  },
  {
    id: "stage_success_rate",
    layer: "mechanics",
    kind: "kpi",
    sentinel: false,
    thresholds: null,
    min_n: 20,
    says: "Share of trials whose scenario succeeded: the exit taken on the forge scenarios, the next bench reached on bench-one.",
  },
  {
    id: "caches_per_trial",
    layer: "mechanics",
    kind: "kpi",
    sentinel: false,
    thresholds: null,
    min_n: 20,
    says: "Caches opened per trial, the stage's one-more-cache question.",
  },
  {
    id: "tier_at_charge",
    layer: "mechanics",
    kind: "kpi",
    sentinel: false,
    thresholds: null,
    min_n: 20,
    says: "Difficulty tier when the forge charge started, over the trials that started it.",
  },
  {
    id: "scrap_per_trial",
    layer: "mechanics",
    kind: "kpi",
    sentinel: false,
    thresholds: null,
    min_n: 20,
    says: "Scrap collected per trial.",
  },
  {
    id: "ledge_visits_per_trial",
    layer: "mechanics",
    kind: "kpi",
    sentinel: false,
    thresholds: null,
    min_n: 20,
    says: "Times per trial the ball came to rest on a high bench's top, by kicker or chute.",
  },
  {
    id: "scrapped_rate",
    layer: "mechanics",
    kind: "kri",
    sentinel: false,
    thresholds: null,
    min_n: 20,
    says: "Share of trials that ended at 0 HP.",
  },
  {
    id: "gated_offer_share",
    layer: "mechanics",
    kind: "kri",
    sentinel: false,
    thresholds: null,
    min_n: 20,
    says: "Share of offered options the precondition gate removed; an option offered where the ball can never meet its gate raises it.",
  },
  {
    id: "cableway_hits_per_trial",
    layer: "mechanics",
    kind: "kri",
    sentinel: false,
    thresholds: null,
    min_n: 20,
    says: "Cableway strikes on the ball per trial.",
  },
];

const TICK_HZ = 90;
const TIER_SECONDS = 45;

const sum = (values) => values.reduce((total, value) => total + value, 0);
const counts = (table) => sum(Object.values(table ?? {}));

// `results` are the batch's scenario results that parsed. Snapshots and offers
// within one trial are not independent draws, so their shares carry no
// interval; trial-level rates carry Wilson's.
export function measure(run, results) {
  const n = results.length;
  if (n === 0) return;
  const rate = (id, bucket, hits) => {
    const interval = wilson(hits, n);
    run[bucket](id, {
      value: hits / n,
      n,
      ci: [interval.lower, interval.upper],
    });
  };
  const mean = (id, bucket, values) =>
    run[bucket](id, {
      value: sum(values) / values.length,
      n: values.length,
      ci: null,
    });

  const snapshots = sum(results.map((one) => one.snapshots ?? 0));
  if (snapshots > 0) {
    run.kpi("choice_share", {
      value: sum(results.map((one) => one.multi ?? 0)) / snapshots,
      n: snapshots,
      ci: null,
    });
  }
  rate(
    "stage_success_rate",
    "kpi",
    results.filter((one) => one.result === "success").length,
  );
  mean(
    "caches_per_trial",
    "kpi",
    results.map((one) => one.caches_opened ?? 0),
  );
  const charged = results.filter((one) => (one.charge_tick ?? -1) >= 0);
  if (charged.length > 0) {
    mean(
      "tier_at_charge",
      "kpi",
      charged.map(
        (one) => 1 + Math.floor(one.charge_tick / TICK_HZ / TIER_SECONDS),
      ),
    );
  }
  mean(
    "scrap_per_trial",
    "kpi",
    results.map((one) => one.scrap_taken ?? 0),
  );
  mean(
    "ledge_visits_per_trial",
    "kpi",
    results.map((one) => (one.mesa_visits ?? []).length),
  );
  rate(
    "scrapped_rate",
    "kri",
    results.filter((one) => one.end === "scrapped").length,
  );
  const offered = sum(results.map((one) => counts(one.offered)));
  if (offered > 0) {
    const kept = sum(results.map((one) => counts(one.kept)));
    run.kri("gated_offer_share", {
      value: (offered - kept) / offered,
      n: offered,
      ci: null,
    });
  }
  mean(
    "cableway_hits_per_trial",
    "kri",
    results.map((one) => one.cableway_hits ?? 0),
  );
}
