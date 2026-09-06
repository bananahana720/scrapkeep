### HF-04b: Specify runtime patterns and typed sketches

**Card revision:** 2 · **Owner:** Runtime · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision) (typed GDScript)
- Godot 4.7 static-typing documentation, resolved by the coordinator and supplied in the packet.
- `docs/tech/sections/HF-04a-runtime-lifecycle.md` from [HF-04a](#hf-04a) (must be admitted before assignment)
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (owner map, admitted before assignment)
- [docs/tech/proofs/S0-04-runtime-ownership.md](docs/tech/proofs/S0-04-runtime-ownership.md), particularly Contract, Scenarios, Unresolved questions and Evidence limits
- The seven source scripts under `native/proofs/tadr-002/`, pinned to their admitted source identity
- `artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt` and `S0-04-int-proof-fault.txt`

**Dependencies:** [HF-04a](#hf-04a). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-04b-runtime-patterns.md`; `artifacts/local/tasks/HF-04b/`.

**Definition of done:**

1. Name the game-loop, state-machine, scoped signal/message and scene-lifecycle patterns and when not to use each. Document time/tick ownership and event ordering under HF-04a.
2. For the game-loop, state-machine and scoped signal/message patterns, replace inline sketches with links to the applicable admitted S0-04 source. Link `native/proofs/tadr-002/encounter_coordinator.gd` for the single physics-callback owner, queued command admission and minimal prepared/cast transitions; `session_owner.gd`, `input_adapter.gd` and `menu_probe.gd` for input release, prepared-action cancellation, pause and resume; and `intruder.gd` with `proof_runner.gd` phase B for rejection of a second mutation source. Each example identifies its source commit, the assertion or phase that exercised it, the retained normal and fault-run evidence, and the behavior those assertions establish. State explicitly that these examples do not prove a complete production state machine, positive committed-result signal delivery or scoped connection teardown. Retain a minimal typed scene-lifecycle sketch marked "unparsed: no editor run in this card; scene replacement and scoped teardown await a later authorized proof". Reconcile every example and remaining paper contract against the admitted HF-04a lifecycle contract. Record the S0-04 trigger as satisfied by source and retained-evidence review; no native execution occurs in this card.
3. State for each pattern which HF-03a module may own it.

**Verification and evidence:**

- Confirm each linked source file and retained receipt exists; identify the exact assertion supporting each claimed behavior; inspect proof discovery and the pinned typing configuration without executing them. Check that every remaining inline sketch carries the unparsed marker, every pattern names its HF-03a owner, and no example substitutes a proof default or untested behavior for the admitted HF-04a contract.
- The reviewer confirms presence and typed form only; no sketch is executed under this card.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

