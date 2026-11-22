# What SoundArbiter.tla stands for

`models/SoundArbiter.tla` checks the music deck ownership priority stack and melodic lane lease (Sound V4): stage roaming, champions, Warden fights and their sections (`build`, `open`, `drop`, `break`), boss arenas and phase 3 finales, pilot radio pins and unpins, ultimate flight builds and returns, player death, telegraph warnings, and June's set-director answers with epoch-stamped stem trims. This page maps each step to the code. `scripts/gate/model-receipts.mjs` reads every source path on this page as the list of covered files, and the last line as the sync commit.

The covered files:

- `sketches/core-loop/src/presentation/music_arbiter.gd`: pure priority stack `resolve(state)` deciding the active deck owner (`dead`, `menu`, `boss_finale`, `launch`, `boss`, `warden`, `ult`, `radio`, `champion`, `moment`, `stage`).
- `sketches/core-loop/src/presentation/melody_lease.gd`: melodic lane booking (`book`, `release`, `bump_epoch`) and June preemption (`should_preempt`).
- `sketches/core-loop/src/presentation/audio.gd`: `_arbiter_state`, `radio_play`, `radio_release`, `_ace_return`, `_begin_boss`, `phase_music`, `_champion_joined`, `_champion_gone`, `warden_took_band`, `warden_engaged`, `_tend_champions`, `_flush_flow` (`dead`/`end`/`run`/`idle`), `_tend_set`, `_set_answer_spoiled`, and `_drop_set_answer`.
- `sketches/core-loop/src/presentation/ace_sequencer.gd`: `trim_epoch`, `trim_at`, `trim_bar`, `invalidate_trims`, and `_run` epoch validation on `"trim"` and `"sweep"`.

## Steps

| Model step             | Code |
| ---------------------- | ---- |
| `ChampionJoins`        | audio.gd `_champion_joined`: tracks the champion and asks `MusicArbiter.resolve(_arbiter_state())`; only loads `champion-hype` when the arbiter grants `"champion"`. |
| `ChampionDies`         | audio.gd `_champion_gone`: drops the champion and restores the stage pack only when `MusicArbiter.resolve(_arbiter_state())` returns `"stage"` or `"moment"`. |
| `WardenEngages`        | audio.gd `warden_took_band` and `warden_engaged`: clears `_champion_hyped`, replaces a flat champion pack with the sectioned stage pack (`_ace_stage(..., true)`), and commits Warden form. |
| `WardenSectionChanges` | ace_sequencer.gd `_commit`, `follow_guard`, `drop_now`, `warden_broken`: moves between `build`, `open`, `drop`, and `break` while incrementing `trim_epoch` and triggering melody preemption in `_tend_set`. |
| `EnterBossArena`       | audio.gd `boss_arena_entered` -> `_begin_boss`: records `_boss_arena_track`, clears `_champion_hyped` and `radio_finale`, and starts the boss track unless radio is pinned. |
| `BossPhase3Finale`     | audio.gd `phase_music(3)`: drops any held radio track with reason `"finale"` using `_active_boss_track()`, starts the boss finale track, and locks out `radio_play` while `radio_finale` is true. |
| `RadioPin`             | audio.gd `radio_play`: refuses during a live boss finale, captures `_radio_boss` before `spin()` overwrites `engine.track`, and pins the radio track. |
| `RadioUnpin`           | audio.gd `radio_release`: captures `_active_boss_track()`, drops radio, and consults `MusicArbiter.resolve(_arbiter_state())` to restore boss finale, boss arena (including phase 2/3 via `phase_music`), Warden, champion, miniboss, moment, or stage. |
| `UltimateStarts`       | audio.gd `_on_ultimate_started`: arms `_ult_armed` and stops the stage/champion recorded band for the synth build. |
| `UltimateEnds`         | audio.gd `_on_ultimate_landed` / `_on_ultimate_cancelled` -> `_ace_return`: consults `MusicArbiter.resolve(_arbiter_state())`, restoring Warden or live champion before falling back to stage roam. |
| `WarningToggle`        | audio.gd `_focus` sets `_focus_until`; `_tend_set` checks `clock < _focus_until` via `_melody_lease.should_preempt`, drops June's answer, and calls `ace.invalidate_trims()`. |
| `DjStartJuneAnswer`    | audio.gd `_tend_set`: books June's answer through `_melody_lease.book` and stamps trims with `ace.trim_epoch`. |
| `DjEndJuneAnswer`      | audio.gd `_drop_set_answer` (with `ace.invalidate_trims()` on spoiled preemption) or bar expiry clears `_set_answer` and calls `_melody_lease.release()`. |
| `PlayerDies`           | audio.gd `_flush_flow` `"dead"` branch: drops radio, disarms launch, calls `_disarm_ultimate()`, and clears `_boss_arena_track`. |

## Guards

| Constant               | The guard in the code | Config that turns it off | Rule that must break |
| ---------------------- | --------------------- | ------------------------ | -------------------- |
| `GuardWardenOverChamp` | `MusicArbiter.resolve` ranks Warden above champion; `warden_took_band` and `warden_engaged` replace flat `champion_hype` with `_ace_stage(..., true)`. | `sound-broken-warden-champ` | `WardenOwnsFightMusic` |
| `GuardUnpinBoss`       | `radio_play` records `_radio_boss` when pinned in boss arena; `radio_release` restores boss track through `MusicArbiter`. | `sound-broken-unpin-boss` | `BossMusicInArena` |
| `GuardUltStack`        | `_ace_return` asks `MusicArbiter` and calls `_restore_champion_pack` while a champion lives. | `sound-broken-ult-champ` | `UltimateRestoresChampion` |
| `GuardDeathClearsUlt`  | `_flush_flow` `"dead"` calls `_disarm_ultimate()` clearing `_ult_armed` and `_ult_took_band`. | `sound-broken-death-ult` | `DeathClearsUltFlight` |
| `GuardMelodyLease`     | `MelodyLease.should_preempt` drops June's answer on warning, directed section, or pack switch. | `sound-broken-melody-clash` | `OneMelodyNoClash` |
| `GuardEpochTrim`       | ace_sequencer.gd `trim_epoch` + `invalidate_trims` skips stale epoch-stamped trims and sweeps. | `sound-broken-stale-trim` | `NoStaleTrim` |

## Bounds

One stage with one champion, one Warden with four sections (`build`, `open`, `drop`, `break`), boss arena phases 1 and 3, radio live vs pinned, one ultimate flight, warning toggle, June DJ answer, and a 3-value cyclic epoch (`0..2`).

## Configs

Run `bash models/make-sound-configs.sh`, then plain TLC on each `sound-*.cfg` with `SoundArbiter.tla`.

| Config | Stands for | Must report |
| ------ | ---------- | ----------- |
| `sound-today` | the code at the sync commit, every guard in place | no break, in at least the pinned 1,116 distinct states |
| `sound-broken-*` | one guard off, as the Guards table lists | the named rule breaks |
| `sound-reach-*` | one probe each for Warden-over-champion, boss finale, boss radio pin, ultimate flight, June answer, and death | every probe breaks |

`node scripts/gate/model-receipts.mjs --out <dir> --row sound-arbiter-safe` writes the receipt from `sound-today` and the six `sound-broken-*` plants.

## The tests behind it

`sketches/core-loop/tests/sound_arbiter_test.gd` exercises the live `Audio` and `AceSequencer` stack on every rule above: Warden preempting a live champion, boss-backed radio records on Stage 1 returning to Stage 1, boss phase 2 radio unpin restoring phase 2 music, boss phase 3 finale overriding a mid-arena radio pin, ultimate landing and radio release restoring a live champion, death clearing ultimate flight flags, null-safe `_drop_set_answer`, `MelodyLease` preemption, `trim_epoch` rejection, and SFX voice-class budgets. set_director_test.gd, warden_form_test.gd, phase_music_test.gd, and radio_test.gd cover the individual subsystems.

## Not modelled

Audio sample timing in seconds, bus DSP filter cutoffs and reverb (music_dsp.gd, covered by music_dsp_test.gd), SFX polyphony counts (sfx_budget.gd, covered by sound_arbiter_test.gd), jukebox spins on the title screen, launch-to-next-stage landings (`RunFlow.tla` models launch flow), minibosses and moment tunes below champion priority, and anything drawn or heard on speakers.

Sync commit: fb1f3adec (branch w45/sound-v4-arbiter-dj, 21 November 2026: review fixes for boss-radio edge cases, threat budget, MelodyLease encapsulation, and MusicDsp dirty check)
