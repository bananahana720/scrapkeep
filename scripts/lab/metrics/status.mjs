// The only file under scripts/lab/ that may name a status or a colour.
// Hex values are the green, yellow, red and dark_foreground keys of
// ~/.config/omarchy/themes/neon-noir/colors.toml. Exit codes follow the gate
// table in plan § 4.

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

export const STATUS = Object.freeze({
  green: entry("green", "#7fd9a0", "●", "pass", 0),
  amber: entry("amber", "#ffd166", "▲", "warn", 0),
  red: entry("red", "#ef476f", "■", "fail", 1),
  insufficient: entry("insufficient", "#5e7a82", "○", "inconclusive", 3),
});

function occurrences(value) {
  return typeof value === "boolean" ? Number(value) : value;
}

function crosses(thresholds, value, limit) {
  return thresholds.worse === "higher" ? value > limit : value < limit;
}

// A sentinel's value counts occurrences of the bad event; one occurrence
// decides even when n is below min_n.
export function evaluate(metric, { value, n }) {
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
