# Jev player

An automated player and design instrument for the light-lane sketches, built on
[TypeSafe's Jev](https://typesafe.ai/blog/introducing-system-one-models-and-jev),
a System One model that returns typed decisions instead of prose.

**This is not a substitute for Andrew's play.** ORCHESTRATOR's light play lane is
explicit: Andrew's play is the review, and no automated result replaces it. What
this does is answer the questions that are about *structure* rather than feel —
whether a decision is really a decision, whether a route is reachable, whether a
build survives tier 5 — and it answers them hundreds of times in the time one
human run takes.

## The shape

Jev never sees pixels. The simulation already knows the ball's speed, the tier,
what is in reach and what is about to hit you, so code serialises that into
structured state and asks one narrow question: what next?

Two rules keep it honest.

**Code computes the options; the model only chooses.** An action that the engine
cannot execute is never offered. `PRECONDITION` in `decide.mjs` drops a stomp with
no air jump, a ram below the fast tier, a kicker commit below its approach speed.
The corpus proved why this belongs in code: offered a stomp while airborne with the
air jump spent over a 22 m drop, the model took it. Physics is not a judgement call.

**Jev picks intent; local code steers.** A round trip measures about 280 ms, so
frame-level control is impossible and unwanted. The model chooses an intent that
holds for a second or more and the 90 Hz simulation keeps flying the last one while
the next decision is in flight.

## Commands

```sh
npm run jev:score      # score the decision layer against the labeled corpus
npm test               # includes the offline precondition tests, no API key needed
```

`TYPESAFE_API_KEY` in the environment, or `~/.config/typesafe/.env`.

## Corpus and scoring

`corpus.json` holds 12 labeled decision points plus a 4-case adversarial block
written so the greedy or obvious answer is wrong: a bargain cache sitting exactly
where a cableway lands, a stomp that drops the run, a full-health state where the
clock is the only thing killing you, a low-health state where retreating is worse
than fighting through.

Each case lists every intent a competent player could defend, and a severity: a
miss that ends the run is weighted 5, a miss that costs tempo 2, taste 1. A flat
accuracy number would hide the only failures that matter, and any severe miss fails
the gate regardless of the total.

Measured 25 September 2026 against `jev-1.13.0`:

| Metric | Result |
| --- | --- |
| Severity-weighted | 39/41 (95.1%) |
| Plain accuracy | 15/16 |
| Adversarial block | 4/4 |
| Severe misses | 0 |
| Latency | median 286 ms, max 324 ms |
| Input tokens | mean 706 per decision, three questions asked in one request |

The one standing disagreement is `cheap-cache-early`: at tier 1, holding 140 scrap,
with a 25-scrap cache in reach and no threats, Jev drives past it. It is left failing
rather than tuned away, because it may be the corpus that is wrong.

**A design signal worth its own look.** The `greedy` judgement came back above 0.5 on
every single case, 0.55 to 0.86 — the model reads looting as costing more than it
returns, everywhere, at every tier. If that holds up it is an answer to the question
Cable Bench was built to ask, and the answer is that the cache economy is priced too
high for the clock it runs against.

## Limits

Corpus agreement means the decider picks defensible intents on these states. It is
not a win rate, not a claim about any sketch, and not evidence about feel, hardware
or performance. The decision layer does not yet drive a running game; the state
export and intent execution inside Godot are the next step.
