# SC-08 review R3

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

# SC-08 review R3: candidate 57bd51244022d39525187fb47dd51f7dabc2cfe7 (attempt A3)

**Verdict: PASS+NOTES.** Evidence level 3: I walked two scenarios step by step against HF-05's edges and checked every other claim against file:line. Level 4 was not reached in this session. I had no shell tool, so every command result below comes from the coordinator's receipts.

The candidate file is clean. One problem sits outside it: SC-01 still names SC-08 fields this candidate removes. Re-pointing SC-01's hash at integration would pass the drift check and hide that. Note N4 lists the exact edits needed.

## Blocking findings
None against the candidate. Notes N1 to N3 break no definition-of-done item.

## Findings the repair had to close
- **B1 (repaired).** Every reference field now names exactly one family:
  - T1: `affiliation_ids` (line 165).
  - T2: lines 207–215, with DT2-04 at line 240.
  - T3: the six subject fields at lines 273–278, and the kind table at 282–295.
  - T4: the eight subject arrays at lines 349–356.
  - T5: grant and prerequisite arrays at lines 412–418.
  - Line 135 now puts "the field's one family as `expected_family` (HF-05 line 108)". HF-05 line 108 reads "Required definition family, or explicit null". A search for multi-family References cells returned nothing. The old field names appear nowhere else in the file.
- **DT2-04 is the minimum and preserves the admitted rule.** The old `line_speaker_ids` was a required id-string per line (base line 209), so each line already had exactly one speaker.
- **B5, SC-08 part (a stated seam).** The F-07 row says "unresolved: three families, no SC-08 field (Seam 8)" (line 77). Seam 8 is at line 542, and DT3-06 at line 321.
  - SC-06 does type F-07 as three families, and HF-07a keeps them as separate arrays (CSV lines 56–58).
  - DT3-06 refuses only `candidate` and `established` companion entries. The only Bible companion is Prototype (BIBLE line 850), so nothing currently admissible is refused.
  - No companion family is chosen, so no open question is answered.
  - The semantic gate fits HF-05 line 51 ("Unknown required rules block that content's admission").
- **A16 (repaired).** The exact wording is at lines 218 and 538, and the save-table cell at line 482 now says "per Seam 6". HF-06b CSV line 21 supports it ("discovery or unlock knowledge … keyed by the exchange's ID").
- **EV-0428 N2 and N6 (repaired).** IV-07 at line 130 carries the read's wording. Line 167 cites "SC-04 line 236, `BossDefinition.narrative_identity_id`", which matches SC-04 line 236.
- **Stale language (repaired).** The amendment wording is at line 26 and the slot-row wording at lines 360 and 422. Sibling statuses are fixed at lines 73–77 and 528, and the provenance sentence at line 5.
- **Save treatment (unchanged).** It still matches HF-06b: N-012, N-056 and N-057 are `immutable-by-id`; N-017 is `json-projection` with both groups; N-058 and N-059 are excluded. The only durable fields are HF-07a CSV lines 8 and 10, as shown at lines 92–93 and 484–485.

## Definition of done
1. **Scope and rows (met, level 2).**
   - Row allocation is at lines 42–49 and exclusions at 53–57.
   - Foreign rows resolve at lines 71–81. F-01, F-05 and F-06 match HF-06a lines 66, 70 and 71.
2. **Per-type contract (met, level 3).** Each type has fields, identity and version rules, references, diagnostics and one illustrative record: T1 at 157–197, T2 at 199–259, T3 at 261–340, T4 at 342–402, T5 at 404–463. The reviewer counts at line 36 match the file (17 type diagnostics, 8 seams, 9 resolution rows).
3. **Save projection and qualification (met, level 2).** Lines 477–500, checked against HF-06b CSV lines 21, 26 and 65–68, HF-07a CSV lines 8–10, and HF-07b lines 135 and 139.
4. **Symbolic values (met, level 2).** Parameters are at lines 502–524. Illustrative labels appear at lines 191, 244, 325, 388, 449 and 467. No value or roster appears.

## Non-blocking notes
- **N1: SC-06 citation off by one.** In the worktree (base bytes), SC-06 line 39 is `DeviceDefinition`, lines 40–42 are the three companion types, and line 43 is blank.
  - Lines 27, 77 and 542: change "lines 41 to 43" to **"lines 40 to 42"**.
  - The paper check does not catch this.
- **N2: DC-06 contradicts the new field type.**
  - Line 107 says speaker arrays permit repeats; DC-06 at line 144 rejects any value that "repeats inside one array". The retained model follows line 107 (check_sc08.py lines 331–334).
  - Proposed DC-06 check: **"A nonempty reference value is not an ID shape, or a value repeats inside one `array of id-string`."**
  - This also widens the admitted rule: the old `line_speaker_ids` could not repeat (base lines 104 and 209). Add to line 688: **"Unlike the former `line_speaker_ids`, the per-line speaker arrays permit repeats, so a speaker may speak more than one line."**
- **N3: stale evidence-limit sentence.** At line 702, "This worktree's base predates them…" is false at base 234c1d7, where SC-03 and SC-04 are present. Replace with: **"Attempt 2's worktree base predated them, so its checks used the integration view named under Procedure performed; attempt 3's closure base contains both, and the coordinator re-points their hashes and line numbers at integration."**
- **N4: integration condition (the SC-01 problem above).** SC-01 still cites the old SC-08:
  - SC-01 lines 135 and 541 name `participant_ids` and `line_speaker_ids`. Replace them with `participant_character_ids` and `line_speaker_character_ids`.
  - SC-01 lines 23, 131, 133, 135, 541 and 547 cite SC-08 line numbers. Re-point 57→59, 88→90, 89→91, 121→124, 203→206 and 272→289.
  - SC-01 cannot be edited in this candidate, so the coordinator's integration step must make these changes.
- **N5: DR-01 does not state `expected_family`.** At line 155, append: **"`expected_family` T4 for `profile.discoveries` and T5 for `profile.unlocks`"**.
- **N6: carried seam, omission class.** SC-06 line 340 still expects inbound companion glossary entries, which DT3-06 now refuses. This belongs to TH-20 under B5.
- **SC-03 re-pointing (by content).** Every cited SC-03 statement is correct at base lines 39, 41, 61, 171, 266 and 405. On main (SC-03 attempt 3) the same content sits at lines 61, 168, 264 and 402.

## Scenario walks
- **WM (lines 562–568).** E02 import passes. At E03, `region.illustrative_absent` has ID shape. Every other structural check passes; for example, DT2-04 finds exactly one speaker at each index. At the semantic gate the ID resolves nowhere, so DC-07 raises `missing_id` with the single family F-05 and referrer `eligible_region_ids[0]`. Because this is a replacement candidate, it leaves by E12, which matches HF-05 lines 91, 108 and 111. No other check fires.
- **WD (lines 611–617).** Structural checks pass, then DT4-02 fires and the candidate leaves by E09, which matches HF-05 line 88.

## Citations sampled (all confirmed except N1)
- **HF-05:** lines 22, 51, 87–92, 108 and 111.
- **SC-04:** line 236 and line 408.
- **SC-03 at base:** lines 39, 41, 61, 171, 266 and 405.
- **SC-06:** lines 41–43 are wrong (N1).
- **HF-06a:** lines 66 and 70–72.
- **HF-06b CSV:** N-012, N-017 and N-056–N-059.
- **HF-07a CSV:** lines 8–10, 24 and 56–58.
- **Others:** HF-07b lines 135 and 139, HF-04a line 24, BIBLE lines 847–853.

## Paper check gaps
- A19 and A20 only look for strings.
- A18 counts families per field (structural), but its test of the common-diagnostics text is still a string match.
- Nothing tests DC-06 against the field types (N2), whether cited line numbers carry the cited content (N1), or files that consume SC-08 (N4).
- RC-07 tests `candidate` but not `established` for DT3-06.

## Commands (all coordinator-supplied receipts, not run by me)
Source: coordinator-candidate-A3/exits.txt.
- `check:scope`, `check:docs`, `check:project` and `check:drift`: exit 0.
- `node scripts/check-drift.mjs --sections docs/tech/schemas`: exit 1. The only mismatch is SC-01 line 23's stated hash for SC-08, not a hash stated inside SC-08.
- Paper check: 25 assertions passed; 22 of 22 negative controls failed on target.
- Candidate SHA256: `ba6eb4c8…1bcc`. identity.txt shows one changed path.

I ran no commands.

## Model, effort and write confirmation
- **Model:** the runtime reports `claude-opus-5[1m]`. AGENTS.md pins Fable 5.1 medium for consequential review. If this lane was meant to be Fable, running on Opus 5 is a substitution for you to record.
- **Effort:** `CLAUDE_EFFORT` is not exposed to me, so it is unavailable.
- **Writes:** I wrote, edited and committed nothing.

Files reviewed:
- /home/andrew/Projects/scrapkeep-wt-SC-08-A3/docs/tech/schemas/SC-08.md
- /home/andrew/Projects/scrapkeep/docs/tech/schemas/SC-01.md
- /home/andrew/Projects/scrapkeep-wt-SC-08-A3/docs/tech/schemas/SC-06.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-08/coordinator-candidate-A3/check_sc08.py