# What SoundArbiter.tla stands for

`models/SoundArbiter.tla` checks the music deck ownership priority stack, melodic lane lease, and festival deck moves (Sound V4): stage roaming, champions, Warden fights and their sections (`build`, `telegraph`, `open`, `drop`, `break`), boss arenas and phase 3 finales, pilot radio pins and unpins, ultimate flight builds and returns, player death, telegraph warnings, June's set-director answers with epoch-stamped stem trims, and the festival deck's kick-locked pump and build/breath/drop one-shots. This page maps each step to the code. `scripts/gate/model-receipts.mjs` reads every source path on this page as the list of covered files, and the last line as the sync commit.

The covered files:

- `sketches/core-loop/src/presentation/music_arbiter.gd`: pure priority stack `resolve(state)` deciding the active deck owner (`dead`, `menu`, `boss_finale`, `launch`, `boss`, `warden`, `ult`, `radio`, `champion`, `moment`, `stage`).
- `sketches/core-loop/src/presentation/melody_lease.gd`: melodic lane booking (`book`, `release`, `bump_epoch`) and June preemption (`should_preempt`).
- `sketches/core-loop/src/presentation/deck_moves.gd`: deck preset policy (`tend`, `on_drop`, `PUMP`, `PUMP_VIKING`, `BUILD_TIERS`) gating pump and build/breath/drop one-shots for `--deck=festival` and `--deck=viking` on the arbiter and live Warden section.
- `sketches/core-loop/src/presentation/audio.gd`: `_arbiter_state`, `radio_play`, `radio_release`, `_ace_return`, `_begin_boss`, `phase_music`, `_champion_joined`, `_champion_gone`, `warden_took_band`, `warden_engaged`, `_tend_champions`, `_flush_flow` (`dead`/`end`/`run`/`idle`), `_tend_set`, `_tend_deck`, `_follow_warden_form`, `_ace_end_at`, `_set_answer_spoiled`, and `_drop_set_answer`.
- `sketches/core-loop/src/presentation/ace_sequencer.gd`: `trim_epoch`, `trim_at`, `trim_bar`, `invalidate_trims`, `_run` epoch validation on `"trim"` and `"sweep"`, `set_pump`, `pump_depth_for`, `pump_active`, `shot_at`, `cancel_shots`, and shot cleanup on `stop` and `start_level` (`invalidate_trims` leaves deck shots intact so `--set-director=on` and `--deck=*` coexist).

## Steps

| Model step             | Code |
| ---------------------- | ---- |
| `ChampionJoins`        | audio.gd `_champion_joined`: tracks the champion and asks `MusicArbiter.resolve(_arbiter_state())`; only loads `champion-hype` when the arbiter grants `"champion"`. |
| `ChampionDies`         | audio.gd `_champion_gone`: drops the champion and restores the stage pack only when `MusicArbiter.resolve(_arbiter_state())` returns `"stage"` or `"moment"`. |
| `WardenEngages`        | audio.gd `warden_took_band` and `warden_engaged`: clears `_champion_hyped`, replaces a flat champion pack with the sectioned stage pack (`_ace_stage(..., true)`), and commits Warden form. |
| `WardenSectionChanges` | ace_sequencer.gd `_commit`, `follow_guard`, `drop_now`, `warden_broken`: moves between `build`, `telegraph`, `open`, `drop`, and `break` while incrementing `trim_epoch`, preempting June in `_tend_set`, and reconciling festival deck pump/shots in `_tend_deck`. |
| `EnterBossArena`       | audio.gd `boss_arena_entered` -> `_begin_boss`: records `_boss_arena_track`, clears `_champion_hyped` and `radio_finale`, and starts the boss track unless radio is pinned. |
| `BossPhase3Finale`     | audio.gd `phase_music(3)`: drops any held radio track with reason `"finale"` using `_active_boss_track()`, starts the boss finale track, and locks out `radio_play` while `radio_finale` is true. |
| `RadioPin`             | audio.gd `radio_play`: refuses during a live boss finale, captures `_radio_boss` before `spin()` overwrites `engine.track`, and pins the radio track. |
| `RadioUnpin`           | audio.gd `radio_release`: captures `_active_boss_track()`, drops radio, and consults `MusicArbiter.resolve(_arbiter_state())` to restore boss finale, boss arena (including phase 2/3 via `phase_music`), Warden, champion, miniboss, moment, or stage. |
| `UltimateStarts`       | audio.gd `_on_ultimate_started`: arms `_ult_armed` and stops the stage/champion recorded band for the synth build. |
| `UltimateEnds`         | audio.gd `_on_ultimate_landed` / `_on_ultimate_cancelled` -> `_ace_return`: consults `MusicArbiter.resolve(_arbiter_state())`, restoring Warden or live champion before falling back to stage roam. |
| `WarningToggle`        | audio.gd `_focus` sets `_focus_until`; `_tend_set` checks `clock < _focus_until` via `_melody_lease.should_preempt`, drops June's answer, and calls `ace.invalidate_trims()`. |
| `DjStartJuneAnswer`    | audio.gd `_tend_set`: books June's answer through `_melody_lease.book` and stamps trims with `ace.trim_epoch`. |
| `DjEndJuneAnswer`      | audio.gd `_drop_set_answer` (with `ace.invalidate_trims()` on spoiled preemption) or bar expiry clears `_set_answer` and calls `_melody_lease.release()`. |
| `DeckEnablePump`       | audio.gd `_tend_deck` -> deck_moves.gd `tend` -> ace_sequencer.gd `set_pump`: enables sidechain pump on sectioned stage packs while the arbiter allows the DJ. |
| `DeckBookShot`         | deck_moves.gd `tend` / `on_drop` -> ace_sequencer.gd `shot_at`: books build (in `telegraph`), downlifter (in `open`), or swell+impact (in `drop`) on the sectioned stage pack. |
| `DeckFinishShot`       | ace_sequencer.gd `render` / `cancel_shots`: finishes or fades out an active deck one-shot. |
| `PlayerDies`           | audio.gd `_flush_flow` `"dead"` branch -> `_ace_end_at`: drops radio, disarms launch, calls `_disarm_ultimate()`, clears `_boss_arena_track`, and clears deck pump and shots. |

## Guards

| Constant               | The guard in the code | Config that turns it off | Rule that must break |
| ---------------------- | --------------------- | ------------------------ | -------------------- |
| `GuardWardenOverChamp` | `MusicArbiter.resolve` ranks Warden above champion; `warden_took_band` and `warden_engaged` replace flat `champion_hype` with `_ace_stage(..., true)`. | `sound-broken-warden-champ` | `WardenOwnsFightMusic` |
| `GuardUnpinBoss`       | `radio_play` records `_radio_boss` when pinned in boss arena; `radio_release` restores boss track through `MusicArbiter`. | `sound-broken-unpin-boss` | `BossMusicInArena` |
| `GuardUltStack`        | `_ace_return` asks `MusicArbiter` and calls `_restore_champion_pack` while a champion lives. | `sound-broken-ult-champ` | `UltimateRestoresChampion` |
| `GuardDeathClearsUlt`  | `_flush_flow` `"dead"` calls `_disarm_ultimate()` clearing `_ult_armed` and `_ult_took_band`. | `sound-broken-death-ult` | `DeathClearsUltFlight` |
| `GuardMelodyLease`     | `MelodyLease.should_preempt` drops June's answer on warning, directed section, or pack switch. | `sound-broken-melody-clash` | `OneMelodyNoClash` |
| `GuardEpochTrim`       | ace_sequencer.gd `trim_epoch` + `invalidate_trims` skips stale epoch-stamped trims and sweeps. | `sound-broken-stale-trim` | `NoStaleTrim` |
| `GuardDeckArbiter`     | audio.gd `_tend_deck` / `radio_play` + deck_moves.gd `tend` + ace_sequencer.gd `pump_depth_for` gate pump (`build`/`telegraph`/`drop`) and deck shots (`build`/`telegraph`/`open`/`drop`) on arbiter `allow_dj`, sectioned packs, and allowed Warden sections. | `sound-broken-deck-arbiter` | `DeckObeysArbiter` |
| `GuardDeckShotClean`   | deck_moves.gd `tend` / `on_drop` + ace_sequencer.gd `cancel_shots` / `stop` / `start_level` + audio.gd `_ace_end_at` cancel shots on stop, pack change, death, back-to-back drop, or leaving the causing section. | `sound-broken-stale-shot` | `NoStaleShot` |

## Bounds

One stage with one champion, one Warden with five sections (`build`, `telegraph`, `open`, `drop`, `break`), boss arena phases 1 and 3, radio live vs pinned, one ultimate flight, warning toggle, June DJ answer, festival deck pump and one-shot kind (`none`, `build`, `breath`, `drop`), and a 3-value cyclic epoch (`0..2`).

## Configs

Run `bash models/make-sound-configs.sh`, then plain TLC on each `sound-*.cfg` with `SoundArbiter.tla`.

| Config | Stands for | Must report |
| ------ | ---------- | ----------- |
| `sound-today` | the code at the sync commit, every guard in place | no break, in at least the pinned 4,890 distinct states |
| `sound-broken-*` | one guard off, as the Guards table lists | the named rule breaks |
| `sound-reach-*` | one probe each for Warden-over-champion, boss finale, boss radio pin, ultimate flight, June answer, deck pump, deck shot, and death | every probe breaks |

`node scripts/gate/model-receipts.mjs --out <dir> --row sound-arbiter-safe` writes the receipt from `sound-today` and the eight `sound-broken-*` plants.

## The tests behind it

`sketches/core-loop/tests/sound_arbiter_test.gd` exercises the live `Audio` and `AceSequencer` stack on the arbiter, melody lease, trim epochs, and SFX voice-class budgets. `sketches/core-loop/tests/deck_moves_test.gd` exercises `--deck=off` parity, `--deck=festival` and `--deck=viking` pump breakpoints and non-pumped/flat/arbiter gating, build/breath/drop shot timing and cleanup on `stop`, pack change, death, back-to-back drops, and `--set-director=on` preemption, and `deck_fx` warning-lane notch, peak bounds, and exact-zero endpoints. `sketches/core-loop/tests/set_director_test.gd`, `sketches/core-loop/tests/warden_form_test.gd`, `sketches/core-loop/tests/phase_music_test.gd`, and `sketches/core-loop/tests/radio_test.gd` cover the individual subsystems.

## Not modelled

Audio sample timing in seconds, bus DSP filter cutoffs and reverb (music_dsp.gd, covered by music_dsp_test.gd), SFX polyphony counts (sfx_budget.gd, covered by sound_arbiter_test.gd), festival deck synthesis and warning-lane spectrum (deck_fx.gd, covered by deck_moves_test.gd), jukebox spins on the title screen, launch-to-next-stage landings (`RunFlow.tla` models launch flow), minibosses and moment tunes below champion priority, and anything drawn or heard on speakers.

Sync commit: f0383feea (stage/alpha-w46, 22 November 2026: W46-A1 audio merged; read by the Gate. Changes outside the arbiter, lease and deck state machine: Brindle phase clash moved into _trigger_boss_phase with phase 1 keeping its section and phase plan but no clash, phase_music reads the active band's bar through _next_bar/_bar_len, _begin_boss closes the synth Warden form, call_in stays quiet while _focus_until holds, synth drop room and Kindness, babble and own-sound rows)

Sync commit: 700e289a1 (stage/alpha-w46, 24 November 2026, E3-04 PR #1260 merge: `sketches/core-loop/src/presentation/audio.gd` adds 17 plain `player`/`ui` cadence/rail/site-flip cues (none ducks, pins, owns music, or evicts `threat`), Audit A Note #4 `_boss_phase`/`_phase_music_done` reset hygiene across run/stage/arena/retry/defeat/phase-1 while keeping phase 2 across `radio_release()`, `NOTIFICATION_PREDELETE` worker settle, and opt-in `--voice=tts|synth` sidecar loader defaulting to `synth` with `cannon` synth-only; no arbiter, lease, or deck state machine transition changed — `sound-today` clean in 4,890 distinct states, 8/8 plants caught)

Sync commit: 049307c66 (stage/alpha-w46, 24 November 2026, Sound W46-A1 follow-up PR #1263 merge: `sketches/core-loop/src/presentation/audio.gd` and music_engine.gd scope synth-form build cancellations with `cancel_build(owner := "")` so closing synth form never clears brindle_hp, start_build, or planned_drop builds; no arbiter, lease, or deck state machine transition changed — `sound-today` clean in 4,890 distinct states, 8/8 plants caught)

Sync commit: 01ada29a0 (branch w50/sync-w47-w49-unified, 25 November 2026, W50-SYNC: of the covered files only `sketches/core-loop/src/presentation/audio.gd` changed, routing boss phase sections through `_set_boss_phase_section` and logging `mind_finale_lift` on phase-3 drops; no music arbiter, melodic lease, trim epoch, or deck moves state machine transition changed)

Sync commit: 4657692058523576912f6adeaf30d560a6ffa8c9 (25 November 2026, Phase 3 formal maintenance: only `7814ab37f` Phase 2 `/no-comments` Slice 5 touched the five covered files — 0 substantive code hunks across ace_sequencer.gd, audio.gd, deck_moves.gd, melody_lease.gd, and music_arbiter.gd; in sync)

Sync commit: ed9db9fcf611e7a1bdf7810614f9867a771bb14c (27 November 2026, Full-Alpha Wave C integration on `swarm/full-alpha-complete`: of the covered files only `sketches/core-loop/src/presentation/audio.gd` changed, adding 6 lines (`note_menu_nav()` + `MenuSounds.WASD` check in `_step_menu_sounds()`) for Workshop WASD menu cues (`W1-114`); zero music arbiter, melody lease, or sequencer steps changed; `#106` live TLC clean; in sync)
