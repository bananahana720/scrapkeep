// Verdict cache key and replay rule for the drone pad decision path.
import { createHash } from "node:crypto";

export const PROTOCOL_VERSION = "drone-ctl-1";
const sha256 = (s) => createHash("sha256").update(s).digest("hex");
export function canonical(v) {
  if (Array.isArray(v)) return `[${v.map(canonical).join(",")}]`;
  if (v && typeof v === "object") return `{${Object.keys(v).sort().map((k) => `${JSON.stringify(k)}:${canonical(v[k])}`).join(",")}}`;
  return JSON.stringify(v);
}

// The only place the key is built. `state` must already be redacted and encoded by the
// versioned state encoder; `options` are in offered order, because order changes the answer.
export function verdictKey({ questionSetSha256, resolvedModel, thresholds, gateVersion, stateEncoderVersion, state, options }) {
  if (typeof resolvedModel !== "string" || resolvedModel === "") throw new Error("resolvedModel required");
  return sha256(canonical({
    protocol_version: PROTOCOL_VERSION,
    question_set_sha256: questionSetSha256,
    resolved_model: resolvedModel,
    thresholds,
    gate_version: gateVersion,
    state_encoder_version: stateEncoderVersion,
    state,
    options: options.map(({ id, label, cost, gain, risk }) => ({ id, label, cost, gain, risk })),
  }));
}

export class VerdictCache {
  constructor() { this.entries = new Map(); }
  put(key, answer, resolvedModel) {
    if (!answer || answer.source !== "model" || !answer.probabilities) return false; // never cache a fallback
    this.entries.set(key, { answer, resolved_model: resolvedModel });
    return true;
  }
}

// Replay: zero decider calls. A miss, a missing or different resolved model, or a cache
// holding two models is an error, never a live call or a wildcard.
export function replay(cache, key, expectedModel) {
  const models = new Set([...cache.entries.values()].map((e) => e.resolved_model));
  if (models.size > 1) throw new Error(`replay void: cache holds ${models.size} resolved models`);
  if (!Object.prototype.hasOwnProperty.call(Object.fromEntries(cache.entries), key)) throw new Error(`replay miss: ${key}`);
  const e = cache.entries.get(key);
  if (typeof e.resolved_model !== "string" || e.resolved_model !== expectedModel) throw new Error(`replay model mismatch: ${e.resolved_model} != ${expectedModel}`);
  return { ...e.answer, source: "replay", original_source: e.answer.source };
}
