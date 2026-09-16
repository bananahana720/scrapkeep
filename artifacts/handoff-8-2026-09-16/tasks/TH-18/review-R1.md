# TH-18 review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**TH-18 review: candidate 7f42500061a4761690f32e3ab26ec22d1895ce53, card revision 1**

## Verdict: FAIL

The contract is mostly sound and well cited. One problem blocks it: the intent coverage table partly fixes a binding layout, which the packet bans and which open question Q-P30 owns. The fix is small.

**Evidence level:**
- Level 2 (pointed at file:line) for the citations and rules.
- Level 3 (walked step by step) for trace CN, checked against its gates.
- The level-4 checks are the coordinator's command logs, not mine. I had only Read, Grep and Glob, so I ran nothing, including `npx ctx7`.

## Definition of done
1. **Map device actions to intents; define device loss, focus/modal clearing and prepared cancellation.** Mostly met (level 2–3).
   - The tables are at lines 39–52 (physical action kinds IK), 58–74 (intents IN), 95–102 (device loss DL), 108–115 (focus and clearing FC), 121–125 (pointer capture CA) and 133–150 (interfaces II).
   - DL-02 at line 96 (loss is not release) matches HF-04a line 26 and O1 at line 87.
   - FC-02 at line 109 (O2 cancels before any view or commit) matches HF-04a line 88, TH-12 FI-01 and FI-05 (lines 132, 136) and TH-04 AO-08 (line 201).
   - DL-08 at line 102 states the F-OTHER default as an explicit gate on implementation ("dependent implementation is gated until it is made"). It does not rely on the default silently.
   - Blocking finding B1 below affects the mapping cells.
2. **Full keyboard/mouse and controller coverage; unqualified hardware recorded.** Coverage is structurally met (IC-01 at line 82; every row IN-01 to IN-15 names a kind for both classes). HQ-01 to HQ-08 (lines 204–211) are all unqualified. B1 applies. Level 2.
3. **Verification: the three traces plus a native test per transition.**
   - The traces are at lines 296–367, each with a named outcome (DA.18, CN.16, FT.21).
   - Every transition IT-01 to IT-14 names a test NT-01 to NT-14 (lines 168–198).
   - I walked CN.1 to CN.16 against HF-04a lines 46, 47, 62, 87–89 and 92, HF-03b D01, D05, D06 and D08, and TH-01 IF-19, IF-26, IF-32 and IF-35. Every step is admissible, O1, O2 and O3 come before the view at CN.9, and no tick runs after CN.2.
4. **Seven headings:** present at lines 3, 25, 286, 369, 385, 398 and 410.
5. **Packet bans:** there are no numeric dead-zone, sensitivity or repeat values, no device list and no qualification claim. The one breach of the layout ban is B1.

## Blocking finding
**B1: coverage cells fix part of the controller and keyboard mapping.**
- **Where:** `docs/tech/sections/TH-18-input-integration.md` lines 62–74 together with line 56 ("Every coverage cell is a requirement"), and line 84 (IC-03).
- **What it fixes:**
  - IN-05 (weapon) on keyboard/mouse may only be a mouse button (IK-02).
  - IN-07 (mobility), IN-08 (ultimate) and IN-09 (pause) on controller may only be a digital button (IK-07), with no trigger (IK-08).
  - IN-11 (switch views) and IN-14 (close view) on controller may only be a digital button, with no D-pad.
  - IC-03's rule that one physical control maps to at most one intent per context rules out tap/hold dual use. Its cited sources (HF-04a lines 87 and 90, TH-12 FI-04 line 135) only require that the pause/resume press is consumed as UI input.
- **Why it blocks:**
  - It contradicts admitted rows that leave mappings and remapping unset under Q-P30: TH-12 UP-15 (line 271), PD-02 IP-02 (line 129) and TH-02 MP-24 (line 238).
  - It partly answers Q-P30 ("controller mappings, remapping", BACKLOG line 3220).
  - It contradicts the candidate's own line 31 ("no controller layout").
- **Fix:** In each cell, list every kind that can produce the signal the intent needs. Held or edge intents get IK-02 and IK-03, or IK-07 and IK-08. Discrete directions add IK-09. Aim needs IK-01 or IK-06. Route any narrower choice to DP-07 (Q-P30). Cut IC-03's first sentence down to the consumed-press rule, or route it to DP-07.

## Non-blocking notes
- **N1: no stated owner for blocking stale UI input.** FC-05, FC-06 and DL-05 (lines 99, 112–113) say held or unfocused input becomes nothing "in any input class". But the navigation steps (CN.10, FT.14) run in Presentation under F-INPUT, and Presentation has no edge to InputAdapter (HF-03b line 52). No row says who stops un-re-armed or unfocused input before it reaches Presentation. The engine mechanism that would do it was not retrieved. Fix: name InputAdapter as the owner, and add a parameter row or native test for the engine mechanism.
- **N2: callback family for focus observation.** II-02 at line 134 classes InputAdapter's focus observation as F-CONTROL. TH-01 IF-33 (line 106) and TH-12 UI-19 (line 171) class `sample_input` as F-INPUT. HF-04a line 47 gives InputAdapter only "clears state" under F-CONTROL. State the refinement explicitly.
- **N3: states FC-08 leaves out.** FC-08 at line 115 covers RL4, RL5, RL6 and RL9. Focus or device loss at RL3, RL7, RL8 and under Held is not addressed, although TH-01 IF-10 (line 83) admits O1 at RL3, RL7 and RL8. FC-08 also omits O1 but still requires neutral re-arm.
- **N4: gate missing from the traces.** The gate cells for DA.3 and DA.11 (lines 302, 310) don't mention DL-08's implementation gate. The HF-04a revision it depends on should travel in the handoff as a requested shared-file change (ORCHESTRATOR line 86).
- **N5: loose question routing.** DP-26 (vibration) is routed to Q-P32, whose text (BACKLOG line 3248) doesn't mention vibration or haptics. DP-13's and DP-24's routings are also loose.
- **N6: wording of `tick`.** Line 288 defines `tick` as advancing "without drawing gameplay randomness, applying damage or releasing a cast". That is true of these trace rows (P1/P2) but not of the tick in general (HF-04a P4/P5, lines 65–66). Scope the wording.
- **N7: gaps in the paper check.** The coordinator's copy (`paper_check.py`) genuinely tests the order of O1, O2, O3 and the view (line 293), that O2 comes before any commit (line 295), edge endpoints and permitted use (lines 171–175), coverage kinds by class (lines 227–233), unqualified hardware and native tests (lines 304–312), and eight negative controls (lines 384–393). It does not test:
  - DL-02's loss-is-not-release meaning.
  - Whether a `none` effect really involves no randomness, damage or cast. The label is self-asserted.
  - Citations written as "ID at line N" in the Sources section, or chained IDs such as "AO-08 line 201" without a section prefix (regex at line 352).
  - Engine claims against the Context7 receipts.
  - Whether a cited row is relevant, as opposed to existing. IN-11 cites parameter row UP-02.
  - The packet bans, except the no-value rule on Q-P30 and Q-P32 rows.
  - The kind-subset choice behind B1.

## Citations sampled (all matched)
- **HF-04a:** line 24 (gameplay randomness means `EncounterRandomState`), 26, 47, 51, 87–90, 92.
- **HF-03a and HF-03b:** HF-03a lines 36 and 50; HF-03b D05 line 31, line 44, DF-04 line 94.
- **TH-12:** FI-11 line 142, UI-01 to UI-22 lines 153–174, seam line 218, UP-15 line 271, UP-19 line 275.
- **TH-04:** AV-06 line 69, AO-08 line 201, AP-23 line 289.
- **TH-02:** MA-06 line 39, MA-07 line 40, MP-24 line 238.
- **TH-01:** IF-26 line 99, IF-32 line 105, IF-35 line 108, line 45.
- **PD-02:** vocabulary lines 44–50, FP-14 line 118.
- **HF-07a:** lines 185, 205, 272; CSV line 67 (`preferences.sensitivity`).
- **Bible, ADRs:** BIBLE lines 483, 544, 602; TADR-001 lines 23 and 39; ADR 0005 lines 11, 13, 15, 19, 21.
- **Engine claims:** checked against the worktree's `artifacts/local/tasks/TH-18/ctx7/` files for `ignore_joypad_on_unfocused_application`, `is_echo`, `get_connected_joypads`, `JoyConnectionChanged` and `MOUSE_MODE_CAPTURED`. Each is present, and the two retrieval limits appear in `retrieval-index.json` lines 69–72.
- **Hashes:** I did not recompute them. Six of the stated hash strings also appear in other admitted sections (grep count), and the rest rest on the coordinator's logs.

## Commands and coordinator receipts I relied on
- **Mine:** Read, Grep and Glob only. No shell or `npx` commands.
- **Coordinator receipts (level 4, not re-run):**
  - `coordinator-candidate/exits.txt`: check:scope, check:docs, check:project, check:drift and the paper check each exit 0.
  - `check-drift.log`: 305 stated hashes, 0 mismatches, and no line for this file. The log does not show which directory it ran in.
  - `paper-check.log`: 1095 of 1095 assertions passed; all 8 negative controls caught.
  - `identity.txt`: head 7f42500…, parent bb97c41…, one added path.
  - `candidate-sha256.txt`: a9982a04….
  - `check-scope.log`: documentation-only.

## Runtime
Model: Opus 5 (`claude-opus-5[1m]`) according to the system context, which is not proof of identity. `CLAUDE_EFFORT` is not exposed to me, so its value is unavailable. I wrote, edited and committed nothing.

Relevant paths:
- /home/andrew/Projects/scrapkeep-wt-TH-18/docs/tech/sections/TH-18-input-integration.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/TH-18/coordinator-candidate/paper_check.py
- /home/andrew/Projects/scrapkeep-wt-TH-18/artifacts/local/tasks/TH-18/ctx7/retrieval-index.json