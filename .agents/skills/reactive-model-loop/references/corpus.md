# Corpus: how to evaluate the decider without fooling yourself

Controls say whether an epoch may be trusted at all. The corpus says how well the decider does on cases nobody tuned it against. Lesson ids point at [the lesson ledger](lessons.md). Numbers are examples from one lab, and none of them is a threshold to copy.

## Build a blind corpus

Only blind scores gate a decision (RML-18).

1. Give labelling to a separate agent or person, not the prompt author.
2. Write a forbidden list into the labeller's brief. It covers the prompt and question text, the decider code, every model output and any existing authored corpus.
3. Restrict the labeller's inputs to domain sources: the game rules, the tuning values, the design notes.
4. Record per case: labeller, date, inputs seen and the instrument epoch at labelling time.
5. Report blind results to the prompt author only as aggregates.
6. Move any case the prompt author sees into a non-gating authored set. That case is burned for good.

In one lab, a blind corpus built this way failed its first neutrality review, passed after a fix, and was re-reviewed across three rounds.

## Recheck blindness per use

Blindness holds relative to one boundary, usually the prompt author against the model (RML-19). It does not carry over to a new tool or a new question set on its own.

- Before each new use, name the boundary and check who has seen which cases.
- Keep case ids out of any record the prompt author reads. In one program the shared execution record named blind case ids in review notes, so later briefs for question authors had to forbid reading that record.
- If a looser rule applies to an advisory tool than to a gated decision, say so in the result. In one program a triage tool's "blind" set was labelled by its prompt author, and a ruling limited the separate-labeller rule to gated decision corpora.

## Score a text-only baseline

A case is weak if a rule that reads only the option wording, ignoring state, gets it right (RML-20).

1. Automate a scanner for wording cues: options that name the answer, verbs that match the cue, telegraphed outcomes.
2. Build a small rule-based picker that reads text only, and score it on the corpus.
3. Check by hand as well. Scanners miss cues that a reviewer finds.

In one lab a scanner missed option wording that named the cue, and a text-only rule scored 5 of 5 on those cases. A reviewer's hand-built text rule later scored 71% against the writer's reported 61%, with chance at 48%. Most of that edge came from domain priors and corpus composition, not guessable labels.

## Never edit after seeing a result

An edit made after seeing output voids the result it touched (RML-21). That holds even when the edit is correct.

- Prompt or question changes made after a probe: re-score from a frozen cache with zero new calls, or run a fresh blind pass.
- Relabels by the prompt author after seeing output: discard them. In one lab an adversarial case was relabelled in the same commit that changed the prompt, and a score of 3 of 4 became 4 of 4.
- Cases added after seeing their result: disclose the selection, or name the cases before measuring. In one program a timing report added a measured case after seeing its simulated result.

## Check the baseline before comparing

A comparison against a broken baseline measures the baseline (RML-22).

- Give a scripted baseline memory and a stop condition. In one lab a scripted rule ladder kept attacking a threat the world never removed and scored 0 of 20, below random.
- When the defect is in what the world reports, fix the world-state export, not the baseline's rule, and apply the fix to every arm alike. Hide a threat from the exported state only when the mechanic actually removes it: dead, freed or otherwise out of play. A foe that survives a hit stays a threat, and the export rule is an instrument decision made per mechanic before the first batch (RML-44). In one lab a hide-after-hit rule, reused where foes survive a hit, confounded two of three scenarios in one port.
- Public reports agree that scripted baselines matter: one public project's model tied a hand-coded heuristic, and one public article says a scripted bot would beat the model at its game. Both are unaudited.

Compare arms on paired trials (RML-23). Give trial *i* the same seeded start on every arm. Without pairing, a deterministic arm's twenty trials are one trial repeated twenty times.
