# TH-18 review R3

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**Verdict: PASS+NOTES.** Evidence level 3: I walked the traces and repairs step by step and checked citations at path:line. Level 4 exists only in the coordinator's receipts. I ran no command, so every hash, drift, scope and paper-check result below is labelled as a receipt.

## Candidate identity
- `/home/andrew/Projects/scrapkeep/.git/refs/heads/wt/TH-18-A3` points to `081badcc0704750aaeb452831c23e9228b5c1268`. The worktree's `HEAD` is `ref: refs/heads/wt/TH-18-A3`.
- **Receipt:** `coordinator-candidate-A3/identity.txt` says the parent is `234c1d7`, the working tree is clean, one commit, and one changed path, the TH-18 section.
- **Receipt:** `candidate-sha256.txt` gives `49ac213b…aa8f`, and `paper-check.json:3` shows the same value.
- I diffed the candidate against the main checkout's admitted TH-18 by reading both in full. The only changes are at lines 29, 56, 131, 136, 137, 140, 221, 225, 256, 263, 264, 273, 285–288, 297, 318–324 (the new DA.14 plus renumbering), 354, 362, 381, 385, 389–396, 403, 405, 410 and 428. No other rule changed.

## Named findings
- **B2 (blocking): repaired.** The Interfaces preamble at `TH-18:131` now says HF-04a line 47 gives InputAdapter only clearing under F-CONTROL. It says the union of two callback families "is not an existing permission" and gates II-02's recording until HF-04a admits it. The same gate appears at `:136` (II-02), `:285` (seam), `:354` (FT.3), `:362` (FT.11) and `:405` (trigger). This matches `HF-04a-runtime-lifecycle.md:46` (F-INPUT: InputAdapter updates records) and `:47` (F-CONTROL: InputAdapter clears state). Level 3.
- **A1, TH-18 part (blocking): repaired.** II-06 at `:140` now reads `RL2, RL3, RL7 and RL8`, which equals `TH-01-complete-loop.md:83` (IF-10). Level 2.
- **A6: repaired.**
  - The II-03 result cell at `:137` matches the read's replacement word for word.
  - The new DA.14 at `:318` is a Session-to-InputAdapter read on D05 through II-04 in F-PROCESS, before readiness at DA.15.
  - The DL-08 delivery gate is still present at DA.3 (`:307`) and DA.11 (`:315`), and the outcome is renumbered to DA.19 (`:297`, `:324`).
  - Level 3.
- **A7: repaired as the read worded it.** IE-01 (`:221`) and IE-05 (`:225`) now name the control bound to IN-05, and the Q-E03 row (`:385`) ends at NT-15. See note N2 for a side effect. Level 2.
- **C2: repaired in substance.**
  - `:56` states "proposed minimum coverage, not a closed answer to Q-P30".
  - PQ-3 to PQ-6 (`:393–396`) only ask questions.
  - DP-14, DP-15 and DP-24 (`:263`, `:264`, `:273`) now route to PQ-5, PQ-6 and PQ-4. DP-24's reasoning checks out against `BACKLOG.md:2646`: Q-E03 asks about devices, not a connection count.
  - One stale phrase remains (note N1). Level 2.
- **Stale seam wording: repaired.** Lines `:286–288` and `:410` use the read's "admitted at the Handoff-8 closure target" wording.

## Definition of done
1. **Device-to-intent mapping, device loss, focus/modal clearing and prepared cancellation: met.** The kinds are at `:39–52` and the intents at `:58–74`, each citing TH-02, TH-04 or TH-12 row IDs. The rules are DL-01 to DL-08 (`:95–102`), FC-01 to FC-10 (`:108–117`) and CA-01 to CA-05 (`:123–127`). FC-02 (`:109`) makes opening a modal clear a prepared action before any commit. Level 3.
2. **Full keyboard/mouse and controller coverage, with hardware recorded as unqualified: met.**
   - IC-01 (`:82`) requires both classes to reach every intent, and every IN row has both coverage cells.
   - HQ-01 to HQ-08 (`:208–215`) are all marked unqualified.
   - IT-01 to IT-15 each name an NT row (`:170–184`).
   - I found no controller layout, dead zone, sensitivity or repeat value, device list or qualification claim. Every such value is `unset` (`:256–280`).
   - Level 2.
3. **Verification (three traces with named outcomes): met.** I walked all 18 DA steps against their gates:
   - The ticks at DA.1, DA.2 and DA.18 are C-TICK P1/P2 at unpaused RL2 (`HF-04a:62`).
   - O1 → O2 → O3 happen at DA.6 → DA.7 → DA.8, before the view at DA.9 (`HF-04a:87–89, 92`).
   - Nothing between DA.3 and DA.17 advances the tick or reaches `submit_action`.
   - O4 re-runs O1 before unpausing last (`HF-04a:90`).
   - Every edge used matches `HF-03b-dependency-graph.md:27, 31, 32, 34`.
   - CN and FT have the same O1 < O2 < O3 < view structure.
   - Level 3.
4. **Seven headings and stated hashes: met, receipt-dependent.** The headings are present. **Receipts:** `check-drift.log` reports 349 stated hashes with 0 mismatches, and `paper-check.log` shows 13 stated hashes matching. I did not compute any hash myself.

## Blocking findings
None.

## Non-blocking notes
- **N1 (leftover C2 wording).** The Q-P30 row at `TH-18:381` still says Q-P30 decides "status wording". Its own DP-14 (`:263`) says no registered question asks that, and routes it to PQ-5. `BACKLOG.md:3220–3226` (Q-P30) does not mention status wording. The Procedure line (`:428`) says DP-14 is "no longer inferred from Q-P30", but `:381` still infers it. Both routes are unset and gated, so no rule changes. **Fix:** delete "and status wording" at `:381`.
- **N2 (A7 side effect).** IE-05 (`:225`) now covers "the keyboard/mouse control bound to IN-05" but keeps "The uncaptured pointer supplies no edge; nothing fires." CA-01 (`:123`) only suppresses pointer motion and buttons, and IC-06 (`:87`) admits discrete edges from both classes. If DP-07 binds IN-05 to a key (IK-03), IE-05 claims a result no rule supports. **Fix:** limit IE-05 to a pointer button (IK-02), or say a key binding falls under IC-06 and DP-13.
- **N3 (withholding at FT.11).** FT.11 (`:362`) has InputAdapter withhold held controls in an F-CONTROL step, and only the recording part is gated. This is defensible: the withholding continues O1's re-arm from FT.6 and FC-05's suppression under F-INPUT at FT.10. Still, the preamble at `:131` now grants only clearing under F-CONTROL. **Fix:** word it as clearing, or refer to the existing re-arm.
- **N4 ("fixes" vs "proposed").** `:29` still says the section "fixes twelve physical action kinds", while `:56` calls the kind table proposed minimum coverage.
- **N5 (boundary with TH-12).** II-06 (`:140`) still cites `TH-12-hud-dashboard-and-settings.md:155` (UI-03), which says `RL2 to RL8`. The read placed that error in TH-12, and `TRACKING.md:668–669` routes the TH-12 half of A1 to CLOSURE-A. Until that lands, TH-18 cites a row that disagrees with it.
- **N6 (paper-check gaps; script read, not run).**
  - The B2 checks (`paper_check.py:258–259`, `:315–316`) only look for the gate text.
  - The A6 check (`:325–328`) only runs if the exact phrase "publishes the connection as a request" appears. Reworded, it would pass without checking anything. It also never confirms the II-04 read is of the connection request.
  - The NT-range check (`:272–273`) only matches "NT-01 to NT-xx" strings.
  - These obligations are untested: all of C2 (PQ-3 to PQ-6 exist and answer nothing, and the Q-P30 row agrees with DP routing), A6's II-03 cell wording, A7's IE-01 and IE-05 wording, the stated count of six protocols (missing from the `stated` dict at `:382–397`), and whether a gate actually prevents randomness, damage or cast release (only proxied by tick position).
  - Module names come from a hardcoded list (`:24–32`); only commands, results and records are parsed from HF-03a.
  - **Receipt:** 19 of 19 negative controls were detected (`paper-check.log:2–20`).

## Citations sampled (all confirmed unless stated)
| Citation | Result |
| --- | --- |
| `HF-04a:46` | F-INPUT; InputAdapter updates records |
| `HF-04a:47` | F-CONTROL; InputAdapter clears state |
| `HF-04a:51` | F-OTHER needs an owner, interface and classification |
| `HF-04a:62` | P1 |
| `HF-04a:87–90` | O1 to O4 |
| `HF-04a:92` | focus loss and modal exit sequence |
| `TH-01:83` | IF-10 at RL2, RL3, RL7, RL8 |
| `TH-01:88` | IF-15 |
| `TH-01:92` | IF-19 |
| `TH-01:99` | IF-26 |
| `TH-01:104–106` | IF-31 to IF-33 |
| `TH-01:108` | IF-35 |
| `TH-01:45` | Paused |
| `HF-03a:36` | InputAdapter row |
| `HF-03b:31` (D05), `:34` (D08), `:44` | as described |
| `TH-04:69` (AV-06), `:201` (AO-08) | as described |
| `TH-02:40` (MA-07), `:238` (MP-24) | as described |
| `TH-12:141` (FI-10), `:171` (UI-19) | as described |
| `TH-12:155` (UI-03) | reads RL2 to RL8; see N5 |
| `PD-02:118` (FP-14) | as described |
| `TADR-001:23`, `:39` | as described |
| `HF-07a:185` | sensitivity unresolved |
| `HF-07a:272` | contains "rebinding" (I saw only a partial match, not the full line) |
| `BACKLOG.md:2646` (Q-E03), `:3220` (Q-P30) | as described |
| 13 dependency SHA256 values | not checked by me; receipt only |

## Commands run
None; I had no shell tool, so there are no exit codes of mine to report. I used only Read, Grep and Glob.

**Receipts, not rerun:** `coordinator-candidate-A3/exits.txt` records exit 0 for `check:scope` (234c1d7..081badcc, `--no-build`), `check:docs`, `check:project`, `check:drift` and `paper_check.py`. `paper-check.log` shows 1267 of 1267 assertions passing.

## Model and effort
- The system prompt names the model as `claude-opus-5[1m]`; I can't verify my own identity.
- `CLAUDE_EFFORT` is not exposed to me, so its value is unavailable.
- `AGENTS.md` pins Fable 5.1 medium for consequential review. If this closure review counts as consequential, running on Opus 5 is a substitution the coordinator should rule on.

## Writes
I wrote, edited and committed nothing. I did not open `assignment-closure.md`, since it is the writer's brief.

Relevant paths:
- `/home/andrew/Projects/scrapkeep-wt-TH-18-A3/docs/tech/sections/TH-18-input-integration.md`
- `/home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/TH-18/coordinator-candidate-A3/paper_check.py`
- `/home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/closure/integrated-read-R1.md`