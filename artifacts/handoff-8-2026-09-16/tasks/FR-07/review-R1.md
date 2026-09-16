# FR-07 review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**FR-07 review R1: candidate `ed928434f026d06c85a44d21ed730183200cd697` (branch `wt/FR-07`, base `39295c4`)**

## Verdict: PASS+NOTES

**Evidence level:** 3. I compared the candidate files in the worktree with the main checkout line by line. For the command results I relied on the coordinator's level-4 receipts, which I read but could not rerun. None of the notes below breaks the card's definition of done.

For base bytes I read the main checkout (HEAD `8879d65`), because I could not run `git show 39295c4:`. The packet states that the cited foundation files have not changed since the base.

Receipts I relied on, all under `/home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/FR-07/coordinator-candidate/`:
- `exits.txt`: every command exited 0.
- `check-scope.log`: 44 paths, documentation-only.
- `check-drift.log`: 36 sections, 349 hashes, 0 mismatches.
- `check-drift-schemas.log`: 6 sections, 88 hashes, 0 mismatches.
- `check-docs.log` and `check-project.log`.
- `paper-check.log`: 106 checks, 0 failed, 8 of 8 controls caught.
- `retained/{HF-06a,HF-06b,HF-07a,HF-08,HF-09,TH-07}/log`: 37/0, 41/0, 967/967, 302/0, 384/0 and 36/0.
- `candidate-sha256.txt` and `identity.txt`.

## Definition of done

**1. Slot definition typed.** Met.
- **N-024 reworded:** `/home/andrew/Projects/scrapkeep-wt-FR-07/docs/tech/sections/HF-06a-schema-inventory.md:97` now types both the slot definition and the slot-tree definition. The treatment, producing card and question cell are unchanged.
- **The choice is admissible under HF-06a's own row rules.** Line 22 says noun rows reuse N-001 to N-059 unchanged. Lines 31–32 require every noun row to carry `nouns.md` text and a Bible heading as its source. Line 193 issues new IDs only when `nouns.md` is regenerated. So an N-060 row would have no source, which is the reason the writer gives at line 205. The retained HF-06a log line 18 enforces the noun-set match.
- **HF-06b matches:** N-024 at `HF-06b-persistence-projection.md:142` says HF-06a N-024 types the slot definition, which resolves by (revision, ID) and is never serialized.
- **HF-07a points at the right row:** line 127 changed its source from "HF-06b row F-03" (main) to "HF-06b row N-024" in both copies (`.csv:23`). That agrees with HF-06b N-024. The rationale cell is unchanged.
- **Markdown and CSV agree:** I compared the CSV rows by eye (`HF-06a…csv:2-33`, `HF-06b…csv:5,18,33`). The coordinator's paper check (lines 9–38) confirms parity for every row.

**2. Kit actions route through abilities (AM-H8-003).** Met.
- HF-06a rows F-01 (line 66), N-007 to N-011 (lines 80–84) and N-019 (line 92) carry the decision text, including "every produced attack stays under TH-03" in F-01.
- N-013 (line 86) separates a slot action's visual reference from an attack's. It also repeats the kit-to-ability clause, a small extra that is consistent with the decision.
- N-016 (line 89) separates replacing a mobility action from replacing an attack. N-021 (line 94) names the attacks it references.
- HF-06b N-009 (line 127) keeps planted-limb attacks as F-02 within an ability.
- HF-07a has no field changes (paper check lines 64 and 78). Nothing I read over- or under-applies the amendment's accepted scope.

**3. Respec opportunity and HF-06b line 114.** Met.
- **Respec (AM-H8-004):** HF-06a N-024, HF-06b N-024 (both copies) and TH-07 Seam 5 (`TH-07…md:364`) all say "F-04 objective definition (SC-04) under Q-P18, not an SC-05 event definition" and cite TH-06 UN-05. I confirmed UN-05 is at `TH-06…md:119`.
- **Line 114 (AM-H8-002):** `HF-06b…md:114` now names only the accepted route decision and next entrance, cites TH-11 line 45 (verified at `TH-11…md:45`), and names no level or encounter ID.
- **Q-P18 is not answered.** HF-06a line 58 now correctly counts Q-P18 as an unregistered question named in a rationale cell.

**4. Drift fixpoint, re-pins and read-for-meaning.** Met.
- **Drift:** both scans report 0 mismatches (receipts).
- **Hash-only re-points:** coordinator paper check lines 79–106 show 28 files differ from base only in hash tokens. My own sample of 15 re-pointed files:
  - Files: PD-02, PD-03, SC-03 to SC-06, SC-08, HF-07b, HF-08, HF-09, TH-04, TH-06, TH-11, TH-12 and TH-19.
  - Line counts are identical in both trees.
  - The old HF-06a, HF-06b, HF-07a and TH-07 hashes appear nowhere in worktree `docs/`, and the new ones sit on the same line numbers as the old ones did in main.
  - `SC-06.md:9-11` differs only in hex strings.
- **Re-pins:**
  - HF-06b's check changed only its `hf06a_*` pins (lines 51–52), and HF-07a's check only its `hf06b_*` pins (lines 99–100).
  - I also compared the pins in HF-08 (lines 23–25), TH-07 (lines 374–384), TH-06 (lines 57–58) and SC-05 (lines 857 and 860); only hash strings changed.
  - All 11 scripts have identical line counts and identical counts of assertion lines, so nothing appears weakened.
  - HF-06a's check pins only HF-05, HF-03a, `nouns.md` and its card (lines 30–34), so it correctly needed no re-pin.
- **Headings:** all seven are unchanged in HF-06a, HF-06b, HF-07a and TH-07 (paper check lines 1–4, plus my own read).

## Writer choices judged
- **TH-07 aligned sentences:** lines 15, 364, 460 and 470 correctly describe the revised N-024, and none changes a rule. Line 470 is a re-verification trigger.
- **TH-07 PR-01 and HF-06a F-02 left as they were:** these are gaps in wording, not contradictions (notes 2 and 3).
- **TH-06 and TH-11 cited as plain text:** acceptable. No hash cycle, and none of the edited sections' new lines is cited by line number anywhere else (grep found nothing).
- **The extra Procedure performed paragraphs** (`HF-07a…md:350`, `TH-07…md:484`) go beyond the card's "cell only / sentence only" wording. They are required by the assignment's acceptance criteria, so I record them as a note, not a failure.

## Blocking findings
None.

## Non-blocking notes
1. **SC-03 now contradicts the revised matrix.** This is more than stale wording.
   - `/home/andrew/Projects/scrapkeep-wt-FR-07/docs/tech/schemas/SC-03.md:58` says HF-06a treats mobility actions as F-02 definitions, which revised N-019 no longer does.
   - SC-03 lines 85–86 and 384 type replaced and replacing actions as F-02 only, while revised N-016 sends mobility replacement to N-021.
   - SC-03 now pins the new HF-06a hash, so drift shows agreement while the content disagrees.
   - It cannot block FR-07, because the card's boundary forbids editing schema contracts, and AM-H8-003's affected-work list never named SC-03.
   - **Fix:** the coordinator records it as a specification contradiction and routes an SC-03 revision before SC-02 attempt 2 or TH-20 depends on it.
2. **HF-06a F-02 at line 67 still says "one attack definition per committed player … action".** It could be read as every player action having an attack. N-052 (line 125) still links per-action feedback only to F-02 attacks. Both fall outside the accepted scope; carry them to SC-02 attempt 2, SC-07 and TH-20.
3. **TH-07 PR-01 at line 110 still says "an authored event definition".** That is narrower than "F-04 objective definition" but does not contradict it. Wording only.
4. **Other stale schema sentences:**
   - The writer's list is accurate but incomplete. It also missed SC-04:433 (the same claim as line 580), SC-06:339 ("not yet applied" for AM-H8-004) and SC-08:466 and 469 (a hypothetical "AM-H8-001 slot row" that will not exist).
   - I judge SC-04:580, SC-05:18, SC-06:338 and 449, and SC-08:26, 326 and 373 as wording to carry forward, not contradictions. The substance still holds: device and part actions stay F-02, SC-05 excludes events, and SC-08's slot questions stay unset.
5. **Four re-pinned checks have no rerun receipt:** HF-07b, TH-06, TH-08 and SC-05. The card does not require them, but they are unverified. They also fall outside the card's literal "HF-06a, HF-06b and HF-07a (pins only)" list, though the assignment allowed them.
6. **N-024's opening "Slot definitions and slot-tree definitions (F-03)" is ambiguous.** F-03's own rationale (line 68) still covers only slot trees. Worth clarifying for SC-01 attempt 2.
7. **A frozen historical copy still holds pre-FR-07 pins:** `artifacts/foundation-sprint-2026-09/tasks/HF-10/attempt-1/rerun/HF-06b/check_projection.py`. It is out of scope and needs no action.

## Files sampled
- **Main sections, worktree against main:**
  - HF-06a `.md`: read in full in both.
  - HF-06a `.csv`: lines 1–34 (worktree only).
  - HF-06b `.md`: in full (worktree) against main lines 10, 111–142 and 187–248.
  - HF-06b `.csv`: lines 5, 18 and 33.
  - HF-07a `.md`: lines 1–30 and 330–355, plus lines 126–129 in both trees.
  - HF-07a `.csv`: lines 22–25 in both trees.
  - TH-07: lines 1–25 and 455–491 in both trees, plus lines 356–367.
- **Citations checked:** TH-06:117–120 and TH-11:45.
- **Schema lines read:** SC-03:58, 85–86 and 384; SC-04:433 and 580; SC-05:18, 491, 495 and 672–691; SC-06:9–11 (both trees), 338–339, 449 and 549; SC-08:26, 326, 373, 466–469 and 589–598.
- **Retained scripts:** hash pins for HF-06a, HF-06b, HF-07a, HF-08, TH-07, TH-06 and SC-05, plus line and assertion-line counts for all 11 scripts.
- **Amendments and packet:** AM-H8-001 to 004 requests, the AM-H8-003 advisory, `assignment.md`, `check_fr07.py`, and ORCHESTRATOR lines 78–95.

## Commands run
None. I had only Read, Grep and Glob, with no shell. Every exit code above comes from the coordinator's receipts.

## Model and effort
The runtime context names `claude-opus-5[1m]`. I cannot verify that by self-description. `CLAUDE_EFFORT` could not be read here because I have no shell or environment access.

## Confirmation
I wrote, edited and committed nothing.