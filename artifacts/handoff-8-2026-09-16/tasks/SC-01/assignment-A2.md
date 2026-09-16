# SC-01 assignment A2 (changes requested after FR-07)

GOAL: Revise SC-01 revision 1 against the repaired matrix so every type carries the HF-06a rows whose rationale names it, fixing review R1's B1 and notes, leaving every passed item intact.

SCOPE: /home/andrew/Projects/scrapkeep-wt-SC-01-A2, branch wt/SC-01-A2, verified base 43a8f12ad64b63a7352adb6cefab9f111a1cb5e8 (main after FR-07's admission), carrying your A1 contract forward: start by restoring docs/tech/schemas/SC-01.md from your A1 candidate with `git show 46c5c199ad1bb00d0d7f117e5316aa47ecf43df8:docs/tech/schemas/SC-01.md > docs/tech/schemas/SC-01.md`. Exclusive lease SC-01-L2, attempt SC-01-A2, the second of at most three attempts. Permitted files: docs/tech/schemas/SC-01.md (new at this base); artifacts/local/tasks/SC-01/ (ignored, receipts), including your paper check (copy it from /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-01/coordinator-candidate/check_contract.py). The schema index docs/tech/schemas/README.md is coordinator-owned; propose its line.

CONTEXT: Review R1 FAIL: artifacts/handoff-8-2026-09-16/tasks/SC-01/review-R1.md in the main checkout. FR-07 (admitted 93989a43aa93f3c3c8d964646141f95df297ce21) applied AM-H8-001 to AM-H8-004: HF-06a N-024 now types both slot and slot-tree definitions (so T3 slot and T4 slot tree both carry N-024 with F-03 as the rationale names them); HF-07a line 127's slot_id source cell names N-024; kit weapon, main hero skill, mobility and ultimate actions reference N-021 ability definitions by expected family `ability` (F-01, N-007 to N-011, N-019), so SC-01's class-kit references target `ability`, not `attack`; a respec opportunity is an F-04 objective (SC-04) under Q-P18. Admitted sibling contracts you may now cite by link and hash: docs/tech/schemas/SC-03.md, SC-04.md, SC-05.md, SC-06.md, SC-08.md. SC-02 (attacks, chaos outcomes, abilities) is concurrent and unadmitted; state its seam without citing bytes. Row allocation rule (EV-0407 onward): every type carries the HF-06a rows whose rationale text names it, in Markdown and CSV; no type lacks a row; no row re-treated (HF-06a lines 22, 46); one family row may cover several types. Drift over docs/tech/schemas is `node scripts/check-drift.mjs --sections docs/tech/schemas`. Engine facts only from Context7 (/websites/godotengine_en_4_7).

REQUIRED CHANGES:
1. B1 (blocking). Re-allocate rows by the repaired rationales: cite N-024 for the slot type and the slot-tree type as its reworded rationale names them, split the save fields between F-03 and N-024 only as HF-06b and HF-07a now credit them, and turn Seam 1 into a plain citation of FR-07.
2. AM-H8-003. Kit slot references name expected family `ability` (N-021) and never `attack`; an attack reaches a kit only through an ability.
3. R1 notes 2 to 7: the negative-control count; the evidence-limits wording about the hand-coded rule model; label SA-23 kit_order and SP-12 and SP-13 as this contract's choices; SV-02 cites HF-09 G11 line 177; AM lists the HF-05 required fields; SI-02's reach over example references.
4. Replace the seams that described AM-H8-001 and AM-H8-003 as pending with citations of the admitted rows.
5. Paper check: add a comparison of each type's rows with the nouns in each row's rationale (Markdown and CSV) and an assertion that no kit reference expects family `attack`; replace any identity round trip with a field-and-reference preservation check against the declared field tables; keep and extend negative controls.

VERIFY: npm run check:scope -- 43a8f12ad64b63a7352adb6cefab9f111a1cb5e8 <candidate> --no-build; npm run check:docs; npm run check:project; npm run check:drift; node scripts/check-drift.mjs --sections docs/tech/schemas (zero mismatches, zero unbound); the revised paper check with --out under artifacts/local/tasks/SC-01/. Record exit codes and counts.

TIMEBOX: Checkpoint at handoff. Target 50 minutes.

FORBIDDEN: Only the permitted files; no Resource, script, runtime content, canon, count or value; no answer to Q-P01 to Q-P07, Q-P10, Q-P11 or Q-P18; no builds, no push, no rebase, no touching main. If a change needs an admitted row altered, stop and submit an amendment request under artifacts/local/tasks/SC-01/.

REPORT: Commit only the permitted file on your branch and leave the tracked worktree clean. Report candidate SHA, base, file sha256, each required change with line references, the proposed index line, commands with exit codes, paper-check counts, CLAUDE_EFFORT, deviations, and state that you have stopped.

## Exact card

### SC-01: Specify character and progression definitions

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` from [TH-04](#th-04) (must be admitted before assignment)
- `docs/tech/sections/TH-07-four-slots-and-milestone-progression.md` from [TH-07](#th-07) (must be admitted before assignment)
- [BIBLE.md § 4. Characters](BIBLE.md#4-characters) (characters, class kits, four slots, binary trees and milestone nodes)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06a](#hf-06a), [TH-04](#th-04), [TH-07](#th-07). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-01.md`; `artifacts/local/tasks/SC-01/`.

**Definition of done:**

1. Cover only characters, class kits, four slots, binary trees and milestone nodes; identify its HF-06 matrix rows and referenced foreign definitions.
2. For each type specify fields, types, identity/version rules, references, validation diagnostics and one labeled illustrative authored record.
3. Document the mutable save projection or explicit immutable/transient exclusion, with paper roundtrip expectations and an executable qualification obligation.
4. Keep unchosen content and numeric values symbolic and linked to question IDs; examples must not become production canon.

**Verification and evidence:**

- Compare covered matrix rows to the family scope with no orphan type; trace valid, missing-reference and invalid-record cases through admission.
- Review illustrative encode/decode for field and reference preservation. This is schema documentation, not an executed codec.

**Boundary:** One schema-family draft only. No Resources, game code, runtime content or production assets are created.

