# PD-03 review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

## Verdict: PASS+NOTES

**Evidence level:** level 3 for the document contract, meaning I checked each item against the candidate's lines and walked WK-3 step by step. I had no shell tool, so I ran no commands. The level-4 evidence (paper check, `check:drift`, `check:docs`, `check:project`, `check:scope`) exists only as coordinator receipts. I read the receipts and the paper-check source but did not rerun them.

**Candidate identity:**
- The ref file `/home/andrew/Projects/scrapkeep/.git/refs/heads/wt/PD-03` contains `cceff383a6be4192092db66f6c792a0f448ba573`, and the worktree HEAD points to that ref.
- **Receipt:** `identity.txt` records parent `bb97c41…`, a clean status and one added path, `docs/product/sections/PD-03-sound-feel-events.md`.
- **Receipt:** `candidate-sha256.txt` gives the file hash as `3ebdf386…613d`.
- I read the file in the worktree and could not confirm that its bytes match the commit.

Below, "PD-03:N" means line N of `/home/andrew/Projects/scrapkeep-wt-PD-03/docs/product/sections/PD-03-sound-feel-events.md`.

## Definition-of-done items

**1. Families mapped to physical sources and trigger meanings: met (level 3).**
- All 13 families have rows at PD-03:50-71. Each row has a source, a trigger meaning, a Section 8 line and a Section 6 line.
- I checked every row's meaning against BIBLE lines 481-602 and 745-805. Each paraphrases its cited line accurately.
- Collection and fabrication are distinct. SE-02 (PD-03:51) ends in an arrival strike during the encounter. SE-03 (PD-03:52) ends in a seated latch after the install at the intermission, which matches BIBLE line 774 ("different endings") and TH-05 CM.7/CM.10/CM.12 at lines 356/359/361.
- Revival and companion rescue are distinct. SE-18 (PD-03:67) follows the Transition C acknowledgement, per HF-07b line 99. SE-20 (PD-03:69) is an ordinary outcome with no transition, per TH-10 DC-07 line 112 and WC.5 line 418. SE-20 never reuses the relay-catch vocabulary, which satisfies BIBLE line 779.

**2. Proposal vs browser proof vs accepted invariant: met (level 3).**
- There are 22 SE rows labelled proposal, 7 BP rows labelled browser proof and 14 SI rows labelled accepted invariant.
- SI-01 (PD-03:97) is the threats-first invariant, carried by BIBLE line 795 and BD-17 line 49. UD-01 to UD-14 (PD-03:116-129) are the unselected details.
- I checked the BP rows against the source files:
  - The orchard tone table at `src/orchard/main.js:121-147` has no entry for jump, deploy, ultimate, companion, lose, phase or spawn.
  - The simulation emits those events at `simulation.js` lines 474, 500, 590, 601, 1427, 1471, 1590, 1667 and 1770, which matches BP-02.
  - The baseline code at `src/audio.js:44-104` and `src/main.js:265-270`, 452 and 595 matches BP-04 to BP-07.

**3. Audition matrix and fatigue method: met (level 3).**
- AU-01 to AU-06 (PD-03:158-163) cross the three scenarios with quiet playback and sound disabled. Each cell names a method, the evidence it needs and the rows it exercises.
- FT-01 and FT-02 (PD-03:169-170) define the fatigue method. PD-03:154 states that no cell has run, and no row claims a result.

**4. Q-P13/17/20/28/31/32 blockers: met (level 2).**
- All six questions appear at PD-03:252-257, each with the rows it gates and the value "none".
- Their answer states match TRACKING.md lines 238-257: only Q-P13 (EV-0322) and Q-P32 (EV-0248, EV-0284) have partial answers, and the candidate reads them as given.
- Their scopes match BACKLOG.md lines 2982, 3038, 3080, 3192, 3234 and 3248.
- Every unsourced value is an unset SP row (PD-03:137-150). No row states an asset count, recording scope or loudness value.

**Packet rules:**
- **HF-04a line 24:** the candidate limits the randomness rule to `EncounterRandomState` and cites it no wider (PD-03:17, SI-11 at PD-03:107).
- **Durable fields:** `run.lifecycle.revival_spent`, `run.lifecycle.terminal` and `run.lifecycle.outcome` are in the HF-07a CSV at lines 63-65, and `preferences.sound`/`impact_shake`/`reduced_motion` at 68-71.
- **Music timing:** SI-02 and SI-03 (PD-03:98-99) keep every danger cue off music timing, and WK-1 step 5 places the phrase boundary after the warning.
- **Headings:** all seven are present.
- **Hashes:** 23 stated. That they match rests only on receipts: `check-drift.log` reports 0 mismatches and 0 unbound, and `paper-check.log` NC-08 shows the BIBLE hash matching.

## Scenario walked: WK-3 (PD-03:209-218)

1. The companion commits at P4 (DC-07, line 112).
2. The outcome and its recovery window publish at P6 (DC-08, line 113).
3. SE-20 plays and no transition runs (WC.5, line 418).
4. A later lethal outcome publishes with the revival unspent.
5. SE-17 plays while gameplay holds at RL7 (TH-01, line 41). No revived state is presented, as HF-07b line 96 requires.
6. Transition C is acknowledged (HF-07b, line 99).
7. O4 resumes the encounter (HF-04a, line 90).
8. SE-18 plays.

The order matches HF-07b line 99 ("only then may play resume … through O4"). The SI-07 gate holds.

## Blocking findings

None.

## Non-blocking notes

1. **Enemy stage mapping is blurred (PD-03:60-61).**
   - SE-11's committed moment merges TH-03 EN-1 (prepare, line 39) with EN-2 (the windup declaration, which TH-03 calls "Commit", line 40). The walks at PD-03:187-189 and 233-234 time SE-11 at the declaration.
   - SE-12 calls the EN-3 execution "Commitment and release". Both BIBLE line 495 and TH-03 put commit before execute.
   - Nothing says what SE-11 does if a preparation is abandoned, which EN-1's exit condition allows.
   - **Fix:** name the TH-03 stage for each of the three BIBLE line 777 cues, and state how an abandoned preparation is handled.
2. **SE-14 breaks the brief's own timing rule (PD-03:63).** PD-03:46 says a cue sounds from a published value and never earlier, but the navigation click is triggered from F-INPUT. The moment sentence is also garbled: "records a `UiRequest` Session reads F-PROCESS on D06".
3. **BP-04 misses one baseline sound.** It omits the class-selection note at `src/main.js:116` (`audio.note(330, …)`), which is a UI sound relevant to SE-14.
4. **Some seams to concurrent cards are missing.** PD-03:176 states seams only to TH-18, TH-19, SC-02 and SC-06. The BACKLOG scopes give SC-01 (class kits → SE-08, line 2214), SC-04 (enemy archetypes and attack references → SE-11 to SE-13, line 2310) and SC-08 (discoveries and dialogue → SE-21, SE-22 and UD-07, line 2438) seams too. None is stated.
5. **The paper check does not test these obligations** (script at `coordinator-candidate/paper-check.mjs`):
   - **Distinct meanings** (lines 301-313): tested by word overlap below 0.6 and inequality only, and only on the first row of each family. A reworded copy with the same meaning would pass.
   - **Music timing** (lines 45-50, 316-329): tested against a fixed word list. Synonyms such as measure, pulse, grid or sync pass. The negation filter strips any span that starts with no, not or never, so "sounds not before the next bar" passes. Only tables with a Label column are scanned, not UD, SP, walk rows or prose.
   - **Bible pages** (lines 279-282): the check confirms each cited line is non-blank and inside the section range (Section 6 is 469-615 and Section 8 is 741-808, both correct per the BIBLE `##` headings). It does not check that the line supports the meaning.
   - **Forbidden statements** (lines 373-380): only table rows are scanned; prose and bullets are not.
   - **Matrix cells** (line 336): a cell passes if its method and evidence text are over 30 characters.
   - **Row-ID citations** (line 395): a line passes if it contains the ID anywhere, so a range such as "EN-2 to EN-4" on another row would also match.
   - **Answered questions:** nothing tests that no open question is answered, beyond SP values being "unset" and question values being "none".

## Citations sampled (all match)

- **BIBLE:** lines 491, 495, 503, 509, 511, 572, 582, 590, 747, 755, 773-780, 795, 799 and 805. Sections 6 and 8 start at lines 469 and 741.
- **BIBLE_DECISIONS.md:** line 49 (BD-17). **ASSETS.md:** lines 7, 8, 15 and 17.
- **HF-04a:** lines 22, 24, 44, 46, 49, 63-67, 81, 90 and 100.
- **HF-07a:** lines 186, 188, 189 and 271, plus CSV lines 63-65 and 68.
- **HF-07b:** lines 90, 96, 99, 101 and 110. **HF-06a:** N-051 to N-053 at lines 124-126.
- **TH-01:** RL4 at 38, RL7 at 41, RL8 at 42, RL9 at 43, EC-03 at 169 and EC-04 at 170.
- **TH-02:** line 64, MO-08 at 125, MO-16 at 133, MC.2 at 291 and MC.10 at 299.
- **TH-03:** PL-4 and EN-1 to EN-4 at lines 38-42, AT-17 at 94, AO-01 at 129 and FM-06 at 217.
- **TH-04:** AI-21 at 146 and AE-02 to AE-04 and AE-07 at 169-174.
- **TH-05:** lines 128, 132, 160, 163, 166, 196-199, 260, 352 and 355-361.
- **TH-09:** lines 97, 100, 152, 155, 156 and 323. **TH-10:** lines 111-113, 196, 203 and 418.
- **TH-12:** lines 79, 82-84, 116, 117, 124 and 276. **TH-16:** lines 67, 113, 142, 248, 249 and 304.
- **PD-02:** lines 90-92 and 114.
- **BACKLOG:** the six questions and SC-01 to SC-08.
- **Source files:** the orchard and baseline audio lines listed under item 2.
- **Hashes:** not checked independently; only the receipts support them.

## Commands run

None, because this session had no shell tool; I used Read, Grep and Glob only. Coordinator receipts, which I read but did not rerun (`exits.txt`):
- `check:scope`: exit 0
- `check:docs`: exit 0
- `check:project`: exit 0
- `check:drift`: exit 0
- `paper-check.mjs`: exit 0, with 12 of 12 negative controls failing as required

## Model and effort

- **Model:** Opus 5 (`claude-opus-5[1m]`), according to the runtime system prompt. A model cannot verify its own identity by self-description.
- **CLAUDE_EFFORT:** could not be read, since I had no shell or environment access.
- **Possible substitution:** AGENTS.md pins Fable 5.1 medium for consequential review. If this review counts as consequential, Opus 5 is a substitution that the coordinator should record as a blocker.

I wrote, edited and committed nothing.