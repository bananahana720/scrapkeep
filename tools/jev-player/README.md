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

The one standing disagreement is `kicker-has-speed`, and the interesting part is the
confidence: 0.01, a flat distribution, the model has no opinion. It is left failing
rather than relabelled. It is also why `CONFIDENCE_FLOOR` exists: below it the player
holds `push_objective` rather than committing to the top of a coin flip.

One label was corrected rather than defended. `adv-full-hp-clock-burning` originally
accepted only skipping the cache at tier 5. Once states began stating the real time
cost, that reasoning failed: a cache you are already rolling over costs a second, not
a tier, scrap buys nothing at the end of a run, and a miniboss is next. The corpus was
wrong. The change and its reason are recorded in the case's own note.

**The negative control, and why it matters more than the score.** The first sweep
returned 0/30: no state took the cache, at any tier, at any price. That read as a
finding about the cache economy. It was a finding about the prompt. The control —
offer a cache priced at zero scrap and see whether it gets taken — failed at 0.18
against 0.81. Two causes, both in this code:

- The instruction said scrubbing speed "costs you" and that time spent is "never
  free". That is a valuation, not a rule. The question contained its own answer.
- No state said what opening a cache actually costs in time, so the model priced
  an imagined detour. In the game you roll over it and press E: about a second.

With the instruction reduced to mechanics and the time cost stated, the control
passes (0.62 take on a free cache) and the sweep inverts. Run `sweep.mjs` and any
change to the questions has to clear the control first.

## What the sweep found

90 decisions across tier 1-5, three scrap-surplus levels and two threat levels.

| Condition | Cache taken |
| --- | --- |
| No threat nearby | **15/15 states, every tier, every price** |
| One chaser 26 m away | 4/15 states, and erratic (0/3, 1/3, 2/3 within a row) |

The stage prices caches at `25 * tier^1.25`, from 25 scrap to 187, on the theory
that the rising price is what makes "one more cache" a decision. In this sweep the
price does nothing. Tier 1 at 25 scrap and tier 5 at 187 both get taken every time
when nothing is chasing you. What flips the answer is whether a threat is present,
and those rows sit right on the boundary, which is where a real decision lives.

So the decision is real, but it is not the decision the stage was designed around.
It is a threat-proximity decision wearing a price tag. Worth testing against your
own play before changing anything: the instrument agrees with a labeled corpus, it
has not played the game.

## Limits

Corpus agreement means the decider picks defensible intents on these states. It is
not a win rate, not a claim about any sketch, and not evidence about feel, hardware
or performance. The decision layer does not yet drive a running game; the state
export and intent execution inside Godot are the next step.
