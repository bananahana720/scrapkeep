# Pre-registration: decide the reading before the run

Use a pre-registration for any live run whose result will change a decision: park a method, trust an epoch, pick a design. It fixes the question, the pass rules and the readings before any call, so the result cannot shape its own interpretation. Lesson ids point at [the lesson ledger](lessons.md).

The pattern comes from one lab's 216-call pre-registered run: six designs, every order, three repeats per order, a reviewer's approval before any call, and no failed calls (RML-24). It is one run. The procedure is the part to copy.

## Procedure

### Phase A: prepare without live calls

1. Write the pre-registration from the template below.
2. Build the states, questions, design file and runner.
3. Dry-run the runner against a stub decider. Check that it covers every cell, order and repeat, and that it writes the records the readings need. Record the result in the template's stub dry-run slot.
4. Compute the SHA-256 of every input file and write the hashes into the pre-registration.
5. Make the runner refuse to start its live mode unless every hash matches.
6. Get an independent reviewer's approval of the pre-registration. Record who approved it and when.
7. Log any change to the plan in the change record, with who asked and why, before the first live call.

### Phase B: run once

1. Capture provenance: commit, tree state (clean or dirty, with the list of changed paths), and the hash of the pre-registration file.
2. Start the live run. It runs once and changes nothing in the pre-registration.
3. Treat a crash mid-run as blocked. Do not resume, and do not rerun into the same result.
4. Capture provenance again after the run.
5. Report which readings fired, with their numbers. Add no rows (RML-25).
6. Report every other observation under a separate heading that says it was not pre-registered (RML-25). In one run a position-direction flip was reported that way.

## Template

```markdown
# Pre-registration: <experiment name>

Status: draft | approved by <reviewer> at <UTC time> | run at <UTC time> | reported
Author: <name or role>   Approver: <independent reviewer>

## Question
<One question this run answers.>

## Decision each outcome drives
| Outcome | Decision |
| --- | --- |
| <outcome> | <what happens next> |

## Instrument
Resolved model: <as the provider reports it>
Question-set hash: <sha256>
Thresholds and gate version: <values>

## Designs
| Cell | What it isolates | Options | Counts toward the verdict? |
| --- | --- | --- | --- |

## Orders and repeats
<Every permutation of the options; <n> repeats per order; <total> calls.>

## Controls in the run
<Dominance, lethal, wording swap, and any others; their pass conditions.>

## Lines and definitions
Noise line: <formula, computed from this run>
Margin rule: <for per-option ratings, if used>
Pass rule: <per cell; every order must pass on its own>

## Readings
| Reading | Fires when | Consequence |
| --- | --- | --- |

## Stub dry-run result
Date: <UTC time>   Stub: <what the stub returns and why>
Coverage: <cells, orders and repeats run, out of the planned total>
Records written: <yes or no; which fields the readings need were present>
Problems found and fixed before pinning: <list, or none>

## Pinned inputs
| File | SHA-256 |
| --- | --- |

## Call budget
Cap: <n calls>   Expected: <n calls>   Counted before send, failures included.

## Provenance to capture
Before and after: commit, tree state, changed paths, pre-registration hash.

## Change record
| UTC time | Change | Requested by | Reason | Before any live call? |
| --- | --- | --- | --- | --- |

## Stop rules
A crash counts as blocked. No reruns. No rows added to Readings after the run.
```

## Tag every claim

Tag each number in the report verified, unverified-computed or retracted (V/U/R) (RML-27):

| Tag | Meaning |
| --- | --- |
| V | Verified: measured, with the retained artifact cited. |
| U | Unverified-computed: computed or estimated, however consistent it looks. |
| R | Retracted: kept in place, with the correction that replaced it. |

A computed number presented as a measurement is the failure to watch for. In one program an audit retagged arithmetic figures, such as eight times a per-boot estimate, as unverified-computed. Two later reviews failed timing reports whose seconds were simulated or stamped after the operation ran.

## Retract by appending

Never edit a published claim (RML-26). Append a correction that names the wrong value, the right value and the evidence. In one program one compensating entry retracted numeric claims finding by finding. Another listed each wrong timestamp beside its real one.

## Prove which code produced the evidence

Record the tree state as well as the commit (RML-41). A commit on a dirty tree does not say which code ran.

When the system has a deterministic mode, a hash re-run can serve as a cheap proof (RML-46). Re-run one batch at the clean commit and compare trace hashes. In one lab a clean-commit re-run matched the dirty-tree batch hash for hash, 20 of 20, without repeating the full batch set. That is one instance.

A matching hash proves something only if the hash can move. Before relying on hash equality, run a sensitivity control (RML-45). Perturb one answer, or the snapshot and apply schedule, and confirm that the trace hash changes while every event before the perturbation stays byte-identical. In one lab such a test showed the hash was neither always equal nor blind to order.

## Route review by the kind of claim

Send recomputation from raw artifacts and instrument-validity questions to the strongest review tier (RML-42). In one program the deepest catches came only from the consequential audit: a headline contradicted by its own artifact, a control that existed only in prose, and a score that depended on a relabel. Routine reviews caught contract and mechanical defects.
