import ballLab from "./ball-lab.mjs";
import cableBench, { measure as cableBenchMeasure } from "./cable-bench.mjs";
import core from "./core.mjs";
import tdd from "./tdd.mjs";
import program from "./program.mjs";
import human from "./human.mjs";

const KEYS = ["id", "layer", "kind", "sentinel", "thresholds", "min_n", "says"];
const LAYERS = new Set([
  "mechanics",
  "agent",
  "stability",
  "pipeline",
  "tdd",
  "program",
  "human",
]);
const KINDS = new Set(["kpi", "kri"]);

function thresholdProblem(thresholds) {
  if (thresholds === null) return null;
  const { worse, warn, fail } = thresholds;
  if (Object.keys(thresholds).toSorted().join() !== "fail,warn,worse") {
    return "thresholds must be {worse, warn, fail}";
  }
  if (!Number.isFinite(warn) || !Number.isFinite(fail))
    return "thresholds must be finite";
  if (worse === "higher" && fail > warn) return null;
  if (worse === "lower" && fail < warn) return null;
  return "fail must lie beyond warn in the worse direction";
}

function problems(metric) {
  const found = [];
  if (Object.keys(metric).toSorted().join() !== KEYS.toSorted().join()) {
    found.push(`keys must be ${KEYS.join(", ")}`);
  }
  if (typeof metric.id !== "string" || !/^[a-z][a-z0-9_]*$/.test(metric.id))
    found.push("bad id");
  if (!LAYERS.has(metric.layer)) found.push(`unknown layer ${metric.layer}`);
  if (!KINDS.has(metric.kind)) found.push(`unknown kind ${metric.kind}`);
  if (typeof metric.sentinel !== "boolean")
    found.push("sentinel must be boolean");
  if (!Number.isInteger(metric.min_n) || metric.min_n < 1)
    found.push("min_n must be a positive integer");
  if (typeof metric.says !== "string" || metric.says.trim() === "")
    found.push("says is required");
  if (metric.sentinel && metric.thresholds !== null)
    found.push("a sentinel takes no thresholds");
  const threshold =
    typeof metric.thresholds === "object"
      ? thresholdProblem(metric.thresholds)
      : "thresholds must be an object or null";
  if (threshold) found.push(threshold);
  return found;
}

export function mergeLayers(...layers) {
  const byId = new Map();
  for (const metric of layers.flat()) {
    const found = problems(metric);
    if (found.length > 0)
      throw new Error(`metric ${metric.id}: ${found.join("; ")}`);
    if (byId.has(metric.id))
      throw new Error(`duplicate metric id ${metric.id}`);
    const thresholds =
      metric.thresholds === null
        ? null
        : Object.freeze({ ...metric.thresholds });
    byId.set(metric.id, Object.freeze({ ...metric, thresholds }));
  }
  return Object.freeze([...byId.values()]);
}

export const METRICS = mergeLayers(ballLab, core, tdd, program, human);

// Stage layers outside the plan's table, keyed by sketch name (JL-26). A batch
// on that sketch records against METRICS plus the stage's own metrics, and the
// stage's measure() turns its scenario results into values.
export const STAGES = Object.freeze({
  "cable-bench": Object.freeze({
    metrics: mergeLayers(cableBench),
    measure: cableBenchMeasure,
  }),
});

const ALL = [
  METRICS,
  ...Object.values(STAGES).map((stage) => stage.metrics),
].flat();
// Refuses a stage id that collides with the plan's or another stage's.
mergeLayers(ALL);

export function registryFor(sketch) {
  if (!Object.hasOwn(STAGES, sketch)) return METRICS;
  return Object.freeze([...METRICS, ...STAGES[sketch].metrics]);
}

const REGISTRY = new Map(ALL.map((metric) => [metric.id, metric]));

export function getMetric(id) {
  const metric = REGISTRY.get(id);
  if (!metric) throw new Error(`unknown metric id ${id}`);
  return metric;
}
