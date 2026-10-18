# Sound that answers play

How the soundtrack and the event set plug into the running game, written 2026-10-16 for the wave coordinator, who owns `src/`. The target is Andrew's own test: during real play, he can't stay seated. Music is not a playlist here. It is a second controller output: every thing the player does that matters gets an answer the ear can read with the eyes closed.

Everything below maps onto calls the engine already has (`music_engine.gd`, `audio.gd`, `sfx_bank.gd`). Nothing here asks for a new engine.

## 1. Two hard targets, checked by a tool

| Target | Value | How it is checked |
| --- | --- | --- |
| Gameplay sound latency | A hit, stomp, wall bash, hurt or telegraph sounds on the frame it happens: at most one frame (16.7 ms at 60 fps) from the event to `AudioStreamPlayer.play()` | The assets: [check_events.py](check_events.py) fails any impact, danger or boss cue whose onset is later than 5 ms into the file. It passed 49 of 49 cues on 2026-10-16, and its planted late cue fails as it should. The engine side is a lab trace: frame of the event against the frame of `play()`, from the existing `audio.gd` cue log. |
| Musical answers land on the grid | Every musical stinger (boss phase, knockout, kill-chain tier, world clear) starts on the next beat, never later than one beat: 349 ms at 172 BPM and 465 ms at 129 BPM | The existing `drop_now` and `_queue` scheduling already quantize. Add one assertion to the music tests: the scheduled sample offset modulo the beat length is 0. |

Sound on the frame, music on the grid (AUDIO-V3 §2.5). A musical answer never delays a gameplay sound, and the player is never graded against the beat.

## 2. Music follows the player's momentum

The three music stems the manifests already split (drums, bass, other) become the momentum meter. Each layer reads one game fact:

| Stem | Reads | Behaviour |
| --- | --- | --- |
| Bass | always on in a stage | The world's identity; ducks under danger cues as today (`duck_bass`) |
| Drums | rolling speed | Fades in from a quarter of top speed, full at half speed. Standing still leaves bass and keys: the world breathes. |
| Other (sax lead, brass) | combo: kill chain and stomp chain | The sax hook enters at chain 2. Brass answers join at chain 4. A broken chain lets the lead finish its phrase, never cutting mid-note. |

This is `set_pressure` with a new parameter source (`set_parameter_source` already exists), so the three faders are one call fed by speed and chain. Smoothing: a fader rises over one beat and falls over two bars, so a single bump never makes the band stutter.

## 3. Moves that land on the music

| Player action | Sound on the frame | Musical answer on the next beat |
| --- | --- | --- |
| Stomp (landing on an enemy) | `slam_boom` | A one-beat band gap, then the downbeat hits harder: `drop_now(1, 0.6)` |
| Wall bash | `smash_crack` | A brass stab from the world's lead family when the bash is above three quarters of top speed |
| Kill chain | `kill_pop`, then `kill_chain_tier_1` to `_5` | Each tier is one more note of a rising D Dorian phrase, so a five-chain plays a melody. Tier 5 triggers the lead stem's hook. |
| Scrap pickup run | `scrap_tick_1` to `_5` by pickup streak | Same ladder, so collecting sounds like playing scales |
| Boost and dash | `boost_whoosh`, `dash_whoosh` | None. Movement is never quantized. |
| Getting hurt | `hurt` (the tritone rasp) | Bass ducks for half a second |

## 4. Boss fights are duels

A boss arrival freezes on the intro card under `boss_arena_in`, the versus stinger, then `begin_boss`. Each posture phase change plays `boss_phase` and moves the boss track to its next section with `set_boss_state`. The stagger that ends the fight plays `stinger_boss_defeated`, the knockout: one unison hit, a beat of silence, then the cadence home. The boss tracks' B-family phrase states and the pilot's A motif answers; the exchange shortens as phases fall (sound bible, "Boss themes").

## 5. The run, start to finish

| Moment | Cue |
| --- | --- |
| Launch | the opening's theme: the title intro (`title_intros.gd`, `theme`) calls `audio.title_theme`, and title A (sax lead) or B (machine lead) starts on its first bar; with no opening, title A; with no pack for the theme, the plain title |
| Camp | `camp`, 129 BPM, warm, while the camp page is open (`audio.camp_theme`); the title theme returns when it closes |
| Stage roaming | `roam_<world>` at 172 on the shelf of every zone pack in that world (`MusicRows.SHELF`); the Warden's pivot, build, telegraph and drop keep the zone pack's own 129 clips, so no roaming bed plays inside an arena |
| First fight in a stage | the pivot bar into the 129 combat layer: the world track, or the combat hype loop for ordinary fights |
| Warden and world boss | the Warden: the zone pack's combat layer. The world boss: its picked theme (`boss-brindle`, `boss-waking`, `boss-mind`) opens the fight, Brindle's p2 and p3 tracks follow, and the final phase plays its euro track |
| World cleared | `stinger_world`, then the next world's roam |
| Run won | theme C, the show opening (`title-c`, `audio.WON_SUMMARY_ROW`), on the summary and on the final win's ending |
| Run lost | the jazz-club `summary` pack, with its wink |

Every pick whose Oggs are not on disk falls back to the pack it replaced: the zone pack's own shelf, the older boss theme, the plain title or the summary pack.

## 6. Variations: phases, champions, areas, buffs, switch-ups

This builds on section 4. Today `set_boss_state` moves one boss track to its next section. Brindle's phases are now three tracks at three tempos (138, 150, 172), so a phase change is a track swap, not a section jump.

| Trigger | Music does | Where it plugs in |
| --- | --- | --- |
| Boss posture phase falls | `boss_phase` stinger now; the next phase track starts on the next downbeat of the stinger's tempo | `set_boss_state`: map phase index to track (Brindle 1 to 3, the Waking and the Mind: final phase on the last posture) |
| Elite or champion joins a fight | Combat loop crossfades to `champion-hype` over one bar; back when it dies | Director, when an elite affix spawns |
| Player enters a secret area | World roam crossfades to its `secret-<world>` version, same tempo and bar position | Area trigger volume, keep the playhead |
| Random event starts | `switch-hit` stinger, then the event track | Event start, ended by its timer |
| Minigame | `minigame-chiptune` | Minigame scene |
| Buff active | A bus effect on the music bus for its duration, faded in and out over one beat | Status-effect start and end |
| Surprise spawn (ambush, out-of-nowhere boss) | Tape stop over 2 beats, `switch-hit-<bpm>`, new track on the hit | Spawn director |
| Planned change (roam to fight) | `turnaround-<bpm>` over the last bar, new track on the next downbeat | The existing 172 to 129 pivot bar |

Buffs, as stock Godot effects on the music bus:

| Buff | Effects |
| --- | --- |
| Overdrive | `AudioEffectDistortion` (mode tan, drive about 0.5, 60% wet), plus a 16th-note hat layer and a brass stab per bar as one-shots |
| Slow-mo or stun | Music player `pitch_scale` 0.75, `AudioEffectLowPassFilter` at 2.5 kHz |
| Low hull | `AudioEffectLowPassFilter` at 700 Hz, heartbeat one-shots on each beat |
| Shield | `AudioEffectHighPassFilter` at 300 Hz, `AudioEffectChorus`, a bell one-shot per bar |
| Scrap streak | A beat-synced volume duck (sidechain pump), plus a chiptune arpeggio per bar |

Hype rule and extras (sound bible, "The hype rule" and "The four extras"). Decided 2026-10-17: the `euro-*` tracks play only in the final phase; earlier phases keep their current tracks.

| Trigger | Music does | Where it plugs in |
| --- | --- | --- |
| Boss, mini-boss or champion enters its last phase | `hype_drop` starts one bar before the next downbeat, then the fight's `euro-*` track starts on the drop | `set_boss_state`: the last posture phase; elites use their final health third |
| Telegraph or danger cue plays | Music bus band dip: 4 dB at 2 to 4 kHz for the cue's length | An `AudioEffectEQ` on the music bus, gain driven from the cue log |
| Low hull | The low-hull buff: low-pass 700 Hz, heartbeat one-shots on each beat of the current track, band ducked 55% under each thump | Read the beat length from the playing track, so the heartbeat follows phase tempo |
| Survive low hull | `clutch_comeback` quantized to the next bar; the current track restarts pitched up a semitone (`pitch_scale` 1.0595) until the phase ends | Low-hull exit with hull above 1 |
| Retry after death | `retry_kickin` on the first frame of the new run, then the combat or roam track on its downbeat | Restart flow |
| Big hit (crit, gauge release, chain milestone) | `pilot_quote_<class motif>` on the next beat, at most once per 8 bars | `class_def.motif` already names the row |
| Kill chain reaches 20, 35, 50 | `crowd_cheer_1`, `_2`, `_3` on the next beat | The existing chain ladder |
| Smash misses | `whiff_honk` on the next beat | The smash resolver's miss branch |

Only one buff colours the music at a time. Low hull wins over every other buff, because danger outranks reward.

## 7. Hand-over list for the coordinator

1. Import the picked takes as `music_ace/` theme sources with htdemucs stems, using the grid-stretched WAVs from RENDERS.md.
2. Register the 49 event WAVs in `sfx_bank.gd` under their existing keys. Cues with tiers (`kill_chain_tier_1` to `_5`, `scrap_tick_1` to `_5`, `rarity_bell_common`, `_rare`, `_epic`) map to the existing tier and rarity arguments. Keep per-cue voice limits.
3. Feed `set_parameter_source` with rolling speed and chain length for the stem faders in section 2.
4. Add the two section 1 checks to the test suite.
5. Special enemies, from `specials.py` (17 WAVs). Play `<name>_presence` as a looping `AudioStreamPlayer3D` on the enemy, with its own voice so it never steals a combat voice, and stop it on death. Fire `<name>_tell` on the same frame as the visual tell: the Foreman's horn on the beat before the shred wipe, the Dispatcher's on each drop, the Splitter's on the seam flare, the Linker's when the cable goes taut. Fire `<name>_break` on death. The Splitter picks `splitter_break_split` when rammed at ground level and `splitter_break_clean` otherwise. Queue `<name>_spawn` on the next beat through the same quantizer as the stomp downbeats in section 3. Cap presence loops at two specials heard at once, nearest first.
6. Variations: import the picked round-7 takes (RENDERS.md) as tracks and wire the section 6 table.
7. Hype rule and extras: import the final-phase Eurodance picks only (`euro-brindle-p3-s2801`, `euro-waking-final-s2801`, `euro-mind-final-s2801`, `euro-champion-s2901`) and the 13 `extras.py` WAVs, and wire the second section 6 table. The other round-8 takes stay as comparison material.

Not covered here: the in-game mix under real combat noise, and whether the stem faders feel right. Both need Andrew playing.
