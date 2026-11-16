# Verify-formal lessons

## Lessons

- **VFM-01** · status: provisional · since: 2026-11-16 · origin: the first runs of the run-flow model
  The model counts no seconds, so it reports orders no player can make. Name each fact about time as one constant with its source in the code, and keep a config that turns it off so the reader sees what the assumption hides.
  Evidence: before `StageOutlastsSwipe`, `TakeNamesHeldPart` broke by a 13-step path that breaks a Warden and takes a gate inside one 0.45 s wind; the `untimed` config keeps that path.
  Overturned by: —
- **VFM-02** · status: provisional · since: 2026-11-16 · origin: the first runs of the run-flow model
  A break is a candidate until it replays on the real game, one model step per call. A step that cannot be made is a guard the model lacks, and it goes into the model as a named constant, not out of it.
  Evidence: `PickHeard` broke by pressing Escape and Space under the swipe; `sketches/core-loop/src/game.gd` `_screen_key` and `sketches/core-loop/src/ui/screens.gd` `_input` swallow those keys, so the path was a modelling error (now `SwipeOwnsKeys`). `TakeNamesHeldPart` replayed with `replay/new_run_under_swipe.gd` and is finding F-1.
  Overturned by: —
- **VFM-03** · status: provisional · since: 2026-11-16 · origin: the first runs of the run-flow model
  A broken variant starts from the config with every guard in place, turns one guard off and checks the one rule that guards it. Built on a config that already fails, every variant fails the same way and shows nothing.
  Evidence: the first `broken-retry`, `broken-end` and `broken-spend` configs all reported the same `TakeNamesHeldPart` path as the baseline.
  Overturned by: —
- **VFM-04** · status: provisional · since: 2026-11-16 · origin: the first runs of the run-flow model
  A guard that no rule can see failing does not get a constant. Either a rule is missing, or the guard protects nothing a player can see; say which.
  Evidence: clearing `_taken_part` in `_play_seam_take` could not break any rule, because `_begin_run` and `resume_run` clear it too; its constant was removed.
  Overturned by: —
- **VFM-05** · status: provisional · since: 2026-11-16 · origin: the wave 42 reviews of the reward gate names
  An interruption is an action enabled in every state where the code allows the call, not where the design expects it. Reviews found this class one case at a time; the model finds the siblings.
  Evidence: pull request 1064's review noted "a retry during the launch flight still stamps the part's name"; pull request 1066 added `_untake` to `retry_stage` and `_end_run`; the model then found the same fault through `new_run` (F-1), which no review had named.
  Overturned by: —
- **VFM-06** · status: provisional · since: 2026-11-16 · origin: reading `sketches/core-loop/src/core/flow.gd` for the model
  Two handlers of one signal emission are one action with a choice of order, because nothing else can run between them. Modelled as two actions, the checker puts a death or a retry between them, which cannot happen.
  Evidence: `sketches/core-loop/src/core/flow.gd` `_on_reward_chosen` and `_on_launched` (the comment above `_on_launched`: world may launch from inside its own `reward_chosen` handler).
  Overturned by: —
- **VFM-07** · status: provisional · since: 2026-11-16 · origin: the A stack formal verification workflow
  A pass is evidence about the model inside its bounds. It becomes evidence about the code only through the coverage table, the sync commit and a scratch break of the real code that the check catches.
  Evidence: `references/coverage.md`; the scratch break recorded in the changelog below.
  Overturned by: —
- **VFM-08** · status: provisional · since: 2026-11-16 · origin: the first runs of the run-flow model
  State a rule at the moment the player meets the fact. A rule held for as long as a word stays on screen fails on a death one frame after a correct launch, which is noise.
  Evidence: `TakeNamesHeldPart` first read the swipe's hold phase and broke on a death after the cut; it now reads the moment the swipe closes.
  Overturned by: —

## Changelog

| Date | Change |
| --- | --- |
| 2026-11-16 | VFM-01 to VFM-08 added with the skill. Model confirmed at `3adc2fd0e`. |
