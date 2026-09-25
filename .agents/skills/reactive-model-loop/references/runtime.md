# Runtime: cache, replay, redaction, fallbacks, caps and cost

This reference covers the code around the model call. Lesson ids point at [the lesson ledger](lessons.md). Numbers are examples from one lab unless marked otherwise, and none of them is a threshold to copy.

## Verdict cache

Key each cached verdict on a SHA-256 over canonical JSON (sorted keys, no whitespace) of these fields (RML-04, RML-05):

| Field | Why it is in the key |
| --- | --- |
| protocol version | a wire-format change changes what the model saw |
| question-set hash | any wording change is a new instrument |
| resolved model | an alias can move; see [instrument](instrument.md#identify-the-instrument) |
| confidence floor and thresholds | they change the final answer |
| gate version | gate rules change the option set |
| state | the input |
| options | the offered menu, in order |

Compute the key in one place. Other components pass the fields and never rebuild the key.

## Replay

Replay proves that a run can be reproduced from its cache (RML-28).

- Replay makes zero model calls. A cache miss during replay is an error, never a silent live call.
- A replay that finds two resolved models in one cache is void.
- A cache entry with no resolved model is a mismatch, not a wildcard. In one lab an entry with a null model left the replay anchor null, so any later verdict passed both checks.

## Redaction

Redact before clipping, before hashing, before building the cache key and before logging (RML-29). The ordering matters, because a clipped secret can escape a pattern that expects the whole secret.

Test redaction against adversarial formats, not only the usual secret shapes. In one lab a review found four gaps:

- a bearer-token pattern that matched only one letter case
- secrets inside JSON quotes that a prefix pattern missed
- a second home-directory path joined to the first with a colon
- a key read from a local environment file that entered by a different code path in one mode

## Fallbacks

Every failure path returns the same conservative default (RML-30): no key, HTTP error, timeout, malformed reply, an answer outside the menu. Pick the default whose error is cheapest. For a triage router that is usually "real regression", never "safe to rerun".

- Never cache a fallback.
- Label a fallback as not from the model wherever it appears: records, logs, dashboards. One public project labels fallback answers on screen and marks an offline mode as a simulated policy, not the model. That observation is unaudited.
- A control must assert its answers came from the live decider. See [controls](controls.md#make-controls-executable).

## Call caps

- Count against the cap before sending the request, and refuse without sending once the cap is reached (RML-31). In one lab 26 refusals short-circuited with no request sent.
- Count failed calls. A counter that increments only on a logged success undercounts. In one lab a cross-run cap missed failed calls because they threw before the line that incremented the counter.

## Epoch records

A rerun of the controls replaces the earlier record for that epoch, with one exception (RML-32). A run in which every call failed writes an error record beside the existing record and never replaces it. A run with some failures still replaces it. In one lab a review found that a transient outage would otherwise erase a passed epoch.

## Validators on untrusted input

- Look up untrusted keys as own properties of a plain map, and reject anything that is not a string (RML-33). In one lab a JavaScript validator accepted an event kind of `constructor` and an array-wrapped option name through prototype lookup and coercion, and it threw on `toString` instead of returning an error. Across 27 new test inputs it wrongly accepted 5 and threw on 4.
- Build a second validator from the written spec alone, without reading the first implementation, and run both against one shared set of fixtures (RML-34). In one lab an independent port found three defects in the reference validator and three gaps in the spec.

## Commands that can spend money

A command that can make paid calls returns from `--help` and `--dry-run` before any request, and it refuses unknown arguments (RML-35). In one program a probe with `--help` ran a scoring command that had no argument handling, and it made 16 unplanned live calls.

## Cost and latency

Usage accounting has three rules:

- Record each usage field under its own name: input tokens, output tokens, cache-read tokens, cache-write tokens. Never sum them into one total, because each is priced differently (RML-37).
- A field the provider did not report is `null`, never 0 (RML-36). In one lab the provider's usage carried only input and output tokens. One recorder printed 0 for the absent cache fields, and a later regression did it again.
- Dedupe by request id before summing usage from transcripts or logs (RML-38). One request can appear in several records. In one ledger 49 records held 22 distinct request ids, which inflated output tokens about 2.05 times and cache reads about 2.2 times.

Every latency figure cites the retained run it came from (RML-39). In one lab three sources gave 223 ms, about 280 ms and 286 ms, and the retained run's median was 294 ms. Regenerate every copied figure when the prompt changes.

Cap spend with a budget that persists across restarts (RML-40). One public project keeps a cumulative dollar cap with a per-request reserve in a file that survives restarts. That is the strongest cost control seen in public projects, read from its README and unaudited. Most others rely on call-rate caps or a request timeout alone.
