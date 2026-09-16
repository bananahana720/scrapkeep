# SC-05 review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

# SC-05 review: candidate `ac3163d44c55337e5975d651f267aeebb7af7c45`, judged against proposed card revision 2

**Verdict: FAIL.** My own evidence reached level 3: I compared the bytes to their cited sources and walked the traces step by step. Level-4 evidence comes only from your receipts (C-labelled below). I ran nothing.

The five types themselves (T1 to T5) hold up well. The rows, save table, diagnostics and citations I checked are accurate. The contract fails because it was written against card revision 1. It does not meet revision 2's definition-of-done item 1, and it still says an amendment is pending even though AM-H8-004 has been accepted. Both fixes are small.

Candidate path: `/home/andrew/Projects/scrapkeep-wt-SC-05/docs/tech/schemas/SC-05.md`.

## Receipts I relied on (level 4, from you; I did not rerun them)
- **C1** `identity.txt`: HEAD is ac3163d, parent is 56e579a, the worktree is clean, and one path was added (`A docs/tech/schemas/SC-05.md`).
- **C2** `exits.txt`: check:scope, check:docs, check:project, check:drift, the schemas drift run and the paper check all exited 0.
- **C3** `check-drift-schemas.log`: 16 stated hashes, 0 mismatches. My grep found 13 SHA256 lines, three of which carry two hashes, so 16 matches the count.
- **C4** `paper-check.log`: 10 of 10 checks passed and 8 of 8 negative controls were caught. I read `check_sc05.py` in full.
- **C5** `candidate-sha256.txt` gives `848f5288…9ede`. I could not recompute it.

## Definition of done, item by item (revision 2)
1. **Scope, rows and foreign definitions: NOT MET.**
   - Covers only the in-scope types (region = area, level module, route, exit, generation constraint): met, lines 32-40 and 90-92.
   - Row allocation: met, lines 44-68. I checked every in-scope rationale at HF-06a lines 70, 74-79, 101 and 109. F-05 names all five type terms. N-001 names region/world/area and "destination offers". N-002 to N-006 name only region terms. N-028 names world/run-region, exit and destination-eligibility. N-036 names landscape-family, region and route. No row is re-treated. Paper check A1 compares these against both the Markdown and the CSV.
   - F-04 objective definitions through which levels reach events and secret rooms: not identified. See B1.
2. **Fields, types, identity/version, references, diagnostics, labelled illustrative record: MET** (level 2-3). T1 lines 136-164, T2 172-201, T3 210-243, T4 252-292, T5 301-331. Shared identity rules SI-01 to SI-08 at 102-111, diagnostics DG-01 to DG-24 at 348-373.
3. **Save projection, round-trip expectations, qualification obligation: MET** (level 3). Save table at 381-395. Every field I checked is an HF-07a CSV `field` whose `projection_group` belongs to its row: `run.start.rng_state` is random-generator-state (CSV line 18), `run.start.entrance_id` is next-entrance (line 17), `generation_decisions` is route-generation-decisions (lines 48-51). N-001 and N-036 match HF-06b lines 119 and 154. Round trips PR-01 to PR-08 at 409-418, obligations QO-01 to QO-06 at 424-431. See notes N2 and N3.
4. **Symbolic values, no canon: MET** (level 2). The parameter table (435-468) has a source line or question ID on every row. The numbers 4, 2, 5 and 1 each trace to BIBLE 578/580, TH-11 RP-10 at line 268, or BIBLE 519. No candidate names appear inside records.
- **Seven headings:** present at lines 3, 26, 488, 628, 639, 645 and 653.
- **Hashes and drift:** C3 only.

## Blocking findings
**B1. Revision 2 item 1 is not met: the F-04 objective definitions are never identified.**
- The foreign-reference table (lines 335-342) has no objective entry.
- T2 `encounter_slots` (line 178) targets an "F-04 encounter definition".
- DG-20 (line 369) requires "an encounter for a slot", so an objective definition placed in a slot would be rejected.
- Seam 1 (line 472) is only conditional: "Under either resolution … would reach a level through an F-04 reference such as FR-01".
- So the contract gives no usable path from a level to an event or secret room, even though TH-06 UN-05 (line 119) and AM-H8-004 option 1 settle that these are F-04 objective definitions owned by SC-04.

**Fix:** add a foreign-reference row for the F-04 objective definitions (SC-04; TH-06 UN-05 line 119; AM-H8-004). State the exact path: either through the F-04 encounter that FR-01 references (a stated SC-04 seam, no field here) or through a named T2 field. Make DG-20 consistent with that path, and leave the types themselves with Q-P38.

**B2. The source identity is stale, and the withholding text contradicts the card this verdict is recorded against.**
- Line 5 says "implements … revision 1" and "withheld pending an amendment request".
- Lines 94-98 say "Card item 1 names events and secrets" and cite `artifacts/local/tasks/SC-05/amendment-request-events-secrets.md`. That path is gitignored (`.gitignore:7`) and does not exist in the main checkout.
- The same pending framing appears in SP-29 and SP-30 (lines 465-466), Seam 1 (line 472), Unresolved questions (line 635) and Procedure (line 649).
- Paper check A9 (`check_sc05.py:702-712`) enforces the withheld section and the local file, so it will fail if rerun from main.

**Fix:**
- Cite revision 2 and `artifacts/handoff-8-2026-09-16/amendments/AM-H8-004/request.md` (accepted, option 1).
- Replace "Withheld" with the settled ownership statement.
- Turn SP-29 and SP-30 into pointers outside this family, or remove them.
- Update A9 and its control.
- Rerun the paper check, `npm run check:drift` and `node scripts/check-drift.mjs --sections docs/tech/schemas`.

## Non-blocking notes
- **N1 (for you, on the card):** Revision 2's source bullet and item 1 leave out exits. HF-06a F-05 (line 70) and N-028 (line 101) give exit definitions to SC-05, and the packet counts five types. Add "exits" to revision 2 before it goes into BACKLOG.
- **N2 (AM-H8-002):** Seam 4 (line 478) and line 637 still treat HF-06b line 114's clause about level and encounter IDs as a live gap for TH-20 ("missing id-string carriers").
  - This does not contradict the amendment: no field is added, and lines 478 and 626 say a resume needs neither ID. It should cite AM-H8-002 as settled.
  - Recovering module IDs by decoding the saved keys (`decision_keys` via `decision_key_decode`) fits HF-07a CSV line 51 ("vocabulary belongs to the producing content card") and TH-11 line 45.
  - Recovering encounter IDs by reading `encounter_slots` assumes every slot of a decoded module was used. That is my inference; nothing I read states it.
- **N3:** DG-24 (line 373) holds a restore when a saved key cannot be decoded. No HF-07b or HF-09 gate I read performs that check. TH-14 GV-07 (line 125) keeps `decision_keys` opaque, and WR.5 (line 624) says keys are not decoded on resume. Restate DG-24 as a TH-20/TH-22 seam.
- **N4 (possible over-constraints):**
  - DG-14 (line 363) forbids exit-graph cycles, but no cited source says so, and topology is still open (SP-10; TH-11 RP-12 at line 271).
  - Line 264 forbids any requirement on an exit, while BIBLE line 177 restricts only *required* exits, and branch types belong to Q-P38 (TH-11 RP-22 at line 281).
  - SP-25 = 1 together with DG-14 could rule out a separate finale boss exit, which Q-P25 leaves open (TH-11 line 103). The recheck trigger at line 643 covers this.
- **N5:** Seam 2 (line 474) calls cue themes "the inverse index" of FR-03 to FR-05, but FR-05 is N-050 (music arrangements). No admitted row gives N-051 cues a region reference, so N-002's "SC-07 cues" relation (HF-06a line 75) has no carrier in either direction. Line 147 ("stores no enemy, item, cue or music reference") differs in direction from N-002. It is flagged to TH-20, but you should confirm it is a direction choice and not a re-treatment of the row.
- **N6:** The T3 illustrative record (`finale_rule: {}`, line 242) fails its own DG-18, and trace TA leaves out T3 (line 506). No route definition is ever shown passing admission.
- **N7:** The fixture's slot stub has kind `"ordinary"` (line 497), but DG-20 expects "an encounter". The model checks only the boss kind (`check_sc05.py:510-513`).
- **N8 (paper-check gaps):**
  - A2 finds the identity/version and references paragraphs by string match (`check_sc05.py:277-288`).
  - A6's encode/decode is a `json.dumps`/`loads` identity, which cannot fail for already-parsed JSON (lines 600-603).
  - PR-02 is tested on a hardcoded dict (lines 609-611), not the document's records.
  - A1 checks consistency with the writer's own term lists, not whether those lists are complete.
  - A7 ignores numbers in prose.
  - No check covers cited line numbers or revision 2's F-04 obligation.

## Citations sampled (all correct)
- **HF-06a:** lines 22, 40, 44, 46, 69, 70, 74-79, 88, 96, 97, 101, 106, 109, 117, 123, 129, 144.
- **HF-06b:** rules 1-6 at lines 31-36; rows at 114, 115, 119-124, 142, 146, 154.
- **HF-05:** lines 18, 22-24, 27, 29, 35, 37, 45, 49-52, 54, 66-74, 80-95, 105, 108, 111, 117.
- **HF-09:** lines 83-89, 93-99, 121, 122, 175, 176, 195.
- **HF-07a:** lines 56 and 62-66, plus CSV rows 11-65.
- **HF-03a:** lines 34, 45, 46, 48.
- **HF-04a:** line 24.
- **TH-11:** lines 20, 39, 41, 42, 45, 55-63, 67-69, 77-79, 91-94, 99, 103, 213, 228, 248, 259-291, 375-377.
- **TH-14:** lines 48, 49, 72, 75, 86-92, 96, 98, 101, 110, 111, 119-125, 262-267, 272.
- **TH-06:** lines 41, 42, 61, 118-120.
- **TH-09:** lines 61 and 66.
- **TH-07:** line 364.
- **TH-15:** lines 140 and 308.
- **BIBLE:** lines 169, 177, 181, 519, 578-584.
- **TADR-003:** lines 23, 25, 27, 29, 31, 35, 45.
- **Hashes:** C3 only.

## Traces walked against HF-05
- **TC (invalid record):** structural failure on an initial candidate takes E08 (line 87), imported to draft. As a replacement it takes E11 (line 90), to rejected-reload. The diagnostic is ContentAdmissionFailure with a rule (line 117). Correct.
- **TB (missing reference):** E03 (line 82) passes, since a well-formed reference shape is structural (line 50). The cross-reference gate (line 51) then fails via E09 (line 88), structurally valid to draft; as a replacement, E12 (line 91). The code `missing_id` is in the closed set at line 105, and the referrer form matches line 111. Correct.
- **TA (valid):** E02, E03, E04, E05 match lines 81-84. Correct.

## Commands, model, writes
- **Commands:** none. This session had only Read, Grep and Glob, so there are no exit codes of my own.
- **Model:** Opus 5 (`claude-opus-5[1m]`). This comes from the runtime system statement; I cannot verify my own identity.
- **CLAUDE_EFFORT:** unavailable, since I had no environment access.
- **Writes:** I wrote, edited and committed nothing.