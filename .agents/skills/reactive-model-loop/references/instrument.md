# Instrument: what the decider sees and how it is identified

This reference covers the split between model and code, the precondition gate, instrument identity, confidence floors and framing effects. Lesson ids point at [the lesson ledger](lessons.md). Numbers are examples from one lab unless marked otherwise, and none of them is a threshold to copy.

## Split the decision between model and code

The model picks coarse intent. Code enumerates the candidates, checks preconditions, executes the chosen intent and owns every safety reflex, such as collision stops or a hard budget stop (RML-01). Public projects that put a model in a game loop all converge on this split, with the model choosing a target or macro goal and code handling aiming, movement and collision. That observation comes from their READMEs and source excerpts and is unaudited.

Decompose each decision before writing any prompt:

1. List the decisions the system needs per tick or per item.
2. Reduce them to the smallest set of orthogonal questions. A question the code can answer exactly, such as a distance, a count or a date, is not a model question (RML-09).
3. For each multi-option choice, decide between one choice over all options and one yes/no rating per option. In one lab, per-option ratings showed no order effect, but they answer "is this option acceptable" rather than "which option wins". Their pass rule, a margin over the best alternative or a rank, must be fixed before the run (RML-17).
4. Name the conservative default that applies when the model is unavailable. See [runtime](runtime.md#fallbacks).

A public use-case list states that one model version "reads literally, is weak at math, counting and dates, and accuracy drops with irrelevant state" (RML-09). The list is unaudited. Treat it as a reason to keep state lean and precomputed, not as a measured limit.

State encoding is a design choice. One public project (public projects, unaudited) documents a signed bearing convention for directions (positive is left, negative is right) and rounds values to integers. Whatever encoding you pick, state its conventions in the prompt and keep them fixed within an epoch.

## Treat the precondition gate as part of the instrument

The gate decides which options the model ever sees. An option removed by the gate cannot be chosen, so a gate defect looks like a model preference.

- Gate on reachability, not on present value, for any option that needs future action to become valid (RML-02). In one lab an option required a speed the agent reached only after a run-up, but the gate checked current speed. The option survived the gate for 7 intents across 40 trials on one arm and none across 40 on another, and one scenario went 0 of 20 for every arm.
- Test the gate's preconditions, the fallback when every option is gated, and the confidence-floor path (RML-16).
- A control whose target option was gated away is a failed control, not a free pass (RML-16).

## Identify the instrument

An instrument identity is a hash of every input that changes an answer (RML-04):

- the question set and its hash
- option text and option order policy
- the resolved model, as reported by the provider (RML-05)
- the confidence floor and any other thresholds
- the gate rules and the all-gated fallback
- the state encoder version, including the export rule for which entities stay in state (RML-44)

Decide the export rule per mechanic before the first batch (RML-44). A dead or permanently removed entity can leave the state. An entity that survives a hit and still acts stays in the state. Changing the rule starts a new epoch. In one lab, a hide-after-hit rule written for a game whose foes could not die was reused in two ports where foes survive a hit. In one port a hit foe vanished from state while still alive and dangerous, and two of its three scenarios were confounded.

A manual version constant is not enough by itself. In one lab a review found a hand-bumped gate version that had not changed when the precondition rules did (RML-04). Either derive the version from the inputs or add a test that fails when a gate rule changes without a bump.

Record the resolved model, never the alias (RML-05). An alias such as "latest" can move to a new model under a passed epoch, so the epoch then covers a model that never ran the controls. At least three of six public projects inspected pin a bare alias; the survey's own counts disagree (public projects, unaudited).

An epoch is one identity. Changing any input starts a new epoch, and the new epoch is untrusted until it re-passes the [controls](controls.md) and the [blind corpus](corpus.md). This is a design choice.

## Keep the raw answer behind a confidence floor

A floor replaces a low-confidence answer with a default. Without the raw answer, "the model had no opinion" and "the model was overridden" look the same (RML-06).

- Store the pre-floor choice, its confidence, and a flag that the floor fired.
- Calibrate the floor on more than one case. In one lab a floor of 0.05 was tuned on a single sub-floor case (0.02, next-lowest 0.25).
- Public projects use similar floors that fall back to named deterministic code. That observation is unaudited.

## Watch for framing

Framing effects are instrument properties. Measure them with [controls](controls.md), and do not argue them away.

- A prompt that states a valuation reads that valuation back as a result (RML-07). In one lab a sweep headline said a price had no effect. Its own retained artifact showed 6 of 15 cases taken by the script's rule, not the 4 of 15 claimed.
- A goal named next to the option under test biases the choice toward options that serve that goal (RML-08). In one lab, removing a named goal from state and option text lifted the dominant option from 0.478 to 0.781 and passed 6 of 6 orders. The run showed that removal was sufficient. It did not show that it was necessary.
- Two phrasings of one question differ mostly through the facts each carries (RML-15). See [controls](controls.md#wording-swap).
