### HF-04b: Specify runtime patterns and typed sketches

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision) (typed GDScript)
- Godot 4.7 static-typing documentation, resolved by the coordinator and supplied in the packet.
- `docs/tech/sections/HF-04a-runtime-lifecycle.md` from [HF-04a](#hf-04a) (must be admitted before assignment)

**Dependencies:** [HF-04a](#hf-04a). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-04b-runtime-patterns.md`; `artifacts/local/tasks/HF-04b/`.

**Definition of done:**

1. Name the game-loop, state-machine, scoped signal/message and scene-lifecycle patterns and when not to use each. Document time/tick ownership and event ordering under HF-04a.
2. Include a minimal typed GDScript sketch per pattern. Mark every sketch "unparsed: no editor run in this card; re-verify at scaffold proof". Re-verify when S0-04 lands; revision 2 of this card replaces each sketch with a link to the S0-04 source.
3. State for each pattern which HF-03a module may own it.

**Verification and evidence:**

- Confirm each sketch carries the unparsed marker and names its HF-03a owner.
- The reviewer confirms presence and typed form only; no sketch is executed under this card.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

