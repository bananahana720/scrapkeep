# DRAFT-ASSETS review R2

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition). Final report retained verbatim.

# DRAFT-ASSETS review R2 (revision A2)

**Verdict: FAIL.** I found one narrow blocking finding; everything else is a note. The A2 revision fixes R1's five blocking findings and encodes all four EV-0423 decisions. The citations I sampled hold up. But two of the concept cards meant for the next sprint can't be admitted as drafted.

**Evidence level:** static review of the admitted staging drafts at main `429c487`, checked against their sources. Every exit code and pass count below is **coordinator-supplied**. I ran no commands.

**Runtime:** the system context reports Opus 5 (`claude-opus-5[1m]`). `CLAUDE_EFFORT` is unavailable: I have no shell and the value isn't shown anywhere I can read. A model can't confirm its own identity by describing itself. **I wrote, edited and committed nothing.**

**Coordinator receipts relied on:**
- `coordinator-check-A2/exits.txt:1-5`: check-drafts, check-docs, check-project, check-drift and check-drift-schemas all exited 0.
- `coordinator-check-A2/check-drafts.log:1,22`: PASS on 36 cards, and all 20 negative controls were detected.
- The packet says "35 draft production cards" (`review-packet-R2.md:3`), but A2 has 36 (the log above; TRACKING EV-0433).

## R1 blocking findings and EV-0423 decisions

| Item | State | Evidence |
| --- | --- | --- |
| B1 missing dependencies | Resolved | ART-08 now depends on ART-06 (`asset-production-cards.md:292`), ART-11 on ART-09 (`:376`), ART-14 on ART-18 (`:464`). The rationale map now runs ART-17 (step 16), ART-18 (17), ART-14 (18) (`asset-production-rationale.md:36-38`). |
| B2 NQ-02 could never be admitted | Resolved | Merged into NQ-01 (`cards:24`). Its item 4 (`:46`) follows TH-19 RR-09, which says "Order and modes, on one candidate … Only the passing candidate is integrated" (`TH-19:212`). |
| B3 effects wrote runtime inputs early | Resolved | ART-15 and ART-16 write only `source-assets/fuse/effects/**` (`cards:496, 525, 535`). ART-19 writes `native/` after NQ-01 and IG-01 to IG-07 (`:610-616`). |
| B4 ART-23 bundled two outcomes | Resolved | Split into ART-23 rig (`:709-732`) and ART-29 clips (`:734-758`). Proposed Q-P42 blocks both (`:1058-1070`). Q-P41 is the last register entry in BACKLOG (`BACKLOG.md:3356`), so Q-P42 is the next free ID. |
| B5 authority and growth state | Resolved | Every native-stage card carries the named gate (I read them all; the checker's missing-native-gate control also covers this). Q-P26 now blocks ART-03 (`cards:139`). The rationale now says the coordinator cannot expand scope (`rationale:3, 122`), matching `ORCHESTRATOR.md:21, 32`. |
| EV-0423 decision 1 (concept first, final assets after Q-E01) | Encoded | `cards:10-11`; each card's Lane and gate line |
| Decision 2 (starting mech; separate clearance card) | Encoded | `cards:84, 145, 243`; ART-26 no longer measures clearance (`:833`); new NQ-03 (`:889-914`) |
| Decision 3 (image prompts plus paintover) | Encoded | `cards:82, 649, 808` |
| Decision 4 (provisional camera distance) | Encoded | ART-04 (`:163, 176`), ART-18's native recheck (`:592`), ART-21 does not extend it (`:667`). The distance expression is at `src/orchard/scene.js:410`. |

## Blocking finding

**F1. ART-20 and ART-25 can't be admitted because their permitted files are placeholders that only resolve after the cards have run.**
- **Requirement:** `ORCHESTRATOR.md:41` requires exact permitted files.
- **The paths:** ART-20 writes `docs/art/production/<enemy_unit>/**` (`cards:642`) and ART-25 writes `docs/art/production/<orchard_modules_unit>/**` (`:800`).
- **Why they can't resolve:** under DQ-13 (`rationale:140`) and `cards:15`, those names are set only "after Q-P25 and Q-P26 answers". But ART-20 exists to support Andrew's Q-P25 choice (`:640`), and ART-25 shapes Q-P26 (`:798`). Neither has a blocking question, and the rationale offers both for the next sprint (`rationale:78`). Each card waits on an answer that depends on the card itself.
- **Fix:** give each card a concrete path grouping, for example `docs/art/production/iron_orchard_enemies/**` and `docs/art/production/iron_orchard_modules/**`. HF-01 line 21 allows this because a unit name is "a path grouping, never a durable gameplay ID". Keep the placeholders for the cards that come after Q-P25 or Q-P26, and amend DQ-13 to match.

## Packet items 1 to 3: readiness, atomicity and scope

**Item 1, readiness.** Apart from F1, every card has one owner role (the "X with Y" form has precedent at `BACKLOG.md:3775`), S or M size, permitted files, a definition of done and verification with limits and human-hands steps.

**Item 2, dependency order.** Traced by hand, the maps match the cards' Dependencies fields. I found no cycle; the coordinator receipt's cycle control agrees. Merging NQ-01 matches RR-09's "on one candidate", which resolves the old NQ-01-before-NQ-02 question. Gaps are notes N1 and N2.

**Item 3, scope fidelity.**
- I found no invented count, budget, polycount, bone count, texture size, loudness or frame rate. "three synthetic importable inputs" comes from `TH-19:220`, and "4.7.2" from `BACKLOG.md:9`.
- Construction C and its carried risks are honoured (`cards:113-115, 299, 382-383`), as is AM-H8-003 (`:440, 590, 940`).
- Nothing authorizes production before Q-E01. Rough blockouts before the native slice are explicitly Andrew's decision 1 (TRACKING EV-0423, `TRACKING.md:638`).

## Non-blocking notes

1. **NQ-03's collision dependency is prose only** (`cards:900, 902`). "The module collision card DQ-05 disposes" has no definition or anchor, so neither the Dependencies field nor the checker can hold it. Fix: define or register that card at import, or leave NQ-03 out until it exists.
2. **NQ-03 reuses a fixture whose expected result is the opposite of its pass rule.**
   - PX-09's expected observation is that the larger extent is *stopped* by the passage (`TH-15:203`). PX-10 tests when an install happens, not whether a passage is clear (`:204`).
   - NQ-03 items 1 and 2 (`cards:908-909`) apply the opposite rule: the ordinary maximum extent must pass.
   - Fix: say NQ-03 uses PX-09's two-extent setup with its own pass rule, and drop PX-10 or explain why it applies.
3. **Blockouts conflict with Q-P26 as it stands.**
   - Q-P26 closes only with "target budget source" (`BACKLOG.md:3170`), and EV-0372 leaves the measured budget open until a native slice exists (`TRACKING.md:587`).
   - So ART-03, ART-21 and ART-26, and through ART-03 also ART-04 and ART-05, can't run before the slice unless Andrew closes Q-P26 in part.
   - The rationale's "no blocking question" list (`rationale:78`) hides that ART-04 and ART-05 still wait on ART-03. The real Q-P26-free set is ART-01, ART-02, ART-20 and ART-25.
4. **Two import cards' write sets overlap SND-05's audio paths.**
   - ART-18 excludes only `effects/` from `native/content/fuse/assets/**` (`cards:584`), so its set includes SND-05's `native/content/fuse/assets/audio/**` (`:1041`). No dependency orders the two.
   - ART-24 (`:772`) overlaps SND-05's `<enemy_unit>` audio path the same way.
   - ART-07 and ART-08 both lease `source-assets/fuse/provenance/**` (`:266, 294`), so they can't run in parallel.
   - Fix: exclude `audio/` from ART-18 and ART-24, and use per-card provenance paths.
5. **DQ-01's amendment wording would break HF-01's disjoint rows.** DQ-01 (`rationale:128`) gives existing rows a second owner by content type, but HF-01 line 19 says "Rows are disjoint". Carve out separate path rows instead: `source-assets/*/audio/**` and `native/content/*/assets/audio/**`.
6. **Q-E03 is applied unevenly.**
   - DQ-07 says every such card blocks on Q-E03 (`rationale:134`), and the register says Q-E03 bounds rigs and effects (`:95`).
   - ART-09 and ART-23 block on it (`cards:319, 720`); ART-10, ART-11, ART-12, ART-15 and ART-16 do not (`:348, 376, 404, 494, 523`).
   - ART-10 and ART-11 bound their bone lists by "the Q-P26 answer" only (`:356, 385`).
7. **ART-06's growth-state record is incomplete.** Item 3 (`cards:243`) should name the capability-set selection the starting mech derives from, which PD-01 PE-03 requires (`PD-01:69`; `TH-16:153`).
8. **SND-01 to SND-04 write `source-assets/**` without blocking on Q-P26.** That departs from A2 required change 5 (`DRAFT-ASSETS-assignment-A2.md:14`). It's defensible because Q-P26's affected work leaves out audio (`BACKLOG.md:3168`) and Q-P31 gates sound. Record the deviation.
9. **ART-01 doesn't say which image generator is allowed or how its output terms become PF-05 license evidence** (`cards:82`; `HF-01:72`; `ASSETS.md:17`).
10. **The rationale's card states are stale at import** (`rationale:7`).
    - It says "FR-07 is ready"; TRACKING now shows it in_progress (`TRACKING.md:152`).
    - It says SC-06 is in review; the git log shows SC-06 admitted (`39295c4`).
11. **Two Context7 query budgets disagree.** NQ-01 allows "at most three queries per question" with no citation (`cards:35`); the rationale says at most two were used (`:144`).
12. **Native-stage cards need re-checking at Q-E01.** ART-14, ART-17, ART-24, ART-28 and NQ-03 rely on runtime pieces that have no cards yet (Session's D06 snapshots, ContentAdmission, the rebuild route). BACKLOG line 28 expects those cards after Q-E01; re-validate these dependencies then.
13. **The tracked receipt copy isn't made yet.** `artifacts/handoff-8-2026-09-16/drafts/ctx7/` doesn't exist (Glob found no files). That is expected: DQ-11 makes the copy a coordinator step before import.

## Item 4: drafting questions DQ-01 to DQ-13

**Must be done before import.**
- **DQ-01:** the HF-01 path amendment, carved as disjoint rows (N5).
- **DQ-11:** copy the receipts to the tracked destination.
- **DQ-13:** amend it together with F1.
- **DQ-05:** define or register the collision card, or hold NQ-03 back (N1).

**The coordinator can settle these from sources.**
- **DQ-02:** ParticleProcessMaterial until shader source is admitted.
- **DQ-03:** pin tool versions at first use.
- **DQ-10:** schema dependencies.
- **DQ-12:** evidence cards are grooming work.
- **DQ-04:** now Q-P42; the coordinator imports it as a question.
- **DQ-07:** its wording is inaccurate (N6).

**Already settled by EV-0423.** DQ-06, DQ-08 (settled by the merge) and DQ-09.

**Put to Andrew in plain language.**
- "Rough blockouts need a list of what gets modelled and where the files go. Can we record that list now and leave the budget until the native build can measure it? Otherwise blockouts can't start next sprint."
- "Should the camera distance from the orchard prototype also be used to check enemy silhouettes, or wait for the native camera?"
- Q-P42: "For the orchard enemies, should attacks be hand-animated in Blender, driven by code in Godot, or a mix?"

## Item 5: does check_drafts.py test what it claims?

Its 20 controls exercise real rules, including R1's six previously untested ones plus body-dependency, cycle, gate and Q-P26. These gaps remain:

- **Bare-number check** (`coordinator-check-A2/check_drafts.py:122-147`):
  - It hides everything in backticks (`:124`).
  - It hides any hyphenated ID-like token (`:128`), so "BUDGET-5000" passes.
  - Any number chained after a line citation is hidden (`:130`): "line 719, 5000 triangles" passes.
  - The tie test is a substring match (`:118`), and spelled-out counts are never examined.
- **Stage labels:** it never checks a Lane label against the card's outcome or files. A rig card labelled "concept stage" would pass, because the native gate text also contains "EV-0423 decision 1" (`:229-234`).
- **Dependencies:** it misses prose-only dependencies (N1). References followed by "item" or "source", or preceded by "As", are skipped, and naming a downstream card is always allowed (`:296-300`). The rationale's "Waits on" column is only order-checked, never compared with the field (`:327-334`).
- **Citations:** it validates row IDs only for the ten SECTIONS keys (`:24-35`). HF-06a N-rows and every line citation go unchecked, as the rationale admits (`rationale:162`).
- **Receipts path:** the default `--receipts` is the ignored local path (`:438`). Re-point it after the DQ-11 copy.
- **Identity:** I read the coordinator's A2 copy and did not verify it is byte-identical to the writer's.

## Citations sampled (all exist and support the claim unless noted in N2)

- **ORCHESTRATOR.md:** 21, 27, 32, 41, 42, 49, 104
- **HF-01:** 19, 21, 26, 27, 30, 31, 33, 36, 37, 47, 50, 61, 66, 68, 72, 85, 102
- **TH-19:**
  - Quoted lines: 183-187 (HR-Q1 to HR-Q5)
  - Rows: AG-01, RR-01 to RR-09, IQ-01 to IQ-07, IG-01 to IG-07, AQ-05, AQ-06, AQ-16, AQ-19, AQ-20
  - Rows: OC-01 to OC-08, PV-01 to PV-07, IS-01 to IS-04, SI-01 to SI-06, GO-03, GO-04, AR-06, AR-07, EM-02, EM-06, CI-01 to CI-05, NO-02 to NO-05
  - Lines 200, 216, 220, 232, 296
- **TH-16:** RC-02, RC-03, RT-01 to RT-05, RT-07, RT-08, RE-02 to RE-07, RM-06, RR-01, RR-02, RR-06 to RR-10, RR-12, RQ-02 to RQ-07, RP-16, RP-17, RP-20
- **TH-02:** MP-03, MP-04, MP-06, MP-16, MP-17, MP-23
- **TH-03:** EN-1, EN-4, EP-01, AO-01, CH-05, CH-06, TP-06, TP-15, TP-21, TP-22
- **TH-15:** PX-09 and PX-10 fixtures and review rows
- **TH-13:** XP-02, XP-06
- **TH-05:** CO-14
- **PD-01:** lines 5, 63, 69, 70, 76; PE-01 to PE-05; VW-01 to VW-05, VW-07 to VW-11; PF-03 to PF-15; AC-05, AC-10, AC-16, AC-20, AC-22; RL-01 to RL-05
- **PD-03:** SE-13, SI-02, SI-03, SI-05, SI-08, SI-11, SI-14, UD-07, UD-10, SP-06, SP-07, AU-02 to AU-05
- **BIBLE.md:** 342-359, 411-428, 481-487, 719, 725, 727, 745, 747
- **Other docs:**
  - `DISCOVERY.md` 211, 213, 215
  - `HF-04a` line 22
  - `ASSETS.md` 15, 17
  - `TADR-003` line 35
  - HF-06a N-013 and N-021; AM-H8-003 `request.md:35`
  - BACKLOG 9, 11, 22, 28, 3164-3184, 3230-3254
  - TRACKING EV-0372, EV-0423, EV-0433 and rows 152, 252
- **Repository files:**
  - `.gitignore` 19-20
  - `scripts/native-smoke.mjs` 147, 148, 688, 742, 751, 753
  - `native/README.md` 42, 86
  - `src/orchard/scene.js` 410, 412
- **Context7 receipts** (under `artifacts/local/tasks/DRAFT-ASSETS/ctx7/`):
  - `b1` 8/16/24, `b3` 8/32/40, `b4` 4/8/16/24/40
  - `g1` 8/111, `g1b` 14/22-36/53, `g2` 8/50/58/66, `g3` 75/83, `g4` 26/81/91

Files reviewed:
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/drafts/asset-production-cards.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/drafts/asset-production-rationale.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/drafts/coordinator-check-A2/check_drafts.py
- /home/andrew/Projects/scrapkeep/docs/tech/sections/TH-15-physics-query-contract.md
- /home/andrew/Projects/scrapkeep/docs/tech/sections/HF-01-production-conventions.md