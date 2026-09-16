# SC-08 review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**SC-08 review: candidate d9920812f511a3083a9a1c729c139ec121f037df**

## Verdict
**FAIL**, on one blocking finding that is cheap to fix. Everything else meets the card. If you decide the blocking rule below is legitimate schema design, the rest would support PASS+NOTES.

**Evidence level:** level 3 for the row allocation and the six walks, level 2 for citations. For the automated checks it is level 4, but only through your receipts, which I read and did not rerun. This session had no shell tool, so I ran no commands.

## Definition of done
1. **Scope and HF-06 rows: met (level 2–3).**
   - Rows N-012, N-017, N-056, N-057, N-058 and N-059 match HF-06a line 147 (candidate `SC-08.md:37-44`).
   - The row allocation follows the corrected rule. HF-06a line 85 says "narrative and dialogue definitions", which covers T1 and T2. Line 90 says "Permanent unlock and discovery definitions", which covers T4 and T5. Lines 129–130 cover T3.
   - No type lacks a row and no row is re-treated (`:35`, `:46`; HF-06a lines 22 and 46).
   - The exclusions N-058, N-059 and N-040 are confirmed at `:48`.
   - Foreign definitions are named by HF-06a row only. I checked F-01, F-04, F-05, F-06, F-07, F-08, N-015, N-023 and N-025 against HF-06a lines 66–73 and 96–98: all are `schema` rows owned by another card.
   - Pilot barks are dealt with at `:50` without re-treating N-007.
2. **Fields, types, identity/version rules, references, diagnostics and an illustrative record per type: met (level 2).**
   - Each type has these at `:115-371`, with a shared type vocabulary (`:64-74`) and ID/version rules IV-01 to IV-08 (`:86-97`).
   - DC-01 to DC-09 match HF-05 lines 50–51, the edges at lines 87–92 and the diagnostic fields at lines 103–117.
   - All five records are labelled "Illustrative, not canon".
3. **Save treatment, paper round-trip and executable obligation: met (level 2–3).**
   - `:54-60` and `:385-395` match the HF-06b CSV rows (N-012 and N-056–N-059 are immutable-by-id with no projection; N-017 projects to discovery knowledge and permanent unlocks).
   - The durable fields are HF-07a CSV lines 8 and 10 with their matching groups.
   - The commit timing matches HF-07b lines 35, 85, 87 and 139 and TH-09 lines 97 and 181.
   - QO-01 to QO-06 assign the executable checks to TH-22 (`:397-408`), as TADR-003 line 45 requires.
4. **Unchosen content and numbers symbolic: not met because of B1.**
   - The parameter table SP-01 to SP-16 (`:414-431`) gives every row a question or a source line, and the Q-E09 answer is correctly read from TRACKING EV-0250 and HF-07b line 139.
   - B1 (below) fixes a content cardinality with no source and no question link.

**Headings and hashes.** All seven headings are present. The stated hashes rest on receipts: `paper-check.log` line 1 reports 18 of 18 assertions passing, including A15; `exits.txt` shows exit 0 for both drift commands; and `check-drift-schemas.log` reports "18 stated hashes, 0 mismatches" with no line for the file. On my own reading, the short hash prefixes for HF-06a, HF-06b and TH-07 match the ones AM-H8-004 cites. The PD-03 hash matches EV-0382. The BIBLE, TADR-003, TH-09 and HF-07a CSV hashes also appear in 22 admitted files.

**Packet bans.** No Resource, script, runtime content or canon was added. The receipt `check-scope.log` shows one changed path, classed documentation-only, which matches `identity.txt`.

## Blocking finding
**B1. `SC-08.md:311` (DT4-02) and `:445` (Seam 6)**
- **Problem:** DT4-02 reads "Two discoveries carry the same set of subject IDs" and rejects the second one. That means at most one discovery can exist per set of subjects, and no source states that.
- **Why it matters:** TH-09 line 45 defines a discovery as knowledge of *a relationship*, and one set of subjects can hold more than one relationship. BIBLE line 893 says attunement can be between an item and a character, another item, or both. Q-P37 (BACKLOG line 3318) leaves open which sightings, offers, declined drops and demonstrated behaviors create discoveries. Q-P14 leaves open what the player learns before and after one.
- **Violated requirements:** DoD 4 and the settled rule that no open question may be answered. SP-10 leaves the admitted subject families unset under Q-P37, but DT4-02 limits how many discoveries each subject can have. The paper check tests none of this: no walk or negative control exercises DT4-02.
- **Fix (either option):**
  - Limit DT4-02 to discoveries whose `subject_ids` is exactly one T2. That is the only case Seam 6 needs to link a discovery one-to-one with an exchange.
  - Or remove DT4-02 and add a parameter row: "Whether several discoveries may share a subject set — unset — Q-P37; Q-P14".

  Then add a negative control for whichever rule remains.

## Non-blocking notes
1. **SC-03 and SC-04 are now admitted.** TRACKING lines 174–175 show them done at EV-0402 and EV-0409. `docs/tech/schemas/SC-03.md` and `SC-04.md` exist on main but not in the worktree, so this happened after base 87e88cc.
   - The candidate's "none is admitted" (`:23`, `:435`) is out of date on main, and the trigger at `:536` now fires.
   - I found no contradiction. SC-04 line 236 references N-012 as a narrative identity, and SC-03 lines 390 and 425 agree on glossary and disclosure ownership.
   - However, SC-04 lines 423–426 put both F-04 and N-023 on each of T1 to T4. SC-08's expected families by row (`:238-239`, `:287`) are therefore ambiguous against SC-04's types. Re-read those References cells before integration.
2. **References to N-012 or N-017 by row are ambiguous.** Each of those rows hosts two SC-08 types (`:437`). SC-04 SR-08 (line 408) references "N-012 narrative identity family". State which type a row-level reference resolves to.
3. **The T1 stub is only half-checked (`:379`).** `narrative.illustrative_fleet` is a T1 without fields, but WV.1 stages "the five records". If it sits in the candidate, it would fail DC-03. The paper model skips stubs at the structural gate (`check_sc08.py:275-277`). State that stubs come from a declared compatible dependency revision.
4. **Two exclusions are overstated.** "N-058's exclusion holds by construction" (`:512`) and the N-040 claim at `:48` only block a `reference` status token. A reference could still be authored as T3 `culture`/`candidate` or as T1 `character`, so the exclusion actually depends on review under TADR-003 line 35.
5. **Subject and grant exclusions are argued rather than cited.** Excluding slot trees from T4 subjects (`:287`) cites no source. Excluding them from T5 grants (`:332`) rests on "tree progress is rebuilt", which is about progress, not whether a tree is available. SP-10 and SP-13 should govern these, and AM-H8-001 may move the slot row anyway.
6. **The seen-state reading is an interpretation.** Recording seen-state through a separate T4 (`:173`, `:445`), and reading HF-06b's N-056 rationale the same way, is how the candidate reads "keyed by the exchange's ID". It is reasonable and stated as a seam, but the TH-20 reconciliation should confirm it.
7. **One citation is weak.** TH-07 line 78 (PG-2) describes the locked slot state. HF-07a CSV line 24 is the direct source for "the only slot access state stored".
8. **WS reuses a label.** It calls its restore failure "DC-07" (`:502`), but DC-07 is defined as an admission-time failure with edges E09/E12.
9. **Gaps in the paper check.**
   - A13's round-trip is `json.dumps` followed by `json.loads` (`check_sc08.py:410-416`), so it cannot fail on how `.tres` stores enums or empty strings.
   - A03 checks that allocations match naming phrases the writer chose, not whether those phrases are the right ones.
   - A06 checks only that sections exist.
   - A14 scans the parameter table only, which is why it cannot catch B1.
   - No negative control or walk exercises DC-02, DC-09, DT1-01/02, DT2-01..03, DT3-01..05, DT4-01/02 or DT5-01..03.

## Citations sampled (all read in this session)
| Citation | Result |
| --- | --- |
| HF-06a lines 22, 24, 46, 54, 56, 85, 90, 113, 129–132, 147, 193; CSV N-012 and N-056–N-059 | confirmed |
| HF-06a review note 2 (`review.md:14`) | confirmed |
| HF-06b lines 27, 34, 57, 58; CSV N-012, N-017, N-056–N-059 | confirmed |
| HF-07a CSV lines 8–10; md lines 62, 196 | confirmed |
| HF-05 lines 18, 22–24, 27, 29, 37, 50–51, 80–95, 103–117 | confirmed |
| HF-04a line 24 (randomness rule scoped to the encounter's `EncounterRandomState`), line 44 | confirmed; the candidate at `:173` does not over-apply it |
| HF-07b lines 35, 85, 87, 135, 139 | confirmed |
| HF-09 lines 46–55, 191, 195, 315–328 | confirmed |
| TH-09 lines 45, 95–104, 181, 296 | confirmed |
| TH-11 lines 39, 278–279; TH-01 lines 159, 161; TH-07 line 200 | confirmed |
| TH-07 line 78 | weak (note 7) |
| PD-03 lines 71, 109, 122, 149 | confirmed |
| HF-03a lines 34, 45, 51 | confirmed |
| BIBLE lines 384, 386, 388, 463, 811, 823–853 (every status cell in the subject-kind table), 857 | confirmed |
| TADR-003 lines 23–45 | confirmed |
| TRACKING EV-0250, EV-0372, EV-0382 | confirmed |
| BACKLOG Q-P08, Q-P28, Q-P37 | confirmed |
| Context7 query 2 and query 3 files | support EF-02 to EF-04 |
| AM-H8-003, AM-H8-004 | not contradicted: SC-08 references no F-02 action and no respec opportunity |

## Scenario walks
- **WV (valid discovery), traced step by step.** It goes draft, E02, E03, E04, E05, E06, matching the from/to states at HF-05 lines 81–85. Every reference in the illustrative catalogue resolves to an allowed family: the T1 organization, F-01, F-05, T5, T3 and T4. Every behavior identifier is in the illustrative vocabulary. The only caveat is the stub in note 3.
- **WM (missing region).** Correct: E12 is a replacement failing from `structurally valid`, and the `referrer` path is right.
- **WI and WX (invalid records).** Correct: DC-04 fails at E08, with no semantic stage.
- **WK (commit).** Matches F-PROCESS and the stage, validate, commit, acknowledge order.
- **WS (missing unlock at restore).** Matches HF-07a line 62, apart from the label in note 8.

## Commands and receipts
I ran no commands because this session has no shell. I relied on these receipts from `coordinator-candidate/` and did not reproduce them:
- `exits.txt`: check:scope, check:docs, check:project, check:drift, the schemas drift run and the paper check, each exit 0.
- The matching `.log` files.
- `paper-check.log`: 18 of 18 assertions pass, and all 12 negative controls fail on their target.
- `identity.txt`.
- `candidate-sha256.txt`: b6cce6f9…56db.

## Runtime
- **Model:** Opus 5 (`claude-opus-5[1m]`), per this session's system prompt. A model cannot verify its own identity by self-description.
- **CLAUDE_EFFORT:** unavailable. I could not read the environment.

## Write confirmation
I wrote, edited and committed nothing.

**Relevant paths**
- /home/andrew/Projects/scrapkeep-wt-SC-08/docs/tech/schemas/SC-08.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-08/coordinator-candidate/check_sc08.py
- /home/andrew/Projects/scrapkeep/docs/tech/schemas/SC-04.md
- /home/andrew/Projects/scrapkeep/docs/tech/schemas/SC-03.md