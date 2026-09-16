# SC-08 review R2

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

# SC-08 review R2: candidate fd698d30b89564cea292affdeab9969aa4abea80

## Verdict

**PASS+NOTES.** B1 is fixed. I found no blocking issue, and no note below breaks the definition of done.

**Evidence level:** level 3 for the row allocation, the save treatment and the walks (WV, WD, WM, WI and WX, checked by hand), and level 2 for citations. The automated checks reach level 4 only through the coordinator's receipts, which I read but could not rerun: this session had only Read, Grep and Glob, with no shell. `SC-08.md` below means `/home/andrew/Projects/scrapkeep-wt-SC-08/docs/tech/schemas/SC-08.md`.

## B1 is resolved
- DT4-02 now fires only when two discoveries each have `subject_ids` of exactly one T2 exchange, and it is the same exchange (`SC-08.md:350`). Line 352 limits the rule to that case.
- SP-17 leaves every other shared subject set unset under Q-P37 and Q-P14 (`:473`). Seam 6 was narrowed to match (`:487`), and the Unresolved questions section lists SP-17 under both questions (`:571-572`).
- Walk WD exercises the rule (`:556-564`). I traced it by hand: the overrides pass the structural gate, the subject resolves to T2 (an allowed family), the placeholder is in the vocabulary, and the only finding is DT4-02 at E09, which takes the candidate from `structurally valid` to `draft` (HF-05 line 88).
- The paper check has controls both ways. RC-03 must produce DT4-02 and RC-04, a shared non-exchange subject, must not (`check_sc08.py:835-837`). NC-13 widens the rule back and NC-14 lets WD pass; both fail on target (`coordinator-view-A2/paper-check.log:14-15`). I confirmed NC-13's mutated line 350.

## Foreign reference resolution table: not an answer to Q-P37
The table resolves N-023 to `EnemyArchetypeDefinition` only and F-04 to `BossDefinition` only (`:72`, `:78`, `:81`). That restriction is a choice about this revision's scope, and three things keep it from answering Q-P37:
- SP-10 leaves the admitted discovery subject families unset under Q-P37, explicitly including "another SC-04 type" (`:466`).
- Every production T4 or T5 record is already blocked at DC-09, because its behaviour vocabulary is unset (`:327`, `:375`, `:453`).
- Re-verification fires when AM-H8-004 is applied or any question is answered (`:589`, `:591`).

The word "only" still has no source line; see note 2.

## Definition of done
1. **Scope and HF-06 rows: met (level 3).**
   - The rows N-012, N-017 and N-056 to N-059 match HF-06a line 147 (`:40-47`).
   - The allocation follows the rationale phrases at HF-06a lines 85, 90, 129 and 130. I read each phrase.
   - The N-058 and N-040 exclusions are narrowed to the status-token check plus review under TADR-003 line 35 (`:51-55`, `:554`).
   - Row-level references resolve: N-012 to T1, N-056 and N-057 to T3, and N-017 must name T4 or T5 (`:59-63`). N-012 → T1 agrees with SC-04 SR-08 (SC-04.md:408).
   - The nine resolution rows are at `:69-79`. Their sources check out: SC-04.md lines 94, 222 and 423–429, and SC-03.md lines 39, 41, 60 and 157.
2. **Fields, identity and version rules, references, diagnostics and one illustrative record per type: met (level 2–3).**
   - The five types are at `:154-412`, the ID rules IV-01 to IV-08 at `:119-128`, and the common diagnostics DC-01 to DC-09 at `:134-144`.
   - The restore failure now has its own label, DR-01 (`:150-152`). The DC edges match HF-05 lines 87–92 and the diagnostic fields match lines 103–117.
   - Stubs come from a declared compatible dependency revision (`:416`, `:501`), which HF-05 line 51 permits.
3. **Save treatment, paper round trip and executable obligation: met (level 2–3).**
   - The save treatments are at `:85-91` and `:428-434`.
   - HF-06b agrees: N-012 and N-056 to N-059 are `immutable-by-id` with no projection, and N-017's projection names both groups (CSV lines 21, 26, 65–68).
   - The durable fields are HF-07a CSV lines 8 and 10. The stored slot access state is now cited to CSV line 24, which I confirmed says "the only slot access state stored".
   - The commit rule matches HF-07b line 139. QO-01 to QO-06 go to TH-22 (`:440-449`), as TADR-003 line 45 requires.
4. **Symbolic values and question links: met (level 2).**
   - There are 17 parameter rows. The 15 unset rows each carry a question ID, and SP-14 and SP-15 carry sources (`:455-473`).
   - Slot trees are handled by SP-10 and SP-13 (`:326`, `:373`). No number, roster or canon value appears.

**Headings, hashes and scope (receipts).**
- All seven headings are present.
- `candidate-sha256.txt` gives ca5c365a…859c, and the view's `paper-check.json:3` shows the same hash.
- On the merged view, the schemas drift check reports 54 hashes, 0 mismatches and 0 unbound. The view's `paper-check.json:5-10` input hashes equal the hashes stated at `:7`, `:9-12`.
- `check-scope.log` shows one changed path, classed documentation-only.
- In the worktree, checks fail only on the SC-03 and SC-04 links and hashes, as the packet expects (`check-docs.log:1-2`, `check-drift-schemas.log:1-2`, `paper-check.log:2-3`).

## Blocking findings
None.

## Non-blocking notes
1. **The seen-state quote leaves out half of HF-06b's wording (`:212`, `:431`, `:487`).**
   - HF-06b CSV line 21 says an exchange's seen-state "is discovery or unlock knowledge in N-017's profile projection, keyed by the exchange's ID".
   - The candidate quotes only "keyed by the exchange's ID" and then says the knowledge "is the one T4". T5 `grant_ids` already accepts T2 (`:373`).
   - That narrows the admitted wording rather than contradicting it, and it is sent to TH-20. But the justification for DT4-02 ("two keys", `:564`) depends on it. R1 raised this as note 6 and it is still open.
   - **Fix:** quote both options and say that choosing T4 is the reading TH-20 confirms.
2. **"Only" in the resolution table has no source.**
   - SC-04 lines 423–426 put both rows on T1 to T4, and HF-06a line 96 gives N-023 "miniboss and boss definitions".
   - IV-07 (`:127`) covers adding, removing or retyping a field. It does not name widening a field's allowed families, even though `:81` relies on it.
   - F-05 is narrowed to "region definition" (`:73`), but SP-10 does not name the other F-05 types.
   - **Fix:** name the SC-04 types directly in the References cells, and add changes to allowed families to IV-05 or IV-07.
3. **One glossary mapping could reject a future entry.** `encounter_mechanism` maps to `EnemyArchetypeDefinition` (`:277`), but BIBLE line 849 calls the Pruner arm an "Implemented encounter mechanism". Nothing breaks today, because such entries must leave `subject_id` empty (`:263`). If SP-08 later promotes one, DC-08 could reject it.
4. **Gaps in the paper check.**
   - A09b only looks for the phrase "exactly one T2" (`check_sc08.py:657-659`). DT4-02's behaviour is hard-coded in the rule model (`:400-404`) and never read from the contract.
   - A13 encodes and decodes using the same field tables (`:423-481`), so it checks internal consistency only. The contract admits this at `:637`.
   - A14 reads only the parameter table (`:849-868`). A06 only checks that sections exist. A07b checks that each cited line is a heading, not where the restriction comes from.
   - No SC-04 stub exists, so the resolution to SC-04 types is never exercised.
   - No walk or control exercises DC-01, DC-03, DC-05, DC-06, DC-08, DT1-01/02, DT2-01..03, DT3-01..05 or DT5-01..03.
5. **Line references.** Line 5 says every line reference is at the base, but `:24-25` cite SC-03 and SC-04 lines on main. The exception is stated only at `:24-25`.
6. **Brindle citation.** Line 164 could also cite SC-04.md:236, where the boss-role link is actually defined (`BossDefinition.narrative_identity_id`).
7. **For the coordinator, not the candidate.**
   - The merged view sits in a disposable session scratchpad (`view-A2/paper-check.json:2`, `check-docs.log:8`), and the view's `exits.txt` has no command lines.
   - The packet lists PD-03 and TH-18 as unadmitted, but TRACKING.md:137 and :158 show both done.

## Citations sampled

| Citation | Result |
| --- | --- |
| HF-06a lines 22, 24, 46, 54, 66–73, 85, 90, 96, 129–132, 147 | confirmed |
| HF-06b CSV lines 21 (N-012), 26 (N-017), 65–68 | confirmed; line 21's quote is partial (note 1) |
| HF-07a CSV lines 8–10 and 24; md line 62 | confirmed |
| HF-05 lines 18, 22–24, 27, 29, 50–51, 80–95, 103–117 | confirmed |
| HF-04a line 24; HF-07b lines 135 and 139 | confirmed |
| TH-09 lines 45, 95–104, 296 | confirmed |
| SC-04 lines 38–46, 94, 222, 236, 408, 423–429 | confirmed |
| SC-03 lines 39, 41, 60, 157, 251, 390 | confirmed |
| BIBLE lines 384, 386, 388, 463, 811, 823–853, 857, 893 | confirmed |
| TADR-003 lines 35, 41, 45 | confirmed |
| PD-03 lines 71, 109, 122, 149 | confirmed |
| BACKLOG Q-P37 (line 3318), Q-P14 (line 2996); AM-H8-004 `request.md:48` | confirmed |
| TRACKING SC-03 at EV-0402, SC-04 at EV-0409 (lines 174–175), EV-0417 | confirmed |

## Commands
I ran no commands, because this session had no shell. The exit codes below come from the coordinator's receipts, which I read but did not reproduce:
- **Worktree run (`coordinator-candidate-A2/exits.txt`):**
  - check:scope and check:drift exited 0.
  - check:docs, check:project, the schemas drift check and the paper check exited 1. As the packet expects, the only failures are the SC-03 and SC-04 links and hashes.
- **Merged view (`coordinator-view-A2/exits.txt`):** every check exited 0. The paper check passed 22 of 22 assertions, and all 17 negative controls failed on target. check:drift covered 349 hashes with 0 mismatches.

I also read `assignment-A2.md` and `review-R1.md`, because the packet names them.

## Runtime
- **Model:** Opus 5 (`claude-opus-5[1m]`), according to this session's system prompt. A model cannot verify its own identity by describing itself.
- **CLAUDE_EFFORT:** unavailable; I could not read the environment.

## Writes
I wrote, edited and committed nothing.

**Relevant paths**
- /home/andrew/Projects/scrapkeep-wt-SC-08/docs/tech/schemas/SC-08.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-08/coordinator-view-A2/check_sc08.py
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-08/coordinator-view-A2/paper-check.log
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-08/coordinator-candidate-A2/exits.txt
- /home/andrew/Projects/scrapkeep/docs/tech/schemas/SC-04.md
- /home/andrew/Projects/scrapkeep/docs/tech/schemas/SC-03.md
- /home/andrew/Projects/scrapkeep/docs/tech/sections/HF-06b-persistence-projection.csv