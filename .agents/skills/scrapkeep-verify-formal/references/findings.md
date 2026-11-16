# Findings from the run-flow model

A finding is a break that replayed on the real game. A break that did not replay is a lesson in [lessons.md](lessons.md), not a row here.

## Open

### F-1. A new run started during the launch swipe closes on the old run's part name

- Rule: `TakeNamesHeldPart`. Config: `today-store` and `today-nostore`.
- Steps, in the code's words:
  1. The player takes a reward gate. `sketches/core-loop/src/build/build.gd` `_on_gate_chosen` adds the part, and flow starts the launch swipe with the part's name (`_play_seam_take`).
  2. In the swipe's first 0.45 s (`WIND_S`), `flow.new_run()` runs. In the real game that is an R held for 0.5 s (`RESTART_HOLD`) that began before the gate, or Restart in the pause menu.
  3. `_begin_run` starts the new run with no parts. It calls no `_untake`, so the swipe keeps the name.
  4. The swipe closes over stage 1 of the new run and shows the old part's name.
- Harm: the screen says a part was taken that the new run does not hold. It is on screen for the hold and the reveal, up to about 1.8 s. Nothing is saved wrongly.
- Replay: `replay/new_run_under_swipe.gd` at `3adc2fd0e`, 16 November 2026, headless with the swipe forced live. Output: `step cover: take phase 3 word 'Impact Driver' visible true, run holds the part: false`, then `REPRODUCED`.
- Evidence limit: the replay calls `flow.new_run()` directly. No one has made the path by hand with a held R.
- The model's fix: `_begin_run` calls `_untake` (the `guarded-*` configs pass with `UntakeOnNewRun=TRUE`). The same class as the retry and run-end notes fixed in pull requests 1064 and 1066.

## Closed

None yet.
