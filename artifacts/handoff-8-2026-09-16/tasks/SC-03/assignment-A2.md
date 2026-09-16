# SC-03 assignment A2 (reopened under AM-H8-005)

GOAL: Revise admitted SC-03 revision 1 so each replacement reference names exactly one expected family after FR-07's revised HF-06a N-016 and N-019, leaving every other admitted item intact.

SCOPE: /home/andrew/Projects/scrapkeep-wt-SC-03-A2, branch wt/SC-03-A2, verified base 43a8f12ad64b63a7352adb6cefab9f111a1cb5e8 (FR-07 admitted at 93989a43aa93f3c3c8d964646141f95df297ce21). Exclusive lease SC-03-L2, attempt SC-03-A2. Permitted files: docs/tech/schemas/SC-03.md (edit in place); artifacts/local/tasks/SC-03/ (ignored), including a copy of the retained paper check /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-03/coordinator-candidate/check_sc03.py which you extend. Writer scrapkeep-writer (claude-opus-5 high; report CLAUDE_EFFORT).

CONTEXT: Amendment AM-H8-005 (artifacts/handoff-8-2026-09-16/amendments/AM-H8-005/request.md) records the contradiction: SC-03 lines 58, 85, 86 and 384 treat mobility actions and all replacements as F-02, while revised HF-06a N-016 (line 89) sends replacing a mobility action to an N-021 ability reference and replacing an attack to an F-02 attack reference, and N-019 (line 92) makes mobility actions kit actions referencing N-021 abilities. HF-05 lines 22 and 108 give each reference one expected family; the coordinator's single-field alignment failed the retained check C07 and was reverted (TRACKING EV-0437). SC-03's original review R1 (artifacts/handoff-8-2026-09-16/tasks/SC-03/review-R1.md) passed with notes you may also fix where they touch the same lines (note 5 on HF-06a line 67 versus 92 and 66). Admitted sibling contracts: SC-04, SC-05, SC-06, SC-08 (cite by link and hash if you reference them); SC-01 and SC-02 are being revised concurrently (state seams without bytes; SC-02 owns ability and attack definitions). Row allocation rule: every type carries the HF-06a rows whose rationale names it; no row re-treated. Engine facts only from Context7 (/websites/godotengine_en_4_7).

REQUIRED CHANGES:
1. Model attack replacement and mobility-action replacement so every reference names exactly one expected family: for example separate replacement records or fields for an attack (F-02) and for a mobility action (N-021 ability), with an exactly-one structural rule and matching diagnostics mapped to HF-05 gates and edges. Keep every save field, projection and treatment unchanged; if a save field would change, stop and submit an amendment request.
2. Add N-021 to the foreign-reference table with its producing card and direction; correct line 58 and Seam 2 (line 384) to the revised N-016 and N-019; update the illustrative ItemDefinition record and any trace that shows a replacement.
3. Record the revision in Procedure performed, citing AM-H8-005 and FR-07.
4. Paper check: extend check_sc03.py so C07 accepts the new single-family references, assert that no replacement reference names two families and that a mobility replacement targets N-021 and an attack replacement F-02, and add negative controls restoring the old F-02-only mobility replacement and a two-family field.

VERIFY: npm run check:scope -- 43a8f12ad64b63a7352adb6cefab9f111a1cb5e8 <candidate> --no-build; npm run check:docs; npm run check:project; npm run check:drift; node scripts/check-drift.mjs --sections docs/tech/schemas (zero mismatches; SC-08 states SC-03's hash, so report the new SC-03 sha256 and leave SC-08 to the coordinator's fixpoint at integration); the extended paper check with --out under artifacts/local/tasks/SC-03/. Record exit codes and counts.

TIMEBOX: Checkpoint at handoff. Target 40 minutes.

FORBIDDEN: Only the permitted files; no edit to SC-08 or any other file; no save, row or treatment change; no answer to Q-P07, Q-P10, Q-P14, Q-P15 or Q-P37; no builds, no push, no rebase, no touching main.

REPORT: Commit only SC-03.md on your branch and leave the tracked worktree clean. Report candidate SHA, base, file sha256, each required change with line references, commands with exit codes, paper-check counts, CLAUDE_EFFORT, deviations, and state that you have stopped.

## Exact card

### SC-03: Specify item and recipe definitions

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/TH-08-inventory-equipment-and-transformations.md` from [TH-08](#th-08) (must be admitted before assignment)
- `docs/tech/sections/TH-09-themed-loot-attunement-and-fixed-secrets.md` from [TH-09](#th-09) (must be admitted before assignment)
- [BIBLE.md § 5. Weapons & Items](BIBLE.md#5-weapons--items) (items, equipment, modifiers, transformations, attunement and fixed recipes)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06a](#hf-06a), [TH-08](#th-08), [TH-09](#th-09). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-03.md`; `artifacts/local/tasks/SC-03/`.

**Definition of done:**

1. Cover only items, equipment, modifiers, transformations, attunement and fixed recipes; identify its HF-06 matrix rows and referenced foreign definitions.
2. For each type specify fields, types, identity/version rules, references, validation diagnostics and one labeled illustrative authored record.
3. Document the mutable save projection or explicit immutable/transient exclusion, with paper roundtrip expectations and an executable qualification obligation.
4. Keep unchosen content and numeric values symbolic and linked to question IDs; examples must not become production canon.

**Verification and evidence:**

- Compare covered matrix rows to the family scope with no orphan type; trace valid, missing-reference and invalid-record cases through admission.
- Review illustrative encode/decode for field and reference preservation. This is schema documentation, not an executed codec.

**Boundary:** One schema-family draft only. No Resources, game code, runtime content or production assets are created.

