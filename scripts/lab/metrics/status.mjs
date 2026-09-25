// The only file under scripts/lab/ that may name a status or a colour.
// Hex values are the green, yellow, red, dark_foreground and blue keys of
// ~/.config/omarchy/themes/neon-noir/colors.toml. Exit codes follow the gate
// table in plan § 4.

export const EXIT = Object.freeze({
  pass: 0,
  fail: 1,
  usage: 2,
  inconclusive: 3,
  invalid: 4,
});

const SEVERITY = [EXIT.invalid, EXIT.fail, EXIT.inconclusive];

// An invalid instrument voids every other reading, and a definite failure
// outranks a missing answer.
export function worstExit(codes) {
  return SEVERITY.find((code) => codes.includes(code)) ?? EXIT.pass;
}

function entry(word, hex, glyph, gate, exit) {
  const rgb = [1, 3, 5]
    .map((start) => parseInt(hex.slice(start, start + 2), 16))
    .join(";");
  return Object.freeze({
    word,
    hex,
    glyph,
    ansi: `\x1b[38;2;${rgb}m`,
    gate,
    exit,
  });
}

// untiered is a metric the plan tracks without thresholds: shown, never
// judged, so the gate ignores it.
export const STATUS = Object.freeze({
  green: entry("green", "#7fd9a0", "●", "pass", EXIT.pass),
  amber: entry("amber", "#ffd166", "▲", "warn", EXIT.pass),
  red: entry("red", "#ef476f", "■", "fail", EXIT.fail),
  insufficient: entry(
    "insufficient",
    "#5e7a82",
    "○",
    "inconclusive",
    EXIT.inconclusive,
  ),
  untiered: entry("untiered", "#4fa3d9", "◇", "ignore", EXIT.pass),
});

// The page around the statuses, from the same colors.toml (mode "dark", so
// there is no light variant). None of these means a status. accent is the
// theme's accent and marks what waits for Andrew; epoch is its cyan and marks
// an instrument change.
export const PAGE = Object.freeze({
  background: "#0b1419",
  deep: "#081015",
  panel: "#13212a",
  rule: "#1e3440",
  muted: "#3a5563",
  text: "#cfe3e6",
  soft: "#a9c3c8",
  bright: "#eaf6f7",
  accent: "#ff9e3d",
  epoch: "#2ee6d6",
});

// Metrics that mean nothing until their epoch has passed its controls. The
// registry shape has no field for this, so the rule lives beside evaluate.
const EPOCH_BOUND = new Set(["lever_effect"]);

function occurrences(value) {
  return typeof value === "boolean" ? Number(value) : value;
}

function crosses(thresholds, value, limit) {
  return thresholds.worse === "higher" ? value > limit : value < limit;
}

// min_n rule for the registry: 1 for a sentinel or a single reading, 5 for a
// per-card or per-minute measure, 20 for rates and percentiles.
// A sentinel's value counts occurrences of the bad event; one occurrence
// decides even when n is below min_n.
export function evaluate(metric, { value, n }, { epochValid = false } = {}) {
  if (EPOCH_BOUND.has(metric.id) && !epochValid) return STATUS.insufficient;
  if (!metric.sentinel && metric.thresholds === null) return STATUS.untiered;
  const measured = metric.sentinel ? occurrences(value) : value;
  if (typeof measured !== "number" || !Number.isFinite(measured))
    return STATUS.insufficient;
  if (metric.sentinel && measured >= 1) return STATUS.red;
  if (!(n >= metric.min_n)) return STATUS.insufficient;
  const { thresholds } = metric;
  if (thresholds === null) return STATUS.green;
  if (crosses(thresholds, measured, thresholds.fail)) return STATUS.red;
  if (crosses(thresholds, measured, thresholds.warn)) return STATUS.amber;
  return STATUS.green;
}
