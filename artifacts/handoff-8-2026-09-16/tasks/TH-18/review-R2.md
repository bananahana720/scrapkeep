# TH-18 review R2

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**TH-18 review R2: candidate 45d2d1974f83d14469189ab9be6c5a39bc85f252 (attempt TH-18-A2, card revision 1)**

## Verdict: PASS+NOTES

B1 is resolved, and none of the notes below breaks the definition of done. The bytes I read are in `/home/andrew/Projects/scrapkeep-wt-TH-18/docs/tech/sections/TH-18-input-integration.md` (below, "TH-18"). Two things rest only on the coordinator's receipts: that the worktree is at 45d2d19, and that the file's hash is b6de4e54… (`coordinator-candidate-A2/identity.txt`, `candidate-sha256.txt`). I could not run git or sha256sum.

**Evidence level:**
- **Level 2:** the citations.
- **Level 3:** I recomputed all 30 coverage cells from the section's own kind table, and walked trace DA step by step.
- **Level 4:** exists only as the coordinator's receipts. I ran nothing.

## B1 and the judgments the packet asked for
- **B1 is resolved (level 3).**
  - For all 15 intents and both device classes, I derived every kind from IK-01 to IK-12 (lines 41–52) whose class, signals and context fit the intent's Signal and Context (lines 60–74). Every cell matches: no kind is missing and none is extra.
  - IC-03 (line 84) is now only the consumed-press rule, which matches HF-04a lines 87 and 90 and TH-12 FI-04 at line 135. Dual use of one control goes to DP-07 (line 256).
  - IC-02 (line 83) sends the choice among kinds to Q-P30. That matches TH-12 UP-15 (line 271), PD-02 IP-02 (line 129) and TH-02 MP-24 (line 238).
- **Widening controller cells with IK-09 is sound.** IK-09 declares `direction, held-or-edge` (line 49), and D-pad directions are digital held controls. Adding it only adds options, so nothing is narrowed.
- **PQ-1 and PQ-2 are sound.**
  - No registered question covers either topic: Q-P30 (BACKLOG line 3220) and Q-P32 (line 3248) don't name vibration or combining device classes. My search of BACKLOG, TRACKING, BIBLE and the sections for vibration, haptic and rumble matched only TH-18 itself.
  - Both protocols (lines 390–391) use the register's own fields (Missing information, Decision owner, Evidence needed to close; compare BACKLOG lines 2632–2638), carry no ID and answer nothing. TRACKING EV-0400 (line 614) carries them to grooming.
  - One small tension: IC-06 (line 87) admits samples from both classes in one context, which could pre-empt a PQ-2 answer where only one class governs.
- **The HF-04a change is stated as a gate, not assumed.** See DL-08 (line 102), DA.3 (line 307), DA.11 (line 315), the seams list (line 285) and the re-verification triggers (line 400). EV-0400 records the requested revision (coordinator record).

## Definition of done
1. **Map device actions to intents; define device loss, focus/modal clearing and prepared cancellation.** Met (levels 2–3).
   - The tables are at lines 39–52, 58–74, 95–102, 108–117 and 121–127.
   - DL-02 (line 96) still matches HF-04a line 26.
   - FC-02 (line 109) still matches HF-04a line 88 and TH-04 AO-08 at line 201.
   - FC-08 (line 115) now matches TH-01 IF-10 at line 83 and IF-15 at line 88.
   - FC-10 and DP-31 (lines 117 and 280) name InputAdapter as the owner that stops stale input.
2. **Full keyboard/mouse and controller coverage; unqualified hardware recorded.** Met.
   - IC-01 is at line 82, and all 30 coverage cells list at least one kind.
   - HQ-01 to HQ-08 (lines 208–215) are all marked `unqualified`.
3. **Verification: the three traces plus a native test per transition.** Met.
   - DA, CN and FT (lines 305–372) each reach a named outcome.
   - IT-01 to IT-15 each name one of NT-01 to NT-15 (lines 170–202).
   - **DA walk (level 3):**
     - Each step's edge and command match HF-03b D01, D05, D06 and D08 (lines 27–34) and HF-03a lines 31–37.
     - Only DA.1, DA.2 and DA.17 are `tick` rows, at C-TICK P1 or P2.
     - O1, O2 and O3 (DA.6–DA.8) come before the view (DA.9).
     - No step reaches P4 or P5, where HF-04a lines 65–66 allow random draws and damage.
- **Headings:** all seven present (lines 3, 25, 291, 374, 395, 409, 423).
- **Bans:** no dead-zone, sensitivity or repeat value, no device list and no qualification claim. DP rows gated on Q-P30 or Q-P32 are all `unset`.
- **R1 notes:** N1 is addressed at lines 117 and 280, N2 at lines 131 and 136, N3 at lines 115, 184 and 202, N4 at lines 307 and 315, N5 at lines 262, 273 and 275 (with a residual, note 5), and N6 at line 293. Nothing regressed.

## Blocking findings
None.

## Non-blocking notes
1. **The kind table itself limits what Q-P30 can choose.**
   - IK-04 (line 44) is `direction` only, even though its shape is the same as IK-06's continuous two-axis sample, which is `aim, direction` (line 46). So IN-02's keyboard/mouse cell (line 61) rules out keyboard-only aim, which is a remapping and accessibility question.
   - No kind covers a mouse wheel or other inputs. DP-07 (line 256) only chooses among the kinds already in a cell.
   - Fix: say the IK table is the minimum coverage vocabulary, route any added kind or signal to DP-07, and add the IK table to the Q-P30 trigger at line 397.
2. **Two edge cases still assume a binding.** IE-01 (line 221, "its trigger holds a prepared weapon") and IE-05 (line 225, "clicks the mouse to fire") do this, although line 419 says such cells were rewritten. Fix: say "the control bound to IN-05".
3. **II-02's justification goes beyond HF-04a.** Line 131 combines what F-CONTROL and F-INPUT allow InputAdapter. HF-04a line 47 gives InputAdapter only "clears state" under F-CONTROL, and recording or withholding is not listed. EV-0400 requests only the connection-delivery revision. Fix: add this allowance to the same HF-04a request, or gate it the way DL-08 is gated.
4. **The states where O1 is allowed disagree.** II-06 (line 140) says "RL2 to RL8", copied from TH-12 UI-03 (line 155). FC-09 (line 116) says, correctly per TH-01 IF-10 at line 83, that no O1 is admitted at RL4–RL6.
5. **Some question routing is still loose.**
   - DP-24 (line 273), "how many may be connected at once", is not in Q-E03's text (BACKLOG line 2646).
   - DP-14 and DP-15 (lines 263–264) go to Q-P30, whose text (line 3220) names neither status wording nor capture mid-play.
6. **A stale range.** The Q-E03 row at line 384 says "NT-01 to NT-14", but NT-15 at line 202 is also gated on Q-E03.
7. **A gap in trace DA.** DA.11 publishes a connection request (line 315), but no II-04 D05 read follows before DA.14 asserts that "the controller path is valid" (line 318).
8. **II-03 (line 137) lists only `PhysicalInputState`.** DA.3 also publishes a `FocusOrModalRequest`, and its buffer is `InputContextState` (HF-03a line 50).
9. **A trigger has already fired.** TH-19 was admitted after this base (TRACKING line 992, EV-0398), so the trigger at line 405 applies to the seam at line 288. The coordinator should handle this at integration.
10. **What the paper check does not test** (`coordinator-candidate-A2/paper_check.py`):
    - Coverage completeness is judged against the section's own Signals and Context columns (lines 245–251), so it cannot catch note 1.
    - The DL-02 check only looks for a string (line 308).
    - The `none` effect label is taken on trust (lines 293–294).
    - Interface-row callback families are not checked against HF-04a (note 3), and interface-row states are not checked against TH-01 (note 4).
    - Bible, TADR, ADR and "lines N to M" citations are only checked to be non-empty (lines 387–390).
    - It doesn't scan for bans beyond the Q-P30/Q-P32 value rule, test that no open question is answered, or check whether a question's routing is relevant (note 5).
    - It did not catch the stale range in note 6.

## Citations sampled (all matched)
- **HF-04a:** lines 22, 24, 26, 46, 47, 51, 53, 62, 65–66, 77, 79, 87–90, 92, 94 and 102.
- **HF-03a:** lines 27, 31–37, 45, 46, 50 and 51.
- **HF-03b:** D01, D04, D05, D06 and D08 (lines 27–34); lines 44, 52, 74, 79 and 83; DF-04 at line 94.
- **TH-01:** IF-10 line 83, IF-14 87, IF-15 88, IF-16 89, IF-19 92, IF-26 99, IF-31 104, IF-32 105, IF-33 106, IF-35 108; RL2–RL9 at lines 36–43; line 45.
- **TH-12:** SO-02–04 lines 116–118, FI-01–14 lines 132–145, UI-01–22 lines 153–174, line 218, UP-02 258, UP-15–17 lines 271–273, UP-19 275, HD-01 74, UN.1/7/8 at lines 304, 310 and 311, UM.1 332, UR.1 343.
- **TH-02:** MA-01–03 lines 34–36, MA-06 39, MA-07 40, line 45, MP-05 219, MP-07 221, MP-21 235, MP-24 238; MI, MO, ME and MF rows at the stated lines.
- **TH-04:** AS-01–04 lines 39–42, line 44, AV-05 68, AV-06 69, AI-02 127, AI-07 132, AO-08 201, AP-01 267, AP-23 289, AP-37 303.
- **PD-02:** lines 44–50, FP-01–14 lines 105–118, line 120, IP-02 129, IP-04 131.
- **HF-07a:** lines 185, 271 and 272; CSV rows 66–71, which contain no binding, device or input field.
- **BIBLE:** lines 481, 483, 544 and 602.
- **TADR-001:** lines 23 and 39. **ADR 0005:** lines 11, 13, 15, 19 and 21.
- **Hashes:** all 13 stated hashes equal the values in the coordinator's `paper-check/source-manifest.json` (receipt; I did not recompute them).
- **Engine claims:** every Godot API name I searched for appears in the worktree's `artifacts/local/tasks/TH-18/ctx7/` retrieval files (existence only).

## Commands and receipts
- **Mine:** Read, Grep and Glob only. No shell commands, so no exit codes.
- **Coordinator receipts I relied on (level 4, not re-run):**
  - `coordinator-candidate-A2/exits.txt`: check:scope, check:docs, check:project, check:drift and the paper check each exit 0.
  - `paper-check.log`: 1243 of 1243 assertions passed; all 14 negative controls caught.
  - `check-drift.log`: 305 stated hashes, 0 mismatches, and no line for this file. The log doesn't show where it ran; EV-0400 says the worktree base.
  - `check-docs.log`: ran in the worktree.
  - `check-scope.log`: documentation-only, one path.

## Runtime
The system context says Opus 5 (`claude-opus-5[1m]`); a model can't verify its own identity. `CLAUDE_EFFORT` is not exposed to me, so its value is unavailable. I wrote, edited and committed nothing.