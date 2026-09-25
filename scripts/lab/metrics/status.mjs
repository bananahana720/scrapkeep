// The only file under scripts/lab/ that may name a status or a colour.
// Hex values are the green, yellow, red, dark_foreground and blue keys of
// ~/.config/omarchy/themes/neon-noir/colors.toml, except INTENT's, which are
// picked in the hues the theme leaves free (see INTENT). Exit codes follow the
// gate table in plan § 4.

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

// ink is the colour for text in the status: the hex itself, except where the
// hex falls under 4.5:1 on the page's panels and a lighter shade of the same
// hue carries the words instead.
function entry(word, hex, glyph, gate, exit, ink = hex) {
  const rgb = [1, 3, 5]
    .map((start) => parseInt(hex.slice(start, start + 2), 16))
    .join(";");
  return Object.freeze({
    word,
    hex,
    ink,
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
    "#7e9aa2",
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

// What each intent looks like wherever a decision is drawn: the watch overlay
// in Godot, the replay page and the terminal. Colour carries one meaning, so
// no intent may sit near a STATUS, PAGE or SOURCE colour: the theme's blue,
// cyan, green, yellow, orange and red all mean something already. The hues
// are the ones those leave free, lime and the indigo-to-magenta arc, picked in
// OKLCH so each is at least 0.12 from every reserved colour and 0.10 from
// every other intent in OKLab (tests/lab-watch.test.js checks both). The two
// attacks on a dummy share magenta at two lightnesses. `shape` is the second
// channel: a closed polygon in a unit box, y down, drawn at any size.
function intent(word, hex, glyph, shape) {
  return Object.freeze({ word, hex, glyph, shape: Object.freeze(shape) });
}

export const INTENT = Object.freeze({
  push_objective: intent("push", "#7a7af5", "→", [
    [-1, -0.35],
    [0.15, -0.35],
    [0.15, -0.85],
    [1, 0],
    [0.15, 0.85],
    [0.15, 0.35],
    [-1, 0.35],
  ]),
  hit_kicker: intent("kicker", "#bae500", "◢", [
    [-1, 0.75],
    [1, 0.75],
    [1, -0.95],
  ]),
  stomp_target: intent("stomp", "#fb96df", "▼", [
    [-0.95, -0.75],
    [0.95, -0.75],
    [0, 0.95],
  ]),
  ram_target: intent("ram", "#c827a8", "◆", [
    [0, -1],
    [1, 0],
    [0, 1],
    [-1, 0],
  ]),
  evade_hazard: intent("evade", "#b6a3ff", "ϟ", [
    [-0.25, -1],
    [0.65, -1],
    [0.15, -0.15],
    [0.75, -0.15],
    [-0.45, 1],
    [-0.05, 0.1],
    [-0.65, 0.1],
  ]),
  sweep_scrap: intent("sweep", "#78b23d", "◠", [
    [-1, 0.4],
    [-0.6, -0.5],
    [0, -0.8],
    [0.6, -0.5],
    [1, 0.4],
    [0.5, 0.4],
    [0, -0.2],
    [-0.5, 0.4],
  ]),
  take_cache: intent("cache", "#ffb3b8", "■", [
    [-0.8, -0.8],
    [0.8, -0.8],
    [0.8, 0.8],
    [-0.8, 0.8],
  ]),
  retreat_regen: intent("retreat", "#235bc8", "←", [
    [1, -0.35],
    [-0.15, -0.35],
    [-0.15, -0.85],
    [-1, 0],
    [-0.15, 0.85],
    [-0.15, 0.35],
    [1, 0.35],
  ]),
  start_exit: intent("exit", "#53760e", "◎", [
    [0, -1],
    [0.7, -0.7],
    [1, 0],
    [0.7, 0.7],
    [0, 1],
    [-0.7, 0.7],
    [-1, 0],
    [-0.7, -0.7],
  ]),
});

// How a decision was made, so a chip never presents a rule, a draw, a cache
// hit or a fallback as a Jev choice. Only `live` is Jev answering now.
export const SOURCE = Object.freeze({
  live: Object.freeze({ word: "JEV", hex: PAGE.bright }),
  cache: Object.freeze({ word: "CACHED", hex: PAGE.soft }),
  forced: Object.freeze({ word: "FORCED", hex: STATUS.insufficient.ink }),
  fallback: Object.freeze({ word: "FALLBACK", hex: STATUS.amber.hex }),
  rule: Object.freeze({ word: "RULE", hex: PAGE.soft }),
  seeded: Object.freeze({ word: "SEEDED", hex: PAGE.soft }),
  failed: Object.freeze({ word: "FAILED", hex: STATUS.red.hex }),
});

// Watch mode's own labels. A watch record is never evidence; a Jev watch run
// is a demo because its epoch need not have passed its controls.
export const WATCH = Object.freeze({
  demo: Object.freeze({
    record: "demo, not evidence",
    banner: "DEMO — not evidence",
    hex: STATUS.amber.hex,
    glyph: STATUS.amber.glyph,
  }),
  watch: Object.freeze({
    record: "watch, not evidence",
    banner: "WATCH — not evidence",
    hex: PAGE.soft,
    glyph: STATUS.untiered.glyph,
  }),
  mark: Object.freeze({ word: "MARK", hex: PAGE.accent }),
  // The overlay's preflight line and end card; the replay page's anomalies.
  verdict: Object.freeze({
    pass: STATUS.green,
    warn: STATUS.amber,
    fail: STATUS.red,
  }),
  anomaly: Object.freeze({ hex: STATUS.red.hex }),
  knock: Object.freeze({ hex: PAGE.soft }),
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
