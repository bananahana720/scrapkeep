# Proposed restraint rule

Proposal only. `music_engine.gd` was not edited.

Add `MAX_ACTIVE_LAYERS = 4`, counting the bass plus every additional musical layer, including SUB, WARM and FLEET. A layer means a musical part, not an oscillator or a chord's note count. Reserve one slot for REESE, the named bass layer. A cap on MELODIC alone would miss the extra bass and event parts.

Add `set_bed_live(on)` and per-area phrase sets, selected by a new `_select_arrangement()` from theme, phrase and game state. Pressure changes phrasing and timbre within the chosen set. It must not monotonically enable every curve. An event requesting a new part must nominate the part it replaces; a full set cannot grow.

Touch `_on_bar()` to commit sets on bar lines, and `_retarget()` to apply the chosen mask after pressure, overcharge, lounge and difficulty calculations. With a live cover, mute KEYS, HATS, KICK and SNARE, and exclude Fleet's anvil from the music bus. Pressure and boss floors cannot override that mask. Bass remains reserved.

Touch `_on_step()` and `_add_action()` to schedule departing parts' 15 ms fades immediately before the line, then admit incoming parts at the line with a 15 ms fade. Touch `_mix()` for these envelopes. Count fading parts against the cap; do not overlap two full sets. Invalidate queued changes when the theme/mode changes.

Touch `_start()` to reject unselected musical parts, including delayed echoes and fills. Give untagged musical stingers a budgeted layer. Immediate gameplay cues on the separate stinger bus retain their existing timing.

Verify pressure sweeps, overcharge/Fleet/boss combinations, delayed echoes, bed on/off and interrupted transitions. Assert the cap sample by sample and zero synth drum energy while a cover plays. Andrew's listening verdict remains the acceptance gate.
