# HF-08-A1 independent review

Reviewer: fresh scrapkeep-reviewer (claude-fable-5-1, effort medium pinned by agent definition after EV-0149; CLAUDE_EFFORT not exposed). Reviewed identity: worktree /home/andrew/Projects/scrapkeep-wt-HF-08, branch wt/HF-08, head 87e3f31d28a78db2094319c3a176aff8cd10fa99, base 2db978b7e8220e8b414d808d2a7d782b72492b58. Verbatim report follows.

---

**Verdict: PASS+NOTES.** Evidence level 3 (walked) for the contract and scenarios; level 2 (file:line) for citation checks; level 4 (coordinator receipt) for every command result. None of the notes below violates a DoD item literally; notes 1 and 2 are contract inconsistencies I recommend fixing in a revision before HF-09, HF-10 or PD-02 consume R5/R6.

**Reviewed identity.** `docs/tech/sections/HF-08-save-recovery.md` at the worktree; head, base, sha256 `57082dfa…` and changed-file set rest on `attempt-1/verification.json:4-13` (coordinator receipt).

## Findings, ranked

**N1. Candidate-path rule contradicts the retry-with-preservation rule (fix recommended).** `:52` fixes the candidate path as "derived deterministically from that candidate's `transaction_id`, so two candidates never share a path". `:124-125` (FC-02, FC-03) require retrying the *same* `transaction_id` from WO1 while keeping the partial candidate preserved, and `:125` says "a fresh candidate path derived from the same `transaction_id`". `:166` (P1) preserves partial candidates byte-identical; `:167` (P2) says a preserved artifact's path is never a write target. With one path per `transaction_id`, the retry's WO1 targets the preserved partial's path, violating P1/P2. V3.3 (`:311`) walks straight through this. Fix: derive the candidate path from `transaction_id` plus an attempt ordinal, or state explicitly that a retry overwrites its own partial candidate and exempt that case from P1. Requirement: internal consistency of DoD 3's preservation rules.

**N2. R5 routes two load-path classes wrongly or not at all (fix recommended).** FC-13 at `:135` yields `MC-UNSUPPORTED` when no candidate exists; R5 maps `MC-UNSUPPORTED` only for "FC-05 to FC-09, FC-12, FC-14" (`:156`) and `RECOVERY_BLOCKED` only for "`MC-AMBIGUOUS` at FC-13" (`:157`), so a corrupt committed record with no candidate has no user-visible state. FC-14 (SP0, no held transition) is routed to `SAVE_HELD_BLOCKED`, a save-hold state, though `:157`'s `RECOVERY_BLOCKED` and the seam rule at `:160` describe it. Requirement: DoD 2 "including user-visible retry and recovery states".

**N3. AC-2 is broader than its own reasoning (judgment note).** `:184` refuses on two parseable newer candidates even with identical lifecycle. Under N1's fix an ordinary FC-04 retry followed by a crash before replace yields two same-`transaction_id`, same-generation candidates whose order is irrelevant, and AC-2 then produces the "unplayable profile for a common power loss" the writer rejects at `:192`. AC-1 already covers the case where either carries a lifecycle fact `C` lacks. Suggest narrowing AC-2 to candidates that differ in `transaction_id` or `generation`. Inside TADR-004:40 as a conservative extension.

**N4. Positive-durability wording in three matrix cells.** `:205`, `:215`, `:221` say "is durable". `:198` defines that column as the proposition a later test must establish, and HF-07b:41/:155 use the same phrase, so not counted as a claim; but it sits uneasily with `:84`, and `check_recovery.py:147-151`'s regex does not catch "is durable".

**N5. FC-13's "start a new run" has no mechanism consistent with P2.** `:135` permits a new run only if no byte is written over a preserved artifact, but the corrupt record sits at the committed path, which the new run's WO5 must replace. PW7 (`:249`) states the preserve-first step for preferences; the aggregate has no equivalent.

**N6. Citation slips.** `:11` and `:150` attribute `retry_transition`/`TransitionStatus` to HF-03a line 35; they are on line 31. `:12` lists four receipt sources; the receipt also draws on `class_projectsettings.html` (receipt `:157`) and `output_panel.html` (receipt `:184`). `:8` says TADR-001:23 "pins" 4.7.2; `:23` recommends, `:25` pins.

## Packet checks

1. **DoD 1.** W1-W5 `:58-64`; WO1-WO6 `:72-79`, every step marked; W4 marked `:63`. Exactly two rows `:93-94` (TADR-001:23 verified), each with question, receipt-line API surface, evidence method, unqualified status. TADR-004:38 verbatim at `:78`. Ten receipt citations sampled, all resolve and name the API. Stated gaps confirmed absent from the receipt.
2. **DoD 2.** FC-01 to FC-18 `:123-140` each with point, held state in C/S/A/L, class, permitted, forbidden. Held states match HF-07b:36-41. PD-02 seam `:150,:160` matches HF-03a:35/37. See N2.
3. **DoD 3.** P1-P8 `:166-173`; AC-1 to AC-8 `:183-190`; excluded condition and declined S0-07:107 tightening `:192`, grounded in TADR-004:40 and HF-07b:30/:68. AC-8 inside TADR-004:40's refusal clause. See N3.
4. **DoD 4.** IM-A1..D5 `:202-221`: 4 transitions x 5 stage points, every row names a stage point, held state and outcome. Coverage also asserted by receipt `dod4.matrix_is_full_cross_product` (level 4).
5. **Verification bullets.** V1 walked `:283-288`: no false success, nothing deleted; N5 applies. V2 `:296-301` consistent with S0-08:49. V3 walked `:309-315`: no false success; N1 applies at V3.3. V4 `:323-330`: same-identity retry converges per HF-07b:118 N6.
6. **Deviations.** SP3a/SP3b and Transition A inside the card; WO naming inside; R9 matches HF-07b review note 6 and HF-07b:157, no field added; the three new engineering questions `:360-363` stay within TADR-004:38/48 or are flagged product. The HF-09 requirement at `:367` reaches into HF-09 as a stated requirement, not a decision.
7. **Prohibitions/headings.** Card titles match BACKLOG. Seven headings match the index. No `mount_id`, `retain_revision`, `read_initial_snapshot` in the contract. No rejected envelope key (receipt). Engine behaviour disclaimed `:389-391`. See N4.
8. **check_recovery.py.** Covers headings, markers, both OS rows, receipt anchors, 41 source-line anchors, CSV field parity, prohibitions, full matrix cross-product, S0-08 dispositions, hashes. Model `decide()` (`:349-378`) encodes AC-1/2/3/4/8 and P5; it does not model FC classes or R5, so N2 is outside its reach. `replay_matrix` expectations (`:452-465`) are a second writer-authored encoding, so `model.matrix_matches_document` proves consistency between two encodings, not against an independent oracle. Four controls detected (level 4).
