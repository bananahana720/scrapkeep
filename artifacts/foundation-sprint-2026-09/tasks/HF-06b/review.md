# HF-06b-A1 independent review

Reviewer: fresh scrapkeep-reviewer (claude-fable-5-1, effort medium pinned by agent definition after EV-0149; CLAUDE_EFFORT not exposed). Reviewed identity: worktree /home/andrew/Projects/scrapkeep-wt-HF-06b, branch wt/HF-06b, head 69bf3c7114a1dff98c5384bc278d0729738cd4eb, base 2d33632136918703a2d64d9ca8f05bf03d45fcd4. Verbatim report follows.

---

**Verdict: PASS+NOTES** (evidence level 2 file:line for artifact and source checks, 3 walked for the row sample and CSV/MD spot check, 4 coordinator receipt for every command result).

**Reviewed identity.** Head `69bf3c71…` and output hashes `63cb5881…` / `8ba1476b…` are taken from `attempt-1/verification.json:4-16` (coordinator receipt). Files read: `docs/tech/sections/HF-06b-persistence-projection.md` (244 lines) and `.csv` (68 data-carrying lines) in that worktree.

## Findings (none blocking)

1. **Sources paragraph contradicts the Questions column rule.** `HF-06b-persistence-projection.md:10` states HF-06a's "question tags are copied unchanged into the matrix below", but `:48` and row F-08 at `:118` (`Q-P14; Q-E09`) differ from HF-06a CSV `:9` (`Q-P14`). `check_projection.py:180-189` compares only id, subject, treatment and producing card, so the pass at `paper.log:14` does not cover this claim. Requirement: ORCHESTRATOR.md:88. One-word fix; not a DoD item.
2. **`:81` misstates which rows name Q-P16.** It says F-04, N-018, N-019, N-023 and N-028 name it; only F-04 (`:114`) and N-028 (`:146`) do. Internal inaccuracy, not a DoD item.
3. **`immutable-by-id` companion-cell rule is loosely met for unreferenced definitions.** `:27` requires a definition row to name "which projection references it"; N-020, N-021, N-023, N-032, N-050/N-051, N-056/N-057 say only "nothing is projected". Readable as "none" under `:27`'s "at most"; `check_projection.py:226-228` only tests rationale length.
4. **`:27` case definition overstates the "no-definition-no-state" trace.** It says the only durable trace "is the admitted catalogue the envelope pins"; false for pure governance prose such as N-030 `:148` and N-041 `:159`, whose own rationales correctly claim no trace. Wording only.
5. **Rule 4 and C11 reach one step into TH-22.** `:34` (IDs are JSON strings) is derived from HF-05:18 and S0-07:45/S0-08:47, both verified, and defers numeric typing to HF-07a; acceptable. But `:209` prescribes "TH-22's round trip must include an ID with a numeric spelling", a test-case instruction inside TH-22's DoD (BACKLOG.md:1831). Advisory.

## DoD checks

**DoD 1** (`:111-177`, `:183-185`): 14 + 3 + 50 = 67, each row exactly one closed-set value. Sampled 22 rows by hand against HF-06a CSV treatment and HF-05:37/39; all pair correctly under rule 2 (`:32`). Values contested: none. F-06 `json-projection` with a possibly-empty set is the one judgment call; it is the only value that holds under both Q-P15 poles, per TADR-004:26. No projection cell names anything but vocabulary tokens; TADR-004:20/34 cited correctly at `:31`.

**DoD 2**: all 14 json rows carry `tres`, a vocabulary projection and `TH-22`. TH-22 heading verified at BACKLOG.md:1813. Projection-group table `:55-71` maps each token to a literal TADR-004:24/26/30 phrase and an HF-03a:45/49 record; verified. S0-08 reconciliation `:90-103` is source review; each cited S0-08 and S0-07 line checked and accurate.

**DoD 3**: CSV rows 2-69 are F-01…F-08, N-001…N-059 in HF-06a CSV order. Hand-checked first, last and ten middle rows: identical save values and projections. Full cell parity rests on the coordinator's rerun (`paper.log:12`).

**DoD 4**: Q-P15 (BACKLOG.md:2996) and Q-E09 (:2730) are open-ended; the section argues both poles (`:77-78`, C03-C06 `:201-204`). EV-0144 proposals are explicitly not assumed at `:75`, `:116`, `:135`, `:216`. EV-0151 is the writer's own restatement of `:77-78`; `:53` leaves HF-07a free to shape or empty the group, so it is answer-invariance, not an answer. Holds.

**Item 5 judgment calls**: guidance rows as `immutable-by-id/no-definition-no-state` within card (finding 4 is wording). N-018 transient with lifecycle facts on N-028: consistent with TADR-004:24/30 and HF-03a:45/49. Rule 4: within card except C11 (finding 5). F-08 tag: within the registered questions; only finding 1's sentence is wrong.

**Item 6**: HF-07a cited by title at `:15`, `:53`, `:220`. No `retain_revision` or `initial_snapshot`. Seven headings present. `:243` disclaims engine behavior; no product value invented in the rows read.

**Item 7**: `check_projection.py` asserts what `paper.log` claims. Gaps: `ENGINE_OBJECT_RE` scans only the projection column; rationale content is length-checked only; question-tag parity to HF-06a is unchecked (finding 1).

Accepted notes: findings 1-5. None violates DoD 1-4; finding 1 should be corrected before admission.
