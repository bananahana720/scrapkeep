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
- **VFM-09** · status: provisional · since: 2026-11-16 · origin: the first cold follow of this skill
  The check for "is this change covered" compares the sync commit with the working tree, and a change to a named guard is run by flipping that guard on the `today-*` configs. A replay of a break that comes from a change also runs on the sync commit as a control.
  Evidence: a fresh agent (Haiku 5.5) followed the skill against a planted removal of `_untake()` from `retry_stage`. The first wording, `<sync>..HEAD`, showed no diff for the uncommitted change; the agent still caught the break through `broken-retry`, replayed it (`word 'Impact Driver' visible true, run holds the part: false`) and got `word 'FWOOSH!'`, not reproduced, on the sync commit.
  Overturned by: —
- **VFM-10** · status: provisional · since: 2026-11-16 · origin: the first independent review of the model
  After the model passes, run the reach probes (`reach-store`, `reach-nostore`); each must break. They prove four paths can happen (a Continue, the boss entered under the swipe, a retry under the swipe, the summary), not every action. An action no probe names is not shown to fire, so a new action gets its own probe or a line in `references/coverage.md` saying it is unprobed. Also check that each stage rule reads the same function the code reads.
  Evidence: the review of pull request 1070 found `Resume` unreachable (no quit action led to a Continue with a store) and the swipe skipped at the world's last stage where the code skips it at the run's last (`is_run_last`), so the launch into the boss was never explored with a swipe. Both are corrected (`QuitRelaunch`, `RunLast`).
  Overturned by: —

## Changelog

| Date | Change |
| --- | --- |
| 2026-11-16 | VFM-01 to VFM-08 added with the skill. Model confirmed at `3adc2fd0e`. |
| 2026-11-16 | VFM-09 added after the cold follow; SKILL.md steps for the diff, guard flips and the replay command corrected. |
| 2026-11-16 | VFM-10 added after the review of pull request 1070: `QuitRelaunch` and `RunLast` added to the model, `guarded-lastgate` config added, the `broken-busy` and stage replay rows corrected. |
