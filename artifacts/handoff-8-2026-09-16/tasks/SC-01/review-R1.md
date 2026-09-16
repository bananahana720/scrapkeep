# SC-01 review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**Verdict: FAIL.** The one blocking finding is Seam 1: the candidate gives HF-06a row N-024 to a new "slot definition" type, but three admitted sources treat N-024 as the slot-tree type.

**Evidence level:** I walked AI, AM and AV step by step against HF-05 (level 3). I checked every sampled citation at its file and line (level 2). The hashes, drift, scope, docs, project and paper-check results are the coordinator's level-4 receipts, which I read but could not rerun.

**Candidate:** `/home/andrew/Projects/scrapkeep-wt-SC-01/docs/tech/schemas/SC-01.md` at `46c5c199`. Per the coordinator's `identity.txt`, its parent is `bb97c411` and it changes only that one file.

## Definition-of-done items
1. **Scope, matrix rows and foreign definitions: not met.** Scope is only characters, kits, slots, trees and nodes (SC-01.md:31-37). All 11 rows are listed and foreign references are tabled (SC-01.md:84-96, 409-422). But row N-024 is given to type T3 (SC-01.md:95), which contradicts admitted rows (blocking finding B1).
2. **Fields, types, identity and version rules, references, diagnostics and one labelled example per type: met, level 2-3.** Types T1-T5 are at SC-01.md:98-407. Shared rules are at :43-78. Each example carries "Illustrative, not canon." Example IDs are refused by rule SA-02, walked in scenario AX (:575-582).
3. **Save treatment, round-trip expectations and executable obligation: met in form.** The save table is at :424-442, load rules at :444-455, round-trip expectations at :457-466 and TH-22 obligations at :468-480. Save column and case match the HF-06b CSV, and every projected path is in HF-07a's CSV. The split of save fields between F-03 and N-024 (:431-432, :442) inherits B1.
4. **Unchosen values symbolic and tied to questions, no canon: met.** Placeholders are in the form `unset:Q-…` (:109-112, :173-174, :369-375). Rows SP-14 to SP-28 are unset with a question ID. The 16 question IDs are real and their subjects fit (BACKLOG.md:2810-3188). The recorded Q-P18 scope matches TRACKING.md:243.

**Seven headings:** present (paper-check C01 passed, per the coordinator's receipt). **Packet bans:** only the one document changed (`identity.txt`). No Resource, script or chosen cost. The counts 15, 14, 8, 2 and 3 come from BIBLE line 529.

## Blocking finding
**B1. Row N-024 is re-read inside the consuming card, against admitted rows.**
- **What the candidate does:** SC-01.md:95 and :521 give N-024 to T3 (the slot definition). SC-01.md:432 and :442 then say T3 supplies `slot_id` and `unlocked`, and T4 supplies `tree_id` and `node_keys`.
- **What the admitted sources say:**
  - HF-06a line 22: a noun row "names the family row it instantiates in its rationale", and it gives F-03 and N-024 as its example of two rows for one type.
  - HF-06a line 97: N-024's rationale reads "Slot-tree definitions (F-03)".
  - HF-06b CSV row N-024: "The same projection as F-03". Row F-03 already includes "the slot's access state".
  - HF-07a line 127: `slot_id` is sourced to HF-06b row F-03, not N-024.
  - HF-06a line 46: a row that does not fit "returns here for re-verification rather than being re-treated inside the consuming card". Line 193 re-opens the matrix when an SC card cannot fit a row.
- **Violated requirement:** "contradictions with an admitted row are blocking", and the obligation that each row maps to its type.
- **Why it is not the writer's fault:** HF-07a line 127 gives a slot its own domain ID, and no HF-06a row types that definition. TH-07 Seam 4 (line 362) even names "the node, tree and slot schema" through F-03 and N-024. The writer found a real gap in the matrix and disclosed it, but settled it by reinterpreting the row. Calling it non-blocking (:615) is not supportable.
- **Fix (needs your decision, outside SC-01's write set):**
  - **Option a:** open the HF-06a re-verification under line 193. Record an HF-06a revision in TRACKING, with matching HF-06b and HF-07a source cells, that either rewords N-024 or adds a row typing the slot definition. SC-01 then re-cites the new hashes, and Seam 1 becomes a plain citation.
  - **Option b:** give N-024 to T4 alongside F-03, and hold T3 as a type with no row, blocked on the same re-verification.
  
  Either way the candidate cannot be admitted until HF-06a changes. You could log this as blocked on HF-06a rather than a plain changes-requested.

## Non-blocking notes
1. **Seam 2 is acceptable.** HF-06a's own rationales for N-045 and N-046 (lines 118-119) and N-014 (line 87) name "SC-07 visual references", so pointing at those rows contradicts nothing. Excluded rows have no definitions (HF-06a line 44), so SM-02 cannot resolve these references until SC-07 defines the type. Raise it in the same HF-06a re-verification.
2. **Wrong count of negative controls.** SC-01.md:637 says "eight negative controls"; the checker has nine (check_contract.py:887-895), and the coordinator's `paper-check.log` shows 9/9.
3. **Evidence limits overstate the checker.** SC-01.md:641 says the rule model shows outcomes "follow from the rules as written". The rules are hand-coded in Python (check_contract.py:172-380); only rule names are read from the document (:742-748). It shows the model agrees with the outcome table, not that the outcomes follow from the table text.
4. **Loose sourcing on three rows:**
   - SA-23 (`kit_order`, :197) applies HF-07a line 64's save-array ordering rule to authored definitions. Label it the contract's own determinism choice.
   - SP-12 (value 1) and SP-13 (at least 2) cite lines that do not state those numbers (:499-500). Label them as this card's grammar and layout decisions (HF-05 line 18; HF-06a line 24).
5. **SV-02 cites HF-09 line 63**, which is the added-key rule. G11 at line 177 is the right source.
6. **AM lists only some required fields.** Its outcome (:563) omits some fields HF-05 lines 105-115 require (`requested_content_revision`, `catalogue_revision`, `candidate_identity`, `available_revision`, `message_key`). Nothing is contradicted.
7. **SI-02 overstates SA-02's reach.** SI-02 (:46) says example IDs are refused by SA-02, but SA-02 checks only `id` fields. Example references are refused only through SM-02 `missing_id`. AX still holds.

## What the paper check does and does not test
It is more than a string check. It verifies hashes, matches rows and save columns against the CSVs, checks projected paths and groups against HF-07a, checks scenario edges and state continuity against HF-05's edge table, runs a rule model with one targeted change per SA, SM and SL rule, does a strict-type round trip, and requires question anchors to exist. Its gaps:
- **C03** does not compare the assigned type with the HF-06a rationale, which is why B1 passed.
- **C06** accepts excluded rows as reference targets.
- **C07** does not check which HF-06b row HF-07a credits for each save field.
- **C11** checks that question anchors exist, not that their subjects fit.
- **C02** checks hashes but not whether cited line numbers say what is claimed.
- **C09** checks a hand-written model rather than the document's rule text.

## Walks
- **AI (:568-573):** replacing edge k2→k5 with k1→k5 leaves 15 nodes, 14 edges, 8 endpoints (k7-k14), one root, no reconvergence, full connectivity and depth 3 everywhere. k1 now has three children and k2 one, so SA-43 fires twice. An initial candidate failing at `imported` goes back to `draft` via E08 (HF-05 lines 69, 87). The trace is correct.
- **AM (:557-564):** E02, then E03 (a well-formed string passes SA-06), then E12 (a replacement failing semantic checks goes to `rejected-reload`, HF-05 line 91). Code `missing_id` and the `referrer` form match lines 105 and 111. Correct.
- **AV (:545-553):** E02, E03, E04, E16, E05 match HF-05 lines 81-84 and 95. Correct.

## Citations sampled (all say what the candidate claims unless noted)
- HF-06a lines 22, 24, 42, 44, 46, 66, 68, 97, 110, 118-119, 193. Line 97 matches the quote but contradicts the allocation (B1).
- HF-05 lines 18, 22, 45, 50, 51, 54, 81-95, 105-117, 123.
- HF-07a lines 26, 37, 56, 61, 64, 113, 125-130.
- HF-06b lines 25, 27, 31-36, 45, 47, 60, 209, and CSV rows F-03 and N-024.
- BIBLE lines 273, 275, 289-294, 400, 402, 432, 529-544, 659.
- TADR-003 lines 23, 25, 27, 29, 31, 35, 41, 45.
- TH-07 PA-1 to PA-4, PT-01 to PT-13, PR-05, PI-01, PI-27, PX-04 to PX-08, PX-17, PX-20, PF-06, PP-01 to PP-06, PP-16 to PP-28, Seam 4 (line 362), WC.5 (line 398).
- TH-04 AS-01 to AS-04, AA-02, AA-03, AP-23, AP-24, AP-26, line 44, Seam 3 (line 317).
- TH-08 EQ-03, EQ-05, EQ-09, EC-01, EC-02, EO-04, EO-06.
- HF-09 lines 35, 121, 122, 175, 177, 181, 195. Line 63 is weak (note 5).
- HF-07b lines 76, 114, 121. HF-03a lines 23, 34, 35, 48. TH-02 lines 66, 127.
- **Hashes:** I did not compute them. I relied on the coordinator's `check-drift-schemas.log` (16 stated hashes, 0 mismatches) and `paper-check.json` (C02: 17 passed). Per the source manifests, the writer's and coordinator's checker copies have the same SHA256 (`222dea59…`).

## Commands
I ran none; I had no shell. The exits below are from the coordinator's `exits.txt`, all 0:
- `check:scope` (documentation-only)
- `check:docs`
- `check:project`
- `check:drift`
- `node scripts/check-drift.mjs --sections docs/tech/schemas`
- the copied paper check (288 passed, 0 failed, 9/9 negative controls failed as intended)

The packet's HF-04a line 24 randomness rule does not apply, because SC-01 has no randomness.

## Runtime and write confirmation
- **Model:** `claude-opus-5[1m]`, per the host's environment statement. That is Opus 5, matching the per-card routing at EV-0367, so there is no substitution.
- **CLAUDE_EFFORT:** unavailable; I had no environment access.
- **Writes:** none. I only read files.