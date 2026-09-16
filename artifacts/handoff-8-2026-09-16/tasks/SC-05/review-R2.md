# SC-05 review R2

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**Verdict: PASS+NOTES.** I reached evidence level 3 on my own: I checked the candidate against its sources line by line and walked all three traces step by step. Anything at level 4 comes only from your receipts, labelled **[C]** below. I ran nothing, because this session only had Read, Grep and Glob.

Candidate: `/home/andrew/Projects/scrapkeep-wt-SC-05/docs/tech/schemas/SC-05.md` at 4b42355, judged against proposed card revision 2.

**One condition before you record the verdict (yours, not the writer's).** The acceptance item "reports no line for the file" is not met by these bytes. **[C]** `check-drift-schemas.log:1` reports `UNBOUND docs/tech/schemas/SC-05.md:24`. Your packet assigns the fix to integration, which means turning the backticked SC-04 path into a link. That changes the reviewed bytes, so rerun the schemas drift scan and the paper check on the integrated file.

## B1 and B2 first
- **B1 is resolved.**
  - FR-03 is added at line 347 as an outbound F-04 ObjectiveDefinition reference, reached through FR-01 or FR-02. No field in T1 to T5 points at an objective.
  - The path is stated at lines 100-106: a T2 slot or the boss exit's `boss_encounter_id` leads to SC-04's EncounterDefinition, whose `objective_ids` lead to T7 ObjectiveDefinition.
  - I checked every SC-04 citation against the main checkout's `docs/tech/schemas/SC-04.md`, and all are exact: `region_ids` 104; T4 at 222 with `tier` 231, `region_ids` 234 and `finale_capable` 235; D4-04 at 249; T5 at 268 with `objective_ids` 277 and `boss_id` 279; D5-01 at 290; T7 at 352 with `kind` 361 and `subject_ids` 362; SR-01/07/09/13 at 401/407/409/413; the region-direction seam at 417.
  - DG-20 (line 379) now reads `boss_id` and `tier`. A slot that names a T7 record is DG-13 (line 106). Objective kinds stay with Q-P38 (lines 98, 106, 477).
- **B2 is resolved.**
  - Line 5 cites revision 2, TRACKING EV-0415 and the tracked AM-H8-004 path. The amendment's decision record (`request.md:48`) accepts option 1.
  - The settled ownership section is at lines 96-98. SP-29 and SP-30 (lines 477-478) now point outside the family. Seam 1 (484) and Unresolved questions (672) match.
  - A grep for "withh" or "pending" finds only lines 686 and 690, which describe attempt 1 and the check itself.
  - The earlier R1 notes are handled: AM-H8-002 cited as settled (495, 674), DG-24 restated as a seam (383, 499), choices labelled (385, 272, 458), Seam 2 direction choice with corrected FR numbering (491), and the T3 `finale_rule` fixture key plus the TA supplement (250, 528-543). The stubs now carry `boss_tier` (518-519).

## Definition of done, item by item
1. **Scope, rows and foreign definitions: MET (level 3).**
   - Five types (36-42), with areas folded into regions (92-94).
   - Row allocation (50-68): I checked every in-scope rationale at HF-06a lines 70, 74-79, 101 and 109, and each named term is present. It follows the current rule that a type carries every row whose rationale names it.
   - Out-of-scope rows that also name these terms are listed at 76-90. The foreign-definition table is at 343-352, including FR-03.
2. **Fields, identity/version, references, diagnostics and a labelled illustrative record per type: MET (level 3).** T1 138-172, T2 174-210, T3 212-252, T4 254-301, T5 303-339; shared identity rules SI-01 to SI-08 at 110-119; diagnostics DG-01 to DG-24 at 358-383.
3. **Save treatment, paper round trips, executable obligations: MET (level 3).**
   - Save table at 393-407. Every field is an HF-07a CSV field, and its projection group belongs to that row's HF-06b groups. F-05's are route-generation-decisions, random-generator-state and offered-choices (CSV line 6). N-028's six groups (CSV line 37) are all covered, three of them by the no-reference table at 411-415. N-001 and N-036 are `no-definition-no-state` (CSV lines 10 and 45).
   - Round trips PR-01 to PR-08 at 421-430; obligations QO-01 to QO-06 at 436-443.
4. **Symbolic values, no canon: MET (level 2-3).**
   - Every parameter row SP-01 to SP-32 (447-480) has a source line or a question ID. The values 4, 2, 5 and 1 trace to BIBLE 578/580, TH-11 RP-01/RP-06/RP-10 (lines 259, 264, 268) and BIBLE 519.
   - SP-05 names no candidate. Every record is labelled illustrative. No open question is answered: DG-14, SP-25 and T4's no-requirement rule are labelled as this contract's choices, with revision triggers.

**Other acceptance items:**
- **Headings:** all seven are present, at lines 3, 28, 509, 665, 676, 682 and 702.
- **HF-04a line 24:** read correctly (lines 13 and 507).

## Traces I walked
- **TA (valid).**
  - Structural, E03: every ID matches the grammar. Ordinary exit a-entry has an onward exit and a null boss; the boss exits have no onward exit and a non-null boss. The pool is nonempty and the starting region is a member.
  - Cross-reference: all references resolve, and both encounter IDs hit EncounterDefinition stubs.
  - Semantic, E04:
    - Region graphs: a-entry→a-boss gives one boss; regions b to e each enter at their single boss exit, so one each, matching SP-25 = 1.
    - Route and content: five route members (SP-03), one route, decode within the pool, `boss_tier` equal to `boss`, and the composition key present in the manifest.
    - Rule profile: every token uses the `illustrative-` prefix except `level_role`, which uses SP-24's valued vocabulary.
  - Then E05. This matches HF-05 lines 81-84.
- **TB (missing reference).** E02, E03, then E09 to draft with `missing_id`, which is in HF-05's closed code set at line 105. The referrer form matches line 111. As a replacement it takes E12 (line 91).
- **TC (invalid record).** E02, then E08 to draft with ContentAdmissionFailure `SC05-S-REQUIRED`, as HF-05 line 117 defines. As a replacement it takes E11.

## Blocking findings
None.

## Non-blocking notes
- **N1. The FR-nn IDs collide with BACKLOG card IDs.** In this document FR-01 to FR-08 are foreign-reference IDs, but BACKLOG has cards FR-03 to FR-06 (BACKLOG 3685-3773). "FR-07" means N-050 music at line 351 and the definition-import card at lines 5, 25, 484 and 678. **Fix:** rename the local IDs (for example XR-nn), or link the card as `[FR-07](BACKLOG.md#fr-07)` once it exists.
- **N2. The rule-profile wording is inconsistent.** Line 387 says every vocabulary parameter is unset, and line 513 says only `illustrative-` tokens are known. But SP-24 (line 472) is valued, and TA's `ordinary`/`boss` depend on that. The check's model quietly exempts `level_role` (`check_sc05.py:476`).
- **N3. SP-26/DG-17 and DG-15 are unlabelled inferences.** Line 385 says "Two rules … are this contract's choices". The one-route-per-candidate limit is inferred from a missing save field (lines 229, 474), and DG-15 is derived rather than sourced. Label both.
- **N4. `finale_rule` (line 225) overlaps SC-04's finale coverage rule D4-04 (SC-04:249-251).** Seam 5 (line 501) states this for TH-20, and it contradicts no admitted row. It is still a potential second truth that would block production routes.
- **N5. Gaps in the paper check.**
  - A6: encode now rejects undeclared keys and wrong types, which is what catches NC11. But the per-field `json.dumps`/`loads` round trip still cannot fail for parsed JSON (608-636). Field order (PR-01) is not asserted, and PR-06 to PR-08 are untested apart from the chosen-option check.
  - A10 and A9: they check that strings are present (699-720, 795-807); they do not compare SC-04's cited lines with SC-04's bytes.
  - A1: it still uses the writer's own term lists. A7 still ignores numbers in prose, and A2 still finds paragraphs by string.
  - The model does not cover DG-15 (Model.run has no `SC05-M-ENTRY-SHARED` rule), DG-21's scene-override half, or DG-22 to DG-24.
  - **[C]** Against the worktree alone the check exits 1 (A8 and A9 need main-checkout files), and with `--main-root` it exits 0 (`exits.txt:6-7`).
- **N6. Your amendment record is stale in places.** `AM-H8-004/request.md` lines 14, 58 and 62 still say Pending/Open, though its decision record at line 48 says accepted.
- **N7. T4's "one illustrative record" is a two-record array (lines 280-300).** It is labelled and justified, so this is minor.

## Citations sampled (all correct)
- **SC-04:** 104, 222, 231, 234, 235, 249, 268, 277, 279, 290, 352, 361, 362, 401, 407, 409, 413, 417.
- **HF-06a:** 8, 22, 40, 44, 46, 69, 70, 74-79, 88, 96, 97, 101, 106, 109, 117, 123, 129, 144.
- **HF-06b:** rules 1 and 3-4 at lines 31, 33, 34; line 114 (F-04, with the "level and encounter by ID" clause); line 115 ("domain ID of a region, level module or exit"); CSV rows F-04, F-05, N-001 to N-006, N-028, N-036.
- **HF-07a:** 56, 62-66; CSV fields at lines 11, 17-20, 39-54, 62-65.
- **HF-05:** 18, 22-24, 27, 29, 35, 37, 45, 49-52, 66-74, 80-95, 105, 108, 111, 117.
- **TH-11:** 20, 39, 41, 42, 45, 55-63, 67-69, 77-79, 91-94, 99, 103; RO-12 at 213, RE-06 at 228, RF-07 at 248; 259-291 (RP-13 at 272, RP-22 at 281).
- **TH-14:** GR-01/02 at 48/49 (F-PROCESS in both rows), GS-04 at 75, GQ-05 at 90, GQ-07 at 92, GG-06 at 101, GU-01 at 110, GV-01/02/07 at 119/120/125, GP-19 at 272.
- **Other sections:** TH-06 118-120; HF-04a 24.
- **BIBLE:** 169, 177, 181, 519, 578, 580. **TADR-003:** 23, 25, 27, 29, 31, 35, 45.
- **TRACKING:** EV-0415 exists (line 629). BACKLOG SC-05 is still revision 1 (line 2326), as the packet expects.
- **Hashes:** **[C]** only. Worktree `identity.txt` shows HEAD 4b42355, parent ac3163d, a clean tree and one path added. File SHA256 is `ae8e9954…0f55`, and the schemas scan reports 17 stated hashes with 0 mismatches. I could not recompute any of them.

## Commands, model, writes
- **Commands I ran:** none, so there are no exit codes of mine. **[C]** Your receipts (`exits.txt`): check:scope, check:docs, check:project, check:drift and the schemas drift scan each exited 0. The paper check exited 1 on the worktree alone and 0 with `--main-root`, with 11/11 checks passing and 12/12 negative controls caught (`paper-check-main-root.log:24`).
- **Model:** Opus 5 (`claude-opus-5[1m]`), according to the runtime system statement; I cannot verify my own identity. **CLAUDE_EFFORT:** unavailable, because I have no environment access.
- **Writes:** I wrote, edited and committed nothing.