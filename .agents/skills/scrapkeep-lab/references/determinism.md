# Determinism per physics mode

The lab runs each scenario in two physics modes. They reproduce differently, so they are gated differently and support different claims.

## What each mode reproduces

| Mode | Repeat-pair evidence | What a hash change means |
| --- | --- | --- |
| Kinematic | ball-lab 360 of 360 identical (EV-0546); Cable Bench 120 of 120 (EV-0550) | The executed behaviour changed (SKL-08) |
| Rigid (Jolt) | ball-lab about 1 divergent pair in 20, and a divergence flipped `timeout` to `success` on one seed (`artifacts/jev-lab-2026-09-25/reviews/JL-21.md:15`); Cable Bench 120 of 120 in A1, then 119 and 118 of 120 in A2 (EV-0550, EV-0553) | Nothing on its own; rigid divergence is stochastic (SKL-09) |

Ball-lab's only randomness is the unhashed camera jitter. Stage seeds come from `seed_override`, which a port adds so that -1 keeps the stage's hand-picked seeds (`tools/jev-player/protocol/PROTOCOL.md:181`; `artifacts/jev-lab-2026-09-25/reviews/JL-26.md:55-56`).

## How the gate treats each mode

These are the current rules in `scripts/lab/gate.mjs:40-46` (SKL-10):

- **Kinematic.** Exact trace-hash and replay equality against the pin. An exit 1 means the behaviour differs from the pin, not that it got worse (SKL-11).
- **Rigid.** At least 20 trials on each side (`RIGID_MIN_N`), else exit 3. The nondeterminism floor `RIGID_FLOOR` of 0.05 applies to the unreachable-scenario check. No batch rate is compared yet; JL-28 owns that comparison. A rigid pin with 0 successes gives the reachability check nothing to compare (`artifacts/jev-lab-2026-09-25/reviews/JL-25.md:11`).

Until JL-28 lands, report a rigid gate pass as "sample size met; no rate compared", never as "no regression".

## Check a hash oracle before trusting it

A hash that never changes proves nothing. Before relying on a new determinism check (SKL-12):

1. Run the same scenario, seed and D/k twice and confirm the hashes match.
2. Change one input the hash must see: k (for example 54 against 26) or one arm answer.
3. Confirm the hash changes and that every event before the change is byte-identical.

The JL-21 test in `tests/lab-bridge.test.js` does this for a contact scenario.

## Evidence from a dirty tree

Batches that ran on a dirty tree or at a base commit are not evidence for the head being merged (SKL-13). The cheap proof uses kinematic determinism:

1. Commit the change.
2. From the writer's own clean worktree at that head, re-run one kinematic batch that the dirty-tree set contains, with the same scenario, arm, seed and trial count.
3. Compare `trace_hash` trial for trial with the dirty-tree record. A full match shows the executed path is unchanged. Any mismatch means the whole set must be re-run at the head.

Launch from the writer's frozen worktree, never from the coordinator worktree, which moves when other cards merge (SKL-23).

## What a rigid result may claim

- A rigid rate needs n ≥ 20 on each side and a Wilson or Newcombe interval; a single repeat pair proves nothing about determinism.
- A rigid finding that depends on one trial's outcome is an anecdote.
- Rigid and kinematic can disagree on the same scenario. JL-26 found rigid run-up speeds below the chaser's speed in 48% of samples against 11% kinematic; the causal reading is inference (`artifacts/jev-lab-2026-09-25/reviews/JL-26.md:33-37`).
