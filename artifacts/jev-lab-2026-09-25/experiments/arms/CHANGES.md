# JL-28 change record

Append-only. This file is outside the pinned set, so adding a row does not change any pin. A change to a pinned file (`design.json`, `analyze.mjs`, `run.mjs`) also needs its new sha256 in PREREGISTRATION.md and a fresh review before Phase B. Never edit or delete a row; correct one by appending another.

| UTC time | Change | Requested by | Reason | Before any counted batch? |
| --- | --- | --- | --- | --- |
| 2026-09-26T00:50Z | Pre-registration, design, runner and analysis written and pinned (JL-28-A1, Phase A) | Coordinator packet for JL-28-A1 | Card revision 3; JL-21b review "JL-28 pre-registration recommendation" | yes |
| 2026-09-26T01:20Z | Applied Fable review a0578b45 as ruled by the coordinator: B1 (n 80, seeds 2000-2079, on cb-bench-one-kinematic and sd-mid-climb-kinematic; power table from a fresh `analyze.mjs --prior`), N1 (paired Newcombe method 10 continuity term, p. 2640; self-test anchor (1,10,0,9)), N2 (run-block count includes not-paired confirmatory and INVALID cells), N3 (analysis applies failed after-run preconditions per sketch), N4 (load average, CPU count and concurrency in provenance), N6 (analysis rerun permitted; nonzero exit when the analysis child dies by signal), N7 (winner's curse sentence), N8 (unpaired Newcombe over the shared seeds), DoD 2 Try lines name launch command and mode. Pins refreshed. | Coordinator, on review a0578b45 | Review CHANGES REQUIRED on 53aad54 | yes |
