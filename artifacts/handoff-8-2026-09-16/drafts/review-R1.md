# DRAFT-ASSETS review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition). Final report retained verbatim.

**Verdict: FAIL.** The drafts are close. Structure, source fidelity and question gating are mostly sound, but several defects need fixing before a definition import. Evidence level: static review of the artifacts, with 30 citations checked directly against their sources. Pass counts and exit codes come only from coordinator receipts, because I cannot run commands.

**Runtime identity.** The system context reports Opus 5 (`claude-opus-5[1m]`). `CLAUDE_EFFORT` is not available to me: I have no shell and the value is not shown anywhere I can read. I wrote, edited and committed nothing.

**Coordinator receipts I relied on.**
- `coordinator-check/exits.txt`: check-drafts first exited 2 (usage error), then 0; check-docs, check-project and check-drift each exited 0.
- `coordinator-check/check.log:1-11`: positive run PASS (35 cards, 385 fields, 759 row citations), and all 9 negative controls were detected.

## Blocking findings

**B1. Three dependencies are missing** (packet item 2; ORCHESTRATOR.md:42, every prerequisite done).
- ART-08 item 3 (`asset-production-cards.md:318`) records mounting "against ART-06's chassis", but its Dependencies at `:310` omit ART-06.
- ART-11 item 3 (`:402`) attaches the hoop to "ART-09's mount bones", but `:394` omits ART-09.
- ART-14 item 3 (`:488`) plays "ART-12 and ART-13 clips" in Godot, but `:480` omits ART-18, the card that imports those clips. The rationale (`asset-production-rationale.md:29,31`) puts ART-14 at step 9, before ART-18 at step 11.
- **Fix:** add those dependencies and reorder rationale steps 5, 6, 9 and 11.

**B2. NQ-02 can never be admitted as drafted.**
- NQ-02 depends on NQ-01 (`:64`). NQ-01 is "handed to the coordinator unintegrated" (`:44`).
- ORCHESTRATOR.md:42 and :104 require dependencies to be done, and say an approved candidate in another worktree is not a completed dependency.
- The sequencing itself is right. TH-19 RR-09 (`TH-19-asset-import-export.md:212`) requires fixtures in the failing run, with only the passing candidate integrated.
- **Fix:** before import, record in NQ-02's card text an explicit exception tied to RR-09 ("NQ-01 reviewed candidate <sha>, integrated only with NQ-02"). Alternatively, restructure into one card. This is DQ-08, and it has to be settled before import.

**B3. ART-15 and ART-16 write runtime inputs before the import gates open.**
- They write `native/content/fuse/assets/effects/**` and `scenes/effects/**` (`:512`, `:540`) without depending on NQ-02.
- `.gitignore:20` (`native/**/*.import`) still blocks committing their sidecars until RR-01 lands.
- ART-17 item 1 (`:572`) requires IG-01 to IG-07 "before any file is staged", and TH-19 AG-01 (`:167`) agrees. The effect cards are inconsistent with both.
- **Fix:** add NQ-02 as a dependency, or keep effect work under `source-assets/fuse/effects/**` until ART-19.

**B4. ART-23 bundles two outcomes and hands a product choice to the coordinator.**
- It covers both the rig and the keyed stage clips (`:735-736`). Fuse's equivalent work is split into ART-10/11 and ART-12/13.
- Item 2 uses "the motion treatment the coordinator records for DQ-04". ORCHESTRATOR.md:112 and :32 reserve product choices for Andrew, and :21 bars the coordinator from inventing answers.
- **Fix:** split ART-23 into a rig card and a clips card. Register a question owned by Andrew for enemy motion, and use it as a Blocking question instead of DQ-04.

**B5. Pre-slice production authority is misassigned, and the growth-state choice is missing.**
- The rationale says production authorization for concept, blockout, model and rig cards "is a scope decision the coordinator records at admission" (`asset-production-rationale.md:102`). ORCHESTRATOR.md:21 says the coordinator "cannot … expand approved scope". Separately, BACKLOG.md:11 says the definitions authorize no production work, and BIBLE.md:747 says "broader sound production needs its own approved scope".
- ART-03 writes `source-assets/**` (`:164`) but treats Q-P26 as non-blocking (`:162`). Q-P26's closure evidence (BACKLOG.md:3170) requires a bounded manifest and allowed output paths "before production assets become runnable cards". Q-P26's missing information also includes *which* growth states (BACKLOG.md:3164). EV-0372 fixed only "one growth state".
- That matters for ART-26, which measures clearance at that authored state (`:816`). Clearance is meant to be tested at ordinary maximum growth (BIBLE.md:487; PD-01 PE-04).
- **Fix:**
  - Make an explicit Andrew authorization a named gate on ART-03, ART-06 to ART-13, ART-22, ART-23, ART-26, ART-27 and SND-01 to SND-04.
  - Make Q-P26 blocking for ART-03, or recast ART-03's output as concept-class renders.
  - Add "which growth state" as a gating item.
  - Correct rationale lines 68 and 102.

## DQ-01 to DQ-13 dispositions

**Must be disposed of before import.**
- **DQ-01:** HF-01.md:19 forbids claiming an unlisted path. The coordinator can settle it by amendment, since TH-19 OC-07 (`:57`) already classes `docs/art/**`. The same amendment should cover the SND cards: their owner is Audio, but they write Technical-art families (HF-01.md:30-31).
- **DQ-04:** needs a registered question (see B4).
- **DQ-08:** see B2.
- **DQ-11:** cited receipts sit in an ignored path, so the sources won't exist in a clean checkout. BACKLOG.md:26 already requires copying them. The coordinator settles the destination.

**The coordinator can settle from sources.**
- **DQ-02:** amend HF-01 for shader source, or restrict effects to ParticleProcessMaterial until amended.
- **DQ-05:** card collision geometry under TH-15.
- **DQ-10:** the schema dependency changes are consistent with BIBLE.md:413 and EV-0412.
- **DQ-12:** evidence cards are grooming work.
- **DQ-13:** path groupings per HF-01.md:21.

**Put to Andrew in plain language.** These questions are mine; the drafts do not raise the growth-state or who-makes-the-art questions.
- **DQ-06:** "To lock Fuse's model we need to judge the silhouette from a camera distance. Pick a provisional distance now and re-check later, or wait for the native slice?"
- **DQ-07:** "Should the first budget be measured in the native slice with placeholder shapes before any real asset is imported?"
- **DQ-09:** "Who makes the concept art: generated images (and with what), or drawn by hand?"
- **DQ-03:** "Which Blender, Krita and Audacity versions should we pin?"
- **Growth state (B5):** "Should the one authored growth state be the starting mech or a grown mech?"
- **Pre-slice authorization (B5):** "Do you authorize real models and sounds before the native slice exists, accepting rework risk?"

## Packet items 1 to 3

**Item 1.** All 35 cards have one owner, S or M sizing, verification with stated limits, and permitted files. Exceptions are B1 to B4, plus ART-14's "a presentation composition scene" (`:482`), which names no exact file (ORCHESTRATOR.md:41).

**Item 2.** I traced the dependency graph by hand and found no cycles. NQ-01 before NQ-02 matches RR-09 (`TH-19:212`); only admissibility is at issue (B2).

**Item 3.** I found no invented counts, budgets, polycounts, bone counts, texture sizes, loudness values or frame rates. The native import, motion and effect cards all gate on Q-E01 (e.g. `:480`, `:510`, `:566`). Construction C and its carried risks are honoured (`:137-139`, `:199`, `:400-401`), and no card contradicts AM-H8-003 (EV-0411).

## Non-blocking notes

1. NQ-02 item 1 (`:70`) leaves out RR-01's `native/content/*/assets/` path (`TH-19:204`).
2. NQ-02 item 4 runs IQ-01, which TH-19 assigns to "Proof card procedure" (`:224`). That is logically forced, but it should be recorded.
3. NQ-01 should require no leftover negative-input sidecar and a clean `sourceDirty` (RR-08, `:211`).
4. NQ-02 item 3 (`:72`) is ambiguous about completion when AQ-19 is negative, because RR-06 then fails the whole run.
5. ART-05 cites PD-01 PE-05 but its definition of done omits the intake-to-fabrication sequence. Q-P27 (BACKLOG.md:3178) needs it to close.
6. ART-11 (`:401`) cites TH-16 RT-06, the camera derivation rule, for nozzle orientation. That citation is weak.
7. Cards line 10 cites PD-01:76 and TH-16 RQ-08 for "Andrew's visual or listening review". Those rows list five evidence classes and do not include it.
8. ART-13, ART-18 and SND-01 could name ability (N-021) triggers under AM-H8-003. ART-15 may need SC-07, since the N-013 visual reference falls under FR-07.
9. TH-16 RP-17 also names Q-P38, which ART-15 and ART-16 omit.
10. The rationale's card states at line 7 are stale: SC-04 is now done (TRACKING.md:175).
11. ART-21 to ART-23, ART-18 and SND-05 may need re-sizing once Q-P25 or the clip lists are answered.
12. No art card states Blender execution authorization, or which steps need a human's hands.

## Item 5: what check_drafts.py actually tests

I read the copy at `coordinator-check/check_drafts.py`. I did not verify it is byte-identical to the writer's copy.
- **Number-tie loophole:** `bare_numbers` (`:122-128`) accepts any number followed within 40 characters by a parenthetical containing "line N". "5000 triangles (BIBLE line 719)" would pass. Spelled-out counts are never examined.
- **Line citations unchecked:** it never verifies line-number citations to BIBLE, HF-01, TH-19, the receipts or `.gitignore`. It checks only that row IDs exist. Ranges are checked at their endpoints only, and nothing checks that a citation supports its sentence.
- **Dependency checks:** there is no cycle check. It never compares card bodies against their Dependencies field (which is how B1 slipped through). The order check (`:237-240`) confirms only that each card ID appears in the rationale.
- **Negative controls:** the 9 controls leave these rules untested: register column mismatch (`:230-233`), order (`:238-240`), card-id (`:185-187`), undefined DQ (`:202-204`), link-text mismatch (`:166-167`) and blocking/non-blocking overlap (`:178-180`).

## Citations sampled (30, all exist and support the claim unless noted)

- **PD-01:** line 5 (no image generation), line 63, line 76; rows AC-10, AC-20, AC-22, VW-04, VW-05, VW-07, VW-10, VW-11, PE-01 to PE-04, PF-09, PF-12, RL-02, CC-01, CC-03.
- **BIBLE.md:** 221, 223, 225, 346, 354, 359, 413, 416, 428, 481, 483, 487, 493, 719, 731, 739, 747, 776, 777.
- **DISCOVERY.md:** 211, 213, 215.
- **TH-19:** lines 204, 212, 216, 220, 232; rows IQ-01 to IQ-07, IG-01 to IG-07, AQ-05, AQ-06, AQ-12, AQ-16, AQ-19, AQ-20, CI-01 to CI-04.
- **Other tech sections:** TH-16 RR-02, RR-05, RR-06, RR-08 to RR-10, RR-12, RT-02, RT-05, RT-06 (weak, note 6), RT-07, RM-06, RE-04 to RE-08, RQ-04, RQ-06, RQ-08, RP-17, RP-20; TH-03 EN-1, EN-4, EP-01, EP-09, AO-01, CH-05, CH-06, TP-06, TP-15, TP-21, TP-22; TH-02 MP-03, MP-04, MP-06, MP-16, MP-17, MP-23; TH-05 CO-11, CO-14; TH-13 XP-02, XP-06; TH-15 PX-09, PX-10; TH-06 AV-03, AV-06.
- **PD-03:** SE-07, SE-08, SE-10, SE-11, SE-13, SI-01, SI-02, SI-04, SI-05, SI-08, SI-14, SP-06, SP-07, UD-07, UD-10, BP-02, AU-02.
- **HF sections and project files:** HF-01.md:19, 21, 26-36, 61, 72, 102; HF-05.md:24, 25, 29; HF-04a.md:22; ASSETS.md:17; BACKLOG.md:9, 26, 3164, 3170, 3184; TRACKING EV-0322, EV-0372, EV-0411 and the Q-P32 row.
- **Repository files:** `.gitignore:20`; `native-smoke.mjs:148,742`; `native/README.md:42,86`.
- **Context7 receipts:** `b1` lines 8/16/24, `b3` 8/32/40, `b4` 4/8/16/24/40, `g1b` 14/53, `g2` 8/50/58/66, `g4` 26/81/91.

Relevant files:
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/drafts/asset-production-cards.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/drafts/asset-production-rationale.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/drafts/coordinator-check/check_drafts.py
- /home/andrew/Projects/scrapkeep/docs/tech/sections/TH-19-asset-import-export.md
- /home/andrew/Projects/scrapkeep/docs/tech/sections/HF-01-production-conventions.md
- /home/andrew/Projects/scrapkeep/ORCHESTRATOR.md