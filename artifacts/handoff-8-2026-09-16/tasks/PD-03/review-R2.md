# PD-03 review R2

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**Verdict: FAIL.** PD-03 candidate `3baba5a354df013cfe42be64beefdbd53191e287`, attempt PD-03-A2, closure repair review R2.

I found one blocking contradiction with an admitted section. A4, A20 and the stale seam wording are repaired as the integrated read requires. A5 uses the read's wording, with one narrowing noted below.

**Evidence level:** 3 for B3 (walked step by step below). 2 for the definition-of-done items and citations (checked against file and line). The level-4 paper check and `check:*` results come only from coordinator receipts; I did not run them.

Identity: `/home/andrew/Projects/scrapkeep/.git/refs/heads/wt/PD-03-A2` reads `3baba5a…`, which is the candidate. The receipt `coordinator-candidate-A2c/identity.txt:2-8` gives parent `234c1d7`, one changed path and a clean status. That last part is a receipt, not something I checked. I compared against the file on main (`/home/andrew/Projects/scrapkeep/docs/product/sections/PD-03-sound-feel-events.md`). That this equals the base copy is inference: its line 5 still names base `bb97c41`, and the packet says nothing cited changed.

## Blocking finding

**BF-1: the UI-only input exception conflicts with TH-16, which is admitted, and the candidate doesn't disclose it.**
- **What the candidate says:** `PD-03…md:48` and the SE-14 row at `:65` let SE-14 sound "at the input moment", which the text calls "the only departure" from the published-value rule. SI-04 at `:102` states the exception but lists `TH-16 line 304` as one of its carriers.
- **What TH-16 says:**
  - `TH-16-rendering-integration.md:304` (Seam 4): "an audible cue consumes a published value."
  - RI-14 at `:181`: "Play a cue, effect, animation or audio voice from a published fact", in F-PROCESS, or F-SIGNAL for an engine completion.
  - RV-5 at `:55`: feedback plays from "one published fact" after `present_committed_result` or `present_snapshot` delivered it.
- **Walk (SE-14, gate SI-04):**
  1. The player moves focus or activates a control on the dashboard.
  2. F-INPUT runs. InputAdapter updates the input context, and Presentation records a `UiRequest` (HF-04a `:46`; TH-16 RI-12 `:179`).
  3. The click plays. At this step no published fact exists and the callback is not F-PROCESS. This is where RI-14, RV-5 and Seam 4 fail.
  4. Session reads the request on D06 in F-PROCESS (TH-12 SO-02 `:116`), and SE-15 or SE-16 follows.
- **Why it matters:** SI-04 still decides nothing, so that gate passes. But the one explicit rule B3 asked for (`integrated-read-R1.md:21`) now disagrees with an admitted technical rule. Handing the callback to TH-17 at `:48` doesn't resolve this, because TH-16 already fixes the playback callback and its input. Contradictions with admitted rows are blocking under the packet (`review-packet-R2.md:16`). Deviating silently is forbidden (`ORCHESTRATOR.md:138`), and Andrew's EV-0453 answer (`TRACKING.md:668`) addressed only PD-03 line 46 against SE-14.
- **Fix:**
  - Name TH-16 RI-14 `:181`, RV-5 `:55` and Seam 4 `:304` beside the exception as rules SE-14 departs from.
  - Move the exception's carrier in SI-04 to TRACKING EV-0453, and keep TH-16 line 304 only for gameplay cues.
  - Gate SE-14's input-moment playback on an amendment request under ORCHESTRATOR "Specification contradictions" (a TH-16 revision routed through TH-17), unless the coordinator records EV-0453 as an accepted amendment and propagates it to TH-16.
  - Add a paper-check assertion and a negative control for this.

## Definition of done
1. **Event map:** met, level 2. All 13 families appear in SE-01 to SE-22 (`:52-73`), each with a physical source, a trigger meaning and Bible pages in § 8 and § 6. Collection/fabrication (`:53-54`) and revival/rescue (`:69,71`) are distinct, restated at `:75`.
2. **Labels:** met, level 2. Proposal rows `:52-73`, browser proof `:83-89`, accepted invariants with SI-01 as threats-first `:99-112`, unselected details `:118-131`. BF-1 affects how SI-04's carrier is stated.
3. **Audition matrix:** met, level 2. AU-01 to AU-06 (`:160-165`) cover three scenarios, each at quiet playback and sound disabled, with a method and evidence per cell. Fatigue methods FT-01 and FT-02 are at `:171-172`.
4. **Six questions:** met, level 2. `:252-259`, with value "none" and gated rows. No asset count, recording scope, loudness value or audition result appears. The coordinator paper-check receipt shows 20/20 negative controls failing as required (receipt only).

## Named findings
- **B3:** stated at `:48`, `:65`, `:102`. Incomplete because of BF-1.
- **A4:** repaired. SE-11 at `:62` and SE-12 at `:63` use the read's wording. The abandonable-preparation cue stays unselected (UD-11 `:128`), and WK-1 step 1 is updated (`:189`).
- **A5:** repaired with the read's verbatim wording (`:73`), which HF-07b `:139` supports.
- **A20:** repaired. BP-04 at `:86` matches `src/main.js:116`, which is `audio.note(330,…)` in the class button handler. The seams are at `:178`.
- **Stale seam wording:** repaired at `:178`. No sibling bytes are cited.

## Non-blocking notes
- **N1:** Old A4 wording survives in two places: AU-01 at `:160` ("each enemy's preparation, commitment and recovery") and `:261` ("whose preparations SE-11 to SE-13 voice").
- **N2:** SE-22's A5 wording is narrower than TH-09 LD-03 `:97`, which also allows "the Transition A it rides (LU-01)".
- **N3:** SE-14's trigger meaning (`:65`) says "an interface control was activated", where Bible `:778` says "a committed selection". It is broader, but not in conflict.
- **N4:** The TH-17 seam bullet (`:176`) doesn't list the UI click plumbing that `:48` hands to TH-17.
- **N5:** "Handoff-8 closure target" (`:178`) is never tied to a SHA. TH-18 and SC-08 have since been reopened (EV-0453), but the past tense stays accurate.
- **N6:** The paper check's closure assertions (`paper-check.mjs:480-520`) only check that exact strings are present. They don't test whether SI-04's carriers support its text, whether other admitted sections conflict (BF-1), or the leftover wording in N1. Distinct meanings and music timing are checked by word matching only.

## Citations sampled
All matched unless noted.
- HF-04a `:24`, `:46`, `:81`
- HF-07b `:139`
- TH-03 EN-1, EN-2, EN-3 at `:39-41`
- `src/main.js:116`
- PD-02 FP-10 `:114`
- TH-12 HD-06 `:79` and SO-02 `:116`
- TH-16 RC-04 `:67`
- TH-16 `:304`: the line is correct, but it conflicts with the exception (BF-1).
- TH-09 LD-03 `:97`: see N2.
- BIBLE `:602` and `:778`
- TRACKING EV-0453 `:668`

I did not compute any SHA256 hashes myself. Hash agreement rests on the coordinator's `check-drift.log:2` (product pass, 0 mismatches).

## Commands and runtime
- **Commands:** I ran no shell commands, since this session has no shell tool; I used only Read, Grep and Glob. The exit codes in `exits.txt:1-5` (all five 0) are coordinator receipts.
- **Model:** the runtime system prompt names claude-opus-5[1m]. A model can't verify its own identity by self-description.
- **CLAUDE_EFFORT:** unavailable; this host doesn't expose it to me.
- **Writes:** I wrote, edited and committed nothing.