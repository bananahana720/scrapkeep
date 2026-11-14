---
name: natural-progression-storyboard-gate
description: "For big Scrapkeep builds, go sketch → storyboard → agents converge → back to Andrew before expensive building; he is not rushing"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 843df1db-1f22-408a-875e-e5c6e3efae36
  modified: 2026-10-11T05:18:42.744Z
---

On 2026-09-27, after setting the early-access demo goal, Andrew said: "we can take things at a natural progression. So sketching, you know, storyboarding, meeting of the minds between yourselves and coming back to me ... I'm not trying to rush you."

**Why:** Expensive builds, such as Blender assets, whole stages and enemy rosters, are cheaper to redirect as storyboards. He wants to see the direction and shape it before it hardens, and he values the agents converging first.

The same day he widened this to every layer, "the same for audio and and character progression, game progression ... account progression ... story beats or threads", as "a good primer or baseline level of context to like truly kind of evolve and flower this game". So the gate is a **primer of four boards**:
- **Visual:** key frames and concept art.
- **Audio:** leitmotif and theme demos he can listen to, rendered to WAV.
- **Progression map:** in-run, character mastery and account/meta.
- **Story thread map:** beats per run and across runs.

**How to apply:** Before a heavy build, run a storyboard gate:
1. Produce key frames and concept art, with local Qwen-Image per [[qwen-image-2-1]] where visuals help.
2. Have the vision keeper and the relevant leads give notes, and reconcile them into one set.
3. Bring Andrew one page with the open choices as AskUserQuestion.
4. Build after that.

**Shape of the gate for a world (2026-10-10).** When the 30 park and Warden concept pictures were served as a card grid, Andrew said the storyboard clicks need to be "a way for the user to make their journey through to each of the climaxes of those worlds, aka the warden", with "more connecting material and more structure versus the concept art". So a world's gate is a journey strip, not a grid: one page per world (`design-v3/park/journeys/world-N-*.md`) with drop-in, every beat (You / You see / Pull / Pressure / Seconds / Music / Panel), the bay between the stages, the Warden climax beat by beat and the exit; the panels sit beside their beats; he approves or reworks per beat and once per world. Panels that no picture covers get drawn to fill the gaps. The page tool is `sketches/core-loop/tools/concept/journey_page.py`; verdicts go to the artifact db collection `journeys`.

His reaction to the first journey page (2026-10-10): "this is awesome... if we can make this come alive in terms of the actual game, that would be amazing... the different branching and forking... all the different paths... the art style, it looks immaculate." So the journey strip is the storyboard format to keep, the branching fans are a feature to make legible in play, and the Astra Southwest stylized finish is the approved park look.

Code-only or well-specified work can proceed meanwhile. Don't rush to a finished build to impress; staged progress is the expectation. Related: [[mid-flight-direction-harmonize]], [[build-mechanic-callbacks]].
