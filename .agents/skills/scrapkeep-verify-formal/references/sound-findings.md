# Findings of the sound arbiter model

Each finding is a break the model found that replayed on the real game. A closed finding names the change that closed it.

## None open

`sound-today` reports no break at the sync commit (`3ea106468`, 1,116 distinct states, checked with TLC 2.19 from tla2tools 1.7.4 on the Mac Studio on 21 November 2026). All four findings discovered on baseline `c1b7bdc26` are closed and covered by regression checks in `sketches/core-loop/tests/sound_arbiter_test.gd`.

## Closed findings

- **SA-1: Champion flat pack hijacked the Warden fight (`WardenOwnsFightMusic`).** On baseline `c1b7bdc26`, spawning a champion loaded flat pack `champion_hype` with `ace.mode = "warden"`. When `warden_engaged` fired, `warden_took_band()` returned early while `_champion_hyped` was true, `_begin_boss` skipped non-boss tracks, and `ace.commit_warden()` was a no-op on flat packs, leaving `ace.follow_guard()` returning `-1` through the entire Warden fight. Replayed in `sketches/core-loop/tests/sound_arbiter_test.gd` on `c1b7bdc26`; closed in `62ee69bc9` via `MusicArbiter` and `warden_took_band` / `warden_engaged` flat-pack preemption.
- **SA-2: Boss arena radio pin lost the boss track on unpin and phase 3 finale (`BossMusicInArena`, `BossFinaleWinsOverAll`).** On baseline `c1b7bdc26`, pinning the radio after entering a boss arena ran `spin()` -> `engine.force_track("level", ...)` with `_radio_boss` empty. Calling `phase_music(3)` returned `{}` without dropping the radio, and `radio_release()` unconditionally restored stage roam (`"level"` / `spillway`) instead of the boss track. Replayed in `sketches/core-loop/tests/sound_arbiter_test.gd` on `c1b7bdc26`; closed in `62ee69bc9` by capturing `_radio_boss` / `_boss_arena_track`, refusing `radio_play` during `radio_finale`, and restoring boss/finale through `MusicArbiter`.
- **SA-3: Ultimate landing and radio unpin clobbered a live champion (`UltimateRestoresChampion`).** On baseline `c1b7bdc26`, `_ace_return` always restored the stage pack even while a champion remained alive, dropping `champion_hype` back to `spillway` after an ultimate landing or radio release. Replayed in `sketches/core-loop/tests/sound_arbiter_test.gd` on `c1b7bdc26`; closed in `62ee69bc9` by routing `_ace_return` through `MusicArbiter` and `_restore_champion_pack`.
- **SA-4: Player death leaked ultimate flight flags (`DeathClearsUltFlight`).** On baseline `c1b7bdc26`, `_flush_flow`'s `"dead"` branch disarmed launches and dropped radio, but left `_ult_armed` and `_ult_took_band` set to `true`. Replayed in `sketches/core-loop/tests/sound_arbiter_test.gd` on `c1b7bdc26`; closed in `62ee69bc9` via `_disarm_ultimate()`.
