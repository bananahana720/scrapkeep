# SC-05 assignment A2 (changes requested, card revision 2)

GOAL: Revise SC-05 to satisfy card revision 2 (below): identify the F-04 objective path through which levels reach events and secret rooms, and remove the stale revision-1 and pending-amendment framing, leaving every passed item intact.

SCOPE: /home/andrew/Projects/scrapkeep-wt-SC-05, branch wt/SC-05, building on your A1 candidate ac3163d44c55337e5975d651f267aeebb7af7c45 (base 56e579a078e80e8cd4ba4298553b8b8942357109). Exclusive lease SC-05-L2, attempt SC-05-A2, the second of at most three attempts. Permitted files unchanged: docs/tech/schemas/SC-05.md; artifacts/local/tasks/SC-05/ (ignored), including your paper check.

CONTEXT: Review R1 (scrapkeep-reviewer-medium, claude-opus-5 high) returned FAIL against proposed card revision 2: artifacts/handoff-8-2026-09-16/tasks/SC-05/review-R1.md in the main checkout /home/andrew/Projects/scrapkeep. Your amendment request is accepted as AM-H8-004 option 1 (artifacts/handoff-8-2026-09-16/amendments/AM-H8-004/request.md): event and secret-room types are F-04 objective definitions owned by SC-04 (TH-06 UN-05 line 119); card revision 2 removes events and secrets and, per review note N1, keeps exits. Revision 2 enters BACKLOG with FR-07's definition import before admission. Other accepted, unapplied amendments: AM-H8-002 (HF-06b line 114 names no level or encounter id; cite it as settled), AM-H8-003 (kit actions reference abilities). SC-04 is admitted at docs/tech/schemas/SC-04.md (F-04 types including ObjectiveDefinition T7); you may now cite its bytes and hash. Items 2, 3 and 4, the row allocation, the save table and the traces passed and must not regress.

REQUIRED CHANGES:
1. B1 (blocking). Add a foreign-reference row for the F-04 objective definitions (SC-04 T7; TH-06 UN-05 line 119; AM-H8-004) and state the exact path from a level to an event or secret room: through the F-04 encounter a level-module slot references (citing SC-04's encounter-to-objective reference), or through a named T2 field. Make DG-20 and the slot kinds consistent with that path. Leave objective types with Q-P38.
2. B2 (blocking). Cite card revision 2 and AM-H8-004 (the tracked path above) at line 5 and wherever the withheld or pending framing appears (lines 94 to 98, SP-29, SP-30, Seam 1, Unresolved questions, Procedure performed); replace 'Withheld' with the settled ownership statement; convert SP-29 and SP-30 to out-of-family pointers or remove them; update paper-check A9 and its control so it passes from the main checkout.
3. N2. Cite AM-H8-002 as settled at Seam 4 and line 637.
4. N3. Restate DG-24's undecodable-key hold as a TH-20 and TH-22 seam, consistent with TH-14 GV-07 line 125 and WR.5.
5. N4. Label DG-14's acyclic exit graph and line 264's no-requirement rule as this contract's choices with revision triggers under SP-10 and Q-P38, or narrow them to what BIBLE line 177 and TH-11 state.
6. N5. State Seam 2's cue-region direction as a direction choice against HF-06a N-002 line 75 for TH-20, and correct the FR-05 reference.
7. N6 and N7. Make the T3 illustrative record's finale_rule satisfy its own DG-18 structure (still illustrative and refused by admission) and add T3 to trace TA; make the slot stub kind consistent with DG-20.
8. Paper check. Replace the json identity round trip with a field-and-reference preservation check against the declared field tables; add an assertion that the F-04 objective foreign reference and its path exist; add a negative control removing it.

VERIFY: In the worktree: npm run check:scope -- 56e579a078e80e8cd4ba4298553b8b8942357109 <candidate> --no-build; npm run check:docs; npm run check:project; node scripts/check-drift.mjs --sections docs/tech/schemas; npm run check:drift; the revised paper check with --out under artifacts/local/tasks/SC-05/. Record exit codes and counts.

TIMEBOX: Checkpoint at handoff. Target 40 minutes.

FORBIDDEN: As A1: only the permitted files; no Resource, roster, count or value; no answer to Q-P12, Q-P23, Q-P25, Q-P38 or Q-P22; no builds, no native execution, no push, no rebase, no touching main. If a change needs an admitted row altered, stop and submit an amendment request under artifacts/local/tasks/SC-05/.

REPORT: Commit only the permitted file on your branch and leave the tracked worktree clean. Report the new candidate SHA, file sha256, each required change item by item with line references, commands with exit codes, paper-check counts, CLAUDE_EFFORT, deviations, and state that you have stopped.

## Exact card (revision 2, proposed)

### SC-05: Specify world and level definitions

**Card revision:** 2 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/TH-11-runs-regions-exits-and-saves.md` from [TH-11](#th-11) (must be admitted before assignment)
- `docs/tech/sections/TH-14-randomness-generation.md` from [TH-14](#th-14) (must be admitted before assignment)
- [BIBLE.md § 3. Maps & Areas](BIBLE.md#3-maps--areas) (regions, areas, level modules, routes, exits and generation constraints; events and secret rooms are F-04 objective definitions owned by SC-04 per TH-06 UN-05 and AM-H8-004)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06a](#hf-06a), [TH-11](#th-11), [TH-14](#th-14). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-05.md`; `artifacts/local/tasks/SC-05/`.

**Definition of done:**

1. Cover only regions, areas, level modules, routes, exits and generation constraints; identify its HF-06 matrix rows and referenced foreign definitions, including the F-04 objective definitions through which levels reach events and secret rooms.
2. For each type specify fields, types, identity/version rules, references, validation diagnostics and one labeled illustrative authored record.
3. Document the mutable save projection or explicit immutable/transient exclusion, with paper roundtrip expectations and an executable qualification obligation.
4. Keep unchosen content and numeric values symbolic and linked to question IDs; examples must not become production canon.

**Verification and evidence:**

- Compare covered matrix rows to the family scope with no orphan type; trace valid, missing-reference and invalid-record cases through admission.
- Review illustrative encode/decode for field and reference preservation. This is schema documentation, not an executed codec.

**Boundary:** One schema-family draft only. No Resources, game code, runtime content or production assets are created.

