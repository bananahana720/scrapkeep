# SC-03 review R2

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**SC-03 review R2: candidate `addccfedc03caa5372dbea234c91edf6e279fbbe` (attempt SC-03-A2)**

## Verdict: PASS+NOTES

Nothing blocks. Each replacement reference now names one expected family: F-02 for attacks, N-021 for mobility abilities. That matches the revised HF-06a rows N-016 and N-019 and HF-05 lines 22 and 108. No save field, projection, matrix row or treatment changed. RP-02 comes from neither of its cited sources, so it is this contract's own choice, but it doesn't answer an open question. None of the notes breaks a definition-of-done item.

**Evidence level**
- **Level 2:** every citation, checked at file:line in the main checkout. The packet says only the board changed after the base.
- **Level 3:** the AV admission trace walked step by step, and a manual comparison of the candidate against the admitted SC-03 on main.
- **Level 4 claims rest only on coordinator receipts.** I have no shell and ran nothing. The receipts are `coordinator-candidate-A2/identity.txt`, `exits.txt`, `candidate-sha256.txt`, `check-drift*.log`, `check-scope.log`, `check-docs.log`, `check-project.log`, `paper-check.log` and `source-manifest.json`. I read `check_sc03.py` lines 200-275 and 510-579.

## Packet questions
- **One family per reference: met.**
  - Fields at SC-03.md:86-89 are `replaces_attack_id` and `provides_attack_id` (target F-02), and `replaces_ability_id` and `provides_ability_id` (target N-021).
  - RP-01 and RP-03 (:101, :103) and DG-19 (:254, structural, E08/E11) enforce them.
  - N-021 is now in the foreign-reference table (:57).
  - The paragraph at :59 and Seam 2 (:399) agree with HF-06a:89 (N-016), :92 (N-019), :66 (F-01) and :94 (N-021), and with HF-05:22 and :108.
  - R1 note 5 is resolved: line 67 is now cited only for F-02 attacks.
- **RP-02 (same-kind replacement only): the contract's own choice, not sourced (note 1).**
  - Its sources, HF-06a:89 and PD-02:89, say what is replaced and how a replacement is shown. Neither says the replacing action must be the same kind.
  - It doesn't answer Q-P22 (BACKLOG:3104-3114 asks which movement or attack transformations enter scope), because QC-07 (:445) keeps cross-kind open for a later revision.
- **Save, projection, row and treatment: unchanged.** I compared the candidate with main's admitted SC-03 by eye, with no diff tool:

  | Part | Candidate | Base |
  | --- | --- | --- |
  | Type table | :37-41 | :37-41 |
  | Save treatment table | :262-266 | :247-251 |
  | Projection field table | :270-279 | :255-264 |
  | JSON example | :296-325 | :281-310 |
  | Parameter rows SP-01 to SP-24 | :368-391 | :353-376 |

  All five are identical. HF-06b:134 (N-016 `immutable-by-id`) matches :265.
- **The writer's recorded gap is correctly disclosed and left open.** Seam 2 (:399) says `effects[].action_ids` targets F-02 only. N-016 revised replacement only, and TH-08 EC-01 (:77) allows "the action or attribute", so `attribute_keys` still reaches a mobility ability. No admitted row is contradicted. It stays a follow-up for SC-02 and TH-20 (note 4).

## Definition-of-done items
1. **Scope, rows and foreign definitions: met (level 2).**
   - Types F-08, N-015, N-016, N-025 and N-026 (:37-41) equal HF-06a:142.
   - Foreign rows F-01, F-02, F-03, F-05, F-06, F-07 and N-021 (:49-57) match the producing cards at HF-06a:66-72 and :94.
   - Sibling states (:23, :51-57) match TRACKING:173-180: SC-01 and SC-02 in progress; SC-04, SC-05, SC-06 and SC-08 done.
2. **Fields, types, identity, references, diagnostics and examples: met (levels 2-3).**
   - Field tables :67-95, :150-157 and :177-192; rules IV-01 to IV-09 at :218-228; diagnostics DG-01 to DG-19 at :234-254.
   - Each example is labelled "Illustrative, not canon." (:109, :161, :198).
   - The ItemDefinition example (:111-135) is now a transformation. By hand it satisfies DG-05, DG-06, DG-08, DG-09 and RP-01/RP-02.
3. **Save treatment, round trip and qualification obligation: met (level 2), unchanged from R1.**
   - Save treatment :262-281, round-trip rows RT-01 to RT-04 :289-292, JSON example and decode table :296-336, obligations QO-01 to QO-05 :344-348.
   - QO-05 now covers DG-01 to DG-19.
   - HF-07a CSV rows 28-34 match the cited paths.
4. **Values symbolic, no canon: met (level 2).**
   - Every new field value is SP-13, which Q-P22 owns (:380).
   - The new placeholders `placeholder.ability.a` and `.b` are not canon.
   - HF-04a line 24 is still cited within its scope (:15, :173).

**Other packet items**
- **Seven headings:** present (:3, :25, :413, :447, :460, :466, :476).
- **Drift (receipt):** `check-drift-schemas.log` shows 88 hashes and 1 mismatch, `SC-08.md:24` stating SC-03's old hash. SC-03 itself has no line, as the packet expects.
- **Scope (receipt):** `identity.txt` shows only `docs/tech/schemas/SC-03.md` changed, in one commit, with a clean tree.

## Blocking findings
None.

## Non-blocking notes
1. **RP-02 is a contract choice presented as sourced (:102).** Also, QC-07 (:445) names no question and says cross-kind needs "a new cross-kind replacement field". The four existing fields could already express it if RP-02 and DG-19 were relaxed.
   - Fix: label RP-02 as this contract's choice, cite Q-P22 and SP-13, and restate QC-07 as a relaxed rule rather than a new field.
2. **Stale source base (:5).** Line 5 still says every line reference is at base `254f8e1`. The revised text this attempt relies on (HF-06a:66, :89, :92, :94, "as revised under FR-07" at :9) exists only at `43a8f12`, which :474 names. The stated HF-06a hash is the post-FR-07 one (drift receipt).
   - Fix: re-point line 5 to `43a8f12ad64b63a7352adb6cefab9f111a1cb5e8`.
3. **Overbroad direction sentence (:47).** "The foreign card names nothing here" contradicts the wording of HF-06a:75 (N-002 region reward themes reference SC-03 items). It also sits awkwardly beside SC-03's own Seam 5 (:405, N-057 glossary references to items).
   - Why it doesn't block: admitted SC-05 Seam 2 (SC-05.md:486-491) already chose the derived direction against N-002 and left it to TH-20. SC-03 defines no inbound field, so no type, field or treatment conflicts.
   - Fix: limit the sentence to the references in this table.
4. **`effects[].action_ids` gap (Seam 2, :399).** It is disclosed and correctly not closed. The HF-06a row list in the re-verification triggers (:462) still omits N-019 and N-021; :464 covers them only for RP-01 to RP-03 and DG-19.
5. **No trace exercises a replacement failure.** No wrong-family reference and no RP-01/RP-02 violation is traced. The card requires only the three traces present.
6. **R1 notes 1-4 and 6-10 carry over unchanged.** Example: :256 says "eleven fields" but lists seven. Line 22's `artifacts/local/tasks/SC-03/context7/` does not exist; the retrievals are at `artifacts/local/tasks/SC-03/writer/context7/q1-3.txt` in the main checkout. These are not regressions.

## Paper check: what it tests and what it misses
**What it tests:**
- C14 (`check_sc03.py:233-239`) requires each reference target cell to name exactly one family.
- C15 (:241-267) checks:
  - there is no `*_action_id` field;
  - all four `replaces`/`provides` × `attack`/`ability` fields are present;
  - attack fields target F-02 and ability fields target N-021;
  - N-021's producing card matches HF-06a;
  - the example names exactly one replaced kind and provides only that kind.
- C16 (:268) requires a structural `sc03.replacement_kind` diagnostic.
- NC8 (:526) restores the first attempt's F-02-only fields and fails C15 and C10. NC9 (:527) gives one field two families and fails C07, C14 and C15.
- Receipt `paper-check.log`: 869 assertions passed, 0 failed, 82 check groups, negative controls 9 of 9 caught.

**Obligations it does not test:**
- C15 hard-codes attack→F-02 and ability→N-021 (:244) instead of reading them from HF-06a N-016, so a change to that row would go unnoticed.
- Nothing checks that RP-02's cited lines actually state the rule (note 1).
- Nothing checks that line 5's base matches the cited line content (note 2).
- Nothing checks the direction prose (note 3).
- Nothing checks that save, projection and parameter rows are unchanged from the base. C08 checks agreement with HF-06b and HF-07a, not absence of change; I compared by hand.
- C16 checks only that DG-19 exists and is structural, not that the example passes or a bad entry fails.
- R1's gaps remain: C10's round trip is circular, C12 only checks that a "line N" is cited, and no check reads cited line content.

NC8 also shows the retained C07 alone does not catch the old F-02-only field. Only the name-based C15 does.

## Scenario walk (level 3)
**AV (:423-426):**
1. **E02** draft→imported (HF-05:81).
2. **E03** imported→structurally valid (HF-05:82, structural gate :50). The replacement entry has `replaces_ability_id`/`provides_ability_id` set and both attack fields `""`, so RP-01, RP-02 and DG-19 pass. `item_class` is `transformation` with a non-empty `replacements`, so DG-05 passes.
3. **E04** →semantically valid (HF-05:83, semantic gate :51). DG-13 resolves both ability IDs as N-021 definitions (preamble :415) with family `ability` (HF-06a:94).
4. **E05** →admitted (HF-05:84).

Correct.

AM (:427-429) and AI (:430-431) are unchanged from R1. Their edges E09/E12 and E08/E11 match HF-05:87-88 and :90-91.

## Citations sampled
All say what the candidate claims unless noted.
- **HF-06a:** 22, 42, 46, 54, 66, 67, 89, 92, 94 and 95 (N-022 excluded, TH-05), 142. Also the HF-06a CSV rows for F-08, N-015, N-025 and N-026.
- **HF-05:** 18, 22, 50, 51, 81-84, 87-91, 105, 108, 111, 117.
- **HF-06b:** 133, 134.
- **HF-07a CSV:** rows 27-34.
- **TH-08:** 58, 63, 66, 67, 77, 79, 84, 178, 180, 191.
- **PD-02:** 89. It supports showing a replacement as a replacement, not RP-02's same-kind rule (note 1).
- **BIBLE:** 450, 452, 454.
- **BACKLOG:** Q-P19 3062-3072, Q-P22 3104-3114.
- **TRACKING:** 152, 173-180.
- **SC-05.md (admitted):** 78, 348, 486-491.
- **SC-06.md (admitted):** 336-337.
- **Hashes:** I computed none. The candidate hash `2a59d68d…09f8fe` comes from receipts `candidate-sha256.txt` and `source-manifest.json`. The dependency hashes' agreement comes from receipts `check-drift.log` (349 hashes, 0 mismatches) and `check-drift-schemas.log`.

## Commands
I ran none (no shell). Coordinator receipt `exits.txt` reports:
- `npm run -s check:scope -- 43a8f12… addccfed… --no-build`: exit 0
- `npm run -s check:docs`: exit 0 (163 files, 0 failures)
- `npm run -s check:project`: exit 0
- `npm run -s check:drift`: exit 0
- `node scripts/check-drift.mjs --sections docs/tech/schemas`: exit 1, only the expected `SC-08.md:24` line
- `python3 …/coordinator-candidate-A2/check_sc03.py /home/andrew/Projects/scrapkeep-wt-SC-03-A2 --out …/paper-check`: exit 0

## Runtime and writes
- **Model:** `claude-opus-5[1m]`, per the host environment statement. A model can't verify its own identity. This matches the Opus 5 per-card review routing at EV-0367.
- **Effort:** `CLAUDE_EFFORT` is unavailable; I have no environment or shell access.
- **Writes:** none. I only read files and made no edits or commits.

Files relevant to this review:
- /home/andrew/Projects/scrapkeep-wt-SC-03-A2/docs/tech/schemas/SC-03.md
- /home/andrew/Projects/scrapkeep/docs/tech/schemas/SC-03.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-03/review-packet-R2.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-03/coordinator-candidate-A2/check_sc03.py
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-03/coordinator-candidate-A2/paper-check.log
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-03/coordinator-candidate-A2/check-drift-schemas.log
- /home/andrew/Projects/scrapkeep/docs/tech/sections/HF-06a-schema-inventory.md
- /home/andrew/Projects/scrapkeep/docs/tech/schemas/SC-05.md