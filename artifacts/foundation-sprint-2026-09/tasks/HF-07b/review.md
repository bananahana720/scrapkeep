# HF-07b-A1 independent review

Reviewer: fresh scrapkeep-reviewer (claude-fable-5-1, effort medium pinned by agent definition after EV-0149; CLAUDE_EFFORT not exposed). Reviewed identity: worktree /home/andrew/Projects/scrapkeep-wt-HF-07b, branch wt/HF-07b, head 30e194b16a93acb6696225863fc4cb072133866c, base 79ed9c5790a896c85f769c5b4e4745aef6b4200d. Verbatim report follows.

---

Reviewed identity: one changed file `docs/tech/sections/HF-07b-commit-boundaries.md` (283 lines as read). Head SHA, base and sha256 rest on the coordinator receipts (`attempt-1/verification.json:4-13`, `paper-check.json:4-6`).

**Verdict: PASS+NOTES.** Evidence level 3 (walked) for DoD 1 to 4, D1 and the two decisions; level 2 for prohibitions and headings; level 4 for exit codes, check counts and control detection. No note below violates the definition of done; note 1 is a required correction at the next revision.

## Findings, ranked

1. **Transition D's validate list omits the array-preservation gate the P4 column relies on.** `HF-07b-commit-boundaries.md:105` lists for Transition D only: terminal true, run object with unchanged run_id, revival_spent not weakened, profile sets supersets. The common checks at `:37` do not cover checkpoint arrays either. Yet `:143` (N1 under P4), `:145` (N3 under P4), `:198` and `:247` attribute exactly that gate to Transition D. Transition C has the symmetric clause at `:94`; D does not. The paper check does not catch this because its model enforces N1/N2/N3 as common validate gates on every transition (`check_boundaries.py:286-318`), so the mechanical replay is stronger than the prose. Requirement touched: card DoD 2. P4 is beyond the DoD's three minimum candidates, and P1 to P3 are fully argued, which is why this is a note and not a FAIL; fix by adding the clause to `:105` or promoting it to `:37`.
2. **C4's open-offer commit is not assigned to a named transition.** `:239-241` commits `T9` carrying an offer with `chosen_option_id` null after level 4 is already banked (`:238`). Transition A (`:73`) carries `offered_choices` only as part of a level completion; Transition B's stage list (`:84`) covers only answering an offer. BIBLE:584 requires offered choices to be stable; the section should say which of the four lists it uses. Minor; the walk still holds.
3. **Who stages.** `:36` "Persistence builds one complete candidate" vs `C1.1` at `:189` "Session stages the candidate". HF-03a:49 and :57 support `:36`. Wording only.
4. **Paper-check coverage is narrower than its summary line suggests.** 171 of the 172 checks are structural or token-presence checks; the model replay is one check (`check_boundaries.py:674`). The R dimension is inert: `apply_policy` (`:452-491`) never reads `revival`, so the 240 runs are 80 distinct runs repeated three times. The section's "all twelve P x R combinations" at `:151` and `:277` overstates what was exercised. The three negative controls are real (`:698`, `:705`, `:712`; baseline `:752-754`); detection rests on `paper-check.json:13-33`.
5. **Q-E09 pole wording.** `:261` describes both poles in the same words EV-0157/EV-0163 use and labels the Persistence-half protocol as submitted, not adopted. Acceptable.
6. **Preferences decision breadth.** `:157` fully decides the question HF-07a:184 assigns jointly to HF-07b and HF-08. It invents no product value and adds no field; HF-08 still owns recovery. Suggest one sentence reserving HF-08's failure-handling half.

## Check results

1. DoD 1: A `:75-78`, B `:84-87`, C `:93-96`, D `:104-107` each have a four-item numbered list with before/after states on C, S, A, L. Seam stated correctly: SEAM-1 `:63` matches HF-04a:67; SEAM-2 `:64` matches HF-04a:108; SEAM-6 `:68` and stage 4 `:39` match HF-04a:90, :113, :108; T5 rows cited at HF-04a:172,173,176,178 match. S0-08 reconciliation `:159-176` is source review; every cited S0-08 line carries the quoted observation.
2. DoD 2: P1/P2/P3 at `:129-131`; P4 and R1 to R3 added; "pending Q-P16" at `:123`, `:125`; no adoption. Walked N4 and N3 through P1 to P4 and R1 to R3: N4 holds everywhere; N3 holds under P1 to P3 and R1 to R3 by stated gates, under P4 only by construction (finding 1).
3. DoD 3: open product choices at `:260`; Q-E09 Persistence half as submitted proposal only at `:261`; nothing depends on EV-0157 or EV-0163 beyond admitted HF-07a:148 text.
4. DoD 4: C1 `:186-196`, C2 `:204-212`, C3 `:220-228`, C4 `:236-245` with per-policy paragraphs and matrix `:251-256`. Replayed C2 under P1 and P2 and C4 under P1 and P4 by hand; both hold; C4's T9 assignment is finding 2.
5. Verification bullet: D1.1 to D1.5 at `:49-53`. No path found by which an unvalidated or uncommitted generation enters A.
6. Decisions: (a) no durable ack trace, from S0-08:70 and HF-07a:172, :174-182, inside the card, HF-08 boundary kept at `:155`; (b) preferences write, inside the card and TADR-004:24/:32, see finding 6.
7. Prohibitions: HF-07a, HF-08, HF-09 titles match BACKLOG. `mount_id`, `retain_revision`, `read_initial_snapshot` absent; containers named only in the disclaimer at `:264`. Seven required headings at `:3, :17, :178, :258, :267, :273, :281`. Engine behaviour disclaimed at `:283`.
8. Script: see finding 4.

## Accepted notes

Findings 1 to 6. Finding 1 should be a required correction at the next HF-07b revision and an HF-10 input; 2 and 3 are wording; 4 is a coverage-claim adjustment for `:151` and `:277`; 5 and 6 need no change.
