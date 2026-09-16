# SC-03 review R3

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**Verdict: PASS+NOTES.** Candidate `553507b31ec51285f025448e4a4470ca71d87a29` is SC-03 attempt A3, reviewed in round R3. None of the notes below breaks a definition-of-done item.

**Evidence level:** mostly 2 (I checked each citation against the source file and line). The C1 gate and the missing-reference trace reach level 3 (walked step by step). Everything at level 4 comes from the coordinator's receipts. I ran no commands: I had only Read, Grep and Glob, so I could neither run a shell nor compute hashes.

**Identity.** `.git/refs/heads/wt/SC-03-A3` resolves to `553507b3…`. According to the coordinator's `identity.txt`, the parent is `234c1d7`, `SC-03.md` is the only changed path and the worktree is clean. According to `candidate-sha256.txt`, the file hash is `50ad21e0…`. I compared the candidate file against the admitted file in the main checkout line by line; every change is listed below.

## Change-request findings
- **C1 (blocking in the read): repaired.** The read required an unresolved gate that admission enforces (`integrated-read-R1.md:22`; `assignment-closure.md:7`).
  - `SC-03.md:379`: SP-15 is now "unset; proposal `bool`, `string`, `id-string` held under Q-P14". Its sources are Q-P14, TH-08 line 289 and HF-07a line 46.
  - `:93`: the `value_type` cell reads "value set unset", and its rule points to DG-20.
  - `:252`: DG-20 is on the semantic gate, takes E09 or E12, and names the rule `sc03.instance_field_types_unset`.
  - `:271`: the supply row now waits for the answer, and the value is never a JSON number.
  - `:446`: the Q-P14 bullet repeats the gate.
  - To keep the valid trace consistent, the illustrative item and the JSON fragment now carry no instance field (`:132`, `:306`, `:412`).
  - The sources support this. TH-08 line 289 (EP-27) says: "The `instance_fields` key set and value types | unset | Q-P14". HF-05 line 51 says "Unknown required rules block that content's admission" and forbids an "implicit product answer". HF-07a line 46 limits numbers in the save aggregate to four named fields. BACKLOG:2992–3002 and TRACKING:240 show Q-P14's product half still unanswered.
- **A10: repaired.** `:19` and `:105` match TH-05 line 284 (CP-15). `:254` lists all eleven fields, which match HF-05 lines 105–115.
- **A11: repaired.** `:35` uses the read's wording; HF-07a CSV rows 28 and 30 and HF-06b line 224 support it. `:221` and SP-01 at `:365` now cite HF-05 line 50 instead of HF-09 line 376.
- **A12: repaired.** The direction sentence (`:47`), RP-02's "present choice" label (`:102`) and QC-07 (`:442`) all use the read's wording.
- **Stale seam and provenance: repaired.**
  - The sibling statuses at `:23`, `:51–57` and `:394–402` use the read's wording.
  - Grep for "concurrently", "admitted after the first attempt" and "bytes not cited" returns nothing.
  - `:5` was adapted to attempt 3 and still names the earlier bases.
- **Edits beyond the named rows**, all disclosed at `:473` and all applying the read's notes:
  - `:11`: admission states 68–74, which matches HF-05:68–74.
  - `:22`: retrieval location; `artifacts/local/tasks/SC-03/writer/context7/q1–q3.txt` exist.
  - `:412`: fixture assumptions.
  - `:459`: N-019/N-021 re-verification trigger.
  - `:396`: the A18 sentence in Seam 2.
  - `:461`: trigger-list status cleanup. Nothing else changed.

## Definition of done
1. **Scope and rows: met (level 2).** The types table at `:37–41` maps F-08, N-015, N-016, N-025 and N-026 one to one, matching HF-06a:142. Each of the seven outbound foreign rows (`:51–57`) names one row.
2. **Per type, fields through illustrative record: met (levels 2–3).** Every type has a field table (`:67–95`, `:147–154`, `:174–189`), the identity and version rules IV-01 to IV-09, diagnostics DG-01 to DG-20, and a labelled illustrative record (`:109`, `:158`, `:195`).
3. **Save treatment, round trip and qualification: met (level 2).**
   - Save treatment is at `:260–277`; the fields cited there match HF-07a CSV rows 28–31.
   - The round-trip expectations RT-01 to RT-04 and the illustrative fragment are at `:285–333`.
   - The qualification obligations QO-01 to QO-05 are at `:339–345`.
4. **Symbolic values: met (level 2).**
   - All 24 parameter rows carry a source line or a question ID. The count sentence at `:390` (4 + 1 + 19) is correct.
   - SP-15 is labelled a proposal and answers no open question.

## Missing-reference trace, walked (AM, `:424–426`)
- **AM.1:** E02 moves the candidate from draft to imported, as HF-05:81 allows.
- **AM.2:** E03 passes the structural gate, because HF-05:50 checks only that a reference is well formed.
- **AM.3:** E09 returns it to draft (HF-05:88) with `missing_id` (HF-05:105), `validate_candidate` (:106), the referrer as definition ID plus field path (:111) and the held operation (:114).
- **Replacement variant:** E12 goes to `rejected-reload` (HF-05:91), and HF-05:160 (T3.3) is the matching case.

**C1 gate, walked.** An item that declares an instance field while SP-15 is unset fails DG-20 at E04 and returns to draft through E09. That is consistent with HF-05:51.

## Blocking findings
None.

## Notes (non-blocking)
1. **DG-10 and DG-20 can both claim the same record.** DG-10 at `:242` fires on the structural gate (E08) when `value_type` is "outside SP-15's answered set". While SP-15 is unset, a literal reading rejects every declaration there, so DG-20 at `:252` (semantic, E09) never runs.
   - Admission refuses either way, so C1 still holds. What is ambiguous is which diagnostic and which edge the record gets.
   - Fix: start DG-10's condition with "Once SP-15 is answered,".
2. **`id_family` is still built around the proposal.** `:94`, DG-10 and `:271` are keyed to the proposed `id-string` value. They cannot fire while the gate holds, but a Q-P14 answer without `id-string` would leave a dead field that needs a new `schema_version`.
3. **QO-05 at `:345` still says "DG-01 to DG-19".** No trace or qualification obligation exercises DG-20.
4. **"TH-20 records this pairing" (`:35`) reads as present tense, but TH-20 is still queued** (TRACKING:161). The sentence is the read's mandated wording.
5. **`:477` still says "the concurrent SC cards".** The read did not name that line.
6. **The illustrative round trip no longer covers any instance-field value.** QO-03 at `:343` defers that until SP-15 is answered. This follows from C1 and is acceptable.

## What the paper check misses
I read the check script; its pass counts come from the coordinator's log.
- **What it checks:**
  - C17 (`check_sc03.py:270–283`) checks the actual table cells: SP-15 unset with the proposal label, DG-20's gate and edges, the illustrative item, and the empty JSON fragment.
  - C18 (`:285–310`) only checks whether required phrases are present or absent.
  - NC10–NC12 (`:570–572`) cover the named findings.
- **What it does not test:**
  - The DG-10/DG-20 overlap in note 1.
  - A regression of the `:271` supply row back to a fixed type mapping; nothing would catch it.
  - The Q-P14 bullet.
  - QO-05's range.
  - Whether A10–A12 are right beyond string presence.
  - Whether any cited line says what the contract claims; C13 compares hashes only.

## Citations sampled
All of these match the candidate's claims:
- TH-08:289
- HF-07a:46, :56, and CSV rows 28, 29, 30, 31
- HF-05:50, :51, :68–74, :81–91, :105–115, :108, :160
- TH-05:284
- HF-06b:224
- HF-06a:22, :88, :89, :92, :94, :142
- HF-04a:24 (limits the randomness rule to `EncounterRandomState`)
- BIBLE:450
- BACKLOG Q-P14 (2992–3002) and TRACKING:240 (Q-P14 still open)
- TRACKING:161 (TH-20 queued) and TRACKING:670 (candidate SHA, sha256, parent)
- The Context7 retrieval files

## Coordinator receipts (not rerun by me)
From `coordinator-candidate-A3/exits.txt` and the logs:

| Check | Exit | Result |
|---|---|---|
| `check:scope` | 0 | documentation-only, 1 path |
| `check:docs` | 0 | 0 failures |
| `check:project` | 0 | passed |
| `check:drift` | 0 | 349 hashes, 0 mismatches |
| `node scripts/check-drift.mjs --sections docs/tech/schemas` | 1 | 2 mismatches |
| paper check | 0 | 900 passed, 0 failed, 12 of 12 negative controls caught |

- **Schemas drift scan:** both mismatches are SC-01:20 and SC-08:24 still quoting SC-03's old hash, which the packet expects the coordinator to re-point. No line comes from SC-03's own citations. The acceptance item fits only under that reading: the scan does print lines naming SC-03.md, but none come from SC-03's own citations.
- **Hash claim:** the only support for "every stated dependency hash matches the attempt-3 base" is that scan and C13's pass.

## Runtime
- **Model:** the system prompt names `claude-opus-5[1m]`; I can't verify that from inside the session. TRACKING:670 records the intended routing as scrapkeep-reviewer-medium (claude-opus-5 high), which is not runtime evidence.
- **`CLAUDE_EFFORT`:** unavailable; this session has no environment access.

I wrote, edited and committed nothing. Relevant files:
- `/home/andrew/Projects/scrapkeep-wt-SC-03-A3/docs/tech/schemas/SC-03.md`
- `/home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-03/coordinator-candidate-A3/`