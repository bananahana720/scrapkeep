export const Z95 = 1.959963984540054;

function proportion(successes, n) {
  if (!Number.isInteger(n) || n < 1)
    throw new RangeError(`n must be a positive integer, got ${n}`);
  if (!Number.isInteger(successes) || successes < 0 || successes > n) {
    throw new RangeError(
      `successes must be an integer in 0..${n}, got ${successes}`,
    );
  }
  return successes / n;
}

export function wilson(successes, n, z = Z95) {
  const p = proportion(successes, n);
  const z2 = z * z;
  const denominator = 1 + z2 / n;
  const centre = (p + z2 / (2 * n)) / denominator;
  const half =
    (z * Math.sqrt((p * (1 - p)) / n + z2 / (4 * n * n))) / denominator;
  return {
    estimate: p,
    lower: Math.max(0, centre - half),
    upper: Math.min(1, centre + half),
  };
}

// Newcombe's hybrid score interval (method 10) for p1 - p2.
export function newcombe(x1, n1, x2, n2, z = Z95) {
  const a = wilson(x1, n1, z);
  const b = wilson(x2, n2, z);
  const estimate = a.estimate - b.estimate;
  return {
    estimate,
    lower: estimate - Math.hypot(a.estimate - a.lower, b.upper - b.estimate),
    upper: estimate + Math.hypot(a.upper - a.estimate, b.estimate - b.lower),
  };
}

// Nearest rank, with the same sample filter as _distribution in
// tools/agent-player/report.py: finite, non-negative numbers only.
export function distribution(values) {
  const sorted = values
    .filter(
      (value) =>
        typeof value === "number" && Number.isFinite(value) && value >= 0,
    )
    .toSorted((a, b) => a - b);
  const n = sorted.length;
  if (n === 0) return { n, p50: null, p95: null, max: null };
  const rank = (fraction) => sorted[Math.max(0, Math.ceil(n * fraction) - 1)];
  return { n, p50: rank(0.5), p95: rank(0.95), max: sorted[n - 1] };
}
