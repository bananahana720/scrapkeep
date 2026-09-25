# Controls: what the decider must get right before you trust it

A control is a state with a known correct answer, run against the live decider under the current instrument. Controls decide whether an epoch may be trusted at all. They run before any evaluation that counts. Lesson ids point at [the lesson ledger](lessons.md). Numbers are examples from one lab, and none of them is a threshold to copy.

## Make controls executable

- Each control is code that calls the live decider and writes a retained record: state, options, order, answer, probabilities, resolved model and answer source (RML-10). In one lab a control existed only as a sentence in a README. Its cited pass numbers had no artifact behind them and could not be reproduced.
- Controls never pass through the verdict cache (RML-11).
- The pass check asserts that every answer came from the live decider (RML-11). A deterministic fallback can match the expected label by construction. In one triage lab, 26 fallback answers produced by a call-cap refusal cascade counted as a passing control in a probe run. The final run had no fallbacks, so its reported number held, but the check was blind to the gap.

## The control set

| Control | State | Pass condition, written before the run |
| --- | --- | --- |
| Dominance | One option is strictly better and costs nothing. A game example is a free heal pickup at low health with no threat near. | The dominant option wins in every order, by the margin rule the method needs. |
| Lethal | One option is certainly fatal or destructive. | That option is refused in every order. Its probability stays under a stated line. |
| Wording swap | Two paraphrases carry the same facts. | The choice matches across paraphrases and orders, and the shift stays under the noise line. |
| Injected known case | A triage router gets an input whose label is certain, such as a deliberate assertion failure. | The router returns the known label from the live decider. |

The set is a design choice. Add controls for each failure you have seen. Do not remove one because it keeps failing.

A control whose target option was removed by the precondition gate fails (RML-16). In one lab a lethal-option control ran in a state where the dangerous option was never offered. The run scored it as a control failure rather than a free pass.

## Run every order

Order effects are real and their direction changes between runs (RML-12).

1. Run every permutation of the options. Two options give two orders. Three options give six.
2. Repeat each order. One pre-registered run used three repeats per order.
3. Report, per position: mean, minimum, maximum and standard deviation. Report overall mean, minimum and pooled standard deviation.
4. Require every order to pass on its own. An average over orders hides a failing order.
5. Measure the position effect in the run being judged. Do not assume that "last wins" or "first wins" from an earlier run.

In one lab, a review of one run found a last-position boost: order shifts of 0.09 to 0.35 against 0.03 to 0.06 same-position noise. A pre-registered run the same day found a first-position depression in every flagged cell instead.

## Set the noise line in the run

A line copied from an earlier run is provisional (RML-13). In one lab a maximum-shift line of 0.15 was derived from one pair of one wording's order noise. The next run's same-wording order movement ranged from 0.09 to 0.35.

Derive the line from the run being judged. One pre-registration used `max(0.1, 3 × pooled within-order SD)`. Treat that formula as an example of the shape, not as a validated constant.

## Pair the pass rules

A "same choice in both orders" rule is blind to magnitude (RML-14). In one lab two wording-swap controls passed that rule with shifts of 0.28 and 0.17. A symmetric 0.15 line would have failed both. Use both rules: the choice must match, and the shift must stay under the noise line.

## Wording swap

A wording control is valid only when every decision-bearing fact appears in both arms' option text (RML-15). Check parity per fact before the run:

1. List every fact the decision could depend on: cost, duration, permanence, risk, what else the resource could buy.
2. For each arm, mark where each fact appears.
3. Fix every gap before the run. A fact present in one arm and absent in the other turns the control into an information test.

In one lab, one phrasing gave the tested option 0.74 and 0.69, and a neutral phrasing gave 0.27 and 0.26. Putting the same facts into both arms closed most of that gap. One fact still missing from the neutral arm left a residual gap of 0.24 and 0.38 against 0.10 and 0.19.

## Per-option ratings need their own rule

Per-option yes/no ratings remove most order effects, and they answer a different question (RML-17). They ask "is this option acceptable", so two good options can both score high.

In one pre-registered run, per-option ratings had order ranges of 0.007 to 0.018. They rated the dominant option top in 18 of 18 calls, yet cleared the pre-registered 0.2 margin over the best alternative in 0 of 6 orders. The gap was 0.10 to 0.14, because a competing option rated about 0.57 on its own. The margin rule, not the model's ranking, decided that cell. Pick the rule (margin, rank or both) before the run and say why.

## A worked example

A small arena game asks the model each tick whether to attack, retreat or collect a pickup.

1. Build three dominance states: a free heal pickup at low health, no threat in range, all else neutral.
2. Build one lethal state: attacking means certain death.
3. Build one wording swap: two paraphrases of the options with every fact listed in both.
4. Run six orders of the three options, three repeats each, against the live decider with the cache disabled.
5. Compute the pooled within-order standard deviation, set the noise line, and apply the pass rules written in the [pre-registration](preregistration.md).
6. Reject the epoch if any order of any control fails, or if any answer's source is not the live decider.
