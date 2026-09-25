# Lesson ledger

Each lesson is one rule with its status, origin and evidence. `SKILL.md` and the other references cite lessons by id. Statuses:

- `provisional`: the default. One run, one review or one source supports it.
- `established`: a second independent run or review supports it.
- `retracted`: a later result overturned it. The text stays, and `Overturned by` names the result.

Origins are descriptions, not locations. A host project that uses this skill keeps its own map from each id to the records the lesson came from. Numbers in the evidence lines are examples from the named origin, not thresholds. Claims from public projects are third-party and unaudited, so a lesson that rests on them stays provisional.

## Lessons

- **RML-01** · status: provisional · since: 2026-09-25 · origin: public projects that put a model in a game loop, and one lab
  The model picks coarse intent. Deterministic code owns execution, safety and preconditions.
  Evidence: every public project surveyed has the model choose a target or macro goal while code handles aiming, movement and collision (read from READMEs and source excerpts, unaudited). One lab used the same split.
  Overturned by: —

- **RML-02** · status: provisional · since: 2026-09-25 · origin: one lab, one review finding
  A precondition gate that checks present state for an option reachable only through future action is a category error, not a tuning problem.
  Evidence: in one lab an option needed a speed reached only after a run-up, but the gate checked current speed. The option survived the gate in 7 of 40 trials on one arm and 0 of 40 on another, and one scenario went 0 of 20 for every arm. Later ports gated on reachability instead.
  Overturned by: —

- **RML-03** · status: established · since: 2026-09-25 · origin: one program, two independent reviews
  Keep the model call off every gate and verify path, and test the isolation through transitive imports.
  Evidence: two reviews of different tools each confirmed no direct gate-path import of the model-calling module, and each noted that the isolation test checked direct imports only.
  Overturned by: —

- **RML-04** · status: provisional · since: 2026-09-25 · origin: one lab, one review finding
  Instrument identity is a hash of every input that changes behaviour. A hand-bumped version constant under-versions.
  Evidence: a review found a manual gate-version constant that had not been bumped when precondition rules and fallback wording changed.
  Overturned by: —

- **RML-05** · status: provisional · since: 2026-09-25 · origin: one lab, one review finding and its fix; a public project survey
  Pin the resolved model, not the requested alias, into any identity that bounds what was tested.
  Evidence: an epoch key used a floating alias, so a passed epoch could cover a model that never ran the controls. A later change stored resolved models. Four of six public projects inspected pin a bare alias (unaudited).
  Overturned by: —

- **RML-06** · status: provisional · since: 2026-09-25 · origin: one lab, one review finding
  A confidence floor keeps the pre-floor answer and a flag, and needs more than one calibration case.
  Evidence: a floor of 0.05 was tuned on one sub-floor case (0.02, next-lowest 0.25). The scorer discarded the raw choice, so "declined" and "overridden" looked the same until raw-choice and low-confidence fields were added. Public projects use similar floors (unaudited).
  Overturned by: —

- **RML-07** · status: provisional · since: 2026-09-25 · origin: one lab, one consequential audit
  A prompt that states a valuation reads that valuation back as a result.
  Evidence: a prompt stated what a resource was for. A sweep headline said price had no effect, and the retained artifact showed 6 of 15 cases taken by the script's own rule, not the 4 of 15 claimed.
  Overturned by: —

- **RML-08** · status: provisional · since: 2026-09-25 · origin: one lab, 216-call pre-registered run
  A goal named next to the option under test biases the choice toward options that serve that goal.
  Evidence: removing a named goal from state, option id and option text lifted the dominant option from 0.478 to 0.781 and passed 6 of 6 orders. The run showed sufficiency, not necessity. Framing and position were not fully separated.
  Overturned by: —

- **RML-09** · status: provisional · since: 2026-09-25 · origin: public use-case list, unaudited
  Compute arithmetic, counts and dates in code, and keep irrelevant state out of the prompt.
  Evidence: a public list states that one model version "reads literally, is weak at math, counting and dates, and accuracy drops with irrelevant state". No measurement in this ledger tests the claim.
  Overturned by: —

- **RML-10** · status: provisional · since: 2026-09-25 · origin: one lab, one consequential audit
  A control is executable, live-run and retained. A control that exists only in prose is not a control.
  Evidence: a documented control had no code path, and its cited pass numbers had no artifact and could not be reproduced.
  Overturned by: —

- **RML-11** · status: provisional · since: 2026-09-25 · origin: one lab, two review findings
  Controls never read the cache, and the pass check asserts the answer came from the live decider.
  Evidence: one review confirmed the control runner passed no cache to the decider. Another found that 26 fallback answers from a call-cap refusal cascade counted as a passing control in a triage probe run. The final run had no fallbacks, so its number held.
  Overturned by: —

- **RML-12** · status: established · since: 2026-09-25 · origin: one lab, two runs on the same day
  Run every order with repeats, require each order to pass, and measure the position effect in the run being judged. Its direction is not a stable prior.
  Evidence: one run's review found a last-position boost (order shifts 0.09 to 0.35 against 0.03 to 0.06 same-position noise). The next run, pre-registered, found a first-position depression in every flagged cell.
  Overturned by: —

- **RML-13** · status: provisional · since: 2026-09-25 · origin: one lab, a line from one run exceeded by the next
  Derive the noise line from the run being judged. A line copied from an earlier run is provisional.
  Evidence: a 0.15 maximum-shift line came from one pair of one wording's order noise. The next run's same-wording order movement ranged from 0.09 to 0.35. One pre-registration then used `max(0.1, 3 × pooled within-order SD)`, which is itself untested beyond that run.
  Overturned by: —

- **RML-14** · status: provisional · since: 2026-09-25 · origin: one lab, one review finding
  A "same choice in both orders" rule is blind to magnitude. Pair it with a maximum-shift line.
  Evidence: two wording-swap controls passed the same-choice rule with shifts of 0.28 and 0.17. A symmetric 0.15 line would have failed both.
  Overturned by: —

- **RML-15** · status: established · since: 2026-09-25 · origin: one lab, two runs and two reviews
  A wording control is valid only when every decision-bearing fact is in both arms. Check parity fact by fact.
  Evidence: one phrasing gave the tested option 0.74 and 0.69 against 0.27 and 0.26 for a neutral phrasing. A second run put the same facts in both arms and closed most of the gap. One omitted fact left a residual of 0.24 and 0.38 against 0.10 and 0.19.
  Overturned by: —

- **RML-16** · status: provisional · since: 2026-09-25 · origin: one lab, two review items
  The precondition gate is part of the instrument. Test it, and score a control whose target was gated away as failed.
  Evidence: an audit found the gate's preconditions, the all-gated fallback and the floor path untested, and a later review confirmed tests were added. A lethal-option control in which the option was never offered was scored as a control failure.
  Overturned by: —

- **RML-17** · status: provisional · since: 2026-09-25 · origin: one lab, 216-call pre-registered run
  Per-option yes/no ratings remove order effects but answer "is this acceptable", so their margin or rank rule, fixed in advance, decides the verdict.
  Evidence: per-option ratings had order ranges of 0.007 to 0.018 and rated the dominant option top in 18 of 18 calls, yet cleared the pre-registered 0.2 margin over the best alternative in 0 of 6 orders (gap 0.10 to 0.14), because a competing option rated about 0.57 on its own.
  Overturned by: —

- **RML-18** · status: established · since: 2026-09-25 · origin: one lab, a blind corpus reviewed in three rounds
  Gate only on a blind corpus from a separate labeller with a forbidden list, per-case provenance, and burned cases moved out of the gating set.
  Evidence: the corpus was built this way. Its neutrality review failed once and passed after a fix, and reviewers confirmed the labellers were isolated.
  Overturned by: —

- **RML-19** · status: provisional · since: 2026-09-25 · origin: one program, one review finding and one ruling
  Blindness holds relative to one boundary. Recheck it per use, and keep case ids out of records the prompt author reads.
  Evidence: a triage tool's "blind" set was labelled by its prompt author. A ruling limited the separate-labeller rule to gated decision corpora. The shared execution record named blind case ids, so later briefs had to forbid reading it.
  Overturned by: —

- **RML-20** · status: established · since: 2026-09-25 · origin: one lab, two review rounds
  Score a text-only baseline, automate the scan, and check by hand.
  Evidence: a scanner missed option wording that named the cue, and a text-only rule scored 5 of 5 on those cases. In the next round a reviewer's hand-built text rule scored 71% against the writer's reported 61%, with chance at 48%.
  Overturned by: —

- **RML-21** · status: established · since: 2026-09-25 · origin: one program, three independent reviews
  An edit made after seeing a result voids that result. Redo it blind, and disclose how cases were selected.
  Evidence: an audit found a relabel in the same commit as a prompt change that turned 3 of 4 into 4 of 4. A triage review had a wording change made after one probe re-scored from a frozen cache with zero new calls. A timing review failed a report that added a case after seeing its simulated result.
  Overturned by: —

- **RML-22** · status: provisional · since: 2026-09-25 · origin: one lab, one review finding; public projects
  Check the baseline policy before comparing against it. A scripted baseline needs memory and a stop condition.
  Evidence: a scripted rule ladder kept attacking a threat the world never removed and scored 0 of 20, below random. The fix hid a neutralised threat from the exported state for every arm alike. Public reports: one project's model tied a hand-coded heuristic, and one article says a scripted bot would beat the model (both unaudited).
  Overturned by: —

- **RML-23** · status: provisional · since: 2026-09-25 · origin: one lab, one review item
  Compare arms on paired trials that share a seeded start per trial index.
  Evidence: seeded start jitter was shared across arms per trial. Without it a deterministic arm's 20 trials are one trial repeated 20 times.
  Overturned by: —

- **RML-24** · status: provisional · since: 2026-09-25 · origin: one lab, 216-call pre-registered run
  Pre-register with hash-pinned inputs, a runner that refuses on mismatch, reviewer approval before any call, a change record, and a single run in which a crash counts as blocked.
  Evidence: six designs, every order, three repeats per order. A reviewer approved the plan before any call. One pre-run change was logged with its requester and reason. No call failed.
  Overturned by: —

- **RML-25** · status: provisional · since: 2026-09-25 · origin: one lab, 216-call pre-registered run
  Fix the readings table in advance, report which rows fired, add none, and label other findings exploratory.
  Evidence: the report cited fired rows only and listed a position-direction flip under a separate heading as not pre-registered.
  Overturned by: —

- **RML-26** · status: established · since: 2026-09-25 · origin: one program, two separate corrections
  Retract by appending a correction that names the old and the new value. Never edit the earlier claim.
  Evidence: one compensating entry retracted numeric claims finding by finding after an audit. Another, prompted by a cross-check against a delegate log, listed each wrong timestamp beside its real one.
  Overturned by: —

- **RML-27** · status: established · since: 2026-09-25 · origin: one program, an audit and two later reviews
  Tag every claim measured, computed or retracted. A computed number presented as measured recurs.
  Evidence: an audit retagged arithmetic figures as unverified. Two later reviews failed timing reports whose seconds were simulated or stamped after the operation ran.
  Overturned by: —

- **RML-28** · status: provisional · since: 2026-09-25 · origin: one lab, one review finding
  Replay makes zero calls, a miss is an error, and an absent resolved-model field is a mismatch.
  Evidence: a cache entry with a null resolved model left the replay anchor null, so any later verdict passed both replay checks.
  Overturned by: —

- **RML-29** · status: provisional · since: 2026-09-25 · origin: one lab, one review finding confirmed by a direct probe
  Redact before clipping, hashing, keying and logging, and test redaction against adversarial formats.
  Evidence: the ordering was right, but a review found four gaps: a case-sensitive bearer-token pattern, JSON-quoted keys, a second home path after a colon, and a key that entered by another code path in one mode. A direct probe of the redaction function confirmed them.
  Overturned by: —

- **RML-30** · status: provisional · since: 2026-09-25 · origin: one lab, one review; public projects
  Every failure path returns one conservative default, never cached and always labelled as not from the model.
  Evidence: a triage tool returned the same conservative label on no key, HTTP error, timeout, malformed reply and off-menu answers, and cached none of them. One public project labels fallbacks and an offline simulated policy on screen (unaudited).
  Overturned by: —

- **RML-31** · status: provisional · since: 2026-09-25 · origin: one lab, two review findings
  Count call caps before sending, and count failures.
  Evidence: 26 cap refusals returned with no request sent. In another tool a cross-run cap undercounted because failed calls threw before the line that incremented the counter.
  Overturned by: —

- **RML-32** · status: provisional · since: 2026-09-25 · origin: one lab, one review finding and its fix
  A run in which every call failed never replaces a passed epoch record.
  Evidence: a review found that a transient outage would overwrite a passed epoch with a failed one. The fix writes an error record beside the existing one. A partial-error run still replaces it.
  Overturned by: —

- **RML-33** · status: provisional · since: 2026-09-25 · origin: one lab, one independent port
  Validate untrusted keys with own-property lookups and reject non-strings.
  Evidence: a JavaScript validator accepted an event kind of `constructor` and an array-wrapped option name, and threw on `toString`. Across 27 new test inputs it wrongly accepted 5 and threw on 4 before the fix. The same pattern sat latent in the decider's gate lookup.
  Overturned by: —

- **RML-34** · status: provisional · since: 2026-09-25 · origin: one lab, one independent port
  Build a second validator from the written spec alone and run both against shared fixtures.
  Evidence: a port written from the spec found three defects in the reference validator and three gaps in the spec. A reviewer then confirmed the port's gate matched the decider rule by rule.
  Overturned by: —

- **RML-35** · status: provisional · since: 2026-09-25 · origin: one program, one incident
  A command that can make paid calls returns from `--help` and `--dry-run` before any request.
  Evidence: probing a scoring command with `--help` ran it, because it had no argument handling, and it made 16 unplanned live calls. The calls were ruled not evidence.
  Overturned by: —

- **RML-36** · status: established · since: 2026-09-25 · origin: one lab, the same defect found twice
  A usage field the provider did not report is `null`, never 0.
  Evidence: the provider's usage carried only input and output tokens. A run recorded by older code printed 0 for the absent cache fields, and a later regression in the run recorder did the same. Two separate reviews caught them.
  Overturned by: —

- **RML-37** · status: provisional · since: 2026-09-25 · origin: one program's reviews
  Record each usage field under its own name, and never sum token fields across kinds.
  Evidence: every review in the program reported input, output, cache-read and cache-write tokens separately, because each kind is priced differently.
  Overturned by: —

- **RML-38** · status: provisional · since: 2026-09-25 · origin: one program, one ledger defect
  Dedupe by request id before summing usage from transcripts or logs.
  Evidence: a ledger summed every assistant record. 49 records held 22 distinct request ids, which inflated output tokens about 2.05 times and cache reads about 2.2 times, and every figure taken from that ledger.
  Overturned by: —

- **RML-39** · status: established · since: 2026-09-25 · origin: one lab, stale latency copies caught twice
  Every latency figure cites the retained run it came from, and copies are regenerated when the prompt changes.
  Evidence: three sources gave 223 ms, about 280 ms and 286 ms, and the retained run's median was 294 ms. An audit and a later review each caught a stale copied figure.
  Overturned by: —

- **RML-40** · status: provisional · since: 2026-09-25 · origin: public projects, unaudited
  Cap spend with a budget persisted across restarts.
  Evidence: one public project keeps a cumulative dollar cap with a per-request reserve in a file that survives restarts. Most others surveyed rely on call-rate caps or a timeout alone. Read from READMEs, not run.
  Overturned by: —

- **RML-41** · status: established · since: 2026-09-25 · origin: one program, two reviews
  Record tree state as well as the commit. In a deterministic mode, a clean-commit re-run with matching trace hashes proves which code produced the evidence.
  Evidence: one review conditioned admission on a clean-commit re-run, which matched the dirty-tree batch hash for hash, 20 of 20. Another required the tree state at run time to be retained.
  Overturned by: —

- **RML-42** · status: provisional · since: 2026-09-25 · origin: one program's review record
  Send recomputation from raw artifacts and instrument-validity questions to the strongest review tier.
  Evidence: the deepest catches (a contradicted headline, a prose-only control, a relabel-dependent score) came only from the consequential audit tier. Routine reviews caught contract and mechanical defects.
  Overturned by: —

- **RML-43** · status: provisional · since: 2026-09-25 · origin: one lab, three repeat sweeps
  Blocking lockstep in a deterministic mode gives exactly reproducible traces, so evidence runs block.
  Evidence: 360 of 360 repeat trials had identical trace hashes across three sweeps. The same lab's stochastic physics mode diverged in about 1 trial in 20 and could flip the outcome. The realtime alternative was not measured.
  Overturned by: —

## Changelog

Append-only. One row per change. Change types: new lesson, second confirmation, lesson overturned, new model version or alias move, instrument or question-set change.

| Date | Change type | Ids touched | Evidence or commit | Reviewer |
| --- | --- | --- | --- | --- |
| 2026-09-25 | new lesson | RML-01 to RML-43 | Initial ledger, written from three lesson inventories of one lab program and one public prior-art survey | pending independent review |
