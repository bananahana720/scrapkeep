# Structure survey: sound
commit: 23e935514ef33e7eb58d50e21bd2a5f757f41fa9   model: Gemini 4 Neon (high)   files read: 34 (all 23 slice files + 11 doc/caller files)   date: 2026-11-27

## Module map
sketches/core-loop/src/presentation/audio.gd | 5263 | Master runtime audio node: bus setup, SFX/UI polyphony, music transport (`MusicEngine` + `AceSequencer`), radio/jukebox, moments, pilot kit cues, park cues, voice sidecar, mixer overlay | Bus/mix state, polyphonic voice pools, flow/cue/drop/cannon/sable logs, ACE/bake/babble worker handles, radio/moment/champion/special/cadence/rail/site trackers | `presentation.gd`, `game.gd`, `combat.gd`, `juice.gd`, `reward_ceremony.gd`, `activities.gd`, `screens.gd`, `workshop.gd`, `radio_deck.gd`
sketches/core-loop/src/presentation/sfx_bank.gd | 3402 | Procedural SFX/stinger synthesizer, file-backed WAV/event-set loader, caller babble/TTS voice renderer, and master `TRIM_DB`/`DANGER_SOUNDS`/`KEYED_SOUNDS`/`FILE_SOUNDS` tables | Static sample/stream/rendered/file-presence caches (`_samples`, `_streams`, `_rendered`, `_file_present`), `_voice_tts`/`_voice_clips`, `bake_cancel`, dynamic-binding `_shift`/`_theme`, `unknown_callers` | `audio.gd`, `music_engine.gd`, `rows.gd`, `special_audio.gd`, `phase_music.gd`, `workshop.gd`, `activities.gd`, `natural.gd`, `scrap_field.gd`, `projectile.gd`
sketches/core-loop/src/presentation/music_engine.gd | 2989 | Procedural real-time music band sequencer, harmonic/melodic phrase generator, stinger/park-cue mixer, and background pre-baker | Sample clock, track/section/key/tempo grid, 16-layer gain targets, active `Voice` list, scheduled action/bar queues, parameter snapshots, static `_stinger_tasks`/`_park_warm`/`_park_tasks` | `audio.gd`, `ending_sequence.gd` (via `audio.engine`), 43 tests, 4 tools
sketches/core-loop/src/presentation/ace_sequencer.gd | 1235 | Multi-stem Ogg Vorbis streaming sequencer for ACE music packs with beat/bar transitions, stem trims, low-pass sweeps, sidechain pump, and deck one-shots *(covered by `SoundArbiter.tla`)* | Loaded pack manifest/clips/sections/streams, active/fading `Voice` arrays, `Shot` queue, `trim_epoch`, `_pump_depths`, parameter/warden/duck state, static 5-pack LRU `_kept` | `audio.gd`, 33 tests, 3 tools
sketches/core-loop/src/presentation/synth.gd | 931 | Pure procedural instrument and drum PCM generator (`kick`, `snare`, `lead`, `brass`, `reese`, `wob`, `choir`, `render_score`, WAV encoder) | Static mutex-guarded `_notes` PCM cache, static mutable `score_step` and `score_transpose` | `sfx_bank.gd`, `music_engine.gd`, `audio.gd`, 34 tests, 5 tools
sketches/core-loop/src/presentation/ambient_pool.gd | 472 | Simulation pool for ambient wildlife creatures (admission radius, wander/flee/scatter/hide state machine, call/react sound flags) | `members` array, `clock`, `boss_lock`, `reduced`, `hushed`, `_rng`, `_last_react_sound` | `ambient_life.gd`, 2 tests

## Outward dependencies
- `src/presentation` (outside slice): 16 file-level refs — most common `src/presentation/harmony.gd` (5), `src/presentation/tune_moments.gd` (2), `src/presentation/deck_moves.gd` (2), `src/presentation/set_director.gd` (2)
- `src/core`: 14 file-level refs — most common `src/core/ambient_kinds.gd` (3), `src/core/event_kinds.gd` (2); also `SignalWire` (`class_name` in `src/core/signal_wire.gd`)
- `src/combat`: 5 file-level refs *(peer module preload; `CONTRACTS.md` boundary debt)* — `src/combat/redline.gd` (1), `src/combat/roster.gd` (1), `src/combat/rogue.gd` (1), `src/combat/boss_posture.gd` (1), `src/combat/special_cues.gd` (1)
- `src/world`: 2 file-level refs *(peer module preload; `CONTRACTS.md` boundary debt)* — `src/world/activities.gd` (1), `src/world/interactables.gd` (1)
- `src/world/park`: 2 file-level refs *(peer module preload; `CONTRACTS.md` boundary debt)* — `src/world/park/park_graph.gd` (1), `src/world/park/park_map.gd` (1)
- `src/movement`: 2 file-level refs — `src/movement/tuning.gd` (1), `src/movement/augments.gd` (1)
- `src/presentation/world_fx`: 1 file-level ref — `src/presentation/world_fx/world_fx_specs.gd` (1)
- **Reverse (wrong-direction) inward dependencies into this slice from lower layers:** `src/core/content_registry.gd` -> `music_rows.gd`, `phase_music.gd`; `src/world/events/natural.gd` -> `audio.gd`, `sfx_bank.gd`; `src/world/events/fleet.gd` & `rubble_fall.gd` -> `foley_audio.gd`; `src/world/activities.gd` & `stake_devices.gd` -> `sfx_bank.gd`; `src/combat/jolt_layer.gd` -> `jolt_layer_audio.gd`; `src/combat/prop_crew.gd` -> `foley_audio.gd`; `src/combat/projectile.gd` -> `sfx_bank.gd`; `src/build/scrap_field.gd` -> `sfx_bank.gd`; `src/ui/screen_busy.gd` -> `mix_rows.gd`; `src/ui/workshop.gd` -> `sfx_bank.gd`.

## Findings

### SOUND-01 Conflicting duplicate `TRIM_DB`, file paths, WAV loaders, and 3D player factories across `foley_audio.gd`, `jolt_layer_audio.gd`, `sfx_bank.gd`, and `special_audio.gd`
- kind: A
- evidence:
  - `src/presentation/sfx_bank.gd:200-206` (`TRIM_DB`) and `sfx_bank.gd:502-514` (`FILE_SOUNDS`) define the same 13 foley and jolt-layer cues as `src/presentation/foley_audio.gd:3-10` and `src/presentation/jolt_layer_audio.gd:3-7`, with **8 drifted dB values**:
    - `lift_cage_arrive`: `-4.0` (`foley_audio.gd:7`) vs `-3.0` (`sfx_bank.gd:205`)
    - `zipline_whine`: `-6.0` (`foley_audio.gd:7`) vs `-5.0` (`sfx_bank.gd:205`)
    - `zipline_snap`: `-4.0` (`foley_audio.gd:7`) vs `-3.0` (`sfx_bank.gd:205`)
    - `cave_in_rumble`: `-5.0` (`foley_audio.gd:7`) vs `-4.0` (`sfx_bank.gd:205`)
    - `cave_in_debris`: `-4.0` (`foley_audio.gd:8`) vs `-3.0` (`sfx_bank.gd:206`)
    - `prop_crew_collapse`: `-3.0` (`foley_audio.gd:8`) vs `-2.0` (`sfx_bank.gd:206`)
    - `jolt_layer_jam`: `-4.0` (`jolt_layer_audio.gd:5`) vs `-3.0` (`sfx_bank.gd:200`)
    - `jolt_layer_fizzle`: `-4.0` (`jolt_layer_audio.gd:5`) vs `-6.0` (`sfx_bank.gd:200`)
  - `foley_audio.gd:19-82` and `jolt_layer_audio.gd:17-76` are near-line-for-line copies of `stream()`, `_from_riff()`, `player()`, and `one_shot()`, each holding its own `static var _streams := {}` (`foley_audio.gd:12`, `jolt_layer_audio.gd:9`) and neither resets in `tools/test_batch_driver.gd`.
  - Caller counts: `git grep -F "FoleyAudio" -- src/ tests/` => 17 `src/` hits (`prop_crew.gd`, `fleet.gd`, `rubble_fall.gd`, `world_fx_sound.gd`), 9 `tests/` hits; `git grep -F "jolt_layer_audio" -- src/ tests/` => 1 `src/` hit (`combat/jolt_layer.gd:4` aliased as `JoltAudio`, 5 uses), 1 `tests/` hit (`tests/jolt_layer_test.gd`).
- fix: Keep `SfxBank` as the single owner of `FILE_SOUNDS`, `TRIM_DB`, and WAV loading (reconciling the 8 dB values explicitly, preserving current runtime `AudioStreamPlayer3D` gains if keeping behaviour strictly identical or aligning `SfxBank.TRIM_DB` to match the live 3D values). Merge `jolt_layer_audio.gd` into a single shared 3D one-shot/loop helper (or fold into `foley_audio.gd` delegating `stream()` and `trim_db()` to `SfxBank`), keeping `JoltAudio` constants (`TELL_LEAD`) in `jolt_layer.gd`.
- files to change: `sketches/core-loop/src/presentation/foley_audio.gd`, `sketches/core-loop/src/presentation/jolt_layer_audio.gd`, `sketches/core-loop/src/presentation/sfx_bank.gd`, `sketches/core-loop/src/combat/jolt_layer.gd`, `sketches/core-loop/src/presentation/world_fx/world_fx_sound.gd`
- size: ~+35 / -110 lines
- risk: low — pure audio helper consolidation; verify exact dB values so no sound-level test moves
- behaviour-preserving: yes, if `TRIM_DB` reconciliation preserves the currently heard 3D player dB values (or updates only the unused side of each pair)
- tests that cover it: `sketches/core-loop/tests/foley_audio_test.gd`, `sketches/core-loop/tests/jolt_layer_test.gd`, `sketches/core-loop/tests/sound_edges_test.gd`, `sketches/core-loop/tests/world_fx_sound_test.gd`
- guard: add a test assertion in `tests/foley_audio_test.gd` (or `tests/sound_own_recipes_test.gd`) checking that every foley/jolt id reads `SfxBank.trim_db` and no separate `TRIM_DB` table duplicates `SfxBank.TRIM_DB` keys.

### SOUND-02 `src/world/events/natural.gd` hijacks `audio.gd`'s `world_fact` signal connection and calls private `_audio._admit()` / `_audio._start()` directly
- kind: C
- evidence:
  - `src/world/events/natural.gd:15-18` preloads 4 presentation scripts (`audio.gd`, `sfx_bank.gd`, `rows.gd`, `harmony.gd`).
  - `src/world/events/natural.gd:130-138` reaches into `world.ctx.root.get("presentation").audio`, inspects `world.ctx.events.get_signal_connection_list("world_fact")`, disconnects `audio.gd`'s own listener, and interposes `_on_world_sound`.
  - `src/world/events/natural.gd:813-824` intercepts `world.events.PARK_LAND_FACTS` and directly calls private methods `_audio._admit("world_fact", sound, pitch)` (`:821`) and `_audio._start("world_fact", sound, Bank.stream(sound), Bank.trim_db(sound) + Audio.PRIORITY_DB[Rows.priority("world_fact")], pitch, "SFX")` (`:822-823`).
  - Caller check: `git grep -n "_audio\._" -- src/` => 2 hits, both in `natural.gd:821-822`.
- fix: Move the `PARK_LAND_FACTS` keyed-pitch playback rule directly into `audio.gd`'s `world_fact` listener (`audio.gd:2172-2187`, or read a flag/property on `EventKinds.world_row(kind)` so `audio.gd` doesn't need `world.events.PARK_LAND_FACTS`), and delete the signal hijack, `_on_world_sound`, and the 4 sound preloads from `natural.gd`.
- files to change: `sketches/core-loop/src/world/events/natural.gd`, `sketches/core-loop/src/presentation/audio.gd`, `sketches/core-loop/src/core/event_kinds.gd` (optional flag on `WORLD_ROWS` to avoid world->presentation or presentation->world coupling)
- size: ~+10 / -30 lines
- risk: low — purely moves sound playback decision back into `audio.gd`; note `audio.gd` is listed in `SoundArbiter.tla`'s `sound-coverage.md`, though `world_fact` is outside the arbiter/lease/deck state machine (re-verify `model-receipts.mjs --row sound-arbiter-safe` if `audio.gd` is edited)
- behaviour-preserving: yes — same `sound`, `pitch = Harmony.ratio(live_key())`, `db`, and `SFX` bus on the exact same `world_fact` signal emission
- tests that cover it: `sketches/core-loop/tests/park_natural_cue_test.gd`, `sketches/core-loop/tests/park_natural_test.gd`, `sketches/core-loop/tests/own_sounds_test.gd`
- guard: extend `scripts/sketch-lint.mjs` to ban `disconnect(` on `events.` signals owned by another module and ban `src/world/` preloading `src/presentation/audio.gd` or `sfx_bank.gd`.

### SOUND-03 Wrong-direction dependencies: lower layers (`core`, `build`, `combat`, `world`) preload presentation sound modules and instantiate raw `AudioStreamPlayer3D`s
- kind: C
- evidence:
  - `src/core/content_registry.gd:9-10, 330-333` preloads `src/presentation/music_rows.gd` and `src/presentation/phase_music.gd` (plus `tune_moments.gd`), making `core` depend upward on `presentation`.
  - `src/build/scrap_field.gd:4, 381-386` preloads `src/presentation/sfx_bank.gd` and instantiates `AudioStreamPlayer3D.new()` directly (`panel_cache`).
  - `src/combat/projectile.gd:8, 229-231` preloads `src/presentation/sfx_bank.gd` and instantiates `AudioStreamPlayer3D.new()` directly (`RIM_PING`).
  - `src/combat/jolt_layer.gd:4, 80, 193, 297, 303` preloads `src/presentation/jolt_layer_audio.gd` and owns `_presence: AudioStreamPlayer3D`.
  - `src/combat/prop_crew.gd:4, 65, 295` preloads `src/presentation/foley_audio.gd`.
  - `src/world/activities.gd:30, 1189-1194` preloads `src/presentation/sfx_bank.gd` and builds `AudioStreamPlayer3D.new()` directly (`_find_sound`).
  - `src/world/stake_devices.gd:11, 352` preloads `src/presentation/sfx_bank.gd` just to check `SfxBank.has_recipe(...)`.
  - `src/world/events/fleet.gd:4, 151, 254, 305-306, 328` and `src/world/events/rubble_fall.gd:4, 75, 95` preload `src/presentation/foley_audio.gd`.
  - `src/ui/screen_busy.gd:4, 27` preloads `src/presentation/mix_rows.gd` solely for `MixRows.combat_after(_combat, pressure)` (hysteresis thresholds `0.4`/`0.25`).
  - Command: `git grep -n 'preload("res://src/presentation/.*\(audio\|sfx\|music\|mix_rows\|foley\)' -- src/core src/build src/combat src/world src/ui` => 13 hits across 11 files.
- fix: (1) Move pure data/schema constants read by `core`/`ui` (`MusicRows.ROWS`, `PhaseMusic.TRACKS`/`PICKED`, `MixRows.combat_after`) into `src/core/` or keep `content_registry.gd` validation in a test/presentation validator. (2) Route 3D foley/beacon loops (`scrap_field`, `projectile`, `activities`, `jolt_layer`, `prop_crew`, `fleet`, `rubble_fall`) through `GameEvents` (or a single presentation-owned 3D audio hook attached by `presentation.gd`, matching how `audio.gd` already handles `special_spawned` and `_warn_threat`).
- files to change: `sketches/core-loop/src/core/content_registry.gd`, `sketches/core-loop/src/build/scrap_field.gd`, `sketches/core-loop/src/combat/projectile.gd`, `sketches/core-loop/src/combat/jolt_layer.gd`, `sketches/core-loop/src/combat/prop_crew.gd`, `sketches/core-loop/src/world/activities.gd`, `sketches/core-loop/src/world/stake_devices.gd`, `sketches/core-loop/src/world/events/fleet.gd`, `sketches/core-loop/src/world/events/rubble_fall.gd`, `sketches/core-loop/src/ui/screen_busy.gd`, `sketches/core-loop/src/presentation/audio.gd`
- size: ~+120 / -110 lines across 2-3 small PRs (split: core/ui data tables first, then 3D audio emitters)
- risk: medium — touches combat/world/build files; changing signal timing or node child counts can affect tests that inspect `AudioStreamPlayer3D` children directly (e.g., `jolt_layer_test.gd`, `foley_audio_test.gd`)
- behaviour-preserving: yes, if 3D players attach to the same host nodes on the same frame with identical `stream`/`volume_db`/`unit_size`/`max_distance`
- tests that cover it: `sketches/core-loop/tests/content_registry_test.gd`, `sketches/core-loop/tests/foley_audio_test.gd`, `sketches/core-loop/tests/jolt_layer_test.gd`, `sketches/core-loop/tests/sound_edges_test.gd`, `sketches/core-loop/tests/sound_twins_test.gd`
- guard: add a `sketch-lint.mjs` rule (with a shrinking baseline like L6–L11) forbidding `src/core/`, `src/build/`, `src/combat/`, and `src/world/` from preloading `src/presentation/` or calling `AudioStreamPlayer3D.new()`.

### SOUND-04 `audio.gd` reaches into 6 private `director._park_*` members on `event_director.gd` and private `ult._beat` on `ultimate.gd`
- kind: C
- evidence:
  - `src/presentation/audio.gd:2616` reads `director._park_states`
  - `src/presentation/audio.gd:2655` calls `_park_director()._park_fact(state, "announced")`
  - `src/presentation/audio.gd:2696-2698` reads `director._park_quiet_until` and calls `director._park_capacity(state)`, `director._park_route_safe(state)`, `director._park_clear(state, ...)`
  - `src/presentation/audio.gd:4783-4785` reads `ult._beat` three times (`_tend_tally()`)
  - Command: `git grep -n "director\._park_\|_park_director()\._park_\|ult\._beat" -- src/presentation/audio.gd` => 8 hits across 6 private members.
- fix: Add two small public query methods on the owners:
  1. On `src/world/event_director.gd`: `park_state_for(event_id: String) -> Dictionary`, `park_landing_info(state: Dictionary) -> Dictionary` (or expose `landing_s`/`time_s` directly on `event_announced`), and `park_booking_safe(state: Dictionary, ball_pos: Vector3, ball_vel: Vector3) -> bool`.
  2. On `src/combat/ultimate.gd`: public `current_beat() -> int` (or emit a `flight_beat(beat: int)` signal).
- files to change: `sketches/core-loop/src/presentation/audio.gd`, `sketches/core-loop/src/world/event_director.gd`, `sketches/core-loop/src/combat/ultimate.gd`
- size: ~+25 / -15 lines
- risk: low — pure read-only getter methods on owners; note both `event_director.gd` (`ParkFlood.tla`) and `audio.gd` (`SoundArbiter.tla`) are covered by TLA+ specs, though neither change alters any modeled state transition (still run `model-receipts.mjs` for both rows to refresh sync commits)
- behaviour-preserving: yes — exact same boolean/int reads moved behind public methods on the state owners
- tests that cover it: `sketches/core-loop/tests/park_music_cues_test.gd`, `sketches/core-loop/tests/park_cue_late_test.gd`, `sketches/core-loop/tests/park_music_hold_game_test.gd`, `sketches/core-loop/tests/tally_kit_test.gd`
- guard: `scripts/deep-sweep.mjs` D2 already flags new underscore reach-ins on diffs; adding a baseline-enforced D2 check in `sketch-lint.mjs` would prevent regressions.

### SOUND-05 Underscore reach-ins into `audio.gd`, `music_engine.gd`, `ace_sequencer.gd`, and `sfx_bank.gd` from UI, intra-sound code, and tools
- kind: C
- evidence:
  - `src/ui/ending_sequence.gd:112-113` calls `audio._flush_flow()` and then directly mutates `audio.engine.menu_theme("summary", true)` (skipping `audio`'s ACE/radio coordination!).
  - `src/presentation/audio.gd:962` reads `engine._bar_step` and `engine._parameter_phrase_due`.
  - `src/presentation/audio.gd:1112, 1114` reads `engine._cadence_bar` and calls `engine._floor()`.
  - `src/presentation/audio.gd:1123` writes `ace._parameter_danger_floor = engine.parameter_committed_danger_floor` *(note: `ace_sequencer.gd` is covered by `SoundArbiter.tla`)*.
  - `src/presentation/audio.gd:3754` calls `engine._add_action(at, {"type": "drop", ...})` directly instead of a public `MusicEngine` drop method.
  - `src/presentation/audio.gd:5226` calls `SfxBank._said(key_s)`.
  - `tools/ace_bounce.gd:119, 212` reads `audio._music_pb`; `tools/perf_bench.gd:342-345, 903-904` calls `audio._finish_opening()`, mutates `audio._rest_task`, and disconnects `audio._on_node_added`; `tools/audio_board.gd:169` calls `SfxBank._motif_score(...)`.
  - Command: `git grep -n "audio\._\|engine\._\|ace\._\|SfxBank\._" -- src/ tools/` => 18 hits (excluding `self`).
- fix: Expose small public methods on the owning classes:
  - `Audio.play_ending_summary()` (replaces `ending_sequence.gd:112-113`), `Audio.music_skips() -> int` (for `ace_bounce.gd`), `Audio.finish_band_bakes()` and `Audio.set_threat_watch(enabled: bool)` (for `perf_bench.gd`).
  - `MusicEngine.parameter_timing() -> Dictionary`, `MusicEngine.fight_floor() -> float`, `MusicEngine.drop_at_sample(at, bars, weight, change)` (replaces `_bar_step`, `_parameter_phrase_due`, `_cadence_bar`, `_floor`, `_add_action`).
  - `AceSequencer.prime_parameters(enabled, values, released, danger_floor, lift)` (replaces `audio.gd:1119-1125` writing 5 fields + `_parameter_danger_floor`).
  - `SfxBank.parse_said(id)` (public rename of `_said`) and `SfxBank.motif_score(...)` (for `audio_board.gd`).
  - **Formal model note:** `_flush_flow` in `audio.gd` and `ace_sequencer.gd` are covered by `SoundArbiter.tla` (`sound-coverage.md`). Keep `_flush_flow`'s internal transitions unchanged (have `play_ending_summary()` delegate to it) and re-run `node scripts/gate/model-receipts.mjs --row sound-arbiter-safe`.
- files to change: `sketches/core-loop/src/presentation/audio.gd`, `sketches/core-loop/src/presentation/music_engine.gd`, `sketches/core-loop/src/presentation/ace_sequencer.gd`, `sketches/core-loop/src/presentation/sfx_bank.gd`, `sketches/core-loop/src/ui/ending_sequence.gd`, `sketches/core-loop/tools/ace_bounce.gd`, `sketches/core-loop/tools/perf_bench.gd`, `sketches/core-loop/tools/audio_board.gd`
- size: ~+45 / -30 lines
- risk: low-medium — low for read getters; medium for `ending_sequence.gd` and `ace_sequencer.gd` because of `SoundArbiter.tla` coverage
- behaviour-preserving: yes — every replacement delegates to the exact existing behaviour
- tests that cover it: `sketches/core-loop/tests/ending_sequence_test.gd`, `sketches/core-loop/tests/sound_arbiter_test.gd`, `sketches/core-loop/tests/music_params_test.gd`, `sketches/core-loop/tests/cannon_ultimate_test.gd`, `sketches/core-loop/tests/cadence_audio_test.gd`
- guard: `scripts/deep-sweep.mjs` D2; add a baseline check for `audio._`/`engine._`/`ace._` in `src/` and `tools/`.

### SOUND-06 Six competing ways callers play a sound (and 5 ways to locate `audio`), plus 3 ways to change music
- kind: G
- evidence:
  - **Sound playback paths across `src/`:**
    1. *Event bus (`ctx.events.*`)* — the `CONTRACTS.md` norm (`audio.gd:2021-2286`).
    2. *Direct `audio.play()` / `audio.play_at()`* — 15 files (`waking.gd`, `combat.gd`, `game.gd`, `juice.gd`, `panel_fx.gd`, `presentation.gd`, `radio_deck.gd`, `reward_ceremony.gd`, `ability_bar.gd`, `callouts.gd`, `hud.gd`, `pause_menu.gd`, `settings_pages.gd`, `workshop.gd`, `activities.gd`, `destructibles.gd`, `stake_devices.gd`), bypassing `GameEvents` with ad-hoc `db`/`pitch`/`bus`/`sound_override` arguments.
    3. *15 bespoke public cue methods on `audio.gd`* — `kest_cue`, `kest_roll`, `cannon_family`, `cannon_line`, `cannon_motif`, `sable_note`, `story_sting`, `chirp`, `speak`, `call_in`, `call_end`, `activity_cue`, `set_complete`, `note_menu_nav`, `slowed`.
    4. *Signal hijack + private `_admit`/`_start`* — `src/world/events/natural.gd:133-138, 821-823` (SOUND-02).
    5. *4 parallel standalone `AudioStreamPlayer3D` factories bypassing `audio.gd`'s voice budget and `cue_log`* — `FoleyAudio` (`foley_audio.gd`), `JoltLayerAudio` (`jolt_layer_audio.gd`), `WorldFxSound` (`world_fx_sound.gd`, which calls `audio.note_cue` via global `static var audio`), and raw inline `AudioStreamPlayer3D.new()` in `scrap_field.gd:381`, `projectile.gd:229`, `activities.gd:1190`, `ambient_life.gd:52`.
    6. *2 standalone experimental `AudioStreamPlayer` banks* — `ExperimentalAudioBank` (`live_run_bridge.gd`) and `CraftAudioCues` (test-only).
  - **Audio node lookup spellings** (`git grep -n '\.audio\b\|get("audio")\|\.audio()' -- src/` => 41 hits): `game.audio()`, `presentation.audio`, `presentation.get("audio")`, `ctx.root.presentation.audio`, `get_parent().get("audio")`, `host.get("audio")`, `_chain(ctx, ["presentation", "audio"], null)`, and `WorldSound.audio` static var.
  - **Music state changes:** (1) bus signals (`_flow_queue` + `_begin_boss` + `_on_boss_phase_with`), (2) direct public methods on `audio.gd` (`radio_play`/`radio_release`, `spin`/`stop_spin`, `title_theme`, `camp_theme`, `activity_cue`, `set_breath`), (3) direct reach-in `audio._flush_flow()` + `audio.engine.menu_theme(...)` (`ending_sequence.gd:112-113`).
- fix: Establish one rule and one entry point:
  - **Gameplay modules (`combat`, `world`, `build`, `boss`)** publish `GameEvents` facts (or for UI/presentation callers that legitimately trigger immediate non-sim sounds, call one `ctx.audio` reference via `audio.play(...)` / `audio.play_at(...)` / `audio.play_3d(...)`). Expose `ctx.audio` (set by `presentation.gd` alongside `ctx.terrain`/`ctx.spawner`/`ctx.build`/`ctx.boss`) so all 8 lookup spellings collapse to one.
  - **Music changes** go exclusively through `audio.gd`'s public music API (and bus signals); never mutate `audio.engine` directly from outside `audio.gd`.
- files to change: `sketches/core-loop/src/core/context.gd`, `sketches/core-loop/src/presentation/presentation.gd`, `sketches/core-loop/src/presentation/audio.gd`, plus incremental migration of the ~18 caller files listed above
- size: ~+60 / -90 lines for `ctx.audio` + `play_3d` facade; larger if migrating all bespoke pilot methods to signals
- risk: medium — high fan-out across callers; do in small per-subsystem PRs (`ctx.audio` first, then 3D factories, then pilot/UI callers). Note `SoundArbiter.tla` covers music-change paths in `audio.gd` — do not alter arbiter transitions while consolidating caller entry points.
- behaviour-preserving: yes — lookup unification and facade routing preserve exact streams, timings, and cue logs
- tests that cover it: `sketches/core-loop/tests/sound_arbiter_test.gd`, `sketches/core-loop/tests/sound_twins_test.gd`, `sketches/core-loop/tests/presentation_sfx_test.gd`, `sketches/core-loop/tests/world_fx_sound_test.gd`
- guard: `CONTRACTS.md` entry for `ctx.audio` + `sketch-lint.mjs` rule flagging direct `AudioStreamPlayer3D.new()` outside `src/presentation/` and direct `audio.engine.` access outside `src/presentation/audio.gd`.

### SOUND-07 Four duplicate 16-bit RIFF WAV parsers across `foley_audio.gd`, `jolt_layer_audio.gd`, and `sfx_bank.gd` (x2)
- kind: A
- evidence:
  - `src/presentation/foley_audio.gd:41-55` (`_from_riff`) parses RIFF chunks into `AudioStreamWAV`.
  - `src/presentation/jolt_layer_audio.gd:35-49` (`_from_riff`) is a verbatim duplicate of `foley_audio.gd:41-55`.
  - `src/presentation/sfx_bank.gd:547-554` (`file_samples`) inline-parses RIFF chunks (skipping `fmt ` and assuming mono 16-bit!).
  - `src/presentation/sfx_bank.gd:2882-2922` (`_read_wav_info` + `load_voice_wav`) writes a fourth full RIFF chunk loop with header validation.
  - Meanwhile `src/presentation/craft/craft_audio_cues.gd:83` uses Godot 4's built-in `AudioStreamWAV.load_from_file(path)`.
  - Command: `git grep -n "_from_riff\|decode_u32" -- src/presentation/` => hits in `foley_audio.gd:41-50`, `jolt_layer_audio.gd:35-44`, `sfx_bank.gd:550, 2899, 2904`.
- fix: Extract one shared `WavLoader` (or static helper in `src/presentation/wav_io.gd`) with `load_wav(path, raw := false) -> AudioStreamWAV` and `read_pcm16(path, require_mono_rate := 0) -> PackedFloat32Array`, used by `SfxBank`, `FoleyAudio`, `JoltLayerAudio`, and `WorldFxSound`. (Check whether Godot 4's `AudioStreamWAV.load_from_file` works cleanly in headless mode without import cache; if it does, it replaces the hand-rolled RIFF parser completely.)
- files to change: `sketches/core-loop/src/presentation/wav_io.gd` (new), `sketches/core-loop/src/presentation/foley_audio.gd`, `sketches/core-loop/src/presentation/jolt_layer_audio.gd`, `sketches/core-loop/src/presentation/sfx_bank.gd`
- size: ~+55 / -95 lines
- risk: low — pure byte-to-`AudioStreamWAV`/PCM decoding with identical output
- behaviour-preserving: yes — identical decoded PCM bytes and `AudioStreamWAV` fields (`format`, `stereo`, `mix_rate`, `data`)
- tests that cover it: `sketches/core-loop/tests/foley_audio_test.gd`, `sketches/core-loop/tests/jolt_layer_test.gd`, `sketches/core-loop/tests/cadence_audio_test.gd`, `sketches/core-loop/tests/audio_event_bank_test.gd`, `sketches/core-loop/tests/world_fx_sound_test.gd`
- guard: unit test on `wav_io.gd` + grep check that no other presentation file manually parses `"RIFF"` / `"fmt "` / `"data"`.

### SOUND-08 `audio.gd` (5,263 lines) has 6 verified private-state seams outside `SoundArbiter.tla` ready to extract
- kind: H
- evidence:
  Static variable-access graph over `src/presentation/audio.gd` (380 functions, 120+ member vars) proves these 6 subsystems share private state that **zero other functions** in `audio.gd` read (except one-line reset/clear hooks):
  1. **Voice TTS sidecar loader** (`audio.gd:4932-4944, 5116-5263`, **149 lines**, 11 funcs, 4 vars: `voice_mode`, `voice_dir`, `_voice_clips`, `_voice_manifest_loaded`) — **0 leaks** into the rest of `audio.gd`.
  2. **Cannon pilot audio** (`audio.gd:4559-4657`, **98 lines**, 9 funcs, 4 vars: `cannon_log`, `_cannon_queue`, `_cannon_threat_at`, `_cannon_streams`) — **0 leaks** (note `static var _cannon_streams` is also un-reset in `reset_for_tests()`).
  3. **Tally pilot audio** (`audio.gd:4718-4807`, **90 lines**, 5 funcs, 3 vars: `_tally_notes`, `_tally_beat`, `_tally_streams`) — **0 leaks**; plus Sable/Tarn/Rivet/Kest kit handlers (`audio.gd:3720-3741, 4524-4717`, **112 lines**).
  4. **Specials presence tracker** (`audio.gd:43, 61, 2950-3026`, **78 lines**, 6 funcs, 2 vars: `_specials`, `specials_heard`) — **0 leaks**; `special_audio.gd` already exists and is only 45 lines!
  5. **Babble async worker queue** (`audio.gd:166-170, 1800-1865`, **66 lines**, 6 funcs, 4 vars: `_babble`, `_babble_job`, `_babble_queue`, `_babble_asked`) — **0 leaks**.
  6. **Cadence / Buff-rail / Site-flip observers** (`audio.gd:4936-4940, 4947-5114`, **174 lines**, 12 funcs, 5 vars: `_cadence_prev`, `_rail_ids`, `_rail_wired_buffs`, `_visited_sites_seen`, `_cable_flips`) — only `.clear()` / `_sync_rail_ids()` in reset handlers.
  7. *(After SOUND-04)* **Park-cue transport & deadline coordinator** (`audio.gd:263-265, 2519-2730`, **244 lines**, 17 funcs, 4 vars: `_park_cues`, `_park_transport_snapshot`, `park_cue_late`, `_unwarned`) — only cleared in `_on_stage_entered`.
  - **Formal model boundary (`SoundArbiter.tla`):** None of seams 1–7 modify `MusicArbiter`, `MelodyLease`, `DeckMoves`, `AceSequencer`, or any modeled transition in `sound-coverage.md` (`_arbiter_state`, `radio_play`, `radio_release`, `_ace_return`, `_begin_boss`, `phase_music`, `_champion_joined`, `_champion_gone`, `warden_took_band`, `_tend_champions`, `_flush_flow`, `_tend_set`, `_tend_deck`, `_follow_warden_form`, `_ace_end_at`). **Do not** split the radio/champion/warden/set-director/flow-flush core without updating `SoundArbiter.tla` and `sound-coverage.md` in the same PR.
- fix: Extract seams 1–6 (starting with voice sidecar, specials presence into `special_audio.gd`, babble worker, and pilot kit audio) as small `RefCounted` helpers owned by `audio.gd` (`audio.gd` keeps thin public delegations where external callers/tests expect methods like `set_voice_mode`, `cannon_family`, `special_spawned`, `speak`, or updates callers in the same PR). That removes ~760–1,000 lines from `audio.gd` cleanly without touching the formally verified arbiter core.
- files to change: `sketches/core-loop/src/presentation/audio.gd`, `sketches/core-loop/src/presentation/special_audio.gd`, plus new focused modules under `sketches/core-loop/src/presentation/` (e.g., `voice_sidecar.gd`, `pilot_audio.gd`, `babble_queue.gd`, `cadence_audio.gd`, `park_cue_sync.gd`)
- size: ~+100 / -0 net (moving ~800–1,000 lines out of `audio.gd`, ~1 PR per seam)
- risk: low per seam — each seam has zero private-state coupling with the music arbiter; because `audio.gd` is listed in `sound-coverage.md`, run `model-receipts.mjs --row sound-arbiter-safe` and confirm zero arbiter diff
- behaviour-preserving: yes — same call order in `_process`, same signals, same `cue_log` entries
- tests that cover it: `sketches/core-loop/tests/cadence_audio_test.gd`, `sketches/core-loop/tests/special_audio_test.gd`, `sketches/core-loop/tests/audio_bakes_ahead_test.gd`, `sketches/core-loop/tests/cannon_kit_test.gd`, `sketches/core-loop/tests/tally_kit_test.gd`, `sketches/core-loop/tests/park_music_cues_test.gd`, `sketches/core-loop/tests/sound_arbiter_test.gd`
- guard: `scripts/deep-sweep.mjs` D5 (`GIANT_LINES = 1500`); adding a max-line cap or seam checklist in `audio.gd` review stops new feature observers from landing inline.

### SOUND-09 `sfx_bank.gd` (3,402 lines) bundles four separable subsystems along clean seams
- kind: H
- evidence:
  - `src/presentation/sfx_bank.gd` currently owns four distinct jobs in one 3,402-line static class:
    1. **Voice / Babble / Caller synthesis & TTS sidecar** (`sfx_bank.gd:246-285, 2690-3064`, **~415 lines**, 24 funcs + `CALLERS`/`MOUTH_*` tables + `_voice_tts`/`_voice_clips`/`unknown_callers` static state) — completely self-contained except calling `Synth` and `Harmony`.
    2. **File-backed WAV & event-set loader** (`sfx_bank.gd:11-28, 338-424, 489-567`, **~185 lines**) — loads `EVENT_DIR`, `FILE_SOUNDS`, `STINGER_PREFIX`, and `RENDERED_DIR`.
    3. **Cue metadata & classification tables** (`sfx_bank.gd:30-245`, **~215 lines**) — `STINGER_BEATS`, `DANGER_SOUNDS`, `KEYED_SOUNDS`, `KEST_SOUNDS`, `TRIM_DB`, `BREAK_PHRASES`.
    4. **Procedural SFX recipe library** (`sfx_bank.gd:691-2689, 3066-3402`, **~2,330 lines**).
- fix: Extract the voice/babble/TTS subsystem (`src/presentation/voice_synth.gd`, ~415 lines) and move the WAV file loader into `wav_io.gd` (SOUND-07), keeping `SfxBank` as the thin facade (`SfxBank.babble(...)`, `SfxBank.say_id(...)`, `SfxBank.set_voice_sidecar(...)` forward or callers import `VoiceSynth` directly).
- files to change: `sketches/core-loop/src/presentation/sfx_bank.gd`, `sketches/core-loop/src/presentation/voice_synth.gd` (new), `sketches/core-loop/src/presentation/audio.gd`
- size: ~+30 / -0 net (moves ~415 lines out of `sfx_bank.gd`)
- risk: low — pure static functions with clean test coverage
- behaviour-preserving: yes — identical PCM synthesis, caching, and TTS clip lookup
- tests that cover it: `sketches/core-loop/tests/audio_call_in_test.gd`, `sketches/core-loop/tests/cadence_audio_test.gd`, `sketches/core-loop/tests/presentation_motifs_test.gd`, `sketches/core-loop/tests/audio_event_bank_test.gd`, `sketches/core-loop/tests/sound_own_recipes_test.gd`
- guard: `scripts/deep-sweep.mjs` D5 (`GIANT_LINES = 1500`).

### SOUND-10 Shared mutable static globals (`Synth.score_step`, `Synth.score_transpose`, `SfxBank._shift`, `SfxBank._theme`, `SfxBank.bake_cancel`, `WorldFxSound.audio`) leak across modules and batched tests
- kind: F
- evidence:
  - `src/presentation/synth.gd:11-12`: `static var score_step := Harmony.STEP` and `static var score_transpose := 0` are mutated as hidden dynamic-binding parameters by `src/presentation/sfx_bank.gd:620-626` (`samples_at`) and saved/restored manually in `sfx_bank.gd:1972-1992` (`tally_recipe`) while read by `synth.gd:912, 924` (`render_score`) and 11 recipe functions in `sfx_bank.gd` (`:1070, 1142, 1365, 1452, 1656, 1738, 1838, 2020, 2041, 2051, 2062, 2094, 3000`).
  - `tools/test_batch_driver.gd:261` resets `Synth.score_transpose = 0` **but never resets `Synth.score_step`**! Nor does it reset `SfxBank._shift`, `SfxBank._theme`, `SfxBank.unknown_callers`, `FoleyAudio._streams`, `JoltLayerAudio._streams`, `PhaseMusic._on_disk`, `Audio._cannon_streams`, or `MusicEngine._stinger_tasks`/`_park_warm`.
  - `src/presentation/sfx_bank.gd:295`: `static var bake_cancel := false` is written by `audio.gd:297, 309, 583, 592` and polled in 20+ loops inside `music_engine.gd:299-506` and `sfx_bank.gd:682, 686`.
  - `src/presentation/world_fx/world_fx_sound.gd:10`: `static var audio = null` is a global service locator written by `world_fx.gd:127` and read by `world_fx_sound.gd:87`.
- fix: (1) Immediate low-risk step: add `Synth.score_step = Harmony.STEP`, `SfxBank.reset_for_tests()` (clearing `unknown_callers`, `_shift`, `_theme`, `_voice_tts`, `_voice_clips`, `bake_cancel`), and `MusicEngine.settle_stingers()` to `tools/test_batch_driver.gd` / `Audio.reset_for_tests()`. (2) Structural fix: pass a small `BakeCtx` (or explicit `step`, `shift`, `theme` params) into `Synth.render_score` and `SfxBank._bake` instead of mutating 4 static globals; pass `audio` explicitly into `WorldFxSound.heard(...)` instead of storing `static var audio`.
- files to change: `sketches/core-loop/src/presentation/synth.gd`, `sketches/core-loop/src/presentation/sfx_bank.gd`, `sketches/core-loop/src/presentation/audio.gd`, `sketches/core-loop/src/presentation/world_fx/world_fx_sound.gd`, `sketches/core-loop/src/presentation/world_fx/world_fx.gd`, `sketches/core-loop/tools/test_batch_driver.gd`
- size: ~+20 / -5 lines for test reset hygiene; ~+45 / -40 lines for eliminating `score_step`/`score_transpose`/`_shift`/`_theme` globals
- risk: medium for refactoring `Synth.score_step`/`_shift` (touches 15+ recipe helpers and worker-thread locking in `SfxBank`); low for `test_batch_driver.gd` reset hygiene
- behaviour-preserving: yes — identical synthesized PCM and thread safety (actually removes a subtle latent data race if any caller invokes `Synth.render_score` outside `SfxBank._lock`)
- tests that cover it: `sketches/core-loop/tests/test_batch_reset_test.gd`, `sketches/core-loop/tests/tally_kit_test.gd`, `sketches/core-loop/tests/world_fx_sound_test.gd`, `sketches/core-loop/tests/audio_bakes_ahead_test.gd`
- guard: `scripts/sketch-lint.mjs` rule L14 already checks un-reset `static var`s; verify why `Synth.score_step`, `SfxBank._shift`/`_theme`/`unknown_callers`, and `Audio._cannon_streams` escaped L14 and tighten the rule.

### SOUND-11 `CraftAudioCues` (`craft_audio_cues.gd`, 149L) is test-only and overlaps `ExperimentalAudioBank`, which also bundles test-only PBR texture specs
- kind: B
- evidence:
  - `git grep -n "CraftAudioCues\|craft_audio_cues" -- src/ tools/ tests/` => **0 hits in `src/`** (outside its own declaration), **0 hits in `tools/`**, 2 hits in `tests/` (`tests/craft_pipeline_integration_test.gd:11`, `tests/vista_atmosphere_test.gd:9, 199`). `CraftAudioCues.cue_exists` (`:65`) has **0 callers anywhere** (including tests).
  - `src/presentation/craft/craft_audio_cues.gd:5-48` points at `res://assets/audio/experimental/` with `smelter_ambience` and 3 callouts, overlapping `src/presentation/experimental_audio_bank.gd:9-88` which also points at `res://assets/audio/experimental/` with `smelter_ambience` (`.ogg` vs `.mp3`) and 4 PA callouts (`pa_salvage_press_lockdown`, etc.).
  - `src/presentation/experimental_audio_bank.gd:90-109, 218-260` puts 3 PBR texture mask loaders (`PBR_MASK_SPECS`, `pbr_mask_ids`, `pbr_mask_spec`, `load_pbr_mask`, `pitted_iron_mask`, `slag_crust_mask`, `corrosive_brine_mask`) inside an audio bank; `git grep -n "pbr_mask\|pitted_iron_mask\|slag_crust_mask\|corrosive_brine_mask" -- src/ tools/ tests/` confirms **0 `src/`/`tools/` callers** (test-only in `tests/experimental_audio_bank_test.gd` / `tests/experimental_worlds23_and_bridge_test.gd`).
- fix: Delete `craft_audio_cues.gd` (requires owner go-ahead per `AGENTS.md`) and move its manifest audit check (if still wanted) onto `ExperimentalAudioBank` or retire the unused `.mp3`/`.wav` duplicates; split or remove the test-only `PBR_MASK_SPECS` texture methods from `experimental_audio_bank.gd` so an audio bank only owns audio.
- files to change: `sketches/core-loop/src/presentation/craft/craft_audio_cues.gd`, `sketches/core-loop/src/presentation/experimental_audio_bank.gd`, `sketches/core-loop/tests/craft_pipeline_integration_test.gd`, `sketches/core-loop/tests/vista_atmosphere_test.gd`, `sketches/core-loop/tests/experimental_audio_bank_test.gd`
- size: ~+10 / -220 lines
- risk: low — zero production gameplay callers for `CraftAudioCues` or `ExperimentalAudioBank`'s PBR masks (`ExperimentalAudioBank` audio is only used by opt-in `src/experimental/live_run_bridge.gd`)
- behaviour-preserving: yes for the shipping game (no production caller exists); test suite needs matching cleanup
- tests that cover it: `sketches/core-loop/tests/craft_pipeline_integration_test.gd`, `sketches/core-loop/tests/vista_atmosphere_test.gd`, `sketches/core-loop/tests/experimental_audio_bank_test.gd`, `sketches/core-loop/tests/experimental_worlds23_and_bridge_test.gd`
- guard: a periodic dead-`src/`-file check in `scripts/check-project.mjs` flagging `src/` scripts with 0 callers outside `tests/`.

### SOUND-12 Bus names (`"SFX"`, `"UI"`, `"Music"`, `"Ambient"`, `"Master"`) and bus-resolution fallbacks are scattered across 23+ `src/` files
- kind: E
- evidence:
  - Raw bus string literals across `src/` (`git grep -c` / script count): `"SFX"` 118 hits in 23 files, `"UI"` 26 hits in 11 files, `"Music"` 21 hits in 5 files, `"Ambient"` 16 hits in 5 files, `"Master"` 9 hits in 7 files.
  - Bus name constants are re-declared independently in 4 files: `mix_rows.gd:3` (`BUS_DB`), `music_dsp.gd:3-5` (`MUSIC_BUS`, `STINGER_BUS`, `SFX_BUS`), `experimental_audio_bank.gd:4-7` (`BUS_AMBIENT`, `BUS_SFX`, `BUS_FALLBACK`), `world_fx_sound.gd:7` (`BUS := "Ambient"`).
  - Six separate `AudioServer.get_bus_index(...) >= 0` fallback checks: `foley_audio.gd:65`, `jolt_layer_audio.gd:59`, `ambient_life.gd:54`, `craft_audio_cues.gd:94-97`, `experimental_audio_bank.gd:165-168`, `music_dsp.gd:63`.
- fix: Define canonical bus constants (`BUS_MASTER`, `BUS_MUSIC`, `BUS_SFX`, `BUS_UI`, `BUS_AMBIENT`, `BUS_STINGER`) and one `static func resolve_bus(preferred: String, fallback := BUS_MASTER) -> String` in `src/presentation/mix_rows.gd` (the existing single owner of `BUS_DB`), and replace all 6 inline fallbacks and duplicate bus constants across the slice with `MixRows`.
- files to change: `sketches/core-loop/src/presentation/mix_rows.gd`, `sketches/core-loop/src/presentation/music_dsp.gd`, `sketches/core-loop/src/presentation/foley_audio.gd`, `sketches/core-loop/src/presentation/jolt_layer_audio.gd`, `sketches/core-loop/src/presentation/ambient_life.gd`, `sketches/core-loop/src/presentation/world_fx/world_fx_sound.gd`, `sketches/core-loop/src/presentation/special_audio.gd`, `sketches/core-loop/src/presentation/sfx_budget.gd`, `sketches/core-loop/src/presentation/experimental_audio_bank.gd`, `sketches/core-loop/src/presentation/audio.gd`
- size: ~+25 / -35 lines
- risk: low — pure constant and helper consolidation
- behaviour-preserving: yes — identical bus strings and fallback order (note `ambient_life.gd:54` falls back `"Ambient" -> "SFX" -> "Master"`, preserve that two-step fallback via a `fallback` arg)
- tests that cover it: `sketches/core-loop/tests/mix_rows_test.gd`, `sketches/core-loop/tests/music_dsp_test.gd`, `sketches/core-loop/tests/world_fx_sound_test.gd`, `sketches/core-loop/tests/foley_audio_test.gd`
- guard: `scripts/sketch-lint.mjs` rule disallowing `AudioServer.get_bus_index(` outside `mix_rows.gd`, `audio.gd`, and `music_dsp.gd`.

### SOUND-13 `"res://assets/music_ace/%s/manifest.json"` path template and pack lists are repeated across `music_rows.gd`, `phase_music.gd`, and `content_registry.gd`
- kind: E
- evidence:
  - `src/presentation/music_rows.gd:94-162` spells `"res://assets/music_ace/<dir>/manifest.json"` 69 times literally inside `ROWS`, plus `"res://assets/music_ace/%s/manifest.json"` at `:184` and `:210`, and `"res://assets/music_ace/"` at `:222`.
  - `src/presentation/phase_music.gd:33-34` duplicates `manifest_of(id)` with `"res://assets/music_ace/%s/manifest.json" % theme_of(id)`, and `phase_music.gd:23-26` duplicates a 20-entry `TRACKS` list that mirrors the keys already in `MusicRows.ROWS` (`music_rows.gd:103-126`).
  - `src/core/content_registry.gd:333` hardcodes `"res://assets/music_ace/"` and `"/manifest.json"` a third time (and lists hardcoded menu/zone IDs at `:331` duplicating `MusicRows.ROWS`).
- fix: Put `const ACE_ROOT := "res://assets/music_ace/"` and `static func manifest_path(dir_or_id: String) -> String` in `music_rows.gd`. Have `phase_music.gd` call `MusicRows.manifest_path(theme_of(id))` and derive `TRACKS` (or validate against `MusicRows.ROWS`), and have `content_registry.gd` read `MusicRows.ACE_ROOT`.
- files to change: `sketches/core-loop/src/presentation/music_rows.gd`, `sketches/core-loop/src/presentation/phase_music.gd`, `sketches/core-loop/src/core/content_registry.gd`
- size: ~+15 / -20 lines (or -69 repeated path prefixes if `ROWS` stores `dir` instead of full path, though check `content_registry_test.gd` / `audio_music_rows_test.gd` for `ace_manifest` schema assertions first)
- risk: low — pure path helper consolidation
- behaviour-preserving: yes — identical resolved strings
- tests that cover it: `sketches/core-loop/tests/audio_music_rows_test.gd`, `sketches/core-loop/tests/ace_tracks_test.gd`, `sketches/core-loop/tests/content_registry_test.gd`, `sketches/core-loop/tests/phase_music_test.gd`
- guard: `tests/content_registry_test.gd` already validates every `MusicRows.ROWS` manifest path; add an assertion that every `PhaseMusic.TRACKS` entry exists in `MusicRows.ROWS`.

### SOUND-14 Peer-module preloads from presentation sound files into `src/combat/`, `src/world/`, and `src/movement/`
- kind: C
- evidence:
  - `src/presentation/audio.gd` preloads 9 peer-module scripts outside `src/core/` and `src/presentation/`: `src/world/activities.gd` (`:4`, for `Activities.RULES` and `Activities.shared_graph`), `src/world/park/park_graph.gd` (`:13` — **unused dead preload**: `git grep -n "ParkGraph" -- src/presentation/audio.gd` => 1 hit, own def only), `src/movement/tuning.gd` (`:16`), `src/combat/redline.gd` (`:20`, only `Redline.KETTLE_S`), `src/movement/augments.gd` (`:21`, only `Augments.VAULT_CAP` and `Augments.LINE_SMASH`), `src/combat/roster.gd` (`:23`), `src/combat/rogue.gd` (`:24`), `src/combat/boss_posture.gd` (`:25`, only `BossPosture.CHUNKS`), `src/world/interactables.gd` (`:26`).
  - `src/presentation/special_audio.gd:4` preloads `src/combat/special_cues.gd` solely for a 1-line forwarding call `SpecialCues.rammed(enemy)` (`:32-33`).
  - `src/presentation/ambient_homes.gd:4` preloads `src/world/park/park_map.gd` (`ParkMap.mesa_edge`, `footprint_half_extents`, `footprint_contains`).
  - `CONTRACTS.md:32` explicitly flags cross-module preloads as boundary debt.
- fix: Delete the unused `ParkGraph` preload at `audio.gd:13`, and pass small shared schema constants (`KETTLE_S`, `CHUNKS`, `VAULT_CAP`, `Interactables.sound`, `Activities.shared_graph`) either through `src/core/` schema modules or through `ctx` methods (`ctx.terrain`, `ctx.spawner`). Note: `audio.gd` is in `sound-coverage.md`, so run `model-receipts.mjs --row sound-arbiter-safe` after touching `audio.gd`.
- files to change: `sketches/core-loop/src/presentation/audio.gd`, `sketches/core-loop/src/presentation/special_audio.gd`, `sketches/core-loop/src/presentation/ambient_homes.gd`
- size: ~+15 / -25 lines (just removing unused/trivial preloads)
- risk: low — pure dependency hygiene
- behaviour-preserving: yes
- tests that cover it: `sketches/core-loop/tests/special_audio_test.gd`, `sketches/core-loop/tests/ambient_homes_test.gd`, `sketches/core-loop/tests/sound_arbiter_test.gd`, `sketches/core-loop/tests/overtime_heat_danger_sounds_test.gd`
- guard: `scripts/sketch-lint.mjs` cross-module preload baseline check.

### SOUND-15 Dead functions and dead constants with zero callers anywhere, plus 11 test-only helpers left on production classes
- kind: B
- evidence:
  - **Dead (0 callers anywhere in `src/`, `tools/`, `tests/`, `scripts/`):**
    - `src/presentation/sfx_bank.gd:633` `baked_at(id, step, shift, theme)` — `git grep -n "baked_at" -- src/ tools/ tests/` => 1 hit (own def).
    - `src/presentation/sfx_bank.gd:12` `const FILE_RATE := 48000` — `git grep -n "FILE_RATE" -- src/ tools/ tests/` => 1 hit (own def).
    - `src/presentation/audio.gd:4718` `const TALLY_SOUNDS := ...` — `git grep -n "TALLY_SOUNDS" -- src/ tools/ tests/` => 1 hit (own def).
    - `src/presentation/audio.gd:4819` `const SET_ANSWER_YIELDS := ["open", "drop", "break"]` — `git grep -n "SET_ANSWER_YIELDS" -- src/ tools/ tests/` => 1 hit (own def; duplicated by `MelodyLease.YIELD_SECTIONS`!).
    - `src/presentation/special_audio.gd:9` `const PRESENCE_DB := -14.0` — `git grep -n "PRESENCE_DB" -- src/ tools/ tests/` => 1 hit (own def; `presence_player` reads `SfxBank.trim_db` instead!).
    - `src/presentation/craft/craft_audio_cues.gd:65` `cue_exists(cue_id)` — `git grep -n "cue_exists" -- src/ tools/ tests/` => 1 hit (own def).
  - **Test-only (0 hits in `src/`/`tools/`/`scripts/`, used only by `tests/`):** `music_engine.gd:79` `BRINDLE_KEY` (2 test hits; superseded by `BOSS_SECTIONS`), `music_engine.gd:462` `prepare_all` (2), `:519` `melodic_layers` (2), `:745` `set_theme` (1), `:815` `end_warden_lap` (2), `:832` `segments_cut` (9), `:839` `pin_rotation` (8), `:1209` `pending_actions` (4); `audio.gd:330` `reset_cue_log` (1), `:1816` `babble_state` (8), `:1825` `band_bakes` (9), `:3662` `pressure_now` (3), `:3666` `ace_pressure` (3), `:5145` `voice_manifest_loaded` (7), `:5149` `voice_clip_for` (15); `ace_sequencer.gd:361` `pump_active` (9 — **keep: covered by `SoundArbiter.tla`**); `sfx_bank.gd:311` `plays_own` (14); `sfx_budget.gd:78` `live_ids` (12).
- fix: Delete the 6 dead (0-caller) functions/constants immediately. Leave the test-only inspection seams alone (per `BRIEF.md`: "Leave out ... test seams a test already names"), except consider retiring superseded legacy knobs (`MusicEngine.BRINDLE_KEY`, `end_warden_lap`, `segments_cut`) if their tests are legacy prototypes. Note: `audio.gd` is in `sound-coverage.md`, so run `model-receipts.mjs --row sound-arbiter-safe` when deleting `TALLY_SOUNDS` and `SET_ANSWER_YIELDS`.
- files to change: `sketches/core-loop/src/presentation/sfx_bank.gd`, `sketches/core-loop/src/presentation/audio.gd`, `sketches/core-loop/src/presentation/special_audio.gd`, `sketches/core-loop/src/presentation/craft/craft_audio_cues.gd`
- size: ~+0 / -14 lines
- risk: low — zero callers in code, tools, tests, or scripts
- behaviour-preserving: yes
- tests that cover it: `sketches/core-loop/tests/sound_arbiter_test.gd`, `sketches/core-loop/tests/tally_kit_test.gd`, `sketches/core-loop/tests/special_audio_test.gd`, `sketches/core-loop/tests/audio_event_bank_test.gd`
- guard: a cheap AST/regex check in `scripts/sketch-lint.mjs` or `scripts/deep-sweep.mjs` for unreferenced `const`s in `src/`.

### SOUND-16 Shallow forwarding wrappers that fail the deletion test
- kind: D
- evidence:
  - `src/presentation/ace_sequencer.gd:135-136`: `static func resolve_manifest(manifest_path, sidecar_dir := "") -> String` forwards verbatim to `MusicRows.resolve_manifest(manifest_path, sidecar_dir)`. Callers (`git grep -n "resolve_manifest" -- src/ tests/` => 8 `src/` hits, 8 `tests/` hits): only `ace_sequencer.gd` itself (`:148, :194`) and `music_rows.gd` (`:199, :211, :241`) plus tests! *(Formal model note: `ace_sequencer.gd` is covered by `SoundArbiter.tla`, though `resolve_manifest` is outside the modeled state machine — run `model-receipts.mjs --row sound-arbiter-safe` if changed.)*
  - `src/presentation/special_audio.gd:32-33`: `static func rammed(enemy: Object) -> bool` forwards verbatim to `SpecialCues.rammed(enemy)`, which is the **sole reason** `special_audio.gd` preloads `src/combat/special_cues.gd` (`:4`)!
  - `src/presentation/music_engine.gd:729-730`: `static func stage_theme(stage = "default") -> int` duplicates `MusicRows.stage_theme` (`music_rows.gd:192-193`).
  - `src/presentation/experimental_audio_bank.gd:122-123` (`reset_cooldowns`), `:133-134` (`has_event`), `:251-260` (`pitted_iron_mask`, `slag_crust_mask`, `corrosive_brine_mask` — 1-line forwarders to `load_pbr_mask`).
- fix: Inline `MusicRows.resolve_manifest` inside `ace_sequencer.gd` (or keep only if tests call `AceSequencer.resolve_manifest` directly — check those 8 test hits first), remove `SpecialAudio.rammed` (have `audio.gd` or `SpecialCues` own the check without the redundant relay), replace `MusicEngine.stage_theme` with `MusicRows.stage_theme`, and delete the 1-line mask forwarders in `experimental_audio_bank.gd`.
- files to change: `sketches/core-loop/src/presentation/ace_sequencer.gd`, `sketches/core-loop/src/presentation/special_audio.gd`, `sketches/core-loop/src/presentation/audio.gd`, `sketches/core-loop/src/presentation/music_engine.gd`, `sketches/core-loop/src/presentation/experimental_audio_bank.gd`
- size: ~+5 / -35 lines
- risk: low — pure pass-through removal; verify test callers of `AceSequencer.resolve_manifest` and `MusicEngine.stage_theme`
- behaviour-preserving: yes
- tests that cover it: `sketches/core-loop/tests/special_audio_test.gd`, `sketches/core-loop/tests/audio_music_rows_test.gd`, `sketches/core-loop/tests/sound_arbiter_test.gd`, `sketches/core-loop/tests/experimental_audio_bank_test.gd`
- guard: `scripts/deep-sweep.mjs` D1 already flags new 1-line pass-through wrappers.

### SOUND-17 `music_engine.gd` (2,989 lines) mixes four separable seams: static pre-baker, park-cue async renderer, phrase generator, and real-time sequencer
- kind: H
- evidence:
  - `src/presentation/music_engine.gd` combines four distinct subsystems:
    1. **Static background pre-bake orchestrator** (`music_engine.gd:296-509`, **214 lines**, 7 static funcs + `_rest_lock`) — knows all progressions/shifts to warm `Synth` and `SfxBank` caches, touches zero instance state of `MusicEngine`.
    2. **Park-cue async warmer & PCM renderer** (`music_engine.gd:150-154, 1217-1342, 1397-1425, 1455-1461`, **~190 lines**, static `_park_warm`/`_park_warm_lock`/`_park_tasks` + `_park_pcm`) — self-contained PCM synthesizer (`_render_park` even implements an inline `steam_whistle` synth that belongs in `Synth`/`SfxBank`!).
    3. **Pure melodic phrase generator** (`music_engine.gd:2891-2989`, **99 lines**, 5 static funcs: `make_lead`, `make_lounge_lead`, `_place`, `_transpose`, `_answer`) plus `_make_counter` / `_make_class_counter` (`:2572-2607`, **36 lines**) — pure music-theory transforms over `Harmony`.
    4. **Real-time step sequencer, pattern triggers, and stereo mixer** (remaining ~2,450 lines).
- fix: Extract seams 1 and 3 first (`music_prebake.gd` and `music_phrases.gd`, both 100% static/pure with zero instance-state coupling), and move `_render_park`'s `steam_whistle` synth into `synth.gd`.
- files to change: `sketches/core-loop/src/presentation/music_engine.gd`, `sketches/core-loop/src/presentation/music_prebake.gd` (new), `sketches/core-loop/src/presentation/music_phrases.gd` (new), `sketches/core-loop/src/presentation/synth.gd`
- size: ~+30 / -0 net (moves ~350 lines out of `music_engine.gd`, keeping thin static entrypoints `MusicEngine.prepare()`/`make_lead()` if external tests call them directly)
- risk: low — pure static extractions with deterministic seeds and existing tests
- behaviour-preserving: yes — identical RNG seeds, sample values, and bake order
- tests that cover it: `sketches/core-loop/tests/audio_bakes_ahead_test.gd`, `sketches/core-loop/tests/park_music_cues_test.gd`, `sketches/core-loop/tests/presentation_music_test.gd` (and 40+ `music_engine.gd` tests)
- guard: `scripts/deep-sweep.mjs` D5 (`GIANT_LINES = 1500`).

## Not findings
- `src/presentation/sound_twins.gd` (317 lines, 0 `src/` callers): intentional test-only contract ledger read by `tests/sound_twins_test.gd` and `tests/sound_own_recipes_test.gd` to enforce visual twins for audio cues — not dead production code.
- `src/presentation/music_arbiter.gd`, `src/presentation/melody_lease.gd`, and `src/presentation/ace_sequencer.gd`'s `trim_epoch`/`shots`/`pump` logic: small, deep, formally verified by `SoundArbiter.tla` (`sound-coverage.md`, 8/8 mutant plants); leave intact unless modifying the TLA+ spec in the same PR.
- `src/presentation/ambient_homes.gd`, `ambient_life.gd`, `ambient_pool.gd`: matched the slice filename filter on `ambient`, but own ambient wildlife placement/simulation; `ambient_life.gd:345` `static var _painted` is intentionally session-wide to prevent Godot skinned-mesh free errors.
- `src/presentation/audio.gd` `const` aliases (`BUSES := MixRows.BUS_DB`, `VOICE_LIMIT := SfxBank.VOICE_LIMIT`, `MIN_GAP_MS := SfxBank.MIN_GAP_MS`, `DANGER_SOUNDS := SfxBank.DANGER_SOUNDS`, `KEYED_SOUNDS := SfxBank.KEYED_SOUNDS`, `KEST_SOUNDS := SfxBank.KEST_SOUNDS`): single-source re-exports, not duplicated tables.
- `src/presentation/audio.gd:342, 354` `AudioServer.get_driver_name() != "Dummy"`: deliberate headless audio-driver guard (preventing Dummy-driver shutdown leaks), distinct from `AppShell.headless()` (lint rule L13).
- `src/presentation/ace_sequencer.gd:75-77` `_kept` LRU cache and `sfx_bank.gd` `_samples`/`_streams`/`_rendered`/`_file_present` mutex caches: immutable PCM/resource memo caches safe across batched tests (unlike mutable config vars in SOUND-10).
- `src/presentation/title_stage.gd:328-331` `audio.has_method("bar_since_s")`: guarded optional hook explicitly documented and skipped in `tests/title_thump_test.gd:115-117`, not a broken call.
- `src/presentation/mix_rows.gd`, `music_dsp.gd`, `sfx_budget.gd`, `menu_sounds.gd`, `phase_music.gd`: already well-scoped leaf modules with clean interfaces; keep separate rather than folding back into `audio.gd`.
- `src/presentation/audio.gd` dual-engine design (`MusicEngine` synth + `AceSequencer` recorded stems): intentional runtime fallback when optional ACE Ogg packs are absent, not duplicate implementations.

## Needs the owner
- **Retiring `CraftAudioCues` and `ExperimentalAudioBank` overlap (`SOUND-11`)**: decide whether the experimental audio assets under `res://assets/audio/experimental/` (and `PBR_MASK_SPECS`) graduate into `SfxBank`/`Audio` or should be deleted (deletion requires owner go-ahead per `AGENTS.md`).
- **Reconciling the 8 drifted dB trims between `SfxBank.TRIM_DB` and `FoleyAudio.TRIM_DB` / `JoltLayerAudio.TRIM_DB` (`SOUND-01`)**: confirm whether the currently heard 3D values in `foley_audio.gd`/`jolt_layer_audio.gd` or the entries in `sfx_bank.gd` are the intended mix target.
- **Canonical audio boundary for lower layers (`SOUND-03`, `SOUND-06`)**: decide whether `combat`/`world`/`build`/`boss` should move strictly to `GameEvents` signals for all 3D foley/kit cues (full `CONTRACTS.md` purity) or use a shared `ctx.audio` playback facade.
- **TTS voice sidecar lifecycle (`SOUND-08`)**: confirm whether `--voice=tts` (`audio.gd:5116-5263`) is a permanent shipping path (extract to `voice_sidecar.gd`) or a temporary W46 audition harness that can later be retired.
