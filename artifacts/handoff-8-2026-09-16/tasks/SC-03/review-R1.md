# SC-03 review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**SC-03 review R1: candidate `1a4eb9f5843a794748b57955a40f61f7821804c7`**

## Verdict: PASS+NOTES

Nothing blocks. The part the packet flagged, how the five rows map to the three types, agrees with every admitted row I checked. SC-01 failed on this point because it assigned a row to a type the row's text doesn't describe. SC-03 doesn't do that. The notes below are sourcing and precision fixes. None of them breaks a definition-of-done item.

**Evidence level:**
- **Level 2:** every citation below, checked at its file and line.
- **Level 3:** the three admission traces, walked against HF-05's edge table.
- **Level 4:** hashes, drift, scope, docs, project and the paper check. These are the coordinator's receipts. I read them but could not rerun them, because I have no shell.
- **Coordinator receipts I relied on:** `identity.txt`, `exits.txt`, `candidate-sha256.txt`, `paper-check.log`, `paper-check/source-manifest.json`, `check-drift-schemas.log`, `check-drift.log`, `check-scope.log`, `check-docs.log`, `check-project.log`, and `check_sc03.py`, which I read in full.

Candidate file: `/home/andrew/Projects/scrapkeep-wt-SC-03/docs/tech/schemas/SC-03.md` (461 lines). The card text in the packet matches BACKLOG.md:2261-2289 exactly.

## Definition-of-done items

1. **Scope, matrix rows and foreign definitions: met (level 2).**
   - The document covers three types over F-08, N-015, N-016, N-025 and N-026 (SC-03.md:37-41). These equal HF-06a line 142.
   - Foreign rows F-01, F-02, F-03, F-05, F-06 and F-07 are tabled with their producing cards (SC-03.md:49-56), matching HF-06a lines 66-72.
   - **Allocation check:**
     - N-026's rationale says "Fixed-secret recipe definitions (F-08)" (HF-06a:99), which is exactly the pattern HF-06a line 22 describes.
     - N-016 is "a compatibility declaration embedded in an item definition" (HF-06a:89), so `AttunementDeclaration` is correct.
     - Neither N-015 nor N-025 names a family row. Both describe item definitions that declare compatibility (HF-06a:88, :98).
     - HF-07a CSV line 28 credits `owned` to both rows, and line 30 gives one `item_id`, "the item definition's domain ID".
     - HF-06b:224 says "N-015 and N-025 project item IDs".
     - One type is therefore the only reading that fits the admitted save fields. No treatment or producing card changes, so HF-06a line 46's rule against re-treating a row in the consuming card is not triggered. The line 22 citation stretches that line (note 1).
2. **Fields, types, identity and version rules, references, diagnostics and one labelled example per type: met (levels 2-3).**
   - Field tables: SC-03.md:66-92, :136-143 and :163-178.
   - Identity and version rules IV-01 to IV-09: :204-214.
   - Diagnostics DG-01 to DG-18: :220-239.
   - One example per type, each marked "Illustrative, not canon.": :98, :147, :184.
3. **Save treatment, round-trip expectations and executable obligation: met (level 2).**
   - The save column, case and codec for each type match HF-06b rows N-015, N-016, N-025, F-08 and N-026 (HF-06b:118, :133, :134, :143, :144). The HF-07a CSV line numbers in the candidate map to the correct field paths, and each field's `projection_group` belongs to its type's rows.
   - `AttunementDeclaration` has an explicit immutable exclusion (SC-03.md:250).
   - Round-trip expectations RT-01 to RT-04 are at :272-277, the JSON example and decode table at :281-321, and qualification obligations QO-01 to QO-05 at :327-333.
4. **Unchosen values symbolic, no canon: met (level 2), with sourcing notes 2 and 3.**
   - Every field value is either `unset` with a question ID or points to a parameter row. Rows SP-06 to SP-14 and SP-16 to SP-24 are unset and each names a question.
   - All identifiers in the examples are placeholders.
   - HF-04a line 24 is quoted within its scope (SC-03.md:15, :159). HF-04a:24 limits the rule to `EncounterRandomState`.

**Seven headings:** present. Paper-check C01 passed (coordinator receipt).
**Hashes and drift:** the candidate states 16 hashes. `check-drift-schemas.log` reports 16 hashes, 0 mismatches and no line for the file. The four hashes in the source manifest (HF-06a CSV, HF-06b CSV, HF-07a CSV, HF-05) match the stated ones (receipt).
**Packet bans:** only `docs/tech/schemas/SC-03.md` changed (`identity.txt`). There is no Resource, no roster and no product value.

## Blocking findings
None.

## Non-blocking notes
1. **SC-03.md:35 stretches HF-06a line 22.** Line 22 lets a family row and a noun row describe one type. SC-03 applies it to two noun rows. The merge is supported by HF-07a CSV lines 28 and 30 and HF-06b:224, but not by line 22.
   - Fix: cite those lines as the reason for the merge, and ask TH-20 to record the pairing.
2. **SP-01 (`1`, SC-03.md:353) and IV-05 (:210) cite HF-09 line 376.** That line is about the save file's `schema_version` 1, not a definition's field-layout version.
   - Fix: label `1` as this card's own starting version for the definition types (HF-05 line 50 "supported schema representation"; HF-05 line 18 on grammar ownership).
3. **SP-15 (SC-03.md:367) cites only HF-07a line 46.** That line supports "no numeric type". It does not support the chosen set `bool`, `string`, `id-string`. TH-08 EP-27 (:289) and TH-09 LP-22 (:275) keep instance-field value types unset under Q-P14. SP-14 (:366) also leaves value types out of its Q-P14 list.
   - Fix: add Q-P14 to SP-15 and label the set as this card's own choice.
4. **SC-03.md:19 and :94 misquote TH-05 CP-15.** TH-05:284 says material "is consumed as collected and the milestone unlocks and the rebuilt chassis are its only durable trace", not that it leaves no durable trace. The conclusion (no material field on items) still holds.
5. **SC-03.md:58 cites HF-06a line 67 for mobility actions being F-02 definitions.** Line 67 doesn't say that. HF-06a:92 (N-019) and :66 (F-01) do.
6. **SC-03.md:241 says "HF-05's eleven fields" but lists nine.** It leaves out `catalogue_revision` and `message_key`. The AM.3 trace (:414) also omits five fields. Nothing is contradicted.
7. **The loot-assembly reference to F-07 has no field.** HF-06a:89 (N-016) says "Companion assembly through loot references F-07". SC-03.md:94 and Seam 4 (:388) push this to Q-P15. BACKLOG:3016 does put assembly under Q-P15, so deferring is valid. But line 89 makes only the slots symbolic, not the reference.
   - Fix: add a question case showing the field a Q-P15 answer would add.
8. **AT-01 reads the run's character (HF-07a CSV line 16) and device and companion presence.** TH-08 EQ-03 (:58) limits the rebuild to exactly three inputs. The character can be derived from the selected tree IDs through F-01 (HF-06a:66), and presence is unset in TH-08 itself (EP-31, :293).
   - Fix: say the character is derived that way, or raise it with TH-20.
9. **IV-08 (SC-03.md:213) has a real consequence.** Changing an item's instance-field declarations makes every save holding that item fail validation at the new revision, because an HF-09 step can't name keys inside `instance_fields` (HF-09:52). This is the writer's follow-up and should go to TH-20 or HF-09. It contradicts no admitted line.
10. **Small precision gaps:**
    - SC-03.md:11 says the admission states are at lines 68-73; they run to line 74.
    - AV assumes `placeholder.item.b` is valid but gives no record for it.
    - AV.3 doesn't say the behaviours accept `placeholder_magnitude`.
    - BIBLE.md and TADR-003 are pinned only by the base commit, not by a file hash.
    - Seams 6 to 8 leave recoverable metal, the behaviour registry and `mount_id` without an owner. That is correctly stated, not decided.

## Paper check: what it tests and what it misses
It is more than a string check:
- It compares type rows, treatment and producing card with the HF-06a CSV.
- It compares save column, case and codec with the HF-06b CSV.
- It checks projection fields, their groups and CSV line numbers against the HF-07a CSV.
- It checks every trace step against the edge table parsed from HF-05 and that the steps chain.
- It parses the JSON example and checks string IDs, sort orders, owned references and instance-field keys and types.
- It recomputes the dependency hashes.
- All 7 negative controls failed as intended (`paper-check.log`: 776 passed, 0 failed).

Obligations it does not test:
- **C02** doesn't compare the type allocation with HF-06a rationale text. This is the same gap that let SC-01's problem through.
- **C10's round trip is circular.** It runs `json.dumps` and `json.loads` on the example as parsed from the Markdown (`check_sc03.py:314-315`), which can't fail. Only its coverage and placeholder checks do real work.
- **C12** only checks that a parameter row cites some "line N" (:438-444). It doesn't check that the line states the value, which is why notes 2 and 3 passed.
- **C05 and C09** check gate-to-edge mapping and edge chains. They don't check that an example record really passes or fails each DG rule.
- **No check covers:** cited line content anywhere, the HF-04a line 24 scoping, the "no open question answered" rule, the QO table, or whether each HF-07a CSV `source` cell credits the right HF-06b row.

## Scenario walks (level 3)
- **AI (SC-03.md:415-416):**
  - E02 takes the candidate from draft to imported (HF-05:81).
  - DG-11 is a structural check. Duplicate tree IDs break TH-07 PT-07's one-lineage rule (:63).
  - E08 (HF-05:87) takes an initial candidate from imported back to draft; E11 (:90) is the replacement version.
  - Rule `sc03.recipe_endpoints_shape` matches DG-11 (SC-03.md:232). Correct.
- **AM (:412-414):**
  - E02, then E03 (HF-05:82). `placeholder.attack.absent` is a well-formed ID, so the structural gate at HF-05:50 passes.
  - E09 (HF-05:88) returns the candidate to draft.
  - `missing_id` is a valid code (HF-05:105), and the referrer uses the "definition ID and field path" form (HF-05:111). E12 (:91) is the replacement version. Correct.
- **AV (:408-411):** E02, E03, E04 (HF-05:83), E05 (HF-05:84). The preamble (:400) places admission at Session's barrier, so no E16 wait is needed. I checked the ItemDefinition and RecipeDefinition examples by hand against DG-05 to DG-11 and they pass. Correct, apart from the item.b gap in note 10.

## Citations sampled
All say what the candidate claims unless marked.
- **HF-06a:** lines 22 (applied beyond its wording, note 1), 42, 46, 54, 66-73, 88, 89 (note 7), 95, 98, 99, 142, 166, 168, 171. Line 67 is wrong for the mobility claim (note 5).
- **HF-06b:** lines 25-27, 32, 34, 36, 57, 61, 64, 118, 133, 134, 143, 144, 209, 224.
- **HF-05:** lines 18, 22-24, 27, 29, 35-41, 45, 49-52, 56, 58, 68-74 (note 10), 81-95, 101-117, 119, 160.
- **HF-07a:** lines 24, 37, 46, 56, 60-64, 223; CSV lines 9, 16, 27-38, 41.
- **HF-07b:** lines 76, 79, 85, 88, 129, 130, 135, 139, 308.
- **HF-09:** lines 52, 121, 122, 124, 175, 178, 195, 324, 325. Line 376 is misapplied (note 2).
- **HF-03a:** lines 23, 34, 45, 48, 49, 56. **HF-04a:** lines 24, 44, 47, 48, 50.
- **TH-08:** lines 42-44, 58, 63, 66, 67, 77-86, 96, 110, 112, 117, 130, 133, 178, 180, 186, 191, 284-291, 308.
- **TH-09:** lines 43-45, 63, 66-68, 77-86, 95, 97, 103, 112, 114, 131, 135, 176, 179, 180, 216, 224, 270-275, 296, 400.
- **TH-05:** lines 35, 168, 378. Line 284 is misquoted (note 4).
- **TH-07:** lines 59, 62, 63, 322, 323, 362. **PD-02:** lines 78, 89, 143.
- **BIBLE:** lines 394, 400, 402, 436, 446, 450, 452, 454, 460-465, 529, 548-554, 558-564, 893-895.
- **TADR-003:** lines 23, 25, 27, 29, 31, 35, 41, 45.
- **Context7 retrievals:** `q1.txt:123` (inner-class serialization), `q2.txt:72` (shallow vs deep duplicate), `q3.txt:53,59` (UID from path and project name).
- **Hashes:** I didn't compute any. I relied on `check-drift-schemas.log` and `source-manifest.json`.

## Commands
I ran none; I only read files. The coordinator's `exits.txt` reports exit 0 for each:
- `npm run -s check:scope -- 254f8e1… 1a4eb9f… --no-build`
- `npm run -s check:docs`
- `npm run -s check:project`
- `npm run -s check:drift`
- `node scripts/check-drift.mjs --sections docs/tech/schemas`
- `python3 …/coordinator-candidate/check_sc03.py /home/andrew/Projects/scrapkeep-wt-SC-03 --out …/paper-check`

## Runtime and writes
- **Model:** `claude-opus-5[1m]`, per the host's environment statement. A model can't confirm its own identity. This matches the per-card routing to Opus 5 at EV-0367.
- **Effort:** the effort in effect wasn't readable. `CLAUDE_EFFORT` is unavailable because I had no environment access.
- **Writes:** none. I only read files.

Files relevant to this review:
- `/home/andrew/Projects/scrapkeep-wt-SC-03/docs/tech/schemas/SC-03.md`
- `/home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-03/review-packet.md`
- `/home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-03/coordinator-candidate/check_sc03.py`
- `/home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-03/coordinator-candidate/paper-check.log`