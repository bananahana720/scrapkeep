# JL-18c pre-registration: one redesign of Jev-as-player

**Card:** JL-18c revision 1 · **Attempt:** JL-18c-A1 · **Lease:** JL-18c-L1 · **Phase:** A (fixed before any call)

**Status.** No call has been made. This file, the three input files and the runner are fixed at the commit that adds them. The runner's `--live` mode refuses to start unless the sha256 of every input listed under [Pinned inputs](#pinned-inputs) appears in this file, and `tools/jev-player/tests/jl18c.test.js` fails on any mismatch. Phase B starts only after the Fable review of this file, runs once, and changes nothing here.

## Why

Andrew's decision at EV-0527 allows one redesign, fixed before any call. If it fails, Jev-as-player is parked for this program.

Jev failed the free-cache dominance control under q1/c1 (EV-0516, P(take_cache) 0.45 and 0.48) and under q2/c2 (EV-0526, 0.38 and 0.52), while refusing the lethal ram (0.02 and 0.02). The JL-18 review § 6 weighs three explanations and proposes this design:

- **Framing.** Residual option framing, most likely in what c1 and c2 share: `objective: reach_exit` in the state, a push option that names the goal, and a second loot-like sibling.
- **Position.** The option listed last gains mass when contested. Six of six JL-18 pairs moved the same way by 0.09 to 0.35 against 0.03 to 0.06 same-position noise.
- **Preference.** A prior of roughly 0.5 toward the objective-directed option that a free permanent buff does not overturn. Averaging the two orders gives about 0.45 under q2.

Two later results are context, not inputs to any rule:

- JL-20 measured batched per-tag Nouls (7 per request, forward and exact reverse order, 4 calls, `jev-1.13.0`). The forward-to-reverse gap was at most 0.010, and 0.000 on 12 of 14 tags. That supports per-option Nouls (design e) as a way around position bias. It was a different domain (text tagging) on easy cases (Nouls at 0.02 to 0.10 or 0.97 to 0.99), so it does not predict design e on game states.
- JL-18b scored the blind corpus live under q2 with the single-Choice `decide()`: 27/31 plain, 0.913 severity-weighted, 0 severe misses, and 5/5 on its dominance block. Under the same instrument Jev passes every blind dominance case yet fails c2 free-cache. I have seen only these aggregates. The cells below test the features of free-cache I can name that a dominance case need not share: an alternative that names the stage-clearing objective (c-no-objective), a loot sibling (the two-option cells), an unvalued random reward (d-named-buff), the cache itself (d-free-heal), and the danger and greedy questions sent beside the Choice (f-free-cache). Which of these the blind cases actually lack is unknown to me.

## Instrument

- **Question set.** `q2-neutral`, pinned in `tools/jev-player/questions/INDEX.json` at sha256 `fccb508a9c1636b0415810a714a5846a9ccb3ca18046c02ecbbe6f96d8895092`. `loadQuestionSet` refuses any other bytes.
- **Model.** The body carries `jev-latest`, as `decide.mjs` sends it. Each call's resolved model is recorded. A run that resolves more than one model is blocked.
- **Endpoint.** `https://api.typesafe.ai/v1/systemone`, the URL `decide.mjs` uses. The runner restates it because `decide.mjs` does not export it and this card may not edit that file.
- **Request shape.** Choice bodies are built by `decide.mjs`'s own `offeredOptions` and `buildQuestions`, as `{model, state, questions}`. A test sends every Choice call in the plan through `decide()` against a replaced `fetch` and asserts the serialised bodies are byte-identical. Noul calls use the same `{model, state, questions}` shape with `{type: "noul", instructions}` entries, the form of q2's `greedy` question.
- **No cache, no retry.** Every call reaches the endpoint. A call that throws or returns non-2xx is recorded with its error and never retried.

## States

Five states in `tools/jev-player/experiments/jl18c/states.json`. Two are c2's, copied verbatim (a test asserts deep equality with `controls/c2.json`). Three are new. Options within each new state are length-matched within 1.25x (a test asserts it). The longest ratio is 1.17 (free-cache-no-objective, 121 to 103 characters). No option in any state is removed by the option gate (a test asserts it).

| State | Source | What differs from free-cache | Probe |
|---|---|---|---|
| `free-cache` | c2 free-cache, verbatim | nothing | `take_cache` |
| `lethal-option` | c2 lethal-option, verbatim | 8 HP, fast tier, chaser 7 m on the line | `ram_target` |
| `free-cache-no-objective` | new | `objective` removed from the state; `push_objective` replaced by `roll_on`: "Roll on along the current line at cruise speed, past the cache, with no stop. The cache stays unopened." | `take_cache` |
| `free-cache-named-buff` | new | the take text names the buff: "... and its buff, +20 max health, stacks for the rest of the run." (+20 max HP is one of the buffs c1 lists) | `take_cache` |
| `free-heal` | new | 8 HP, no threats; a repair pad replaces the cache: "You are rolling over a repair pad now. It restores your health from 8 to the full 100 for 0 scrap and no stop."; push ends "The pad stays unused." | `take_repair` |

`free-cache-no-objective` removes the objective from every place the experiment controls (state, option id, option text). The pinned q2 rules still say "The stage is cleared by holding a 60 second exit charge at the exit", so the exit is not absent from the prompt. A test asserts that no body in the no-objective cells contains the word "objective" and that neither the state nor `roll_on` mentions exit, charge or objective.

The repair pad is hypothetical. Neither q2 nor the sketches' stated mechanics include one. It asks only whether Jev takes a free dominant option away from caches. The cable-bench and spillway sketch READMEs cited by the JL-18 review are not in this worktree, so every mechanic here rests on q2's rules text and c2.

## Designs

Six designs from the JL-18 review § 6, sixteen cells. "Order" means the order in which options (or Noul keys) appear in the request. Three-option cells run all six permutations; two-option cells run both orders; every order runs three times.

### a. Threshold controls in every permutation

| Cell | Call | State | Calls | Pass rule |
|---|---|---|---|---|
| `a-free-cache` | Choice (q2 intent, danger, greedy) | free-cache | 6 × 3 = 18 | in every order, mean P(take_cache) over its 3 repeats ≥ 0.6 |
| `a-lethal` | Choice | lethal-option | 18 | in every order, mean P(ram_target) ≤ 0.2 |

Reported beside the verdict, per cell: P(probe) by position (positions 1 to 3, n = 6 each) with mean, min, max and sample SD; the cell's overall mean and min; the per-order means; the pooled within-order SD.

### b. Comprehension Nouls, no Choice

One call per state holds one Noul per item, and no intent question. The Noul text is the option text and one yes/no question, with no rules preamble, so a stated item tests reading of that text alone:

> One action is available right now, with what it involves: "{why}" {question}

| Cell | State | Items (stated + implied) | Calls |
|---|---|---|---|
| `b-free-cache` | free-cache | 6 + 3 | 2 orders × 3 = 6 |
| `b-no-objective` | free-cache-no-objective | 7 + 2 | 6 |
| `b-free-heal` | free-heal | 5 + 3 | 6 |
| `b-lethal` | lethal-option | 3 + 4 | 6 |

The items and expected answers are in `questions.json`. For `take_cache` in free-cache they are spends scrap (no, stated), involves stopping or a detour (no, stated), grants a run-long buff (yes, stated) and gives up heading toward the exit (no, implied). Orders are the item list forward and reversed.

**Rule.** An item is correct when every reading is on the expected side of 0.5 (above for yes, below for no). A state is **read** when every stated item is correct. Implied items are reported but do not decide whether a state was read. `take_cache__forgoes_exit` is the item that tests the specific misreading "taking the cache abandons the exit".

### c. Framing and the loot sibling

| Cell | Call | State and options | Calls | Pass rule |
|---|---|---|---|---|
| `c-no-objective` | Choice | free-cache-no-objective, three options | 18 | as a-free-cache |
| `c-no-objective-two` | Choice | free-cache-no-objective, take_cache and roll_on | 2 × 3 = 6 | as a-free-cache |
| `c-free-cache-two` | Choice | free-cache, take_cache and push_objective | 6 | as a-free-cache |

The two-option cell on the original state is an addition to the review's list. Together with the others it makes a 2 × 2 of objective named or not against loot sibling present or not.

### d. Dominance outside the random cache

| Cell | Call | State | Calls | Pass rule |
|---|---|---|---|---|
| `d-free-heal` | Choice | free-heal | 18 | in every order, mean P(take_repair) ≥ 0.6 (diagnostic, not a verdict cell) |
| `d-named-buff` | Choice | free-cache-named-buff | 18 | as a-free-cache |

`d-named-buff` was added after the JL-18b contrast, before any call. It changes one thing from free-cache, the random reward.

### e. Per-option preference Nouls

One call per state holds one Noul per option, keyed by option id, and no Choice. Each Noul carries q2's rules sentences, verbatim, as a preamble (a test asserts the preamble is a prefix of the pinned q2 intent text), then the option and a neutral question:

> {q2 rules} One action is available right now, with what it involves: "{why}" Is this the action to take now?

| Cell | State | Calls | Pass rule, in every order (per-order mean over 3 repeats) |
|---|---|---|---|
| `e-free-cache` | free-cache | 6 × 3 = 18 | Noul(take_cache) ≥ 0.6 and Noul(take_cache) − max(other Nouls) ≥ 0.2 |
| `e-free-heal` | free-heal | 18 | Noul(take_repair) ≥ 0.6 and exceeds every other option's by ≥ 0.2 (diagnostic, not a verdict cell) |
| `e-lethal` | lethal-option | 18 | Noul(ram_target) ≤ 0.2 and max(other Nouls) − Noul(ram_target) ≥ 0.2 |
| `e-no-objective` | free-cache-no-objective | 18 | as e-free-cache |

Order is the key order of the Nouls in the request. Each option's Noul averaged over all orders is reported beside the per-order verdict, with the probe's Noul by position.

**The margin.** 0.2 is three times the largest same-position repeat noise JL-18 observed in a Choice probability (0.06), rounded up. For the lethal cell the margin applies to the best alternative, so a design passes when at least one safe action is clearly preferred to the ram. It need not prefer both.

### f. Intent only

| Cell | Call | State | Calls | Pass rule |
|---|---|---|---|---|
| `f-free-cache` | Choice with only the intent question (no danger, no greedy) | free-cache | 18 | as a-free-cache |

Each body is the matching a-free-cache body with `danger` and `greedy` removed (a test asserts the intent question and state are identical).

## Lines and definitions

- **0.6** (min probability) and **0.2** (max probability) are c2's lines, unchanged.
- **Every order.** A threshold or preference cell passes only when every order passes. An order passes on the mean of its three repeats. An order with no usable reading fails. The minimum single-call reading is reported beside it.
- **Noise line.** Where a result is compared against noise, the line is max(0.1, 3 × pooled within-order SD). The pooled SD is the square root of the mean sample variance of the repeats within each order, taken over the cells involved. This follows the JL-18 review § 4 recommendation to derive lines from noise measured in the same run. The 0.1 floor keeps a noiseless stub or a deterministic endpoint from flagging a 0.01 difference.
- **Position effect.** Flagged for a cell when the range of its per-position probe means exceeds the cell's noise line.
- **Comparisons.** Each is a lift, treatment mean minus baseline mean over all readings, and is indicated when |lift| exceeds the noise line pooled over both cells.

| Comparison | Baseline | Treatment | Reads |
|---|---|---|---|
| framing | a-free-cache | c-no-objective | P(take_cache) |
| sibling-with-objective | a-free-cache | c-free-cache-two | share P(take) / (P(take) + P(push_objective)) |
| sibling-without-objective | c-no-objective | c-no-objective-two | share P(take) / (P(take) + P(roll_on)) |
| random-buff | a-free-cache | d-named-buff | P(take_cache) |
| priming | a-free-cache | f-free-cache | P(take_cache) |

The share removes the sweep sibling's mass from the three-option cell, so a two-option P(take) can be compared with it on one scale.

## What each outcome means

| Outcome | Reading |
|---|---|
| A stated item in `b-free-cache` is wrong | **Reading.** Jev does not read the free option's text correctly. The Choice failure is then not evidence about preference. |
| `b-free-cache` read, `take_cache__forgoes_exit` answered yes | **Inference.** Jev reads the text but infers that taking the cache abandons the exit. This is a framing failure through inference, reported as a lead. |
| Position effect in `a-free-cache` | **Position.** Measured, not averaged away. The every-order rule already fails a design that depends on it. |
| framing indicated with positive lift | **Framing.** Naming the objective (state, id, text) accounts for part of the discount. If `c-no-objective` also passes in every order, framing is sufficient to explain the failure. |
| A sibling comparison indicated with positive lift | **Sibling.** The loot sibling splits mass away from the dominant option. |
| random-buff indicated with positive lift | **Random reward.** Jev discounts an unvalued random buff. Naming the buff helps. |
| priming indicated | **Priming.** Sending danger and greedy beside the Choice moves it. |
| `b-free-cache` read, and `a-free-cache` and `c-no-objective` both have overall mean < 0.6 | **Preference.** Jev reads the free option correctly, removing objective framing does not rescue it, and averaging over every position leaves it below 0.6. This is the residual prior. |
| `d-free-heal` passes | **Scope.** The discount is specific to caches or their buffs. |
| `d-free-heal` fails | **Scope.** Jev does not reliably take a free dominant option in this domain. |
| `e-*` passes where the matching Choice cell fails | **Asking method.** Per-option Nouls avoid what the single Choice suffers from (position or relative framing). |

These are the pre-stated readings. The Phase B report states which rows fired and cites the numbers. It does not add rows.

## Overall verdict rule

- **BLOCKED** (no verdict) when 10 or more calls fail, or when the successful calls resolve more than one model. The retained answers are reported. Any rerun is a new decision with its own budget.
- **Candidate** when at least one asking method clears free-cache and lethal-option in every order:
  - **Choice:** `a-free-cache` and `a-lethal`.
  - **Preference Nouls:** `e-free-cache` and `e-lethal`.

  A candidate becomes the subject of a follow-up card. Adopting it into the arm is not part of JL-18c.
- **Park** otherwise, per EV-0527.

**Free-heal cells are diagnostics.** `d-free-heal` and `e-free-heal` stay in the plan and in the call budget. They locate whether the discount is specific to caches (the scope rows above) and do not decide the verdict.

**Leads.** Diagnostic cells (`c-no-objective`, `c-no-objective-two`, `c-free-cache-two`, `d-named-buff`, `e-no-objective`, `f-free-cache`) that pass are listed as leads for any future reopening. A passing lead does not change a park. The verdict cells are the game's real controls, so a candidate must take the free cache and refuse the lethal ram under one asking method.

**Change record.** Before any call, the free-heal cells were removed from both methods' verdict cells. The Fable review of this pre-registration (N1) questioned letting a hypothetical repair pad decide the verdict, and the coordinator decided, on Andrew's deferral, that the verdict rests on the game's real controls only. Every cell, text, line and the 216-call budget are otherwise unchanged. Per review § 5, the runner also now records provenance before the first call and after the last, which does not change the plan.

## Budget and cap

| Design | Cells | Calls |
|---|---|---|
| a | a-free-cache, a-lethal | 36 |
| b | four comprehension cells | 24 |
| c | c-no-objective, c-no-objective-two, c-free-cache-two | 30 |
| d | d-free-heal, d-named-buff | 36 |
| e | four preference cells | 72 |
| f | f-free-cache | 18 |
| **Total** | 16 cells | **216** |

The cap is 216 calls, made once. `runPlan` refuses a plan whose length is not the budget. Calls run sequentially with a 30 s timeout each. Repeats form the outer loop, then cells in the order above, then orders, so each cell is spread across the run rather than bunched at one moment. JL-18's Choice calls used about 800 input and 80 output tokens each. The Noul calls are longer, so the run is estimated at 150k to 250k input tokens (ASSERTED, unmeasured).

## Phase B procedure

1. The coordinator confirms that this commit is the reviewed one and the worktree is clean.
2. Run once: `node tools/jev-player/experiments/jl18c/run.mjs --live`. Before the first call and again after the last it writes `jl18c-<start>.provenance-before.json` and `jl18c-<start>.provenance-after.json` to the output folder, each holding `git rev-parse HEAD`, `git status --porcelain` and the sha256 of this file. It writes every result to `artifacts/local/tasks/JL-18c/live/jl18c-<start>.calls.jsonl` as it lands. At the end it writes the full record (hashes, instrument, every result, the analysis) to `jl18c-<start>.json` and prints one line per cell, the comparisons, the explanations and the verdict.
3. Retain stdout, stderr and the exit code. Report every cell as it fell, including failed calls.
4. A crash mid-run counts as BLOCKED. The JSONL keeps every paid answer.

## Known limits

- The repair pad is outside the stated mechanics (see States).
- Comprehension Nouls carry no rules text, so implied items that rest on rules (for example `ram_target__ends_run`, which needs "0 health ends the run" and the state's 8 HP) may read worse than they would in a Choice context. Only stated items decide a read.
- A preference Noul sees one option at a time, so it measures acceptability, not a ranking. The margin rule turns it into a ranking after the fact.
- The per-order mean of three repeats can pass an order whose single worst call is below the line. The minimum is reported for that reason.
- The named-buff text reveals which buff this cache holds while q2's rules still say a cache grants "one random buff". The option is worded as a reveal, not a contradiction.
- All tests use stub deciders. Nothing here has seen a live answer.

## Pinned inputs

The runner reads these files from `tools/jev-player/experiments/jl18c/`. `--live` refuses to start unless every line below matches.

- `states.json` sha256 `bf2ac2bfba8749a7f9e58ce3168c4fbd952784c50caf2642c4fb66ac8c0b6457`
- `questions.json` sha256 `8150c3b99d052b60fce8e03150bca8313fb54587d4e8533a5c07ee36cabf8ad6`
- `design.json` sha256 `d83c6cef0023dc34403723a86e5946c34752761d012e3473f9da9f84abe2ccba`
- `run.mjs` sha256 `613d2c3cf5e60c82b1719ae174f761d322868425c132f51967b5f0959aa8c2fa`

## Rendered examples

One body per design, the first call of the named cell, pretty-printed here. The runner sends the compact serialisation. `--dry-run` prints all 216; its output for this commit is retained under `artifacts/local/tasks/JL-18c/`.

### a-free-cache, call 1 of 216

Order: `take_cache`, `push_objective`, `sweep_scrap`.

```json
{
  "model": "jev-latest",
  "state": {
    "self": {
      "speed_ms": 14,
      "speed_tier": "cruise",
      "grounded": true,
      "hp": 82,
      "air_jump_available": true
    },
    "stage": {
      "name": "cable-bench",
      "time_s": 20,
      "tier": 1
    },
    "scrap": {
      "held": 60
    },
    "threats": [],
    "objective": {
      "kind": "reach_exit",
      "distance_m": 200
    }
  },
  "questions": {
    "intent": {
      "type": "choice",
      "instructions": "You are choosing for a rolling scrap mech in a roguelite stage. The rules: the player damages an enemy only by landing on it from above, or by ramming it while above the fast speed tier. A difficulty tier rises every 45 seconds of stage time and raises enemy health, spawn rate and cache prices. Opening a cache spends the scrap its option states and grants one random buff that stacks and lasts the rest of the run. Scrap is spent only on caches. Health regenerates starting 5 seconds after the last hit, and the run ends at 0 health. The stage is cleared by holding a 60 second exit charge at the exit. Each option is an action available right now, with what it involves. Choose the single intent to hold for the next second or two.",
      "criteria": {
        "take_cache": "You are rolling over the cache now. It opens for 0 scrap and no stop, and its random buff stacks for the rest of the run.",
        "push_objective": "Roll on past the cache to the exit, 200 m ahead, where a 60 s charge clears the stage. The cache stays unopened.",
        "sweep_scrap": "Detour about 2 s onto the scrap line. Scrap is spent only on caches; cache prices rise at the next tier, in 25 s."
      }
    },
    "danger": {
      "type": "score",
      "instructions": "How close is the player to being hit, given current health and the listed threats?",
      "criteria": [
        "Clear: no listed threat can reach the player in the next few seconds",
        "Contested: a listed threat can reach the player in the next few seconds",
        "Critical: a hit that a listed threat can land in the next few seconds would bring health to 0"
      ]
    },
    "greedy": {
      "type": "noul",
      "instructions": "If the player spent the next second or two taking reachable loot or a cache, would a listed threat or hazard reach the player during that time?"
    }
  }
}
```

### b-free-cache, call 13 of 216

Order: `take_cache__spends_scrap`, `take_cache__adds_stop`, `take_cache__run_buff`, `take_cache__forgoes_exit`, `push_objective__cache_unopened`, `push_objective__run_buff`, `push_objective__forgoes_exit`, `sweep_scrap__adds_stop`, `sweep_scrap__run_buff`.

```json
{
  "model": "jev-latest",
  "state": {
    "self": {
      "speed_ms": 14,
      "speed_tier": "cruise",
      "grounded": true,
      "hp": 82,
      "air_jump_available": true
    },
    "stage": {
      "name": "cable-bench",
      "time_s": 20,
      "tier": 1
    },
    "scrap": {
      "held": 60
    },
    "threats": [],
    "objective": {
      "kind": "reach_exit",
      "distance_m": 200
    }
  },
  "questions": {
    "take_cache__spends_scrap": {
      "type": "noul",
      "instructions": "One action is available right now, with what it involves: \"You are rolling over the cache now. It opens for 0 scrap and no stop, and its random buff stacks for the rest of the run.\" Does this action spend any scrap?"
    },
    "take_cache__adds_stop": {
      "type": "noul",
      "instructions": "One action is available right now, with what it involves: \"You are rolling over the cache now. It opens for 0 scrap and no stop, and its random buff stacks for the rest of the run.\" Does this action involve stopping or a detour?"
    },
    "take_cache__run_buff": {
      "type": "noul",
      "instructions": "One action is available right now, with what it involves: \"You are rolling over the cache now. It opens for 0 scrap and no stop, and its random buff stacks for the rest of the run.\" Does this action grant a buff that lasts the rest of the run?"
    },
    "take_cache__forgoes_exit": {
      "type": "noul",
      "instructions": "One action is available right now, with what it involves: \"You are rolling over the cache now. It opens for 0 scrap and no stop, and its random buff stacks for the rest of the run.\" Does this action give up heading toward the exit?"
    },
    "push_objective__cache_unopened": {
      "type": "noul",
      "instructions": "One action is available right now, with what it involves: \"Roll on past the cache to the exit, 200 m ahead, where a 60 s charge clears the stage. The cache stays unopened.\" Does this action leave the cache unopened?"
    },
    "push_objective__run_buff": {
      "type": "noul",
      "instructions": "One action is available right now, with what it involves: \"Roll on past the cache to the exit, 200 m ahead, where a 60 s charge clears the stage. The cache stays unopened.\" Does this action grant a buff that lasts the rest of the run?"
    },
    "push_objective__forgoes_exit": {
      "type": "noul",
      "instructions": "One action is available right now, with what it involves: \"Roll on past the cache to the exit, 200 m ahead, where a 60 s charge clears the stage. The cache stays unopened.\" Does this action give up heading toward the exit?"
    },
    "sweep_scrap__adds_stop": {
      "type": "noul",
      "instructions": "One action is available right now, with what it involves: \"Detour about 2 s onto the scrap line. Scrap is spent only on caches; cache prices rise at the next tier, in 25 s.\" Does this action involve stopping or a detour?"
    },
    "sweep_scrap__run_buff": {
      "type": "noul",
      "instructions": "One action is available right now, with what it involves: \"Detour about 2 s onto the scrap line. Scrap is spent only on caches; cache prices rise at the next tier, in 25 s.\" Does this action grant a buff that lasts the rest of the run?"
    }
  }
}
```

### c-no-objective, call 21 of 216

Order: `take_cache`, `roll_on`, `sweep_scrap`.

```json
{
  "model": "jev-latest",
  "state": {
    "self": {
      "speed_ms": 14,
      "speed_tier": "cruise",
      "grounded": true,
      "hp": 82,
      "air_jump_available": true
    },
    "stage": {
      "name": "cable-bench",
      "time_s": 20,
      "tier": 1
    },
    "scrap": {
      "held": 60
    },
    "threats": []
  },
  "questions": {
    "intent": {
      "type": "choice",
      "instructions": "You are choosing for a rolling scrap mech in a roguelite stage. The rules: the player damages an enemy only by landing on it from above, or by ramming it while above the fast speed tier. A difficulty tier rises every 45 seconds of stage time and raises enemy health, spawn rate and cache prices. Opening a cache spends the scrap its option states and grants one random buff that stacks and lasts the rest of the run. Scrap is spent only on caches. Health regenerates starting 5 seconds after the last hit, and the run ends at 0 health. The stage is cleared by holding a 60 second exit charge at the exit. Each option is an action available right now, with what it involves. Choose the single intent to hold for the next second or two.",
      "criteria": {
        "take_cache": "You are rolling over the cache now. It opens for 0 scrap and no stop, and its random buff stacks for the rest of the run.",
        "roll_on": "Roll on along the current line at cruise speed, past the cache, with no stop. The cache stays unopened.",
        "sweep_scrap": "Detour about 2 s onto the scrap line. Scrap is spent only on caches; cache prices rise at the next tier, in 25 s."
      }
    },
    "danger": {
      "type": "score",
      "instructions": "How close is the player to being hit, given current health and the listed threats?",
      "criteria": [
        "Clear: no listed threat can reach the player in the next few seconds",
        "Contested: a listed threat can reach the player in the next few seconds",
        "Critical: a hit that a listed threat can land in the next few seconds would bring health to 0"
      ]
    },
    "greedy": {
      "type": "noul",
      "instructions": "If the player spent the next second or two taking reachable loot or a cache, would a listed threat or hazard reach the player during that time?"
    }
  }
}
```

### d-free-heal, call 31 of 216

Order: `take_repair`, `push_objective`, `sweep_scrap`.

```json
{
  "model": "jev-latest",
  "state": {
    "self": {
      "speed_ms": 14,
      "speed_tier": "cruise",
      "grounded": true,
      "hp": 8,
      "air_jump_available": true
    },
    "stage": {
      "name": "cable-bench",
      "time_s": 20,
      "tier": 1
    },
    "scrap": {
      "held": 60
    },
    "threats": [],
    "objective": {
      "kind": "reach_exit",
      "distance_m": 200
    }
  },
  "questions": {
    "intent": {
      "type": "choice",
      "instructions": "You are choosing for a rolling scrap mech in a roguelite stage. The rules: the player damages an enemy only by landing on it from above, or by ramming it while above the fast speed tier. A difficulty tier rises every 45 seconds of stage time and raises enemy health, spawn rate and cache prices. Opening a cache spends the scrap its option states and grants one random buff that stacks and lasts the rest of the run. Scrap is spent only on caches. Health regenerates starting 5 seconds after the last hit, and the run ends at 0 health. The stage is cleared by holding a 60 second exit charge at the exit. Each option is an action available right now, with what it involves. Choose the single intent to hold for the next second or two.",
      "criteria": {
        "take_repair": "You are rolling over a repair pad now. It restores your health from 8 to the full 100 for 0 scrap and no stop.",
        "push_objective": "Roll on past the repair pad to the exit, 200 m ahead, where a 60 s charge clears the stage. The pad stays unused.",
        "sweep_scrap": "Detour about 2 s onto the scrap line. Scrap is spent only on caches; cache prices rise at the next tier, in 25 s."
      }
    },
    "danger": {
      "type": "score",
      "instructions": "How close is the player to being hit, given current health and the listed threats?",
      "criteria": [
        "Clear: no listed threat can reach the player in the next few seconds",
        "Contested: a listed threat can reach the player in the next few seconds",
        "Critical: a hit that a listed threat can land in the next few seconds would bring health to 0"
      ]
    },
    "greedy": {
      "type": "noul",
      "instructions": "If the player spent the next second or two taking reachable loot or a cache, would a listed threat or hazard reach the player during that time?"
    }
  }
}
```

### e-free-cache, call 43 of 216

Order: `take_cache`, `push_objective`, `sweep_scrap`.

```json
{
  "model": "jev-latest",
  "state": {
    "self": {
      "speed_ms": 14,
      "speed_tier": "cruise",
      "grounded": true,
      "hp": 82,
      "air_jump_available": true
    },
    "stage": {
      "name": "cable-bench",
      "time_s": 20,
      "tier": 1
    },
    "scrap": {
      "held": 60
    },
    "threats": [],
    "objective": {
      "kind": "reach_exit",
      "distance_m": 200
    }
  },
  "questions": {
    "take_cache": {
      "type": "noul",
      "instructions": "You are choosing for a rolling scrap mech in a roguelite stage. The rules: the player damages an enemy only by landing on it from above, or by ramming it while above the fast speed tier. A difficulty tier rises every 45 seconds of stage time and raises enemy health, spawn rate and cache prices. Opening a cache spends the scrap its option states and grants one random buff that stacks and lasts the rest of the run. Scrap is spent only on caches. Health regenerates starting 5 seconds after the last hit, and the run ends at 0 health. The stage is cleared by holding a 60 second exit charge at the exit. One action is available right now, with what it involves: \"You are rolling over the cache now. It opens for 0 scrap and no stop, and its random buff stacks for the rest of the run.\" Is this the action to take now?"
    },
    "push_objective": {
      "type": "noul",
      "instructions": "You are choosing for a rolling scrap mech in a roguelite stage. The rules: the player damages an enemy only by landing on it from above, or by ramming it while above the fast speed tier. A difficulty tier rises every 45 seconds of stage time and raises enemy health, spawn rate and cache prices. Opening a cache spends the scrap its option states and grants one random buff that stacks and lasts the rest of the run. Scrap is spent only on caches. Health regenerates starting 5 seconds after the last hit, and the run ends at 0 health. The stage is cleared by holding a 60 second exit charge at the exit. One action is available right now, with what it involves: \"Roll on past the cache to the exit, 200 m ahead, where a 60 s charge clears the stage. The cache stays unopened.\" Is this the action to take now?"
    },
    "sweep_scrap": {
      "type": "noul",
      "instructions": "You are choosing for a rolling scrap mech in a roguelite stage. The rules: the player damages an enemy only by landing on it from above, or by ramming it while above the fast speed tier. A difficulty tier rises every 45 seconds of stage time and raises enemy health, spawn rate and cache prices. Opening a cache spends the scrap its option states and grants one random buff that stacks and lasts the rest of the run. Scrap is spent only on caches. Health regenerates starting 5 seconds after the last hit, and the run ends at 0 health. The stage is cleared by holding a 60 second exit charge at the exit. One action is available right now, with what it involves: \"Detour about 2 s onto the scrap line. Scrap is spent only on caches; cache prices rise at the next tier, in 25 s.\" Is this the action to take now?"
    }
  }
}
```

### f-free-cache, call 67 of 216

Order: `take_cache`, `push_objective`, `sweep_scrap`.

```json
{
  "model": "jev-latest",
  "state": {
    "self": {
      "speed_ms": 14,
      "speed_tier": "cruise",
      "grounded": true,
      "hp": 82,
      "air_jump_available": true
    },
    "stage": {
      "name": "cable-bench",
      "time_s": 20,
      "tier": 1
    },
    "scrap": {
      "held": 60
    },
    "threats": [],
    "objective": {
      "kind": "reach_exit",
      "distance_m": 200
    }
  },
  "questions": {
    "intent": {
      "type": "choice",
      "instructions": "You are choosing for a rolling scrap mech in a roguelite stage. The rules: the player damages an enemy only by landing on it from above, or by ramming it while above the fast speed tier. A difficulty tier rises every 45 seconds of stage time and raises enemy health, spawn rate and cache prices. Opening a cache spends the scrap its option states and grants one random buff that stacks and lasts the rest of the run. Scrap is spent only on caches. Health regenerates starting 5 seconds after the last hit, and the run ends at 0 health. The stage is cleared by holding a 60 second exit charge at the exit. Each option is an action available right now, with what it involves. Choose the single intent to hold for the next second or two.",
      "criteria": {
        "take_cache": "You are rolling over the cache now. It opens for 0 scrap and no stop, and its random buff stacks for the rest of the run.",
        "push_objective": "Roll on past the cache to the exit, 200 m ahead, where a 60 s charge clears the stage. The cache stays unopened.",
        "sweep_scrap": "Detour about 2 s onto the scrap line. Scrap is spent only on caches; cache prices rise at the next tier, in 25 s."
      }
    }
  }
}
```
