# SC-02 assignment A2 (changes requested after FR-07)

GOAL: Revise SC-02 revision 1 against the repaired matrix so its ability-first kit reference is a plain citation of the admitted rows, fixing review R1's B1 and notes, leaving every passed item intact.

SCOPE: /home/andrew/Projects/scrapkeep-wt-SC-02-A2, branch wt/SC-02-A2, verified base 43a8f12ad64b63a7352adb6cefab9f111a1cb5e8 (main after FR-07's admission), carrying your A1 contract forward: start by restoring docs/tech/schemas/SC-02.md from your A1 candidate with `git show 07bef9da9bf72b1831307811bba177646d004f3c:docs/tech/schemas/SC-02.md > docs/tech/schemas/SC-02.md`. Exclusive lease SC-02-L2, attempt SC-02-A2, the second of at most three attempts. Permitted files: docs/tech/schemas/SC-02.md (new at this base); artifacts/local/tasks/SC-02/ (ignored), including your paper check (copy it from /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-02/coordinator-candidate/check_sc02.py). The schema index is coordinator-owned; propose its line.

CONTEXT: Review R1 FAIL: artifacts/handoff-8-2026-09-16/tasks/SC-02/review-R1.md. Andrew chose ability-first (TRACKING EV-0411, AM-H8-003), and FR-07 (admitted 93989a43aa93f3c3c8d964646141f95df297ce21) applied it: HF-06a F-01, N-007 to N-011 and N-019 route kit weapon, main hero skill, mobility and ultimate actions to N-021 ability definitions of expected family `ability`; N-021 references the F-02 attacks it produces and a mobility action may produce none; N-013 separates a slot action's visual reference from an attack's; N-016 separates replacing a mobility action from replacing an attack; HF-06b N-009 keeps planted-limb attacks F-02 within an ability. Admitted sibling contracts you may cite by link and hash: SC-03, SC-04, SC-05, SC-06, SC-08 under docs/tech/schemas. SC-01 (characters and kits) is concurrent and unadmitted; state its seam without bytes. Row allocation rule: every type carries the HF-06a rows whose rationale names it, in Markdown and CSV; no row re-treated (HF-06a lines 22, 46). Drift over docs/tech/schemas via `node scripts/check-drift.mjs --sections docs/tech/schemas`. Engine facts only from Context7 (/websites/godotengine_en_4_7).

REQUIRED CHANGES:
1. B1 (blocking). Seam 1, FR-03 and the `commits` field cite the revised F-01, N-007 to N-011, N-019 and N-021 rows as admitted; FR-11 now restates N-019 as an ability, not AttackDefinition; remove the TH-20 routing at line 569 for this question.
2. R1 notes: name both failing rules (or which reports first) in the AI trace; list the HF-05 required fields in AM.3 and AI.2; state that N-020's 'restates' is not a second mapping; state how SC02-M04's unset gate is carried (a card revision supplying the value); add TH-16 line 279 (RP-17) to SP-31; one sentence tying slot_role and charge to N-021's availability phrase.
3. Re-cite admitted SC-03, SC-04 and SC-06 where your foreign-reference table names their rows, and align with SC-06's rule that command capabilities may reference F-02 attacks by id.
4. Paper check: read sibling rows that point into this family (F-01, N-007 to N-011, N-013, N-016, N-019) and assert their expected families agree with your types; replace the trivial codec with a field-and-reference preservation check against the declared field tables; add a negative control restoring a kit-to-attack reference.

VERIFY: npm run check:scope -- 43a8f12ad64b63a7352adb6cefab9f111a1cb5e8 <candidate> --no-build; npm run check:docs; npm run check:project; npm run check:drift; node scripts/check-drift.mjs --sections docs/tech/schemas (zero mismatches, zero unbound); the revised paper check with --out under artifacts/local/tasks/SC-02/. Record exit codes and counts.

TIMEBOX: Checkpoint at handoff. Target 50 minutes.

FORBIDDEN: Only the permitted files; no Resource, script, runtime content, canon, count or value; no answer to Q-P13, Q-E10, Q-P41, Q-P32 or Q-E03; no builds, no push, no rebase, no touching main. If a change needs an admitted row altered, stop and submit an amendment request under artifacts/local/tasks/SC-02/.

REPORT: Commit only the permitted file on your branch and leave the tracked worktree clean. Report candidate SHA, base, file sha256, each required change with line references, the proposed index line, commands with exit codes, paper-check counts, CLAUDE_EFFORT, deviations, and state that you have stopped.

## Exact card

### SC-02: Specify attack and effect definitions

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` from [TH-03](#th-03) (must be admitted before assignment)
- `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` from [TH-04](#th-04) (must be admitted before assignment)
- `docs/tech/sections/TH-13-chaos-outcomes.md` from [TH-13](#th-13) (must be admitted before assignment)
- [BIBLE.md § A committed attack means what it shows](BIBLE.md#a-committed-attack-means-what-it-shows) (committed attacks, hit geometry, telegraphs, abilities, ultimates and chaos outcomes)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06a](#hf-06a), [TH-03](#th-03), [TH-04](#th-04), [TH-13](#th-13). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-02.md`; `artifacts/local/tasks/SC-02/`.

**Definition of done:**

1. Cover only committed attacks, hit geometry, telegraphs, abilities, ultimates and chaos outcomes; identify its HF-06 matrix rows and referenced foreign definitions.
2. For each type specify fields, types, identity/version rules, references, validation diagnostics and one labeled illustrative authored record.
3. Document the mutable save projection or explicit immutable/transient exclusion, with paper roundtrip expectations and an executable qualification obligation.
4. Keep unchosen content and numeric values symbolic and linked to question IDs; examples must not become production canon.

**Verification and evidence:**

- Compare covered matrix rows to the family scope with no orphan type; trace valid, missing-reference and invalid-record cases through admission.
- Review illustrative encode/decode for field and reference preservation. This is schema documentation, not an executed codec.

**Boundary:** One schema-family draft only. No Resources, game code, runtime content or production assets are created.

