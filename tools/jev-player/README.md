# Jev player

An automated player for the light-lane sketches, built on
[TypeSafe's Jev](https://typesafe.ai/blog/introducing-system-one-models-and-jev).
It is meant to answer structural questions, such as whether a route is reachable
or a build survives tier 5. It does not replace Andrew's play, which is the review
in ORCHESTRATOR's light play lane.

## How it decides

Code serialises the simulation state and asks Jev one question: which intent to
hold next.

- **Code computes the options; the model only chooses.** `PRECONDITION` in
  `decide.mjs` drops any action the engine cannot execute: a stomp with no air
  jump, a ram below the fast tier, a kicker below its approach speed, an exit
  charge outside the ring. If every option is dropped, the player gets
  `push_objective` alone.
- **Jev picks an intent; local code steers.** The last retained run had a median
  round trip of 294 ms, so the model chooses an intent that holds for a second or
  more and the 90 Hz simulation keeps flying it.
- **`CONFIDENCE_FLOOR` (0.05) is provisional.** Below it the player holds
  `push_objective` instead of the model's choice. The value rests on one case,
  `kicker-has-speed` at confidence 0.02. JL-21 calibrates it from live play.
- **`danger` and `greedy` are recorded but drive no decision.** They are asked in
  the same request and stored with each result. Nothing reads them. In the last
  retained run `greedy` was above 0.5 on all 16 cases while caches were being
  taken, so it carries no usable signal yet.

## Question sets

The question wording is part of the instrument, so it lives in versioned files.

- `questions/<version>.json` holds `{version, status, intent, danger, greedy, rationale}`.
- `questions/INDEX.json` pins each file's sha256. A published file never changes;
  new wording is a new file with a new pin. `npm test` fails if a pinned file's
  bytes change, and `loadQuestionSet()` refuses to load one.
- `instrumentIdentity()` returns `{questions_sha, model, confidence_floor, gate_version}`.
  Each distinct `questions_sha` starts a new epoch. Do not compare or aggregate
  results across epochs.

`q1-original` is the only set. It is the wording in use before versioning, byte
for byte, with status `retracted-leading`. Its intent instruction states a
valuation ("Scrap has no use other than buying caches"), which makes any
affordable cache look dominant. It is kept only so old results stay comparable.
A neutral set is JL-18.

## Commands

```sh
npm run jev:score   # score against the corpora; calls Jev
npm test            # offline tests; no API key, no network
```

`jev:score` reads `TYPESAFE_API_KEY` from the environment or
`~/.config/typesafe/.env`.

## Scoring

- **Authored corpus** (`corpus.json`): 12 cases plus a 4-case adversarial block.
  The prompt's author wrote it, so it is reported and never gates.
- **Blind corpus** (`corpus-blind.json`, JL-04): scored separately and never
  merged with the authored set. Only this score gates.
- Misses are weighted by cost: 5 for a miss that ends the run, 2 for lost tempo,
  1 for taste.
- Every case records `rawIntent` and `lowConfidence`. Each result is a `pass`, a
  `model-miss`, a `floor-miss` (the model's raw choice was acceptable and the floor
  replaced it) or a `floor-rescue` (the floor replaced an unacceptable choice with
  an acceptable one).
- Exit codes: 0 when the blind set passes (no severe miss, weighted score at least
  0.8); 1 when it fails; 3 when it is absent or has fewer than 20 cases. Until
  JL-04 lands, `jev:score` exits 3.

## Last retained run

From `artifacts/local/jev-player/corpus-score.json` in the main checkout,
2026-09-25 13:57Z, under `q1-original`. The artifact does not record the model
version.

| Metric            | Labels as committed | Original labels |
| ----------------- | ------------------- | --------------- |
| Severity-weighted | 39/41               | 37/41           |
| Plain accuracy    | 15/16               | 14/16           |
| Adversarial block | 4/4                 | 3/4             |
| Severe misses     | 0                   | 0               |

Median latency 294 ms, max 309 ms, mean 749 input tokens per decision.

This is not instrument evidence:

- The corpus is authored, and the question set is retracted.
- `adv-full-hp-clock-burning` gained `take_cache` as an accepted answer after its
  author saw the model choose it. The original-labels column scores it without
  that answer. The case is burned for any blind set.
- The one failure, `kicker-has-speed`, fell below the floor. The run did not record
  the raw choice, so whether the model or the floor missed is unknown.
- Four cache options have been reworded since the run (see below), so a rerun
  does not repeat these inputs.

## Retracted

These claims from earlier versions of this README are withdrawn (JL-00 audit,
TRACKING EV-0485):

- The cache sweep's conclusion that cache price has no effect and threat proximity
  decides, with its numbers (4/15 under threat; 0/3, 1/3, 2/3). The
  retained sweep artifact gives 6/15 under threat by `sweep.mjs`'s own rule, and
  under threat tier 1 was taken more often than tiers 2 to 5. `sweep.mjs` moves
  tier, price, elapsed time and scrap held together, so it cannot isolate price.
  The question is re-tested under a neutral set (JL-18) and in live trials (JL-28).
- The negative-control figures (0.18 against 0.81, then 0.62) and the "0/30 first
  sweep". No control code or artifact exists. The same claim in `corpus.json`'s
  top-level note is covered by this retraction.
- "Tuned against the corpus" for `CONFIDENCE_FLOOR`.
- The earlier metrics table (286 ms, 324 ms, 706 tokens), replaced above by the
  retained run.

## Corpus wording change

The eight cache options each began "You are already rolling over it; opening
costs about one second of stopping." Four of them also place the cache elsewhere
(14 m away, 8 m away, 5 m ahead, on a ledge above). Those four no longer carry
the prefix. No label changed.

## Limits

Corpus agreement means the decider picks defensible intents on these states. It
is not a win rate, not a claim about any sketch, and not evidence about feel,
hardware or performance. The decision layer does not drive a running game yet.
