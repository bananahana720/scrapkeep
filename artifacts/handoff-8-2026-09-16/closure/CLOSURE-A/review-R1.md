# CLOSURE-A review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**Verdict: FAIL (bounded).** The candidate applies nearly every named repair correctly and changes no rule, gate or question state. But it adds three new factual defects, all small, and I couldn't pass it with those in: two in SC-02 caused by the new FR-13 row, and one unsupported sentence the writer composed in TH-19.

**Evidence level:** I read the files directly. I had no shell, so I ran no `git diff` and no checks. For each of the nine paths I read the whole file in the worktree (`/home/andrew/Projects/scrapkeep-wt-CLOSURE-A`) and in the main checkout, and compared them line by line. Where main differs only in hash or SC-03/SC-08 line cells, that comes from main's later re-pointing and I ignored it. The branch ref `.git/refs/heads/wt/CLOSURE-A` reads `0f55274f0ae70c126560f0863d21486a540234ca`. The claim that the worktree is clean rests on `coordinator-candidate/identity.txt` (`status-lines 0`) [coordinator receipt]. Every command result below rests on coordinator receipts, which I read.

**Diff I observed** (candidate line numbers):
- **SC-01:** 5, 25, 194, 394, 395, 421, 425, 426, 511, 512, 535, 539, 560, 633, 635.
- **SC-02:** 27, 96, 363, 379 (new FR-13 row), 396, 508, 514, 516, 518, 560.
- **SC-04:** 23, 24, 46, 71, 143, 251, 415, 433, 580, 596.
- **SC-05:** 5, 18, 25, 26, 84, 278, 385, 387, 484, 491, 505, 513, 678.
- **SC-06:** 26, 140, 141, 199, 200, 252, 253, 303, 304, 335, 338–341, 449, 451, 532, 539, 543.
- **TH-07:** 110 and 253 only.
- **TH-12:** 155 only.
- **TH-19:** 14, 72, 210, 216, 220, 244, 272, 280, 284, 290, 294, 296, 298, 361, 362 (new W3.5), 363–366 renumbered, 375, 379, 404.
- **AM-H8-004 request:** 14, 58 and 62 only.

## Named rows

| Row | Status | Lines |
|---|---|---|
| A1, TH-12 part | Done. UI-03 reads "RL2, RL3, RL7 and RL8", matching TH-01 IF-10 (`TH-01:83`) and TH-18 II-06 (`TH-18:140`). UI-05, the O3 row, is unchanged. | TH-12:155 |
| A2 | Done, exact wording | SC-02:396 |
| A3 | Done, exact wording; the existing sentence "Nothing here references the objective." is kept | SC-01:539 |
| A8 | Line 210 exact, AQ-20 per the read. Lines 14 and 404 are composed but supported by the excerpt at `command-line-excerpt.md:15-16`. **Line 216 is unsupported (B3).** | TH-19:14, 210, 216, 290, 404 |
| A9 | Done. W3.4 and the new W3.5 match the read's text, and the new row mirrors W1.10. | TH-19:361–366 |
| A13 | Done (see note 1) | SC-02:96, 516, 560 |
| A14 | Done | SC-04:23, 46, 71, 596 |
| A15 | Done | SC-05:385, 387, 513 |
| A17 | Done. PX-02 is arithmetically right: with 7 nonterminals the tree still has 8 endpoints. | SC-01:5, 560, 633, 635; TH-07:253 |
| A18 | Seam 3 sentence exact. FR-13 added and its HF-06a rows match SC-03's type table (`SC-03:39,41`). **The row leaves two knock-on defects (B1, B2).** | SC-01:535; SC-02:379 |
| A19 | Done. Every value cell stays `unset` or `open`, so no gate is answered. | TH-19:72, 244, 280, 284, 375, 379; SC-01:511, 512; SC-02:508 |
| Stale seam and amendment language | Done, and AM-H8-004's history is kept | SC-04:433, 580; SC-05:18, 484; SC-06:338, 339, 449; AM-H8-004:14, 58, 62; SC-06:26, 543 |
| Live seam status | Done | SC-01:25, 194, 421, 425, 426; SC-02:27, 363, 514, 518; SC-04:24, 251, 415; SC-05:26, 505; SC-06:140–141, 199–200, 252–253, 303–304, 532, 539; TH-19:294, 296, 298 |
| Carried notes | Done | TH-19:272 (EV-0397 N3), 220 (N4); SC-05:5, 25, 84, 491, 678 (EV-0425 N1), 278 (N7); SC-06:451 (EV-0430 N3, rows match HF-06a lines 89 and 98); TH-07:110 (EV-0436 N3) |

**Other acceptance checks:**
- **Line citations:** a grep of `docs/` and the worktree (excluding `artifacts/`) found no citation into SC-02 at line 379 or later, or into TH-19 at line 362 or later. TRACKING only cites TH-19 lines 24–26. No external reference to W3.5–W3.9 turned up.
- **TH-07 and TH-12 scope:** both files were compared in full. Only the named lines changed.

## Blocking findings

**B1. SC-02:33 still says "twelve foreign reference rows".** Lines 367–379 now hold thirteen (FR-01 to FR-13), so a contract count is now false.
- Proposed wording: "thirteen foreign reference rows".

**B2. SC-02:167's list of inbound references for `AttackDefinition` leaves out FR-13.**
- Proposed wording: "Inbound references are FR-04, FR-06 to FR-10, FR-12 and FR-13."

**B3. TH-19:216 says RR-09's first run is "the first observation of the runner's `--editor --import` at lines 597 to 612 in proof mode".** TH-19:10 and :200 both say lines 597–612 run only in export mode. The proof-mode import is RR-04's new step (TH-19:207), so no cited line supports the sentence.
- Proposed wording: "The retained command-line excerpt documents `--import`; whether the relevant `--script` invocation performs the needed import remains unverified (AQ-20), and RR-09's first run is the first proof-mode observation of the RR-04 import, which reuses the argument list of lines 598 to 604."

## Writer deviations

1. **Status fixes beyond the listed lines** (SC-01:394, 395, 535 heading; SC-04:143; SC-06:335, 340, 341; SC-02:518): **accepted.** They change status wording only, in permitted files.
2. **FR-13's HF-06a rows:** **accepted** under the packet's test, since they match SC-03's type table. See note 2, and B1/B2 for the consequences. The row sits at line 379, not 380 as the handoff says, and it follows FR-12; the writer's own script would have placed it before FR-12, so an undisclosed manual reorder happened. That is harmless.
3. **Line shifts:** **accepted.** No broken external citation was found.
4. **Composed wording:** TH-19:14 and :404 **accepted**. TH-19:216 **rejected (B3)**. Keeping "Nothing here references the objective" in A3 is accepted. Dropping the respec sentence at SC-06:338 and :449 is accepted, since those rows are about AM-H8-003, not respec.
5. **Value cells kept `unset` or `open`:** **accepted.** This is what keeps the gates intact for A19.

## Non-blocking notes

1. SC-02:96 has a capital "Player-facing" after a semicolon.
2. SC-02:363 defines inbound rows as "the foreign rows HF-06a says reference these types". HF-06a lines 73, 88, 98 and 99 (F-08, N-015, N-025, N-026) never mention F-02. Consider citing `SC-03:39,41` in FR-13.
3. TH-07's walk step WM.2 (line 381) still says the totals fail PT-02 and PT-03, and line 376 says the edge and endpoint counts are wrong. Both now contradict the repaired PX-02 at :253 and SC-01:578 and :583. TH-07:484 still says PR-01 "keeps 'an authored event definition'". All three lines are outside the lease, so they need a follow-up card.
4. Stale wording remains on lines the integrated read did not name:
   - SC-02:587, 607
   - SC-04:584, 592, 612
   - SC-05:678, and 704, which still says the rule profile is empty despite :387
   - SC-06:463 ("SC-02 has no admitted attack type") and 537
   - TH-19:29 ("Concurrent cards…, none admitted") and 386, whose `--import` trigger has already fired
5. SC-05:513 now adds `ordinary` and `boss` to the fixture profile, but the fixture JSON at :523 still lists only `known_token_prefix`.
6. SC-01:511's partial selection describes the asset batch. The more relevant recorded partial answer is Q-P06: Fuse supplies the first complete kit (`TRACKING.md:232`, EV-0372).
7. SC-01:432, which says objective content grants a T3 slot or T5 node, sits uneasily beside the repaired Seam 5 at :539.

## Coordinator receipts I read

- **Candidate** [coordinator receipt]: check:scope, check:docs and check:project exited 0. Both drift scans exited 1. `check-drift.log` has 4 mismatches and `check-drift-schemas.log` has 10; every one is a stated hash of TH-07, TH-12, SC-04 or SC-06.
- **Merged view** [coordinator receipt]: after 6 fixpoint passes (`fixpoint.log`), both drift scans exit 0. `paper-reruns.log` shows 35 checks with 1 failure, SC-05, at 11 of 12 controls caught. `paper-SC-05-repinned.log` catches 12 of 12 after NC12 was re-pinned to `8ab8f0cc…` (`check_sc05-repinned.py:856-857`).

## Model and effort

The runtime describes this reviewer as claude-opus-5 with a 1M context. That is self-description and I can't verify it. `CLAUDE_EFFORT` is not exposed to me, so it is unavailable. The project's AGENTS.md pins Fable 5.1 medium for consequential review; if this review counts as consequential, running it on Opus 5 is a substitution, and AGENTS.md says substitutions are reported as blockers. That call is yours.

Relevant paths:
- /home/andrew/Projects/scrapkeep-wt-CLOSURE-A/docs/tech/schemas/SC-02.md
- /home/andrew/Projects/scrapkeep-wt-CLOSURE-A/docs/tech/sections/TH-19-asset-import-export.md
- /home/andrew/Projects/scrapkeep-wt-CLOSURE-A/docs/tech/sections/TH-07-four-slots-and-milestone-progression.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/closure/CLOSURE-A/review-packet-R1.md