# Controls: what the decider must get right before you trust it

A control is a state with a known correct answer, run against the live decider under the current instrument. Controls decide whether an epoch may be trusted at all. They run before any evaluation that counts. Lesson ids point at [the lesson ledger](lessons.md). Numbers are examples from one lab, and none of them is a threshold to copy.

## Make controls executable

- Each control is code that calls the live decider and writes a retained record: state, options, order, answer, probabilities, resolved model and answer source (RML-10). In one lab a control existed only as a sentence in a README. Its cited pass numbers had no artifact behind them and could not be reproduced.
- Controls never pass through the verdict cache (RML-11).
- The pass check asserts that every answer came from the live decider (RML-11). A deterministic fallback can match the expected label by construction. In one triage lab, 26 fallback answers produced by a call-cap refusal cascade counted as a passing control in a probe run. The final run had no fallbacks, so its reported number held, but the check was blind to the gap.

## Keep the fallback rate apart from the model's preference

A pipeline that falls back some fraction of the time mixes two questions into one control: does the model prefer the right option, and does the pipeline answer at all (RML-49).

- Judge each control's pass rule on live-model answers only. A fallback never counts toward a pass (RML-11), and it never counts as the model's preference either.
- Pre-register a minimum number of live answers per order. An order that falls short is inconclusive, not passed.
- Pre-register a fallback budget: the largest fallback rate the system may have, set from what a fallback costs. Count every non-model answer in the run against it, controls included, and report the rate as its own finding with its own pass or fail.
- Report both verdicts. "The model prefers the dominant option" and "the pipeline falls back too often" lead to different fixes.

Without the split, a small built-in fallback rate decides the verdict. In one exercise a pipeline fell back on about 5% of calls by design. At that rate a 30-call control that fails on any non-model answer fails with probability about 0.79 (computed, unverified), whatever the model prefers. Its wording-swap control failed only because 4 answers in one arm were fallbacks, and it passed on model answers alone.

## The control set

| Control | State | Pass condition, written before the run |
| --- | --- | --- |
| Dominance | One option is strictly better and costs nothing. A game example is a free heal pickup at low health with no threat near. | The dominant option wins in every order, by a margin rule of its own (RML-48). |
| Lethal | One option is certainly fatal or destructive. | That option is refused in every order. Its probability stays under a line set from the consequence before the run (RML-53). |
| Wording swap | Two paraphrases carry the same facts, plus a sensitivity arm (RML-50). | The choice matches across paraphrases and orders, the shift stays under the noise line, and the sensitivity arm moves the answer. |
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

Derive the line from the run being judged: a pre-registered multiple of the pooled within-order standard deviation, computed from that run's repeats. This skill hands out no constant, and no floor to copy.

A fixed floor under the measured line is a separate decision (RML-48). Add one only when the decision needs it, and pre-register its value with a reason tied to the decision's consequence: for example, the smallest shift that would change what the system does. For every cell, report the measured line, the floor, and which of the two decided the verdict. A verdict decided by the floor is a verdict about the floor, not about the model.

## Pair the pass rules

A "same choice in both orders" rule is blind to magnitude (RML-14). In one lab two wording-swap controls passed that rule with shifts of 0.28 and 0.17. A symmetric 0.15 line would have failed both. Use both rules: the choice must match, and the shift must stay under the noise line.

## Dominance needs its own margin rule

A floor points the opposite way in the two kinds of control (RML-48). A shift control passes when the shift stays under the line, so a floor makes it more lenient. A dominance control passes when the margin (the dominant option's probability minus the best alternative's) clears the line, so the same floor makes it stricter. A line written for shift controls and reused as a dominance margin can fail a decider whose win is many standard deviations clear.

1. Write the dominance margin rule separately from the shift rule, and say what it protects against. "Wins in every answer" catches the wrong choice. A margin over measured noise catches a win that is a coin flip.
2. If the margin rule has a fixed floor, pre-register its value and the consequence it stands for, as above.
3. Report the measured margin line and the floor side by side, and say which one decided each order.

In one exercise a pre-registration copied an example floor of 0.1 from a skill. The dominant option won 30 of 30 model answers. Its smallest margin was 0.058, and the pooled within-order standard deviation was 0.008, so the margin was about 7.5 standard deviations. The copied floor, not measured noise, failed four of six orders; under the measured term alone the cell passes on model answers. The same run showed a last-position boost, so the floor failure and the position effect were entangled. Reporting both lines made that visible.

## Set the lethal line from the consequence

A lethal option must be refused in every answer, and its probability must stay under a line (RML-53). Pick the line before the run, from what one loss costs, and write the reasoning into the pre-registration.

1. Decide whether the decider samples its answer from its probabilities or takes the top option. If it samples, the probability is the per-call chance of the fatal act, and the line is the accepted loss rate divided by the number of such decisions the system makes in that period. If it takes the top option, the probability is a distance from being chosen, and the line is a margin: how far below the chosen option the fatal one must sit.
2. Scale the line to the consequence. A reversible loss tolerates a looser line than the loss of the device, the account or the run.
3. Do not choose a round number because it looks strict. In one exercise a line of 0.10 was chosen with no rationale. The fatal option was chosen 0 of 28 times, yet its probability ranged from 0.13 to 0.31, so the cell failed in six of six orders. Whether that is a real hazard depends on how the decider turns probabilities into choices, which the line never stated.

## Wording swap

A wording control is valid only when every decision-bearing fact appears in both arms' option text (RML-15). Check parity per fact before the run:

1. List every fact the decision could depend on: cost, duration, permanence, risk, what else the resource could buy.
2. For each arm, mark where each fact appears.
3. Fix every gap before the run. A fact present in one arm and absent in the other turns the control into an information test.

In one lab, one phrasing gave the tested option 0.74 and 0.69, and a neutral phrasing gave 0.27 and 0.26. Putting the same facts into both arms closed most of that gap. One fact still missing from the neutral arm left a residual gap of 0.24 and 0.38 against 0.10 and 0.19.

### Show that wording can move the answer

A wording swap passes trivially for a decider that never reads the wording (RML-50). Add a sensitivity arm, in the spirit of the hash sensitivity control (RML-45): change the text of one decision-bearing fact so the right answer changes, and require the answer to move. If it does not move, the swap's pass means "the decider ignores text", not "the decider is robust to phrasing". Report it that way.

The same holds for every input a control holds fixed. A control that never varies state or the size of a risk says nothing about whether the decider reads them. Probe each input the decision should depend on. In one exercise the decider passed its wording swap on model answers, but it read only numeric fields and option position. State had no effect (the pad was chosen 28 of 28 at 9% battery and at 97%), and a risk of 0.001 was treated the same as a certain loss.

## Per-option ratings need their own rule

In one lab, per-option yes/no ratings showed no order effect, and they answer a different question (RML-17). They ask "is this option acceptable", so two good options can both score high.

In one pre-registered run, per-option ratings had order ranges of 0.007 to 0.018. They rated the dominant option top in 18 of 18 calls, yet cleared the pre-registered 0.2 margin over the best alternative in 0 of 6 orders. The gap was 0.10 to 0.14, because a competing option rated about 0.57 on its own. The margin rule, not the model's ranking, decided that cell. Pick the rule (margin, rank or both) before the run and say why.

## A worked example

A small arena game asks the model each tick whether to attack, retreat or collect a pickup.

1. Build three dominance states: a free heal pickup at low health, no threat in range, all else neutral.
2. Build one lethal state: attacking means certain death.
3. Build one wording swap: two paraphrases of the options with every fact listed in both.
4. Run six orders of the three options, three repeats each, against the live decider with the cache disabled.
5. Compute the pooled within-order standard deviation, set the noise line, and apply the pass rules written in the [pre-registration](preregistration.md) to live-model answers.
6. Reject the epoch if any order of any control fails, if any order has fewer live answers than the pre-registered minimum, or if the fallback rate is over its budget. Report the fallback finding separately from the preference verdict.
