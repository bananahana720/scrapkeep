# SC-04 review R2

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**Verdict: PASS+NOTES.** B1 is fixed. All four definition-of-done items are met, and none of my notes breaks the definition of done.

**Evidence level:** 3 for what I read and walked myself: the B1 allocation, the SA, SM and SI traces, and the checker source. Citations are level 2. Hashes, drift, scope, docs, project and paper-check results are level 4, but only through the coordinator's receipts. I had no shell and reran nothing.

**What I reviewed:**
- The candidate is `/home/andrew/Projects/scrapkeep-wt-SC-04/docs/tech/schemas/SC-04.md` (615 lines). Line numbers below are that file's.
- The coordinator's `identity.txt` (receipt) says HEAD is `1259050b`, parent is `b1427907`, the tree is clean and only this file changed.
- I could not read the A1-to-A2 diff or run `git show`. I read the worktree bytes and took their match with the commit from receipts: `candidate-sha256.txt` gives `2bb8c569…`, and `paper-check.json:133` gives the same value.
- I compared sources against the main checkout, as the packet allows.

## B1 and the R1 notes
- **B1 is resolved.**
  - The scope table (:38-44) and its explanation (:46) put T1 to T4 on F-04 and N-023, and T5, T6 and T7 on F-04 only.
  - That matches the rows' own text: F-04 at HF-06a :69 and CSV :5, and N-023 at HF-06a :96 and CSV :32.
  - It also follows HF-06a :22, which lets a family row and a noun row describe the same type.
  - T4 now carries N-023, which is the only row that names region references.
  - A grep for "exactly one", "only row", "one root" and "one row" finds only an unrelated phrase at :439, so no one-row rule is left.
  - The save table (:423-429) and QO-05 (:469) match the new allocation. HF-06b :114 and :141 have identical columns, so save outcomes don't change.
- **HF-06b :114 seam:** it cites AM-H8-002 at :433, :580 and :584, and the quote matches HF-06b :114. Nothing still sends this seam to TH-20; TH-20 appears only at :415, :417, :469 and :592, for other seams. The citation fits `AM-H8-002/request.md:15`.
- **SC-02's kit-slot tension:** SC-04 does not depend on it.
  - SC-04 references F-02 only for enemy attacks (:150, SR-03 :403), which F-02's own text at HF-06a :67 allows.
  - A grep for N-021, N-020, ability, kit, slot, F-01, N-019 and mobility matches only the unrelated word "durability".
  - T6 `player_activation_rule` (:324) references no family.
- **R1 notes 2 to 6 are addressed, with no regression to items 2, 3 or 4:**
  - Note 2: D4-04 now cites TH-11 :103 and labels the finale-boss representation as a schema choice Q-P25 may revise (:251). TH-11 is in Sources with a hash (:20).
  - Note 3: the five fields now have types (:106, :191, :235, :321, :322), with the named value types at :69-73.
  - Note 4: `boss_id`, D4-02 and D5-02 are labelled as this contract's choices (:279, :251, :295), and the revision list covers all three cases (:590).
  - Note 5: the SA.4 and SA.5 gate labels are fixed (:525-526; HF-05 :84, :95).
  - Note 6: rule 1 now states the `illustrative.` prefix as an exception (:59).

## Definition-of-done items
1. **Scope, matrix rows and foreign definitions: met (level 3).**
   - The six card items are covered (:36-44).
   - The foreign rows are F-02, F-05 and N-012 (:9; HF-06a :67, :70, :85, all `schema`), plus the inbound seams N-002 to N-004 and N-057 (:50-55).
   - The references table has 13 rows (:399-413).
2. **Fields, identity and version rules, references, diagnostics and one labelled example per type: met (level 2).** This covers T1 to T7 (:94-395). There are 10 family diagnostics and 23 type diagnostics, and their edges match HF-05 :80-95. Every example carries the label "Illustrative, not canon."
3. **Save exclusion, round-trip expectations and qualification obligations: met (level 2).**
   - The exclusion is at :431.
   - Every save path exists in HF-07a: `generation_decisions` (:152-155), `rng_state` (:156), `next_entrance` (:166) and `content_revision` (:79).
   - Round-trip expectations RA-01 to RA-07 and RS-01 to RS-03 are at :441-457. Obligations QO-01 to QO-05 are at :463-469.
4. **Unchosen values symbolic, no canon: met (level 2).**
   - There are 32 parameter rows (:475-508).
   - The fixed values are sourced: ST-30 and ST-31 to BIBLE :519 (TH-06 ET-02 :314 also gives one boss per world), ST-32 to BIBLE :386, ST-28 to TRACKING :263, and ST-21 to TRACKING :221.
   - SX (:553-562) makes every example fail admission. I found no answered open question.

**Other packet items:**
- All seven headings are present in order (:3, :26, :512, :570, :582, :594, :606).
- Sources state 18 hashes. Per the receipts, the schema-folder drift check found 18 hashes with 0 mismatches and 0 unbound, and `check:drift` found 292 with 0 mismatches.
- There is no Resource, script or roster.
- HF-04a :24 is quoted as written (:15).

## Scenario walks (level 3)
- **SM (:536-540):**
  - SM.1: E02, draft to imported (HF-05 :81).
  - SM.2: E03, imported to structurally valid (:82). The structural gate checks only reference shape (:50).
  - SM.3: E09, structurally valid to draft (:88). The fields match HF-05 :105-114: `missing_id`, `validate_candidate`, the referrer as definition ID plus field path, and the held candidate admission.
  - As a replacement candidate, the step is E12 (:91).
  - The trace holds.
- **SA (:522-526):** E02, E03, E04, then E16 as a self-loop, then E05. This matches HF-05 :81-84 and :95. SA holds.
- **SI (:548-549):** E02, then E08 (:87), with `ContentAdmissionFailure` (:117). SI holds.

## Blocking findings
None.

## Non-blocking notes
1. **The packet contradicts B1's fix.** Its paper-check wording says every row "maps to exactly one type here", which can't hold once F-04 covers five types as B1 requires. I applied B1 and HF-06a :22. The coordinator should reword future packets.
2. **T6's row rule is the candidate's own.** :46 says "An embedded type takes the rows its parents share". HF-06a :42 doesn't state that. Following it, T6 gets F-04 only, even though it also sits inside T3, which is on N-023. That matches assignment A2 item 1 and changes nothing about saving. Label it as this contract's reading.
3. **Sources :23 attributes a derived consequence to EV-0273.** It folds "so every run region … needs a finale-capable boss variant" into Q-P12's recorded answer. TRACKING :237 doesn't contain that; it comes from TH-11 :103. This is R1 note 2's issue, fixed at D4-04 but still present at :23.
4. **The procedure record is out of date.** :596 says the worktree was verified at HEAD `254f8e11` "before any write". That was true for A1; A2 started from `b1427907`. :602 also says no parameter row changed, which I could not check without the diff.
5. **One unlabelled constraint.** `DurabilityValue` is "non-negative" (:71), but the choice column labels only "one number". Label non-negativity as a choice too.
6. **A seam is missing.** TH-06 UN-04 (:118) says boss placement enters "the region and level definitions". T4 `region_ids` and the D4-04 coverage check could duplicate an SC-05 placement. N-023's text allows the boss-to-region reference, but the region-direction seam (:417) names only archetypes.
7. **Integration order (coordinator's call).** AM-H8-002 is accepted but not yet applied (request :12, :14), and ORCHESTRATOR :142 treats an unapplied amendment as a blocker for dependent work. SC-04 rests on TH-11 and HF-07a rather than on HF-06b's wording, and the request says Handoff-8 work may continue (:16). Once FR-07 edits HF-06b, SC-04's stated hash will stop matching; :584 already names that recheck.

## What the paper check does not test
It now compares each type's rows with the nouns in HF-06a's text, in both the Markdown and the CSV (`check_schema.py:288-338`). It encodes and decodes through a codec built from the fields tables (:549-623), and it has 7 negative controls, including a wave on F-04 without N-023 (:811). Gaps:
- **Allocation:** the noun patterns are hand-declared (:43-50), and T6's intersection rule is never checked against a source.
- **Codec:** it is written in the checker over the document's own text grammar, and no negative control targets its preservation logic.
- **Bare numbers:** checked only in record values (:694), not in prose or parameter rows.
- **Save paths:** the regex (:38) still skips unprefixed names. Neither HF-06b's text nor the AM-H8-002 citation is checked.
- **Gate labels:** the gate-to-edge map (:29-37) is hand-coded, not derived from HF-05.
- **Trace fields:** the required `ContentReferenceFailure` fields are not checked.
- **Questions:** only anchor existence is checked, not that no open question is answered.
- **Sources:** hashes are compared, not line numbers. Any text containing "line" passes as a source (:402).
- **Foreign rows:** their `schema` treatment is not checked. I checked it by hand.

## Citations sampled (all say what the candidate claims unless noted)
- **HF-06a:** :22, :42, :46, :67, :69, :70, :85, :96, :143; CSV :5 and :32.
- **HF-06b:** :27, :31-35, :114, :141; CSV :32.
- **HF-05:** :18, :22-24, :27, :29, :35-39, :45-52, :64, :78-95, :101-117.
- **HF-07a:** :56, :61-63, :70, :79, :152-156, :166.
- **HF-09:** :52, :175, :290.
- **HF-04a:** :24, :63.
- **TADR-003:** :23-35, :45, :47.
- **TH-06:** :40-42, :50, :60, :61, :63, :64, :67, :81, :92, :94, :115-122, :130-136, :182, :184, :201, :265, :267, :279-282, :286, :316-330, :340, :360.
- **TH-11:** :42, :45, :93, :103, :120, :143.
- **TH-14:** :73, :78, :98, :101, :111.
- **TH-03:** :171, :173.
- **BIBLE:** :386, :517-525, :582.
- **TRACKING:** :221, :237, :248, :250, :263.
- **BACKLOG:** the SC-04 card at :2293-2317, which matches the packet.
- **Other artifacts:** AM-H8-002 `request.md`, SC-02 `review-R1.md`, ORCHESTRATOR :78-94 and :136-144.
- **Hashes:** not recomputed. `paper-check.json:133-137` shows the candidate hash plus the HF-06a, HF-06b and HF-07a CSV hashes and the HF-05 hash, and they equal the values in Sources (receipt).

## Commands and receipts
I ran no commands. From `coordinator-candidate-A2/exits.txt`, all exit 0:
- **`check:scope`:** documentation-only, one path.
- **`check:docs`:** 156 files, 0 failures.
- **`check:project`:** passed.
- **`check:drift`:** 292 hashes, 0 mismatches.
- **`check-drift.mjs --sections docs/tech/schemas`:** 18 hashes, 0 mismatches, 0 unbound.
- **Paper check:** 10/10 checks passed, 7/7 negative controls caught.

I read `check_schema.py` in full. The writer's copy has the same structural line markers (38, 288, 810, 886); that is not proof the two files are byte-identical.

## Model and writes
- **Model:** the runtime context names Opus 5 (`claude-opus-5[1m]`). That matches the EV-0367 routing, but I can't verify it by self-description.
- **CLAUDE_EFFORT:** unavailable; no environment access was exposed to me.
- **Writes:** none. I wrote, edited and committed nothing.