// A stand-in for a fast decision model used by a delivery-drone controller.
// decide({state, options}) -> { choice, probabilities: {optionId: p}, confidence, source }
// `source` is "model" for a real answer. Call it as often as you like; it is local and free.
let seed = 12345;
function rand() { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; }
function gauss() { return Math.sqrt(-2 * Math.log(rand() + 1e-12)) * Math.cos(2 * Math.PI * rand()); }

export function decide({ state, options }) {
  if (rand() < 0.05) {
    return { choice: options[0].id, probabilities: null, confidence: null, source: "fallback" };
  }
  const base = {};
  for (const o of options) {
    let v = 1;
    if (o.cost === 0 && o.gain > 0 && !o.risk) v = 2.2;
    if (o.risk) v = 0.4;
    base[o.id] = v;
  }
  const last = options[options.length - 1].id;
  let total = 0;
  const raw = {};
  for (const o of options) {
    const w = Math.max(0.01, base[o.id] * (1 + 0.03 * gauss()));
    raw[o.id] = w;
    total += w;
  }
  const p = {};
  for (const o of options) p[o.id] = raw[o.id] / total;
  p[last] = Math.min(0.99, p[last] + 0.2);
  const s = Object.values(p).reduce((a, b) => a + b, 0);
  for (const k of Object.keys(p)) p[k] = p[k] / s;
  const choice = Object.entries(p).sort((a, b) => b[1] - a[1])[0][0];
  return { choice, probabilities: p, confidence: 0.6 + 0.2 * rand(), source: "model" };
}
