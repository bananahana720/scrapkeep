# HF-06a-A1 independent review

Reviewer: fresh scrapkeep-reviewer (claude-fable-5-1, effort high pinned by agent definition; CLAUDE_EFFORT not exposed). Reviewed identity: worktree /home/andrew/Projects/scrapkeep-wt-HF-06a, branch wt/HF-06a, head 321929ad25b3261758b1a800f5996b5416d43550, base 08fcbcca07f4db4123a6367bd5fc252610bda398. Verbatim report follows.

---

**Verdict: PASS+NOTES** — evidence level 2 (file:line) for artifact content and source cross-checks; level 4 (coordinator receipt) for commit identity, hashes and command exit codes.

**Reviewed identity** (level 4, from `attempt-1/verification.json:4-15`): sourceCommit 321929ad…, base 08fcbcca…, two changed files with sha256 c83973f7… (md) and efc09028… (csv), cleanTracked true.

## Findings (none blocking)

1. **N-052 embedded-record has no parent row.** `HF-06a-schema-inventory.md:42` defines embedded-record as living "inside a parent `schema` definition"; `:125` names the parent as "the presentation definition of an action", which is not a matrix row. N-013 (parent F-01), N-014 (F-03) and N-016 (item definitions N-015/N-025) each name a parent row; N-052 does not. The DoD (`BACKLOG.md:422-423`) requires only ID, treatment and producing card, so this is not a DoD failure, but SC-07 (`BACKLOG.md:2406`) must host the parent under "visual references" or the row collapses to excluded. Treatment holds; parent should be named.
2. **Producing-card scope stretch on two rows.** N-050 (`:123`) assigns "music arrangement definitions" to SC-07, whose "Cover only" list is "audio cues, visual references and interface settings" (`BACKLOG.md:2406`); TH-17 explicitly does not author music (`BACKLOG.md:1674`). N-012 (`:85`) assigns "narrative identities" to SC-08, whose list is "dialogue, glossary entries, discoveries and permanent unlock definitions" (`BACKLOG.md:2438`). Both are reachable readings but the SC card's own scope check (`:2413`, `:2445`) could bounce them.
3. **N-014 states a stronger rule than the Bible.** `:87` says "Each upgrade node and endpoint … embeds a visible-construction change reference". `BIBLE.md:540` says "Significant upgrades should alter visible hardware or effects"; `BIBLE.md:681` is an art rule about depiction. The embedded-record treatment holds; the "each" is a mild schema-shape overreach that SC-01 can absorb with a nullable field. Borderline.
4. **N-032 palette as schema is the row I would contest most.** `:105` treats AD-02 swatches (`BIBLE.md:622-635`) as SC-07 visual-reference definitions while the sibling frozen AD rows N-031, N-033 to N-041 are excluded as rules. Defensible, and the row correctly fixes type not values per `TADR-003:35`. The risk is a second editable copy of frozen Bible text (`BIBLE.md:614-691`); the rationale does not address that. Holds; note only.
5. **Inaccurate sentence at `:58`.** It says Q-P10, Q-P11, Q-P13, Q-P16, Q-P18, Q-P19 are "named in rationales". The CSV has only Q-P13 (N-010, `csv:19`) and Q-P16 (N-028, `csv:37`); Q-P10 appears only at `:186`, and Q-P11/P18/P19 nowhere in the matrix. Cosmetic.
6. **Excluded-rationale check is a length proxy.** `check_matrix.py:240-241` passes any excluded rationale of 40+ characters; it does not verify the rationale names one of the three cases at `:44`. N-034 (`:107`) and N-042 (`:115`) are complete reasons by my reading, but minimal.
7. **"Producing card" for excluded rows.** `:46` defines it as the consumer that "confirms at its own review that no authored definition is needed". This stays within the card. Caveat: TH-01, TH-02, TH-05, TH-16, TH-17 do not list HF-06a as a source (`BACKLOG.md:1167-1170`, `:1198-1201`, `:1291-1294`, `:1631-1636`, `:1661-1665`), so their writers will not see the obligation; TH-20 (`:1753`) is the only TH card that reads the matrix.

## Checks that passed

- **DoD 1.** F-01 to F-08 at `:66-73` match `TADR-003:25` order; N-001 to N-059 at `:74-132` match `nouns.md:7-65` (14 rows spot-checked). Each row has one treatment. Counts at `:62` (35/28/4) hand-verified. Seventeen noun rows sampled against Bible headings; all defensible from the Bible text and HF-05 identity rules except the notes above.
- **DoD 2.** Twelve producing-card matches checked against BACKLOG scope. Rows-by-card table `:140-154` sums to 67 and matches the matrix.
- **DoD 3.** CSV row n is md line n+64 throughout; first, last and eleven middle rows agree on ID, treatment, card and question cell.
- **DoD 4.** Q-P14 rows F-08, N-015, N-016, N-017, N-025, N-026; Q-P15 rows F-06, F-07, N-016, N-027; Q-E09 rows N-017, N-026, N-028 all carry the ID; invariance paragraphs `:54-56` hold against the candidates at `BACKLOG.md:2982`, `:2996`, `:2730`.
- **Prohibitions.** `retain_revision`/`read_initial_snapshot` absent. HF-06b and HF-07a cited by title at `:8`, `:184`. Validation in ContentAdmission only (`:48`, `:173`). TADR-004 not propagated. Seven H2 headings match the index. No engine behavior claimed (`:205`). Cited HF-05, HF-03a, HF-01, TADR-003 and Bible lines resolve.
- **check_matrix.py.** Its 38 assertions (`:128-278`) cover what the receipts claim. Only gap is note 6.
