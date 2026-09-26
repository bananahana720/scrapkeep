# Jev player

An automated player for the light-lane sketches, built on
[TypeSafe's Jev](https://typesafe.ai/blog/introducing-system-one-models-and-jev).
It was meant to answer structural questions, such as whether a route is reachable
or a build survives tier 5. It does not replace Andrew's play, which is the review
in ORCHESTRATOR's light play lane.

**Status: parked as a player for this program** (TRACKING EV-0527, EV-0540,
EV-0541). Jev fails the free-cache dominance control under every question set and
method tried, so no instrument epoch has passed and the jev arm refuses to run a
batch (preflight exit 6). The `scripted` and `random` arms carry the mechanics
metrics. Jev keeps four advisory roles in the test loop, listed under
[Jev test-loop tools](#jev-test-loop-tools). The program's findings are in the
[Jev Lab retro](../../artifacts/jev-lab-2026-09-25/RETRO.md).

How to run the lab is in the [lab skill](../../.agents/skills/scrapkeep-lab/SKILL.md).
The method for any Jev decider (controls, blind corpora, pre-registration, caching,
cost fields) is in the [reactive-model-loop skill](../../.agents/skills/reactive-model-loop/SKILL.md).
This file gives what each tool has been measured to do, with the event that
measured it.

## How it decides

Code serialises the simulation state and asks Jev one question: which intent to
hold next.

- **Code computes the options; the model only chooses.** `PRECONDITION` in
  `decide.mjs` drops any action the engine cannot execute: a stomp with no air
  jump, a ram below the fast tier, a kicker below its approach speed, an exit
  charge outside the ring. If every option is dropped, the player gets
  `push_objective` alone.
- **Jev picks an intent; local code steers.** The last retained authored run had
  a median round trip of 294 ms, so the model chooses an intent that holds for a
  second or more and the 90 Hz simulation keeps flying it.
- **`CONFIDENCE_FLOOR` (0.05) is provisional and uncalibrated.** Below it the
  player holds `push_objective` instead of the model's choice. The value rests on
  one case, `kicker-has-speed` at confidence 0.02. JL-21 was re-scoped to scenario
  calibration after the park (EV-0542), so no live play calibrated it.
- **`danger` and `greedy` are recorded but drive no decision.** They are asked in
  the same request and stored with each result. Nothing reads them. In the last
  retained authored run `greedy` was above 0.5 on all 16 cases while caches were
  being taken, so it carries no usable signal yet.

## Question sets and controls

The question wording is part of the instrument, so it lives in versioned files.

- `questions/<version>.json` holds `{version, status, intent, danger, greedy, rationale}`.
- `questions/INDEX.json` pins each file's sha256. A published file never changes;
  new wording is a new file with a new pin. `npm test` fails if a pinned file's
  bytes change, and `loadQuestionSet()` refuses to load one.
- `instrumentIdentity()` returns `{questions_sha, model, confidence_floor, gate_version}`.
  Each distinct `questions_sha` starts a new epoch. Do not compare or aggregate
  results across epochs.

Two sets exist, and neither epoch is valid.

- `q1-original` is the wording in use before versioning, byte for byte, with
  status `retracted-leading`. Its intent instruction states a valuation ("Scrap
  has no use other than buying caches"). It failed free-cache and wording-swap
  under `controls/c1.json` (EV-0516, EV-0520). It is still `decide.mjs`'s
  `DEFAULT_QUESTION_SET`, so `jev:score` scores under it.
- `q2-neutral` (JL-18) states mechanics only. It failed free-cache under
  `controls/c2.json` (EV-0526). The lab harness defaults jev batches to q2 and c2
  (EV-0533).

`preflight.mjs` runs a controls file live, in both option orders, never from the
cache, before any jev batch, and exits 6 on a failure before Godot starts. Its CLI
is `node tools/jev-player/preflight.mjs [--questions <set>] [--controls <set>] [--out dir] [--epochs dir]`;
it makes live calls (12 under c2, EV-0526).

## Commands

```sh
npm run jev:score -- --dry-run   # validate the corpora and question set; no call
npm run jev:score                # score both corpora under q1-original; calls Jev
npm test                         # offline tests; no API key, no network
```

`jev:score` reads `TYPESAFE_API_KEY` from the environment or
`~/.config/typesafe/.env`. It has no flag for another question set, so it cannot
score q2 (carried at EV-0536). The q2 blind score below came from JL-18b's run.

## Scoring

- **Authored corpus** (`corpus.json`): 12 cases plus a 4-case adversarial block.
  The prompt's author wrote it, so it is reported and never gates.
- **Blind corpus** (`corpus-blind.json`, JL-04): 31 cases from a separate
  labeller (EV-0498), scored separately and never merged with the authored set.
  Only this score gates. `score.mjs` prints and writes blind aggregates only; no
  blind case id leaves it (EV-0533).
- Misses are weighted by cost: 5 for a miss that ends the run, 2 for lost tempo,
  1 for taste.
- Every case records `rawIntent` and `lowConfidence`. Each result is a `pass`, a
  `model-miss`, a `floor-miss` (the model's raw choice was acceptable and the floor
  replaced it) or a `floor-rescue` (the floor replaced an unacceptable choice with
  an acceptable one).
- Exit codes: 0 when the blind set passes (no severe miss, weighted score at least
  0.8); 1 when it fails; 3 when it is absent or has fewer than 20 cases.

## Measured results as a player

All on `jev-1.13.0`. The [retro](../../artifacts/jev-lab-2026-09-25/RETRO.md#jev-as-a-player-parked)
carries each result's full qualification.

| Run                                      | Result                                                                                                                                        | Event            |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| q1 with c1, 8 calls                      | free-cache fails in both orders (P(take) 0.45 and 0.48 against 0.6); lethal-option passes; wording-swap fails, with arms that differ in facts | EV-0516, EV-0520 |
| q2 with c2, 12 calls                     | free-cache fails (0.38 and 0.52); lethal-option passes (0.02); wording swaps pass only under the one-sided rule                               | EV-0526, EV-0529 |
| Blind corpus under q2, 31 calls          | 42 of 46 weighted (0.913), 0 severe misses; the epoch stays invalid because its controls failed                                               | EV-0533          |
| JL-18c redesign, 216 calls               | park: free-cache fails every order under Choice (mean 0.478) and on the 0.2 margin under per-option Nouls; lethal-option passes every order   | EV-0540, EV-0541 |
| Real-Godot jev batch                     | refused by preflight with exit 6 and no Godot process                                                                                         | EV-0542          |
| Replay of a jev batch against fake Godot | 0 calls, 4 cache hits, identical `trace_hash`                                                                                                 | EV-0521          |

## Jev Lab tools and their measured limits

Commands are from each script's usage text. None is a `verify` stage, and nothing
on the gate path calls Jev.

| Tool                         | Command                                                                                                                                 | Measured limits                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Headless batch on real Godot | `node scripts/lab/godot-launch.mjs <scenario> [--arm scripted\|random\|jev] [-n N] [--seed N] [--mode kinematic\|rigid] [--sketch dir]` | Kinematic trials reproduce exactly (360 of 360 repeat pairs, EV-0546). Rigid trials do not: ball-lab diverges in about 1 trial in 20 and can flip the outcome (EV-0546), Cable Bench kept 119 and 118 of 120 pairs (EV-0553). Only `run-to-pad`, `dummy-knock`, `pillar-weave` and `bench-climb` offer a choice in most snapshots (EV-0546); `downhill-run` is forced throughout (EV-0542). Rigid, `pillar-weave` and `bench-climb` time limits stay censored and provisional (EV-0563, EV-0566). `npm run play -- lab run <scenario>` drives the fake Godot and is for harness tests.                            |
| Gate and pins                | `npm run play -- gate <run_id> --against <pin>`; `node scripts/lab/gate.mjs --pin <run_id> --as <name>`                                 | Exits 0 pass, 1 differs or red, 2 usage, 3 inconclusive, 4 instrument invalid. Qualified on real ball-lab records: an injected −10% `drive_accel` exits 1, removing it exits 0, an invalid record and an instrument change exit 4, 10 rigid trials exit 3 (EV-0550). A kinematic exit 1 means behaviour differs from the pin, not worse (EV-0550). Rigid records are gated on n ≥ 20 per side and reachability only (EV-0551). A stale pin can pass after a state-rule change; after re-cutting, a fresh batch exits 0 against the new pin and 1 against the old (EV-0564, EV-0566).                              |
| Stats                        | `npm run play -- stats [--layer <layer>]`                                                                                               | Prints every registry metric, with epoch-aware trends (EV-0519). Layers: mechanics, agent, stability, pipeline, tdd, program, human. A metric below its `min_n` reads insufficient, never green.                                                                                                                                                                                                                                                                                                                                                                                                                  |
| Program collector            | `npm run play -- lab program`                                                                                                           | Reproduced EV-0492's commit times (EV-0497). In the JL-29 retro run its `first_pass_review` and `rework_per_card` read attempts only through JL-20, it read JL-28, JL-30 and JL-31 as admitted at the wrong events, and `untracked_commits` counted 27 commits that no event cites by SHA, all of them named by card ([retro](../../artifacts/jev-lab-2026-09-25/RETRO.md#program-layer-plan--4)). It does not measure `escaped_defects` or `overclaim`. Token means use the delegate ledger, which overcounted about 2× before a hooks fix (EV-0498).                                                            |
| Dashboard                    | `npm run play -- dash`, written to `artifacts/local/dash/index.html`                                                                    | Every registry id appears exactly once, and the page has no script and a `default-src 'none'` policy, both asserted by tests (EV-0545). Colours come from the `STATUS` and `PAGE` tables in `status.mjs`. At review the real page had no batch runs and no second epoch, so its arms table and epoch rules were checked on fixtures only (EV-0545).                                                                                                                                                                                                                                                               |
| Watch view                   | `npm run play -- lab watch <scenario> --arm scripted\|random\|jev`                                                                      | A demo, never evidence: the gate refuses its records and a watch pin (EV-0562). Keys: M marks the moment with a note, T shows the state text, S steps speed through 1×, ½× and ¼×, H shows help. With `--arm jev` it runs past a failed preflight under a "DEMO, not evidence" banner, and every live call counts against `--call-cap` (60 by default), which must cover the 12 preflight calls (EV-0562). The headless path reproduces its `events.ndjson` byte for byte (EV-0559). `--sketch` stage labs have no overlay (EV-0562). Andrew ran it (EV-0571); no human press of M, T or S is recorded (EV-0562). |

## Jev test-loop tools

Each is advisory. Nothing on the gate path imports it (a test follows imports
transitively, EV-0534). Input is redacted before it leaves the machine, answers
are cached, and a failure falls back to a named rule. Each ran on `jev-1.13.0`.
The `score <cases.json>... --out <dir> --max-calls <n>` mode of triage, coverage
gap and test ordering makes live calls up to its cap.

| Role                    | Command                                                                                                       | Measured result                                                                                                                                               | Limits and caveats                                                                                                                                                                                                                                                                              | Event                     |
| ----------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| Failure triage (JL-19)  | `node scripts/lab/triage.mjs --log <file> [--diff <file>] [--check <name>]`                                   | Blind 65 of 71 weighted (91.5%), authored 73 of 81 (90.1%), 0 severe misses; both `assert(false)` controls answered `real_regression` by Jev                  | The blind set was labelled by the prompt's author, so it is blind to Jev output only, and it is burned for future wording changes; the authored score is contaminated by a result-triggered rewording. It calls Jev whenever a key is found. `play.mjs` does not run it.                        | EV-0529, EV-0532, EV-0534 |
| Verdict tagging (JL-20) | `node scripts/lab/verdict-tags.mjs [--live] [--write]`                                                        | 14 of 14 hand labels reproduced with 4 calls; forward and reverse Nouls differ by at most 0.010                                                               | Easy cases and a vocabulary that echoes the quotes, so close to lexical matching. It fills an entry only when every tag reproduces a hand label, so it cannot tag a new entry alone. Without `--live` it reads the cache only.                                                                  | EV-0531, EV-0534          |
| Coverage gap (JL-24)    | `node scripts/lab/coverage-gap.mjs [--base <rev>] [--diff <file>]`                                            | Check set 68 of 77 weighted, 19 of 22, 1 severe miss, against a static import scan at 49 of 77 (4 severe) and a mention rule at 63 of 77 (2 severe); 35 calls | On the 19 real-commit cases Jev ties the free mention rule (53 of 62, 1 severe each), and one severe label is contestable. One writer wrote the prompt and both label sets. The 0.6 floor is provisional. With no argument it calls Jev on the working diff; it has no `--dry-run`.             | EV-0544                   |
| Test ordering (JL-23)   | inside `npm run play -- watch [name]`; `node scripts/lab/test-order.mjs order --dir <sketch> --check <id>...` | Mean rank of the first failing check 2.0 on a frozen 16-case set, against 6.4 for the current order and 2.5 for a static import scan                          | No reliable time benefit on real streaming runs: on the three pre-named mutations at `--jobs=1`, faster on 1 and slower on 2. It only reorders, never skips. When checks do not outnumber jobs the order changes nothing and `watch` makes no call; ball-lab has 4 checks against up to 8 jobs. | EV-0545, EV-0548, EV-0549 |

## Last retained authored run

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
  The re-test was planned under q2 (JL-18) and in live trials; after the park,
  JL-28 compares only the scripted and random arms (EV-0542), so the question is
  still open.
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
hardware or performance. The jev arm can drive a real Godot run through the lab
harness (JL-17), but no epoch has passed, so it has produced no evidence batch.
Automated play is not a feel verdict.
