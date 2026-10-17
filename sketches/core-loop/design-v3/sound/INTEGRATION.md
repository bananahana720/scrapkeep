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
| Launch | one of titles A, B or C, never the same twice in a row |
| Camp | `camp`, 129 BPM, warm |
| Stage roaming | `roam-<world>` at 172 |
| First fight in a stage | the pivot bar into the 129 combat layer: the world track, or the combat hype loop for ordinary fights |
| Warden and world boss | the world's boss theme |
| World cleared | `stinger_world`, then the next world's roam |
| Run won | `summary-win`, then on the final win the ending |
| Run lost | `summary-loss`, with its wink |

## 6. Hand-over list for the coordinator

1. Import the picked takes as `music_ace/` theme sources with htdemucs stems, using the grid-stretched WAVs from RENDERS.md.
2. Register the 49 event WAVs in `sfx_bank.gd` under their existing keys. Cues with tiers (`kill_chain_tier_1` to `_5`, `scrap_tick_1` to `_5`, `rarity_bell_common`, `_rare`, `_epic`) map to the existing tier and rarity arguments. Keep per-cue voice limits.
3. Feed `set_parameter_source` with rolling speed and chain length for the stem faders in section 2.
4. Add the two section 1 checks to the test suite.
5. Special enemies, from `specials.py` (17 WAVs). Play `<name>_presence` as a looping `AudioStreamPlayer3D` on the enemy, with its own voice so it never steals a combat voice, and stop it on death. Fire `<name>_tell` on the same frame as the visual tell: the Foreman's horn on the beat before the shred wipe, the Dispatcher's on each drop, the Splitter's on the seam flare, the Linker's when the cable goes taut. Fire `<name>_break` on death. The Splitter picks `splitter_break_split` when rammed at ground level and `splitter_break_clean` otherwise. Queue `<name>_spawn` on the next beat through the same quantizer as the stomp downbeats in section 3. Cap presence loops at two specials heard at once, nearest first.

Not covered here: the in-game mix under real combat noise, and whether the stem faders feel right. Both need Andrew playing.
