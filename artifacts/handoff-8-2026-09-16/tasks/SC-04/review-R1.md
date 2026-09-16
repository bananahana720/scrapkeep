# SC-04 review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**Verdict: FAIL.** There is one blocking finding: SC-04 splits its seven types across rows F-04 and N-023 in a way that contradicts the text of both admitted rows. The fix fits inside SC-04's own file, and no HF-06a change is needed.

**Evidence level:** 3 for what I read myself. I compared citations against the source files and walked the SM trace step by step. Hashes and command exits are level 4, but only through the coordinator's receipts; I had no shell and reran nothing.

Candidate: `/home/andrew/Projects/scrapkeep-wt-SC-04/docs/tech/schemas/SC-04.md` (606 lines) at `b1427907`, base `254f8e11`. Per the coordinator's `identity.txt`, only this file changed and the worktree was clean. The line numbers below are that file's.

## Definition-of-done items
1. **Scope, matrix rows and foreign definitions: not met (level 3).**
   - Coverage is limited to the six card items (:36-44).
   - Foreign rows F-02, N-002 to N-004, N-012 and N-057 are tabled against the right HF-06a lines (:48-55; HF-06a :67, 75-77, 85, 130).
   - The references table has 13 rows (:392-406).
   - The row allocation contradicts the admitted rows (B1).
2. **Fields, types, identity/version rules, references, diagnostics and one labelled example per type: met, with notes (level 2).**
   - Types T1 to T7 are at :87-388, each record marked "Illustrative, not canon."
   - Shared rules are at :57-66 and family diagnostics at :72-83. Every diagnostic edge matches HF-05 :78-95.
   - Scenario SX (:546-555) makes the example records fail admission.
3. **Save treatment, round-trip expectations and qualification obligation: met (level 2).**
   - The save table (:414-422) matches HF-06b :114 and :141: immutable-by-id, definition-by-id, tres, projection none.
   - Every save path named at :426 exists in `HF-07a-save-envelope.csv` (`content_revision` at CSV :3, `generation_decisions` at :48-51, `next_entrance` at :62).
   - Round-trip expectations RA-01 to RA-07 and RS-01 to RS-03 are at :434-450. Obligations QO-01 to QO-05 (:456-462) go to TH-22 and TH-20, which fits their definition-of-done items (BACKLOG :1770-1771, :1831-1832).
4. **Unchosen values symbolic and tied to questions, no canon: met (level 2).**
   - There are 32 parameter rows (:468-501).
   - The only fixed values are sourced: ST-30 and ST-31 to BIBLE :519, ST-32 to BIBLE :386.
   - Recorded answers are cited without being extended: Q-E10 (TRACKING :221), Q-P12 (:237), Q-P25 (:250), Q-P38 (:263).

**Other packet items:**
- **Headings:** all seven are present in order (:3, 26, 505, 563, 575, 587, 597).
- **Bans:** no Resource, script, roster or unsourced number in the records.
- **Seams:** concurrent cards are named without citing their bytes (:24). Both TH-20 seams are stated (:410, :573).
- **HF-04a :24:** cited only as written (:15) and not misapplied.

## Blocking finding
**B1. The row allocation contradicts HF-06a rows F-04 and N-023.**
- **What the candidate does:**
  - The scope table maps T3 (waves) and T4 (bosses) only to F-04, and T1 (archetypes) and T2 only to N-023 (:38-44).
  - :46 says "Each type maps to exactly one HF-06a row", each row has "exactly one root type", and N-023 "is the only row naming enemy archetypes and their attack and region references".
  - The save table (:416-422) and QO-05 (:462) carry this map forward to TH-20 and TH-22.
- **What the admitted sources say:**
  - HF-06a :22: a family row and a noun row describe "the same definition type from two directions", and the noun row names the family row it instantiates.
  - HF-06a :96 and CSV :32: N-023 is "Enemy archetype, wave, miniboss and boss definitions (F-04) referencing attacks (F-02) and regions (F-05)". So waves and bosses are N-023's too, and archetypes belong to the F-04 family.
  - HF-06a :69 and CSV :5: F-04 does name "enemy archetypes (SC-04) and their attacks (F-02)", so the "only row" claim at :46 is false.
  - HF-06b CSV :32: N-023 is "The same family as F-04". HF-06b :114 covers "Encounter, wave, boss and objective definitions".
  - Internal sign of the problem: T4 references F-05 regions (:227), but only N-023's text names region references, and T4 is mapped to F-04 alone.
  - HF-06a :46: a row is not to be re-treated inside the consuming card. "One root type per row" appears nowhere in HF-06a.
- **Requirements violated:**
  - The packet's rule that contradicting an admitted row is blocking.
  - Card item 1, "identify its HF-06 matrix rows".
  - The effect lands on TH-20 (index per row) and TH-22 (round-trip checks for "every matrix row", BACKLOG :1831): N-023 would be indexed to T1 and T2 only.
- **Fix, inside SC-04's write set:**
  - Map rows by their rationale text: F-04 covers T1, T3, T4, T5 and T7, with T2 and T6 embedded; N-023 is the noun row instantiating F-04 for T1 (with T2), T3 and T4.
  - Drop the "exactly one row / one root" wording and correct :46.
  - Make the save table and QO-05 agree.
  - Have the paper check's `coverage` compare the map to the rationale nouns (`check_schema.py:259-284` currently enforces the invented rule, which is why B1 passed).
  - Save outcomes don't change, since both rows carry identical columns.

## Non-blocking notes
1. **Admitted-source conflict routed to TH-20 instead of an amendment request.** HF-06b :114 says N-028's projection names "the level and encounter by ID". HF-07a's closed field list (HF-07a :70) and TH-11 :45 contradict that. The candidate discloses it (:573), but ORCHESTRATOR :138 routes contradictions through an amendment request, and TH-20's item 2 returns corrections to SC cards, not HF-06b. RS-01 and the migration claim at :428 depend on the HF-07a reading. The coordinator should decide the route.
2. **D4-04 cites the wrong source for its derivation.** It cites EV-0273, but "every non-start region needs a finale-capable boss" is TH-11 :103, which Sources does not cite. D4-04 also fixes the variant as a `boss`-tier record with `finale_capable` true, a representation TH-11 :103 leaves to Q-P25. Cite :103 and label it a schema representation an answer may revise.
3. **Several fields have no stated value type.** `durability`, `entries[].count`, `finale_capable`, `commitment_budget` and `pressure_budget` are typed `symbolic`. `finale_capable` is evidently boolean, since D4-04 tests it for "true" (:242). SD-03 (wrong type) can't be checked against those fields.
4. **Some structure rests on the contract's own choice, not a source.** `boss_id` allows at most one boss per encounter (:272). D4-02 requires a nonempty archetype list "because a boss test needs an actor" (:225). D5-02 forbids repeating a wave (:284). Two bosses in one encounter isn't in the revision list at :583.
5. **Gate labels in SA are slightly off.** SA.4 and SA.5 are labelled "Manifest and compatibility" (:518-519), but HF-05 :83 makes E04 the edge that passes that gate; E05's guard is the identity recheck plus Session permission (:84).
6. **Rule 1 contradicts itself.** It says "no grammar beyond that" and then reserves the `illustrative.` prefix (:59). The rule itself is fine.

## What the paper check does not test
It is more than a string check: it compares the save rows to the HF-06b CSV, save paths to HF-07a, and trace edges and state continuity to HF-05's edge table. It also matches embedded copies to their parents, and a negative control only counts as caught if the mutation adds a new failure (:724-731). Its gaps:
- **Row allocation** (`coverage`, :259-284) is never compared with the rationale text, so B1 passed.
- **The encode/decode** is `json.dumps`/`json.loads` of the parsed dict (:506-512), which always returns the input.
- **The bare-number check** covers record values only (:578), not prose or parameter rows.
- **Save paths:** the regex (:35) skips unprefixed names such as `content_revision` and `scope_id`, and nothing checks HF-06b's rationale text.
- **Foreign targets** aren't checked for `schema` treatment (:385-389).
- **Traces:** the check doesn't verify `ContentReferenceFailure` fields or the SE review.
- **Questions:** it confirms question IDs exist, not that their subjects fit, and nothing tests that no open question is answered.
- **Hashes:** it checks hash agreement only, not line numbers.

## Citations sampled (all say what the candidate claims unless noted)
- **BIBLE:** :386, :519, :521, :523, :525, :582.
- **TADR-003:** :23, :25, :27, :29, :31, :33, :35, :45, :47.
- **HF-06a:** :22, :24, :40, :42, :46, :67, :69, :75-77, :85, :96, :130, :143, CSV :5 and :32. Lines :69 and :96 match their quotes but contradict the allocation (B1).
- **HF-06b:** :27, :31-35, :114, :141, CSV :32.
- **HF-05:** :18, :22-24, :27, :29, :35-39, :45-52, :64, :78-95, :105-117, :188.
- **HF-07a:** :56, :61-63, :70, :152-156, :166, full CSV (70 field rows, 7 groups).
- **HF-09:** :22, :46-55, :175-176, :195, :290.
- **HF-03a:** :46. **HF-04a:** :24, :63 (phrases confirmed by grep). **HF-07b:** :74-81.
- **TH-06:** :40-42, :50, :60-67, :81, :92, :94, :115-122, :130-136, :182, :184, :201, :265, :267, :279-282, :286, :316-330, :340, :360.
- **TH-03:** :171, :173. **TH-14:** :73, :78, :98, :101, :111. **TH-11:** :42, :45, :93, :103, :120, :143. **TH-01:** :153.
- **TRACKING:** :221, :237, :248, :250, :263.
- **Hashes:** not recomputed. The 18 stated hashes rest on the coordinator's `check-drift-schemas.log` (0 mismatches) and the "every stated dependency hash matches" line in `paper-check.log`.

**Walked trace SM (:529-533):**
- SM.1: E02, draft to imported (HF-05 :81).
- SM.2: E03, imported to structurally valid. The structural gate checks only reference shape (:50, :82).
- SM.3: E09, structurally valid to draft. The semantic gate checks the ID exists (:51, :88), and the failure fields match :105-114.
- As a replacement candidate, the same step is E12 to rejected-reload (:91).

It holds. SA and SI also match HF-05 :81-84, :87 and :95.

## Commands and receipts
I ran no commands; this session had no shell. I relied on these coordinator receipts in `artifacts/handoff-8-2026-09-16/tasks/SC-04/coordinator-candidate/`:
- **`exits.txt`:** check:scope, check:docs, check:project, check:drift, the schema-folder drift check and the paper check, all exit 0.
- **`identity.txt`, `check-scope.log`:** one changed file, classed documentation-only.
- **`check-drift.log`:** 292 hashes, 0 mismatches.
- **`check-drift-schemas.log`:** 18 hashes, 0 mismatches.
- **`paper-check.log`:** checks 10/10, negative controls 6/6.
- **`candidate-sha256.txt`:** `56154770…` (not recomputed).
- **`check-docs.log`, `check-project.log`:** both passed.

I read `check_schema.py` in full.

## Model and write confirmation
- **Model:** the runtime context names Opus 5 (`claude-opus-5[1m]`). I can't verify that by self-description.
- **CLAUDE_EFFORT:** unavailable. No environment access was exposed to me.
- **Writes:** none. I wrote, edited and committed nothing.